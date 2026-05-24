const std = @import("std");
const clock = @import("clock.zig");
const icon = @import("icon.zig");
const ui_input = @import("input.zig");
const interaction = @import("ui_interaction.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");
const component_common = @import("ui_component_common.zig");
const component_codec = @import("ui/components/Codec.zig");
const component_io = @import("ui/components/ComponentIO.zig");
const tree_codec = @import("ui/components/TreeCodec.zig");
const component_render = @import("ui/components/Render.zig");
const stack_component = @import("ui/components/Stack.zig");
const slot_component = @import("ui/components/Slot.zig");
const text_component = @import("ui/components/Text.zig");
const card_component = @import("ui/components/Card.zig");
const button_component = @import("ui/components/Button.zig");
const badge_component = @import("ui/components/Badge.zig");
const avatar_component = @import("ui/components/Avatar.zig");
const kbd_component = @import("ui/components/Kbd.zig");
const separator_component = @import("ui/components/Separator.zig");
const input_component = @import("ui/components/Input.zig");
const textarea_component = @import("ui/components/Textarea.zig");
const select_component = @import("ui/components/Select.zig");
const checkbox_component = @import("ui/components/Checkbox.zig");
const switch_component = @import("ui/components/Switch.zig");
const progress_component = @import("ui/components/Progress.zig");
const slider_component = @import("ui/components/Slider.zig");
const row_item_component = @import("ui/components/RowItem.zig");
pub const layouts = @import("layouts.zig");

const tree_layout_size = tree_codec.tree_layout_size;
const slot_layout_size = tree_codec.slot_layout_size;

pub const Error = component_common.Error;

pub const Component = union(enum) {
    text: Text,
    card: Card,
    badge: Badge,
    avatar: Avatar,
    kbd: Kbd,
    separator: Separator,
    button: Button,
    input: Input,
    textarea: Textarea,
    select: Select,
    checkbox: Checkbox,
    switch_control: Switch,
    progress: Progress,
    slider: Slider,
    row_item: RowItem,

    pub fn node(self: Component) ui.Node {
        return switch (self) {
            .text => |component| component.node(),
            .card => |component| component.node(),
            .badge => |component| component.node(),
            .avatar => |component| component.node(),
            .kbd => |component| component.node(),
            .separator => |component| component.node(),
            .button => |component| component.node(),
            .input => |component| component.node(),
            .textarea => |component| component.node(),
            .select => |component| component.node(),
            .checkbox => |component| component.node(),
            .switch_control => |component| component.node(),
            .progress => |component| component.node(),
            .slider => |component| component.node(),
            .row_item => |component| component.node(),
        };
    }

    pub fn render(self: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderComponent(scene, bounds, self, options);
    }

    pub fn collectInteractions(self: Component, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectComponentInteractions(collector, bounds, self);
    }

    pub fn measure(self: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
        return component_render.measureComponent(Component, self, constraints, options);
    }

    pub fn toObject(self: Component, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_io.writeObject(Component, self, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Component {
        return fromNode(try component_codec.singleNode(view));
    }

    pub fn fromNode(node_value: ui.Node) Error!Component {
        return switch (node_value) {
            .text => |text| .{ .text = .{ .value = text.value } },
            .card => |card| .{ .card = .{ .title = card.title, .detail = card.detail } },
            .badge => |badge| .{ .badge = .{ .label = badge.label } },
            .avatar => |avatar| .{ .avatar = .{ .label = avatar.label } },
            .kbd => |kbd| .{ .kbd = .{ .label = kbd.label } },
            .separator => .{ .separator = .{} },
            .button => |button| .{ .button = .{ .id = button.id, .label = button.label } },
            .input => |input| .{ .input = .{ .id = input.id, .placeholder = input.placeholder } },
            .textarea => |textarea| .{ .textarea = .{ .id = textarea.id, .placeholder = textarea.placeholder } },
            .select => |select| .{ .select = .{ .id = select.id, .label = select.label } },
            .checkbox => |checkbox| .{ .checkbox = .{ .id = checkbox.id, .label = checkbox.label, .checked = checkbox.checked } },
            .switch_control => |switch_control| .{ .switch_control = .{ .id = switch_control.id, .label = switch_control.label, .checked = switch_control.checked } },
            .progress => |progress| .{ .progress = .{ .value = progress.value } },
            .slider => |slider| .{ .slider = .{ .id = slider.id, .label = slider.label, .value = slider.value } },
            .row_item => |row| .{ .row_item = .{ .id = row.id, .title = row.title, .detail = row.detail } },
            else => error.UnsupportedComponent,
        };
    }
};

pub const ButtonVariant = component_common.ButtonVariant;
pub const BadgeVariant = component_common.BadgeVariant;
pub const SurfaceVariant = component_common.SurfaceVariant;
pub const RenderOptions = component_common.RenderOptions;

pub const Text = text_component.Text;

pub const Card = card_component.Card;

pub const Button = button_component.Button;

pub const Badge = badge_component.Badge;

pub const Avatar = avatar_component.Avatar;

pub const Kbd = kbd_component.Kbd;

pub const Separator = separator_component.Separator;

pub const Input = input_component.Input;

pub const Textarea = textarea_component.Textarea;

pub const Select = select_component.Select;

pub const Checkbox = checkbox_component.Checkbox;

pub const Switch = switch_component.Switch;

pub const Progress = progress_component.Progress;

pub const Slider = slider_component.Slider;

pub const RowItem = row_item_component.RowItem;

pub fn renderComponent(scene: *ui.Scene, bounds: ui.Rect, component: Component, options: RenderOptions) ui.RenderError!void {
    return component_render.renderComponent(Component, scene, bounds, component, options);
}

pub fn renderNode(scene: *ui.Scene, bounds: ui.Rect, node: ui.Node, options: RenderOptions) ui.RenderError!void {
    if (!bounds.valid()) return error.InvalidBounds;
    switch (node) {
        .rect => |rect| try scene.push(.{ .rect = .{ .bounds = bounds, .color = rect.color } }),
        .text => |text| try scene.push(.{ .text = .{ .origin = bounds, .value = text.value, .color = text.color orelse options.style.text } }),
        .slot => |slot| try renderNode(scene, bounds, slot.child.*, options),
        .stack => |stack| try renderNodeStack(scene, bounds, stack, options),
        else => {
            const component = Component.fromNode(node) catch return error.UnsupportedComponent;
            try renderComponent(scene, bounds, component, options);
        },
    }
}

pub fn collectComponentInteractions(collector: *interaction.Collector, bounds: ui.Rect, component: Component) interaction.Error!void {
    return component_render.collectComponentInteractions(Component, collector, bounds, component);
}

pub fn measureNode(node: ui.Node, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return switch (node) {
        .rect, .text => primitiveNodeMeasurement(node, constraints),
        .slot => |slot| measureNode(slot.child.*, constraints, options),
        .stack => |stack| measureNodeStack(stack, constraints, options),
        else => if (Component.fromNode(node)) |component|
            component_render.measureComponent(Component, component, constraints, options)
        else |_|
            primitiveNodeMeasurement(node, constraints),
    };
}

fn renderNodeStack(scene: *ui.Scene, bounds: ui.Rect, stack: ui.Layout, options: RenderOptions) ui.RenderError!void {
    if (stack.children.len == 0) return;
    if (stack.children.len > node_stack_max_children) return error.CommandBudgetExceeded;

    const constraints = constraintsFromBounds(bounds);
    var child_measurements: [node_stack_max_children]layouts.types.Measurement = undefined;
    var child_bounds: [node_stack_max_children]ui.Rect = undefined;
    const measured_children = measureNodeChildren(stack.children, nodeStackChildConstraints(stack, constraints), options, &child_measurements);
    const placed_children = layouts.Flex.place(bounds, measured_children, nodeStackLayoutOptions(stack), &child_bounds);
    for (stack.children[0..placed_children.len], placed_children) |child, child_rect| {
        if (!child_rect.valid()) return error.InvalidBounds;
        try renderNode(scene, child_rect, child, options);
    }
}

fn constraintsFromBounds(bounds: ui.Rect) layouts.types.Constraints {
    return .{
        .width = .{ .exact = bounds.w },
        .height = .{ .exact = bounds.h },
        .text_wrap = .wrap,
    };
}

fn measureNodeStack(stack: ui.Layout, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    var child_measurements: [node_stack_max_children]layouts.types.Measurement = undefined;
    const measured_children = measureNodeChildren(stack.children, nodeStackChildConstraints(stack, constraints), options, &child_measurements);
    return layouts.Flex.measure(measured_children, constraints, nodeStackLayoutOptions(stack));
}

fn measureNodeChildren(children: []const ui.Node, constraints: layouts.types.Constraints, options: RenderOptions, out: []layouts.types.Measurement) []layouts.types.Measurement {
    const count = @min(children.len, @min(out.len, node_stack_max_children));
    for (children[0..count], 0..) |child, index| {
        out[index] = measureNode(child, constraints, options);
    }
    return out[0..count];
}

fn nodeStackChildConstraints(stack: ui.Layout, constraints: layouts.types.Constraints) layouts.types.Constraints {
    const inner = constraints.inner(layouts.types.Insets.uniform(stack.padding));
    return switch (stack.axis) {
        .column => .{ .width = inner.width, .height = .unconstrained, .text_wrap = constraints.text_wrap },
        .row => .{ .width = .unconstrained, .height = inner.height, .text_wrap = constraints.text_wrap },
    };
}

fn nodeStackLayoutOptions(stack: ui.Layout) layouts.Flex.Options {
    return .{
        .axis = switch (stack.axis) {
            .row => .horizontal,
            .column => .vertical,
        },
        .gap = stack.gap,
        .padding = layouts.types.Insets.uniform(stack.padding),
        .cross_align = switch (stack.cross_align) {
            .start => .start,
            .center, .end => .start,
            .stretch => .stretch,
        },
    };
}

fn primitiveNodeMeasurement(node: ui.Node, constraints: layouts.types.Constraints) layouts.types.Measurement {
    const size = node.preferredSize();
    return layouts.types.Measurement.flexible(
        .{ .w = @min(size.w, constraints.width.limit(size.w)), .h = @min(size.h, constraints.height.limit(size.h)) },
        size,
        .{ .w = node_measure_max_width, .h = size.h },
    ).applyExact(constraints);
}

const node_stack_max_children: usize = 64;
const node_measure_max_width: f32 = 4096.0;

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
        if (tree_codec.isTreeLayout(resolved_children[0])) {
            return .{ .stack = try StackTree.fromTree(tree, resolved_children, out_components) };
        }
        if (tree_codec.isSlotLayout(resolved_children[0])) {
            return .{ .slot = try SlotTree.fromTree(tree, resolved_children) };
        }
        return error.UnsupportedComponent;
    }
};

pub const TreeObjects = tree_codec.TreeObjects;

pub const Stack = stack_component.Stack(Component);
pub const StackTree = stack_component.StackTree(Component);

pub const Slot = slot_component.Slot(Component);
pub const SlotTree = slot_component.SlotTree(Component);

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

test "component deserializer rejects wrong component kind" {
    const text = Text{ .value = "not a button" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectError(error.UnsupportedComponent, Button.fromView(view));
}

test "component union roundtrips concrete component objects" {
    const component = Component{ .button = .{ .id = 14, .label = "Commit" } };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = component.toObject(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const decoded = try Component.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(@as(u32, 14), decoded.button.id);
    try std.testing.expectEqualStrings("Commit", decoded.button.label);
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

    const canonical = stack.toObject(&ui_raw, &object_raw, testReq(), testEpoch()).?;
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

test "slot component wraps a leaf component and renders the child" {
    const slot = Slot{
        .id = 99,
        .child = .{ .button = .{ .id = 12, .label = "Inside" } },
    };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = slot.toObject(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const decoded = try Slot.fromView(try object.View.decode(canonical));
    try std.testing.expectEqual(@as(u32, 99), decoded.id);
    try std.testing.expectEqual(@as(u32, 12), decoded.child.button.id);

    var nodes: [1]ui.Node = undefined;
    const root = decoded.node(&nodes).?;
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderNode(&scene, .{ .x = 0, .y = 0, .w = 140, .h = 40 }, root, .{});

    try std.testing.expect(hasText(scene.written(), "Inside"));
}

test "stack tree composes child component objects with explicit resolver input" {
    var title_ui: [128]u8 = undefined;
    var title_object_raw: [object.header_size + 128]u8 = undefined;
    const title_object = (Text{ .value = "Tree" }).toObject(&title_ui, &title_object_raw, testReq(), testEpoch()).?;

    var button_ui: [128]u8 = undefined;
    var button_object_raw: [object.header_size + 128]u8 = undefined;
    const button_object = (Button{ .id = 77, .label = "Open" }).toObject(&button_ui, &button_object_raw, testReq(), testEpoch()).?;

    const child_views = [_]object.View{
        try object.View.decode(title_object),
        try object.View.decode(button_object),
    };
    const tree_builder = StackTree{ .axis = .column, .gap = 6, .padding = 10, .children = &child_views };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 3]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;
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
    const left_object = (Text{ .value = "Left" }).toObject(&left_ui, &left_object_raw, testReq(), testEpoch()).?;

    var right_ui: [128]u8 = undefined;
    var right_object_raw: [object.header_size + 128]u8 = undefined;
    const right_object = (Button{ .id = 1, .label = "Right" }).toObject(&right_ui, &right_object_raw, testReq(), testEpoch()).?;

    const tree_children = [_]object.View{try object.View.decode(left_object)};
    const tree_builder = StackTree{ .axis = .column, .children = &tree_children };

    var layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = tree_builder.toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;

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
    const button_object = (Button{ .id = 3, .label = "Slot child" }).toObject(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const tree_objects = (SlotTree{ .id = 44, .child = button_view }).toTreeObjects(&layout_raw, &tree_raw, testReq(), testEpoch()).?;

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
    const button_object = (Button{ .id = 10, .label = "Child" }).toObject(&button_ui, &button_object_raw, testReq(), testEpoch()).?;
    const button_view = try object.View.decode(button_object);

    var stack_layout_raw: [object.header_size + tree_layout_size]u8 = undefined;
    var stack_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const stack_objects = (StackTree{ .axis = .column, .children = &.{button_view} }).toTreeObjects(&stack_layout_raw, &stack_tree_raw, testReq(), testEpoch()).?;
    const stack_resolved = [_]object.View{ try object.View.decode(stack_objects.layout), button_view };
    var stack_components: [1]Component = undefined;
    const stack_tree = try Tree.fromTree(try object.View.decode(stack_objects.tree), &stack_resolved, &stack_components);
    try std.testing.expectEqual(@as(u32, 10), stack_tree.stack.children[0].button.id);

    var slot_layout_raw: [object.header_size + slot_layout_size]u8 = undefined;
    var slot_tree_raw: [object.header_size + object.child_size * 2]u8 = undefined;
    const slot_objects = (SlotTree{ .id = 88, .child = button_view }).toTreeObjects(&slot_layout_raw, &slot_tree_raw, testReq(), testEpoch()).?;
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
    const outline = Component{ .button = .{ .id = 502, .label = "Outline" } };
    try renderComponent(&scene, ui.Rect.init(0, 0, 120, 36), primary, .{});
    try collectComponentInteractions(&collector, ui.Rect.init(0, 0, 120, 36), primary);
    try renderComponent(&scene, ui.Rect.init(0, 44, 120, 36), outline, .{ .button_variant = .outline, .button_leading_icon = .search });
    try collectComponentInteractions(&collector, ui.Rect.init(0, 44, 120, 36), outline);
    const primary_hit = ui_input.hitTest(collector.written(), 12, 12).?;
    try std.testing.expectEqual(@as(u32, 501), primary_hit.id);
    const outline_hit = ui_input.hitTest(collector.written(), 12, 56).?;
    try std.testing.expectEqual(@as(u32, 502), outline_hit.id);
    try std.testing.expect(hasText(scene.written(), "Primary"));
    try std.testing.expect(hasText(scene.written(), "Outline"));
    try std.testing.expect(hasIcon(scene.written(), .search));
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

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasIcon(commands: []const ui.Command, value: icon.Icon) bool {
    const icon_id = icon.id(value);
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}
