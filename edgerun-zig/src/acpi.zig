const std = @import("std");

pub const max_tables = 32;
pub const max_madt_lapics = 32;
pub const max_madt_ioapics = 8;
pub const max_madt_interrupt_source_overrides = 16;
pub const max_mcfg_allocations = 16;

pub const rsdp_v1_len = 20;
pub const rsdp_v2_min_len = 36;
pub const sdt_header_len = 36;

pub const TableKind = enum(u8) {
    none = 0,
    rsdt = 1,
    xsdt = 2,
};

pub const MadtEntryKind = enum(u8) {
    lapic = 0,
    ioapic = 1,
    interrupt_source_override = 2,
};

pub const madt_lapic_enabled: u32 = 0x0000_0001;
pub const madt_lapic_online_capable: u32 = 0x0000_0002;

pub const GenericAddress = struct {
    address_space_id: u8 = 0,
    register_bit_width: u8 = 0,
    register_bit_offset: u8 = 0,
    access_size: u8 = 0,
    address: u64 = 0,
};

pub const RsdpInfo = struct {
    found: bool = false,
    revision: u8 = 0,
    checksum_valid: bool = false,
    xsdt_checksum_valid: bool = false,
    rsdp_address: u64 = 0,
    rsdt_address: u32 = 0,
    xsdt_address: u64 = 0,
};

pub const TableInfo = struct {
    signature: u32 = 0,
    length: u32 = 0,
    revision: u8 = 0,
    checksum_valid: bool = false,
    address: u64 = 0,
};

pub const TableList = struct {
    found: bool = false,
    table_kind: TableKind = .none,
    table_count: usize = 0,
    tables: [max_tables]TableInfo = [_]TableInfo{.{}} ** max_tables,

    pub fn append(self: *TableList, table: TableInfo) bool {
        if (self.table_count >= self.tables.len) return false;
        self.tables[self.table_count] = table;
        self.table_count += 1;
        return true;
    }

    pub fn find(self: TableList, sig: u32) ?TableInfo {
        for (self.tables[0..self.table_count]) |table| {
            if (table.signature == sig) return table;
        }
        return null;
    }
};

pub const MadtLapic = struct {
    acpi_processor_id: u8 = 0,
    apic_id: u8 = 0,
    flags: u32 = 0,
};

pub const MadtIoapic = struct {
    ioapic_id: u8 = 0,
    address: u32 = 0,
    global_system_interrupt_base: u32 = 0,
};

pub const MadtInterruptSourceOverride = struct {
    bus: u8 = 0,
    source: u8 = 0,
    global_system_interrupt: u32 = 0,
    flags: u16 = 0,
};

pub const MadtInfo = struct {
    found: bool = false,
    checksum_valid: bool = false,
    lapic_address: u32 = 0,
    flags: u32 = 0,
    lapic_count: usize = 0,
    ioapic_count: usize = 0,
    interrupt_source_override_count: usize = 0,
    lapics: [max_madt_lapics]MadtLapic = [_]MadtLapic{.{}} ** max_madt_lapics,
    ioapics: [max_madt_ioapics]MadtIoapic = [_]MadtIoapic{.{}} ** max_madt_ioapics,
    interrupt_source_overrides: [max_madt_interrupt_source_overrides]MadtInterruptSourceOverride = [_]MadtInterruptSourceOverride{.{}} ** max_madt_interrupt_source_overrides,
};

pub const McfgAllocation = struct {
    base_address: u64 = 0,
    pci_segment_group: u16 = 0,
    start_bus: u8 = 0,
    end_bus: u8 = 0,
};

pub const McfgInfo = struct {
    found: bool = false,
    checksum_valid: bool = false,
    allocation_count: usize = 0,
    allocations: [max_mcfg_allocations]McfgAllocation = [_]McfgAllocation{.{}} ** max_mcfg_allocations,

    pub fn configAddress(self: McfgInfo, segment: u16, bus: u8, dev: u8, func: u8, offset: u16) ?u64 {
        if (!self.found or dev >= 32 or func >= 8 or offset >= 4096) return null;
        for (self.allocations[0..self.allocation_count]) |allocation| {
            if (allocation.pci_segment_group == segment and bus >= allocation.start_bus and bus <= allocation.end_bus) {
                return allocation.base_address +
                    (@as(u64, bus - allocation.start_bus) * 0x100000) +
                    (@as(u64, dev) * 0x8000) +
                    (@as(u64, func) * 0x1000) +
                    offset;
            }
        }
        return null;
    }
};

pub const HpetInfo = struct {
    found: bool = false,
    checksum_valid: bool = false,
    hardware_rev_id: u8 = 0,
    comparator_count: u8 = 0,
    counter_size_64: bool = false,
    pci_vendor_id: u16 = 0,
    address_space_id: u8 = 0,
    register_bit_width: u8 = 0,
    register_bit_offset: u8 = 0,
    address_size: u8 = 0,
    address: u64 = 0,
    hpet_number: u8 = 0,
    minimum_tick: u16 = 0,
    page_protection: u8 = 0,
};

pub const FadtInfo = struct {
    found: bool = false,
    checksum_valid: bool = false,
    sci_interrupt: u16 = 0,
    smi_command_port: u32 = 0,
    acpi_enable: u8 = 0,
    acpi_disable: u8 = 0,
    boot_architecture_flags: u16 = 0,
    flags: u32 = 0,
    pm1a_event_block: u32 = 0,
    pm1b_event_block: u32 = 0,
    pm1a_control_block: u32 = 0,
    pm1b_control_block: u32 = 0,
    pm_timer_block: u32 = 0,
    pm1_event_length: u8 = 0,
    pm1_control_length: u8 = 0,
    pm_timer_length: u8 = 0,
    reset_register: GenericAddress = .{},
    reset_value: u8 = 0,
};

pub const EfiGuid = extern struct {
    data1: u32,
    data2: u16,
    data3: u16,
    data4: [8]u8,

    pub fn eql(self: EfiGuid, other: EfiGuid) bool {
        return self.data1 == other.data1 and self.data2 == other.data2 and self.data3 == other.data3 and std.mem.eql(u8, &self.data4, &other.data4);
    }
};

pub const EfiConfigurationTable = struct {
    vendor_guid: EfiGuid,
    vendor_table_address: u64,
};

pub const acpi_10_table_guid = EfiGuid{
    .data1 = 0xeb9d2d30,
    .data2 = 0x2d88,
    .data3 = 0x11d3,
    .data4 = .{ 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d },
};

pub const acpi_20_table_guid = EfiGuid{
    .data1 = 0x8868e871,
    .data2 = 0xe4f1,
    .data3 = 0x11d3,
    .data4 = .{ 0xbc, 0x22, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 },
};

pub fn signature(s: []const u8) u32 {
    if (s.len < 4 or s[0] == 0 or s[1] == 0 or s[2] == 0 or s[3] == 0) return 0;
    return @as(u32, s[0]) | (@as(u32, s[1]) << 8) | (@as(u32, s[2]) << 16) | (@as(u32, s[3]) << 24);
}

pub fn checksumValid(value: []const u8) bool {
    if (value.len == 0) return false;
    var sum: u8 = 0;
    for (value) |byte| sum +%= byte;
    return sum == 0;
}

pub fn findRsdpInEfiTables(tables: []const EfiConfigurationTable, read: *const fn (address: u64, min_len: usize) ?[]const u8) ?RsdpInfo {
    var rsdp10: ?u64 = null;
    for (tables) |table| {
        if (table.vendor_guid.eql(acpi_20_table_guid)) {
            const bytes = read(table.vendor_table_address, rsdp_v2_min_len) orelse return null;
            return parseRsdpAt(table.vendor_table_address, bytes);
        }
        if (table.vendor_guid.eql(acpi_10_table_guid)) {
            rsdp10 = table.vendor_table_address;
        }
    }
    if (rsdp10) |address| {
        const bytes = read(address, rsdp_v1_len) orelse return null;
        return parseRsdpAt(address, bytes);
    }
    return null;
}

pub fn parseRsdpAt(address: u64, rsdp: []const u8) ?RsdpInfo {
    if (rsdp.len < rsdp_v1_len or getLe64(rsdp[0..8]) != 0x2052545020445352) return null;
    var out = RsdpInfo{
        .found = true,
        .revision = rsdp[15],
        .checksum_valid = checksumValid(rsdp[0..rsdp_v1_len]),
        .rsdp_address = address,
        .rsdt_address = getLe32(rsdp[16..20]),
    };
    if (out.revision >= 2 and rsdp.len >= rsdp_v2_min_len) {
        const len = getLe32(rsdp[20..24]);
        if (len >= rsdp_v2_min_len and len <= rsdp.len) {
            out.xsdt_address = getLe64(rsdp[24..32]);
            out.xsdt_checksum_valid = checksumValid(rsdp[0..len]);
        }
    }
    return out;
}

pub fn tableInfoAt(address: u64, table: []const u8) ?TableInfo {
    if (table.len < sdt_header_len) return null;
    const len = getLe32(table[4..8]);
    if (len < sdt_header_len or len > table.len) return null;
    return .{
        .signature = getLe32(table[0..4]),
        .length = len,
        .revision = table[8],
        .checksum_valid = checksumValid(table[0..len]),
        .address = address,
    };
}

pub fn enumerateTables(rsdp: RsdpInfo, read: *const fn (address: u64, min_len: usize) ?[]const u8) ?TableList {
    if (!rsdp.found or !rsdp.checksum_valid) return null;
    const use_xsdt = rsdp.xsdt_address != 0 and rsdp.xsdt_checksum_valid;
    const root_address = if (use_xsdt) rsdp.xsdt_address else @as(u64, rsdp.rsdt_address);
    const root = read(root_address, sdt_header_len) orelse return null;
    const root_info = tableInfoAt(root_address, root) orelse return null;
    if (!root_info.checksum_valid) return null;

    const entry_bytes: usize = if (use_xsdt) 8 else 4;
    const root_len: usize = root_info.length;
    if (root.len < root_len) return null;
    const entry_count = @min(max_tables, (root_len - sdt_header_len) / entry_bytes);
    var out = TableList{ .found = true, .table_kind = if (use_xsdt) .xsdt else .rsdt };

    var index: usize = 0;
    while (index < entry_count) : (index += 1) {
        const entry = root[sdt_header_len + index * entry_bytes ..];
        const table_address = if (use_xsdt) getLe64(entry[0..8]) else @as(u64, getLe32(entry[0..4]));
        const table = read(table_address, sdt_header_len) orelse continue;
        const info = tableInfoAt(table_address, table) orelse continue;
        _ = out.append(info);
    }
    return out;
}

pub fn parseMadt(table: []const u8) ?MadtInfo {
    const info = tableInfoAt(0, table) orelse return null;
    if (info.signature != signature("APIC") or info.length < 44) return null;
    var out = MadtInfo{
        .found = true,
        .checksum_valid = info.checksum_valid,
        .lapic_address = getLe32(table[36..40]),
        .flags = getLe32(table[40..44]),
    };
    var cursor: usize = 44;
    while (cursor + 2 <= info.length) {
        const entry_kind = table[cursor];
        const entry_len = table[cursor + 1];
        if (entry_len < 2 or cursor + entry_len > info.length) return null;
        const entry = table[cursor .. cursor + entry_len];
        switch (entry_kind) {
            @intFromEnum(MadtEntryKind.lapic) => if (entry_len >= 8 and out.lapic_count < out.lapics.len) {
                out.lapics[out.lapic_count] = .{
                    .acpi_processor_id = entry[2],
                    .apic_id = entry[3],
                    .flags = getLe32(entry[4..8]),
                };
                out.lapic_count += 1;
            },
            @intFromEnum(MadtEntryKind.ioapic) => if (entry_len >= 12 and out.ioapic_count < out.ioapics.len) {
                out.ioapics[out.ioapic_count] = .{
                    .ioapic_id = entry[2],
                    .address = getLe32(entry[4..8]),
                    .global_system_interrupt_base = getLe32(entry[8..12]),
                };
                out.ioapic_count += 1;
            },
            @intFromEnum(MadtEntryKind.interrupt_source_override) => if (entry_len >= 10 and out.interrupt_source_override_count < out.interrupt_source_overrides.len) {
                out.interrupt_source_overrides[out.interrupt_source_override_count] = .{
                    .bus = entry[2],
                    .source = entry[3],
                    .global_system_interrupt = getLe32(entry[4..8]),
                    .flags = getLe16(entry[8..10]),
                };
                out.interrupt_source_override_count += 1;
            },
            else => {},
        }
        cursor += entry_len;
    }
    return out;
}

pub fn parseMcfg(table: []const u8) ?McfgInfo {
    const info = tableInfoAt(0, table) orelse return null;
    if (info.signature != signature("MCFG") or info.length < 44) return null;
    var out = McfgInfo{ .found = true, .checksum_valid = info.checksum_valid };
    var cursor: usize = 44;
    while (cursor + 16 <= info.length and out.allocation_count < out.allocations.len) : (cursor += 16) {
        out.allocations[out.allocation_count] = .{
            .base_address = getLe64(table[cursor..][0..8]),
            .pci_segment_group = getLe16(table[cursor + 8 ..][0..2]),
            .start_bus = table[cursor + 10],
            .end_bus = table[cursor + 11],
        };
        out.allocation_count += 1;
    }
    return out;
}

pub fn parseHpet(table: []const u8) ?HpetInfo {
    const info = tableInfoAt(0, table) orelse return null;
    if (info.signature != signature("HPET") or info.length < 56) return null;
    const block_id = getLe32(table[36..40]);
    return .{
        .found = true,
        .checksum_valid = info.checksum_valid,
        .hardware_rev_id = @intCast(block_id & 0xff),
        .comparator_count = @intCast((block_id >> 8) & 0x1f),
        .counter_size_64 = ((block_id >> 13) & 1) != 0,
        .pci_vendor_id = @intCast((block_id >> 16) & 0xffff),
        .address_space_id = table[40],
        .register_bit_width = table[41],
        .register_bit_offset = table[42],
        .address_size = table[43],
        .address = getLe64(table[44..52]),
        .hpet_number = table[52],
        .minimum_tick = getLe16(table[53..55]),
        .page_protection = table[55],
    };
}

pub fn parseFadt(table: []const u8) ?FadtInfo {
    const info = tableInfoAt(0, table) orelse return null;
    if (info.signature != signature("FACP") or info.length < 116) return null;
    var out = FadtInfo{
        .found = true,
        .checksum_valid = info.checksum_valid,
        .sci_interrupt = getLe16(table[46..48]),
        .smi_command_port = getLe32(table[48..52]),
        .acpi_enable = table[52],
        .acpi_disable = table[53],
        .pm1a_event_block = getLe32(table[56..60]),
        .pm1b_event_block = getLe32(table[60..64]),
        .pm1a_control_block = getLe32(table[64..68]),
        .pm1b_control_block = getLe32(table[68..72]),
        .pm_timer_block = getLe32(table[76..80]),
        .pm1_event_length = table[88],
        .pm1_control_length = table[89],
        .pm_timer_length = table[91],
        .boot_architecture_flags = getLe16(table[109..111]),
        .flags = getLe32(table[112..116]),
    };
    if (info.length >= 129 and table.len >= 129) {
        out.reset_register = parseGenericAddress(table[116..128]);
        out.reset_value = table[128];
    }
    return out;
}

fn parseGenericAddress(value: []const u8) GenericAddress {
    return .{
        .address_space_id = value[0],
        .register_bit_width = value[1],
        .register_bit_offset = value[2],
        .access_size = value[3],
        .address = getLe64(value[4..12]),
    };
}

fn getLe16(value: []const u8) u16 {
    return @as(u16, value[0]) | (@as(u16, value[1]) << 8);
}

fn getLe32(value: []const u8) u32 {
    return @as(u32, value[0]) |
        (@as(u32, value[1]) << 8) |
        (@as(u32, value[2]) << 16) |
        (@as(u32, value[3]) << 24);
}

fn getLe64(value: []const u8) u64 {
    return @as(u64, getLe32(value[0..4])) | (@as(u64, getLe32(value[4..8])) << 32);
}

fn putLe16(out: []u8, value: u16) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
}

fn putLe32(out: []u8, value: u32) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
    out[2] = @intCast((value >> 16) & 0xff);
    out[3] = @intCast((value >> 24) & 0xff);
}

fn putLe64(out: []u8, value: u64) void {
    putLe32(out[0..4], @intCast(value & 0xffff_ffff));
    putLe32(out[4..8], @intCast(value >> 32));
}

fn finishChecksum(bytes: []u8) void {
    bytes[9] = 0;
    var sum: u8 = 0;
    for (bytes) |byte| sum +%= byte;
    bytes[9] = 0 -% sum;
}

test "parses ACPI signatures checksums and fixed tables" {
    try std.testing.expectEqual(@as(u32, 0x43495041), signature("APIC"));
    var madt = [_]u8{0} ** 64;
    putLe32(madt[0..4], signature("APIC"));
    putLe32(madt[4..8], 64);
    madt[8] = 1;
    putLe32(madt[36..40], 0xfee0_0000);
    putLe32(madt[40..44], 1);
    madt[44] = @intFromEnum(MadtEntryKind.lapic);
    madt[45] = 8;
    madt[46] = 7;
    madt[47] = 8;
    putLe32(madt[48..52], madt_lapic_enabled);
    madt[52] = @intFromEnum(MadtEntryKind.ioapic);
    madt[53] = 12;
    madt[54] = 2;
    putLe32(madt[56..60], 0xfec0_0000);
    putLe32(madt[60..64], 24);
    finishChecksum(&madt);

    const parsed_madt = parseMadt(&madt).?;
    try std.testing.expect(parsed_madt.checksum_valid);
    try std.testing.expectEqual(@as(u32, 0xfee0_0000), parsed_madt.lapic_address);
    try std.testing.expectEqual(@as(usize, 1), parsed_madt.lapic_count);
    try std.testing.expectEqual(@as(u8, 7), parsed_madt.lapics[0].acpi_processor_id);
    try std.testing.expectEqual(@as(usize, 1), parsed_madt.ioapic_count);
    try std.testing.expectEqual(@as(u32, 0xfec0_0000), parsed_madt.ioapics[0].address);

    var mcfg = [_]u8{0} ** 60;
    putLe32(mcfg[0..4], signature("MCFG"));
    putLe32(mcfg[4..8], 60);
    putLe64(mcfg[44..52], 0xe000_0000);
    putLe16(mcfg[52..54], 0);
    mcfg[54] = 0;
    mcfg[55] = 0xff;
    finishChecksum(&mcfg);
    const parsed_mcfg = parseMcfg(&mcfg).?;
    try std.testing.expectEqual(@as(usize, 1), parsed_mcfg.allocation_count);
    try std.testing.expectEqual(@as(u64, 0xe000_0000 + 2 * 0x8000 + 3 * 0x1000 + 0x40), parsed_mcfg.configAddress(0, 0, 2, 3, 0x40).?);
}

test "parses RSDP and EFI ACPI table selection" {
    var rsdp = [_]u8{0} ** rsdp_v2_min_len;
    @memcpy(rsdp[0..8], "RSD PTR ");
    rsdp[15] = 2;
    putLe32(rsdp[16..20], 0x1000);
    putLe32(rsdp[20..24], rsdp_v2_min_len);
    putLe64(rsdp[24..32], 0x2000);
    var sum20: u8 = 0;
    for (rsdp[0..rsdp_v1_len]) |byte| sum20 +%= byte;
    rsdp[8] = 0 -% sum20;
    var sum36: u8 = 0;
    for (rsdp[0..rsdp_v2_min_len]) |byte| sum36 +%= byte;
    rsdp[32] = 0 -% sum36;

    const parsed = parseRsdpAt(0x4000, &rsdp).?;
    try std.testing.expect(parsed.found);
    try std.testing.expect(parsed.checksum_valid);
    try std.testing.expect(parsed.xsdt_checksum_valid);
    try std.testing.expectEqual(@as(u64, 0x2000), parsed.xsdt_address);
}
