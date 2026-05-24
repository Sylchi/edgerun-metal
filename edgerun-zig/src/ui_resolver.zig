const std = @import("std");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");
const store = @import("store.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");

pub const Error = error{
    Corrupt,
    MissingObject,
    NoSpace,
    ResolutionBudgetExceeded,
    UnsupportedComponent,
    ComponentBudgetExceeded,
    ChildMismatch,
};

pub fn storeTreeObjects(target: *store.Store, owner: identity.Id, objects: components.TreeObjects) Error![store.hash_size]u8 {
    if (!owner.valid()) return error.Corrupt;
    _ = target.putObject(owner, objects.layout) orelse return error.NoSpace;
    return target.putObject(owner, objects.tree) orelse return error.NoSpace;
}

pub fn resolveStackTree(source: store.Store, owner: identity.Id, tree: object.View, resolved: []object.View, out_components: []components.Component) Error!components.Stack {
    const resolved_children = try resolveTreeChildren(source, owner, tree, resolved, null);

    return components.StackTree.fromTree(tree, resolved_children, out_components) catch |err| switch (err) {
        error.Corrupt => error.Corrupt,
        error.UnsupportedComponent => error.UnsupportedComponent,
        error.ComponentBudgetExceeded => error.ComponentBudgetExceeded,
        error.ChildMismatch => error.ChildMismatch,
    };
}

pub fn resolveSlotTree(source: store.Store, owner: identity.Id, tree: object.View, resolved: []object.View) Error!components.Slot {
    const resolved_children = try resolveTreeChildren(source, owner, tree, resolved, 2);

    return components.SlotTree.fromTree(tree, resolved_children) catch |err| switch (err) {
        error.Corrupt => error.Corrupt,
        error.UnsupportedComponent => error.UnsupportedComponent,
        error.ComponentBudgetExceeded => error.ComponentBudgetExceeded,
        error.ChildMismatch => error.ChildMismatch,
    };
}

pub fn resolveTree(source: store.Store, owner: identity.Id, tree: object.View, resolved: []object.View, out_components: []components.Component) Error!components.Tree {
    const resolved_children = try resolveTreeChildren(source, owner, tree, resolved, null);

    return components.Tree.fromTree(tree, resolved_children, out_components) catch |err| switch (err) {
        error.Corrupt => error.Corrupt,
        error.UnsupportedComponent => error.UnsupportedComponent,
        error.ComponentBudgetExceeded => error.ComponentBudgetExceeded,
        error.ChildMismatch => error.ChildMismatch,
    };
}

fn resolveTreeChildren(source: store.Store, owner: identity.Id, tree: object.View, resolved: []object.View, expected_count: ?usize) Error![]const object.View {
    if (!owner.valid() or tree.header.kind != .tree) return error.Corrupt;
    const child_count = std.math.cast(usize, tree.header.child_count) orelse return error.Corrupt;
    if (expected_count) |expected| {
        if (child_count != expected) return error.Corrupt;
    }
    if (child_count > resolved.len) return error.ResolutionBudgetExceeded;

    var index: usize = 0;
    while (index < child_count) : (index += 1) {
        const child = tree.childAt(index) catch return error.Corrupt;
        resolved[index] = source.getObject(owner, child.object_id) orelse return error.MissingObject;
    }
    return resolved[0..child_count];
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

fn testApp() identity.Identity {
    return identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ui")).?, testEpoch()).?;
}

test "resolver hydrates stack tree children from store" {
    var data: [4096]u8 = undefined;
    var slots: [8]store.Blob = undefined;
    var source = store.Store.init(.{ .base = &data }, &slots);
    const app = testApp();

    var text_ui: [128]u8 = undefined;
    var text_object_raw: [object.header_size + 128]u8 = undefined;
    const text_object = (components.Text{ .value = "Stored" }).toObject(&text_ui, &text_object_raw, testReq(), testEpoch()).?;
    const text_id = source.putObject(app.id, text_object).?;

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (components.Button{ .id = 8, .label = "Load" }).toObject(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_id = source.putObject(app.id, button_object).?;

    const child_views = [_]object.View{
        source.getObject(app.id, text_id).?,
        source.getObject(app.id, button_id).?,
    };
    const tree_builder = components.StackTree{ .axis = .column, .gap = 4, .padding = 6, .children = &child_views };

    var layout_raw: [object.header_size + 16]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 3]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;
    const tree_id = try storeTreeObjects(&source, app.id, tree_objects);
    const tree_view = source.getObject(app.id, tree_id).?;

    var resolved: [3]object.View = undefined;
    var out_components: [2]components.Component = undefined;
    const stack = try resolveStackTree(source, app.id, tree_view, &resolved, &out_components);

    try std.testing.expectEqual(@as(u16, 4), stack.gap);
    try std.testing.expectEqual(@as(u16, 6), stack.padding);
    try std.testing.expectEqualStrings("Stored", stack.children[0].text.value);
    try std.testing.expectEqual(@as(u32, 8), stack.children[1].button.id);

    var nodes: [2]ui.Node = undefined;
    const root = stack.node(&nodes).?;
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 240, .h = 160 }, .{});
    try std.testing.expect(scene.commandCount() != 0);
}

test "resolver rejects unresolved tree children" {
    var data: [1024]u8 = undefined;
    var slots: [4]store.Blob = undefined;
    var source = store.Store.init(.{ .base = &data }, &slots);
    const app = testApp();

    var text_ui: [128]u8 = undefined;
    var text_object_raw: [object.header_size + 128]u8 = undefined;
    const text_object = (components.Text{ .value = "Only child" }).toObject(&text_ui, &text_object_raw, testReq(), testEpoch()).?;
    const text_view = try object.View.decode(text_object);
    const tree_builder = components.StackTree{ .axis = .column, .children = &.{text_view} };

    var layout_raw: [object.header_size + 16]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;
    const tree_id = try storeTreeObjects(&source, app.id, tree_objects);
    const tree_view = source.getObject(app.id, tree_id).?;

    var resolved: [2]object.View = undefined;
    var out_components: [1]components.Component = undefined;
    try std.testing.expectError(error.MissingObject, resolveStackTree(source, app.id, tree_view, &resolved, &out_components));
}

test "resolver hydrates slot tree child from store" {
    var data: [2048]u8 = undefined;
    var slots: [6]store.Blob = undefined;
    var source = store.Store.init(.{ .base = &data }, &slots);
    const app = testApp();

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (components.Button{ .id = 12, .label = "Slot" }).toObject(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_id = source.putObject(app.id, button_object).?;
    const button_view = source.getObject(app.id, button_id).?;

    var layout_raw: [object.header_size + 16]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (components.SlotTree{ .id = 77, .child = button_view }).toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;
    const tree_id = try storeTreeObjects(&source, app.id, tree_objects);
    const tree_view = source.getObject(app.id, tree_id).?;

    var resolved: [2]object.View = undefined;
    const slot = try resolveSlotTree(source, app.id, tree_view, &resolved);
    try std.testing.expectEqual(@as(u32, 77), slot.id);
    try std.testing.expectEqual(@as(u32, 12), slot.child.button.id);

    var nodes: [1]ui.Node = undefined;
    const root = slot.node(&nodes).?;
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 120, .h = 40 }, .{});
    try std.testing.expect(hasText(scene.written(), "Slot"));
}

test "generic resolver detects stored tree layout type" {
    var data: [2048]u8 = undefined;
    var slots: [6]store.Blob = undefined;
    var source = store.Store.init(.{ .base = &data }, &slots);
    const app = testApp();

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (components.Button{ .id = 31, .label = "Generic" }).toObject(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_id = source.putObject(app.id, button_object).?;
    const button_view = source.getObject(app.id, button_id).?;

    var layout_raw: [object.header_size + 16]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (components.SlotTree{ .id = 17, .child = button_view }).toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;
    const tree_id = try storeTreeObjects(&source, app.id, tree_objects);
    const tree_view = source.getObject(app.id, tree_id).?;

    var resolved: [2]object.View = undefined;
    var out_components: [1]components.Component = undefined;
    const tree = try resolveTree(source, app.id, tree_view, &resolved, &out_components);
    try std.testing.expectEqual(@as(u32, 17), tree.slot.id);
    try std.testing.expectEqual(@as(u32, 31), tree.slot.child.button.id);

    var nodes: [1]ui.Node = undefined;
    const root = tree.node(&nodes).?;
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 120, .h = 40 }, .{});
    try std.testing.expect(scene.commandCount() != 0);
}

test "tree object storage helper rejects insufficient storage" {
    var data: [object.header_size + 32]u8 = undefined;
    var slots: [1]store.Blob = undefined;
    var source = store.Store.init(.{ .base = &data }, &slots);
    const app = testApp();

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (components.Button{ .id = 1, .label = "x" }).toObject(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var layout_raw: [object.header_size + 16]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (components.SlotTree{ .id = 1, .child = button_view }).toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;

    try std.testing.expectError(error.NoSpace, storeTreeObjects(&source, app.id, tree_objects));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}
