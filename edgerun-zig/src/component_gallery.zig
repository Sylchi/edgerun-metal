const std = @import("std");
const components = @import("ui_components.zig");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const interaction = @import("ui_interaction.zig");

const GalleryError = ui.RenderError || interaction.Error;

pub const preview_base_id: u32 = 18_000;
pub const layout_masonry_id: u32 = preview_base_id + 970;
pub const layout_grid_id: u32 = preview_base_id + 971;
pub const gap_compact_id: u32 = preview_base_id + 974;
pub const gap_default_id: u32 = preview_base_id + 975;
pub const gap_wide_id: u32 = preview_base_id + 976;
const gallery_topbar_h: f32 = 56;
const card_radius: f32 = 12;
const card_shadow: f32 = 8;
const card_hover_shadow: f32 = 16;
const card_content_x: f32 = 18;
const card_header_y: f32 = 18;
const card_detail_y: f32 = 42;
const card_body_top: f32 = 78;
const card_body_bottom: f32 = 18;
const control_radius: f32 = 7;
const control_shadow: f32 = 6;
const text_char_w: f32 = 8.3;
const compact_text_height: f32 = 14;
const body_text_height: f32 = 16;
const title_text_height: f32 = 18;
const hover_disabled_coord: f32 = -1;
const min_column_width: f32 = 300;
const max_gallery_columns: usize = 5;
pub const grid_gap_compact: f32 = 28;
pub const grid_gap_default: f32 = 40;
pub const grid_gap_wide: f32 = 56;
var gallery_text_clip_top: ?f32 = null;
var gallery_hover_point: ?HoverPoint = null;

const HoverPoint = struct {
    x: f32,
    y: f32,
};

pub const Category = enum {
    foundation,
    form,
    overlay,
    navigation,
    data_display,
    feedback,
    layout,
    media,

    pub fn label(self: Category) []const u8 {
        return switch (self) {
            .foundation => "Foundation",
            .form => "Form",
            .overlay => "Overlay",
            .navigation => "Navigation",
            .data_display => "Data Display",
            .feedback => "Feedback",
            .layout => "Layout",
            .media => "Media",
        };
    }
};

pub const ComponentSpec = struct {
    name: []const u8,
    slug: []const u8,
    route: []const u8,
    category: Category,
    source_component: []const u8,
    edge_builder: []const u8,
    status: Status,

    pub fn hasNativeRenderer(self: ComponentSpec) bool {
        return self.status.hasNativeRenderer();
    }

    pub fn nativeComponent(self: ComponentSpec, id: u32) ?components.Component {
        return componentForSlug(self.slug, id);
    }
};

pub const categories = [_]Category{ .foundation, .form, .overlay, .navigation, .data_display, .feedback, .layout, .media };

pub const Status = enum {
    cataloged,
    native_primitive,
    exact_port,

    pub fn label(self: Status) []const u8 {
        return switch (self) {
            .cataloged => "Cataloged",
            .native_primitive => "Native primitive",
            .exact_port => "Exact port",
        };
    }

    pub fn hasNativeRenderer(self: Status) bool {
        return switch (self) {
            .cataloged => false,
            .native_primitive, .exact_port => true,
        };
    }
};

pub const statuses = [_]Status{ .cataloged, .native_primitive, .exact_port };

pub const CategorySummary = struct {
    category: Category,
    label: []const u8,
    count: usize,
};

pub const StatusSummary = struct {
    status: Status,
    label: []const u8,
    count: usize,
};

const catalog_eval_branch_quota: u32 = component_route_count * component_route_count * 2;

pub const component_catalog = blk: {
    @setEvalBranchQuota(catalog_eval_branch_quota);
    break :blk [_]ComponentSpec{
        catalogSpec("Accordion", "accordion", .layout, "Accordion", "accordion_node"),
        catalogSpec("Alert", "alert", .feedback, "Alert", "alert_node"),
        catalogSpec("Alert Dialog", "alert-dialog", .overlay, "AlertDialog", "alert_dialog_node"),
        catalogSpec("Aspect Ratio", "aspect-ratio", .media, "AspectRatio", "aspect_ratio_node"),
        nativeSpec("Avatar", "avatar", .data_display, "Avatar", "avatar_node"),
        nativeSpec("Badge", "badge", .foundation, "Badge", "badge"),
        catalogSpec("Breadcrumb", "breadcrumb", .navigation, "Breadcrumb", "breadcrumb"),
        nativeSpec("Button", "button", .foundation, "Button", "button"),
        catalogSpec("Button Group", "button-group", .foundation, "ButtonGroup", "button_group_node"),
        catalogSpec("Calendar", "calendar", .form, "Calendar", "calendar_node"),
        nativeSpec("Card", "card", .layout, "Card", "card"),
        catalogSpec("Carousel", "carousel", .media, "Carousel", "carousel_node"),
        catalogSpec("Chart", "chart", .data_display, "Chart", "chart_node"),
        nativeSpec("Checkbox", "checkbox", .form, "Checkbox", "checkbox"),
        catalogSpec("Collapsible", "collapsible", .layout, "Collapsible", "collapsible_node"),
        catalogSpec("Combobox", "combobox", .form, "Combobox", "combobox_node"),
        catalogSpec("Command", "command", .overlay, "Command", "command_palette"),
        catalogSpec("Context Menu", "context-menu", .overlay, "ContextMenu", "context_menu_node"),
        catalogSpec("Data Table", "data-table", .data_display, "DataTable", "data_table_node"),
        catalogSpec("Date Picker", "date-picker", .form, "DatePicker", "date_picker_node"),
        catalogSpec("Dialog", "dialog", .overlay, "Dialog", "dialog"),
        catalogSpec("Direction", "direction", .foundation, "DirectionProvider", "direction_node"),
        catalogSpec("Drawer", "drawer", .overlay, "Drawer", "drawer_node"),
        catalogSpec("Dropdown Menu", "dropdown-menu", .overlay, "DropdownMenu", "dropdown_menu_node"),
        catalogSpec("Empty", "empty", .feedback, "Empty", "empty_state"),
        catalogSpec("Field", "field", .form, "Field", "field_node"),
        catalogSpec("Hover Card", "hover-card", .overlay, "HoverCard", "hover_card_node"),
        nativeSpec("Input", "input", .form, "Input", "field_node"),
        catalogSpec("Input Group", "input-group", .form, "InputGroup", "input_group_node"),
        catalogSpec("Input OTP", "input-otp", .form, "InputOTP", "input_otp_node"),
        nativeSpec("Item", "item", .data_display, "Item", "list_row_node"),
        nativeSpec("Kbd", "kbd", .foundation, "Kbd", "kbd_node"),
        nativeSpec("Label", "label", .form, "Label", "text"),
        catalogSpec("Menubar", "menubar", .navigation, "Menubar", "menubar_node"),
        nativeSpec("Native Select", "native-select", .form, "NativeSelect", "select_node"),
        catalogSpec("Navigation Menu", "navigation-menu", .navigation, "NavigationMenu", "navigation_menu_node"),
        catalogSpec("Pagination", "pagination", .navigation, "Pagination", "pagination_node"),
        catalogSpec("Popover", "popover", .overlay, "Popover", "popover_node"),
        nativeSpec("Progress", "progress", .feedback, "Progress", "progress_bar_node"),
        catalogSpec("Radio Group", "radio-group", .form, "RadioGroup", "radio"),
        catalogSpec("Resizable", "resizable", .layout, "Resizable", "resizable_node"),
        catalogSpec("Scroll Area", "scroll-area", .layout, "ScrollArea", "scroll_area"),
        nativeSpec("Select", "select", .form, "Select", "select_node"),
        nativeSpec("Separator", "separator", .layout, "Separator", "divider"),
        catalogSpec("Sheet", "sheet", .overlay, "Sheet", "sheet_node"),
        catalogSpec("Sidebar", "sidebar", .navigation, "Sidebar", "sidebar_node"),
        catalogSpec("Skeleton", "skeleton", .feedback, "Skeleton", "skeleton"),
        nativeSpec("Slider", "slider", .form, "Slider", "slider_node"),
        catalogSpec("Sonner", "sonner", .feedback, "Sonner", "toast"),
        nativeSpec("Switch", "switch", .form, "Switch", "toggle_node"),
        catalogSpec("Table", "table", .data_display, "Table", "table_node"),
        catalogSpec("Tabs", "tabs", .navigation, "Tabs", "tabs_node"),
        nativeSpec("Textarea", "textarea", .form, "Textarea", "text_area_node"),
        catalogSpec("Toast", "toast", .feedback, "Toast", "toast"),
        catalogSpec("Toggle", "toggle", .foundation, "Toggle", "toggle_node"),
        catalogSpec("Toggle Group", "toggle-group", .foundation, "ToggleGroup", "toggle_group_node"),
        catalogSpec("Tooltip", "tooltip", .overlay, "Tooltip", "tooltip"),
    };
};

fn catalogSpec(name: []const u8, slug: []const u8, category: Category, source_component: []const u8, edge_builder: []const u8) ComponentSpec {
    return componentSpec(name, slug, category, source_component, edge_builder, .cataloged);
}

fn nativeSpec(name: []const u8, slug: []const u8, category: Category, source_component: []const u8, edge_builder: []const u8) ComponentSpec {
    return componentSpec(name, slug, category, source_component, edge_builder, .native_primitive);
}

fn componentSpec(name: []const u8, slug: []const u8, category: Category, source_component: []const u8, edge_builder: []const u8, status: Status) ComponentSpec {
    return .{
        .name = name,
        .slug = slug,
        .route = routeFor(slug),
        .category = category,
        .source_component = source_component,
        .edge_builder = edge_builder,
        .status = status,
    };
}

pub fn findBySlug(slug: []const u8) ?*const ComponentSpec {
    for (&component_catalog) |*spec| {
        if (std.mem.eql(u8, spec.slug, slug)) return spec;
    }
    return null;
}

pub fn nativeComponentCount() usize {
    return countByStatus(.native_primitive) + countByStatus(.exact_port);
}

pub fn findBySourceComponent(source_component: []const u8) ?*const ComponentSpec {
    for (&component_catalog) |*spec| {
        if (std.mem.eql(u8, spec.source_component, source_component)) return spec;
    }
    return null;
}

pub fn countByCategory(category: Category) usize {
    var count: usize = 0;
    for (component_catalog) |spec| {
        if (spec.category == category) count += 1;
    }
    return count;
}

pub fn countByStatus(status: Status) usize {
    var count: usize = 0;
    for (component_catalog) |spec| {
        if (spec.status == status) count += 1;
    }
    return count;
}

pub fn categorySummary(category: Category) CategorySummary {
    return .{ .category = category, .label = category.label(), .count = countByCategory(category) };
}

pub fn statusSummary(status: Status) StatusSummary {
    return .{ .status = status, .label = status.label(), .count = countByStatus(status) };
}

pub fn componentForSlug(slug: []const u8, id: u32) ?components.Component {
    if (std.mem.eql(u8, slug, "avatar")) return .{ .avatar = .{ .label = "ER" } };
    if (std.mem.eql(u8, slug, "badge")) return .{ .badge = .{ .label = "Ready" } };
    if (std.mem.eql(u8, slug, "button")) return .{ .button = .{ .id = id, .label = "Continue" } };
    if (std.mem.eql(u8, slug, "card")) return .{ .card = .{ .title = "Card", .detail = "Canonical surface" } };
    if (std.mem.eql(u8, slug, "checkbox")) return .{ .checkbox = .{ .id = id, .label = "Enabled", .checked = true } };
    if (std.mem.eql(u8, slug, "input")) return .{ .input = .{ .id = id, .placeholder = "Input" } };
    if (std.mem.eql(u8, slug, "item")) return .{ .row_item = .{ .id = id, .title = "Item", .detail = "Composed row" } };
    if (std.mem.eql(u8, slug, "kbd")) return .{ .kbd = .{ .label = "Ctrl K" } };
    if (std.mem.eql(u8, slug, "label")) return .{ .text = .{ .value = "Label" } };
    if (std.mem.eql(u8, slug, "native-select")) return .{ .select = .{ .id = id, .label = "Native select" } };
    if (std.mem.eql(u8, slug, "progress")) return .{ .progress = .{ .value = 0.64 } };
    if (std.mem.eql(u8, slug, "select")) return .{ .select = .{ .id = id, .label = "Select" } };
    if (std.mem.eql(u8, slug, "separator")) return .{ .separator = .{} };
    if (std.mem.eql(u8, slug, "slider")) return .{ .slider = .{ .id = id, .label = "Slider", .value = 0.72 } };
    if (std.mem.eql(u8, slug, "switch")) return .{ .switch_control = .{ .id = id, .label = "Switch", .checked = true } };
    if (std.mem.eql(u8, slug, "textarea")) return .{ .textarea = .{ .id = id, .placeholder = "Textarea" } };
    return null;
}

fn routeFor(slug: []const u8) []const u8 {
    inline for (component_routes) |entry| {
        if (std.mem.eql(u8, slug, entry.slug)) return entry.route;
    }
    unreachable;
}

const Route = struct {
    slug: []const u8,
    route: []const u8,
};

const component_route_count: u32 = 57;

const component_routes = [_]Route{
    .{ .slug = "accordion", .route = "/docs/components/accordion" },
    .{ .slug = "alert", .route = "/docs/components/alert" },
    .{ .slug = "alert-dialog", .route = "/docs/components/alert-dialog" },
    .{ .slug = "aspect-ratio", .route = "/docs/components/aspect-ratio" },
    .{ .slug = "avatar", .route = "/docs/components/avatar" },
    .{ .slug = "badge", .route = "/docs/components/badge" },
    .{ .slug = "breadcrumb", .route = "/docs/components/breadcrumb" },
    .{ .slug = "button", .route = "/docs/components/button" },
    .{ .slug = "button-group", .route = "/docs/components/button-group" },
    .{ .slug = "calendar", .route = "/docs/components/calendar" },
    .{ .slug = "card", .route = "/docs/components/card" },
    .{ .slug = "carousel", .route = "/docs/components/carousel" },
    .{ .slug = "chart", .route = "/docs/components/chart" },
    .{ .slug = "checkbox", .route = "/docs/components/checkbox" },
    .{ .slug = "collapsible", .route = "/docs/components/collapsible" },
    .{ .slug = "combobox", .route = "/docs/components/combobox" },
    .{ .slug = "command", .route = "/docs/components/command" },
    .{ .slug = "context-menu", .route = "/docs/components/context-menu" },
    .{ .slug = "data-table", .route = "/docs/components/data-table" },
    .{ .slug = "date-picker", .route = "/docs/components/date-picker" },
    .{ .slug = "dialog", .route = "/docs/components/dialog" },
    .{ .slug = "direction", .route = "/docs/components/direction" },
    .{ .slug = "drawer", .route = "/docs/components/drawer" },
    .{ .slug = "dropdown-menu", .route = "/docs/components/dropdown-menu" },
    .{ .slug = "empty", .route = "/docs/components/empty" },
    .{ .slug = "field", .route = "/docs/components/field" },
    .{ .slug = "hover-card", .route = "/docs/components/hover-card" },
    .{ .slug = "input", .route = "/docs/components/input" },
    .{ .slug = "input-group", .route = "/docs/components/input-group" },
    .{ .slug = "input-otp", .route = "/docs/components/input-otp" },
    .{ .slug = "item", .route = "/docs/components/item" },
    .{ .slug = "kbd", .route = "/docs/components/kbd" },
    .{ .slug = "label", .route = "/docs/components/label" },
    .{ .slug = "menubar", .route = "/docs/components/menubar" },
    .{ .slug = "native-select", .route = "/docs/components/native-select" },
    .{ .slug = "navigation-menu", .route = "/docs/components/navigation-menu" },
    .{ .slug = "pagination", .route = "/docs/components/pagination" },
    .{ .slug = "popover", .route = "/docs/components/popover" },
    .{ .slug = "progress", .route = "/docs/components/progress" },
    .{ .slug = "radio-group", .route = "/docs/components/radio-group" },
    .{ .slug = "resizable", .route = "/docs/components/resizable" },
    .{ .slug = "scroll-area", .route = "/docs/components/scroll-area" },
    .{ .slug = "select", .route = "/docs/components/select" },
    .{ .slug = "separator", .route = "/docs/components/separator" },
    .{ .slug = "sheet", .route = "/docs/components/sheet" },
    .{ .slug = "sidebar", .route = "/docs/components/sidebar" },
    .{ .slug = "skeleton", .route = "/docs/components/skeleton" },
    .{ .slug = "slider", .route = "/docs/components/slider" },
    .{ .slug = "sonner", .route = "/docs/components/sonner" },
    .{ .slug = "switch", .route = "/docs/components/switch" },
    .{ .slug = "table", .route = "/docs/components/table" },
    .{ .slug = "tabs", .route = "/docs/components/tabs" },
    .{ .slug = "textarea", .route = "/docs/components/textarea" },
    .{ .slug = "toast", .route = "/docs/components/toast" },
    .{ .slug = "toggle", .route = "/docs/components/toggle" },
    .{ .slug = "toggle-group", .route = "/docs/components/toggle-group" },
    .{ .slug = "tooltip", .route = "/docs/components/tooltip" },
};

pub const ComponentGalleryState = struct {
    contribution_bar: usize = 5,
    stock_bar: usize = 5,
    power_bar: usize = 6,
    payout_value: f32 = 0.24,
    brightness: f32 = 0.82,
    layout: LayoutMode = .masonry,
    grid_gap: f32 = grid_gap_default,
    scroll_y: f32 = 0.0,
    hover_x: f32 = hover_disabled_coord,
    hover_y: f32 = hover_disabled_coord,
    list_order_scope_id: u32 = 0,
    list_order: [list_row_count]u8 = default_list_order,
};

pub const LayoutMode = enum(u32) {
    masonry = 0,
    grid = 1,

    pub fn fromRaw(value: u32) LayoutMode {
        return switch (value) {
            1 => .grid,
            else => .masonry,
        };
    }

    pub fn label(self: LayoutMode) []const u8 {
        return switch (self) {
            .masonry => "Masonry",
            .grid => "Grid",
        };
    }
};

const CardKind = enum {
    chart,
    form,
    metrics,
    table,
    list,
    centered,
    controls,
    navigation,
    calendar,
    skeleton,
    security,
};

pub const list_row_count: usize = 4;
pub const default_list_order = [_]u8{ 0, 1, 2, 3 };

const ShowcaseCard = struct {
    title: []const u8,
    detail: []const u8,
    kind: CardKind,
    id: u32,
};

const showcase_cards = [_]ShowcaseCard{
    card("Contribution History", "Last 6 months of activity", .chart, 940),
    card("Payout Threshold", "Set minimum balance", .form, 944),
    card("Savings Targets", "Active milestones for 2024", .metrics, 945),
    card("Buy Investment", "Market orders execute at current price", .form, 947),
    card("Distribute Track", "Upload your first master", .centered, 957),
    card("Claimable Balance", "Pending setup", .table, 966),
    card("Recent Transactions", "Latest account activity", .list, 950),
    card("Account Access", "Update credentials", .form, 948),
    card("Mobile Pairing", "Scan to connect device", .centered, 958),
    card("Preferences", "Manage account settings", .controls, 972),
    card("Navigation", "Menu, tabs, and rows", .navigation, 980),
    card("Transfer Funds", "Move money between accounts", .form, 1019),
    card("Q2 Dividend Income", "Quarterly payouts", .list, 959),
    card("Room Controls", "Smart home controls", .controls, 973),
    card("Support Tabs", "Account help center", .navigation, 1008),
    card("Cover Art", "Artwork upload", .centered, 1020),
    card("Dollar-Cost Averaging", "Strategy copy block", .metrics, 0),
    card("Savings Ring", "Projected finish", .metrics, 0),
    card("Holdings Table", "Search holdings and tickers", .table, 1009),
    card("Skeleton Loading", "Loading state", .skeleton, 0),
    card("Syncing Accounts", "Background import", .centered, 965),
    card("Payout Preferences", "Receiving method", .form, 1024),
    card("Power Usage", "Whole home", .chart, 1025),
    card("Connect Bank", "Payout setup", .centered, 1027),
    card("Upcoming Payments", "Scheduled payments", .calendar, 1028),
    card("Front Door", "Smart Lock Pro", .security, 1053),
    card("Stock Performance", "6-month price history", .chart, 1056),
    card("Explore Catalog", "Metadata and assets", .centered, 1058),
    card("Set a new milestone", "Financial target", .form, 1059),
    card("Social Links", "Artist URLs", .form, 1062),
    card("Notifications", "Choose notification topics", .controls, 1068),
};

fn card(title: []const u8, detail: []const u8, kind: CardKind, id: u32) ShowcaseCard {
    return .{ .title = title, .detail = detail, .kind = kind, .id = preview_base_id + id };
}

const palette = struct {
    const bg = ui.Color{ .r = 9, .g = 9, .b = 11 };
    const sidebar = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 219 };
    const panel = ui.Color{ .r = 24, .g = 24, .b = 27, .a = 224 };
    const panel_hover = ui.Color{ .r = 32, .g = 32, .b = 36, .a = 238 };
    const panel_hover_bottom = ui.Color{ .r = 47, .g = 47, .b = 52, .a = 176 };
    const panel_alt = ui.Color{ .r = 39, .g = 39, .b = 42, .a = 107 };
    const panel_alt_hover = ui.Color{ .r = 50, .g = 50, .b = 55, .a = 170 };
    const row = ui.Color{ .r = 39, .g = 39, .b = 42, .a = 158 };
    const row_hover = ui.Color{ .r = 55, .g = 55, .b = 61, .a = 186 };
    const border = ui.Color{ .r = 63, .g = 63, .b = 70, .a = 82 };
    const border_hover = ui.Color{ .r = 8, .g = 145, .b = 178, .a = 140 };
    const text = ui.Color{ .r = 250, .g = 250, .b = 250 };
    const muted = ui.Color{ .r = 161, .g = 161, .b = 170 };
    const accent = ui.Color{ .r = 8, .g = 145, .b = 178 };
    const green = ui.Color{ .r = 16, .g = 185, .b = 129 };
    const danger = ui.Color{ .r = 225, .g = 29, .b = 72 };
    const shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
    const shadow_hover = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 160 };
};

pub fn renderComponentGallery(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: ComponentGalleryState) GalleryError!void {
    const previous_hover_point = gallery_hover_point;
    gallery_hover_point = if (state.hover_x >= hover_disabled_coord + 1 and state.hover_y >= hover_disabled_coord + 1)
        .{ .x = state.hover_x, .y = state.hover_y }
    else
        null;
    defer gallery_hover_point = previous_hover_point;

    try fill(scene, bounds, palette.bg, 0);

    const layout = galleryLayout(bounds, state);
    if (layout.rail.w > 0) try renderRail(scene, collector, layout.rail, layout.gap);
    if (layout.frame) |frame| try stroke(scene, frame, palette.border, card_radius);

    var column_y = [_]f32{0} ** max_gallery_columns;

    {
        const previous_text_clip_top = gallery_text_clip_top;
        gallery_text_clip_top = bounds.y + gallery_topbar_h;
        defer gallery_text_clip_top = previous_text_clip_top;

        switch (state.layout) {
            .masonry => {
                for (showcase_cards) |spec| {
                    const col = shortestColumn(column_y[0..layout.columns]);
                    const height = showcaseCardHeight(spec, layout.card_w);
                    try renderShowcaseCard(scene, collector, layout.cardBounds(col, column_y[col], height), spec, state);
                    column_y[col] += height + layout.gap;
                }
            },
            .grid => {
                var row_y: f32 = 0;
                var row_h: f32 = 0;
                for (showcase_cards, 0..) |spec, index| {
                    const col = index % layout.columns;
                    const height = showcaseCardHeight(spec, layout.card_w);
                    try renderShowcaseCard(scene, collector, layout.cardBounds(col, row_y, height), spec, state);
                    row_h = @max(row_h, height);
                    if (col + 1 == layout.columns or index + 1 == showcase_cards.len) {
                        row_y += row_h + layout.gap;
                        row_h = 0;
                    }
                }
            },
        }
    }

    try renderTopbar(scene, collector, .{ .x = bounds.x, .y = bounds.y, .w = bounds.w, .h = gallery_topbar_h }, state.layout);
}

const GalleryLayout = struct {
    rail: ui.Rect,
    frame: ?ui.Rect,
    board: ui.Rect,
    gap: f32,
    columns: usize,
    card_w: f32,

    fn cardBounds(self: GalleryLayout, column: usize, y_offset: f32, height: f32) ui.Rect {
        return ui.Rect.init(self.board.x + @as(f32, @floatFromInt(column)) * (self.card_w + self.gap), self.board.y + y_offset, self.card_w, height);
    }
};

fn galleryLayout(bounds: ui.Rect, state: ComponentGalleryState) GalleryLayout {
    const rail_w: f32 = if (bounds.w < 760) 0 else 246;
    const rail = ui.Rect.init(bounds.x, bounds.y, rail_w, bounds.h);
    const scroll_y = std.math.clamp(state.scroll_y, 0.0, 4096.0);
    const gap = normalizedGridGap(state.grid_gap);
    const board = ui.Rect.init(bounds.x + rail_w, bounds.y + gallery_topbar_h + 40 - scroll_y, @max(320, bounds.w - rail_w - 24), @max(240, bounds.h - gallery_topbar_h - 64 + scroll_y));
    const columns = galleryColumnCount(board.w, gap);
    const card_w = (board.w - gap * @as(f32, @floatFromInt(columns - 1))) / @as(f32, @floatFromInt(columns));
    const frame = if (rail_w > 0) ui.Rect.init(board.x, bounds.y + gallery_topbar_h, bounds.w - rail_w - 20, bounds.h - gallery_topbar_h - 24) else null;
    return .{ .rail = rail, .frame = frame, .board = board, .gap = gap, .columns = columns, .card_w = card_w };
}

fn renderRail(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, grid_gap: f32) GalleryError!void {
    const panel_bounds = ui.Rect.init(bounds.x + 20, bounds.y + gallery_topbar_h, bounds.w - 40, bounds.h - gallery_topbar_h - 16);
    try scene.pushRect(panel_bounds.insetUniform(-1), palette.shadow, .shadow, 16, 18);
    try panel(scene, panel_bounds, 14);

    const menu = ui.Rect.init(panel_bounds.x + 12, panel_bounds.y + 12, panel_bounds.w - 24, 36);
    try fill(scene, menu, palette.panel_alt, 8);
    try stroke(scene, menu, palette.border, 8);
    try text(scene, menu.x + 10, menu.y + 11, 80, 14, "Menu", palette.text);
    try iconQuad(scene, ui.Rect.init(menu.x + menu.w - 28, menu.y + 10, 16, 16), .menu, palette.text);

    const labels = [_]struct { []const u8, []const u8 }{
        .{ "Style", "Nova" },
        .{ "Base Color", "Neutral" },
        .{ "Theme", "Neutral" },
        .{ "Chart Color", "Neutral" },
        .{ "Heading", "Geist VF" },
        .{ "Font", "Geist VF" },
        .{ "Icon Library", "Tabler" },
        .{ "Radius", "Default" },
        .{ "Menu", "Solid" },
        .{ "Grid Gap", gapLabel(grid_gap) },
    };
    var rows = ui.LinearCursor.init(ui.Rect.init(panel_bounds.x + 12, menu.y + menu.h + 22, panel_bounds.w - 24, panel_bounds.h), .column, 10);
    for (labels, 0..) |item, index| {
        const row = rows.take(50);
        try fill(scene, row, if (index == 0) palette.panel_alt else palette.panel, 8);
        try stroke(scene, row, palette.border, 8);
        try text(scene, row.x + 12, row.y + 9, row.w - 24, 14, item[0], palette.muted);
        if (index == 9) {
            try renderGridGapControls(scene, collector, row, grid_gap);
        } else {
            try text(scene, row.x + 12, row.y + 27, row.w - 24, 14, item[1], palette.text);
            try renderRailTrailing(scene, row, index);
        }
    }

    const button_w = panel_bounds.w - 24;
    const button_x = panel_bounds.x + 12;
    try button(scene, collector, ui.Rect.init(button_x, panel_bounds.y + panel_bounds.h - 166, button_w, 30), "--preset b0", preview_base_id + 931, false);
    try button(scene, collector, ui.Rect.init(button_x, panel_bounds.y + panel_bounds.h - 126, button_w, 30), "Open Preset", preview_base_id + 932, false);
    try button(scene, collector, ui.Rect.init(button_x, panel_bounds.y + panel_bounds.h - 86, button_w, 30), "Shuffle", preview_base_id + 933, false);
    try buttonWithIcon(scene, collector, ui.Rect.init(button_x, panel_bounds.y + panel_bounds.h - 36, button_w, 30), "Get Code", .code, preview_base_id + 934, true);
}

fn renderTopbar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, layout: LayoutMode) GalleryError!void {
    try fill(scene, bounds, palette.bg, 0);
    try iconQuad(scene, ui.Rect.init(bounds.x + 26, bounds.y + 18, 20, 20), .sparkles, palette.text);
    if (bounds.w < 540) {
        try buttonWithIcon(scene, collector, ui.Rect.init(bounds.x + bounds.w - 132, bounds.y + 12, 112, 34), "Get Code", .code, preview_base_id + 908, true);
        return;
    }
    var tabs_cursor = ui.LinearCursor.init(ui.Rect.init(bounds.x + 60, bounds.y + 12, bounds.w, 32), .row, 2);
    const tabs = [_][]const u8{ "Docs", "Components", "Blocks", "Charts", "Directory", "Create" };
    for (tabs, 0..) |label, index| {
        const w: f32 = switch (index) {
            1 => 112,
            4 => 92,
            5 => 76,
            else => 76,
        };
        try ghostButton(scene, collector, tabs_cursor.take(w), label, preview_base_id + 900 + @as(u32, @intCast(index)));
    }
    if (bounds.w >= 920) {
        const action_widths = TopbarActionWidths.init(bounds.w);
        var actions = ui.LinearCursor.init(bounds.right(action_widths.total()).withHeightCentered(34), .row, 8);
        if (bounds.w >= 1500) {
            try layoutSwitcher(scene, collector, actions.take(action_widths.layout), layout);
        }
        try searchField(scene, collector, actions.take(action_widths.search), "Search documentation...", preview_base_id + 905);
        try buttonWithIcon(scene, collector, actions.take(action_widths.stars), "115k", .network, preview_base_id + 906, false);
        try button(scene, collector, actions.take(action_widths.open), "Open in", preview_base_id + 907, false);
        try buttonWithIcon(scene, collector, actions.take(action_widths.code), "Get Code", .code, preview_base_id + 908, true);
        return;
    }
    try buttonWithIcon(scene, collector, ui.Rect.init(bounds.x + bounds.w - 132, bounds.y + 12, 112, 34), "Get Code", .code, preview_base_id + 908, true);
}

const TopbarActionWidths = struct {
    layout: f32,
    search: f32,
    stars: f32,
    open: f32,
    code: f32,

    fn init(available_width: f32) TopbarActionWidths {
        return .{
            .layout = if (available_width >= 1500) 186 else 0,
            .search = @min(320, @max(160, available_width - 1020)),
            .stars = 84,
            .open = 104,
            .code = 112,
        };
    }

    fn total(self: TopbarActionWidths) f32 {
        const layout_gap: f32 = if (self.layout > 0) 8 else 0;
        return self.layout + layout_gap + self.search + 8 + self.stars + 8 + self.open + 8 + self.code + 20;
    }
};

fn renderRailTrailing(scene: *ui.Scene, row: ui.Rect, index: usize) GalleryError!void {
    const center_y = row.y + row.h - 18;
    switch (index) {
        0 => try iconQuad(scene, ui.Rect.init(row.x + row.w - 29, center_y - 10, 20, 20), .app, palette.text),
        1, 2, 3 => try fill(scene, ui.Rect.init(row.x + row.w - 24, center_y - 7, 14, 14), palette.muted, 7),
        4, 5 => try text(scene, row.x + row.w - 34, center_y - 7, 28, 14, "Aa", palette.text),
        6 => try iconQuad(scene, ui.Rect.init(row.x + row.w - 29, center_y - 10, 20, 20), .sparkles, palette.text),
        7 => try iconQuad(scene, ui.Rect.init(row.x + row.w - 29, center_y - 10, 20, 20), .route, palette.text),
        8 => try iconQuad(scene, ui.Rect.init(row.x + row.w - 29, center_y - 10, 20, 20), .menu, palette.text),
        else => {},
    }
}

fn renderGridGapControls(scene: *ui.Scene, collector: *interaction.Collector, row: ui.Rect, grid_gap: f32) GalleryError!void {
    const control_w: f32 = 28;
    const control_h: f32 = 20;
    const control_gap: f32 = 6;
    const group_w = control_w * 3.0 + control_gap * 2.0 + 10.0;
    const group = ui.Rect.init(row.x + row.w - group_w, row.y + 25.0, group_w, control_h);
    var controls = ui.LinearCursor.init(group.insetLtrb(0, 0, 10, 0), .row, control_gap);
    try gridGapButton(scene, collector, controls.take(control_w), "S", gap_compact_id, grid_gap == grid_gap_compact);
    try gridGapButton(scene, collector, controls.take(control_w), "M", gap_default_id, grid_gap == grid_gap_default);
    try gridGapButton(scene, collector, controls.take(control_w), "L", gap_wide_id, grid_gap == grid_gap_wide);
    try text(scene, row.x + 12, group.y + 4.0, @max(1.0, group.x - row.x - 18.0), 12, gapLabel(grid_gap), palette.text);
}

fn gridGapButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id_value: u32, selected: bool) GalleryError!void {
    try fill(scene, bounds, if (selected) palette.text else palette.panel_alt, 6);
    try stroke(scene, bounds, if (selected) palette.text else palette.border, 6);
    try alignedText(scene, bounds.x + 2.0, bounds.y + 4.0, bounds.w - 4.0, 12.0, label, if (selected) palette.panel else palette.text, .center);
    try collector.addHit(bounds, .button, id_value);
}

fn normalizedGridGap(value: f32) f32 {
    if (value <= (grid_gap_compact + grid_gap_default) * 0.5) return grid_gap_compact;
    if (value >= (grid_gap_default + grid_gap_wide) * 0.5) return grid_gap_wide;
    return grid_gap_default;
}

fn gapLabel(value: f32) []const u8 {
    return switch (@as(u8, if (normalizedGridGap(value) == grid_gap_compact) 0 else if (normalizedGridGap(value) == grid_gap_wide) 2 else 1)) {
        0 => "Compact",
        2 => "Wide",
        else => "Default",
    };
}

fn layoutSwitcher(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, layout: LayoutMode) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, control_radius);
    try stroke(scene, bounds, palette.border, control_radius);
    const item_gap: f32 = 4;
    const item_w = (bounds.w - item_gap - 8) * 0.5;
    const masonry = ui.Rect.init(bounds.x + 4, bounds.y + 4, item_w, bounds.h - 8);
    const grid = ui.Rect.init(masonry.x + masonry.w + item_gap, bounds.y + 4, item_w, bounds.h - 8);
    try layoutSwitchItem(scene, collector, masonry, "Masonry", layout_masonry_id, layout == .masonry);
    try layoutSwitchItem(scene, collector, grid, "Grid", layout_grid_id, layout == .grid);
}

fn layoutSwitchItem(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id_value: u32, selected: bool) GalleryError!void {
    const is_hovered = hovered(bounds);
    if (selected or is_hovered) {
        try fill(scene, bounds, if (selected) palette.text else palette.panel_alt_hover, control_radius);
    }
    try centeredText(scene, bounds, label, if (selected) palette.panel else palette.text);
    try collector.addHit(bounds, .button, id_value);
}

fn galleryColumnCount(width: f32, gap: f32) usize {
    var columns: usize = 1;
    while (columns < max_gallery_columns) {
        const next = columns + 1;
        const required = min_column_width * @as(f32, @floatFromInt(next)) + gap * @as(f32, @floatFromInt(next - 1));
        if (required > width) break;
        columns = next;
    }
    return columns;
}

fn showcaseCardHeight(spec: ShowcaseCard, width: f32) f32 {
    const compact = width < 380;
    if (std.mem.eql(u8, spec.title, "Payout Threshold")) return if (compact) 400 else 420;
    return switch (spec.kind) {
        .chart => if (compact) 320 else 360,
        .form => if (compact) 336 else 356,
        .metrics => if (compact) 268 else 286,
        .table => if (compact) 330 else 384,
        .list => if (compact) 336 else 390,
        .centered => centeredCardHeight(spec.title, compact),
        .controls => if (compact) 326 else 356,
        .navigation => if (compact) 306 else 340,
        .calendar => if (compact) 350 else 380,
        .skeleton => if (compact) 270 else 300,
        .security => if (compact) 300 else 320,
    };
}

fn centeredCardHeight(title: []const u8, compact: bool) f32 {
    if (std.mem.eql(u8, title, "Mobile Pairing")) return if (compact) 326 else 326;
    if (std.mem.eql(u8, title, "Cover Art")) return if (compact) 300 else 330;
    return if (compact) 260 else 286;
}

fn renderShowcaseCard(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, spec: ShowcaseCard, state: ComponentGalleryState) GalleryError!void {
    const is_hovered = hovered(bounds);
    try scene.pushRect(bounds.insetUniform(-1), if (is_hovered) palette.shadow_hover else palette.shadow, .shadow, card_radius, if (is_hovered) card_hover_shadow else card_shadow);
    try scene.pushGradientRect(bounds, if (is_hovered) palette.panel_hover else palette.panel, if (is_hovered) palette.panel_hover_bottom else palette.row, card_radius);
    try stroke(scene, bounds, if (is_hovered) palette.border_hover else palette.border, card_radius);
    try text(scene, bounds.x + card_content_x, bounds.y + card_header_y, bounds.w - card_content_x * 2.0, title_text_height, spec.title, palette.text);
    try text(scene, bounds.x + card_content_x, bounds.y + card_detail_y, bounds.w - card_content_x * 2.0, body_text_height, spec.detail, palette.muted);

    const body = bounds.insetLtrb(16, card_body_top, 16, card_body_bottom);
    if (std.mem.eql(u8, spec.title, "Payout Threshold")) return renderPayoutThreshold(scene, collector, body, spec.id, state.payout_value);
    if (std.mem.eql(u8, spec.title, "Savings Targets")) return renderSavingsTargets(scene, body);
    if (std.mem.eql(u8, spec.title, "Mobile Pairing")) return renderPairing(scene, collector, body, spec.id);
    if (std.mem.eql(u8, spec.title, "Claimable Balance")) return renderClaimableBalance(scene, collector, body, spec.id);
    if (std.mem.eql(u8, spec.title, "Notifications")) return renderNotifications(scene, collector, body, spec.id);

    switch (spec.kind) {
        .chart => try renderChart(scene, collector, body, spec.id, if (std.mem.eql(u8, spec.title, "Power Usage")) state.brightness else state.payout_value),
        .form => try renderForm(scene, collector, body, spec.id),
        .metrics => try renderMetrics(scene, body),
        .table => try renderTable(scene, collector, body, spec.id),
        .list => try renderList(scene, collector, body, spec.id, state),
        .centered => try renderCentered(scene, collector, body, spec.id, spec.title),
        .controls => try renderControls(scene, collector, body, spec.id),
        .navigation => try renderNavigation(scene, collector, body, spec.id),
        .calendar => try renderCalendar(scene, collector, body, spec.id),
        .skeleton => try renderSkeleton(scene, body),
        .security => try renderSecurity(scene, collector, body, spec.id),
    }
}

fn renderPayoutThreshold(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, action_id: u32, value: f32) GalleryError!void {
    const field_h: f32 = 42;
    const metric_h: f32 = 66;
    const slider_h: f32 = 42;
    const button_h: f32 = 34;
    const section_gap: f32 = 14;
    const compact_gap: f32 = 10;

    var y = bounds.y;
    try field(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, field_h), "Preferred Currency: USD", action_id + 1);
    y += field_h + section_gap;

    const amount = 50.0 + std.math.clamp(value, 0.0, 1.0) * 9950.0;
    const label = if (amount > 5000) "$5k+ minimum payout" else "$2.4k minimum payout";
    try metricBox(scene, ui.Rect.init(bounds.x, y, bounds.w, metric_h), "Minimum Payout Amount", label);
    y += metric_h + compact_gap;

    try slider(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, slider_h), "Minimum payout", value, action_id + 2);
    y += slider_h + compact_gap;

    const button_y = bounds.y + bounds.h - button_h;
    const notes_h = @max(48, button_y - y - section_gap);
    try textArea(scene, ui.Rect.init(bounds.x, y, bounds.w, notes_h), "Add notes for this payout configuration...");
    try button(scene, collector, ui.Rect.init(bounds.x, button_y, @min(156, bounds.w), button_h), "Save Threshold", action_id, true);
}

fn renderSavingsTargets(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    const row_gap: f32 = 14;
    const note_gap: f32 = 16;
    const note_h: f32 = 36;
    const target_h = @max(48.0, @min(64.0, (bounds.h - row_gap - note_gap - note_h) * 0.5));
    const first = ui.Rect.init(bounds.x, bounds.y, bounds.w, target_h);
    const second = ui.Rect.init(bounds.x, first.y + first.h + row_gap, bounds.w, target_h);
    try savingsTarget(scene, first, "Retirement", "$420,000", "$273,000", 0.65);
    try savingsTarget(scene, second, "Real Estate", "$85,000", "$27,200", 0.32);
    try text(scene, bounds.x, second.y + second.h + note_gap, bounds.w, note_h, "You have not met your targets for this year.", palette.muted);
}

fn renderPairing(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, action_id: u32) GalleryError!void {
    const cell: f32 = 8;
    const qr = ui.Rect.init(bounds.x + bounds.w * 0.5 - 58, bounds.y, 116, 116);
    try fill(scene, qr.insetUniform(-10), palette.panel_alt, 10);
    for (0..13) |row| {
        for (0..13) |col| {
            if (qrModuleOn(row, col)) {
                try fill(scene, ui.Rect.init(qr.x + @as(f32, @floatFromInt(col)) * cell, qr.y + @as(f32, @floatFromInt(row)) * cell, cell - 1, cell - 1), palette.text, 1);
            }
        }
    }
    try text(scene, bounds.x + 24, bounds.y + 144, bounds.w - 48, 36, "Scan to connect your mobile device", palette.text);
    try button(scene, collector, ui.Rect.init(bounds.x + bounds.w * 0.5 - 48, bounds.y + bounds.h - 36, 96, 34), "Got it", action_id, false);
}

fn renderClaimableBalance(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32) GalleryError!void {
    try metricBox(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 66), "Claimable Balance", "$0.00");
    try badge(scene, ui.Rect.init(bounds.x, bounds.y + 78, 108, 24), "Pending Setup", palette.muted);
    try renderTableRows(scene, collector, ui.Rect.init(bounds.x, bounds.y + 116, bounds.w, @max(80, bounds.h - 116)), base_id, 3);
}

fn renderNotifications(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32) GalleryError!void {
    const rows = [_]struct { []const u8, bool }{
        .{ "Select all", true },
        .{ "Transaction alerts", true },
        .{ "Security alerts", true },
        .{ "Goal milestones", false },
        .{ "Market updates", false },
    };
    var y = bounds.y;
    for (rows, 0..) |row, index| {
        try checkboxRow(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 30), row[0], row[1], base_id + @as(u32, @intCast(index)));
        y += 36;
    }
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + bounds.h - 36, 156, 34), "Save Preferences", base_id + 8, true);
}

fn renderChart(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32, boost: f32) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, 8);
    const button_h: f32 = 32;
    const button_w: f32 = 156;
    const button_bottom_gap: f32 = 12;
    const metric_h: f32 = 56;
    const metric_gap: f32 = 12;
    const chart_top_gap: f32 = 16;
    const chart_side_gap: f32 = 14;
    const button_y = bounds.y + bounds.h - button_h - button_bottom_gap;
    const metric_y = button_y - metric_h - 16.0;
    const chart_h = @max(56.0, metric_y - bounds.y - chart_top_gap - metric_gap);
    const chart = ui.Rect.init(bounds.x + chart_side_gap, bounds.y + chart_top_gap, bounds.w - chart_side_gap * 2.0, chart_h);
    const values = [_]f32{ 0.42, 0.66, 0.48, 0.78, 0.38, 0.84, 0.62, 0.7 };
    const count: usize = if (chart.w > 420) 8 else 6;
    const gap: f32 = 8;
    const bar_w = (chart.w - gap * @as(f32, @floatFromInt(count - 1))) / @as(f32, @floatFromInt(count));
    for (0..count) |i| {
        const value = @min(1.0, values[i] + if (i == count - 1) boost * 0.12 else 0);
        const h = @max(12, chart.h * value);
        const bar = ui.Rect.init(chart.x + @as(f32, @floatFromInt(i)) * (bar_w + gap), chart.y + chart.h - h, bar_w, h);
        try fill(scene, bar, if (i == count - 1) palette.accent else palette.row, 6);
        try collector.addHit(bar, .button, base_id + @as(u32, @intCast(i)));
    }
    const metric_w = (bounds.w - 40) * 0.5;
    try metricBox(scene, ui.Rect.init(bounds.x + chart_side_gap, metric_y, metric_w, metric_h), "Upcoming", "May 25");
    try metricBox(scene, ui.Rect.init(bounds.x + chart_side_gap + metric_w + 12.0, metric_y, metric_w, metric_h), "Auto-save", "Weekly");
    try button(scene, collector, ui.Rect.init(bounds.x + chart_side_gap, button_y, button_w, button_h), "View Full Report", base_id, true);
}

fn renderForm(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, action_id: u32) GalleryError!void {
    var y = bounds.y;
    try field(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 42), "Amount to Invest", action_id + 1);
    y += 54;
    try field(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 42), "Order Type", action_id + 2);
    y += 58;
    try metricBox(scene, ui.Rect.init(bounds.x, y, (bounds.w - 12) * 0.5, 62), "Estimated Shares", "1.95");
    try metricBox(scene, ui.Rect.init(bounds.x + (bounds.w + 12) * 0.5, y, (bounds.w - 12) * 0.5, 62), "Buying Power", "$12,450");
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + bounds.h - 36, 138, 34), "Review Order", action_id, true);
}

fn savingsTarget(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, target: []const u8, current: []const u8, value: f32) GalleryError!void {
    try fill(scene, bounds, palette.row, 8);
    try text(scene, bounds.x + 12, bounds.y + 10, bounds.w * 0.48, 14, title_value, palette.muted);
    try text(scene, bounds.x + 12, bounds.y + 29, bounds.w * 0.48, 16, target, palette.text);
    try alignedText(scene, bounds.x + bounds.w - 116, bounds.y + 17, 104, 14, current, palette.muted, .end);
    try progress(scene, ui.Rect.init(bounds.x + 12, bounds.y + bounds.h - 7, bounds.w - 24, 5), value);
}

fn checkboxRow(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, checked: bool, id_value: u32) GalleryError!void {
    const box = ui.Rect.init(bounds.x, bounds.y + 5, 20, 20);
    try fill(scene, box, if (checked) palette.text else palette.panel, 5);
    try stroke(scene, box, if (checked) palette.text else palette.border, 5);
    if (checked) try iconQuad(scene, box.insetUniform(3), .check, palette.panel);
    try text(scene, bounds.x + 32, bounds.y + 7, bounds.w - 40, 15, label, palette.text);
    try collector.addHit(bounds, .button, id_value);
}

fn textArea(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, 7);
    try stroke(scene, bounds, palette.border, 7);
    try text(scene, bounds.x + 12, bounds.y + 12, bounds.w - 24, bounds.h - 24, placeholder, palette.muted);
}

fn qrModuleOn(row: usize, col: usize) bool {
    return finder(row, col, 0, 0) or finder(row, col, 0, 8) or finder(row, col, 8, 0) or
        ((row * 7 + col * 11 + row * col) % 5 == 0) or ((row + col * 3) % 7 == 0);
}

fn finder(row: usize, col: usize, origin_row: usize, origin_col: usize) bool {
    const r = row -% origin_row;
    const c = col -% origin_col;
    return r < 5 and c < 5 and (r == 0 or r == 4 or c == 0 or c == 4 or (r == 2 and c == 2));
}

fn renderMetrics(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    const w = (bounds.w - 12) * 0.5;
    try metricBox(scene, ui.Rect.init(bounds.x, bounds.y, w, 72), "Upcoming", "May 25");
    try metricBox(scene, ui.Rect.init(bounds.x + w + 12, bounds.y, w, 72), "Auto-save", "Weekly");
    try progress(scene, ui.Rect.init(bounds.x, bounds.y + 96, bounds.w, 10), 0.68);
    try progress(scene, ui.Rect.init(bounds.x, bounds.y + 124, bounds.w * 0.76, 10), 0.42);
    try text(scene, bounds.x, bounds.y + 152, bounds.w, 40, "Reusable card, progress, badge, and copy primitives.", palette.muted);
}

fn renderTable(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32) GalleryError!void {
    try renderTableRows(scene, collector, bounds, base_id, 4);
}

fn renderTableRows(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32, row_limit: usize) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, 8);
    try text(scene, bounds.x + 14, bounds.y + 14, bounds.w * 0.35, 14, "Item", palette.muted);
    const amount_header = ui.Rect.init(bounds.x + bounds.w * 0.55, bounds.y + 14, bounds.w * 0.4, 14);
    try alignedText(scene, amount_header.x, amount_header.y, amount_header.w, amount_header.h, "Amount", palette.muted, .end);
    const rows = [_]struct { []const u8, []const u8 }{
        .{ "Net Royalties", "$0.00" },
        .{ "Processing Fee", "-$0.00" },
        .{ "Total Ready", "$0.00 USD" },
        .{ "Vanguard ETF", "$48,230" },
    };
    var y = bounds.y + 42;
    const visible_rows = @min(@min(row_limit, rows.len), rowsForTableHeight(bounds.h));
    for (rows[0..visible_rows], 0..) |row, index| {
        const r = ui.Rect.init(bounds.x + 8, y, bounds.w - 16, 38);
        try fill(scene, r, if (hovered(r)) palette.row_hover else if (index % 2 == 0) palette.panel else palette.row, 6);
        try text(scene, r.x + 10, r.y + 12, r.w * 0.45, 14, row[0], palette.text);
        const amount = ui.Rect.init(r.x + r.w * 0.58, r.y + 12, r.w * 0.35, 14);
        try alignedText(scene, amount.x, amount.y, amount.w, amount.h, row[1], palette.muted, .end);
        try collector.addHit(r, .row_item, base_id + @as(u32, @intCast(index)));
        y += 42;
    }
}

fn rowsForTableHeight(height: f32) usize {
    if (height < 80) return 0;
    return @as(usize, @intFromFloat((height - 80) / 42)) + 1;
}

fn renderList(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32, state: ComponentGalleryState) GalleryError!void {
    try renderListRows(scene, collector, bounds, base_id, 4, state.list_order, state.list_order_scope_id);
}

fn renderListRows(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32, row_limit: usize, order: [list_row_count]u8, order_scope_id: u32) GalleryError!void {
    const rows = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "Blue Bottle Coffee", "Food and Drink", "-$6.50" },
        .{ "Whole Foods Market", "Groceries", "-$142.30" },
        .{ "Stripe Payout", "Income", "+$4,200" },
        .{ "Realty Income", "Dividend", "$1,139" },
    };
    var row_cursor = ui.LinearCursor.init(bounds, .column, 10);
    const visible_rows = @min(@min(row_limit, rows.len), rowsForListHeight(bounds.h));
    for (0..visible_rows) |index| {
        const row_index = orderedRowIndex(index, order, order_scope_id == base_id);
        const row = rows[row_index];
        const r = row_cursor.take(54);
        try scene.pushDropTarget(.{ .scope_id = base_id, .index = index, .bounds = r });
        try scene.pushDragSource(.{ .scope_id = base_id, .item_id = base_id + @as(u32, @intCast(row_index)), .index = index, .bounds = r });
        try fill(scene, r, if (hovered(r)) palette.row_hover else palette.row, 7);
        const icon_box = ui.Rect.init(r.x + 10, r.y + 10, 34, 34);
        try fill(scene, icon_box, palette.panel, 7);
        try iconQuad(scene, icon_box.insetUniform(8), listRowIcon(row_index), if (row[2][0] == '+') palette.green else palette.muted);
        try text(scene, r.x + 56, r.y + 11, r.w - 128, 16, row[0], palette.text);
        try text(scene, r.x + 56, r.y + 31, r.w - 128, 14, row[1], palette.muted);
        try alignedText(scene, r.x + r.w - 70, r.y + 21, 58, 12, row[2], if (row[2][0] == '+') palette.green else palette.muted, .end);
        try collector.addHit(r, .row_item, base_id + @as(u32, @intCast(row_index)));
    }
}

fn orderedRowIndex(index: usize, order: [list_row_count]u8, enabled: bool) usize {
    if (!enabled) return index;
    const value: usize = order[index];
    if (value >= list_row_count) return index;
    return value;
}

fn rowsForListHeight(height: f32) usize {
    if (height < 54) return 0;
    return @as(usize, @intFromFloat((height + 10) / 64));
}

fn renderCentered(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, action_id: u32, title: []const u8) GalleryError!void {
    const center_x = bounds.x + bounds.w * 0.5;
    const has_action = action_id != preview_base_id;
    const icon_size: f32 = 56;
    const icon_top: f32 = 12;
    const title_gap: f32 = 20;
    const copy_gap: f32 = 6;
    const button_h: f32 = 34;
    const button_bottom: f32 = 0;
    const icon_box = ui.Rect.init(center_x - icon_size * 0.5, bounds.y + icon_top, icon_size, icon_size);
    try fill(scene, icon_box, if (hovered(bounds)) palette.row_hover else palette.row, 14);
    try iconQuad(scene, icon_box.insetUniform(15), centeredCardIcon(title), palette.text);
    const button_y = bounds.y + bounds.h - button_h - button_bottom;
    const text_x = bounds.x + 24.0;
    const text_w = bounds.w - 48.0;
    const title_y = icon_box.y + icon_box.h + title_gap;
    const copy_y = title_y + body_text_height + copy_gap;
    const copy_bottom = if (has_action) button_y - 4.0 else bounds.y + bounds.h;
    if (title_y + body_text_height <= copy_bottom) {
        try alignedText(scene, text_x, title_y, text_w, body_text_height, "Native component preview", palette.text, .center);
    }
    if (copy_y + body_text_height <= copy_bottom) {
        try centeredWrappedText(scene, ui.Rect.init(text_x, copy_y, text_w, copy_bottom - copy_y), "Canvas-hosted, reusable, and compact.", palette.muted, 2);
    }
    if (has_action) {
        const button_w = @min(140, bounds.w - 48);
        try button(scene, collector, ui.Rect.init(center_x - button_w * 0.5, button_y, button_w, button_h), "Continue", action_id, true);
    }
}

fn renderControls(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32) GalleryError!void {
    try switchRow(scene, collector, bounds.x, bounds.y, bounds.w, "Public Statistics", true, base_id);
    try switchRow(scene, collector, bounds.x, bounds.y + 52, bounds.w, "Email Notifications", true, base_id + 1);
    try slider(scene, collector, ui.Rect.init(bounds.x, bounds.y + 110, bounds.w, 42), "Brightness", 0.82, base_id + 2);
    try slider(scene, collector, ui.Rect.init(bounds.x, bounds.y + 156, bounds.w, 42), "Volume", 0.42, base_id + 3);
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + bounds.h - 36, 156, 34), "Save Preferences", base_id + 4, true);
}

fn renderNavigation(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32) GalleryError!void {
    const tabs = [_][]const u8{ "Dashboard", "Transactions", "Settings" };
    const tab_gap: f32 = 8;
    const middle_w = @min(112, bounds.w * 0.38);
    const side_w = (bounds.w - middle_w - tab_gap * 2.0) * 0.5;
    var tabs_cursor = ui.LinearCursor.init(ui.Rect.init(bounds.x, bounds.y, bounds.w, 34), .row, tab_gap);
    for (tabs, 0..) |label, index| {
        const tab_w = if (index == 1) middle_w else side_w;
        try tabButton(scene, collector, tabs_cursor.take(tab_w), label, base_id + @as(u32, @intCast(index)), index == 0);
    }
    const rows = [_][]const u8{ "Change transfer limit", "Scheduled transfers", "Direct Debits", "Security" };
    const row_count = @min(rows.len, @as(usize, @intFromFloat(@max(0, bounds.h - 48) / 58)));
    var row_cursor = ui.LinearCursor.init(ui.Rect.init(bounds.x, bounds.y + 58, bounds.w, @max(0.0, bounds.h - 58)), .column, 10);
    for (rows[0..row_count], 0..) |label, index| {
        const r = row_cursor.take(48);
        try fill(scene, r, if (hovered(r)) palette.row_hover else palette.row, 7);
        try iconQuad(scene, ui.Rect.init(r.x + 14, r.y + 15, 18, 18), navigationRowIcon(index), palette.muted);
        try text(scene, r.x + 42, r.y + 16, r.w - 76, 15, label, palette.text);
        try iconQuad(scene, ui.Rect.init(r.x + r.w - 30, r.y + 16, 16, 16), .chevron_right, palette.muted);
        try collector.addHit(r, .row_item, base_id + 20 + @as(u32, @intCast(index)));
    }
}

fn listRowIcon(index: usize) icon.Icon {
    return switch (index) {
        0 => .wallet,
        1 => .storage,
        2 => .send,
        3 => .database,
        else => .activity,
    };
}

fn centeredCardIcon(title: []const u8) icon.Icon {
    if (std.mem.eql(u8, title, "Distribute Track")) return .send;
    if (std.mem.eql(u8, title, "Mobile Pairing")) return .network;
    if (std.mem.eql(u8, title, "Cover Art")) return .file;
    if (std.mem.eql(u8, title, "Connect Bank")) return .wallet;
    if (std.mem.eql(u8, title, "Explore Catalog")) return .storage;
    if (std.mem.eql(u8, title, "Syncing Accounts")) return .activity;
    return .sparkles;
}

fn navigationRowIcon(index: usize) icon.Icon {
    return switch (index) {
        0 => .settings,
        1 => .activity,
        2 => .route,
        3 => .shield,
        else => .chevron_right,
    };
}

fn renderCalendar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32) GalleryError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 18, "May 2026", palette.text);
    const cell: f32 = @min(38, (bounds.w - 36) / 7);
    var day: usize = 1;
    var y = bounds.y + 34;
    for (0..3) |row| {
        var x = bounds.x;
        for (0..7) |col| {
            const r = ui.Rect.init(x, y, cell, cell);
            const active = row == 2 and col == 2;
            try fill(scene, r, if (active) palette.accent else if (hovered(r)) palette.row_hover else palette.row, 8);
            try collector.addHit(r, .button, base_id + @as(u32, @intCast(day)));
            day += 1;
            x += cell + 6;
        }
        y += cell + 6;
    }
    const list_y = y + 8;
    try renderListRows(scene, collector, ui.Rect.init(bounds.x, list_y, bounds.w, @max(54, bounds.y + bounds.h - list_y)), base_id + 40, 2, default_list_order, 0);
}

fn renderSkeleton(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    const bar_h: f32 = 18;
    const bar_gap: f32 = 14;
    const block_h: f32 = 38;
    const block_gap: f32 = 14;
    const bottom_y = bounds.y + bounds.h - block_h;
    var y = bounds.y;
    const widths = [_]f32{ 0.42, 0.68, 1.0, 0.92, 0.54 };
    for (widths) |factor| {
        if (y + bar_h > bottom_y - block_gap) break;
        try fill(scene, ui.Rect.init(bounds.x, y, bounds.w * factor, bar_h), palette.row, bar_h * 0.5);
        y += bar_h + bar_gap;
    }
    try fill(scene, ui.Rect.init(bounds.x, bottom_y, (bounds.w - 12) * 0.5, block_h), palette.row, 8);
    try fill(scene, ui.Rect.init(bounds.x + (bounds.w + 12) * 0.5, bottom_y, (bounds.w - 12) * 0.5, block_h), palette.row, 8);
}

fn renderSecurity(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, base_id: u32) GalleryError!void {
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 120), palette.row, 10);
    try badge(scene, ui.Rect.init(bounds.x + bounds.w - 86, bounds.y + 14, 70, 24), "Locked", palette.danger);
    try slider(scene, collector, ui.Rect.init(bounds.x, bounds.y + 142, bounds.w, 42), "Open", 0.35, base_id);
    const button_y = bounds.y + bounds.h - 36;
    try button(scene, collector, ui.Rect.init(bounds.x, button_y, 78, 34), "Open", base_id + 1, false);
    try button(scene, collector, ui.Rect.init(bounds.x + 88, button_y, 78, 34), "Half", base_id + 2, false);
    try button(scene, collector, ui.Rect.init(bounds.x + 176, button_y, 96, 34), "Closed", base_id + 3, true);
}

fn field(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id_value: u32) GalleryError!void {
    const is_hovered = hovered(bounds);
    try fill(scene, bounds, if (is_hovered) palette.panel_alt_hover else palette.panel_alt, control_radius);
    try stroke(scene, bounds, if (is_hovered) palette.border_hover else palette.border, control_radius);
    try text(scene, bounds.x + 12, bounds.y + (bounds.h - compact_text_height) * 0.5, bounds.w - 24, compact_text_height, label, palette.muted);
    try collector.addHit(bounds, .input, id_value);
}

fn searchField(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id_value: u32) GalleryError!void {
    const is_hovered = hovered(bounds);
    try fill(scene, bounds, if (is_hovered) palette.panel_alt_hover else palette.panel_alt, control_radius);
    try stroke(scene, bounds, if (is_hovered) palette.border_hover else palette.border, control_radius);
    try iconQuad(scene, ui.Rect.init(bounds.x + 12, bounds.y + (bounds.h - 16.0) * 0.5, 16, 16), .search, palette.muted);
    try text(scene, bounds.x + 36, bounds.y + (bounds.h - compact_text_height) * 0.5, bounds.w - 48, compact_text_height, label, palette.muted);
    try collector.addHit(bounds, .input, id_value);
}

fn button(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id_value: u32, primary: bool) GalleryError!void {
    try buttonChrome(scene, bounds, primary);
    try centeredText(scene, bounds, label, if (primary) palette.panel else palette.text);
    try collector.addHit(bounds, .button, id_value);
}

fn tabButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id_value: u32, primary: bool) GalleryError!void {
    try buttonChrome(scene, bounds, primary);
    try alignedText(scene, bounds.x + 4.0, bounds.y + (bounds.h - 12.0) * 0.5, @max(1.0, bounds.w - 8.0), 12.0, label, if (primary) palette.panel else palette.text, .center);
    try collector.addHit(bounds, .button, id_value);
}

fn buttonWithIcon(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, value: icon.Icon, id_value: u32, primary: bool) GalleryError!void {
    try buttonChrome(scene, bounds, primary);
    const icon_color = if (primary) palette.panel else palette.text;
    const label_w = @min(@max(1.0, bounds.w - 40.0), @as(f32, @floatFromInt(label.len)) * text_char_w);
    const group_w = label_w + 22.0;
    const group_x = bounds.x + (bounds.w - group_w) * 0.5;
    try iconQuad(scene, ui.Rect.init(group_x, bounds.y + (bounds.h - 16.0) * 0.5, 16, 16), value, icon_color);
    try alignedText(scene, group_x + 22.0, bounds.y + (bounds.h - 14.0) * 0.5, label_w, 14.0, label, icon_color, .start);
    try collector.addHit(bounds, .button, id_value);
}

fn buttonChrome(scene: *ui.Scene, bounds: ui.Rect, primary: bool) GalleryError!void {
    const is_hovered = hovered(bounds);
    if (is_hovered) try scene.pushRect(bounds.insetUniform(-1), palette.shadow_hover, .shadow, control_radius, control_shadow);
    if (primary) {
        const top = if (is_hovered) ui.Color{ .r = 255, .g = 255, .b = 255 } else palette.text;
        const bottom = if (is_hovered) ui.Color{ .r = 226, .g = 232, .b = 240 } else palette.text;
        try scene.pushGradientRect(bounds, top, bottom, control_radius);
    } else {
        try scene.pushGradientRect(bounds, if (is_hovered) palette.panel_alt_hover else palette.panel_alt, if (is_hovered) palette.row_hover else palette.panel_alt, control_radius);
    }
    try stroke(scene, bounds, if (is_hovered) palette.border_hover else if (primary) palette.text else palette.border, control_radius);
}

fn ghostButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id_value: u32) GalleryError!void {
    if (hovered(bounds)) try fill(scene, bounds, palette.panel_alt_hover, control_radius);
    try centeredText(scene, bounds, label, palette.text);
    try collector.addHit(bounds, .button, id_value);
}

fn metricBox(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, value: []const u8) GalleryError!void {
    try fill(scene, bounds, if (hovered(bounds)) palette.row_hover else palette.row, 8);
    const label_y = bounds.y + @max(10.0, @min(14.0, bounds.h * 0.2));
    const value_y = @min(label_y + 22.0, bounds.y + bounds.h - 28.0);
    try text(scene, bounds.x + 12, label_y, bounds.w - 24, 12, label, palette.muted);
    try text(scene, bounds.x + 12, value_y, bounds.w - 24, 18, value, palette.text);
}

fn switchRow(scene: *ui.Scene, collector: *interaction.Collector, x: f32, y: f32, w: f32, label: []const u8, checked: bool, id_value: u32) GalleryError!void {
    const bounds = ui.Rect.init(x, y, w, 42);
    const is_hovered = hovered(bounds);
    try text(scene, x, y + 5, w - 72, 16, label, palette.text);
    try text(scene, x, y + 25, w - 72, 14, "Native switch state", palette.muted);
    const track = ui.Rect.init(x + w - 54, y + 10, 48, 26);
    try fill(scene, track, if (checked) palette.text else if (is_hovered) palette.row_hover else palette.row, 13);
    const thumb_offset: f32 = if (checked) 24 else 3;
    try fill(scene, ui.Rect.init(track.x + thumb_offset, track.y + 3, 20, 20), if (is_hovered) palette.panel_hover else palette.panel, 10);
    try collector.addHit(track, .button, id_value);
}

fn slider(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, value: f32, id_value: u32) GalleryError!void {
    const is_hovered = hovered(bounds);
    try text(scene, bounds.x, bounds.y, bounds.w, 14, label, palette.text);
    const track = ui.Rect.init(bounds.x, bounds.y + 24, bounds.w, 6);
    try fill(scene, track, if (is_hovered) palette.row_hover else palette.row, 3);
    try fill(scene, ui.Rect.init(track.x, track.y, track.w * std.math.clamp(value, 0.0, 1.0), track.h), palette.accent, 3);
    const thumb = ui.Rect.init(track.x + track.w * std.math.clamp(value, 0.0, 1.0) - 7, track.y - 5, 16, 16);
    if (is_hovered) try scene.pushRect(thumb.insetUniform(-1), palette.shadow_hover, .shadow, 8, 4);
    try fill(scene, thumb, if (is_hovered) palette.panel_hover else palette.panel, 8);
    try collector.addHit(bounds, .button, id_value);
}

fn progress(scene: *ui.Scene, bounds: ui.Rect, value: f32) GalleryError!void {
    try fill(scene, bounds, palette.row, bounds.h * 0.5);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w * std.math.clamp(value, 0.0, 1.0), bounds.h), palette.accent, bounds.h * 0.5);
}

fn badge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) GalleryError!void {
    var fill_color = color;
    fill_color.a = 30;
    try fill(scene, bounds, fill_color, bounds.h * 0.5);
    try alignedText(scene, bounds.x + 10, bounds.y + (bounds.h - 12.0) * 0.5, bounds.w - 20, 12, label, color, .center);
}

fn panel(scene: *ui.Scene, bounds: ui.Rect, radius: f32) GalleryError!void {
    try fill(scene, bounds, palette.panel, radius);
    try stroke(scene, bounds, palette.border, radius);
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) GalleryError!void {
    try scene.pushRect(bounds, color, .fill, radius, 0);
}

fn stroke(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) GalleryError!void {
    try scene.pushRect(bounds, color, .border, radius, 0);
}

fn iconQuad(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) GalleryError!void {
    try scene.pushIconQuad(.{ .bounds = bounds, .icon_id = icon.id(value), .color = color });
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) GalleryError!void {
    try alignedText(scene, x, y, w, h, value, color, .start);
}

fn alignedText(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) GalleryError!void {
    if (gallery_text_clip_top) |clip_top| {
        if (y < clip_top) return;
    }
    if (h < 28) {
        try scene.pushAlignedText(ui.Rect.init(x, y, @max(1, w), @max(1, h)), value, color, alignment);
        return;
    }
    const line_height = if (h >= 28) @as(f32, 16) else @max(12, @min(20, h));
    try scene.pushWrappedText(ui.Rect.init(x, y, @max(1, w), @max(1, h)), value, color, .{
        .line_height = line_height,
        .average_char_width = text_char_w,
        .max_lines = 4,
    });
}

fn centeredText(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) GalleryError!void {
    try alignedText(scene, bounds.x + 8.0, bounds.y + (bounds.h - 14.0) * 0.5, @max(1.0, bounds.w - 16.0), 14.0, value, color, .center);
}

fn centeredWrappedText(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, max_lines: usize) GalleryError!void {
    if (value.len == 0 or !bounds.valid() or max_lines == 0) return;
    const line_height = body_text_height;
    const lines_by_height = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, bounds.h / line_height))));
    const line_count = @min(max_lines, lines_by_height);
    const char_capacity = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, bounds.w / text_char_w))));
    var byte_cursor: usize = 0;
    var line_index: usize = 0;
    while (line_index < line_count) : (line_index += 1) {
        byte_cursor = ui.skipAsciiSpace(value, byte_cursor);
        if (byte_cursor >= value.len) break;
        const split = ui.wrappedLine(value, byte_cursor, char_capacity);
        if (split.end > split.start) {
            try alignedText(scene, bounds.x, bounds.y + @as(f32, @floatFromInt(line_index)) * line_height, bounds.w, line_height, value[split.start..split.end], color, .center);
        }
        byte_cursor = split.next;
    }
}

fn hovered(bounds: ui.Rect) bool {
    const point = gallery_hover_point orelse return false;
    return bounds.containsExclusive(point.x, point.y);
}

fn shortestColumn(values: []const f32) usize {
    var best: usize = 0;
    var best_value = values[0];
    for (values[1..], 1..) |value, index| {
        if (value < best_value) {
            best = index;
            best_value = value;
        }
    }
    return best;
}

test "component gallery catalog is the authoritative component registry" {
    try std.testing.expectEqual(@as(usize, 57), component_catalog.len);
    try std.testing.expectEqual(@as(usize, 16), nativeComponentCount());
    try std.testing.expectEqual(@as(usize, 41), countByStatus(.cataloged));
    try std.testing.expectEqual(@as(usize, 0), countByStatus(.exact_port));
    try std.testing.expect(findBySlug("button").?.hasNativeRenderer());
    try std.testing.expect(!findBySlug("accordion").?.hasNativeRenderer());
    try std.testing.expectEqualStrings("/docs/components/input-group", findBySlug("input-group").?.route);
    try std.testing.expectEqualStrings("Button", findBySourceComponent("Button").?.source_component);
    try std.testing.expectEqual(Category.foundation, findBySlug("button").?.category);
    try std.testing.expectEqual(@as(usize, 15), countByCategory(.form));
    try std.testing.expectEqual(@as(usize, 6), countByCategory(.layout));
}

test "component gallery native catalog entries render through canonical components" {
    var commands: [256]ui.Command = undefined;
    var regions: [64]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    var rendered: usize = 0;

    for (component_catalog, 0..) |spec, index| {
        const component = spec.nativeComponent(preview_base_id + @as(u32, @intCast(index))) orelse {
            try std.testing.expect(!spec.hasNativeRenderer());
            continue;
        };
        try std.testing.expect(spec.hasNativeRenderer());
        const y = @as(f32, @floatFromInt(rendered)) * 48.0;
        const bounds = ui.Rect.init(0, y, 220, 36);
        try component.render(&scene, bounds, .{});
        try component.collectInteractions(&collector, bounds);
        rendered += 1;
    }

    try std.testing.expectEqual(nativeComponentCount(), rendered);
    try std.testing.expect(scene.written().len > nativeComponentCount());
    try std.testing.expect(collector.written().len > 6);
    try std.testing.expect(hasHit(collector.written(), preview_base_id + 7));
    try std.testing.expect(findBySlug("accordion").?.nativeComponent(preview_base_id) == null);
}

test "component gallery renders component wall commands and interaction regions" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 1440, 940), .{});

    const stats = scene.stats();
    try std.testing.expect(stats.rects > 150);
    try std.testing.expect(stats.text_quads > 120);
    try std.testing.expect(stats.icon_quads >= 2);
    try std.testing.expect(collector.written().len > 60);
    try std.testing.expect(hasHit(collector.written(), preview_base_id + 908));
    try std.testing.expect(hasText(scene.written(), "Contribution History"));
    try std.testing.expect(hasText(scene.written(), "Stock Performance"));
}

test "component gallery derives responsive card sizing from kind and width" {
    const form = ShowcaseCard{ .title = "Form", .detail = "", .kind = .form, .id = preview_base_id + 5000 };
    const table = ShowcaseCard{ .title = "Table", .detail = "", .kind = .table, .id = preview_base_id + 5001 };

    try std.testing.expectEqual(@as(usize, 1), galleryColumnCount(335, 24));
    try std.testing.expectEqual(@as(usize, 2), galleryColumnCount(696, 24));
    try std.testing.expectEqual(@as(usize, 5), galleryColumnCount(1660, 40));
    try std.testing.expect(showcaseCardHeight(form, 340) < showcaseCardHeight(form, 420));
    try std.testing.expect(showcaseCardHeight(table, 420) > showcaseCardHeight(form, 420));
}

test "component gallery wide masonry uses fifth column without card overlap" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 2048, 940), .{});

    const first = textCommand(scene.written(), "Contribution History").?.text.origin;
    const fifth = textCommand(scene.written(), "Distribute Track").?.text.origin;
    const sixth = textCommand(scene.written(), "Claimable Balance").?.text.origin;

    try std.testing.expect(fifth.x > first.x + 1000);
    try std.testing.expect(sixth.y > first.y + 250);
}

test "component gallery gallery scrolls through later component cards" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 900, 720), .{ .scroll_y = 900 });

    try std.testing.expect(hasText(scene.written(), "Power Usage"));
    try std.testing.expect(hasText(scene.written(), "Notifications"));
}

test "component gallery topbar paints over scrolled card content" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 1440, 940), .{ .scroll_y = 900 });

    const navigation_index = textCommandIndex(scene.written(), "Room Controls").?;
    const topbar_index = textCommandIndex(scene.written(), "Docs").?;
    try std.testing.expect(topbar_index > navigation_index);
}

test "component gallery scrolled card text stays below fixed topbar" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 1440, 940), .{ .scroll_y = 900 });

    for (scene.written()) |command| switch (command) {
        .text => |text_command| {
            if (text_command.origin.x >= 184 and text_command.origin.y < gallery_topbar_h) {
                try std.testing.expect(isTopbarText(text_command.value));
            }
        },
        else => {},
    };
}

test "component gallery hover raises card shadow without changing interaction coverage" {
    var base_commands: [4096]ui.Command = undefined;
    var base_regions: [512]interaction.Region = undefined;
    var base_scene = ui.Scene.init(&base_commands);
    var base_collector = interaction.Collector.init(&base_regions);
    try renderComponentGallery(&base_scene, &base_collector, ui.Rect.init(0, 0, 1440, 940), .{});

    var hover_commands: [4096]ui.Command = undefined;
    var hover_regions: [512]interaction.Region = undefined;
    var hover_scene = ui.Scene.init(&hover_commands);
    var hover_collector = interaction.Collector.init(&hover_regions);
    try renderComponentGallery(&hover_scene, &hover_collector, ui.Rect.init(0, 0, 1440, 940), .{ .hover_x = 260, .hover_y = 120 });

    try std.testing.expect(!hasRectShadow(base_scene.written(), card_hover_shadow));
    try std.testing.expect(hasRectShadow(hover_scene.written(), card_hover_shadow));
    try std.testing.expectEqual(base_collector.written().len, hover_collector.written().len);
}

test "component gallery exposes layout switcher as interaction regions" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 1840, 940), .{ .layout = .grid });

    try std.testing.expect(hasHit(collector.written(), layout_masonry_id));
    try std.testing.expect(hasHit(collector.written(), layout_grid_id));
    try std.testing.expect(hasText(scene.written(), "Masonry"));
    try std.testing.expect(hasText(scene.written(), "Grid"));
}

test "component gallery table amount column is right aligned" {
    var commands: [256]ui.Command = undefined;
    var regions: [64]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderTableRows(&scene, &collector, ui.Rect.init(0, 0, 360, 180), preview_base_id + 6000, 3);

    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "Amount").?.text.alignment);
    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "$0.00").?.text.alignment);
    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "$0.00 USD").?.text.alignment);
}

test "component gallery list amount column is right aligned" {
    var commands: [256]ui.Command = undefined;
    var regions: [64]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderListRows(&scene, &collector, ui.Rect.init(0, 0, 360, 246), preview_base_id + 6100, 4, default_list_order, 0);

    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "-$6.50").?.text.alignment);
    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "+$4,200").?.text.alignment);
    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "$1,139").?.text.alignment);
}

test "component gallery list rows render semantic icons" {
    var commands: [256]ui.Command = undefined;
    var regions: [64]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderListRows(&scene, &collector, ui.Rect.init(0, 0, 360, 246), preview_base_id + 6150, 4, default_list_order, 0);

    try std.testing.expect(hasIcon(scene.written(), icon.id(.wallet)));
    try std.testing.expect(hasIcon(scene.written(), icon.id(.storage)));
    try std.testing.expect(hasIcon(scene.written(), icon.id(.send)));
    try std.testing.expect(hasIcon(scene.written(), icon.id(.database)));
}

test "component gallery list rows expose canonical drag and drop targets" {
    var commands: [256]ui.Command = undefined;
    var regions: [64]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderListRows(&scene, &collector, ui.Rect.init(0, 0, 360, 246), preview_base_id + 6200, 4, default_list_order, 0);

    try std.testing.expectEqual(@as(usize, 4), scene.stats().drag_sources);
    try std.testing.expectEqual(@as(usize, 4), scene.stats().drop_targets);
}

test "component gallery list rows render reordered state by scope" {
    var commands: [256]ui.Command = undefined;
    var regions: [64]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    const scope_id = preview_base_id + 6250;
    try renderListRows(&scene, &collector, ui.Rect.init(0, 0, 360, 246), scope_id, 4, .{ 1, 0, 2, 3 }, scope_id);

    const whole_foods = textCommandIndex(scene.written(), "Whole Foods Market").?;
    const blue_bottle = textCommandIndex(scene.written(), "Blue Bottle Coffee").?;
    try std.testing.expect(whole_foods < blue_bottle);
}

test "component gallery icon buttons emit visible icon quads" {
    var commands: [32]ui.Command = undefined;
    var regions: [8]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try buttonWithIcon(&scene, &collector, ui.Rect.init(0, 0, 128, 34), "Get Code", .code, preview_base_id + 7000, true);

    try std.testing.expect(hasIcon(scene.written(), icon.id(.code)));
    try std.testing.expect(hasHit(collector.written(), preview_base_id + 7000));
}

test "component gallery rail exposes Tabler semantic icons" {
    var commands: [512]ui.Command = undefined;
    var regions: [64]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderRail(&scene, &collector, ui.Rect.init(0, 0, 160, 720), grid_gap_wide);

    try std.testing.expect(hasText(scene.written(), "Tabler"));
    try std.testing.expect(hasText(scene.written(), "Wide"));
    try std.testing.expect(hasIcon(scene.written(), icon.id(.menu)));
    try std.testing.expect(hasIcon(scene.written(), icon.id(.sparkles)));
    try std.testing.expect(hasIcon(scene.written(), icon.id(.app)));
    try std.testing.expect(hasIcon(scene.written(), icon.id(.route)));
    try std.testing.expect(hasHit(collector.written(), gap_compact_id));
    try std.testing.expect(hasHit(collector.written(), gap_default_id));
    try std.testing.expect(hasHit(collector.written(), gap_wide_id));
}

test "component gallery centered cards render semantic icon and bounded action" {
    var commands: [128]ui.Command = undefined;
    var regions: [16]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    const bounds = ui.Rect.init(0, 0, 180, 210);
    try renderCentered(&scene, &collector, bounds, preview_base_id + 3000, "Mobile Pairing");

    try std.testing.expect(hasIcon(scene.written(), icon.id(.network)));
    try std.testing.expect(hasHit(collector.written(), preview_base_id + 3000));
    try expectPaintInside(scene.written(), bounds);
}

test "component gallery controls keep action button clear of volume slider" {
    var commands: [256]ui.Command = undefined;
    var regions: [32]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    const base_id = preview_base_id + 2000;
    try renderControls(&scene, &collector, ui.Rect.init(0, 0, 420, 266), base_id);

    const volume = hitBounds(collector.written(), base_id + 3).?;
    const save = hitBounds(collector.written(), base_id + 4).?;
    try std.testing.expect(save.y >= volume.y + volume.h + 24);
}

test "component gallery buttons center labels through shared primitive" {
    var commands: [16]ui.Command = undefined;
    var regions: [8]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    const bounds = ui.Rect.init(10, 20, 140, 34);
    try button(&scene, &collector, bounds, "Continue", preview_base_id + 5010, true);

    const label = textCommand(scene.written(), "Continue").?.text;
    const center_delta = @abs((label.origin.x + label.origin.w * 0.5) - (bounds.x + bounds.w * 0.5));
    try std.testing.expectEqual(ui.TextAlign.center, label.alignment);
    try std.testing.expect(center_delta < 0.01);
    try std.testing.expectEqual(bounds.y + 10.0, label.origin.y);
}

test "component gallery showcase card interaction regions stay inside card bounds" {
    for (showcase_cards) |spec| {
        var commands: [512]ui.Command = undefined;
        var regions: [64]interaction.Region = undefined;
        var scene = ui.Scene.init(&commands);
        var collector = interaction.Collector.init(&regions);
        const bounds = ui.Rect.init(0, 0, 420, showcaseCardHeight(spec, 420));
        try renderShowcaseCard(&scene, &collector, bounds, spec, .{});
        try expectHitsInside(collector.written(), bounds);
    }
}

test "component gallery showcase card paint stays inside card bounds" {
    for (showcase_cards) |spec| {
        var commands: [512]ui.Command = undefined;
        var regions: [64]interaction.Region = undefined;
        var scene = ui.Scene.init(&commands);
        var collector = interaction.Collector.init(&regions);
        const bounds = ui.Rect.init(0, 0, 360, showcaseCardHeight(spec, 360));
        try renderShowcaseCard(&scene, &collector, bounds, spec, .{});
        try expectPaintInside(scene.written(), bounds);
    }
}

test "component gallery narrow copy wraps inside component text regions" {
    var centered_commands: [128]ui.Command = undefined;
    var centered_regions: [16]interaction.Region = undefined;
    var centered_scene = ui.Scene.init(&centered_commands);
    var centered_collector = interaction.Collector.init(&centered_regions);
    try renderCentered(&centered_scene, &centered_collector, ui.Rect.init(0, 0, 180, 210), preview_base_id + 3000, "Distribute Track");
    try std.testing.expect(hasText(centered_scene.written(), "Canvas-hosted,"));
    try std.testing.expect(hasText(centered_scene.written(), "reusable, and"));

    var text_area_commands: [64]ui.Command = undefined;
    var text_area_scene = ui.Scene.init(&text_area_commands);
    try textArea(&text_area_scene, ui.Rect.init(0, 0, 180, 78), "Add notes for this payout configuration...");
    try std.testing.expect(hasText(text_area_scene.written(), "Add notes for this"));
    try std.testing.expect(hasText(text_area_scene.written(), "payout"));
    try std.testing.expect(hasText(text_area_scene.written(), "configuration..."));
}

test "component gallery dense cards reserve vertical spacing between sections" {
    var savings_commands: [128]ui.Command = undefined;
    var savings_scene = ui.Scene.init(&savings_commands);
    try renderSavingsTargets(&savings_scene, ui.Rect.init(0, 0, 360, 176));
    const real_estate = textCommand(savings_scene.written(), "$85,000").?.text.origin;
    const note = textCommandPrefix(savings_scene.written(), "You have not met").?.text.origin;
    try std.testing.expect(note.y >= real_estate.y + real_estate.h + 12.0);

    var chart_commands: [256]ui.Command = undefined;
    var chart_regions: [64]interaction.Region = undefined;
    var chart_scene = ui.Scene.init(&chart_commands);
    var chart_collector = interaction.Collector.init(&chart_regions);
    const base_id = preview_base_id + 8100;
    try renderChart(&chart_scene, &chart_collector, ui.Rect.init(0, 0, 360, 226), base_id, 0.7);
    const metric_label = textCommand(chart_scene.written(), "Upcoming").?.text.origin;
    var index: usize = 0;
    while (index < 6) : (index += 1) {
        const bar = hitBounds(chart_collector.written(), base_id + @as(u32, @intCast(index))).?;
        try std.testing.expect(bar.y + bar.h <= metric_label.y - 10.0);
    }
}

test "component gallery text clears nearby progress and centered actions" {
    var savings_commands: [128]ui.Command = undefined;
    var savings_scene = ui.Scene.init(&savings_commands);
    try savingsTarget(&savings_scene, ui.Rect.init(0, 0, 360, 64), "Retirement", "$420,000", "$273,000", 0.65);
    const amount = textCommand(savings_scene.written(), "$420,000").?.text.origin;
    const progress_bounds = accentProgressBounds(savings_scene.written()).?;
    try std.testing.expect(progress_bounds.y >= amount.y + amount.h + 5.0);

    var centered_commands: [128]ui.Command = undefined;
    var centered_regions: [16]interaction.Region = undefined;
    var centered_scene = ui.Scene.init(&centered_commands);
    var centered_collector = interaction.Collector.init(&centered_regions);
    const action_id = preview_base_id + 8400;
    try renderCentered(&centered_scene, &centered_collector, ui.Rect.init(0, 0, 360, 164), action_id, "Syncing Accounts");
    const title = textCommand(centered_scene.written(), "Native component preview").?.text.origin;
    const copy = textCommandPrefix(centered_scene.written(), "Canvas-hosted").?.text.origin;
    const action = hitBounds(centered_collector.written(), action_id).?;
    try std.testing.expect(copy.y >= title.y + title.h + 4.0);
    try std.testing.expect(action.y >= copy.y + copy.h + 4.0);
}

fn accentProgressBounds(commands: []const ui.Command) ?ui.Rect {
    for (commands) |command| switch (command) {
        .rect => |rect| if (rect.mode == .fill and rect.color.r == palette.accent.r and rect.color.g == palette.accent.g and rect.color.b == palette.accent.b) return rect.bounds,
        else => {},
    };
    return null;
}

fn hasHit(regions: []const interaction.Region, id_value: u32) bool {
    for (regions) |region| {
        if (region.id == id_value) return true;
    }
    return false;
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasIcon(commands: []const ui.Command, icon_id: u32) bool {
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

fn textCommandIndex(commands: []const ui.Command, value: []const u8) ?usize {
    for (commands, 0..) |command, index| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return index,
        else => {},
    };
    return null;
}

fn textCommand(commands: []const ui.Command, value: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return .{ .text = text_command },
        else => {},
    };
    return null;
}

fn textCommandPrefix(commands: []const ui.Command, prefix: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.startsWith(u8, text_command.value, prefix)) return .{ .text = text_command },
        else => {},
    };
    return null;
}

fn hasRectShadow(commands: []const ui.Command, shadow: f32) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (rect.mode == .shadow and rect.shadow == shadow) return true,
        else => {},
    };
    return false;
}

fn isTopbarText(value: []const u8) bool {
    const labels = [_][]const u8{ "Docs", "Components", "Blocks", "Charts", "Directory", "Create", "Search documentation...", "115k", "Open in", "Get Code" };
    for (labels) |label| {
        if (std.mem.eql(u8, value, label)) return true;
    }
    return false;
}

fn hitBounds(regions: []const interaction.Region, id_value: u32) ?ui.Rect {
    for (regions) |region| {
        if (region.id == id_value) return region.bounds;
    }
    return null;
}

fn expectHitsInside(regions: []const interaction.Region, bounds: ui.Rect) !void {
    for (regions) |region| {
        try std.testing.expect(region.bounds.x >= bounds.x);
        try std.testing.expect(region.bounds.y >= bounds.y);
        try std.testing.expect(region.bounds.x + region.bounds.w <= bounds.x + bounds.w);
        try std.testing.expect(region.bounds.y + region.bounds.h <= bounds.y + bounds.h);
    }
}

fn expectPaintInside(commands: []const ui.Command, bounds: ui.Rect) !void {
    for (commands) |command| switch (command) {
        .rect => |value| {
            if (value.mode != .shadow) try expectRectInside(value.bounds, bounds);
        },
        .border => |value| try expectRectInside(value.bounds, bounds),
        .text => |value| try expectRectInside(value.origin, bounds),
        .icon_quad => |value| try expectRectInside(value.bounds, bounds),
        .text_quad => |value| try expectRectInside(value.bounds, bounds),
        else => {},
    };
}

fn expectRectInside(value: ui.Rect, bounds: ui.Rect) !void {
    try std.testing.expect(value.x >= bounds.x);
    try std.testing.expect(value.y >= bounds.y);
    try std.testing.expect(value.x + value.w <= bounds.x + bounds.w);
    try std.testing.expect(value.y + value.h <= bounds.y + bounds.h);
}
