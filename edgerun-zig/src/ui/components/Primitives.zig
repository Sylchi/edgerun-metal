const layout = @import("../../layouts/Types.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const std = @import("std");
const text_metrics = @import("../../ui_text_metrics.zig");
const tokens = @import("../../ui_tokens.zig");
const ui = @import("../../ui.zig");
const text_component = @import("Text.zig");

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

pub fn textMetrics(value: []const u8, line_height: f32, max_lines: usize) layout.TextMetrics {
    return .{
        .line_height = line_height,
        .average_char_width = text_metrics.averageWidth(value, line_height),
        .max_lines = max_lines,
    };
}

pub fn textWrap(value: []const u8, line_height: f32, max_lines: usize) ui.TextWrap {
    return .{
        .line_height = line_height,
        .average_char_width = text_metrics.averageWidth(value, line_height),
        .max_lines = max_lines,
    };
}

pub fn measuredTextHeight(value: []const u8, width: f32, line_height: f32, max_lines: usize) f32 {
    return layout.measureText(value, .{ .width = .{ .at_most = width }, .text_wrap = .wrap }, textMetrics(value, line_height, max_lines)).preferred.h;
}

pub fn renderControlFrame(scene: *ui.Scene, bounds: ui.Rect, fill: ui.Color, border: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, fill, .fill, radius, 0.0);
    try scene.pushRect(bounds, border, .border, radius, 0.0);
}

pub fn renderControlText(scene: *ui.Scene, bounds: ui.Rect, padding: f32, height: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    if (contentInset(bounds, padding)) |text_bounds| {
        try text_component.Text.renderAligned(scene, text_bounds.withHeightCentered(height), value, color, alignment);
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

pub const Chrome = struct {
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    shadow_color: ?ui.Color = null,
    radius: f32 = 0.0,
    shadow: f32 = 0.0,

    pub fn control(fill: ui.Color, border: ui.Color, radius: f32) Chrome {
        return .{ .fill = fill, .border = border, .radius = radius };
    }

    pub fn panel(fill: ui.Color, border: ui.Color, radius: f32) Chrome {
        return .{ .fill = fill, .border = border, .radius = radius };
    }

    pub fn elevated(fill: ui.Color, border: ?ui.Color, radius: f32, shadow: f32) Chrome {
        return .{ .fill = fill, .border = border, .shadow_color = fill, .radius = radius, .shadow = shadow };
    }

    pub fn shadowOnly(color: ui.Color, radius: f32, shadow: f32) Chrome {
        return .{ .shadow_color = color, .radius = radius, .shadow = shadow };
    }
};

pub fn renderChrome(scene: *ui.Scene, bounds: ui.Rect, chrome: Chrome) ui.RenderError!void {
    if (chrome.shadow > 0.0) try scene.pushRect(bounds, chrome.shadow_color orelse chrome.fill orelse ui.Color.clear, .shadow, chrome.radius, chrome.shadow);
    if (chrome.fill) |fill| try scene.pushRect(bounds, fill, .fill, chrome.radius, 0.0);
    if (chrome.border) |border| try scene.pushRect(bounds, border, .border, chrome.radius, 0.0);
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

pub fn renderControlTrigger(scene: *ui.Scene, trigger: ui.Rect, fill: ui.Color, border: ui.Color, padding: f32, label: []const u8, text_color: ui.Color) ui.RenderError!void {
    try renderControlFrame(scene, trigger, fill, border, control_radius);
    try renderControlText(scene, trigger, padding, control_label_height, label, text_color, .center);
}

pub fn renderSidePanelTrigger(scene: *ui.Scene, bounds: ui.Rect, spec: SidePanelLayout, fill: ui.Color, border: ui.Color, padding: f32, label: []const u8, text_color: ui.Color) ui.RenderError!void {
    try renderControlTrigger(scene, sidePanelTriggerBounds(bounds, spec), fill, border, padding, label, text_color);
}

pub const TitleDetailPanel = struct {
    radius: f32,
    padding: f32,
    title_y: f32,
    title_h: f32,
    detail_y: f32,
    detail_h: f32,
    title_right_inset: f32 = 0.0,
    title_max_lines: usize = 2,
    detail_max_lines: usize = 2,
};

pub fn renderTitleDetailPanel(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: common.RenderOptions, spec: TitleDetailPanel, border: ui.Color, title_color: ui.Color) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.panel, .fill, spec.radius, 0.0);
    try scene.pushRect(bounds, border, .border, spec.radius, 0.0);
    const title_w = @max(min_extent, bounds.w - spec.padding * 2.0 - spec.title_right_inset);
    const title_h = @min(measuredTextHeight(title, title_w, spec.title_h, spec.title_max_lines), @max(min_extent, bounds.h - spec.title_y - spec.padding));
    try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + spec.padding, bounds.y + spec.title_y, title_w, title_h), title, title_color, textWrap(title, spec.title_h, spec.title_max_lines));

    const detail_gap = @max(0.0, spec.detail_y - spec.title_y - spec.title_h);
    const detail_y = spec.title_y + title_h + detail_gap;
    const detail_w = @max(min_extent, bounds.w - spec.padding * 2.0);
    const detail_h = @min(measuredTextHeight(detail, detail_w, spec.detail_h, spec.detail_max_lines), @max(min_extent, bounds.h - detail_y - spec.padding));
    try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + spec.padding, bounds.y + detail_y, detail_w, detail_h), detail, options.style.muted, textWrap(detail, spec.detail_h, spec.detail_max_lines));
}

pub fn measureTitleDetailPanel(title: []const u8, detail: []const u8, constraints: layout.Constraints, spec: TitleDetailPanel) layout.Measurement {
    const title_constraints = constraints.inner(.{ .left = spec.padding, .right = spec.padding + spec.title_right_inset });
    const detail_constraints = constraints.inner(.{ .left = spec.padding, .right = spec.padding });
    const title_text = text_component.Text.measureValue(title, title_constraints, textMetrics(title, spec.title_h, spec.title_max_lines));
    const detail_text = text_component.Text.measureValue(detail, detail_constraints, textMetrics(detail, spec.detail_h, spec.detail_max_lines));
    const detail_gap = @max(0.0, spec.detail_y - spec.title_y - spec.title_h);
    const preferred = constrainPreferredSize(.{
        .w = @max(title_text.preferred.w + spec.title_right_inset, detail_text.preferred.w) + spec.padding * 2.0,
        .h = spec.title_y + title_text.preferred.h + detail_gap + detail_text.preferred.h + spec.padding,
    }, constraints);
    return layout.Measurement.flexible(
        .{
            .w = min_extent + spec.padding * 2.0 + spec.title_right_inset,
            .h = spec.title_y + spec.title_h + detail_gap + spec.detail_h + spec.padding,
        },
        preferred,
        .{ .w = measure_max_width, .h = @max(preferred.h, title_text.max.h + detail_gap + detail_text.max.h + spec.title_y + spec.padding) },
    ).applyExact(constraints);
}

pub fn measureSidePanelTitleDetail(trigger: []const u8, title: []const u8, detail: []const u8, constraints: layout.Constraints, panel: SidePanelLayout, trigger_padding: f32, content: TitleDetailPanel) layout.Measurement {
    const trigger_text = text_component.Text.measureValue(trigger, .{ .width = .unconstrained, .text_wrap = .nowrap }, textMetrics(trigger, control_label_height, 1));
    const trigger_w = trigger_text.preferred.w + trigger_padding * 2.0;
    const content_constraints = constraints.inner(.{ .left = trigger_w + panel.gap });
    const panel_measure = measureTitleDetailPanel(title, detail, content_constraints, content);
    const preferred = constrainPreferredSize(.{
        .w = trigger_w + panel.gap + panel_measure.preferred.w,
        .h = @max(panel.trigger_y + @max(panel.trigger_h, trigger_text.preferred.h + trigger_padding * 2.0), panel_measure.preferred.h),
    }, constraints);
    return layout.Measurement.flexible(
        .{
            .w = min_extent * 2.0 + panel.gap,
            .h = @max(panel.trigger_y + control_label_height + trigger_padding * 2.0, panel_measure.min.h),
        },
        preferred,
        .{ .w = measure_max_width, .h = @max(preferred.h, panel_measure.max.h) },
    ).applyExact(constraints);
}

pub fn collectSidePanelLayoutHits(collector: *interaction.Collector, bounds: ui.Rect, spec: SidePanelLayout, id: u32) interaction.Error!void {
    try collectSidePanelHits(collector, sidePanelTriggerBounds(bounds, spec), sidePanelContentBounds(bounds, spec), id);
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

pub fn renderTwoItemMenuPanel(scene: *ui.Scene, content: ui.Rect, first: []const u8, second: []const u8, options: common.RenderOptions, radius: f32, spec: MenuListLayout) ui.RenderError!void {
    try scene.pushRect(content, options.style.panel, .fill, radius, 0.0);
    try scene.pushRect(content, options.style.border, .border, radius, 0.0);
    try renderMenuItem(scene, menuItemBounds(content, 0, spec), first, options, spec);
    try renderMenuItem(scene, menuItemBounds(content, 1, spec), second, options, spec);
}

pub fn measureTwoItemMenuPanel(first: []const u8, second: []const u8, constraints: layout.Constraints, spec: MenuListLayout) layout.Measurement {
    const item_constraints = constraints.inner(.{ .left = spec.padding + spec.item_padding, .right = spec.padding + spec.item_padding, .top = spec.padding, .bottom = spec.padding });
    const first_text = text_component.Text.measureValue(first, item_constraints, textMetrics(first, spec.item_text_h, 1));
    const second_text = text_component.Text.measureValue(second, item_constraints, textMetrics(second, spec.item_text_h, 1));
    const preferred = constrainPreferredSize(.{
        .w = @max(first_text.preferred.w, second_text.preferred.w) + (spec.padding + spec.item_padding) * 2.0,
        .h = spec.padding * 2.0 + spec.item_h + spec.item_pitch,
    }, constraints);
    return layout.Measurement.flexible(
        .{ .w = min_extent + (spec.padding + spec.item_padding) * 2.0, .h = spec.padding * 2.0 + spec.item_h * 2.0 },
        preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

pub fn measureSidePanelMenu(trigger: []const u8, first: []const u8, second: []const u8, constraints: layout.Constraints, panel: SidePanelLayout, trigger_padding: f32, menu: MenuListLayout) layout.Measurement {
    const trigger_text = text_component.Text.measureValue(trigger, .{ .width = .unconstrained, .text_wrap = .nowrap }, textMetrics(trigger, control_label_height, 1));
    const trigger_w = trigger_text.preferred.w + trigger_padding * 2.0;
    const menu_constraints = constraints.inner(.{ .left = trigger_w + panel.gap });
    const menu_measure = measureTwoItemMenuPanel(first, second, menu_constraints, menu);
    const preferred = constrainPreferredSize(.{
        .w = trigger_w + panel.gap + menu_measure.preferred.w,
        .h = @max(panel.trigger_y + @max(panel.trigger_h, trigger_text.preferred.h + trigger_padding * 2.0), menu_measure.preferred.h),
    }, constraints);
    return layout.Measurement.flexible(
        .{
            .w = min_extent * 2.0 + panel.gap,
            .h = @max(panel.trigger_y + control_label_height + trigger_padding * 2.0, menu_measure.min.h),
        },
        preferred,
        .{ .w = measure_max_width, .h = @max(preferred.h, menu_measure.max.h) },
    ).applyExact(constraints);
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

pub fn collectSidePanelMenuHits(collector: *interaction.Collector, bounds: ui.Rect, panel: SidePanelLayout, id: u32, spec: MenuListLayout, item_count: usize) interaction.Error!void {
    try collector.addHit(sidePanelTriggerBounds(bounds, panel), .button, id);
    try collectMenuListHits(collector, sidePanelContentBounds(bounds, panel), id, spec, item_count);
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

test "component chrome helper emits deterministic frame commands" {
    var commands: [3]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(1, 2, 30, 40);
    const fill = ui.Color{ .r = 1, .g = 2, .b = 3 };
    const border = ui.Color{ .r = 4, .g = 5, .b = 6 };

    try renderChrome(&scene, bounds, .elevated(fill, border, 7.0, 3.0));

    try std.testing.expectEqual(@as(usize, 3), scene.written().len);
    try std.testing.expectEqual(ui.RectMode.shadow, scene.written()[0].rect.mode);
    try std.testing.expectEqual(ui.RectMode.fill, scene.written()[1].rect.mode);
    try std.testing.expectEqual(ui.RectMode.border, scene.written()[2].rect.mode);
    try std.testing.expectEqual(@as(f32, 7.0), scene.written()[1].rect.radius);
    try std.testing.expect(std.meta.eql(border, scene.written()[2].rect.color));
}

test "title detail panel wraps text inside shared overlay primitive" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const spec = TitleDetailPanel{
        .radius = 8.0,
        .padding = 8.0,
        .title_y = 6.0,
        .title_h = 14.0,
        .detail_y = 24.0,
        .detail_h = 12.0,
    };

    try renderTitleDetailPanel(&scene, ui.Rect.init(0, 0, 104, 72), "Runtime authority", "Receipt detail wraps", .{}, spec, ui.Color.border, ui.Color.text);

    try std.testing.expect(scene.written().len > 4);
    for (scene.written()) |command| switch (command) {
        .text => |text| try std.testing.expect(text.origin.w <= 88.0),
        else => {},
    };
}
