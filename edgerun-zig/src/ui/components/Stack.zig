const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const codec = @import("../../ui_codec.zig");
const component_io = @import("ComponentIO.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const object = @import("../../object.zig");
const std = @import("std");
const tree_codec = @import("TreeCodec.zig");
const ui = @import("../../ui.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const codec_max_children: usize = 64;
const max_children: usize = codec_max_children;

pub fn Stack(comptime Component: type) type {
    return struct {
        axis: ui.Axis,
        gap: u16 = 8,
        padding: u16 = 0,
        children: []const Component,

        const Self = @This();

        pub fn measure(self: Self, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
            return measureStack(Component, self, constraints, options);
        }

        pub fn render(self: Self, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
            return renderStack(Component, scene, bounds, self, options);
        }

        pub fn collectInteractions(self: Self, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) interaction.Error!void {
            return collectStackInteractions(Component, collector, bounds, self, options);
        }

        pub fn collectAccessibility(self: Self, tree: *common.AccessibilityTree, bounds: ui.Rect, options: RenderOptions) common.AccessibilityError!void {
            return collectStackAccessibility(Component, tree, bounds, self, options);
        }

        pub fn node(self: Self, out_nodes: []ui.Node) ?ui.Node {
            if (out_nodes.len < self.children.len) return null;
            for (self.children, 0..) |child, index| {
                out_nodes[index] = child.node();
            }
            return .{
                .stack = .{
                    .axis = self.axis,
                    .gap = @floatFromInt(self.gap),
                    .padding = @floatFromInt(self.padding),
                    .children = out_nodes[0..self.children.len],
                },
            };
        }

        pub fn toObject(self: Self, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
            if (self.children.len == 0 or self.children.len > std.math.maxInt(u16)) return null;
            var writer = codec.Writer.init(ui_out, @intCast(self.children.len), @intCast(self.children.len), self.axis, self.gap, self.padding) orelse return null;
            for (self.children, 0..) |child, index| {
                if (!component_io.writeRecord(Component, &writer, index, child)) return null;
            }
            return writer.objectNode(object_out, component_io.requirements(), epoch);
        }

        pub fn fromView(view: object.View, out_components: []Component) Error!Self {
            try component_io.validateView(view);
            var nodes: [codec_max_children]ui.Node = undefined;
            const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
            const layout = switch (root) {
                .stack => |stack| stack,
                else => return error.UnsupportedComponent,
            };
            if (layout.children.len > out_components.len) return error.ComponentBudgetExceeded;

            for (layout.children, 0..) |child, index| {
                out_components[index] = try Component.fromNode(child);
            }
            return .{
                .axis = layout.axis,
                .gap = @intFromFloat(layout.gap),
                .padding = @intFromFloat(layout.padding),
                .children = out_components[0..layout.children.len],
            };
        }
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
        try child.render(scene, child_rect, options);
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
        try child.collectInteractions(collector, child_rect);
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
        try child.collectAccessibility(tree, child_rect, options);
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
        out[index] = child.measure(constraints, options);
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

pub fn StackTree(comptime Component: type) type {
    return struct {
        axis: ui.Axis,
        gap: u16 = 8,
        padding: u16 = 0,
        children: []const object.View,

        const Self = @This();
        const StackType = Stack(Component);

        pub fn toTreeObjects(self: Self, layout_out: []u8, tree_out: []u8, epoch: clock.Stamp) ?tree_codec.TreeObjects {
            if (self.children.len == 0 or self.children.len + 1 > object.max_children) return null;

            var layout_body: [tree_codec.tree_layout_size]u8 = undefined;
            tree_codec.encodeTreeLayout(self.axis, self.gap, self.padding, @intCast(self.children.len), &layout_body) orelse return null;
            const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(component_io.requirements(), epoch, &layout_body) catch return null;

            var child_records: [tree_codec.tree_max_children]object.Child = undefined;
            if (self.children.len + 1 > child_records.len) return null;

            const layout_view = object.View.decode(layout) catch return null;
            child_records[0] = tree_codec.childRecord(layout_view, 0) catch return null;
            var logical_offset = child_records[0].logical_len;
            for (self.children, 0..) |child, index| {
                component_io.validateView(child) catch return null;
                child_records[index + 1] = tree_codec.childRecord(child, logical_offset) catch return null;
                logical_offset += child_records[index + 1].logical_len;
            }

            const tree = (object.NodeWriter{ .out = tree_out }).treeNode(component_io.requirements(), epoch, child_records[0 .. self.children.len + 1]) catch return null;
            return .{ .layout = layout, .tree = tree };
        }

        pub fn fromTree(tree: object.View, resolved_children: []const object.View, out_components: []Component) Error!StackType {
            try component_io.validateTreeView(tree);
            if (tree.header.kind != .tree or tree.header.child_count == 0) return error.Corrupt;
            if (resolved_children.len != tree.header.child_count) return error.ChildMismatch;

            const descriptor_child = tree.childAt(0) catch return error.Corrupt;
            if (!tree_codec.sameId(descriptor_child.object_id, resolved_children[0].id())) return error.ChildMismatch;
            const descriptor = tree_codec.decodeTreeLayout(resolved_children[0]) catch return error.Corrupt;
            if (descriptor.child_count + 1 != resolved_children.len) return error.ChildMismatch;
            if (descriptor.child_count > out_components.len) return error.ComponentBudgetExceeded;

            var index: usize = 0;
            while (index < descriptor.child_count) : (index += 1) {
                const child_record = tree.childAt(index + 1) catch return error.Corrupt;
                const child_view = resolved_children[index + 1];
                if (!tree_codec.sameId(child_record.object_id, child_view.id())) return error.ChildMismatch;
                out_components[index] = try Component.fromView(child_view);
            }

            return .{
                .axis = descriptor.axis,
                .gap = descriptor.gap,
                .padding = descriptor.padding,
                .children = out_components[0..descriptor.child_count],
            };
        }
    };
}
