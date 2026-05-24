const std = @import("std");
const icon_vector = @import("icon_vector.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_present = @import("renderer_present.zig");
const ui = @import("ui.zig");
const varfont = @import("varfont.zig");

pub const Error = renderer_present.Error || error{
    PixelBudgetExceeded,
    InvalidIrBuffer,
    InvalidIrResource,
    UnsupportedIrPrimitive,
};

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
        var iter = icon_vector.Iterator.init(icon_vector.dataForIconId(icon_id));
        while (iter.next() catch unreachable) |op| {
            switch (op) {
                .polyline => |points| self.iconLine(bounds, color, points),
                .circle => |circle| self.iconCircle(bounds, color, circle.cx, circle.cy, circle.radius),
                .ellipse => |ellipse| self.iconEllipse(bounds, color, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry, ellipse.full),
                .round_rect => |rect| self.iconRoundRect(bounds, color, rect.x, rect.y, rect.w, rect.h, rect.radius),
                .filled_circle => |circle| self.iconFilledCircle(bounds, color, circle.cx, circle.cy, circle.radius),
            }
        }
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

    fn iconRoundRect(self: Surface, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, w: f32, h: f32, radius: f32) void {
        const rect = ui.Rect.init(bounds.x + bounds.w * x, bounds.y + bounds.h * y, bounds.w * w, bounds.h * h);
        self.strokeRounded(rect, color, @min(bounds.w, bounds.h) * radius, iconStroke(bounds));
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
                const alpha = coverageAlpha(radius, dist);
                if (alpha != 0) self.blendPixel(x, y, color, alpha);
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

const default_raster_scale: f32 = 1.0;
const max_alpha: u8 = 255;
const pixel_center: f32 = 0.5;
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
    return @max(1.5, @min(bounds.w, bounds.h) * 0.09);
}

fn coverageAlpha(radius: f32, distance: f32) u8 {
    if (distance <= radius - antialias_width) return max_alpha;
    if (distance >= radius + antialias_width) return 0;
    const coverage = (radius + antialias_width - distance) / (antialias_width * 2.0);
    return @intFromFloat(@round(std.math.clamp(coverage, 0.0, 1.0) * 255.0));
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
