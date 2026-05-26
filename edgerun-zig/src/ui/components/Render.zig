const std = @import("std");
const common = @import("../../ui_component_common.zig");
const icon = @import("../../icon.zig");
const layout = @import("../../layouts/Types.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const ui = @import("../../ui.zig");
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

fn renderCalendarNav(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, ui.Color.clear, .fill, control_radius, 0.0);
    try renderControlText(scene, bounds, calendar_nav_text_padding, calendar_day_text_h, label, options.style.muted, .center);
}

fn renderCalendarDay(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (selected) options.style.accent else ui.Color.clear, .fill, control_radius, 0.0);
    try renderControlText(scene, bounds, calendar_day_text_padding, calendar_day_text_h, label, if (selected) options.style.bg else options.style.text, .center);
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

pub const preferred_calendar = ui.Size{ .w = 240.0, .h = 152.0 };
pub const preferred_combobox = ui.Size{ .w = 240.0, .h = 82.0 };
pub const preferred_scroll_area = ui.Size{ .w = 220.0, .h = 48.0 };
pub const preferred_command = ui.Size{ .w = 220.0, .h = 36.0 };
pub const preferred_command_palette = ui.Size{ .w = 260.0, .h = 130.0 };
pub const preferred_field = ui.Size{ .w = 220.0, .h = 56.0 };
pub const preferred_field_with_validation = ui.Size{ .w = 220.0, .h = 74.0 };
pub const preferred_input = ui.Size{ .w = 220.0, .h = 40.0 };
pub const preferred_table = ui.Size{ .w = 260.0, .h = 64.0 };
const min_extent: f32 = 1.0;
const measure_max_width: f32 = 4096.0;
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
const combobox_input_h: f32 = 36.0;
const combobox_popup_gap: f32 = 6.0;
const combobox_popup_radius: f32 = 8.0;
const combobox_popup_padding: f32 = 4.0;
const combobox_icon_size: f32 = 14.0;
const combobox_icon_space: f32 = 22.0;
const combobox_option_padding: f32 = 8.0;
const combobox_option_indicator_w: f32 = 28.0;
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
const control_text_padding: f32 = tokens.Component.control_text_padding;
const control_label_height: f32 = tokens.Component.control_label_height;
const control_average_char_width: f32 = tokens.Component.control_average_char_width;
const input_icon_size: f32 = 16.0;
const input_icon_gap: f32 = 8.0;
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
const calendar_weekday_labels = [_][]const u8{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" };
const calendar_day_labels = [_][]const u8{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28" };
