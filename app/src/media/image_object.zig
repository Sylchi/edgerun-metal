const std = @import("std");
const clock = @import("../clock.zig");
const object = @import("../object.zig");
const runtime_image = @import("runtime_image.zig");

pub const max_inline_runtime_image_bytes: usize = 64 * 1024 * 1024;

pub const Error = object.Error || error{
    BadImage,
};

pub fn runtimeImageRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };
}

pub fn canonicalObjectLen(runtime_image_bytes: []const u8) Error!usize {
    _ = runtime_image.decode(runtime_image_bytes) catch return error.BadImage;
    if (runtime_image_bytes.len > max_inline_runtime_image_bytes) return error.BadImage;
    return try object.canonicalSize(.bytes, runtime_image_bytes.len, 0, 0, 0);
}

pub fn writeRuntimeImageObject(runtime_image_bytes: []const u8, epoch: clock.Stamp, out: []u8) Error![]u8 {
    _ = runtime_image.decode(runtime_image_bytes) catch return error.BadImage;
    if (runtime_image_bytes.len > max_inline_runtime_image_bytes) return error.BadImage;
    return try (object.NodeWriter{ .out = out }).bytesNode(runtimeImageRequirements(), epoch, runtime_image_bytes);
}

pub fn decodeRuntimeImageObject(canonical_object: []const u8) Error!runtime_image.View {
    const view = try object.View.decode(canonical_object);
    if (view.header.kind != .bytes) return error.BadImage;
    if (view.header.requirements.durability != .durable or
        view.header.requirements.confidentiality != .public or
        view.header.requirements.portability != .public_portable or
        view.header.requirements.integrity != .hash_only or
        view.header.requirements.lifetime != .retained or
        view.header.requirements.visibility != .public or
        view.header.requirements.access != .explicit_io)
    {
        return error.BadImage;
    }
    return runtime_image.decode(view.body) catch return error.BadImage;
}

fn testEpoch() clock.Stamp {
    return .{
        .keeper = .{ .bytes = [_]u8{
            0x65, 0x72, 0x69, 0x6d, 0x67, 0x3a, 0x74, 0x65,
            0x73, 0x74, 0x3a, 0x63, 0x6c, 0x6f, 0x63, 0x6b,
            0x3a, 0x6b, 0x65, 0x65, 0x70, 0x65, 0x72, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        } },
        .tick = 1,
        .slot = 1,
        .epoch = 1,
        .era = 1,
    };
}

test "runtime image object wraps canonical ERIMG bytes" {
    const ui = @import("../ui.zig");
    const pixels = [_]ui.Color{.{ .r = 1, .g = 2, .b = 3, .a = 255 }};
    var erimg_raw: [runtime_image.header_size + @sizeOf(ui.Color)]u8 = undefined;
    const erimg = try runtime_image.encodeRgba(1, 1, &pixels, &erimg_raw);
    var object_raw: [object.header_size + erimg_raw.len]u8 = undefined;
    const canonical = try writeRuntimeImageObject(erimg, testEpoch(), &object_raw);
    const decoded = try decodeRuntimeImageObject(canonical);
    try std.testing.expectEqual(@as(usize, 1), decoded.header.width);
    try std.testing.expectEqual(@as(usize, 1), decoded.header.height);
}

test "runtime image object rejects raw non-ERIMG bytes" {
    var out: [object.header_size + 8]u8 = undefined;
    try std.testing.expectError(error.BadImage, writeRuntimeImageObject("not-erimg", testEpoch(), &out));
}
