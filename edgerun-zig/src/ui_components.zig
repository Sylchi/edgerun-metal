const std = @import("std");
const clock = @import("clock.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");
const codec = @import("ui_codec.zig");

const tree_layout_magic = "ERUL001\x00";
const tree_layout_size = 16;
const slot_layout_magic = "ERUS001\x00";
const slot_layout_size = 16;

pub const Error = error{
    Corrupt,
    UnsupportedComponent,
    ComponentBudgetExceeded,
    ChildMismatch,
};

pub const Component = union(enum) {
    text: Text,
    button: Button,
    input: Input,
    row_item: RowItem,

    pub fn node(self: Component) ui.Node {
        return switch (self) {
            .text => |component| component.node(),
            .button => |component| component.node(),
            .input => |component| component.node(),
            .row_item => |component| component.node(),
        };
    }

    pub fn objectNode(self: Component, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return switch (self) {
            .text => |component| component.objectNode(ui_out, object_out, req, epoch),
            .button => |component| component.objectNode(ui_out, object_out, req, epoch),
            .input => |component| component.objectNode(ui_out, object_out, req, epoch),
            .row_item => |component| component.objectNode(ui_out, object_out, req, epoch),
        };
    }

    pub fn fromView(view: object.View) Error!Component {
        var nodes: [1]ui.Node = undefined;
        const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
        if (root.stack.children.len != 1) return error.Corrupt;
        return fromNode(root.stack.children[0]);
    }

    pub fn fromNode(node_value: ui.Node) Error!Component {
        return switch (node_value) {
            .text => |text| .{ .text = .{ .value = text.value } },
            .button => |button| .{ .button = .{ .id = button.id, .label = button.label } },
            .input => |input| .{ .input = .{ .id = input.id, .placeholder = input.placeholder } },
            .row_item => |row| .{ .row_item = .{ .id = row.id, .title = row.title, .detail = row.detail } },
            else => error.UnsupportedComponent,
        };
    }
};

pub const Tree = union(enum) {
    stack: Stack,
    slot: Slot,

    pub fn node(self: Tree, out_nodes: []ui.Node) ?ui.Node {
        return switch (self) {
            .stack => |stack| stack.node(out_nodes),
            .slot => |slot| slot.node(out_nodes),
        };
    }

    pub fn fromTree(tree: object.View, resolved_children: []const object.View, out_components: []Component) Error!Tree {
        if (tree.header.kind != .tree or resolved_children.len == 0) return error.Corrupt;
        if (isTreeLayout(resolved_children[0])) {
            return .{ .stack = try StackTree.fromTree(tree, resolved_children, out_components) };
        }
        if (isSlotLayout(resolved_children[0])) {
            return .{ .slot = try SlotTree.fromTree(tree, resolved_children) };
        }
        return error.UnsupportedComponent;
    }
};

pub const TreeObjects = struct {
    layout: []const u8,
    tree: []const u8,
};

pub const Text = struct {
    value: []const u8,

    pub fn node(self: Text) ui.Node {
        return .{ .text = .{ .value = self.value } };
    }

    pub fn objectNode(self: Text, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        const value = writer.string(self.value) orelse return null;
        if (!writer.record(0, .text, 0, value, .{})) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Text {
        var nodes: [1]ui.Node = undefined;
        const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
        if (root.stack.children.len != 1) return error.Corrupt;
        return switch (root.stack.children[0]) {
            .text => |text| .{ .value = text.value },
            else => error.UnsupportedComponent,
        };
    }
};

pub const Button = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Button) ui.Node {
        return .{ .button = .{ .id = self.id, .label = self.label } };
    }

    pub fn objectNode(self: Button, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        const label = writer.string(self.label) orelse return null;
        if (!writer.record(0, .button, self.id, label, .{})) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Button {
        var nodes: [1]ui.Node = undefined;
        const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
        if (root.stack.children.len != 1) return error.Corrupt;
        return switch (root.stack.children[0]) {
            .button => |button| .{ .id = button.id, .label = button.label },
            else => error.UnsupportedComponent,
        };
    }
};

pub const Input = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Input) ui.Node {
        return .{ .input = .{ .id = self.id, .placeholder = self.placeholder } };
    }

    pub fn objectNode(self: Input, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        const placeholder = writer.string(self.placeholder) orelse return null;
        if (!writer.record(0, .input, self.id, placeholder, .{})) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Input {
        var nodes: [1]ui.Node = undefined;
        const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
        if (root.stack.children.len != 1) return error.Corrupt;
        return switch (root.stack.children[0]) {
            .input => |input| .{ .id = input.id, .placeholder = input.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

pub const RowItem = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: RowItem) ui.Node {
        return .{ .row_item = .{ .id = self.id, .title = self.title, .detail = self.detail } };
    }

    pub fn objectNode(self: RowItem, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        const title = writer.string(self.title) orelse return null;
        const detail = writer.string(self.detail) orelse return null;
        if (!writer.record(0, .row_item, self.id, title, detail)) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!RowItem {
        var nodes: [1]ui.Node = undefined;
        const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
        if (root.stack.children.len != 1) return error.Corrupt;
        return switch (root.stack.children[0]) {
            .row_item => |row| .{ .id = row.id, .title = row.title, .detail = row.detail },
            else => error.UnsupportedComponent,
        };
    }
};

pub const Stack = struct {
    axis: ui.Axis,
    gap: u16 = 8,
    padding: u16 = 0,
    children: []const Component,

    pub fn node(self: Stack, out_nodes: []ui.Node) ?ui.Node {
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

    pub fn objectNode(self: Stack, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        if (self.children.len == 0 or self.children.len > std.math.maxInt(u16)) return null;
        var writer = codec.Writer.init(ui_out, @intCast(self.children.len), @intCast(self.children.len), self.axis, self.gap, self.padding) orelse return null;
        for (self.children, 0..) |child, index| {
            if (!writeComponentRecord(&writer, index, child)) return null;
        }
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn fromView(view: object.View, out_components: []Component) Error!Stack {
        var nodes: [codec_max_stack_children]ui.Node = undefined;
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

pub const StackTree = struct {
    axis: ui.Axis,
    gap: u16 = 8,
    padding: u16 = 0,
    children: []const object.View,

    pub fn objectTree(self: StackTree, layout_out: []u8, tree_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?TreeObjects {
        if (self.children.len == 0 or self.children.len + 1 > object.max_children) return null;

        var layout_body: [tree_layout_size]u8 = undefined;
        encodeTreeLayout(self.axis, self.gap, self.padding, @intCast(self.children.len), &layout_body) orelse return null;
        const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(req, epoch, &layout_body) orelse return null;

        var child_records: [tree_max_children]object.Child = undefined;
        if (self.children.len + 1 > child_records.len) return null;

        child_records[0] = childRecord(layout, 0);
        var logical_offset = child_records[0].logical_len;
        for (self.children, 0..) |child, index| {
            child_records[index + 1] = childRecord(child.canonical, logical_offset);
            logical_offset += child_records[index + 1].logical_len;
        }

        const tree = (object.NodeWriter{ .out = tree_out }).treeNode(req, epoch, child_records[0 .. self.children.len + 1]) orelse return null;
        return .{ .layout = layout, .tree = tree };
    }

    pub fn fromTree(tree: object.View, resolved_children: []const object.View, out_components: []Component) Error!Stack {
        if (tree.header.kind != .tree or tree.header.child_count == 0) return error.Corrupt;
        if (resolved_children.len != tree.header.child_count) return error.ChildMismatch;

        const descriptor_child = tree.childAt(0) catch return error.Corrupt;
        if (!sameId(descriptor_child.object_id, resolved_children[0].id())) return error.ChildMismatch;
        const descriptor = decodeTreeLayout(resolved_children[0]) catch return error.Corrupt;
        if (descriptor.child_count + 1 != resolved_children.len) return error.ChildMismatch;
        if (descriptor.child_count > out_components.len) return error.ComponentBudgetExceeded;

        var index: usize = 0;
        while (index < descriptor.child_count) : (index += 1) {
            const child_record = tree.childAt(index + 1) catch return error.Corrupt;
            const child_view = resolved_children[index + 1];
            if (!sameId(child_record.object_id, child_view.id())) return error.ChildMismatch;
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

const tree_max_children = 64;

const TreeLayout = struct {
    axis: ui.Axis,
    gap: u16,
    padding: u16,
    child_count: usize,
};

pub const Slot = struct {
    id: u32,
    child: Component,

    pub fn node(self: Slot, out_nodes: []ui.Node) ?ui.Node {
        if (out_nodes.len < 1) return null;
        out_nodes[0] = self.child.node();
        return .{ .slot = .{ .id = self.id, .child = &out_nodes[0] } };
    }

    pub fn objectNode(self: Slot, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = codec.Writer.init(ui_out, 2, 1, .column, 0, 0) orelse return null;
        if (!writer.record(0, .slot, self.id, .{ .offset = 1, .len = 0 }, .{})) return null;
        if (!writeComponentRecord(&writer, 1, self.child)) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Slot {
        var nodes: [2]ui.Node = undefined;
        const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
        if (root.stack.children.len != 1) return error.Corrupt;
        return switch (root.stack.children[0]) {
            .slot => |slot| .{
                .id = slot.id,
                .child = try Component.fromNode(slot.child.*),
            },
            else => error.UnsupportedComponent,
        };
    }
};

pub const SlotTree = struct {
    id: u32,
    child: object.View,

    pub fn objectTree(self: SlotTree, layout_out: []u8, tree_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?TreeObjects {
        var layout_body: [slot_layout_size]u8 = undefined;
        encodeSlotLayout(self.id, &layout_body) orelse return null;
        const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(req, epoch, &layout_body) orelse return null;

        var children: [2]object.Child = undefined;
        children[0] = childRecord(layout, 0);
        children[1] = childRecord(self.child.canonical, children[0].logical_len);

        const tree = (object.NodeWriter{ .out = tree_out }).treeNode(req, epoch, &children) orelse return null;
        return .{ .layout = layout, .tree = tree };
    }

    pub fn fromTree(tree: object.View, resolved_children: []const object.View) Error!Slot {
        if (tree.header.kind != .tree or tree.header.child_count != 2) return error.Corrupt;
        if (resolved_children.len != 2) return error.ChildMismatch;

        const descriptor_child = tree.childAt(0) catch return error.Corrupt;
        if (!sameId(descriptor_child.object_id, resolved_children[0].id())) return error.ChildMismatch;
        const slot_id = decodeSlotLayout(resolved_children[0]) catch return error.Corrupt;

        const child_record = tree.childAt(1) catch return error.Corrupt;
        if (!sameId(child_record.object_id, resolved_children[1].id())) return error.ChildMismatch;

        return .{
            .id = slot_id,
            .child = try Component.fromView(resolved_children[1]),
        };
    }
};

const codec_max_stack_children = 64;

fn encodeTreeLayout(axis: ui.Axis, gap: u16, padding: u16, child_count: u16, out: []u8) ?void {
    if (out.len < tree_layout_size) return null;
    @memset(out[0..tree_layout_size], 0);
    @memcpy(out[0..tree_layout_magic.len], tree_layout_magic);
    out[8] = switch (axis) {
        .column => 0,
        .row => 1,
    };
    out[9] = 0;
    out[10] = @truncate(gap);
    out[11] = @truncate(gap >> 8);
    out[12] = @truncate(padding);
    out[13] = @truncate(padding >> 8);
    out[14] = @truncate(child_count);
    out[15] = @truncate(child_count >> 8);
}

fn decodeTreeLayout(view: object.View) Error!TreeLayout {
    if (view.header.kind != .bytes or view.body.len != tree_layout_size) return error.Corrupt;
    if (!std.mem.eql(u8, view.body[0..tree_layout_magic.len], tree_layout_magic)) return error.Corrupt;
    if (view.body[9] != 0) return error.Corrupt;
    return .{
        .axis = switch (view.body[8]) {
            0 => .column,
            1 => .row,
            else => return error.Corrupt,
        },
        .gap = @as(u16, view.body[10]) | (@as(u16, view.body[11]) << 8),
        .padding = @as(u16, view.body[12]) | (@as(u16, view.body[13]) << 8),
        .child_count = @as(u16, view.body[14]) | (@as(u16, view.body[15]) << 8),
    };
}

fn isTreeLayout(view: object.View) bool {
    return view.header.kind == .bytes and
        view.body.len == tree_layout_size and
        std.mem.eql(u8, view.body[0..tree_layout_magic.len], tree_layout_magic);
}

fn encodeSlotLayout(id: u32, out: []u8) ?void {
    if (out.len < slot_layout_size) return null;
    @memset(out[0..slot_layout_size], 0);
    @memcpy(out[0..slot_layout_magic.len], slot_layout_magic);
    out[8] = @truncate(id);
    out[9] = @truncate(id >> 8);
    out[10] = @truncate(id >> 16);
    out[11] = @truncate(id >> 24);
}

fn decodeSlotLayout(view: object.View) Error!u32 {
    if (view.header.kind != .bytes or view.body.len != slot_layout_size) return error.Corrupt;
    if (!std.mem.eql(u8, view.body[0..slot_layout_magic.len], slot_layout_magic)) return error.Corrupt;
    return @as(u32, view.body[8]) |
        (@as(u32, view.body[9]) << 8) |
        (@as(u32, view.body[10]) << 16) |
        (@as(u32, view.body[11]) << 24);
}

fn isSlotLayout(view: object.View) bool {
    return view.header.kind == .bytes and
        view.body.len == slot_layout_size and
        std.mem.eql(u8, view.body[0..slot_layout_magic.len], slot_layout_magic);
}

fn childRecord(canonical: []const u8, offset: u64) object.Child {
    const view = object.View.decode(canonical) catch unreachable;
    const logical_len = if (view.header.logical_len == 0) 1 else view.header.logical_len;
    return .{
        .object_id = view.id(),
        .logical_offset = offset,
        .logical_len = logical_len,
        .kind = view.header.kind,
        .requirements_hash = view.header.requirements.hash(),
    };
}

fn sameId(left: [object.id_size]u8, right: [object.id_size]u8) bool {
    return std.mem.eql(u8, &left, &right);
}

fn writeComponentRecord(writer: *codec.Writer, index: usize, component: Component) bool {
    return switch (component) {
        .text => |text| blk: {
            const value = writer.string(text.value) orelse break :blk false;
            break :blk writer.record(index, .text, 0, value, .{});
        },
        .button => |button| blk: {
            const label = writer.string(button.label) orelse break :blk false;
            break :blk writer.record(index, .button, button.id, label, .{});
        },
        .input => |input| blk: {
            const placeholder = writer.string(input.placeholder) orelse break :blk false;
            break :blk writer.record(index, .input, input.id, placeholder, .{});
        },
        .row_item => |row| blk: {
            const title = writer.string(row.title) orelse break :blk false;
            const detail = writer.string(row.detail) orelse break :blk false;
            break :blk writer.record(index, .row_item, row.id, title, detail);
        },
    };
}

fn testReq() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .public,
        .access = .hot_memory_allowed,
    };
}

fn testEpoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
}

test "button component serializes to canonical object and deserializes" {
    const button = Button{ .id = 7, .label = "Run" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.objectNode(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const view = try object.View.decode(canonical);
    const decoded = try Button.fromView(view);

    try std.testing.expectEqual(@as(u32, 7), decoded.id);
    try std.testing.expectEqualStrings("Run", decoded.label);
}

test "component deserializer rejects wrong component kind" {
    const text = Text{ .value = "not a button" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.objectNode(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectError(error.UnsupportedComponent, Button.fromView(view));
}

test "input and row item components roundtrip through objects" {
    var input_ui: [128]u8 = undefined;
    var input_object: [object.header_size + 128]u8 = undefined;
    const input_canonical = (Input{ .id = 9, .placeholder = "Search" }).objectNode(&input_ui, &input_object, testReq(), testEpoch()).?;
    const input = try Input.fromView(try object.View.decode(input_canonical));
    try std.testing.expectEqual(@as(u32, 9), input.id);
    try std.testing.expectEqualStrings("Search", input.placeholder);

    var row_ui: [128]u8 = undefined;
    var row_object: [object.header_size + 128]u8 = undefined;
    const row_canonical = (RowItem{ .id = 11, .title = "Object", .detail = "Canonical" }).objectNode(&row_ui, &row_object, testReq(), testEpoch()).?;
    const row = try RowItem.fromView(try object.View.decode(row_canonical));
    try std.testing.expectEqual(@as(u32, 11), row.id);
    try std.testing.expectEqualStrings("Object", row.title);
    try std.testing.expectEqualStrings("Canonical", row.detail);
}

test "component union roundtrips concrete component objects" {
    const component = Component{ .button = .{ .id = 14, .label = "Commit" } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.objectNode(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const decoded = try Component.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(@as(u32, 14), decoded.button.id);
    try std.testing.expectEqualStrings("Commit", decoded.button.label);
}

test "stack component serializes leaf composition to canonical object" {
    const children = [_]Component{
        .{ .text = .{ .value = "Title" } },
        .{ .input = .{ .id = 1, .placeholder = "Filter" } },
        .{ .button = .{ .id = 2, .label = "Apply" } },
    };
    const stack = Stack{ .axis = .column, .gap = 10, .padding = 16, .children = &children };
    var ui_raw: [256]u8 = undefined;
    var object_raw: [object.header_size + 256]u8 = undefined;

    const canonical = stack.objectNode(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const view = try object.View.decode(canonical);

    var decoded_children: [3]Component = undefined;
    const decoded = try Stack.fromView(view, &decoded_children);
    try std.testing.expectEqual(ui.Axis.column, decoded.axis);
    try std.testing.expectEqual(@as(u16, 10), decoded.gap);
    try std.testing.expectEqual(@as(u16, 16), decoded.padding);
    try std.testing.expectEqual(@as(usize, 3), decoded.children.len);
    try std.testing.expectEqualStrings("Title", decoded.children[0].text.value);
    try std.testing.expectEqual(@as(u32, 1), decoded.children[1].input.id);
    try std.testing.expectEqualStrings("Apply", decoded.children[2].button.label);
}

test "stack component produces renderable ui node" {
    const children = [_]Component{
        .{ .row_item = .{ .id = 5, .title = "Object", .detail = "Ready" } },
        .{ .button = .{ .id = 6, .label = "Open" } },
    };
    const stack = Stack{ .axis = .column, .gap = 8, .padding = 12, .children = &children };
    var nodes: [2]ui.Node = undefined;
    const root = stack.node(&nodes).?;

    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 240, .h = 160 }, .{});

    try std.testing.expect(ui.hitTest(scene.written(), 20, 70) != null);
}

test "slot component wraps a leaf component and preserves structural hit id" {
    const slot = Slot{
        .id = 99,
        .child = .{ .button = .{ .id = 12, .label = "Inside" } },
    };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = slot.objectNode(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const decoded = try Slot.fromView(try object.View.decode(canonical));
    try std.testing.expectEqual(@as(u32, 99), decoded.id);
    try std.testing.expectEqual(@as(u32, 12), decoded.child.button.id);

    var nodes: [1]ui.Node = undefined;
    const root = decoded.node(&nodes).?;
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 140, .h = 40 }, .{});

    const hit = ui.hitTest(scene.written(), 4, 4).?;
    try std.testing.expectEqual(@as(u32, 99), hit.slot);
    try std.testing.expectEqual(@as(u32, 12), hit.id);
}

test "stack tree composes child component objects with explicit resolver input" {
    var title_ui: [128]u8 = undefined;
    var title_object_raw: [object.header_size + 128]u8 = undefined;
    const title_object = (Text{ .value = "Tree" }).objectNode(&title_ui, &title_object_raw, testReq(), testEpoch()).?;

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 77, .label = "Open" }).objectNode(&button_ui, &button_object_raw, testReq(), testEpoch()).?;

    const child_views = [_]object.View{
        try object.View.decode(title_object),
        try object.View.decode(button_object),
    };
    const tree_builder = StackTree{ .axis = .column, .gap = 6, .padding = 10, .children = &child_views };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 3]u8 = undefined;
    const tree_objects = tree_builder.objectTree(&layout_raw, &tree_raw, testReq(), testEpoch()).?;
    const tree_view = try object.View.decode(tree_objects.tree);
    const layout_view = try object.View.decode(tree_objects.layout);

    const resolved = [_]object.View{ layout_view, child_views[0], child_views[1] };
    var components: [2]Component = undefined;
    const stack = try StackTree.fromTree(tree_view, &resolved, &components);

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
    const left_object = (Text{ .value = "Left" }).objectNode(&left_ui, &left_object_raw, testReq(), testEpoch()).?;

    var right_ui: [128]u8 = undefined;
    var right_object_raw: [object.header_size + 128]u8 = undefined;
    const right_object = (Button{ .id = 1, .label = "Right" }).objectNode(&right_ui, &right_object_raw, testReq(), testEpoch()).?;

    const tree_children = [_]object.View{try object.View.decode(left_object)};
    const tree_builder = StackTree{ .axis = .column, .children = &tree_children };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = tree_builder.objectTree(&layout_raw, &tree_raw, testReq(), testEpoch()).?;

    const resolved = [_]object.View{
        try object.View.decode(tree_objects.layout),
        try object.View.decode(right_object),
    };
    var components: [1]Component = undefined;
    try std.testing.expectError(error.ChildMismatch, StackTree.fromTree(try object.View.decode(tree_objects.tree), &resolved, &components));
}

test "slot tree composes one child component object" {
    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 3, .label = "Slot child" }).objectNode(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (SlotTree{ .id = 44, .child = button_view }).objectTree(&layout_raw, &tree_raw, testReq(), testEpoch()).?;

    const resolved = [_]object.View{
        try object.View.decode(tree_objects.layout),
        button_view,
    };
    const slot = try SlotTree.fromTree(try object.View.decode(tree_objects.tree), &resolved);
    try std.testing.expectEqual(@as(u32, 44), slot.id);
    try std.testing.expectEqual(@as(u32, 3), slot.child.button.id);
}

test "tree union detects stack and slot descriptors" {
    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 10, .label = "Child" }).objectNode(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var stack_layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var stack_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const stack_objects = (StackTree{ .axis = .column, .children = &.{button_view} }).objectTree(&stack_layout_raw, &stack_tree_raw, testReq(), testEpoch()).?;
    const stack_resolved = [_]object.View{ try object.View.decode(stack_objects.layout), button_view };
    var stack_components: [1]Component = undefined;
    const stack_tree = try Tree.fromTree(try object.View.decode(stack_objects.tree), &stack_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 10), stack_tree.stack.children[0].button.id);

    var slot_layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var slot_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const slot_objects = (SlotTree{ .id = 88, .child = button_view }).objectTree(&slot_layout_raw, &slot_tree_raw, testReq(), testEpoch()).?;
    const slot_resolved = [_]object.View{ try object.View.decode(slot_objects.layout), button_view };
    const slot_tree = try Tree.fromTree(try object.View.decode(slot_objects.tree), &slot_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 88), slot_tree.slot.id);
    try std.testing.expectEqual(@as(u32, 10), slot_tree.slot.child.button.id);
}
