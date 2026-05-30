const std = @import("std");
const video = @import("media/video.zig");
const ui = @import("ui.zig");

const max_input_bytes: usize = 64 * 1024 * 1024;
const default_max_frames: usize = 16;
const output_name_len: usize = 64;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    if (args.len < 3 or args.len > 4) return error.InvalidArgument;

    const input_path = args[1];
    const output_dir = args[2];
    const max_frames = if (args.len == 4)
        try std.fmt.parseUnsigned(usize, args[3], 10)
    else
        default_max_frames;
    if (max_frames == 0) return error.InvalidArgument;

    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, allocator, .limited(max_input_bytes));
    defer allocator.free(bytes);

    var decoder = try video.Decoder.init(bytes);
    const header = decoder.header;
    const pixel_count = try std.math.mul(usize, header.width, header.height);
    const pixels = try allocator.alloc(ui.Color, pixel_count);
    defer allocator.free(pixels);

    const scratch_len = video.scratchByteLen(bytes, header.width, header.height);
    if (scratch_len == 0) return error.InvalidVideoScratch;
    const scratch = try allocator.alloc(u8, scratch_len);
    defer allocator.free(scratch);

    try std.Io.Dir.cwd().createDirPath(init.io, output_dir);
    var output = try std.Io.Dir.cwd().openDir(init.io, output_dir, .{});
    defer output.close(init.io);

    var decoded: usize = 0;
    while (decoded < max_frames) : (decoded += 1) {
        const frame = (try decoder.nextFrame(pixels, scratch)) orelse break;
        try writeFramePpm(init.io, output, frame.index, header.width, header.height, pixels);
    }
    if (decoded == 0) return error.NoFramesDecoded;
}

fn writeFramePpm(io: std.Io, output: anytype, frame_index: usize, width: usize, height: usize, pixels: []const ui.Color) !void {
    var name_buffer: [output_name_len]u8 = undefined;
    const name = try std.fmt.bufPrint(&name_buffer, "frame_{d:0>4}.ppm", .{frame_index});
    const file = try output.createFile(io, name, .{ .truncate = true });
    defer file.close(io);

    var header: [64]u8 = undefined;
    const header_bytes = try std.fmt.bufPrint(&header, "P6\n{d} {d}\n255\n", .{ width, height });
    try file.writeStreamingAll(io, header_bytes);
    for (pixels[0 .. width * height]) |pixel| {
        try file.writeStreamingAll(io, &.{ pixel.r, pixel.g, pixel.b });
    }
}

test "ppm frame writer emits deterministic header and rgb bytes" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3, .a = 255 },
        .{ .r = 4, .g = 5, .b = 6, .a = 255 },
    };
    try writeFramePpm(std.testing.io, tmp.dir, 7, 2, 1, &pixels);

    const bytes = try tmp.dir.readFileAlloc(std.testing.io, "frame_0007.ppm", std.testing.allocator, .limited(64));
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("P6\n2 1\n255\n", bytes[0..11]);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6 }, bytes[11..]);
}
