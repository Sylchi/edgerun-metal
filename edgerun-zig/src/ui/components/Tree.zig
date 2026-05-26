const common = @import("../../ui_component_common.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_union = @import("Component.zig");
const object = @import("../../object.zig");
const slot_component = @import("Slot.zig");
const stack_component = @import("Stack.zig");
const std = @import("std");
const tree_codec = @import("TreeCodec.zig");
const ui = @import("../../ui.zig");

const Error = common.Error;

pub fn Tree(comptime Component: type) type {
    return union(enum) {
        stack: stack_component.Stack(Component),
        slot: slot_component.Slot(Component),

        const Self = @This();
        const StackTree = stack_component.StackTree(Component);
        const SlotTree = slot_component.SlotTree(Component);

        pub fn node(self: Self, out_nodes: []ui.Node) ?ui.Node {
            return switch (self) {
                .stack => |stack| stack.node(out_nodes),
                .slot => |slot| slot.node(out_nodes),
            };
        }

        pub fn fromTree(tree: object.View, resolved_children: []const object.View, out_components: []Component) Error!Self {
            try component_codec.validateTreeView(tree);
            if (tree.header.kind != .tree or resolved_children.len == 0) return error.Corrupt;
            if (tree_codec.isTreeLayout(resolved_children[0])) {
                return .{ .stack = try StackTree.fromTree(tree, resolved_children, out_components) };
            }
            if (tree_codec.isSlotLayout(resolved_children[0])) {
                return .{ .slot = try SlotTree.fromTree(tree, resolved_children) };
            }
            return error.UnsupportedComponent;
        }
    };
}

pub const TreeObjects = tree_codec.TreeObjects;

const TestComponent = component_union.Component;
const TestStackTree = stack_component.StackTree(TestComponent);
const TestSlotTree = slot_component.SlotTree(TestComponent);
const TestTree = Tree(TestComponent);

test "tree union detects stack and slot descriptors" {
    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (TestComponent{ .button = .{ .id = 10, .label = "Child" } }).toObject(&button_ui, &button_object_raw, component_test.epoch()).?;
    const button_view = try object.View.decode(button_object);

    var stack_layout_raw: [object.header_size + tree_codec.tree_layout_size]u8 = undefined;
    var stack_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const stack_objects = (TestStackTree{ .axis = .column, .children = &.{button_view} }).toTreeObjects(&stack_layout_raw, &stack_tree_raw, component_test.epoch()).?;
    const stack_resolved = [_]object.View{ try object.View.decode(stack_objects.layout), button_view };
    var stack_components: [1]TestComponent = undefined;
    const stack_tree = try TestTree.fromTree(try object.View.decode(stack_objects.tree), &stack_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 10), stack_tree.stack.children[0].button.id);

    var slot_layout_raw: [object.header_size + tree_codec.slot_layout_size]u8 = undefined;
    var slot_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const slot_objects = (TestSlotTree{ .id = 88, .child = button_view }).toTreeObjects(&slot_layout_raw, &slot_tree_raw, component_test.epoch()).?;
    const slot_resolved = [_]object.View{ try object.View.decode(slot_objects.layout), button_view };
    const slot_tree = try TestTree.fromTree(try object.View.decode(slot_objects.tree), &slot_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 88), slot_tree.slot.id);
    try std.testing.expectEqual(@as(u32, 10), slot_tree.slot.child.button.id);
}

test "tree union rejects non component tree objects and descriptors" {
    var child_ui: [128]u8 = undefined;
    var child_object_raw: [object.header_size + 128]u8 = undefined;
    const child_object = (TestComponent{ .button = .{ .id = 5, .label = "Child" } }).toObject(&child_ui, &child_object_raw, component_test.epoch()).?;
    const child_view = try object.View.decode(child_object);

    var layout_body: [tree_codec.tree_layout_size]u8 = undefined;
    tree_codec.encodeTreeLayout(.column, 8, 0, 1, &layout_body).?;

    var bad_req = component_codec.requirements();
    bad_req.visibility = .private;
    var bad_layout_raw: [object.header_size + tree_codec.tree_layout_size]u8 = undefined;
    const bad_layout = try (object.NodeWriter{ .out = &bad_layout_raw }).bytesNode(bad_req, component_test.epoch(), &layout_body);
    const bad_layout_view = try object.View.decode(bad_layout);

    var children: [2]object.Child = undefined;
    children[0] = try object.Child.fromView(bad_layout_view, 0);
    children[1] = try object.Child.fromView(child_view, children[0].logical_len);

    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree = try (object.NodeWriter{ .out = &tree_raw }).treeNode(component_codec.requirements(), component_test.epoch(), &children);
    var components: [1]TestComponent = undefined;
    try std.testing.expectError(error.UnsupportedComponent, TestTree.fromTree(try object.View.decode(tree), &.{ bad_layout_view, child_view }, &components));

    var wrong_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const wrong_tree = try (object.NodeWriter{ .out = &wrong_tree_raw }).treeNode(bad_req, component_test.epoch(), &children);
    try std.testing.expectError(error.Corrupt, TestTree.fromTree(try object.View.decode(wrong_tree), &.{ bad_layout_view, child_view }, &components));
}
