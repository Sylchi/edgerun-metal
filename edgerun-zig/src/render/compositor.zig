const std = @import("std");
const renderer_ir = @import("ir.zig");
const renderer_pipeline = @import("pipeline.zig");
const renderer_font_atlas = @import("font_atlas_weighted.zig");
const renderer_software = @import("backends/software.zig");
const ui = @import("../ui.zig");

pub const Error = error{
    InvalidTarget,
    InvalidSurface,
    InvalidIrBuffer,
    InvalidIrResource,
    MissingFontAtlas,
    MissingImageTexture,
    UnsupportedIrPrimitive,
    DamageBudgetExceeded,
};

const compose_rect_budget: usize = 4096;
const compose_icon_budget: usize = 4096;
const compose_image_vertex_budget: usize = 2400;
const compose_overlay_rect_budget: usize = 512;
const compose_overlay_icon_budget: usize = 256;

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
    target: renderer_software.Framebuffer,
    damage: DamageList,

    pub fn init(target: renderer_software.Framebuffer, damage_rects: []PixelRect) Error!Compositor {
        if (target.width == 0 or target.height == 0 or target.pixels.len < target.width * target.height) return error.InvalidTarget;
        return .{
            .target = target,
            .damage = .{ .rects = damage_rects },
        };
    }

    pub fn compose(self: *Compositor, surfaces: []const Surface, font_atlas: *renderer_font_atlas.Atlas, scene: ui.Scene, background: ui.Color) Error!Receipt {
        var storage = renderer_ir.FixedBuffers(
            compose_rect_budget,
            compose_icon_budget,
            compose_image_vertex_budget,
            compose_overlay_rect_budget,
            compose_overlay_icon_budget,
            0,
            0,
        ){};
        const buffers = storage.buffers();
        renderer_pipeline.packScene(buffers, font_atlas, scene.written()) catch return error.InvalidIrBuffer;
        renderer_pipeline.packTextQuads(buffers, font_atlas, scene.written()) catch return error.InvalidIrBuffer;
        return self.composeIr(surfaces, buffers, renderer_pipeline.softwareResources(font_atlas, null), background);
    }

    pub fn composeIr(
        self: *Compositor,
        surfaces: []const Surface,
        buffers: renderer_ir.Buffers,
        resources: renderer_software.Resources,
        background: ui.Color,
    ) Error!Receipt {
        self.target.clear(background);
        self.damage.reset();
        renderer_ir.validateBuffers(buffers) catch return error.InvalidIrBuffer;

        var pixels_written: u64 = 0;
        for (surfaces) |surface| {
            pixels_written += try self.compositeSurface(surface);
        }

        try self.markIrDamage(buffers);
        const presentation = self.target.renderIr(buffers, resources) catch |err| return switch (err) {
            error.InvalidIrBuffer => error.InvalidIrBuffer,
            error.InvalidBuffer => error.InvalidIrBuffer,
            error.InvalidIrResource => error.InvalidIrResource,
            error.MissingFontAtlas => error.MissingFontAtlas,
            error.MissingImageTexture => error.MissingImageTexture,
            error.UnsupportedIrPrimitive => error.UnsupportedIrPrimitive,
            error.PixelBudgetExceeded => error.InvalidTarget,
            error.InvalidTarget => error.InvalidTarget,
            error.Budget => error.InvalidIrBuffer,
        };

        return .{
            .surface_count = surfaces.len,
            .ui_command_count = presentation.primitive_count,
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
            .svg_quad => |quad| try self.markRect(quad.bounds),
            .text_quad => |quad| try self.markRect(quad.bounds),
            .image_quad => |quad| try self.markRect(quad.bounds),
            .drag_source, .drop_target, .transition => {},
        }
    }

    fn markIrDamage(self: *Compositor, buffers: renderer_ir.Buffers) Error!void {
        for (renderer_ir.drawBatches(buffers)) |batch| switch (batch) {
            .rects, .overlay_rects => |rects| try self.markIrRectBuffer(rects),
            .image, .svg, .overlay_icon => |vertices| try self.markTexturedVertices(vertices),
            .icon_lines, .overlay_icon_lines => {},
        };
    }

    fn markIrRectBuffer(self: *Compositor, values: []const f32) Error!void {
        var iter = renderer_ir.RectIterator.init(values) catch return error.InvalidIrBuffer;
        while (iter.next() catch return error.InvalidIrBuffer) |rect| {
            try self.markRect(rect.bounds);
        }
    }

    fn markTexturedVertices(self: *Compositor, values: []const f32) Error!void {
        var iter = renderer_ir.TexturedQuadIterator.init(values) catch return error.InvalidIrBuffer;
        while (iter.next() catch return error.InvalidIrBuffer) |quad| {
            try self.markTexturedQuad(quad);
        }
    }

    fn markTexturedQuad(self: *Compositor, quad: renderer_ir.TexturedQuad) Error!void {
        try self.markRect(quad.bounds);
    }

    fn markRect(self: *Compositor, rect: ui.Rect) Error!void {
        const clipped = clipRect(rect, self.target) orelse return;
        try self.damage.append(clipped);
    }
};

fn clipSurface(surface: Surface, target: renderer_software.Framebuffer) ?PixelRect {
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

fn clipRect(rect: ui.Rect, target: renderer_software.Framebuffer) ?PixelRect {
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
const max_i32: u32 = @intCast(2147483647);

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
    const target = try renderer_software.Framebuffer.init(4, 4, &pixels);
    var damage: [4]PixelRect = undefined;
    var compositor = try Compositor.init(target, &damage);
    var commands: [1]ui.Command = undefined;
    const scene = ui.Scene.init(&commands);
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();

    const receipt = try compositor.compose(&.{app_surface}, &font_atlas, scene, .clear);
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
    const target = try renderer_software.Framebuffer.init(4, 4, &pixels);
    var damage: [4]PixelRect = undefined;
    var compositor = try Compositor.init(target, &damage);
    var commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(.{ .x = 1, .y = 1, .w = 2, .h = 2 }, red, .fill, 0.0, 0.0);
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();

    const receipt = try compositor.compose(&.{app_surface}, &font_atlas, scene, .clear);
    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(blue, pixels[0]);
    try std.testing.expectEqual(red, pixels[1 * 4 + 1]);
    try std.testing.expectEqual(@as(usize, 2), compositor.damageRects().len);
}

test "compositor renders canonical ir above app surfaces" {
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

    var commands: [2]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(ui.Rect.init(1, 1, 2, 2), red, .fill, 0.0, 0.0);

    var command_pixels: [4 * 4]ui.Color = undefined;
    const command_target = try renderer_software.Framebuffer.init(4, 4, &command_pixels);
    var command_damage: [4]PixelRect = undefined;
    var command_compositor = try Compositor.init(command_target, &command_damage);
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    const command_receipt = try command_compositor.compose(&.{app_surface}, &font_atlas, scene, .clear);

    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();

    var ir_pixels: [4 * 4]ui.Color = undefined;
    const ir_target = try renderer_software.Framebuffer.init(4, 4, &ir_pixels);
    var ir_damage: [4]PixelRect = undefined;
    var ir_compositor = try Compositor.init(ir_target, &ir_damage);
    const alpha_single = [_]u8{255};
    const ir_receipt = try ir_compositor.composeIr(&.{app_surface}, buffers, .{
        .font = .{ .width = 1, .height = 1, .alpha = &alpha_single },
    }, .clear);

    try std.testing.expect(ir_receipt.valid());
    try std.testing.expectEqual(command_receipt.damage_count, ir_receipt.damage_count);
    try std.testing.expectEqualSlices(ui.Color, &command_pixels, &ir_pixels);
}
