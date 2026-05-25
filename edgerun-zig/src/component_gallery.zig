const std = @import("std");
const icon = @import("icon.zig");
const components = @import("ui_components.zig");
const ui = @import("ui.zig");
const interaction = @import("ui_interaction.zig");

const GalleryError = ui.RenderError || interaction.Error;

pub const preview_base_id: u32 = 18_000;
pub const layout_masonry_id: u32 = preview_base_id + 970;
pub const layout_grid_id: u32 = preview_base_id + 971;
pub const gap_compact_id: u32 = preview_base_id + 974;
pub const gap_default_id: u32 = preview_base_id + 975;
pub const gap_wide_id: u32 = preview_base_id + 976;
pub const first_catalog_card_id: u32 = preview_base_id + 2000;
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
const catalog_intro_h: f32 = 86;
const catalog_card_h: f32 = 148;
const catalog_preview_h: f32 = 38;
const catalog_status_w: f32 = 116;
const catalog_card_pad: f32 = 14;
const catalog_source_w: f32 = 108;
const selected_component_h: f32 = 164;
const selected_component_gap: f32 = 32;
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
    preview: PreviewKind,
};

pub const PreviewKind = enum {
    accordion,
    alert,
    alert_dialog,
    aspect_ratio,
    avatar,
    badge,
    breadcrumb,
    button,
    button_group,
    calendar,
    card,
    carousel,
    chart,
    checkbox,
    combobox,
    command,
    context_menu,
    data_table,
    date_picker,
    dialog,
    direction,
    drawer,
    dropdown_menu,
    empty,
    field,
    hover_card,
    input,
    input_group,
    input_otp,
    item,
    kbd,
    label,
    menubar,
    native_select,
    navigation_menu,
    pagination,
    popover,
    progress,
    radio_group,
    resizable,
    scroll_area,
    select,
    separator,
    sheet,
    sidebar,
    skeleton,
    slider,
    sonner,
    switch_control,
    table,
    tabs,
    textarea,
    toast,
    toggle,
    toggle_group,
    tooltip,
};

pub const categories = [_]Category{ .foundation, .form, .overlay, .navigation, .data_display, .feedback, .layout, .media };

pub const CategorySummary = struct {
    category: Category,
    label: []const u8,
    count: usize,
};

const catalog_eval_branch_quota: u32 = component_route_count * component_route_count * 2;

pub const component_catalog = blk: {
    @setEvalBranchQuota(catalog_eval_branch_quota);
    break :blk [_]ComponentSpec{
        componentSpec("Accordion", "accordion", .layout, "Accordion", "accordion_node", .accordion),
        componentSpec("Alert", "alert", .feedback, "Alert", "alert_node", .alert),
        componentSpec("Alert Dialog", "alert-dialog", .overlay, "AlertDialog", "alert_dialog_node", .alert_dialog),
        componentSpec("Aspect Ratio", "aspect-ratio", .media, "AspectRatio", "aspect_ratio_node", .aspect_ratio),
        componentSpec("Avatar", "avatar", .data_display, "Avatar", "avatar_node", .avatar),
        componentSpec("Badge", "badge", .foundation, "Badge", "badge", .badge),
        componentSpec("Breadcrumb", "breadcrumb", .navigation, "Breadcrumb", "breadcrumb", .breadcrumb),
        componentSpec("Button", "button", .foundation, "Button", "button", .button),
        componentSpec("Button Group", "button-group", .foundation, "ButtonGroup", "button_group_node", .button_group),
        componentSpec("Calendar", "calendar", .form, "Calendar", "calendar_node", .calendar),
        componentSpec("Card", "card", .layout, "Card", "card", .card),
        componentSpec("Carousel", "carousel", .media, "Carousel", "carousel_node", .carousel),
        componentSpec("Chart", "chart", .data_display, "Chart", "chart_node", .chart),
        componentSpec("Checkbox", "checkbox", .form, "Checkbox", "checkbox", .checkbox),
        componentSpec("Collapsible", "collapsible", .layout, "Collapsible", "collapsible_node", .accordion),
        componentSpec("Combobox", "combobox", .form, "Combobox", "combobox_node", .combobox),
        componentSpec("Command", "command", .overlay, "Command", "command_palette", .command),
        componentSpec("Context Menu", "context-menu", .overlay, "ContextMenu", "context_menu_node", .context_menu),
        componentSpec("Data Table", "data-table", .data_display, "DataTable", "data_table_node", .data_table),
        componentSpec("Date Picker", "date-picker", .form, "DatePicker", "date_picker_node", .date_picker),
        componentSpec("Dialog", "dialog", .overlay, "Dialog", "dialog", .dialog),
        componentSpec("Direction", "direction", .foundation, "DirectionProvider", "direction_node", .direction),
        componentSpec("Drawer", "drawer", .overlay, "Drawer", "drawer_node", .drawer),
        componentSpec("Dropdown Menu", "dropdown-menu", .overlay, "DropdownMenu", "dropdown_menu_node", .dropdown_menu),
        componentSpec("Empty", "empty", .feedback, "Empty", "empty_state", .empty),
        componentSpec("Field", "field", .form, "Field", "field_node", .field),
        componentSpec("Hover Card", "hover-card", .overlay, "HoverCard", "hover_card_node", .hover_card),
        componentSpec("Input", "input", .form, "Input", "field_node", .input),
        componentSpec("Input Group", "input-group", .form, "InputGroup", "input_group_node", .input_group),
        componentSpec("Input OTP", "input-otp", .form, "InputOTP", "input_otp_node", .input_otp),
        componentSpec("Item", "item", .data_display, "Item", "list_row_node", .item),
        componentSpec("Kbd", "kbd", .foundation, "Kbd", "kbd_node", .kbd),
        componentSpec("Label", "label", .form, "Label", "text", .label),
        componentSpec("Menubar", "menubar", .navigation, "Menubar", "menubar_node", .menubar),
        componentSpec("Native Select", "native-select", .form, "NativeSelect", "select_node", .native_select),
        componentSpec("Navigation Menu", "navigation-menu", .navigation, "NavigationMenu", "navigation_menu_node", .navigation_menu),
        componentSpec("Pagination", "pagination", .navigation, "Pagination", "pagination_node", .pagination),
        componentSpec("Popover", "popover", .overlay, "Popover", "popover_node", .popover),
        componentSpec("Progress", "progress", .feedback, "Progress", "progress_bar_node", .progress),
        componentSpec("Radio Group", "radio-group", .form, "RadioGroup", "radio", .radio_group),
        componentSpec("Resizable", "resizable", .layout, "Resizable", "resizable_node", .resizable),
        componentSpec("Scroll Area", "scroll-area", .layout, "ScrollArea", "scroll_area", .scroll_area),
        componentSpec("Select", "select", .form, "Select", "select_node", .select),
        componentSpec("Separator", "separator", .layout, "Separator", "divider", .separator),
        componentSpec("Sheet", "sheet", .overlay, "Sheet", "sheet_node", .sheet),
        componentSpec("Sidebar", "sidebar", .navigation, "Sidebar", "sidebar_node", .sidebar),
        componentSpec("Skeleton", "skeleton", .feedback, "Skeleton", "skeleton", .skeleton),
        componentSpec("Slider", "slider", .form, "Slider", "slider_node", .slider),
        componentSpec("Sonner", "sonner", .feedback, "Sonner", "toast", .sonner),
        componentSpec("Switch", "switch", .form, "Switch", "toggle_node", .switch_control),
        componentSpec("Table", "table", .data_display, "Table", "table_node", .table),
        componentSpec("Tabs", "tabs", .navigation, "Tabs", "tabs_node", .tabs),
        componentSpec("Textarea", "textarea", .form, "Textarea", "text_area_node", .textarea),
        componentSpec("Toast", "toast", .feedback, "Toast", "toast", .toast),
        componentSpec("Toggle", "toggle", .foundation, "Toggle", "toggle_node", .toggle),
        componentSpec("Toggle Group", "toggle-group", .foundation, "ToggleGroup", "toggle_group_node", .toggle_group),
        componentSpec("Tooltip", "tooltip", .overlay, "Tooltip", "tooltip", .tooltip),
    };
};

fn componentSpec(name: []const u8, slug: []const u8, category: Category, source_component: []const u8, edge_builder: []const u8, preview: PreviewKind) ComponentSpec {
    return .{
        .name = name,
        .slug = slug,
        .route = routeFor(slug),
        .category = category,
        .source_component = source_component,
        .edge_builder = edge_builder,
        .preview = preview,
    };
}

pub fn findBySlug(slug: []const u8) ?*const ComponentSpec {
    for (&component_catalog) |*entry| {
        if (std.mem.eql(u8, entry.slug, slug)) return entry;
    }
    return null;
}

pub fn findBySourceComponent(source_component: []const u8) ?*const ComponentSpec {
    for (&component_catalog) |*entry| {
        if (std.mem.eql(u8, entry.source_component, source_component)) return entry;
    }
    return null;
}

pub fn indexBySlug(slug: []const u8) ?usize {
    for (component_catalog, 0..) |entry, index| {
        if (std.mem.eql(u8, entry.slug, slug)) return index;
    }
    return null;
}

pub fn indexByCatalogHit(hit_id: u32) ?usize {
    if (hit_id < first_catalog_card_id) return null;
    const index: usize = @intCast(hit_id - first_catalog_card_id);
    return if (index < component_catalog.len) index else null;
}

pub fn countByCategory(category: Category) usize {
    var count: usize = 0;
    for (component_catalog) |entry| {
        if (entry.category == category) count += 1;
    }
    return count;
}

pub fn categorySummary(category: Category) CategorySummary {
    return .{ .category = category, .label = category.label(), .count = countByCategory(category) };
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
    layout: LayoutMode = .masonry,
    grid_gap: f32 = grid_gap_default,
    scroll_y: f32 = 0.0,
    hover_x: f32 = hover_disabled_coord,
    hover_y: f32 = hover_disabled_coord,
    selected_component_index: ?usize = null,
};

pub fn contentHeight(width: f32) f32 {
    return contentHeightForState(width, .{});
}

pub fn contentHeightForState(width: f32, state: ComponentGalleryState) f32 {
    const bounds = ui.Rect.init(0, 0, @max(1.0, width), 1);
    const layout = galleryLayout(bounds, state);
    const catalog_h = catalogSectionHeight(layout.columns, layout.gap);
    const selected_h: f32 = if (selectedComponent(state.selected_component_index) != null) selected_component_h + selected_component_gap else 0;
    return gallery_topbar_h + 40 + selected_h + catalog_h + 120;
}

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

    {
        const previous_text_clip_top = gallery_text_clip_top;
        gallery_text_clip_top = bounds.y + gallery_topbar_h;
        defer gallery_text_clip_top = previous_text_clip_top;

        _ = state.layout;
        const catalog_h = catalogSectionHeight(layout.columns, layout.gap);
        try renderCatalogSection(scene, collector, ui.Rect.init(layout.board.x, layout.board.y, layout.board.w, catalog_h), layout.columns, layout.gap, state.selected_component_index);
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

fn catalogSectionHeight(columns: usize, gap: f32) f32 {
    const rows = (component_catalog.len + columns - 1) / columns;
    return catalog_intro_h + @as(f32, @floatFromInt(rows)) * catalog_card_h + @as(f32, @floatFromInt(rows - 1)) * gap;
}

fn renderCatalogSection(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, columns: usize, gap: f32, selected_index: ?usize) GalleryError!void {
    var cursor_y = bounds.y;
    if (selectedComponent(selected_index)) |entry| {
        try renderSelectedComponent(scene, collector, ui.Rect.init(bounds.x, cursor_y, bounds.w, selected_component_h), entry, selected_index.?);
        cursor_y += selected_component_h + selected_component_gap;
    }

    try text(scene, bounds.x, cursor_y, bounds.w, 22, "Component Catalog", palette.text);
    try wrappedText(scene, ui.Rect.init(bounds.x, cursor_y + 32, bounds.w, 42), "Every public component starts here. Catalog cards are rendered from the base-nova reference structure, through the same scene commands used by browser, CPU, and GPU hosts.", palette.muted, 18, 9.4, 2);

    const card_w = (bounds.w - gap * @as(f32, @floatFromInt(columns - 1))) / @as(f32, @floatFromInt(columns));
    for (component_catalog, 0..) |entry, index| {
        const col = index % columns;
        const row = index / columns;
        const card_bounds = ui.Rect.init(
            bounds.x + @as(f32, @floatFromInt(col)) * (card_w + gap),
            cursor_y + catalog_intro_h + @as(f32, @floatFromInt(row)) * (catalog_card_h + gap),
            card_w,
            catalog_card_h,
        );
        const card_id = first_catalog_card_id + @as(u32, @intCast(index));
        const preview_id = preview_base_id + 5000 + @as(u32, @intCast(index)) * 32;
        try renderCatalogCard(scene, collector, card_bounds, entry, card_id, preview_id, selected_index == index);
    }
}

fn selectedComponent(selected_index: ?usize) ?ComponentSpec {
    const index = selected_index orelse return null;
    if (index >= component_catalog.len) return null;
    return component_catalog[index];
}

fn renderSelectedComponent(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, entry: ComponentSpec, index: usize) GalleryError!void {
    try scene.pushRect(bounds.insetUniform(-1), palette.shadow, .shadow, card_radius, card_shadow);
    try fill(scene, bounds, palette.panel, card_radius);
    try stroke(scene, bounds, palette.accent, card_radius);

    const inset = bounds.insetUniform(18);
    try catalogSource(scene, ui.Rect.init(inset.x, inset.y, catalog_source_w, 24), true);
    try text(scene, inset.x, inset.y + 38, inset.w * 0.42, 26, entry.name, palette.text);
    try text(scene, inset.x, inset.y + 72, inset.w * 0.42, body_text_height, entry.route, palette.muted);
    try text(scene, inset.x, inset.y + 96, inset.w * 0.42, body_text_height, entry.edge_builder, palette.muted);

    const preview_bounds = ui.Rect.init(inset.x + inset.w * 0.48, inset.y + 10, inset.w * 0.52, inset.h - 20);
    try renderReferencePreview(scene, collector, preview_bounds, entry, preview_base_id + 7000 + @as(u32, @intCast(index)) * 32);
}

fn renderCatalogCard(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, entry: ComponentSpec, card_id: u32, preview_id: u32, selected: bool) GalleryError!void {
    if (gallery_text_clip_top) |clip_top| {
        if (bounds.y < clip_top) return;
    }
    const is_hovered = hovered(bounds);
    try scene.pushRect(bounds.insetUniform(-1), if (is_hovered) palette.shadow_hover else palette.shadow, .shadow, card_radius, if (is_hovered) card_hover_shadow else card_shadow);
    try fill(scene, bounds, if (is_hovered) palette.panel_hover else palette.panel, card_radius);
    try stroke(scene, bounds, if (selected) palette.accent else if (is_hovered) palette.border_hover else palette.border, card_radius);
    try collector.addHit(bounds, .button, card_id);

    const inset = bounds.insetUniform(catalog_card_pad);
    try text(scene, inset.x, inset.y, inset.w - catalog_source_w, title_text_height, entry.name, palette.text);
    try catalogSource(scene, ui.Rect.init(inset.x + inset.w - catalog_source_w, inset.y - 1, catalog_source_w, 24), selected);
    try text(scene, inset.x, inset.y + 28, inset.w, body_text_height, entry.category.label(), palette.muted);
    try text(scene, inset.x, inset.y + 48, inset.w, body_text_height, entry.edge_builder, palette.muted);

    try renderReferencePreview(scene, collector, ui.Rect.init(inset.x, inset.y + 76, inset.w, catalog_preview_h), entry, preview_id);
}

fn catalogSource(scene: *ui.Scene, bounds: ui.Rect, selected: bool) GalleryError!void {
    const color = if (selected) palette.green else palette.accent;
    try fill(scene, bounds, palette.panel_alt, 6);
    try stroke(scene, bounds, color, 6);
    try centeredText(scene, bounds, if (selected) "selected" else "base-nova", color);
}

fn renderReferencePreview(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, spec_value: ComponentSpec, id: u32) GalleryError!void {
    return switch (spec_value.preview) {
        .accordion => previewAccordion(scene, collector, bounds, id),
        .alert => previewAlert(scene, bounds, false),
        .alert_dialog => previewDialogSurface(scene, collector, bounds, id, true),
        .aspect_ratio => previewAspectRatio(scene, bounds),
        .avatar,
        .badge,
        .card,
        .checkbox,
        .input,
        .item,
        .kbd,
        .progress,
        .select,
        .separator,
        .slider,
        .switch_control,
        .textarea,
        => renderPrimitivePreview(scene, collector, bounds, spec_value.preview, id),
        .breadcrumb => previewBreadcrumb(scene, collector, bounds, id),
        .button => previewButtonVariants(scene, collector, bounds, id),
        .button_group => previewButtonGroup(scene, collector, bounds, id),
        .calendar => previewCalendarMini(scene, collector, bounds, id),
        .carousel => previewCarousel(scene, collector, bounds, id),
        .chart => previewChartMini(scene, collector, bounds, id),
        .combobox => previewCombobox(scene, collector, bounds, id),
        .command => previewCommand(scene, collector, bounds, id),
        .context_menu => previewMenu(scene, collector, bounds, id, "Context"),
        .data_table, .table => previewTable(scene, collector, bounds, id),
        .date_picker => previewDatePicker(scene, collector, bounds, id),
        .dialog => previewDialogSurface(scene, collector, bounds, id, false),
        .direction => previewDirection(scene, bounds),
        .drawer => previewDrawer(scene, collector, bounds, id),
        .dropdown_menu => previewMenu(scene, collector, bounds, id, "Open"),
        .empty => previewEmpty(scene, collector, bounds, id),
        .field => previewField(scene, collector, bounds, id),
        .hover_card => previewHoverCard(scene, collector, bounds, id),
        .input_group => previewInputGroup(scene, collector, bounds, id),
        .input_otp => previewOtp(scene, collector, bounds, id),
        .label => previewLabel(scene, bounds),
        .menubar => previewMenubar(scene, collector, bounds, id),
        .native_select => previewSelect(scene, collector, bounds, id, "Native"),
        .navigation_menu => previewNavigationMenu(scene, collector, bounds, id),
        .pagination => previewPagination(scene, collector, bounds, id),
        .popover => previewPopover(scene, collector, bounds, id),
        .radio_group => previewRadioGroup(scene, collector, bounds, id),
        .resizable => previewResizable(scene, collector, bounds, id),
        .scroll_area => previewScrollArea(scene, bounds),
        .sheet => previewSheet(scene, collector, bounds, id),
        .sidebar => previewSidebar(scene, collector, bounds, id),
        .skeleton => previewSkeletonBars(scene, bounds),
        .sonner => previewToast(scene, collector, bounds, id, "Saved"),
        .tabs => previewTabs(scene, collector, bounds, id),
        .toast => previewToast(scene, collector, bounds, id, "Queued"),
        .toggle => previewToggle(scene, collector, bounds, id),
        .toggle_group => previewToggleGroup(scene, collector, bounds, id),
        .tooltip => previewTooltip(scene, collector, bounds, id),
    };
}

const PrimitivePreview = struct {
    component: components.Component,
    options: components.RenderOptions = .{},
};

fn renderPrimitivePreview(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, kind: PreviewKind, id: u32) GalleryError!void {
    const preview = primitivePreview(kind, id);
    try renderComponentPreview(scene, collector, bounds, preview.component, preview.options);
}

fn primitivePreview(kind: PreviewKind, id: u32) PrimitivePreview {
    return switch (kind) {
        .avatar => .{ .component = .{ .avatar = .{ .label = "ER" } } },
        .badge => .{ .component = .{ .badge = .{ .label = "Default" } } },
        .button => .{ .component = .{ .button = .{ .id = id, .label = "Default" } } },
        .card => .{ .component = .{ .card = .{ .title = "Card title", .detail = "Description" } } },
        .checkbox => .{ .component = .{ .checkbox = .{ .id = id, .label = "Accept terms", .checked = true } } },
        .input => .{ .component = .{ .input = .{ .id = id, .placeholder = "Email" } } },
        .item => .{ .component = .{ .row_item = .{ .id = id, .title = "Item title", .detail = "Description" } } },
        .kbd => .{ .component = .{ .kbd = .{ .label = "Cmd K" } } },
        .progress => .{ .component = .{ .progress = .{ .value = 0.62 } } },
        .select => .{ .component = .{ .select = .{ .id = id, .label = "Select" } } },
        .separator => .{ .component = .{ .separator = .{} } },
        .slider => .{ .component = .{ .slider = .{ .id = id, .label = "Volume", .value = 0.68 } } },
        .switch_control => .{ .component = .{ .switch_control = .{ .id = id, .label = "Airplane Mode", .checked = true } } },
        .textarea => .{ .component = .{ .textarea = .{ .id = id, .placeholder = "Type your message here." } } },
        else => unreachable,
    };
}

fn renderComponentPreview(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, component: components.Component, options: components.RenderOptions) GalleryError!void {
    var resolved = options;
    resolved.style = componentStyle();
    try component.render(scene, bounds, resolved);
    try component.collectInteractions(collector, bounds);
}

fn componentStyle() ui.Style {
    return .{
        .bg = palette.bg,
        .panel = palette.panel_alt,
        .row = palette.row,
        .border = palette.border,
        .text = palette.text,
        .muted = palette.muted,
        .accent = palette.accent,
    };
}

fn previewAccordion(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    const row_h = bounds.h * 0.48;
    const top = ui.Rect.init(bounds.x, bounds.y, bounds.w, row_h);
    const bottom = ui.Rect.init(bounds.x, bounds.y + row_h + 2, bounds.w, @max(1, bounds.h - row_h - 2));
    try text(scene, top.x, top.y + 4, top.w - 20, 14, "Is it accessible?", palette.text);
    try iconQuad(scene, ui.Rect.init(top.x + top.w - 16, top.y + 5, 14, 14), .chevron_right, palette.muted);
    try stroke(scene, ui.Rect.init(bottom.x, top.y + top.h, bottom.w, 1), palette.border, 0);
    try text(scene, bottom.x, bottom.y + 3, bottom.w, 13, "Yes. It follows the pattern.", palette.muted);
    try collector.addHit(top, .button, id);
}

fn previewAlert(scene: *ui.Scene, bounds: ui.Rect, destructive: bool) GalleryError!void {
    const color = if (destructive) palette.danger else palette.text;
    try fill(scene, bounds, palette.panel_alt, 8);
    try stroke(scene, bounds, if (destructive) palette.danger else palette.border, 8);
    try iconQuad(scene, ui.Rect.init(bounds.x + 8, bounds.y + 10, 16, 16), .shield, color);
    try text(scene, bounds.x + 30, bounds.y + 6, bounds.w - 38, 14, "Heads up", color);
    try text(scene, bounds.x + 30, bounds.y + 22, bounds.w - 38, 12, "Status message", palette.muted);
}

fn previewDialogSurface(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32, destructive: bool) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 3, 66, 30), if (destructive) "Delete" else "Open", id, false);
    const popup = ui.Rect.init(bounds.x + 78, bounds.y, @max(92, bounds.w - 78), bounds.h);
    try fill(scene, popup, palette.panel_alt, 10);
    try stroke(scene, popup, palette.border, 10);
    try text(scene, popup.x + 10, popup.y + 6, popup.w - 20, 14, if (destructive) "Are you sure?" else "Edit profile", palette.text);
    try text(scene, popup.x + 10, popup.y + 22, popup.w - 20, 12, "Modal content", palette.muted);
    try collector.addHit(popup, .button, id + 1);
}

fn previewAspectRatio(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    const frame_w = @min(bounds.w, bounds.h * 16.0 / 9.0);
    const frame = ui.Rect.init(bounds.x, bounds.y, frame_w, bounds.h);
    try fill(scene, frame, palette.row, 6);
    try stroke(scene, frame, palette.border, 6);
}

fn previewBreadcrumb(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(bounds, .row, 5);
    const labels = [_][]const u8{ "Home", "/", "Docs", "/", "Button" };
    for (labels, 0..) |label, index| {
        const w: f32 = if (std.mem.eql(u8, label, "/")) 8 else @as(f32, @floatFromInt(label.len)) * 7.0 + 4.0;
        const item = cursor.take(w);
        try text(scene, item.x, item.y + 11, item.w, 13, label, if (index == labels.len - 1) palette.text else palette.muted);
        if (!std.mem.eql(u8, label, "/")) try collector.addHit(item, .button, id + @as(u32, @intCast(index)));
    }
}

fn previewButtonVariants(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(bounds, .row, 6);
    try renderComponentPreview(scene, collector, cursor.take(70), .{ .button = .{ .id = id, .label = "Default" } }, .{});
    try renderComponentPreview(scene, collector, cursor.take(76), .{ .button = .{ .id = id + 1, .label = "Second" } }, .{ .button_variant = .secondary });
    try renderComponentPreview(scene, collector, cursor.take(54), .{ .button = .{ .id = id + 2, .label = "Link" } }, .{ .button_variant = .link });
}

fn previewButtonGroup(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    const item_w: f32 = @min(50, bounds.w / 3.0);
    var cursor = ui.LinearCursor.init(ui.Rect.init(bounds.x, bounds.y + 4, item_w * 3.0, 30), .row, 0);
    const labels = [_][]const u8{ "Left", "Mid", "Right" };
    for (labels, 0..) |label, index| {
        const item = cursor.take(item_w);
        try fill(scene, item, if (index == 1) palette.text else palette.panel_alt, 0);
        try stroke(scene, item, palette.border, 0);
        try centeredText(scene, item, label, if (index == 1) palette.panel else palette.text);
        try collector.addHit(item, .button, id + @as(u32, @intCast(index)));
    }
}

fn previewCalendarMini(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    const cell = @min(18, (bounds.w - 12) / 7.0);
    for (0..2) |row| {
        for (0..7) |col| {
            const day = row * 7 + col;
            const r = ui.Rect.init(bounds.x + @as(f32, @floatFromInt(col)) * (cell + 2), bounds.y + @as(f32, @floatFromInt(row)) * (cell + 2), cell, cell);
            try fill(scene, r, if (day == 9) palette.accent else palette.row, 5);
            try collector.addHit(r, .button, id + @as(u32, @intCast(day)));
        }
    }
}

fn previewCarousel(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    const side: f32 = 26;
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 6, side, side), "<", id, false);
    try fill(scene, ui.Rect.init(bounds.x + side + 8, bounds.y, @max(1, bounds.w - side * 2 - 16), bounds.h), palette.row, 8);
    try button(scene, collector, ui.Rect.init(bounds.x + bounds.w - side, bounds.y + 6, side, side), ">", id + 1, false);
}

fn previewChartMini(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    const values = [_]f32{ 0.45, 0.72, 0.38, 0.86, 0.62 };
    const gap: f32 = 5;
    const bar_w = @min(18, (bounds.w - gap * 4.0) / 5.0);
    for (values, 0..) |value, index| {
        const h = bounds.h * value;
        const bar = ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * (bar_w + gap), bounds.y + bounds.h - h, bar_w, h);
        try fill(scene, bar, if (index == values.len - 1) palette.accent else palette.row, 5);
        try collector.addHit(bar, .button, id + @as(u32, @intCast(index)));
    }
}

fn previewCombobox(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try previewInput(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, 30), id, "Search framework...");
    const menu_bounds = ui.Rect.init(bounds.x, bounds.y + 28, @min(bounds.w, 122), 10);
    try fill(scene, menu_bounds, palette.panel_alt, 5);
}

fn previewCommand(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, 8);
    try stroke(scene, bounds, palette.border, 8);
    try iconQuad(scene, ui.Rect.init(bounds.x + 8, bounds.y + 11, 14, 14), .search, palette.muted);
    try text(scene, bounds.x + 28, bounds.y + 10, bounds.w - 36, 13, "Type a command...", palette.muted);
    try collector.addHit(bounds, .input, id);
}

fn previewMenu(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32, label: []const u8) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 4, 64, 30), label, id, false);
    const menu_bounds = ui.Rect.init(bounds.x + 72, bounds.y, @max(88, bounds.w - 72), bounds.h);
    try fill(scene, menu_bounds, palette.panel_alt, 8);
    try menuRow(scene, collector, ui.Rect.init(menu_bounds.x + 5, menu_bounds.y + 4, menu_bounds.w - 10, 14), "Profile", id + 1);
    try menuRow(scene, collector, ui.Rect.init(menu_bounds.x + 5, menu_bounds.y + 20, menu_bounds.w - 10, 14), "Settings", id + 2);
}

fn previewTable(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, 6);
    try text(scene, bounds.x + 8, bounds.y + 4, bounds.w * 0.5, 12, "Name", palette.muted);
    try alignedText(scene, bounds.x + bounds.w * 0.55, bounds.y + 4, bounds.w * 0.38, 12, "Role", palette.muted, .end);
    try menuRow(scene, collector, ui.Rect.init(bounds.x + 4, bounds.y + 18, bounds.w - 8, 14), "Sarah Chen", id);
}

fn previewDatePicker(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try previewInput(scene, collector, bounds, id, "May 25, 2026");
}

fn previewDirection(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    var no_regions: [0]interaction.Region = .{};
    var collector = interaction.Collector.init(&no_regions);
    try renderComponentPreview(scene, &collector, ui.Rect.init(bounds.x, bounds.y + 8, 42, 20), .{ .badge = .{ .label = "LTR" } }, .{ .badge_variant = .default });
    try iconQuad(scene, ui.Rect.init(bounds.x + 54, bounds.y + 11, 18, 18), .route, palette.muted);
    try renderComponentPreview(scene, &collector, ui.Rect.init(bounds.x + 84, bounds.y + 8, 42, 20), .{ .badge = .{ .label = "RTL" } }, .{ .badge_variant = .secondary });
}

fn previewDrawer(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 4, 56, 30), "Open", id, false);
    const sheet_bounds = ui.Rect.init(bounds.x + bounds.w - 72, bounds.y, 72, bounds.h);
    try fill(scene, sheet_bounds, palette.panel_alt, 8);
    try stroke(scene, sheet_bounds, palette.border, 8);
}

fn previewEmpty(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try iconQuad(scene, ui.Rect.init(bounds.x + bounds.w * 0.5 - 8, bounds.y + 2, 16, 16), .storage, palette.muted);
    try alignedText(scene, bounds.x, bounds.y + 20, bounds.w, 12, "No results found", palette.text, .center);
    try collector.addHit(bounds, .button, id);
}

fn previewField(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 12, "Email", palette.text);
    try previewInput(scene, collector, ui.Rect.init(bounds.x, bounds.y + 14, bounds.w, 24), id, "m@example.com");
}

fn previewHoverCard(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 4, 64, 30), "Hover", id, false);
    try fill(scene, ui.Rect.init(bounds.x + 76, bounds.y, @max(80, bounds.w - 76), bounds.h), palette.panel_alt, 8);
    try text(scene, bounds.x + 86, bounds.y + 10, @max(1, bounds.w - 96), 14, "@shadcn", palette.text);
}

fn previewInput(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32, placeholder: []const u8) GalleryError!void {
    try renderComponentPreview(scene, collector, bounds, .{ .input = .{ .id = id, .placeholder = placeholder } }, .{});
}

fn previewInputGroup(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 4, 32, 30), "@", id, false);
    try previewInput(scene, collector, ui.Rect.init(bounds.x + 32, bounds.y + 4, @max(1, bounds.w - 32), 30), id + 1, "username");
}

fn previewOtp(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(bounds, .row, 5);
    for (0..6) |index| {
        const cell = cursor.take(28);
        try fill(scene, cell, palette.panel_alt, 6);
        try stroke(scene, cell, palette.border, 6);
        try collector.addHit(cell, .input, id + @as(u32, @intCast(index)));
    }
}

fn previewLabel(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    try text(scene, bounds.x, bounds.y + 10, bounds.w, 14, "Email address", palette.text);
}

fn previewMenubar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(bounds, .row, 4);
    const labels = [_][]const u8{ "File", "Edit", "View" };
    for (labels, 0..) |label, index| try button(scene, collector, cursor.take(48), label, id + @as(u32, @intCast(index)), false);
}

fn previewSelect(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32, label: []const u8) GalleryError!void {
    try renderComponentPreview(scene, collector, bounds, .{ .select = .{ .id = id, .label = label } }, .{});
}

fn previewNavigationMenu(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(bounds, .row, 4);
    const labels = [_][]const u8{ "Docs", "Components", "Blocks" };
    for (labels, 0..) |label, index| try ghostButton(scene, collector, cursor.take(if (index == 1) 88 else 52), label, id + @as(u32, @intCast(index)));
}

fn previewPagination(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(bounds, .row, 5);
    const labels = [_][]const u8{ "<", "1", "2", "3", ">" };
    for (labels, 0..) |label, index| try button(scene, collector, cursor.take(28), label, id + @as(u32, @intCast(index)), index == 2);
}

fn previewPopover(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 4, 64, 30), "Open", id, false);
    try fill(scene, ui.Rect.init(bounds.x + 74, bounds.y, @max(72, bounds.w - 74), bounds.h), palette.panel_alt, 8);
}

fn previewRadioGroup(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try radioRow(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, 18), "Default", true, id);
    try radioRow(scene, collector, ui.Rect.init(bounds.x, bounds.y + 20, bounds.w, 18), "Comfortable", false, id + 1);
}

fn previewResizable(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    const left = ui.Rect.init(bounds.x, bounds.y, bounds.w * 0.58, bounds.h);
    const grip = ui.Rect.init(left.x + left.w + 3, bounds.y, 4, bounds.h);
    try fill(scene, left, palette.row, 6);
    try fill(scene, grip, palette.accent, 2);
    try fill(scene, ui.Rect.init(grip.x + 7, bounds.y, @max(1, bounds.w - left.w - 10), bounds.h), palette.panel_alt, 6);
    try collector.addHit(grip.insetUniform(-6), .slider, id);
}

fn previewScrollArea(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, 7);
    try text(scene, bounds.x + 8, bounds.y + 6, bounds.w - 20, 12, "Scrollable content", palette.text);
    try fill(scene, ui.Rect.init(bounds.x + bounds.w - 6, bounds.y + 5, 3, bounds.h - 10), palette.row, 2);
}

fn previewSheet(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try previewDrawer(scene, collector, bounds, id);
}

fn previewSidebar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    const rail = ui.Rect.init(bounds.x, bounds.y, 52, bounds.h);
    try fill(scene, rail, palette.panel_alt, 8);
    try menuRow(scene, collector, ui.Rect.init(rail.x + 5, rail.y + 5, rail.w - 10, 12), "Nav", id);
    try fill(scene, ui.Rect.init(bounds.x + 62, bounds.y, @max(1, bounds.w - 62), bounds.h), palette.row, 8);
}

fn previewSkeletonBars(scene: *ui.Scene, bounds: ui.Rect) GalleryError!void {
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + 4, bounds.w * 0.72, 8), palette.row, 4);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + 18, bounds.w, 8), palette.row, 4);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + 32, bounds.w * 0.48, 6), palette.row, 3);
}

fn previewTabs(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(ui.Rect.init(bounds.x, bounds.y + 3, @min(bounds.w, 170), 30), .row, 3);
    const labels = [_][]const u8{ "Account", "Password" };
    for (labels, 0..) |label, index| try tabButton(scene, collector, cursor.take(if (index == 0) 76 else 88), label, id + @as(u32, @intCast(index)), index == 0);
}

fn previewToast(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32, label: []const u8) GalleryError!void {
    try fill(scene, bounds, palette.panel_alt, 8);
    try stroke(scene, bounds, palette.border, 8);
    try text(scene, bounds.x + 10, bounds.y + 7, bounds.w - 20, 14, label, palette.text);
    try text(scene, bounds.x + 10, bounds.y + 23, bounds.w - 20, 12, "Notification", palette.muted);
    try collector.addHit(bounds, .button, id);
}

fn previewToggle(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 4, 64, 30), "Bold", id, false);
    try fill(scene, ui.Rect.init(bounds.x + 74, bounds.y + 4, 64, 30), palette.row, 8);
    try centeredText(scene, ui.Rect.init(bounds.x + 74, bounds.y + 4, 64, 30), "Italic", palette.text);
    try collector.addHit(ui.Rect.init(bounds.x + 74, bounds.y + 4, 64, 30), .button, id + 1);
}

fn previewToggleGroup(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = ui.LinearCursor.init(bounds, .row, 2);
    const labels = [_][]const u8{ "Left", "Center", "Right" };
    for (labels, 0..) |label, index| try button(scene, collector, cursor.take(if (index == 1) 64 else 48), label, id + @as(u32, @intCast(index)), index == 1);
}

fn previewTooltip(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, id: u32) GalleryError!void {
    try button(scene, collector, ui.Rect.init(bounds.x, bounds.y + 8, 80, 28), "Hover me", id, false);
    const tip = ui.Rect.init(bounds.x + 90, bounds.y + 7, @max(82, bounds.w - 90), 24);
    try fill(scene, tip, palette.text, 6);
    try centeredText(scene, tip, "Add to library", palette.bg);
}

fn menuRow(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32) GalleryError!void {
    try fill(scene, bounds, if (hovered(bounds)) palette.row_hover else palette.row, 4);
    try text(scene, bounds.x + 5, bounds.y + 1, bounds.w - 10, 12, label, palette.text);
    try collector.addHit(bounds, .row_item, id);
}

fn radioRow(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, selected: bool, id: u32) GalleryError!void {
    const circle = ui.Rect.init(bounds.x, bounds.y + 2, 14, 14);
    try fill(scene, circle, if (selected) palette.text else palette.panel, 7);
    try stroke(scene, circle, if (selected) palette.text else palette.border, 7);
    if (selected) try fill(scene, circle.insetUniform(5), palette.panel, 2);
    try text(scene, bounds.x + 22, bounds.y + 1, bounds.w - 22, 13, label, palette.text);
    try collector.addHit(bounds, .checkbox, id);
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

fn wrappedText(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, line_height: f32, average_char_width: f32, max_lines: usize) GalleryError!void {
    if (gallery_text_clip_top) |clip_top| {
        if (bounds.y < clip_top) return;
    }
    try scene.pushWrappedText(bounds, value, color, .{
        .line_height = line_height,
        .average_char_width = average_char_width,
        .max_lines = max_lines,
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

test "component gallery catalog is the authoritative component registry" {
    try std.testing.expectEqual(@as(usize, 57), component_catalog.len);
    try std.testing.expectEqualStrings("/docs/components/input-group", findBySlug("input-group").?.route);
    try std.testing.expectEqualStrings("Button", findBySourceComponent("Button").?.source_component);
    try std.testing.expectEqual(@as(usize, 7), indexBySlug("button").?);
    try std.testing.expectEqual(@as(usize, 7), indexByCatalogHit(first_catalog_card_id + 7).?);
    try std.testing.expectEqual(Category.foundation, findBySlug("button").?.category);
    try std.testing.expectEqual(@as(usize, 15), countByCategory(.form));
    try std.testing.expectEqual(@as(usize, 6), countByCategory(.layout));
}

test "component gallery catalog entries render reference previews without proxy components" {
    var commands: [2048]ui.Command = undefined;
    var regions: [256]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    var rendered: usize = 0;

    for (component_catalog, 0..) |entry, index| {
        const y = @as(f32, @floatFromInt(rendered)) * 48.0;
        const bounds = ui.Rect.init(0, y, 220, 36);
        try renderReferencePreview(&scene, &collector, bounds, entry, preview_base_id + @as(u32, @intCast(index)));
        rendered += 1;
    }

    try std.testing.expectEqual(component_catalog.len, rendered);
    try std.testing.expect(scene.written().len > component_catalog.len);
    try std.testing.expect(collector.written().len > 40);
    try std.testing.expect(hasHit(collector.written(), preview_base_id + 7));
    try std.testing.expect(hasText(scene.written(), "Is it accessible?"));
    try std.testing.expect(hasText(scene.written(), "Edit profile"));
    try std.testing.expect(hasText(scene.written(), "Account"));
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
    try std.testing.expect(hasText(scene.written(), "Component Catalog"));
    try std.testing.expect(hasText(scene.written(), "Accordion"));
    try std.testing.expect(hasText(scene.written(), "Tooltip"));
}

test "component gallery selected route renders selected component panel" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    const index = indexBySlug("button").?;
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 1440, 940), .{ .selected_component_index = index });

    try std.testing.expect(hasText(scene.written(), "/docs/components/button"));
    try std.testing.expect(hasText(scene.written(), "button"));
    try std.testing.expect(hasHit(collector.written(), preview_base_id + 7000 + @as(u32, @intCast(index)) * 32));
    try std.testing.expect(contentHeightForState(1440, .{ .selected_component_index = index }) > contentHeight(1440));
}

test "component gallery derives responsive catalog columns" {
    try std.testing.expectEqual(@as(usize, 1), galleryColumnCount(335, 24));
    try std.testing.expectEqual(@as(usize, 2), galleryColumnCount(696, 24));
    try std.testing.expectEqual(@as(usize, 5), galleryColumnCount(1660, 40));
}

test "component gallery scrolls through later catalog cards" {
    var commands: [4096]ui.Command = undefined;
    var regions: [512]interaction.Region = undefined;
    var scene = ui.Scene.init(&commands);
    var collector = interaction.Collector.init(&regions);
    try renderComponentGallery(&scene, &collector, ui.Rect.init(0, 0, 900, 720), .{ .scroll_y = 4096 });

    try std.testing.expect(hasText(scene.written(), "Table"));
    try std.testing.expect(hasText(scene.written(), "Tooltip"));
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
    try renderComponentGallery(&hover_scene, &hover_collector, ui.Rect.init(0, 0, 1440, 940), .{ .hover_x = 260, .hover_y = 210 });

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

fn textCommand(commands: []const ui.Command, value: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return .{ .text = text_command },
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
