const common = @import("../component_common.zig");
const geometry = @import("../geometry.zig");
const interaction = @import("../interaction.zig");
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");
const ui = @import("../core.zig");
const ui_icon = @import("../icon.zig");

pub const SectionProps = struct {
    title: []const u8,
    detail: []const u8 = "",
    icon: ?ui_icon.Icon = null,
};

pub const MetricCardProps = struct {
    id: ?u32 = null,
    title: []const u8,
    detail: []const u8 = "",
    value: []const u8,
    icon: ?ui_icon.Icon = null,
    progress: ?f32 = null,
    selected: bool = false,
};

pub const Segment = struct {
    id: u32,
    weight: f32,
    height: f32 = 1.0,
    color: ui.Color,
    selected: bool = false,
};

pub const SegmentMapProps = struct {
    segments: []const Segment,
    background: ui.Color,
    border: ui.Color,
    selected_border: ui.Color,
    gap: f32 = 5.0,
    radius: f32 = 8.0,
};

pub const ControlGroupProps = struct {
    id: u32,
    title: []const u8,
    value: []const u8,
    slider_id: u32,
    slider_value: f32,
    down_id: u32,
    down_label: []const u8,
    down_icon: ui_icon.Icon,
    up_id: u32,
    up_label: []const u8,
    up_icon: ui_icon.Icon,
};

pub const PathRowProps = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    trailing: []const u8,
    progress: f32,
    accent: ui.Color,
    progress_color: ui.Color,
    selected: bool = false,
    fill: ?ui.Color = null,
    selected_fill: ?ui.Color = null,
    border: ?ui.Color = null,
    text: ?ui.Color = null,
    muted: ?ui.Color = null,
};

pub const PipelineNodeProps = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    accent: ui.Color,
    selected: bool = false,
    fill: ?ui.Color = null,
    selected_fill: ?ui.Color = null,
    border: ?ui.Color = null,
    text: ?ui.Color = null,
    muted: ?ui.Color = null,
};

pub const FloatingPanelProps = struct {
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    shadow: ui.Color = .{ .r = 0, .g = 0, .b = 0, .a = 88 },
    radius: f32 = 12.0,
    shadow_size: f32 = 8.0,
    shadow_outset: f32 = 2.0,
    inset: f32 = 16.0,
    scrim: ?ui.Color = null,
    scrim_height: f32 = 0.0,
};

pub const MessageBubbleProps = struct {
    body: []const u8,
    outbound: bool = false,
    media_label: []const u8 = "",
    media_detail: []const u8 = "",
    media_icon: ?ui_icon.Icon = null,
    inbound_fill: ?ui.Color = null,
    outbound_fill: ui.Color = .{ .r = 15, .g = 95, .b = 160 },
    outbound_border: ui.Color = .{ .r = 58, .g = 177, .b = 255, .a = 190 },
    radius: f32 = 5.0,
};

pub const PanelScaffoldProps = struct {
    title: []const u8,
    detail: []const u8 = "",
    icon: ?ui_icon.Icon = null,
    id: ?u32 = null,
    variant: common.SurfaceVariant = .panel,
    selected: bool = false,
    inset: f32 = 16.0,
    header_h: f32 = 42.0,
    header_gap: f32 = 16.0,
};

pub const IconButtonSpec = struct {
    id: u32,
    label: []const u8,
    icon: ui_icon.Icon,
    variant: common.ButtonVariant = .outline,
};

pub const ToolbarDirection = enum {
    row,
    column,
};

pub const ActionToolbarProps = struct {
    specs: []const IconButtonSpec,
    direction: ToolbarDirection = .row,
    button_w: f32 = 34.0,
    button_h: f32 = 36.0,
    gap: f32 = 8.0,
};

pub const PanelListItem = struct {
    id: ?u32 = null,
    title: []const u8,
    detail: []const u8 = "",
    icon: ?ui_icon.Icon = null,
    active: bool = false,
};

pub const PanelListProps = struct {
    title: []const u8,
    detail: []const u8 = "",
    icon: ?ui_icon.Icon = null,
    id: ?u32 = null,
    variant: common.SurfaceVariant = .panel,
    selected: bool = false,
    inset: f32 = 8.0,
    header_h: f32 = 42.0,
    header_gap: f32 = 8.0,
    row_h: f32 = 42.0,
    gap: f32 = 4.0,
    empty_title: []const u8 = "No rows",
    empty_detail: []const u8 = "",
    items: []const PanelListItem = &.{},
};

pub const HeaderBadge = struct {
    label: []const u8,
    variant: common.BadgeVariant = .outline,
    accent: ?ui.Color = null,
    width: f32 = 96.0,
};

pub const PageHeaderProps = struct {
    title: []const u8,
    detail: []const u8 = "",
    icon: ?ui_icon.Icon = null,
    id: ?u32 = null,
    variant: common.SurfaceVariant = .elevated,
    selected: bool = false,
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    accent: ?ui.Color = null,
    detail_color: ?ui.Color = null,
    badges: []const HeaderBadge = &.{},
    trailing_action: ?IconButtonSpec = null,
    inset: f32 = 20.0,
    radius: f32 = 12.0,
};

pub const IconButtonValueSpec = struct {
    id: u32,
    label: []const u8,
    icon: icon_component.Icon,
    variant: common.ButtonVariant = .outline,
};

pub const WorkspaceRailProps = struct {
    actions: []const IconButtonSpec,
    fill: ui.Color,
    pad_x: f32 = 6.0,
    pad_top: f32 = 12.0,
    button_h: f32 = 36.0,
    gap: f32 = 8.0,
};

pub const WorkspaceRailValueProps = struct {
    actions: []const IconButtonValueSpec,
    fill: ui.Color,
    pad_x: f32 = 6.0,
    pad_top: f32 = 12.0,
    button_h: f32 = 36.0,
    gap: f32 = 8.0,
};

pub const WorkspaceSidebarChromeProps = struct {
    title: []const u8 = "",
    detail: []const u8 = "",
    fill: ui.Color,
    border: ui.Color,
    inset_x: f32 = 16.0,
    title_y: f32 = 14.0,
    detail_y: f32 = 36.0,
    body_y: f32 = 68.0,
    right_border_w: f32 = 1.0,
};

pub const ComposeBarProps = struct {
    actions: []const IconButtonSpec,
    textarea_id: u32,
    textarea_value: []const u8,
    send_id: u32,
    send_label: []const u8 = "Send",
    send_icon: ui_icon.Icon = .send,
    send_variant: common.ButtonVariant = .outline,
    footer: []const u8 = "",
    fill: ?ui.Color = null,
    separator: ?ui.Color = null,
    height: f32 = 74.0,
    inset_x: f32 = 18.0,
    toolbar_w: f32 = 120.0,
    toolbar_button_w: f32 = 34.0,
    toolbar_gap: f32 = 6.0,
    textarea_gap: f32 = 6.0,
    send_w: f32 = 44.0,
};

pub const ContextActionPanelProps = struct {
    x: f32,
    y: f32,
    title: []const u8,
    detail: []const u8 = "",
    primary_id: u32,
    primary_label: []const u8,
    secondary_id: u32,
    secondary_label: []const u8,
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    shadow: ui.Color = .{ .r = 0, .g = 0, .b = 0, .a = 96 },
    progress: f32 = 1.0,
    w: f32 = 220.0,
    h: f32 = 118.0,
};

pub const EditorSwitchSpec = struct {
    id: u32,
    label: []const u8,
    checked: bool,
};

pub const PropertyEditorPanelProps = struct {
    title: []const u8,
    detail: []const u8,
    close_id: u32,
    preview_title: []const u8 = "Selected",
    preview_detail: []const u8,
    section_title: []const u8,
    section_detail: []const u8,
    prev_id: u32,
    prev_label: []const u8,
    next_id: u32,
    next_label: []const u8,
    switches: []const EditorSwitchSpec = &.{},
    fill: ?ui.Color = null,
    border: ?ui.Color = null,
    shadow: ui.Color = .{ .r = 0, .g = 0, .b = 0, .a = 82 },
    scrim: ?ui.Color = null,
    progress: f32 = 1.0,
    panel_w: f32 = 360.0,
};

pub fn headerBadgesWidth(badges: []const HeaderBadge) f32 {
    if (badges.len == 0) return 0.0;
    var width: f32 = 0.0;
    for (badges) |badge_value| width += badge_value.width + 10.0;
    return width;
}

pub fn panelScaffold(view: anytype, bounds: ui.Rect, props: PanelScaffoldProps) (ui.RenderError || interaction.Error)!ui.Rect {
    try view.surfaceControlAt(bounds, props.id, props.variant, props.selected);

    const inner = bounds.insetUniform(props.inset);
    const header_h = @max(primitives.min_extent, props.header_h);
    const gap = @max(0.0, props.header_gap);
    const header = ui.Rect.init(inner.x, inner.y, inner.w, header_h);
    try section(view, header, .{
        .title = props.title,
        .detail = props.detail,
        .icon = props.icon,
    });
    const body_y = inner.y + header_h + gap;
    return ui.Rect.init(inner.x, body_y, inner.w, @max(primitives.min_extent, inner.y + inner.h - body_y));
}

pub fn actionToolbar(view: anytype, bounds: ui.Rect, props: ActionToolbarProps) (ui.RenderError || interaction.Error)!void {
    switch (props.direction) {
        .row => try view.iconButtonRow(bounds, props.specs, props.button_w, props.gap),
        .column => try view.iconButtonColumn(bounds, props.specs, props.button_h, props.gap),
    }
}

pub fn panelList(view: anytype, bounds: ui.Rect, props: PanelListProps) (ui.RenderError || interaction.Error)!void {
    const panel_body = try panelScaffold(view, bounds, .{
        .title = props.title,
        .detail = props.detail,
        .icon = props.icon,
        .id = props.id,
        .variant = props.variant,
        .selected = props.selected,
        .inset = props.inset,
        .header_h = props.header_h,
        .header_gap = props.header_gap,
    });
    var list = view.column(panel_body, props.gap);
    if (props.items.len == 0) {
        try view.emptyAt(list.remaining(), props.empty_title, props.empty_detail);
        return;
    }
    for (props.items) |item| {
        const row_bounds = list.takeIfFits(props.row_h) orelse break;
        if (item.id) |id| {
            if (item.icon) |icon_value| {
                try view.selectableRow(row_bounds, id, item.title, item.detail, icon_value, item.active);
            } else {
                try view.selectableRowText(row_bounds, id, item.title, item.detail, item.active);
            }
        } else if (item.icon) |icon_value| {
            try view.rowItemIconWithControlAt(row_bounds, 0, item.title, item.detail, icon_value, .{ .active = item.active });
        } else {
            try view.rowItemAt(row_bounds, 0, item.title, item.detail);
        }
    }
}

pub fn pageHeader(view: anytype, bounds: ui.Rect, props: PageHeaderProps) (ui.RenderError || interaction.Error)!void {
    if (props.fill) |fill_color| {
        try view.fill(bounds, fill_color, props.radius);
        if (props.id) |id| try view.buttonHit(bounds, id);
        if (props.selected) try view.selectionOverlay(bounds, props.accent orelse view.options.style.accent, view.options.style.row, 1.0, true);
    } else {
        try view.surfaceControlAt(bounds, props.id, props.variant, props.selected);
    }
    if (props.border) |border_color| try view.stroke(bounds, border_color, props.radius);

    const inner = bounds.insetUniform(props.inset);
    var text_x = inner.x;
    if (props.icon) |icon_value| {
        const chip = ui.Rect.init(inner.x, inner.y, 36.0, 36.0);
        try view.fill(chip, props.accent orelse view.options.style.row, 9.0);
        try view.icon(chip.withHeightCentered(18.0).withWidthCentered(18.0), icon_value, view.options.style.accent);
        text_x += 52.0;
    }

    const action_w: f32 = if (props.trailing_action != null) 44.0 else 0.0;
    const badges_w = headerBadgesWidth(props.badges);
    const reserved = action_w + badges_w + if (badges_w > 0.0 and action_w > 0.0) @as(f32, 10.0) else @as(f32, 0.0);
    const text_w = @max(primitives.min_extent, inner.x + inner.w - text_x - reserved);
    try view.strongText(ui.Rect.init(text_x, inner.y - 2.0, text_w, 24.0), props.title, view.options.style.text);
    if (props.detail.len != 0) {
        try view.text(ui.Rect.init(text_x, inner.y + 28.0, text_w, 18.0), props.detail, props.detail_color orelse view.options.style.muted);
    }

    var x = inner.x + inner.w - action_w;
    if (props.trailing_action) |action| {
        try view.iconButtonAt(ui.Rect.init(x, inner.y + 1.0, 34.0, 34.0), action.id, action.label, action.icon, action.variant);
        x -= 10.0;
    }
    var badge_index = props.badges.len;
    while (badge_index > 0) {
        badge_index -= 1;
        const badge_value = props.badges[badge_index];
        x -= badge_value.width;
        const badge_view = if (badge_value.accent) |accent_color| view.withAccent(accent_color) else view;
        try badge_view.badgeAt(ui.Rect.init(x, inner.y + 4.0, badge_value.width, 28.0), badge_value.label, badge_value.variant);
        x -= 10.0;
    }
}

pub fn workspaceRail(view: anytype, bounds: ui.Rect, props: WorkspaceRailProps) (ui.RenderError || interaction.Error)!void {
    try view.fill(bounds, props.fill, 0.0);
    try actionToolbar(view, ui.Rect.init(bounds.x + props.pad_x, bounds.y + props.pad_top, @max(primitives.min_extent, bounds.w - props.pad_x * 2.0), @max(primitives.min_extent, bounds.h - props.pad_top)), .{
        .specs = props.actions,
        .direction = .column,
        .button_h = props.button_h,
        .gap = props.gap,
    });
}

pub fn workspaceRailValues(view: anytype, bounds: ui.Rect, props: WorkspaceRailValueProps) (ui.RenderError || interaction.Error)!void {
    try view.fill(bounds, props.fill, 0.0);
    var column_cursor = view.column(ui.Rect.init(bounds.x + props.pad_x, bounds.y + props.pad_top, @max(primitives.min_extent, bounds.w - props.pad_x * 2.0), @max(primitives.min_extent, bounds.h - props.pad_top)), props.gap);
    for (props.actions) |action| {
        try view.iconButtonValueAt(column_cursor.take(props.button_h), action.id, action.label, action.icon, action.variant);
    }
}

pub fn workspaceSidebarChrome(view: anytype, bounds: ui.Rect, props: WorkspaceSidebarChromeProps) ui.RenderError!ui.Rect {
    try view.fill(bounds, props.fill, 0.0);
    if (props.right_border_w > 0.0) {
        try view.fill(ui.Rect.init(bounds.x + bounds.w - props.right_border_w, bounds.y, props.right_border_w, bounds.h), props.border, 0.0);
    }
    const text_w = @max(primitives.min_extent, bounds.w - props.inset_x * 2.0);
    if (props.title.len != 0) try view.title(ui.Rect.init(bounds.x + props.inset_x, bounds.y + props.title_y, text_w, 16.0), props.title);
    if (props.detail.len != 0) try view.muted(ui.Rect.init(bounds.x + props.inset_x, bounds.y + props.detail_y, text_w, 14.0), props.detail);
    return ui.Rect.init(bounds.x + props.inset_x - 6.0, bounds.y + props.body_y, @max(primitives.min_extent, bounds.w - (props.inset_x - 6.0) * 2.0), @max(primitives.min_extent, bounds.h - props.body_y));
}

pub fn composeBar(view: anytype, bounds: ui.Rect, props: ComposeBarProps) (ui.RenderError || interaction.Error)!void {
    if (props.fill) |fill_color| try view.fill(bounds, fill_color, 0.0);
    try view.line(ui.Rect.init(bounds.x, bounds.y, bounds.w, 1.0));
    const tool_y = bounds.y + @max(0.0, (bounds.h - 38.0) * 0.5);
    try actionToolbar(view, ui.Rect.init(bounds.x + props.inset_x, tool_y, props.toolbar_w, 38.0), .{
        .specs = props.actions,
        .button_w = props.toolbar_button_w,
        .gap = props.toolbar_gap,
    });
    const textarea_x = bounds.x + props.inset_x + props.toolbar_w + props.textarea_gap;
    const send_x = bounds.x + bounds.w - props.inset_x - props.send_w;
    try view.textareaAt(ui.Rect.init(textarea_x, bounds.y + 15.0, @max(primitives.min_extent, send_x - textarea_x - props.textarea_gap), 44.0), props.textarea_id, "", props.textarea_value);
    try view.iconButtonAt(ui.Rect.init(send_x, tool_y, props.send_w, 38.0), props.send_id, props.send_label, props.send_icon, props.send_variant);
    if (props.footer.len != 0) try view.muted(ui.Rect.init(bounds.x + props.inset_x, bounds.y + bounds.h - 18.0, @max(primitives.min_extent, props.toolbar_w + 40.0), 14.0), props.footer);
}

pub fn contextActionPanel(view: anytype, container: ui.Rect, props: ContextActionPanelProps) (ui.RenderError || interaction.Error)!void {
    const mark = view.overlayMark();
    const x = geometry.clamp(props.x, container.x + 8.0, container.x + container.w - props.w - 8.0);
    const y = geometry.clamp(props.y, container.y + 8.0, container.y + container.h - props.h - 8.0);
    const panel_bounds = ui.Rect.init(x, y, props.w, props.h);
    _ = try floatingPanel(view, panel_bounds, .{
        .fill = props.fill,
        .border = props.border,
        .shadow = props.shadow,
        .radius = 12.0,
        .shadow_outset = 2.0,
    });
    try view.title(ui.Rect.init(panel_bounds.x + 14.0, panel_bounds.y + 12.0, panel_bounds.w - 28.0, 18.0), props.title);
    if (props.detail.len != 0) try view.muted(ui.Rect.init(panel_bounds.x + 14.0, panel_bounds.y + 36.0, panel_bounds.w - 28.0, 16.0), props.detail);
    try view.buttonAt(ui.Rect.init(panel_bounds.x + 12.0, panel_bounds.y + 66.0, 118.0, 34.0), props.primary_id, props.primary_label, .primary);
    try view.buttonAt(ui.Rect.init(panel_bounds.x + 138.0, panel_bounds.y + 66.0, 70.0, 34.0), props.secondary_id, props.secondary_label, .outline);
    view.applyOverlayMotion(mark, .{ .opacity = props.progress, .dy = (1.0 - props.progress) * 8.0 });
}

pub fn propertyEditorPanel(view: anytype, container: ui.Rect, props: PropertyEditorPanelProps) (ui.RenderError || interaction.Error)!void {
    const mark = view.overlayMark();
    const panel_w = @min(props.panel_w, @max(300.0, container.w * 0.24));
    const panel_bounds = ui.Rect.init(container.x + container.w - panel_w - 18.0, container.y + 18.0, panel_w, @min(398.0, container.h - 36.0));
    const inner = try floatingPanel(view, panel_bounds, .{
        .fill = props.fill,
        .border = props.border,
        .shadow = props.shadow,
        .radius = 14.0,
        .shadow_outset = 1.0,
        .scrim = props.scrim,
        .scrim_height = 76.0,
    });
    try view.boldText(ui.Rect.init(inner.x, inner.y, inner.w - 42.0, 24.0), props.title, view.options.style.text);
    try view.iconButtonAt(ui.Rect.init(inner.x + inner.w - 34.0, inner.y - 2.0, 32.0, 32.0), props.close_id, "Close editor", .x, .outline);
    try view.muted(ui.Rect.init(inner.x, inner.y + 31.0, inner.w, 17.0), props.detail);
    try view.muted(ui.Rect.init(inner.x, inner.y + 54.0, inner.w, 17.0), "Live changes apply immediately.");
    try view.subtleAt(ui.Rect.init(inner.x, inner.y + 86.0, inner.w, 74.0), props.preview_title, props.preview_detail);
    const section_y = inner.y + 184.0;
    try view.title(ui.Rect.init(inner.x, section_y, inner.w, 20.0), props.section_title);
    try view.muted(ui.Rect.init(inner.x, section_y + 25.0, inner.w, 18.0), props.section_detail);
    const button_w = (inner.w - 10.0) * 0.5;
    try view.buttonAt(ui.Rect.init(inner.x, section_y + 52.0, button_w, 34.0), props.prev_id, props.prev_label, .outline);
    try view.buttonAt(ui.Rect.init(inner.x + button_w + 10.0, section_y + 52.0, button_w, 34.0), props.next_id, props.next_label, .primary);
    try view.line(ui.Rect.init(inner.x, section_y + 106.0, inner.w, 1.0));
    var switch_y = section_y + 122.0;
    for (props.switches) |switch_value| {
        try view.switchAt(ui.Rect.init(inner.x, switch_y, inner.w, 32.0), switch_value.id, switch_value.label, switch_value.checked);
        switch_y += 40.0;
    }
    view.applyOverlayMotion(mark, .{ .opacity = props.progress, .dx = (1.0 - props.progress) * 18.0 });
}

pub fn section(view: anytype, bounds: ui.Rect, props: SectionProps) ui.RenderError!void {
    const text_x = if (props.icon != null) bounds.x + 42.0 else bounds.x;
    const text_w = @max(primitives.min_extent, bounds.x + bounds.w - text_x);
    if (props.icon) |icon_value| {
        const chip = ui.Rect.init(bounds.x, bounds.y + 2.0, 28.0, 28.0);
        try view.fill(chip, view.options.style.row, 7.0);
        try view.stroke(chip, view.options.style.border, 7.0);
        try view.icon(chip.withHeightCentered(15.0).withWidthCentered(15.0), icon_value, view.options.style.accent);
    }
    try view.strongText(ui.Rect.init(text_x, bounds.y, text_w, 18.0), props.title, view.options.style.text);
    if (props.detail.len != 0) {
        try view.text(ui.Rect.init(text_x, bounds.y + 23.0, text_w, 15.0), props.detail, view.options.style.muted);
    }
}

pub fn labelValue(view: anytype, bounds: ui.Rect, label: []const u8, value: []const u8, label_w: f32) ui.RenderError!void {
    const clamped_label_w = @min(bounds.w, @max(primitives.min_extent, label_w));
    try view.text(ui.Rect.init(bounds.x, bounds.y, clamped_label_w, bounds.h), label, view.options.style.muted);
    if (bounds.w > clamped_label_w) {
        try view.strongText(
            ui.Rect.init(bounds.x + clamped_label_w, bounds.y, @max(primitives.min_extent, bounds.w - clamped_label_w), bounds.h),
            value,
            view.options.style.text,
        );
    }
}

pub fn metricCard(view: anytype, bounds: ui.Rect, props: MetricCardProps) (ui.RenderError || interaction.Error)!void {
    try view.surfaceControlAt(bounds, props.id, .panel, props.selected);

    const inner = bounds.insetUniform(14.0);
    const text_x = if (props.icon != null) inner.x + 40.0 else inner.x;
    const text_w = @max(primitives.min_extent, inner.x + inner.w - text_x);
    if (props.icon) |icon_value| {
        const chip = ui.Rect.init(inner.x, inner.y, 28.0, 28.0);
        try view.fill(chip, view.options.style.row, 7.0);
        try view.stroke(chip, view.options.style.border, 7.0);
        try view.icon(chip.withHeightCentered(15.0).withWidthCentered(15.0), icon_value, view.options.style.accent);
    }
    try view.strongText(ui.Rect.init(text_x, inner.y - 1.0, text_w, 17.0), props.title, view.options.style.text);
    if (props.detail.len != 0) {
        try view.text(ui.Rect.init(text_x, inner.y + 21.0, text_w, 14.0), props.detail, view.options.style.muted);
    }
    const value_y = if (props.detail.len != 0) inner.y + 58.0 else inner.y + 36.0;
    if (props.value.len != 0) {
        try view.text(ui.Rect.init(inner.x, value_y, inner.w, 20.0), props.value, view.options.style.text);
    }
    if (props.progress) |value| {
        try view.progressAt(ui.Rect.init(inner.x, inner.y + inner.h - 24.0, inner.w, 18.0), value);
    }
}

pub fn segmentMap(view: anytype, bounds: ui.Rect, props: SegmentMapProps) (ui.RenderError || interaction.Error)!void {
    try view.fill(bounds, props.background, props.radius);
    try view.stroke(bounds, props.border, props.radius);
    const inner = bounds.insetUniform(8.0);
    var total_weight: f32 = 0.0;
    for (props.segments) |segment| {
        total_weight += @max(0.0, segment.weight);
    }
    if (props.segments.len == 0 or total_weight <= 0.0) return;

    var x = inner.x;
    for (props.segments, 0..) |segment, index| {
        const remaining = @max(primitives.min_extent, inner.x + inner.w - x);
        const normalized = @max(0.0, segment.weight) / total_weight;
        const width = if (index == props.segments.len - 1) remaining else @max(18.0, inner.w * normalized);
        const block_w = @max(primitives.min_extent, @min(width, remaining));
        const block_h = @max(18.0, inner.h * @max(0.05, @min(1.0, segment.height)));
        const block = ui.Rect.init(x, inner.y + inner.h - block_h, block_w, block_h);
        try view.selectableSubtleAt(block, segment.id, "", "");
        try view.fill(block, segment.color, props.radius - 3.0);
        try view.stroke(block, if (segment.selected) props.selected_border else props.border, props.radius - 3.0);
        x += width + props.gap;
        if (x >= inner.x + inner.w) break;
    }
}

pub fn controlGroup(view: anytype, bounds: ui.Rect, props: ControlGroupProps) (ui.RenderError || interaction.Error)!void {
    try view.selectableSubtleAt(bounds, props.id, "", "");
    const inner = bounds.insetUniform(14.0);
    try view.strongText(ui.Rect.init(inner.x, inner.y, inner.w * 0.55, 18.0), props.title, view.options.style.text);
    try view.text(ui.Rect.init(inner.x + inner.w * 0.55, inner.y + 1.0, inner.w * 0.45, 15.0), props.value, view.options.style.muted);
    try view.sliderAt(ui.Rect.init(inner.x, inner.y + 27.0, inner.w, 26.0), props.slider_id, "", props.slider_value);
    const half_w = (inner.w - 10.0) * 0.5;
    try view.buttonIconAt(ui.Rect.init(inner.x, inner.y + 66.0, half_w, 32.0), props.down_id, props.down_label, .outline, props.down_icon);
    try view.buttonIconAt(ui.Rect.init(inner.x + half_w + 10.0, inner.y + 66.0, half_w, 32.0), props.up_id, props.up_label, .primary, props.up_icon);
}

pub fn pathRow(view: anytype, bounds: ui.Rect, props: PathRowProps) (ui.RenderError || interaction.Error)!void {
    const fill_color = if (props.selected) props.selected_fill orelse view.options.style.panel else props.fill orelse view.options.style.row;
    const border_color = if (props.selected) props.accent else props.border orelse view.options.style.border;
    const text_color = props.text orelse view.options.style.text;
    const muted_color = props.muted orelse view.options.style.muted;

    try view.selectableSubtleAt(bounds, props.id, "", "");
    try view.fill(bounds, fill_color, 7.0);
    try view.stroke(bounds, border_color, 7.0);

    const marker_h = @max(primitives.min_extent, bounds.h - 18.0);
    try view.fill(ui.Rect.init(bounds.x + 9.0, bounds.y + 9.0, 7.0, marker_h), props.accent, 4.0);
    try view.strongText(ui.Rect.init(bounds.x + 24.0, bounds.y + 7.0, @max(primitives.min_extent, bounds.w - 92.0), 16.0), props.title, text_color);
    try view.text(ui.Rect.init(bounds.x + 24.0, bounds.y + 27.0, @max(primitives.min_extent, bounds.w - 92.0), 14.0), props.detail, muted_color);
    try view.text(ui.Rect.init(bounds.x + bounds.w - 62.0, bounds.y + 8.0, 56.0, 14.0), props.trailing, muted_color);
    try view.withAccent(props.progress_color).progressAt(ui.Rect.init(bounds.x + bounds.w - 62.0, bounds.y + bounds.h - 16.0, 50.0, 6.0), props.progress);
}

pub fn pipelineNode(view: anytype, bounds: ui.Rect, props: PipelineNodeProps) (ui.RenderError || interaction.Error)!void {
    const fill_color = if (props.selected) props.selected_fill orelse view.options.style.panel else props.fill orelse view.options.style.row;
    const border_color = if (props.selected) props.accent else props.border orelse view.options.style.border;
    const text_color = props.text orelse view.options.style.text;
    const muted_color = props.muted orelse view.options.style.muted;

    try view.selectableSubtleAt(bounds, props.id, "", "");
    try view.fill(bounds, fill_color, 8.0);
    try view.stroke(bounds, border_color, 8.0);

    const marker_h = @max(primitives.min_extent, bounds.h - 20.0);
    try view.fill(ui.Rect.init(bounds.x + 10.0, bounds.y + 10.0, 8.0, marker_h), props.accent, 5.0);
    try view.strongText(ui.Rect.init(bounds.x + 28.0, bounds.y + 10.0, @max(primitives.min_extent, bounds.w - 36.0), 18.0), props.title, text_color);
    try view.text(ui.Rect.init(bounds.x + 28.0, bounds.y + 32.0, @max(primitives.min_extent, bounds.w - 36.0), 16.0), props.detail, muted_color);
}

pub fn floatingPanel(view: anytype, bounds: ui.Rect, props: FloatingPanelProps) ui.RenderError!ui.Rect {
    const radius = @max(0.0, props.radius);
    if (props.shadow.a != 0 and props.shadow_size > 0.0) {
        try view.overlayRect(bounds.insetUniform(-props.shadow_outset), props.shadow, .shadow, radius + props.shadow_outset, props.shadow_size);
    }
    try view.fill(bounds, props.fill orelse view.options.style.panel, radius);
    try view.stroke(bounds, props.border orelse view.options.style.border, radius);
    if (props.scrim) |scrim_color| {
        if (props.scrim_height > 0.0) {
            try view.gradient(ui.Rect.init(bounds.x, bounds.y, bounds.w, props.scrim_height), scrim_color, ui.Color.clear, radius);
        }
    }
    return bounds.insetUniform(props.inset);
}

pub fn messageBubble(view: anytype, bounds: ui.Rect, props: MessageBubbleProps) ui.RenderError!void {
    const fill_color = if (props.outbound) props.outbound_fill else props.inbound_fill orelse view.options.style.row;
    const border_color = if (props.outbound) props.outbound_border else view.options.style.border;
    try view.fill(bounds, fill_color, props.radius);
    try view.stroke(bounds, border_color, props.radius);
    try view.wrapped(bounds.insetUniform(11.0), props.body, 2);
    if (props.media_label.len == 0) return;

    const media = ui.Rect.init(bounds.x + 10.0, bounds.y + 42.0, @max(primitives.min_extent, bounds.w - 20.0), 66.0);
    try view.subtleAt(media, props.media_label, props.media_detail);
    if (props.media_icon) |icon_value| {
        try view.icon(ui.Rect.init(media.x + media.w - 28.0, media.y + 10.0, 18.0, 18.0), icon_value, view.options.style.accent);
    }
}
