const std = @import("er_std");

const jc3248_frame = @import("ui/jc3248_frame.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const ui = @import("ui/core.zig");

const max_commands: usize = 128;
const max_rects: usize = 256;
const max_text_vertices: usize = 2048;
const frame_path = ".build/app/jc3248_ui.rgb565";

const IrStorage = renderer_ir.FixedBuffers(max_rects, 0, max_text_vertices, 0, 0, 0, 0);

pub fn main() !void {
    const io: std.Io = .{};
    const alloc = std.heap.page_allocator;

    const frame = try alloc.alloc(u8, jc3248_frame.frame_bytes);
    defer alloc.free(frame);
    try renderFrame(frame);

    try std.Io.Dir.cwd().createDirPath(io, ".build/app");
    const file = try std.Io.Dir.cwd().createFile(io, frame_path, .{ .truncate = true });
    defer file.close(io);
    try file.writeStreamingAll(io, frame);
    std.debug.print("wrote {s} ({d} bytes)\n", .{ frame_path, frame.len });
}

pub fn renderFrame(frame: []u8) !void {
    var rgba: [jc3248_frame.width * jc3248_frame.height]ui.Color = undefined;
    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderScene(&scene);

    var storage = IrStorage{};
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    try renderer_pipeline.packScene(storage.buffers(), &font_atlas, scene.written());
    try jc3248_frame.renderPackedIr(frame, &rgba, storage.buffers(), renderer_pipeline.softwareResources(&font_atlas, null), .bg);
}

fn renderScene(scene: *ui.Scene) !void {
    const W: f32 = @floatFromInt(jc3248_frame.width);
    try scene.pushGradientRect(ui.Rect.init(0, 0, W, 480), .{ .r = 4, .g = 8, .b = 18 }, .{ .r = 13, .g = 22, .b = 34 }, 0);
    try scene.pushRect(ui.Rect.init(14, 14, 292, 70), .{ .r = 14, .g = 24, .b = 38 }, .fill, 16, 0);
    try scene.pushBoldText(ui.Rect.init(28, 24, 220, 24), "EdgeRun JC3248", .text);
    try scene.pushText(ui.Rect.init(28, 52, 240, 16), "Bluetooth display/controller", .muted);
    try scene.pushRect(ui.Rect.init(260, 34, 28, 28), .accent, .fill, 14, 0);

    try card(scene, 14, 104, "DISPLAY", "RGB565 frame", "ready", .accent);
    try card(scene, 14, 196, "CONTROL", "touch + BLE route", "armed", .{ .r = 110, .g = 231, .b = 183 });
    try card(scene, 14, 288, "LINK", "ERUI patches", "waiting", .{ .r = 250, .g = 204, .b = 21 });

    try scene.pushRect(ui.Rect.init(30, 404, 260, 42), .{ .r = 20, .g = 184, .b = 166 }, .fill, 18, 0);
    try scene.pushBoldText(ui.Rect.init(84, 416, 180, 18), "Pair controller", .{ .r = 2, .g = 6, .b = 23 });
}

fn card(scene: *ui.Scene, x: f32, y: f32, label: []const u8, title: []const u8, value: []const u8, accent: ui.Color) !void {
    try scene.pushRect(ui.Rect.init(x, y, 292, 72), .{ .r = 18, .g = 29, .b = 44 }, .fill, 14, 0);
    try scene.pushRect(ui.Rect.init(x + 14, y + 16, 5, 40), accent, .fill, 3, 0);
    try scene.pushText(ui.Rect.init(x + 30, y + 12, 120, 14), label, .muted);
    try scene.pushStrongText(ui.Rect.init(x + 30, y + 32, 170, 18), title, .text);
    try scene.pushText(ui.Rect.init(x + 212, y + 30, 64, 16), value, accent);
}

test "renders jc3248 ui frame into rgb565" {
    var frame: [jc3248_frame.frame_bytes]u8 = undefined;
    try renderFrame(&frame);
    try std.testing.expectEqual(@as(usize, jc3248_frame.frame_bytes), frame.len);
    try std.testing.expect(frame[0] != 0 or frame[1] != 0);
}
