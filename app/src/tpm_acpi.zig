const std = @import("er_std");
const acpi = @import("acpi.zig");
const bytes_mod = @import("bytes.zig");
const tpm = @import("tpm.zig");

pub const Tpm2Info = struct {
    found: bool = false,
    checksum_valid: bool = false,
    platform_class: u16 = 0,
    control_area: u64 = 0,
    start_method: u32 = 0,

    pub fn asCommandInfo(self: Tpm2Info) tpm.Tpm2Info {
        return .{
            .found = self.found,
            .start_method = self.start_method,
        };
    }

    pub fn isCrb(self: Tpm2Info) bool {
        return self.found and (self.start_method == 6 or self.start_method == 7 or self.start_method == 8);
    }
};

pub fn parseTpm2Table(table: []const u8) ?Tpm2Info {
    const info = acpi.tableInfoAt(0, table) orelse return null;
    if (info.signature != acpi.signature("TPM2") or info.length < 52 or !info.checksum_valid) return null;
    return .{
        .found = true,
        .checksum_valid = true,
        .platform_class = getLe16(table[36..38]),
        .control_area = getLe64(table[40..48]),
        .start_method = getLe32(table[48..52]),
    };
}

pub fn findTpm2Table(tables: acpi.TableList, read: *const fn (address: u64, min_len: usize) ?[]const u8) ?Tpm2Info {
    const table_info = tables.find(acpi.signature("TPM2")) orelse return null;
    const table = read(table_info.address, 52) orelse return null;
    return parseTpm2Table(table);
}

fn getLe16(value: []const u8) u16 {
    return bytes_mod.load16(value) orelse 0;
}

fn getLe32(value: []const u8) u32 {
    return bytes_mod.load32(value) orelse 0;
}

fn getLe64(value: []const u8) u64 {
    return bytes_mod.load64(value) orelse 0;
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

test "parses TPM2 ACPI table into transport metadata" {
    var table = [_]u8{0} ** 52;
    putLe32(table[0..4], acpi.signature("TPM2"));
    putLe32(table[4..8], table.len);
    putLe16(table[36..38], 1);
    putLe64(table[40..48], 0xfed4_0000);
    putLe32(table[48..52], 6);
    finishChecksum(&table);

    const parsed = parseTpm2Table(&table).?;
    try std.testing.expect(parsed.found);
    try std.testing.expect(parsed.checksum_valid);
    try std.testing.expect(parsed.isCrb());
    try std.testing.expectEqual(@as(u16, 1), parsed.platform_class);
    try std.testing.expectEqual(@as(u64, 0xfed4_0000), parsed.control_area);
    try std.testing.expectEqual(@as(u32, 6), parsed.asCommandInfo().start_method);
}
