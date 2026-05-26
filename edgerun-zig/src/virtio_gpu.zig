const std = @import("std");
const virtio = @import("virtio.zig");

pub const device_id = virtio.modern_device_id_gpu;
pub const device_type = virtio.device_type_gpu;
pub const feature_virgl: u64 = 1 << 0;
pub const feature_edid: u64 = 1 << 1;
pub const feature_resource_uuid: u64 = 1 << 2;
pub const feature_resource_blob: u64 = 1 << 3;
pub const feature_context_init: u64 = 1 << 4;

pub const control_queue: u16 = 0;
pub const cursor_queue: u16 = 1;
const poll_spins: usize = 5_000_000;

pub const ControlType = enum(u32) {
    get_display_info = 0x0100,
    resource_create_2d = 0x0101,
    resource_unref = 0x0102,
    set_scanout = 0x0103,
    resource_flush = 0x0104,
    transfer_to_host_2d = 0x0105,
    resource_attach_backing = 0x0106,
    resource_detach_backing = 0x0107,
    resp_ok_nodata = 0x1100,
    resp_ok_display_info = 0x1101,
    resp_err_unspec = 0x1200,
    resp_err_out_of_memory = 0x1201,
    resp_err_invalid_scanout_id = 0x1202,
    resp_err_invalid_resource_id = 0x1203,
    resp_err_invalid_context_id = 0x1204,
    resp_err_invalid_parameter = 0x1205,
};

pub const Format = enum(u32) {
    b8g8r8a8_unorm = 1,
    b8g8r8x8_unorm = 2,
    a8r8g8b8_unorm = 3,
    x8r8g8b8_unorm = 4,
    r8g8b8a8_unorm = 67,
    x8b8g8r8_unorm = 68,
    a8b8g8r8_unorm = 121,
    r8g8b8x8_unorm = 134,
};

pub const Header = extern struct {
    control_type: ControlType,
    flags: u32 = 0,
    fence_id: u64 = 0,
    context_id: u32 = 0,
    padding: u32 = 0,
};

pub const Rect = extern struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

pub const Display = extern struct {
    rect: Rect,
    enabled: u32,
    flags: u32,
};

pub const DisplayInfoResponse = extern struct {
    header: Header,
    displays: [16]Display,
};

pub const ResourceCreate2d = extern struct {
    header: Header,
    resource_id: u32,
    format: Format,
    width: u32,
    height: u32,

    pub fn init(resource_id: u32, width: u32, height: u32, format: Format) ResourceCreate2d {
        return .{
            .header = .{ .control_type = .resource_create_2d },
            .resource_id = resource_id,
            .format = format,
            .width = width,
            .height = height,
        };
    }
};

pub const MemEntry = extern struct {
    address: u64,
    length: u32,
    padding: u32 = 0,
};

pub const ResourceAttachBacking = extern struct {
    header: Header,
    resource_id: u32,
    nr_entries: u32,
    entry: MemEntry,

    pub fn init(resource_id: u32, address: u64, byte_len: u32) ResourceAttachBacking {
        return .{
            .header = .{ .control_type = .resource_attach_backing },
            .resource_id = resource_id,
            .nr_entries = 1,
            .entry = .{ .address = address, .length = byte_len },
        };
    }
};

pub const SetScanout = extern struct {
    header: Header,
    rect: Rect,
    scanout_id: u32,
    resource_id: u32,

    pub fn init(scanout_id: u32, resource_id: u32, width: u32, height: u32) SetScanout {
        return .{
            .header = .{ .control_type = .set_scanout },
            .rect = .{ .x = 0, .y = 0, .width = width, .height = height },
            .scanout_id = scanout_id,
            .resource_id = resource_id,
        };
    }
};

pub const TransferToHost2d = extern struct {
    header: Header,
    rect: Rect,
    offset: u64,
    resource_id: u32,
    padding: u32 = 0,

    pub fn init(resource_id: u32, width: u32, height: u32) TransferToHost2d {
        return .{
            .header = .{ .control_type = .transfer_to_host_2d },
            .rect = .{ .x = 0, .y = 0, .width = width, .height = height },
            .offset = 0,
            .resource_id = resource_id,
        };
    }
};

pub const ResourceFlush = extern struct {
    header: Header,
    rect: Rect,
    resource_id: u32,
    padding: u32 = 0,

    pub fn init(resource_id: u32, width: u32, height: u32) ResourceFlush {
        return .{
            .header = .{ .control_type = .resource_flush },
            .rect = .{ .x = 0, .y = 0, .width = width, .height = height },
            .resource_id = resource_id,
        };
    }
};

pub const Response = extern struct {
    header: Header,

    pub fn okNoData(self: Response) bool {
        return self.header.control_type == .resp_ok_nodata;
    }
};

pub const Error = virtio.Error || error{
    DeviceTimeout,
    InvalidResponse,
};

pub const QueueStorage = struct {
    desc: [virtio.QueueSize]virtio.Desc align(16) = [_]virtio.Desc{.{ .addr = 0, .len = 0, .flags = 0, .next = 0 }} ** virtio.QueueSize,
    avail: virtio.Avail align(2) = .{ .flags = 0, .idx = 0, .ring = [_]u16{0} ** virtio.QueueSize, .used_event = 0 },
    used: virtio.Used align(4) = .{ .flags = 0, .idx = 0, .ring = [_]virtio.UsedElem{.{ .id = 0, .len = 0 }} ** virtio.QueueSize, .avail_event = 0 },
    response: Response align(8) = .{ .header = .{ .control_type = .resp_err_unspec } },

    fn reset(self: *QueueStorage) void {
        @memset(&self.desc, .{ .addr = 0, .len = 0, .flags = 0, .next = 0 });
        self.avail = .{ .flags = 0, .idx = 0, .ring = [_]u16{0} ** virtio.QueueSize, .used_event = 0 };
        self.used = .{ .flags = 0, .idx = 0, .ring = [_]virtio.UsedElem{.{ .id = 0, .len = 0 }} ** virtio.QueueSize, .avail_event = 0 };
        self.response = .{ .header = .{ .control_type = .resp_err_unspec } };
    }
};

pub const Device = struct {
    transport: virtio.Transport,
    features: virtio.NegotiatedFeatures,
    queue_notify_off: u16,
    queue_size: u16,
    last_used_idx: u16 = 0,

    pub fn initFromTransport(transport: virtio.Transport, storage: *QueueStorage) Error!Device {
        return initFromTransportWithFeatures(transport, storage, feature_virgl | feature_context_init);
    }

    pub fn initFromTransportWithFeatures(transport: virtio.Transport, storage: *QueueStorage, optional_features: u64) Error!Device {
        storage.reset();
        const features = try transport.negotiateFeatures(virtio.feature_version_1 | optional_features);
        transport.selectQueue(control_queue);
        const queue_notify_off = transport.readQueueNotifyOff();
        const queue_size = try transport.configureSplitQueue(
            control_queue,
            virtio.QueueSize,
            2,
            @intFromPtr(&storage.desc),
            @intFromPtr(&storage.avail),
            @intFromPtr(&storage.used),
        );
        transport.writeStatus(transport.status() | virtio.status_driver_ok);
        return .{
            .transport = transport,
            .features = features,
            .queue_notify_off = queue_notify_off,
            .queue_size = queue_size,
        };
    }

    pub fn findAndInit(storage: *QueueStorage) Error!Device {
        const pci_device = findPciDevice() orelse return error.DeviceNotFound;
        return initFromTransport(try pci_device.map(), storage);
    }

    pub fn virglReady(self: Device) bool {
        return self.features.driver & feature_virgl != 0;
    }

    pub fn contextInitReady(self: Device) bool {
        return self.features.driver & feature_context_init != 0;
    }

    pub fn sendNoData(self: *Device, storage: *QueueStorage, command: anytype) Error!void {
        const response = try self.send(storage, std.mem.asBytes(&command));
        if (!response.okNoData()) return error.InvalidResponse;
    }

    pub fn send(self: *Device, storage: *QueueStorage, command_bytes: []const u8) Error!Response {
        if (command_bytes.len == 0 or command_bytes.len > std.math.maxInt(u32)) return error.InvalidResponse;
        storage.response = .{ .header = .{ .control_type = .resp_err_unspec } };
        prepareCommandDescriptors(storage, command_bytes, std.mem.asBytes(&storage.response));
        virtio.postDescriptor(&storage.avail, self.queue_size, 0);
        self.transport.notifyQueue(self.queue_notify_off, control_queue);
        _ = try waitForCompletion(&storage.used, self.queue_size, &self.last_used_idx);
        return storage.response;
    }

    pub fn setup2d(self: *Device, storage: *QueueStorage, setup: Setup2d) Error!void {
        try self.sendNoData(storage, setup.resource);
        try self.sendNoData(storage, setup.backing);
        try self.sendNoData(storage, setup.scanout);
    }

    pub fn flush2d(self: *Device, storage: *QueueStorage, resource_id: u32, width: u32, height: u32) Error!void {
        try self.sendNoData(storage, TransferToHost2d.init(resource_id, width, height));
        try self.sendNoData(storage, ResourceFlush.init(resource_id, width, height));
    }
};

pub const Setup2d = struct {
    resource: ResourceCreate2d,
    backing: ResourceAttachBacking,
    scanout: SetScanout,

    pub fn init(resource_id: u32, scanout_id: u32, width: u32, height: u32, pixel_address: u64, pixel_byte_len: u32) Setup2d {
        return .{
            .resource = ResourceCreate2d.init(resource_id, width, height, .b8g8r8x8_unorm),
            .backing = ResourceAttachBacking.init(resource_id, pixel_address, pixel_byte_len),
            .scanout = SetScanout.init(scanout_id, resource_id, width, height),
        };
    }
};

pub fn findPciDevice() ?virtio.ModernPciDevice {
    return virtio.findModernPciDevice(device_id);
}

fn prepareCommandDescriptors(storage: *QueueStorage, command_bytes: []const u8, response_bytes: []u8) void {
    storage.desc[0] = .{
        .addr = @intFromPtr(command_bytes.ptr),
        .len = @intCast(command_bytes.len),
        .flags = virtio.desc_flag_next,
        .next = 1,
    };
    storage.desc[1] = .{
        .addr = @intFromPtr(response_bytes.ptr),
        .len = @intCast(response_bytes.len),
        .flags = virtio.desc_flag_write,
        .next = 0,
    };
}

fn waitForCompletion(used: *const virtio.Used, queue_size: u16, last_used_idx: *u16) Error!virtio.UsedElem {
    var spins: usize = 0;
    while (virtio.nextUsed(used, queue_size, last_used_idx)) |elem| {
        return elem;
    } else {
        while (spins < poll_spins) : (spins += 1) {
            if (virtio.nextUsed(used, queue_size, last_used_idx)) |elem| return elem;
            std.atomic.spinLoopHint();
        }
    }
    return error.DeviceTimeout;
}

test "virtio gpu command layouts match fixed 2d protocol sizes" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(Header));
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(ResourceCreate2d));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(ResourceAttachBacking));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(SetScanout));
    try std.testing.expectEqual(@as(usize, 56), @sizeOf(TransferToHost2d));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(ResourceFlush));
}

test "setup 2d sequence targets one resource and scanout" {
    const setup = Setup2d.init(1, 0, 640, 480, 0x100000, 640 * 480 * 4);
    try std.testing.expectEqual(ControlType.resource_create_2d, setup.resource.header.control_type);
    try std.testing.expectEqual(ControlType.resource_attach_backing, setup.backing.header.control_type);
    try std.testing.expectEqual(ControlType.set_scanout, setup.scanout.header.control_type);
    try std.testing.expectEqual(@as(u32, 1), setup.resource.resource_id);
    try std.testing.expectEqual(@as(u32, 1), setup.backing.resource_id);
    try std.testing.expectEqual(@as(u32, 1), setup.scanout.resource_id);
    try std.testing.expectEqual(@as(u32, 0), setup.scanout.scanout_id);
}

test "frame update commands cover full resource" {
    const transfer = TransferToHost2d.init(3, 800, 600);
    const flush = ResourceFlush.init(3, 800, 600);
    try std.testing.expectEqual(ControlType.transfer_to_host_2d, transfer.header.control_type);
    try std.testing.expectEqual(ControlType.resource_flush, flush.header.control_type);
    try std.testing.expectEqual(@as(u32, 800), transfer.rect.width);
    try std.testing.expectEqual(@as(u32, 600), flush.rect.height);
    try std.testing.expectEqual(@as(u32, 3), transfer.resource_id);
    try std.testing.expectEqual(@as(u32, 3), flush.resource_id);
}

test "command descriptor chain sends request then writable response" {
    var storage = QueueStorage{};
    const command = ResourceFlush.init(9, 32, 24);
    prepareCommandDescriptors(&storage, std.mem.asBytes(&command), std.mem.asBytes(&storage.response));
    try std.testing.expectEqual(@intFromPtr(std.mem.asBytes(&command).ptr), storage.desc[0].addr);
    try std.testing.expectEqual(@as(u16, virtio.desc_flag_next), storage.desc[0].flags);
    try std.testing.expectEqual(@as(u16, 1), storage.desc[0].next);
    try std.testing.expectEqual(@intFromPtr(std.mem.asBytes(&storage.response).ptr), storage.desc[1].addr);
    try std.testing.expectEqual(@as(u16, virtio.desc_flag_write), storage.desc[1].flags);
}
