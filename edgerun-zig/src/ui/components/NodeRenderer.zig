const layouts = @import("../../layouts.zig");
const common = @import("../../ui_component_common.zig");
const primitives = @import("Primitives.zig");
const stack_component = @import("Stack.zig");
const Text = @import("Text.zig").Text;
const ui = @import("../../ui.zig");

const RenderOptions = common.RenderOptions;

pub fn renderNode(comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, node: ui.Node, options: RenderOptions) ui.RenderError!void {
    if (!bounds.valid()) return error.InvalidBounds;
    switch (node) {
        .rect => |rect| try scene.pushRect(bounds, rect.color, .fill, 0.0, 0.0),
        .text => |text| {
            var component_options = options;
            if (text.color) |color| component_options.style.text = color;
            try (Text{ .value = text.value }).render(scene, bounds, component_options);
        },
        .slot => |slot| try renderNode(Component, scene, bounds, slot.child.*, options),
        .stack => |stack| try renderNodeStack(Component, scene, bounds, stack, options),
        else => {
            const component = Component.fromNode(node) catch return error.UnsupportedComponent;
            try component.render(scene, bounds, options);
        },
    }
}

pub fn measureNode(comptime Component: type, node: ui.Node, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return switch (node) {
        .rect, .text => primitiveNodeMeasurement(node, constraints),
        .slot => |slot| measureNode(Component, slot.child.*, constraints, options),
        .stack => |stack| measureNodeStack(Component, stack, constraints, options),
        else => if (Component.fromNode(node)) |component|
            component.measure(constraints, options)
        else |_|
            primitiveNodeMeasurement(node, constraints),
    };
}

fn renderNodeStack(comptime Component: type, scene: *ui.Scene, bounds: ui.Rect, stack: ui.Layout, options: RenderOptions) ui.RenderError!void {
    if (stack.children.len == 0) return;
    if (stack.children.len > node_stack_max_children) return error.CommandBudgetExceeded;

    var child_measurements: [node_stack_max_children]layouts.types.Measurement = undefined;
    var child_bounds: [node_stack_max_children]ui.Rect = undefined;
    const placed_children = placeNodeStackChildren(Component, bounds, stack, options, &child_measurements, &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidBounds;
        try renderNode(Component, scene, child_rect, child, options);
    }
}

fn measureNodeStack(comptime Component: type, stack: ui.Layout, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    var child_measurements: [node_stack_max_children]layouts.types.Measurement = undefined;
    const child_constraints = stack_component.stackChildConstraintsFor(stack.axis, stack.padding, constraints);
    const measured_children = measureNodeChildren(Component, stack.children, child_constraints, options, &child_measurements);
    return layouts.Flex.measure(measured_children, constraints, nodeStackLayoutOptionsFor(stack));
}

fn placeNodeStackChildren(comptime Component: type, bounds: ui.Rect, stack: ui.Layout, options: RenderOptions, measurements: *[node_stack_max_children]layouts.types.Measurement, out: *[node_stack_max_children]ui.Rect) []ui.Rect {
    const constraints = stack_component.constraintsFromBounds(bounds);
    const child_constraints = stack_component.stackChildConstraintsFor(stack.axis, stack.padding, constraints);
    const measured_children = measureNodeChildren(Component, stack.children, child_constraints, options, measurements);
    return layouts.Flex.place(bounds, measured_children, nodeStackLayoutOptionsFor(stack), out);
}

fn measureNodeChildren(comptime Component: type, children: []const ui.Node, constraints: layouts.types.Constraints, options: RenderOptions, out: []layouts.types.Measurement) []layouts.types.Measurement {
    const count = @min(children.len, @min(out.len, node_stack_max_children));
    for (children[0..count], 0..) |child, index| {
        out[index] = measureNode(Component, child, constraints, options);
    }
    return out[0..count];
}

fn nodeStackLayoutOptionsFor(stack: ui.Layout) layouts.Flex.Options {
    return stack_component.stackLayoutOptionsFor(stack.axis, stack.gap, stack.padding, nodeStackCrossAlign(stack.cross_align));
}

pub fn nodeStackCrossAlign(value: ui.Align) layouts.Flex.Align {
    return switch (value) {
        .start => .start,
        .center, .end => .start,
        .stretch => .stretch,
    };
}

fn primitiveNodeMeasurement(node: ui.Node, constraints: layouts.types.Constraints) layouts.types.Measurement {
    const size = node.preferredSize();
    const preferred = primitives.constrainPreferredSize(size, constraints);
    return layouts.types.Measurement.flexible(
        .{ .w = @min(size.w, preferred.w), .h = @min(size.h, preferred.h) },
        preferred,
        .{ .w = primitives.measure_max_width, .h = size.h },
    ).applyExact(constraints);
}

const node_stack_max_children: usize = 64;
