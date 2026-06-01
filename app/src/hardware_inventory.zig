const std = @import("er_std");
const acpi = @import("acpi.zig");
const bytes_mod = @import("bytes.zig");
const tpm_acpi = @import("tpm_acpi.zig");

pub const max_pci_devices = 128;

pub const MemoryReadFn = *const fn (address: u64, min_len: usize) ?[]const u8;
pub const PciConfigRead32Fn = *const fn (address: u64) ?u32;

pub const PciDevice = struct {
    segment: u16 = 0,
    bus: u8 = 0,
    device: u8 = 0,
    function: u8 = 0,
    vendor_id: u16 = 0,
    device_id: u16 = 0,
    class_code: u8 = 0,
    subclass: u8 = 0,
    prog_if: u8 = 0,
    revision_id: u8 = 0,
    header_type: u8 = 0,

    pub fn valid(self: PciDevice) bool {
        return self.vendor_id != 0 and self.vendor_id != 0xffff;
    }
};

pub const PciInventory = struct {
    scanned: bool = false,
    overflowed: bool = false,
    device_count: usize = 0,
    devices: [max_pci_devices]PciDevice = [_]PciDevice{.{}} ** max_pci_devices,

    pub fn append(self: *PciInventory, device: PciDevice) void {
        if (!device.valid()) return;
        if (self.device_count >= self.devices.len) {
            self.overflowed = true;
            return;
        }
        self.devices[self.device_count] = device;
        self.device_count += 1;
    }
};

pub const Inventory = struct {
    collected_before_exit_boot_services: bool = false,
    rsdp: acpi.RsdpInfo = .{},
    tables: acpi.TableList = .{},
    madt: ?acpi.MadtInfo = null,
    mcfg: ?acpi.McfgInfo = null,
    hpet: ?acpi.HpetInfo = null,
    fadt: ?acpi.FadtInfo = null,
    tpm2: ?tpm_acpi.Tpm2Info = null,
    pci: PciInventory = .{},

    pub fn hasInterruptTopology(self: Inventory) bool {
        return self.madt != null and self.madt.?.found and self.madt.?.checksum_valid;
    }

    pub fn hasPciEcam(self: Inventory) bool {
        return self.mcfg != null and self.mcfg.?.found and self.mcfg.?.checksum_valid;
    }

    pub fn hasTpm2Crb(self: Inventory) bool {
        return self.tpm2 != null and self.tpm2.?.isCrb();
    }
};

pub fn collectPreExitBootServices(
    efi_tables: []const acpi.EfiConfigurationTable,
    read_memory: MemoryReadFn,
    read_pci_config32: ?PciConfigRead32Fn,
) Inventory {
    var out = Inventory{ .collected_before_exit_boot_services = true };
    out.rsdp = acpi.findRsdpInEfiTables(efi_tables, read_memory) orelse return out;
    out.tables = acpi.enumerateTables(out.rsdp, read_memory) orelse return out;

    if (out.tables.find(acpi.signature("APIC"))) |table| {
        if (read_memory(table.address, table.length)) |bytes| out.madt = acpi.parseMadt(bytes);
    }
    if (out.tables.find(acpi.signature("MCFG"))) |table| {
        if (read_memory(table.address, table.length)) |bytes| out.mcfg = acpi.parseMcfg(bytes);
    }
    if (out.tables.find(acpi.signature("HPET"))) |table| {
        if (read_memory(table.address, table.length)) |bytes| out.hpet = acpi.parseHpet(bytes);
    }
    if (out.tables.find(acpi.signature("FACP"))) |table| {
        if (read_memory(table.address, table.length)) |bytes| out.fadt = acpi.parseFadt(bytes);
    }
    out.tpm2 = tpm_acpi.findTpm2Table(out.tables, read_memory);

    if (read_pci_config32) |read_pci| {
        if (out.mcfg) |mcfg| scanPciEcam(mcfg, read_pci, &out.pci);
    }
    return out;
}

pub fn scanPciEcam(mcfg: acpi.McfgInfo, read_pci_config32: PciConfigRead32Fn, out: *PciInventory) void {
    out.scanned = true;
    if (!mcfg.found or !mcfg.checksum_valid) return;
    for (mcfg.allocations[0..mcfg.allocation_count]) |allocation| {
        var bus = allocation.start_bus;
        while (bus <= allocation.end_bus) : (bus += 1) {
            var device: u8 = 0;
            while (device < 32) : (device += 1) {
                scanPciDevice(mcfg, allocation.pci_segment_group, bus, device, read_pci_config32, out);
            }
            if (bus == 0xff) break;
        }
    }
}

fn scanPciDevice(mcfg: acpi.McfgInfo, segment: u16, bus: u8, device: u8, read_pci_config32: PciConfigRead32Fn, out: *PciInventory) void {
    const function0_address = mcfg.configAddress(segment, bus, device, 0, 0) orelse return;
    const id0 = read_pci_config32(function0_address) orelse return;
    if (!validPciId(id0)) return;

    const header0 = read_pci_config32(function0_address + 0x0c) orelse 0;
    appendPciFunction(mcfg, segment, bus, device, 0, id0, header0, read_pci_config32, out);
    if (((header0 >> 16) & 0x80) == 0) return;

    var function: u8 = 1;
    while (function < 8) : (function += 1) {
        const address = mcfg.configAddress(segment, bus, device, function, 0) orelse continue;
        const id = read_pci_config32(address) orelse continue;
        if (!validPciId(id)) continue;
        const header = read_pci_config32(address + 0x0c) orelse 0;
        appendPciFunction(mcfg, segment, bus, device, function, id, header, read_pci_config32, out);
    }
}

fn appendPciFunction(
    mcfg: acpi.McfgInfo,
    segment: u16,
    bus: u8,
    device: u8,
    function: u8,
    id: u32,
    header: u32,
    read_pci_config32: PciConfigRead32Fn,
    out: *PciInventory,
) void {
    const address = mcfg.configAddress(segment, bus, device, function, 0) orelse return;
    const class_revision = read_pci_config32(address + 0x08) orelse 0;
    out.append(.{
        .segment = segment,
        .bus = bus,
        .device = device,
        .function = function,
        .vendor_id = @intCast(id & 0xffff),
        .device_id = @intCast((id >> 16) & 0xffff),
        .revision_id = @intCast(class_revision & 0xff),
        .prog_if = @intCast((class_revision >> 8) & 0xff),
        .subclass = @intCast((class_revision >> 16) & 0xff),
        .class_code = @intCast((class_revision >> 24) & 0xff),
        .header_type = @intCast((header >> 16) & 0xff),
    });
}

fn validPciId(id: u32) bool {
    const vendor_id = id & 0xffff;
    return vendor_id != 0 and vendor_id != 0xffff;
}

const TestMemory = struct {
    rsdp: []const u8,
    xsdt: []const u8,
    madt: []const u8,
    mcfg: []const u8,
    hpet: []const u8,
    fadt: []const u8,
    tpm2: []const u8,
};

var test_memory: TestMemory = undefined;

fn testReadMemory(address: u64, min_len: usize) ?[]const u8 {
    const bytes = switch (address) {
        0x1000 => test_memory.rsdp,
        0x2000 => test_memory.xsdt,
        0x3000 => test_memory.madt,
        0x4000 => test_memory.mcfg,
        0x5000 => test_memory.hpet,
        0x6000 => test_memory.fadt,
        0x7000 => test_memory.tpm2,
        else => return null,
    };
    if (bytes.len < min_len) return null;
    return bytes;
}

fn testReadPciConfig32(address: u64) ?u32 {
    return switch (address) {
        0xe000_0000 => 0x100e_8086,
        0xe000_0008 => 0x0200_0001,
        0xe000_000c => 0x0000_0000,
        else => 0xffff_ffff,
    };
}

fn putLe16(out: []u8, value: u16) void {
    _ = bytes_mod.store16(out, value);
}

fn putLe32(out: []u8, value: u32) void {
    _ = bytes_mod.store32(out, value);
}

fn putLe64(out: []u8, value: u64) void {
    _ = bytes_mod.store64(out, value);
}

fn finishChecksum(bytes: []u8) void {
    bytes[9] = 0;
    var sum: u8 = 0;
    for (bytes) |byte| sum +%= byte;
    bytes[9] = 0 -% sum;
}

fn finishRsdpChecksum(bytes: []u8) void {
    bytes[8] = 0;
    var sum20: u8 = 0;
    for (bytes[0..acpi.rsdp_v1_len]) |byte| sum20 +%= byte;
    bytes[8] = 0 -% sum20;
    bytes[32] = 0;
    var sum36: u8 = 0;
    for (bytes[0..acpi.rsdp_v2_min_len]) |byte| sum36 +%= byte;
    bytes[32] = 0 -% sum36;
}

test "collects full hardware inventory before ExitBootServices" {
    var rsdp = [_]u8{0} ** acpi.rsdp_v2_min_len;
    @memcpy(rsdp[0..8], "RSD PTR ");
    rsdp[15] = 2;
    putLe32(rsdp[20..24], rsdp.len);
    putLe64(rsdp[24..32], 0x2000);
    finishRsdpChecksum(&rsdp);

    var xsdt = [_]u8{0} ** (acpi.sdt_header_len + 5 * 8);
    putLe32(xsdt[0..4], acpi.signature("XSDT"));
    putLe32(xsdt[4..8], xsdt.len);
    putLe64(xsdt[36..44], 0x3000);
    putLe64(xsdt[44..52], 0x4000);
    putLe64(xsdt[52..60], 0x5000);
    putLe64(xsdt[60..68], 0x6000);
    putLe64(xsdt[68..76], 0x7000);
    finishChecksum(&xsdt);

    var madt = [_]u8{0} ** 52;
    putLe32(madt[0..4], acpi.signature("APIC"));
    putLe32(madt[4..8], madt.len);
    putLe32(madt[36..40], 0xfee0_0000);
    madt[44] = @intFromEnum(acpi.MadtEntryKind.lapic);
    madt[45] = 8;
    madt[46] = 1;
    madt[47] = 2;
    putLe32(madt[48..52], acpi.madt_lapic_enabled);
    finishChecksum(&madt);

    var mcfg = [_]u8{0} ** 60;
    putLe32(mcfg[0..4], acpi.signature("MCFG"));
    putLe32(mcfg[4..8], mcfg.len);
    putLe64(mcfg[44..52], 0xe000_0000);
    putLe16(mcfg[52..54], 0);
    mcfg[54] = 0;
    mcfg[55] = 0;
    finishChecksum(&mcfg);

    var hpet = [_]u8{0} ** 56;
    putLe32(hpet[0..4], acpi.signature("HPET"));
    putLe32(hpet[4..8], hpet.len);
    putLe32(hpet[36..40], 0x8086_2001);
    putLe64(hpet[44..52], 0xfed0_0000);
    finishChecksum(&hpet);

    var fadt = [_]u8{0} ** 129;
    putLe32(fadt[0..4], acpi.signature("FACP"));
    putLe32(fadt[4..8], fadt.len);
    putLe16(fadt[46..48], 9);
    putLe32(fadt[76..80], 0x408);
    fadt[91] = 4;
    finishChecksum(&fadt);

    var tpm2 = [_]u8{0} ** 52;
    putLe32(tpm2[0..4], acpi.signature("TPM2"));
    putLe32(tpm2[4..8], tpm2.len);
    putLe16(tpm2[36..38], 1);
    putLe64(tpm2[40..48], 0xfed4_0000);
    putLe32(tpm2[48..52], 6);
    finishChecksum(&tpm2);

    test_memory = .{
        .rsdp = &rsdp,
        .xsdt = &xsdt,
        .madt = &madt,
        .mcfg = &mcfg,
        .hpet = &hpet,
        .fadt = &fadt,
        .tpm2 = &tpm2,
    };

    const efi_tables = [_]acpi.EfiConfigurationTable{.{
        .vendor_guid = acpi.acpi_20_table_guid,
        .vendor_table_address = 0x1000,
    }};
    const inventory = collectPreExitBootServices(&efi_tables, testReadMemory, testReadPciConfig32);
    try std.testing.expect(inventory.collected_before_exit_boot_services);
    try std.testing.expect(inventory.rsdp.found);
    try std.testing.expectEqual(@as(usize, 5), inventory.tables.table_count);
    try std.testing.expect(inventory.hasInterruptTopology());
    try std.testing.expect(inventory.hasPciEcam());
    try std.testing.expect(inventory.hpet != null);
    try std.testing.expect(inventory.fadt != null);
    try std.testing.expect(inventory.hasTpm2Crb());
    try std.testing.expect(inventory.pci.scanned);
    try std.testing.expectEqual(@as(usize, 1), inventory.pci.device_count);
    try std.testing.expectEqual(@as(u16, 0x8086), inventory.pci.devices[0].vendor_id);
    try std.testing.expectEqual(@as(u8, 0x02), inventory.pci.devices[0].class_code);
}
