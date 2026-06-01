const std = @import("std");
const math = @import("../math.zig");
const bytes = @import("../bytes.zig");
const clock = @import("../clock.zig");
const component_union = @import("components/Component.zig");
const component_common = @import("component_common.zig");
const component_test = @import("components/TestSupport.zig");
const ui = @import("core.zig");
const interaction = @import("interaction.zig");
const design = @import("theme.zig");
const app_chrome = @import("chrome.zig");
const app_layout = @import("layout.zig");

pub const GalleryError = ui.RenderError || interaction.Error || component_union.Error || error{NoSpace};

pub const preview_base_id: u32 = 18_000;
pub const first_catalog_card_id: u32 = preview_base_id + 2000;
const catalog_preview_id_base: u32 = preview_base_id + 5000;
const selected_preview_id_base: u32 = preview_base_id + 7000;
const preview_id_stride: u32 = 32;
const header_h: f32 = app_chrome.header_h;
const page_top_pad: f32 = 48;
const page_bottom_pad: f32 = 120;
const card_content_x: f32 = 18;
const card_header_y: f32 = 18;
const card_detail_y: f32 = 42;
const card_body_top: f32 = 78;
const card_body_bottom: f32 = 18;
const text_char_w: f32 = design.Type.average_body_w;
const compact_text_height: f32 = 14;
const body_text_height: f32 = design.Type.body_h;
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
const catalog_source_min_w: f32 = 82;
const canonical_ui_buffer_size: usize = 2048;
const canonical_object_buffer_size: usize = 4096;
const selected_component_h: f32 = 500;
const selected_component_compact_h: f32 = 820;
const selected_component_gap: f32 = 32;
const selected_preview_surface_h: f32 = 266;
const selected_preview_compact_surface_h: f32 = 320;
const api_label_h: f32 = 14;
const api_value_line_h: f32 = 16;
const api_value_avg_w: f32 = 7.8;
const api_value_max_lines: usize = 2;
pub const grid_gap_compact: f32 = 28;
pub const grid_gap_default: f32 = 40;
pub const grid_gap_wide: f32 = 56;
var gallery_text_clip_top: ?f32 = null;
var gallery_hover_point: ?HoverPoint = null;
var gallery_drag_override: ?DragOverride = null;

const HoverPoint = struct {
    x: f32,
    y: f32,
};

pub const DragOverride = struct {
    id: u32,
    value: f32,
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
    component_path: []const u8,
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
    icon,
    icon_button,
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
    spinner,
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

const catalog_eval_branch_quota: u32 = component_path_count * component_path_count * 2;

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
        componentSpec("Icon", "icon", .foundation, "Icon", "icon_node", .icon),
        componentSpec("Icon Button", "icon-button", .foundation, "IconButton", "icon_button_node", .icon_button),
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
        componentSpec("Spinner", "spinner", .feedback, "Spinner", "spinner_node", .spinner),
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
        .component_path = componentPathFor(slug),
        .category = category,
        .source_component = source_component,
        .edge_builder = edge_builder,
        .preview = preview,
    };
}

pub fn findBySlug(slug: []const u8) ?*const ComponentSpec {
    for (&component_catalog) |*entry| {
        if (bytes.eql(entry.slug, slug)) return entry;
    }
    return null;
}

pub fn findBySourceComponent(source_component: []const u8) ?*const ComponentSpec {
    for (&component_catalog) |*entry| {
        if (bytes.eql(entry.source_component, source_component)) return entry;
    }
    return null;
}

pub fn indexBySlug(slug: []const u8) ?usize {
    for (component_catalog, 0..) |entry, index| {
        if (bytes.eql(entry.slug, slug)) return index;
    }
    return null;
}

pub fn indexByCatalogHit(hit_id: u32) ?usize {
    if (hit_id < first_catalog_card_id) return null;
    const index: usize = @intCast(hit_id - first_catalog_card_id);
    return if (index < component_catalog.len) index else null;
}

pub fn indexByPreviewHit(hit_id: u32) ?usize {
    return indexByPreviewIdBase(hit_id, catalog_preview_id_base) orelse indexByPreviewIdBase(hit_id, selected_preview_id_base);
}

pub fn previewHitForIndexForTest(index: usize) u32 {
    return catalog_preview_id_base + @as(u32, @intCast(index)) * preview_id_stride;
}

pub fn sourcePathForIndex(index: usize, out: []u8) ?[]const u8 {
    if (index >= component_catalog.len) return null;
    return std.fmt.bufPrint(out, "src/ui/components/{s}.zig", .{component_catalog[index].source_component}) catch null;
}

fn indexByPreviewIdBase(hit_id: u32, base: u32) ?usize {
    if (hit_id < base) return null;
    const relative = hit_id - base;
    const index: usize = @intCast(relative / preview_id_stride);
    if (relative % preview_id_stride >= preview_id_stride or index >= component_catalog.len) return null;
    return index;
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

fn componentPathFor(slug: []const u8) []const u8 {
    inline for (component_paths) |entry| {
        if (bytes.eql(slug, entry.slug)) return entry.component_path;
    }
    return "";
}

const ComponentPath = struct {
    slug: []const u8,
    component_path: []const u8,
};

const component_path_count: u32 = 58;

const component_paths = [_]ComponentPath{
    .{ .slug = "accordion", .component_path = "/docs/components/accordion" },
    .{ .slug = "alert", .component_path = "/docs/components/alert" },
    .{ .slug = "alert-dialog", .component_path = "/docs/components/alert-dialog" },
    .{ .slug = "aspect-ratio", .component_path = "/docs/components/aspect-ratio" },
    .{ .slug = "avatar", .component_path = "/docs/components/avatar" },
    .{ .slug = "badge", .component_path = "/docs/components/badge" },
    .{ .slug = "breadcrumb", .component_path = "/docs/components/breadcrumb" },
    .{ .slug = "button", .component_path = "/docs/components/button" },
    .{ .slug = "button-group", .component_path = "/docs/components/button-group" },
    .{ .slug = "calendar", .component_path = "/docs/components/calendar" },
    .{ .slug = "card", .component_path = "/docs/components/card" },
    .{ .slug = "carousel", .component_path = "/docs/components/carousel" },
    .{ .slug = "chart", .component_path = "/docs/components/chart" },
    .{ .slug = "checkbox", .component_path = "/docs/components/checkbox" },
    .{ .slug = "collapsible", .component_path = "/docs/components/collapsible" },
    .{ .slug = "combobox", .component_path = "/docs/components/combobox" },
    .{ .slug = "command", .component_path = "/docs/components/command" },
    .{ .slug = "context-menu", .component_path = "/docs/components/context-menu" },
    .{ .slug = "data-table", .component_path = "/docs/components/data-table" },
    .{ .slug = "date-picker", .component_path = "/docs/components/date-picker" },
    .{ .slug = "dialog", .component_path = "/docs/components/dialog" },
    .{ .slug = "direction", .component_path = "/docs/components/direction" },
    .{ .slug = "drawer", .component_path = "/docs/components/drawer" },
    .{ .slug = "dropdown-menu", .component_path = "/docs/components/dropdown-menu" },
    .{ .slug = "empty", .component_path = "/docs/components/empty" },
    .{ .slug = "field", .component_path = "/docs/components/field" },
    .{ .slug = "hover-card", .component_path = "/docs/components/hover-card" },
    .{ .slug = "icon", .component_path = "/docs/components/icon" },
    .{ .slug = "icon-button", .component_path = "/docs/components/icon-button" },
    .{ .slug = "input", .component_path = "/docs/components/input" },
    .{ .slug = "input-group", .component_path = "/docs/components/input-group" },
    .{ .slug = "input-otp", .component_path = "/docs/components/input-otp" },
    .{ .slug = "item", .component_path = "/docs/components/item" },
    .{ .slug = "kbd", .component_path = "/docs/components/kbd" },
    .{ .slug = "label", .component_path = "/docs/components/label" },
    .{ .slug = "menubar", .component_path = "/docs/components/menubar" },
    .{ .slug = "native-select", .component_path = "/docs/components/native-select" },
    .{ .slug = "navigation-menu", .component_path = "/docs/components/navigation-menu" },
    .{ .slug = "pagination", .component_path = "/docs/components/pagination" },
    .{ .slug = "popover", .component_path = "/docs/components/popover" },
    .{ .slug = "progress", .component_path = "/docs/components/progress" },
    .{ .slug = "radio-group", .component_path = "/docs/components/radio-group" },
    .{ .slug = "resizable", .component_path = "/docs/components/resizable" },
    .{ .slug = "scroll-area", .component_path = "/docs/components/scroll-area" },
    .{ .slug = "select", .component_path = "/docs/components/select" },
    .{ .slug = "separator", .component_path = "/docs/components/separator" },
    .{ .slug = "sheet", .component_path = "/docs/components/sheet" },
    .{ .slug = "sidebar", .component_path = "/docs/components/sidebar" },
    .{ .slug = "skeleton", .component_path = "/docs/components/skeleton" },
    .{ .slug = "spinner", .component_path = "/docs/components/spinner" },
    .{ .slug = "slider", .component_path = "/docs/components/slider" },
    .{ .slug = "sonner", .component_path = "/docs/components/sonner" },
    .{ .slug = "switch", .component_path = "/docs/components/switch" },
    .{ .slug = "table", .component_path = "/docs/components/table" },
    .{ .slug = "tabs", .component_path = "/docs/components/tabs" },
    .{ .slug = "textarea", .component_path = "/docs/components/textarea" },
    .{ .slug = "toast", .component_path = "/docs/components/toast" },
    .{ .slug = "toggle", .component_path = "/docs/components/toggle" },
    .{ .slug = "toggle-group", .component_path = "/docs/components/toggle-group" },
    .{ .slug = "tooltip", .component_path = "/docs/components/tooltip" },
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
    return header_h + page_top_pad + galleryBodyHeight(layout.board.w, layout.columns, layout.gap, state.selected_component_index) + page_bottom_pad;
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

const palette = design.Palette;

pub fn renderComponentGallery(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: ComponentGalleryState) GalleryError!void {
    const previous_hover_point = gallery_hover_point;
    gallery_hover_point = if (state.hover_x >= hover_disabled_coord + 1 and state.hover_y >= hover_disabled_coord + 1)
        .{ .x = state.hover_x, .y = state.hover_y }
    else
        null;
    defer gallery_hover_point = previous_hover_point;

    const app = component_union.renderer(scene, collector, .{ .style = componentStyle() });
    try app.fill(bounds, palette.bg, 0);

    const content = app_layout.centered(bounds, design.content_wide, design.content_pad);
    const layout = galleryLayout(bounds, state);

    {
        const previous_text_clip_top = gallery_text_clip_top;
        gallery_text_clip_top = bounds.y + header_h;
        defer gallery_text_clip_top = previous_text_clip_top;

        _ = state.layout;
        const catalog_h = galleryBodyHeight(layout.board.w, layout.columns, layout.gap, state.selected_component_index);
        try renderCatalogSection(app, ui.Rect.init(layout.board.x, layout.board.y, layout.board.w, catalog_h), layout.columns, layout.gap, state.selected_component_index);
    }

    try app_chrome.renderHeaderView(app, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content);
}

const GalleryLayout = struct {
    board: ui.Rect,
    gap: f32,
    columns: usize,
    card_w: f32,
};

fn galleryLayout(bounds: ui.Rect, state: ComponentGalleryState) GalleryLayout {
    const content = app_layout.centered(bounds, design.content_wide, design.content_pad);
    const scroll_y = math.clampF(state.scroll_y, 0.0, 4096.0);
    const gap = normalizedGridGap(state.grid_gap);
    const board = ui.Rect.init(content.x, bounds.y + header_h + page_top_pad - scroll_y, content.w, @max(240, bounds.h - header_h - page_top_pad + scroll_y));
    const columns = galleryColumnCount(board.w, gap);
    const card_w = (board.w - gap * @as(f32, @floatFromInt(columns - 1))) / @as(f32, @floatFromInt(columns));
    return .{ .board = board, .gap = gap, .columns = columns, .card_w = card_w };
}

fn catalogSectionHeight(columns: usize, gap: f32) f32 {
    const rows = (component_catalog.len + columns - 1) / columns;
    return catalog_intro_h + @as(f32, @floatFromInt(rows)) * catalog_card_h + @as(f32, @floatFromInt(rows - 1)) * gap;
}

fn galleryBodyHeight(width: f32, columns: usize, gap: f32, selected_index: ?usize) f32 {
    const selected_h = if (selectedComponent(selected_index) != null) selectedComponentHeight(width) + selected_component_gap else 0.0;
    return selected_h + catalogSectionHeight(columns, gap);
}

fn renderCatalogSection(app: component_union.View, bounds: ui.Rect, columns: usize, gap: f32, selected_index: ?usize) GalleryError!void {
    var stack = app.column(bounds, 0.0);
    if (selectedComponent(selected_index)) |entry| {
        const selected_h = selectedComponentHeight(bounds.w);
        try renderSelectedComponent(app, stack.take(selected_h), entry, selected_index.?);
        stack.skip(selected_component_gap);
    }

    const intro = stack.take(catalog_intro_h);
    try clippedText(app, ui.Rect.init(intro.x, intro.y, intro.w, 22), "Component Catalog", palette.text);
    try clippedWrappedText(app, ui.Rect.init(intro.x, intro.y + 32, intro.w, 42), "Every public component starts here. Cards, previews, and opened component pages use the shared component system used by web host, CPU, and GPU hosts.", palette.muted, 18, 9.4, 2);

    const grid = app.grid(stack.remaining(), columns, gap, catalog_card_h);
    for (component_catalog, 0..) |entry, index| {
        const card_bounds = grid.item(index);
        const card_id = first_catalog_card_id + @as(u32, @intCast(index));
        const preview_id = catalog_preview_id_base + @as(u32, @intCast(index)) * preview_id_stride;
        try renderCatalogCard(app, card_bounds, entry, card_id, preview_id, selected_index == index);
    }
}

pub fn docsContentHeight(width: f32, selected_index: ?usize) f32 {
    const gap = grid_gap_default;
    const columns = galleryColumnCount(width, gap);
    const selected_h: f32 = if (selectedComponent(selected_index) != null) selectedComponentHeight(width) + selected_component_gap else 0.0;
    return selected_h + catalogSectionHeight(columns, gap);
}

pub fn renderDocsContent(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, selected_index: ?usize, hover_x: f32, hover_y: f32, drag_override: ?DragOverride) GalleryError!void {
    const previous_hover_point = gallery_hover_point;
    gallery_hover_point = if (hover_x >= hover_disabled_coord + 1 and hover_y >= hover_disabled_coord + 1)
        .{ .x = hover_x, .y = hover_y }
    else
        null;
    defer gallery_hover_point = previous_hover_point;

    const previous_drag = gallery_drag_override;
    gallery_drag_override = drag_override;
    defer gallery_drag_override = previous_drag;

    const gap = grid_gap_default;
    const columns = galleryColumnCount(bounds.w, gap);
    const app = component_union.renderer(scene, collector, .{ .style = componentStyle() });
    try renderCatalogSection(app, bounds, columns, gap, selected_index);
}

fn selectedComponent(selected_index: ?usize) ?ComponentSpec {
    const index = selected_index orelse return null;
    if (index >= component_catalog.len) return null;
    return component_catalog[index];
}

fn selectedComponentHeight(width_value: f32) f32 {
    return if (width_value < 760.0) selected_component_compact_h else selected_component_h;
}

fn renderSelectedComponent(app: component_union.View, bounds: ui.Rect, entry: ComponentSpec, index: usize) GalleryError!void {
    const selected_app = app.withMergedControl(.{ .active = true });
    try selected_app.elevatedAt(bounds, "", "");

    const inset = bounds.insetUniform(18);
    try catalogSource(app, sourceBadgeBounds(inset, true), true);
    if (inset.w < 720.0) {
        try clippedText(app, ui.Rect.init(inset.x, inset.y + 38, inset.w, 26), entry.name, palette.text);
        try clippedWrappedText(app, ui.Rect.init(inset.x, inset.y + 76, inset.w, 54), "This component page is generated from the shared catalog entry and renders the real component preview beside its API surface.", palette.muted, 18, 8.8, 3);
        try renderOpenedComponentRenderings(app, ui.Rect.init(inset.x, inset.y + 148, inset.w, selected_preview_compact_surface_h), entry, selected_preview_id_base + @as(u32, @intCast(index)) * preview_id_stride);
        try renderComponentApi(app, ui.Rect.init(inset.x, inset.y + 490, inset.w, 210), entry);
        try renderComponentContract(app, ui.Rect.init(inset.x, inset.y + 718, inset.w, 64), entry);
    } else {
        const split = app.splitLeft(inset, inset.w * 0.42, inset.w * 0.06);
        try clippedText(app, ui.Rect.init(split.first.x, split.first.y + 38, split.first.w, 26), entry.name, palette.text);
        try clippedWrappedText(app, ui.Rect.init(split.first.x, split.first.y + 76, split.first.w, 54), "This component page is generated from the shared catalog entry and renders the real component preview beside its API surface.", palette.muted, 18, 8.8, 3);

        try renderComponentApi(app, ui.Rect.init(split.first.x, split.first.y + 154, split.first.w, inset.h - 154), entry);

        const preview_bounds = ui.Rect.init(split.second.x, split.second.y + 10, split.second.w, selected_preview_surface_h);
        try renderOpenedComponentRenderings(app, preview_bounds, entry, selected_preview_id_base + @as(u32, @intCast(index)) * preview_id_stride);
        try renderComponentContract(app, ui.Rect.init(preview_bounds.x, preview_bounds.y + selected_preview_surface_h + 22, preview_bounds.w, inset.h - selected_preview_surface_h - 32), entry);
    }
}

fn renderOpenedComponentRenderings(app: component_union.View, bounds: ui.Rect, entry: ComponentSpec, id: u32) GalleryError!void {
    var render_style = componentStyle();
    render_style.panel = palette.code_bg;
    const preview_app = app.withStyle(render_style);
    try preview_app.panelAt(bounds, "Rendered component", entry.name);

    const inner = ui.Rect.init(bounds.x + card_content_x, bounds.y + 72, bounds.w - card_content_x * 2, bounds.h - 92);
    if (inner.w < 360.0) {
        const main_h = @min(112.0, inner.h * 0.45);
        const second_h = @min(88.0, inner.h * 0.32);
        var stack = preview_app.column(inner, 14.0);
        try previewSlot(app, stack.take(main_h), "default", entry, id);
        try previewSlot(app, stack.take(second_h), "compact", entry, id + 1);
        try previewSlot(app, stack.take(second_h), "small", entry, id + 2);
    } else {
        const split = preview_app.splitLeft(inner, inner.w * 0.58, 14.0);
        try previewSlot(app, split.first, "default", entry, id);
        var side = preview_app.column(split.second, 14.0);
        try previewSlot(app, side.take((inner.h - 14.0) * 0.5), "compact", entry, id + 1);
        try previewSlot(app, side.take((inner.h - 14.0) * 0.5), "small", entry, id + 2);
    }
}

fn previewSlot(app: component_union.View, bounds: ui.Rect, label: []const u8, entry: ComponentSpec, id: u32) GalleryError!void {
    try app.subtleAt(bounds, label, "");
    try renderReferencePreview(app, bounds.insetLtrb(12.0, 32.0, 12.0, 12.0), entry, id);
}

fn renderComponentApi(app: component_union.View, bounds: ui.Rect, entry: ComponentSpec) GalleryError!void {
    var api_style = componentStyle();
    api_style.panel = palette.code_bg;
    const api_app = app.withStyle(api_style);
    try api_app.panelAt(bounds, "API", "");
    const content_w = @max(1.0, bounds.w - card_content_x * 2);
    var fields = api_app.column(ui.Rect.init(bounds.x + card_content_x, bounds.y + 50, content_w, @max(1.0, bounds.h - 50)), 12.0);
    try renderApiField(app, fields.take(apiFieldHeight(content_w, entry.component_path)), "component path", entry.component_path);
    try renderApiField(app, fields.take(apiFieldHeight(content_w, entry.source_component)), "source component", entry.source_component);
    try renderApiField(app, fields.take(apiFieldHeight(content_w, entry.edge_builder)), "builder", entry.edge_builder);
}

fn apiFieldHeight(width: f32, value: []const u8) f32 {
    return 20.0 + app_layout.wrappedTextHeightWith(value, width, api_value_line_h, api_value_max_lines, api_value_avg_w);
}

fn renderApiField(app: component_union.View, bounds: ui.Rect, label_value: []const u8, value: []const u8) GalleryError!void {
    try clippedText(app, ui.Rect.init(bounds.x, bounds.y, bounds.w, api_label_h), label_value, palette.muted);
    const value_h = app_layout.wrappedTextHeightWith(value, bounds.w, api_value_line_h, api_value_max_lines, api_value_avg_w);
    try clippedWrappedText(app, ui.Rect.init(bounds.x, bounds.y + 20, bounds.w, value_h), value, palette.text, api_value_line_h, api_value_avg_w, api_value_max_lines);
}

fn renderComponentContract(app: component_union.View, bounds: ui.Rect, entry: ComponentSpec) GalleryError!void {
    try app.subtleAt(bounds, "Contract", "Render through `Component.render`, collect hits through `Component.collectInteractions`, and keep backend concerns out of component code.");
    try app.badgeAt(contractBadgeBounds(bounds, entry.category.label()), entry.category.label(), .outline);
}

fn renderCatalogCard(app: component_union.View, bounds: ui.Rect, entry: ComponentSpec, card_id: u32, preview_id: u32, selected: bool) GalleryError!void {
    if (gallery_text_clip_top) |clip_top| {
        if (bounds.y < clip_top) return;
    }
    const is_hovered = hovered(bounds);
    const card_app = app.withStyle(componentStyle()).withMergedControl(.{ .active = selected, .hovered = is_hovered });
    try card_app.selectableSurfaceAt(bounds, card_id, entry.name, entry.category.label(), if (is_hovered or selected) .elevated else .panel);

    const inset = bounds.insetUniform(catalog_card_pad);
    const source_bounds = sourceBadgeBounds(inset, selected);
    try catalogSource(app, ui.Rect.init(inset.x + inset.w - source_bounds.w, inset.y - 1, source_bounds.w, source_bounds.h), selected);
    try clippedText(card_app, ui.Rect.init(inset.x, inset.y + 48, inset.w, body_text_height), entry.edge_builder, palette.muted);

    try renderReferencePreview(app, ui.Rect.init(inset.x, inset.y + 76, inset.w, catalog_preview_h), entry, preview_id);
}

fn catalogSource(app: component_union.View, bounds: ui.Rect, selected: bool) GalleryError!void {
    try app.badgeAt(bounds, if (selected) "selected" else "EdgeRun", if (selected) .default else .outline);
}

fn sourceBadgeBounds(inset: ui.Rect, selected: bool) ui.Rect {
    const label_value = if (selected) "selected" else "EdgeRun";
    const desired_w = @as(f32, @floatFromInt(label_value.len)) * 7.5 + 34.0;
    return ui.Rect.init(inset.x, inset.y, @min(inset.w, @max(catalog_source_min_w, desired_w)), 24.0);
}

fn contractBadgeBounds(bounds: ui.Rect, label_value: []const u8) ui.Rect {
    const desired_w = @as(f32, @floatFromInt(label_value.len)) * 7.5 + 34.0;
    const width = @min(@max(1.0, bounds.w - card_content_x * 2.0), @max(catalog_source_min_w, desired_w));
    return ui.Rect.init(bounds.x + card_content_x, bounds.y + bounds.h - 32, width, 24);
}

fn renderReferencePreview(app: component_union.View, bounds: ui.Rect, spec_value: ComponentSpec, id: u32) GalleryError!void {
    return switch (spec_value.preview) {
        .accordion => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .alert => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .alert_dialog => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .aspect_ratio => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .avatar,
        .card,
        .empty,
        .checkbox,
        .icon,
        .icon_button,
        .input,
        .item,
        .kbd,
        .label,
        .progress,
        .radio_group,
        .select,
        .separator,
        .skeleton,
        .spinner,
        .slider,
        .switch_control,
        .textarea,
        .toggle,
        .tabs,
        => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .badge => renderBadgeVariants(app, bounds),
        .breadcrumb => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .button => renderButtonVariants(app, bounds, id),
        .button_group => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .calendar => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .carousel => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .chart => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .combobox => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .command => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .context_menu => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .data_table, .table => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .date_picker => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .dialog => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .direction => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .drawer => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .dropdown_menu => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .field => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .hover_card => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .input_group => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .input_otp => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .menubar => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .native_select => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .navigation_menu => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .pagination => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .popover => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .resizable => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .scroll_area => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .sheet => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .sidebar => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .sonner => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .toast => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .toggle_group => renderPrimitivePreview(app, bounds, spec_value.preview, id),
        .tooltip => renderPrimitivePreview(app, bounds, spec_value.preview, id),
    };
}

const PrimitivePreview = component_union.Component;

fn renderPrimitivePreview(app: component_union.View, bounds: ui.Rect, kind: PreviewKind, id: u32) GalleryError!void {
    try renderComponentPreview(app, bounds, primitivePreview(kind, id));
}

fn primitivePreview(kind: PreviewKind, id: u32) PrimitivePreview {
    return switch (kind) {
        .avatar => .{ .avatar = .{ .label = "ER" } },
        .accordion => .{ .accordion = .{ .id = id, .title = "Is it accessible?", .detail = "Yes. It follows the pattern.", .open = true } },
        .alert => .{ .alert = .{ .title = "Heads up", .detail = "Status message" } },
        .alert_dialog => .{ .alert_dialog = .{ .id = id, .title = "Are you sure?", .detail = "Modal content" } },
        .aspect_ratio => .{ .aspect_ratio = .{ .ratio_w = 16, .ratio_h = 9 } },
        .badge => .{ .badge = .{ .label = "Default" } },
        .breadcrumb => .{ .breadcrumb = .{ .id = id, .first = "Home", .current = "Button" } },
        .button => .{ .button = .{ .id = id, .label = "Default" } },
        .button_group => .{ .button_group = .{ .id = id, .first = "Left", .second = "Right", .active = 1 } },
        .calendar => .{ .calendar = .{ .id = id, .month = "May 2026", .selected_day = 25 } },
        .carousel => .{ .carousel = .{ .id = id, .label = "Slide" } },
        .card => .{ .card = .{ .title = "Card title", .detail = "Description" } },
        .chart => .{ .chart = .{ .id = id, .label = "Visitors" } },
        .empty => .{ .empty = .{ .title = "No results", .detail = "Try another filter." } },
        .field => .{ .field = .{ .id = id, .label = "Email", .placeholder = "m@example.com" } },
        .hover_card => .{ .hover_card = .{ .id = id, .trigger = "Hover", .content = "@shadcn" } },
        .icon => component_union.icon(.sparkles),
        .icon_button => component_union.iconButtonNamed(id, "Search", .search, .primary),
        .checkbox => .{ .checkbox = .{ .id = id, .label = "Accept terms", .checked = true } },
        .combobox => .{ .combobox = .{ .id = id, .placeholder = "Search framework...", .selected = "React" } },
        .command => .{ .command = .{ .id = id, .placeholder = "Type a command..." } },
        .context_menu => .{ .context_menu = .{ .id = id, .first = "Profile", .second = "Settings" } },
        .dropdown_menu => .{ .dropdown_menu = .{ .id = id, .first = "Profile", .second = "Settings" } },
        .input => .{ .input = .{ .id = id, .placeholder = "Email" } },
        .input_group => .{ .input_group = .{ .id = id, .addon = "https://", .placeholder = "example.com" } },
        .input_otp => .{ .input_otp = .{ .id = id, .value = "123" } },
        .item => .{ .row_item = .{ .id = id, .title = "Item title", .detail = "Description" } },
        .kbd => .{ .kbd = .{ .label = "Cmd K" } },
        .label => .{ .label = .{ .value = "Email" } },
        .menubar => .{ .menubar = .{ .id = id, .first = "File", .second = "Edit", .active = 0 } },
        .navigation_menu => .{ .navigation_menu = .{ .id = id, .first = "Docs", .second = "Components", .active = 1 } },
        .native_select => .{ .select = .{ .id = id, .label = "Native" } },
        .pagination => .{ .pagination = .{ .id = id, .page = 1 } },
        .popover => .{ .popover = .{ .id = id, .trigger = "Open", .content = "Place content" } },
        .progress => .{ .progress = .{ .value = 0.62 } },
        .radio_group => .{ .radio_group = .{ .id = id, .first = "Default", .second = "Comfortable", .selected = 1 } },
        .resizable => .{ .resizable = .{ .id = id, .ratio = 0.58 } },
        .select => .{ .select = .{ .id = id, .label = "Select" } },
        .separator => .{ .separator = .{} },
        .scroll_area => .{ .scroll_area = .{} },
        .skeleton => .{ .skeleton = .{} },
        .spinner => .{ .spinner = .{} },
        .sonner => .{ .toast = .{ .id = id, .title = "Saved", .detail = "Notification" } },
        .slider => .{ .slider = .{ .id = id, .label = "Volume", .value = 0.68 } },
        .switch_control => .{ .switch_control = .{ .id = id, .label = "Airplane Mode", .checked = true } },
        .textarea => .{ .textarea = .{ .id = id, .placeholder = "Type your message here." } },
        .toggle => .{ .toggle = .{ .id = id, .label = "Bold", .pressed = true } },
        .toggle_group => .{ .toggle_group = .{ .id = id, .first = "Left", .second = "Center", .active = 1 } },
        .tabs => .{ .tabs = .{ .id = id, .first = "Account", .second = "Password", .active = 0 } },
        .data_table, .table => .{ .table = .{ .id = id, .name = "Sarah Chen", .role = "Engineer" } },
        .date_picker => .{ .input = .{ .id = id, .placeholder = "May 25, 2026" } },
        .dialog => .{ .dialog = .{ .id = id, .title = "Edit profile", .detail = "Modal content" } },
        .direction => .{ .direction = .{ .id = id, .active = 0 } },
        .drawer => .{ .drawer = .{ .id = id, .title = "Edit profile", .detail = "Drawer content" } },
        .sheet => .{ .sheet = .{ .id = id, .title = "Edit profile", .detail = "Sheet content" } },
        .sidebar => .{ .sidebar = .{ .id = id, .title = "Workspace", .item = "Nav" } },
        .tooltip => .{ .tooltip = .{ .id = id, .trigger = "Hover me", .content = "Add to library" } },
        .toast => .{ .toast = .{ .id = id, .title = "Queued", .detail = "Notification" } },
    };
}

fn renderComponentPreview(app: component_union.View, bounds: ui.Rect, component: component_union.Component) GalleryError!void {
    try validateCanonicalPreview(component);
    const meta = component.accessibility();
    const open_ids = if (meta.control_id) |id| (&[_]u32{id})[0..] else &.{};
    const drag_value = if (meta.control_id) |id| if (gallery_drag_override) |drag| if (drag.id == id) drag.value else null else null else null;
    const options: component_common.RenderOptions = .{ .style = componentStyle(), .overlay = .{ .open_ids = open_ids }, .drag_value = drag_value };
    try app.withOptions(options).interactive(component, bounds);
}

fn validateCanonicalPreview(component: component_union.Component) GalleryError!void {
    var ui_raw: [canonical_ui_buffer_size]u8 = undefined;
    var object_raw: [canonical_object_buffer_size]u8 = undefined;
    const canonical = component.toObject(&ui_raw, &object_raw, galleryEpoch()) orelse return error.NoSpace;
    _ = try component_union.Component.fromObject(canonical);
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

fn galleryEpoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
}

fn renderBadgeVariants(app: component_union.View, bounds: ui.Rect) GalleryError!void {
    var cursor = app.row(bounds, 6);
    try renderComponentPreview(app, cursor.take(64), .{ .badge = .{ .label = "Default" } });
    try renderComponentPreview(app, cursor.take(72), .{ .badge = .{ .label = "Outline", .variant = .outline } });
    try renderComponentPreview(app, cursor.take(44), .{ .badge = .{ .label = "Link", .variant = .link } });
}

fn renderButtonVariants(app: component_union.View, bounds: ui.Rect, id: u32) GalleryError!void {
    var cursor = app.row(bounds, 6);
    try renderComponentPreview(app, cursor.take(70), .{ .button = .{ .id = id, .label = "Default" } });
    try renderComponentPreview(app, cursor.take(76), .{ .button = .{ .id = id + 1, .label = "Second", .variant = .secondary } });
    try renderComponentPreview(app, cursor.take(54), .{ .button = .{ .id = id + 2, .label = "Link", .variant = .link } });
}

fn normalizedGridGap(value: f32) f32 {
    if (value <= (grid_gap_compact + grid_gap_default) * 0.5) return grid_gap_compact;
    if (value >= (grid_gap_default + grid_gap_wide) * 0.5) return grid_gap_wide;
    return grid_gap_default;
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

fn clippedText(app: component_union.View, bounds: ui.Rect, value: []const u8, color: ui.Color) GalleryError!void {
    try clippedAlignedText(app, bounds, value, color, .start);
}

fn clippedAlignedText(app: component_union.View, bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) GalleryError!void {
    if (gallery_text_clip_top) |clip_top| {
        if (bounds.y < clip_top) return;
    }
    const text_bounds = ui.Rect.init(bounds.x, bounds.y, @max(1, bounds.w), @max(1, bounds.h));
    if (bounds.h < 28) {
        try app.alignedText(text_bounds, value, color, alignment);
        return;
    }
    try app.wrappedWith(text_bounds, value, color, 16.0, text_char_w, 4);
}

fn clippedWrappedText(app: component_union.View, bounds: ui.Rect, value: []const u8, color: ui.Color, line_height: f32, average_char_width: f32, max_lines: usize) GalleryError!void {
    if (gallery_text_clip_top) |clip_top| {
        if (bounds.y < clip_top) return;
    }
    try app.wrappedWith(bounds, value, color, line_height, average_char_width, max_lines);
}

fn centeredWrappedText(app: component_union.View, bounds: ui.Rect, value: []const u8, color: ui.Color, max_lines: usize) GalleryError!void {
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
            try clippedAlignedText(app, ui.Rect.init(bounds.x, bounds.y + @as(f32, @floatFromInt(line_index)) * line_height, bounds.w, line_height), value[split.start..split.end], color, .center);
        }
        byte_cursor = split.next;
    }
}

fn hovered(bounds: ui.Rect) bool {
    const point = gallery_hover_point orelse return false;
    return bounds.containsExclusive(point.x, point.y);
}

test "component gallery catalog is the authoritative component list" {
    try std.testing.expectEqual(@as(usize, 60), component_catalog.len);
    try std.testing.expectEqualStrings("/docs/components/input-group", findBySlug("input-group").?.component_path);
    try std.testing.expectEqualStrings("Button", findBySourceComponent("Button").?.source_component);
    try std.testing.expectEqual(@as(usize, 7), indexBySlug("button").?);
    try std.testing.expectEqual(@as(usize, 7), indexByCatalogHit(first_catalog_card_id + 7).?);
    try std.testing.expectEqual(Category.foundation, findBySlug("button").?.category);
    try std.testing.expectEqual(@as(usize, 15), countByCategory(.form));
    try std.testing.expectEqual(@as(usize, 6), countByCategory(.layout));
}

test "component gallery catalog entries render reference previews with canonical components" {
    var h = component_test.ClippedInteractiveHarness(2048, 128, 256){};
    h.init();
    const app = component_union.renderer(&h.scene, &h.collector, .{ .style = componentStyle() });
    var rendered: usize = 0;

    for (component_catalog, 0..) |entry, index| {
        const y = @as(f32, @floatFromInt(rendered)) * 48.0;
        const bounds = ui.Rect.init(0, y, 220, 36);
        try renderReferencePreview(app, bounds, entry, preview_base_id + @as(u32, @intCast(index)));
        rendered += 1;
    }

    try std.testing.expectEqual(component_catalog.len, rendered);
    try std.testing.expect(h.written().len > component_catalog.len);
    try std.testing.expect(h.hits().len > 40);
    try h.expectHitId(preview_base_id + 7);
    try h.expectText("Is it accessible?");
    try h.expectText("Edit profile");
    try h.expectText("Account");
}

test "component gallery preview path validates canonical component object" {
    var ui_raw: [canonical_ui_buffer_size]u8 = undefined;
    var object_raw: [canonical_object_buffer_size]u8 = undefined;
    const source = primitivePreview(.button, preview_base_id + 33);
    const canonical = source.toObject(&ui_raw, &object_raw, galleryEpoch()).?;
    const decoded = try component_union.Component.fromObject(canonical);

    var h = component_test.ClippedInteractiveHarness(16, 4, 4){};
    h.init();
    const app = component_union.renderer(&h.scene, &h.collector, .{ .style = componentStyle() });
    try renderComponentPreview(app, ui.Rect.init(0, 0, 140, 36), source);

    try std.testing.expectEqualStrings("Default", switch (decoded) {
        .button => |button| button.label,
        else => "",
    });
    try h.expectText("Default");
    try h.expectHitId(preview_base_id + 33);
}

test "component gallery renders component wall commands and interaction regions" {
    var h = component_test.ClippedInteractiveHarness(4096, 128, 512){};
    h.init();
    try renderComponentGallery(&h.scene, &h.collector, ui.Rect.init(0, 0, 1440, 940), .{});

    const stats = h.scene.stats();
    try std.testing.expect(stats.rects > 150);
    try std.testing.expect(stats.text_quads > 120);
    try std.testing.expect(stats.icon_quads >= 2);
    try std.testing.expect(h.hits().len > 60);
    try h.expectText("Component Catalog");
    try h.expectText("Accordion");
    try h.expectText("Tooltip");
}

test "component gallery selected component renders selected component panel" {
    var h = component_test.ClippedInteractiveHarness(4096, 128, 512){};
    h.init();
    const index = indexBySlug("button").?;
    try renderComponentGallery(&h.scene, &h.collector, ui.Rect.init(0, 0, 1440, 940), .{ .selected_component_index = index });

    try h.expectText("/docs/components/button");
    try h.expectText("button");
    try h.expectText("Rendered component");
    try h.expectText("default");
    try h.expectText("compact");
    try h.expectText("small");
    const selected_preview_id = selected_preview_id_base + @as(u32, @intCast(index)) * preview_id_stride;
    try h.expectHitId(selected_preview_id);
    try h.expectHitId(selected_preview_id + 1);
    try h.expectHitId(selected_preview_id + 2);
    try std.testing.expectEqual(index, indexByPreviewHit(selected_preview_id + 2).?);
    var source_path: [96]u8 = undefined;
    try std.testing.expectEqualStrings("src/ui/components/Button.zig", sourcePathForIndex(index, &source_path).?);
    try std.testing.expect(contentHeightForState(1440, .{ .selected_component_index = index }) > contentHeight(1440));
}

test "component gallery derives responsive catalog columns" {
    try std.testing.expectEqual(@as(usize, 1), galleryColumnCount(335, 24));
    try std.testing.expectEqual(@as(usize, 2), galleryColumnCount(696, 24));
    try std.testing.expectEqual(@as(usize, 5), galleryColumnCount(1660, 40));
}

test "component gallery scrolls through later catalog cards" {
    var h = component_test.ClippedInteractiveHarness(4096, 128, 512){};
    h.init();
    try renderComponentGallery(&h.scene, &h.collector, ui.Rect.init(0, 0, 900, 720), .{ .scroll_y = 4096 });

    try h.expectText("Table");
    try h.expectText("Tooltip");
}

test "component gallery hover uses canonical card control state without changing interaction coverage" {
    var base = component_test.ClippedInteractiveHarness(4096, 128, 512){};
    base.init();
    try renderComponentGallery(&base.scene, &base.collector, ui.Rect.init(0, 0, 1440, 940), .{});

    var hover = component_test.ClippedInteractiveHarness(4096, 128, 512){};
    hover.init();
    try renderComponentGallery(&hover.scene, &hover.collector, ui.Rect.init(0, 0, 1440, 940), .{ .hover_x = 260, .hover_y = 210 });

    try base.expectNoRectColor(component_common.state_hover_border);
    try hover.expectRectColor(component_common.state_hover_border);
    try std.testing.expectEqual(base.hits().len, hover.hits().len);
}

test "component gallery buttons use shared optical label placement" {
    var h = component_test.ClippedInteractiveHarness(16, 4, 8){};
    h.init();
    const bounds = ui.Rect.init(10, 20, 140, 34);
    const app = component_union.renderer(&h.scene, &h.collector, .{ .style = componentStyle() });
    try renderComponentPreview(app, bounds, .{ .button = .{ .id = preview_base_id + 5010, .label = "Continue" } });

    const label = textCommand(h.written(), "Continue").?.text;
    const center_delta = @abs((label.origin.x + label.origin.w * 0.5) - (bounds.x + bounds.w * 0.5));
    try std.testing.expectEqual(ui.TextAlign.center, label.alignment);
    try std.testing.expect(center_delta < 0.01);
    try std.testing.expect(label.origin.y + label.origin.h * 0.5 < bounds.y + bounds.h * 0.5);
    try std.testing.expect(label.origin.y >= bounds.y);
    try h.expectHitId(preview_base_id + 5010);
}

fn textCommand(commands: []const ui.Command, value: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text_command| if (bytes.eql(text_command.value, value)) return .{ .text = text_command },
        else => {},
    };
    return null;
}
