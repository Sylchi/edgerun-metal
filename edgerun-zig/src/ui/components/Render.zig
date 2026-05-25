const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const ui = @import("../../ui.zig");

const RenderOptions = common.RenderOptions;

const max_children: usize = 64;

pub fn renderComponent(comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, component: Component, options: RenderOptions) ui.RenderError!void {
    switch (component) {
        .text => |text| try text.render(scene, bounds, options),
        .card => |card| try card.render(scene, bounds, options),
        .badge => |badge| try badge.render(scene, bounds, options),
        .avatar => |avatar| try avatar.render(scene, bounds, options),
        .kbd => |kbd| try kbd.render(scene, bounds, options),
        .separator => |separator| try separator.render(scene, bounds, options),
        .button => |button| try button.render(scene, bounds, options),
        .input => |input| try input.render(scene, bounds, options),
        .textarea => |textarea| try textarea.render(scene, bounds, options),
        .select => |select| try select.render(scene, bounds, options),
        .checkbox => |checkbox| try checkbox.render(scene, bounds, options),
        .switch_control => |switch_control| try switch_control.render(scene, bounds, options),
        .progress => |progress| try progress.render(scene, bounds, options),
        .slider => |slider| try slider.render(scene, bounds, options),
        .row_item => |row| try row.render(scene, bounds, options),
    }
}

pub fn collectComponentInteractions(comptime Component: type, collector: *interaction.Collector, bounds: ui.Rect, component: Component) interaction.Error!void {
    switch (component) {
        .button => |button| try button.collectInteractions(collector, bounds),
        .input => |input| try input.collectInteractions(collector, bounds),
        .textarea => |textarea| try textarea.collectInteractions(collector, bounds),
        .select => |select| try select.collectInteractions(collector, bounds),
        .checkbox => |checkbox| try checkbox.collectInteractions(collector, bounds),
        .switch_control => |switch_control| try switch_control.collectInteractions(collector, bounds),
        .slider => |slider| try slider.collectInteractions(collector, bounds),
        .row_item => |row| try row.collectInteractions(collector, bounds),
        else => {},
    }
}

pub fn measureComponent(comptime Component: type, component: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return switch (component) {
        .text => |text| text.measure(constraints, options),
        .card => |card| card.measure(constraints, options),
        .badge => |badge| badge.measure(constraints, options),
        .avatar => |avatar| avatar.measure(constraints, options),
        .kbd => |kbd| kbd.measure(constraints, options),
        .separator => |separator| separator.measure(constraints, options),
        .button => |button| button.measure(constraints, options),
        .input => |input| input.measure(constraints, options),
        .textarea => |textarea| textarea.measure(constraints, options),
        .select => |select| select.measure(constraints, options),
        .checkbox => |checkbox| checkbox.measure(constraints, options),
        .switch_control => |switch_control| switch_control.measure(constraints, options),
        .progress => |progress| progress.measure(constraints, options),
        .slider => |slider| slider.measure(constraints, options),
        .row_item => |row| row.measure(constraints, options),
    };
}

pub fn measureStack(comptime Component: type, stack: anytype, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    const measured_children = measureChildren(Component, stack.children, stackChildConstraints(stack, constraints), options, &child_measurements);
    return layouts.Flex.measure(measured_children, constraints, stackLayoutOptions(stack));
}

pub fn renderStack(comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, stack: anytype, options: RenderOptions) ui.RenderError!void {
    if (stack.children.len == 0) return;
    if (stack.children.len > max_children) return error.CommandBudgetExceeded;

    const constraints = constraintsFromBounds(bounds);
    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    var child_bounds: [max_children]ui.Rect = undefined;
    const measured_children = measureChildren(Component, stack.children, stackChildConstraints(stack, constraints), options, &child_measurements);
    const placed_children = layouts.Flex.place(bounds, measured_children, stackLayoutOptions(stack), &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidBounds;
        try renderComponent(Component, scene, child_rect, child, options);
    }
}

pub fn collectStackInteractions(comptime Component: type, collector: *interaction.Collector, bounds: ui.Rect, stack: anytype, options: RenderOptions) interaction.Error!void {
    if (stack.children.len == 0) return;
    if (stack.children.len > max_children) return error.InteractionBudgetExceeded;

    const constraints = constraintsFromBounds(bounds);
    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    var child_bounds: [max_children]ui.Rect = undefined;
    const measured_children = measureChildren(Component, stack.children, stackChildConstraints(stack, constraints), options, &child_measurements);
    const placed_children = layouts.Flex.place(bounds, measured_children, stackLayoutOptions(stack), &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidInteractionBounds;
        try collectComponentInteractions(Component, collector, child_rect, child);
    }
}

fn measureChildren(comptime Component: type, children: []const Component, constraints: layouts.types.Constraints, options: RenderOptions, out: []layouts.types.Measurement) []layouts.types.Measurement {
    const count = @min(children.len, @min(out.len, max_children));
    for (children[0..count], 0..) |child, index| {
        out[index] = measureComponent(Component, child, constraints, options);
    }
    return out[0..count];
}

fn stackChildConstraints(stack: anytype, constraints: layouts.types.Constraints) layouts.types.Constraints {
    const inner = constraints.inner(layouts.types.Insets.uniform(@floatFromInt(stack.padding)));
    return switch (stack.axis) {
        .column => .{ .width = inner.width, .height = .unconstrained, .text_wrap = constraints.text_wrap },
        .row => .{ .width = .unconstrained, .height = inner.height, .text_wrap = constraints.text_wrap },
    };
}

fn stackLayoutOptions(stack: anytype) layouts.Flex.Options {
    return .{
        .axis = layoutAxis(stack.axis),
        .gap = @floatFromInt(stack.gap),
        .padding = layouts.types.Insets.uniform(@floatFromInt(stack.padding)),
        .cross_align = .stretch,
    };
}

fn layoutAxis(axis: ui.Axis) layouts.types.Axis {
    return switch (axis) {
        .row => .horizontal,
        .column => .vertical,
    };
}

fn constraintsFromBounds(bounds: ui.Rect) layouts.types.Constraints {
    return .{
        .width = .{ .exact = bounds.w },
        .height = .{ .exact = bounds.h },
        .text_wrap = .wrap,
    };
}

pub fn renderText(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.push(.{ .text = .{ .origin = bounds, .value = value, .color = options.style.text } });
}

pub fn renderBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    const paint = badgePaint(options);
    const resolved_height = @min(badge_height, bounds.h);
    const badge_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - resolved_height) * 0.5, bounds.w, resolved_height);
    if (paint.fill.a != 0) try scene.pushRect(badge_bounds, paint.fill, .fill, resolved_height * 0.5, 0.0);
    if (paint.border) |border| try scene.pushRect(badge_bounds, border, .border, resolved_height * 0.5, 0.0);
    try scene.pushAlignedText(badgeLabelBounds(badge_bounds), label, paint.text, .center);
}

pub fn renderSurface(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderSurfaceFrame(scene, bounds, options);
    if (title.len == 0 and detail.len == 0) return;

    const title_bounds = ui.Rect.init(bounds.x + surface_padding, bounds.y + surface_padding, @max(min_extent, bounds.w - surface_padding * 2.0), surface_title_height);
    if (title.len != 0) {
        try scene.pushAlignedText(title_bounds, title, options.style.text, .start);
    }
    if (detail.len != 0) {
        const detail_y = title_bounds.y + title_bounds.h + surface_detail_gap;
        const detail_bounds = ui.Rect.init(title_bounds.x, detail_y, title_bounds.w, @max(min_extent, bounds.y + bounds.h - detail_y - surface_padding));
        try scene.pushWrappedText(detail_bounds, detail, options.style.muted, .{
            .line_height = surface_detail_height,
            .average_char_width = surface_detail_average_w,
            .max_lines = surface_detail_max_lines,
        });
    }
}

pub fn renderSurfaceFrame(scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const frame_radius = surfaceRadiusFor(options);
    if (options.surface_variant == .elevated) {
        try scene.pushRect(bounds.insetUniform(-surface_shadow_inset), surface_shadow, .shadow, frame_radius, surface_shadow_size);
    }
    try scene.pushRect(bounds, surfaceFillColor(options), .fill, frame_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, frame_radius, 0.0);
}

pub fn renderInput(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    if (contentInset(bounds, input_text_padding)) |placeholder_bounds| {
        try scene.push(.{ .text = .{ .origin = placeholder_bounds, .value = placeholder, .color = options.style.muted } });
    }
}

pub fn renderTextarea(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    const text_bounds = bounds.insetUniform(textarea_padding);
    if (text_bounds.valid()) {
        try scene.pushWrappedText(text_bounds, placeholder, options.style.muted, .{
            .line_height = control_label_height,
            .average_char_width = control_average_char_width,
            .max_lines = textarea_max_lines,
        });
    }
}

pub fn renderSelect(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    if (contentInset(bounds, input_text_padding)) |label_bounds| {
        const text_bounds = ui.Rect.init(label_bounds.x, label_bounds.y, @max(min_extent, label_bounds.w - select_arrow_w), label_bounds.h);
        try scene.push(.{ .text = .{ .origin = text_bounds, .value = label, .color = options.style.text } });
        const arrow_bounds = ui.Rect.init(label_bounds.x + label_bounds.w - select_arrow_w, label_bounds.y, select_arrow_w, label_bounds.h);
        try scene.push(.{ .text = .{ .origin = arrow_bounds, .value = "v", .color = options.style.muted, .alignment = .center } });
    }
}

pub fn renderCheckbox(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, checked: bool, options: RenderOptions) ui.RenderError!void {
    const box = ui.Rect.init(bounds.x, bounds.y + (bounds.h - checkbox_box_size) * 0.5, checkbox_box_size, checkbox_box_size);
    try scene.pushRect(box, if (checked) options.style.accent else options.style.panel, .fill, control_radius, 0.0);
    try scene.pushRect(box, if (checked) options.style.accent else options.style.border, .border, control_radius, 0.0);
    if (checked) {
        try scene.pushRect(box.insetUniform(checkbox_mark_inset), options.style.bg, .fill, checkbox_mark_radius, 0.0);
    }
    const label_x = box.x + box.w + checkbox_text_gap;
    const label_bounds = ui.Rect.init(label_x, bounds.y + (bounds.h - control_label_height) * 0.5, @max(min_extent, bounds.x + bounds.w - label_x), control_label_height);
    try scene.push(.{ .text = .{ .origin = label_bounds, .value = label, .color = options.style.text } });
}

pub fn renderSwitch(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, checked: bool, options: RenderOptions) ui.RenderError!void {
    const pill = ui.Rect.init(bounds.x + bounds.w - switch_width, bounds.y + (bounds.h - switch_height) * 0.5, switch_width, switch_height);
    try scene.pushRect(pill, if (checked) options.style.accent else options.style.row, .fill, switch_height * 0.5, 0.0);
    try scene.pushRect(pill, options.style.border, .border, switch_height * 0.5, 0.0);
    const knob_x = if (checked) pill.x + pill.w - switch_knob_size - switch_knob_inset else pill.x + switch_knob_inset;
    const knob = ui.Rect.init(knob_x, pill.y + switch_knob_inset, switch_knob_size, switch_knob_size);
    try scene.pushRect(knob, options.style.text, .fill, switch_knob_size * 0.5, 0.0);
    const label_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - control_label_height) * 0.5, @max(min_extent, pill.x - bounds.x - checkbox_text_gap), control_label_height);
    try scene.push(.{ .text = .{ .origin = label_bounds, .value = label, .color = options.style.text } });
}

pub fn renderProgress(scene: *ui.Scene, bounds: ui.Rect, value: f32, options: RenderOptions) ui.RenderError!void {
    const track = ui.Rect.init(bounds.x, bounds.y + (bounds.h - progress_height) * 0.5, bounds.w, progress_height);
    try renderProgressTrack(scene, track, value, options, progress_height * 0.5, 0.0, false);
}

pub fn renderSlider(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, value: f32, options: RenderOptions) ui.RenderError!void {
    const clamped = ui.clampUnit(value);
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(bounds.x, bounds.y, bounds.w, slider_label_height), .value = label, .color = options.style.text } });
    const track_y = bounds.y + @min(slider_track_top, @max(0.0, bounds.h - slider_track_height));
    const track = ui.Rect.init(bounds.x, track_y, bounds.w, slider_track_height);
    try scene.pushRect(track, options.style.row, .fill, slider_track_height * 0.5, 0.0);
    try scene.pushRect(ui.Rect.init(track.x, track.y, track.w * clamped, track.h), options.style.accent, .fill, slider_track_height * 0.5, 0.0);
    const thumb_center = track.x + track.w * clamped;
    const thumb = ui.Rect.init(thumb_center - slider_thumb_size * 0.5, track.y + (track.h - slider_thumb_size) * 0.5, slider_thumb_size, slider_thumb_size);
    try scene.pushRect(thumb, options.style.text, .fill, slider_thumb_size * 0.5, 0.0);
}

pub fn renderAvatar(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    const size = @min(avatar_size, @max(min_extent, @min(bounds.w, bounds.h)));
    const avatar_bounds = ui.Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
    try scene.pushRect(avatar_bounds, options.style.row, .fill, size * 0.5, 0.0);
    try scene.pushRect(avatar_bounds, options.style.border, .border, size * 0.5, 0.0);
    const label_bounds = avatar_bounds.insetUniform(avatar_label_inset).withHeightCentered(avatar_text_height);
    try scene.push(.{ .text = .{ .origin = label_bounds, .value = label, .color = options.style.text, .alignment = .center } });
}

pub fn renderKbd(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    const height = @min(kbd_height, @max(min_extent, bounds.h));
    const kbd_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - height) * 0.5, bounds.w, height);
    try renderControlFrame(scene, kbd_bounds, options.style.row, options.style.border, control_radius);
    if (contentInset(kbd_bounds, kbd_label_padding)) |label_bounds| {
        try scene.push(.{ .text = .{ .origin = label_bounds.withHeightCentered(kbd_text_height), .value = label, .color = options.style.text, .alignment = .center } });
    }
}

pub fn renderSeparator(scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const line = ui.Rect.init(bounds.x, bounds.y + (bounds.h - separator_height) * 0.5, bounds.w, separator_height);
    try scene.pushRect(line, options.style.border, .fill, 0.0, 0.0);
}

pub fn renderRowItem(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, row_radius, 0.0);
    if (rowTitleBounds(bounds, detail.len == 0)) |title_bounds| {
        try scene.push(.{ .text = .{ .origin = title_bounds, .value = title, .color = options.style.text } });
    }
    if (detail.len != 0) {
        if (rowDetailBounds(bounds)) |detail_bounds| {
            try scene.push(.{ .text = .{ .origin = detail_bounds, .value = detail, .color = options.style.muted } });
        }
    }
}

pub fn measureText(value: []const u8, constraints: layout.Constraints) layout.Measurement {
    const measured = layout.measureText(value, constraints, .{
        .line_height = text_line_height,
        .average_char_width = text_average_w,
        .max_lines = text_max_lines,
    });
    return layout.Measurement.flexible(
        .{ .w = @min(text_min_width, measured.preferred.w), .h = @min(text_line_height, measured.preferred.h) },
        measured.preferred,
        measured.max,
    ).applyExact(constraints);
}

pub fn measureBadge(label: []const u8, constraints: layout.Constraints) layout.Measurement {
    const preferred_width = @max(badge_min_width, @as(f32, @floatFromInt(label.len)) * badge_label_average_w + badge_padding_x * 2.0);
    return layout.Measurement.flexible(
        .{ .w = badge_min_width, .h = badge_height },
        .{ .w = preferred_width, .h = badge_height },
        .{ .w = measure_max_width, .h = badge_height },
    ).applyExact(constraints);
}

pub fn measureSurface(title: []const u8, detail: []const u8, constraints: layout.Constraints) layout.Measurement {
    const inner = constraints.inner(layout.Insets.uniform(surface_padding));
    const title_measure = layout.measureText(title, inner, .{
        .line_height = surface_title_height,
        .average_char_width = surface_title_average_w,
        .max_lines = surface_title_max_lines,
    });
    const detail_measure = layout.measureText(detail, inner, .{
        .line_height = surface_detail_height,
        .average_char_width = surface_detail_average_w,
        .max_lines = surface_detail_max_lines,
    });
    const content_width = @max(title_measure.preferred.w, detail_measure.preferred.w);
    const content_height = title_measure.preferred.h + surface_detail_gap + detail_measure.preferred.h;
    return layout.Measurement.flexible(
        .{ .w = surface_min_width, .h = surface_padding * 2.0 + surface_title_height },
        .{ .w = content_width + surface_padding * 2.0, .h = content_height + surface_padding * 2.0 },
        .{ .w = measure_max_width, .h = content_height + surface_padding * 2.0 },
    ).applyExact(constraints);
}

pub fn measureFixed(preferred: ui.Size, constraints: layout.Constraints) layout.Measurement {
    return layout.Measurement.flexible(
        .{ .w = @min(preferred.w, constraints.width.limit(preferred.w)), .h = @min(preferred.h, constraints.height.limit(preferred.h)) },
        preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

fn renderControlFrame(scene: *ui.Scene, bounds: ui.Rect, fill: ui.Color, border: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, fill, .fill, radius, 0.0);
    try scene.pushRect(bounds, border, .border, radius, 0.0);
}

fn rowTitleBounds(bounds: ui.Rect, centered: bool) ?ui.Rect {
    const row_bounds = if (centered) bounds.withHeightCentered(row_title_height) else ui.Rect.init(bounds.x, bounds.y + row_title_offset_y, bounds.w, row_title_height);
    return rowTextBounds(row_bounds);
}

fn rowDetailBounds(bounds: ui.Rect) ?ui.Rect {
    return rowTextBounds(ui.Rect.init(bounds.x, bounds.y + row_detail_offset_y, bounds.w, row_detail_height));
}

fn rowTextBounds(bounds: ui.Rect) ?ui.Rect {
    const out = bounds.insetLtrb(row_text_padding_x, 0.0, row_text_padding_x, 0.0);
    return if (out.valid()) out else null;
}

fn renderProgressTrack(scene: *ui.Scene, track: ui.Rect, value: f32, options: RenderOptions, radius: f32, min_fill_width: f32, omit_empty_fill: bool) ui.RenderError!void {
    if (track.w <= 0.0 or track.h <= 0.0) return;
    try scene.pushRect(track, options.style.row, .fill, radius, 0.0);
    const clamped = ui.clampUnit(value);
    if (omit_empty_fill and clamped <= 0.0) return;
    const fill_width = @min(track.w, @max(min_fill_width, track.w * clamped));
    try scene.pushRect(ui.Rect.init(track.x, track.y, fill_width, track.h), options.style.accent, .fill, radius, 0.0);
}

const BadgePaint = struct {
    fill: ui.Color,
    text: ui.Color,
    border: ?ui.Color = null,
};

fn badgePaint(options: RenderOptions) BadgePaint {
    return switch (options.badge_variant) {
        .default => alphaPaint(options.style.accent, options.style.accent),
        .secondary => .{ .fill = options.style.row, .text = options.style.text },
        .destructive => alphaPaint(badge_danger, badge_danger),
        .outline => .{ .fill = ui.Color.clear, .text = options.style.text, .border = options.style.border },
        .ghost => .{ .fill = ui.Color.clear, .text = options.style.muted },
        .link => .{ .fill = ui.Color.clear, .text = options.style.accent },
    };
}

fn alphaPaint(color: ui.Color, text_color: ui.Color) BadgePaint {
    var fill = color;
    fill.a = badge_fill_alpha;
    return .{ .fill = fill, .text = text_color };
}

fn badgeLabelBounds(bounds: ui.Rect) ui.Rect {
    const resolved_padding = @min(badge_padding_x, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + resolved_padding, bounds.y + (bounds.h - badge_text_height) * 0.5, @max(min_extent, bounds.w - resolved_padding * 2.0), badge_text_height);
}

pub fn surfaceRadiusFor(options: RenderOptions) f32 {
    return switch (options.surface_variant) {
        .panel => surface_radius,
        .elevated => surface_radius + surface_elevated_radius_extra,
        .subtle => surface_radius,
    };
}

fn surfaceFillColor(options: RenderOptions) ui.Color {
    return switch (options.surface_variant) {
        .panel, .elevated => options.style.panel,
        .subtle => options.style.row,
    };
}

pub const preferred_badge = ui.Size{ .w = 96.0, .h = 24.0 };
pub const preferred_avatar = ui.Size{ .w = 40.0, .h = 40.0 };
pub const preferred_kbd = ui.Size{ .w = 48.0, .h = 24.0 };
pub const preferred_separator = ui.Size{ .w = 220.0, .h = 1.0 };
pub const preferred_input = ui.Size{ .w = 220.0, .h = 40.0 };
pub const preferred_textarea = ui.Size{ .w = 220.0, .h = 88.0 };
pub const preferred_select = ui.Size{ .w = 220.0, .h = 40.0 };
pub const preferred_checkbox = ui.Size{ .w = 220.0, .h = 28.0 };
pub const preferred_switch = ui.Size{ .w = 220.0, .h = 32.0 };
pub const preferred_progress = ui.Size{ .w = 220.0, .h = 10.0 };
pub const preferred_slider = ui.Size{ .w = 220.0, .h = 42.0 };
pub const preferred_row_item = ui.Size{ .w = 260.0, .h = 48.0 };

const min_extent: f32 = 1.0;
const measure_max_width: f32 = 4096.0;
const control_radius: f32 = 6.0;
const row_radius: f32 = 4.0;
const input_text_padding: f32 = 12.0;
const control_label_height: f32 = 16.0;
const control_average_char_width: f32 = 8.5;
const textarea_padding: f32 = 12.0;
const textarea_max_lines: usize = 4;
const select_arrow_w: f32 = 18.0;
const checkbox_box_size: f32 = 18.0;
const checkbox_mark_inset: f32 = 5.0;
const checkbox_mark_radius: f32 = 2.0;
const checkbox_text_gap: f32 = 10.0;
const switch_width: f32 = 42.0;
const switch_height: f32 = 24.0;
const switch_knob_size: f32 = 18.0;
const switch_knob_inset: f32 = 3.0;
const progress_height: f32 = 8.0;
const slider_label_height: f32 = 14.0;
const slider_track_height: f32 = 6.0;
const slider_thumb_size: f32 = 16.0;
const slider_track_top: f32 = 26.0;
const avatar_size: f32 = 40.0;
const avatar_text_height: f32 = 14.0;
const avatar_label_inset: f32 = 6.0;
const kbd_height: f32 = 24.0;
const kbd_text_height: f32 = 12.0;
const kbd_label_padding: f32 = 8.0;
const separator_height: f32 = 1.0;
const row_text_padding_x: f32 = 12.0;
const row_title_offset_y: f32 = 8.0;
const row_detail_offset_y: f32 = 26.0;
const row_title_height: f32 = 18.0;
const row_detail_height: f32 = 16.0;
const text_line_height: f32 = 18.0;
const text_average_w: f32 = 8.0;
const text_max_lines: usize = 8;
const text_min_width: f32 = 24.0;
pub const surface_radius: f32 = 10.0;
pub const surface_padding: f32 = 16.0;
pub const surface_title_height: f32 = 18.0;
pub const surface_detail_height: f32 = 16.0;
pub const surface_detail_gap: f32 = 8.0;
const surface_elevated_radius_extra: f32 = 2.0;
const surface_shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
const surface_shadow_size: f32 = 8.0;
const surface_shadow_inset: f32 = 1.0;
const surface_title_average_w: f32 = 8.5;
const surface_title_max_lines: usize = 1;
const surface_detail_average_w: f32 = 8.0;
const surface_detail_max_lines: usize = 3;
const surface_min_width: f32 = 160.0;
pub const badge_height: f32 = 24.0;
pub const badge_text_height: f32 = 13.0;
pub const badge_padding_x: f32 = 12.0;
const badge_fill_alpha: u8 = 48;
const badge_label_average_w: f32 = 8.0;
const badge_min_width: f32 = 28.0;
const badge_danger = ui.Color{ .r = 239, .g = 68, .b = 68 };
