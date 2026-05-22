const std = @import("std");
const ui = @import("ui.zig");

pub const Surface = struct {
    width: usize,
    height: usize,
    pixels: []ui.Color,

    pub fn init(width: usize, height: usize, pixels: []ui.Color) !Surface {
        if (pixels.len < width * height) return error.PixelBudgetExceeded;
        return .{ .width = width, .height = height, .pixels = pixels[0 .. width * height] };
    }

    pub fn clear(self: Surface, color: ui.Color) void {
        @memset(self.pixels, color);
    }

    pub fn rasterize(self: Surface, commands: []const ui.Command) void {
        for (commands) |command| switch (command) {
            .rect => |rect| self.fill(rect.bounds, rect.color),
            .border => |border| {
                self.fill(.{ .x = border.bounds.x, .y = border.bounds.y, .w = border.bounds.w, .h = 1 }, border.color);
                self.fill(.{ .x = border.bounds.x, .y = border.bounds.y + border.bounds.h - 1, .w = border.bounds.w, .h = 1 }, border.color);
                self.fill(.{ .x = border.bounds.x, .y = border.bounds.y, .w = 1, .h = border.bounds.h }, border.color);
                self.fill(.{ .x = border.bounds.x + border.bounds.w - 1, .y = border.bounds.y, .w = 1, .h = border.bounds.h }, border.color);
            },
            .text => |text| self.rasterText(text.origin, text.value, text.color),
            .hit, .drag_source, .drop_target, .icon_quad, .text_quad, .transition => {},
        };
    }

    fn fill(self: Surface, bounds: ui.Rect, color: ui.Color) void {
        const x0 = clampCoord(@intFromFloat(@floor(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(@floor(bounds.y)), self.height);
        const x1 = clampCoord(@intFromFloat(@ceil(bounds.x + bounds.w)), self.width);
        const y1 = clampCoord(@intFromFloat(@ceil(bounds.y + bounds.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) self.pixels[y * self.width + x] = color;
        }
    }

    fn rasterText(self: Surface, bounds: ui.Rect, value: []const u8, color: ui.Color) void {
        const glyph_w: f32 = 5;
        const glyph_h: f32 = 7;
        for (value, 0..) |byte, index| {
            if (byte == ' ') continue;
            const x = bounds.x + @as(f32, @floatFromInt(index)) * 7;
            if (x + glyph_w > bounds.x + bounds.w) break;
            self.fill(.{ .x = x, .y = bounds.y + 4, .w = glyph_w, .h = glyph_h }, color);
        }
    }
};

fn clampCoord(value: isize, limit: usize) usize {
    if (value <= 0) return 0;
    const as_usize: usize = @intCast(value);
    return @min(as_usize, limit);
}

test "software renderer rasterizes ui commands to nonblank pixels" {
    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, .{});

    var pixels: [320 * 240]ui.Color = undefined;
    const surface = try Surface.init(320, 240, &pixels);
    surface.clear(.clear);
    surface.rasterize(scene.written());

    var painted: usize = 0;
    for (surface.pixels) |pixel| {
        if (pixel.a != 0) painted += 1;
    }
    try std.testing.expect(painted > 0);
}

fn sampleRoot(children: []ui.Node) ui.Node {
    std.debug.assert(children.len >= 5);
    children[0] = .{ .text = .{ .value = "edgerun ui", .color = .accent } };
    children[1] = .{ .input = .{ .id = 10, .placeholder = "search objects" } };
    children[2] = .{ .row_item = .{ .id = 20, .title = "object graph", .detail = "canonical data in, scene commands out" } };
    children[3] = .{ .slot = .{ .id = 7, .child = &children[4] } };
    children[4] = .{ .button = .{ .id = 30, .label = "Render" } };
    return .{ .stack = .{ .axis = .column, .gap = 10, .padding = 16, .children = children[0..4] } };
}
