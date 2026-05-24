const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const icon = @import("icon.zig");
const ui_input = @import("input.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");
const codec = @import("ui_codec.zig");
const component_common = @import("ui_component_common.zig");
const aside_component = @import("ui/components/Aside.zig");
const breadcrumb_component = @import("ui/components/Breadcrumb.zig");
const definition_list_component = @import("ui/components/DefinitionList.zig");
const details_component = @import("ui/components/Details.zig");
const figure_component = @import("ui/components/Figure.zig");
const nav_component = @import("ui/components/Nav.zig");
const progress_summary_component = @import("ui/components/ProgressSummary.zig");
const resource_list_component = @import("ui/components/ResourceList.zig");
const step_list_component = @import("ui/components/StepList.zig");
const table_component = @import("ui/components/Table.zig");

const tree_layout_magic = "ERUL001\x00";
const tree_layout_size = 16;
const slot_layout_magic = "ERUS001\x00";
const slot_layout_size = 16;

pub const Error = component_common.Error;
pub const HtmlError = component_common.HtmlError;
pub const MarkdownError = component_common.MarkdownError;
pub const RegistryError = component_common.RegistryError;
pub const ComponentDescriptor = component_common.ComponentDescriptor;
pub const ComponentRegistry = component_common.ComponentRegistry;

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

    pub fn toObject(self: Component, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(self, ui_out, object_out, req, epoch);
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
        var nodes: [1]ui.Node = undefined;
        const root = codec.decodeView(view, &nodes) catch return error.Corrupt;
        if (root.stack.children.len != 1) return error.Corrupt;
        return fromNode(root.stack.children[0]);
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

pub const ArticleCard = struct {
    id: u32,
    category: []const u8,
    meta: []const u8,
    title: []const u8,
    summary: []const u8,
};

pub const ArticleListItem = struct {
    id: u32,
    category: []const u8,
    meta: []const u8,
    title: []const u8,
    summary: []const u8,
};

pub const CodeBlock = struct {
    language: []const u8 = "",
    lines: []const []const u8,

    pub fn render(self: CodeBlock, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderCodeBlock(scene, bounds, self, options);
    }

    pub fn toHtml(self: CodeBlock, out: []u8) HtmlError![]u8 {
        return writeCodeBlockHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_lines: [][]const u8, text_out: []u8) HtmlError!CodeBlock {
        return readCodeBlockHtml(html, out_lines, text_out);
    }

    pub fn toMarkdown(self: CodeBlock, out: []u8) MarkdownError![]u8 {
        return writeCodeBlockMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_lines: [][]const u8) MarkdownError!CodeBlock {
        return readCodeBlockMarkdown(markdown, out_lines);
    }
};

pub const Heading = struct {
    level: u8,
    value: []const u8,

    pub fn render(self: Heading, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderHeading(scene, bounds, self, options);
    }

    pub fn toHtml(self: Heading, out: []u8) HtmlError![]u8 {
        return writeHeadingHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Heading {
        return readHeadingHtml(html, text_out);
    }

    pub fn toMarkdown(self: Heading, out: []u8) MarkdownError![]u8 {
        return writeHeadingMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Heading {
        return readHeadingMarkdown(markdown, text_out);
    }
};

pub const List = struct {
    ordered: bool = false,
    items: []const []const u8,

    pub fn render(self: List, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderList(scene, bounds, self, options);
    }

    pub fn toHtml(self: List, out: []u8) HtmlError![]u8 {
        return writeListHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_items: [][]const u8, text_out: []u8) HtmlError!List {
        return readListHtml(html, out_items, text_out);
    }

    pub fn toMarkdown(self: List, out: []u8) MarkdownError![]u8 {
        return writeListMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_items: [][]const u8, text_out: []u8) MarkdownError!List {
        return readListMarkdown(markdown, out_items, text_out);
    }
};

pub const Callout = struct {
    value: []const u8,

    pub fn render(self: Callout, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderCallout(scene, bounds, self, options);
    }

    pub fn toHtml(self: Callout, out: []u8) HtmlError![]u8 {
        return writeCalloutHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Callout {
        return readCalloutHtml(html, text_out);
    }

    pub fn toMarkdown(self: Callout, out: []u8) MarkdownError![]u8 {
        return writeCalloutMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Callout {
        return readCalloutMarkdown(markdown, text_out);
    }
};

pub const Aside = aside_component.Aside;

pub const Details = details_component.Details;

pub const Figure = figure_component.Figure;

pub const ChoiceOption = struct {
    id: u32,
    label: []const u8,
    selected: bool = false,
};

pub const ChoiceGroup = struct {
    id: u32,
    legend: []const u8,
    options: []const ChoiceOption,

    pub fn render(self: ChoiceGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderChoiceGroup(scene, bounds, self, options);
    }

    pub fn toHtml(self: ChoiceGroup, out: []u8) HtmlError![]u8 {
        return writeChoiceGroupHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_options: []ChoiceOption, text_out: []u8) HtmlError!ChoiceGroup {
        return readChoiceGroupHtml(html, out_options, text_out);
    }

    pub fn toMarkdown(self: ChoiceGroup, out: []u8) MarkdownError![]u8 {
        return writeChoiceGroupMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_options: []ChoiceOption, text_out: []u8) MarkdownError!ChoiceGroup {
        return readChoiceGroupMarkdown(markdown, out_options, text_out);
    }
};

pub const StepState = step_list_component.StepState;
pub const StepItem = step_list_component.StepItem;
pub const StepList = step_list_component.StepList;

pub const BreadcrumbItem = breadcrumb_component.BreadcrumbItem;
pub const Breadcrumb = breadcrumb_component.Breadcrumb;

pub const DefinitionItem = definition_list_component.DefinitionItem;
pub const DefinitionList = definition_list_component.DefinitionList;

pub const TimelineEvent = struct {
    id: u32,
    time: []const u8,
    title: []const u8,
    detail: []const u8,
};

pub const Timeline = struct {
    events: []const TimelineEvent,

    pub fn render(self: Timeline, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderTimeline(scene, bounds, self, options);
    }

    pub fn toHtml(self: Timeline, out: []u8) HtmlError![]u8 {
        return writeTimelineHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_events: []TimelineEvent, text_out: []u8) HtmlError!Timeline {
        return readTimelineHtml(html, out_events, text_out);
    }

    pub fn toMarkdown(self: Timeline, out: []u8) MarkdownError![]u8 {
        return writeTimelineMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_events: []TimelineEvent, text_out: []u8) MarkdownError!Timeline {
        return readTimelineMarkdown(markdown, out_events, text_out);
    }
};

pub const ResourceItem = resource_list_component.ResourceItem;
pub const ResourceList = resource_list_component.ResourceList;

pub const ProgressSummary = progress_summary_component.ProgressSummary;

pub const NavItem = nav_component.NavItem;
pub const Nav = nav_component.Nav;

pub const RegionTag = enum {
    header,
    main,
    footer,
    section,
    article,
};

pub const Region = struct {
    tag: RegionTag,
    label: []const u8 = "",
    children: []const Component,

    pub fn render(self: Region, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderRegion(scene, bounds, self, options);
    }

    pub fn toHtml(self: Region, out: []u8) HtmlError![]u8 {
        return writeRegionHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_components: []Component, text_out: []u8) HtmlError!Region {
        return readRegionHtml(html, out_components, text_out);
    }

    pub fn toMarkdown(self: Region, out: []u8) MarkdownError![]u8 {
        return writeRegionMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError!Region {
        return readRegionMarkdown(markdown, out_components, text_out);
    }
};

pub const TableCell = table_component.TableCell;
pub const TableRow = table_component.TableRow;
pub const Table = table_component.Table;

pub fn registerAside(registry: *ComponentRegistry) RegistryError!void {
    return aside_component.register(registry);
}

pub fn registerBreadcrumb(registry: *ComponentRegistry) RegistryError!void {
    return breadcrumb_component.register(registry);
}

pub fn registerDefinitionList(registry: *ComponentRegistry) RegistryError!void {
    return definition_list_component.register(registry);
}

pub fn registerDetails(registry: *ComponentRegistry) RegistryError!void {
    return details_component.register(registry);
}

pub fn registerFigure(registry: *ComponentRegistry) RegistryError!void {
    return figure_component.register(registry);
}

pub fn registerNav(registry: *ComponentRegistry) RegistryError!void {
    return nav_component.register(registry);
}

pub fn registerProgressSummary(registry: *ComponentRegistry) RegistryError!void {
    return progress_summary_component.register(registry);
}

pub fn registerResourceList(registry: *ComponentRegistry) RegistryError!void {
    return resource_list_component.register(registry);
}

pub fn registerStepList(registry: *ComponentRegistry) RegistryError!void {
    return step_list_component.register(registry);
}

pub fn registerTable(registry: *ComponentRegistry) RegistryError!void {
    return table_component.register(registry);
}

pub fn renderComponent(scene: *ui.Scene, bounds: ui.Rect, component: Component, options: RenderOptions) ui.RenderError!void {
    switch (component) {
        .card => |card| try renderSurface(scene, bounds, card.title, card.detail, options),
        .badge => |badge| try renderBadge(scene, bounds, badge.label, options),
        .button => |button| try renderButton(scene, bounds, button, options),
        else => try ui.render(scene, component.node(), bounds, options.style),
    }
}

pub fn renderArticleCard(scene: *ui.Scene, bounds: ui.Rect, article: ArticleCard, options: RenderOptions) ui.RenderError!void {
    try renderSurface(scene, bounds, "", "", .{ .style = options.style, .surface_variant = .elevated });
    const inset = bounds.insetUniform(article_padding);
    const badge_width = @min(article_badge_max_width, @max(article_badge_min_width, inset.w * 0.28));
    try renderBadge(scene, ui.Rect.init(inset.x, inset.y, badge_width, article_badge_height), article.category, .{ .style = options.style, .badge_variant = .accent });
    try scene.pushAlignedText(ui.Rect.init(inset.x + badge_width + article_gap, inset.y + 6.0, @max(1.0, inset.w - badge_width - article_gap), article_meta_height), article.meta, options.style.muted, .end);
    try scene.pushWrappedText(ui.Rect.init(inset.x, inset.y + 42.0, inset.w - article_arrow_slot, 50.0), article.title, options.style.text, .{
        .line_height = 22.0,
        .average_char_width = 10.5,
        .max_lines = 2,
    });
    try scene.pushWrappedText(ui.Rect.init(inset.x, bounds.y + bounds.h - 58.0, inset.w - article_arrow_slot, 44.0), article.summary, options.style.muted, .{
        .line_height = 18.0,
        .average_char_width = 10.0,
        .max_lines = 2,
    });
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = article.id, .bounds = bounds });
}

pub fn articleListItemHeight(width: f32, article: ArticleListItem) f32 {
    const text_width = articleListTextWidth(width);
    const title_lines = wrappedLineCount(article.title, text_width, article_list_title_average_char_width, article_list_title_max_lines);
    const summary_lines = wrappedLineCount(article.summary, text_width, article_list_summary_average_char_width, article_list_summary_max_lines);
    const text_height = article_list_meta_height +
        article_list_meta_gap +
        @as(f32, @floatFromInt(title_lines)) * article_list_title_line_height +
        article_list_title_summary_gap +
        @as(f32, @floatFromInt(summary_lines)) * article_list_summary_line_height;
    return @max(article_list_min_height, article_list_padding_y * 2.0 + text_height);
}

pub fn renderArticleListItem(scene: *ui.Scene, bounds: ui.Rect, article: ArticleListItem, options: RenderOptions) ui.RenderError!void {
    const text_width = articleListTextWidth(bounds.w);
    const text_x = bounds.x + article_list_padding_x;
    const text_top = bounds.y + article_list_padding_y;
    const meta_bounds = ui.Rect.init(text_x, text_top, text_width, article_list_meta_height);
    const meta = if (article.meta.len != 0) article.meta else article.category;
    try scene.pushAlignedText(meta_bounds, article.category, options.style.accent, .start);
    try scene.pushAlignedText(meta_bounds, meta, options.style.muted, .end);

    const title_y = text_top + article_list_meta_height + article_list_meta_gap;
    const title_lines = wrappedLineCount(article.title, text_width, article_list_title_average_char_width, article_list_title_max_lines);
    const title_h = @as(f32, @floatFromInt(title_lines)) * article_list_title_line_height;
    try scene.pushWrappedText(ui.Rect.init(text_x, title_y, text_width, title_h), article.title, options.style.text, .{
        .line_height = article_list_title_line_height,
        .average_char_width = article_list_title_average_char_width,
        .max_lines = article_list_title_max_lines,
    });

    const summary_y = title_y + title_h + article_list_title_summary_gap;
    const summary_lines = wrappedLineCount(article.summary, text_width, article_list_summary_average_char_width, article_list_summary_max_lines);
    const summary_h = @as(f32, @floatFromInt(summary_lines)) * article_list_summary_line_height;
    try scene.pushWrappedText(ui.Rect.init(text_x, summary_y, text_width, summary_h), article.summary, options.style.muted, .{
        .line_height = article_list_summary_line_height,
        .average_char_width = article_list_summary_average_char_width,
        .max_lines = article_list_summary_max_lines,
    });

    const divider = ui.Rect.init(bounds.x, bounds.y + bounds.h - article_list_divider_height, bounds.w, article_list_divider_height);
    try scene.pushRect(divider, options.style.border, .fill, 0.0, 0.0);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = article.id, .bounds = bounds });
}

pub fn renderCodeBlock(scene: *ui.Scene, bounds: ui.Rect, block: CodeBlock, options: RenderOptions) ui.RenderError!void {
    const radius = surface_radius;
    try scene.pushRect(bounds, options.style.bg, .fill, radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, radius, 0.0);
    if (try scene.pushClip(bounds.insetUniform(code_clip_inset))) {
        defer scene.popClip();
        var y = bounds.y + code_padding_y;
        for (block.lines) |line| {
            if (y + code_line_height > bounds.y + bounds.h - code_padding_y) break;
            try scene.pushAlignedText(ui.Rect.init(bounds.x + code_padding_x, y, @max(1.0, bounds.w - code_padding_x * 2.0), code_text_height), line, options.style.accent, .start);
            y += code_line_height;
        }
    }
}

pub fn renderHeading(scene: *ui.Scene, bounds: ui.Rect, heading: Heading, options: RenderOptions) ui.RenderError!void {
    if (!validHeadingLevel(heading.level)) return;
    const line_height: f32 = switch (heading.level) {
        1 => heading_h1_line_h,
        2 => heading_h2_line_h,
        3 => heading_h3_line_h,
        else => unreachable,
    };
    const avg_width: f32 = switch (heading.level) {
        1 => heading_h1_avg_w,
        2 => heading_h2_avg_w,
        3 => heading_h3_avg_w,
        else => unreachable,
    };
    try scene.pushWrappedText(bounds, heading.value, options.style.text, .{
        .line_height = line_height,
        .average_char_width = avg_width,
        .max_lines = 3,
    });
}

pub fn renderList(scene: *ui.Scene, bounds: ui.Rect, list: List, options: RenderOptions) ui.RenderError!void {
    var y = bounds.y;
    for (list.items, 0..) |item, index| {
        if (y + list_item_h > bounds.y + bounds.h) break;
        const marker_bounds = ui.Rect.init(bounds.x, y + list_marker_y, list_marker_w, list_marker_h);
        if (list.ordered) {
            try scene.pushAlignedText(marker_bounds, orderedMarker(index), options.style.accent, .end);
        } else {
            try scene.pushRect(ui.Rect.init(bounds.x + 4.0, y + list_bullet_y, list_bullet_size, list_bullet_size), options.style.accent, .fill, list_bullet_size * 0.5, 0.0);
        }
        try scene.pushWrappedText(ui.Rect.init(bounds.x + list_text_x, y, @max(1.0, bounds.w - list_text_x), list_item_h), item, options.style.text, .{
            .line_height = list_line_h,
            .average_char_width = list_avg_w,
            .max_lines = 2,
        });
        y += list_item_h + list_item_gap;
    }
}

pub fn renderCallout(scene: *ui.Scene, bounds: ui.Rect, callout: Callout, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, callout_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, callout_radius, 0.0);
    try scene.pushRect(ui.Rect.init(bounds.x, bounds.y, callout_accent_w, bounds.h), options.style.accent, .fill, callout_radius, 0.0);
    try scene.pushWrappedText(bounds.insetLtrb(callout_text_x, callout_text_y, callout_text_x, callout_text_y), callout.value, options.style.text, .{
        .line_height = callout_line_h,
        .average_char_width = callout_avg_w,
        .max_lines = 4,
    });
}

pub fn renderChoiceGroup(scene: *ui.Scene, bounds: ui.Rect, group: ChoiceGroup, options: RenderOptions) ui.RenderError!void {
    if (group.options.len == 0) return;
    const style = options.style;
    try scene.pushRect(bounds, style.panel, .fill, choice_radius, 0.0);
    try scene.pushRect(bounds, style.border, .border, choice_radius, 0.0);

    const content_x = bounds.x + choice_padding_x;
    const content_w = @max(1.0, bounds.w - choice_padding_x * 2.0);
    var y = bounds.y + choice_padding_y;
    try scene.pushWrappedText(ui.Rect.init(content_x, y, content_w, choice_legend_h), group.legend, style.text, .{
        .line_height = choice_legend_line_h,
        .average_char_width = choice_legend_avg_w,
        .max_lines = choice_legend_max_lines,
    });
    y += choice_legend_h + choice_option_gap;

    const bottom = bounds.y + bounds.h - choice_padding_y;
    for (group.options) |option| {
        if (y + choice_option_h > bottom) break;
        const option_bounds = ui.Rect.init(content_x, y, content_w, choice_option_h);
        if (option.selected) {
            try scene.pushRect(option_bounds, style.row, .fill, choice_option_radius, 0.0);
        }
        const marker_bounds = ui.Rect.init(option_bounds.x + choice_marker_x, option_bounds.y + choice_marker_y, choice_marker_size, choice_marker_size);
        try scene.pushRect(marker_bounds, style.border, .border, choice_marker_size * 0.5, 0.0);
        if (option.selected) {
            try scene.pushRect(marker_bounds.insetUniform(choice_marker_selected_inset), style.accent, .fill, (choice_marker_size - choice_marker_selected_inset * 2.0) * 0.5, 0.0);
        }
        try scene.pushAlignedText(ui.Rect.init(option_bounds.x + choice_label_x, option_bounds.y + choice_label_y, @max(1.0, option_bounds.w - choice_label_x - choice_option_padding_x), choice_label_h), option.label, style.text, .start);
        try scene.pushHit(.{ .slot = 0, .kind = .button, .id = option.id, .bounds = option_bounds });
        y += choice_option_h + choice_option_gap;
    }
}

pub fn renderTimeline(scene: *ui.Scene, bounds: ui.Rect, timeline: Timeline, options: RenderOptions) ui.RenderError!void {
    if (timeline.events.len == 0) return;
    const style = options.style;
    try scene.pushRect(bounds, style.panel, .fill, timeline_radius, 0.0);
    try scene.pushRect(bounds, style.border, .border, timeline_radius, 0.0);

    var y = bounds.y + timeline_padding_y;
    const content_x = bounds.x + timeline_padding_x;
    const content_w = @max(1.0, bounds.w - timeline_padding_x * 2.0);
    const bottom = bounds.y + bounds.h - timeline_padding_y;
    for (timeline.events) |event| {
        if (y + timeline_event_h > bottom) break;
        const event_bounds = ui.Rect.init(content_x, y, content_w, timeline_event_h);
        const marker_bounds = ui.Rect.init(event_bounds.x + timeline_marker_x, event_bounds.y + timeline_marker_y, timeline_marker_size, timeline_marker_size);
        try scene.pushRect(marker_bounds, style.accent, .fill, timeline_marker_size * 0.5, 0.0);
        try scene.pushAlignedText(ui.Rect.init(event_bounds.x + timeline_text_x, event_bounds.y + timeline_time_y, timeline_time_w, timeline_time_h), event.time, style.accent, .start);
        try scene.pushAlignedText(ui.Rect.init(event_bounds.x + timeline_text_x + timeline_time_w + timeline_text_gap, event_bounds.y + timeline_title_y, @max(1.0, event_bounds.w - timeline_text_x - timeline_time_w - timeline_text_gap - timeline_text_padding_x), timeline_title_h), event.title, style.text, .start);
        try scene.pushWrappedText(ui.Rect.init(event_bounds.x + timeline_text_x, event_bounds.y + timeline_detail_y, @max(1.0, event_bounds.w - timeline_text_x - timeline_text_padding_x), timeline_detail_h), event.detail, style.muted, .{
            .line_height = timeline_detail_line_h,
            .average_char_width = timeline_detail_avg_w,
            .max_lines = timeline_detail_max_lines,
        });
        try scene.pushHit(.{ .slot = 0, .kind = .row_item, .id = event.id, .bounds = event_bounds });
        y += timeline_event_h + timeline_event_gap;
    }
}

pub fn renderRegion(scene: *ui.Scene, bounds: ui.Rect, region: Region, options: RenderOptions) ui.RenderError!void {
    if (region.children.len == 0) return;
    if (region.tag == .header or region.tag == .footer) {
        try scene.pushRect(bounds, options.style.panel, .fill, region_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, region_radius, 0.0);
    }

    var y = bounds.y + region_padding_y;
    const child_x = bounds.x + region_padding_x;
    const child_w = @max(1.0, bounds.w - region_padding_x * 2.0);
    const bottom = bounds.y + bounds.h - region_padding_y;
    for (region.children) |child| {
        const child_h = regionChildHeight(child);
        if (y + child_h > bottom) break;
        try renderComponent(scene, ui.Rect.init(child_x, y, child_w, child_h), child, options);
        y += child_h + region_child_gap;
    }
}

pub fn renderSurface(scene: *ui.Scene, bounds: ui.Rect, title: []const u8, detail: []const u8, options: RenderOptions) ui.RenderError!void {
    const style = options.style;
    const radius = switch (options.surface_variant) {
        .panel => surface_radius,
        .elevated => surface_radius + 2.0,
        .subtle => surface_radius,
    };
    if (options.surface_variant == .elevated) {
        try scene.pushRect(bounds.insetUniform(-1.0), surface_shadow, .shadow, radius, surface_shadow_size);
    }
    const fill_color = switch (options.surface_variant) {
        .panel, .elevated => style.panel,
        .subtle => style.row,
    };
    try scene.pushRect(bounds, fill_color, .fill, radius, 0.0);
    try scene.pushRect(bounds, style.border, .border, radius, 0.0);
    if (title.len == 0 and detail.len == 0) return;

    const title_bounds = ui.Rect.init(bounds.x + surface_padding, bounds.y + surface_padding, @max(1.0, bounds.w - surface_padding * 2.0), surface_title_height);
    if (title.len != 0) {
        try scene.pushAlignedText(title_bounds, title, style.text, .start);
    }
    if (detail.len != 0) {
        const detail_y = title_bounds.y + title_bounds.h + surface_detail_gap;
        const detail_bounds = ui.Rect.init(title_bounds.x, detail_y, title_bounds.w, @max(1.0, bounds.y + bounds.h - detail_y - surface_padding));
        try scene.pushWrappedText(detail_bounds, detail, style.muted, .{
            .line_height = surface_detail_height,
            .average_char_width = 8.5,
            .max_lines = 3,
        });
    }
}

fn renderBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    const style = options.style;
    const color = switch (options.badge_variant) {
        .accent => style.accent,
        .neutral => style.muted,
        .danger => ui.Color{ .r = 239, .g = 68, .b = 68 },
    };
    var fill = color;
    fill.a = badge_fill_alpha;
    const height = @min(badge_height, bounds.h);
    const badge_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - height) * 0.5, bounds.w, height);
    try scene.pushRect(badge_bounds, fill, .fill, height * 0.5, 0.0);
    try scene.pushAlignedText(badgeLabelBounds(badge_bounds), label, color, .center);
}

fn renderButton(scene: *ui.Scene, bounds: ui.Rect, button: Button, options: RenderOptions) ui.RenderError!void {
    const text_color = switch (options.button_variant) {
        .primary => options.style.bg,
        .outline => options.style.text,
        .ghost => options.style.muted,
    };
    const icon_color = text_color;
    switch (options.button_variant) {
        .primary => {
            try scene.pushRect(bounds, options.style.accent, .fill, button_radius, 0.0);
            try scene.pushRect(bounds, options.style.accent, .border, button_radius, 0.0);
        },
        .outline => {
            try scene.pushRect(bounds, options.style.panel, .fill, button_radius, 0.0);
            try scene.pushRect(bounds, options.style.border, .border, button_radius, 0.0);
        },
        .ghost => {
            try scene.pushRect(bounds, ui.Color.clear, .fill, button_radius, 0.0);
        },
    }
    try renderButtonContent(scene, bounds, button.label, text_color, icon_color, options.button_leading_icon, options.button_trailing_icon);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = button.id, .bounds = bounds });
}

fn buttonTextBounds(bounds: ui.Rect) ui.Rect {
    const margin = @min(button_label_padding, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + margin, bounds.y + (bounds.h - button_label_height) * 0.5, @max(1.0, bounds.w - margin * 2.0), button_label_height);
}

fn renderButtonContent(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, text_color: ui.Color, icon_color: ui.Color, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon) ui.RenderError!void {
    const has_leading = leading_icon != null;
    const has_trailing = trailing_icon != null;
    if (!has_leading and !has_trailing) {
        try scene.pushAlignedText(buttonTextBounds(bounds), label, text_color, .center);
        return;
    }

    const icon_count: usize = @intFromBool(has_leading) + @intFromBool(has_trailing);
    const label_w = estimatedButtonLabelWidth(label);
    const content_w = label_w +
        @as(f32, @floatFromInt(icon_count)) * button_icon_size +
        @as(f32, @floatFromInt(icon_count)) * button_icon_gap;
    var cursor_x = bounds.x + @max(button_content_min_x, (bounds.w - content_w) * 0.5);
    const icon_y = bounds.y + (bounds.h - button_icon_size) * 0.5;
    const text_y = bounds.y + (bounds.h - button_label_height) * 0.5;

    if (leading_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, button_icon_size, button_icon_size),
            .atlas_id = icon.atlasId(value),
            .color = icon_color,
        });
        cursor_x += button_icon_size + button_icon_gap;
    }

    try scene.pushAlignedText(ui.Rect.init(cursor_x, text_y, label_w, button_label_height), label, text_color, .start);
    cursor_x += label_w + button_icon_gap;

    if (trailing_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, button_icon_size, button_icon_size),
            .atlas_id = icon.atlasId(value),
            .color = icon_color,
        });
    }
}

fn estimatedButtonLabelWidth(label: []const u8) f32 {
    return @max(button_label_min_width, @as(f32, @floatFromInt(label.len)) * button_label_average_w);
}

fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(padding, @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

fn badgeLabelBounds(bounds: ui.Rect) ui.Rect {
    const padding = @min(badge_padding_x, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + padding, bounds.y + (bounds.h - badge_text_height) * 0.5, @max(1.0, bounds.w - padding * 2.0), badge_text_height);
}

const button_radius: f32 = 7.0;
const button_label_height: f32 = 16.0;
const button_label_padding: f32 = 14.0;
const button_label_average_w: f32 = 8.0;
const button_label_min_width: f32 = 8.0;
const button_icon_size: f32 = 18.0;
const button_icon_gap: f32 = 8.0;
const button_content_min_x: f32 = 14.0;
const badge_height: f32 = 24.0;
const badge_text_height: f32 = 13.0;
const badge_padding_x: f32 = 12.0;
const badge_fill_alpha: u8 = 48;
const surface_radius: f32 = 10.0;
const surface_padding: f32 = 16.0;
const surface_title_height: f32 = 18.0;
const surface_detail_height: f32 = 16.0;
const surface_detail_gap: f32 = 8.0;
const surface_shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
const surface_shadow_size: f32 = 8.0;
const article_padding: f32 = 18.0;
const article_gap: f32 = 12.0;
const article_badge_min_width: f32 = 96.0;
const article_badge_max_width: f32 = 140.0;
const article_badge_height: f32 = 24.0;
const article_meta_height: f32 = 12.0;
const article_arrow_slot: f32 = 24.0;
const article_list_padding_x: f32 = 6.0;
const article_list_padding_y: f32 = 16.0;
const article_list_arrow_slot: f32 = 34.0;
const article_list_min_height: f32 = 104.0;
const article_list_meta_height: f32 = 14.0;
const article_list_meta_gap: f32 = 10.0;
const article_list_title_line_height: f32 = 25.0;
const article_list_title_average_char_width: f32 = 10.5;
const article_list_title_max_lines: usize = 3;
const article_list_title_summary_gap: f32 = 8.0;
const article_list_summary_line_height: f32 = 18.0;
const article_list_summary_average_char_width: f32 = 9.0;
const article_list_summary_max_lines: usize = 3;
const article_list_divider_height: f32 = 1.0;
fn articleListTextWidth(width: f32) f32 {
    return @max(1.0, width - article_list_padding_x * 2.0 - article_list_arrow_slot);
}

fn wrappedLineCount(value: []const u8, width: f32, average_char_width: f32, max_lines: usize) usize {
    if (value.len == 0 or max_lines == 0) return 0;
    const char_capacity = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, width / average_char_width))));
    var byte_cursor: usize = 0;
    var line_count: usize = 0;
    while (line_count < max_lines) : (line_count += 1) {
        byte_cursor = ui.skipAsciiSpace(value, byte_cursor);
        if (byte_cursor >= value.len) return line_count;
        byte_cursor = ui.wrappedLine(value, byte_cursor, char_capacity).next;
    }
    return line_count;
}
const code_padding_x: f32 = 18.0;
const code_padding_y: f32 = 18.0;
const code_line_height: f32 = 17.0;
const code_text_height: f32 = 12.0;
const code_clip_inset: f32 = 1.0;
const heading_h1_line_h: f32 = 34.0;
const heading_h2_line_h: f32 = 26.0;
const heading_h3_line_h: f32 = 21.0;
const heading_h1_avg_w: f32 = 15.0;
const heading_h2_avg_w: f32 = 12.0;
const heading_h3_avg_w: f32 = 10.5;
const list_item_h: f32 = 42.0;
const list_item_gap: f32 = 4.0;
const list_marker_w: f32 = 24.0;
const list_marker_h: f32 = 14.0;
const list_marker_y: f32 = 4.0;
const list_bullet_y: f32 = 8.0;
const list_bullet_size: f32 = 5.0;
const list_text_x: f32 = 28.0;
const list_line_h: f32 = 18.0;
const list_avg_w: f32 = 9.0;
const callout_radius: f32 = 8.0;
const callout_accent_w: f32 = 4.0;
const callout_text_x: f32 = 18.0;
const callout_text_y: f32 = 14.0;
const callout_line_h: f32 = 18.0;
const callout_avg_w: f32 = 9.0;
const choice_radius: f32 = 8.0;
const choice_padding_x: f32 = 14.0;
const choice_padding_y: f32 = 14.0;
const choice_legend_h: f32 = 42.0;
const choice_legend_line_h: f32 = 20.0;
const choice_legend_avg_w: f32 = 9.5;
const choice_legend_max_lines: usize = 2;
const choice_option_h: f32 = 36.0;
const choice_option_gap: f32 = 6.0;
const choice_option_radius: f32 = 6.0;
const choice_option_padding_x: f32 = 10.0;
const choice_marker_x: f32 = 10.0;
const choice_marker_y: f32 = 10.0;
const choice_marker_size: f32 = 16.0;
const choice_marker_selected_inset: f32 = 4.0;
const choice_label_x: f32 = 36.0;
const choice_label_y: f32 = 10.0;
const choice_label_h: f32 = 14.0;
const timeline_radius: f32 = 8.0;
const timeline_padding_x: f32 = 12.0;
const timeline_padding_y: f32 = 12.0;
const timeline_event_h: f32 = 82.0;
const timeline_event_gap: f32 = 8.0;
const timeline_marker_x: f32 = 10.0;
const timeline_marker_y: f32 = 14.0;
const timeline_marker_size: f32 = 12.0;
const timeline_text_x: f32 = 34.0;
const timeline_time_y: f32 = 9.0;
const timeline_time_w: f32 = 74.0;
const timeline_time_h: f32 = 14.0;
const timeline_text_gap: f32 = 10.0;
const timeline_title_y: f32 = 9.0;
const timeline_title_h: f32 = 16.0;
const timeline_detail_y: f32 = 34.0;
const timeline_detail_h: f32 = 38.0;
const timeline_detail_line_h: f32 = 17.0;
const timeline_detail_avg_w: f32 = 8.5;
const timeline_detail_max_lines: usize = 2;
const timeline_text_padding_x: f32 = 10.0;
const region_radius: f32 = 8.0;
const region_padding_x: f32 = 12.0;
const region_padding_y: f32 = 12.0;
const region_child_gap: f32 = 10.0;
const region_text_h: f32 = 32.0;
const region_card_h: f32 = 88.0;
const region_badge_h: f32 = 28.0;
const region_button_h: f32 = 40.0;
const region_input_h: f32 = 40.0;
const region_row_h: f32 = 66.0;
const region_separator_h: f32 = 1.0;

fn regionChildHeight(component: Component) f32 {
    return switch (component) {
        .text => region_text_h,
        .card => region_card_h,
        .badge => region_badge_h,
        .separator => region_separator_h,
        .button => region_button_h,
        .input => region_input_h,
        .row_item => region_row_h,
        else => region_text_h,
    };
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

    pub fn toObject(self: Text, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .text = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Text {
        return switch (try Component.fromView(view)) {
            .text => |text| text,
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

    pub fn toObject(self: Button, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .button = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Button {
        return switch (try Component.fromView(view)) {
            .button => |button| button,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Card = struct {
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Card) ui.Node {
        return ui.cardNode(self.title, self.detail);
    }

    pub fn toObject(self: Card, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .card = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Card {
        return switch (try Component.fromView(view)) {
            .card => |card| card,
            else => error.UnsupportedComponent,
        };
    }

    pub fn toMarkdown(self: Card, out: []u8) MarkdownError![]u8 {
        return writeCardMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Card {
        return readCardMarkdown(markdown, text_out);
    }
};

pub const Badge = struct {
    label: []const u8,

    pub fn node(self: Badge) ui.Node {
        return ui.badgeNode(self.label);
    }

    pub fn toObject(self: Badge, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .badge = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Badge {
        return switch (try Component.fromView(view)) {
            .badge => |badge| badge,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Avatar = struct {
    label: []const u8,

    pub fn node(self: Avatar) ui.Node {
        return ui.avatarNode(self.label);
    }

    pub fn toObject(self: Avatar, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .avatar = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Avatar {
        return switch (try Component.fromView(view)) {
            .avatar => |avatar| avatar,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Kbd = struct {
    label: []const u8,

    pub fn node(self: Kbd) ui.Node {
        return ui.kbdNode(self.label);
    }

    pub fn toObject(self: Kbd, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .kbd = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Kbd {
        return switch (try Component.fromView(view)) {
            .kbd => |kbd| kbd,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Separator = struct {
    pub fn node(self: Separator) ui.Node {
        _ = self;
        return ui.separatorNode();
    }

    pub fn toObject(self: Separator, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .separator = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Separator {
        return switch (try Component.fromView(view)) {
            .separator => |separator| separator,
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

    pub fn toObject(self: Input, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .input = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Input {
        return switch (try Component.fromView(view)) {
            .input => |input| input,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Textarea = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Textarea) ui.Node {
        return ui.textareaNode(self.id, self.placeholder);
    }

    pub fn toObject(self: Textarea, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .textarea = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Textarea {
        return switch (try Component.fromView(view)) {
            .textarea => |textarea| textarea,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Select = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Select) ui.Node {
        return ui.selectNode(self.id, self.label);
    }

    pub fn toObject(self: Select, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .select = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Select {
        return switch (try Component.fromView(view)) {
            .select => |select| select,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Checkbox = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Checkbox) ui.Node {
        return ui.checkboxNode(self.id, self.label, self.checked);
    }

    pub fn toObject(self: Checkbox, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .checkbox = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Checkbox {
        return switch (try Component.fromView(view)) {
            .checkbox => |checkbox| checkbox,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Switch = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Switch) ui.Node {
        return ui.switchNode(self.id, self.label, self.checked);
    }

    pub fn toObject(self: Switch, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .switch_control = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Switch {
        return switch (try Component.fromView(view)) {
            .switch_control => |switch_control| switch_control,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Progress = struct {
    value: f32,

    pub fn node(self: Progress) ui.Node {
        return ui.progressNode(self.value);
    }

    pub fn toObject(self: Progress, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .progress = .{ .value = ui.clampUnit(self.value) } }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Progress {
        return switch (try Component.fromView(view)) {
            .progress => |progress| progress,
            else => error.UnsupportedComponent,
        };
    }
};

pub const Slider = struct {
    id: u32,
    label: []const u8,
    value: f32,

    pub fn node(self: Slider) ui.Node {
        return ui.sliderNode(self.id, self.label, self.value);
    }

    pub fn toObject(self: Slider, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .slider = .{ .id = self.id, .label = self.label, .value = ui.clampUnit(self.value) } }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!Slider {
        return switch (try Component.fromView(view)) {
            .slider => |slider| slider,
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

    pub fn toObject(self: RowItem, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return writeSingleComponentObject(.{ .row_item = self }, ui_out, object_out, req, epoch);
    }

    pub fn fromView(view: object.View) Error!RowItem {
        return switch (try Component.fromView(view)) {
            .row_item => |row| row,
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

    pub fn toObject(self: Stack, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
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

    pub fn toHtml(self: Stack, out: []u8) HtmlError![]u8 {
        return writeStackHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_components: []Component, text_out: []u8) HtmlError!Stack {
        return readStackHtml(html, out_components, text_out);
    }

    pub fn toMarkdown(self: Stack, out: []u8) MarkdownError![]u8 {
        return writeStackMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError!Stack {
        return readStackMarkdown(markdown, out_components, text_out);
    }
};

pub const StackTree = struct {
    axis: ui.Axis,
    gap: u16 = 8,
    padding: u16 = 0,
    children: []const object.View,

    pub fn toTreeObjects(self: StackTree, layout_out: []u8, tree_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?TreeObjects {
        if (self.children.len == 0 or self.children.len + 1 > object.max_children) return null;

        var layout_body: [tree_layout_size]u8 = undefined;
        encodeTreeLayout(self.axis, self.gap, self.padding, @intCast(self.children.len), &layout_body) orelse return null;
        const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(req, epoch, &layout_body) catch return null;

        var child_records: [tree_max_children]object.Child = undefined;
        if (self.children.len + 1 > child_records.len) return null;

        child_records[0] = childRecord(layout, 0);
        var logical_offset = child_records[0].logical_len;
        for (self.children, 0..) |child, index| {
            child_records[index + 1] = childRecord(child.canonical, logical_offset);
            logical_offset += child_records[index + 1].logical_len;
        }

        const tree = (object.NodeWriter{ .out = tree_out }).treeNode(req, epoch, child_records[0 .. self.children.len + 1]) catch return null;
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

    pub fn toObject(self: Slot, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
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

    pub fn toTreeObjects(self: SlotTree, layout_out: []u8, tree_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?TreeObjects {
        var layout_body: [slot_layout_size]u8 = undefined;
        encodeSlotLayout(self.id, &layout_body) orelse return null;
        const layout = (object.NodeWriter{ .out = layout_out }).bytesNode(req, epoch, &layout_body) catch return null;

        var children: [2]object.Child = undefined;
        children[0] = childRecord(layout, 0);
        children[1] = childRecord(self.child.canonical, children[0].logical_len);

        const tree = (object.NodeWriter{ .out = tree_out }).treeNode(req, epoch, &children) catch return null;
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
    _ = bytes.store16(out[10..12], gap);
    _ = bytes.store16(out[12..14], padding);
    _ = bytes.store16(out[14..16], child_count);
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
        .gap = bytes.load16(view.body[10..12]) orelse return error.Corrupt,
        .padding = bytes.load16(view.body[12..14]) orelse return error.Corrupt,
        .child_count = bytes.load16(view.body[14..16]) orelse return error.Corrupt,
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
    _ = bytes.store32(out[8..12], id);
}

fn decodeSlotLayout(view: object.View) Error!u32 {
    if (view.header.kind != .bytes or view.body.len != slot_layout_size) return error.Corrupt;
    if (!std.mem.eql(u8, view.body[0..slot_layout_magic.len], slot_layout_magic)) return error.Corrupt;
    return bytes.load32(view.body[8..12]) orelse error.Corrupt;
}

fn isSlotLayout(view: object.View) bool {
    return view.header.kind == .bytes and
        view.body.len == slot_layout_size and
        std.mem.eql(u8, view.body[0..slot_layout_magic.len], slot_layout_magic);
}

fn childRecord(canonical: []const u8, offset: u64) object.Child {
    const view = object.View.decode(canonical) catch unreachable;
    return object.Child.fromView(view, offset) catch unreachable;
}

fn sameId(left: [object.id_size]u8, right: [object.id_size]u8) bool {
    return std.mem.eql(u8, &left, &right);
}

fn writeSingleComponentObject(component: Component, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
    if (!writeComponentRecord(&writer, 0, component)) return null;
    return writer.objectNode(object_out, req, epoch);
}

fn writeComponentRecord(writer: *codec.Writer, index: usize, component: Component) bool {
    return switch (component) {
        .text => |text| blk: {
            const value = writer.string(text.value) orelse break :blk false;
            break :blk writer.record(index, .text, 0, value, .{});
        },
        .card => |card| blk: {
            const title = writer.string(card.title) orelse break :blk false;
            const detail = writer.string(card.detail) orelse break :blk false;
            break :blk writer.record(index, .card, 0, title, detail);
        },
        .badge => |badge| blk: {
            const label = writer.string(badge.label) orelse break :blk false;
            break :blk writer.record(index, .badge, 0, label, .{});
        },
        .avatar => |avatar| blk: {
            const label = writer.string(avatar.label) orelse break :blk false;
            break :blk writer.record(index, .avatar, 0, label, .{});
        },
        .kbd => |kbd| blk: {
            const label = writer.string(kbd.label) orelse break :blk false;
            break :blk writer.record(index, .kbd, 0, label, .{});
        },
        .separator => writer.record(index, .separator, 0, .{}, .{}),
        .button => |button| blk: {
            const label = writer.string(button.label) orelse break :blk false;
            break :blk writer.record(index, .button, button.id, label, .{});
        },
        .input => |input| blk: {
            const placeholder = writer.string(input.placeholder) orelse break :blk false;
            break :blk writer.record(index, .input, input.id, placeholder, .{});
        },
        .textarea => |textarea| blk: {
            const placeholder = writer.string(textarea.placeholder) orelse break :blk false;
            break :blk writer.record(index, .textarea, textarea.id, placeholder, .{});
        },
        .select => |select| blk: {
            const label = writer.string(select.label) orelse break :blk false;
            break :blk writer.record(index, .select, select.id, label, .{});
        },
        .checkbox => |checkbox| blk: {
            const label = writer.string(checkbox.label) orelse break :blk false;
            break :blk writer.record(index, .checkbox, checkbox.id, label, boolRef(checkbox.checked));
        },
        .switch_control => |switch_control| blk: {
            const label = writer.string(switch_control.label) orelse break :blk false;
            break :blk writer.record(index, .switch_control, switch_control.id, label, boolRef(switch_control.checked));
        },
        .progress => |progress| writer.record(index, .progress, 0, .{}, unitRef(progress.value)),
        .slider => |slider| blk: {
            const label = writer.string(slider.label) orelse break :blk false;
            break :blk writer.record(index, .slider, slider.id, label, unitRef(slider.value));
        },
        .row_item => |row| blk: {
            const title = writer.string(row.title) orelse break :blk false;
            const detail = writer.string(row.detail) orelse break :blk false;
            break :blk writer.record(index, .row_item, row.id, title, detail);
        },
    };
}

fn writeComponentHtml(component: Component, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeComponentHtmlInto(&writer, component);
    return writer.written();
}

fn writeComponentHtmlInto(writer: *HtmlWriter, component: Component) HtmlError!void {
    switch (component) {
        .text => |text| {
            try writer.writeAll("<p data-er-component=\"text\">");
            try writer.writeEscapedText(text.value);
            try writer.writeAll("</p>");
        },
        .card => |card| {
            try writer.writeAll("<article data-er-component=\"card\"><h2>");
            try writer.writeEscapedText(card.title);
            try writer.writeAll("</h2><p>");
            try writer.writeEscapedText(card.detail);
            try writer.writeAll("</p></article>");
        },
        .badge => |badge| {
            try writer.writeAll("<span data-er-component=\"badge\">");
            try writer.writeEscapedText(badge.label);
            try writer.writeAll("</span>");
        },
        .avatar => |avatar| {
            try writer.writeAll("<span data-er-component=\"avatar\"");
            try writer.writeAttrText("aria-label", avatar.label);
            try writer.writeByte('>');
            try writer.writeEscapedText(avatar.label);
            try writer.writeAll("</span>");
        },
        .kbd => |kbd| {
            try writer.writeAll("<kbd data-er-component=\"kbd\">");
            try writer.writeEscapedText(kbd.label);
            try writer.writeAll("</kbd>");
        },
        .separator => try writer.writeAll("<hr data-er-component=\"separator\">"),
        .button => |button| {
            try writer.writeAll("<button data-er-component=\"button\"");
            try writer.writeAttrInt("data-er-id", button.id);
            try writer.writeByte('>');
            try writer.writeEscapedText(button.label);
            try writer.writeAll("</button>");
        },
        .input => |input| {
            try writer.writeAll("<input data-er-component=\"input\"");
            try writer.writeAttrInt("data-er-id", input.id);
            try writer.writeAttrText("placeholder", input.placeholder);
            try writer.writeByte('>');
        },
        .textarea => |textarea| {
            try writer.writeAll("<textarea data-er-component=\"textarea\"");
            try writer.writeAttrInt("data-er-id", textarea.id);
            try writer.writeAttrText("placeholder", textarea.placeholder);
            try writer.writeAll("></textarea>");
        },
        .select => |select| {
            try writer.writeAll("<select data-er-component=\"select\"");
            try writer.writeAttrInt("data-er-id", select.id);
            try writer.writeAll("><option selected>");
            try writer.writeEscapedText(select.label);
            try writer.writeAll("</option></select>");
        },
        .checkbox => |checkbox| {
            try writer.writeAll("<label data-er-component=\"checkbox\"");
            try writer.writeAttrInt("data-er-id", checkbox.id);
            try writer.writeAttrBool("data-er-checked", checkbox.checked);
            try writer.writeAll("><input type=\"checkbox\"");
            if (checkbox.checked) try writer.writeAll(" checked");
            try writer.writeAll(">");
            try writer.writeEscapedText(checkbox.label);
            try writer.writeAll("</label>");
        },
        .switch_control => |switch_control| {
            try writer.writeAll("<button data-er-component=\"switch\"");
            try writer.writeAttrInt("data-er-id", switch_control.id);
            try writer.writeAttrBool("aria-pressed", switch_control.checked);
            try writer.writeByte('>');
            try writer.writeEscapedText(switch_control.label);
            try writer.writeAll("</button>");
        },
        .progress => |progress| {
            try writer.writeAll("<progress data-er-component=\"progress\"");
            try writer.writeAttrInt("value", percentFromUnit(progress.value));
            try writer.writeAttrRaw("max", "100");
            try writer.writeAll("></progress>");
        },
        .slider => |slider| {
            try writer.writeAll("<label data-er-component=\"slider\"");
            try writer.writeAttrInt("data-er-id", slider.id);
            try writer.writeAll("><span>");
            try writer.writeEscapedText(slider.label);
            try writer.writeAll("</span><input type=\"range\" min=\"0\" max=\"100\" value=\"");
            try writer.writeInt(percentFromUnit(slider.value));
            try writer.writeAll("\"></label>");
        },
        .row_item => |row| {
            try writer.writeAll("<div data-er-component=\"row-item\"");
            try writer.writeAttrInt("data-er-id", row.id);
            try writer.writeAll("><strong>");
            try writer.writeEscapedText(row.title);
            try writer.writeAll("</strong><span>");
            try writer.writeEscapedText(row.detail);
            try writer.writeAll("</span></div>");
        },
    }
}

fn writeStackHtml(stack: Stack, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<section data-er-component=\"stack\"");
    try writer.writeAttrRaw("data-er-axis", axisName(stack.axis));
    try writer.writeAttrInt("data-er-gap", stack.gap);
    try writer.writeAttrInt("data-er-padding", stack.padding);
    try writer.writeByte('>');
    for (stack.children) |child| try writeComponentHtmlInto(&writer, child);
    try writer.writeAll("</section>");
    return writer.written();
}

const markdown_component_marker = "--- component ---\n";
const markdown_next_component_marker = "\n--- component ---\n";

fn writeStackMarkdown(stack: Stack, out: []u8) MarkdownError![]u8 {
    if (stack.children.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("stack");
    try writer.fieldRaw("axis", axisName(stack.axis));
    try writer.fieldInt("gap", stack.gap);
    try writer.fieldInt("padding", stack.padding);
    for (stack.children) |child| {
        try writer.writeByte('\n');
        try writer.writeAll(markdown_component_marker);
        try writeComponentMarkdownInto(&writer, child);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeHeadingHtml(heading: Heading, out: []u8) HtmlError![]u8 {
    if (!validHeadingLevel(heading.level)) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeByte('<');
    try writer.writeByte('h');
    try writer.writeByte('0' + heading.level);
    try writer.writeAll(" data-er-component=\"heading\">");
    try writer.writeEscapedText(heading.value);
    try writer.writeAll("</h");
    try writer.writeByte('0' + heading.level);
    try writer.writeByte('>');
    return writer.written();
}

fn writeListHtml(list: List, out: []u8) HtmlError![]u8 {
    if (list.items.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    const tag = if (list.ordered) "ol" else "ul";
    try writer.writeByte('<');
    try writer.writeAll(tag);
    try writer.writeAll(" data-er-component=\"list\">");
    for (list.items) |item| {
        try writer.writeAll("<li>");
        try writer.writeEscapedText(item);
        try writer.writeAll("</li>");
    }
    try writer.writeAll("</");
    try writer.writeAll(tag);
    try writer.writeByte('>');
    return writer.written();
}

fn writeCalloutHtml(callout: Callout, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<blockquote data-er-component=\"callout\">");
    try writer.writeEscapedText(callout.value);
    try writer.writeAll("</blockquote>");
    return writer.written();
}

fn writeCodeBlockHtml(block: CodeBlock, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<pre data-er-component=\"code-block\"><code");
    try writer.writeAttrText("data-er-lang", block.language);
    try writer.writeByte('>');
    for (block.lines, 0..) |line, index| {
        if (index != 0) try writer.writeByte('\n');
        try writer.writeEscapedText(line);
    }
    try writer.writeAll("</code></pre>");
    return writer.written();
}

fn writeChoiceGroupHtml(group: ChoiceGroup, out: []u8) HtmlError![]u8 {
    if (group.legend.len == 0 or group.options.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<fieldset data-er-component=\"choice-group\"");
    try writer.writeAttrInt("data-er-id", group.id);
    try writer.writeAll("><legend>");
    try writer.writeEscapedText(group.legend);
    try writer.writeAll("</legend>");
    for (group.options) |option| {
        if (option.label.len == 0) return error.InvalidHtml;
        try writer.writeAll("<label");
        try writer.writeAttrInt("data-er-id", option.id);
        try writer.writeAttrBool("data-er-selected", option.selected);
        try writer.writeAll("><input type=\"radio\" name=\"choice-");
        try writer.writeInt(group.id);
        try writer.writeAll("\">");
        try writer.writeEscapedText(option.label);
        try writer.writeAll("</label>");
    }
    try writer.writeAll("</fieldset>");
    return writer.written();
}

fn writeTimelineHtml(timeline: Timeline, out: []u8) HtmlError![]u8 {
    if (timeline.events.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<ol data-er-component=\"timeline\">");
    for (timeline.events) |event| {
        if (event.time.len == 0 or event.title.len == 0 or event.detail.len == 0) return error.InvalidHtml;
        try writer.writeAll("<li");
        try writer.writeAttrInt("data-er-id", event.id);
        try writer.writeAll("><time>");
        try writer.writeEscapedText(event.time);
        try writer.writeAll("</time><strong>");
        try writer.writeEscapedText(event.title);
        try writer.writeAll("</strong><p>");
        try writer.writeEscapedText(event.detail);
        try writer.writeAll("</p></li>");
    }
    try writer.writeAll("</ol>");
    return writer.written();
}

fn writeRegionHtml(region: Region, out: []u8) HtmlError![]u8 {
    if (region.children.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    const tag = regionTagName(region.tag);
    try writer.writeByte('<');
    try writer.writeAll(tag);
    try writer.writeAttrRaw("data-er-component", "region");
    try writer.writeAttrText("aria-label", region.label);
    try writer.writeByte('>');
    for (region.children) |child| try writeComponentHtmlInto(&writer, child);
    try writer.writeAll("</");
    try writer.writeAll(tag);
    try writer.writeByte('>');
    return writer.written();
}

fn writeRegionMarkdown(region: Region, out: []u8) MarkdownError![]u8 {
    if (region.children.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("region");
    try writer.fieldRaw("tag", regionTagName(region.tag));
    try writer.fieldText("label", region.label);
    for (region.children) |child| {
        try writer.writeByte('\n');
        try writer.writeAll(markdown_component_marker);
        try writeComponentMarkdownInto(&writer, child);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeComponentMarkdown(component: Component, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeComponentMarkdownInto(&writer, component);
    return writer.written();
}

fn writeComponentMarkdownInto(writer: *MarkdownWriter, component: Component) MarkdownError!void {
    switch (component) {
        .text => |text| {
            if (text.value.len == 0) return error.InvalidMarkdown;
            try writer.writeEscapedInline(text.value);
        },
        .card => |card| try writeCardMarkdownInto(writer, card),
        .badge => |badge| {
            if (badge.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("badge");
            try writer.fieldText("label", badge.label);
            try writer.endDirective();
        },
        .avatar => |avatar| {
            if (avatar.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("avatar");
            try writer.fieldText("label", avatar.label);
            try writer.endDirective();
        },
        .kbd => |kbd| {
            if (kbd.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("kbd");
            try writer.fieldText("label", kbd.label);
            try writer.endDirective();
        },
        .separator => try writer.writeAll("---"),
        .button => |button| {
            if (button.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("button");
            try writer.fieldInt("id", button.id);
            try writer.fieldText("label", button.label);
            try writer.endDirective();
        },
        .input => |input| {
            if (input.placeholder.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("input");
            try writer.fieldInt("id", input.id);
            try writer.fieldText("placeholder", input.placeholder);
            try writer.endDirective();
        },
        .textarea => |textarea| {
            if (textarea.placeholder.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("textarea");
            try writer.fieldInt("id", textarea.id);
            try writer.fieldText("placeholder", textarea.placeholder);
            try writer.endDirective();
        },
        .select => |select| {
            if (select.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("select");
            try writer.fieldInt("id", select.id);
            try writer.fieldText("label", select.label);
            try writer.endDirective();
        },
        .checkbox => |checkbox| {
            if (checkbox.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("checkbox");
            try writer.fieldInt("id", checkbox.id);
            try writer.fieldBool("checked", checkbox.checked);
            try writer.fieldText("label", checkbox.label);
            try writer.endDirective();
        },
        .switch_control => |switch_control| {
            if (switch_control.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("switch");
            try writer.fieldInt("id", switch_control.id);
            try writer.fieldBool("checked", switch_control.checked);
            try writer.fieldText("label", switch_control.label);
            try writer.endDirective();
        },
        .progress => |progress| {
            try writer.beginDirective("progress-control");
            try writer.fieldInt("value", percentFromUnit(progress.value));
            try writer.endDirective();
        },
        .slider => |slider| {
            if (slider.label.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("slider");
            try writer.fieldInt("id", slider.id);
            try writer.fieldText("label", slider.label);
            try writer.fieldInt("value", percentFromUnit(slider.value));
            try writer.endDirective();
        },
        .row_item => |row| {
            if (row.title.len == 0 or row.detail.len == 0) return error.InvalidMarkdown;
            try writer.beginDirective("row-item");
            try writer.fieldInt("id", row.id);
            try writer.fieldText("title", row.title);
            try writer.fieldText("detail", row.detail);
            try writer.endDirective();
        },
    }
}

fn writeHeadingMarkdown(heading: Heading, out: []u8) MarkdownError![]u8 {
    if (!validHeadingLevel(heading.level) or heading.value.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    var level: u8 = 0;
    while (level < heading.level) : (level += 1) try writer.writeByte('#');
    try writer.writeAll(" ");
    try writer.writeEscapedInline(heading.value);
    return writer.written();
}

fn writeListMarkdown(list: List, out: []u8) MarkdownError![]u8 {
    if (list.items.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    for (list.items, 0..) |item, index| {
        if (item.len == 0) return error.InvalidMarkdown;
        if (index != 0) try writer.writeByte('\n');
        if (list.ordered) {
            try writer.writeInt(@intCast(index + 1));
            try writer.writeAll(". ");
        } else {
            try writer.writeAll("- ");
        }
        try writer.writeEscapedInline(item);
    }
    return writer.written();
}

fn writeCalloutMarkdown(callout: Callout, out: []u8) MarkdownError![]u8 {
    if (callout.value.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.writeAll("> ");
    try writer.writeEscapedInline(callout.value);
    return writer.written();
}

fn writeChoiceGroupMarkdown(group: ChoiceGroup, out: []u8) MarkdownError![]u8 {
    if (group.legend.len == 0 or group.options.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("choice");
    try writer.fieldInt("id", group.id);
    try writer.fieldText("legend", group.legend);
    for (group.options) |option| {
        if (option.label.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("option", option.id);
        try writer.fieldBool("selected", option.selected);
        try writer.fieldText("label", option.label);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeCardMarkdown(card: Card, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeCardMarkdownInto(&writer, card);
    return writer.written();
}

fn writeCardMarkdownInto(writer: *MarkdownWriter, card: Card) MarkdownError!void {
    if (card.title.len == 0 or card.detail.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("card");
    try writer.fieldText("title", card.title);
    try writer.fieldText("detail", card.detail);
    try writer.endDirective();
}

fn writeTimelineMarkdown(timeline: Timeline, out: []u8) MarkdownError![]u8 {
    if (timeline.events.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("timeline");
    for (timeline.events) |event| {
        if (event.time.len == 0 or event.title.len == 0 or event.detail.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("event", event.id);
        try writer.fieldText("time", event.time);
        try writer.fieldText("title", event.title);
        try writer.fieldText("detail", event.detail);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeCodeBlockMarkdown(block: CodeBlock, out: []u8) MarkdownError![]u8 {
    if (!validMarkdownFenceLanguage(block.language)) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.writeAll("```");
    try writer.writeAll(block.language);
    try writer.writeByte('\n');
    for (block.lines, 0..) |line, index| {
        if (std.mem.indexOf(u8, line, "```") != null) return error.InvalidMarkdown;
        if (index != 0) try writer.writeByte('\n');
        try writer.writeAll(line);
    }
    try writer.writeAll("\n```");
    return writer.written();
}

fn readHeadingMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Heading {
    if (std.mem.indexOfScalar(u8, markdown, '\n') != null) return error.InvalidMarkdown;
    const level: u8 = if (std.mem.startsWith(u8, markdown, "### "))
        3
    else if (std.mem.startsWith(u8, markdown, "## "))
        2
    else if (std.mem.startsWith(u8, markdown, "# "))
        1
    else if (std.mem.startsWith(u8, markdown, "#"))
        return error.InvalidMarkdown
    else
        return error.UnsupportedMarkdown;
    const value_start: usize = @as(usize, level) + 1;
    var text = MarkdownTextArena.init(text_out);
    const value = try text.unescapeInline(markdown[value_start..]);
    if (value.len == 0) return error.InvalidMarkdown;
    return .{ .level = level, .value = value };
}

fn readListMarkdown(markdown: []const u8, out_items: [][]const u8, text_out: []u8) MarkdownError!List {
    if (markdown.len == 0) return error.InvalidMarkdown;
    const ordered = if (std.mem.startsWith(u8, markdown, "1. "))
        true
    else if (std.mem.startsWith(u8, markdown, "- "))
        false
    else if (std.mem.startsWith(u8, markdown, "1.") or std.mem.startsWith(u8, markdown, "-"))
        return error.InvalidMarkdown
    else
        return error.UnsupportedMarkdown;

    var text = MarkdownTextArena.init(text_out);
    var item_count: usize = 0;
    var cursor = LineCursor.init(markdown);
    while (cursor.next()) |line| {
        if (item_count == out_items.len) return error.MarkdownBudgetExceeded;
        const value = if (ordered) blk: {
            var prefix_buffer: [16]u8 = undefined;
            const prefix = std.fmt.bufPrint(&prefix_buffer, "{d}. ", .{item_count + 1}) catch unreachable;
            if (!std.mem.startsWith(u8, line, prefix)) return error.InvalidMarkdown;
            break :blk line[prefix.len..];
        } else blk: {
            if (!std.mem.startsWith(u8, line, "- ")) return error.InvalidMarkdown;
            break :blk line["- ".len..];
        };
        out_items[item_count] = try text.unescapeInline(value);
        if (out_items[item_count].len == 0) return error.InvalidMarkdown;
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidMarkdown;
    return .{ .ordered = ordered, .items = out_items[0..item_count] };
}

fn readCalloutMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Callout {
    if (!std.mem.startsWith(u8, markdown, "> ")) {
        if (std.mem.startsWith(u8, markdown, ">")) return error.InvalidMarkdown;
        return error.UnsupportedMarkdown;
    }
    if (std.mem.indexOfScalar(u8, markdown, '\n') != null) return error.InvalidMarkdown;
    var text = MarkdownTextArena.init(text_out);
    const value = try text.unescapeInline(markdown["> ".len..]);
    if (value.len == 0) return error.InvalidMarkdown;
    return .{ .value = value };
}

fn readChoiceGroupMarkdown(markdown: []const u8, out_options: []ChoiceOption, text_out: []u8) MarkdownError!ChoiceGroup {
    const prefix = ":::choice\nid: ";
    const body = try readMarkdownDirectiveBody(markdown, ":::choice", prefix);
    var cursor = MarkdownCursor.init(body);
    const id = try parseMarkdownU32(try cursor.fieldBetween("", "\nlegend: "));
    var text = MarkdownTextArena.init(text_out);
    const legend = try text.unescapeInline(try cursor.fieldBetween("\nlegend: ", "\noption: "));
    if (legend.len == 0) return error.InvalidMarkdown;
    var option_count: usize = 0;
    try cursor.skipNewline();
    while (!cursor.done()) {
        if (option_count == out_options.len) return error.MarkdownBudgetExceeded;
        const option_id = try parseMarkdownU32(try cursor.lineAfter("option: "));
        const selected = try parseMarkdownBool(try cursor.fieldBetween("\nselected: ", "\nlabel: "));
        const label = try text.unescapeInline(try cursor.finalField("\nlabel: ", "\noption: "));
        if (label.len == 0) return error.InvalidMarkdown;
        out_options[option_count] = .{ .id = option_id, .label = label, .selected = selected };
        option_count += 1;
        try cursor.skipNewline();
    }
    if (option_count == 0) return error.InvalidMarkdown;
    return .{ .id = id, .legend = legend, .options = out_options[0..option_count] };
}

fn readCardMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Card {
    var text = MarkdownTextArena.init(text_out);
    return readCardMarkdownWithArena(markdown, &text);
}

fn readCardMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Card {
    const prefix = ":::card\ntitle: ";
    const body = try readMarkdownDirectiveBody(markdown, ":::card", prefix);
    const title_end_relative = std.mem.indexOf(u8, body, "\ndetail: ") orelse return error.InvalidMarkdown;
    const detail_start = title_end_relative + "\ndetail: ".len;
    const title = try text.unescapeInline(body[0..title_end_relative]);
    const detail = try text.unescapeInline(body[detail_start..]);
    if (title.len == 0 or detail.len == 0) return error.InvalidMarkdown;
    return .{ .title = title, .detail = detail };
}

fn readTimelineMarkdown(markdown: []const u8, out_events: []TimelineEvent, text_out: []u8) MarkdownError!Timeline {
    const prefix = ":::timeline\n";
    const body = try readMarkdownDirectiveBody(markdown, ":::timeline", prefix);
    var text = MarkdownTextArena.init(text_out);
    var event_count: usize = 0;
    var cursor = MarkdownCursor.init(body);
    while (!cursor.done()) {
        if (event_count == out_events.len) return error.MarkdownBudgetExceeded;
        const id = try parseMarkdownU32(try cursor.lineAfter("event: "));
        const time = try text.unescapeInline(try cursor.fieldBetween("\ntime: ", "\ntitle: "));
        const title = try text.unescapeInline(try cursor.fieldBetween("\ntitle: ", "\ndetail: "));
        const detail = try text.unescapeInline(try cursor.finalField("\ndetail: ", "\nevent: "));
        if (time.len == 0 or title.len == 0 or detail.len == 0) return error.InvalidMarkdown;
        out_events[event_count] = .{ .id = id, .time = time, .title = title, .detail = detail };
        event_count += 1;
        try cursor.skipNewline();
    }
    if (event_count == 0) return error.InvalidMarkdown;
    return .{ .events = out_events[0..event_count] };
}

fn readCodeBlockMarkdown(markdown: []const u8, out_lines: [][]const u8) MarkdownError!CodeBlock {
    if (!std.mem.startsWith(u8, markdown, "```")) return error.UnsupportedMarkdown;
    const language_start = "```".len;
    const language_end_relative = std.mem.indexOfScalar(u8, markdown[language_start..], '\n') orelse return error.InvalidMarkdown;
    const language = markdown[language_start .. language_start + language_end_relative];
    if (!validMarkdownFenceLanguage(language)) return error.InvalidMarkdown;
    if (!std.mem.endsWith(u8, markdown, "\n```")) return error.InvalidMarkdown;
    const body_start = language_start + language_end_relative + 1;
    const body_end = markdown.len - "\n```".len;
    const lines = try readCodeBlockMarkdownLines(markdown[body_start..body_end], out_lines);
    return .{ .language = language, .lines = lines };
}

fn readCodeBlockMarkdownLines(body: []const u8, out_lines: [][]const u8) MarkdownError![]const []const u8 {
    if (body.len == 0) return out_lines[0..0];
    var line_count: usize = 0;
    var cursor = LineCursor.init(body);
    while (cursor.next()) |line| {
        if (line_count == out_lines.len) return error.MarkdownBudgetExceeded;
        if (std.mem.indexOf(u8, line, "```") != null) return error.InvalidMarkdown;
        out_lines[line_count] = line;
        line_count += 1;
    }
    return out_lines[0..line_count];
}

fn readDirectiveBody(markdown: []const u8, prefix: []const u8) MarkdownError![]const u8 {
    if (!std.mem.endsWith(u8, markdown, "\n:::")) return error.InvalidMarkdown;
    const body_end = markdown.len - "\n:::".len;
    if (body_end < prefix.len) return error.InvalidMarkdown;
    return markdown[prefix.len..body_end];
}

fn readMarkdownDirectiveBody(markdown: []const u8, directive: []const u8, prefix: []const u8) MarkdownError![]const u8 {
    if (!std.mem.startsWith(u8, markdown, prefix)) {
        if (std.mem.startsWith(u8, markdown, directive)) return error.InvalidMarkdown;
        return error.UnsupportedMarkdown;
    }
    return readDirectiveBody(markdown, prefix);
}

const MarkdownCursor = struct {
    body: []const u8,
    cursor: usize = 0,

    fn init(body: []const u8) MarkdownCursor {
        return .{ .body = body };
    }

    fn done(self: MarkdownCursor) bool {
        return self.cursor >= self.body.len;
    }

    fn requirePrefix(self: MarkdownCursor, prefix: []const u8) MarkdownError!usize {
        if (!std.mem.startsWith(u8, self.body[self.cursor..], prefix)) return error.InvalidMarkdown;
        return self.cursor + prefix.len;
    }

    fn lineAfter(self: *MarkdownCursor, prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOfScalar(u8, self.body[value_start..], '\n') orelse return error.InvalidMarkdown;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    fn fieldBetween(self: *MarkdownCursor, prefix: []const u8, next_prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOf(u8, self.body[value_start..], next_prefix) orelse return error.InvalidMarkdown;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    fn finalField(self: *MarkdownCursor, prefix: []const u8, next_record_prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOf(u8, self.body[value_start..], next_record_prefix) orelse self.body[value_start..].len;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    fn tailField(self: *MarkdownCursor, prefix: []const u8) MarkdownError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        self.cursor = self.body.len;
        return self.body[value_start..];
    }

    fn skipNewline(self: *MarkdownCursor) MarkdownError!void {
        if (self.cursor == self.body.len) return;
        if (self.body[self.cursor] != '\n') return error.InvalidMarkdown;
        self.cursor += 1;
    }
};

const LineCursor = struct {
    body: []const u8,
    cursor: usize = 0,

    fn init(body: []const u8) LineCursor {
        return .{ .body = body };
    }

    fn done(self: LineCursor) bool {
        return self.cursor >= self.body.len;
    }

    fn next(self: *LineCursor) ?[]const u8 {
        if (self.cursor > self.body.len) return null;
        if (self.body.len == 0) return null;
        const end = std.mem.indexOfScalarPos(u8, self.body, self.cursor, '\n') orelse self.body.len;
        const line = self.body[self.cursor..end];
        self.cursor = if (end == self.body.len) self.body.len + 1 else end + 1;
        return line;
    }
};

const HtmlCursor = struct {
    body: []const u8,
    cursor: usize = 0,

    fn init(body: []const u8) HtmlCursor {
        return .{ .body = body };
    }

    fn done(self: HtmlCursor) bool {
        return self.cursor >= self.body.len;
    }

    fn requirePrefix(self: HtmlCursor, prefix: []const u8) HtmlError!usize {
        if (!std.mem.startsWith(u8, self.body[self.cursor..], prefix)) return error.InvalidHtml;
        return self.cursor + prefix.len;
    }

    fn fieldBetween(self: *HtmlCursor, prefix: []const u8, next_prefix: []const u8) HtmlError![]const u8 {
        const value_start = try self.requirePrefix(prefix);
        const value_end_relative = std.mem.indexOf(u8, self.body[value_start..], next_prefix) orelse return error.InvalidHtml;
        self.cursor = value_start + value_end_relative;
        return self.body[value_start..self.cursor];
    }

    fn consume(self: *HtmlCursor, value: []const u8) HtmlError!void {
        self.cursor = try self.requirePrefix(value);
    }
};

fn readComponentMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Component {
    var text = MarkdownTextArena.init(text_out);
    return readComponentMarkdownWithArena(markdown, &text);
}

fn readComponentMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Component {
    if (std.mem.eql(u8, markdown, "---")) return .{ .separator = .{} };
    if (std.mem.startsWith(u8, markdown, ":::card")) return .{ .card = try readCardMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::badge")) {
        return .{ .badge = .{ .label = try readSingleFieldDirectiveMarkdown(markdown, ":::badge\nlabel: ", text) } };
    }
    if (std.mem.startsWith(u8, markdown, ":::avatar")) {
        return .{ .avatar = .{ .label = try readSingleFieldDirectiveMarkdown(markdown, ":::avatar\nlabel: ", text) } };
    }
    if (std.mem.startsWith(u8, markdown, ":::kbd")) {
        return .{ .kbd = .{ .label = try readSingleFieldDirectiveMarkdown(markdown, ":::kbd\nlabel: ", text) } };
    }
    if (std.mem.startsWith(u8, markdown, ":::button")) {
        const body = try readMarkdownDirectiveBody(markdown, ":::button", ":::button\nid: ");
        const decoded = try readIdLabelDirectiveBody(body, "\nlabel: ", text);
        return .{ .button = .{ .id = decoded.id, .label = decoded.label } };
    }
    if (std.mem.startsWith(u8, markdown, ":::input")) {
        const body = try readMarkdownDirectiveBody(markdown, ":::input", ":::input\nid: ");
        const decoded = try readIdLabelDirectiveBody(body, "\nplaceholder: ", text);
        return .{ .input = .{ .id = decoded.id, .placeholder = decoded.label } };
    }
    if (std.mem.startsWith(u8, markdown, ":::textarea")) {
        const body = try readMarkdownDirectiveBody(markdown, ":::textarea", ":::textarea\nid: ");
        const decoded = try readIdLabelDirectiveBody(body, "\nplaceholder: ", text);
        return .{ .textarea = .{ .id = decoded.id, .placeholder = decoded.label } };
    }
    if (std.mem.startsWith(u8, markdown, ":::select")) {
        const body = try readMarkdownDirectiveBody(markdown, ":::select", ":::select\nid: ");
        const decoded = try readIdLabelDirectiveBody(body, "\nlabel: ", text);
        return .{ .select = .{ .id = decoded.id, .label = decoded.label } };
    }
    if (std.mem.startsWith(u8, markdown, ":::checkbox")) {
        const decoded = try readCheckedLabelDirectiveMarkdown(markdown, ":::checkbox\nid: ", text);
        return .{ .checkbox = .{ .id = decoded.id, .label = decoded.label, .checked = decoded.checked } };
    }
    if (std.mem.startsWith(u8, markdown, ":::switch")) {
        const decoded = try readCheckedLabelDirectiveMarkdown(markdown, ":::switch\nid: ", text);
        return .{ .switch_control = .{ .id = decoded.id, .label = decoded.label, .checked = decoded.checked } };
    }
    if (std.mem.startsWith(u8, markdown, ":::progress-control")) {
        const body = try readMarkdownDirectiveBody(markdown, ":::progress-control", ":::progress-control\nvalue: ");
        return .{ .progress = .{ .value = try parseMarkdownPercent(body) } };
    }
    if (std.mem.startsWith(u8, markdown, ":::slider")) {
        const prefix = ":::slider\nid: ";
        const body = try readMarkdownDirectiveBody(markdown, ":::slider", prefix);
        const id_end = std.mem.indexOf(u8, body, "\nlabel: ") orelse return error.InvalidMarkdown;
        const id = try parseMarkdownU32(body[0..id_end]);
        const label_start = id_end + "\nlabel: ".len;
        const label_end_relative = std.mem.indexOf(u8, body[label_start..], "\nvalue: ") orelse return error.InvalidMarkdown;
        const value_start = label_start + label_end_relative + "\nvalue: ".len;
        const label = try text.unescapeInline(body[label_start .. label_start + label_end_relative]);
        if (label.len == 0) return error.InvalidMarkdown;
        return .{ .slider = .{ .id = id, .label = label, .value = try parseMarkdownPercent(body[value_start..]) } };
    }
    if (std.mem.startsWith(u8, markdown, ":::row-item")) {
        const prefix = ":::row-item\nid: ";
        const body = try readMarkdownDirectiveBody(markdown, ":::row-item", prefix);
        const id_end = std.mem.indexOf(u8, body, "\ntitle: ") orelse return error.InvalidMarkdown;
        const id = try parseMarkdownU32(body[0..id_end]);
        const title_start = id_end + "\ntitle: ".len;
        const title_end_relative = std.mem.indexOf(u8, body[title_start..], "\ndetail: ") orelse return error.InvalidMarkdown;
        const detail_start = title_start + title_end_relative + "\ndetail: ".len;
        const title = try text.unescapeInline(body[title_start .. title_start + title_end_relative]);
        const detail = try text.unescapeInline(body[detail_start..]);
        if (title.len == 0 or detail.len == 0) return error.InvalidMarkdown;
        return .{ .row_item = .{ .id = id, .title = title, .detail = detail } };
    }
    if (std.mem.startsWith(u8, markdown, ":::")) return error.UnsupportedMarkdown;
    if (markdown.len == 0 or std.mem.indexOfScalar(u8, markdown, '\n') != null) return error.InvalidMarkdown;
    return .{ .text = .{ .value = try text.unescapeInline(markdown) } };
}

const MarkdownIdLabel = struct {
    id: u32,
    label: []const u8,
};

const MarkdownCheckedLabel = struct {
    id: u32,
    checked: bool,
    label: []const u8,
};

fn readSingleFieldDirectiveMarkdown(markdown: []const u8, prefix: []const u8, text: *MarkdownTextArena) MarkdownError![]const u8 {
    const directive_end = std.mem.indexOfScalar(u8, prefix, '\n') orelse return error.InvalidMarkdown;
    const body = try readMarkdownDirectiveBody(markdown, prefix[0..directive_end], prefix);
    const value = try text.unescapeInline(body);
    if (value.len == 0) return error.InvalidMarkdown;
    return value;
}

fn readIdLabelDirectiveBody(body: []const u8, label_prefix: []const u8, text: *MarkdownTextArena) MarkdownError!MarkdownIdLabel {
    const id_end = std.mem.indexOf(u8, body, label_prefix) orelse return error.InvalidMarkdown;
    const id = try parseMarkdownU32(body[0..id_end]);
    const label = try text.unescapeInline(body[id_end + label_prefix.len ..]);
    if (label.len == 0) return error.InvalidMarkdown;
    return .{ .id = id, .label = label };
}

fn readCheckedLabelDirectiveMarkdown(markdown: []const u8, prefix: []const u8, text: *MarkdownTextArena) MarkdownError!MarkdownCheckedLabel {
    const directive_end = std.mem.indexOfScalar(u8, prefix, '\n') orelse return error.InvalidMarkdown;
    const body = try readMarkdownDirectiveBody(markdown, prefix[0..directive_end], prefix);
    const id_end = std.mem.indexOf(u8, body, "\nchecked: ") orelse return error.InvalidMarkdown;
    const id = try parseMarkdownU32(body[0..id_end]);
    const checked_start = id_end + "\nchecked: ".len;
    const checked_end_relative = std.mem.indexOf(u8, body[checked_start..], "\nlabel: ") orelse return error.InvalidMarkdown;
    const label_start = checked_start + checked_end_relative + "\nlabel: ".len;
    const checked = try parseMarkdownBool(body[checked_start .. checked_start + checked_end_relative]);
    const label = try text.unescapeInline(body[label_start..]);
    if (label.len == 0) return error.InvalidMarkdown;
    return .{ .id = id, .checked = checked, .label = label };
}

fn readComponentHtml(html: []const u8, text_out: []u8) HtmlError!Component {
    var text = HtmlTextArena.init(text_out);
    return readComponentHtmlWithArena(html, &text);
}

fn readComponentHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Component {
    if (takeWrapped(html, "<p data-er-component=\"text\">", "</p>")) |value| {
        return .{ .text = .{ .value = try text.unescape(value) } };
    }
    if (takeWrapped(html, "<span data-er-component=\"badge\">", "</span>")) |value| {
        return .{ .badge = .{ .label = try text.unescape(value) } };
    }
    if (std.mem.startsWith(u8, html, "<span data-er-component=\"avatar\" aria-label=\"")) {
        const after_label = html["<span data-er-component=\"avatar\" aria-label=\"".len..];
        const label_end = std.mem.indexOf(u8, after_label, "\">") orelse return error.InvalidHtml;
        if (!std.mem.endsWith(u8, html, "</span>")) return error.InvalidHtml;
        const visible_start = "<span data-er-component=\"avatar\" aria-label=\"".len + label_end + "\">".len;
        const label = try text.unescape(after_label[0..label_end]);
        const visible = try text.unescape(html[visible_start .. html.len - "</span>".len]);
        if (!std.mem.eql(u8, label, visible)) return error.InvalidHtml;
        return .{ .avatar = .{ .label = label } };
    }
    if (takeWrapped(html, "<kbd data-er-component=\"kbd\">", "</kbd>")) |value| {
        return .{ .kbd = .{ .label = try text.unescape(value) } };
    }
    if (std.mem.eql(u8, html, "<hr data-er-component=\"separator\">")) {
        return .{ .separator = .{} };
    }
    if (std.mem.startsWith(u8, html, "<button data-er-component=\"button\" data-er-id=\"")) {
        const after_id_prefix = html["<button data-er-component=\"button\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\">") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const label_start = "<button data-er-component=\"button\" data-er-id=\"".len + id_end + "\">".len;
        if (!std.mem.endsWith(u8, html, "</button>")) return error.InvalidHtml;
        const label = html[label_start .. html.len - "</button>".len];
        return .{ .button = .{ .id = id, .label = try text.unescape(label) } };
    }
    if (std.mem.startsWith(u8, html, "<input data-er-component=\"input\" data-er-id=\"")) {
        const after_id_prefix = html["<input data-er-component=\"input\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\" placeholder=\"") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const placeholder_start = "<input data-er-component=\"input\" data-er-id=\"".len + id_end + "\" placeholder=\"".len;
        if (!std.mem.endsWith(u8, html, "\">")) return error.InvalidHtml;
        const placeholder = html[placeholder_start .. html.len - "\">".len];
        return .{ .input = .{ .id = id, .placeholder = try text.unescape(placeholder) } };
    }
    if (std.mem.startsWith(u8, html, "<textarea data-er-component=\"textarea\" data-er-id=\"")) {
        const after_id_prefix = html["<textarea data-er-component=\"textarea\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\" placeholder=\"") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const placeholder_start = "<textarea data-er-component=\"textarea\" data-er-id=\"".len + id_end + "\" placeholder=\"".len;
        if (!std.mem.endsWith(u8, html, "\"></textarea>")) return error.InvalidHtml;
        const placeholder = html[placeholder_start .. html.len - "\"></textarea>".len];
        return .{ .textarea = .{ .id = id, .placeholder = try text.unescape(placeholder) } };
    }
    if (std.mem.startsWith(u8, html, "<select data-er-component=\"select\" data-er-id=\"")) {
        const after_id_prefix = html["<select data-er-component=\"select\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\"><option selected>") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const label_start = "<select data-er-component=\"select\" data-er-id=\"".len + id_end + "\"><option selected>".len;
        if (!std.mem.endsWith(u8, html, "</option></select>")) return error.InvalidHtml;
        const label = try text.unescape(html[label_start .. html.len - "</option></select>".len]);
        return .{ .select = .{ .id = id, .label = label } };
    }
    if (std.mem.startsWith(u8, html, "<label data-er-component=\"checkbox\" data-er-id=\"")) {
        const after_id_prefix = html["<label data-er-component=\"checkbox\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\" data-er-checked=\"") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const checked_start = "<label data-er-component=\"checkbox\" data-er-id=\"".len + id_end + "\" data-er-checked=\"".len;
        const checked_end_relative = std.mem.indexOf(u8, html[checked_start..], "\">") orelse return error.InvalidHtml;
        const checked = try parseHtmlBool(html[checked_start .. checked_start + checked_end_relative]);
        const input_start = checked_start + checked_end_relative;
        const input_text = if (checked) "\"><input type=\"checkbox\" checked>" else "\"><input type=\"checkbox\">";
        if (!std.mem.startsWith(u8, html[input_start..], input_text)) return error.InvalidHtml;
        if (!std.mem.endsWith(u8, html, "</label>")) return error.InvalidHtml;
        const label_start = input_start + input_text.len;
        const label = try text.unescape(html[label_start .. html.len - "</label>".len]);
        return .{ .checkbox = .{ .id = id, .label = label, .checked = checked } };
    }
    if (std.mem.startsWith(u8, html, "<button data-er-component=\"switch\" data-er-id=\"")) {
        const after_id_prefix = html["<button data-er-component=\"switch\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\" aria-pressed=\"") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const pressed_start = "<button data-er-component=\"switch\" data-er-id=\"".len + id_end + "\" aria-pressed=\"".len;
        const pressed_end_relative = std.mem.indexOf(u8, html[pressed_start..], "\">") orelse return error.InvalidHtml;
        const checked = try parseHtmlBool(html[pressed_start .. pressed_start + pressed_end_relative]);
        if (!std.mem.endsWith(u8, html, "</button>")) return error.InvalidHtml;
        const label_start = pressed_start + pressed_end_relative + "\">".len;
        const label = try text.unescape(html[label_start .. html.len - "</button>".len]);
        return .{ .switch_control = .{ .id = id, .label = label, .checked = checked } };
    }
    if (std.mem.startsWith(u8, html, "<progress data-er-component=\"progress\" value=\"")) {
        const value_start = "<progress data-er-component=\"progress\" value=\"".len;
        const value_end_relative = std.mem.indexOf(u8, html[value_start..], "\" max=\"100\"></progress>") orelse return error.InvalidHtml;
        const value = try parseHtmlPercent(html[value_start .. value_start + value_end_relative]);
        return .{ .progress = .{ .value = value } };
    }
    if (std.mem.startsWith(u8, html, "<label data-er-component=\"slider\" data-er-id=\"")) {
        const after_id_prefix = html["<label data-er-component=\"slider\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\"><span>") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const label_start = "<label data-er-component=\"slider\" data-er-id=\"".len + id_end + "\"><span>".len;
        const label_end_relative = std.mem.indexOf(u8, html[label_start..], "</span><input type=\"range\" min=\"0\" max=\"100\" value=\"") orelse return error.InvalidHtml;
        const value_start = label_start + label_end_relative + "</span><input type=\"range\" min=\"0\" max=\"100\" value=\"".len;
        const value_end_relative = std.mem.indexOf(u8, html[value_start..], "\"></label>") orelse return error.InvalidHtml;
        const label = try text.unescape(html[label_start .. label_start + label_end_relative]);
        const value = try parseHtmlPercent(html[value_start .. value_start + value_end_relative]);
        return .{ .slider = .{ .id = id, .label = label, .value = value } };
    }
    if (std.mem.startsWith(u8, html, "<article data-er-component=\"card\"><h2>")) {
        const title_start = "<article data-er-component=\"card\"><h2>".len;
        const title_end_relative = std.mem.indexOf(u8, html[title_start..], "</h2><p>") orelse return error.InvalidHtml;
        const detail_start = title_start + title_end_relative + "</h2><p>".len;
        if (!std.mem.endsWith(u8, html, "</p></article>")) return error.InvalidHtml;
        const title = try text.unescape(html[title_start .. title_start + title_end_relative]);
        const detail = try text.unescape(html[detail_start .. html.len - "</p></article>".len]);
        return .{ .card = .{ .title = title, .detail = detail } };
    }
    if (std.mem.startsWith(u8, html, "<div data-er-component=\"row-item\" data-er-id=\"")) {
        const after_id_prefix = html["<div data-er-component=\"row-item\" data-er-id=\"".len..];
        const id_end = std.mem.indexOf(u8, after_id_prefix, "\"><strong>") orelse return error.InvalidHtml;
        const id = try parseHtmlU32(after_id_prefix[0..id_end]);
        const title_start = "<div data-er-component=\"row-item\" data-er-id=\"".len + id_end + "\"><strong>".len;
        const title_end_relative = std.mem.indexOf(u8, html[title_start..], "</strong><span>") orelse return error.InvalidHtml;
        const detail_start = title_start + title_end_relative + "</strong><span>".len;
        if (!std.mem.endsWith(u8, html, "</span></div>")) return error.InvalidHtml;
        const title = try text.unescape(html[title_start .. title_start + title_end_relative]);
        const detail = try text.unescape(html[detail_start .. html.len - "</span></div>".len]);
        return .{ .row_item = .{ .id = id, .title = title, .detail = detail } };
    }
    return error.UnsupportedHtml;
}

fn readHeadingHtml(html: []const u8, text_out: []u8) HtmlError!Heading {
    var text = HtmlTextArena.init(text_out);
    inline for (.{ 1, 2, 3 }) |level| {
        var prefix: [32]u8 = undefined;
        const prefix_text = std.fmt.bufPrint(&prefix, "<h{d} data-er-component=\"heading\">", .{level}) catch unreachable;
        var suffix: [6]u8 = undefined;
        const suffix_text = std.fmt.bufPrint(&suffix, "</h{d}>", .{level}) catch unreachable;
        if (takeWrapped(html, prefix_text, suffix_text)) |value| {
            return .{ .level = level, .value = try text.unescape(value) };
        }
    }
    if (std.mem.startsWith(u8, html, "<h")) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

fn readListHtml(html: []const u8, out_items: [][]const u8, text_out: []u8) HtmlError!List {
    if (takeWrapped(html, "<ul data-er-component=\"list\">", "</ul>")) |body| {
        return .{ .ordered = false, .items = try readListItemsHtml(body, out_items, text_out) };
    }
    if (takeWrapped(html, "<ol data-er-component=\"list\">", "</ol>")) |body| {
        return .{ .ordered = true, .items = try readListItemsHtml(body, out_items, text_out) };
    }
    if (std.mem.startsWith(u8, html, "<ul") or std.mem.startsWith(u8, html, "<ol")) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

fn readListItemsHtml(html: []const u8, out_items: [][]const u8, text_out: []u8) HtmlError![]const []const u8 {
    var text = HtmlTextArena.init(text_out);
    var cursor = HtmlCursor.init(html);
    var item_count: usize = 0;
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.HtmlBudgetExceeded;
        out_items[item_count] = try text.unescape(try cursor.fieldBetween("<li>", "</li>"));
        try cursor.consume("</li>");
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidHtml;
    return out_items[0..item_count];
}

fn readCalloutHtml(html: []const u8, text_out: []u8) HtmlError!Callout {
    var text = HtmlTextArena.init(text_out);
    if (takeWrapped(html, "<blockquote data-er-component=\"callout\">", "</blockquote>")) |value| {
        return .{ .value = try text.unescape(value) };
    }
    if (std.mem.startsWith(u8, html, "<blockquote")) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

fn readCodeBlockHtml(html: []const u8, out_lines: [][]const u8, text_out: []u8) HtmlError!CodeBlock {
    const prefix = "<pre data-er-component=\"code-block\"><code data-er-lang=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<pre")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    const after_lang = html[prefix.len..];
    const lang_end = std.mem.indexOf(u8, after_lang, "\">") orelse return error.InvalidHtml;
    if (!std.mem.endsWith(u8, html, "</code></pre>")) return error.InvalidHtml;
    var text = HtmlTextArena.init(text_out);
    const language = try text.unescape(after_lang[0..lang_end]);
    const code_start = prefix.len + lang_end + "\">".len;
    const body = html[code_start .. html.len - "</code></pre>".len];
    const lines = try readCodeLinesHtml(body, out_lines, &text);
    return .{ .language = language, .lines = lines };
}

fn readCodeLinesHtml(html: []const u8, out_lines: [][]const u8, text: *HtmlTextArena) HtmlError![]const []const u8 {
    var line_count: usize = 0;
    var cursor = LineCursor.init(html);
    while (cursor.next()) |line| {
        if (line_count == out_lines.len) return error.HtmlBudgetExceeded;
        out_lines[line_count] = try text.unescape(line);
        line_count += 1;
    }
    return out_lines[0..line_count];
}

fn readChoiceGroupHtml(html: []const u8, out_options: []ChoiceOption, text_out: []u8) HtmlError!ChoiceGroup {
    const prefix = "<fieldset data-er-component=\"choice-group\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<fieldset")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    const after_id = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id, "\"><legend>") orelse return error.InvalidHtml;
    const id = try parseHtmlU32(after_id[0..id_end]);
    const legend_start = prefix.len + id_end + "\"><legend>".len;
    const legend_end_relative = std.mem.indexOf(u8, html[legend_start..], "</legend>") orelse return error.InvalidHtml;
    if (!std.mem.endsWith(u8, html, "</fieldset>")) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    const legend = try text.unescape(html[legend_start .. legend_start + legend_end_relative]);
    if (legend.len == 0) return error.InvalidHtml;
    const options_start = legend_start + legend_end_relative + "</legend>".len;
    const options_html = html[options_start .. html.len - "</fieldset>".len];
    const options = try readChoiceOptionsHtml(options_html, id, out_options, &text);
    return .{ .id = id, .legend = legend, .options = options };
}

fn readChoiceOptionsHtml(html: []const u8, group_id: u32, out_options: []ChoiceOption, text: *HtmlTextArena) HtmlError![]const ChoiceOption {
    var expected_name_buffer: [17]u8 = undefined;
    const expected_name = std.fmt.bufPrint(&expected_name_buffer, "choice-{d}", .{group_id}) catch unreachable;
    var cursor = HtmlCursor.init(html);
    var option_count: usize = 0;
    while (!cursor.done()) {
        if (option_count == out_options.len) return error.HtmlBudgetExceeded;
        const id = try parseHtmlU32(try cursor.fieldBetween("<label data-er-id=\"", "\" data-er-selected=\""));
        const selected = try parseHtmlBool(try cursor.fieldBetween("\" data-er-selected=\"", "\"><input type=\"radio\" name=\""));
        const name = try cursor.fieldBetween("\"><input type=\"radio\" name=\"", "\">");
        if (!std.mem.eql(u8, name, expected_name)) return error.InvalidHtml;
        const label = try text.unescape(try cursor.fieldBetween("\">", "</label>"));
        try cursor.consume("</label>");
        if (label.len == 0) return error.InvalidHtml;
        out_options[option_count] = .{ .id = id, .label = label, .selected = selected };
        option_count += 1;
    }
    if (option_count == 0) return error.InvalidHtml;
    return out_options[0..option_count];
}

fn readTimelineHtml(html: []const u8, out_events: []TimelineEvent, text_out: []u8) HtmlError!Timeline {
    const body = takeWrapped(html, "<ol data-er-component=\"timeline\">", "</ol>") orelse {
        if (std.mem.startsWith(u8, html, "<ol")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    };
    var text = HtmlTextArena.init(text_out);
    const events = try readTimelineEventsHtml(body, out_events, &text);
    return .{ .events = events };
}

fn readTimelineEventsHtml(html: []const u8, out_events: []TimelineEvent, text: *HtmlTextArena) HtmlError![]const TimelineEvent {
    var cursor = HtmlCursor.init(html);
    var event_count: usize = 0;
    while (!cursor.done()) {
        if (event_count == out_events.len) return error.HtmlBudgetExceeded;
        const id = try parseHtmlU32(try cursor.fieldBetween("<li data-er-id=\"", "\"><time>"));
        const time = try text.unescape(try cursor.fieldBetween("\"><time>", "</time><strong>"));
        const title = try text.unescape(try cursor.fieldBetween("</time><strong>", "</strong><p>"));
        const detail = try text.unescape(try cursor.fieldBetween("</strong><p>", "</p></li>"));
        try cursor.consume("</p></li>");
        if (time.len == 0 or title.len == 0 or detail.len == 0) return error.InvalidHtml;
        out_events[event_count] = .{ .id = id, .time = time, .title = title, .detail = detail };
        event_count += 1;
    }
    if (event_count == 0) return error.InvalidHtml;
    return out_events[0..event_count];
}

fn readRegionHtml(html: []const u8, out_components: []Component, text_out: []u8) HtmlError!Region {
    inline for (.{ .header, .main, .footer, .section, .article }) |tag| {
        const decoded = try readRegionHtmlForTag(tag, html, out_components, text_out);
        if (decoded) |region| return region;
    }
    if (std.mem.startsWith(u8, html, "<header") or
        std.mem.startsWith(u8, html, "<main") or
        std.mem.startsWith(u8, html, "<footer") or
        std.mem.startsWith(u8, html, "<section") or
        std.mem.startsWith(u8, html, "<article") or
        std.mem.indexOf(u8, html, "data-er-component=\"region\"") != null) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

fn readRegionMarkdown(markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError!Region {
    const prefix = ":::region\ntag: ";
    const body = try readMarkdownDirectiveBody(markdown, ":::region", prefix);
    const tag_end_relative = std.mem.indexOf(u8, body, "\nlabel: ") orelse return error.InvalidMarkdown;
    const tag = parseRegionTagName(body[0..tag_end_relative]) orelse return error.InvalidMarkdown;
    const label_start = tag_end_relative + "\nlabel: ".len;
    const label_end_relative = std.mem.indexOf(u8, body[label_start..], markdown_next_component_marker) orelse return error.InvalidMarkdown;
    var text = MarkdownTextArena.init(text_out);
    const label = try text.unescapeInline(body[label_start .. label_start + label_end_relative]);
    const children_start = label_start + label_end_relative + 1;
    const children = try readComponentListMarkdownWithArena(body[children_start..], out_components, &text);
    return .{
        .tag = tag,
        .label = label,
        .children = children,
    };
}

fn readRegionHtmlForTag(comptime tag: RegionTag, html: []const u8, out_components: []Component, text_out: []u8) HtmlError!?Region {
    const prefix = switch (tag) {
        .header => "<header data-er-component=\"region\" aria-label=\"",
        .main => "<main data-er-component=\"region\" aria-label=\"",
        .footer => "<footer data-er-component=\"region\" aria-label=\"",
        .section => "<section data-er-component=\"region\" aria-label=\"",
        .article => "<article data-er-component=\"region\" aria-label=\"",
    };
    if (!std.mem.startsWith(u8, html, prefix)) return null;
    const after_label = html[prefix.len..];
    const label_end = std.mem.indexOf(u8, after_label, "\">") orelse return error.InvalidHtml;
    const suffix = switch (tag) {
        .header => "</header>",
        .main => "</main>",
        .footer => "</footer>",
        .section => "</section>",
        .article => "</article>",
    };
    if (!std.mem.endsWith(u8, html, suffix)) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    const label = try text.unescape(after_label[0..label_end]);
    const children_start = prefix.len + label_end + "\">".len;
    const children_html = html[children_start .. html.len - suffix.len];
    const children = try readComponentListHtmlWithArena(children_html, out_components, &text);
    if (children.len == 0) return error.InvalidHtml;
    return .{ .tag = tag, .label = label, .children = children };
}

fn readStackHtml(html: []const u8, out_components: []Component, text_out: []u8) HtmlError!Stack {
    const prefix = "<section data-er-component=\"stack\" data-er-axis=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_axis = html[prefix.len..];
    const axis_end = std.mem.indexOf(u8, after_axis, "\" data-er-gap=\"") orelse return error.InvalidHtml;
    const axis = parseAxisName(after_axis[0..axis_end]) orelse return error.InvalidHtml;
    const gap_start = prefix.len + axis_end + "\" data-er-gap=\"".len;
    const gap_end_relative = std.mem.indexOf(u8, html[gap_start..], "\" data-er-padding=\"") orelse return error.InvalidHtml;
    const gap = try parseHtmlU16(html[gap_start .. gap_start + gap_end_relative]);
    const padding_start = gap_start + gap_end_relative + "\" data-er-padding=\"".len;
    const padding_end_relative = std.mem.indexOf(u8, html[padding_start..], "\">") orelse return error.InvalidHtml;
    const padding = try parseHtmlU16(html[padding_start .. padding_start + padding_end_relative]);
    const children_start = padding_start + padding_end_relative + "\">".len;
    if (!std.mem.endsWith(u8, html, "</section>")) return error.InvalidHtml;
    const children_html = html[children_start .. html.len - "</section>".len];
    const children = try readStackChildrenHtml(children_html, out_components, text_out);
    return .{
        .axis = axis,
        .gap = gap,
        .padding = padding,
        .children = children,
    };
}

fn readStackMarkdown(markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError!Stack {
    const prefix = ":::stack\naxis: ";
    const body = try readMarkdownDirectiveBody(markdown, ":::stack", prefix);
    const axis_end_relative = std.mem.indexOf(u8, body, "\ngap: ") orelse return error.InvalidMarkdown;
    const axis = parseAxisName(body[0..axis_end_relative]) orelse return error.InvalidMarkdown;
    const gap_start = axis_end_relative + "\ngap: ".len;
    const gap_end_relative = std.mem.indexOf(u8, body[gap_start..], "\npadding: ") orelse return error.InvalidMarkdown;
    const gap = try parseMarkdownU16(body[gap_start .. gap_start + gap_end_relative]);
    const padding_start = gap_start + gap_end_relative + "\npadding: ".len;
    const padding_end_relative = std.mem.indexOf(u8, body[padding_start..], markdown_next_component_marker) orelse return error.InvalidMarkdown;
    const padding = try parseMarkdownU16(body[padding_start .. padding_start + padding_end_relative]);
    const children_start = padding_start + padding_end_relative + 1;
    const children = try readStackChildrenMarkdown(body[children_start..], out_components, text_out);
    return .{
        .axis = axis,
        .gap = gap,
        .padding = padding,
        .children = children,
    };
}

fn readStackChildrenHtml(html: []const u8, out_components: []Component, text_out: []u8) HtmlError![]const Component {
    var text = HtmlTextArena.init(text_out);
    return readComponentListHtmlWithArena(html, out_components, &text);
}

fn readStackChildrenMarkdown(markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError![]const Component {
    var text = MarkdownTextArena.init(text_out);
    return readComponentListMarkdownWithArena(markdown, out_components, &text);
}

fn readComponentListMarkdownWithArena(markdown: []const u8, out_components: []Component, text: *MarkdownTextArena) MarkdownError![]const Component {
    var component_count: usize = 0;
    var cursor: usize = 0;
    while (cursor < markdown.len) {
        if (component_count == out_components.len) return error.MarkdownBudgetExceeded;
        if (!std.mem.startsWith(u8, markdown[cursor..], markdown_component_marker)) return error.InvalidMarkdown;
        const child_start = cursor + markdown_component_marker.len;
        const child_end_relative = std.mem.indexOf(u8, markdown[child_start..], markdown_next_component_marker) orelse markdown[child_start..].len;
        const child_end = child_start + child_end_relative;
        const child_markdown = markdown[child_start..child_end];
        if (child_markdown.len == 0) return error.InvalidMarkdown;
        out_components[component_count] = try readComponentMarkdownWithArena(child_markdown, text);
        component_count += 1;
        cursor = child_end;
        if (cursor < markdown.len) cursor += 1;
    }
    if (component_count == 0) return error.InvalidMarkdown;
    return out_components[0..component_count];
}

fn readComponentListHtmlWithArena(html: []const u8, out_components: []Component, text: *HtmlTextArena) HtmlError![]const Component {
    var component_count: usize = 0;
    var cursor: usize = 0;
    while (cursor < html.len) {
        if (component_count == out_components.len) return error.HtmlBudgetExceeded;
        const end = childHtmlEnd(html[cursor..]) orelse return error.InvalidHtml;
        out_components[component_count] = try readComponentHtmlWithArena(html[cursor .. cursor + end], text);
        component_count += 1;
        cursor += end;
    }
    return out_components[0..component_count];
}

fn childHtmlEnd(html: []const u8) ?usize {
    const shapes = [_]HtmlShape{
        .{ .prefix = "<p data-er-component=\"text\">", .suffix = "</p>" },
        .{ .prefix = "<span data-er-component=\"badge\">", .suffix = "</span>" },
        .{ .prefix = "<span data-er-component=\"avatar\" aria-label=\"", .suffix = "</span>" },
        .{ .prefix = "<kbd data-er-component=\"kbd\">", .suffix = "</kbd>" },
        .{ .prefix = "<hr data-er-component=\"separator\">", .suffix = "" },
        .{ .prefix = "<button data-er-component=\"button\" data-er-id=\"", .suffix = "</button>" },
        .{ .prefix = "<input data-er-component=\"input\" data-er-id=\"", .suffix = ">" },
        .{ .prefix = "<textarea data-er-component=\"textarea\" data-er-id=\"", .suffix = "</textarea>" },
        .{ .prefix = "<select data-er-component=\"select\" data-er-id=\"", .suffix = "</select>" },
        .{ .prefix = "<label data-er-component=\"checkbox\" data-er-id=\"", .suffix = "</label>" },
        .{ .prefix = "<button data-er-component=\"switch\" data-er-id=\"", .suffix = "</button>" },
        .{ .prefix = "<progress data-er-component=\"progress\" value=\"", .suffix = "</progress>" },
        .{ .prefix = "<label data-er-component=\"slider\" data-er-id=\"", .suffix = "</label>" },
        .{ .prefix = "<article data-er-component=\"card\"><h2>", .suffix = "</p></article>" },
        .{ .prefix = "<div data-er-component=\"row-item\" data-er-id=\"", .suffix = "</span></div>" },
    };
    for (shapes) |shape| {
        if (!std.mem.startsWith(u8, html, shape.prefix)) continue;
        if (shape.suffix.len == 0) return shape.prefix.len;
        const suffix_start = std.mem.indexOf(u8, html, shape.suffix) orelse return null;
        return suffix_start + shape.suffix.len;
    }
    return null;
}

const HtmlShape = struct {
    prefix: []const u8,
    suffix: []const u8,
};

const HtmlWriter = struct {
    out: []u8,
    len: usize = 0,

    fn init(out: []u8) HtmlWriter {
        return .{ .out = out };
    }

    fn written(self: HtmlWriter) []u8 {
        return self.out[0..self.len];
    }

    fn writeAll(self: *HtmlWriter, value: []const u8) HtmlError!void {
        if (self.len + value.len > self.out.len) return error.HtmlBudgetExceeded;
        @memcpy(self.out[self.len .. self.len + value.len], value);
        self.len += value.len;
    }

    fn writeInt(self: *HtmlWriter, value: u32) HtmlError!void {
        var buf: [10]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
        try self.writeAll(text);
    }

    fn writeBool(self: *HtmlWriter, value: bool) HtmlError!void {
        try self.writeAll(boolName(value));
    }

    fn writeAttrInt(self: *HtmlWriter, name: []const u8, value: u32) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeInt(value);
        try self.writeByte('"');
    }

    fn writeAttrBool(self: *HtmlWriter, name: []const u8, value: bool) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeBool(value);
        try self.writeByte('"');
    }

    fn writeAttrText(self: *HtmlWriter, name: []const u8, value: []const u8) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeEscapedAttr(value);
        try self.writeByte('"');
    }

    fn writeAttrRaw(self: *HtmlWriter, name: []const u8, value: []const u8) HtmlError!void {
        try self.writeAttrPrefix(name);
        try self.writeAll(value);
        try self.writeByte('"');
    }

    fn writeAttrPrefix(self: *HtmlWriter, name: []const u8) HtmlError!void {
        try self.writeByte(' ');
        try self.writeAll(name);
        try self.writeAll("=\"");
    }

    fn writeEscapedText(self: *HtmlWriter, value: []const u8) HtmlError!void {
        for (value) |byte| {
            switch (byte) {
                '&' => try self.writeAll("&amp;"),
                '<' => try self.writeAll("&lt;"),
                '>' => try self.writeAll("&gt;"),
                else => try self.writeByte(byte),
            }
        }
    }

    fn writeEscapedAttr(self: *HtmlWriter, value: []const u8) HtmlError!void {
        for (value) |byte| {
            switch (byte) {
                '&' => try self.writeAll("&amp;"),
                '<' => try self.writeAll("&lt;"),
                '>' => try self.writeAll("&gt;"),
                '"' => try self.writeAll("&quot;"),
                else => try self.writeByte(byte),
            }
        }
    }

    fn writeByte(self: *HtmlWriter, byte: u8) HtmlError!void {
        if (self.len == self.out.len) return error.HtmlBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }
};

const HtmlTextArena = struct {
    out: []u8,
    len: usize = 0,

    fn init(out: []u8) HtmlTextArena {
        return .{ .out = out };
    }

    fn unescape(self: *HtmlTextArena, value: []const u8) HtmlError![]const u8 {
        const start = self.len;
        var index: usize = 0;
        while (index < value.len) {
            if (value[index] != '&') {
                try self.append(value[index]);
                index += 1;
                continue;
            }
            if (std.mem.startsWith(u8, value[index..], "&amp;")) {
                try self.append('&');
                index += "&amp;".len;
            } else if (std.mem.startsWith(u8, value[index..], "&lt;")) {
                try self.append('<');
                index += "&lt;".len;
            } else if (std.mem.startsWith(u8, value[index..], "&gt;")) {
                try self.append('>');
                index += "&gt;".len;
            } else if (std.mem.startsWith(u8, value[index..], "&quot;")) {
                try self.append('"');
                index += "&quot;".len;
            } else {
                return error.InvalidHtml;
            }
        }
        return self.out[start..self.len];
    }

    fn append(self: *HtmlTextArena, byte: u8) HtmlError!void {
        if (self.len == self.out.len) return error.HtmlBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }
};

const MarkdownWriter = struct {
    out: []u8,
    len: usize = 0,

    fn init(out: []u8) MarkdownWriter {
        return .{ .out = out };
    }

    fn written(self: MarkdownWriter) []u8 {
        return self.out[0..self.len];
    }

    fn writeAll(self: *MarkdownWriter, value: []const u8) MarkdownError!void {
        if (self.len + value.len > self.out.len) return error.MarkdownBudgetExceeded;
        @memcpy(self.out[self.len .. self.len + value.len], value);
        self.len += value.len;
    }

    fn writeInt(self: *MarkdownWriter, value: u32) MarkdownError!void {
        var buf: [10]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
        try self.writeAll(text);
    }

    fn beginDirective(self: *MarkdownWriter, name: []const u8) MarkdownError!void {
        try self.writeAll(":::");
        try self.writeAll(name);
    }

    fn endDirective(self: *MarkdownWriter) MarkdownError!void {
        try self.writeAll("\n:::");
    }

    fn fieldInt(self: *MarkdownWriter, name: []const u8, value: u32) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeInt(value);
    }

    fn fieldBool(self: *MarkdownWriter, name: []const u8, value: bool) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeAll(boolName(value));
    }

    fn fieldText(self: *MarkdownWriter, name: []const u8, value: []const u8) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeEscapedInline(value);
    }

    fn fieldRaw(self: *MarkdownWriter, name: []const u8, value: []const u8) MarkdownError!void {
        try self.fieldPrefix(name);
        try self.writeAll(value);
    }

    fn fieldPrefix(self: *MarkdownWriter, name: []const u8) MarkdownError!void {
        try self.writeByte('\n');
        try self.writeAll(name);
        try self.writeAll(": ");
    }

    fn writeEscapedInline(self: *MarkdownWriter, value: []const u8) MarkdownError!void {
        for (value) |byte| {
            switch (byte) {
                '\n', '\r' => return error.InvalidMarkdown,
                '\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '.', '!', '>', '|', ':' => {
                    try self.writeByte('\\');
                    try self.writeByte(byte);
                },
                else => try self.writeByte(byte),
            }
        }
    }

    fn writeByte(self: *MarkdownWriter, byte: u8) MarkdownError!void {
        if (self.len == self.out.len) return error.MarkdownBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }
};

const MarkdownTextArena = struct {
    out: []u8,
    len: usize = 0,

    fn init(out: []u8) MarkdownTextArena {
        return .{ .out = out };
    }

    fn unescapeInline(self: *MarkdownTextArena, value: []const u8) MarkdownError![]const u8 {
        const start = self.len;
        var index: usize = 0;
        while (index < value.len) {
            const byte = value[index];
            if (byte == '\n' or byte == '\r') return error.InvalidMarkdown;
            if (byte != '\\') {
                try self.append(byte);
                index += 1;
                continue;
            }
            index += 1;
            if (index == value.len or !markdownEscapable(value[index])) return error.InvalidMarkdown;
            try self.append(value[index]);
            index += 1;
        }
        return self.out[start..self.len];
    }

    fn append(self: *MarkdownTextArena, byte: u8) MarkdownError!void {
        if (self.len == self.out.len) return error.MarkdownBudgetExceeded;
        self.out[self.len] = byte;
        self.len += 1;
    }
};

fn takeWrapped(value: []const u8, prefix: []const u8, suffix: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, value, prefix)) return null;
    if (!std.mem.endsWith(u8, value, suffix)) return null;
    return value[prefix.len .. value.len - suffix.len];
}

fn axisName(axis: ui.Axis) []const u8 {
    return switch (axis) {
        .column => "column",
        .row => "row",
    };
}

fn parseAxisName(value: []const u8) ?ui.Axis {
    if (std.mem.eql(u8, value, "column")) return .column;
    if (std.mem.eql(u8, value, "row")) return .row;
    return null;
}

fn alignName(alignment: ui.TextAlign) []const u8 {
    return switch (alignment) {
        .start => "start",
        .center => "center",
        .end => "end",
    };
}

fn parseAlignName(value: []const u8) ?ui.TextAlign {
    if (std.mem.eql(u8, value, "start")) return .start;
    if (std.mem.eql(u8, value, "center")) return .center;
    if (std.mem.eql(u8, value, "end")) return .end;
    return null;
}

fn boolName(value: bool) []const u8 {
    return switch (value) {
        true => "true",
        false => "false",
    };
}

fn parseHtmlBool(value: []const u8) HtmlError!bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidHtml;
}

fn parseHtmlU16(value: []const u8) HtmlError!u16 {
    return std.fmt.parseUnsigned(u16, value, 10) catch error.InvalidHtml;
}

fn parseHtmlU32(value: []const u8) HtmlError!u32 {
    return std.fmt.parseUnsigned(u32, value, 10) catch error.InvalidHtml;
}

fn parseMarkdownBool(value: []const u8) MarkdownError!bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidMarkdown;
}

fn parseMarkdownU16(value: []const u8) MarkdownError!u16 {
    return std.fmt.parseUnsigned(u16, value, 10) catch error.InvalidMarkdown;
}

fn parseMarkdownU32(value: []const u8) MarkdownError!u32 {
    return std.fmt.parseUnsigned(u32, value, 10) catch error.InvalidMarkdown;
}

fn parseMarkdownPercent(value: []const u8) MarkdownError!f32 {
    const parsed = try parseMarkdownU32(value);
    if (parsed > 100) return error.InvalidMarkdown;
    return @as(f32, @floatFromInt(parsed)) / 100.0;
}

fn markdownEscapable(byte: u8) bool {
    return switch (byte) {
        '\\', '`', '*', '_', '{', '}', '[', ']', '(', ')', '#', '+', '-', '.', '!', '>', '|', ':' => true,
        else => false,
    };
}

fn validMarkdownFenceLanguage(value: []const u8) bool {
    for (value) |byte| {
        switch (byte) {
            'a'...'z', 'A'...'Z', '0'...'9', '-', '_' => {},
            else => return false,
        }
    }
    return true;
}

fn regionTagName(tag: RegionTag) []const u8 {
    return switch (tag) {
        .header => "header",
        .main => "main",
        .footer => "footer",
        .section => "section",
        .article => "article",
    };
}

fn parseRegionTagName(value: []const u8) ?RegionTag {
    if (std.mem.eql(u8, value, "header")) return .header;
    if (std.mem.eql(u8, value, "main")) return .main;
    if (std.mem.eql(u8, value, "footer")) return .footer;
    if (std.mem.eql(u8, value, "section")) return .section;
    if (std.mem.eql(u8, value, "article")) return .article;
    return null;
}

fn validHeadingLevel(level: u8) bool {
    return level >= 1 and level <= 3;
}

fn orderedMarker(index: usize) []const u8 {
    const markers = [_][]const u8{ "1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9." };
    if (index < markers.len) return markers[index];
    return "9.";
}

fn percentFromUnit(value: f32) u32 {
    return @intFromFloat(@round(ui.clampUnit(value) * 100.0));
}

fn parseHtmlPercent(value: []const u8) HtmlError!f32 {
    const parsed = try parseHtmlU32(value);
    if (parsed > 100) return error.InvalidHtml;
    return @as(f32, @floatFromInt(parsed)) / 100.0;
}

fn boolRef(value: bool) codec.StringRef {
    return .{ .offset = if (value) 1 else 0, .len = 0 };
}

fn unitRef(value: f32) codec.StringRef {
    return .{ .offset = ui.encodeUnit(value), .len = 0 };
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

    try std.testing.expect(ui_input.hitTest(scene.written(), 20, 70) != null);
}

test "slot component wraps a leaf component and preserves structural hit id" {
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

    const hit = ui_input.hitTest(scene.written(), 4, 4).?;
    try std.testing.expectEqual(@as(u32, 99), hit.slot);
    try std.testing.expectEqual(@as(u32, 12), hit.id);
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

test "component render helper owns button variants and hit targets" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderComponent(&scene, ui.Rect.init(0, 0, 120, 36), .{ .button = .{ .id = 501, .label = "Primary" } }, .{});
    try renderComponent(&scene, ui.Rect.init(0, 44, 120, 36), .{ .button = .{ .id = 502, .label = "Outline" } }, .{ .button_variant = .outline, .button_leading_icon = .search });

    const primary_hit = ui_input.hitTest(scene.written(), 12, 12).?;
    try std.testing.expectEqual(@as(u32, 501), primary_hit.id);
    const outline_hit = ui_input.hitTest(scene.written(), 12, 56).?;
    try std.testing.expectEqual(@as(u32, 502), outline_hit.id);
    try std.testing.expect(hasText(scene.written(), "Primary"));
    try std.testing.expect(hasText(scene.written(), "Outline"));
    try std.testing.expect(hasIcon(scene.written(), .search));
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

    try renderArticleCard(&scene, ui.Rect.init(0, 0, 360, 172), .{
        .id = 801,
        .category = "Architecture",
        .meta = "May 23, 2026",
        .title = "EdgeRun Apps Run Where The User Is",
        .summary = "A short introduction to identity-routed apps and local execution.",
    }, .{});
    try renderCodeBlock(&scene, ui.Rect.init(0, 190, 360, 72), .{ .lines = &.{ "const app = try edge.compile(source);", "try app.run(.{});" } }, .{});

    const hit = ui_input.hitTest(scene.written(), 20, 20).?;
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

test "choice group component renders selected option and hit targets" {
    const options = [_]ChoiceOption{
        .{ .id = 33001, .label = "Browser asks DNS" },
        .{ .id = 33002, .label = "GPU opens a socket", .selected = true },
        .{ .id = 33003, .label = "Battery signs TLS" },
    };
    const group = ChoiceGroup{ .id = 33000, .legend = "Which part looks up a domain name?", .options = &options };
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try group.render(&scene, ui.Rect.init(0, 0, 380, 180), .{});

    try std.testing.expect(hasTextContaining(scene.written(), "domain name"));
    try std.testing.expect(hasText(scene.written(), "GPU opens a socket"));
    const hit = ui_input.hitTest(scene.written(), 24, 104).?;
    try std.testing.expectEqual(@as(u32, 33002), hit.id);
}

test "choice group html codec roundtrips semantic radio options" {
    const options = [_]ChoiceOption{
        .{ .id = 33101, .label = "The app" },
        .{ .id = 33102, .label = "The resolver & cache", .selected = true },
    };
    const group = ChoiceGroup{ .id = 33100, .legend = "Who answers cached DNS?", .options = &options };
    var html: [768]u8 = undefined;
    var decoded_options: [2]ChoiceOption = undefined;
    var text: [256]u8 = undefined;

    const encoded = try group.toHtml(&html);
    const decoded = try ChoiceGroup.fromHtml(encoded, &decoded_options, &text);

    try std.testing.expectEqualStrings("<fieldset data-er-component=\"choice-group\" data-er-id=\"33100\"><legend>Who answers cached DNS?</legend><label data-er-id=\"33101\" data-er-selected=\"false\"><input type=\"radio\" name=\"choice-33100\">The app</label><label data-er-id=\"33102\" data-er-selected=\"true\"><input type=\"radio\" name=\"choice-33100\">The resolver &amp; cache</label></fieldset>", encoded);
    try std.testing.expectEqual(@as(u32, 33100), decoded.id);
    try std.testing.expectEqualStrings("Who answers cached DNS?", decoded.legend);
    try std.testing.expectEqual(@as(usize, 2), decoded.options.len);
    try std.testing.expectEqual(@as(u32, 33102), decoded.options[1].id);
    try std.testing.expect(decoded.options[1].selected);
    try std.testing.expectEqualStrings("The resolver & cache", decoded.options[1].label);
}

test "choice group html codec rejects malformed radio groups" {
    var options: [2]ChoiceOption = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset><legend>Plain</legend></fieldset>", &options, &text));
    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset data-er-component=\"choice-group\" data-er-id=\"x\"><legend>Broken</legend></fieldset>", &options, &text));
    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset data-er-component=\"choice-group\" data-er-id=\"1\"><legend>Broken</legend><label data-er-id=\"2\" data-er-selected=\"maybe\"><input type=\"radio\" name=\"choice-1\">Option</label></fieldset>", &options, &text));
    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset data-er-component=\"choice-group\" data-er-id=\"1\"><legend>Broken</legend><label data-er-id=\"2\" data-er-selected=\"false\"><input type=\"radio\" name=\"choice-9\">Option</label></fieldset>", &options, &text));
}

test "timeline component renders events and hit targets" {
    const events = [_]TimelineEvent{
        .{ .id = 37001, .time = "1", .title = "Browser asks", .detail = "The app asks for a name to become an address." },
        .{ .id = 37002, .time = "2", .title = "Resolver answers", .detail = "A cached or authoritative answer comes back." },
    };
    const timeline = Timeline{ .events = &events };
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try timeline.render(&scene, ui.Rect.init(0, 0, 380, 210), .{});

    try std.testing.expect(hasText(scene.written(), "Browser asks"));
    try std.testing.expect(hasText(scene.written(), "Resolver answers"));
    const hit = ui_input.hitTest(scene.written(), 24, 104).?;
    try std.testing.expectEqual(@as(u32, 37002), hit.id);
}

test "timeline html codec roundtrips semantic events" {
    const events = [_]TimelineEvent{
        .{ .id = 37101, .time = "t0", .title = "Key exists", .detail = "The device already has a root of authority." },
        .{ .id = 37102, .time = "t1", .title = "Receipt written", .detail = "The work result is bound to an object & signer." },
    };
    const timeline = Timeline{ .events = &events };
    var html: [768]u8 = undefined;
    var decoded_events: [2]TimelineEvent = undefined;
    var text: [256]u8 = undefined;

    const encoded = try timeline.toHtml(&html);
    const decoded = try Timeline.fromHtml(encoded, &decoded_events, &text);

    try std.testing.expectEqualStrings("<ol data-er-component=\"timeline\"><li data-er-id=\"37101\"><time>t0</time><strong>Key exists</strong><p>The device already has a root of authority.</p></li><li data-er-id=\"37102\"><time>t1</time><strong>Receipt written</strong><p>The work result is bound to an object &amp; signer.</p></li></ol>", encoded);
    try std.testing.expectEqual(@as(usize, 2), decoded.events.len);
    try std.testing.expectEqual(@as(u32, 37102), decoded.events[1].id);
    try std.testing.expectEqualStrings("t1", decoded.events[1].time);
    try std.testing.expectEqualStrings("Receipt written", decoded.events[1].title);
    try std.testing.expectEqualStrings("The work result is bound to an object & signer.", decoded.events[1].detail);
}

test "timeline html codec rejects malformed events" {
    var events: [2]TimelineEvent = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol><li>Plain</li></ol>", &events, &text));
    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol data-er-component=\"timeline\"></ol>", &events, &text));
    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol data-er-component=\"timeline\"><li data-er-id=\"x\"><time>1</time><strong>Broken</strong><p>Bad id</p></li></ol>", &events, &text));
    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol data-er-component=\"timeline\"><li data-er-id=\"1\"><time></time><strong>Broken</strong><p>Missing time</p></li></ol>", &events, &text));
}

test "region component renders semantic children" {
    const children = [_]Component{
        .{ .text = .{ .value = "Academy path" } },
        .{ .button = .{ .id = 31001, .label = "Continue" } },
    };
    const region = Region{ .tag = .main, .label = "Lesson body", .children = &children };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try region.render(&scene, ui.Rect.init(0, 0, 360, 120), .{});

    try std.testing.expect(hasText(scene.written(), "Academy path"));
    try std.testing.expect(hasText(scene.written(), "Continue"));
    const hit = ui_input.hitTest(scene.written(), 24, 58).?;
    try std.testing.expectEqual(@as(u32, 31001), hit.id);
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
    const short_height = articleListItemHeight(420.0, short_article);
    const long_height = articleListItemHeight(420.0, long_article);
    try std.testing.expect(long_height > short_height);

    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderArticleListItem(&scene, ui.Rect.init(0.0, 0.0, 420.0, long_height), long_article, .{});

    const hit = ui_input.hitTest(scene.written(), 20, 20).?;
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
    const atlas_id = icon.atlasId(value);
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.atlas_id == atlas_id) return true,
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
