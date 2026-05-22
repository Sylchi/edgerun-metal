const std = @import("std");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");

pub const Error = error{
    InvalidTarget,
    InvalidSurface,
    DamageBudgetExceeded,
};

pub const PixelFormat = enum(u8) {
    xrgb8888,
    argb8888,
};

pub const PixelRect = struct {
    x0: u32,
    y0: u32,
    x1: u32,
    y1: u32,

    pub fn valid(self: PixelRect) bool {
        return self.x1 > self.x0 and self.y1 > self.y0;
    }
};

pub const SampleRect = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,

    pub fn full(buffer: SurfaceBuffer) SampleRect {
        return .{ .x = 0, .y = 0, .width = buffer.width, .height = buffer.height };
    }

    pub fn validFor(self: SampleRect, buffer: SurfaceBuffer) bool {
        const right = @as(u64, self.x) + @as(u64, self.width);
        const bottom = @as(u64, self.y) + @as(u64, self.height);
        return self.width != 0 and
            self.height != 0 and
            right <= buffer.width and
            bottom <= buffer.height;
    }
};

pub const SurfaceBuffer = struct {
    pixels: []const ui.Color,
    width: u32,
    height: u32,
    stride: u32,
    format: PixelFormat = .argb8888,

    pub fn valid(self: SurfaceBuffer) bool {
        if (self.width == 0 or self.height == 0 or self.stride < self.width) return false;
        const last_row = @as(u64, self.height - 1) * @as(u64, self.stride);
        const required = last_row + @as(u64, self.width);
        return required <= self.pixels.len;
    }
};

pub const Surface = struct {
    id: u32,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    opacity: u8 = max_alpha,
    is_opaque: bool = false,
    buffer: SurfaceBuffer,
    sample: SampleRect,

    pub fn valid(self: Surface) bool {
        return self.id != 0 and
            self.width != 0 and
            self.height != 0 and
            self.width <= max_i32 and
            self.height <= max_i32 and
            self.opacity != 0 and
            self.buffer.valid() and
            self.sample.validFor(self.buffer);
    }
};

pub const Receipt = struct {
    surface_count: usize,
    ui_command_count: usize,
    damage_count: usize,
    pixels_written: u64,

    pub fn valid(self: Receipt) bool {
        return self.damage_count != 0 and (self.surface_count != 0 or self.ui_command_count != 0);
    }
};

const DamageList = struct {
    rects: []PixelRect,
    count: usize = 0,

    fn reset(self: *DamageList) void {
        self.count = 0;
    }

    fn append(self: *DamageList, rect: PixelRect) Error!void {
        if (!rect.valid()) return;
        if (self.count >= self.rects.len) return error.DamageBudgetExceeded;
        self.rects[self.count] = rect;
        self.count += 1;
    }

    fn written(self: DamageList) []const PixelRect {
        return self.rects[0..self.count];
    }
};

pub const Compositor = struct {
    target: renderer_software.Surface,
    damage: DamageList,

    pub fn init(target: renderer_software.Surface, damage_rects: []PixelRect) Error!Compositor {
        if (target.width == 0 or target.height == 0 or target.pixels.len < target.width * target.height) return error.InvalidTarget;
        return .{
            .target = target,
            .damage = .{ .rects = damage_rects },
        };
    }

    pub fn compose(self: *Compositor, surfaces: []const Surface, scene: ui.Scene, background: ui.Color) Error!Receipt {
        self.target.clear(background);
        self.damage.reset();

        var pixels_written: u64 = 0;
        for (surfaces) |surface| {
            pixels_written += try self.compositeSurface(surface);
        }

        for (scene.written()) |command| {
            try self.markCommandDamage(command);
        }
        self.target.rasterize(scene.written());

        return .{
            .surface_count = surfaces.len,
            .ui_command_count = scene.written().len,
            .damage_count = self.damage.written().len,
            .pixels_written = pixels_written,
        };
    }

    pub fn damageRects(self: Compositor) []const PixelRect {
        return self.damage.written();
    }

    fn compositeSurface(self: *Compositor, surface: Surface) Error!u64 {
        if (!surface.valid()) return error.InvalidSurface;
        const clipped = clipSurface(surface, self.target) orelse return 0;
        try self.damage.append(clipped);

        var written: u64 = 0;
        var y = clipped.y0;
        while (y < clipped.y1) : (y += 1) {
            const local_y: u32 = @intCast(@as(i64, y) - @as(i64, surface.y));
            const sy = surface.sample.y + scaledCoord(local_y, surface.height, surface.sample.height);
            var x = clipped.x0;
            while (x < clipped.x1) : (x += 1) {
                const local_x: u32 = @intCast(@as(i64, x) - @as(i64, surface.x));
                const sx = surface.sample.x + scaledCoord(local_x, surface.width, surface.sample.width);
                self.writeSample(surface, sx, sy, x, y);
                written += 1;
            }
        }
        return written;
    }

    fn writeSample(self: *Compositor, surface: Surface, sx: u32, sy: u32, dx: u32, dy: u32) void {
        const source_index = @as(usize, sy) * @as(usize, surface.buffer.stride) + sx;
        const source = surface.buffer.pixels[source_index];
        const alpha = sourceAlpha(source, surface.buffer.format, surface.opacity);
        const target_index = @as(usize, dy) * self.target.width + dx;
        if (surface.is_opaque and alpha == max_alpha) {
            self.target.pixels[target_index] = .{ .r = source.r, .g = source.g, .b = source.b, .a = max_alpha };
            return;
        }
        var color = source;
        color.a = max_alpha;
        self.target.blendPixel(@intCast(dx), @intCast(dy), color, alpha);
    }

    fn markCommandDamage(self: *Compositor, command: ui.Command) Error!void {
        switch (command) {
            .rect => |rect| try self.markRect(rect.bounds),
            .border => |border| try self.markRect(border.bounds),
            .text => |text| try self.markRect(text.origin),
            .icon_quad => |quad| try self.markRect(quad.bounds),
            .text_quad => |quad| try self.markRect(quad.bounds),
            .hit, .drag_source, .drop_target, .transition => {},
        }
    }

    fn markRect(self: *Compositor, rect: ui.Rect) Error!void {
        const clipped = clipRect(rect, self.target) orelse return;
        try self.damage.append(clipped);
    }
};

fn clipSurface(surface: Surface, target: renderer_software.Surface) ?PixelRect {
    const x1 = @as(i64, surface.x) + @as(i64, surface.width);
    const y1 = @as(i64, surface.y) + @as(i64, surface.height);
    return clipEdges(
        @as(i64, surface.x),
        @as(i64, surface.y),
        x1,
        y1,
        target.width,
        target.height,
    );
}

fn clipRect(rect: ui.Rect, target: renderer_software.Surface) ?PixelRect {
    if (!rect.valid()) return null;
    return clipEdges(
        @intFromFloat(@floor(rect.x)),
        @intFromFloat(@floor(rect.y)),
        @intFromFloat(@ceil(rect.x + rect.w)),
        @intFromFloat(@ceil(rect.y + rect.h)),
        target.width,
        target.height,
    );
}

fn clipEdges(x0: i64, y0: i64, x1: i64, y1: i64, width: usize, height: usize) ?PixelRect {
    const right: i64 = @intCast(width);
    const bottom: i64 = @intCast(height);
    const clipped = PixelRect{
        .x0 = @intCast(std.math.clamp(x0, 0, right)),
        .y0 = @intCast(std.math.clamp(y0, 0, bottom)),
        .x1 = @intCast(std.math.clamp(x1, 0, right)),
        .y1 = @intCast(std.math.clamp(y1, 0, bottom)),
    };
    return if (clipped.valid()) clipped else null;
}

fn scaledCoord(local: u32, destination_extent: u32, sample_extent: u32) u32 {
    return @intCast((@as(u64, local) * @as(u64, sample_extent)) / @as(u64, destination_extent));
}

fn sourceAlpha(source: ui.Color, format: PixelFormat, opacity: u8) u8 {
    const alpha = switch (format) {
        .xrgb8888 => max_alpha,
        .argb8888 => source.a,
    };
    return @intCast((@as(u16, alpha) * @as(u16, opacity)) / max_alpha);
}

const max_alpha: u8 = 255;
const max_i32: u32 = @intCast(std.math.maxInt(i32));

test "compositor composites app surface pixels into the target" {
    const red = ui.Color{ .r = 255, .g = 0, .b = 0 };
    const green = ui.Color{ .r = 0, .g = 255, .b = 0 };
    const blue = ui.Color{ .r = 0, .g = 0, .b = 255 };
    const source_pixels = [_]ui.Color{ red, green, blue, .clear };
    const buffer = SurfaceBuffer{ .pixels = &source_pixels, .width = 2, .height = 2, .stride = 2 };
    const app_surface = Surface{
        .id = 1,
        .x = 1,
        .y = 1,
        .width = 2,
        .height = 2,
        .is_opaque = false,
        .buffer = buffer,
        .sample = SampleRect.full(buffer),
    };

    var pixels: [4 * 4]ui.Color = undefined;
    const target = try renderer_software.Surface.init(4, 4, &pixels);
    var damage: [4]PixelRect = undefined;
    var compositor = try Compositor.init(target, &damage);
    var commands: [1]ui.Command = undefined;
    const scene = ui.Scene.init(&commands);

    const receipt = try compositor.compose(&.{app_surface}, scene, .clear);
    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(@as(u64, 4), receipt.pixels_written);
    try std.testing.expectEqual(red, pixels[1 * 4 + 1]);
    try std.testing.expectEqual(green, pixels[1 * 4 + 2]);
    try std.testing.expectEqual(blue, pixels[2 * 4 + 1]);
    try std.testing.expectEqual(ui.Color.clear, pixels[2 * 4 + 2]);
}

test "compositor renders ui scene above app surfaces" {
    const blue = ui.Color{ .r = 0, .g = 0, .b = 255 };
    const red = ui.Color{ .r = 255, .g = 0, .b = 0 };
    const source_pixels = [_]ui.Color{ blue, blue, blue, blue };
    const buffer = SurfaceBuffer{ .pixels = &source_pixels, .width = 2, .height = 2, .stride = 2, .format = .xrgb8888 };
    const app_surface = Surface{
        .id = 7,
        .x = 0,
        .y = 0,
        .width = 4,
        .height = 4,
        .is_opaque = true,
        .buffer = buffer,
        .sample = SampleRect.full(buffer),
    };

    var pixels: [4 * 4]ui.Color = undefined;
    const target = try renderer_software.Surface.init(4, 4, &pixels);
    var damage: [4]PixelRect = undefined;
    var compositor = try Compositor.init(target, &damage);
    var commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(.{ .x = 1, .y = 1, .w = 2, .h = 2 }, red, .fill, 0.0, 0.0);

    const receipt = try compositor.compose(&.{app_surface}, scene, .clear);
    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(blue, pixels[0]);
    try std.testing.expectEqual(red, pixels[1 * 4 + 1]);
    try std.testing.expectEqual(@as(usize, 2), compositor.damageRects().len);
}
