const clock = @import("../../clock.zig");
const interaction = @import("../interaction.zig");
const layout_types = @import("../layouts/Types.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const common = @import("../component_common.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");
const ui_icon = @import("../icon.zig");

const accordion_component = @import("Accordion.zig");
const app_surfaces_component = @import("AppSurfaces.zig");
const alert_component = @import("Alert.zig");
const alert_dialog_component = @import("AlertDialog.zig");
const badge_component = @import("Badge.zig");
const breadcrumb_component = @import("Breadcrumb.zig");
const button_component = @import("Button.zig");
const button_group_component = @import("ButtonGroup.zig");
const calendar_component = @import("Calendar.zig");
const card_component = @import("Card.zig");
const carousel_component = @import("Carousel.zig");
const chart_component = @import("Chart.zig");
const checkbox_component = @import("Checkbox.zig");
const combobox_component = @import("Combobox.zig");
const command_component = @import("Command.zig");
const context_menu_component = @import("ContextMenu.zig");
const dialog_component = @import("Dialog.zig");
const direction_component = @import("Direction.zig");
const drawer_component = @import("Drawer.zig");
const dropdown_menu_component = @import("DropdownMenu.zig");
const display_component = @import("Display.zig");
const empty_component = @import("Empty.zig");
const field_component = @import("Field.zig");
const graph_component = @import("Graph.zig");
const hover_card_component = @import("HoverCard.zig");
const icon_component = @import("Icon.zig");
const input_component = @import("Input.zig");
const input_group_component = @import("InputGroup.zig");
const input_otp_component = @import("InputOtp.zig");
const menubar_component = @import("Menubar.zig");
const navigation_menu_component = @import("NavigationMenu.zig");
const pagination_component = @import("Pagination.zig");
const popover_component = @import("Popover.zig");
const radio_group_component = @import("RadioGroup.zig");
const resizable_component = @import("Resizable.zig");
const row_item_component = @import("RowItem.zig");
const scroll_area_component = @import("ScrollArea.zig");
const select_component = @import("Select.zig");
const sheet_component = @import("Sheet.zig");
const sidebar_component = @import("Sidebar.zig");
const slider_component = @import("Slider.zig");
const switch_component = @import("Switch.zig");
const table_component = @import("Table.zig");
const tabs_component = @import("Tabs.zig");
const textarea_component = @import("Textarea.zig");
const text_component = @import("Text.zig");
const timeline_component = @import("Timeline.zig");
const toast_component = @import("Toast.zig");
const toggle_component = @import("Toggle.zig");
const toggle_group_component = @import("ToggleGroup.zig");
const tooltip_component = @import("Tooltip.zig");
const view_layout = @import("ViewLayout.zig");
const semantic_component = @import("Semantic.zig");
const workspace_component = @import("Workspace.zig");

pub const Error = common.Error;
pub const RenderOptions = common.RenderOptions;
pub const Accessibility = common.Accessibility;
pub const AccessibilityTree = common.AccessibilityTree;
pub const ButtonVariant = common.ButtonVariant;
pub const BadgeVariant = common.BadgeVariant;
pub const SurfaceVariant = common.SurfaceVariant;
pub const Icon = icon_component.Icon;
pub const IconSlot = icon_component.IconSlot;

pub const Component = union(enum) {
    text: text_component.Text,
    accordion: accordion_component.Accordion,
    alert: alert_component.Alert,
    alert_dialog: alert_dialog_component.AlertDialog,
    aspect_ratio: display_component.AspectRatio,
    calendar: calendar_component.Calendar,
    carousel: carousel_component.Carousel,
    chart: chart_component.Chart,
    combobox: combobox_component.Combobox,
    card: card_component.Card,
    empty: empty_component.Empty,
    badge: badge_component.Badge,
    avatar: display_component.Avatar,
    kbd: display_component.Kbd,
    label: display_component.Label,
    separator: display_component.Separator,
    scroll_area: scroll_area_component.ScrollArea,
    skeleton: display_component.Skeleton,
    spinner: display_component.Spinner,
    breadcrumb: breadcrumb_component.Breadcrumb,
    menubar: menubar_component.Menubar,
    navigation_menu: navigation_menu_component.NavigationMenu,
    command: command_component.Command,
    context_menu: context_menu_component.ContextMenu,
    dialog: dialog_component.Dialog,
    direction: direction_component.Direction,
    drawer: drawer_component.Drawer,
    dropdown_menu: dropdown_menu_component.DropdownMenu,
    field: field_component.Field,
    hover_card: hover_card_component.HoverCard,
    input_otp: input_otp_component.InputOtp,
    icon: icon_component.Icon,
    button: button_component.Button,
    icon_button: button_component.IconButton,
    button_group: button_group_component.ButtonGroup,
    toggle_group: toggle_group_component.ToggleGroup,
    toggle: toggle_component.Toggle,
    input: input_component.Input,
    input_group: input_group_component.InputGroup,
    textarea: textarea_component.Textarea,
    select: select_component.Select,
    checkbox: checkbox_component.Checkbox,
    radio_group: radio_group_component.RadioGroup,
    switch_control: switch_component.Switch,
    pagination: pagination_component.Pagination,
    popover: popover_component.Popover,
    resizable: resizable_component.Resizable,
    sheet: sheet_component.Sheet,
    sidebar: sidebar_component.Sidebar,
    progress: display_component.Progress,
    slider: slider_component.Slider,
    tabs: tabs_component.Tabs,
    table: table_component.Table,
    tooltip: tooltip_component.Tooltip,
    toast: toast_component.Toast,
    row_item: row_item_component.RowItem,

    pub fn node(self: Component) ui.Node {
        return switch (self) {
            inline else => |component| component.node(),
        };
    }

    pub fn render(self: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const resolved_options = self.componentFlags().apply(options.withControlId(self.controlId()));
        switch (self) {
            inline else => |component| try component.render(scene, bounds, resolved_options),
        }
        try primitives.renderControlStateOverlay(scene, bounds, resolved_options, primitives.control_radius);
    }

    pub fn collectInteractions(self: Component, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) interaction.Error!void {
        const resolved_options = self.componentFlags().apply(options.withControlId(self.controlId()));
        if (resolved_options.control.disabled) return;
        switch (self) {
            inline else => |component| {
                if (comptime @hasDecl(@TypeOf(component), "collectInteractions")) {
                    const T = @TypeOf(component);
                    const fn_info = @typeInfo(@TypeOf(T.collectInteractions)).@"fn";
                    if (fn_info.params.len >= 4) {
                        try component.collectInteractions(collector, bounds, resolved_options);
                    } else {
                        try component.collectInteractions(collector, bounds);
                    }
                }
            },
        }
    }

    pub fn renderInteractive(self: Component, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) (ui.RenderError || interaction.Error)!void {
        try self.render(scene, bounds, options);
        try self.collectInteractions(collector, bounds, options);
    }

    pub fn measure(self: Component, constraints: layout_types.Constraints, options: RenderOptions) layout_types.Measurement {
        return switch (self) {
            inline else => |component| component.measure(constraints, options),
        };
    }

    pub fn accessibility(self: Component) Accessibility {
        return switch (self) {
            inline else => |component| if (comptime @hasDecl(@TypeOf(component), "accessibility")) component.accessibility() else .{ .role = .generic },
        };
    }

    pub fn collectAccessibility(self: Component, tree: *AccessibilityTree, bounds: ui.Rect, options: RenderOptions) common.AccessibilityError!void {
        _ = options;
        const metadata = self.accessibility();
        if (metadata.role == .generic and metadata.label.len == 0 and metadata.control_id == null) return;
        try tree.append(.{ .metadata = metadata, .bounds = bounds });
    }

    pub fn withFlags(self: Component, flags: common.ComponentFlags) Component {
        var next = self;
        switch (next) {
            inline else => |*component| {
                if (comptime @hasField(@TypeOf(component.*), "flags")) {
                    component.flags = component.flags.merge(flags);
                }
            },
        }
        return next;
    }

    pub fn disabled(self: Component) Component {
        return self.withFlags(.{ .disabled = true });
    }

    pub fn loading(self: Component) Component {
        return self.withFlags(.{ .loading = true });
    }

    pub fn invalid(self: Component) Component {
        return self.withFlags(.{ .invalid = true });
    }

    fn controlId(self: Component) ?u32 {
        return self.accessibility().control_id;
    }

    fn componentFlags(self: Component) common.ComponentFlags {
        return switch (self) {
            inline else => |component| if (comptime @hasField(@TypeOf(component), "flags")) component.flags else .{},
        };
    }

    pub fn toObject(self: Component, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.writeObject(Component, self, ui_out, object_out, epoch);
    }

    pub fn fromObject(canonical: []const u8) Error!Component {
        const view = object.View.decode(canonical) catch return error.Corrupt;
        return fromView(view);
    }

    pub fn fromView(view: object.View) Error!Component {
        return fromNode(try component_codec.singleNode(view));
    }

    pub fn fromNode(node_value: ui.Node) Error!Component {
        return switch (node_value) {
            inline else => |payload, tag| {
                if (comptime @hasField(Component, @tagName(tag))) {
                    return @unionInit(Component, @tagName(tag), try componentFromNode(@FieldType(Component, @tagName(tag)), payload));
                }
                return error.UnsupportedComponent;
            },
        };
    }
};

pub const registrations = @typeInfo(Component).@"union".fields;

pub fn text(value: []const u8) Component {
    return .{ .text = .{ .value = value } };
}

pub fn card(title: []const u8, detail: []const u8, variant: SurfaceVariant) Component {
    return .{ .card = .{ .title = title, .detail = detail, .variant = variant } };
}

pub fn selectableCard(id: u32, title: []const u8, detail: []const u8, variant: SurfaceVariant) Component {
    return .{ .card = .{ .id = id, .title = title, .detail = detail, .variant = variant } };
}

pub fn panel(title: []const u8, detail: []const u8) Component {
    return card(title, detail, .panel);
}

pub fn selectablePanel(id: u32, title: []const u8, detail: []const u8) Component {
    return selectableCard(id, title, detail, .panel);
}

pub fn elevated(title: []const u8, detail: []const u8) Component {
    return card(title, detail, .elevated);
}

pub fn selectableElevated(id: u32, title: []const u8, detail: []const u8) Component {
    return selectableCard(id, title, detail, .elevated);
}

pub fn subtle(title: []const u8, detail: []const u8) Component {
    return card(title, detail, .subtle);
}

pub fn selectableSubtle(id: u32, title: []const u8, detail: []const u8) Component {
    return selectableCard(id, title, detail, .subtle);
}

pub fn progress(value: f32) Component {
    return .{ .progress = .{ .value = value } };
}

pub fn badge(label: []const u8, variant: BadgeVariant) Component {
    return .{ .badge = .{ .label = label, .variant = variant } };
}

pub fn empty(title: []const u8, detail: []const u8) Component {
    return .{ .empty = .{ .title = title, .detail = detail } };
}

pub fn icon(icon_value: ui_icon.Icon) Component {
    return .{ .icon = Icon.named(icon_value) };
}

pub fn input(id: u32, placeholder: []const u8) Component {
    return .{ .input = .{ .id = id, .placeholder = placeholder } };
}

pub fn inputValue(id: u32, placeholder: []const u8, value: []const u8) Component {
    return .{ .input = .{ .id = id, .placeholder = placeholder, .value = value } };
}

pub fn inputIcon(id: u32, placeholder: []const u8, icon_value: ui_icon.Icon) Component {
    return .{ .input = .{ .id = id, .placeholder = placeholder, .icon_slot = IconSlot.named(.leading, icon_value) } };
}

pub fn rowItem(id: u32, title: []const u8, detail: []const u8) Component {
    return .{ .row_item = .{ .id = id, .title = title, .detail = detail } };
}

pub fn rowItemIcon(id: u32, title: []const u8, detail: []const u8, icon_value: ui_icon.Icon) Component {
    return .{ .row_item = .{ .id = id, .title = title, .detail = detail, .leading_icon = IconSlot.named(.leading, icon_value) } };
}

pub fn button(id: u32, label: []const u8, variant: ButtonVariant, icon_slot: IconSlot) Component {
    return .{ .button = .{ .id = id, .label = label, .variant = variant, .icon_slot = icon_slot } };
}

pub fn buttonText(id: u32, label: []const u8, variant: ButtonVariant) Component {
    return button(id, label, variant, .none);
}

pub fn buttonIcon(id: u32, label: []const u8, variant: ButtonVariant, icon_value: ui_icon.Icon) Component {
    return button(id, label, variant, IconSlot.named(.leading, icon_value));
}

pub fn iconButton(id: u32, label: []const u8, icon_value: Icon, variant: ButtonVariant) Component {
    return .{ .icon_button = .{ .id = id, .label = label, .icon = icon_value, .variant = variant } };
}

pub fn iconButtonNamed(id: u32, label: []const u8, icon_value: ui_icon.Icon, variant: ButtonVariant) Component {
    return iconButton(id, label, Icon.named(icon_value), variant);
}

pub fn textarea(id: u32, placeholder: []const u8) Component {
    return .{ .textarea = .{ .id = id, .placeholder = placeholder } };
}

pub fn textareaValue(id: u32, placeholder: []const u8, value: []const u8) Component {
    return .{ .textarea = .{ .id = id, .placeholder = placeholder, .value = value } };
}

pub fn slider(id: u32, label: []const u8, value: f32) Component {
    return .{ .slider = .{ .id = id, .label = label, .value = value } };
}

pub fn select(id: u32, label: []const u8) Component {
    return .{ .select = .{ .id = id, .label = label } };
}

pub fn selectIcon(id: u32, label: []const u8, icon_value: ui_icon.Icon) Component {
    return .{ .select = .{ .id = id, .label = label, .icon_slot = IconSlot.named(.trailing, icon_value) } };
}

pub fn switchControl(id: u32, label: []const u8, checked: bool) Component {
    return .{ .switch_control = .{ .id = id, .label = label, .checked = checked } };
}

pub fn checkbox(id: u32, label: []const u8, checked: bool) Component {
    return .{ .checkbox = .{ .id = id, .label = label, .checked = checked } };
}

pub fn toggle(id: u32, label: []const u8, pressed: bool) Component {
    return .{ .toggle = .{ .id = id, .label = label, .pressed = pressed } };
}

pub fn tabs(id: u32, first: []const u8, second: []const u8, active: u16) Component {
    return .{ .tabs = .{ .id = id, .first = first, .second = second, .active = active } };
}

pub fn chart(id: u32, label: []const u8) Component {
    return .{ .chart = .{ .id = id, .label = label } };
}

pub fn alert(title: []const u8, detail: []const u8) Component {
    return .{ .alert = .{ .title = title, .detail = detail } };
}

pub fn destructiveAlert(title: []const u8, detail: []const u8) Component {
    return .{ .alert = .{ .title = title, .detail = detail, .destructive = true } };
}

pub fn command(id: u32, placeholder: []const u8) Component {
    return .{ .command = .{ .id = id, .placeholder = placeholder } };
}

pub fn toast(id: u32, title: []const u8, detail: []const u8) Component {
    return .{ .toast = .{ .id = id, .title = title, .detail = detail } };
}

pub fn tooltip(id: u32, trigger: []const u8, content: []const u8) Component {
    return .{ .tooltip = .{ .id = id, .trigger = trigger, .content = content } };
}

pub fn separator() Component {
    return .{ .separator = .{} };
}

pub fn render(component: Component, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    try component.render(scene, bounds, options);
}

pub fn renderInteractive(component: Component, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) (ui.RenderError || interaction.Error)!void {
    try component.renderInteractive(scene, collector, bounds, options);
}

pub fn renderLine(scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    try render(separator(), scene, bounds, options);
}

pub fn renderer(scene: *ui.Scene, collector: ?*interaction.Collector, options: RenderOptions) View {
    return .{ .scene = scene, .collector = collector, .options = options };
}

fn clampUnit(value: f32) f32 {
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
}

fn colorWithAlphaUnit(color: ui.Color, unit: f32) ui.Color {
    var out = color;
    out.a = @as(u8, @intFromFloat(@round(@as(f32, @floatFromInt(color.a)) * clampUnit(unit))));
    return out;
}

pub const SectionProps = app_surfaces_component.SectionProps;
pub const MetricCardProps = app_surfaces_component.MetricCardProps;
pub const Segment = app_surfaces_component.Segment;
pub const SegmentMapProps = app_surfaces_component.SegmentMapProps;

pub const TimelineBlock = timeline_component.Block;
pub const TimelineLaneProps = timeline_component.LaneProps;
pub const TimelineViewportLane = timeline_component.ViewportLane;
pub const TimelineViewportMark = timeline_component.ViewportMark;
pub const TimelineViewportControls = timeline_component.ViewportControls;
pub const TimelineViewportAction = timeline_component.ViewportAction;
pub const TimelineViewportState = timeline_component.ViewportState;
pub const TimelineViewportProps = timeline_component.ViewportProps;

pub fn timelineViewportActionForHit(hit_id: u32, controls: TimelineViewportControls) ?TimelineViewportAction {
    return timeline_component.actionForHit(hit_id, controls);
}

pub fn applyTimelineViewportAction(state: *TimelineViewportState, action: TimelineViewportAction) void {
    timeline_component.applyAction(state, action);
}

pub const ControlGroupProps = app_surfaces_component.ControlGroupProps;
pub const PathRowProps = app_surfaces_component.PathRowProps;
pub const PipelineNodeProps = app_surfaces_component.PipelineNodeProps;
pub const FloatingPanelProps = app_surfaces_component.FloatingPanelProps;
pub const MessageBubbleProps = app_surfaces_component.MessageBubbleProps;
pub const PanelScaffoldProps = app_surfaces_component.PanelScaffoldProps;

pub const WorkspaceTopBarProps = workspace_component.TopBarProps;
pub const WorkspaceStatusBarProps = workspace_component.StatusBarProps;
pub const WorkspaceSurfaceProps = workspace_component.SurfaceProps;

pub const IconButtonSpec = app_surfaces_component.IconButtonSpec;
pub const IconButtonValueSpec = app_surfaces_component.IconButtonValueSpec;
pub const ToolbarDirection = app_surfaces_component.ToolbarDirection;
pub const ActionToolbarProps = app_surfaces_component.ActionToolbarProps;
pub const PanelListItem = app_surfaces_component.PanelListItem;
pub const PanelListProps = app_surfaces_component.PanelListProps;
pub const HeaderBadge = app_surfaces_component.HeaderBadge;
pub const PageHeaderProps = app_surfaces_component.PageHeaderProps;
pub const WorkspaceRailProps = app_surfaces_component.WorkspaceRailProps;
pub const WorkspaceRailValueProps = app_surfaces_component.WorkspaceRailValueProps;
pub const WorkspaceSidebarChromeProps = app_surfaces_component.WorkspaceSidebarChromeProps;
pub const ComposeBarProps = app_surfaces_component.ComposeBarProps;
pub const ContextActionPanelProps = app_surfaces_component.ContextActionPanelProps;
pub const EditorSwitchSpec = app_surfaces_component.EditorSwitchSpec;
pub const PropertyEditorPanelProps = app_surfaces_component.PropertyEditorPanelProps;

pub const SemanticKind = semantic_component.Kind;
pub const SemanticImportance = semantic_component.Importance;
pub const SemanticState = semantic_component.State;
pub const SemanticMode = semantic_component.Mode;
pub const SemanticFocus = semantic_component.Focus;
pub const SemanticDensity = semantic_component.Density;
pub const SemanticIntent = semantic_component.Intent;
pub const SemanticItem = semantic_component.Item;
pub const SemanticViewProps = semantic_component.ViewProps;

pub const StackCursor = view_layout.StackCursor;
pub const RowCursor = view_layout.RowCursor;
pub const Split = view_layout.Split;

pub const WorkspaceShellProps = workspace_component.ShellProps;
pub const WorkspaceShell = workspace_component.Shell;
pub const ResponsivePanesProps = workspace_component.ResponsivePanesProps;
pub const ResponsivePanes = workspace_component.ResponsivePanes;

pub const TimelineMark = timeline_component.Mark;

pub const OverlayMotion = struct {
    opacity: f32 = 1.0,
    dx: f32 = 0.0,
    dy: f32 = 0.0,
    promote: bool = true,
};

pub const Grid = view_layout.Grid;

pub const View = struct {
    scene: *ui.Scene,
    collector: ?*interaction.Collector = null,
    options: RenderOptions = .{},

    pub fn withOptions(self: View, options: RenderOptions) View {
        var next = self;
        next.options = options;
        return next;
    }

    pub fn withStyle(self: View, style: ui.Style) View {
        return self.withOptions(self.options.withStyle(style));
    }

    pub fn withAccent(self: View, color: ui.Color) View {
        return self.withOptions(self.options.withAccent(color));
    }

    pub fn withTextColor(self: View, color: ui.Color) View {
        return self.withOptions(self.options.withTextColor(color));
    }

    pub fn withControl(self: View, control: common.ControlState) View {
        return self.withOptions(self.options.withControl(control));
    }

    pub fn withMergedControl(self: View, control: common.ControlState) View {
        return self.withOptions(self.options.withMergedControl(control));
    }

    pub fn withControlSize(self: View, size: common.ControlSize) View {
        return self.withOptions(self.options.withControlSize(size));
    }

    pub fn hasCollector(self: View) bool {
        return self.collector != null;
    }

    pub fn interactionRegions(self: View) []const interaction.Region {
        const collector = self.collector orelse return &.{};
        return collector.written();
    }

    pub fn draw(self: View, component: Component, bounds: ui.Rect) ui.RenderError!void {
        try component.render(self.scene, bounds, self.options);
    }

    pub fn drawWith(self: View, component: Component, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try component.render(self.scene, bounds, options);
    }

    pub fn interactive(self: View, component: Component, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
        const collector = self.collector orelse return error.MissingInteractionCollector;
        try component.renderInteractive(self.scene, collector, bounds, self.options);
    }

    pub fn interactiveWith(self: View, component: Component, bounds: ui.Rect, options: RenderOptions) (ui.RenderError || interaction.Error)!void {
        const collector = self.collector orelse return error.MissingInteractionCollector;
        try component.renderInteractive(self.scene, collector, bounds, options);
    }

    pub fn drawWithControl(self: View, component: Component, bounds: ui.Rect, control: common.ControlState) ui.RenderError!void {
        try self.drawWith(component, bounds, self.options.withMergedControl(control));
    }

    pub fn interactiveWithControl(self: View, component: Component, bounds: ui.Rect, control: common.ControlState) (ui.RenderError || interaction.Error)!void {
        try self.interactiveWith(component, bounds, self.options.withMergedControl(control));
    }

    pub fn hit(self: View, bounds: ui.Rect, kind: ui.HitKind, id: u32) interaction.Error!void {
        const collector = self.collector orelse return error.MissingInteractionCollector;
        try collector.addHit(bounds, kind, id);
    }

    pub fn pushClip(self: View, bounds: ui.Rect) ui.RenderError!bool {
        return self.scene.pushClip(bounds);
    }

    pub fn popClip(self: View) void {
        self.scene.popClip();
    }

    pub fn buttonHit(self: View, bounds: ui.Rect, id: u32) interaction.Error!void {
        try self.hit(bounds, .button, id);
    }

    pub fn line(self: View, bounds: ui.Rect) ui.RenderError!void {
        try self.draw(separator(), bounds);
    }

    pub fn text(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
        try self.scene.pushText(bounds, value, color);
    }

    pub fn alignedText(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
        try self.scene.pushAlignedText(bounds, value, color, alignment);
    }

    pub fn strongText(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
        try self.scene.pushStrongText(bounds, value, color);
    }

    pub fn boldText(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
        try self.scene.pushBoldText(bounds, value, color);
    }

    pub fn icon(self: View, bounds: ui.Rect, icon_value: ui_icon.Icon, color: ui.Color) ui.RenderError!void {
        try Icon.named(icon_value).renderColor(self.scene, bounds, color);
    }

    pub fn overlayRect(self: View, bounds: ui.Rect, color: ui.Color, mode: ui.RectMode, radius: f32, shadow: f32) ui.RenderError!void {
        try self.scene.pushOverlayRect(bounds, color, mode, radius, shadow);
    }

    pub fn selectionOverlay(self: View, bounds: ui.Rect, border: ui.Color, fill_color: ui.Color, progress_unit: f32, emphasized: bool) ui.RenderError!void {
        const unit = clampUnit(progress_unit);
        if (emphasized) try self.overlayRect(bounds, colorWithAlphaUnit(fill_color, unit), .fill, 12.0, 0.0);
        try self.overlayRect(bounds.insetUniform(-2.0), colorWithAlphaUnit(border, unit), .border, 14.0, 0.0);
    }

    pub fn overlayMark(self: View) ui.Cursor {
        return self.scene.cursor();
    }

    pub fn applyOverlayMotion(self: View, mark: ui.Cursor, motion: OverlayMotion) void {
        self.scene.applyOpacitySince(mark, motion.opacity);
        self.scene.translateSince(mark, motion.dx, motion.dy);
        if (motion.promote) self.scene.promoteSinceToOverlay(mark);
    }

    pub fn fill(self: View, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
        try self.scene.pushRect(bounds, color, .fill, radius, 0.0);
    }

    pub fn stroke(self: View, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
        try self.scene.pushRect(bounds, color, .border, radius, 0.0);
    }

    pub fn frame(self: View, bounds: ui.Rect, fill_color: ui.Color, border_color: ui.Color, radius: f32) ui.RenderError!void {
        try self.fill(bounds, fill_color, radius);
        try self.stroke(bounds, border_color, radius);
    }

    pub fn lineRect(self: View, x0: f32, y0: f32, x1: f32, y1: f32, color: ui.Color, thickness: f32) ui.RenderError!void {
        try graph_component.lineRect(self, x0, y0, x1, y1, color, thickness);
    }

    pub fn elbowEdge(self: View, from: ui.Rect, to: ui.Rect, color: ui.Color, thickness: f32) ui.RenderError!void {
        try graph_component.elbowEdge(self, from, to, color, thickness);
    }

    pub fn timelineAxis(self: View, axis: ui.Rect, marks: []const TimelineMark, line_color: ui.Color, label_color: ui.Color) ui.RenderError!void {
        try timeline_component.timelineAxis(self, axis, marks, line_color, label_color);
    }

    pub fn gradient(self: View, bounds: ui.Rect, top: ui.Color, bottom: ui.Color, radius: f32) ui.RenderError!void {
        try self.scene.pushGradientRect(bounds, top, bottom, radius);
    }

    pub fn topScrim(self: View, bounds: ui.Rect, color: ui.Color, height: f32, radius: f32) ui.RenderError!void {
        if (height <= 0.0 or color.a == 0) return;
        try self.gradient(ui.Rect.init(bounds.x, bounds.y, bounds.w, height), color, ui.Color.clear, radius);
    }

    pub fn column(self: View, bounds: ui.Rect, gap: f32) StackCursor {
        _ = self;
        return StackCursor.init(bounds, gap);
    }

    pub fn row(self: View, bounds: ui.Rect, gap: f32) RowCursor {
        _ = self;
        return RowCursor.init(bounds, gap);
    }

    pub fn splitLeft(self: View, bounds: ui.Rect, width: f32, gap: f32) Split {
        _ = self;
        return view_layout.splitLeft(bounds, width, gap);
    }

    pub fn splitRight(self: View, bounds: ui.Rect, width: f32, gap: f32) Split {
        _ = self;
        return view_layout.splitRight(bounds, width, gap);
    }

    pub fn splitTop(self: View, bounds: ui.Rect, height: f32, gap: f32) Split {
        _ = self;
        return view_layout.splitTop(bounds, height, gap);
    }

    pub fn splitBottom(self: View, bounds: ui.Rect, height: f32, gap: f32) Split {
        _ = self;
        return view_layout.splitBottom(bounds, height, gap);
    }

    pub fn grid(self: View, bounds: ui.Rect, columns: usize, gap: f32, item_h: f32) Grid {
        _ = self;
        return .{ .bounds = bounds, .columns = @max(@as(usize, 1), columns), .gap = gap, .item_h = item_h };
    }

    pub fn workspaceShell(self: View, bounds: ui.Rect, props: WorkspaceShellProps) WorkspaceShell {
        _ = self;
        return workspace_component.shell(bounds, props);
    }

    pub fn workspaceSurface(self: View, bounds: ui.Rect, props: WorkspaceSurfaceProps) ui.RenderError!WorkspaceShell {
        return workspace_component.surface(self, bounds, props);
    }

    pub fn responsivePanes(self: View, bounds: ui.Rect, props: ResponsivePanesProps) ResponsivePanes {
        _ = self;
        return workspace_component.responsivePanes(bounds, props);
    }

    pub fn title(self: View, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
        try self.strongText(bounds, value, self.options.style.text);
    }

    pub fn body(self: View, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
        try self.text(bounds, value, self.options.style.text);
    }

    pub fn muted(self: View, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
        try self.text(bounds, value, self.options.style.muted);
    }

    pub fn wrapped(self: View, bounds: ui.Rect, value: []const u8, max_lines: usize) ui.RenderError!void {
        try text_component.Text.renderWrapped(self.scene, bounds, value, self.options.style.text, .{
            .line_height = 16.0,
            .average_char_width = 7.0,
            .max_lines = max_lines,
        });
    }

    pub fn wrappedWith(self: View, bounds: ui.Rect, value: []const u8, color: ui.Color, line_height: f32, average_char_width: f32, max_lines: usize) ui.RenderError!void {
        try text_component.Text.renderWrapped(self.scene, bounds, value, color, .{
            .line_height = line_height,
            .average_char_width = average_char_width,
            .max_lines = max_lines,
        });
    }

    pub fn iconButtonAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, icon_value: ui_icon.Icon, variant: ButtonVariant) (ui.RenderError || interaction.Error)!void {
        try self.interactive(iconButtonNamed(id, label, icon_value, variant), bounds);
    }

    pub fn iconButtonValueAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, icon_value: Icon, variant: ButtonVariant) (ui.RenderError || interaction.Error)!void {
        try self.interactive(.{ .icon_button = .{ .id = id, .label = label, .icon = icon_value, .variant = variant } }, bounds);
    }

    pub fn buttonAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, variant: ButtonVariant) (ui.RenderError || interaction.Error)!void {
        try self.interactive(buttonText(id, label, variant), bounds);
    }

    pub fn buttonSlotAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, variant: ButtonVariant, icon_slot: IconSlot) (ui.RenderError || interaction.Error)!void {
        try self.interactive(.{ .button = .{ .id = id, .label = label, .variant = variant, .icon_slot = icon_slot } }, bounds);
    }

    pub fn buttonIconAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, variant: ButtonVariant, icon_value: ui_icon.Icon) (ui.RenderError || interaction.Error)!void {
        try self.interactive(buttonIcon(id, label, variant, icon_value), bounds);
    }

    pub fn textareaAt(self: View, bounds: ui.Rect, id: u32, placeholder: []const u8, value: []const u8) (ui.RenderError || interaction.Error)!void {
        try self.interactive(textareaValue(id, placeholder, value), bounds);
    }

    pub fn textareaPlaceholderAt(self: View, bounds: ui.Rect, id: u32, placeholder: []const u8) (ui.RenderError || interaction.Error)!void {
        try self.interactive(textarea(id, placeholder), bounds);
    }

    pub fn sliderAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, value: f32) (ui.RenderError || interaction.Error)!void {
        try self.interactive(slider(id, label, value), bounds);
    }

    pub fn switchAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, checked: bool) (ui.RenderError || interaction.Error)!void {
        try self.interactive(switchControl(id, label, checked), bounds);
    }

    pub fn selectAt(self: View, bounds: ui.Rect, id: u32, label: []const u8, icon_value: ?ui_icon.Icon) (ui.RenderError || interaction.Error)!void {
        const component_value = if (icon_value) |value| selectIcon(id, label, value) else select(id, label);
        try self.interactive(component_value, bounds);
    }

    pub fn chartAt(self: View, bounds: ui.Rect, id: u32, label: []const u8) (ui.RenderError || interaction.Error)!void {
        try self.interactive(chart(id, label), bounds);
    }

    pub fn badgeAt(self: View, bounds: ui.Rect, label: []const u8, variant: BadgeVariant) ui.RenderError!void {
        try self.draw(badge(label, variant), bounds);
    }

    pub fn progressAt(self: View, bounds: ui.Rect, value: f32) ui.RenderError!void {
        try self.draw(progress(value), bounds);
    }

    pub fn emptyAt(self: View, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
        try self.draw(empty(title_value, detail_value), bounds);
    }

    pub fn rowItemAt(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
        try self.draw(rowItem(id, title_value, detail_value), bounds);
    }

    pub fn rowItemIconWithControlAt(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8, icon_value: ui_icon.Icon, control: common.ControlState) ui.RenderError!void {
        try self.drawWithControl(rowItemIcon(id, title_value, detail_value, icon_value), bounds, control);
    }

    pub fn surfaceAt(self: View, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8, variant: SurfaceVariant) ui.RenderError!void {
        try self.draw(card(title_value, detail_value, variant), bounds);
    }

    pub fn selectableSurfaceAt(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8, variant: SurfaceVariant) (ui.RenderError || interaction.Error)!void {
        try self.interactive(selectableCard(id, title_value, detail_value, variant), bounds);
    }

    pub fn surfaceControlAt(self: View, bounds: ui.Rect, id: ?u32, variant: SurfaceVariant, selected: bool) (ui.RenderError || interaction.Error)!void {
        if (id) |control_id| {
            try self.interactiveWithControl(selectableCard(control_id, "", "", variant), bounds, .{ .active = selected });
        } else {
            try self.drawWithControl(card("", "", variant), bounds, .{ .active = selected });
        }
    }

    pub fn panelAt(self: View, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
        try self.surfaceAt(bounds, title_value, detail_value, .panel);
    }

    pub fn selectablePanelAt(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8) (ui.RenderError || interaction.Error)!void {
        try self.selectableSurfaceAt(bounds, id, title_value, detail_value, .panel);
    }

    pub fn elevatedAt(self: View, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
        try self.surfaceAt(bounds, title_value, detail_value, .elevated);
    }

    pub fn selectableElevatedAt(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8) (ui.RenderError || interaction.Error)!void {
        try self.selectableSurfaceAt(bounds, id, title_value, detail_value, .elevated);
    }

    pub fn subtleAt(self: View, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
        try self.surfaceAt(bounds, title_value, detail_value, .subtle);
    }

    pub fn selectableSubtleAt(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8) (ui.RenderError || interaction.Error)!void {
        try self.selectableSurfaceAt(bounds, id, title_value, detail_value, .subtle);
    }

    pub fn panelBody(self: View, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8, variant: SurfaceVariant, inset: f32) ui.RenderError!ui.Rect {
        try self.surfaceAt(bounds, title_value, detail_value, variant);
        return bounds.insetUniform(inset);
    }

    pub fn panelScaffold(self: View, bounds: ui.Rect, props: PanelScaffoldProps) (ui.RenderError || interaction.Error)!ui.Rect {
        return app_surfaces_component.panelScaffold(self, bounds, props);
    }

    pub fn workspaceTopBar(self: View, bounds: ui.Rect, props: WorkspaceTopBarProps) ui.RenderError!void {
        try workspace_component.topBar(self, bounds, props);
    }

    pub fn workspaceStatusBar(self: View, bounds: ui.Rect, props: WorkspaceStatusBarProps) ui.RenderError!void {
        try workspace_component.statusBar(self, bounds, props);
    }

    pub fn iconButtonRow(self: View, bounds: ui.Rect, specs: []const IconButtonSpec, button_w: f32, gap: f32) (ui.RenderError || interaction.Error)!void {
        var row_cursor = self.row(bounds, gap);
        for (specs) |spec| {
            const slot = row_cursor.take(button_w);
            try self.iconButtonAt(slot, spec.id, spec.label, spec.icon, spec.variant);
        }
    }

    pub fn iconButtonColumn(self: View, bounds: ui.Rect, specs: []const IconButtonSpec, button_h: f32, gap: f32) (ui.RenderError || interaction.Error)!void {
        var column_cursor = self.column(bounds, gap);
        for (specs) |spec| {
            const slot = column_cursor.take(button_h);
            try self.iconButtonAt(slot, spec.id, spec.label, spec.icon, spec.variant);
        }
    }

    pub fn actionToolbar(self: View, bounds: ui.Rect, props: ActionToolbarProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.actionToolbar(self, bounds, props);
    }

    pub fn selectableRow(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8, icon_value: ui_icon.Icon, active: bool) (ui.RenderError || interaction.Error)!void {
        try self.interactiveWithControl(rowItemIcon(id, title_value, detail_value, icon_value), bounds, .{ .active = active });
    }

    pub fn selectableRowText(self: View, bounds: ui.Rect, id: u32, title_value: []const u8, detail_value: []const u8, active: bool) (ui.RenderError || interaction.Error)!void {
        try self.interactiveWithControl(rowItem(id, title_value, detail_value), bounds, .{ .active = active });
    }

    pub fn panelList(self: View, bounds: ui.Rect, props: PanelListProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.panelList(self, bounds, props);
    }

    pub fn pageHeader(self: View, bounds: ui.Rect, props: PageHeaderProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.pageHeader(self, bounds, props);
    }

    pub fn workspaceRail(self: View, bounds: ui.Rect, props: WorkspaceRailProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.workspaceRail(self, bounds, props);
    }

    pub fn workspaceRailValues(self: View, bounds: ui.Rect, props: WorkspaceRailValueProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.workspaceRailValues(self, bounds, props);
    }

    pub fn workspaceSidebarChrome(self: View, bounds: ui.Rect, props: WorkspaceSidebarChromeProps) ui.RenderError!ui.Rect {
        return app_surfaces_component.workspaceSidebarChrome(self, bounds, props);
    }

    pub fn composeBar(self: View, bounds: ui.Rect, props: ComposeBarProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.composeBar(self, bounds, props);
    }

    pub fn contextActionPanel(self: View, container: ui.Rect, props: ContextActionPanelProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.contextActionPanel(self, container, props);
    }

    pub fn propertyEditorPanel(self: View, container: ui.Rect, props: PropertyEditorPanelProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.propertyEditorPanel(self, container, props);
    }

    pub fn section(self: View, bounds: ui.Rect, props: SectionProps) ui.RenderError!void {
        try app_surfaces_component.section(self, bounds, props);
    }

    pub fn labelValue(self: View, bounds: ui.Rect, label: []const u8, value: []const u8, label_w: f32) ui.RenderError!void {
        try app_surfaces_component.labelValue(self, bounds, label, value, label_w);
    }

    pub fn metricCard(self: View, bounds: ui.Rect, props: MetricCardProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.metricCard(self, bounds, props);
    }

    pub fn segmentMap(self: View, bounds: ui.Rect, props: SegmentMapProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.segmentMap(self, bounds, props);
    }

    pub fn timelineLane(self: View, axis: ui.Rect, props: TimelineLaneProps) (ui.RenderError || interaction.Error)!void {
        try timeline_component.lane(self, axis, props);
    }

    pub fn timelineViewport(self: View, bounds: ui.Rect, props: TimelineViewportProps) (ui.RenderError || interaction.Error)!void {
        try timeline_component.viewport(self, bounds, props);
    }

    pub fn controlGroup(self: View, bounds: ui.Rect, props: ControlGroupProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.controlGroup(self, bounds, props);
    }

    pub fn pathRow(self: View, bounds: ui.Rect, props: PathRowProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.pathRow(self, bounds, props);
    }

    pub fn pipelineNode(self: View, bounds: ui.Rect, props: PipelineNodeProps) (ui.RenderError || interaction.Error)!void {
        try app_surfaces_component.pipelineNode(self, bounds, props);
    }

    pub fn floatingPanel(self: View, bounds: ui.Rect, props: FloatingPanelProps) ui.RenderError!ui.Rect {
        return app_surfaces_component.floatingPanel(self, bounds, props);
    }

    pub fn messageBubble(self: View, bounds: ui.Rect, props: MessageBubbleProps) ui.RenderError!void {
        try app_surfaces_component.messageBubble(self, bounds, props);
    }

    pub fn semanticView(self: View, bounds: ui.Rect, props: SemanticViewProps) (ui.RenderError || interaction.Error)!void {
        try semantic_component.renderView(self, bounds, props);
    }

    pub fn semanticCard(self: View, bounds: ui.Rect, item: SemanticItem) (ui.RenderError || interaction.Error)!void {
        try semantic_component.renderCard(self, bounds, item);
    }

    pub fn semanticRow(self: View, bounds: ui.Rect, item: SemanticItem, intent: SemanticIntent) (ui.RenderError || interaction.Error)!void {
        try semantic_component.renderRow(self, bounds, item, intent);
    }
};

pub fn textNode(value: []const u8) ui.Node {
    return text(value).node();
}

pub fn cardNode(title: []const u8, detail: []const u8, variant: common.SurfaceVariant) ui.Node {
    return card(title, detail, variant).node();
}

pub fn progressNode(value: f32) ui.Node {
    return progress(value).node();
}

pub fn badgeNode(label: []const u8, variant: common.BadgeVariant) ui.Node {
    return badge(label, variant).node();
}

pub fn emptyNode(title: []const u8, detail: []const u8) ui.Node {
    return empty(title, detail).node();
}

pub fn rowItemNode(id: u32, title: []const u8, detail: []const u8) ui.Node {
    return rowItem(id, title, detail).node();
}

fn componentFromNode(comptime ComponentPayload: type, node_payload: anytype) Error!ComponentPayload {
    if (comptime !@hasDecl(ComponentPayload, "fromNode")) @compileError(@typeName(ComponentPayload) ++ " must own fromNode");
    return ComponentPayload.fromNode(node_payload);
}

comptime {
    @setEvalBranchQuota(10000);
    for (registrations) |entry| {
        if (entry.name.len == 0) @compileError("component union fields must have stable names");
        if (!@hasDecl(entry.type, "node")) @compileError(@typeName(entry.type) ++ " must own node");
        if (!@hasDecl(entry.type, "render")) @compileError(@typeName(entry.type) ++ " must own render");
        if (!@hasDecl(entry.type, "measure")) @compileError(@typeName(entry.type) ++ " must own measure");
        if (!@hasDecl(entry.type, "writeRecord")) @compileError(@typeName(entry.type) ++ " must own writeRecord");
        if (!@hasDecl(entry.type, "fromNode")) @compileError(@typeName(entry.type) ++ " must own fromNode");
        common.assertComponentContract(entry.type, .{
            .requires_id = @hasField(entry.type, "id"),
            .requires_flags = @hasField(entry.type, "flags"),
            .requires_accessibility = @hasDecl(entry.type, "accessibility"),
            .requires_interactions = @hasDecl(entry.type, "collectInteractions"),
        });
    }
}
