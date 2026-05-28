const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const codec = @import("../../ui_codec.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_union = @import("Component.zig");
const interaction = @import("../../ui_interaction.zig");
const layout_types = @import("../../layouts/Types.zig");
const object = @import("../../object.zig");
const std = @import("std");
const tree_codec = @import("TreeCodec.zig");
const ui = @import("../../ui.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub fn Slot(comptime Component: type) type {
    return struct {
        id: u32,
        child: Component,

        const Self = @This();

        pub fn node(self: Self, out_nodes: []ui.Node) ?ui.Node {
            if (out_nodes.len < 1) return null;
            out_nodes[0] = self.child.node();
            return .{ .slot = .{ .id = self.id, .child = &out_nodes[0] } };
        }

        pub fn measure(self: Self, constraints: layout_types.Constraints, options: RenderOptions) layout_types.Measurement {
            return self.child.measure(constraints, options);
        }

        pub fn render(self: Self, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
            return self.child.render(scene, bounds, options);
        }

        pub fn collectInteractions(self: Self, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) interaction.Error!void {
            _ = options;
            return self.child.collectInteractions(collector, bounds);
        }

        pub fn collectAccessibility(self: Self, tree: *common.AccessibilityTree, bounds: ui.Rect, options: RenderOptions) common.AccessibilityError!void {
            return self.child.collectAccessibility(tree, bounds, options);
        }

        pub fn toObject(self: Self, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
            var writer = codec.Writer.init(ui_out, 2, 1, .column, 0, 0) orelse return null;
            if (!writer.record(0, .slot, self.id, .{ .offset = 1, .len = 0 }, .{})) return null;
            if (!component_codec.writeRecord(Component, &writer, 1, self.child)) return null;
            return writer.objectNode(object_out, component_codec.requirements(), epoch);
        }

        pub fn fromView(view: object.View) Error!Self {
            try component_codec.validateView(view);
            var nodes: [2]ui.Node = undefined;
            const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
            return switch (root) {
                .stack => |stack| {
                    if (stack.children.len != 1) return error.Corrupt;
                    return switch (stack.children[0]) {
                        .slot => |slot| .{
                            .id = slot.id,
                            .child = try Component.fromNode(slot.child.*),
                        },
                        else => error.UnsupportedComponent,
                    };
                },
                else => error.UnsupportedComponent,
            };
        }
    };
}

const TestComponent = component_union.Component;
const TestSlot = Slot(TestComponent);
const TestSlotTree = SlotTree(TestComponent);

test "slot component wraps a leaf component and renders the child" {
    const slot = TestSlot{
        .id = 99,
        .child = .{ .button = .{ .id = 12, .label = "Inside" } },
    };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = slot.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try TestSlot.fromView(try object.View.decode(canonical));
    try std.testing.expectEqual(@as(u32, 99), decoded.id);
    try std.testing.expectEqual(@as(u32, 12), decoded.child.button.id);

    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try decoded.render(&scene, .{ .x = 0, .y = 0, .w = 140, .h = 40 }, .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Inside"));
}

test "slot component rejects non-slot object roots" {
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;
    const canonical = (TestComponent{ .button = .{ .id = 12, .label = "Plain" } }).toObject(&ui_raw, &object_raw, component_test.epoch()).?;

    try std.testing.expectError(error.UnsupportedComponent, TestSlot.fromView(try object.View.decode(canonical)));
}

test "slot tree composes one child component object" {
    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (TestComponent{ .button = .{ .id = 3, .label = "Slot child" } }).toObject(&button_ui, &button_object_raw, component_test.epoch()).?;
    const button_view = try object.View.decode(button_object);

    var layout_raw: [object.header_size + tree_codec.slot_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (TestSlotTree{ .id = 44, .child = button_view }).toTreeObjects(&layout_raw, &tree_raw, component_test.epoch()).?;

    const resolved = [_]object.View{
        try object.View.decode(tree_objects.layout),
        button_view,
    };
    const slot = try TestSlotTree.fromTree(try object.View.decode(tree_objects.tree), &resolved);
    try std.testing.expectEqual(@as(u32, 44), slot.id);
    try std.testing.expectEqual(@as(u32, 3), slot.child.button.id);
}

pub fn SlotTree(comptime Component: type) type {
    return struct {
        id: u32,
        child: object.View,

        const Self = @This();
        const SlotType = Slot(Component);

        pub fn toTreeObjects(self: Self, layout_out: []u8, tree_out: []u8, epoch: clock.Stamp) ?tree_codec.TreeObjects {
            var layout_body: [tree_codec.slot_layout_size]u8 = undefined;
            tree_codec.encodeSlotLayout(self.id, &layout_body) orelse return null;
            const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(component_codec.requirements(), epoch, &layout_body) catch return null;

            var children: [2]object.Child = undefined;
            const layout_view = object.View.decode(layout) catch return null;
            component_codec.validateView(self.child) catch return null;
            children[0] = tree_codec.childRecord(layout_view, 0) catch return null;
            children[1] = tree_codec.childRecord(self.child, children[0].logical_len) catch return null;

            const tree = (object.NodeWriter{ .out = tree_out }).treeNode(component_codec.requirements(), epoch, &children) catch return null;
            return .{ .layout = layout, .tree = tree };
        }

        pub fn fromTree(tree: object.View, resolved_children: []const object.View) Error!SlotType {
            try component_codec.validateTreeView(tree);
            if (tree.header.kind != .tree or tree.header.child_count != 2) return error.Corrupt;
            if (resolved_children.len != 2) return error.ChildMismatch;

            const descriptor_child = tree.childAt(0) catch return error.Corrupt;
            if (!tree_codec.sameId(descriptor_child.object_id, resolved_children[0].id())) return error.ChildMismatch;
            const slot_id = tree_codec.decodeSlotLayout(resolved_children[0]) catch return error.Corrupt;

            const child_record = tree.childAt(1) catch return error.Corrupt;
            if (!tree_codec.sameId(child_record.object_id, resolved_children[1].id())) return error.ChildMismatch;

            return .{
                .id = slot_id,
                .child = try Component.fromView(resolved_children[1]),
            };
        }
    };
}
