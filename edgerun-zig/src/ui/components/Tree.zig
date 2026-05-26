const common = @import("../../ui_component_common.zig");
const component_io = @import("ComponentIO.zig");
const object = @import("../../object.zig");
const slot_component = @import("Slot.zig");
const stack_component = @import("Stack.zig");
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
            try component_io.validateTreeView(tree);
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
