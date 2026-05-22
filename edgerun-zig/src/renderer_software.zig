const std = @import("std");
const ui = @import("ui.zig");
const varfont = @import("varfont.zig");

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

    pub fn rasterize(self: Surface, commands: []const ui.Command, font: *varfont.Cache) varfont.Error!void {
        try self.rasterizeScaled(commands, font, default_raster_scale);
    }

    pub fn rasterizeScaled(self: Surface, commands: []const ui.Command, font: *varfont.Cache, scale: f32) varfont.Error!void {
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
            .text => |text| try font.drawText(self, scaleRect(text.origin, scale), text.value, text.color, varfont.default_px_size * scale),
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
};

const default_raster_scale: f32 = 1.0;
const min_border_width: f32 = 1.0;

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
    const font = try varfont.Face.geist();
    var glyph_bitmap: [128 * 1024]u8 = undefined;
    var font_cache = varfont.Cache.init(font, &glyph_bitmap);
    surface.clear(.clear);
    try surface.rasterize(scene.written(), &font_cache);

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
