const std = @import("std");

pub const vendor_id: u16 = 0x1af4;
pub const modern_device_id_gpu: u16 = 0x1050;

pub const device_type_gpu: u32 = 16;

pub const feature_version_1: u64 = 1 << 32;

pub const status_acknowledge: u8 = 1;
pub const status_driver: u8 = 2;
pub const status_driver_ok: u8 = 4;
pub const status_features_ok: u8 = 8;
pub const status_failed: u8 = 0x80;

const pci_cap_vendor: u8 = 0x09;
const pci_cap_common_cfg: u8 = 1;
const pci_cap_notify_cfg: u8 = 2;
const pci_cap_isr_cfg: u8 = 3;
const pci_cap_device_cfg: u8 = 4;

const pci_config_address: u16 = 0xcf8;
const pci_config_data: u16 = 0xcfc;
const pci_command: u8 = 0x04;
const pci_status: u8 = 0x06;
const pci_header_type: u8 = 0x0e;
const pci_bar0: u8 = 0x10;
const pci_capability_list: u8 = 0x34;
const pci_command_memory: u16 = 0x0002;
const pci_command_bus_master: u16 = 0x0004;
const pci_status_capabilities: u16 = 0x0010;

pub const Error = error{
    DeviceNotFound,
    FeatureNegotiationFailed,
    InvalidBar,
    MissingCapability,
    MissingTransport,
    QueueSetupFailed,
    QueueTooSmall,
    UnsupportedDevice,
};

pub const DeviceInfo = struct {
    vendor_id: u16,
    device_id: u16,
    device_type: u32,
    bus: u8,
    slot: u8,
    function: u8,
};

pub const PciCap = struct {
    cfg_type: u8,
    bar: u8,
    offset: u32,
    length: u32,
    notify_off_multiplier: u32 = 0,
};

pub const ModernPciDevice = struct {
    bus: u8,
    slot: u8,
    function: u8,
    common: PciCap,
    notify: PciCap,
    device: ?PciCap,
    isr: ?PciCap,

    pub fn map(self: ModernPciDevice) Error!Transport {
        const common_cfg = try mapPciCap(self.bus, self.slot, self.function, self.common);
        const notify_cfg = try mapPciCap(self.bus, self.slot, self.function, self.notify);
        const device_cfg = if (self.device) |cap| try mapPciCap(self.bus, self.slot, self.function, cap) else null;
        const isr_cfg = if (self.isr) |cap| try mapPciCap(self.bus, self.slot, self.function, cap) else null;
        return .{ .modern_pci = .{
            .bus = self.bus,
            .slot = self.slot,
            .function = self.function,
            .common_cfg = common_cfg,
            .notify_cfg = notify_cfg,
            .device_cfg = device_cfg,
            .isr_cfg = isr_cfg,
            .notify_off_multiplier = self.notify.notify_off_multiplier,
        } };
    }
};

pub const Transport = union(enum) {
    modern_pci: ModernPciTransport,

    pub fn status(self: Transport) u8 {
        return switch (self) {
            .modern_pci => |pci| read8(pci.common_cfg + 20),
        };
    }

    pub fn writeStatus(self: Transport, value: u8) void {
        switch (self) {
            .modern_pci => |pci| write8(pci.common_cfg + 20, value),
        }
    }

    pub fn readDeviceFeatures(self: Transport) u64 {
        return switch (self) {
            .modern_pci => |pci| readModernDeviceFeatures(pci.common_cfg),
        };
    }

    pub fn writeDriverFeatures(self: Transport, features: u64) void {
        switch (self) {
            .modern_pci => |pci| writeModernDriverFeatures(pci.common_cfg, features),
        }
    }

    pub fn selectQueue(self: Transport, queue: u16) void {
        switch (self) {
            .modern_pci => |pci| write16(pci.common_cfg + 22, queue),
        }
    }

    pub fn readQueueSize(self: Transport) u16 {
        return switch (self) {
            .modern_pci => |pci| read16(pci.common_cfg + 24),
        };
    }

    pub fn readQueueNotifyOff(self: Transport) u16 {
        return switch (self) {
            .modern_pci => |pci| read16(pci.common_cfg + 30),
        };
    }

    pub fn notifyQueue(self: Transport, queue_notify_off: u16, queue: u16) void {
        switch (self) {
            .modern_pci => |pci| {
                const offset = @as(u64, queue_notify_off) * pci.notify_off_multiplier;
                write16(pci.notify_cfg + offset, queue);
            },
        }
    }

    pub fn takeInterruptStatus(self: Transport) u8 {
        return switch (self) {
            .modern_pci => |pci| if (pci.isr_cfg) |isr| read8(isr) else 0,
        };
    }

    pub fn enable(self: Transport) void {
        switch (self) {
            .modern_pci => |pci| enablePciMemoryAndBusMaster(pci.bus, pci.slot, pci.function),
        }
    }

    pub fn fail(self: Transport) void {
        self.writeStatus(self.status() | status_failed);
    }

    pub fn reset(self: Transport) void {
        self.writeStatus(0);
    }

    pub fn driverOk(self: Transport) bool {
        return self.status() & status_driver_ok != 0;
    }

    pub fn negotiateFeatures(self: Transport, supported_features: u64) Error!NegotiatedFeatures {
        self.enable();
        self.writeStatus(0);
        self.writeStatus(status_acknowledge);
        self.writeStatus(status_acknowledge | status_driver);

        const host = self.readDeviceFeatures();
        const driver = host & supported_features;
        if (driver & feature_version_1 == 0) {
            self.fail();
            return error.FeatureNegotiationFailed;
        }

        self.writeDriverFeatures(driver);
        self.writeStatus(self.status() | status_features_ok);
        if (self.status() & status_features_ok == 0) {
            self.fail();
            return error.FeatureNegotiationFailed;
        }
        return .{ .host = host, .driver = driver };
    }

    pub fn configureSplitQueue(
        self: Transport,
        queue: u16,
        max_queue_size: u16,
        min_queue_size: u16,
        desc: u64,
        driver: u64,
        device: u64,
    ) Error!u16 {
        self.selectQueue(queue);
        const queue_size = @min(self.readQueueSize(), max_queue_size);
        if (queue_size < min_queue_size) return error.QueueTooSmall;

        switch (self) {
            .modern_pci => |pci| {
                write16(pci.common_cfg + 24, queue_size);
                write64(pci.common_cfg + 32, desc);
                write64(pci.common_cfg + 40, driver);
                write64(pci.common_cfg + 48, device);
                write16(pci.common_cfg + 28, 1);
            },
        }
        return queue_size;
    }
};

pub const ModernPciTransport = struct {
    bus: u8,
    slot: u8,
    function: u8,
    common_cfg: u64,
    notify_cfg: u64,
    device_cfg: ?u64,
    isr_cfg: ?u64,
    notify_off_multiplier: u32,
};

pub const NegotiatedFeatures = struct {
    host: u64,
    driver: u64,
};

pub const QueueSize = 16;

pub const Desc = extern struct {
    addr: u64,
    len: u32,
    flags: u16,
    next: u16,
};

pub const UsedElem = extern struct {
    id: u32,
    len: u32,
};

pub const Avail = extern struct {
    flags: u16,
    idx: u16,
    ring: [QueueSize]u16,
    used_event: u16,
};

pub const Used = extern struct {
    flags: u16,
    idx: u16,
    ring: [QueueSize]UsedElem,
    avail_event: u16,
};

pub const desc_flag_next: u16 = 1;
pub const desc_flag_write: u16 = 2;

pub fn findModernPciDevice(device_id: u16) ?ModernPciDevice {
    var bus: u8 = 0;
    while (bus <= 0) : (bus += 1) {
        var slot: u8 = 0;
        while (slot < 32) : (slot += 1) {
            var function: u8 = 0;
            while (function < 8) : (function += 1) {
                const found_vendor = pciRead16(bus, slot, function, 0x00);
                if (found_vendor == 0xffff) {
                    if (function == 0) break;
                    continue;
                }
                const found_device = pciRead16(bus, slot, function, 0x02);
                if (found_vendor == vendor_id and found_device == device_id) {
                    if (readModernPciDevice(bus, slot, function)) |device| return device;
                }
                if (function == 0 and !isMultifunction(bus, slot)) break;
            }
        }
        if (bus == 0xff) break;
    }
    return null;
}

pub fn readModernPciDevice(bus: u8, slot: u8, function: u8) ?ModernPciDevice {
    if (pciRead16(bus, slot, function, pci_status) & pci_status_capabilities == 0) return null;

    var common: ?PciCap = null;
    var notify: ?PciCap = null;
    var device: ?PciCap = null;
    var isr: ?PciCap = null;
    var cap_ptr = pciRead8(bus, slot, function, pci_capability_list) & ~@as(u8, 0x3);
    var guard: usize = 0;
    while (cap_ptr >= 0x40 and guard < 48) : (guard += 1) {
        const cap_vndr = pciRead8(bus, slot, function, cap_ptr);
        const cap_next = pciRead8(bus, slot, function, cap_ptr + 1) & ~@as(u8, 0x3);
        const cap_len = pciRead8(bus, slot, function, cap_ptr + 2);
        if (cap_vndr == pci_cap_vendor and cap_len >= 16) {
            const cfg_type = pciRead8(bus, slot, function, cap_ptr + 3);
            const cap = PciCap{
                .cfg_type = cfg_type,
                .bar = pciRead8(bus, slot, function, cap_ptr + 4),
                .offset = pciRead32(bus, slot, function, cap_ptr + 8),
                .length = pciRead32(bus, slot, function, cap_ptr + 12),
                .notify_off_multiplier = if (cfg_type == pci_cap_notify_cfg and cap_len >= 20)
                    pciRead32(bus, slot, function, cap_ptr + 16)
                else
                    0,
            };
            switch (cfg_type) {
                pci_cap_common_cfg => common = cap,
                pci_cap_notify_cfg => notify = cap,
                pci_cap_isr_cfg => isr = cap,
                pci_cap_device_cfg => device = cap,
                else => {},
            }
        }
        if (cap_next == 0) break;
        cap_ptr = cap_next;
    }

    return .{
        .bus = bus,
        .slot = slot,
        .function = function,
        .common = common orelse return null,
        .notify = notify orelse return null,
        .device = device,
        .isr = isr,
    };
}

pub fn modernDeviceType(device_id: u16) ?u32 {
    return switch (device_id) {
        modern_device_id_gpu => device_type_gpu,
        else => null,
    };
}

pub fn postDescriptor(avail: *Avail, queue_size: u16, desc_id: u16) void {
    const next_idx = avail.idx +% 1;
    avail.ring[avail.idx % queue_size] = desc_id;
    @atomicStore(u16, &avail.idx, next_idx, .release);
}

pub fn nextUsed(used: *const Used, queue_size: u16, last_used_idx: *u16) ?UsedElem {
    const current = @atomicLoad(u16, &used.idx, .acquire);
    if (current == last_used_idx.*) return null;
    const elem = used.ring[last_used_idx.* % queue_size];
    last_used_idx.* +%= 1;
    return elem;
}

fn mapPciCap(bus: u8, slot: u8, function: u8, cap: PciCap) Error!u64 {
    if (cap.bar >= 6) return error.InvalidBar;
    const bar = pciBarAddress(bus, slot, function, cap.bar) orelse return error.InvalidBar;
    return bar + cap.offset;
}

fn pciBarAddress(bus: u8, slot: u8, function: u8, bar: u8) ?u64 {
    const offset = pci_bar0 + bar * 4;
    const raw = pciRead32(bus, slot, function, offset);
    if (raw == 0 or raw == 0xffff_ffff or raw & 0x1 != 0) return null;
    const base: u64 = if (raw & 0x6 == 0x4)
        (@as(u64, pciRead32(bus, slot, function, offset + 4)) << 32) | @as(u64, raw & ~@as(u32, 0xf))
    else
        @as(u64, raw & ~@as(u32, 0xf));
    return if (base == 0) null else base;
}

fn isMultifunction(bus: u8, slot: u8) bool {
    return pciRead8(bus, slot, 0, pci_header_type) & 0x80 != 0;
}

fn enablePciMemoryAndBusMaster(bus: u8, slot: u8, function: u8) void {
    const command = pciRead16(bus, slot, function, pci_command);
    pciWrite16(bus, slot, function, pci_command, command | pci_command_memory | pci_command_bus_master);
}

fn readModernDeviceFeatures(common_cfg: u64) u64 {
    write32(common_cfg + 0, 0);
    const low = read32(common_cfg + 4);
    write32(common_cfg + 0, 1);
    const high = read32(common_cfg + 4);
    return @as(u64, low) | (@as(u64, high) << 32);
}

fn writeModernDriverFeatures(common_cfg: u64, features: u64) void {
    write32(common_cfg + 8, 0);
    write32(common_cfg + 12, @intCast(features & 0xffff_ffff));
    write32(common_cfg + 8, 1);
    write32(common_cfg + 12, @intCast(features >> 32));
}

fn pciAddress(bus: u8, slot: u8, function: u8, offset: u8) u32 {
    return 0x8000_0000 |
        (@as(u32, bus) << 16) |
        (@as(u32, slot) << 11) |
        (@as(u32, function) << 8) |
        (@as(u32, offset) & 0xfc);
}

fn pciRead32(bus: u8, slot: u8, function: u8, offset: u8) u32 {
    outl(pci_config_address, pciAddress(bus, slot, function, offset));
    return inl(pci_config_data);
}

fn pciWrite32(bus: u8, slot: u8, function: u8, offset: u8, value: u32) void {
    outl(pci_config_address, pciAddress(bus, slot, function, offset));
    outl(pci_config_data, value);
}

fn pciRead16(bus: u8, slot: u8, function: u8, offset: u8) u16 {
    const shift: u5 = @intCast((offset & 0x2) * 8);
    return @intCast((pciRead32(bus, slot, function, offset) >> shift) & 0xffff);
}

fn pciWrite16(bus: u8, slot: u8, function: u8, offset: u8, value: u16) void {
    const shift: u5 = @intCast((offset & 0x2) * 8);
    const mask = ~(@as(u32, 0xffff) << shift);
    const current = pciRead32(bus, slot, function, offset);
    pciWrite32(bus, slot, function, offset, (current & mask) | (@as(u32, value) << shift));
}

fn pciRead8(bus: u8, slot: u8, function: u8, offset: u8) u8 {
    const shift: u5 = @intCast((offset & 0x3) * 8);
    return @intCast((pciRead32(bus, slot, function, offset) >> shift) & 0xff);
}

fn read8(address: u64) u8 {
    const ptr: *volatile u8 = @ptrFromInt(address);
    return ptr.*;
}

fn read16(address: u64) u16 {
    const ptr: *volatile u16 = @ptrFromInt(address);
    return ptr.*;
}

fn read32(address: u64) u32 {
    const ptr: *volatile u32 = @ptrFromInt(address);
    return ptr.*;
}

fn write8(address: u64, value: u8) void {
    const ptr: *volatile u8 = @ptrFromInt(address);
    ptr.* = value;
}

fn write16(address: u64, value: u16) void {
    const ptr: *volatile u16 = @ptrFromInt(address);
    ptr.* = value;
}

fn write32(address: u64, value: u32) void {
    const ptr: *volatile u32 = @ptrFromInt(address);
    ptr.* = value;
}

fn write64(address: u64, value: u64) void {
    const ptr: *volatile u64 = @ptrFromInt(address);
    ptr.* = value;
}

fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[value]"
        : [value] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}

fn outl(port: u16, value: u32) void {
    asm volatile ("outl %[value], %[port]"
        :
        : [value] "{eax}" (value),
          [port] "{dx}" (port),
    );
}

test "modern virtio gpu device id maps to device type" {
    try std.testing.expectEqual(device_type_gpu, modernDeviceType(modern_device_id_gpu).?);
    try std.testing.expect(modernDeviceType(0x1041) == null);
}

test "split virtqueue layout matches virtio basics" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Desc));
    try std.testing.expectEqual(@as(usize, 8), @alignOf(Desc));
    try std.testing.expectEqual(@as(usize, 2), @alignOf(Avail));
    try std.testing.expectEqual(@as(usize, 4), @alignOf(Used));
}

test "post descriptor advances avail ring with wrapping index" {
    var avail = Avail{ .flags = 0, .idx = 15, .ring = [_]u16{0} ** QueueSize, .used_event = 0 };
    postDescriptor(&avail, QueueSize, 7);
    try std.testing.expectEqual(@as(u16, 7), avail.ring[15]);
    try std.testing.expectEqual(@as(u16, 16), avail.idx);
}

test "single used completion accepts one entry" {
    var used = Used{
        .flags = 0,
        .idx = 1,
        .ring = [_]UsedElem{.{ .id = 7, .len = 11 }} ** QueueSize,
        .avail_event = 0,
    };
    var last: u16 = 0;
    const elem = nextUsed(&used, QueueSize, &last).?;
    try std.testing.expectEqual(@as(u32, 7), elem.id);
    try std.testing.expectEqual(@as(u32, 11), elem.len);
    try std.testing.expectEqual(@as(u16, 1), last);
    try std.testing.expect(nextUsed(&used, QueueSize, &last) == null);
}
