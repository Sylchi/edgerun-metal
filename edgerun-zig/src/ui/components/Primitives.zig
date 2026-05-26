const layout = @import("../../layouts/Types.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const tokens = @import("../../ui_tokens.zig");
const ui = @import("../../ui.zig");

pub const measure_max_width: f32 = 4096.0;

pub fn measureFixed(preferred: ui.Size, constraints: layout.Constraints) layout.Measurement {
    const resolved_preferred = constrainPreferredSize(preferred, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(preferred.w, resolved_preferred.w), .h = @min(preferred.h, resolved_preferred.h) },
        resolved_preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

pub fn constrainPreferredSize(preferred: ui.Size, constraints: layout.Constraints) ui.Size {
    return .{
        .w = constraints.width.limit(preferred.w),
        .h = constraints.height.limit(preferred.h),
    };
}

pub fn renderControlFrame(scene: *ui.Scene, bounds: ui.Rect, fill: ui.Color, border: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, fill, .fill, radius, 0.0);
    try scene.pushRect(bounds, border, .border, radius, 0.0);
}

pub fn renderControlText(scene: *ui.Scene, bounds: ui.Rect, padding: f32, height: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    if (contentInset(bounds, padding)) |text_bounds| {
        try scene.pushAlignedText(text_bounds.withHeightCentered(height), value, color, alignment);
    }
}

pub fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

pub fn renderControlStateOverlay(scene: *ui.Scene, bounds: ui.Rect, options: common.RenderOptions, radius: f32) ui.RenderError!void {
    const state = options.control;
    if (!state.any()) return;
    if (state.hovered) try scene.pushRect(bounds, common.state_hover_border, .border, radius, 0.0);
    if (state.active) try scene.pushRect(bounds, common.state_active_border, .border, radius, 0.0);
    if (state.focused) try scene.pushRect(bounds.insetUniform(-focus_ring_outset), common.state_focus_border, .border, radius + focus_ring_outset, 0.0);
    if (state.invalid) try scene.pushRect(bounds, common.state_invalid_border, .border, radius, 0.0);
    if (state.loading) {
        const bar = ui.Rect.init(bounds.x, bounds.y + @max(0.0, bounds.h - state_loading_h), @max(min_extent, bounds.w), state_loading_h);
        try scene.pushRect(bar, common.state_loading_fill, .fill, state_loading_h * 0.5, 0.0);
    }
    if (state.disabled) try scene.pushRect(bounds, common.state_disabled_tint, .fill, radius, 0.0);
}

pub const SidePanelLayout = struct {
    trigger_y: f32,
    trigger_w: f32,
    trigger_h: f32,
    gap: f32,
};

pub fn sidePanelTriggerBounds(bounds: ui.Rect, spec: SidePanelLayout) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + spec.trigger_y, spec.trigger_w, spec.trigger_h);
}

pub fn sidePanelContentBounds(bounds: ui.Rect, spec: SidePanelLayout) ui.Rect {
    const x = bounds.x + spec.trigger_w + spec.gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

pub const MenuListLayout = struct {
    padding: f32,
    item_h: f32,
    item_pitch: f32,
    item_radius: f32,
    item_padding: f32,
    item_text_h: f32,
};

pub fn menuItemBounds(content: ui.Rect, index: usize, spec: MenuListLayout) ui.Rect {
    return ui.Rect.init(content.x + spec.padding, content.y + spec.padding + @as(f32, @floatFromInt(index)) * spec.item_pitch, @max(min_extent, content.w - spec.padding * 2.0), spec.item_h);
}

pub fn renderMenuItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: common.RenderOptions, spec: MenuListLayout) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, spec.item_radius, 0.0);
    try renderControlText(scene, bounds, spec.item_padding, spec.item_text_h, label, options.style.text, .start);
}

pub fn collectSidePanelHits(collector: *interaction.Collector, trigger: ui.Rect, content: ui.Rect, id: u32) interaction.Error!void {
    try collector.addHit(trigger, .button, id);
    try collector.addHit(content, .button, id + 1);
}

pub fn collectMenuListHits(collector: *interaction.Collector, content: ui.Rect, id: u32, spec: MenuListLayout, item_count: usize) interaction.Error!void {
    for (0..item_count) |index| {
        try collector.addHit(menuItemBounds(content, index, spec), .row_item, id + @as(u32, @intCast(index + 1)));
    }
}

pub fn renderTextCell(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, fill: ui.Color, border: ui.Color, radius: f32, padding: f32, text_color: ui.Color) ui.RenderError!void {
    try scene.pushRect(bounds, fill, .fill, radius, 0.0);
    try scene.pushRect(bounds, border, .border, radius, 0.0);
    try renderControlText(scene, bounds, padding, control_label_height, label, text_color, .center);
}

pub const min_extent: f32 = 1.0;
pub const control_radius: f32 = tokens.Component.control_radius;
pub const control_text_padding: f32 = tokens.Component.control_text_padding;
pub const control_label_height: f32 = tokens.Component.control_label_height;
const focus_ring_outset: f32 = tokens.Component.focus_ring_outset;
const state_loading_h: f32 = tokens.Component.state_loading_h;
