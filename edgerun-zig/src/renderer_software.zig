const std = @import("std");
const icon_svg = @import("icon_svg.zig");
const icon_vector = @import("icon_vector.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_present = @import("renderer_present.zig");
const ui = @import("ui.zig");
const builtin = @import("builtin");
const ui_components = if (builtin.is_test) @import("ui_components.zig") else struct {};
const varfont = @import("varfont.zig");

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

pub const RgbaTexture = struct {
    width: usize,
    height: usize,
    pixels: []const ui.Color,

    pub fn valid(self: RgbaTexture) bool {
        return self.width != 0 and self.height != 0 and self.pixels.len >= self.width * self.height;
    }
};

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
            .text => |text| self.drawTextCommand(text, scale),
            .icon_quad => |quad| self.drawIconQuad(quad, scale),
            .drag_source, .drop_target, .text_quad, .image_quad, .transition => {},
        };
    }

    pub fn rasterizeIr(self: Surface, buffers: renderer_ir.Buffers) Error!void {
        renderer_ir.validateBuffers(buffers) catch return error.InvalidIrBuffer;
        if (buffers.hasTexturedVertices()) return error.UnsupportedIrPrimitive;
        for (renderer_ir.drawBatches(buffers)) |batch| switch (batch) {
            .rects, .overlay_rects => |rects| try self.rasterizeIrRects(rects),
            .icon, .overlay_icon => |icons| try self.rasterizeIrIcons(icons),
            .image, .text, .overlay_text => {},
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
            .icon, .overlay_icon => |icons| try self.rasterizeIrIcons(icons),
        };
    }

    pub fn renderIrFrameWithResources(self: Surface, buffers: renderer_ir.Buffers, resources: IrResources) Error!renderer_present.Receipt {
        const receipt = renderer_present.present(.{
            .target = .{
                .kind = .cpu,
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
        const px0 = clampCoord(@intFromFloat(@floor(quad.bounds.x)), self.width);
        const py0 = clampCoord(@intFromFloat(@floor(quad.bounds.y)), self.height);
        const px1 = clampCoord(@intFromFloat(@ceil(quad.bounds.x + quad.bounds.w)), self.width);
        const py1 = clampCoord(@intFromFloat(@ceil(quad.bounds.y + quad.bounds.h)), self.height);
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

    fn rasterizeNearestAlphaTexturedQuads(self: Surface, vertices: []const f32, atlas: AlphaAtlas) Error!void {
        var iter = renderer_ir.TexturedQuadIterator.init(vertices) catch return error.InvalidIrBuffer;
        while (iter.next() catch return error.InvalidIrBuffer) |quad| {
            try self.rasterizeNearestAlphaTexturedQuad(quad, atlas);
        }
    }

    fn rasterizeNearestAlphaTexturedQuad(self: Surface, quad: renderer_ir.TexturedQuad, atlas: AlphaAtlas) Error!void {
        const px0 = clampCoord(@intFromFloat(@floor(quad.bounds.x)), self.width);
        const py0 = clampCoord(@intFromFloat(@floor(quad.bounds.y)), self.height);
        const px1 = clampCoord(@intFromFloat(@ceil(quad.bounds.x + quad.bounds.w)), self.width);
        const py1 = clampCoord(@intFromFloat(@ceil(quad.bounds.y + quad.bounds.h)), self.height);
        if (px1 <= px0 or py1 <= py0) return;

        const atlas_w: f32 = @floatFromInt(atlas.width - 1);
        const atlas_h: f32 = @floatFromInt(atlas.height - 1);
        const u_step = (quad.u1 - quad.u0) / quad.bounds.w;
        const v_step = (quad.v1 - quad.v0) / quad.bounds.h;
        var y = py0;
        while (y < py1) : (y += 1) {
            const v = quad.v0 + (@as(f32, @floatFromInt(y)) + pixel_center - quad.bounds.y) * v_step;
            const sample_y = nearestSampleIndex(v, atlas_h, atlas.height);
            var x = px0;
            while (x < px1) : (x += 1) {
                const u = quad.u0 + (@as(f32, @floatFromInt(x)) + pixel_center - quad.bounds.x) * u_step;
                const sample_x = nearestSampleIndex(u, atlas_w, atlas.width);
                const alpha = scaleByte(quad.color.a, @as(f32, @floatFromInt(atlas.alpha[sample_y * atlas.width + sample_x])) / byte_unit_scale);
                var color = quad.color;
                color.a = 255;
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
        const px0 = clampCoord(@intFromFloat(@floor(quad.bounds.x)), self.width);
        const py0 = clampCoord(@intFromFloat(@floor(quad.bounds.y)), self.height);
        const px1 = clampCoord(@intFromFloat(@ceil(quad.bounds.x + quad.bounds.w)), self.width);
        const py1 = clampCoord(@intFromFloat(@ceil(quad.bounds.y + quad.bounds.h)), self.height);
        if (px1 <= px0 or py1 <= py0) return;

        const u_step = (quad.u1 - quad.u0) / quad.bounds.w;
        const v_step = (quad.v1 - quad.v0) / quad.bounds.h;
        const atlas_w: f32 = @floatFromInt(atlas.width - 1);
        const atlas_h: f32 = @floatFromInt(atlas.height - 1);
        var color = quad.color;
        color.a = max_alpha;
        var y = py0;
        while (y < py1) : (y += 1) {
            const v = quad.v0 + (@as(f32, @floatFromInt(y)) + pixel_center - quad.bounds.y) * v_step;
            const sample_y = bilinearAxis(v, atlas_h, atlas.height);
            const row0 = sample_y.index0 * atlas.width;
            const row1 = sample_y.index1 * atlas.width;
            var x = px0;
            while (x < px1) : (x += 1) {
                const u = quad.u0 + (@as(f32, @floatFromInt(x)) + pixel_center - quad.bounds.x) * u_step;
                const sample_x = bilinearAxis(u, atlas_w, atlas.width);
                var sampled_alpha = bilinearAlphaByte(
                    atlas.alpha[row0 + sample_x.index0],
                    atlas.alpha[row0 + sample_x.index1],
                    atlas.alpha[row1 + sample_x.index0],
                    atlas.alpha[row1 + sample_x.index1],
                    sample_x.fraction,
                    sample_y.fraction,
                );
                if (quad.bounds.h <= small_text_sharpen_max_glyph_h) sampled_alpha = sharpenSmallTextAlpha(sampled_alpha);
                const alpha = scaleAlphaByte(quad.color.a, sampled_alpha);
                if (alpha != 0) self.blendPixelAt(y * self.width + x, color, alpha);
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
            .r = @intCast((@as(u16, color.r) * a + @as(u16, dst.r) * inv) / 255),
            .g = @intCast((@as(u16, color.g) * a + @as(u16, dst.g) * inv) / 255),
            .b = @intCast((@as(u16, color.b) * a + @as(u16, dst.b) * inv) / 255),
            .a = @intCast(@min(@as(u16, 255), @as(u16, dst.a) + (@as(u16, color.a) * a) / 255)),
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
        const out_a = src_a + (dst_a * (255 - src_a)) / 255;
        self.pixels[index] = .{
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = @intCast(@min(@as(u16, 255), out_a)),
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
        if (radius <= 0.0 and colorsEqual(top_color, bottom_color) and top_color.a == max_alpha) {
            self.fill(bounds, top_color);
            return;
        }
        if (radius > 0.0 and colorsEqual(top_color, bottom_color) and top_color.a == max_alpha) {
            self.fillRoundedSolid(bounds, top_color, radius);
            return;
        }
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
                self.drawCoveredPixel(x, y, color, alpha);
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
        const x0 = clampCoord(@intFromFloat(@floor(corner.x)), self.width);
        const y0 = clampCoord(@intFromFloat(@floor(corner.y)), self.height);
        const x1 = clampCoord(@intFromFloat(@ceil(corner.x + corner.w)), self.width);
        const y1 = clampCoord(@intFromFloat(@ceil(corner.y + corner.h)), self.height);
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
        var shadow_color = color;
        shadow_color.a = scaleByte(color.a, cpu_shadow_alpha);
        if (shadow_color.a == 0) return;
        const outer = bounds.insetUniform(-spread);
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

    fn drawTextCommand(self: Surface, text: anytype, scale: f32) void {
        const bounds = scaleRect(text.origin, scale);
        const px_size = textPxSize(bounds);
        var draw_bounds = bounds;
        const measured = @min(bounds.w, measureText(text.value, px_size));
        draw_bounds.x += switch (text.alignment) {
            .start => 0.0,
            .center => @max(0.0, (bounds.w - measured) * 0.5),
            .end => @max(0.0, bounds.w - measured),
        };
        draw_bounds.w = @max(1.0, bounds.w - (draw_bounds.x - bounds.x));
        textCache().drawText(self, draw_bounds, text.value, text.color, px_size) catch unreachable;
    }

    fn drawIconQuad(self: Surface, quad: ui.IconQuad, scale: f32) void {
        self.drawIconInstance(quad.bounds, quad.color, quad.icon_id, scale);
    }

    fn drawIconInstance(self: Surface, icon_bounds: ui.Rect, color: ui.Color, icon_id: u32, scale: f32) void {
        const bounds = scaleRect(icon_bounds, scale);
        self.drawIconSvg(bounds, color, icon_svg.sourceForIconId(icon_id));
    }

    fn drawIconSvg(self: Surface, bounds: ui.Rect, color: ui.Color, svg: []const u8) void {
        var iter = icon_svg.Iterator.init(svg);
        var buffer: [icon_alpha_mask_capacity]u8 = undefined;
        var mask = IconAlphaMask.init(bounds, self.width, self.height, buffer[0..]);
        var path = IconPathState{};
        var paint = color;
        while (iter.next() catch unreachable) |op| {
            self.drawIconOp(bounds, color, &paint, &mask, &path, op);
        }
        self.finishIconSubpath(&mask, &path);
        self.blendIconMask(&mask, paint);
    }

    fn drawIconOp(self: Surface, bounds: ui.Rect, current_color: ui.Color, paint: *ui.Color, mask: *IconAlphaMask, path: *IconPathState, op: icon_vector.Op) void {
        switch (op) {
            .paint_current_color => {
                self.finishIconPathMask(mask, path, paint.*);
                paint.* = current_color;
            },
            .paint_rgba => |rgba| {
                self.finishIconPathMask(mask, path, paint.*);
                paint.* = .{ .r = rgba.r, .g = rgba.g, .b = rgba.b, .a = rgba.a };
            },
            .polyline => |points| self.iconLine(bounds, paint.*, points),
            .circle => |circle| self.iconCircle(bounds, paint.*, circle.cx, circle.cy, circle.radius),
            .ellipse => |ellipse| self.iconEllipse(bounds, paint.*, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry, ellipse.full),
            .round_rect => |rect| self.iconRoundRect(bounds, paint.*, rect.x, rect.y, rect.w, rect.h, rect.radius),
            .filled_circle => |circle| self.iconFilledCircle(bounds, paint.*, circle.cx, circle.cy, circle.radius),
            .filled_ellipse => |ellipse| self.iconFilledEllipse(bounds, paint.*, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry),
            .filled_round_rect => |rect| self.iconFilledRoundRect(bounds, paint.*, rect.x, rect.y, rect.w, rect.h, rect.radius),
            .begin_fill_path => {
                self.finishIconPathMask(mask, path, paint.*);
                path.beginFill(.nonzero);
            },
            .begin_evenodd_fill_path => {
                self.finishIconPathMask(mask, path, paint.*);
                path.beginFill(.evenodd);
            },
            .end_fill_path => {
                self.fillIconPath(bounds, paint.*, path);
                path.clearFill();
            },
            .move_to => |point| {
                if (path.fill_active) {
                    path.fillMoveTo(point);
                    return;
                }
                if (path.has_segment) {
                    self.finishIconPathMask(mask, path, paint.*);
                }
                path.moveTo(point);
            },
            .line_to => |point| {
                if (path.fill_active) {
                    path.fillLineTo(point);
                    return;
                }
                if (path.current) |current| self.strokePathSegmentMask(mask, path, current, point, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
                path.lineTo(point);
            },
            .quad_to => |quad| {
                if (path.fill_active) {
                    if (path.current) |current| self.fillQuadraticPath(path, current, quad.control, quad.end);
                    path.lineTo(quad.end);
                    return;
                }
                if (path.current) |current| self.strokeQuadraticPathMask(mask, path, current, quad.control, quad.end);
                path.lineTo(quad.end);
            },
            .cubic_to => |cubic| {
                if (path.fill_active) {
                    if (path.current) |current| self.fillCubicPath(path, current, cubic.control0, cubic.control1, cubic.end);
                    path.lineTo(cubic.end);
                    return;
                }
                if (path.current) |current| self.strokeCubicPathMask(mask, path, current, cubic.control0, cubic.control1, cubic.end);
                path.lineTo(cubic.end);
            },
            .arc_to => |arc| {
                if (path.fill_active) {
                    if (path.current) |current| self.fillArcPath(path, current, arc);
                    path.lineTo(arc.end);
                    return;
                }
                if (path.current) |current| self.strokeArcPathMask(mask, path, current, arc);
                path.lineTo(arc.end);
            },
            .close_path => if (path.current) |current| if (path.start) |start| {
                if (path.fill_active) {
                    path.closeFillSubpath();
                    return;
                }
                self.strokePathSegmentMask(mask, path, current, start, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
                self.strokeRoundPointMask(mask, start, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
                path.closed = true;
                path.lineTo(start);
            },
        }
    }

    fn finishIconPathMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, color: ui.Color) void {
        self.finishIconSubpath(mask, path);
        self.blendIconMask(mask, color);
        mask.clear();
    }

    fn iconLine(self: Surface, bounds: ui.Rect, color: ui.Color, points: []const f32) void {
        if (points.len < 4) return;
        var index: usize = 2;
        while (index < points.len) : (index += 2) {
            self.strokeSegment(bounds, color, points[index - 2], points[index - 1], points[index], points[index + 1]);
        }
    }

    fn iconCircle(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, radius: f32) void {
        self.strokeEllipse(bounds, color, x, y, radius, radius, true);
    }

    fn iconEllipse(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, rx: f32, ry: f32, full: bool) void {
        self.strokeEllipse(bounds, color, x, y, rx, ry, full);
    }

    fn iconFilledCircle(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, radius: f32) void {
        const size = @min(bounds.w, bounds.h);
        const cx = bounds.x + bounds.w * x;
        const cy = bounds.y + bounds.h * y;
        const r = size * radius;
        const area = ui.Rect.init(cx - r, cy - r, r * 2.0, r * 2.0);
        self.fillRounded(area, color, color, r);
    }

    fn iconFilledEllipse(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, rx: f32, ry: f32) void {
        const cx = bounds.x + bounds.w * x;
        const cy = bounds.y + bounds.h * y;
        const radius_x = bounds.w * rx;
        const radius_y = bounds.h * ry;
        if (radius_x <= 0.0 or radius_y <= 0.0) return;
        const area = ui.Rect.init(cx - radius_x - antialias_width, cy - radius_y - antialias_width, (radius_x + antialias_width) * 2.0, (radius_y + antialias_width) * 2.0);
        const x_start = clampCoord(@intFromFloat(@floor(area.x)), self.width);
        const y_start = clampCoord(@intFromFloat(@floor(area.y)), self.height);
        const x_end = clampCoord(@intFromFloat(@ceil(area.x + area.w)), self.width);
        const y_end = clampCoord(@intFromFloat(@ceil(area.y + area.h)), self.height);
        var py_i = y_start;
        while (py_i < y_end) : (py_i += 1) {
            var px_i = x_start;
            while (px_i < x_end) : (px_i += 1) {
                const px = @as(f32, @floatFromInt(px_i)) + pixel_center;
                const py = @as(f32, @floatFromInt(py_i)) + pixel_center;
                const nx = (px - cx) / radius_x;
                const ny = (py - cy) / radius_y;
                const distance = (1.0 - @sqrt(nx * nx + ny * ny)) * @min(radius_x, radius_y);
                const alpha = coverageAlpha(0.0, -distance);
                if (alpha != 0) self.blendPixel(px_i, py_i, color, alpha);
            }
        }
    }

    fn iconRoundRect(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, w: f32, h: f32, radius: f32) void {
        const rect = ui.Rect.init(bounds.x + bounds.w * x, bounds.y + bounds.h * y, bounds.w * w, bounds.h * h);
        self.strokeRounded(rect, color, @min(bounds.w, bounds.h) * radius, iconStroke(bounds));
    }

    fn iconFilledRoundRect(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, w: f32, h: f32, radius: f32) void {
        const rect = ui.Rect.init(bounds.x + bounds.w * x, bounds.y + bounds.h * y, bounds.w * w, bounds.h * h);
        self.fillRounded(rect, color, color, @min(bounds.w, bounds.h) * radius);
    }

    fn strokeSegment(self: Surface, bounds: ui.Rect, color: ui.Color, x0n: f32, y0n: f32, x1n: f32, y1n: f32) void {
        const x0 = bounds.x + bounds.w * x0n;
        const y0 = bounds.y + bounds.h * y0n;
        const x1 = bounds.x + bounds.w * x1n;
        const y1 = bounds.y + bounds.h * y1n;
        const radius = iconStroke(bounds) * 0.5;
        const left = @min(x0, x1) - radius;
        const top = @min(y0, y1) - radius;
        const right = @max(x0, x1) + radius;
        const bottom = @max(y0, y1) + radius;
        const x_start = clampCoord(@intFromFloat(@floor(left)), self.width);
        const y_start = clampCoord(@intFromFloat(@floor(top)), self.height);
        const x_end = clampCoord(@intFromFloat(@ceil(right)), self.width);
        const y_end = clampCoord(@intFromFloat(@ceil(bottom)), self.height);
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
                const t = std.math.clamp(((px - x0) * dx + (py - y0) * dy) / denom, 0.0, 1.0);
                const cx = x0 + dx * t;
                const cy = y0 + dy * t;
                const dist = @sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
                const alpha = strokeCoverageAlpha(radius, dist, active_icon_tuning.stroke_antialias_width, boost_coverage, active_icon_tuning.line_stroke_coverage_boost);
                if (alpha != 0) self.blendPixelMaxAlpha(x, y, color, alpha);
            }
        }
    }

    fn strokePathSegmentMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, start: icon_vector.Point, end: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
        if (path.has_segment) {
            self.strokeRoundPointMask(mask, start, antialias_width_value, coverage_boost);
        } else {
            path.first_segment_start = start;
            path.first_cap_antialias_width = antialias_width_value;
            path.first_cap_coverage_boost = coverage_boost;
            path.has_segment = true;
        }
        self.strokeSegmentMaskButt(mask, start.x, start.y, end.x, end.y, antialias_width_value, coverage_boost);
        path.last_segment_end = end;
        path.last_cap_antialias_width = antialias_width_value;
        path.last_cap_coverage_boost = coverage_boost;
        path.segment_count += 1;
    }

    fn finishIconSubpath(self: Surface, mask: *IconAlphaMask, path: *IconPathState) void {
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
        self.strokeRoundPointMask(mask, path.first_segment_start, cap_antialias_width, first_cap_boost);
        self.strokeRoundPointMask(mask, path.last_segment_end, cap_antialias_width, last_cap_boost);
        path.clearStroke();
    }

    fn strokeSegmentMaskButt(self: Surface, mask: *IconAlphaMask, x0n: f32, y0n: f32, x1n: f32, y1n: f32, antialias_width_value: f32, coverage_boost: f32) void {
        _ = self;
        const bounds = mask.bounds;
        const x0 = bounds.x + bounds.w * x0n;
        const y0 = bounds.y + bounds.h * y0n;
        const x1 = bounds.x + bounds.w * x1n;
        const y1 = bounds.y + bounds.h * y1n;
        const radius = iconStroke(bounds) * 0.5;
        const left = @min(x0, x1) - radius;
        const top = @min(y0, y1) - radius;
        const right = @max(x0, x1) + radius;
        const bottom = @max(y0, y1) + radius;
        const x_start = mask.clampX(@intFromFloat(@floor(left)));
        const y_start = mask.clampY(@intFromFloat(@floor(top)));
        const x_end = mask.clampX(@intFromFloat(@ceil(right)));
        const y_end = mask.clampY(@intFromFloat(@ceil(bottom)));
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
                const dist = @sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
                const alpha = strokeCoverageAlpha(radius, dist, antialias_width_value, boost_coverage, coverage_boost);
                if (alpha != 0) mask.writeMax(x, y, alpha);
            }
        }
    }

    fn strokeRoundPointMask(self: Surface, mask: *IconAlphaMask, point: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
        _ = self;
        const bounds = mask.bounds;
        const cx = bounds.x + bounds.w * point.x;
        const cy = bounds.y + bounds.h * point.y;
        const radius = iconStroke(bounds) * 0.5;
        const x_start = mask.clampX(@intFromFloat(@floor(cx - radius)));
        const y_start = mask.clampY(@intFromFloat(@floor(cy - radius)));
        const x_end = mask.clampX(@intFromFloat(@ceil(cx + radius)));
        const y_end = mask.clampY(@intFromFloat(@ceil(cy + radius)));
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + icon_pixel_center;
                const py = @as(f32, @floatFromInt(y)) + icon_pixel_center;
                const dx = px - cx;
                const dy = py - cy;
                const dist = @sqrt(dx * dx + dy * dy);
                const alpha = strokeCoverageAlpha(radius, dist, antialias_width_value, true, coverage_boost);
                if (alpha != 0) mask.writeMax(x, y, alpha);
            }
        }
    }

    fn strokeQuadraticPathMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, start: icon_vector.Point, control: icon_vector.Point, end: icon_vector.Point) void {
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
            self.strokePathSegmentMask(mask, path, previous, next, active_icon_tuning.stroke_antialias_width, active_icon_tuning.curve_stroke_coverage_boost);
            previous = next;
        }
    }

    fn strokeCubicPathMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, start: icon_vector.Point, control0: icon_vector.Point, control1: icon_vector.Point, end: icon_vector.Point) void {
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
            self.strokePathSegmentMask(mask, path, previous, next, active_icon_tuning.stroke_antialias_width, active_icon_tuning.curve_stroke_coverage_boost);
            previous = next;
        }
    }

    fn strokeArcPathMask(self: Surface, mask: *IconAlphaMask, path: *IconPathState, start: icon_vector.Point, arc: icon_vector.Arc) void {
        const geometry = svgArcGeometry(start, arc) orelse {
            self.strokePathSegmentMask(mask, path, start, arc.end, active_icon_tuning.stroke_antialias_width, active_icon_tuning.line_stroke_coverage_boost);
            return;
        };
        const steps = arcStepCount(geometry.delta, arc);
        const arc_antialias_width = arcAntialiasWidth(arc);
        var previous = start;
        var step: usize = 1;
        while (step <= steps) : (step += 1) {
            const next = geometry.pointAt(step, steps);
            self.strokePathSegmentMask(mask, path, previous, next, arc_antialias_width, active_icon_tuning.arc_stroke_coverage_boost);
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

    fn fillIconPath(self: Surface, bounds: ui.Rect, color: ui.Color, path: *const IconPathState) void {
        if (path.fill_point_len < min_fill_path_points) return;
        const x_start = clampCoord(@intFromFloat(@floor(bounds.x)), self.width);
        const y_start = clampCoord(@intFromFloat(@floor(bounds.y)), self.height);
        const x_end = clampCoord(@intFromFloat(@ceil(bounds.x + bounds.w)), self.width);
        const y_end = clampCoord(@intFromFloat(@ceil(bounds.y + bounds.h)), self.height);
        var y = y_start;
        while (y < y_end) : (y += 1) {
            var x = x_start;
            while (x < x_end) : (x += 1) {
                const coverage = self.fillPathCoverage(bounds, path, x, y);
                if (coverage != 0) self.blendPixel(x, y, color, coverage);
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

    fn blendIconMask(self: Surface, mask: *const IconAlphaMask, color: ui.Color) void {
        var row: usize = 0;
        while (row < mask.height) : (row += 1) {
            var col: usize = 0;
            while (col < mask.width) : (col += 1) {
                const alpha = mask.pixels[row * mask.width + col];
                if (alpha > icon_alpha_floor) self.blendPixelPathAlpha(mask.x + col, mask.y + row, color, alpha);
            }
        }
    }

    fn strokeEllipse(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, rx: f32, ry: f32, full: bool) void {
        const cx = bounds.x + bounds.w * x;
        const cy = bounds.y + bounds.h * y;
        const radius_x = bounds.w * rx;
        const radius_y = bounds.h * ry;
        const stroke = iconStroke(bounds);
        const area = ui.Rect.init(cx - radius_x - stroke, cy - radius_y - stroke, (radius_x + stroke) * 2.0, (radius_y + stroke) * 2.0);
        const x_start = clampCoord(@intFromFloat(@floor(area.x)), self.width);
        const y_start = clampCoord(@intFromFloat(@floor(area.y)), self.height);
        const x_end = clampCoord(@intFromFloat(@ceil(area.x + area.w)), self.width);
        const y_end = clampCoord(@intFromFloat(@ceil(area.y + area.h)), self.height);
        var py_i = y_start;
        while (py_i < y_end) : (py_i += 1) {
            var px_i = x_start;
            while (px_i < x_end) : (px_i += 1) {
                const px = @as(f32, @floatFromInt(px_i)) + pixel_center;
                const py = @as(f32, @floatFromInt(py_i)) + pixel_center;
                if (!full and py < cy) continue;
                const nx = (px - cx) / @max(1.0, radius_x);
                const ny = (py - cy) / @max(1.0, radius_y);
                const distance = @abs(@sqrt(nx * nx + ny * ny) - 1.0) * @min(radius_x, radius_y);
                const alpha = coverageAlpha(stroke * 0.5, distance);
                if (alpha != 0) self.blendPixel(px_i, py_i, color, alpha);
            }
        }
    }

    fn fillPieSlice(self: Surface, bounds: ui.Rect, color: ui.Color, encoded_angles: ui.Color) void {
        const x0 = clampCoord(@intFromFloat(@floor(bounds.x)), self.width);
        const y0 = clampCoord(@intFromFloat(@floor(bounds.y)), self.height);
        const x1 = clampCoord(@intFromFloat(@ceil(bounds.x + bounds.w)), self.width);
        const y1 = clampCoord(@intFromFloat(@ceil(bounds.y + bounds.h)), self.height);
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
                const distance = @sqrt(dx * dx + dy * dy);
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
        const pad = iconStroke(bounds);
        const x0 = clampCoord(@intFromFloat(@floor(bounds.x - pad)), surface_width);
        const y0 = clampCoord(@intFromFloat(@floor(bounds.y - pad)), surface_height);
        const x1 = clampCoord(@intFromFloat(@ceil(bounds.x + bounds.w + pad)), surface_width);
        const y1 = clampCoord(@intFromFloat(@ceil(bounds.y + bounds.h + pad)), surface_height);
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

    fn clear(self: *IconAlphaMask) void {
        @memset(self.pixels, 0);
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
const small_text_sharpen_max_glyph_h: f32 = 14.0;
const small_text_sharpen_midpoint: f32 = 128.0;
const small_text_sharpen_contrast: f32 = 1.18;
const small_text_sharpen_lift: f32 = 8.0;
const font_bitmap_bytes: usize = 4 * 1024 * 1024;
var geist_face: ?varfont.Face = null;
var geist_bitmap: [font_bitmap_bytes]u8 = undefined;
var geist_cache: ?varfont.Cache = null;

fn textCache() *varfont.Cache {
    if (geist_cache == null) {
        const face = varfont.Face.geist() catch unreachable;
        geist_face = face;
        geist_cache = varfont.Cache.init(geist_face.?, &geist_bitmap);
        _ = geist_cache.?.setAxis("wght", 560.0);
    }
    return &geist_cache.?;
}

fn textPxSize(bounds: ui.Rect) f32 {
    return @max(11.0, @min(22.0, bounds.h));
}

fn measureText(value: []const u8, px_size: f32) f32 {
    const face = if (geist_face) |face| face else blk: {
        const parsed = varfont.Face.geist() catch unreachable;
        geist_face = parsed;
        break :blk parsed;
    };
    var width: f32 = 0.0;
    var previous: u16 = 0;
    for (value) |byte| {
        if (byte >= 0x80) unreachable;
        const glyph_id = face.glyphId(@intCast(byte));
        if (previous != 0) width += face.kern(previous, glyph_id, px_size);
        width += face.advance(glyph_id, px_size);
        previous = glyph_id;
    }
    return width;
}

fn iconStroke(bounds: ui.Rect) f32 {
    return @max(1.5, @min(bounds.w, bounds.h) * icon_stroke_scale);
}

const icon_stroke_scale: f32 = 2.0 / 24.0;
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
    const rx_start = @abs(arc.rx);
    const ry_start = @abs(arc.ry);
    if (rx_start <= 0.0 or ry_start <= 0.0) return null;
    const phi = arc.x_axis_rotation * std.math.pi / 180.0;
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
        const scale = @sqrt(radius_scale);
        rx *= scale;
        ry *= scale;
    }
    const numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    const denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    const sign: f32 = if (arc.large_arc == arc.sweep) -1.0 else 1.0;
    const coefficient = sign * @sqrt(@max(0.0, numerator / @max(denominator, svg_arc_denominator_min)));
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
    if (!arc.sweep and delta > 0.0) delta -= std.math.tau;
    if (arc.sweep and delta < 0.0) delta += std.math.tau;
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
    return @max(4, @as(usize, @intFromFloat(@ceil(@abs(delta) * divisor / std.math.pi))));
}

fn arcAntialiasWidth(arc: icon_vector.Arc) f32 {
    if (@max(arc.rx, arc.ry) >= icon_large_arc_radius_threshold) return active_icon_tuning.large_arc_antialias_width;
    return active_icon_tuning.arc_antialias_width;
}

fn vectorAngle(left: icon_vector.Point, right: icon_vector.Point) f32 {
    const dot = left.x * right.x + left.y * right.y;
    const det = left.x * right.y - left.y * right.x;
    return std.math.atan2(det, dot);
}

fn coverageAlpha(radius: f32, distance: f32) u8 {
    if (distance <= radius - antialias_width) return max_alpha;
    if (distance >= radius + antialias_width) return 0;
    const coverage = (radius + antialias_width - distance) / (antialias_width * 2.0);
    return @intFromFloat(@round(std.math.clamp(coverage, 0.0, 1.0) * 255.0));
}

fn isSlopedSegment(dx: f32, dy: f32) bool {
    return @abs(dx) > icon_axis_epsilon and @abs(dy) > icon_axis_epsilon;
}

fn strokeCoverageAlpha(radius: f32, distance: f32, antialias_width_value: f32, boost_coverage: bool, coverage_boost: f32) u8 {
    if (distance <= radius - antialias_width_value) return max_alpha;
    if (distance >= radius + antialias_width_value) return 0;
    const t = (radius + antialias_width_value - distance) / (antialias_width_value * 2.0);
    const coverage = if (boost_coverage and t > icon_stroke_coverage_boost_floor)
        t + coverage_boost * (t - icon_stroke_coverage_boost_floor) * (1.0 - t)
    else
        t;
    return @intFromFloat(@round(std.math.clamp(coverage, 0.0, 1.0) * 255.0));
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

fn roundedOutsideDistance(bounds: ui.Rect, radius: f32, x: f32, y: f32) f32 {
    const r = @min(@max(radius, 0.0), @max(0.0, @min(bounds.w, bounds.h) * 0.5));
    const half_w = bounds.w * 0.5;
    const half_h = bounds.h * 0.5;
    const center_x = bounds.x + half_w;
    const center_y = bounds.y + half_h;
    const qx = @abs(x - center_x) - @max(0.0, half_w - r);
    const qy = @abs(y - center_y) - @max(0.0, half_h - r);
    const outside_x = @max(qx, 0.0);
    const outside_y = @max(qy, 0.0);
    const outside = @sqrt(outside_x * outside_x + outside_y * outside_y);
    const inside = @min(@max(qx, qy), 0.0);
    return outside + inside - r;
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

fn colorsEqual(a: ui.Color, b: ui.Color) bool {
    return a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a;
}

fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * std.math.clamp(t, 0.0, 1.0);
}

fn scaleByte(value: u8, factor: f32) u8 {
    return @intFromFloat(@round(std.math.clamp(@as(f32, @floatFromInt(value)) * factor, 0.0, 255.0)));
}

fn nearestSampleIndex(value: f32, max_index_float: f32, len: usize) usize {
    const scaled = std.math.clamp(value, 0.0, 1.0) * max_index_float;
    const index: usize = @intFromFloat(@round(scaled));
    return @min(index, len - 1);
}

const BilinearAxis = struct {
    index0: usize,
    index1: usize,
    fraction: f32,
};

fn bilinearAxis(value: f32, max_index_float: f32, len: usize) BilinearAxis {
    const scaled = std.math.clamp(value, 0.0, 1.0) * max_index_float;
    const index0: usize = @intFromFloat(@floor(scaled));
    return .{
        .index0 = index0,
        .index1 = @min(index0 + 1, len - 1),
        .fraction = scaled - @as(f32, @floatFromInt(index0)),
    };
}

fn bilinearAlphaByte(a00: u8, a10: u8, a01: u8, a11: u8, tx: f32, ty: f32) u8 {
    return @intFromFloat(@round(lerp(
        lerp(@as(f32, @floatFromInt(a00)), @as(f32, @floatFromInt(a10)), tx),
        lerp(@as(f32, @floatFromInt(a01)), @as(f32, @floatFromInt(a11)), tx),
        ty,
    )));
}

fn scaleAlphaByte(tint: u8, sample: u8) u8 {
    if (tint == max_alpha) return sample;
    return @intCast((@as(u16, tint) * @as(u16, sample) + 127) / 255);
}

fn sharpenSmallTextAlpha(sample: u8) u8 {
    if (sample == 0 or sample == max_alpha) return sample;
    const value = small_text_sharpen_midpoint +
        (@as(f32, @floatFromInt(sample)) - small_text_sharpen_midpoint) * small_text_sharpen_contrast +
        small_text_sharpen_lift;
    return @intFromFloat(@round(std.math.clamp(value, 0.0, byte_unit_scale)));
}

fn sampleRgba(texture: RgbaTexture, u: f32, v: f32) ui.Color {
    const x = std.math.clamp(u, 0.0, 1.0) * @as(f32, @floatFromInt(texture.width - 1));
    const y = std.math.clamp(v, 0.0, 1.0) * @as(f32, @floatFromInt(texture.height - 1));
    const x0: usize = @intFromFloat(@floor(x));
    const y0: usize = @intFromFloat(@floor(y));
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
    return @intFromFloat(@round(lerp(top, bottom, ty)));
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
    var turn = std.math.atan2(dy, dx) / std.math.tau + quarter_turn;
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
    return std.math.clamp(as_usize, start, limit);
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
    try ui_components.renderNode(&scene, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, root, .{});

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
    try std.testing.expect(geometry.delta < std.math.pi);
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

    surface.strokePathSegmentMask(&mask, &path, start, end, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    try std.testing.expectEqual(@as(u8, 0), iconMaskPixel(mask, 5, 12));

    surface.finishIconSubpath(&mask, &path);
    try std.testing.expect(iconMaskPixel(mask, 5, 12) > 0);
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

    surface.strokePathSegmentMask(&mask, &path, start, mid, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    surface.strokePathSegmentMask(&mask, &path, mid, start, icon_stroke_antialias_width_default, icon_line_stroke_coverage_boost_default);
    try std.testing.expect(path.endsAtStart());

    surface.finishIconSubpath(&mask, &path);
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

    surface.finishIconPathMask(&mask, &path, .{ .r = 255, .g = 255, .b = 255 });
    const first_alpha = pixels[0].a;
    try std.testing.expect(first_alpha > 0);
    try std.testing.expectEqual(@as(u8, 0), mask.pixels[0]);

    mask.pixels[0] = 128;
    surface.finishIconPathMask(&mask, &path, .{ .r = 255, .g = 255, .b = 255 });
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
        \\  <rect x="14" y="14" width="8" height="8" fill="rgba(1, 2, 3, .5)"/>
        \\</svg>
    ;
    var pixels: [24 * 24]ui.Color = undefined;
    const surface = try Surface.init(24, 24, &pixels);
    surface.clear(ui.Color.clear);

    surface.drawIconSvg(ui.Rect.init(0, 0, 24, 24), .{ .r = 20, .g = 200, .b = 20, .a = 255 }, svg);

    try std.testing.expectEqual(ui.Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, pixels[8 * 24 + 6]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 0, .b = 255, .a = 255 }, pixels[8 * 24 + 18]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 255, .b = 0, .a = 128 }, pixels[18 * 24 + 6]);
    try std.testing.expectEqual(ui.Color{ .r = 1, .g = 2, .b = 3, .a = 128 }, pixels[18 * 24 + 18]);
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
    surface.rasterize(scene.written());

    try std.testing.expectEqual(ui.Color.clear, pixels[8 * 64 + 8]);
    const top = pixels[12 * 64 + 20];
    const bottom = pixels[28 * 64 + 20];
    try std.testing.expect(top.r > top.b);
    try std.testing.expect(bottom.b > bottom.r);
    try std.testing.expect(pixels[18 * 64 + 39].a > 0);
}

test "software renderer rasterizes rect ir equivalent to command path" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try scene.pushRect(ui.Rect.init(0.0, 0.0, 64.0, 48.0), .bg, .fill, 0.0, 0.0);
    try scene.pushGradientRect(ui.Rect.init(8.0, 8.0, 24.0, 24.0), .{ .r = 240, .g = 40, .b = 40 }, .{ .r = 40, .g = 40, .b = 240 }, 8.0);
    try scene.pushRect(ui.Rect.init(42.0, 18.0, 12.0, 12.0), .{ .r = 0, .g = 0, .b = 0, .a = 120 }, .shadow, 4.0, 5.0);
    try scene.pushRect(ui.Rect.init(44.0, 20.0, 10.0, 10.0), .accent, .border, 3.0, 0.0);

    var command_pixels: [64 * 48]ui.Color = undefined;
    const command_surface = try Surface.init(64, 48, &command_pixels);
    command_surface.clear(.clear);
    command_surface.rasterize(scene.written());

    var storage = renderer_ir.FixedBuffers(3, 0, 0, 0, 1, 0, 0){};
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

    try std.testing.expectEqualSlices(ui.Color, &command_pixels, &ir_pixels);
}

test "software renderer rejects textured ir without resources" {
    var pixels: [4]ui.Color = undefined;
    const surface = try Surface.init(2, 2, &pixels);
    var storage = renderer_ir.FixedBuffers(0, 1, 0, 0, 0, 0, 0){};
    storage.text_vertex_len = 1;
    const buffers = storage.buffers();
    try std.testing.expectError(error.UnsupportedIrPrimitive, surface.rasterizeIr(buffers));
}

test "software renderer rasterizes alpha textured ir with supplied resources" {
    var pixels: [8 * 8]ui.Color = undefined;
    const surface = try Surface.init(8, 8, &pixels);
    surface.clear(.clear);

    var storage = renderer_ir.FixedBuffers(0, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
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
    try std.testing.expectEqual(renderer_present.Transport.software_pixels, receipt.transport);
    try std.testing.expectEqual(@as(usize, 1), receipt.primitive_count);
    const pixel = pixels[4 * 8 + 4];
    try std.testing.expect(pixel.a > 0);
    try std.testing.expect(pixel.r > pixel.g);
}

test "software renderer sharpens small text alpha without changing solid coverage" {
    try std.testing.expectEqual(@as(u8, 0), sharpenSmallTextAlpha(0));
    try std.testing.expectEqual(max_alpha, sharpenSmallTextAlpha(max_alpha));
    try std.testing.expect(sharpenSmallTextAlpha(64) < 64);
    try std.testing.expect(sharpenSmallTextAlpha(160) > 160);
}

test "software renderer rasterizes image ir with supplied rgba texture" {
    var pixels: [8 * 8]ui.Color = undefined;
    const surface = try Surface.init(8, 8, &pixels);
    surface.clear(.clear);

    var storage = renderer_ir.FixedBuffers(0, 0, 0, renderer_ir.textured_quad_vertex_count, 0, 0, 0){};
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

    var storage = renderer_ir.FixedBuffers(0, 0, 0, renderer_ir.textured_quad_vertex_count, 0, 0, 0){};
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

fn irTestFontMetrics(_: *anyopaque, _: u8) renderer_ir.TextMetrics {
    return .{ .ascender = 10.0, .descender = -3.0 };
}

fn irTestTextWidth(_: *anyopaque, value: []const u8, _: u8) f32 {
    return @floatFromInt(value.len * 8);
}

fn irTestGlyph(_: *anyopaque, _: u8, _: u8) renderer_ir.Error!?renderer_ir.Glyph {
    return null;
}
