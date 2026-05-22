const std = @import("std");
const ui = @import("ui.zig");

pub const preview_base_id: u32 = 18_000;

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
        return self == .native_primitive or self == .exact_port;
    }
};

pub const DemoSpec = struct {
    name: []const u8,
    slug: []const u8,
    route: []const u8,
    category: Category,
    source_component: []const u8,
    edge_builder: []const u8,
    status: Status = .exact_port,

    pub fn hasNativeRenderer(self: DemoSpec) bool {
        return self.status.hasNativeRenderer();
    }
};

pub const categories = [_]Category{ .foundation, .form, .overlay, .navigation, .data_display, .feedback, .layout, .media };
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

pub const demo_components = [_]DemoSpec{
    demo("Accordion", "accordion", "Layout", "Accordion", "accordion_node"),
    demo("Alert", "alert", "Feedback", "Alert", "alert_node"),
    demo("Alert Dialog", "alert-dialog", "Overlay", "AlertDialog", "alert_dialog_node"),
    demo("Aspect Ratio", "aspect-ratio", "Media", "AspectRatio", "aspect_ratio_node"),
    demo("Avatar", "avatar", "Data Display", "Avatar", "avatar_node"),
    demo("Badge", "badge", "Foundation", "Badge", "badge"),
    demo("Breadcrumb", "breadcrumb", "Navigation", "Breadcrumb", "breadcrumb"),
    demo("Button", "button", "Foundation", "Button", "button"),
    demo("Button Group", "button-group", "Foundation", "ButtonGroup", "button_group_node"),
    demo("Calendar", "calendar", "Form", "Calendar", "calendar_node"),
    demo("Card", "card", "Layout", "Card", "card"),
    demo("Carousel", "carousel", "Media", "Carousel", "carousel_node"),
    demo("Chart", "chart", "Data Display", "Chart", "chart_node"),
    demo("Checkbox", "checkbox", "Form", "Checkbox", "checkbox"),
    demo("Collapsible", "collapsible", "Layout", "Collapsible", "collapsible_node"),
    demo("Combobox", "combobox", "Form", "Combobox", "combobox_node"),
    demo("Command", "command", "Overlay", "Command", "command_palette"),
    demo("Context Menu", "context-menu", "Overlay", "ContextMenu", "context_menu_node"),
    demo("Data Table", "data-table", "Data Display", "DataTable", "data_table_node"),
    demo("Date Picker", "date-picker", "Form", "DatePicker", "date_picker_node"),
    demo("Dialog", "dialog", "Overlay", "Dialog", "dialog"),
    demo("Direction", "direction", "Foundation", "DirectionProvider", "direction_node"),
    demo("Drawer", "drawer", "Overlay", "Drawer", "drawer_node"),
    demo("Dropdown Menu", "dropdown-menu", "Overlay", "DropdownMenu", "dropdown_menu_node"),
    demo("Empty", "empty", "Feedback", "Empty", "empty_state"),
    demo("Field", "field", "Form", "Field", "field_node"),
    demo("Hover Card", "hover-card", "Overlay", "HoverCard", "hover_card_node"),
    demo("Input", "input", "Form", "Input", "field_node"),
    demo("Input Group", "input-group", "Form", "InputGroup", "input_group_node"),
    demo("Input OTP", "input-otp", "Form", "InputOTP", "input_otp_node"),
    demo("Item", "item", "Data Display", "Item", "list_row_node"),
    demo("Kbd", "kbd", "Foundation", "Kbd", "kbd_node"),
    demo("Label", "label", "Form", "Label", "text"),
    demo("Menubar", "menubar", "Navigation", "Menubar", "menubar_node"),
    demo("Native Select", "native-select", "Form", "NativeSelect", "select_node"),
    demo("Navigation Menu", "navigation-menu", "Navigation", "NavigationMenu", "navigation_menu_node"),
    demo("Pagination", "pagination", "Navigation", "Pagination", "pagination_node"),
    demo("Popover", "popover", "Overlay", "Popover", "popover_node"),
    demo("Progress", "progress", "Feedback", "Progress", "progress_bar_node"),
    demo("Radio Group", "radio-group", "Form", "RadioGroup", "radio"),
    demo("Resizable", "resizable", "Layout", "Resizable", "resizable_node"),
    demo("Scroll Area", "scroll-area", "Layout", "ScrollArea", "scroll_area"),
    demo("Select", "select", "Form", "Select", "select_node"),
    demo("Separator", "separator", "Layout", "Separator", "divider"),
    demo("Sheet", "sheet", "Overlay", "Sheet", "sheet_node"),
    demo("Sidebar", "sidebar", "Navigation", "Sidebar", "sidebar_node"),
    demo("Skeleton", "skeleton", "Feedback", "Skeleton", "skeleton"),
    demo("Slider", "slider", "Form", "Slider", "slider_node"),
    demo("Sonner", "sonner", "Feedback", "Sonner", "toast"),
    demo("Switch", "switch", "Form", "Switch", "toggle_node"),
    demo("Table", "table", "Data Display", "Table", "table_node"),
    demo("Tabs", "tabs", "Navigation", "Tabs", "tabs_node"),
    demo("Textarea", "textarea", "Form", "Textarea", "text_area_node"),
    demo("Toast", "toast", "Feedback", "Toast", "toast"),
    demo("Toggle", "toggle", "Foundation", "Toggle", "toggle_node"),
    demo("Toggle Group", "toggle-group", "Foundation", "ToggleGroup", "toggle_group_node"),
    demo("Tooltip", "tooltip", "Overlay", "Tooltip", "tooltip"),
};

fn demo(name: []const u8, slug: []const u8, category_label: []const u8, source: []const u8, builder: []const u8) DemoSpec {
    return .{
        .name = name,
        .slug = slug,
        .route = routeFor(slug),
        .category = categoryFromLabel(category_label),
        .source_component = source,
        .edge_builder = builder,
    };
}

fn routeFor(slug: []const u8) []const u8 {
    @setEvalBranchQuota(6000);
    const routes = [_]struct { []const u8, []const u8 }{
        .{ "accordion", "/docs/components/accordion" },
        .{ "alert", "/docs/components/alert" },
        .{ "alert-dialog", "/docs/components/alert-dialog" },
        .{ "aspect-ratio", "/docs/components/aspect-ratio" },
        .{ "avatar", "/docs/components/avatar" },
        .{ "badge", "/docs/components/badge" },
        .{ "breadcrumb", "/docs/components/breadcrumb" },
        .{ "button", "/docs/components/button" },
        .{ "button-group", "/docs/components/button-group" },
        .{ "calendar", "/docs/components/calendar" },
        .{ "card", "/docs/components/card" },
        .{ "carousel", "/docs/components/carousel" },
        .{ "chart", "/docs/components/chart" },
        .{ "checkbox", "/docs/components/checkbox" },
        .{ "collapsible", "/docs/components/collapsible" },
        .{ "combobox", "/docs/components/combobox" },
        .{ "command", "/docs/components/command" },
        .{ "context-menu", "/docs/components/context-menu" },
        .{ "data-table", "/docs/components/data-table" },
        .{ "date-picker", "/docs/components/date-picker" },
        .{ "dialog", "/docs/components/dialog" },
        .{ "direction", "/docs/components/direction" },
        .{ "drawer", "/docs/components/drawer" },
        .{ "dropdown-menu", "/docs/components/dropdown-menu" },
        .{ "empty", "/docs/components/empty" },
        .{ "field", "/docs/components/field" },
        .{ "hover-card", "/docs/components/hover-card" },
        .{ "input", "/docs/components/input" },
        .{ "input-group", "/docs/components/input-group" },
        .{ "input-otp", "/docs/components/input-otp" },
        .{ "item", "/docs/components/item" },
        .{ "kbd", "/docs/components/kbd" },
        .{ "label", "/docs/components/label" },
        .{ "menubar", "/docs/components/menubar" },
        .{ "native-select", "/docs/components/native-select" },
        .{ "navigation-menu", "/docs/components/navigation-menu" },
        .{ "pagination", "/docs/components/pagination" },
        .{ "popover", "/docs/components/popover" },
        .{ "progress", "/docs/components/progress" },
        .{ "radio-group", "/docs/components/radio-group" },
        .{ "resizable", "/docs/components/resizable" },
        .{ "scroll-area", "/docs/components/scroll-area" },
        .{ "select", "/docs/components/select" },
        .{ "separator", "/docs/components/separator" },
        .{ "sheet", "/docs/components/sheet" },
        .{ "sidebar", "/docs/components/sidebar" },
        .{ "skeleton", "/docs/components/skeleton" },
        .{ "slider", "/docs/components/slider" },
        .{ "sonner", "/docs/components/sonner" },
        .{ "switch", "/docs/components/switch" },
        .{ "table", "/docs/components/table" },
        .{ "tabs", "/docs/components/tabs" },
        .{ "textarea", "/docs/components/textarea" },
        .{ "toast", "/docs/components/toast" },
        .{ "toggle", "/docs/components/toggle" },
        .{ "toggle-group", "/docs/components/toggle-group" },
        .{ "tooltip", "/docs/components/tooltip" },
    };
    for (routes) |entry| {
        if (std.mem.eql(u8, slug, entry[0])) return entry[1];
    }
    return "/docs/components";
}

fn categoryFromLabel(label: []const u8) Category {
    if (std.mem.eql(u8, label, "Foundation")) return .foundation;
    if (std.mem.eql(u8, label, "Form")) return .form;
    if (std.mem.eql(u8, label, "Overlay")) return .overlay;
    if (std.mem.eql(u8, label, "Navigation")) return .navigation;
    if (std.mem.eql(u8, label, "Data Display")) return .data_display;
    if (std.mem.eql(u8, label, "Feedback")) return .feedback;
    if (std.mem.eql(u8, label, "Media")) return .media;
    return .layout;
}

pub fn findBySlug(slug: []const u8) ?*const DemoSpec {
    for (&demo_components) |*spec| {
        if (std.mem.eql(u8, spec.slug, slug)) return spec;
    }
    return null;
}

pub fn nativeDemoCount() usize {
    var count: usize = 0;
    for (demo_components) |spec| {
        if (spec.hasNativeRenderer()) count += 1;
    }
    return count;
}

pub fn findBySourceComponent(source_component: []const u8) ?*const DemoSpec {
    for (&demo_components) |*spec| {
        if (std.mem.eql(u8, spec.source_component, source_component)) return spec;
    }
    return null;
}

pub fn countByCategory(category: Category) usize {
    var count: usize = 0;
    for (demo_components) |spec| {
        if (spec.category == category) count += 1;
    }
    return count;
}

pub fn countByStatus(status: Status) usize {
    var count: usize = 0;
    for (demo_components) |spec| {
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

pub const GalleryState = struct {
    contribution_bar: usize = 5,
    stock_bar: usize = 5,
    power_bar: usize = 6,
    payout_value: f32 = 0.24,
    brightness: f32 = 0.82,
    scroll_y: f32 = 0.0,
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

const ShowcaseCard = struct {
    title: []const u8,
    detail: []const u8,
    kind: CardKind,
    height: f32,
    id: u32,
};

const showcase_cards = [_]ShowcaseCard{
    card("Contribution History", "Last 6 months of activity", .chart, 296, 940),
    card("Payout Threshold", "Set minimum balance", .form, 330, 944),
    card("Savings Targets", "Active milestones for 2024", .metrics, 278, 945),
    card("Buy Investment", "Market orders execute at current price", .form, 292, 947),
    card("Distribute Track", "Upload your first master", .centered, 210, 957),
    card("Claimable Balance", "Pending setup", .table, 276, 966),
    card("Recent Transactions", "Latest account activity", .list, 376, 950),
    card("Account Access", "Update credentials", .form, 284, 948),
    card("Mobile Pairing", "Scan to connect device", .centered, 274, 958),
    card("Preferences", "Manage account settings", .controls, 326, 972),
    card("Navigation", "Menu, breadcrumb, and rows", .navigation, 340, 980),
    card("Transfer Funds", "Move money between accounts", .form, 330, 1019),
    card("Q2 Dividend Income", "Quarterly payouts", .list, 336, 959),
    card("Room Controls", "Smart home controls", .controls, 340, 973),
    card("Support Tabs", "Account help center", .navigation, 292, 1008),
    card("Cover Art", "Artwork upload", .centered, 330, 1020),
    card("Dollar-Cost Averaging", "Strategy copy block", .metrics, 178, 0),
    card("Savings Ring", "Projected finish", .metrics, 284, 0),
    card("Holdings Table", "Search holdings and tickers", .table, 330, 1009),
    card("Skeleton Loading", "Loading state", .skeleton, 236, 0),
    card("Syncing Accounts", "Background import", .centered, 214, 965),
    card("Payout Preferences", "Receiving method", .form, 330, 1024),
    card("Power Usage", "Whole home", .chart, 300, 1025),
    card("Connect Bank", "Payout setup", .centered, 210, 1027),
    card("Upcoming Payments", "Scheduled payments", .calendar, 348, 1028),
    card("Front Door", "Smart Lock Pro", .security, 320, 1053),
    card("Stock Performance", "6-month price history", .chart, 300, 1056),
    card("Explore Catalog", "Metadata and assets", .centered, 220, 1058),
    card("Set a new milestone", "Financial target", .form, 286, 1059),
    card("Social Links", "Artist URLs", .form, 330, 1062),
    card("Notifications", "Choose notification topics", .controls, 300, 1068),
};

fn card(title: []const u8, detail: []const u8, kind: CardKind, height: f32, id: u32) ShowcaseCard {
    return .{ .title = title, .detail = detail, .kind = kind, .height = height, .id = preview_base_id + id };
}

const palette = struct {
    const bg = ui.Color{ .r = 9, .g = 12, .b = 18 };
    const sidebar = ui.Color{ .r = 14, .g = 18, .b = 27 };
    const panel = ui.Color{ .r = 18, .g = 24, .b = 36 };
    const panel_alt = ui.Color{ .r = 23, .g = 31, .b = 46 };
    const row = ui.Color{ .r = 30, .g = 40, .b = 58 };
    const border = ui.Color{ .r = 43, .g = 55, .b = 78 };
    const text = ui.Color{ .r = 232, .g = 238, .b = 247 };
    const muted = ui.Color{ .r = 145, .g = 159, .b = 179 };
    const accent = ui.Color{ .r = 59, .g = 130, .b = 246 };
    const green = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const danger = ui.Color{ .r = 248, .g = 113, .b = 113 };
    const shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
};

pub fn renderGallery(scene: *ui.Scene, bounds: ui.Rect, state: GalleryState) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0);

    const rail_w: f32 = if (bounds.w < 760) 0 else 176;
    if (rail_w > 0) try renderRail(scene, .{ .x = bounds.x, .y = bounds.y, .w = rail_w, .h = bounds.h });
    try renderTopbar(scene, .{ .x = bounds.x + rail_w, .y = bounds.y, .w = bounds.w - rail_w, .h = 56 });

    const scroll_y = std.math.clamp(state.scroll_y, 0.0, 4096.0);
    const board = ui.Rect.init(bounds.x + rail_w + 28, bounds.y + 84 - scroll_y, @max(320, bounds.w - rail_w - 56), @max(240, bounds.h - 112 + scroll_y));
    const columns: usize = if (board.w < 700) 1 else if (board.w < 1040) 2 else if (board.w < 1400) 3 else 4;
    const gap: f32 = 24;
    const card_w = (board.w - gap * @as(f32, @floatFromInt(columns - 1))) / @as(f32, @floatFromInt(columns));
    var column_y = [_]f32{ 0, 0, 0, 0 };

    for (showcase_cards) |spec| {
        const col = shortestColumn(column_y[0..columns]);
        const x = board.x + @as(f32, @floatFromInt(col)) * (card_w + gap);
        const y = board.y + column_y[col];
        try renderShowcaseCard(scene, ui.Rect.init(x, y, card_w, spec.height), spec, state);
        column_y[col] += spec.height + gap;
    }
}

fn renderRail(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.sidebar, 0);
    try panel(scene, ui.Rect.init(bounds.x + 8, bounds.y + 8, bounds.w - 16, 40), 8);
    try text(scene, bounds.x + 20, bounds.y + 20, 80, 16, "Menu", palette.text);
    const labels = [_]struct { []const u8, []const u8 }{
        .{ "Style", "Nova" },
        .{ "Base Color", "Neutral" },
        .{ "Theme", "Neutral" },
        .{ "Chart Color", "Neutral" },
        .{ "Heading", "Geist VF" },
        .{ "Font", "Geist VF" },
        .{ "Icon Library", "Lucide" },
        .{ "Radius", "Default" },
        .{ "Menu", "Solid" },
        .{ "Menu Accent", "Subtle" },
    };
    var y = bounds.y + 62;
    for (labels, 0..) |item, index| {
        const row = ui.Rect.init(bounds.x + 8, y, bounds.w - 16, 48);
        if (index == 0) try fill(scene, row, palette.panel, 8);
        try text(scene, row.x + 12, row.y + 9, row.w - 24, 14, item[0], palette.muted);
        try text(scene, row.x + 12, row.y + 27, row.w - 24, 14, item[1], palette.text);
        y += 50;
    }
    try button(scene, ui.Rect.init(bounds.x + 12, bounds.y + bounds.h - 98, bounds.w - 24, 34), "--preset b0", preview_base_id + 931, false);
    try button(scene, ui.Rect.init(bounds.x + 12, bounds.y + bounds.h - 54, bounds.w - 24, 34), "Get Code", preview_base_id + 934, true);
}

fn renderTopbar(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0);
    try text(scene, bounds.x + 20, bounds.y + 20, 132, 16, "EdgeRun UI", palette.text);
    if (bounds.w < 540) {
        try button(scene, ui.Rect.init(bounds.x + bounds.w - 116, bounds.y + 12, 96, 34), "Get Code", preview_base_id + 908, true);
        return;
    }
    var x = bounds.x + 160;
    const tabs = [_][]const u8{ "Docs", "Components", "Blocks", "Charts", "Directory" };
    for (tabs, 0..) |label, index| {
        const w: f32 = if (index == 1) 112 else 76;
        try ghostButton(scene, ui.Rect.init(x, bounds.y + 12, w, 32), label, preview_base_id + 900 + @as(u32, @intCast(index)));
        x += w + 8;
    }
    if (bounds.w >= 920) {
        const search_w = @min(320, @max(160, bounds.w - 760));
        try field(scene, ui.Rect.init(bounds.x + bounds.w - search_w - 242, bounds.y + 12, search_w, 34), "Search documentation...", preview_base_id + 905);
        try button(scene, ui.Rect.init(bounds.x + bounds.w - 228, bounds.y + 12, 82, 34), "11.4k", preview_base_id + 906, false);
    }
    try button(scene, ui.Rect.init(bounds.x + bounds.w - 136, bounds.y + 12, 112, 34), "Get Code", preview_base_id + 908, true);
}

fn renderShowcaseCard(scene: *ui.Scene, bounds: ui.Rect, spec: ShowcaseCard, state: GalleryState) ui.RenderError!void {
    try scene.pushRect(bounds.insetUniform(-2), palette.shadow, .shadow, 12, 10);
    try fill(scene, bounds, palette.panel, 12);
    try stroke(scene, bounds, palette.border, 12);
    try text(scene, bounds.x + 18, bounds.y + 18, bounds.w - 36, 18, spec.title, palette.text);
    try text(scene, bounds.x + 18, bounds.y + 42, bounds.w - 36, 16, spec.detail, palette.muted);

    const body = bounds.insetLtrb(16, 74, 16, 16);
    if (std.mem.eql(u8, spec.title, "Payout Threshold")) return renderPayoutThreshold(scene, body, spec.id, state.payout_value);
    if (std.mem.eql(u8, spec.title, "Savings Targets")) return renderSavingsTargets(scene, body);
    if (std.mem.eql(u8, spec.title, "Mobile Pairing")) return renderPairing(scene, body, spec.id);
    if (std.mem.eql(u8, spec.title, "Claimable Balance")) return renderClaimableBalance(scene, body, spec.id);
    if (std.mem.eql(u8, spec.title, "Notifications")) return renderNotifications(scene, body, spec.id);

    switch (spec.kind) {
        .chart => try renderChart(scene, body, spec.id, if (std.mem.eql(u8, spec.title, "Power Usage")) state.brightness else state.payout_value),
        .form => try renderForm(scene, body, spec.id),
        .metrics => try renderMetrics(scene, body),
        .table => try renderTable(scene, body, spec.id),
        .list => try renderList(scene, body, spec.id),
        .centered => try renderCentered(scene, body, spec.id),
        .controls => try renderControls(scene, body, spec.id),
        .navigation => try renderNavigation(scene, body, spec.id),
        .calendar => try renderCalendar(scene, body, spec.id),
        .skeleton => try renderSkeleton(scene, body),
        .security => try renderSecurity(scene, body, spec.id),
    }
}

fn renderPayoutThreshold(scene: *ui.Scene, bounds: ui.Rect, action_id: u32, value: f32) ui.RenderError!void {
    try field(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 42), "Preferred Currency: USD", action_id + 1);
    const amount = 50.0 + std.math.clamp(value, 0.0, 1.0) * 9950.0;
    const label = if (amount > 5000) "$5k+ minimum payout" else "$2.4k minimum payout";
    try metricBox(scene, ui.Rect.init(bounds.x, bounds.y + 56, bounds.w, 66), "Minimum Payout Amount", label);
    try slider(scene, ui.Rect.init(bounds.x, bounds.y + 142, bounds.w, 42), "Minimum payout", value, action_id + 2);
    try textArea(scene, ui.Rect.init(bounds.x, bounds.y + 196, bounds.w, 66), "Add notes for this payout configuration...");
    try button(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 36, 132, 34), "Save Threshold", action_id, true);
}

fn renderSavingsTargets(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try savingsTarget(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 64), "Retirement", "$420,000", "$273,000", 0.65);
    try savingsTarget(scene, ui.Rect.init(bounds.x, bounds.y + 78, bounds.w, 64), "Real Estate", "$85,000", "$27,200", 0.32);
    try text(scene, bounds.x, bounds.y + 164, bounds.w, 18, "You have not met your targets for this year.", palette.muted);
}

fn renderPairing(scene: *ui.Scene, bounds: ui.Rect, action_id: u32) ui.RenderError!void {
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
    try text(scene, bounds.x + 24, bounds.y + 144, bounds.w - 48, 18, "Scan to connect your mobile device", palette.text);
    try button(scene, ui.Rect.init(bounds.x + bounds.w * 0.5 - 48, bounds.y + bounds.h - 36, 96, 34), "Got it", action_id, false);
}

fn renderClaimableBalance(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    try metricBox(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 66), "Claimable Balance", "$0.00");
    try badge(scene, ui.Rect.init(bounds.x, bounds.y + 78, 108, 24), "Pending Setup", palette.muted);
    try renderTable(scene, ui.Rect.init(bounds.x, bounds.y + 116, bounds.w, bounds.h - 116), base_id);
}

fn renderNotifications(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    const rows = [_]struct { []const u8, bool }{
        .{ "Select all", true },
        .{ "Transaction alerts", true },
        .{ "Security alerts", true },
        .{ "Goal milestones", false },
        .{ "Market updates", false },
    };
    var y = bounds.y;
    for (rows, 0..) |row, index| {
        try checkboxRow(scene, ui.Rect.init(bounds.x, y, bounds.w, 30), row[0], row[1], base_id + @as(u32, @intCast(index)));
        y += 36;
    }
    try button(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 36, 156, 34), "Save Preferences", base_id + 8, true);
}

fn renderChart(scene: *ui.Scene, bounds: ui.Rect, base_id: u32, boost: f32) ui.RenderError!void {
    try fill(scene, bounds, palette.panel_alt, 8);
    const chart = bounds.insetLtrb(14, 16, 14, 52);
    const values = [_]f32{ 0.42, 0.66, 0.48, 0.78, 0.38, 0.84, 0.62, 0.7 };
    const count: usize = if (chart.w > 420) 8 else 6;
    const gap: f32 = 8;
    const bar_w = (chart.w - gap * @as(f32, @floatFromInt(count - 1))) / @as(f32, @floatFromInt(count));
    for (0..count) |i| {
        const value = @min(1.0, values[i] + if (i == count - 1) boost * 0.12 else 0);
        const h = @max(12, chart.h * value);
        const bar = ui.Rect.init(chart.x + @as(f32, @floatFromInt(i)) * (bar_w + gap), chart.y + chart.h - h, bar_w, h);
        try fill(scene, bar, if (i == count - 1) palette.accent else palette.row, 6);
        try hit(scene, bar, .button, base_id + @as(u32, @intCast(i)));
    }
    try button(scene, ui.Rect.init(bounds.x + 14, bounds.y + bounds.h - 40, 136, 32), "View Report", base_id, true);
}

fn renderForm(scene: *ui.Scene, bounds: ui.Rect, action_id: u32) ui.RenderError!void {
    var y = bounds.y;
    try field(scene, ui.Rect.init(bounds.x, y, bounds.w, 42), "Amount to Invest", action_id + 1);
    y += 54;
    try field(scene, ui.Rect.init(bounds.x, y, bounds.w, 42), "Order Type", action_id + 2);
    y += 58;
    try metricBox(scene, ui.Rect.init(bounds.x, y, (bounds.w - 12) * 0.5, 62), "Estimated Shares", "1.95");
    try metricBox(scene, ui.Rect.init(bounds.x + (bounds.w + 12) * 0.5, y, (bounds.w - 12) * 0.5, 62), "Buying Power", "$12,450");
    try button(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 36, 132, 34), "Save", action_id, true);
    try button(scene, ui.Rect.init(bounds.x + 142, bounds.y + bounds.h - 36, 98, 34), "Cancel", action_id + 10, false);
}

fn savingsTarget(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, target: []const u8, current: []const u8, value: f32) ui.RenderError!void {
    try fill(scene, bounds, palette.row, 8);
    try text(scene, bounds.x + 12, bounds.y + 10, bounds.w * 0.48, 15, title_value, palette.muted);
    try text(scene, bounds.x + 12, bounds.y + 30, bounds.w * 0.48, 18, target, palette.text);
    try text(scene, bounds.x + bounds.w - 92, bounds.y + 16, 80, 14, current, palette.muted);
    try progress(scene, ui.Rect.init(bounds.x + 12, bounds.y + bounds.h - 12, bounds.w - 24, 6), value);
}

fn checkboxRow(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, checked: bool, id_value: u32) ui.RenderError!void {
    const box = ui.Rect.init(bounds.x, bounds.y + 5, 20, 20);
    try fill(scene, box, if (checked) palette.text else palette.panel, 5);
    try stroke(scene, box, if (checked) palette.text else palette.border, 5);
    if (checked) try text(scene, box.x + 5, box.y + 5, 10, 10, "x", palette.panel);
    try text(scene, bounds.x + 32, bounds.y + 7, bounds.w - 40, 15, label, palette.text);
    try hit(scene, bounds, .button, id_value);
}

fn textArea(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8) ui.RenderError!void {
    try fill(scene, bounds, palette.panel_alt, 7);
    try stroke(scene, bounds, palette.border, 7);
    try text(scene, bounds.x + 12, bounds.y + 12, bounds.w - 24, 14, placeholder, palette.muted);
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

fn renderMetrics(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const w = (bounds.w - 12) * 0.5;
    try metricBox(scene, ui.Rect.init(bounds.x, bounds.y, w, 72), "Upcoming", "May 25");
    try metricBox(scene, ui.Rect.init(bounds.x + w + 12, bounds.y, w, 72), "Auto-save", "Weekly");
    try progress(scene, ui.Rect.init(bounds.x, bounds.y + 96, bounds.w, 10), 0.68);
    try progress(scene, ui.Rect.init(bounds.x, bounds.y + 124, bounds.w * 0.76, 10), 0.42);
    try text(scene, bounds.x, bounds.y + 152, bounds.w, 18, "Reusable card, progress, badge, and copy primitives.", palette.muted);
}

fn renderTable(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    try fill(scene, bounds, palette.panel_alt, 8);
    try text(scene, bounds.x + 14, bounds.y + 14, bounds.w * 0.35, 14, "Item", palette.muted);
    try text(scene, bounds.x + bounds.w * 0.55, bounds.y + 14, bounds.w * 0.4, 14, "Amount", palette.muted);
    const rows = [_]struct { []const u8, []const u8 }{
        .{ "Net Royalties", "$0.00" },
        .{ "Processing Fee", "-$0.00" },
        .{ "Total Ready", "$0.00 USD" },
        .{ "Vanguard ETF", "$48,230" },
    };
    var y = bounds.y + 42;
    for (rows, 0..) |row, index| {
        const r = ui.Rect.init(bounds.x + 8, y, bounds.w - 16, 38);
        try fill(scene, r, if (index % 2 == 0) palette.panel else palette.row, 6);
        try text(scene, r.x + 10, r.y + 12, r.w * 0.45, 14, row[0], palette.text);
        try text(scene, r.x + r.w * 0.58, r.y + 12, r.w * 0.35, 14, row[1], palette.muted);
        try hit(scene, r, .row_item, base_id + @as(u32, @intCast(index)));
        y += 42;
    }
}

fn renderList(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    const rows = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "Blue Bottle Coffee", "Food and Drink", "-$6.50" },
        .{ "Whole Foods Market", "Groceries", "-$142.30" },
        .{ "Stripe Payout", "Income", "+$4,200" },
        .{ "Realty Income", "Dividend", "$1,139" },
    };
    var y = bounds.y;
    for (rows, 0..) |row, index| {
        const r = ui.Rect.init(bounds.x, y, bounds.w, 54);
        try fill(scene, r, palette.row, 7);
        try fill(scene, ui.Rect.init(r.x + 10, r.y + 10, 34, 34), palette.panel, 7);
        try text(scene, r.x + 56, r.y + 11, r.w - 150, 16, row[0], palette.text);
        try text(scene, r.x + 56, r.y + 31, r.w - 150, 14, row[1], palette.muted);
        try text(scene, r.x + r.w - 90, r.y + 20, 78, 14, row[2], if (row[2][0] == '+') palette.green else palette.muted);
        try hit(scene, r, .row_item, base_id + @as(u32, @intCast(index)));
        y += 64;
    }
}

fn renderCentered(scene: *ui.Scene, bounds: ui.Rect, action_id: u32) ui.RenderError!void {
    const center_x = bounds.x + bounds.w * 0.5;
    try fill(scene, ui.Rect.init(center_x - 28, bounds.y + 10, 56, 56), palette.row, 14);
    try text(scene, bounds.x + 24, bounds.y + 86, bounds.w - 48, 18, "Native component preview", palette.text);
    try text(scene, bounds.x + 24, bounds.y + 112, bounds.w - 48, 16, "Canvas-hosted, reusable, and compact.", palette.muted);
    if (action_id != preview_base_id) try button(scene, ui.Rect.init(center_x - 70, bounds.y + bounds.h - 42, 140, 34), "Continue", action_id, true);
}

fn renderControls(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    try switchRow(scene, bounds.x, bounds.y, bounds.w, "Public Statistics", true, base_id);
    try switchRow(scene, bounds.x, bounds.y + 58, bounds.w, "Email Notifications", true, base_id + 1);
    try slider(scene, ui.Rect.init(bounds.x, bounds.y + 134, bounds.w, 42), "Brightness", 0.82, base_id + 2);
    try slider(scene, ui.Rect.init(bounds.x, bounds.y + 190, bounds.w, 42), "Volume", 0.42, base_id + 3);
    try button(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 36, 156, 34), "Save Preferences", base_id + 4, true);
}

fn renderNavigation(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    const tabs = [_][]const u8{ "Dashboard", "Transactions", "Settings" };
    var x = bounds.x;
    for (tabs, 0..) |label, index| {
        const w: f32 = if (index == 1) 128 else 104;
        try button(scene, ui.Rect.init(x, bounds.y, w, 34), label, base_id + @as(u32, @intCast(index)), index == 0);
        x += w + 8;
    }
    var y = bounds.y + 58;
    const rows = [_][]const u8{ "Change transfer limit", "Scheduled transfers", "Direct Debits", "Security" };
    for (rows, 0..) |label, index| {
        const r = ui.Rect.init(bounds.x, y, bounds.w, 48);
        try fill(scene, r, palette.row, 7);
        try text(scene, r.x + 14, r.y + 16, r.w - 28, 15, label, palette.text);
        try hit(scene, r, .row_item, base_id + 20 + @as(u32, @intCast(index)));
        y += 58;
    }
}

fn renderCalendar(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 18, "May 2026", palette.text);
    const cell: f32 = @min(38, (bounds.w - 36) / 7);
    var day: usize = 1;
    var y = bounds.y + 34;
    for (0..3) |row| {
        var x = bounds.x;
        for (0..7) |col| {
            const r = ui.Rect.init(x, y, cell, cell);
            const active = row == 2 and col == 2;
            try fill(scene, r, if (active) palette.accent else palette.row, 8);
            try hit(scene, r, .button, base_id + @as(u32, @intCast(day)));
            day += 1;
            x += cell + 6;
        }
        y += cell + 6;
    }
    try renderList(scene, ui.Rect.init(bounds.x, y + 8, bounds.w, 116), base_id + 40);
}

fn renderSkeleton(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    var y = bounds.y;
    const widths = [_]f32{ 0.42, 0.68, 1.0, 0.92, 0.54 };
    for (widths) |factor| {
        try fill(scene, ui.Rect.init(bounds.x, y, bounds.w * factor, 18), palette.row, 9);
        y += 30;
    }
    try fill(scene, ui.Rect.init(bounds.x, y + 8, (bounds.w - 12) * 0.5, 38), palette.row, 8);
    try fill(scene, ui.Rect.init(bounds.x + (bounds.w + 12) * 0.5, y + 8, (bounds.w - 12) * 0.5, 38), palette.row, 8);
}

fn renderSecurity(scene: *ui.Scene, bounds: ui.Rect, base_id: u32) ui.RenderError!void {
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 120), palette.row, 10);
    try badge(scene, ui.Rect.init(bounds.x + bounds.w - 74, bounds.y + 14, 58, 24), "Locked", palette.danger);
    try slider(scene, ui.Rect.init(bounds.x, bounds.y + 142, bounds.w, 42), "Open", 0.35, base_id);
    try button(scene, ui.Rect.init(bounds.x, bounds.y + 206, 78, 34), "Open", base_id + 1, false);
    try button(scene, ui.Rect.init(bounds.x + 88, bounds.y + 206, 78, 34), "Half", base_id + 2, false);
    try button(scene, ui.Rect.init(bounds.x + 176, bounds.y + 206, 96, 34), "Closed", base_id + 3, true);
}

fn field(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id_value: u32) ui.RenderError!void {
    try fill(scene, bounds, palette.panel_alt, 7);
    try stroke(scene, bounds, palette.border, 7);
    try text(scene, bounds.x + 12, bounds.y + 14, bounds.w - 24, 14, label, palette.muted);
    try hit(scene, bounds, .input, id_value);
}

fn button(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id_value: u32, primary: bool) ui.RenderError!void {
    try fill(scene, bounds, if (primary) palette.text else palette.panel_alt, 7);
    try stroke(scene, bounds, if (primary) palette.text else palette.border, 7);
    try text(scene, bounds.x + 12, bounds.y + 10, bounds.w - 24, 14, label, if (primary) palette.panel else palette.text);
    try hit(scene, bounds, .button, id_value);
}

fn ghostButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id_value: u32) ui.RenderError!void {
    try text(scene, bounds.x + 10, bounds.y + 9, bounds.w - 20, 14, label, palette.text);
    try hit(scene, bounds, .button, id_value);
}

fn metricBox(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, value: []const u8) ui.RenderError!void {
    try fill(scene, bounds, palette.row, 8);
    try text(scene, bounds.x + 12, bounds.y + 14, bounds.w - 24, 14, label, palette.muted);
    try text(scene, bounds.x + 12, bounds.y + 38, bounds.w - 24, 18, value, palette.text);
}

fn switchRow(scene: *ui.Scene, x: f32, y: f32, w: f32, label: []const u8, checked: bool, id_value: u32) ui.RenderError!void {
    try text(scene, x, y + 5, w - 72, 16, label, palette.text);
    try text(scene, x, y + 25, w - 72, 14, "Native switch state", palette.muted);
    const track = ui.Rect.init(x + w - 54, y + 10, 48, 26);
    try fill(scene, track, if (checked) palette.text else palette.row, 13);
    const thumb_offset: f32 = if (checked) 24 else 3;
    try fill(scene, ui.Rect.init(track.x + thumb_offset, track.y + 3, 20, 20), palette.panel, 10);
    try hit(scene, track, .button, id_value);
}

fn slider(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, value: f32, id_value: u32) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 14, label, palette.text);
    const track = ui.Rect.init(bounds.x, bounds.y + 24, bounds.w, 6);
    try fill(scene, track, palette.row, 3);
    try fill(scene, ui.Rect.init(track.x, track.y, track.w * std.math.clamp(value, 0.0, 1.0), track.h), palette.accent, 3);
    try fill(scene, ui.Rect.init(track.x + track.w * std.math.clamp(value, 0.0, 1.0) - 7, track.y - 5, 16, 16), palette.panel, 8);
    try hit(scene, bounds, .button, id_value);
}

fn progress(scene: *ui.Scene, bounds: ui.Rect, value: f32) ui.RenderError!void {
    try fill(scene, bounds, palette.row, bounds.h * 0.5);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w * std.math.clamp(value, 0.0, 1.0), bounds.h), palette.accent, bounds.h * 0.5);
}

fn badge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) ui.RenderError!void {
    var fill_color = color;
    fill_color.a = 30;
    try fill(scene, bounds, fill_color, bounds.h * 0.5);
    try text(scene, bounds.x + 10, bounds.y + 7, bounds.w - 20, 12, label, color);
}

fn panel(scene: *ui.Scene, bounds: ui.Rect, radius: f32) ui.RenderError!void {
    try fill(scene, bounds, palette.panel, radius);
    try stroke(scene, bounds, palette.border, radius);
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, radius, 0);
}

fn stroke(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .border, radius, 0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.push(.{ .text = .{ .origin = ui.Rect.init(x, y, @max(1, w), @max(1, h)), .value = value, .color = color } });
}

fn hit(scene: *ui.Scene, bounds: ui.Rect, kind: ui.HitKind, id_value: u32) ui.RenderError!void {
    if (id_value == preview_base_id) return;
    try scene.pushHit(.{ .slot = 0, .kind = kind, .id = id_value, .bounds = bounds });
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

test "shadcn demo catalog mirrors github pages component count" {
    try std.testing.expectEqual(@as(usize, 57), demo_components.len);
    try std.testing.expectEqual(@as(usize, 57), nativeDemoCount());
    try std.testing.expect(findBySlug("button").?.hasNativeRenderer());
    try std.testing.expectEqualStrings("/docs/components/button", findBySlug("button").?.route);
    try std.testing.expectEqualStrings("/docs/components/accordion", findBySlug("accordion").?.route);
    try std.testing.expectEqualStrings("InputGroup", findBySlug("input-group").?.source_component);
    try std.testing.expectEqualStrings("input_group_node", findBySourceComponent("InputGroup").?.edge_builder);
    try std.testing.expect(countByCategory(.form) >= 10);
    try std.testing.expectEqual(@as(usize, 57), countByStatus(.exact_port));
}

test "github pages gallery renders component wall commands and hits" {
    var commands: [4096]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderGallery(&scene, ui.Rect.init(0, 0, 1440, 940), .{});

    const stats = scene.stats();
    try std.testing.expect(stats.rects > 150);
    try std.testing.expect(stats.text_quads > 120);
    try std.testing.expect(stats.hits > 60);
    try std.testing.expect(hasHit(scene.written(), preview_base_id + 908));
    try std.testing.expect(hasText(scene.written(), "Contribution History"));
    try std.testing.expect(hasText(scene.written(), "Stock Performance"));
}

test "github pages gallery scrolls through later component cards" {
    var commands: [4096]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try renderGallery(&scene, ui.Rect.init(0, 0, 900, 720), .{ .scroll_y = 900 });

    try std.testing.expect(hasText(scene.written(), "Power Usage"));
    try std.testing.expect(hasText(scene.written(), "Notifications"));
}

fn hasHit(commands: []const ui.Command, id_value: u32) bool {
    for (commands) |command| switch (command) {
        .hit => |value| if (value.id == id_value) return true,
        else => {},
    };
    return false;
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}
