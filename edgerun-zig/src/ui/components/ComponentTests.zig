const std = @import("std");
const clock = @import("../../clock.zig");
const icon = @import("../../icon.zig");
const ui_input = @import("../../input.zig");
const interaction = @import("../../ui_interaction.zig");
const layouts = @import("../../layouts.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const ui_tokens = @import("../../ui_tokens.zig");
const component_common = @import("../../ui_component_common.zig");
const component_codec = @import("Codec.zig");
const component_io = @import("ComponentIO.zig");
const component_test = @import("TestSupport.zig");
const component_union = @import("Component.zig");
const node_renderer = @import("NodeRenderer.zig");
const tree_codec = @import("TreeCodec.zig");
const tree_component = @import("Tree.zig");
const stack_component = @import("Stack.zig");
const slot_component = @import("Slot.zig");
const text_component = @import("Text.zig");
const button_component = @import("Button.zig");
const badge_component = @import("Badge.zig");
const card_component = @import("Card.zig");

const Component = component_union.Component;
const IconComponent = component_union.IconComponent;
const Text = text_component.Text;
const Button = button_component.Button;
const Stack = stack_component.Stack(Component);
const StackTree = stack_component.StackTree(Component);
const Slot = slot_component.Slot(Component);
const SlotTree = slot_component.SlotTree(Component);
const Tree = tree_component.Tree(Component);
const AccessibilityNode = component_common.AccessibilityNode;
const AccessibilityTree = component_common.AccessibilityTree;
const RenderOptions = component_common.RenderOptions;
const tree_layout_size = tree_codec.tree_layout_size;
const slot_layout_size = tree_codec.slot_layout_size;

fn renderComponent(scene: *ui.Scene, bounds: ui.Rect, component: Component, options: RenderOptions) ui.RenderError!void {
    return component.render(scene, bounds, options);
}

fn renderNode(scene: *ui.Scene, bounds: ui.Rect, node: ui.Node, options: RenderOptions) ui.RenderError!void {
    return node_renderer.renderNode(Component, scene, bounds, node, options);
}

fn collectComponentInteractions(collector: *interaction.Collector, bounds: ui.Rect, component: Component) interaction.Error!void {
    return component.collectInteractions(collector, bounds);
}

fn accessibility(component: Component) component_common.Accessibility {
    return component.accessibility();
}

fn measureNode(node: ui.Node, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return node_renderer.measureNode(Component, node, constraints, options);
}

fn objectRequirements() object.Requirements {
    return component_io.requirements();
}

fn testReq() object.Requirements {
    return objectRequirements();
}

fn testEpoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
}

test "component deserializer rejects wrong component kind" {
    const text = Text{ .value = "not a button" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectError(error.UnsupportedComponent, Button.fromView(view));
}

test "component union roundtrips concrete component objects" {
    const component = Component{ .icon_button = .{ .id = 14, .label = "Search", .icon = IconComponent.named(.search) } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const decoded = try Component.fromObject(canonical);

    try std.testing.expectEqual(@as(u32, 14), decoded.icon_button.id);
    try std.testing.expectEqualStrings("Search", decoded.icon_button.label);
    try std.testing.expectEqual(icon.Icon.search, decoded.icon_button.icon.value);
}

test "component union decodes only canonical component objects" {
    const component = Component{ .badge = .{ .label = "Object", .variant = .secondary } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expect(std.meta.eql(component_io.requirements(), view.header.requirements));
    try std.testing.expectError(error.Corrupt, Component.fromObject(view.body));
}

test "component union rejects objects without component requirements" {
    const component = Component{ .button = .{ .id = 7, .label = "Wrong req" } };
    var req = testReq();
    req.visibility = .private;
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    var writer = component_codec.Writer.init(&ui_raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(component_io.writeRecord(Component, &writer, 0, component));
    const canonical = writer.objectNode(&object_raw, req, testEpoch()).?;

    try std.testing.expectError(error.Corrupt, Component.fromObject(canonical));
}

test "stack component serializes leaf composition to canonical object" {
    const children = [_]Component{
        .{ .text = .{ .value = "Title" } },
        .{ .badge = .{ .label = "Ready" } },
        .{ .input = .{ .id = 1, .placeholder = "Filter" } },
        .{ .checkbox = .{ .id = 3, .label = "Only active", .checked = true } },
        .{ .button = .{ .id = 2, .label = "Apply" } },
    };
    const stack = Stack{ .axis = .column, .gap = 10, .padding = 16, .children = &children };
    var ui_raw: [256]u8 = undefined;
    var object_raw: [object.header_size + 256]u8 = undefined;

    const canonical = stack.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const view = try object.View.decode(canonical);

    var decoded_children: [5]Component = undefined;
    const decoded = try Stack.fromView(view, &decoded_children);
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
    const children = [_]Component{
        .{ .text = .{ .value = "Intro" } },
        .{ .button = .{ .id = 41002, .label = "Continue" } },
    };
    const stack = Stack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };
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

test "primitive node measurement respects at-most constraints" {
    const node = ui.inputNode(1, "Filter");
    const measured = measureNode(node, .{ .width = .{ .at_most = 96.0 }, .height = .{ .at_most = 28.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 96.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 28.0), measured.preferred.h);
}

test "node stack layout keeps existing cross alignment policy" {
    try std.testing.expectEqual(layouts.Flex.Align.start, node_renderer.nodeStackCrossAlign(.start));
    try std.testing.expectEqual(layouts.Flex.Align.start, node_renderer.nodeStackCrossAlign(.center));
    try std.testing.expectEqual(layouts.Flex.Align.start, node_renderer.nodeStackCrossAlign(.end));
    try std.testing.expectEqual(layouts.Flex.Align.stretch, node_renderer.nodeStackCrossAlign(.stretch));
}

test "primitive node rendering uses scene command helpers" {
    var commands: [4]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try std.testing.expect(try scene.pushClip(ui.Rect.init(0, 0, 40, 40)));

    try renderNode(&scene, ui.Rect.init(30, 30, 20, 20), .{ .rect = .{ .color = .accent } }, .{});
    try renderNode(&scene, ui.Rect.init(2, 4, 20, 12), .{ .text = .{ .value = "node", .color = .muted } }, .{});

    try std.testing.expectEqual(ui.Rect.init(30, 30, 10, 10), scene.commandAt(0).?.rect.bounds);
    try std.testing.expectEqual(ui.Rect.init(2, 4, 20, 12), scene.commandAt(1).?.text.origin);
    try std.testing.expectEqual(ui.Color.muted, scene.commandAt(1).?.text.color);
}

test "raw node text uses responsive wrapped renderer" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderNode(&scene, ui.Rect.init(0, 0, 72, 54), ui.textNode("Runtime text wraps cleanly", null), .{});

    try std.testing.expect(scene.written().len > 1);
    for (scene.written()) |command| {
        try std.testing.expect(command.text.origin.w <= 72);
    }
}

test "slot component wraps a leaf component and renders the child" {
    const slot = Slot{
        .id = 99,
        .child = .{ .button = .{ .id = 12, .label = "Inside" } },
    };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = slot.toObject(&ui_raw, &object_raw, testEpoch()).?;
    const decoded = try Slot.fromView(try object.View.decode(canonical));
    try std.testing.expectEqual(@as(u32, 99), decoded.id);
    try std.testing.expectEqual(@as(u32, 12), decoded.child.button.id);

    var nodes: [1]ui.Node = undefined;
    const root = decoded.node(&nodes).?;
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderNode(&scene, .{ .x = 0, .y = 0, .w = 140, .h = 40 }, root, .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Inside"));
}

test "slot component rejects non-slot object roots" {
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;
    const canonical = (Button{ .id = 12, .label = "Plain" }).toObject(&ui_raw, &object_raw, testEpoch()).?;

    try std.testing.expectError(error.UnsupportedComponent, Slot.fromView(try object.View.decode(canonical)));
}

test "stack tree composes child component objects with explicit resolver input" {
    var title_ui: [128]u8 = undefined;
    var title_object_raw: [object.header_size + 128]u8 = undefined;
    const title_object = (Text{ .value = "Tree" }).toObject(&title_ui, &title_object_raw, testEpoch()).?;

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 77, .label = "Open" }).toObject(&button_ui, &button_object_raw, testEpoch()).?;

    const child_views = [_]object.View{
        try object.View.decode(title_object),
        try object.View.decode(button_object),
    };
    const tree_builder = StackTree{ .axis = .column, .gap = 6, .padding = 10, .children = &child_views };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 3]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testEpoch()).?;
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
    const left_object = (Text{ .value = "Left" }).toObject(&left_ui, &left_object_raw, testEpoch()).?;

    var right_ui: [128]u8 = undefined;
    var right_object_raw: [object.header_size + 128]u8 = undefined;
    const right_object = (Button{ .id = 1, .label = "Right" }).toObject(&right_ui, &right_object_raw, testEpoch()).?;

    const tree_children = [_]object.View{try object.View.decode(left_object)};
    const tree_builder = StackTree{ .axis = .column, .children = &tree_children };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testEpoch()).?;

    const resolved = [_]object.View{
        try object.View.decode(tree_objects.layout),
        try object.View.decode(right_object),
    };
    var components: [1]Component = undefined;
    try std.testing.expectError(error.ChildMismatch, StackTree.fromTree(try object.View.decode(tree_objects.tree), &resolved, &components));
}

test "stack tree rejects non component tree objects and descriptors" {
    var child_ui: [128]u8 = undefined;
    var child_object_raw: [object.header_size + 128]u8 = undefined;
    const child_object = (Button{ .id = 5, .label = "Child" }).toObject(&child_ui, &child_object_raw, testEpoch()).?;
    const child_view = try object.View.decode(child_object);

    var layout_body: [tree_layout_size]u8 = undefined;
    tree_codec.encodeTreeLayout(.column, 8, 0, 1, &layout_body).?;

    var bad_req = testReq();
    bad_req.visibility = .private;
    var bad_layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    const bad_layout = try (object.NodeWriter{ .out = &bad_layout_raw }).bytesNode(bad_req, testEpoch(), &layout_body);
    const bad_layout_view = try object.View.decode(bad_layout);

    var children: [2]object.Child = undefined;
    children[0] = try object.Child.fromView(bad_layout_view, 0);
    children[1] = try object.Child.fromView(child_view, children[0].logical_len);

    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree = try (object.NodeWriter{ .out = &tree_raw }).treeNode(testReq(), testEpoch(), &children);
    var components: [1]Component = undefined;
    try std.testing.expectError(error.UnsupportedComponent, Tree.fromTree(try object.View.decode(tree), &.{ bad_layout_view, child_view }, &components));

    var wrong_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const wrong_tree = try (object.NodeWriter{ .out = &wrong_tree_raw }).treeNode(bad_req, testEpoch(), &children);
    try std.testing.expectError(error.Corrupt, Tree.fromTree(try object.View.decode(wrong_tree), &.{ bad_layout_view, child_view }, &components));
}

test "stack tree writer rejects non component child objects" {
    const component = Component{ .button = .{ .id = 19, .label = "Wrong child" } };
    var req = testReq();
    req.visibility = .private;
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;
    var writer = component_codec.Writer.init(&ui_raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(component_io.writeRecord(Component, &writer, 0, component));
    const child = writer.objectNode(&object_raw, req, testEpoch()).?;
    const child_view = try object.View.decode(child);

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    try std.testing.expect((StackTree{ .axis = .column, .children = &.{child_view} }).toTreeObjects(&layout_raw, &tree_raw, testEpoch()) == null);
}

test "slot tree composes one child component object" {
    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 3, .label = "Slot child" }).toObject(&button_ui, &button_object_raw, testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (SlotTree{ .id = 44, .child = button_view }).toTreeObjects(&layout_raw, &tree_raw, testEpoch()).?;

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
    const button_object = (Button{ .id = 10, .label = "Child" }).toObject(&button_ui, &button_object_raw, testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var stack_layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var stack_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const stack_objects = (StackTree{ .axis = .column, .children = &.{button_view} }).toTreeObjects(&stack_layout_raw, &stack_tree_raw, testEpoch()).?;
    const stack_resolved = [_]object.View{ try object.View.decode(stack_objects.layout), button_view };
    var stack_components: [1]Component = undefined;
    const stack_tree = try Tree.fromTree(try object.View.decode(stack_objects.tree), &stack_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 10), stack_tree.stack.children[0].button.id);

    var slot_layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var slot_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const slot_objects = (SlotTree{ .id = 88, .child = button_view }).toTreeObjects(&slot_layout_raw, &slot_tree_raw, testEpoch()).?;
    const slot_resolved = [_]object.View{ try object.View.decode(slot_objects.layout), button_view };
    const slot_tree = try Tree.fromTree(try object.View.decode(slot_objects.tree), &slot_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 88), slot_tree.slot.id);
    try std.testing.expectEqual(@as(u32, 10), slot_tree.slot.child.button.id);
}

test "component render helper owns button variants and collects hit targets" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    const primary = Component{ .button = .{ .id = 501, .label = "Primary" } };
    const outline = Component{ .button = .{ .id = 502, .label = "Outline", .variant = .outline, .icon_slot = .{ .leading = IconComponent.named(.search) } } };
    try renderComponent(&scene, ui.Rect.init(0, 0, 120, 36), primary, .{});
    try collectComponentInteractions(&collector, ui.Rect.init(0, 0, 120, 36), primary);
    try renderComponent(&scene, ui.Rect.init(0, 44, 120, 36), outline, .{});
    try collectComponentInteractions(&collector, ui.Rect.init(0, 44, 120, 36), outline);
    const primary_hit = ui_input.hitTest(collector.written(), 12, 12).?;
    try std.testing.expectEqual(@as(u32, 501), primary_hit.id);
    const outline_hit = ui_input.hitTest(collector.written(), 12, 56).?;
    try std.testing.expectEqual(@as(u32, 502), outline_hit.id);
    try std.testing.expect(component_test.hasText(scene.written(), "Primary"));
    try std.testing.expect(component_test.hasText(scene.written(), "Outline"));
    try std.testing.expect(component_test.hasIcon(scene.written(), icon.id(.search)));
}

test "component renderer exports shared sizing tokens for measurements" {
    try std.testing.expectEqual(ui_tokens.Component.surface_radius, card_component.surface_radius);
    try std.testing.expectEqual(ui_tokens.Component.surface_padding, card_component.surface_padding);
    try std.testing.expectEqual(ui_tokens.Component.surface_detail_gap, card_component.surface_detail_gap);
    try std.testing.expectEqual(ui_tokens.Component.badge_height, badge_component.badge_height);
    try std.testing.expectEqual(ui_tokens.Component.badge_padding_x, badge_component.badge_padding_x);
}

test "component accessibility metadata comes from component identity and labels" {
    const button_meta = accessibility(.{ .button = .{ .id = 91, .label = "Save" } });
    try std.testing.expectEqual(component_common.AccessibilityRole.button, button_meta.role);
    try std.testing.expectEqual(@as(u32, 91), button_meta.control_id.?);
    try std.testing.expectEqualStrings("Save", button_meta.label);

    const input_meta = accessibility(.{ .input = .{ .id = 92, .placeholder = "Email" } });
    try std.testing.expectEqual(component_common.AccessibilityRole.input, input_meta.role);
    try std.testing.expectEqual(@as(u32, 92), input_meta.control_id.?);
    try std.testing.expectEqualStrings("Email", input_meta.label);

    const table_meta = accessibility(.{ .table = .{ .id = 93, .name = "Ada", .role = "Engineer" } });
    try std.testing.expectEqual(component_common.AccessibilityRole.table, table_meta.role);
    try std.testing.expectEqual(@as(u32, 93), table_meta.control_id.?);
    try std.testing.expectEqualStrings("Ada", table_meta.label);
}

test "component accessibility tree emitter follows stack layout bounds" {
    const children = [_]Component{
        .{ .text = .{ .value = "Intro" } },
        .{ .button = .{ .id = 94, .label = "Continue" } },
        .{ .input = .{ .id = 95, .placeholder = "Filter" } },
    };
    const stack = Stack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };
    var raw_nodes: [4]AccessibilityNode = undefined;
    var tree = AccessibilityTree.init(&raw_nodes);

    try stack.collectAccessibility(&tree, ui.Rect.init(0, 0, 160, 120), .{});

    try std.testing.expectEqual(@as(usize, 3), tree.written().len);
    try std.testing.expectEqual(component_common.AccessibilityRole.text, tree.written()[0].metadata.role);
    try std.testing.expectEqualStrings("Intro", tree.written()[0].metadata.label);
    try std.testing.expectEqual(component_common.AccessibilityRole.button, tree.written()[1].metadata.role);
    try std.testing.expectEqual(@as(u32, 94), tree.written()[1].metadata.control_id.?);
    try std.testing.expect(tree.written()[1].bounds.y > tree.written()[0].bounds.y);
    try std.testing.expectEqual(component_common.AccessibilityRole.input, tree.written()[2].metadata.role);
    try std.testing.expectEqual(@as(u32, 95), tree.written()[2].metadata.control_id.?);
}

test "component accessibility tree emitter enforces caller budget" {
    const children = [_]Component{
        .{ .button = .{ .id = 96, .label = "One" } },
        .{ .button = .{ .id = 97, .label = "Two" } },
    };
    const stack = Stack{ .axis = .column, .children = &children };
    var raw_nodes: [1]AccessibilityNode = undefined;
    var tree = AccessibilityTree.init(&raw_nodes);

    try std.testing.expectError(error.AccessibilityBudgetExceeded, stack.collectAccessibility(&tree, ui.Rect.init(0, 0, 120, 80), .{}));
}

test "component render helper applies shared interactive states by component id" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const button = Component{ .button = .{ .id = 701, .label = "Save" } };
    try renderComponent(&scene, ui.Rect.init(10, 12, 120, 36), button, .{
        .interaction = .{
            .hovered_id = 701,
            .active_id = 701,
            .focused_id = 701,
            .disabled_id = 701,
            .loading_id = 701,
            .invalid_id = 701,
        },
    });

    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_hover_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_active_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_focus_border));
    try std.testing.expect(component_test.hasRectColor(scene.written(), component_common.state_invalid_border));
    try std.testing.expect(component_test.hasFillColor(scene.written(), component_common.state_disabled_tint));
    try std.testing.expect(component_test.hasFillColor(scene.written(), component_common.state_loading_fill));
}

test "component render helper does not leak interactive state to other ids" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const button = Component{ .button = .{ .id = 702, .label = "Save" } };
    try renderComponent(&scene, ui.Rect.init(10, 12, 120, 36), button, .{
        .interaction = .{ .focused_id = 701 },
    });

    try std.testing.expect(!component_test.hasRectColor(scene.written(), component_common.state_focus_border));
}

test "component interaction collection covers primitive controls" {
    const primitives = [_]Component{
        .{ .input = .{ .id = 601, .placeholder = "Filter" } },
        .{ .textarea = .{ .id = 602, .placeholder = "Explain" } },
        .{ .select = .{ .id = 603, .label = "Mode" } },
        .{ .checkbox = .{ .id = 604, .label = "Receipts", .checked = true } },
        .{ .switch_control = .{ .id = 605, .label = "Public", .checked = false } },
        .{ .slider = .{ .id = 606, .label = "Brightness", .value = 0.5 } },
        .{ .row_item = .{ .id = 607, .title = "DNS", .detail = "Lookup" } },
    };
    const expected = [_]ui.HitKind{ .input, .textarea, .select, .checkbox, .switch_control, .slider, .row_item };
    var regions: [primitives.len]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    for (primitives, 0..) |component, index| {
        const y = @as(f32, @floatFromInt(index)) * 48.0;
        try collectComponentInteractions(&collector, ui.Rect.init(0, y, 240, 40), component);
    }

    try std.testing.expectEqual(primitives.len, collector.written().len);
    for (collector.written(), 0..) |region, index| {
        try std.testing.expectEqual(@as(u32, 601 + @as(u32, @intCast(index))), region.id);
        try std.testing.expectEqual(expected[index], region.kind);
    }
}
