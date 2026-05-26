const std = @import("std");
const common = @import("../../ui_component_common.zig");
const icon = @import("../../icon.zig");
const layout = @import("../../layouts/Types.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const ui = @import("../../ui.zig");
const text_metrics = @import("../../ui_text_metrics.zig");
const tokens = @import("../../ui_tokens.zig");

const RenderOptions = common.RenderOptions;

const max_children: usize = 64;

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

pub fn renderComponent(comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, component: Component, options: RenderOptions) ui.RenderError!void {
    const resolved_options = options.withControlId(componentControlId(component));
    switch (component) {
        .text => |text| try text.render(scene, bounds, resolved_options),
        .accordion => |accordion| try accordion.render(scene, bounds, resolved_options),
        .alert => |alert| try alert.render(scene, bounds, resolved_options),
        .alert_dialog => |dialog| try dialog.render(scene, bounds, resolved_options),
        .aspect_ratio => |aspect_ratio| try aspect_ratio.render(scene, bounds, resolved_options),
        .calendar => |calendar| try calendar.render(scene, bounds, resolved_options),
        .carousel => |carousel| try carousel.render(scene, bounds, resolved_options),
        .chart => |chart| try chart.render(scene, bounds, resolved_options),
        .combobox => |combobox| try combobox.render(scene, bounds, resolved_options),
        .card => |card| try card.render(scene, bounds, resolved_options),
        .empty => |empty| try empty.render(scene, bounds, resolved_options),
        .badge => |badge| try badge.render(scene, bounds, resolved_options),
        .avatar => |avatar| try avatar.render(scene, bounds, resolved_options),
        .kbd => |kbd| try kbd.render(scene, bounds, resolved_options),
        .label => |label| try label.render(scene, bounds, resolved_options),
        .separator => |separator| try separator.render(scene, bounds, resolved_options),
        .scroll_area => |scroll_area| try scroll_area.render(scene, bounds, resolved_options),
        .skeleton => |skeleton| try skeleton.render(scene, bounds, resolved_options),
        .spinner => |spinner| try spinner.render(scene, bounds, resolved_options),
        .breadcrumb => |breadcrumb| try breadcrumb.render(scene, bounds, resolved_options),
        .menubar => |menubar| try menubar.render(scene, bounds, resolved_options),
        .navigation_menu => |menu| try menu.render(scene, bounds, resolved_options),
        .command => |command| try command.render(scene, bounds, resolved_options),
        .context_menu => |menu| try menu.render(scene, bounds, resolved_options),
        .dialog => |dialog| try dialog.render(scene, bounds, resolved_options),
        .direction => |direction| try direction.render(scene, bounds, resolved_options),
        .drawer => |drawer| try drawer.render(scene, bounds, resolved_options),
        .dropdown_menu => |menu| try menu.render(scene, bounds, resolved_options),
        .field => |field| try field.render(scene, bounds, resolved_options),
        .hover_card => |hover_card| try hover_card.render(scene, bounds, resolved_options),
        .input_otp => |otp| try otp.render(scene, bounds, resolved_options),
        .button => |button| try button.render(scene, bounds, resolved_options),
        .icon_button => |button| try button.render(scene, bounds, resolved_options),
        .button_group => |group| try group.render(scene, bounds, resolved_options),
        .toggle_group => |group| try group.render(scene, bounds, resolved_options),
        .toggle => |toggle| try toggle.render(scene, bounds, resolved_options),
        .input => |input| try input.render(scene, bounds, resolved_options),
        .input_group => |input_group| try input_group.render(scene, bounds, resolved_options),
        .textarea => |textarea| try textarea.render(scene, bounds, resolved_options),
        .select => |select| try select.render(scene, bounds, resolved_options),
        .checkbox => |checkbox| try checkbox.render(scene, bounds, resolved_options),
        .radio_group => |radio| try radio.render(scene, bounds, resolved_options),
        .switch_control => |switch_control| try switch_control.render(scene, bounds, resolved_options),
        .pagination => |pagination| try pagination.render(scene, bounds, resolved_options),
        .popover => |popover| try popover.render(scene, bounds, resolved_options),
        .resizable => |resizable| try resizable.render(scene, bounds, resolved_options),
        .sheet => |sheet| try sheet.render(scene, bounds, resolved_options),
        .sidebar => |sidebar| try sidebar.render(scene, bounds, resolved_options),
        .progress => |progress| try progress.render(scene, bounds, resolved_options),
        .slider => |slider| try slider.render(scene, bounds, resolved_options),
        .tabs => |tabs| try tabs.render(scene, bounds, resolved_options),
        .table => |table| try table.render(scene, bounds, resolved_options),
        .tooltip => |tooltip| try tooltip.render(scene, bounds, resolved_options),
        .toast => |toast| try toast.render(scene, bounds, resolved_options),
        .row_item => |row| try row.render(scene, bounds, resolved_options),
    }
    try renderControlStateOverlay(scene, bounds, resolved_options, control_radius);
}

fn componentControlId(component: anytype) ?u32 {
    return switch (component) {
        .text, .alert, .aspect_ratio, .card, .empty, .badge, .avatar, .kbd, .label, .separator, .scroll_area, .skeleton, .spinner, .progress => null,
        .accordion => |value| value.id,
        .alert_dialog => |value| value.id,
        .calendar => |value| value.id,
        .carousel => |value| value.id,
        .chart => |value| value.id,
        .combobox => |value| value.id,
        .breadcrumb => |value| value.id,
        .menubar => |value| value.id,
        .navigation_menu => |value| value.id,
        .command => |value| value.id,
        .context_menu => |value| value.id,
        .dialog => |value| value.id,
        .direction => |value| value.id,
        .drawer => |value| value.id,
        .dropdown_menu => |value| value.id,
        .field => |value| value.id,
        .hover_card => |value| value.id,
        .input_otp => |value| value.id,
        .button => |value| value.id,
        .icon_button => |value| value.id,
        .button_group => |value| value.id,
        .toggle_group => |value| value.id,
        .toggle => |value| value.id,
        .input => |value| value.id,
        .input_group => |value| value.id,
        .textarea => |value| value.id,
        .select => |value| value.id,
        .checkbox => |value| value.id,
        .radio_group => |value| value.id,
        .switch_control => |value| value.id,
        .pagination => |value| value.id,
        .popover => |value| value.id,
        .resizable => |value| value.id,
        .sheet => |value| value.id,
        .sidebar => |value| value.id,
        .slider => |value| value.id,
        .tabs => |value| value.id,
        .table => |value| value.id,
        .tooltip => |value| value.id,
        .toast => |value| value.id,
        .row_item => |value| value.id,
    };
}

pub fn collectComponentInteractions(comptime Component: type, collector: *interaction.Collector, bounds: ui.Rect, component: Component) interaction.Error!void {
    switch (component) {
        .accordion => |accordion| try accordion.collectInteractions(collector, bounds),
        .alert_dialog => |dialog| try dialog.collectInteractions(collector, bounds),
        .calendar => |calendar| try calendar.collectInteractions(collector, bounds),
        .carousel => |carousel| try carousel.collectInteractions(collector, bounds),
        .chart => |chart| try chart.collectInteractions(collector, bounds),
        .combobox => |combobox| try combobox.collectInteractions(collector, bounds),
        .breadcrumb => |breadcrumb| try breadcrumb.collectInteractions(collector, bounds),
        .menubar => |menubar| try menubar.collectInteractions(collector, bounds),
        .navigation_menu => |menu| try menu.collectInteractions(collector, bounds),
        .command => |command| try command.collectInteractions(collector, bounds),
        .context_menu => |menu| try menu.collectInteractions(collector, bounds),
        .dialog => |dialog| try dialog.collectInteractions(collector, bounds),
        .direction => |direction| try direction.collectInteractions(collector, bounds),
        .drawer => |drawer| try drawer.collectInteractions(collector, bounds),
        .dropdown_menu => |menu| try menu.collectInteractions(collector, bounds),
        .field => |field| try field.collectInteractions(collector, bounds),
        .hover_card => |hover_card| try hover_card.collectInteractions(collector, bounds),
        .input_otp => |otp| try otp.collectInteractions(collector, bounds),
        .button => |button| try button.collectInteractions(collector, bounds),
        .icon_button => |button| try button.collectInteractions(collector, bounds),
        .button_group => |group| try group.collectInteractions(collector, bounds),
        .toggle_group => |group| try group.collectInteractions(collector, bounds),
        .input => |input| try input.collectInteractions(collector, bounds),
        .input_group => |input_group| try input_group.collectInteractions(collector, bounds),
        .textarea => |textarea| try textarea.collectInteractions(collector, bounds),
        .select => |select| try select.collectInteractions(collector, bounds),
        .checkbox => |checkbox| try checkbox.collectInteractions(collector, bounds),
        .radio_group => |radio| try radio.collectInteractions(collector, bounds),
        .switch_control => |switch_control| try switch_control.collectInteractions(collector, bounds),
        .pagination => |pagination| try pagination.collectInteractions(collector, bounds),
        .popover => |popover| try popover.collectInteractions(collector, bounds),
        .resizable => |resizable| try resizable.collectInteractions(collector, bounds),
        .sheet => |sheet| try sheet.collectInteractions(collector, bounds),
        .sidebar => |sidebar| try sidebar.collectInteractions(collector, bounds),
        .toggle => |toggle| try toggle.collectInteractions(collector, bounds),
        .slider => |slider| try slider.collectInteractions(collector, bounds),
        .tabs => |tabs| try tabs.collectInteractions(collector, bounds),
        .table => |table| try table.collectInteractions(collector, bounds),
        .tooltip => |tooltip| try tooltip.collectInteractions(collector, bounds),
        .toast => |toast| try toast.collectInteractions(collector, bounds),
        .row_item => |row| try row.collectInteractions(collector, bounds),
        else => {},
    }
}

pub fn accessibility(comptime Component: type, component: Component) common.Accessibility {
    return switch (component) {
        .text => |text| .{ .role = .text, .label = text.value },
        .button => |button| .{ .role = .button, .label = button.label, .control_id = button.id },
        .icon_button => |button| .{ .role = .button, .label = button.label, .control_id = button.id },
        .input => |input| .{ .role = .input, .label = input.placeholder, .control_id = input.id },
        .field => |field| .{ .role = .input, .label = field.label, .control_id = field.id },
        .textarea => |textarea| .{ .role = .input, .label = textarea.placeholder, .control_id = textarea.id },
        .select => |select| .{ .role = .input, .label = select.label, .control_id = select.id },
        .checkbox => |checkbox| .{ .role = .checkbox, .label = checkbox.label, .control_id = checkbox.id },
        .switch_control => |switch_control| .{ .role = .switch_control, .label = switch_control.label, .control_id = switch_control.id },
        .slider => |slider| .{ .role = .slider, .label = slider.label, .control_id = slider.id },
        .tabs => |tabs| .{ .role = .tab, .label = tabs.first, .control_id = tabs.id },
        .table => |table| .{ .role = .table, .label = table.name, .control_id = table.id },
        .dialog => |dialog| .{ .role = .dialog, .label = dialog.title, .control_id = dialog.id },
        .alert_dialog => |dialog| .{ .role = .dialog, .label = dialog.title, .control_id = dialog.id },
        .dropdown_menu => |menu| .{ .role = .menu, .label = menu.first, .control_id = menu.id },
        .context_menu => |menu| .{ .role = .menu, .label = menu.first, .control_id = menu.id },
        .menubar => |menubar| .{ .role = .menu, .label = menubar.first, .control_id = menubar.id },
        .navigation_menu => |menu| .{ .role = .menu, .label = menu.first, .control_id = menu.id },
        .avatar => |avatar| .{ .role = .image, .label = avatar.label },
        .toast => |toast| .{ .role = .status, .label = toast.title, .control_id = toast.id },
        .row_item => |row| .{ .role = .button, .label = row.title, .control_id = row.id },
        else => .{ .role = .generic },
    };
}

pub fn collectAccessibility(comptime Component: type, tree: *common.AccessibilityTree, bounds: ui.Rect, component: Component, options: RenderOptions) common.AccessibilityError!void {
    _ = options;
    const metadata = accessibility(Component, component);
    if (metadata.role == .generic and metadata.label.len == 0 and metadata.control_id == null) return;
    try tree.append(.{ .metadata = metadata, .bounds = bounds });
}

pub fn measureComponent(comptime Component: type, component: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return switch (component) {
        .text => |text| text.measure(constraints, options),
        .accordion => |accordion| accordion.measure(constraints, options),
        .alert => |alert| alert.measure(constraints, options),
        .alert_dialog => |dialog| dialog.measure(constraints, options),
        .aspect_ratio => |aspect_ratio| aspect_ratio.measure(constraints, options),
        .calendar => |calendar| calendar.measure(constraints, options),
        .carousel => |carousel| carousel.measure(constraints, options),
        .chart => |chart| chart.measure(constraints, options),
        .combobox => |combobox| combobox.measure(constraints, options),
        .card => |card| card.measure(constraints, options),
        .empty => |empty| empty.measure(constraints, options),
        .badge => |badge| badge.measure(constraints, options),
        .avatar => |avatar| avatar.measure(constraints, options),
        .kbd => |kbd| kbd.measure(constraints, options),
        .label => |label| label.measure(constraints, options),
        .separator => |separator| separator.measure(constraints, options),
        .scroll_area => |scroll_area| scroll_area.measure(constraints, options),
        .skeleton => |skeleton| skeleton.measure(constraints, options),
        .spinner => |spinner| spinner.measure(constraints, options),
        .breadcrumb => |breadcrumb| breadcrumb.measure(constraints, options),
        .menubar => |menubar| menubar.measure(constraints, options),
        .navigation_menu => |menu| menu.measure(constraints, options),
        .command => |command| command.measure(constraints, options),
        .context_menu => |menu| menu.measure(constraints, options),
        .dialog => |dialog| dialog.measure(constraints, options),
        .direction => |direction| direction.measure(constraints, options),
        .drawer => |drawer| drawer.measure(constraints, options),
        .dropdown_menu => |menu| menu.measure(constraints, options),
        .field => |field| field.measure(constraints, options),
        .hover_card => |hover_card| hover_card.measure(constraints, options),
        .input_otp => |otp| otp.measure(constraints, options),
        .button => |button| button.measure(constraints, options),
        .icon_button => |button| button.measure(constraints, options),
        .button_group => |group| group.measure(constraints, options),
        .toggle_group => |group| group.measure(constraints, options),
        .toggle => |toggle| toggle.measure(constraints, options),
        .input => |input| input.measure(constraints, options),
        .input_group => |input_group| input_group.measure(constraints, options),
        .textarea => |textarea| textarea.measure(constraints, options),
        .select => |select| select.measure(constraints, options),
        .checkbox => |checkbox| checkbox.measure(constraints, options),
        .radio_group => |radio| radio.measure(constraints, options),
        .switch_control => |switch_control| switch_control.measure(constraints, options),
        .pagination => |pagination| pagination.measure(constraints, options),
        .popover => |popover| popover.measure(constraints, options),
        .resizable => |resizable| resizable.measure(constraints, options),
        .sheet => |sheet| sheet.measure(constraints, options),
        .sidebar => |sidebar| sidebar.measure(constraints, options),
        .progress => |progress| progress.measure(constraints, options),
        .slider => |slider| slider.measure(constraints, options),
        .tabs => |tabs| tabs.measure(constraints, options),
        .table => |table| table.measure(constraints, options),
        .tooltip => |tooltip| tooltip.measure(constraints, options),
        .toast => |toast| toast.measure(constraints, options),
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

    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    var child_bounds: [max_children]ui.Rect = undefined;
    const placed_children = placeStackChildren(Component, bounds, stack, options, &child_measurements, &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidBounds;
        try renderComponent(Component, scene, child_rect, child, options);
    }
}

pub fn collectStackInteractions(comptime Component: type, collector: *interaction.Collector, bounds: ui.Rect, stack: anytype, options: RenderOptions) interaction.Error!void {
    if (stack.children.len == 0) return;
    if (stack.children.len > max_children) return error.InteractionBudgetExceeded;

    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    var child_bounds: [max_children]ui.Rect = undefined;
    const placed_children = placeStackChildren(Component, bounds, stack, options, &child_measurements, &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidInteractionBounds;
        try collectComponentInteractions(Component, collector, child_rect, child);
    }
}

pub fn collectStackAccessibility(comptime Component: type, tree: *common.AccessibilityTree, bounds: ui.Rect, stack: anytype, options: RenderOptions) common.AccessibilityError!void {
    if (stack.children.len == 0) return;
    if (stack.children.len > max_children) return error.AccessibilityBudgetExceeded;

    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    var child_bounds: [max_children]ui.Rect = undefined;
    const placed_children = placeStackChildren(Component, bounds, stack, options, &child_measurements, &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidAccessibilityBounds;
        try collectAccessibility(Component, tree, child_rect, child, options);
    }
}

fn placeStackChildren(comptime Component: type, bounds: ui.Rect, stack: anytype, options: RenderOptions, measurements: *[max_children]layouts.types.Measurement, out: *[max_children]ui.Rect) []ui.Rect {
    const constraints = constraintsFromBounds(bounds);
    const measured_children = measureChildren(Component, stack.children, stackChildConstraints(stack, constraints), options, measurements);
    return layouts.Flex.place(bounds, measured_children, stackLayoutOptions(stack), out);
}

fn measureChildren(comptime Component: type, children: []const Component, constraints: layouts.types.Constraints, options: RenderOptions, out: []layouts.types.Measurement) []layouts.types.Measurement {
    const count = @min(children.len, @min(out.len, max_children));
    for (children[0..count], 0..) |child, index| {
        out[index] = measureComponent(Component, child, constraints, options);
    }
    return out[0..count];
}

fn stackChildConstraints(stack: anytype, constraints: layouts.types.Constraints) layouts.types.Constraints {
    return stackChildConstraintsFor(stack.axis, @floatFromInt(stack.padding), constraints);
}

fn stackLayoutOptions(stack: anytype) layouts.Flex.Options {
    return stackLayoutOptionsFor(stack.axis, @floatFromInt(stack.gap), @floatFromInt(stack.padding), .stretch);
}

pub fn stackChildConstraintsFor(axis: ui.Axis, padding: f32, constraints: layouts.types.Constraints) layouts.types.Constraints {
    const inner = constraints.inner(layouts.types.Insets.uniform(padding));
    return switch (axis) {
        .column => .{ .width = inner.width, .height = .unconstrained, .text_wrap = constraints.text_wrap },
        .row => .{ .width = .unconstrained, .height = inner.height, .text_wrap = constraints.text_wrap },
    };
}

pub fn stackLayoutOptionsFor(axis: ui.Axis, gap: f32, padding: f32, cross_align: layouts.Flex.Align) layouts.Flex.Options {
    return .{
        .axis = layoutAxis(axis),
        .gap = gap,
        .padding = layouts.types.Insets.uniform(padding),
        .cross_align = cross_align,
    };
}

pub fn layoutAxis(axis: ui.Axis) layouts.types.Axis {
    return switch (axis) {
        .row => .horizontal,
        .column => .vertical,
    };
}

pub fn constraintsFromBounds(bounds: ui.Rect) layouts.types.Constraints {
    return .{
        .width = .{ .exact = bounds.w },
        .height = .{ .exact = bounds.h },
        .text_wrap = .wrap,
    };
}

pub fn renderAccordion(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, open: bool, options: RenderOptions) ui.RenderError!void {
    const trigger = accordionTriggerBounds(bounds);
    try scene.pushText(ui.Rect.init(trigger.x, trigger.y + accordion_trigger_text_y, @max(min_extent, trigger.w - accordion_icon_space), control_label_height), title, options.style.text);
    try scene.pushIconQuad(.{ .bounds = ui.Rect.init(trigger.x + trigger.w - accordion_icon_size, trigger.y + accordion_icon_y, accordion_icon_size, accordion_icon_size), .icon_id = icon.id(.chevron_right), .color = options.style.muted });
    try scene.pushRect(ui.Rect.init(bounds.x, trigger.y + trigger.h, bounds.w, separator_height), options.style.border, .fill, 0.0, 0.0);
    if (open) {
        try scene.pushWrappedText(ui.Rect.init(bounds.x, trigger.y + trigger.h + accordion_content_padding_top, bounds.w, @max(min_extent, bounds.h - trigger.h - accordion_content_padding_top)), detail, options.style.muted, .{
            .line_height = accordion_detail_height,
            .average_char_width = accordion_detail_average_w,
            .max_lines = accordion_detail_max_lines,
        });
    }
}

pub fn accordionTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, accordion_trigger_h);
}

pub fn renderAlert(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, destructive: bool, options: RenderOptions) ui.RenderError!void {
    const content_color = if (destructive) alert_danger else options.style.text;
    try scene.pushRect(bounds, options.style.panel, .fill, alert_radius, 0.0);
    try scene.pushRect(bounds, if (destructive) alert_danger else options.style.border, .border, alert_radius, 0.0);
    try scene.pushIconQuad(.{ .bounds = ui.Rect.init(bounds.x + alert_padding_x, bounds.y + alert_padding_y, alert_icon_size, alert_icon_size), .icon_id = icon.id(if (destructive) .warning else .shield), .color = content_color });
    try scene.pushText(ui.Rect.init(bounds.x + alert_text_x, bounds.y + alert_padding_y - 1.0, @max(min_extent, bounds.w - alert_text_x - alert_padding_x), alert_title_height), title, content_color);
    try scene.pushWrappedText(ui.Rect.init(bounds.x + alert_text_x, bounds.y + alert_padding_y + alert_title_height + alert_detail_gap, @max(min_extent, bounds.w - alert_text_x - alert_padding_x), @max(min_extent, bounds.h - alert_padding_y * 2.0 - alert_title_height)), detail, if (destructive) alert_danger else options.style.muted, .{
        .line_height = alert_detail_height,
        .average_char_width = alert_detail_average_w,
        .max_lines = alert_detail_max_lines,
    });
}

pub fn renderAspectRatio(scene: *ui.Scene, bounds: ui.Rect, ratio_w: u16, ratio_h: u16, options: RenderOptions) ui.RenderError!void {
    const frame = aspectRatioFrame(bounds, ratio_w, ratio_h);
    try scene.pushRect(frame, options.style.row, .fill, control_radius, 0.0);
    try scene.pushRect(frame, options.style.border, .border, control_radius, 0.0);
}

pub fn aspectRatioFrame(bounds: ui.Rect, ratio_w: u16, ratio_h: u16) ui.Rect {
    const safe_w = @max(@as(f32, @floatFromInt(ratio_w)), min_extent);
    const safe_h = @max(@as(f32, @floatFromInt(ratio_h)), min_extent);
    const frame_w = @min(bounds.w, bounds.h * safe_w / safe_h);
    const frame_h = @min(bounds.h, frame_w * safe_h / safe_w);
    return ui.Rect.init(bounds.x + (bounds.w - frame_w) * 0.5, bounds.y + (bounds.h - frame_h) * 0.5, frame_w, frame_h);
}

pub fn renderCalendar(scene: *ui.Scene, bounds: ui.Rect, month: []const u8, selected_day: u16, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.panel, .fill, calendar_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, calendar_radius, 0.0);
    try renderCalendarNav(scene, calendarNavBounds(bounds, 0), "<", options);
    try renderCalendarNav(scene, calendarNavBounds(bounds, 1), ">", options);
    try scene.pushAlignedText(calendarCaptionBounds(bounds), month, options.style.text, .center);

    for (calendar_weekday_labels, 0..) |label, index| {
        try scene.pushAlignedText(calendarWeekdayBounds(bounds, index), label, options.style.muted, .center);
    }
    for (calendar_day_labels, 0..) |label, index| {
        const day = @as(u16, @intCast(index + 1));
        try renderCalendarDay(scene, calendarDayBounds(bounds, index), label, day == selected_day, options);
    }
}

pub fn calendarNavBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const y = bounds.y + calendar_padding;
    return switch (index) {
        0 => ui.Rect.init(bounds.x + calendar_padding, y, calendar_nav_size, calendar_nav_size),
        else => ui.Rect.init(bounds.x + bounds.w - calendar_padding - calendar_nav_size, y, calendar_nav_size, calendar_nav_size),
    };
}

pub fn calendarDayBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const grid = calendarGridBounds(bounds);
    const col = index % calendar_column_count;
    const row = index / calendar_column_count;
    return ui.Rect.init(
        grid.x + @as(f32, @floatFromInt(col)) * (calendar_cell_size + calendar_cell_gap),
        grid.y + @as(f32, @floatFromInt(row)) * (calendar_cell_size + calendar_cell_gap),
        calendar_cell_size,
        calendar_cell_size,
    );
}

fn calendarCaptionBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + calendar_nav_size + calendar_padding * 2.0, bounds.y + calendar_padding, @max(min_extent, bounds.w - (calendar_nav_size + calendar_padding * 2.0) * 2.0), calendar_caption_h);
}

fn calendarWeekdayBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const grid = calendarGridBounds(bounds);
    return ui.Rect.init(grid.x + @as(f32, @floatFromInt(index)) * (calendar_cell_size + calendar_cell_gap), bounds.y + calendar_weekday_y, calendar_cell_size, calendar_weekday_h);
}

fn calendarGridBounds(bounds: ui.Rect) ui.Rect {
    const grid_w = @as(f32, @floatFromInt(calendar_column_count)) * calendar_cell_size + @as(f32, @floatFromInt(calendar_column_count - 1)) * calendar_cell_gap;
    return ui.Rect.init(bounds.x + (bounds.w - grid_w) * 0.5, bounds.y + calendar_grid_y, grid_w, @max(min_extent, bounds.h - calendar_grid_y - calendar_padding));
}

pub fn renderCarousel(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderCarouselButton(scene, carouselButtonBounds(bounds, 0), "<", options);
    const content = carouselContentBounds(bounds);
    try scene.pushRect(content, options.style.row, .fill, carousel_radius, 0.0);
    try renderControlText(scene, content, carousel_text_padding, control_label_height, label, options.style.muted, .center);
    try renderCarouselButton(scene, carouselButtonBounds(bounds, 1), ">", options);
}

pub fn carouselButtonBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const y = bounds.y + (bounds.h - carousel_button_size) * 0.5;
    return switch (index) {
        0 => ui.Rect.init(bounds.x, y, carousel_button_size, carousel_button_size),
        else => ui.Rect.init(bounds.x + bounds.w - carousel_button_size, y, carousel_button_size, carousel_button_size),
    };
}

fn carouselContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + carousel_button_size + carousel_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.w - carousel_button_size * 2.0 - carousel_gap * 2.0), bounds.h);
}

pub fn renderChart(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    const plot = chartPlotBounds(bounds);
    try scene.pushRect(bounds, options.style.panel, .fill, chart_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, chart_radius, 0.0);
    try scene.pushText(ui.Rect.init(bounds.x + chart_padding, bounds.y + chart_padding, @max(min_extent, bounds.w - chart_padding * 2.0), chart_label_h), label, options.style.text);
    try scene.pushRect(ui.Rect.init(plot.x, plot.y + plot.h - separator_height, plot.w, separator_height), options.style.border, .fill, 0.0, 0.0);
    for (0..chart_bar_count) |index| {
        const bar = chartBarBounds(bounds, index);
        try scene.pushRect(bar, if (index == chart_bar_count - 1) options.style.accent else options.style.row, .fill, chart_bar_radius, 0.0);
    }
}

pub fn chartBarBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const plot = chartPlotBounds(bounds);
    const gap_total = chart_bar_gap * @as(f32, @floatFromInt(chart_bar_count - 1));
    const bar_w = @max(min_extent, (plot.w - gap_total) / @as(f32, @floatFromInt(chart_bar_count)));
    const h = @max(min_extent, plot.h * chart_bar_values[index]);
    return ui.Rect.init(plot.x + @as(f32, @floatFromInt(index)) * (bar_w + chart_bar_gap), plot.y + plot.h - h, bar_w, h);
}

fn chartPlotBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + chart_padding, bounds.y + chart_padding + chart_label_h + chart_label_gap, @max(min_extent, bounds.w - chart_padding * 2.0), @max(min_extent, bounds.h - chart_padding * 2.0 - chart_label_h - chart_label_gap));
}

pub fn renderCombobox(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, selected: []const u8, options: RenderOptions) ui.RenderError!void {
    const input = comboboxInputBounds(bounds);
    try renderControlFrame(scene, input, options.style.panel, options.style.border, control_radius);
    if (contentInset(input, control_text_padding)) |input_content| {
        const text_bounds = ui.Rect.init(input_content.x, input_content.y, @max(min_extent, input_content.w - combobox_icon_space), input_content.h);
        try pushControlText(scene, text_bounds, control_label_height, placeholder, options.style.muted, .start);
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(input_content.x + input_content.w - combobox_icon_size, input_content.y + (input_content.h - combobox_icon_size) * 0.5, combobox_icon_size, combobox_icon_size),
            .icon_id = icon.id(.chevron_right),
            .color = options.style.muted,
        });
    }

    const popup = comboboxPopupBounds(bounds);
    try scene.pushRect(popup, options.style.panel, .fill, combobox_popup_radius, 0.0);
    try scene.pushRect(popup, options.style.border, .border, combobox_popup_radius, 0.0);
    try renderComboboxOption(scene, comboboxOptionBounds(bounds), selected, true, options);
}

pub fn comboboxInputBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(combobox_input_h, bounds.h));
}

pub fn comboboxOptionBounds(bounds: ui.Rect) ui.Rect {
    const popup = comboboxPopupBounds(bounds);
    return ui.Rect.init(popup.x + combobox_popup_padding, popup.y + combobox_popup_padding, @max(min_extent, popup.w - combobox_popup_padding * 2.0), @max(min_extent, popup.h - combobox_popup_padding * 2.0));
}

fn comboboxPopupBounds(bounds: ui.Rect) ui.Rect {
    const y = bounds.y + combobox_input_h + combobox_popup_gap;
    return ui.Rect.init(bounds.x, y, bounds.w, @max(min_extent, bounds.y + bounds.h - y));
}

pub fn renderEmpty(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, ui.Color.clear, .fill, empty_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, empty_radius, 0.0);
    const media = ui.Rect.init(bounds.x + (bounds.w - empty_media_size) * 0.5, bounds.y + empty_padding, empty_media_size, empty_media_size);
    try scene.pushRect(media, options.style.row, .fill, control_radius, 0.0);
    try scene.pushIconQuad(.{ .bounds = media.insetUniform(empty_media_icon_inset), .icon_id = icon.id(.sparkles), .color = options.style.text });
    try scene.pushAlignedText(ui.Rect.init(bounds.x + empty_padding, media.y + media.h + empty_gap, @max(min_extent, bounds.w - empty_padding * 2.0), empty_title_height), title, options.style.text, .center);
    try scene.pushWrappedText(ui.Rect.init(bounds.x + empty_padding, media.y + media.h + empty_gap + empty_title_height + empty_detail_gap, @max(min_extent, bounds.w - empty_padding * 2.0), empty_detail_height * empty_detail_max_lines), detail, options.style.muted, .{
        .line_height = empty_detail_height,
        .average_char_width = empty_detail_average_w,
        .max_lines = empty_detail_max_lines,
    });
}

pub fn renderInput(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, leading_icon: ?icon.Icon, options: RenderOptions) ui.RenderError!void {
    const padding = inputPadding(options.control_size);
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    try renderControlStateOverlay(scene, bounds, options, control_radius);
    const text_bounds = if (leading_icon) |value| with_icon: {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(bounds.x + padding, bounds.y + (bounds.h - input_icon_size) * 0.5, input_icon_size, input_icon_size),
            .icon_id = icon.id(value),
            .color = options.style.muted,
        });
        break :with_icon ui.Rect.init(bounds.x + padding + input_icon_size + input_icon_gap, bounds.y, @max(min_extent, bounds.w - padding * 2.0 - input_icon_size - input_icon_gap), bounds.h);
    } else bounds;
    try renderControlText(scene, text_bounds, padding, control_label_height, placeholder, options.style.muted, .start);
}

pub fn renderInputGroup(scene: *ui.Scene, bounds: ui.Rect, addon: []const u8, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    const addon_w = @min(input_group_addon_max_w, @max(input_group_addon_min_w, text_metrics.width(addon, control_label_height) + input_group_addon_padding * 2.0));
    const addon_bounds = ui.Rect.init(bounds.x, bounds.y, addon_w, bounds.h);
    try renderControlText(scene, addon_bounds, input_group_addon_padding, control_label_height, addon, options.style.muted, .center);
    try scene.pushRect(ui.Rect.init(addon_bounds.x + addon_bounds.w, bounds.y + input_group_separator_inset, separator_height, @max(min_extent, bounds.h - input_group_separator_inset * 2.0)), options.style.border, .fill, 0.0, 0.0);
    try renderControlText(scene, ui.Rect.init(addon_bounds.x + addon_bounds.w + input_group_control_gap, bounds.y, @max(min_extent, bounds.w - addon_w - input_group_control_gap), bounds.h), control_text_padding, control_label_height, placeholder, options.style.muted, .start);
}

pub fn renderTextarea(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    if (contentInset(bounds, textarea_padding)) |text_bounds| {
        try scene.pushWrappedText(text_bounds, placeholder, options.style.muted, .{
            .line_height = control_label_height,
            .average_char_width = control_average_char_width,
            .max_lines = textarea_max_lines,
        });
    }
}

pub fn renderSelect(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    if (contentInset(bounds, control_text_padding)) |label_bounds| {
        const text_bounds = ui.Rect.init(label_bounds.x, label_bounds.y, @max(min_extent, label_bounds.w - select_arrow_w), label_bounds.h);
        try pushControlText(scene, text_bounds, control_label_height, label, options.style.text, .start);
        const arrow_bounds = ui.Rect.init(label_bounds.x + label_bounds.w - select_icon_size, label_bounds.y + (label_bounds.h - select_icon_size) * 0.5, select_icon_size, select_icon_size);
        try scene.pushIconQuad(.{ .bounds = arrow_bounds, .icon_id = icon.id(.chevron_right), .color = options.style.muted });
    }
}

pub fn renderCheckbox(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, checked: bool, options: RenderOptions) ui.RenderError!void {
    const box = ui.Rect.init(bounds.x, bounds.y + (bounds.h - checkbox_box_size) * 0.5, checkbox_box_size, checkbox_box_size);
    try scene.pushRect(box, if (checked) options.style.accent else options.style.panel, .fill, control_radius, 0.0);
    try scene.pushRect(box, if (checked) options.style.accent else options.style.border, .border, control_radius, 0.0);
    if (checked) {
        try scene.pushIconQuad(.{ .bounds = box.insetUniform(checkbox_icon_inset), .icon_id = icon.id(.check), .color = options.style.bg });
    }
    const label_x = box.x + box.w + checkbox_text_gap;
    try renderInlineLabel(scene, ui.Rect.init(label_x, bounds.y, @max(min_extent, bounds.x + bounds.w - label_x), bounds.h), label, options.style.text);
}

pub fn renderRadioGroup(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8, selected: u16, options: RenderOptions) ui.RenderError!void {
    try renderRadioOption(scene, radioOptionBounds(bounds, 0), first, selected == 0, options);
    try renderRadioOption(scene, radioOptionBounds(bounds, 1), second, selected == 1, options);
}

pub fn radioOptionBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const y = bounds.y + @as(f32, @floatFromInt(index)) * radio_option_pitch;
    return ui.Rect.init(bounds.x, y, bounds.w, radio_option_h);
}

pub fn renderSwitch(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, checked: bool, options: RenderOptions) ui.RenderError!void {
    const pill = ui.Rect.init(bounds.x + bounds.w - switch_width, bounds.y + (bounds.h - switch_height) * 0.5, switch_width, switch_height);
    try scene.pushRect(pill, if (checked) options.style.accent else options.style.row, .fill, switch_height * 0.5, 0.0);
    try scene.pushRect(pill, options.style.border, .border, switch_height * 0.5, 0.0);
    const knob_x = if (checked) pill.x + pill.w - switch_knob_size - switch_knob_inset else pill.x + switch_knob_inset;
    const knob = ui.Rect.init(knob_x, pill.y + switch_knob_inset, switch_knob_size, switch_knob_size);
    try scene.pushRect(knob, options.style.panel, .fill, switch_knob_size * 0.5, 0.0);
    try renderInlineLabel(scene, ui.Rect.init(bounds.x, bounds.y, @max(min_extent, pill.x - bounds.x - checkbox_text_gap), bounds.h), label, options.style.text);
}

pub fn renderPagination(scene: *ui.Scene, bounds: ui.Rect, page: u16, options: RenderOptions) ui.RenderError!void {
    for (0..pagination_item_count) |index| {
        const item = paginationItemBounds(bounds, index);
        const active = index == page + 1;
        const label = paginationLabel(index);
        try scene.pushRect(item, if (active) options.style.panel else ui.Color.clear, .fill, control_radius, 0.0);
        try scene.pushRect(item, if (active) options.style.border else ui.Color.clear, .border, control_radius, 0.0);
        try renderControlText(scene, item, pagination_text_padding, control_label_height, label, if (active) options.style.text else options.style.muted, .center);
    }
}

pub fn paginationItemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * (pagination_item_w + pagination_gap), bounds.y, pagination_item_w, @min(bounds.h, pagination_item_h));
}

fn paginationLabel(index: usize) []const u8 {
    return switch (index) {
        0 => "<",
        1 => "1",
        2 => "2",
        3 => "3",
        4 => ">",
        else => "",
    };
}

pub fn renderPopover(scene: *ui.Scene, bounds: ui.Rect, trigger: []const u8, content: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, popoverTriggerBounds(bounds), options.style.accent, options.style.border, control_radius);
    try renderControlText(scene, popoverTriggerBounds(bounds), control_text_padding, control_label_height, trigger, options.style.bg, .center);
    const content_bounds = popoverContentBounds(bounds);
    try scene.pushRect(content_bounds, options.style.panel, .fill, popover_radius, 0.0);
    try scene.pushRect(content_bounds, options.style.border, .border, popover_radius, 0.0);
    try renderControlText(scene, content_bounds, popover_padding, control_label_height, content, options.style.text, .start);
}

pub fn renderHoverCard(scene: *ui.Scene, bounds: ui.Rect, trigger: []const u8, content: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, hoverCardTriggerBounds(bounds), options.style.panel, options.style.border, control_radius);
    try renderControlText(scene, hoverCardTriggerBounds(bounds), control_text_padding, control_label_height, trigger, options.style.text, .center);
    const content_bounds = hoverCardContentBounds(bounds);
    try scene.pushRect(content_bounds, options.style.panel, .fill, hover_card_radius, 0.0);
    try scene.pushRect(content_bounds, options.style.border, .border, hover_card_radius, 0.0);
    try scene.pushText(ui.Rect.init(content_bounds.x + hover_card_padding, content_bounds.y + hover_card_title_y, @max(min_extent, content_bounds.w - hover_card_padding * 2.0), hover_card_title_h), content, options.style.text);
    try scene.pushText(ui.Rect.init(content_bounds.x + hover_card_padding, content_bounds.y + hover_card_detail_y, @max(min_extent, content_bounds.w - hover_card_padding * 2.0), hover_card_detail_h), hover_card_detail_label, options.style.muted);
}

pub fn renderDialog(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, destructive: bool, options: RenderOptions) ui.RenderError!void {
    const trigger = dialogTriggerBounds(bounds);
    try renderControlFrame(scene, trigger, if (destructive) alert_danger else options.style.accent, options.style.border, control_radius);
    try renderControlText(scene, trigger, dialog_trigger_padding, control_label_height, if (destructive) dialog_delete_label else dialog_open_label, options.style.bg, .center);

    const content = dialogContentBounds(bounds);
    try scene.pushRect(content, options.style.panel, .fill, dialog_radius, 0.0);
    try scene.pushRect(content, if (destructive) alert_danger else options.style.border, .border, dialog_radius, 0.0);
    try scene.pushText(ui.Rect.init(content.x + dialog_padding, content.y + dialog_title_y, @max(min_extent, content.w - dialog_padding * 2.0), dialog_title_h), title, if (destructive) alert_danger else options.style.text);
    try scene.pushText(ui.Rect.init(content.x + dialog_padding, content.y + dialog_detail_y, @max(min_extent, content.w - dialog_padding * 2.0), dialog_detail_h), detail, options.style.muted);
}

pub fn renderDirection(scene: *ui.Scene, bounds: ui.Rect, active: u16, options: RenderOptions) ui.RenderError!void {
    try renderDirectionItem(scene, directionItemBounds(bounds, 0), direction_ltr_label, active == 0, options);
    try scene.pushIconQuad(.{ .bounds = directionIconBounds(bounds), .icon_id = icon.id(.route), .color = options.style.muted });
    try renderDirectionItem(scene, directionItemBounds(bounds, 1), direction_rtl_label, active == 1, options);
}

pub fn renderDrawer(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    const trigger = drawerTriggerBounds(bounds);
    try renderControlFrame(scene, trigger, options.style.accent, options.style.border, control_radius);
    try renderControlText(scene, trigger, drawer_trigger_padding, control_label_height, overlay_open_label, options.style.bg, .center);

    const content = drawerContentBounds(bounds);
    try scene.pushRect(content, options.style.panel, .fill, drawer_radius, 0.0);
    try scene.pushRect(content, options.style.border, .border, drawer_radius, 0.0);
    try scene.pushRect(drawerHandleBounds(content), options.style.muted, .fill, drawer_handle_radius, 0.0);
    try scene.pushText(ui.Rect.init(content.x + drawer_padding, content.y + drawer_title_y, @max(min_extent, content.w - drawer_padding * 2.0), overlay_title_h), title, options.style.text);
    try scene.pushText(ui.Rect.init(content.x + drawer_padding, content.y + drawer_detail_y, @max(min_extent, content.w - drawer_padding * 2.0), overlay_detail_h), detail, options.style.muted);
}

pub fn renderSheet(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    const trigger = sheetTriggerBounds(bounds);
    try renderControlFrame(scene, trigger, options.style.accent, options.style.border, control_radius);
    try renderControlText(scene, trigger, sheet_trigger_padding, control_label_height, overlay_open_label, options.style.bg, .center);

    const content = sheetContentBounds(bounds);
    try scene.pushRect(content, options.style.panel, .fill, sheet_radius, 0.0);
    try scene.pushRect(content, options.style.border, .border, sheet_radius, 0.0);
    try scene.pushText(ui.Rect.init(content.x + sheet_padding, content.y + sheet_title_y, @max(min_extent, content.w - sheet_padding * 2.0 - sheet_close_space), overlay_title_h), title, options.style.text);
    try scene.pushText(ui.Rect.init(content.x + sheet_padding, content.y + sheet_detail_y, @max(min_extent, content.w - sheet_padding * 2.0), overlay_detail_h), detail, options.style.muted);
    try scene.pushIconQuad(.{ .bounds = sheetCloseBounds(bounds), .icon_id = icon.id(.x), .color = options.style.muted });
}

pub fn renderMenu(scene: *ui.Scene, bounds: ui.Rect, trigger: []const u8, first: []const u8, second: []const u8, options: RenderOptions) ui.RenderError!void {
    const trigger_bounds = menuTriggerBounds(bounds);
    try renderControlFrame(scene, trigger_bounds, options.style.accent, options.style.border, control_radius);
    try renderControlText(scene, trigger_bounds, menu_trigger_padding, control_label_height, trigger, options.style.bg, .center);

    const content = menuContentBounds(bounds);
    try scene.pushRect(content, options.style.panel, .fill, menu_radius, 0.0);
    try scene.pushRect(content, options.style.border, .border, menu_radius, 0.0);
    try renderMenuItem(scene, menuItemBounds(content, 0), first, options);
    try renderMenuItem(scene, menuItemBounds(content, 1), second, options);
}

pub fn collectMenuInteractions(collector: *interaction.Collector, bounds: ui.Rect, id: u32) interaction.Error!void {
    try collector.addHit(menuTriggerBounds(bounds), .button, id);
    const content = menuContentBounds(bounds);
    try collector.addHit(menuItemBounds(content, 0), .row_item, id + 1);
    try collector.addHit(menuItemBounds(content, 1), .row_item, id + 2);
}

pub fn menuTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + menu_trigger_y, menu_trigger_w, menu_trigger_h);
}

fn menuContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + menu_trigger_w + menu_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

fn menuItemBounds(content: ui.Rect, index: usize) ui.Rect {
    return ui.Rect.init(content.x + menu_padding, content.y + menu_padding + @as(f32, @floatFromInt(index)) * menu_item_pitch, @max(min_extent, content.w - menu_padding * 2.0), menu_item_h);
}

pub fn dialogTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + dialog_trigger_y, dialog_trigger_w, dialog_trigger_h);
}

pub fn dialogContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + dialog_trigger_w + dialog_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

pub fn directionItemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return switch (index) {
        0 => ui.Rect.init(bounds.x, bounds.y + direction_item_y, direction_item_w, direction_item_h),
        else => ui.Rect.init(bounds.x + direction_second_x, bounds.y + direction_item_y, direction_item_w, direction_item_h),
    };
}

fn directionIconBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + direction_icon_x, bounds.y + direction_icon_y, direction_icon_size, direction_icon_size);
}

pub fn drawerTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + drawer_trigger_y, drawer_trigger_w, drawer_trigger_h);
}

pub fn drawerContentBounds(bounds: ui.Rect) ui.Rect {
    const y = bounds.y + drawer_content_y;
    return ui.Rect.init(bounds.x + drawer_content_inset_x, y, @max(min_extent, bounds.w - drawer_content_inset_x * 2.0), @max(min_extent, bounds.y + bounds.h - y));
}

fn drawerHandleBounds(content: ui.Rect) ui.Rect {
    return ui.Rect.init(content.x + (content.w - drawer_handle_w) * 0.5, content.y + drawer_handle_y, drawer_handle_w, drawer_handle_h);
}

pub fn sheetTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + sheet_trigger_y, sheet_trigger_w, sheet_trigger_h);
}

pub fn sheetContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + bounds.w - @min(sheet_content_w, @max(min_extent, bounds.w - sheet_content_min_left));
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

pub fn sheetCloseBounds(bounds: ui.Rect) ui.Rect {
    const content = sheetContentBounds(bounds);
    return ui.Rect.init(content.x + content.w - sheet_close_inset - sheet_close_size, content.y + sheet_close_inset, sheet_close_size, sheet_close_size);
}

pub fn popoverTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + popover_trigger_y, popover_trigger_w, popover_trigger_h);
}

pub fn popoverContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + popover_trigger_w + popover_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

pub fn hoverCardTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + hover_card_trigger_y, hover_card_trigger_w, hover_card_trigger_h);
}

pub fn hoverCardContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + hover_card_trigger_w + hover_card_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

pub fn renderTooltip(scene: *ui.Scene, bounds: ui.Rect, trigger: []const u8, content: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, tooltipTriggerBounds(bounds), options.style.panel, options.style.border, control_radius);
    try renderControlText(scene, tooltipTriggerBounds(bounds), control_text_padding, control_label_height, trigger, options.style.text, .center);
    const tip = tooltipContentBounds(bounds);
    try scene.pushRect(tip, options.style.text, .fill, tooltip_radius, 0.0);
    try renderControlText(scene, tip, tooltip_padding, tooltip_text_h, content, options.style.bg, .center);
}

pub fn renderToast(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    const toast = toastBounds(bounds);
    try scene.pushRect(toast, options.style.panel, .fill, toast_radius, 0.0);
    try scene.pushRect(toast, options.style.border, .border, toast_radius, 0.0);
    try scene.pushIconQuad(.{ .bounds = toastIconBounds(toast), .icon_id = icon.id(.check), .color = options.style.accent });
    const text_x = toast.x + toast_text_x;
    try scene.pushText(ui.Rect.init(text_x, toast.y + toast_title_y, @max(min_extent, toast.x + toast.w - text_x - toast_padding), toast_title_h), title, options.style.text);
    try scene.pushText(ui.Rect.init(text_x, toast.y + toast_detail_y, @max(min_extent, toast.x + toast.w - text_x - toast_padding), toast_detail_h), detail, options.style.muted);
}

pub fn renderSidebar(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, item: []const u8, options: RenderOptions) ui.RenderError!void {
    const rail = sidebarRailBounds(bounds);
    try scene.pushRect(rail, options.style.panel, .fill, sidebar_radius, 0.0);
    try scene.pushRect(rail, options.style.border, .border, sidebar_radius, 0.0);
    try scene.pushIconQuad(.{ .bounds = sidebarTriggerBounds(bounds), .icon_id = icon.id(.menu), .color = options.style.text });
    try scene.pushText(sidebarTitleBounds(bounds), title, options.style.muted);
    const item_bounds = sidebarItemBounds(bounds);
    try scene.pushRect(item_bounds, options.style.row, .fill, sidebar_item_radius, 0.0);
    try scene.pushText(sidebarItemTextBounds(item_bounds), item, options.style.text);
    const content = sidebarContentBounds(bounds);
    try scene.pushRect(content, options.style.row, .fill, sidebar_radius, 0.0);
}

pub fn tooltipTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + tooltip_trigger_y, tooltip_trigger_w, tooltip_trigger_h);
}

fn tooltipContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + tooltip_trigger_w + tooltip_gap;
    return ui.Rect.init(x, bounds.y + tooltip_content_y, @max(min_extent, bounds.x + bounds.w - x), tooltip_content_h);
}

pub fn toastBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(bounds.h, toast_h));
}

fn toastIconBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + toast_icon_x, bounds.y + (bounds.h - toast_icon_size) * 0.5, toast_icon_size, toast_icon_size);
}

fn sidebarRailBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, @min(bounds.w, sidebar_rail_w), bounds.h);
}

pub fn sidebarTriggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + sidebar_trigger_x, bounds.y + sidebar_trigger_y, sidebar_trigger_size, sidebar_trigger_size);
}

pub fn sidebarItemBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + sidebar_item_x, bounds.y + sidebar_item_y, @max(min_extent, sidebar_rail_w - sidebar_item_x * 2.0), sidebar_item_h);
}

fn sidebarTitleBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + sidebar_item_x, bounds.y + sidebar_title_y, @max(min_extent, sidebar_rail_w - sidebar_item_x * 2.0), sidebar_title_h);
}

fn sidebarItemTextBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + sidebar_item_padding, bounds.y + (bounds.h - sidebar_item_text_h) * 0.5, @max(min_extent, bounds.w - sidebar_item_padding * 2.0), sidebar_item_text_h);
}

fn sidebarContentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + sidebar_rail_w + sidebar_content_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

pub fn renderTabs(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8, active: u16, options: RenderOptions) ui.RenderError!void {
    const list = tabsListBounds(bounds);
    try scene.pushRect(list, options.style.row, .fill, tabs_list_radius, 0.0);
    try renderTabsTrigger(scene, tabsTriggerBounds(list, 0), first, active == 0, options);
    try renderTabsTrigger(scene, tabsTriggerBounds(list, 1), second, active == 1, options);
    const panel = ui.Rect.init(bounds.x, bounds.y + tabs_list_h + tabs_gap, bounds.w, @max(min_extent, bounds.h - tabs_list_h - tabs_gap));
    try scene.pushRect(panel, options.style.panel, .fill, control_radius, 0.0);
    try scene.pushRect(panel, options.style.border, .border, control_radius, 0.0);
    try scene.pushText(ui.Rect.init(panel.x + tabs_panel_padding, panel.y + tabs_panel_padding, @max(min_extent, panel.w - tabs_panel_padding * 2.0), control_label_height), if (active == 1) second else first, options.style.muted);
}

pub fn tabsListBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, @min(bounds.w, tabs_list_w), tabs_list_h);
}

pub fn tabsTriggerBounds(list: ui.Rect, index: usize) ui.Rect {
    const trigger_w = @max(min_extent, (list.w - tabs_list_padding * 2.0) / 2.0);
    return ui.Rect.init(list.x + tabs_list_padding + @as(f32, @floatFromInt(index)) * trigger_w, list.y + tabs_list_padding, trigger_w, @max(min_extent, list.h - tabs_list_padding * 2.0));
}

pub fn renderTable(scene: *ui.Scene, bounds: ui.Rect, name: []const u8, role: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.panel, .fill, table_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, table_radius, 0.0);
    try renderTableHeader(scene, bounds, .name, options);
    try renderTableHeader(scene, bounds, .role, options);
    try scene.pushRect(ui.Rect.init(bounds.x, bounds.y + table_header_h, bounds.w, separator_height), options.style.border, .fill, 0.0, 0.0);
    const row = tableRowBounds(bounds);
    try scene.pushRect(row.insetUniform(table_row_inset), options.style.row, .fill, table_row_radius, 0.0);
    try scene.pushText(tableBodyCellBounds(bounds, 0), name, options.style.text);
    try scene.pushAlignedText(tableBodyCellBounds(bounds, 1), role, options.style.muted, .end);
}

fn renderTableHeader(scene: *ui.Scene, bounds: ui.Rect, column: common.TableColumn, options: RenderOptions) ui.RenderError!void {
    const active = if (options.table_sort) |sort| sort.column == column else false;
    if (active) try scene.pushRect(tableHeaderBounds(bounds, column).insetLtrb(table_row_inset, table_row_inset, table_row_inset, table_row_inset), options.style.row, .fill, table_row_radius, 0.0);
    const label = tableHeaderLabel(column, options.table_sort);
    const text_color = if (active) options.style.text else options.style.muted;
    switch (column) {
        .name => try scene.pushText(tableHeaderBounds(bounds, column), label, text_color),
        .role => try scene.pushAlignedText(tableHeaderBounds(bounds, column), label, text_color, .end),
    }
}

pub fn tableHeaderBounds(bounds: ui.Rect, column: common.TableColumn) ui.Rect {
    return tableCellBounds(bounds, tableColumnIndex(column), table_header_y, table_header_text_h);
}

pub fn tableHeaderCellBounds(bounds: ui.Rect, column: usize) ui.Rect {
    return tableCellBounds(bounds, column, table_header_y, table_header_text_h);
}

fn tableBodyCellBounds(bounds: ui.Rect, column: usize) ui.Rect {
    return tableCellBounds(bounds, column, table_body_y, table_body_text_h);
}

fn tableCellBounds(bounds: ui.Rect, column: usize, y_offset: f32, height: f32) ui.Rect {
    const left_w = bounds.w * table_name_column_ratio;
    return switch (column) {
        0 => ui.Rect.init(bounds.x + table_padding_x, bounds.y + y_offset, @max(min_extent, left_w - table_padding_x), height),
        else => ui.Rect.init(bounds.x + left_w, bounds.y + y_offset, @max(min_extent, bounds.w - left_w - table_padding_x), height),
    };
}

pub fn tableRowBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + table_header_h + separator_height, bounds.w, @max(min_extent, bounds.h - table_header_h - separator_height));
}

fn tableHeaderLabel(column: common.TableColumn, sort: ?common.TableSort) []const u8 {
    const sorted = if (sort) |value| value.column == column else false;
    return switch (column) {
        .name => if (sorted) sortedLabel(sort.?.direction, table_header_name_asc, table_header_name_desc) else table_header_name,
        .role => if (sorted) sortedLabel(sort.?.direction, table_header_role_asc, table_header_role_desc) else table_header_role,
    };
}

fn sortedLabel(direction: common.SortDirection, asc: []const u8, desc: []const u8) []const u8 {
    return switch (direction) {
        .ascending => asc,
        .descending => desc,
    };
}

fn tableColumnIndex(column: common.TableColumn) usize {
    return switch (column) {
        .name => 0,
        .role => 1,
    };
}

pub fn renderScrollArea(scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.panel, .fill, scroll_area_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, scroll_area_radius, 0.0);

    const metrics = scrollAreaMetrics(bounds, options.scroll);
    const viewport = scrollAreaViewportBounds(bounds);
    if (try scene.pushClip(viewport)) {
        try scene.pushText(ui.Rect.init(viewport.x, viewport.y + scroll_area_content_y - metrics.offset_y, viewport.w, scroll_area_text_h), scroll_area_label, options.style.text);
        scene.popClip();
    }

    const track = scrollAreaTrackBounds(bounds);
    try scene.pushRect(track, options.style.row, .fill, scroll_area_track_radius, 0.0);
    try scene.pushRect(scrollAreaThumbBounds(track, metrics), options.style.border, .fill, scroll_area_track_radius, 0.0);
}

pub const ScrollAreaMetrics = struct {
    viewport_h: f32,
    content_h: f32,
    offset_y: f32,

    pub fn maxOffset(self: ScrollAreaMetrics) f32 {
        return @max(0.0, self.content_h - self.viewport_h);
    }
};

pub fn scrollAreaMetrics(bounds: ui.Rect, state: ?common.ScrollState) ScrollAreaMetrics {
    const fallback_viewport_h = @max(min_extent, bounds.h - scroll_area_track_inset_y * 2.0);
    if (state) |value| {
        const viewport_h = @max(min_extent, value.viewport_h);
        const content_h = @max(viewport_h, value.content_h);
        return .{
            .viewport_h = viewport_h,
            .content_h = content_h,
            .offset_y = std.math.clamp(value.offset_y, 0.0, @max(0.0, content_h - viewport_h)),
        };
    }
    const content_h = fallback_viewport_h / scroll_area_thumb_ratio;
    return .{
        .viewport_h = fallback_viewport_h,
        .content_h = content_h,
        .offset_y = 0.0,
    };
}

pub fn scrollAreaViewportBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + scroll_area_padding, bounds.y + scroll_area_track_inset_y, @max(min_extent, bounds.w - scroll_area_scrollbar_w - scroll_area_padding * 2.0), @max(min_extent, bounds.h - scroll_area_track_inset_y * 2.0));
}

pub fn scrollAreaTrackBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + bounds.w - scroll_area_track_inset_x, bounds.y + scroll_area_track_inset_y, scroll_area_track_w, @max(min_extent, bounds.h - scroll_area_track_inset_y * 2.0));
}

pub fn scrollAreaThumbBounds(track: ui.Rect, metrics: ScrollAreaMetrics) ui.Rect {
    const ratio = std.math.clamp(metrics.viewport_h / @max(metrics.viewport_h, metrics.content_h), 0.0, 1.0);
    const thumb_h = @min(track.h, @max(scroll_area_thumb_min_h, track.h * ratio));
    const travel = @max(0.0, track.h - thumb_h);
    const offset_ratio = if (metrics.maxOffset() == 0.0) 0.0 else metrics.offset_y / metrics.maxOffset();
    return ui.Rect.init(track.x, track.y + travel * offset_ratio, track.w, thumb_h);
}

pub fn renderBreadcrumb(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, current: []const u8, options: RenderOptions) ui.RenderError!void {
    const first_bounds = breadcrumbItemBounds(bounds, 0);
    const middle_bounds = breadcrumbItemBounds(bounds, 1);
    const current_bounds = breadcrumbItemBounds(bounds, 2);
    try scene.pushText(first_bounds.withHeightCentered(control_label_height), first, options.style.muted);
    try scene.pushIconQuad(.{ .bounds = breadcrumbSeparatorBounds(bounds, 0), .icon_id = icon.id(.chevron_right), .color = options.style.muted });
    try scene.pushText(middle_bounds.withHeightCentered(control_label_height), breadcrumb_middle_label, options.style.muted);
    try scene.pushIconQuad(.{ .bounds = breadcrumbSeparatorBounds(bounds, 1), .icon_id = icon.id(.chevron_right), .color = options.style.muted });
    try scene.pushText(current_bounds.withHeightCentered(control_label_height), current, options.style.text);
}

pub fn breadcrumbItemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return switch (index) {
        0 => ui.Rect.init(bounds.x, bounds.y, breadcrumb_first_w, bounds.h),
        1 => ui.Rect.init(bounds.x + breadcrumb_first_w + breadcrumb_separator_w, bounds.y, breadcrumb_middle_w, bounds.h),
        else => ui.Rect.init(bounds.x + breadcrumb_first_w + breadcrumb_middle_w + breadcrumb_separator_w * 2.0, bounds.y, @max(min_extent, bounds.w - breadcrumb_first_w - breadcrumb_middle_w - breadcrumb_separator_w * 2.0), bounds.h),
    };
}

fn breadcrumbSeparatorBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const x = if (index == 0) bounds.x + breadcrumb_first_w else bounds.x + breadcrumb_first_w + breadcrumb_separator_w + breadcrumb_middle_w;
    return ui.Rect.init(x + breadcrumb_icon_inset, bounds.y + (bounds.h - breadcrumb_icon_size) * 0.5, breadcrumb_icon_size, breadcrumb_icon_size);
}

pub fn renderToggle(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, pressed: bool, options: RenderOptions) ui.RenderError!void {
    const fill = if (pressed) options.style.row else ui.Color.clear;
    const text_color = if (pressed) options.style.text else options.style.muted;
    try scene.pushRect(bounds, fill, .fill, control_radius, 0.0);
    try scene.pushRect(bounds, if (pressed) options.style.border else ui.Color.clear, .border, control_radius, 0.0);
    try renderControlText(scene, bounds, toggle_text_padding, control_label_height, label, text_color, .center);
}

pub fn renderButtonGroup(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8, active: u16, options: RenderOptions) ui.RenderError!void {
    try renderButtonGroupSegment(scene, buttonGroupSegmentBounds(bounds, 0), first, active == 0, options);
    try renderButtonGroupSegment(scene, buttonGroupSegmentBounds(bounds, 1), second, active == 1, options);
}

pub fn renderMenubar(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8, active: u16, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, control_radius);
    try renderMenubarItem(scene, menubarItemBounds(bounds, 0), first, active == 0, options);
    try renderMenubarItem(scene, menubarItemBounds(bounds, 1), second, active == 1, options);
    try renderMenubarItem(scene, menubarItemBounds(bounds, 2), menubar_third_label, active == 2, options);
}

pub fn menubarItemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const item_w = switch (index) {
        0 => menubar_first_w,
        1 => menubar_second_w,
        else => menubar_third_w,
    };
    const item_x = switch (index) {
        0 => bounds.x + menubar_padding,
        1 => bounds.x + menubar_padding + menubar_first_w,
        else => bounds.x + menubar_padding + menubar_first_w + menubar_second_w,
    };
    return ui.Rect.init(item_x, bounds.y + menubar_padding, item_w, @max(min_extent, bounds.h - menubar_padding * 2.0));
}

pub fn renderNavigationMenu(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8, active: u16, options: RenderOptions) ui.RenderError!void {
    try renderNavigationMenuItem(scene, navigationMenuItemBounds(bounds, 0), first, active == 0, true, options);
    try renderNavigationMenuItem(scene, navigationMenuItemBounds(bounds, 1), second, active == 1, true, options);
    try renderNavigationMenuItem(scene, navigationMenuItemBounds(bounds, 2), navigation_menu_third_label, active == 2, false, options);
}

pub fn navigationMenuItemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const item_w = switch (index) {
        0 => navigation_menu_first_w,
        1 => navigation_menu_second_w,
        else => navigation_menu_third_w,
    };
    const item_x = switch (index) {
        0 => bounds.x,
        1 => bounds.x + navigation_menu_first_w + navigation_menu_gap,
        else => bounds.x + navigation_menu_first_w + navigation_menu_second_w + navigation_menu_gap * 2.0,
    };
    return ui.Rect.init(item_x, bounds.y, item_w, @min(bounds.h, navigation_menu_item_h));
}

pub fn renderCommand(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    const input = commandInputBounds(bounds);
    try renderControlFrame(scene, input, options.style.panel, options.style.border, command_radius);
    try scene.pushIconQuad(.{ .bounds = ui.Rect.init(input.x + command_icon_x, input.y + (input.h - command_icon_size) * 0.5, command_icon_size, command_icon_size), .icon_id = icon.id(.search), .color = options.style.muted });
    const input_text = if (options.command_palette) |palette| if (palette.query.len == 0) placeholder else palette.query else placeholder;
    const input_color = if (options.command_palette) |palette| if (palette.query.len == 0) options.style.muted else options.style.text else options.style.muted;
    try scene.pushText(ui.Rect.init(input.x + command_text_x, input.y + (input.h - command_text_h) * 0.5, @max(min_extent, input.w - command_text_x - command_padding_x), command_text_h), input_text, input_color);

    if (options.command_palette) |palette| {
        const list = commandListBounds(bounds) orelse return;
        try scene.pushRect(list, options.style.panel, .fill, command_radius, 0.0);
        try scene.pushRect(list, options.style.border, .border, command_radius, 0.0);
        var item_index: usize = 0;
        var visible_index: usize = 0;
        while (item_index < palette.items.len and visible_index < commandVisibleItemCapacity(bounds)) : (item_index += 1) {
            const item = palette.items[item_index];
            if (!commandItemMatches(palette.query, item)) continue;
            try renderCommandItem(scene, commandItemBounds(bounds, visible_index).?, item, item_index == palette.selected_index, options);
            visible_index += 1;
        }
        if (visible_index == 0) {
            try scene.pushText(ui.Rect.init(list.x + command_list_padding, list.y + command_list_padding, @max(min_extent, list.w - command_list_padding * 2.0), command_empty_text_h), command_empty_label, options.style.muted);
        }
    }
}

pub fn collectCommandInteractions(collector: *interaction.Collector, bounds: ui.Rect, id: u32) interaction.Error!void {
    try collector.addHit(commandInputBounds(bounds), .input, id);
    var index: usize = 0;
    while (index < commandVisibleItemCapacity(bounds)) : (index += 1) {
        if (commandItemBounds(bounds, index)) |item_bounds| {
            try collector.addHit(item_bounds, .row_item, id + command_item_id_offset + @as(u32, @intCast(index)));
        }
    }
}

pub fn commandInputBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(bounds.h, command_input_h));
}

fn commandListBounds(bounds: ui.Rect) ?ui.Rect {
    if (bounds.h <= command_input_h + command_list_gap) return null;
    return ui.Rect.init(bounds.x, bounds.y + command_input_h + command_list_gap, bounds.w, @max(min_extent, bounds.h - command_input_h - command_list_gap));
}

pub fn commandItemBounds(bounds: ui.Rect, index: usize) ?ui.Rect {
    if (index >= command_max_visible_items) return null;
    const list = commandListBounds(bounds) orelse return null;
    const y = list.y + command_list_padding + @as(f32, @floatFromInt(index)) * command_item_pitch;
    if (y + command_item_h > list.y + list.h - command_list_padding) return null;
    return ui.Rect.init(list.x + command_list_padding, y, @max(min_extent, list.w - command_list_padding * 2.0), command_item_h);
}

pub fn renderField(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushText(fieldLabelBounds(bounds), label, options.style.text);
    try renderInput(scene, fieldInputBoundsFor(bounds, options), placeholder, null, fieldInputOptions(options));
    if (options.validation) |validation| {
        const color = switch (validation.state) {
            .helper => options.style.muted,
            .invalid => common.state_invalid_border,
        };
        try scene.pushText(fieldValidationBounds(bounds), validation.message, color);
    }
}

fn fieldLabelBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, field_label_h);
}

pub fn fieldInputBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + field_label_h + field_gap, bounds.w, @max(min_extent, bounds.h - field_label_h - field_gap));
}

pub fn fieldValidationBounds(bounds: ui.Rect) ui.Rect {
    const input = fieldInputBoundsWithValidation(bounds);
    return ui.Rect.init(bounds.x, input.y + input.h + field_validation_gap, bounds.w, field_validation_h);
}

pub fn measureField(constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
    const preferred = if (options.validation == null) preferred_field else preferred_field_with_validation;
    return measureFixed(preferred, constraints);
}

fn fieldInputOptions(options: RenderOptions) RenderOptions {
    var next = options;
    if (options.validation) |validation| {
        next.control.invalid = next.control.invalid or validation.state == .invalid;
    }
    return next;
}

fn fieldInputBoundsFor(bounds: ui.Rect, options: RenderOptions) ui.Rect {
    return if (options.validation == null) fieldInputBounds(bounds) else fieldInputBoundsWithValidation(bounds);
}

fn fieldInputBoundsWithValidation(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + field_label_h + field_gap, bounds.w, @max(min_extent, @min(field_input_h, bounds.h - field_label_h - field_gap)));
}

pub fn renderInputOtp(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, options: RenderOptions) ui.RenderError!void {
    for (0..input_otp_slot_count) |index| {
        const slot = inputOtpSlotBounds(bounds, index);
        try renderControlFrame(scene, slot, options.style.panel, options.style.border, control_radius);
        if (index < value.len) {
            try renderControlText(scene, slot, input_otp_text_padding, control_label_height, value[index .. index + 1], options.style.text, .center);
        }
    }
}

pub fn inputOtpSlotBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const x = bounds.x + @as(f32, @floatFromInt(index)) * (input_otp_slot_size + input_otp_slot_gap);
    return ui.Rect.init(x, bounds.y, input_otp_slot_size, @min(bounds.h, input_otp_slot_size));
}

pub fn renderToggleGroup(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8, active: u16, options: RenderOptions) ui.RenderError!void {
    try renderToggleGroupItem(scene, toggleGroupItemBounds(bounds, 0), first, active == 0, options);
    try renderToggleGroupItem(scene, toggleGroupItemBounds(bounds, 1), second, active == 1, options);
    try renderToggleGroupItem(scene, toggleGroupItemBounds(bounds, 2), toggle_group_third_label, active == 2, options);
}

pub fn toggleGroupItemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const item_w = switch (index) {
        1 => toggle_group_middle_w,
        else => toggle_group_side_w,
    };
    const item_x = switch (index) {
        0 => bounds.x,
        1 => bounds.x + toggle_group_side_w,
        else => bounds.x + toggle_group_side_w + toggle_group_middle_w,
    };
    return ui.Rect.init(item_x, bounds.y, item_w, bounds.h);
}

pub fn buttonGroupSegmentBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const segment_w = @max(min_extent, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * segment_w, bounds.y, segment_w, bounds.h);
}

pub fn renderRowItem(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, row_radius, 0.0);
    if (rowTitleBounds(bounds, detail.len == 0)) |title_bounds| {
        try scene.pushText(title_bounds, title, options.style.text);
    }
    if (detail.len != 0) {
        if (rowDetailBounds(bounds)) |detail_bounds| {
            try scene.pushText(detail_bounds, detail, options.style.muted);
        }
    }
}

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

fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

fn renderControlText(scene: *ui.Scene, bounds: ui.Rect, padding: f32, height: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    if (contentInset(bounds, padding)) |text_bounds| try pushControlText(scene, text_bounds, height, value, color, alignment);
}

fn pushControlText(scene: *ui.Scene, bounds: ui.Rect, height: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    try scene.pushAlignedText(bounds.withHeightCentered(height), value, color, alignment);
}

fn renderInlineLabel(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushText(bounds.withHeightCentered(control_label_height), value, color);
}

fn renderRadioOption(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    const outer = ui.Rect.init(bounds.x, bounds.y + (bounds.h - checkbox_box_size) * 0.5, checkbox_box_size, checkbox_box_size);
    try scene.pushRect(outer, options.style.panel, .fill, checkbox_box_size * 0.5, 0.0);
    try scene.pushRect(outer, options.style.border, .border, checkbox_box_size * 0.5, 0.0);
    if (selected) {
        const dot = ui.Rect.init(outer.x + (outer.w - radio_dot_size) * 0.5, outer.y + (outer.h - radio_dot_size) * 0.5, radio_dot_size, radio_dot_size);
        try scene.pushRect(dot, options.style.accent, .fill, radio_dot_size * 0.5, 0.0);
    }
    const label_x = outer.x + outer.w + checkbox_text_gap;
    try renderInlineLabel(scene, ui.Rect.init(label_x, bounds.y, @max(min_extent, bounds.x + bounds.w - label_x), bounds.h), label, options.style.text);
}

fn renderTabsTrigger(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    if (active) {
        try scene.pushRect(bounds, options.style.panel, .fill, control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, control_radius, 0.0);
    }
    try renderControlText(scene, bounds, toggle_text_padding, control_label_height, label, if (active) options.style.text else options.style.muted, .center);
}

fn renderButtonGroupSegment(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.text else options.style.panel, .fill, 0.0, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, 0.0, 0.0);
    try renderControlText(scene, bounds, toggle_text_padding, control_label_height, label, if (active) options.style.panel else options.style.text, .center);
}

fn renderCarouselButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, ui.Color.clear, options.style.border, carousel_button_size * 0.5);
    try renderControlText(scene, bounds, carousel_button_text_padding, control_label_height, label, options.style.text, .center);
}

fn renderCalendarNav(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, ui.Color.clear, .fill, control_radius, 0.0);
    try renderControlText(scene, bounds, calendar_nav_text_padding, calendar_day_text_h, label, options.style.muted, .center);
}

fn renderCalendarDay(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (selected) options.style.accent else ui.Color.clear, .fill, control_radius, 0.0);
    try renderControlText(scene, bounds, calendar_day_text_padding, calendar_day_text_h, label, if (selected) options.style.bg else options.style.text, .center);
}

fn renderMenuItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, menu_item_radius, 0.0);
    try renderControlText(scene, bounds, menu_item_padding, menu_item_text_h, label, options.style.text, .start);
}

fn renderCommandItem(scene: *ui.Scene, bounds: ui.Rect, item: common.CommandItem, selected: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (selected) options.style.row else ui.Color.clear, .fill, command_radius, 0.0);
    const detail_w: f32 = if (item.shortcut.len == 0) 0.0 else command_item_detail_w;
    const label_bounds = ui.Rect.init(bounds.x, bounds.y, @max(min_extent, bounds.w - detail_w), bounds.h);
    try renderControlText(scene, label_bounds, command_item_padding_x, control_label_height, item.label, if (selected) options.style.text else options.style.muted, .start);
    if (item.shortcut.len != 0) {
        try renderControlText(scene, ui.Rect.init(bounds.x + bounds.w - detail_w, bounds.y, detail_w, bounds.h), command_item_padding_x, control_label_height, item.shortcut, options.style.muted, .end);
    }
}

fn commandVisibleItemCapacity(bounds: ui.Rect) usize {
    const list = commandListBounds(bounds) orelse return 0;
    const available_h = @max(0.0, list.h - command_list_padding * 2.0);
    const raw_count: usize = @intFromFloat(@floor((available_h + command_item_pitch - command_item_h) / command_item_pitch));
    return @min(command_max_visible_items, raw_count);
}

fn commandItemMatches(query: []const u8, item: common.CommandItem) bool {
    if (query.len == 0) return true;
    return asciiContainsFold(item.label, query) or asciiContainsFold(item.detail, query) or asciiContainsFold(item.shortcut, query);
}

fn asciiContainsFold(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (asciiEqualFold(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

fn asciiEqualFold(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_char, right_char| {
        if (asciiLower(left_char) != asciiLower(right_char)) return false;
    }
    return true;
}

fn asciiLower(value: u8) u8 {
    return switch (value) {
        'A'...'Z' => value + ('a' - 'A'),
        else => value,
    };
}

fn renderDirectionItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.accent else options.style.row, .fill, direction_item_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, direction_item_radius, 0.0);
    try renderControlText(scene, bounds, direction_item_padding, direction_item_text_h, label, if (active) options.style.bg else options.style.text, .center);
}

fn renderComboboxOption(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, control_radius, 0.0);
    try renderControlText(scene, ui.Rect.init(bounds.x, bounds.y, @max(min_extent, bounds.w - combobox_option_indicator_w), bounds.h), combobox_option_padding, control_label_height, label, options.style.text, .start);
    if (selected) {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(bounds.x + bounds.w - combobox_icon_size - combobox_option_padding, bounds.y + (bounds.h - combobox_icon_size) * 0.5, combobox_icon_size, combobox_icon_size),
            .icon_id = icon.id(.check),
            .color = options.style.accent,
        });
    }
}

fn renderMenubarItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.row else ui.Color.clear, .fill, control_radius, 0.0);
    try renderControlText(scene, bounds, menubar_item_padding_x, control_label_height, label, if (active) options.style.text else options.style.muted, .center);
}

fn renderToggleGroupItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.row else ui.Color.clear, .fill, 0.0, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, 0.0, 0.0);
    try renderControlText(scene, bounds, toggle_text_padding, control_label_height, label, if (active) options.style.text else options.style.muted, .center);
}

fn renderNavigationMenuItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, show_chevron: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.row else ui.Color.clear, .fill, control_radius, 0.0);
    const icon_space: f32 = if (show_chevron) navigation_menu_icon_space else 0.0;
    try renderControlText(scene, ui.Rect.init(bounds.x, bounds.y, @max(min_extent, bounds.w - icon_space), bounds.h), navigation_menu_text_padding, control_label_height, label, if (active) options.style.text else options.style.muted, .center);
    if (show_chevron) {
        try scene.pushIconQuad(.{ .bounds = ui.Rect.init(bounds.x + bounds.w - navigation_menu_icon_size - navigation_menu_icon_padding, bounds.y + (bounds.h - navigation_menu_icon_size) * 0.5, navigation_menu_icon_size, navigation_menu_icon_size), .icon_id = icon.id(.chevron_right), .color = options.style.muted });
    }
}

fn renderControlFrame(scene: *ui.Scene, bounds: ui.Rect, fill: ui.Color, border: ui.Color, radius: f32) ui.RenderError!void {
    try renderChrome(scene, bounds, .control(fill, border, radius));
}

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

fn renderControlStateOverlay(scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions, radius: f32) ui.RenderError!void {
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

pub const preferred_alert = ui.Size{ .w = 260.0, .h = 64.0 };
pub const preferred_accordion = ui.Size{ .w = 260.0, .h = 68.0 };
pub const preferred_dialog = ui.Size{ .w = 240.0, .h = 52.0 };
pub const preferred_direction = ui.Size{ .w = 150.0, .h = 36.0 };
pub const preferred_aspect_ratio = ui.Size{ .w = 220.0, .h = 124.0 };
pub const preferred_calendar = ui.Size{ .w = 240.0, .h = 152.0 };
pub const preferred_carousel = ui.Size{ .w = 240.0, .h = 40.0 };
pub const preferred_chart = ui.Size{ .w = 240.0, .h = 90.0 };
pub const preferred_combobox = ui.Size{ .w = 240.0, .h = 82.0 };
pub const preferred_empty = ui.Size{ .w = 260.0, .h = 132.0 };
pub const preferred_scroll_area = ui.Size{ .w = 220.0, .h = 48.0 };
pub const preferred_breadcrumb = ui.Size{ .w = 220.0, .h = 36.0 };
pub const preferred_menubar = ui.Size{ .w = 170.0, .h = 36.0 };
pub const preferred_navigation_menu = ui.Size{ .w = 220.0, .h = 36.0 };
pub const preferred_command = ui.Size{ .w = 220.0, .h = 36.0 };
pub const preferred_command_palette = ui.Size{ .w = 260.0, .h = 130.0 };
pub const preferred_field = ui.Size{ .w = 220.0, .h = 56.0 };
pub const preferred_field_with_validation = ui.Size{ .w = 220.0, .h = 74.0 };
pub const preferred_hover_card = ui.Size{ .w = 240.0, .h = 52.0 };
pub const preferred_menu = ui.Size{ .w = 240.0, .h = 52.0 };
pub const preferred_drawer = ui.Size{ .w = 240.0, .h = 76.0 };
pub const preferred_sheet = ui.Size{ .w = 240.0, .h = 76.0 };
pub const preferred_input_otp = ui.Size{ .w = 200.0, .h = 36.0 };
pub const preferred_button_group = ui.Size{ .w = 160.0, .h = 36.0 };
pub const preferred_toggle_group = ui.Size{ .w = 180.0, .h = 36.0 };
pub const preferred_toggle = ui.Size{ .w = 96.0, .h = 36.0 };
pub const preferred_input = ui.Size{ .w = 220.0, .h = 40.0 };
pub const preferred_input_group = ui.Size{ .w = 260.0, .h = 40.0 };
pub const preferred_textarea = ui.Size{ .w = 220.0, .h = 88.0 };
pub const preferred_select = ui.Size{ .w = 220.0, .h = 40.0 };
pub const preferred_checkbox = ui.Size{ .w = 220.0, .h = 28.0 };
pub const preferred_radio_group = ui.Size{ .w = 220.0, .h = 52.0 };
pub const preferred_switch = ui.Size{ .w = 220.0, .h = 32.0 };
pub const preferred_pagination = ui.Size{ .w = 240.0, .h = 36.0 };
pub const preferred_popover = ui.Size{ .w = 240.0, .h = 52.0 };
pub const preferred_tabs = ui.Size{ .w = 220.0, .h = 84.0 };
pub const preferred_table = ui.Size{ .w = 260.0, .h = 64.0 };
pub const preferred_tooltip = ui.Size{ .w = 240.0, .h = 44.0 };
pub const preferred_toast = ui.Size{ .w = 240.0, .h = 52.0 };
pub const preferred_sidebar = ui.Size{ .w = 240.0, .h = 64.0 };
pub const preferred_row_item = ui.Size{ .w = 260.0, .h = 48.0 };

const min_extent: f32 = 1.0;
const measure_max_width: f32 = 4096.0;
pub const menubar_item_count: u32 = 3;
pub const navigation_menu_item_count: u32 = 3;
pub const input_otp_slot_count: usize = 6;
pub const toggle_group_item_count: u32 = 3;
pub const direction_item_count: u32 = 2;
const accordion_trigger_h: f32 = 36.0;
const accordion_trigger_text_y: f32 = 10.0;
const accordion_icon_space: f32 = 22.0;
const accordion_icon_size: f32 = 14.0;
const accordion_icon_y: f32 = 11.0;
const accordion_content_padding_top: f32 = 8.0;
const accordion_detail_height: f32 = 16.0;
const accordion_detail_average_w: f32 = 7.5;
const accordion_detail_max_lines: usize = 2;
const alert_radius: f32 = 8.0;
const alert_padding_x: f32 = 16.0;
const alert_padding_y: f32 = 12.0;
const alert_icon_size: f32 = 16.0;
const alert_text_x: f32 = 44.0;
const alert_title_height: f32 = 16.0;
const alert_detail_gap: f32 = 2.0;
const alert_detail_height: f32 = 16.0;
const alert_detail_average_w: f32 = 7.5;
const alert_detail_max_lines: usize = 2;
const alert_danger = ui.Color{ .r = 239, .g = 68, .b = 68 };
const control_radius: f32 = tokens.Component.control_radius;
const focus_ring_outset: f32 = tokens.Component.focus_ring_outset;
const state_loading_h: f32 = tokens.Component.state_loading_h;
pub const calendar_day_count: usize = 28;
pub const calendar_day_id_offset: u32 = 2;
const calendar_column_count: usize = 7;
const calendar_radius: f32 = 8.0;
const calendar_padding: f32 = 8.0;
const calendar_nav_size: f32 = 24.0;
const calendar_caption_h: f32 = 24.0;
const calendar_weekday_y: f32 = 36.0;
const calendar_weekday_h: f32 = 16.0;
const calendar_grid_y: f32 = 56.0;
const calendar_cell_size: f32 = 22.0;
const calendar_cell_gap: f32 = 2.0;
const calendar_day_text_h: f32 = 12.0;
const calendar_day_text_padding: f32 = 2.0;
const calendar_nav_text_padding: f32 = 4.0;
const carousel_button_size: f32 = 28.0;
const carousel_gap: f32 = 8.0;
const carousel_radius: f32 = 8.0;
const carousel_text_padding: f32 = 8.0;
const carousel_button_text_padding: f32 = 4.0;
pub const chart_bar_count: usize = 5;
const chart_radius: f32 = 8.0;
const chart_padding: f32 = 8.0;
const chart_label_h: f32 = 14.0;
const chart_label_gap: f32 = 4.0;
const chart_bar_gap: f32 = 5.0;
const chart_bar_radius: f32 = 5.0;
const combobox_input_h: f32 = 36.0;
const combobox_popup_gap: f32 = 6.0;
const combobox_popup_radius: f32 = 8.0;
const combobox_popup_padding: f32 = 4.0;
const combobox_icon_size: f32 = 14.0;
const combobox_icon_space: f32 = 22.0;
const combobox_option_padding: f32 = 8.0;
const combobox_option_indicator_w: f32 = 28.0;
const menubar_padding: f32 = 4.0;
const menubar_first_w: f32 = 48.0;
const menubar_second_w: f32 = 48.0;
const menubar_third_w: f32 = 48.0;
const menubar_item_padding_x: f32 = 8.0;
const menubar_third_label = "View";
const navigation_menu_gap: f32 = 4.0;
const navigation_menu_item_h: f32 = 36.0;
const navigation_menu_first_w: f32 = 62.0;
const navigation_menu_second_w: f32 = 112.0;
const navigation_menu_third_w: f32 = 56.0;
const navigation_menu_text_padding: f32 = 10.0;
const navigation_menu_icon_size: f32 = 12.0;
const navigation_menu_icon_space: f32 = 16.0;
const navigation_menu_icon_padding: f32 = 8.0;
const navigation_menu_third_label = "Blocks";
const command_radius: f32 = 8.0;
const command_input_h: f32 = 36.0;
const command_icon_x: f32 = 8.0;
const command_icon_size: f32 = 14.0;
const command_text_x: f32 = 28.0;
const command_padding_x: f32 = 8.0;
const command_text_h: f32 = 13.0;
pub const command_item_id_offset: u32 = 1;
const command_list_gap: f32 = 6.0;
const command_list_padding: f32 = 4.0;
const command_item_h: f32 = 24.0;
const command_item_pitch: f32 = 28.0;
const command_item_padding_x: f32 = 8.0;
const command_item_detail_w: f32 = 72.0;
const command_max_visible_items: usize = 3;
const command_empty_label = "No commands found";
const command_empty_text_h: f32 = 14.0;
const field_label_h: f32 = 14.0;
const field_gap: f32 = 6.0;
const field_input_h: f32 = 36.0;
const field_validation_gap: f32 = 6.0;
const field_validation_h: f32 = 12.0;
const input_otp_slot_size: f32 = 36.0;
const input_otp_slot_gap: f32 = 0.0;
const input_otp_text_padding: f32 = 8.0;
const toggle_group_side_w: f32 = 48.0;
const toggle_group_middle_w: f32 = 64.0;
const toggle_group_third_label = "Right";
const table_radius: f32 = 6.0;
const table_padding_x: f32 = 8.0;
const table_header_h: f32 = 24.0;
const table_header_y: f32 = 5.0;
const table_header_text_h: f32 = 14.0;
const table_body_y: f32 = 35.0;
const table_body_text_h: f32 = 14.0;
const table_name_column_ratio: f32 = 0.55;
const table_row_inset: f32 = 4.0;
const table_row_radius: f32 = 4.0;
const table_header_name = "Name";
const table_header_role = "Role";
const table_header_name_asc = "Name ^";
const table_header_name_desc = "Name v";
const table_header_role_asc = "Role ^";
const table_header_role_desc = "Role v";
const empty_radius: f32 = 8.0;
const empty_padding: f32 = 24.0;
const empty_media_size: f32 = 40.0;
const empty_media_icon_inset: f32 = 8.0;
const empty_gap: f32 = 10.0;
const empty_title_height: f32 = 20.0;
const empty_detail_gap: f32 = 4.0;
const empty_detail_height: f32 = 16.0;
const empty_detail_average_w: f32 = 7.5;
const empty_detail_max_lines: usize = 2;
const row_radius: f32 = tokens.Component.row_radius;
const control_text_padding: f32 = tokens.Component.control_text_padding;
const control_label_height: f32 = tokens.Component.control_label_height;
const control_average_char_width: f32 = tokens.Component.control_average_char_width;
const input_icon_size: f32 = 16.0;
const input_icon_gap: f32 = 8.0;
const input_group_addon_min_w: f32 = 42.0;
const input_group_addon_max_w: f32 = 96.0;
const input_group_addon_padding: f32 = 10.0;
const input_group_control_gap: f32 = 8.0;
const input_group_separator_inset: f32 = 8.0;

pub fn inputPreferredSize(size: common.ControlSize) ui.Size {
    return switch (size) {
        .small => .{ .w = 180.0, .h = 32.0 },
        .default => preferred_input,
        .large => .{ .w = 260.0, .h = 48.0 },
    };
}

fn inputPadding(size: common.ControlSize) f32 {
    return switch (size) {
        .small => 10.0,
        .default => control_text_padding,
        .large => 16.0,
    };
}
const textarea_padding: f32 = 12.0;
const textarea_max_lines: usize = 4;
const select_arrow_w: f32 = 18.0;
const select_icon_size: f32 = 14.0;
const checkbox_box_size: f32 = 18.0;
const checkbox_icon_inset: f32 = 3.0;
const checkbox_text_gap: f32 = 10.0;
const radio_dot_size: f32 = 8.0;
const radio_option_h: f32 = 20.0;
const radio_option_pitch: f32 = 26.0;
const switch_width: f32 = 42.0;
const switch_height: f32 = 24.0;
const switch_knob_size: f32 = 18.0;
const switch_knob_inset: f32 = 3.0;
const pagination_item_count: usize = 5;
const pagination_item_w: f32 = 36.0;
const pagination_item_h: f32 = 36.0;
const pagination_gap: f32 = 4.0;
const pagination_text_padding: f32 = 2.0;
const popover_trigger_y: f32 = 6.0;
const popover_trigger_w: f32 = 64.0;
const popover_trigger_h: f32 = 30.0;
const popover_gap: f32 = 10.0;
const popover_radius: f32 = 8.0;
const popover_padding: f32 = 10.0;
const hover_card_trigger_y: f32 = 6.0;
const hover_card_trigger_w: f32 = 66.0;
const hover_card_trigger_h: f32 = 30.0;
const hover_card_gap: f32 = 10.0;
const hover_card_radius: f32 = 8.0;
const hover_card_padding: f32 = 10.0;
const hover_card_title_y: f32 = 8.0;
const hover_card_title_h: f32 = 14.0;
const hover_card_detail_y: f32 = 25.0;
const hover_card_detail_h: f32 = 12.0;
const hover_card_detail_label = "Hover content";
const dialog_trigger_y: f32 = 6.0;
const dialog_trigger_w: f32 = 66.0;
const dialog_trigger_h: f32 = 30.0;
const dialog_gap: f32 = 12.0;
const dialog_radius: f32 = 10.0;
const dialog_padding: f32 = 10.0;
const dialog_title_y: f32 = 6.0;
const dialog_title_h: f32 = 14.0;
const dialog_detail_y: f32 = 22.0;
const dialog_detail_h: f32 = 12.0;
const dialog_trigger_padding: f32 = 8.0;
const dialog_open_label = "Open";
const dialog_delete_label = "Delete";
const direction_ltr_label = "LTR";
const direction_rtl_label = "RTL";
const direction_item_y: f32 = 8.0;
const direction_item_w: f32 = 42.0;
const direction_item_h: f32 = 20.0;
const direction_item_radius: f32 = 6.0;
const direction_item_padding: f32 = 5.0;
const direction_item_text_h: f32 = 12.0;
const direction_icon_x: f32 = 54.0;
const direction_icon_y: f32 = 11.0;
const direction_icon_size: f32 = 18.0;
const direction_second_x: f32 = 84.0;
const overlay_open_label = "Open";
const overlay_title_h: f32 = 14.0;
const overlay_detail_h: f32 = 12.0;
const drawer_trigger_y: f32 = 4.0;
const drawer_trigger_w: f32 = 62.0;
const drawer_trigger_h: f32 = 30.0;
const drawer_trigger_padding: f32 = 8.0;
const drawer_content_y: f32 = 38.0;
const drawer_content_inset_x: f32 = 10.0;
const drawer_radius: f32 = 10.0;
const drawer_padding: f32 = 12.0;
const drawer_handle_w: f32 = 58.0;
const drawer_handle_h: f32 = 4.0;
const drawer_handle_y: f32 = 5.0;
const drawer_handle_radius: f32 = 2.0;
const drawer_title_y: f32 = 14.0;
const drawer_detail_y: f32 = 31.0;
const sheet_trigger_y: f32 = 4.0;
const sheet_trigger_w: f32 = 62.0;
const sheet_trigger_h: f32 = 30.0;
const sheet_trigger_padding: f32 = 8.0;
const sheet_content_w: f32 = 96.0;
const sheet_content_min_left: f32 = 82.0;
const sheet_radius: f32 = 8.0;
const sheet_padding: f32 = 10.0;
const sheet_title_y: f32 = 10.0;
const sheet_detail_y: f32 = 29.0;
const sheet_close_size: f32 = 12.0;
const sheet_close_inset: f32 = 8.0;
const sheet_close_space: f32 = 18.0;
pub const dropdown_menu_trigger = "Open";
pub const context_menu_trigger = "Context";
const menu_trigger_y: f32 = 4.0;
const menu_trigger_w: f32 = 64.0;
const menu_trigger_h: f32 = 30.0;
const menu_gap: f32 = 8.0;
const menu_radius: f32 = 8.0;
const menu_padding: f32 = 5.0;
const menu_item_h: f32 = 14.0;
const menu_item_pitch: f32 = 16.0;
const menu_item_radius: f32 = 4.0;
const menu_item_padding: f32 = 5.0;
const menu_item_text_h: f32 = 12.0;
const menu_trigger_padding: f32 = 8.0;
const tabs_list_w: f32 = 184.0;
const tabs_list_h: f32 = 36.0;
const tabs_list_padding: f32 = 3.0;
const tabs_list_radius: f32 = 8.0;
const tabs_gap: f32 = 8.0;
const tabs_panel_padding: f32 = 10.0;
const tooltip_trigger_y: f32 = 8.0;
const tooltip_trigger_w: f32 = 80.0;
const tooltip_trigger_h: f32 = 28.0;
const tooltip_gap: f32 = 10.0;
const tooltip_content_y: f32 = 7.0;
const tooltip_content_h: f32 = 24.0;
const tooltip_radius: f32 = 6.0;
const tooltip_padding: f32 = 8.0;
const tooltip_text_h: f32 = 12.0;
const toast_h: f32 = 52.0;
const toast_radius: f32 = 8.0;
const toast_padding: f32 = 10.0;
const toast_icon_x: f32 = 12.0;
const toast_icon_size: f32 = 16.0;
const toast_text_x: f32 = 38.0;
const toast_title_y: f32 = 10.0;
const toast_title_h: f32 = 14.0;
const toast_detail_y: f32 = 27.0;
const toast_detail_h: f32 = 12.0;
const sidebar_rail_w: f32 = 62.0;
const sidebar_content_gap: f32 = 10.0;
const sidebar_radius: f32 = 8.0;
const sidebar_trigger_x: f32 = 8.0;
const sidebar_trigger_y: f32 = 8.0;
const sidebar_trigger_size: f32 = 16.0;
const sidebar_title_y: f32 = 10.0;
const sidebar_title_h: f32 = 12.0;
const sidebar_item_x: f32 = 6.0;
const sidebar_item_y: f32 = 34.0;
const sidebar_item_h: f32 = 20.0;
const sidebar_item_radius: f32 = 4.0;
const sidebar_item_padding: f32 = 5.0;
const sidebar_item_text_h: f32 = 12.0;
const separator_height: f32 = 1.0;
const scroll_area_radius: f32 = 7.0;
const scroll_area_padding: f32 = 8.0;
const scroll_area_content_y: f32 = 6.0;
const scroll_area_text_h: f32 = 14.0;
const scroll_area_scrollbar_w: f32 = 10.0;
const scroll_area_track_inset_x: f32 = 6.0;
const scroll_area_track_inset_y: f32 = 5.0;
const scroll_area_track_w: f32 = 3.0;
const scroll_area_track_radius: f32 = 2.0;
const scroll_area_thumb_min_h: f32 = 12.0;
const scroll_area_thumb_ratio: f32 = 0.45;
const scroll_area_label = "Scrollable content";
const breadcrumb_first_w: f32 = 44.0;
const breadcrumb_middle_w: f32 = 42.0;
const breadcrumb_separator_w: f32 = 18.0;
const breadcrumb_icon_size: f32 = 12.0;
const breadcrumb_icon_inset: f32 = 3.0;
const breadcrumb_middle_label = "Docs";
const toggle_text_padding: f32 = 8.0;
const row_text_padding_x: f32 = 12.0;
const row_title_offset_y: f32 = 8.0;
const row_detail_offset_y: f32 = 26.0;
const row_title_height: f32 = 18.0;
const row_detail_height: f32 = 16.0;
const calendar_weekday_labels = [_][]const u8{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" };
const calendar_day_labels = [_][]const u8{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28" };
const chart_bar_values = [_]f32{ 0.45, 0.72, 0.38, 0.86, 0.62 };
