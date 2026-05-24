const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const ui = @import("../../ui.zig");
const base_surface = @import("base/Surface.zig");

const RenderOptions = common.RenderOptions;

const max_children: usize = 64;
const region_padding_x: f32 = 12.0;
const region_padding_y: f32 = 12.0;
const region_child_gap: f32 = 10.0;
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

pub fn measureRegion(comptime Component: type, region: anytype, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    const measured_children = measureChildren(Component, region.children, regionChildConstraints(constraints), options, &child_measurements);
    return layouts.Flex.measure(measured_children, constraints, regionLayoutOptions());
}

pub fn renderRegion(comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, region: anytype, options: RenderOptions) ui.RenderError!void {
    if (region.children.len == 0) return;
    if (region.children.len > max_children) return error.CommandBudgetExceeded;
    if (region.tag == .header or region.tag == .footer) {
        try base_surface.renderFrame(scene, bounds, options);
    }

    const constraints = constraintsFromBounds(bounds);
    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    var child_bounds: [max_children]ui.Rect = undefined;
    const measured_children = measureChildren(Component, region.children, regionChildConstraints(constraints), options, &child_measurements);
    const placed_children = layouts.Flex.place(bounds, measured_children, regionLayoutOptions(), &child_bounds);
    for (region.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidBounds;
        try renderComponent(Component, scene, child_rect, child, options);
    }
}

pub fn collectRegionInteractions(comptime Component: type, collector: *interaction.Collector, bounds: ui.Rect, region: anytype, options: RenderOptions) interaction.Error!void {
    if (region.children.len == 0) return;
    if (region.children.len > max_children) return error.InteractionBudgetExceeded;

    const constraints = constraintsFromBounds(bounds);
    var child_measurements: [max_children]layouts.types.Measurement = undefined;
    var child_bounds: [max_children]ui.Rect = undefined;
    const measured_children = measureChildren(Component, region.children, regionChildConstraints(constraints), options, &child_measurements);
    const placed_children = layouts.Flex.place(bounds, measured_children, regionLayoutOptions(), &child_bounds);
    for (region.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidInteractionBounds;
        try collectComponentInteractions(Component, collector, child_rect, child);
    }
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

pub fn renderSurface(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    return base_surface.render(scene, bounds, .{ .title = title, .detail = detail }, options);
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

fn regionChildConstraints(constraints: layouts.types.Constraints) layouts.types.Constraints {
    const inner = constraints.inner(regionInsets());
    return .{ .width = inner.width, .height = .unconstrained, .text_wrap = constraints.text_wrap };
}

fn stackLayoutOptions(stack: anytype) layouts.Flex.Options {
    return .{
        .axis = layoutAxis(stack.axis),
        .gap = @floatFromInt(stack.gap),
        .padding = layouts.types.Insets.uniform(@floatFromInt(stack.padding)),
        .cross_align = .stretch,
    };
}

fn regionLayoutOptions() layouts.Flex.Options {
    return .{
        .axis = .vertical,
        .gap = region_child_gap,
        .padding = regionInsets(),
        .cross_align = .stretch,
    };
}

fn regionInsets() layouts.types.Insets {
    return .{ .top = region_padding_y, .right = region_padding_x, .bottom = region_padding_y, .left = region_padding_x };
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
