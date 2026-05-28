const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const codec = @import("../../ui_codec.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_union = @import("Component.zig");
const ui_input = @import("../../input.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const object = @import("../../object.zig");
const std = @import("std");
const math = @import("../../math.zig");
const Text = @import("Text.zig").Text;
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
            if (self.children.len == 0 or self.children.len > 0xFFFF) return null;
            var writer = codec.Writer.init(ui_out, @intCast(self.children.len), @intCast(self.children.len), self.axis, self.gap, self.padding) orelse return null;
            for (self.children, 0..) |child, index| {
                if (!component_codec.writeRecord(Component, &writer, index, child)) return null;
            }
            return writer.objectNode(object_out, component_codec.requirements(), epoch);
        }

        pub fn fromView(view: object.View, out_components: []Component) Error!Self {
            try component_codec.validateView(view);
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
            const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(component_codec.requirements(), epoch, &layout_body) catch return null;

            var child_records: [tree_codec.tree_max_children]object.Child = undefined;
            if (self.children.len + 1 > child_records.len) return null;

            const layout_view = object.View.decode(layout) catch return null;
            child_records[0] = tree_codec.childRecord(layout_view, 0) catch return null;
            var logical_offset = child_records[0].logical_len;
            for (self.children, 0..) |child, index| {
                component_codec.validateView(child) catch return null;
                child_records[index + 1] = tree_codec.childRecord(child, logical_offset) catch return null;
                logical_offset += child_records[index + 1].logical_len;
            }

            const tree = (object.NodeWriter{ .out = tree_out }).treeNode(component_codec.requirements(), epoch, child_records[0 .. self.children.len + 1]) catch return null;
            return .{ .layout = layout, .tree = tree };
        }

        pub fn fromTree(tree: object.View, resolved_children: []const object.View, out_components: []Component) Error!StackType {
            try component_codec.validateTreeView(tree);
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

const TestComponent = component_union.Component;
const TestStack = Stack(TestComponent);
const TestStackTree = StackTree(TestComponent);

test "stack component serializes leaf composition to canonical object" {
    const children = [_]TestComponent{
        .{ .text = Text{ .value = "Title" } },
        .{ .badge = .{ .label = "Ready" } },
        .{ .input = .{ .id = 1, .placeholder = "Filter" } },
        .{ .checkbox = .{ .id = 3, .label = "Only active", .checked = true } },
        .{ .button = .{ .id = 2, .label = "Apply" } },
    };
    const stack = TestStack{ .axis = .column, .gap = 10, .padding = 16, .children = &children };
    var ui_raw: [256]u8 = undefined;
    var object_raw: [object.header_size + 256]u8 = undefined;

    const canonical = stack.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const view = try object.View.decode(canonical);

    var decoded_children: [5]TestComponent = undefined;
    const decoded = try TestStack.fromView(view, &decoded_children);
    try std.testing.expectEqual(ui.Axis.column, decoded.axis);
    try std.testing.expectEqual(@as(u16, 10), decoded.gap);
    try std.testing.expectEqual(@as(u16, 16), decoded.padding);
    try std.testing.expectEqual(@as(usize, 5), decoded.children.len);
    try std.testing.expectEqualStrings("Title", decoded.children[0].text.value);
    try std.testing.expectEqualStrings("Ready", decoded.children[1].badge.label);
    try std.testing.expectEqual(@as(u32, 1), decoded.children[2].input.id);
    try std.testing.expect(decoded.children[3].checkbox.checked);
    try std.testing.expectEqualStrings("Apply", decoded.children[4].button.label);
}

test "stack measure render and interaction collection use layout placement" {
    const children = [_]TestComponent{
        .{ .text = Text{ .value = "Intro" } },
        .{ .button = .{ .id = 41002, .label = "Continue" } },
    };
    const stack = TestStack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };
    const measured = stack.measure(.{ .width = .{ .exact = 160 }, .text_wrap = .wrap }, .{});
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try std.testing.expectEqual(@as(f32, 160), measured.preferred.w);
    try std.testing.expect(measured.preferred.h > 0);
    try stack.render(&scene, ui.Rect.init(0, 0, 160, measured.preferred.h), .{});
    try stack.collectInteractions(&collector, ui.Rect.init(0, 0, 160, measured.preferred.h), .{});
    const hit = ui_input.hitTest(collector.written(), 16, 40).?;
    try std.testing.expectEqual(@as(u32, 41002), hit.id);
}

test "stack tree composes child component objects with explicit resolver input" {
    var title_ui: [128]u8 = undefined;
    var title_object_raw: [object.header_size + 128]u8 = undefined;
    const title_object = (TestComponent{ .text = .{ .value = "Tree" } }).toObject(&title_ui, &title_object_raw, component_test.epoch()).?;

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (TestComponent{ .button = .{ .id = 77, .label = "Open" } }).toObject(&button_ui, &button_object_raw, component_test.epoch()).?;

    const child_views = [_]object.View{
        try object.View.decode(title_object),
        try object.View.decode(button_object),
    };
    const tree_builder = TestStackTree{ .axis = .column, .gap = 6, .padding = 10, .children = &child_views };

    var layout_raw: [object.header_size + tree_codec.tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 3]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, component_test.epoch()).?;
    const tree_view = try object.View.decode(tree_objects.tree);
    const layout_view = try object.View.decode(tree_objects.layout);

    const resolved = [_]object.View{ layout_view, child_views[0], child_views[1] };
    var components: [2]TestComponent = undefined;
    const stack = try TestStackTree.fromTree(tree_view, &resolved, &components);

    try std.testing.expectEqual(ui.Axis.column, stack.axis);
    try std.testing.expectEqual(@as(u16, 6), stack.gap);
    try std.testing.expectEqual(@as(u16, 10), stack.padding);
    try std.testing.expectEqual(@as(usize, 2), stack.children.len);
    try std.testing.expectEqualStrings("Tree", stack.children[0].text.value);
    try std.testing.expectEqual(@as(u32, 77), stack.children[1].button.id);
}

test "stack tree rejects resolved children that do not match tree records" {
    var left_ui: [128]u8 = undefined;
    var left_object_raw: [object.header_size + 128]u8 = undefined;
    const left_object = (TestComponent{ .text = .{ .value = "Left" } }).toObject(&left_ui, &left_object_raw, component_test.epoch()).?;

    var right_ui: [128]u8 = undefined;
    var right_object_raw: [object.header_size + 128]u8 = undefined;
    const right_object = (TestComponent{ .button = .{ .id = 1, .label = "Right" } }).toObject(&right_ui, &right_object_raw, component_test.epoch()).?;

    const tree_children = [_]object.View{try object.View.decode(left_object)};
    const tree_builder = TestStackTree{ .axis = .column, .children = &tree_children };

    var layout_raw: [object.header_size + tree_codec.tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, component_test.epoch()).?;

    const resolved = [_]object.View{
        try object.View.decode(tree_objects.layout),
        try object.View.decode(right_object),
    };
    var components: [1]TestComponent = undefined;
    try std.testing.expectError(error.ChildMismatch, TestStackTree.fromTree(try object.View.decode(tree_objects.tree), &resolved, &components));
}

test "stack tree writer rejects non component child objects" {
    const component = TestComponent{ .button = .{ .id = 19, .label = "Wrong child" } };
    var req = component_codec.requirements();
    req.visibility = .private;
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;
    var writer = component_codec.Writer.init(&ui_raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(component_codec.writeRecord(TestComponent, &writer, 0, component));
    const child = writer.objectNode(&object_raw, req, component_test.epoch()).?;
    const child_view = try object.View.decode(child);

    var layout_raw: [object.header_size + tree_codec.tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    try std.testing.expect((TestStackTree{ .axis = .column, .children = &.{child_view} }).toTreeObjects(&layout_raw, &tree_raw, component_test.epoch()) == null);
}

test "stack accessibility tree emitter follows layout bounds" {
    const children = [_]TestComponent{
        .{ .text = Text{ .value = "Intro" } },
        .{ .button = .{ .id = 94, .label = "Continue" } },
        .{ .input = .{ .id = 95, .placeholder = "Filter" } },
    };
    const stack = TestStack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };
    var raw_nodes: [4]common.AccessibilityNode = undefined;
    var tree = common.AccessibilityTree.init(&raw_nodes);

    try stack.collectAccessibility(&tree, ui.Rect.init(0, 0, 160, 120), .{});

    try std.testing.expectEqual(@as(usize, 3), tree.written().len);
    try std.testing.expectEqual(common.AccessibilityRole.text, tree.written()[0].metadata.role);
    try std.testing.expectEqualStrings("Intro", tree.written()[0].metadata.label);
    try std.testing.expectEqual(common.AccessibilityRole.button, tree.written()[1].metadata.role);
    try std.testing.expectEqual(@as(u32, 94), tree.written()[1].metadata.control_id.?);
    try std.testing.expect(tree.written()[1].bounds.y > tree.written()[0].bounds.y);
    try std.testing.expectEqual(common.AccessibilityRole.input, tree.written()[2].metadata.role);
    try std.testing.expectEqual(@as(u32, 95), tree.written()[2].metadata.control_id.?);
}

test "stack accessibility tree emitter enforces caller budget" {
    const children = [_]TestComponent{
        .{ .button = .{ .id = 96, .label = "One" } },
        .{ .button = .{ .id = 97, .label = "Two" } },
    };
    const stack = TestStack{ .axis = .column, .children = &children };
    var raw_nodes: [1]common.AccessibilityNode = undefined;
    var tree = common.AccessibilityTree.init(&raw_nodes);

    try std.testing.expectError(error.AccessibilityBudgetExceeded, stack.collectAccessibility(&tree, ui.Rect.init(0, 0, 120, 80), .{}));
}
