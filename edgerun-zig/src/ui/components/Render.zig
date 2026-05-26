const std = @import("std");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const ui = @import("../../ui.zig");
const primitives = @import("Primitives.zig");

const RenderOptions = common.RenderOptions;
const renderControlStateOverlay = primitives.renderControlStateOverlay;

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
    try renderControlStateOverlay(scene, bounds, resolved_options, primitives.control_radius);
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
