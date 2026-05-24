const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const codec = @import("../../ui_codec.zig");
const component_io = @import("ComponentIO.zig");
const component_render = @import("Render.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const object = @import("../../object.zig");
const std = @import("std");
const tree_codec = @import("TreeCodec.zig");
const ui = @import("../../ui.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const codec_max_children: usize = 64;

pub fn Stack(comptime Component: type) type {
    return struct {
        axis: ui.Axis,
        gap: u16 = 8,
        padding: u16 = 0,
        children: []const Component,

        const Self = @This();

        pub fn measure(self: Self, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
            return component_render.measureStack(Component, self, constraints, options);
        }

        pub fn render(self: Self, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
            return component_render.renderStack(Component, scene, bounds, self, options);
        }

        pub fn collectInteractions(self: Self, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) interaction.Error!void {
            return component_render.collectStackInteractions(Component, collector, bounds, self, options);
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

        pub fn toObject(self: Self, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
            if (self.children.len == 0 or self.children.len > std.math.maxInt(u16)) return null;
            var writer = codec.Writer.init(ui_out, @intCast(self.children.len), @intCast(self.children.len), self.axis, self.gap, self.padding) orelse return null;
            for (self.children, 0..) |child, index| {
                if (!component_io.writeRecord(Component, &writer, index, child)) return null;
            }
            return writer.objectNode(object_out, req, epoch);
        }

        pub fn fromView(view: object.View, out_components: []Component) Error!Self {
            var nodes: [codec_max_children]ui.Node = undefined;
            const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
            if (root != .stack) return error.UnsupportedComponent;
            const layout = root.stack;
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

pub fn StackTree(comptime Component: type) type {
    return struct {
        axis: ui.Axis,
        gap: u16 = 8,
        padding: u16 = 0,
        children: []const object.View,

        const Self = @This();
        const StackType = Stack(Component);

        pub fn toTreeObjects(self: Self, layout_out: []u8, tree_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?tree_codec.TreeObjects {
            if (self.children.len == 0 or self.children.len + 1 > object.max_children) return null;

            var layout_body: [tree_codec.tree_layout_size]u8 = undefined;
            tree_codec.encodeTreeLayout(self.axis, self.gap, self.padding, @intCast(self.children.len), &layout_body) orelse return null;
            const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(req, epoch, &layout_body) catch return null;

            var child_records: [tree_codec.tree_max_children]object.Child = undefined;
            if (self.children.len + 1 > child_records.len) return null;

            child_records[0] = tree_codec.childRecord(layout, 0);
            var logical_offset = child_records[0].logical_len;
            for (self.children, 0..) |child, index| {
                child_records[index + 1] = tree_codec.childRecord(child.canonical, logical_offset);
                logical_offset += child_records[index + 1].logical_len;
            }

            const tree = (object.NodeWriter{ .out = tree_out }).treeNode(req, epoch, child_records[0 .. self.children.len + 1]) catch return null;
            return .{ .layout = layout, .tree = tree };
        }

        pub fn fromTree(tree: object.View, resolved_children: []const object.View, out_components: []Component) Error!StackType {
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
