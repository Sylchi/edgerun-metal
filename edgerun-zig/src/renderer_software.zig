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
            .rect => |rect| self.drawRect(rect, scale),
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

    fn drawRect(self: Surface, rect: anytype, scale: f32) void {
        const bounds = scaleRect(rect.bounds, scale);
        const radius = rect.radius * scale;
        const shadow_spread = rect.shadow * scale;
        switch (rect.mode) {
            .fill => self.fillRounded(bounds, rect.color, rect.color, radius),
            .linear_gradient => self.fillRounded(bounds, rect.color, rect.color2, radius),
            .shadow => self.shadow(bounds, rect.color, radius, shadow_spread),
            .border => self.strokeRounded(bounds, rect.color, radius, @max(min_border_width, scale)),
        }
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

    fn fillRounded(self: Surface, bounds: ui.Rect, top_color: ui.Color, bottom_color: ui.Color, radius: f32) void {
        const x0 = clampCoord(@intFromFloat(@floor(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(@floor(bounds.y)), self.height);
        const x1 = clampCoord(@intFromFloat(@ceil(bounds.x + bounds.w)), self.width);
        const y1 = clampCoord(@intFromFloat(@ceil(bounds.y + bounds.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            const py = @as(f32, @floatFromInt(y)) + pixel_center;
            const mix_value = gradientMix(bounds, py);
            const color = mixColor(top_color, bottom_color, mix_value);
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const alpha = roundedAlpha(bounds, radius, px, py);
                if (alpha == max_alpha) {
                    self.pixels[y * self.width + x] = color;
                } else if (alpha != 0) {
                    self.blendPixel(x, y, color, alpha);
                }
            }
        }
    }

    fn strokeRounded(self: Surface, bounds: ui.Rect, color: ui.Color, radius: f32, width: f32) void {
        const outer = bounds;
        const inner = bounds.insetUniform(width);
        const x0 = clampCoord(@intFromFloat(@floor(outer.x)), self.width);
        const y0 = clampCoord(@intFromFloat(@floor(outer.y)), self.height);
        const x1 = clampCoord(@intFromFloat(@ceil(outer.x + outer.w)), self.width);
        const y1 = clampCoord(@intFromFloat(@ceil(outer.y + outer.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            const py = @as(f32, @floatFromInt(y)) + pixel_center;
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const outer_alpha = roundedAlpha(outer, radius, px, py);
                const inner_alpha = if (inner.valid()) roundedAlpha(inner, @max(0.0, radius - width), px, py) else 0;
                const alpha = outer_alpha -| inner_alpha;
                if (alpha != 0) self.blendPixel(x, y, color, alpha);
            }
        }
    }

    fn shadow(self: Surface, bounds: ui.Rect, color: ui.Color, radius: f32, spread: f32) void {
        if (spread <= 0.0) return;
        var step: usize = shadow_steps;
        while (step > 0) : (step -= 1) {
            const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(shadow_steps));
            const grow = spread * t;
            var layer_color = color;
            layer_color.a = scaleByte(color.a, shadow_layer_alpha * (1.0 - t * shadow_fade));
            self.fillRounded(bounds.insetUniform(-grow), layer_color, layer_color, radius + grow);
        }
    }

    fn textPlaceholder(self: Surface, bounds: ui.Rect, value: []const u8, color: ui.Color) void {
        if (value.len == 0) return;
        const bar_height = @max(min_text_placeholder_height, bounds.h * text_placeholder_height_ratio);
        const max_width = bounds.w;
        const width = @min(max_width, @max(min_text_placeholder_width, @as(f32, @floatFromInt(value.len)) * text_placeholder_glyph_width));
        const y = bounds.y + @max(0.0, (bounds.h - bar_height) * 0.5);
        self.fillRounded(.{ .x = bounds.x, .y = y, .w = width, .h = bar_height }, color, color, bar_height * text_placeholder_radius_ratio);
    }
};

const default_raster_scale: f32 = 1.0;
const max_alpha: u8 = 255;
const pixel_center: f32 = 0.5;
const min_border_width: f32 = 1.0;
const min_text_placeholder_width: f32 = 4.0;
const min_text_placeholder_height: f32 = 2.0;
const text_placeholder_height_ratio: f32 = 0.18;
const text_placeholder_glyph_width: f32 = 7.0;
const text_placeholder_radius_ratio: f32 = 0.5;
const shadow_steps: usize = 4;
const shadow_layer_alpha: f32 = 0.24;
const shadow_fade: f32 = 0.82;

fn roundedAlpha(bounds: ui.Rect, radius: f32, x: f32, y: f32) u8 {
    const max_radius = @max(0.0, @min(bounds.w, bounds.h) * 0.5);
    const r = @min(@max(radius, 0.0), max_radius);
    if (r <= 0.0) return max_alpha;
    const left = bounds.x + r;
    const right = bounds.x + bounds.w - r;
    const top = bounds.y + r;
    const bottom = bounds.y + bounds.h - r;
    const cx = clampRange(x, left, right);
    const cy = clampRange(y, top, bottom);
    const dx = x - cx;
    const dy = y - cy;
    const distance = @sqrt(dx * dx + dy * dy);
    if (distance <= r - antialias_width) return max_alpha;
    if (distance >= r) return 0;
    const coverage = (r - distance) / antialias_width;
    return @intFromFloat(@round(std.math.clamp(coverage, 0.0, 1.0) * 255.0));
}

fn clampRange(value: f32, lower: f32, upper: f32) f32 {
    if (lower > upper) return (lower + upper) * 0.5;
    return std.math.clamp(value, lower, upper);
}

fn gradientMix(bounds: ui.Rect, y: f32) f32 {
    if (bounds.h <= 0.0) return 0.0;
    return std.math.clamp((y - bounds.y) / bounds.h, 0.0, 1.0);
}

fn mixColor(a: ui.Color, b: ui.Color, t: f32) ui.Color {
    const clamped = std.math.clamp(t, 0.0, 1.0);
    return .{
        .r = mixByte(a.r, b.r, clamped),
        .g = mixByte(a.g, b.g, clamped),
        .b = mixByte(a.b, b.b, clamped),
        .a = mixByte(a.a, b.a, clamped),
    };
}

fn mixByte(a: u8, b: u8, t: f32) u8 {
    const af: f32 = @floatFromInt(a);
    const bf: f32 = @floatFromInt(b);
    return @intFromFloat(@round(af + (bf - af) * t));
}

fn scaleByte(value: u8, factor: f32) u8 {
    return @intFromFloat(@round(std.math.clamp(@as(f32, @floatFromInt(value)) * factor, 0.0, 255.0)));
}

const antialias_width: f32 = 1.0;

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

test "software renderer honors rounded gradient and shadow rect modes" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushGradientRect(ui.Rect.init(8.0, 8.0, 24.0, 24.0), .{ .r = 240, .g = 40, .b = 40 }, .{ .r = 40, .g = 40, .b = 240 }, 8.0);
    try scene.pushRect(ui.Rect.init(42.0, 18.0, 12.0, 12.0), .{ .r = 0, .g = 0, .b = 0, .a = 120 }, .shadow, 4.0, 5.0);

    var pixels: [64 * 48]ui.Color = undefined;
    const surface = try Surface.init(64, 48, &pixels);
    surface.clear(.clear);
    surface.rasterize(scene.written());

    try std.testing.expectEqual(ui.Color.clear, pixels[8 * 64 + 8]);
    const top = pixels[12 * 64 + 20];
    const bottom = pixels[28 * 64 + 20];
    try std.testing.expect(top.r > top.b);
    try std.testing.expect(bottom.b > bottom.r);
    try std.testing.expect(pixels[18 * 64 + 39].a > 0);
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
