const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const icon = @import("icon.zig");
const ui_input = @import("input.zig");
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

pub const ButtonVariant = enum {
    primary,
    outline,
    ghost,
};

pub const BadgeVariant = enum {
    accent,
    neutral,
    danger,
};

pub const SurfaceVariant = enum {
    panel,
    elevated,
    subtle,
};

pub const RenderOptions = struct {
    style: ui.Style = .{},
    button_variant: ButtonVariant = .primary,
    button_leading_icon: ?icon.Icon = null,
    button_trailing_icon: ?icon.Icon = null,
    badge_variant: BadgeVariant = .accent,
    surface_variant: SurfaceVariant = .panel,
};

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
    lines: []const []const u8,
};

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
const button_label_height: f32 = 14.0;
const button_label_padding: f32 = 4.0;
const button_label_average_w: f32 = 7.2;
const button_label_min_width: f32 = 8.0;
const button_icon_size: f32 = 18.0;
const button_icon_gap: f32 = 8.0;
const button_content_min_x: f32 = 8.0;
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
