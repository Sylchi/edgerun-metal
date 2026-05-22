const std = @import("std");
const acpi = @import("acpi.zig");
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
