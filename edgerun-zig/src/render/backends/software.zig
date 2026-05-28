const std = @import("std");
const math = @import("../../math.zig");
const icon_vector = @import("../../icon_vector.zig");
const renderer_icon_mask = @import("../icon_mask.zig");
const renderer_ir = @import("../ir.zig");
const renderer_present = @import("../present.zig");
const component_union = @import("../../ui/components/Component.zig");
const node_renderer = @import("../../ui/components/NodeRenderer.zig");
const ui = @import("../../ui.zig");
const builtin = @import("builtin");

pub const Error = renderer_present.Error || error{
    PixelBudgetExceeded,
    InvalidIrBuffer,
    InvalidIrResource,
    UnsupportedIrPrimitive,
};

pub const TuningError = error{
    InvalidIconTuning,
};

pub const IconTuning = struct {
    curve_segments: usize,
    stroke_antialias_width: f32,
    round_cap_antialias_width: f32,
    line_stroke_coverage_boost: f32,
    curve_stroke_coverage_boost: f32,
    arc_stroke_coverage_boost: f32,
    arc_antialias_width: f32,
    large_arc_antialias_width: f32,
    arc_step_divisor: f32,
    large_arc_step_divisor: f32,
};

pub const default_icon_tuning = IconTuning{
    .curve_segments = icon_curve_segments_default,
    .stroke_antialias_width = icon_stroke_antialias_width_default,
    .round_cap_antialias_width = icon_stroke_round_cap_antialias_width_default,
    .line_stroke_coverage_boost = icon_line_stroke_coverage_boost_default,
    .curve_stroke_coverage_boost = icon_curve_stroke_coverage_boost_default,
    .arc_stroke_coverage_boost = icon_arc_stroke_coverage_boost_default,
    .arc_antialias_width = icon_arc_antialias_width_default,
    .large_arc_antialias_width = icon_large_arc_antialias_width_default,
    .arc_step_divisor = icon_arc_step_divisor_default,
    .large_arc_step_divisor = icon_large_arc_step_divisor_default,
};

var active_icon_tuning = default_icon_tuning;

pub fn setIconTuningForTest(tuning: IconTuning) TuningError!void {
    if (tuning.curve_segments < icon_curve_segments_min or tuning.curve_segments > icon_curve_segments_max) return error.InvalidIconTuning;
    if (tuning.stroke_antialias_width < icon_stroke_antialias_width_min or tuning.stroke_antialias_width > icon_stroke_antialias_width_max) return error.InvalidIconTuning;
    if (tuning.round_cap_antialias_width < icon_stroke_antialias_width_min or tuning.round_cap_antialias_width > icon_stroke_antialias_width_max) return error.InvalidIconTuning;
    if (tuning.line_stroke_coverage_boost < icon_stroke_coverage_boost_min or tuning.line_stroke_coverage_boost > icon_stroke_coverage_boost_max) return error.InvalidIconTuning;
    if (tuning.curve_stroke_coverage_boost < icon_stroke_coverage_boost_min or tuning.curve_stroke_coverage_boost > icon_stroke_coverage_boost_max) return error.InvalidIconTuning;
    if (tuning.arc_stroke_coverage_boost < icon_stroke_coverage_boost_min or tuning.arc_stroke_coverage_boost > icon_stroke_coverage_boost_max) return error.InvalidIconTuning;
    if (tuning.arc_antialias_width < icon_arc_antialias_width_min or tuning.arc_antialias_width > icon_arc_antialias_width_max) return error.InvalidIconTuning;
    if (tuning.large_arc_antialias_width < icon_arc_antialias_width_min or tuning.large_arc_antialias_width > icon_arc_antialias_width_max) return error.InvalidIconTuning;
    if (tuning.arc_step_divisor < icon_arc_step_divisor_min or tuning.arc_step_divisor > icon_arc_step_divisor_max) return error.InvalidIconTuning;
    if (tuning.large_arc_step_divisor < icon_arc_step_divisor_min or tuning.large_arc_step_divisor > icon_arc_step_divisor_max) return error.InvalidIconTuning;
    active_icon_tuning = tuning;
}

pub fn resetIconTuningForTest() void {
    active_icon_tuning = default_icon_tuning;
}

pub const AlphaAtlas = struct {
    width: usize,
    height: usize,
    alpha: []const u8,

    pub fn valid(self: AlphaAtlas) bool {
        return self.width != 0 and self.height != 0 and self.alpha.len >= self.width * self.height;
    }
};

pub const RgbaTexture = renderer_ir.RgbaTexture;

pub const IrResources = struct {
    font: AlphaAtlas,
    image: ?RgbaTexture = null,

    pub fn presentationResources(self: IrResources) renderer_present.Resources {
        return .{
            .font_atlas = self.font.valid(),
            .image_texture = if (self.image) |image| image.valid() else false,
        };
    }
};

const IconPaint = union(enum) {
    solid: ui.Color,
    linear_gradient: icon_vector.LinearGradient,
    radial_gradient: icon_vector.RadialGradient,

    fn solidColor(self: IconPaint) ui.Color {
        return switch (self) {
            .solid => |color| color,
            .linear_gradient => |gradient| paintToColor(gradient.stops[0].color),
            .radial_gradient => |gradient| paintToColor(gradient.stops[0].color),
        };
    }

    fn colorAt(self: IconPaint, icon_bounds: ui.Rect, object_bounds: ui.Rect, x: usize, y: usize) ui.Color {
        return switch (self) {
            .solid => |color| color,
            .linear_gradient => |gradient| gradientColorAt(gradient, icon_bounds, object_bounds, x, y),
            .radial_gradient => |gradient| radialGradientColorAt(gradient, icon_bounds, object_bounds, x, y),
        };
    }
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

    pub fn rasterize(self: Surface, commands: []const ui.Command) Error!void {
        try self.rasterizeScaled(commands, default_raster_scale);
    }

    pub fn rasterizeScaled(self: Surface, commands: []const ui.Command, scale: f32) Error!void {
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
            .text => return error.UnsupportedIrPrimitive,
            .icon_quad => |quad| self.drawIconQuad(quad, scale),
            .svg_quad => |quad| self.drawIconInstance(quad.bounds, quad.color, quad.svg.icon_id, scale),
            .drag_source, .drop_target, .text_quad, .image_quad, .transition => {},
        };
    }

    pub fn rasterizeIr(self: Surface, buffers: renderer_ir.Buffers) Error!void {
        renderer_ir.validateBuffers(buffers) catch return error.InvalidIrBuffer;
        if (buffers.hasTexturedVertices()) return error.UnsupportedIrPrimitive;
        for (renderer_ir.drawBatches(buffers)) |batch| switch (batch) {
            .rects, .overlay_rects => |rects| try self.rasterizeIrRects(rects),
            .svg, .overlay_icon => |icons| try self.rasterizeIrIcons(icons),
            .image, .text, .overlay_text, .icon_lines, .overlay_icon_lines => {},
        };
    }

    pub fn rasterizeIrWithResources(self: Surface, buffers: renderer_ir.Buffers, resources: IrResources) Error!void {
        renderer_ir.validateBuffers(buffers) catch return error.InvalidIrBuffer;
        if (!resources.font.valid()) return error.InvalidIrResource;
        const image_texture = if (!buffers.hasImageVertices())
            null
        else
            resources.image orelse return error.InvalidIrResource;
        if (image_texture) |texture| if (!texture.valid()) return error.InvalidIrResource;

        for (renderer_ir.drawBatches(buffers)) |batch| switch (batch) {
            .rects, .overlay_rects => |rects| try self.rasterizeIrRects(rects),
            .image => |vertices| if (image_texture) |texture| try self.rasterizeRgbaTexturedQuads(vertices, texture),
            .text, .overlay_text => |vertices| try self.rasterizeBilinearAlphaTexturedQuads(vertices, resources.font),
            .svg, .overlay_icon => |icons| try self.rasterizeIrIcons(icons),
            .icon_lines, .overlay_icon_lines => {},
        };
    }

    pub fn renderIrFrameWithResources(self: Surface, buffers: renderer_ir.Buffers, resources: IrResources) Error!renderer_present.Receipt {
        const receipt = renderer_present.present(.{
            .target = .{
                .destination = .pixel_frame,
                .width = @intCast(self.width),
                .height = @intCast(self.height),
            },
            .buffers = buffers,
            .resources = resources.presentationResources(),
        }) catch |err| return switch (err) {
            error.InvalidBuffer => error.InvalidIrBuffer,
            else => err,
        };
        try self.rasterizeIrWithResources(buffers, resources);
        return receipt;
    }

    fn rasterizeIrRects(self: Surface, rects: []const f32) Error!void {
        var iter = renderer_ir.RectIterator.init(rects) catch return error.InvalidIrBuffer;
        while (iter.next() catch return error.InvalidIrBuffer) |rect| {
            self.drawRect(rect, default_raster_scale);
        }
    }

    fn rasterizeIrIcons(self: Surface, icons: []const f32) Error!void {
        var iter = renderer_ir.IconIterator.init(icons) catch return error.InvalidIrBuffer;
        while (iter.next() catch return error.InvalidIrBuffer) |instance| {
            self.drawIconInstance(instance.bounds, instance.color, instance.icon_id, default_raster_scale);
        }
    }

    fn rasterizeRgbaTexturedQuads(self: Surface, vertices: []const f32, texture: RgbaTexture) Error!void {
        var iter = renderer_ir.TexturedQuadIterator.init(vertices) catch return error.InvalidIrBuffer;
        while (iter.next() catch return error.InvalidIrBuffer) |quad| {
            try self.rasterizeRgbaTexturedQuad(quad, texture);
        }
    }

    fn rasterizeRgbaTexturedQuad(self: Surface, quad: renderer_ir.TexturedQuad, texture: RgbaTexture) Error!void {
        const px0 = clampCoord(@intFromFloat(math.floorF(quad.bounds.x)), self.width);
        const py0 = clampCoord(@intFromFloat(math.floorF(quad.bounds.y)), self.height);
        const px1 = clampCoord(@intFromFloat(math.ceilF(quad.bounds.x + quad.bounds.w)), self.width);
        const py1 = clampCoord(@intFromFloat(math.ceilF(quad.bounds.y + quad.bounds.h)), self.height);
        if (px1 <= px0 or py1 <= py0) return;

        var y = py0;
        while (y < py1) : (y += 1) {
            const fy = (@as(f32, @floatFromInt(y)) + pixel_center - quad.bounds.y) / quad.bounds.h;
            const v = lerp(quad.v0, quad.v1, fy);
            var x = px0;
            while (x < px1) : (x += 1) {
                const fx = (@as(f32, @floatFromInt(x)) + pixel_center - quad.bounds.x) / quad.bounds.w;
                const u = lerp(quad.u0, quad.u1, fx);
                const texel = sampleRgba(texture, u, v);
                const color = multiplyRgb(texel, quad.color);
                const alpha = scaleByte(quad.color.a, @as(f32, @floatFromInt(texel.a)) / 255.0);
                if (alpha != 0) self.blendPixel(x, y, color, alpha);
            }
        }
    }

    fn rasterizeBilinearAlphaTexturedQuads(self: Surface, vertices: []const f32, atlas: AlphaAtlas) Error!void {
        var iter = renderer_ir.TexturedQuadIterator.init(vertices) catch return error.InvalidIrBuffer;
        while (iter.next() catch return error.InvalidIrBuffer) |quad| {
            try self.rasterizeBilinearAlphaTexturedQuad(quad, atlas);
        }
    }

    fn rasterizeBilinearAlphaTexturedQuad(self: Surface, quad: renderer_ir.TexturedQuad, atlas: AlphaAtlas) Error!void {
        const px0 = clampCoord(@intFromFloat(math.floorF(quad.bounds.x)), self.width);
        const py0 = clampCoord(@intFromFloat(math.floorF(quad.bounds.y)), self.height);
        const px1 = clampCoord(@intFromFloat(math.ceilF(quad.bounds.x + quad.bounds.w)), self.width);
        const py1 = clampCoord(@intFromFloat(math.ceilF(quad.bounds.y + quad.bounds.h)), self.height);
        if (px1 <= px0 or py1 <= py0) return;

        const u_step = (quad.u1 - quad.u0) / quad.bounds.w;
        const v_step = (quad.v1 - quad.v0) / quad.bounds.h;
        var color = quad.color;
        color.a = max_alpha;
        var y = py0;
        while (y < py1) : (y += 1) {
            const v = quad.v0 + (@as(f32, @floatFromInt(y)) + pixel_center - quad.bounds.y) * v_step;
            const sample_y = bilinearAxis(v, atlas.height);
            const row0 = sample_y.index0 * atlas.width;
            const row1 = sample_y.index1 * atlas.width;
            var x = px0;
            while (x < px1) : (x += 1) {
                const u = quad.u0 + (@as(f32, @floatFromInt(x)) + pixel_center - quad.bounds.x) * u_step;
                const sample_x = bilinearAxis(u, atlas.width);
                const sampled_alpha = bilinearAlphaFloat(
                    atlas.alpha[row0 + sample_x.index0],
                    atlas.alpha[row0 + sample_x.index1],
                    atlas.alpha[row1 + sample_x.index0],
                    atlas.alpha[row1 + sample_x.index1],
                    sample_x.fraction,
                    sample_y.fraction,
                );
                const alpha = colorF(quad.color.a) * sampled_alpha;
                if (alpha > 0.0) self.blendPixelFloatAlpha(y * self.width + x, color, alpha);
            }
        }
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
            .pie_slice => self.fillPieSlice(bounds, rect.color, rect.color2),
        }
    }

    pub fn blendPixel(self: Surface, x: usize, y: usize, color: ui.Color, alpha: u8) void {
        self.blendPixelAt(y * self.width + x, color, alpha);
    }

    fn blendPixelAt(self: Surface, index: usize, color: ui.Color, alpha: u8) void {
        const dst = self.pixels[index];
        const a: u16 = alpha;
        const inv: u16 = 255 - a;
        self.pixels[index] = .{
            .r = blendChannel(color.r, dst.r, a, inv),
            .g = blendChannel(color.g, dst.g, a, inv),
            .b = blendChannel(color.b, dst.b, a, inv),
            .a = @intCast(@min(@as(u16, 255), @as(u16, dst.a) + (@as(u16, color.a) * a) / 255)),
        };
    }

    fn blendPixelFloatAlpha(self: Surface, index: usize, color: ui.Color, alpha: f32) void {
        const dst = self.pixels[index];
        const a = math.clampF(alpha, 0.0, 1.0);
        const inv = 1.0 - a;
        self.pixels[index] = .{
            .r = blendChannelFloat(color.r, dst.r, a, inv),
            .g = blendChannelFloat(color.g, dst.g, a, inv),
            .b = blendChannelFloat(color.b, dst.b, a, inv),
            .a = @intCast(math.lrintF(math.clampF(@as(f32, @floatFromInt(color.a)) * a + @as(f32, @floatFromInt(dst.a)) * inv, 0.0, 255.0))),
        };
    }

    fn blendPixelMaxAlpha(self: Surface, x: usize, y: usize, color: ui.Color, alpha: u8) void {
        const index = y * self.width + x;
        if (alpha <= self.pixels[index].a) return;
        self.pixels[index] = .{
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = scaleByte(color.a, @as(f32, @floatFromInt(alpha)) / byte_unit_scale),
        };
    }

    fn blendPixelPathAlpha(self: Surface, x: usize, y: usize, color: ui.Color, alpha: u8) void {
        const index = y * self.width + x;
        const src_a: u16 = scaleByte(color.a, @as(f32, @floatFromInt(alpha)) / byte_unit_scale);
        const dst_a: u16 = self.pixels[index].a;
        const inv_a: u16 = 255 - src_a;
        const dst = self.pixels[index];
        const out_a = src_a + (dst_a * (255 - src_a)) / 255;
        self.pixels[index] = .{
            .r = blendChannel(color.r, dst.r, src_a, inv_a),
            .g = blendChannel(color.g, dst.g, src_a, inv_a),
            .b = blendChannel(color.b, dst.b, src_a, inv_a),
            .a = @intCast(@min(@as(u16, 255), out_a)),
        };
    }

    fn fill(self: Surface, bounds: ui.Rect, color: ui.Color) void {
        const x0 = clampCoord(@intFromFloat(math.floorF(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(bounds.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(bounds.x + bounds.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(bounds.y + bounds.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) self.pixels[y * self.width + x] = color;
        }
    }

    fn fillRounded(self: Surface, bounds: ui.Rect, top_color: ui.Color, bottom_color: ui.Color, radius: f32) void {
        if (radius <= 0.0 and colorsEqual(top_color, bottom_color) and top_color.a == max_alpha) {
            self.fill(bounds, top_color);
            return;
        }
        const x0 = clampCoord(@intFromFloat(math.floorF(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(bounds.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(bounds.x + bounds.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(bounds.y + bounds.h)), self.height);
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
                self.drawCoveredPixel(x, y, color, alpha);
            }
        }
    }

    fn fillRoundedPaint(self: Surface, icon_bounds: ui.Rect, bounds: ui.Rect, paint: IconPaint, radius: f32) void {
        const x0 = clampCoord(@intFromFloat(math.floorF(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(bounds.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(bounds.x + bounds.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(bounds.y + bounds.h)), self.height);
        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const py = @as(f32, @floatFromInt(y)) + pixel_center;
                const alpha = roundedAlpha(bounds, radius, px, py);
                if (alpha != 0) self.blendPixel(x, y, paint.colorAt(icon_bounds, bounds, x, y), alpha);
            }
        }
    }

    fn fillRoundedSolid(self: Surface, bounds: ui.Rect, color: ui.Color, radius: f32) void {
        const r = @min(radius, @min(bounds.w * 0.5, bounds.h * 0.5));
        if (r <= 0.0) {
            self.fill(bounds, color);
            return;
        }

        const center_w = bounds.w - r * 2.0;
        if (center_w > 0.0) self.fill(ui.Rect.init(bounds.x + r, bounds.y, center_w, bounds.h), color);
        const center_h = bounds.h - r * 2.0;
        if (center_h > 0.0) self.fill(ui.Rect.init(bounds.x, bounds.y + r, bounds.w, center_h), color);

        const corner = ui.Rect.init(bounds.x, bounds.y, r, r);
        self.fillRoundedCorner(bounds, corner, color, r);
        self.fillRoundedCorner(bounds, ui.Rect.init(bounds.x + bounds.w - r, bounds.y, r, r), color, r);
        self.fillRoundedCorner(bounds, ui.Rect.init(bounds.x, bounds.y + bounds.h - r, r, r), color, r);
        self.fillRoundedCorner(bounds, ui.Rect.init(bounds.x + bounds.w - r, bounds.y + bounds.h - r, r, r), color, r);
    }

    fn fillRoundedCorner(self: Surface, bounds: ui.Rect, corner: ui.Rect, color: ui.Color, radius: f32) void {
        const x0 = clampCoord(@intFromFloat(math.floorF(corner.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(corner.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(corner.x + corner.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(corner.y + corner.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            const py = @as(f32, @floatFromInt(y)) + pixel_center;
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                self.drawCoveredPixel(x, y, color, roundedAlpha(bounds, radius, px, py));
            }
        }
    }

    fn strokeRounded(self: Surface, bounds: ui.Rect, color: ui.Color, radius: f32, width: f32) void {
        const outer = bounds;
        const inner = bounds.insetUniform(width);
        const x0 = clampCoord(@intFromFloat(math.floorF(outer.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(outer.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(outer.x + outer.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(outer.y + outer.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            const py = @as(f32, @floatFromInt(y)) + pixel_center;
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const outer_alpha = roundedAlpha(outer, radius, px, py);
                const alpha = roundedBorderAlpha(outer_alpha, inner, @max(0.0, radius - width), px, py);
                if (alpha != 0) self.blendPixel(x, y, color, alpha);
            }
        }
    }

    fn strokeRoundedPaint(self: Surface, icon_bounds: ui.Rect, bounds: ui.Rect, paint: IconPaint, radius: f32, width: f32) void {
        const outer = bounds;
        const inner = bounds.insetUniform(width);
        const x0 = clampCoord(@intFromFloat(math.floorF(outer.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(outer.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(outer.x + outer.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(outer.y + outer.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            const py = @as(f32, @floatFromInt(y)) + pixel_center;
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const outer_alpha = roundedAlpha(outer, radius, px, py);
                const alpha = roundedBorderAlpha(outer_alpha, inner, @max(0.0, radius - width), px, py);
                if (alpha != 0) self.blendPixel(x, y, paint.colorAt(icon_bounds, bounds, x, y), alpha);
            }
        }
    }

    fn shadow(self: Surface, bounds: ui.Rect, color: ui.Color, radius: f32, spread: f32) void {
        if (spread <= 0.0) return;
        var shadow_color = color;
        shadow_color.a = scaleByte(color.a, cpu_shadow_alpha);
        if (shadow_color.a == 0) return;
        const outer = bounds.insetUniform(-spread);
        const x0 = clampCoord(@intFromFloat(math.floorF(outer.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(outer.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(outer.x + outer.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(outer.y + outer.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        var y = y0;
        while (y < y1) : (y += 1) {
            const py = @as(f32, @floatFromInt(y)) + pixel_center;
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                if (bounds.containsInclusive(px, py)) continue;
                const distance = roundedOutsideDistance(bounds, radius, px, py);
                if (distance <= 0.0 or distance >= spread) continue;
                const t = 1.0 - distance / spread;
                const coverage = scaleByte(max_alpha, t * t);
                self.drawCoveredPixel(x, y, shadow_color, coverage);
            }
        }
    }

    fn drawCoveredPixel(self: Surface, x: usize, y: usize, color: ui.Color, coverage: u8) void {
        if (coverage == 0 or color.a == 0) return;
        if (coverage == max_alpha and color.a == max_alpha) {
            self.pixels[y * self.width + x] = color;
            return;
        }
        var source = color;
        source.a = max_alpha;
        self.blendPixel(x, y, source, scaleByte(color.a, @as(f32, @floatFromInt(coverage)) / byte_unit_scale));
    }

    fn drawIconQuad(self: Surface, quad: ui.IconQuad, scale: f32) void {
        self.drawIconInstance(quad.bounds, quad.color, quad.icon_id, scale);
    }

    fn drawIconInstance(self: Surface, icon_bounds: ui.Rect, color: ui.Color, icon_id: u32, scale: f32) void {
        const bounds = scaleRect(icon_bounds, scale);
        if (self.drawMappedIconMask(bounds, color, icon_id)) return;
        var iter = renderer_ir.iconOpIteratorForId(icon_id);
        self.drawIconOps(bounds, color, &iter);
    }

    fn drawMappedIconMask(self: Surface, bounds: ui.Rect, color: ui.Color, icon_id: u32) bool {
        const width = iconMaskAxis(bounds.w);
        const height = iconMaskAxis(bounds.h);
        var alpha: [renderer_icon_mask.max_pixels]u8 = undefined;
        const mask = renderer_icon_mask.rasterizeIconAlpha(icon_id, width, height, &alpha) catch return false;
        if (!mask.painted) return false;
        const x0 = clampCoord(@intFromFloat(math.floorF(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(bounds.y)), self.height);
        var row: usize = 0;
        while (row < mask.height) : (row += 1) {
            const y = y0 + row;
            if (y >= self.height) break;
            var col: usize = 0;
            while (col < mask.width) : (col += 1) {
                const x = x0 + col;
                if (x >= self.width) break;
                const alpha_value = mask.alpha[row * mask.width + col];
                if (alpha_value > icon_alpha_floor) self.blendPixelPathAlpha(x, y, color, alpha_value);
            }
        }
        return true;
    }

    fn drawIconSvg(self: Surface, bounds: ui.Rect, color: ui.Color, svg: []const u8) void {
        var iter = renderer_ir.iconOpIteratorFromSource(svg);
        self.drawIconOps(bounds, color, &iter);
    }

    fn drawIconOps(self: Surface, bounds: ui.Rect, color: ui.Color, iter: *renderer_ir.IconOpIterator) void {
        var buffer: [icon_alpha_mask_capacity]u8 = undefined;
        var mask = IconAlphaMask.init(bounds, self.width, self.height, buffer[0..]);
        var clip_buffer: [icon_alpha_mask_capacity]u8 = undefined;
        var clip_mask = IconAlphaMask.init(bounds, self.width, self.height, clip_buffer[0..]);
        var clip = IconClipState{ .mask = &clip_mask };
        var path = IconPathState{};
        var paint = IconPaint{ .solid = color };
        var stroke_width: f32 = icon_stroke_scale;
        var stroke_cap = icon_vector.StrokeCap.round;
        var stroke_join = icon_vector.StrokeJoin.round;
        var stroke_miter_limit: f32 = svg_miter_limit_default;
        while (iter.next() catch unreachable) |op| {
            self.drawIconOp(bounds, color, &paint, &stroke_width, &stroke_cap, &stroke_join, &stroke_miter_limit, &mask, &clip, &path, op);
        }
        self.finishIconSubpath(&mask, &path, stroke_width, stroke_cap);
        self.blendIconMaskPaint(&mask, paint, &clip);
    }

    fn drawIconOp(self: Surface, bounds: ui.Rect, current_color: ui.Color, paint: *IconPaint, stroke_width: *f32, stroke_cap: *icon_vector.StrokeCap, stroke_join: *icon_vector.StrokeJoin, stroke_miter_limit: *f32, mask: *IconAlphaMask, clip: *IconClipState, path: *IconPathState, op: icon_vector.Op) void {
        switch (op) {
            .paint_current_color => {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                paint.* = .{ .solid = current_color };
            },
            .paint_current_color_alpha => |alpha| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                paint.* = .{ .solid = .{
                    .r = current_color.r,
                    .g = current_color.g,
                    .b = current_color.b,
                    .a = scaleAlphaByte(current_color.a, alpha),
                } };
            },
            .paint_rgba => |rgba| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                paint.* = .{ .solid = .{ .r = rgba.r, .g = rgba.g, .b = rgba.b, .a = rgba.a } };
            },
            .paint_linear_gradient => |gradient| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                paint.* = .{ .linear_gradient = gradient };
            },
            .paint_radial_gradient => |gradient| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                paint.* = .{ .radial_gradient = gradient };
            },
            .stroke_width => |width| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                stroke_width.* = width;
            },
            .stroke_cap => |cap| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                stroke_cap.* = cap;
            },
            .stroke_join => |join| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                stroke_join.* = join;
            },
            .stroke_miter_limit => |limit| {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                stroke_miter_limit.* = limit;
            },
            .begin_clip_path => {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                clip.begin();
            },
            .end_clip_path => clip.end(),
            .clear_clip_path => {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                clip.clear();
            },
            .polyline => |points| self.iconLine(bounds, paint.*, stroke_width.*, stroke_cap.*, stroke_join.*, stroke_miter_limit.*, points),
            .circle => |circle| self.iconCircle(bounds, paint.*, stroke_width.*, circle.cx, circle.cy, circle.radius),
            .ellipse => |ellipse| self.iconEllipse(bounds, paint.*, stroke_width.*, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry, ellipse.full),
            .round_rect => |rect| self.iconRoundRect(bounds, paint.*, stroke_width.*, rect.x, rect.y, rect.w, rect.h, rect.radius),
            .filled_circle => |circle| self.iconFilledCircle(bounds, paint.*, circle.cx, circle.cy, circle.radius),
            .filled_ellipse => |ellipse| self.iconFilledEllipse(bounds, paint.*, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry),
            .filled_round_rect => |rect| self.iconFilledRoundRect(bounds, paint.*, rect.x, rect.y, rect.w, rect.h, rect.radius),
            .begin_fill_path => {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                path.beginFill(.nonzero);
            },
            .begin_evenodd_fill_path => {
                self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                path.beginFill(.evenodd);
            },
            .end_fill_path => {
                if (clip.building) {
                    self.fillClipPathMask(bounds, path, clip.mask);
                } else {
                    self.fillIconPath(bounds, paint.*, path, clip);
                }
                path.clearFill();
            },
            .move_to => |point| {
                if (path.fill_active) {
                    path.fillMoveTo(point);
                    return;
                }
                if (path.has_segment) {
                    self.finishIconPathMask(mask, clip, path, paint.*, stroke_width.*, stroke_cap.*);
                }
                path.moveTo(point);
            },
            .line_to => |point| {
                if (path.fill_active) {
                    path.fillLineTo(point);
                    return;
                }
                if (path.current) |current| self.strokePathSegmentMask(mask, path, stroke_width.*, stroke_join.*, stroke_miter_limit.*, current, point, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
                path.lineTo(point);
            },
            .quad_to => |quad| {
                if (path.fill_active) {
                    if (path.current) |current| self.fillQuadraticPath(path, current, quad.control, quad.end);
                    path.lineTo(quad.end);
                    return;
                }
                if (path.current) |current| self.strokeQuadraticPathMask(mask, path, stroke_width.*, stroke_join.*, stroke_miter_limit.*, current, quad.control, quad.end);
                path.lineTo(quad.end);
            },
            .cubic_to => |cubic| {
                if (path.fill_active) {
                    if (path.current) |current| self.fillCubicPath(path, current, cubic.control0, cubic.control1, cubic.end);
                    path.lineTo(cubic.end);
                    return;
                }
                if (path.current) |current| self.strokeCubicPathMask(mask, path, stroke_width.*, stroke_join.*, stroke_miter_limit.*, current, cubic.control0, cubic.control1, cubic.end);
                path.lineTo(cubic.end);
            },
            .arc_to => |arc| {
                if (path.fill_active) {
                    if (path.current) |current| self.fillArcPath(path, current, arc);
                    path.lineTo(arc.end);
                    return;
                }
                if (path.current) |current| self.strokeArcPathMask(mask, path, stroke_width.*, stroke_join.*, stroke_miter_limit.*, current, arc);
                path.lineTo(arc.end);
            },
            .close_path => if (path.current) |current| if (path.start) |start| {
                if (path.fill_active) {
                    path.closeFillSubpath();
                    return;
                }
                self.strokePathSegmentMask(mask, path, stroke_width.*, stroke_join.*, stroke_miter_limit.*, current, start, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
                self.strokeRoundPointMask(mask, stroke_width.*, start, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
                path.closed = true;
                path.lineTo(start);
            },
        }
    }

    fn finishIconPathMask(self: Surface, mask: *IconAlphaMask, clip: ?*const IconClipState, path: *IconPathState, paint: IconPaint, stroke_width: f32, stroke_cap: icon_vector.StrokeCap) void {
        self.finishIconSubpath(mask, path, stroke_width, stroke_cap);
        self.blendIconMaskPaint(mask, paint, clip);
        mask.clear();
    }

    fn iconLine(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, stroke_cap: icon_vector.StrokeCap, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, points: []const f32) void {
        if (points.len < 4) return;
        var index: usize = 2;
        while (index < points.len) : (index += 2) {
            self.strokeSegmentPaint(bounds, paint, stroke_width, points[index - 2], points[index - 1], points[index], points[index + 1]);
            if (index > 2) {
                self.strokeJoinPaint(bounds, paint, stroke_width, stroke_join, stroke_miter_limit, points[index - 4], points[index - 3], points[index - 2], points[index - 1], points[index], points[index + 1]);
            }
        }
        self.strokeSegmentCapsPaint(bounds, paint, stroke_width, stroke_cap, points[0], points[1], points[2], points[3], points[points.len - 4], points[points.len - 3], points[points.len - 2], points[points.len - 1]);
    }

    fn iconCircle(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, x: f32, y: f32, radius: f32) void {
        self.strokeEllipsePaint(bounds, paint, stroke_width, x, y, radius, radius, true);
    }

    fn iconEllipse(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, x: f32, y: f32, rx: f32, ry: f32, full: bool) void {
        self.strokeEllipsePaint(bounds, paint, stroke_width, x, y, rx, ry, full);
    }

    fn iconFilledCircle(self: Surface, bounds: ui.Rect, paint: IconPaint, x: f32, y: f32, radius: f32) void {
        const size = @min(bounds.w, bounds.h);
        const cx = bounds.x + bounds.w * x;
        const cy = bounds.y + bounds.h * y;
        const r = size * radius;
        const area = ui.Rect.init(cx - r, cy - r, r * 2.0, r * 2.0);
        switch (paint) {
            .solid => |color| self.fillRounded(area, color, color, r),
            .linear_gradient, .radial_gradient => self.iconFilledEllipse(bounds, paint, x, y, radius, radius),
        }
    }

    fn iconFilledEllipse(self: Surface, bounds: ui.Rect, paint: IconPaint, x: f32, y: f32, rx: f32, ry: f32) void {
        const cx = bounds.x + bounds.w * x;
        const cy = bounds.y + bounds.h * y;
        const radius_x = bounds.w * rx;
        const radius_y = bounds.h * ry;
        if (radius_x <= 0.0 or radius_y <= 0.0) return;
        const object_bounds = ui.Rect.init(cx - radius_x, cy - radius_y, radius_x * 2.0, radius_y * 2.0);
        const area = ui.Rect.init(cx - radius_x - antialias_width, cy - radius_y - antialias_width, (radius_x + antialias_width) * 2.0, (radius_y + antialias_width) * 2.0);
        const x_start = clampCoord(@intFromFloat(math.floorF(area.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(area.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(area.x + area.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(area.y + area.h)), self.height);
        var py_i = y_start;
        while (py_i < y_end) : (py_i += 1) {
            var px_i = x_start;
            while (px_i < x_end) : (px_i += 1) {
                const px = @as(f32, @floatFromInt(px_i)) + pixel_center;
                const py = @as(f32, @floatFromInt(py_i)) + pixel_center;
                const nx = (px - cx) / radius_x;
                const ny = (py - cy) / radius_y;
                const distance = (1.0 - math.sqrtF(nx * nx + ny * ny)) * @min(radius_x, radius_y);
                const alpha = coverageAlpha(0.0, -distance);
                if (alpha != 0) self.blendPixel(px_i, py_i, paint.colorAt(bounds, object_bounds, px_i, py_i), alpha);
            }
        }
    }

    fn iconRoundRect(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, x: f32, y: f32, w: f32, h: f32, radius: f32) void {
        const rect = ui.Rect.init(bounds.x + bounds.w * x, bounds.y + bounds.h * y, bounds.w * w, bounds.h * h);
        self.strokeRoundedPaint(bounds, rect, paint, @min(bounds.w, bounds.h) * radius, iconStroke(bounds, stroke_width));
    }

    fn iconFilledRoundRect(self: Surface, bounds: ui.Rect, paint: IconPaint, x: f32, y: f32, w: f32, h: f32, radius: f32) void {
        const rect = ui.Rect.init(bounds.x + bounds.w * x, bounds.y + bounds.h * y, bounds.w * w, bounds.h * h);
        switch (paint) {
            .solid => |color| self.fillRounded(rect, color, color, @min(bounds.w, bounds.h) * radius),
            .linear_gradient, .radial_gradient => self.fillRoundedPaint(bounds, rect, paint, @min(bounds.w, bounds.h) * radius),
        }
    }

    fn strokeSegment(self: Surface, bounds: ui.Rect, color: ui.Color, x0n: f32, y0n: f32, x1n: f32, y1n: f32) void {
        const x0 = bounds.x + bounds.w * x0n;
        const y0 = bounds.y + bounds.h * y0n;
        const x1 = bounds.x + bounds.w * x1n;
        const y1 = bounds.y + bounds.h * y1n;
        const radius = iconStroke(bounds, icon_stroke_scale) * 0.5;
        const left = @min(x0, x1) - radius;
        const top = @min(y0, y1) - radius;
        const right = @max(x0, x1) + radius;
        const bottom = @max(y0, y1) + radius;
        const x_start = clampCoord(@intFromFloat(math.floorF(left)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(top)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(right)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(bottom)), self.height);
        const dx = x1 - x0;
        const dy = y1 - y0;
        const denom = dx * dx + dy * dy;
        if (denom <= 0.0) return;
        const boost_coverage = isSlopedSegment(dx, dy);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const py = @as(f32, @floatFromInt(y)) + pixel_center;
                const t = math.clampF(((px - x0) * dx + (py - y0) * dy) / denom, 0.0, 1.0);
                const cx = x0 + dx * t;
                const cy = y0 + dy * t;
                const dist = math.sqrtF((px - cx) * (px - cx) + (py - cy) * (py - cy));
                const alpha = strokeCoverageAlpha(radius, dist, active_icon_tuning.stroke_antialias_width, boost_coverage, active_icon_tuning.line_stroke_coverage_boost);
                if (alpha != 0) self.blendPixelMaxAlpha(x, y, color, alpha);
            }
        }
    }

    fn strokeSegmentPaint(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, x0n: f32, y0n: f32, x1n: f32, y1n: f32) void {
        const x0 = bounds.x + bounds.w * x0n;
        const y0 = bounds.y + bounds.h * y0n;
        const x1 = bounds.x + bounds.w * x1n;
        const y1 = bounds.y + bounds.h * y1n;
        const radius = iconStroke(bounds, stroke_width) * 0.5;
        const object_bounds = ui.Rect.init(@min(x0, x1) - radius, @min(y0, y1) - radius, math.absF(x1 - x0) + radius * 2.0, math.absF(y1 - y0) + radius * 2.0);
        const x_start = clampCoord(@intFromFloat(math.floorF(object_bounds.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(object_bounds.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.x + object_bounds.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.y + object_bounds.h)), self.height);
        const dx = x1 - x0;
        const dy = y1 - y0;
        const denom = dx * dx + dy * dy;
        if (denom <= 0.0) return;
        const boost_coverage = isSlopedSegment(dx, dy);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const py = @as(f32, @floatFromInt(y)) + pixel_center;
                const t = math.clampF(((px - x0) * dx + (py - y0) * dy) / denom, 0.0, 1.0);
                const cx = x0 + dx * t;
                const cy = y0 + dy * t;
                const dist = math.sqrtF((px - cx) * (px - cx) + (py - cy) * (py - cy));
                const alpha = strokeCoverageAlpha(radius, dist, active_icon_tuning.stroke_antialias_width, boost_coverage, active_icon_tuning.line_stroke_coverage_boost);
                if (alpha != 0) self.blendPixelMaxAlpha(x, y, paint.colorAt(bounds, object_bounds, x, y), alpha);
            }
        }
    }

    fn strokeSegmentCapsPaint(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, stroke_cap: icon_vector.StrokeCap, first_x0: f32, first_y0: f32, first_x1: f32, first_y1: f32, last_x0: f32, last_y0: f32, last_x1: f32, last_y1: f32) void {
        switch (stroke_cap) {
            .butt => {},
            .round => {
                self.strokeRoundCapPaint(bounds, paint, stroke_width, first_x0, first_y0);
                self.strokeRoundCapPaint(bounds, paint, stroke_width, last_x1, last_y1);
            },
            .square => {
                self.strokeSquareCapPaint(bounds, paint, stroke_width, first_x1, first_y1, first_x0, first_y0);
                self.strokeSquareCapPaint(bounds, paint, stroke_width, last_x0, last_y0, last_x1, last_y1);
            },
        }
    }

    fn strokeRoundCapPaint(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, xn: f32, yn: f32) void {
        const cx = bounds.x + bounds.w * xn;
        const cy = bounds.y + bounds.h * yn;
        const radius = iconStroke(bounds, stroke_width) * 0.5;
        const object_bounds = ui.Rect.init(cx - radius, cy - radius, radius * 2.0, radius * 2.0);
        const x_start = clampCoord(@intFromFloat(math.floorF(object_bounds.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(object_bounds.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.x + object_bounds.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.y + object_bounds.h)), self.height);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const py = @as(f32, @floatFromInt(y)) + pixel_center;
                const dx = px - cx;
                const dy = py - cy;
                const alpha = strokeCoverageAlpha(radius, math.sqrtF(dx * dx + dy * dy), active_icon_tuning.round_cap_antialias_width, true, 0.0);
                if (alpha != 0) self.blendPixelMaxAlpha(x, y, paint.colorAt(bounds, object_bounds, x, y), alpha);
            }
        }
    }

    fn strokeSquareCapPaint(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, inner_xn: f32, inner_yn: f32, cap_xn: f32, cap_yn: f32) void {
        const x_inner = bounds.x + bounds.w * inner_xn;
        const y_inner = bounds.y + bounds.h * inner_yn;
        const x_cap = bounds.x + bounds.w * cap_xn;
        const y_cap = bounds.y + bounds.h * cap_yn;
        const dx = x_cap - x_inner;
        const dy = y_cap - y_inner;
        const length = math.sqrtF(dx * dx + dy * dy);
        if (length <= icon_axis_epsilon) return;
        const ux = dx / length;
        const uy = dy / length;
        const radius = iconStroke(bounds, stroke_width) * 0.5;
        const cx = x_cap + ux * radius * 0.5;
        const cy = y_cap + uy * radius * 0.5;
        const span = radius + antialias_width;
        const object_bounds = ui.Rect.init(cx - span, cy - span, span * 2.0, span * 2.0);
        const x_start = clampCoord(@intFromFloat(math.floorF(object_bounds.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(object_bounds.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.x + object_bounds.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.y + object_bounds.h)), self.height);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center - cx;
                const py = @as(f32, @floatFromInt(y)) + pixel_center - cy;
                const along = px * ux + py * uy;
                const across = math.absF(px * -uy + py * ux);
                const outside = @max(math.absF(along) - radius * 0.5, across - radius);
                const alpha = coverageAlpha(0.0, outside);
                if (alpha != 0) self.blendPixelMaxAlpha(x, y, paint.colorAt(bounds, object_bounds, x, y), alpha);
            }
        }
    }

    fn strokeJoinPaint(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, x0n: f32, y0n: f32, x1n: f32, y1n: f32, x2n: f32, y2n: f32) void {
        var local_buffer: [icon_alpha_mask_capacity]u8 = undefined;
        var mask = IconAlphaMask.init(bounds, self.width, self.height, local_buffer[0..]);
        self.strokeJoinMask(&mask, stroke_width, stroke_join, stroke_miter_limit, .{ .x = x0n, .y = y0n }, .{ .x = x1n, .y = y1n }, .{ .x = x2n, .y = y2n }, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
        self.blendIconMaskPaint(&mask, paint, null);
    }

    fn strokePathSegmentMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, stroke_width: f32, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, start: icon_vector.Point, end: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
        if (path.has_segment) {
            self.strokeJoinMask(mask, stroke_width, stroke_join, stroke_miter_limit, path.last_segment_start, start, end, antialias_width_value, coverage_boost);
        } else {
            path.first_segment_start = start;
            path.first_segment_end = end;
            path.first_cap_antialias_width = antialias_width_value;
            path.first_cap_coverage_boost = coverage_boost;
            path.has_segment = true;
        }
        self.strokeSegmentMaskButt(mask, stroke_width, start.x, start.y, end.x, end.y, antialias_width_value, coverage_boost);
        path.last_segment_start = start;
        path.last_segment_end = end;
        path.last_cap_antialias_width = antialias_width_value;
        path.last_cap_coverage_boost = coverage_boost;
        path.segment_count += 1;
    }

    fn finishIconSubpath(self: Surface, mask: *IconAlphaMask, path: *IconPathState, stroke_width: f32, stroke_cap: icon_vector.StrokeCap) void {
        if (!path.has_segment or path.closed) {
            path.clearStroke();
            return;
        }
        if (path.endsAtStart()) {
            path.clearStroke();
            return;
        }
        const single_segment = path.segment_count == 1;
        const cap_antialias_width = if (single_segment) active_icon_tuning.round_cap_antialias_width else path.first_cap_antialias_width;
        const first_cap_boost = if (single_segment) 0.0 else path.first_cap_coverage_boost;
        const last_cap_boost = if (single_segment) 0.0 else path.last_cap_coverage_boost;
        switch (stroke_cap) {
            .butt => {},
            .round => {
                self.strokeRoundPointMask(mask, stroke_width, path.first_segment_start, cap_antialias_width, first_cap_boost);
                self.strokeRoundPointMask(mask, stroke_width, path.last_segment_end, cap_antialias_width, last_cap_boost);
            },
            .square => {
                self.strokeSquareCapMask(mask, stroke_width, path.first_segment_end, path.first_segment_start, active_icon_tuning.stroke_antialias_width, first_cap_boost);
                self.strokeSquareCapMask(mask, stroke_width, path.last_segment_start, path.last_segment_end, active_icon_tuning.stroke_antialias_width, last_cap_boost);
            },
        }
        path.clearStroke();
    }

    fn strokeSegmentMaskButt(self: Surface, mask: *IconAlphaMask, stroke_width: f32, x0n: f32, y0n: f32, x1n: f32, y1n: f32, antialias_width_value: f32, coverage_boost: f32) void {
        _ = self;
        const bounds = mask.bounds;
        const x0 = bounds.x + bounds.w * x0n;
        const y0 = bounds.y + bounds.h * y0n;
        const x1 = bounds.x + bounds.w * x1n;
        const y1 = bounds.y + bounds.h * y1n;
        const radius = iconStroke(bounds, stroke_width) * 0.5;
        const left = @min(x0, x1) - radius;
        const top = @min(y0, y1) - radius;
        const right = @max(x0, x1) + radius;
        const bottom = @max(y0, y1) + radius;
        const x_start = mask.clampX(@intFromFloat(math.floorF(left)));
        const y_start = mask.clampY(@intFromFloat(math.floorF(top)));
        const x_end = mask.clampX(@intFromFloat(math.ceilF(right)));
        const y_end = mask.clampY(@intFromFloat(math.ceilF(bottom)));
        const dx = x1 - x0;
        const dy = y1 - y0;
        const denom = dx * dx + dy * dy;
        if (denom <= 0.0) return;
        const boost_coverage = isSlopedSegment(dx, dy);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + icon_pixel_center;
                const py = @as(f32, @floatFromInt(y)) + icon_pixel_center;
                const t = ((px - x0) * dx + (py - y0) * dy) / denom;
                if (t < 0.0 or t > 1.0) continue;
                const cx = x0 + dx * t;
                const cy = y0 + dy * t;
                const dist = math.sqrtF((px - cx) * (px - cx) + (py - cy) * (py - cy));
                const alpha = strokeCoverageAlpha(radius, dist, antialias_width_value, boost_coverage, coverage_boost);
                if (alpha != 0) mask.writeMax(x, y, alpha);
            }
        }
    }

    fn strokeRoundPointMask(self: Surface, mask: *IconAlphaMask, stroke_width: f32, point: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
        _ = self;
        const bounds = mask.bounds;
        const cx = bounds.x + bounds.w * point.x;
        const cy = bounds.y + bounds.h * point.y;
        const radius = iconStroke(bounds, stroke_width) * 0.5;
        const x_start = mask.clampX(@intFromFloat(math.floorF(cx - radius)));
        const y_start = mask.clampY(@intFromFloat(math.floorF(cy - radius)));
        const x_end = mask.clampX(@intFromFloat(math.ceilF(cx + radius)));
        const y_end = mask.clampY(@intFromFloat(math.ceilF(cy + radius)));
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + icon_pixel_center;
                const py = @as(f32, @floatFromInt(y)) + icon_pixel_center;
                const dx = px - cx;
                const dy = py - cy;
                const dist = math.sqrtF(dx * dx + dy * dy);
                const alpha = strokeCoverageAlpha(radius, dist, antialias_width_value, true, coverage_boost);
                if (alpha != 0) mask.writeMax(x, y, alpha);
            }
        }
    }

    fn strokeSquareCapMask(self: Surface, mask: *IconAlphaMask, stroke_width: f32, inner: icon_vector.Point, cap: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
        _ = self;
        const bounds = mask.bounds;
        const x_inner = bounds.x + bounds.w * inner.x;
        const y_inner = bounds.y + bounds.h * inner.y;
        const x_cap = bounds.x + bounds.w * cap.x;
        const y_cap = bounds.y + bounds.h * cap.y;
        const dx = x_cap - x_inner;
        const dy = y_cap - y_inner;
        const length = math.sqrtF(dx * dx + dy * dy);
        if (length <= icon_axis_epsilon) return;
        const ux = dx / length;
        const uy = dy / length;
        const radius = iconStroke(bounds, stroke_width) * 0.5;
        const cx = x_cap + ux * radius * 0.5;
        const cy = y_cap + uy * radius * 0.5;
        const span = radius + antialias_width_value;
        const x_start = mask.clampX(@intFromFloat(math.floorF(cx - span)));
        const y_start = mask.clampY(@intFromFloat(math.floorF(cy - span)));
        const x_end = mask.clampX(@intFromFloat(math.ceilF(cx + span)));
        const y_end = mask.clampY(@intFromFloat(math.ceilF(cy + span)));
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + icon_pixel_center - cx;
                const py = @as(f32, @floatFromInt(y)) + icon_pixel_center - cy;
                const along = px * ux + py * uy;
                const across = math.absF(px * -uy + py * ux);
                _ = coverage_boost;
                const outside = @max(math.absF(along) - radius * 0.5, across - radius);
                const alpha = coverageAlpha(0.0, outside);
                if (alpha != 0) mask.writeMax(x, y, alpha);
            }
        }
    }

    fn strokeJoinMask(self: Surface, mask: *IconAlphaMask, stroke_width: f32, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, previous: icon_vector.Point, joint: icon_vector.Point, next: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
        switch (stroke_join) {
            .round => self.strokeRoundPointMask(mask, stroke_width, joint, antialias_width_value, coverage_boost),
            .bevel, .miter => self.strokeCornerJoinMask(mask, stroke_width, stroke_join, stroke_miter_limit, previous, joint, next),
        }
    }

    fn strokeCornerJoinMask(self: Surface, mask: *IconAlphaMask, stroke_width: f32, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, previous: icon_vector.Point, joint: icon_vector.Point, next: icon_vector.Point) void {
        const bounds = mask.bounds;
        const p0 = pointToPixels(bounds, previous);
        const p1 = pointToPixels(bounds, joint);
        const p2 = pointToPixels(bounds, next);
        const incoming = unitVector(p1, p0) orelse return;
        const outgoing = unitVector(p2, p1) orelse return;
        const turn = cross2(incoming, outgoing);
        if (math.absF(turn) <= icon_axis_epsilon) return;
        const side: f32 = if (turn > 0.0) -1.0 else 1.0;
        const n0 = icon_vector.Point{ .x = -incoming.y * side, .y = incoming.x * side };
        const n1 = icon_vector.Point{ .x = -outgoing.y * side, .y = outgoing.x * side };
        const radius = iconStroke(bounds, stroke_width) * 0.5;
        const a = icon_vector.Point{ .x = p1.x + n0.x * radius, .y = p1.y + n0.y * radius };
        const c = icon_vector.Point{ .x = p1.x + n1.x * radius, .y = p1.y + n1.y * radius };
        const b = switch (stroke_join) {
            .bevel => p1,
            .round => unreachable,
            .miter => miterPoint(p1, incoming, outgoing, n0, n1, radius, stroke_miter_limit) orelse p1,
        };
        self.fillTriangleMask(mask, a, b, c);
    }

    fn fillTriangleMask(self: Surface, mask: *IconAlphaMask, a: icon_vector.Point, b: icon_vector.Point, c: icon_vector.Point) void {
        _ = self;
        const left = @min(a.x, @min(b.x, c.x));
        const top = @min(a.y, @min(b.y, c.y));
        const right = @max(a.x, @max(b.x, c.x));
        const bottom = @max(a.y, @max(b.y, c.y));
        const x_start = mask.clampX(@intFromFloat(math.floorF(left - antialias_width)));
        const y_start = mask.clampY(@intFromFloat(math.floorF(top - antialias_width)));
        const x_end = mask.clampX(@intFromFloat(math.ceilF(right + antialias_width)));
        const y_end = mask.clampY(@intFromFloat(math.ceilF(bottom + antialias_width)));
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + icon_pixel_center;
                const py = @as(f32, @floatFromInt(y)) + icon_pixel_center;
                if (pointInTriangle(.{ .x = px, .y = py }, a, b, c)) mask.writeMax(x, y, max_alpha);
            }
        }
    }

    fn strokeQuadraticPathMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, stroke_width: f32, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, start: icon_vector.Point, control: icon_vector.Point, end: icon_vector.Point) void {
        var previous = start;
        const curve_segments = active_icon_tuning.curve_segments;
        var step: usize = 1;
        while (step <= curve_segments) : (step += 1) {
            const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(curve_segments));
            const mt = 1.0 - t;
            const next = icon_vector.Point{
                .x = mt * mt * start.x + 2.0 * mt * t * control.x + t * t * end.x,
                .y = mt * mt * start.y + 2.0 * mt * t * control.y + t * t * end.y,
            };
            self.strokePathSegmentMask(mask, path, stroke_width, stroke_join, stroke_miter_limit, previous, next, active_icon_tuning.stroke_antialias_width, active_icon_tuning.curve_stroke_coverage_boost);
            previous = next;
        }
    }

    fn strokeCubicPathMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, stroke_width: f32, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, start: icon_vector.Point, control0: icon_vector.Point, control1: icon_vector.Point, end: icon_vector.Point) void {
        var previous = start;
        const curve_segments = active_icon_tuning.curve_segments;
        var step: usize = 1;
        while (step <= curve_segments) : (step += 1) {
            const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(curve_segments));
            const mt = 1.0 - t;
            const next = icon_vector.Point{
                .x = mt * mt * mt * start.x + 3.0 * mt * mt * t * control0.x + 3.0 * mt * t * t * control1.x + t * t * t * end.x,
                .y = mt * mt * mt * start.y + 3.0 * mt * mt * t * control0.y + 3.0 * mt * t * t * control1.y + t * t * t * end.y,
            };
            self.strokePathSegmentMask(mask, path, stroke_width, stroke_join, stroke_miter_limit, previous, next, active_icon_tuning.stroke_antialias_width, active_icon_tuning.curve_stroke_coverage_boost);
            previous = next;
        }
    }

    fn strokeArcPathMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, stroke_width: f32, stroke_join: icon_vector.StrokeJoin, stroke_miter_limit: f32, start: icon_vector.Point, arc: icon_vector.Arc) void {
        const geometry = svgArcGeometry(start, arc) orelse {
            self.strokePathSegmentMask(mask, path, stroke_width, stroke_join, stroke_miter_limit, start, arc.end, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
            return;
        };
        const steps = arcStepCount(geometry.delta, arc);
        const arc_antialias_width = arcAntialiasWidth(arc);
        var previous = start;
        var step: usize = 1;
        while (step <= steps) : (step += 1) {
            const next = geometry.pointAt(step, steps);
            self.strokePathSegmentMask(mask, path, stroke_width, stroke_join, stroke_miter_limit, previous, next, arc_antialias_width, active_icon_tuning.arc_stroke_coverage_boost);
            previous = next;
        }
    }

    fn fillQuadraticPath(self: Surface, path: *IconPathState, start: icon_vector.Point, control: icon_vector.Point, end: icon_vector.Point) void {
        _ = self;
        var step: usize = 1;
        while (step <= active_icon_tuning.curve_segments) : (step += 1) {
            const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(active_icon_tuning.curve_segments));
            const mt = 1.0 - t;
            path.fillLineTo(.{
                .x = mt * mt * start.x + 2.0 * mt * t * control.x + t * t * end.x,
                .y = mt * mt * start.y + 2.0 * mt * t * control.y + t * t * end.y,
            });
        }
    }

    fn fillCubicPath(self: Surface, path: *IconPathState, start: icon_vector.Point, control0: icon_vector.Point, control1: icon_vector.Point, end: icon_vector.Point) void {
        _ = self;
        var step: usize = 1;
        while (step <= active_icon_tuning.curve_segments) : (step += 1) {
            const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(active_icon_tuning.curve_segments));
            const mt = 1.0 - t;
            path.fillLineTo(.{
                .x = mt * mt * mt * start.x + 3.0 * mt * mt * t * control0.x + 3.0 * mt * t * t * control1.x + t * t * t * end.x,
                .y = mt * mt * mt * start.y + 3.0 * mt * mt * t * control0.y + 3.0 * mt * t * t * control1.y + t * t * t * end.y,
            });
        }
    }

    fn fillArcPath(self: Surface, path: *IconPathState, start: icon_vector.Point, arc: icon_vector.Arc) void {
        const geometry = svgArcGeometry(start, arc) orelse {
            path.fillLineTo(arc.end);
            return;
        };
        const steps = arcStepCount(geometry.delta, arc);
        var step: usize = 1;
        while (step <= steps) : (step += 1) path.fillLineTo(geometry.pointAt(step, steps));
        _ = self;
    }

    fn fillIconPath(self: Surface, bounds: ui.Rect, paint: IconPaint, path: *const IconPathState, clip: *const IconClipState) void {
        if (path.fill_point_len < min_fill_path_points) return;
        const paint_bounds = fillPathPaintBounds(bounds, path);
        const x_start = clampCoord(@intFromFloat(math.floorF(bounds.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(bounds.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(bounds.x + bounds.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(bounds.y + bounds.h)), self.height);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const coverage = self.fillPathCoverage(bounds, path, x, y);
                if (coverage != 0) self.blendPixel(x, y, paint.colorAt(bounds, paint_bounds, x, y), clip.apply(x, y, coverage));
            }
        }
    }

    fn fillClipPathMask(self: Surface, bounds: ui.Rect, path: *const IconPathState, clip_mask: *IconAlphaMask) void {
        if (path.fill_point_len < min_fill_path_points) return;
        const x_start = clampCoord(@intFromFloat(math.floorF(bounds.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(bounds.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(bounds.x + bounds.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(bounds.y + bounds.h)), self.height);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const coverage = self.fillPathCoverage(bounds, path, x, y);
                if (coverage != 0) clip_mask.writeMax(x, y, coverage);
            }
        }
    }

    fn fillPathCoverage(self: Surface, bounds: ui.Rect, path: *const IconPathState, x: usize, y: usize) u8 {
        _ = self;
        var inside_samples: usize = 0;
        for (fill_sample_offsets) |offset| {
            const nx = (@as(f32, @floatFromInt(x)) + offset.x - bounds.x) / bounds.w;
            const ny = (@as(f32, @floatFromInt(y)) + offset.y - bounds.y) / bounds.h;
            if (pathContainsPoint(path, .{ .x = nx, .y = ny })) inside_samples += 1;
        }
        return @intCast((inside_samples * max_alpha) / fill_sample_offsets.len);
    }

    fn fillPathPaintBounds(bounds: ui.Rect, path: *const IconPathState) ui.Rect {
        if (path.fill_point_len == 0) return bounds;
        var min_x = path.fill_points[0].x;
        var min_y = path.fill_points[0].y;
        var max_x = path.fill_points[0].x;
        var max_y = path.fill_points[0].y;
        var index: usize = 1;
        while (index < path.fill_point_len) : (index += 1) {
            const point = path.fill_points[index];
            min_x = @min(min_x, point.x);
            min_y = @min(min_y, point.y);
            max_x = @max(max_x, point.x);
            max_y = @max(max_y, point.y);
        }
        return ui.Rect.init(
            bounds.x + bounds.w * min_x,
            bounds.y + bounds.h * min_y,
            bounds.w * @max(max_x - min_x, icon_axis_epsilon),
            bounds.h * @max(max_y - min_y, icon_axis_epsilon),
        );
    }

    fn blendIconMask(self: Surface, mask: *const IconAlphaMask, color: ui.Color) void {
        self.blendIconMaskPaint(mask, .{ .solid = color }, null);
    }

    fn blendIconMaskPaint(self: Surface, mask: *const IconAlphaMask, paint: IconPaint, clip: ?*const IconClipState) void {
        var row: usize = 0;
        while (row < mask.height) : (row += 1) {
            var col: usize = 0;
            while (col < mask.width) : (col += 1) {
                const raw_alpha = mask.pixels[row * mask.width + col];
                const x = mask.x + col;
                const y = mask.y + row;
                const alpha = if (clip) |active_clip| active_clip.apply(x, y, raw_alpha) else raw_alpha;
                if (alpha > icon_alpha_floor) self.blendPixelPathAlpha(x, y, paint.colorAt(mask.bounds, mask.bounds, x, y), alpha);
            }
        }
    }

    fn strokeEllipse(self: Surface, bounds: ui.Rect, color: ui.Color, stroke_width: f32, x: f32, y: f32, rx: f32, ry: f32, full: bool) void {
        const cx = bounds.x + bounds.w * x;
        const cy = bounds.y + bounds.h * y;
        const radius_x = bounds.w * rx;
        const radius_y = bounds.h * ry;
        const stroke = iconStroke(bounds, stroke_width);
        const area = ui.Rect.init(cx - radius_x - stroke, cy - radius_y - stroke, (radius_x + stroke) * 2.0, (radius_y + stroke) * 2.0);
        const x_start = clampCoord(@intFromFloat(math.floorF(area.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(area.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(area.x + area.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(area.y + area.h)), self.height);
        var py_i = y_start;
        while (py_i < y_end) : (py_i += 1) {
            var px_i = x_start;
            while (px_i < x_end) : (px_i += 1) {
                const px = @as(f32, @floatFromInt(px_i)) + pixel_center;
                const py = @as(f32, @floatFromInt(py_i)) + pixel_center;
                if (!full and py < cy) continue;
                const nx = (px - cx) / @max(1.0, radius_x);
                const ny = (py - cy) / @max(1.0, radius_y);
                const distance = math.absF(math.sqrtF(nx * nx + ny * ny) - 1.0) * @min(radius_x, radius_y);
                const alpha = coverageAlpha(stroke * 0.5, distance);
                if (alpha != 0) self.blendPixel(px_i, py_i, color, alpha);
            }
        }
    }

    fn strokeEllipsePaint(self: Surface, bounds: ui.Rect, paint: IconPaint, stroke_width: f32, x: f32, y: f32, rx: f32, ry: f32, full: bool) void {
        const cx = bounds.x + bounds.w * x;
        const cy = bounds.y + bounds.h * y;
        const radius_x = bounds.w * rx;
        const radius_y = bounds.h * ry;
        const stroke = iconStroke(bounds, stroke_width);
        const object_bounds = ui.Rect.init(cx - radius_x - stroke, cy - radius_y - stroke, (radius_x + stroke) * 2.0, (radius_y + stroke) * 2.0);
        const x_start = clampCoord(@intFromFloat(math.floorF(object_bounds.x)), self.width);
        const y_start = clampCoord(@intFromFloat(math.floorF(object_bounds.y)), self.height);
        const x_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.x + object_bounds.w)), self.width);
        const y_end = clampCoord(@intFromFloat(math.ceilF(object_bounds.y + object_bounds.h)), self.height);
        var py_i = y_start;
        while (py_i < y_end) : (py_i += 1) {
            var px_i = x_start;
            while (px_i < x_end) : (px_i += 1) {
                const px = @as(f32, @floatFromInt(px_i)) + pixel_center;
                const py = @as(f32, @floatFromInt(py_i)) + pixel_center;
                if (!full and py < cy) continue;
                const nx = (px - cx) / @max(1.0, radius_x);
                const ny = (py - cy) / @max(1.0, radius_y);
                const distance = math.absF(math.sqrtF(nx * nx + ny * ny) - 1.0) * @min(radius_x, radius_y);
                const alpha = coverageAlpha(stroke * 0.5, distance);
                if (alpha != 0) self.blendPixel(px_i, py_i, paint.colorAt(bounds, object_bounds, px_i, py_i), alpha);
            }
        }
    }

    fn fillPieSlice(self: Surface, bounds: ui.Rect, color: ui.Color, encoded_angles: ui.Color) void {
        const x0 = clampCoord(@intFromFloat(math.floorF(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(math.floorF(bounds.y)), self.height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(bounds.x + bounds.w)), self.width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(bounds.y + bounds.h)), self.height);
        if (x1 <= x0 or y1 <= y0) return;

        const start_turn = byteUnit(encoded_angles.r);
        const end_turn = byteUnit(encoded_angles.g);
        const cx = bounds.x + bounds.w * 0.5;
        const cy = bounds.y + bounds.h * 0.5;
        const radius = @min(bounds.w, bounds.h) * 0.5;

        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + pixel_center;
                const py = @as(f32, @floatFromInt(y)) + pixel_center;
                const dx = px - cx;
                const dy = py - cy;
                const distance = math.sqrtF(dx * dx + dy * dy);
                if (distance > radius) continue;
                const turn = clockwiseTurn(dx, dy);
                if (turn < start_turn or turn > end_turn) continue;
                const alpha = coverageAlpha(radius, distance);
                if (alpha != 0) self.blendPixel(x, y, color, alpha);
            }
        }
    }
};

const IconAlphaMask = struct {
    bounds: ui.Rect,
    x: usize,
    y: usize,
    width: usize,
    height: usize,
    pixels: []u8,

    fn init(bounds: ui.Rect, surface_width: usize, surface_height: usize, buffer: []u8) IconAlphaMask {
        @setRuntimeSafety(false);
        const pad = iconStroke(bounds, icon_mask_pad_scale);
        const x0 = clampCoord(@intFromFloat(math.floorF(bounds.x - pad)), surface_width);
        const y0 = clampCoord(@intFromFloat(math.floorF(bounds.y - pad)), surface_height);
        const x1 = clampCoord(@intFromFloat(math.ceilF(bounds.x + bounds.w + pad)), surface_width);
        const y1 = clampCoord(@intFromFloat(math.ceilF(bounds.y + bounds.h + pad)), surface_height);
        const width = x1 - x0;
        const height = y1 - y0;
        const length = width * height;
        @memset(buffer[0..length], 0);
        return .{
            .bounds = bounds,
            .x = x0,
            .y = y0,
            .width = width,
            .height = height,
            .pixels = buffer[0..length],
        };
    }

    fn clampX(self: IconAlphaMask, value: isize) usize {
        return clampMaskCoord(value, self.x, self.x + self.width);
    }

    fn clampY(self: IconAlphaMask, value: isize) usize {
        return clampMaskCoord(value, self.y, self.y + self.height);
    }

    fn writeMax(self: *IconAlphaMask, x_value: usize, y_value: usize, alpha: u8) void {
        if (x_value < self.x or y_value < self.y) return;
        const local_x = x_value - self.x;
        const local_y = y_value - self.y;
        if (local_x >= self.width or local_y >= self.height) return;
        const index = local_y * self.width + local_x;
        if (alpha > self.pixels[index]) self.pixels[index] = alpha;
    }

    fn read(self: *const IconAlphaMask, x_value: usize, y_value: usize) u8 {
        if (x_value < self.x or y_value < self.y) return 0;
        const local_x = x_value - self.x;
        const local_y = y_value - self.y;
        if (local_x >= self.width or local_y >= self.height) return 0;
        return self.pixels[local_y * self.width + local_x];
    }

    fn clear(self: *IconAlphaMask) void {
        @memset(self.pixels, 0);
    }
};

const IconClipState = struct {
    mask: *IconAlphaMask,
    active: bool = false,
    building: bool = false,

    fn begin(self: *IconClipState) void {
        self.mask.clear();
        self.active = false;
        self.building = true;
    }

    fn end(self: *IconClipState) void {
        self.building = false;
        self.active = true;
    }

    fn clear(self: *IconClipState) void {
        self.mask.clear();
        self.active = false;
        self.building = false;
    }

    fn apply(self: *const IconClipState, x: usize, y: usize, alpha: u8) u8 {
        if (!self.active or alpha == 0) return alpha;
        const clip_alpha = self.mask.read(x, y);
        return @intCast((@as(u16, alpha) * @as(u16, clip_alpha) + 127) / 255);
    }
};

const default_raster_scale: f32 = 1.0;
const max_alpha: u8 = 255;
const pixel_center: f32 = 0.5;
const icon_pixel_center: f32 = 0.5;
const min_border_width: f32 = 1.0;
const quarter_turn: f32 = 0.25;
const byte_unit_scale: f32 = 255.0;
const cpu_shadow_alpha: f32 = 0.34;
fn iconStroke(bounds: ui.Rect, stroke_width: f32) f32 {
    return @max(icon_stroke_min_px, @min(bounds.w, bounds.h) * stroke_width);
}

fn iconMaskAxis(value: f32) usize {
    if (value <= 1.0) return 1;
    return @min(renderer_icon_mask.max_width, @max(@as(usize, 1), @as(usize, @intFromFloat(math.ceilF(value)))));
}

const icon_stroke_scale: f32 = 2.0 / 24.0;
const icon_stroke_min_px: f32 = 1.5;
const icon_mask_pad_scale: f32 = 1.0;
const icon_stroke_antialias_width_default: f32 = 0.5;
const icon_stroke_round_cap_antialias_width_default: f32 = 0.588086;
const icon_stroke_antialias_width_min: f32 = 0.4;
const icon_stroke_antialias_width_max: f32 = 0.75;
const icon_arc_antialias_width_default: f32 = 0.54;
const icon_large_arc_antialias_width_default: f32 = 0.66;
const icon_large_arc_radius_threshold: f32 = 0.25;
const icon_arc_antialias_width_min: f32 = 0.4;
const icon_arc_antialias_width_max: f32 = 0.7;
const icon_stroke_coverage_boost_floor: f32 = 0.5;
const icon_line_stroke_coverage_boost_default: f32 = 1.2;
const icon_curve_stroke_coverage_boost_default: f32 = 0.05;
const icon_arc_stroke_coverage_boost_default: f32 = 1.4;
const icon_stroke_coverage_boost_min: f32 = 0.0;
const icon_stroke_coverage_boost_max: f32 = 2.0;
const icon_axis_epsilon: f32 = 0.00001;
const svg_miter_limit_default: f32 = 4.0;
const icon_closed_subpath_epsilon_squared: f32 = 0.00000001;
const icon_alpha_floor: u8 = 1;
const icon_curve_segments_default: usize = 4;
const icon_curve_segments_min: usize = 2;
const icon_curve_segments_max: usize = 64;
const icon_arc_step_divisor_default: f32 = 40.0;
const icon_large_arc_step_divisor_default: f32 = 10.0;
const icon_arc_step_divisor_min: f32 = 8.0;
const icon_arc_step_divisor_max: f32 = 64.0;
const icon_alpha_mask_capacity: usize = 512 * 512;
const svg_arc_denominator_min: f32 = 0.000001;
const max_fill_path_points: usize = 512;
const max_fill_path_subpaths: usize = 64;
const min_fill_path_points: usize = 3;
const fill_sample_offsets = [_]icon_vector.Point{
    .{ .x = 0.25, .y = 0.25 },
    .{ .x = 0.75, .y = 0.25 },
    .{ .x = 0.25, .y = 0.75 },
    .{ .x = 0.75, .y = 0.75 },
};

const FillRule = enum {
    nonzero,
    evenodd,
};

const IconPathState = struct {
    current: ?icon_vector.Point = null,
    start: ?icon_vector.Point = null,
    first_segment_start: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    first_segment_end: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    last_segment_start: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    last_segment_end: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    first_cap_antialias_width: f32 = icon_stroke_antialias_width_default,
    first_cap_coverage_boost: f32 = icon_line_stroke_coverage_boost_default,
    last_cap_antialias_width: f32 = icon_stroke_antialias_width_default,
    last_cap_coverage_boost: f32 = icon_line_stroke_coverage_boost_default,
    segment_count: usize = 0,
    has_segment: bool = false,
    closed: bool = false,
    fill_active: bool = false,
    fill_rule: FillRule = .nonzero,
    fill_points: [max_fill_path_points]icon_vector.Point = undefined,
    fill_subpaths: [max_fill_path_subpaths]usize = undefined,
    fill_point_len: usize = 0,
    fill_subpath_len: usize = 0,

    fn moveTo(self: *IconPathState, point: icon_vector.Point) void {
        self.current = point;
        self.start = point;
        self.clearStroke();
    }

    fn lineTo(self: *IconPathState, point: icon_vector.Point) void {
        self.current = point;
    }

    fn beginFill(self: *IconPathState, fill_rule: FillRule) void {
        self.clearStroke();
        self.current = null;
        self.start = null;
        self.fill_active = true;
        self.fill_rule = fill_rule;
        self.fill_point_len = 0;
        self.fill_subpath_len = 0;
    }

    fn fillMoveTo(self: *IconPathState, point: icon_vector.Point) void {
        if (self.fill_subpath_len >= self.fill_subpaths.len) unreachable;
        self.fill_subpaths[self.fill_subpath_len] = self.fill_point_len;
        self.fill_subpath_len += 1;
        self.current = point;
        self.start = point;
        self.appendFillPoint(point);
    }

    fn fillLineTo(self: *IconPathState, point: icon_vector.Point) void {
        if (self.fill_subpath_len == 0) self.fillMoveTo(point) else self.appendFillPoint(point);
        self.current = point;
    }

    fn closeFillSubpath(self: *IconPathState) void {
        if (self.start) |start_point| self.current = start_point;
    }

    fn clearFill(self: *IconPathState) void {
        self.fill_active = false;
        self.fill_rule = .nonzero;
        self.fill_point_len = 0;
        self.fill_subpath_len = 0;
        self.current = null;
        self.start = null;
    }

    fn appendFillPoint(self: *IconPathState, point: icon_vector.Point) void {
        if (self.fill_point_len >= self.fill_points.len) unreachable;
        self.fill_points[self.fill_point_len] = point;
        self.fill_point_len += 1;
    }

    fn clearStroke(self: *IconPathState) void {
        self.first_segment_start = .{ .x = 0.0, .y = 0.0 };
        self.first_segment_end = .{ .x = 0.0, .y = 0.0 };
        self.last_segment_start = .{ .x = 0.0, .y = 0.0 };
        self.last_segment_end = .{ .x = 0.0, .y = 0.0 };
        self.first_cap_antialias_width = icon_stroke_antialias_width_default;
        self.first_cap_coverage_boost = icon_line_stroke_coverage_boost_default;
        self.last_cap_antialias_width = icon_stroke_antialias_width_default;
        self.last_cap_coverage_boost = icon_line_stroke_coverage_boost_default;
        self.segment_count = 0;
        self.has_segment = false;
        self.closed = false;
    }

    fn endsAtStart(self: IconPathState) bool {
        const dx = self.last_segment_end.x - self.first_segment_start.x;
        const dy = self.last_segment_end.y - self.first_segment_start.y;
        return dx * dx + dy * dy <= icon_closed_subpath_epsilon_squared;
    }
};

const SvgArcGeometry = struct {
    center: icon_vector.Point,
    rx: f32,
    ry: f32,
    cos_phi: f32,
    sin_phi: f32,
    start_angle: f32,
    delta: f32,

    fn pointAt(self: SvgArcGeometry, step: usize, steps: usize) icon_vector.Point {
        const angle = self.start_angle + self.delta * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(steps));
        const xp = self.rx * @cos(angle);
        const yp = self.ry * @sin(angle);
        return .{
            .x = self.center.x + self.cos_phi * xp - self.sin_phi * yp,
            .y = self.center.y + self.sin_phi * xp + self.cos_phi * yp,
        };
    }
};

fn svgArcGeometry(start: icon_vector.Point, arc: icon_vector.Arc) ?SvgArcGeometry {
    const rx_start = math.absF(arc.rx);
    const ry_start = math.absF(arc.ry);
    if (rx_start <= 0.0 or ry_start <= 0.0) return null;
    const phi = arc.x_axis_rotation * math.pi / 180.0;
    const cos_phi = @cos(phi);
    const sin_phi = @sin(phi);
    const dx = (start.x - arc.end.x) * 0.5;
    const dy = (start.y - arc.end.y) * 0.5;
    const x1p = cos_phi * dx + sin_phi * dy;
    const y1p = -sin_phi * dx + cos_phi * dy;
    var rx = rx_start;
    var ry = ry_start;
    const radius_scale = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry);
    if (radius_scale > 1.0) {
        const scale = math.sqrtF(radius_scale);
        rx *= scale;
        ry *= scale;
    }
    const numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    const denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    const sign: f32 = if (arc.large_arc == arc.sweep) -1.0 else 1.0;
    const coefficient = sign * math.sqrtF(@max(0.0, numerator / @max(denominator, svg_arc_denominator_min)));
    const cxp = coefficient * rx * y1p / ry;
    const cyp = coefficient * -ry * x1p / rx;
    const center = icon_vector.Point{
        .x = cos_phi * cxp - sin_phi * cyp + (start.x + arc.end.x) * 0.5,
        .y = sin_phi * cxp + cos_phi * cyp + (start.y + arc.end.y) * 0.5,
    };
    const v0 = icon_vector.Point{ .x = (x1p - cxp) / rx, .y = (y1p - cyp) / ry };
    const v1 = icon_vector.Point{ .x = (-x1p - cxp) / rx, .y = (-y1p - cyp) / ry };
    const start_angle = vectorAngle(.{ .x = 1.0, .y = 0.0 }, v0);
    var delta = vectorAngle(v0, v1);
    if (!arc.sweep and delta > 0.0) delta -= math.tau;
    if (arc.sweep and delta < 0.0) delta += math.tau;
    return .{
        .center = center,
        .rx = rx,
        .ry = ry,
        .cos_phi = cos_phi,
        .sin_phi = sin_phi,
        .start_angle = start_angle,
        .delta = delta,
    };
}

fn arcStepCount(delta: f32, arc: icon_vector.Arc) usize {
    const divisor = if (arc.large_arc) active_icon_tuning.large_arc_step_divisor else active_icon_tuning.arc_step_divisor;
    return @max(4, @as(usize, @intFromFloat(math.ceilF(math.absF(delta) * divisor / math.pi))));
}

fn arcAntialiasWidth(arc: icon_vector.Arc) f32 {
    if (@max(arc.rx, arc.ry) >= icon_large_arc_radius_threshold) return active_icon_tuning.large_arc_antialias_width;
    return active_icon_tuning.arc_antialias_width;
}

fn vectorAngle(left: icon_vector.Point, right: icon_vector.Point) f32 {
    const dot = left.x * right.x + left.y * right.y;
    const det = left.x * right.y - left.y * right.x;
    return math.atan2F(det, dot);
}

fn pointToPixels(bounds: ui.Rect, point: icon_vector.Point) icon_vector.Point {
    return .{
        .x = bounds.x + bounds.w * point.x,
        .y = bounds.y + bounds.h * point.y,
    };
}

fn unitVector(to: icon_vector.Point, from: icon_vector.Point) ?icon_vector.Point {
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const length = math.sqrtF(dx * dx + dy * dy);
    if (length <= icon_axis_epsilon) return null;
    return .{ .x = dx / length, .y = dy / length };
}

fn cross2(left: icon_vector.Point, right: icon_vector.Point) f32 {
    return left.x * right.y - left.y * right.x;
}

fn miterPoint(joint: icon_vector.Point, incoming: icon_vector.Point, outgoing: icon_vector.Point, incoming_normal: icon_vector.Point, outgoing_normal: icon_vector.Point, radius: f32, miter_limit: f32) ?icon_vector.Point {
    const a = icon_vector.Point{ .x = joint.x + incoming_normal.x * radius, .y = joint.y + incoming_normal.y * radius };
    const b = icon_vector.Point{ .x = joint.x + outgoing_normal.x * radius, .y = joint.y + outgoing_normal.y * radius };
    const denom = cross2(incoming, outgoing);
    if (math.absF(denom) <= icon_axis_epsilon) return null;
    const delta = icon_vector.Point{ .x = b.x - a.x, .y = b.y - a.y };
    const t = cross2(delta, outgoing) / denom;
    const point = icon_vector.Point{ .x = a.x + incoming.x * t, .y = a.y + incoming.y * t };
    const mx = point.x - joint.x;
    const my = point.y - joint.y;
    if (mx * mx + my * my > radius * radius * miter_limit * miter_limit) return null;
    return point;
}

fn pointInTriangle(point: icon_vector.Point, a: icon_vector.Point, b: icon_vector.Point, c: icon_vector.Point) bool {
    const ab = cross2(.{ .x = b.x - a.x, .y = b.y - a.y }, .{ .x = point.x - a.x, .y = point.y - a.y });
    const bc = cross2(.{ .x = c.x - b.x, .y = c.y - b.y }, .{ .x = point.x - b.x, .y = point.y - b.y });
    const ca = cross2(.{ .x = a.x - c.x, .y = a.y - c.y }, .{ .x = point.x - c.x, .y = point.y - c.y });
    return (ab >= 0.0 and bc >= 0.0 and ca >= 0.0) or (ab <= 0.0 and bc <= 0.0 and ca <= 0.0);
}

fn coverageAlpha(radius: f32, distance: f32) u8 {
    if (distance <= radius - antialias_width) return max_alpha;
    if (distance >= radius + antialias_width) return 0;
    const coverage = (radius + antialias_width - distance) / (antialias_width * 2.0);
    return @intCast(math.lrintF(math.clampF(coverage, 0.0, 1.0) * 255.0));
}

fn isSlopedSegment(dx: f32, dy: f32) bool {
    return math.absF(dx) > icon_axis_epsilon and math.absF(dy) > icon_axis_epsilon;
}

fn strokeCoverageAlpha(radius: f32, distance: f32, antialias_width_value: f32, boost_coverage: bool, coverage_boost: f32) u8 {
    if (distance <= radius - antialias_width_value) return max_alpha;
    if (distance >= radius + antialias_width_value) return 0;
    const t = (radius + antialias_width_value - distance) / (antialias_width_value * 2.0);
    const coverage = if (boost_coverage and t > icon_stroke_coverage_boost_floor)
        t + coverage_boost * (t - icon_stroke_coverage_boost_floor) * (1.0 - t)
    else
        t;
    return @intCast(math.lrintF(math.clampF(coverage, 0.0, 1.0) * 255.0));
}

fn pathContainsPoint(path: *const IconPathState, point: icon_vector.Point) bool {
    return switch (path.fill_rule) {
        .nonzero => pathContainsPointNonzero(path, point),
        .evenodd => pathContainsPointEvenOdd(path, point),
    };
}

fn pathContainsPointNonzero(path: *const IconPathState, point: icon_vector.Point) bool {
    var winding: isize = 0;
    var subpath_index: usize = 0;
    while (subpath_index < path.fill_subpath_len) : (subpath_index += 1) {
        const start = path.fill_subpaths[subpath_index];
        const end = if (subpath_index + 1 < path.fill_subpath_len) path.fill_subpaths[subpath_index + 1] else path.fill_point_len;
        if (end <= start + 1) continue;
        var previous = path.fill_points[end - 1];
        var index = start;
        while (index < end) : (index += 1) {
            const current = path.fill_points[index];
            if (previous.y <= point.y) {
                if (current.y > point.y and isLeftOfEdge(previous, current, point) > 0.0) winding += 1;
            } else if (current.y <= point.y and isLeftOfEdge(previous, current, point) < 0.0) {
                winding -= 1;
            }
            previous = current;
        }
    }
    return winding != 0;
}

fn pathContainsPointEvenOdd(path: *const IconPathState, point: icon_vector.Point) bool {
    var crossings: usize = 0;
    var subpath_index: usize = 0;
    while (subpath_index < path.fill_subpath_len) : (subpath_index += 1) {
        const start = path.fill_subpaths[subpath_index];
        const end = if (subpath_index + 1 < path.fill_subpath_len) path.fill_subpaths[subpath_index + 1] else path.fill_point_len;
        if (end <= start + 1) continue;
        var previous = path.fill_points[end - 1];
        var index = start;
        while (index < end) : (index += 1) {
            const current = path.fill_points[index];
            if ((previous.y > point.y) != (current.y > point.y)) {
                const intersection_x = previous.x + (point.y - previous.y) * (current.x - previous.x) / (current.y - previous.y);
                if (intersection_x > point.x) crossings += 1;
            }
            previous = current;
        }
    }
    return crossings % 2 == 1;
}

fn isLeftOfEdge(start: icon_vector.Point, end: icon_vector.Point, point: icon_vector.Point) f32 {
    return (end.x - start.x) * (point.y - start.y) - (point.x - start.x) * (end.y - start.y);
}

fn roundedAlpha(bounds: ui.Rect, radius: f32, x: f32, y: f32) u8 {
    const distance = roundedOutsideDistance(bounds, radius, x, y);
    const coverage = math.clampF(-distance / antialias_width, 0.0, 1.0);
    return @intFromFloat(math.floorF(coverage * 255.0 + 0.5));
}

fn roundedBorderAlpha(outer_alpha: u8, inner: ui.Rect, inner_radius: f32, x: f32, y: f32) u8 {
    if (outer_alpha == 0) return 0;
    if (!inner.valid()) return outer_alpha;
    const inner_distance = roundedOutsideDistance(inner, inner_radius, x, y);
    const gate = math.clampF(inner_distance / antialias_width, 0.0, 1.0);
    return scaleByte(outer_alpha, gate);
}

fn roundedOutsideDistance(bounds: ui.Rect, radius: f32, x: f32, y: f32) f32 {
    const r = @min(@max(radius, 0.0), @max(0.0, @min(bounds.w, bounds.h) * 0.5));
    const half_w = bounds.w * 0.5;
    const half_h = bounds.h * 0.5;
    const center_x = bounds.x + half_w;
    const center_y = bounds.y + half_h;
    const qx = math.absF(x - center_x) - @max(0.0, half_w - r);
    const qy = math.absF(y - center_y) - @max(0.0, half_h - r);
    const outside_x = @max(qx, 0.0);
    const outside_y = @max(qy, 0.0);
    const outside = math.sqrtF(outside_x * outside_x + outside_y * outside_y);
    const inside = @min(@max(qx, qy), 0.0);
    return outside + inside - r;
}

fn clampRange(value: f32, lower: f32, upper: f32) f32 {
    if (lower > upper) return (lower + upper) * 0.5;
    return math.clampF(value, lower, upper);
}

fn gradientMix(bounds: ui.Rect, y: f32) f32 {
    if (bounds.h <= 0.0) return 0.0;
    return math.clampF((y - bounds.y) / bounds.h, 0.0, 1.0);
}

fn gradientColorAt(gradient: icon_vector.LinearGradient, icon_bounds: ui.Rect, object_bounds: ui.Rect, x: usize, y: usize) ui.Color {
    const bounds = switch (gradient.coordinate_space) {
        .object_bounding_box => object_bounds,
        .user_space => icon_bounds,
    };
    const x1 = bounds.x + bounds.w * gradient.x1;
    const y1 = bounds.y + bounds.h * gradient.y1;
    const x2 = bounds.x + bounds.w * gradient.x2;
    const y2 = bounds.y + bounds.h * gradient.y2;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const length_squared = dx * dx + dy * dy;
    const last_stop = gradient.stops[gradient.stop_count - 1];
    if (length_squared <= icon_axis_epsilon) return paintToColor(last_stop.color);
    const px = @as(f32, @floatFromInt(x)) + pixel_center;
    const py = @as(f32, @floatFromInt(y)) + pixel_center;
    const projected = ((px - x1) * dx + (py - y1) * dy) / length_squared;
    return gradientStopsColorAt(gradient.stops[0..gradient.stop_count], gradient.spread, projected);
}

fn radialGradientColorAt(gradient: icon_vector.RadialGradient, icon_bounds: ui.Rect, object_bounds: ui.Rect, x: usize, y: usize) ui.Color {
    const bounds = switch (gradient.coordinate_space) {
        .object_bounding_box => object_bounds,
        .user_space => icon_bounds,
    };
    const cx = bounds.x + bounds.w * gradient.cx;
    const cy = bounds.y + bounds.h * gradient.cy;
    const radius = @min(bounds.w, bounds.h) * gradient.radius;
    const fx = bounds.x + bounds.w * gradient.fx;
    const fy = bounds.y + bounds.h * gradient.fy;
    const focal_radius = @min(bounds.w, bounds.h) * gradient.focal_radius;
    const px = @as(f32, @floatFromInt(x)) + pixel_center;
    const py = @as(f32, @floatFromInt(y)) + pixel_center;
    const mix = radialGradientMix(cx, cy, radius, fx, fy, focal_radius, px, py) orelse return ui.Color.clear;
    return gradientStopsColorAt(gradient.stops[0..gradient.stop_count], gradient.spread, mix);
}

fn radialGradientMix(cx: f32, cy: f32, radius: f32, fx: f32, fy: f32, focal_radius: f32, px: f32, py: f32) ?f32 {
    if (radius <= icon_axis_epsilon) return 1.0;
    const focus_to_center_x = cx - fx;
    const focus_to_center_y = cy - fy;
    const focus_to_center_distance = math.sqrtF(focus_to_center_x * focus_to_center_x + focus_to_center_y * focus_to_center_y);
    if (focus_to_center_distance + radius <= focal_radius + icon_axis_epsilon) return null;

    const point_x = px - fx;
    const point_y = py - fy;
    const point_distance = math.sqrtF(point_x * point_x + point_y * point_y);
    if (point_distance <= focal_radius + icon_axis_epsilon) return 0.0;

    const radius_delta = radius - focal_radius;
    const a = focus_to_center_x * focus_to_center_x + focus_to_center_y * focus_to_center_y - radius_delta * radius_delta;
    const b = -2.0 * (point_x * focus_to_center_x + point_y * focus_to_center_y + focal_radius * radius_delta);
    const c = point_x * point_x + point_y * point_y - focal_radius * focal_radius;
    if (math.absF(a) <= icon_axis_epsilon) {
        if (math.absF(b) <= icon_axis_epsilon) return null;
        const linear = -c / b;
        return if (linear >= 0.0) linear else null;
    }
    const discriminant = b * b - 4.0 * a * c;
    if (discriminant < -icon_axis_epsilon) return null;
    const root = math.sqrtF(@max(0.0, discriminant));
    const t0 = (-b - root) / (2.0 * a);
    const t1 = (-b + root) / (2.0 * a);
    return positiveGradientRoot(t0, t1);
}

fn positiveGradientRoot(first: f32, second: f32) ?f32 {
    const first_valid = first >= 0.0;
    const second_valid = second >= 0.0;
    if (first_valid and second_valid) return @min(first, second);
    if (first_valid) return first;
    if (second_valid) return second;
    return null;
}

fn gradientStopsColorAt(stops: []const icon_vector.LinearGradientStop, spread: icon_vector.GradientSpreadMethod, raw_mix: f32) ui.Color {
    const mix = applyGradientSpread(spread, raw_mix);
    const first_stop = stops[0];
    const last_stop = stops[stops.len - 1];
    if (mix <= first_stop.offset) return paintToColor(first_stop.color);
    if (mix >= last_stop.offset) return paintToColor(last_stop.color);
    var index: usize = 1;
    while (index < stops.len) : (index += 1) {
        const previous = stops[index - 1];
        const next = stops[index];
        if (mix > next.offset) continue;
        const offset_range = next.offset - previous.offset;
        const t = if (math.absF(offset_range) <= icon_axis_epsilon) 1.0 else (mix - previous.offset) / offset_range;
        return mixColor(paintToColor(previous.color), paintToColor(next.color), t);
    }
    return paintToColor(last_stop.color);
}

fn applyGradientSpread(spread: icon_vector.GradientSpreadMethod, value: f32) f32 {
    return switch (spread) {
        .pad => value,
        .repeat => fractionalPart(value),
        .reflect => {
            const repeated = fractionalPart(value * 0.5) * 2.0;
            return if (repeated <= 1.0) repeated else 2.0 - repeated;
        },
    };
}

fn fractionalPart(value: f32) f32 {
    const floor_value = math.floorF(value);
    return value - floor_value;
}

fn paintToColor(paint: icon_vector.Paint) ui.Color {
    return .{ .r = paint.r, .g = paint.g, .b = paint.b, .a = paint.a };
}

fn mixColor(a: ui.Color, b: ui.Color, t: f32) ui.Color {
    const clamped = math.clampF(t, 0.0, 1.0);
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
    return @intCast(math.lrintF(af + (bf - af) * t));
}

fn colorsEqual(a: ui.Color, b: ui.Color) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * math.clampF(t, 0.0, 1.0);
}

fn scaleByte(value: u8, factor: f32) u8 {
    return @intCast(math.lrintF(math.clampF(@as(f32, @floatFromInt(value)) * factor, 0.0, 255.0)));
}

fn blendChannel(src: u8, dst: u8, src_alpha: u16, inv_alpha: u16) u8 {
    return @intCast((@as(u16, src) * src_alpha + @as(u16, dst) * inv_alpha + 127) / 255);
}

fn blendChannelFloat(src: u8, dst: u8, src_alpha: f32, inv_alpha: f32) u8 {
    const value = @as(f32, @floatFromInt(src)) * src_alpha + @as(f32, @floatFromInt(dst)) * inv_alpha;
    return @intCast(math.lrintF(math.clampF(value, 0.0, 255.0)));
}

fn colorF(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

const BilinearAxis = struct {
    index0: usize,
    index1: usize,
    fraction: f32,
};

fn bilinearAxis(value: f32, len: usize) BilinearAxis {
    const scaled = math.clampF(math.clampF(value, 0.0, 1.0) * @as(f32, @floatFromInt(len)) - 0.5, 0.0, @as(f32, @floatFromInt(len - 1)));
    const index0: usize = @intFromFloat(math.floorF(scaled));
    return .{
        .index0 = index0,
        .index1 = @min(index0 + 1, len - 1),
        .fraction = scaled - @as(f32, @floatFromInt(index0)),
    };
}

fn bilinearAlphaByte(a00: u8, a10: u8, a01: u8, a11: u8, tx: f32, ty: f32) u8 {
    return @intCast(math.lrintF(bilinearAlphaFloat(a00, a10, a01, a11, tx, ty) * 255.0));
}

fn bilinearAlphaFloat(a00: u8, a10: u8, a01: u8, a11: u8, tx: f32, ty: f32) f32 {
    return lerp(
        lerp(@as(f32, @floatFromInt(a00)), @as(f32, @floatFromInt(a10)), tx),
        lerp(@as(f32, @floatFromInt(a01)), @as(f32, @floatFromInt(a11)), tx),
        ty,
    ) / 255.0;
}

fn scaleAlphaByte(tint: u8, sample: u8) u8 {
    if (tint == max_alpha) return sample;
    return @intCast((@as(u16, tint) * @as(u16, sample) + 127) / 255);
}

fn sampleRgba(texture: RgbaTexture, u: f32, v: f32) ui.Color {
    const x = math.clampF(u, 0.0, 1.0) * @as(f32, @floatFromInt(texture.width - 1));
    const y = math.clampF(v, 0.0, 1.0) * @as(f32, @floatFromInt(texture.height - 1));
    const x0: usize = @intFromFloat(math.floorF(x));
    const y0: usize = @intFromFloat(math.floorF(y));
    const x1 = @min(x0 + 1, texture.width - 1);
    const y1 = @min(y0 + 1, texture.height - 1);
    const tx = x - @as(f32, @floatFromInt(x0));
    const ty = y - @as(f32, @floatFromInt(y0));
    const c00 = texture.pixels[y0 * texture.width + x0];
    const c10 = texture.pixels[y0 * texture.width + x1];
    const c01 = texture.pixels[y1 * texture.width + x0];
    const c11 = texture.pixels[y1 * texture.width + x1];
    return .{
        .r = sampleChannel(c00.r, c10.r, c01.r, c11.r, tx, ty),
        .g = sampleChannel(c00.g, c10.g, c01.g, c11.g, tx, ty),
        .b = sampleChannel(c00.b, c10.b, c01.b, c11.b, tx, ty),
        .a = sampleChannel(c00.a, c10.a, c01.a, c11.a, tx, ty),
    };
}

fn sampleChannel(a00: u8, a10: u8, a01: u8, a11: u8, tx: f32, ty: f32) u8 {
    const top = lerp(@floatFromInt(a00), @floatFromInt(a10), tx);
    const bottom = lerp(@floatFromInt(a01), @floatFromInt(a11), tx);
    return @intCast(math.lrintF(lerp(top, bottom, ty)));
}

fn multiplyRgb(texel: ui.Color, tint: ui.Color) ui.Color {
    return .{
        .r = multiplyByte(texel.r, tint.r),
        .g = multiplyByte(texel.g, tint.g),
        .b = multiplyByte(texel.b, tint.b),
        .a = 255,
    };
}

fn multiplyByte(a: u8, b: u8) u8 {
    return @intCast((@as(u16, a) * @as(u16, b) + 127) / 255);
}

fn byteUnit(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / byte_unit_scale;
}

fn clockwiseTurn(dx: f32, dy: f32) f32 {
    var turn = math.atan2F(dy, dx) / math.tau + quarter_turn;
    if (turn < 0.0) turn += 1.0;
    if (turn > 1.0) turn -= 1.0;
    return turn;
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

fn clampMaskCoord(value: isize, start: usize, limit: usize) usize {
    if (value <= 0) return start;
    const as_usize: usize = @intCast(value);
    return math.clampSize(as_usize, start, limit);
}

fn iconMaskPixel(mask: IconAlphaMask, x: usize, y: usize) u8 {
    if (x < mask.x or y < mask.y) return 0;
    const local_x = x - mask.x;
    const local_y = y - mask.y;
    if (local_x >= mask.width or local_y >= mask.height) return 0;
    return mask.pixels[local_y * mask.width + local_x];
}

fn iconMaskAlphaSum(mask: IconAlphaMask) usize {
    var sum: usize = 0;
    for (mask.pixels) |alpha| sum += alpha;
    return sum;
}

test "software renderer rasterizes ui commands to nonblank pixels" {
    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try node_renderer.renderNode(component_union.Component, &scene, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, root, .{});

    var pixels: [320 * 240]ui.Color = undefined;
    const surface = try Surface.init(320, 240, &pixels);
    surface.clear(.clear);
    try renderTestSceneIr(surface, scene.written());

    var painted: usize = 0;
    for (surface.pixels) |pixel| {
        if (pixel.a != 0) painted += 1;
    }
    try std.testing.expect(painted > 0);
}

test "software renderer svg arc geometry follows sweep side" {
    const start = icon_vector.Point{ .x = 0.0, .y = 0.0 };
    const arc = icon_vector.Arc{
        .rx = 0.7,
        .ry = 0.55,
        .x_axis_rotation = 0.0,
        .large_arc = false,
        .sweep = true,
        .end = .{ .x = 0.8, .y = 0.2 },
    };
    const geometry = svgArcGeometry(start, arc).?;
    try std.testing.expect(geometry.center.x < 0.4);
    try std.testing.expect(geometry.center.y > 0.5);
    try std.testing.expect(geometry.delta > 0.0);
    try std.testing.expect(geometry.delta < math.pi);
}

test "software renderer boosts only sloped icon stroke mid coverage" {
    const radius: f32 = 1.0;
    const mid_distance: f32 = 0.707;
    const edge_distance: f32 = 1.414;
    const explicit_boost: f32 = 0.8;
    const linear_mid = strokeCoverageAlpha(radius, mid_distance, icon_stroke_antialias_width_default, false, explicit_boost);
    const boosted_mid = strokeCoverageAlpha(radius, mid_distance, icon_stroke_antialias_width_default, true, explicit_boost);
    const default_linear_mid = strokeCoverageAlpha(radius, mid_distance, icon_stroke_antialias_width_default, false, active_icon_tuning.line_stroke_coverage_boost);
    const default_boosted_mid = strokeCoverageAlpha(radius, mid_distance, icon_stroke_antialias_width_default, true, active_icon_tuning.line_stroke_coverage_boost);
    const linear_edge = strokeCoverageAlpha(radius, edge_distance, icon_stroke_antialias_width_default, false, explicit_boost);
    const boosted_edge = strokeCoverageAlpha(radius, edge_distance, icon_stroke_antialias_width_default, true, explicit_boost);

    try std.testing.expect(isSlopedSegment(1.0, 1.0));
    try std.testing.expect(!isSlopedSegment(1.0, 0.0));
    try std.testing.expect(boosted_mid > linear_mid);
    try std.testing.expect(default_boosted_mid > default_linear_mid);
    try std.testing.expectEqual(linear_edge, boosted_edge);
}

test "software renderer applies svg round caps only at open subpath endpoints" {
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    const bounds = ui.Rect.init(0, 0, 24, 24);
    var buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var mask = IconAlphaMask.init(bounds, surface.width, surface.height, buffer[0..]);
    var path = IconPathState{};
    const start = icon_vector.Point{ .x = 0.25, .y = 0.5 };
    const end = icon_vector.Point{ .x = 0.75, .y = 0.5 };
    path.moveTo(start);

    surface.strokePathSegmentMask(&mask, &path, icon_stroke_scale, .round, svg_miter_limit_default, start, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    try std.testing.expectEqual(@as(u8, 0), iconMaskPixel(mask, 5, 12));

    surface.finishIconSubpath(&mask, &path, icon_stroke_scale, .round);
    try std.testing.expect(iconMaskPixel(mask, 5, 12) > 0);
}

test "software renderer honors svg butt and square caps" {
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    const bounds = ui.Rect.init(0, 0, 24, 24);
    const start = icon_vector.Point{ .x = 0.25, .y = 0.5 };
    const end = icon_vector.Point{ .x = 0.75, .y = 0.5 };

    var butt_buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var butt_mask = IconAlphaMask.init(bounds, surface.width, surface.height, butt_buffer[0..]);
    var butt_path = IconPathState{};
    butt_path.moveTo(start);
    surface.strokePathSegmentMask(&butt_mask, &butt_path, icon_stroke_scale, .round, svg_miter_limit_default, start, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.finishIconSubpath(&butt_mask, &butt_path, icon_stroke_scale, .butt);
    try std.testing.expectEqual(@as(u8, 0), iconMaskPixel(butt_mask, 5, 12));

    var square_buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var square_mask = IconAlphaMask.init(bounds, surface.width, surface.height, square_buffer[0..]);
    var square_path = IconPathState{};
    square_path.moveTo(start);
    surface.strokePathSegmentMask(&square_mask, &square_path, icon_stroke_scale, .round, svg_miter_limit_default, start, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.finishIconSubpath(&square_mask, &square_path, icon_stroke_scale, .square);
    try std.testing.expect(iconMaskPixel(square_mask, 5, 12) > 0);
}

test "software renderer honors svg bevel and miter joins" {
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    const bounds = ui.Rect.init(0, 0, 24, 24);
    const start = icon_vector.Point{ .x = 0.25, .y = 0.5 };
    const corner = icon_vector.Point{ .x = 0.5, .y = 0.5 };
    const end = icon_vector.Point{ .x = 0.5, .y = 0.25 };
    const thick_stroke = 6.0 / 24.0;

    var bevel_buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var bevel_mask = IconAlphaMask.init(bounds, surface.width, surface.height, bevel_buffer[0..]);
    var bevel_path = IconPathState{};
    bevel_path.moveTo(start);
    surface.strokePathSegmentMask(&bevel_mask, &bevel_path, thick_stroke, .bevel, svg_miter_limit_default, start, corner, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.strokePathSegmentMask(&bevel_mask, &bevel_path, thick_stroke, .bevel, svg_miter_limit_default, corner, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);

    var miter_buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var miter_mask = IconAlphaMask.init(bounds, surface.width, surface.height, miter_buffer[0..]);
    var miter_path = IconPathState{};
    miter_path.moveTo(start);
    surface.strokePathSegmentMask(&miter_mask, &miter_path, thick_stroke, .miter, svg_miter_limit_default, start, corner, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.strokePathSegmentMask(&miter_mask, &miter_path, thick_stroke, .miter, svg_miter_limit_default, corner, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);

    try std.testing.expectEqual(@as(u8, 0), iconMaskPixel(bevel_mask, 14, 14));
    try std.testing.expect(iconMaskPixel(miter_mask, 14, 14) > 0);
}

test "software renderer honors svg miter limit" {
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    const bounds = ui.Rect.init(0, 0, 24, 24);
    const start = icon_vector.Point{ .x = 0.25, .y = 0.5 };
    const corner = icon_vector.Point{ .x = 0.5, .y = 0.5 };
    const end = icon_vector.Point{ .x = 0.5, .y = 0.25 };
    const thick_stroke = 6.0 / 24.0;

    var limited_buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var limited_mask = IconAlphaMask.init(bounds, surface.width, surface.height, limited_buffer[0..]);
    var limited_path = IconPathState{};
    limited_path.moveTo(start);
    surface.strokePathSegmentMask(&limited_mask, &limited_path, thick_stroke, .miter, 1.0, start, corner, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.strokePathSegmentMask(&limited_mask, &limited_path, thick_stroke, .miter, 1.0, corner, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);

    var default_buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var default_mask = IconAlphaMask.init(bounds, surface.width, surface.height, default_buffer[0..]);
    var default_path = IconPathState{};
    default_path.moveTo(start);
    surface.strokePathSegmentMask(&default_mask, &default_path, thick_stroke, .miter, svg_miter_limit_default, start, corner, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.strokePathSegmentMask(&default_mask, &default_path, thick_stroke, .miter, svg_miter_limit_default, corner, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);

    try std.testing.expectEqual(@as(u8, 0), iconMaskPixel(limited_mask, 14, 14));
    try std.testing.expect(iconMaskPixel(default_mask, 14, 14) > 0);
}

test "software renderer treats returned subpaths as closed for svg cap handling" {
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    const bounds = ui.Rect.init(0, 0, 24, 24);
    var buffer: [icon_alpha_mask_capacity]u8 = undefined;
    var mask = IconAlphaMask.init(bounds, surface.width, surface.height, buffer[0..]);
    var path = IconPathState{};
    const start = icon_vector.Point{ .x = 0.25, .y = 0.5 };
    const mid = icon_vector.Point{ .x = 0.75, .y = 0.5 };
    path.moveTo(start);

    surface.strokePathSegmentMask(&mask, &path, icon_stroke_scale, .round, svg_miter_limit_default, start, mid, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.strokePathSegmentMask(&mask, &path, icon_stroke_scale, .round, svg_miter_limit_default, mid, start, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    try std.testing.expect(path.endsAtStart());

    surface.finishIconSubpath(&mask, &path, icon_stroke_scale, .round);
    try std.testing.expectEqual(@as(usize, 0), path.segment_count);
}

test "software renderer drops subvisible icon alpha floor on blend" {
    var pixels: [4]ui.Color = undefined;
    const surface = try Surface.init(2, 2, &pixels);
    surface.clear(ui.Color.clear);
    var mask_pixels = [_]u8{ icon_alpha_floor, icon_alpha_floor + 1, 0, max_alpha };
    const mask = IconAlphaMask{
        .bounds = ui.Rect.init(0, 0, 2, 2),
        .x = 0,
        .y = 0,
        .width = 2,
        .height = 2,
        .pixels = &mask_pixels,
    };

    surface.blendIconMask(&mask, .{ .r = 255, .g = 255, .b = 255 });

    try std.testing.expectEqual(ui.Color.clear, pixels[0]);
    try std.testing.expect(pixels[1].a > 0);
    try std.testing.expectEqual(ui.Color.clear, pixels[2]);
    try std.testing.expectEqual(max_alpha, pixels[3].a);
}

test "software renderer composites separate icon path masks" {
    var pixels: [1]ui.Color = undefined;
    const surface = try Surface.init(1, 1, &pixels);
    surface.clear(ui.Color.clear);
    var mask_pixels = [_]u8{128};
    var mask = IconAlphaMask{
        .bounds = ui.Rect.init(0, 0, 1, 1),
        .x = 0,
        .y = 0,
        .width = 1,
        .height = 1,
        .pixels = &mask_pixels,
    };
    var path = IconPathState{};

    surface.finishIconPathMask(&mask, null, &path, .{ .solid = .{ .r = 255, .g = 255, .b = 255 } }, icon_stroke_scale, .round);
    const first_alpha = pixels[0].a;
    try std.testing.expect(first_alpha > 0);
    try std.testing.expectEqual(@as(u8, 0), mask.pixels[0]);

    mask.pixels[0] = 128;
    surface.finishIconPathMask(&mask, null, &path, .{ .solid = .{ .r = 255, .g = 255, .b = 255 } }, icon_stroke_scale, .round);
    try std.testing.expect(pixels[0].a > first_alpha);
}

test "software renderer uses svg iterator for transformed shape elements" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <circle transform="translate(4 0)" cx="8" cy="12" r="3"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255 }, svg);

    try std.testing.expect(pixels[12 * 24 + 15].a > 0);
    try std.testing.expectEqual(ui.Color.clear, pixels[12 * 24 + 5]);
}

test "software renderer fills default painted svg shapes" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <circle cx="8" cy="12" r="4"/>
        \\  <rect x="14" y="8" width="6" height="8" rx="1"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 33, .g = 200, .b = 120, .a = 255 }, svg);

    try std.testing.expect(pixels[12 * 24 + 8].a > 0);
    try std.testing.expect(pixels[12 * 24 + 17].a > 0);
    try std.testing.expectEqual(ui.Color.clear, pixels[2 * 24 + 2]);
}

test "software renderer honors explicit svg solid paint colors" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <rect x="2" y="4" width="8" height="8" fill="red"/>
        \\  <rect x="14" y="4" width="8" height="8" fill="#0000ff"/>
        \\  <rect x="2" y="14" width="8" height="8" fill="#00ff0080"/>
        \\  <rect x="14" y="14" width="8" height="8" fill="rgba(200, 100, 50, .5)"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 20, .g = 200, .b = 20, .a = 255 }, svg);

    try std.testing.expectEqual(ui.Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, pixels[8 * 24 + 6]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 0, .b = 255, .a = 255 }, pixels[8 * 24 + 18]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 128, .b = 0, .a = 128 }, pixels[18 * 24 + 6]);
    try std.testing.expectEqual(ui.Color{ .r = 100, .g = 50, .b = 25, .a = 128 }, pixels[18 * 24 + 18]);
}

test "software renderer rasterizes svg linear gradient fills" {
    const user_space_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <linearGradient id="paint" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="24" y2="0">
        \\      <stop offset="0" stop-color="red"/>
        \\      <stop offset="1" stop-color="blue"/>
        \\    </linearGradient>
        \\  </defs>
        \\  <rect x="12" y="0" width="12" height="24" fill="url(#paint)"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, user_space_svg);

    const left = pixels[12 * 24 + 13];
    const right = pixels[12 * 24 + 21];
    try std.testing.expect(left.b > left.r);
    try std.testing.expect(right.b > right.r);
    try std.testing.expectEqual(max_alpha, left.a);
    try std.testing.expectEqual(max_alpha, right.a);

    const object_box_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <linearGradient id="paint" gradientTransform="translate(.25 0) scale(.5 1)">
        \\      <stop offset="0" stop-color="red"/>
        \\      <stop offset="1" stop-color="blue"/>
        \\    </linearGradient>
        \\  </defs>
        \\  <rect x="12" y="0" width="12" height="24" fill="url(#paint)"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, object_box_svg);

    const object_left = pixels[12 * 24 + 13];
    const object_right = pixels[12 * 24 + 21];
    try std.testing.expect(object_left.r > object_left.b);
    try std.testing.expect(object_right.b > object_right.r);
    try std.testing.expectEqual(max_alpha, object_left.a);
    try std.testing.expectEqual(max_alpha, object_right.a);

    const multi_stop_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <linearGradient id="paint">
        \\      <stop offset="0" stop-color="red"/>
        \\      <stop offset=".5" stop-color="green"/>
        \\      <stop offset="1" stop-color="blue"/>
        \\    </linearGradient>
        \\  </defs>
        \\  <rect x="0" y="0" width="24" height="24" fill="url(#paint)"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, multi_stop_svg);

    const middle = pixels[12 * 24 + 12];
    try std.testing.expect(middle.g > middle.r);
    try std.testing.expect(middle.g > middle.b);
    try std.testing.expectEqual(max_alpha, middle.a);

    const inherited_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <linearGradient id="base">
        \\      <stop offset="0" stop-color="red"/>
        \\      <stop offset="1" stop-color="blue"/>
        \\    </linearGradient>
        \\    <linearGradient id="paint" href="#base" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="24" y2="0"/>
        \\  </defs>
        \\  <rect x="0" y="0" width="24" height="24" fill="url(#paint)"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, inherited_svg);

    const inherited_left = pixels[12 * 24 + 2];
    const inherited_right = pixels[12 * 24 + 22];
    try std.testing.expect(inherited_left.r > inherited_left.b);
    try std.testing.expect(inherited_right.b > inherited_right.r);
    try std.testing.expectEqual(max_alpha, inherited_left.a);
    try std.testing.expectEqual(max_alpha, inherited_right.a);

    const fallback_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <rect x="0" y="0" width="24" height="24" fill="url(#missing) red"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, fallback_svg);

    const fallback_pixel = pixels[12 * 24 + 12];
    try std.testing.expect(fallback_pixel.r > fallback_pixel.b);
    try std.testing.expect(fallback_pixel.r > fallback_pixel.g);
    try std.testing.expectEqual(max_alpha, fallback_pixel.a);

    const fill_opacity_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <rect x="0" y="0" width="24" height="24" fill="red" fill-opacity=".5"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, fill_opacity_svg);

    const opacity_pixel = pixels[12 * 24 + 12];
    try std.testing.expectEqual(@as(u8, 128), opacity_pixel.a);
    try std.testing.expect(opacity_pixel.r > opacity_pixel.g);

    const current_opacity_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-opacity=".5" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 2 12 L 22 12"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 10, .g = 200, .b = 20, .a = 255 }, current_opacity_svg);

    const current_opacity_pixel = pixels[12 * 24 + 12];
    try std.testing.expectEqual(@as(u8, 128), current_opacity_pixel.a);
    try std.testing.expect(current_opacity_pixel.g > current_opacity_pixel.r);

    const authored_color_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" color="red">
        \\  <rect x="0" y="0" width="24" height="24" fill="currentColor"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 10, .g = 200, .b = 20, .a = 255 }, authored_color_svg);

    const authored_color_pixel = pixels[12 * 24 + 12];
    try std.testing.expect(authored_color_pixel.r > authored_color_pixel.g);
    try std.testing.expectEqual(max_alpha, authored_color_pixel.a);

    const radial_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <radialGradient id="paint" cx="50%" cy="50%" r="50%">
        \\      <stop offset="0" stop-color="white"/>
        \\      <stop offset="1" stop-color="black"/>
        \\    </radialGradient>
        \\  </defs>
        \\  <rect x="0" y="0" width="24" height="24" fill="url(#paint)"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, radial_svg);

    const radial_center = pixels[12 * 24 + 12];
    const radial_corner = pixels[1 * 24 + 1];
    try std.testing.expect(radial_center.r > radial_corner.r);
    try std.testing.expect(radial_center.g > radial_corner.g);
    try std.testing.expect(radial_center.b > radial_corner.b);
    try std.testing.expectEqual(max_alpha, radial_center.a);

    const focal_radial_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <radialGradient id="paint" gradientUnits="userSpaceOnUse" cx="12" cy="12" r="12" fx="6" fy="18" fr="3">
        \\      <stop offset="0" stop-color="white"/>
        \\      <stop offset="1" stop-color="black"/>
        \\    </radialGradient>
        \\  </defs>
        \\  <rect x="0" y="0" width="24" height="24" fill="url(#paint)"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, focal_radial_svg);

    const focal_inside = pixels[18 * 24 + 6];
    const focal_outer = pixels[1 * 24 + 22];
    try std.testing.expect(focal_inside.r > focal_outer.r);
    try std.testing.expect(focal_inside.g > focal_outer.g);
    try std.testing.expect(focal_inside.b > focal_outer.b);
    try std.testing.expectEqual(max_alpha, focal_inside.a);

    const repeat_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <linearGradient id="paint" x1="0" y1="0" x2="25%" y2="0" spreadMethod="repeat">
        \\      <stop offset="0" stop-color="red"/>
        \\      <stop offset="1" stop-color="blue"/>
        \\    </linearGradient>
        \\  </defs>
        \\  <rect x="0" y="0" width="24" height="24" fill="url(#paint)"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, repeat_svg);

    const repeat_pixel = pixels[12 * 24 + 13];
    try std.testing.expect(repeat_pixel.r > repeat_pixel.b);
    try std.testing.expectEqual(max_alpha, repeat_pixel.a);

    const gradient_stroke_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="url(#paint)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <linearGradient id="paint" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="24" y2="0">
        \\      <stop offset="0" stop-color="red"/>
        \\      <stop offset="1" stop-color="blue"/>
        \\    </linearGradient>
        \\  </defs>
        \\  <path d="M 2 12 L 22 12"/>
        \\</svg>
    ;
    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, gradient_stroke_svg);

    const stroke_left = pixels[12 * 24 + 4];
    const stroke_right = pixels[12 * 24 + 20];
    try std.testing.expect(stroke_left.r > stroke_left.b);
    try std.testing.expect(stroke_right.b > stroke_right.r);
    try std.testing.expect(stroke_left.a > 0);
    try std.testing.expect(stroke_right.a > 0);
}

test "software renderer honors variable svg stroke widths" {
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    const thin_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 4 12 L 20 12"/>
        \\</svg>
    ;
    const thick_svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 4 12 L 20 12"/>
        \\</svg>
    ;

    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, thin_svg);
    const thin_edge = pixels[9 * 24 + 12].a;

    surface.clear(ui.Color.clear);
    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, thick_svg);
    const thick_edge = pixels[9 * 24 + 12].a;

    try std.testing.expect(thick_edge > thin_edge);
    try std.testing.expect(thick_edge > 0);
}

test "software renderer fills svg path interiors with nonzero rule" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <path d="M 4 4 L 20 4 L 12 20"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, svg);

    try std.testing.expect(pixels[10 * 24 + 12].a > 0);
    try std.testing.expectEqual(ui.Color.clear, pixels[21 * 24 + 12]);
}

test "software renderer applies evenodd svg fill rule" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill-rule="evenodd">
        \\  <path d="M 4 4 H 20 V 20 H 4 Z M 8 8 H 16 V 16 H 8 Z"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, svg);

    try std.testing.expect(pixels[6 * 24 + 6].a > 0);
    try std.testing.expectEqual(ui.Color.clear, pixels[12 * 24 + 12]);
}

test "software renderer paints mixed fill and stroke svg paths" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="black" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d="M 4 4 L 20 4 L 12 20"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, svg);

    try std.testing.expect(pixels[10 * 24 + 12].a > 0);
    try std.testing.expect(pixels[4 * 24 + 12].a > 0);
}

test "software renderer fills open svg subpaths as closed" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <polyline points="4,20 12,4 20,20"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 255, .g = 255, .b = 255, .a = 255 }, svg);

    try std.testing.expect(pixels[14 * 24 + 12].a > 0);
    try std.testing.expectEqual(ui.Color.clear, pixels[3 * 24 + 12]);
}

test "software renderer applies svg path clip paths" {
    const svg =
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
        \\  <defs>
        \\    <clipPath id="left"><path d="M 0 0 H 12 V 24 H 0 Z"/></clipPath>
        \\  </defs>
        \\  <path clip-path="url(#left)" fill="white" d="M 0 0 H 24 V 24 H 0 Z"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    const white = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), white, svg);

    try std.testing.expect(colorsEqual(pixels[12 * 24 + 6], white));
    try std.testing.expect(colorsEqual(pixels[12 * 24 + 18], ui.Color.clear));
}

test "software renderer icon tuning sweeps explicit candidates" {
    defer resetIconTuningForTest();
    const candidates = [_]IconTuning{
        .{ .curve_segments = 4, .stroke_antialias_width = 0.5, .round_cap_antialias_width = 0.588086, .line_stroke_coverage_boost = 0.8, .curve_stroke_coverage_boost = 0.75, .arc_stroke_coverage_boost = 0.8, .arc_antialias_width = 0.535, .large_arc_antialias_width = 0.565, .arc_step_divisor = 16.0, .large_arc_step_divisor = 10.0 },
        .{ .curve_segments = 5, .stroke_antialias_width = 0.52, .round_cap_antialias_width = 0.57, .line_stroke_coverage_boost = 1.0, .curve_stroke_coverage_boost = 0.75, .arc_stroke_coverage_boost = 0.95, .arc_antialias_width = 0.535, .large_arc_antialias_width = 0.565, .arc_step_divisor = icon_arc_step_divisor_default, .large_arc_step_divisor = icon_large_arc_step_divisor_default },
        .{ .curve_segments = 4, .stroke_antialias_width = 0.48, .round_cap_antialias_width = 0.6, .line_stroke_coverage_boost = 0.9, .curve_stroke_coverage_boost = 0.65, .arc_stroke_coverage_boost = 0.9, .arc_antialias_width = 0.535, .large_arc_antialias_width = 0.545, .arc_step_divisor = 28.0, .large_arc_step_divisor = 14.0 },
        .{ .curve_segments = 4, .stroke_antialias_width = 0.54, .round_cap_antialias_width = 0.55, .line_stroke_coverage_boost = 1.1, .curve_stroke_coverage_boost = 0.85, .arc_stroke_coverage_boost = 1.0, .arc_antialias_width = 0.545, .large_arc_antialias_width = 0.555, .arc_step_divisor = 36.0, .large_arc_step_divisor = 18.0 },
    };
    for (candidates) |candidate| {
        try setIconTuningForTest(candidate);
        try std.testing.expectEqual(candidate.curve_segments, active_icon_tuning.curve_segments);
        try std.testing.expectEqual(candidate.stroke_antialias_width, active_icon_tuning.stroke_antialias_width);
        try std.testing.expectEqual(candidate.round_cap_antialias_width, active_icon_tuning.round_cap_antialias_width);
        try std.testing.expectEqual(candidate.line_stroke_coverage_boost, active_icon_tuning.line_stroke_coverage_boost);
        try std.testing.expectEqual(candidate.curve_stroke_coverage_boost, active_icon_tuning.curve_stroke_coverage_boost);
        try std.testing.expectEqual(candidate.arc_stroke_coverage_boost, active_icon_tuning.arc_stroke_coverage_boost);
        try std.testing.expectEqual(candidate.arc_antialias_width, active_icon_tuning.arc_antialias_width);
        try std.testing.expectEqual(candidate.large_arc_antialias_width, active_icon_tuning.large_arc_antialias_width);
        try std.testing.expectEqual(candidate.arc_step_divisor, active_icon_tuning.arc_step_divisor);
        try std.testing.expectEqual(candidate.large_arc_step_divisor, active_icon_tuning.large_arc_step_divisor);
    }

    try std.testing.expectError(error.InvalidIconTuning, setIconTuningForTest(.{
        .curve_segments = icon_curve_segments_max + 1,
        .stroke_antialias_width = icon_stroke_antialias_width_default,
        .round_cap_antialias_width = icon_stroke_round_cap_antialias_width_default,
        .line_stroke_coverage_boost = icon_line_stroke_coverage_boost_default,
        .curve_stroke_coverage_boost = icon_curve_stroke_coverage_boost_default,
        .arc_stroke_coverage_boost = icon_arc_stroke_coverage_boost_default,
        .arc_antialias_width = icon_arc_antialias_width_default,
        .large_arc_antialias_width = icon_large_arc_antialias_width_default,
        .arc_step_divisor = icon_arc_step_divisor_default,
        .large_arc_step_divisor = icon_large_arc_step_divisor_default,
    }));
}

test "software renderer honors rounded gradient and shadow rect modes" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushGradientRect(ui.Rect.init(8.0, 8.0, 24.0, 24.0), .{ .r = 240, .g = 40, .b = 40 }, .{ .r = 40, .g = 40, .b = 240 }, 8.0);
    try scene.pushRect(ui.Rect.init(42.0, 18.0, 12.0, 12.0), .{ .r = 0, .g = 0, .b = 0, .a = 120 }, .shadow, 4.0, 5.0);

    var pixels: [64 * 48]ui.Color = undefined;
    const surface = try Surface.init(64, 48, &pixels);
    surface.clear(.clear);
    try renderTestSceneIr(surface, scene.written());

    try std.testing.expectEqual(ui.Color.clear, pixels[8 * 64 + 8]);
    const top = pixels[12 * 64 + 20];
    const bottom = pixels[28 * 64 + 20];
    try std.testing.expect(top.r > top.b);
    try std.testing.expect(bottom.b > bottom.r);
    try std.testing.expect(pixels[18 * 64 + 39].a > 0);
}

test "software renderer rasterizes rect ir deterministically" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(ui.Rect.init(0.0, 0.0, 64.0, 48.0), .bg, .fill, 0.0, 0.0);
    try scene.pushGradientRect(ui.Rect.init(8.0, 8.0, 24.0, 24.0), .{ .r = 240, .g = 40, .b = 40 }, .{ .r = 40, .g = 40, .b = 240 }, 8.0);
    try scene.pushRect(ui.Rect.init(42.0, 18.0, 12.0, 12.0), .{ .r = 0, .g = 0, .b = 0, .a = 120 }, .shadow, 4.0, 5.0);
    try scene.pushRect(ui.Rect.init(44.0, 20.0, 10.0, 10.0), .accent, .border, 3.0, 0.0);

    var storage = renderer_ir.FixedBuffers(3, 0, 0, 0, 1, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    var source_context: u8 = 0;
    const sources = renderer_ir.Sources{
        .font = .{ .context = &source_context, .metrics = irTestFontMetrics, .width = irTestTextWidth, .glyph = irTestGlyph },
    };
    try renderer_ir.packSceneWithOverlay(buffers, sources, scene.written(), 3);

    var ir_pixels: [64 * 48]ui.Color = undefined;
    const ir_surface = try Surface.init(64, 48, &ir_pixels);
    ir_surface.clear(.clear);
    try ir_surface.rasterizeIr(buffers);

    try std.testing.expectEqual(ui.Color.bg, ir_pixels[1 * 64 + 1]);
    try std.testing.expect(ir_pixels[12 * 64 + 20].r > ir_pixels[28 * 64 + 20].r);
    try std.testing.expect(ir_pixels[20 * 64 + 44].a > 0);
}

test "software renderer rejects textured ir without resources" {
    var pixels: [4]ui.Color = undefined;
    const surface = try Surface.init(2, 2, &pixels);
    var storage = renderer_ir.FixedBuffers(0, 1, 0, 0, 0, 0, 0, 0, 0){};
    storage.text_vertex_len = 1;
    const buffers = storage.buffers();
    try std.testing.expectError(error.UnsupportedIrPrimitive, surface.rasterizeIr(buffers));
}

test "software renderer rasterizes alpha textured ir with supplied resources" {
    var pixels: [8 * 8]ui.Color = undefined;
    const surface = try Surface.init(8, 8, &pixels);
    surface.clear(.clear);

    var storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();

    try renderer_ir.pushClippedTexturedQuad(
        buffers.text_vertices,
        buffers.text_vertex_len,
        ui.Rect.init(0, 0, 8, 8),
        ui.Rect.init(0, 0, 8, 8),
        0.0,
        0.0,
        1.0,
        1.0,
        .{ .r = 255, .g = 32, .b = 16, .a = 200 },
    );
    const alpha = [_]u8{
        0,   255,
        255, 255,
    };
    const resources = IrResources{
        .font = .{ .width = 2, .height = 2, .alpha = &alpha },
    };

    const receipt = try surface.renderIrFrameWithResources(buffers, resources);
    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(renderer_present.Transport.pixel_bytes, receipt.transport);
    try std.testing.expectEqual(@as(usize, 1), receipt.primitive_count);
    const pixel = pixels[4 * 8 + 4];
    try std.testing.expect(pixel.a > 0);
    try std.testing.expect(pixel.r > pixel.g);
}

test "software renderer rasterizes image ir with supplied rgba texture" {
    var pixels: [8 * 8]ui.Color = undefined;
    const surface = try Surface.init(8, 8, &pixels);
    surface.clear(.clear);

    var storage = renderer_ir.FixedBuffers(0, 0, 0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();

    try renderer_ir.pushClippedTexturedQuad(
        buffers.image_vertices,
        buffers.image_vertex_len,
        ui.Rect.init(0, 0, 8, 8),
        ui.Rect.init(0, 0, 8, 8),
        0.0,
        0.0,
        1.0,
        1.0,
        .{ .r = 128, .g = 255, .b = 255, .a = 255 },
    );
    const alpha = [_]u8{ 255, 255, 255, 255 };
    const image = [_]ui.Color{
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
    };
    const resources = IrResources{
        .font = .{ .width = 2, .height = 2, .alpha = &alpha },
        .image = .{ .width = 2, .height = 2, .pixels = &image },
    };

    const receipt = try surface.renderIrFrameWithResources(buffers, resources);
    try std.testing.expect(receipt.valid());
    try std.testing.expect(receipt.requirements.image_texture);
    const pixel = pixels[4 * 8 + 4];
    try std.testing.expect(pixel.r > 120);
    try std.testing.expect(pixel.r < 140);
    try std.testing.expectEqual(@as(u8, 0), pixel.g);
    try std.testing.expectEqual(@as(u8, 0), pixel.b);
}

test "software renderer frame rejects missing image texture through presentation contract" {
    var pixels: [8 * 8]ui.Color = undefined;
    const surface = try Surface.init(8, 8, &pixels);

    var storage = renderer_ir.FixedBuffers(0, 0, 0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushClippedTexturedQuad(
        buffers.image_vertices,
        buffers.image_vertex_len,
        ui.Rect.init(0, 0, 8, 8),
        ui.Rect.init(0, 0, 8, 8),
        0.0,
        0.0,
        1.0,
        1.0,
        .{ .r = 255, .g = 255, .b = 255, .a = 255 },
    );

    const alpha = [_]u8{ 255, 255, 255, 255 };
    const resources = IrResources{
        .font = .{ .width = 2, .height = 2, .alpha = &alpha },
    };
    try std.testing.expectError(error.MissingImageTexture, surface.renderIrFrameWithResources(buffers, resources));
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

fn renderTestSceneIr(surface: Surface, commands: []const ui.Command) !void {
    var storage = renderer_ir.FixedBuffers(64, 1024, 64, 64, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    var source_context: u8 = 0;
    const sources = renderer_ir.Sources{
        .font = .{ .context = &source_context, .metrics = irTestFontMetrics, .width = irTestTextWidth, .glyph = irTestGlyph },
    };
    try renderer_ir.packScene(buffers, sources, commands);
    const alpha = [_]u8{255};
    try surface.rasterizeIrWithResources(buffers, .{
        .font = .{ .width = 1, .height = 1, .alpha = &alpha },
    });
}

fn irTestFontMetrics(_: *anyopaque, _: u8) renderer_ir.TextMetrics {
    return .{ .ascender = 10.0, .descender = -3.0 };
}

fn irTestTextWidth(_: *anyopaque, value: []const u8, _: u8) f32 {
    return @as(f32, @floatFromInt(ui.utf8CodepointCount(value))) * 8.0;
}

fn irTestGlyph(_: *anyopaque, _: u21, _: u8) renderer_ir.Error!?renderer_ir.Glyph {
    return null;
}

pub const Framebuffer = struct {
    width: usize,
    height: usize,
    pixels: []ui.Color,

    pub fn init(w: usize, h: usize, px: []ui.Color) Error!Framebuffer {
        const surface = try Surface.init(w, h, px);
        return .{ .width = surface.width, .height = surface.height, .pixels = surface.pixels };
    }

    pub fn clear(self: Framebuffer, color: ui.Color) void {
        (Surface{ .width = self.width, .height = self.height, .pixels = self.pixels }).clear(color);
    }

    pub fn renderIr(self: Framebuffer, buffers: renderer_ir.Buffers, resources: IrResources) Error!renderer_present.Receipt {
        return (Surface{ .width = self.width, .height = self.height, .pixels = self.pixels }).renderIrFrameWithResources(buffers, resources);
    }

    pub fn blendPixel(self: Framebuffer, x: usize, y: usize, color: ui.Color, alpha: u8) void {
        (Surface{ .width = self.width, .height = self.height, .pixels = self.pixels }).blendPixel(x, y, color, alpha);
    }
};

pub const Resources = IrResources;
