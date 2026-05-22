const std = @import("std");
const ui = @import("ui.zig");

pub const Error = error{
    PixelBudgetExceeded,
};

pub const Surface = struct {
    width: usize,
    height: usize,
    pixels: []ui.Color,

    pub fn init(width: usize, height: usize, pixels: []ui.Color) Error!Surface {
        if (pixels.len < width * height) return error.PixelBudgetExceeded;
        return .{ .width = width, .height = height, .pixels = pixels[0 .. width * height] };
    }

    pub fn clear(self: Surface, color: ui.Color) void {
        @memset(self.pixels, color);
    }

    pub fn rasterize(self: Surface, commands: []const ui.Command) void {
        self.rasterizeScaled(commands, default_raster_scale);
    }

    pub fn rasterizeScaled(self: Surface, commands: []const ui.Command, scale: f32) void {
        for (commands) |command| switch (command) {
            .rect => |rect| self.fill(scaleRect(rect.bounds, scale), rect.color),
            .border => |border| {
                const bounds = scaleRect(border.bounds, scale);
                const border_width = @max(min_border_width, scale);
                self.fill(.{ .x = bounds.x, .y = bounds.y, .w = bounds.w, .h = border_width }, border.color);
                self.fill(.{ .x = bounds.x, .y = bounds.y + bounds.h - border_width, .w = bounds.w, .h = border_width }, border.color);
                self.fill(.{ .x = bounds.x, .y = bounds.y, .w = border_width, .h = bounds.h }, border.color);
                self.fill(.{ .x = bounds.x + bounds.w - border_width, .y = bounds.y, .w = border_width, .h = bounds.h }, border.color);
            },
            .text => |text| self.textPlaceholder(scaleRect(text.origin, scale), text.value, text.color),
            .hit, .drag_source, .drop_target, .icon_quad, .text_quad, .transition => {},
        };
    }

    pub fn blendPixel(self: Surface, x: usize, y: usize, color: ui.Color, alpha: u8) void {
        const index = y * self.width + x;
        const dst = self.pixels[index];
        const a: u16 = alpha;
        const inv: u16 = 255 - a;
        self.pixels[index] = .{
            .r = @intCast((@as(u16, color.r) * a + @as(u16, dst.r) * inv) / 255),
            .g = @intCast((@as(u16, color.g) * a + @as(u16, dst.g) * inv) / 255),
            .b = @intCast((@as(u16, color.b) * a + @as(u16, dst.b) * inv) / 255),
            .a = @intCast(@min(@as(u16, 255), @as(u16, dst.a) + (@as(u16, color.a) * a) / 255)),
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

    fn textPlaceholder(self: Surface, bounds: ui.Rect, value: []const u8, color: ui.Color) void {
        if (value.len == 0) return;
        const bar_height = @max(min_text_placeholder_height, bounds.h * text_placeholder_height_ratio);
        const max_width = bounds.w;
        const width = @min(max_width, @max(min_text_placeholder_width, @as(f32, @floatFromInt(value.len)) * text_placeholder_glyph_width));
        const y = bounds.y + @max(0.0, (bounds.h - bar_height) * 0.5);
        self.fill(.{ .x = bounds.x, .y = y, .w = width, .h = bar_height }, color);
    }
};

const default_raster_scale: f32 = 1.0;
const min_border_width: f32 = 1.0;
const min_text_placeholder_width: f32 = 4.0;
const min_text_placeholder_height: f32 = 2.0;
const text_placeholder_height_ratio: f32 = 0.18;
const text_placeholder_glyph_width: f32 = 7.0;

fn scaleRect(bounds: ui.Rect, scale: f32) ui.Rect {
    return .{
        .x = bounds.x * scale,
        .y = bounds.y * scale,
        .w = bounds.w * scale,
        .h = bounds.h * scale,
    };
}

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
