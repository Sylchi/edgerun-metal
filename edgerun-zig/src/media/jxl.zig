const std = @import("std");
const common = @import("common.zig");

pub const codestream_signature = [_]u8{ 0xff, 0x0a };
pub const container_signature = [_]u8{ 0x00, 0x00, 0x00, 0x0c, 0x4a, 0x58, 0x4c, 0x20, 0x0d, 0x0a, 0x87, 0x0a };

pub const Kind = enum {
    codestream,
    container,
};

pub fn detectKind(bytes: []const u8) common.DecodeError!Kind {
    if (isJxlCodestream(bytes)) return .codestream;
    if (isJxlContainer(bytes)) return .container;
    return error.UnsupportedImage;
}

pub fn isJxl(bytes: []const u8) bool {
    return isJxlCodestream(bytes) or isJxlContainer(bytes);
}

pub fn isJxlCodestream(bytes: []const u8) bool {
    return bytes.len >= codestream_signature.len and std.mem.eql(u8, bytes[0..codestream_signature.len], &codestream_signature);
}

pub fn isJxlContainer(bytes: []const u8) bool {
    return bytes.len >= container_signature.len and std.mem.eql(u8, bytes[0..container_signature.len], &container_signature);
}

pub fn decodeHeader(bytes: []const u8) common.DecodeError!common.Header {
    _ = try detectKind(bytes);
    return error.UnsupportedImage;
}

test "jxl detects codestream signature" {
    const bytes = [_]u8{ 0xff, 0x0a, 0x00, 0x01 };
    try std.testing.expect(isJxl(&bytes));
    try std.testing.expectEqual(Kind.codestream, try detectKind(&bytes));
}

test "jxl detects container signature" {
    const bytes = container_signature ++ [_]u8{ 0x00, 0x00, 0x00, 0x00 };
    try std.testing.expect(isJxl(&bytes));
    try std.testing.expectEqual(Kind.container, try detectKind(&bytes));
}

test "jxl rejects unknown bytes" {
    try std.testing.expect(!isJxl("not-jxl"));
    try std.testing.expectError(error.UnsupportedImage, detectKind("not-jxl"));
}
