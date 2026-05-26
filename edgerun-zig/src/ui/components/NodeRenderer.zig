const layouts = @import("../../layouts.zig");
const common = @import("../../ui_component_common.zig");
const component_union = @import("Component.zig");
const primitives = @import("Primitives.zig");
const stack_component = @import("Stack.zig");
const std = @import("std");
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

const TestComponent = component_union.Component;

test "primitive node measurement respects at-most constraints" {
    const node = ui.inputNode(1, "Filter");
    const measured = measureNode(TestComponent, node, .{ .width = .{ .at_most = 96.0 }, .height = .{ .at_most = 28.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 96.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 28.0), measured.preferred.h);
}

test "node stack layout keeps existing cross alignment policy" {
    try std.testing.expectEqual(layouts.Flex.Align.start, nodeStackCrossAlign(.start));
    try std.testing.expectEqual(layouts.Flex.Align.start, nodeStackCrossAlign(.center));
    try std.testing.expectEqual(layouts.Flex.Align.start, nodeStackCrossAlign(.end));
    try std.testing.expectEqual(layouts.Flex.Align.stretch, nodeStackCrossAlign(.stretch));
}

test "primitive node rendering uses scene command helpers" {
    var commands: [4]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try std.testing.expect(try scene.pushClip(ui.Rect.init(0, 0, 40, 40)));

    try renderNode(TestComponent, &scene, ui.Rect.init(30, 30, 20, 20), .{ .rect = .{ .color = .accent } }, .{});
    var text_node = (Text{ .value = "node" }).node();
    text_node.text.color = .muted;
    try renderNode(TestComponent, &scene, ui.Rect.init(2, 4, 20, 12), text_node, .{});

    try std.testing.expectEqual(ui.Rect.init(30, 30, 10, 10), scene.commandAt(0).?.rect.bounds);
    try std.testing.expectEqual(ui.Rect.init(2, 4, 20, 12), scene.commandAt(1).?.text.origin);
    try std.testing.expectEqual(ui.Color.muted, scene.commandAt(1).?.text.color);
}

test "raw node text uses responsive wrapped renderer" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderNode(TestComponent, &scene, ui.Rect.init(0, 0, 72, 54), (Text{ .value = "Runtime text wraps cleanly" }).node(), .{});

    try std.testing.expect(scene.written().len > 1);
    for (scene.written()) |command| {
        try std.testing.expect(command.text.origin.w <= 72);
    }
}
