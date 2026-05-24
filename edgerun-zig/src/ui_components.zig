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
const region_component = @import("ui/components/Region.zig");
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
const article_card_component = @import("ui/components/ArticleCard.zig");
const article_list_item_component = @import("ui/components/ArticleListItem.zig");
const aside_component = @import("ui/components/Aside.zig");
const breadcrumb_component = @import("ui/components/Breadcrumb.zig");
const callout_component = @import("ui/components/Callout.zig");
const choice_group_component = @import("ui/components/ChoiceGroup.zig");
const code_block_component = @import("ui/components/CodeBlock.zig");
const definition_list_component = @import("ui/components/DefinitionList.zig");
const details_component = @import("ui/components/Details.zig");
const figure_component = @import("ui/components/Figure.zig");
const heading_component = @import("ui/components/Heading.zig");
const list_component = @import("ui/components/List.zig");
const nav_component = @import("ui/components/Nav.zig");
const progress_summary_component = @import("ui/components/ProgressSummary.zig");
const resource_list_component = @import("ui/components/ResourceList.zig");
const step_list_component = @import("ui/components/StepList.zig");
const table_component = @import("ui/components/Table.zig");
const timeline_component = @import("ui/components/Timeline.zig");
pub const layouts = @import("layouts.zig");

const tree_layout_size = tree_codec.tree_layout_size;
const slot_layout_size = tree_codec.slot_layout_size;

pub const Error = component_common.Error;
pub const HtmlError = component_common.HtmlError;
pub const MarkdownError = component_common.MarkdownError;
pub const RegistryError = component_common.RegistryError;
pub const ComponentDescriptor = component_common.ComponentDescriptor;
pub const ComponentRegistry = component_common.ComponentRegistry;
const HtmlWriter = component_common.HtmlWriter;
const HtmlTextArena = component_common.HtmlTextArena;
const MarkdownWriter = component_common.MarkdownWriter;
const MarkdownTextArena = component_common.MarkdownTextArena;

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
        return measureComponent(self, constraints, options);
    }

    pub fn toObject(self: Component, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_io.writeObject(Component, self, ui_out, object_out, req, epoch);
    }

    pub fn toHtml(self: Component, out: []u8) HtmlError![]u8 {
        return writeComponentHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Component {
        return readComponentHtml(html, text_out);
    }

    pub fn toMarkdown(self: Component, out: []u8) MarkdownError![]u8 {
        return writeComponentMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Component {
        return readComponentMarkdown(markdown, text_out);
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

pub const ArticleCard = article_card_component.ArticleCard;
pub const ArticleListItem = article_list_item_component.ArticleListItem;

pub const CodeBlock = code_block_component.CodeBlock;

pub const Heading = heading_component.Heading;

pub const List = list_component.List;

pub const Callout = callout_component.Callout;

pub const Aside = aside_component.Aside;

pub const Details = details_component.Details;

pub const Figure = figure_component.Figure;

pub const ChoiceOption = choice_group_component.ChoiceOption;
pub const ChoiceGroup = choice_group_component.ChoiceGroup;

pub const StepState = step_list_component.StepState;
pub const StepItem = step_list_component.StepItem;
pub const StepList = step_list_component.StepList;

pub const BreadcrumbItem = breadcrumb_component.BreadcrumbItem;
pub const Breadcrumb = breadcrumb_component.Breadcrumb;

pub const DefinitionItem = definition_list_component.DefinitionItem;
pub const DefinitionList = definition_list_component.DefinitionList;

pub const TimelineEvent = timeline_component.TimelineEvent;
pub const Timeline = timeline_component.Timeline;

pub const ResourceItem = resource_list_component.ResourceItem;
pub const ResourceList = resource_list_component.ResourceList;

pub const ProgressSummary = progress_summary_component.ProgressSummary;

pub const NavItem = nav_component.NavItem;
pub const Nav = nav_component.Nav;

pub const RegionTag = region_component.RegionTag;
pub const Region = region_component.Region(Component);

pub const TableCell = table_component.TableCell;
pub const TableRow = table_component.TableRow;
pub const Table = table_component.Table;

pub const AcademyComponentKind = enum {
    aside,
    breadcrumb,
    callout,
    choice_group,
    code_block,
    definition_list,
    details,
    figure,
    heading,
    list,
    nav,
    progress_summary,
    resource_list,
    step_list,
    table,
    timeline,
};

pub const academy_component_count = 16;

pub fn registerAcademyComponent(registry: *ComponentRegistry, kind: AcademyComponentKind) RegistryError!void {
    return switch (kind) {
        .aside => aside_component.register(registry),
        .breadcrumb => breadcrumb_component.register(registry),
        .callout => callout_component.register(registry),
        .choice_group => choice_group_component.register(registry),
        .code_block => code_block_component.register(registry),
        .definition_list => definition_list_component.register(registry),
        .details => details_component.register(registry),
        .figure => figure_component.register(registry),
        .heading => heading_component.register(registry),
        .list => list_component.register(registry),
        .nav => nav_component.register(registry),
        .progress_summary => progress_summary_component.register(registry),
        .resource_list => resource_list_component.register(registry),
        .step_list => step_list_component.register(registry),
        .table => table_component.register(registry),
        .timeline => timeline_component.register(registry),
    };
}

pub fn registerAcademyComponents(registry: *ComponentRegistry) RegistryError!void {
    const kinds = [_]AcademyComponentKind{
        .aside,
        .breadcrumb,
        .callout,
        .choice_group,
        .code_block,
        .definition_list,
        .details,
        .figure,
        .heading,
        .list,
        .nav,
        .progress_summary,
        .resource_list,
        .step_list,
        .table,
        .timeline,
    };
    for (kinds) |kind| {
        try registerAcademyComponent(registry, kind);
    }
}

pub fn registerAside(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .aside);
}

pub fn registerBreadcrumb(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .breadcrumb);
}

pub fn registerCallout(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .callout);
}

pub fn registerChoiceGroup(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .choice_group);
}

pub fn registerCodeBlock(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .code_block);
}

pub fn registerDefinitionList(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .definition_list);
}

pub fn registerDetails(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .details);
}

pub fn registerFigure(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .figure);
}

pub fn registerHeading(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .heading);
}

pub fn registerList(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .list);
}

pub fn registerNav(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .nav);
}

pub fn registerProgressSummary(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .progress_summary);
}

pub fn registerResourceList(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .resource_list);
}

pub fn registerStepList(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .step_list);
}

pub fn registerTable(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .table);
}

pub fn registerTimeline(registry: *ComponentRegistry) RegistryError!void {
    return registerAcademyComponent(registry, .timeline);
}

pub fn renderComponent(scene: *ui.Scene, bounds: ui.Rect, component: Component, options: RenderOptions) ui.RenderError!void {
    return component_render.renderComponent(Component, scene, bounds, component, options);
}

pub fn collectComponentInteractions(collector: *interaction.Collector, bounds: ui.Rect, component: Component) interaction.Error!void {
    return component_render.collectComponentInteractions(Component, collector, bounds, component);
}

pub fn measureComponent(component: Component, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return component_render.measureComponent(Component, component, constraints, options);
}

pub fn measureRegion(region: Region, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return component_render.measureRegion(Component, region, constraints, options);
}

pub fn renderRegion(scene: *ui.Scene, bounds: ui.Rect, region: Region, options: RenderOptions) ui.RenderError!void {
    return component_render.renderRegion(Component, scene, bounds, region, options);
}

pub fn collectRegionInteractions(collector: *interaction.Collector, bounds: ui.Rect, region: Region, options: RenderOptions) interaction.Error!void {
    return component_render.collectRegionInteractions(Component, collector, bounds, region, options);
}

pub fn renderStack(scene: *ui.Scene, bounds: ui.Rect, stack: Stack, options: RenderOptions) ui.RenderError!void {
    return component_render.renderStack(Component, scene, bounds, stack, options);
}

pub fn collectStackInteractions(collector: *interaction.Collector, bounds: ui.Rect, stack: Stack, options: RenderOptions) interaction.Error!void {
    return component_render.collectStackInteractions(Component, collector, bounds, stack, options);
}

pub fn renderSurface(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    return component_render.renderSurface(scene, bounds, title, detail, options);
}

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

fn writeComponentHtml(component: Component, out: []u8) HtmlError![]u8 {
    return component_io.writeHtml(Component, component, out);
}

fn writeComponentHtmlInto(writer: *HtmlWriter, component: Component) HtmlError!void {
    return component_io.writeHtmlInto(Component, writer, component);
}

fn writeComponentMarkdown(component: Component, out: []u8) MarkdownError![]u8 {
    return component_io.writeMarkdown(Component, component, out);
}

fn writeComponentMarkdownInto(writer: *MarkdownWriter, component: Component) MarkdownError!void {
    return component_io.writeMarkdownInto(Component, writer, component);
}

fn readComponentMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Component {
    return component_io.readMarkdown(Component, markdown, text_out);
}

fn readComponentMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Component {
    return component_io.readMarkdownWithArena(Component, markdown, text);
}

fn readComponentHtml(html: []const u8, text_out: []u8) HtmlError!Component {
    return component_io.readHtml(Component, html, text_out);
}

fn readComponentHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Component {
    return component_io.readHtmlWithArena(Component, html, text);
}

fn readComponentListMarkdownWithArena(markdown: []const u8, out_components: []Component, text: *MarkdownTextArena) MarkdownError![]const Component {
    return component_io.readListMarkdownWithArena(Component, markdown, out_components, text);
}

fn readComponentListHtmlWithArena(html: []const u8, out_components: []Component, text: *HtmlTextArena) HtmlError![]const Component {
    return component_io.readListHtmlWithArena(Component, html, out_components, text);
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

test "academy component registration uses one canonical component list" {
    var entries: [academy_component_count]ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);

    try registerAcademyComponents(&registry);

    try std.testing.expectEqual(@as(usize, academy_component_count), registry.len);
    _ = try registry.get("aside");
    _ = try registry.get("breadcrumb");
    _ = try registry.get("callout");
    _ = try registry.get("choice-group");
    _ = try registry.get("code-block");
    _ = try registry.get("definition-list");
    _ = try registry.get("details");
    _ = try registry.get("figure");
    _ = try registry.get("heading");
    _ = try registry.get("list");
    _ = try registry.get("nav");
    _ = try registry.get("progress-summary");
    _ = try registry.get("resource-list");
    _ = try registry.get("step-list");
    _ = try registry.get("table");
    _ = try registry.get("timeline");
    try std.testing.expectError(error.DuplicateComponent, registerAcademyComponent(&registry, .nav));
}

test "button component serializes to canonical object and deserializes" {
    const button = Button{ .id = 7, .label = "Run" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.toObject(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const view = try object.View.decode(canonical);
    const decoded = try Button.fromView(view);

    try std.testing.expectEqual(@as(u32, 7), decoded.id);
    try std.testing.expectEqualStrings("Run", decoded.label);
}

test "component deserializer rejects wrong component kind" {
    const text = Text{ .value = "not a button" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, testReq(), testEpoch()).?;
    const view = try object.View.decode(canonical);

    try std.testing.expectError(error.UnsupportedComponent, Button.fromView(view));
}

test "input and row item components roundtrip through objects" {
    var input_ui: [128]u8 = undefined;
    var input_object: [object.header_size + 128]u8 = undefined;
    const input_canonical = (Input{ .id = 9, .placeholder = "Search" }).toObject(&input_ui, &input_object, testReq(), testEpoch()).?;
    const input = try Input.fromView(try object.View.decode(input_canonical));
    try std.testing.expectEqual(@as(u32, 9), input.id);
    try std.testing.expectEqualStrings("Search", input.placeholder);

    var row_ui: [128]u8 = undefined;
    var row_object: [object.header_size + 128]u8 = undefined;
    const row_canonical = (RowItem{ .id = 11, .title = "Object", .detail = "Canonical" }).toObject(&row_ui, &row_object, testReq(), testEpoch()).?;
    const row = try RowItem.fromView(try object.View.decode(row_canonical));
    try std.testing.expectEqual(@as(u32, 11), row.id);
    try std.testing.expectEqualStrings("Object", row.title);
    try std.testing.expectEqualStrings("Canonical", row.detail);
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

test "dev primitive components roundtrip through canonical objects" {
    var badge_ui: [128]u8 = undefined;
    var badge_object: [object.header_size + 128]u8 = undefined;
    const badge_canonical = (Badge{ .label = "Ready" }).toObject(&badge_ui, &badge_object, testReq(), testEpoch()).?;
    const badge = try Badge.fromView(try object.View.decode(badge_canonical));
    try std.testing.expectEqualStrings("Ready", badge.label);

    var checkbox_ui: [128]u8 = undefined;
    var checkbox_object: [object.header_size + 128]u8 = undefined;
    const checkbox_canonical = (Checkbox{ .id = 21, .label = "Enable sync", .checked = true }).toObject(&checkbox_ui, &checkbox_object, testReq(), testEpoch()).?;
    const checkbox = try Checkbox.fromView(try object.View.decode(checkbox_canonical));
    try std.testing.expectEqual(@as(u32, 21), checkbox.id);
    try std.testing.expect(checkbox.checked);

    var switch_ui: [128]u8 = undefined;
    var switch_object: [object.header_size + 128]u8 = undefined;
    const switch_canonical = (Switch{ .id = 22, .label = "Public", .checked = false }).toObject(&switch_ui, &switch_object, testReq(), testEpoch()).?;
    const switch_control = try Switch.fromView(try object.View.decode(switch_canonical));
    try std.testing.expectEqual(@as(u32, 22), switch_control.id);
    try std.testing.expect(!switch_control.checked);

    var progress_ui: [128]u8 = undefined;
    var progress_object: [object.header_size + 128]u8 = undefined;
    const progress_canonical = (Progress{ .value = 0.64 }).toObject(&progress_ui, &progress_object, testReq(), testEpoch()).?;
    const progress = try Progress.fromView(try object.View.decode(progress_canonical));
    try std.testing.expect(@abs(progress.value - 0.64) < 0.001);

    var slider_ui: [128]u8 = undefined;
    var slider_object: [object.header_size + 128]u8 = undefined;
    const slider_canonical = (Slider{ .id = 23, .label = "Brightness", .value = 0.72 }).toObject(&slider_ui, &slider_object, testReq(), testEpoch()).?;
    const slider = try Slider.fromView(try object.View.decode(slider_canonical));
    try std.testing.expectEqual(@as(u32, 23), slider.id);
    try std.testing.expect(@abs(slider.value - 0.72) < 0.001);
}

test "layout and display primitive components roundtrip through canonical objects" {
    var card_ui: [128]u8 = undefined;
    var card_object: [object.header_size + 128]u8 = undefined;
    const card_canonical = (Card{ .title = "Project", .detail = "Interactive docs" }).toObject(&card_ui, &card_object, testReq(), testEpoch()).?;
    const card = try Card.fromView(try object.View.decode(card_canonical));
    try std.testing.expectEqualStrings("Project", card.title);
    try std.testing.expectEqualStrings("Interactive docs", card.detail);

    var avatar_ui: [128]u8 = undefined;
    var avatar_object: [object.header_size + 128]u8 = undefined;
    const avatar_canonical = (Avatar{ .label = "ER" }).toObject(&avatar_ui, &avatar_object, testReq(), testEpoch()).?;
    const avatar = try Avatar.fromView(try object.View.decode(avatar_canonical));
    try std.testing.expectEqualStrings("ER", avatar.label);

    var kbd_ui: [128]u8 = undefined;
    var kbd_object: [object.header_size + 128]u8 = undefined;
    const kbd_canonical = (Kbd{ .label = "CmdK" }).toObject(&kbd_ui, &kbd_object, testReq(), testEpoch()).?;
    const kbd = try Kbd.fromView(try object.View.decode(kbd_canonical));
    try std.testing.expectEqualStrings("CmdK", kbd.label);

    var separator_ui: [128]u8 = undefined;
    var separator_object: [object.header_size + 128]u8 = undefined;
    const separator_canonical = (Separator{}).toObject(&separator_ui, &separator_object, testReq(), testEpoch()).?;
    _ = try Separator.fromView(try object.View.decode(separator_canonical));

    var textarea_ui: [128]u8 = undefined;
    var textarea_object: [object.header_size + 128]u8 = undefined;
    const textarea_canonical = (Textarea{ .id = 31, .placeholder = "Describe this app" }).toObject(&textarea_ui, &textarea_object, testReq(), testEpoch()).?;
    const textarea = try Textarea.fromView(try object.View.decode(textarea_canonical));
    try std.testing.expectEqual(@as(u32, 31), textarea.id);
    try std.testing.expectEqualStrings("Describe this app", textarea.placeholder);

    var select_ui: [128]u8 = undefined;
    var select_object: [object.header_size + 128]u8 = undefined;
    const select_canonical = (Select{ .id = 32, .label = "Production" }).toObject(&select_ui, &select_object, testReq(), testEpoch()).?;
    const select = try Select.fromView(try object.View.decode(select_canonical));
    try std.testing.expectEqual(@as(u32, 32), select.id);
    try std.testing.expectEqualStrings("Production", select.label);
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

    try std.testing.expect(scene.commandCount() != 0);
}

test "component measurement wraps primitive text under exact width" {
    const component = Component{ .text = .{ .value = "A browser shell loads the tiny bootstrap and wasm owns the rest" } };
    const wide = component.measure(.{ .width = .{ .exact = 360 }, .text_wrap = .wrap }, .{});
    const narrow = component.measure(.{ .width = .{ .exact = 120 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 360), wide.preferred.w);
    try std.testing.expectEqual(@as(f32, 120), narrow.preferred.w);
    try std.testing.expect(narrow.preferred.h > wide.preferred.h);
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
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = 140, .h = 40 }, .{});

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

test "component render helper owns badge and surface variants" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderComponent(&scene, ui.Rect.init(0, 0, 180, 34), .{ .badge = .{ .label = "Native component" } }, .{ .badge_variant = .accent });
    try renderComponent(&scene, ui.Rect.init(0, 44, 220, 86), .{ .card = .{ .title = "Surface", .detail = "Shared primitive rendering." } }, .{ .surface_variant = .elevated });

    try std.testing.expect(hasText(scene.written(), "Native component"));
    try std.testing.expect(hasText(scene.written(), "Surface"));
    try std.testing.expect(hasShadow(scene.written()));
}

test "component render helper owns article cards and code blocks" {
    var commands: [64]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const article = ArticleCard{
        .id = 801,
        .category = "Architecture",
        .meta = "May 23, 2026",
        .title = "EdgeRun Apps Run Where The User Is",
        .summary = "A short introduction to identity-routed apps and local execution.",
    };

    try article.render(&scene, ui.Rect.init(0, 0, 360, 172), .{});
    try article.collectInteractions(&collector, ui.Rect.init(0, 0, 360, 172));
    try (CodeBlock{ .lines = &.{ "const app = try edge.compile(source);", "try app.run(.{});" } }).render(&scene, ui.Rect.init(0, 190, 360, 72), .{});
    const hit = ui_input.hitTest(collector.written(), 20, 20).?;
    try std.testing.expectEqual(@as(u32, 801), hit.id);
    try std.testing.expect(hasText(scene.written(), "Architecture"));
    try std.testing.expect(hasText(scene.written(), "const app = try edge.compile(source);"));
}

test "component html codec roundtrips semantic leaf components" {
    const components = [_]Component{
        .{ .text = .{ .value = "DNS turns names into addresses." } },
        .{ .badge = .{ .label = "Lesson" } },
        .{ .avatar = .{ .label = "ER" } },
        .{ .kbd = .{ .label = "CtrlK" } },
        .{ .separator = .{} },
        .{ .button = .{ .id = 42, .label = "Run demo" } },
        .{ .input = .{ .id = 77, .placeholder = "Search lessons" } },
        .{ .textarea = .{ .id = 78, .placeholder = "Explain the packet path" } },
        .{ .select = .{ .id = 79, .label = "Beginner track" } },
        .{ .checkbox = .{ .id = 80, .label = "Show packet headers", .checked = true } },
        .{ .switch_control = .{ .id = 81, .label = "Guided mode", .checked = false } },
        .{ .progress = .{ .value = 0.64 } },
        .{ .slider = .{ .id = 82, .label = "Simulation speed", .value = 0.72 } },
        .{ .card = .{ .title = "Router boundary", .detail = "A router forwards packets but does not own the app." } },
        .{ .row_item = .{ .id = 91, .title = "TLS tunnel", .detail = "Protects the trip, not every endpoint." } },
    };

    for (components) |component| {
        var html: [512]u8 = undefined;
        var text: [256]u8 = undefined;
        const encoded = try component.toHtml(&html);
        const decoded = try Component.fromHtml(encoded, &text);

        try expectSameComponent(component, decoded);
    }
}

test "component html codec emits readable semantic html" {
    var html: [256]u8 = undefined;
    const encoded = try (Component{ .button = .{ .id = 9, .label = "Open object" } }).toHtml(&html);

    try std.testing.expectEqualStrings("<button data-er-component=\"button\" data-er-id=\"9\">Open object</button>", encoded);

    const progress = try (Component{ .progress = .{ .value = 0.64 } }).toHtml(&html);
    try std.testing.expectEqualStrings("<progress data-er-component=\"progress\" value=\"64\" max=\"100\"></progress>", progress);

    const checkbox = try (Component{ .checkbox = .{ .id = 17, .label = "Show receipts", .checked = true } }).toHtml(&html);
    try std.testing.expectEqualStrings("<label data-er-component=\"checkbox\" data-er-id=\"17\" data-er-checked=\"true\"><input type=\"checkbox\" checked>Show receipts</label>", checkbox);
}

test "component html codec escapes text and attributes" {
    var html: [256]u8 = undefined;
    var text: [128]u8 = undefined;
    const encoded = try (Component{ .input = .{ .id = 5, .placeholder = "Search \"objects\" & apps" } }).toHtml(&html);

    try std.testing.expectEqualStrings("<input data-er-component=\"input\" data-er-id=\"5\" placeholder=\"Search &quot;objects&quot; &amp; apps\">", encoded);
    const decoded = try Component.fromHtml(encoded, &text);
    try std.testing.expectEqual(@as(u32, 5), decoded.input.id);
    try std.testing.expectEqualStrings("Search \"objects\" & apps", decoded.input.placeholder);

    const textarea_html = try (Component{ .textarea = .{ .id = 6, .placeholder = "Explain \"DNS\" & TLS" } }).toHtml(&html);
    const textarea = try Component.fromHtml(textarea_html, &text);
    try std.testing.expectEqualStrings("Explain \"DNS\" & TLS", textarea.textarea.placeholder);
}

test "component html codec rejects untrusted browser html" {
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.UnsupportedHtml, Component.fromHtml("<script>alert(1)</script>", &text));
    try std.testing.expectError(error.UnsupportedHtml, Component.fromHtml("<button onclick=\"evil()\">Run</button>", &text));
    try std.testing.expectError(error.InvalidHtml, Component.fromHtml("<button data-er-component=\"button\" data-er-id=\"x\">Run</button>", &text));
    try std.testing.expectError(error.InvalidHtml, Component.fromHtml("<p data-er-component=\"text\">bad&nbsp;entity</p>", &text));
    try std.testing.expectError(error.InvalidHtml, Component.fromHtml("<progress data-er-component=\"progress\" value=\"101\" max=\"100\"></progress>", &text));
    try std.testing.expectError(error.InvalidHtml, Component.fromHtml("<label data-er-component=\"checkbox\" data-er-id=\"8\" data-er-checked=\"maybe\"><input type=\"checkbox\">Broken</label>", &text));
    try std.testing.expectError(error.InvalidHtml, Component.fromHtml("<span data-er-component=\"avatar\" aria-label=\"ER\">Different</span>", &text));
}

test "component markdown codec roundtrips semantic leaf components" {
    const components = [_]Component{
        .{ .text = .{ .value = "DNS turns names into addresses." } },
        .{ .card = .{ .title = "Router boundary", .detail = "Forwards packets, not app authority." } },
        .{ .badge = .{ .label = "Lesson" } },
        .{ .avatar = .{ .label = "ER" } },
        .{ .kbd = .{ .label = "CtrlK" } },
        .{ .separator = .{} },
        .{ .button = .{ .id = 42, .label = "Run demo" } },
        .{ .input = .{ .id = 77, .placeholder = "Search lessons" } },
        .{ .textarea = .{ .id = 78, .placeholder = "Explain the packet path" } },
        .{ .select = .{ .id = 79, .label = "Beginner track" } },
        .{ .checkbox = .{ .id = 80, .label = "Show packet headers", .checked = true } },
        .{ .switch_control = .{ .id = 81, .label = "Guided mode", .checked = false } },
        .{ .progress = .{ .value = 0.64 } },
        .{ .slider = .{ .id = 82, .label = "Simulation speed", .value = 0.72 } },
        .{ .row_item = .{ .id = 91, .title = "TLS tunnel", .detail = "Protects the trip." } },
    };

    for (components) |component| {
        var markdown: [512]u8 = undefined;
        var text: [256]u8 = undefined;
        const encoded = try component.toMarkdown(&markdown);
        const decoded = try Component.fromMarkdown(encoded, &text);

        try expectSameComponent(component, decoded);
    }
}

test "component markdown codec emits readable primitive directives" {
    var markdown: [256]u8 = undefined;

    const button = try (Component{ .button = .{ .id = 9, .label = "Open object" } }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::button\nid: 9\nlabel: Open object\n:::", button);

    const progress = try (Component{ .progress = .{ .value = 0.64 } }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::progress-control\nvalue: 64\n:::", progress);

    const text = try (Component{ .text = .{ .value = "TLS > DNS?" } }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings("TLS \\> DNS?", text);
}

test "component markdown codec rejects malformed primitive directives" {
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Component.fromMarkdown("", &text));
    try std.testing.expectError(error.InvalidMarkdown, Component.fromMarkdown("bad\nparagraph", &text));
    try std.testing.expectError(error.UnsupportedMarkdown, Component.fromMarkdown(":::unknown\nvalue: no\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, Component.fromMarkdown(":::button\nlabel: Missing id\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, Component.fromMarkdown(":::badge\nname: Missing label\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, Component.fromMarkdown(":::button\nid: x\nlabel: Bad\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, Component.fromMarkdown(":::checkbox\nid: 1\nchecked: maybe\nlabel: Bad\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, Component.fromMarkdown(":::progress-control\nvalue: 101\n:::", &text));
}

test "stack html codec roundtrips a semantic section" {
    const children = [_]Component{
        .{ .text = .{ .value = "How DNS Works" } },
        .{ .card = .{ .title = "Name lookup", .detail = "DNS turns a human name into an address a network can route." } },
        .{ .button = .{ .id = 44, .label = "Run DNS demo" } },
    };
    const stack = Stack{ .axis = .column, .gap = 14, .padding = 20, .children = &children };
    var html: [1024]u8 = undefined;
    var decoded_children: [3]Component = undefined;
    var text: [512]u8 = undefined;

    const encoded = try stack.toHtml(&html);
    const decoded = try Stack.fromHtml(encoded, &decoded_children, &text);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "<section data-er-component=\"stack\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "<p data-er-component=\"text\">How DNS Works</p>") != null);
    try std.testing.expectEqual(ui.Axis.column, decoded.axis);
    try std.testing.expectEqual(@as(u16, 14), decoded.gap);
    try std.testing.expectEqual(@as(u16, 20), decoded.padding);
    try std.testing.expectEqual(@as(usize, 3), decoded.children.len);
    try expectSameComponent(children[0], decoded.children[0]);
    try expectSameComponent(children[1], decoded.children[1]);
    try expectSameComponent(children[2], decoded.children[2]);
}

test "stack html codec streams long child components without scratch truncation" {
    const long_detail =
        "A lesson card can carry a full human explanation about how a request moves through the system. " ++
        "The browser shell starts the app, the WASM side owns behavior, and every visible control still has a semantic HTML form. " ++
        "That matters because search engines, accessibility tools, and future EdgeRun import paths need meaning instead of pixels. " ++
        "This deliberately long card proves nested component HTML is written through the parent writer instead of a small temporary buffer. " ++
        "The output buffer belongs to the caller, so large academy explanations can remain structured without being forced into tiny fragments. " ++
        "The parser still rejects unsupported browser HTML and only accepts the exact component shapes that EdgeRun emits.";
    const children = [_]Component{
        .{ .card = .{ .title = "Long explanation", .detail = long_detail } },
    };
    const stack = Stack{ .axis = .column, .gap = 8, .padding = 12, .children = &children };
    var html: [2048]u8 = undefined;
    var decoded_children: [1]Component = undefined;
    var text: [1024]u8 = undefined;

    const encoded = try stack.toHtml(&html);
    const decoded = try Stack.fromHtml(encoded, &decoded_children, &text);

    try std.testing.expectEqual(@as(usize, 1), decoded.children.len);
    try std.testing.expectEqualStrings(long_detail, decoded.children[0].card.detail);
}

test "stack html codec roundtrips primitive control children" {
    const children = [_]Component{
        .{ .avatar = .{ .label = "ER" } },
        .{ .kbd = .{ .label = "CtrlK" } },
        .{ .textarea = .{ .id = 1201, .placeholder = "Explain capability routing" } },
        .{ .select = .{ .id = 1202, .label = "Security track" } },
        .{ .checkbox = .{ .id = 1203, .label = "Show receipt ids", .checked = true } },
        .{ .switch_control = .{ .id = 1204, .label = "Guided demo", .checked = false } },
        .{ .progress = .{ .value = 0.42 } },
        .{ .slider = .{ .id = 1205, .label = "Simulation speed", .value = 0.73 } },
    };
    const stack = Stack{ .axis = .column, .gap = 6, .padding = 10, .children = &children };
    var html: [2048]u8 = undefined;
    var decoded_children: [8]Component = undefined;
    var text: [512]u8 = undefined;

    const encoded = try stack.toHtml(&html);
    const decoded = try Stack.fromHtml(encoded, &decoded_children, &text);

    try std.testing.expectEqual(@as(usize, children.len), decoded.children.len);
    for (children, decoded.children) |expected, actual| {
        try expectSameComponent(expected, actual);
    }
}

test "stack html codec rejects unsupported nested or malformed content" {
    var components: [2]Component = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Stack.fromHtml("<section data-er-component=\"stack\" data-er-axis=\"diagonal\" data-er-gap=\"1\" data-er-padding=\"0\"></section>", &components, &text));
    try std.testing.expectError(error.InvalidHtml, Stack.fromHtml("<section data-er-component=\"stack\" data-er-axis=\"column\" data-er-gap=\"1\" data-er-padding=\"0\"><script>x()</script></section>", &components, &text));
    try std.testing.expectError(error.UnsupportedHtml, Stack.fromHtml("<div><p>plain html</p></div>", &components, &text));
}

test "stack markdown codec roundtrips component children" {
    const children = [_]Component{
        .{ .text = .{ .value = "DNS turns names into addresses." } },
        .{ .card = .{ .title = "Name lookup", .detail = "A resolver follows the route from name to address." } },
        .{ .button = .{ .id = 44, .label = "Run DNS demo" } },
        .{ .progress = .{ .value = 0.64 } },
    };
    const stack = Stack{ .axis = .column, .gap = 14, .padding = 20, .children = &children };
    var markdown: [2048]u8 = undefined;
    var decoded_children: [4]Component = undefined;
    var text: [512]u8 = undefined;

    const encoded = try stack.toMarkdown(&markdown);
    const decoded = try Stack.fromMarkdown(encoded, &decoded_children, &text);

    try std.testing.expect(std.mem.indexOf(u8, encoded, ":::stack\naxis: column\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "--- component ---\n:::button") != null);
    try std.testing.expectEqual(ui.Axis.column, decoded.axis);
    try std.testing.expectEqual(@as(u16, 14), decoded.gap);
    try std.testing.expectEqual(@as(u16, 20), decoded.padding);
    try std.testing.expectEqual(@as(usize, children.len), decoded.children.len);
    for (children, decoded.children) |expected, actual| {
        try expectSameComponent(expected, actual);
    }
}

test "stack markdown codec rejects malformed or unsupported children" {
    var components: [2]Component = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Stack.fromMarkdown(":::stack\naxis: diagonal\ngap: 1\npadding: 0\n--- component ---\nText\n:::", &components, &text));
    try std.testing.expectError(error.InvalidMarkdown, Stack.fromMarkdown(":::stack\naxis: column\ngap: 1\npadding: 0\n:::", &components, &text));
    try std.testing.expectError(error.UnsupportedMarkdown, Stack.fromMarkdown(":::stack\naxis: column\ngap: 1\npadding: 0\n--- component ---\n:::unknown\nvalue: no\n:::\n:::", &components, &text));
}

test "region component renders semantic children and collects interactions" {
    const children = [_]Component{
        .{ .text = .{ .value = "Academy path" } },
        .{ .button = .{ .id = 31001, .label = "Continue" } },
    };
    const region = Region{ .tag = .main, .label = "Lesson body", .children = &children };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try region.render(&scene, ui.Rect.init(0, 0, 360, 120), .{});
    try region.collectInteractions(&collector, ui.Rect.init(0, 0, 360, 120), .{});

    try std.testing.expect(hasText(scene.written(), "Academy path"));
    try std.testing.expect(hasText(scene.written(), "Continue"));
    const hit = ui_input.hitTest(collector.written(), 24, 58).?;
    try std.testing.expectEqual(@as(u32, 31001), hit.id);
}

test "region measurement follows wrapped child content" {
    const children = [_]Component{
        .{ .text = .{ .value = "Normal people understand IT systems faster when each layer explains the next layer in the path." } },
        .{ .button = .{ .id = 31002, .label = "Next" } },
    };
    const region = Region{ .tag = .main, .label = "Lesson body", .children = &children };
    const wide = region.measure(.{ .width = .{ .exact = 360 }, .text_wrap = .wrap }, .{});
    const narrow = region.measure(.{ .width = .{ .exact = 160 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 360), wide.preferred.w);
    try std.testing.expectEqual(@as(f32, 160), narrow.preferred.w);
    try std.testing.expect(narrow.preferred.h > wide.preferred.h);
}

test "region html codec roundtrips landmark content" {
    const children = [_]Component{
        .{ .text = .{ .value = "A browser loads the shell." } },
        .{ .card = .{ .title = "WASM owns behavior", .detail = "The host only evaluates the bootstrap string." } },
    };
    const region = Region{ .tag = .article, .label = "Browser and WASM", .children = &children };
    var html: [1024]u8 = undefined;
    var decoded_children: [2]Component = undefined;
    var text: [512]u8 = undefined;

    const encoded = try region.toHtml(&html);
    const decoded = try Region.fromHtml(encoded, &decoded_children, &text);

    try std.testing.expectEqualStrings("<article data-er-component=\"region\" aria-label=\"Browser and WASM\"><p data-er-component=\"text\">A browser loads the shell.</p><article data-er-component=\"card\"><h2>WASM owns behavior</h2><p>The host only evaluates the bootstrap string.</p></article></article>", encoded);
    try std.testing.expectEqual(RegionTag.article, decoded.tag);
    try std.testing.expectEqualStrings("Browser and WASM", decoded.label);
    try std.testing.expectEqual(@as(usize, 2), decoded.children.len);
    try expectSameComponent(children[0], decoded.children[0]);
    try expectSameComponent(children[1], decoded.children[1]);
}

test "region html codec rejects plain landmarks and empty regions" {
    var children: [2]Component = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Region.fromHtml("<main><p>Plain</p></main>", &children, &text));
    try std.testing.expectError(error.InvalidHtml, Region.fromHtml("<main data-er-component=\"region\" aria-label=\"Body\"></main>", &children, &text));
    try std.testing.expectError(error.InvalidHtml, Region.fromHtml("<aside data-er-component=\"region\" aria-label=\"Side\"><p data-er-component=\"text\">No</p></aside>", &children, &text));
}

test "region markdown codec roundtrips landmark content" {
    const children = [_]Component{
        .{ .text = .{ .value = "A browser loads the shell." } },
        .{ .card = .{ .title = "WASM owns behavior", .detail = "The host only evaluates the bootstrap string." } },
        .{ .button = .{ .id = 32001, .label = "Open lesson" } },
    };
    const region = Region{ .tag = .main, .label = "Browser and WASM", .children = &children };
    var markdown: [2048]u8 = undefined;
    var decoded_children: [3]Component = undefined;
    var text: [512]u8 = undefined;

    const encoded = try region.toMarkdown(&markdown);
    const decoded = try Region.fromMarkdown(encoded, &decoded_children, &text);

    try std.testing.expect(std.mem.indexOf(u8, encoded, ":::region\ntag: main\nlabel: Browser and WASM\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "--- component ---\n:::card") != null);
    try std.testing.expectEqual(RegionTag.main, decoded.tag);
    try std.testing.expectEqualStrings("Browser and WASM", decoded.label);
    try std.testing.expectEqual(@as(usize, children.len), decoded.children.len);
    for (children, decoded.children) |expected, actual| {
        try expectSameComponent(expected, actual);
    }
}

test "region markdown codec rejects unsupported landmarks and empty content" {
    var children: [2]Component = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Region.fromMarkdown(":::region\ntag: aside\nlabel: Side\n--- component ---\nNo\n:::", &children, &text));
    try std.testing.expectError(error.InvalidMarkdown, Region.fromMarkdown(":::region\ntag: main\nlabel: Empty\n:::", &children, &text));
    try std.testing.expectError(error.UnsupportedMarkdown, Region.fromMarkdown(":::region\ntag: article\nlabel: Body\n--- component ---\n:::unknown\nvalue: no\n:::\n:::", &children, &text));
}

test "markdown codecs roundtrip academy content blocks" {
    var markdown: [768]u8 = undefined;
    var text: [512]u8 = undefined;

    const heading_markdown = try (Heading{ .level = 2, .value = "DNS & TLS: simple path" }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings("## DNS & TLS\\: simple path", heading_markdown);
    const heading = try Heading.fromMarkdown(heading_markdown, &text);
    try std.testing.expectEqual(@as(u8, 2), heading.level);
    try std.testing.expectEqualStrings("DNS & TLS: simple path", heading.value);

    const items = [_][]const u8{ "Browser asks", "Resolver answers", "Cache remembers" };
    const list_markdown = try (List{ .ordered = true, .items = &items }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings("1. Browser asks\n2. Resolver answers\n3. Cache remembers", list_markdown);
    var decoded_items: [3][]const u8 = undefined;
    const list = try List.fromMarkdown(list_markdown, &decoded_items, &text);
    try std.testing.expect(list.ordered);
    try std.testing.expectEqualStrings("Resolver answers", list.items[1]);

    const callout_markdown = try (Callout{ .value = "A name is not identity." }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings("> A name is not identity\\.", callout_markdown);
    const callout = try Callout.fromMarkdown(callout_markdown, &text);
    try std.testing.expectEqualStrings("A name is not identity.", callout.value);

    const aside_markdown = try (Aside{ .title = "Mental model", .body = "A capability opens one specific door." }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::aside\ntitle: Mental model\nbody: A capability opens one specific door\\.\n:::", aside_markdown);
    const aside = try Aside.fromMarkdown(aside_markdown, &text);
    try std.testing.expectEqualStrings("Mental model", aside.title);
    try std.testing.expectEqualStrings("A capability opens one specific door.", aside.body);

    const lines = [_][]const u8{ "const port = 443;", "try connect(port);" };
    const code_markdown = try (CodeBlock{ .language = "zig", .lines = &lines }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings("```zig\nconst port = 443;\ntry connect(port);\n```", code_markdown);
    var decoded_lines: [2][]const u8 = undefined;
    const code = try CodeBlock.fromMarkdown(code_markdown, &decoded_lines);
    try std.testing.expectEqualStrings("zig", code.language);
    try std.testing.expectEqualStrings("try connect(port);", code.lines[1]);
}

test "markdown codecs reject unsupported or ambiguous input" {
    var text: [128]u8 = undefined;
    var items: [2][]const u8 = undefined;
    var lines: [2][]const u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Heading.fromMarkdown("#### Too deep", &text));
    try std.testing.expectError(error.InvalidMarkdown, Heading.fromMarkdown("#", &text));
    try std.testing.expectError(error.InvalidMarkdown, List.fromMarkdown("1. First\n3. Skips", &items, &text));
    try std.testing.expectError(error.InvalidMarkdown, List.fromMarkdown("- ", &items, &text));
    try std.testing.expectError(error.UnsupportedMarkdown, Callout.fromMarkdown("plain paragraph", &text));
    try std.testing.expectError(error.InvalidMarkdown, Aside.fromMarkdown(":::aside\ntitle: Missing body\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, CodeBlock.fromMarkdown("```zig\nbad ``` fence\n```", &lines));
}

test "markdown directives roundtrip academy cards resources and progress" {
    var markdown: [1024]u8 = undefined;
    var text: [512]u8 = undefined;

    const card_markdown = try (Card{ .title = "Router boundary", .detail = "Forwards packets, does not own the app." }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::card\ntitle: Router boundary\ndetail: Forwards packets, does not own the app\\.\n:::", card_markdown);
    const card = try Card.fromMarkdown(card_markdown, &text);
    try std.testing.expectEqualStrings("Router boundary", card.title);
    try std.testing.expectEqualStrings("Forwards packets, does not own the app.", card.detail);

    const resources = [_]ResourceItem{
        .{ .id = 41001, .label = "DNS simulator", .href = "#/demo/dns", .detail = "Watch a resolver answer." },
        .{ .id = 41002, .label = "TLS walkthrough", .href = "#/demo/tls", .detail = "Follow protected bytes." },
    };
    const resource_markdown = try (ResourceList{ .items = &resources }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::resources\nitem: 41001\nlabel: DNS simulator\nhref: \\#/demo/dns\ndetail: Watch a resolver answer\\.\nitem: 41002\nlabel: TLS walkthrough\nhref: \\#/demo/tls\ndetail: Follow protected bytes\\.\n:::", resource_markdown);
    var decoded_resources: [2]ResourceItem = undefined;
    const resource_list = try ResourceList.fromMarkdown(resource_markdown, &decoded_resources, &text);
    try std.testing.expectEqual(@as(usize, 2), resource_list.items.len);
    try std.testing.expectEqual(@as(u32, 41002), resource_list.items[1].id);
    try std.testing.expectEqualStrings("TLS walkthrough", resource_list.items[1].label);
    try std.testing.expectEqualStrings("#/demo/tls", resource_list.items[1].href);

    const progress_markdown = try (ProgressSummary{ .id = 42001, .label = "Academy progress", .completed = 6, .total = 10 }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::progress\nid: 42001\nlabel: Academy progress\ncompleted: 6\ntotal: 10\n:::", progress_markdown);
    const progress = try ProgressSummary.fromMarkdown(progress_markdown, &text);
    try std.testing.expectEqual(@as(u32, 42001), progress.id);
    try std.testing.expectEqualStrings("Academy progress", progress.label);
    try std.testing.expectEqual(@as(u32, 6), progress.completed);
    try std.testing.expectEqual(@as(u32, 10), progress.total);
}

test "markdown directives reject malformed academy blocks" {
    var text: [128]u8 = undefined;
    var resources: [2]ResourceItem = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Card.fromMarkdown(":::card\ntitle: Missing detail\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, ResourceList.fromMarkdown(":::resources\nitem: 1\nlabel: Missing href\ndetail: No\n:::", &resources, &text));
    try std.testing.expectError(error.InvalidMarkdown, ResourceList.fromMarkdown(":::resources\n:::", &resources, &text));
    try std.testing.expectError(error.InvalidMarkdown, ProgressSummary.fromMarkdown(":::progress\nid: 1\nlabel: Bad\ncompleted: 11\ntotal: 10\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, ProgressSummary.fromMarkdown(":::progress\nid: 1\nlabel: Bad\ncompleted: 0\ntotal: 0\n:::", &text));
}

test "markdown directives roundtrip learning order blocks" {
    var markdown: [1536]u8 = undefined;
    var text: [768]u8 = undefined;

    const steps = [_]StepItem{
        .{ .id = 43001, .state = .done, .title = "Name the actor", .detail = "Find which component is asking for authority." },
        .{ .id = 43002, .state = .current, .title = "Trace the boundary", .detail = "Follow the request into the host." },
    };
    const step_markdown = try (StepList{ .steps = &steps }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::steps\nstep: 43001\nstate: done\ntitle: Name the actor\ndetail: Find which component is asking for authority\\.\nstep: 43002\nstate: current\ntitle: Trace the boundary\ndetail: Follow the request into the host\\.\n:::", step_markdown);
    var decoded_steps: [2]StepItem = undefined;
    const step_list = try StepList.fromMarkdown(step_markdown, &decoded_steps, &text);
    try std.testing.expectEqual(@as(usize, 2), step_list.steps.len);
    try std.testing.expectEqual(StepState.current, step_list.steps[1].state);
    try std.testing.expectEqualStrings("Trace the boundary", step_list.steps[1].title);

    const definitions = [_]DefinitionItem{
        .{ .id = 44001, .term = "Capability", .detail = "A concrete permission to do one thing." },
        .{ .id = 44002, .term = "Receipt", .detail = "A signed record that work happened." },
    };
    const definition_markdown = try (DefinitionList{ .items = &definitions }).toMarkdown(&markdown);
    var decoded_definitions: [2]DefinitionItem = undefined;
    const definition_list = try DefinitionList.fromMarkdown(definition_markdown, &decoded_definitions, &text);
    try std.testing.expectEqual(@as(usize, 2), definition_list.items.len);
    try std.testing.expectEqual(@as(u32, 44002), definition_list.items[1].id);
    try std.testing.expectEqualStrings("Receipt", definition_list.items[1].term);

    const events = [_]TimelineEvent{
        .{ .id = 45001, .time = "t0", .title = "Request starts", .detail = "The UI asks for a capability." },
        .{ .id = 45002, .time = "t1", .title = "Receipt lands", .detail = "The result is tied to identity." },
    };
    const timeline_markdown = try (Timeline{ .events = &events }).toMarkdown(&markdown);
    var decoded_events: [2]TimelineEvent = undefined;
    const timeline = try Timeline.fromMarkdown(timeline_markdown, &decoded_events, &text);
    try std.testing.expectEqual(@as(usize, 2), timeline.events.len);
    try std.testing.expectEqualStrings("t1", timeline.events[1].time);
    try std.testing.expectEqualStrings("Receipt lands", timeline.events[1].title);
}

test "markdown directives reject malformed learning order blocks" {
    var text: [128]u8 = undefined;
    var steps: [2]StepItem = undefined;
    var definitions: [2]DefinitionItem = undefined;
    var events: [2]TimelineEvent = undefined;

    try std.testing.expectError(error.InvalidMarkdown, StepList.fromMarkdown(":::steps\n:::", &steps, &text));
    try std.testing.expectError(error.InvalidMarkdown, StepList.fromMarkdown(":::steps\nstep: 1\nstate: maybe\ntitle: Broken\ndetail: Bad state\n:::", &steps, &text));
    try std.testing.expectError(error.InvalidMarkdown, DefinitionList.fromMarkdown(":::definitions\nitem: 1\nterm: Missing detail\n:::", &definitions, &text));
    try std.testing.expectError(error.InvalidMarkdown, Timeline.fromMarkdown(":::timeline\nevent: 1\ntime: t0\ntitle: Missing detail\n:::", &events, &text));
}

test "markdown directives roundtrip interactive lesson blocks" {
    var markdown: [1536]u8 = undefined;
    var text: [768]u8 = undefined;

    const details_markdown = try (Details{ .id = 46001, .summary = "Why DNS cache matters", .body = "Caching avoids repeating the same network trip.", .open = true }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::details\nid: 46001\nopen: true\nsummary: Why DNS cache matters\nbody: Caching avoids repeating the same network trip\\.\n:::", details_markdown);
    const details = try Details.fromMarkdown(details_markdown, &text);
    try std.testing.expectEqual(@as(u32, 46001), details.id);
    try std.testing.expect(details.open);
    try std.testing.expectEqualStrings("Why DNS cache matters", details.summary);

    const figure_markdown = try (Figure{ .src = "/assets/dns.png", .alt = "DNS request path", .caption = "A name becomes a routable address." }).toMarkdown(&markdown);
    try std.testing.expectEqualStrings(":::figure\nsrc: /assets/dns\\.png\nalt: DNS request path\ncaption: A name becomes a routable address\\.\n:::", figure_markdown);
    const figure = try Figure.fromMarkdown(figure_markdown, &text);
    try std.testing.expectEqualStrings("/assets/dns.png", figure.src);
    try std.testing.expectEqualStrings("DNS request path", figure.alt);

    const options = [_]ChoiceOption{
        .{ .id = 47001, .label = "The browser owns every packet" },
        .{ .id = 47002, .label = "The resolver answers name lookups", .selected = true },
    };
    const choice_markdown = try (ChoiceGroup{ .id = 47000, .legend = "Who answers DNS?", .options = &options }).toMarkdown(&markdown);
    var decoded_options: [2]ChoiceOption = undefined;
    const choice = try ChoiceGroup.fromMarkdown(choice_markdown, &decoded_options, &text);
    try std.testing.expectEqual(@as(u32, 47000), choice.id);
    try std.testing.expectEqualStrings("Who answers DNS?", choice.legend);
    try std.testing.expectEqual(@as(usize, 2), choice.options.len);
    try std.testing.expect(choice.options[1].selected);
    try std.testing.expectEqualStrings("The resolver answers name lookups", choice.options[1].label);
}

test "markdown directives reject malformed interactive lesson blocks" {
    var text: [128]u8 = undefined;
    var options: [2]ChoiceOption = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Details.fromMarkdown(":::details\nid: 1\nopen: maybe\nsummary: Bad\nbody: Bad\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, Figure.fromMarkdown(":::figure\nsrc: /x.png\nalt: Missing caption\n:::", &text));
    try std.testing.expectError(error.InvalidMarkdown, ChoiceGroup.fromMarkdown(":::choice\nid: 1\nlegend: Empty\n:::", &options, &text));
    try std.testing.expectError(error.InvalidMarkdown, ChoiceGroup.fromMarkdown(":::choice\nid: 1\nlegend: Bad\noption: 2\nselected: maybe\nlabel: Bad\n:::", &options, &text));
}

test "markdown directives roundtrip navigation and table blocks" {
    var markdown: [2048]u8 = undefined;
    var text: [768]u8 = undefined;

    const crumbs = [_]BreadcrumbItem{
        .{ .id = 48001, .label = "Academy", .href = "#/academy" },
        .{ .id = 48002, .label = "DNS", .href = "#/academy/dns", .current = true },
    };
    const breadcrumb_markdown = try (Breadcrumb{ .items = &crumbs }).toMarkdown(&markdown);
    var decoded_crumbs: [2]BreadcrumbItem = undefined;
    const breadcrumb = try Breadcrumb.fromMarkdown(breadcrumb_markdown, &decoded_crumbs, &text);
    try std.testing.expectEqual(@as(usize, 2), breadcrumb.items.len);
    try std.testing.expect(breadcrumb.items[1].current);
    try std.testing.expectEqualStrings("#/academy/dns", breadcrumb.items[1].href);

    const nav_items = [_]NavItem{
        .{ .id = 49001, .label = "Systems", .href = "#/systems", .active = true },
        .{ .id = 49002, .label = "Security", .href = "#/security" },
    };
    const nav_markdown = try (Nav{ .label = "Academy sections", .items = &nav_items }).toMarkdown(&markdown);
    var decoded_nav_items: [2]NavItem = undefined;
    const nav = try Nav.fromMarkdown(nav_markdown, &decoded_nav_items, &text);
    try std.testing.expectEqualStrings("Academy sections", nav.label);
    try std.testing.expect(nav.items[0].active);
    try std.testing.expectEqualStrings("Security", nav.items[1].label);

    const headers = [_]TableCell{
        .{ .value = "Layer" },
        .{ .value = "Owner", .alignment = .end },
    };
    const row_cells = [_]TableCell{
        .{ .value = "DNS" },
        .{ .value = "Resolver", .alignment = .end },
        .{ .value = "TLS" },
        .{ .value = "Endpoint", .alignment = .end },
    };
    const rows = [_]TableRow{
        .{ .id = 50001, .cells = row_cells[0..2] },
        .{ .id = 50002, .cells = row_cells[2..4] },
    };
    const table_markdown = try (Table{ .id = 50000, .headers = &headers, .rows = &rows }).toMarkdown(&markdown);
    var decoded_rows: [2]TableRow = undefined;
    var decoded_cells: [6]TableCell = undefined;
    const table = try Table.fromMarkdown(table_markdown, &decoded_rows, &decoded_cells, &text);
    try std.testing.expectEqual(@as(u32, 50000), table.id);
    try std.testing.expectEqual(@as(usize, 2), table.headers.len);
    try std.testing.expectEqual(ui.TextAlign.end, table.headers[1].alignment);
    try std.testing.expectEqual(@as(u32, 50002), table.rows[1].id);
    try std.testing.expectEqualStrings("Endpoint", table.rows[1].cells[1].value);
}

test "markdown directives reject malformed navigation and table blocks" {
    var text: [128]u8 = undefined;
    var crumbs: [2]BreadcrumbItem = undefined;
    var nav_items: [2]NavItem = undefined;
    var rows: [2]TableRow = undefined;
    var cells: [6]TableCell = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Breadcrumb.fromMarkdown(":::breadcrumb\n:::", &crumbs, &text));
    try std.testing.expectError(error.InvalidMarkdown, Breadcrumb.fromMarkdown(":::breadcrumb\nitem: 1\ncurrent: maybe\nhref: #\nlabel: Bad\n:::", &crumbs, &text));
    try std.testing.expectError(error.InvalidMarkdown, Nav.fromMarkdown(":::nav\nlabel: Empty\n:::", &nav_items, &text));
    try std.testing.expectError(error.InvalidMarkdown, Nav.fromMarkdown(":::nav\nlabel: Bad\nitem: 1\nactive: maybe\nhref: #\nlabel: Bad\n:::", &nav_items, &text));
    try std.testing.expectError(error.InvalidMarkdown, Table.fromMarkdown(":::table\nid: 1\n:::", &rows, &cells, &text));
    try std.testing.expectError(error.InvalidMarkdown, Table.fromMarkdown(":::table\nid: 1\nheader: diagonal Bad\nrow: 2\ncell: start Value\n:::", &rows, &cells, &text));
}

test "semantic html codecs roundtrip heading list callout and code block" {
    var html: [512]u8 = undefined;
    var text: [512]u8 = undefined;

    const heading_html = try (Heading{ .level = 1, .value = "How DNS Works" }).toHtml(&html);
    try std.testing.expectEqualStrings("<h1 data-er-component=\"heading\">How DNS Works</h1>", heading_html);
    const heading = try Heading.fromHtml(heading_html, &text);
    try std.testing.expectEqual(@as(u8, 1), heading.level);
    try std.testing.expectEqualStrings("How DNS Works", heading.value);

    const items = [_][]const u8{ "Name", "Address", "Cache" };
    const list_html = try (List{ .ordered = true, .items = &items }).toHtml(&html);
    var decoded_items: [3][]const u8 = undefined;
    const list = try List.fromHtml(list_html, &decoded_items, &text);
    try std.testing.expect(list.ordered);
    try std.testing.expectEqual(@as(usize, 3), list.items.len);
    try std.testing.expectEqualStrings("Address", list.items[1]);

    const callout_html = try (Callout{ .value = "TLS protects the trip, not every endpoint." }).toHtml(&html);
    try std.testing.expectEqualStrings("<blockquote data-er-component=\"callout\">TLS protects the trip, not every endpoint.</blockquote>", callout_html);
    const callout = try Callout.fromHtml(callout_html, &text);
    try std.testing.expectEqualStrings("TLS protects the trip, not every endpoint.", callout.value);

    const lines = [_][]const u8{ "const port = 443;", "try connect(port);" };
    const code_html = try (CodeBlock{ .language = "zig", .lines = &lines }).toHtml(&html);
    var decoded_lines: [2][]const u8 = undefined;
    const code = try CodeBlock.fromHtml(code_html, &decoded_lines, &text);
    try std.testing.expectEqualStrings("zig", code.language);
    try std.testing.expectEqual(@as(usize, 2), code.lines.len);
    try std.testing.expectEqualStrings("try connect(port);", code.lines[1]);
}

test "semantic html codecs escape and reject malformed content" {
    var html: [512]u8 = undefined;
    var text: [256]u8 = undefined;
    var items: [2][]const u8 = undefined;
    var lines: [2][]const u8 = undefined;

    const heading_html = try (Heading{ .level = 2, .value = "TLS < DNS & TPM" }).toHtml(&html);
    try std.testing.expectEqualStrings("<h2 data-er-component=\"heading\">TLS &lt; DNS &amp; TPM</h2>", heading_html);
    const heading = try Heading.fromHtml(heading_html, &text);
    try std.testing.expectEqualStrings("TLS < DNS & TPM", heading.value);

    try std.testing.expectError(error.InvalidHtml, Heading.fromHtml("<h4 data-er-component=\"heading\">Too deep</h4>", &text));
    try std.testing.expectError(error.InvalidHtml, List.fromHtml("<ul data-er-component=\"list\"><script>x()</script></ul>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, Callout.fromHtml("<blockquote>plain quote</blockquote>", &text));
    try std.testing.expectError(error.InvalidHtml, CodeBlock.fromHtml("<pre><code>plain</code></pre>", &lines, &text));
}

test "semantic components render through scene primitives" {
    var commands: [64]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    const list_items = [_][]const u8{ "DNS query leaves the device", "Resolver answers with an address" };

    try (Heading{ .level = 2, .value = "Lookup path" }).render(&scene, ui.Rect.init(0, 0, 360, 64), .{});
    try (List{ .items = &list_items }).render(&scene, ui.Rect.init(0, 70, 360, 110), .{});
    try (Callout{ .value = "A name is a lookup, not an identity." }).render(&scene, ui.Rect.init(0, 190, 360, 72), .{});
    try (CodeBlock{ .language = "zig", .lines = &.{"const dns = lookup(name);"} }).render(&scene, ui.Rect.init(0, 272, 360, 64), .{});

    try std.testing.expect(hasText(scene.written(), "Lookup path"));
    try std.testing.expect(hasTextContaining(scene.written(), "DNS query"));
    try std.testing.expect(hasTextContaining(scene.written(), "lookup, not an identity"));
    try std.testing.expect(hasText(scene.written(), "const dns = lookup(name);"));
}

test "article list item expands around wrapped titles" {
    const short_article = ArticleListItem{
        .id = 811,
        .category = "Episode 01",
        .meta = "Arc 1",
        .title = "Short Title",
        .summary = "Brief summary.",
    };
    const long_article = ArticleListItem{
        .id = 812,
        .category = "Episode 17",
        .meta = "Arc 2",
        .title = "The Internet Already Connects Everything. Platforms Keep It Apart.",
        .summary = "Show why TCP and UDP move bytes, but platforms still trap identity, data, contacts, and meaning.",
    };
    const short_height = short_article.height(420.0);
    const long_height = long_article.height(420.0);
    try std.testing.expect(long_height > short_height);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try long_article.render(&scene, ui.Rect.init(0.0, 0.0, 420.0, long_height), .{});
    try long_article.collectInteractions(&collector, ui.Rect.init(0.0, 0.0, 420.0, long_height));
    const hit = ui_input.hitTest(collector.written(), 20, 20).?;
    try std.testing.expectEqual(@as(u32, 812), hit.id);
    try std.testing.expect(hasText(scene.written(), "Episode 17"));
    try std.testing.expect(hasText(scene.written(), "The Internet Already Connects"));
    try std.testing.expect(hasTextContaining(scene.written(), "Show why TCP"));
}

fn expectSameComponent(expected: Component, actual: Component) !void {
    try std.testing.expectEqual(std.meta.activeTag(expected), std.meta.activeTag(actual));
    switch (expected) {
        .text => |component| try std.testing.expectEqualStrings(component.value, actual.text.value),
        .card => |component| {
            try std.testing.expectEqualStrings(component.title, actual.card.title);
            try std.testing.expectEqualStrings(component.detail, actual.card.detail);
        },
        .badge => |component| try std.testing.expectEqualStrings(component.label, actual.badge.label),
        .avatar => |component| try std.testing.expectEqualStrings(component.label, actual.avatar.label),
        .kbd => |component| try std.testing.expectEqualStrings(component.label, actual.kbd.label),
        .separator => {},
        .button => |component| {
            try std.testing.expectEqual(component.id, actual.button.id);
            try std.testing.expectEqualStrings(component.label, actual.button.label);
        },
        .input => |component| {
            try std.testing.expectEqual(component.id, actual.input.id);
            try std.testing.expectEqualStrings(component.placeholder, actual.input.placeholder);
        },
        .textarea => |component| {
            try std.testing.expectEqual(component.id, actual.textarea.id);
            try std.testing.expectEqualStrings(component.placeholder, actual.textarea.placeholder);
        },
        .select => |component| {
            try std.testing.expectEqual(component.id, actual.select.id);
            try std.testing.expectEqualStrings(component.label, actual.select.label);
        },
        .checkbox => |component| {
            try std.testing.expectEqual(component.id, actual.checkbox.id);
            try std.testing.expectEqualStrings(component.label, actual.checkbox.label);
            try std.testing.expectEqual(component.checked, actual.checkbox.checked);
        },
        .switch_control => |component| {
            try std.testing.expectEqual(component.id, actual.switch_control.id);
            try std.testing.expectEqualStrings(component.label, actual.switch_control.label);
            try std.testing.expectEqual(component.checked, actual.switch_control.checked);
        },
        .progress => |component| try std.testing.expect(@abs(component.value - actual.progress.value) < 0.001),
        .slider => |component| {
            try std.testing.expectEqual(component.id, actual.slider.id);
            try std.testing.expectEqualStrings(component.label, actual.slider.label);
            try std.testing.expect(@abs(component.value - actual.slider.value) < 0.001);
        },
        .row_item => |component| {
            try std.testing.expectEqual(component.id, actual.row_item.id);
            try std.testing.expectEqualStrings(component.title, actual.row_item.title);
            try std.testing.expectEqualStrings(component.detail, actual.row_item.detail);
        },
    }
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasTextContaining(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.indexOf(u8, text_command.value, value) != null) return true,
        else => {},
    };
    return false;
}

fn textCommand(commands: []const ui.Command, value: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return command,
        else => {},
    };
    return null;
}

fn hasIcon(commands: []const ui.Command, value: icon.Icon) bool {
    const icon_id = icon.id(value);
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

fn hasShadow(commands: []const ui.Command) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (rect.mode == .shadow and rect.shadow > 0.0) return true,
        else => {},
    };
    return false;
}
