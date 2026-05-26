const interaction = @import("../../ui_interaction.zig");
const layout = @import("../../layouts/Types.zig");
const ui = @import("../../ui.zig");
const primitives = @import("Primitives.zig");

pub const SegmentPaint = struct {
    active_fill: ui.Color,
    inactive_fill: ui.Color,
    border: ui.Color,
    active_text: ui.Color,
    inactive_text: ui.Color,
    radius: f32 = 0.0,
    padding: f32 = primitives.control_text_padding,
};

pub fn renderSegment(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, paint: SegmentPaint) ui.RenderError!void {
    try primitives.renderTextCell(
        scene,
        bounds,
        label,
        if (active) paint.active_fill else paint.inactive_fill,
        paint.border,
        paint.radius,
        paint.padding,
        if (active) paint.active_text else paint.inactive_text,
    );
}

pub const SegmentMeasure = struct {
    item_count: usize,
    height: f32,
    padding: f32 = primitives.control_text_padding,
    gap: f32 = 0.0,
    min_width: f32 = 0.0,
    line_height: f32 = primitives.control_label_height,
    max_lines: usize = 1,
};

pub fn measureSegments(labels: []const []const u8, constraints: layout.Constraints, spec: SegmentMeasure) layout.Measurement {
    const item_count = @max(spec.item_count, labels.len);
    var item_w: f32 = spec.min_width;
    var item_h: f32 = spec.height;
    for (labels) |label| {
        const measured = layout.measureText(label, .{ .width = .unconstrained, .text_wrap = .nowrap }, primitives.textMetrics(label, spec.line_height, spec.max_lines));
        item_w = @max(item_w, measured.preferred.w + spec.padding * 2.0);
        item_h = @max(item_h, measured.preferred.h + spec.padding * 2.0);
    }
    const count_f = @as(f32, @floatFromInt(item_count));
    const min_total_w = spec.min_width * count_f + spec.gap * @max(0.0, count_f - 1.0);
    const preferred = primitives.constrainPreferredSize(.{
        .w = item_w * count_f + spec.gap * @max(0.0, count_f - 1.0),
        .h = item_h,
    }, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(min_total_w, preferred.w), .h = @min(spec.height, preferred.h) },
        preferred,
        .{ .w = primitives.measure_max_width, .h = @max(preferred.h, spec.height) },
    ).applyExact(constraints);
}

pub fn equalSegmentBounds(bounds: ui.Rect, index: usize, item_count: usize) ui.Rect {
    const count = @max(@as(f32, @floatFromInt(item_count)), 1.0);
    const segment_w = @max(primitives.min_extent, bounds.w / count);
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * segment_w, bounds.y, segment_w, bounds.h);
}

pub fn paddedEqualSegmentBounds(bounds: ui.Rect, index: usize, item_count: usize, padding: f32) ui.Rect {
    return equalSegmentBounds(bounds.insetUniform(padding), index, item_count);
}

pub fn collectEqualSegmentHits(collector: *interaction.Collector, bounds: ui.Rect, id: u32, item_count: usize) interaction.Error!void {
    for (0..item_count) |index| {
        try collector.addHit(equalSegmentBounds(bounds, index, item_count), .button, id + @as(u32, @intCast(index)));
    }
}

pub fn collectPaddedEqualSegmentHits(collector: *interaction.Collector, bounds: ui.Rect, id: u32, item_count: usize, padding: f32) interaction.Error!void {
    for (0..item_count) |index| {
        try collector.addHit(paddedEqualSegmentBounds(bounds, index, item_count, padding), .button, id + @as(u32, @intCast(index)));
    }
}

pub fn fixedPitchItemBounds(bounds: ui.Rect, index: usize, item_w: f32, item_h: f32, gap: f32) ui.Rect {
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * (item_w + gap), bounds.y, item_w, @min(bounds.h, item_h));
}

pub fn collectFixedPitchHits(collector: *interaction.Collector, bounds: ui.Rect, id: u32, item_count: usize, item_w: f32, item_h: f32, gap: f32) interaction.Error!void {
    for (0..item_count) |index| {
        try collector.addHit(fixedPitchItemBounds(bounds, index, item_w, item_h, gap), .button, id + @as(u32, @intCast(index)));
    }
}

pub const ItemStripLayout = struct {
    padding: f32 = 0.0,
    gap: f32 = 0.0,
    item_h: f32,
};

pub fn itemStripBounds(bounds: ui.Rect, index: usize, widths: []const f32, spec: ItemStripLayout) ui.Rect {
    var x = bounds.x + spec.padding;
    for (widths[0..@min(index, widths.len)]) |width| {
        x += width + spec.gap;
    }
    const resolved_w = if (index < widths.len) widths[index] else primitives.min_extent;
    const resolved_h = @min(@max(primitives.min_extent, bounds.h - spec.padding * 2.0), spec.item_h);
    return ui.Rect.init(x, bounds.y + spec.padding, resolved_w, resolved_h);
}

pub fn collectItemStripHits(collector: *interaction.Collector, bounds: ui.Rect, id: u32, widths: []const f32, spec: ItemStripLayout) interaction.Error!void {
    for (widths, 0..) |_, index| {
        try collector.addHit(itemStripBounds(bounds, index, widths, spec), .button, id + @as(u32, @intCast(index)));
    }
}

pub fn clampedIndex(value: u16, item_count: u16) u16 {
    if (item_count == 0) return 0;
    return @min(value, item_count - 1);
}

pub fn encodedIndexedId(id: u32, active: u16, item_count: u16) u32 {
    return id * item_count + clampedIndex(active, item_count);
}
