const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const site_chrome = @import("site_chrome.zig");

pub const first_app_button_id: u32 = 50_100;

const header_h: f32 = site_chrome.header_h;
const content_wide: f32 = 1180.0;
const content_pad: f32 = 28.0;
const page_top_pad: f32 = 72.0;
const page_bottom_pad: f32 = 120.0;
const section_gap: f32 = 52.0;
const hero_min_h: f32 = 432.0;
const hero_split_w: f32 = 900.0;
const hero_panel_w: f32 = 430.0;
const hero_gap: f32 = 70.0;
const eyebrow_w: f32 = 96.0;
const card_gap: f32 = 18.0;
const card_h: f32 = 184.0;
const compact_card_h: f32 = 170.0;
const capability_h: f32 = 118.0;
const capability_gap: f32 = 14.0;
const terminal_h: f32 = 260.0;
const terminal_row_h: f32 = 24.0;
const terminal_pad: f32 = 24.0;
const node_map_grid: f32 = 28.0;
const node_map_dot_size: f32 = 2.0;
const node_map_dot_radius: f32 = 1.0;
const node_map_dot_alpha: u8 = 9;
const node_map_pattern_divisor: i32 = 8;

const palette = struct {
    const bg = ui.Color{ .r = 11, .g = 11, .b = 11 };
    const card = ui.Color{ .r = 18, .g = 18, .b = 18 };
    const card_alt = ui.Color{ .r = 24, .g = 24, .b = 24 };
    const border = ui.Color{ .r = 56, .g = 56, .b = 56 };
    const text = ui.Color{ .r = 242, .g = 242, .b = 242 };
    const dim = ui.Color{ .r = 154, .g = 154, .b = 154 };
    const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const blue = ui.Color{ .r = 96, .g = 165, .b = 250 };
    const amber = ui.Color{ .r = 245, .g = 158, .b = 11 };
    const danger = ui.Color{ .r = 248, .g = 113, .b = 113 };
    const neutral_soft = ui.Color{ .r = 30, .g = 30, .b = 30 };
};

const App = struct {
    name: []const u8,
    category: []const u8,
    status: []const u8,
    summary: []const u8,
    icon_value: icon.Icon,
};

const apps = [_]App{
    .{
        .name = "Chat",
        .category = "Messages",
        .status = "native",
        .summary = "Sealed messages addressed by identity instead of accounts.",
        .icon_value = .chat,
    },
    .{
        .name = "Vault",
        .category = "Storage",
        .status = "native",
        .summary = "Local sealed objects with explicit export and backup boundaries.",
        .icon_value = .lock,
    },
    .{
        .name = "Wallet",
        .category = "Receipts",
        .status = "design",
        .summary = "Clocked receipts for bandwidth, storage, compute, and settlement.",
        .icon_value = .wallet,
    },
    .{
        .name = "Files",
        .category = "Archive",
        .status = "design",
        .summary = "Portable personal archives with content hashes and user-owned keys.",
        .icon_value = .file,
    },
    .{
        .name = "Node Monitor",
        .category = "Runtime",
        .status = "native",
        .summary = "Inspect local resource budgets, child apps, routes, and receipts.",
        .icon_value = .activity,
    },
    .{
        .name = "Identity",
        .category = "Keys",
        .status = "native",
        .summary = "Create and delegate identity without making a cloud account root.",
        .icon_value = .key,
    },
};

const Capability = struct {
    title: []const u8,
    detail: []const u8,
    icon_value: icon.Icon,
};

const capabilities = [_]Capability{
    .{ .title = "Runs Locally", .detail = "The browser app starts from your device and receives only the resources delegated to it.", .icon_value = .cpu },
    .{ .title = "Sealed Storage", .detail = "Durable state is explicit, scoped, and portable instead of hidden in a vendor database.", .icon_value = .storage },
    .{ .title = "Signed Actions", .detail = "Identity, routes, and resource use become inspectable receipts instead of platform claims.", .icon_value = .shield },
};

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
};

pub fn contentHeight(width: f32) f32 {
    const bounds = ui.Rect.init(0.0, 0.0, @max(1.0, width), 1.0);
    return flow(null, bounds, .{}) catch unreachable;
}

pub fn render(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);

    const content = centered(bounds, content_wide);
    const page_y = header_h - state.scroll_y;
    try renderNodeMap(scene, ui.Rect.init(bounds.x, page_y, bounds.w, @max(bounds.h, hero_min_h + page_top_pad)));

    const page_clip = ui.Rect.init(bounds.x, bounds.y + header_h, bounds.w, @max(1.0, bounds.h - header_h));
    if (try scene.pushClip(page_clip)) {
        defer scene.popClip();
        _ = try flow(scene, ui.Rect.init(content.x, page_y, content.w, bounds.h), state);
    }

    try site_chrome.renderHeader(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content, .apps);
}

fn flow(scene: ?*ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!f32 {
    const hero_y = bounds.y + page_top_pad;
    const hero_h = heroHeight(bounds.w);
    if (scene) |target| try renderHero(target, ui.Rect.init(bounds.x, hero_y, bounds.w, hero_h), state);

    const apps_y = hero_y + hero_h + section_gap;
    const apps_h = appGridHeight(bounds.w);
    if (scene) |target| try renderAppGrid(target, ui.Rect.init(bounds.x, apps_y, bounds.w, apps_h));

    const caps_y = apps_y + apps_h + section_gap;
    const caps_h = capabilityGridHeight(bounds.w);
    if (scene) |target| try renderCapabilities(target, ui.Rect.init(bounds.x, caps_y, bounds.w, caps_h));

    return caps_y + caps_h + page_bottom_pad;
}

fn heroHeight(width: f32) f32 {
    return if (width >= hero_split_w) hero_min_h else hero_min_h + terminal_h + 42.0;
}

fn appGridHeight(width: f32) f32 {
    const cols = gridColumns(width, 3);
    const rows = (apps.len + cols - 1) / cols;
    const card_height = if (cols == 1) compact_card_h else card_h;
    return 78.0 + @as(f32, @floatFromInt(rows)) * card_height + @as(f32, @floatFromInt(rows - 1)) * card_gap;
}

fn capabilityGridHeight(width: f32) f32 {
    const cols = gridColumns(width, 3);
    const rows = (capabilities.len + cols - 1) / cols;
    return 74.0 + @as(f32, @floatFromInt(rows)) * capability_h + @as(f32, @floatFromInt(rows - 1)) * capability_gap;
}

fn renderHero(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
    _ = state;
    const split = bounds.w >= hero_split_w;
    const copy_w = if (split) bounds.w - hero_panel_w - hero_gap else bounds.w;
    const terminal = if (split)
        ui.Rect.init(bounds.x + bounds.w - hero_panel_w, bounds.y + 42.0, hero_panel_w, terminal_h)
    else
        ui.Rect.init(bounds.x, bounds.y + 320.0, bounds.w, terminal_h);

    try tag(scene, ui.Rect.init(bounds.x, bounds.y, eyebrow_w, 24.0), "APP STORE", palette.primary);
    try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + 52.0, copy_w, 112.0), "Apps That Respect The Machine", palette.text, .{
        .line_height = 52.0,
        .average_char_width = 24.0,
        .max_lines = 2,
    });
    try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + 184.0, copy_w, 86.0), "EdgeRun apps run inside explicit resource and authority budgets. They get identity, storage, routes, and compute from the parent runtime instead of taking the whole device.", palette.dim, .{
        .line_height = 22.0,
        .average_char_width = 10.0,
        .max_lines = 4,
    });
    try primaryButton(scene, ui.Rect.init(bounds.x, bounds.y + 294.0, 152.0, 42.0), "Browse Apps", site_chrome.apps_button_id);
    try outlineButton(scene, ui.Rect.init(bounds.x + 170.0, bounds.y + 294.0, 148.0, 42.0), "Read Docs", site_chrome.docs_button_id);

    try renderTerminal(scene, terminal);
}

fn renderTerminal(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.card, site_chrome.surface_radius);
    try scene.pushRect(bounds, palette.border, .border, site_chrome.surface_radius, 0.0);
    const top = ui.Rect.init(bounds.x, bounds.y, bounds.w, 38.0);
    try fill(scene, top, palette.card_alt, site_chrome.surface_radius);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + 37.0, bounds.w, 1.0), palette.border, 0.0);
    try iconQuad(scene, ui.Rect.init(bounds.x + 18.0, bounds.y + 11.0, 16.0, 16.0), .app, palette.primary);
    try text(scene, bounds.x + 44.0, bounds.y + 13.0, bounds.w - 66.0, 12.0, "edgerun app admission", palette.dim);

    const lines = [_]struct { []const u8, ui.Color }{
        .{ "request app: chat", palette.dim },
        .{ "grant memory: 64 MB", palette.primary },
        .{ "grant storage: sealed 256 MB", palette.primary },
        .{ "grant route: identity relay", palette.primary },
        .{ "grant notifications: none", palette.amber },
        .{ "receipt clocked: accepted", palette.text },
    };
    var y = bounds.y + 62.0;
    for (lines) |line| {
        try text(scene, bounds.x + terminal_pad, y, bounds.w - terminal_pad * 2.0, 14.0, line[0], line[1]);
        y += terminal_row_h;
    }
}

fn renderAppGrid(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 24.0, "Native App Surfaces", palette.text);
    try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + 34.0, bounds.w, 36.0), "A catalog is useful only when the runtime can explain what each app receives and what it can never touch.", palette.dim, .{
        .line_height = 18.0,
        .average_char_width = 9.2,
        .max_lines = 2,
    });

    const cols = gridColumns(bounds.w, 3);
    const card_height = if (cols == 1) compact_card_h else card_h;
    const card_w = (bounds.w - card_gap * @as(f32, @floatFromInt(cols - 1))) / @as(f32, @floatFromInt(cols));
    for (apps, 0..) |app, index| {
        const row = index / cols;
        const col = index % cols;
        const card = ui.Rect.init(
            bounds.x + @as(f32, @floatFromInt(col)) * (card_w + card_gap),
            bounds.y + 78.0 + @as(f32, @floatFromInt(row)) * (card_height + card_gap),
            card_w,
            card_height,
        );
        try renderAppCard(scene, card, app, first_app_button_id + @as(u32, @intCast(index)));
    }
}

fn renderAppCard(scene: *ui.Scene, bounds: ui.Rect, app: App, id: u32) ui.RenderError!void {
    try components.renderArticleCard(scene, bounds, .{
        .id = id,
        .category = app.category,
        .meta = app.status,
        .title = app.name,
        .summary = app.summary,
    }, .{ .style = siteStyle() });
    const icon_box = ui.Rect.init(bounds.x + bounds.w - 48.0, bounds.y + 54.0, 28.0, 28.0);
    try iconQuad(scene, icon_box, app.icon_value, palette.primary);
}

fn renderCapabilities(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 24.0, "Runtime Contract", palette.text);
    try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + 34.0, bounds.w, 36.0), "The page is not a marketing shell. These are the requirements every app surface has to satisfy before it belongs here.", palette.dim, .{
        .line_height = 18.0,
        .average_char_width = 9.2,
        .max_lines = 2,
    });

    const cols = gridColumns(bounds.w, 3);
    const card_w = (bounds.w - capability_gap * @as(f32, @floatFromInt(cols - 1))) / @as(f32, @floatFromInt(cols));
    for (capabilities, 0..) |capability, index| {
        const row = index / cols;
        const col = index % cols;
        const card = ui.Rect.init(
            bounds.x + @as(f32, @floatFromInt(col)) * (card_w + capability_gap),
            bounds.y + 74.0 + @as(f32, @floatFromInt(row)) * (capability_h + capability_gap),
            card_w,
            capability_h,
        );
        try fill(scene, card, palette.card, site_chrome.surface_radius);
        try scene.pushRect(card, palette.border, .border, site_chrome.surface_radius, 0.0);
        try iconQuad(scene, ui.Rect.init(card.x + 18.0, card.y + 18.0, 22.0, 22.0), capability.icon_value, palette.primary);
        try text(scene, card.x + 52.0, card.y + 20.0, card.w - 70.0, 16.0, capability.title, palette.text);
        try scene.pushWrappedText(ui.Rect.init(card.x + 18.0, card.y + 54.0, card.w - 36.0, 44.0), capability.detail, palette.dim, .{
            .line_height = 18.0,
            .average_char_width = 9.0,
            .max_lines = 3,
        });
    }
}

fn renderNodeMap(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    var x = bounds.x;
    while (x < bounds.x + bounds.w) : (x += node_map_grid) {
        var y = bounds.y;
        while (y < bounds.y + bounds.h) : (y += node_map_grid) {
            if (@mod(@as(i32, @intFromFloat(x + y)), node_map_pattern_divisor) == 0) {
                try fill(scene, ui.Rect.init(x, y, node_map_dot_size, node_map_dot_size), ui.Color{ .r = 255, .g = 255, .b = 255, .a = node_map_dot_alpha }, node_map_dot_radius);
            }
        }
    }
}

fn gridColumns(width: f32, max_cols: usize) usize {
    if (width < 700.0) return 1;
    if (width < 980.0) return @min(max_cols, 2);
    return max_cols;
}

fn centered(bounds: ui.Rect, max_w: f32) ui.Rect {
    const width = @min(max_w, @max(1.0, bounds.w - content_pad * 2.0));
    return ui.Rect.init(bounds.x + (bounds.w - width) * 0.5, bounds.y, width, bounds.h);
}

fn tag(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) ui.RenderError!void {
    try fill(scene, bounds, palette.neutral_soft, 5.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + 8.0, bounds.y + 6.0, bounds.w - 16.0, 10.0), label, color, .center);
}

fn primaryButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{
        .style = siteStyle(),
        .button_variant = .primary,
        .button_trailing_icon = .chevron_right,
    });
}

fn outlineButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{
        .style = siteStyle(),
        .button_variant = .outline,
    });
}

fn siteStyle() ui.Style {
    var resolved = site_chrome.style();
    resolved.panel = palette.card;
    resolved.row = palette.card_alt;
    return resolved;
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, r: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, r, 0.0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, .start);
}

fn iconQuad(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    try scene.pushIconQuad(.{ .bounds = bounds, .atlas_id = icon.atlasId(value), .color = color });
}

test "apps page renders catalog through native components" {
    var commands: [2048]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try render(&scene, ui.Rect.init(0, 0, 1280, 1500), .{});

    try std.testing.expect(hasTextPrefix(scene.written(), "Apps That Respect"));
    try std.testing.expect(hasText(scene.written(), "Native App Surfaces"));
    try std.testing.expect(hasText(scene.written(), "Runtime Contract"));
    try std.testing.expect(hasHit(scene.written(), site_chrome.apps_button_id));
    try std.testing.expect(hasHit(scene.written(), first_app_button_id));
    try std.testing.expect(hasIcon(scene.written(), .chat));
}

test "apps page content height grows for compact layout" {
    try std.testing.expect(contentHeight(390.0) > contentHeight(1280.0));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasTextPrefix(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.startsWith(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasHit(commands: []const ui.Command, id: u32) bool {
    for (commands) |command| switch (command) {
        .hit => |hit_command| if (hit_command.id == id) return true,
        else => {},
    };
    return false;
}

fn hasIcon(commands: []const ui.Command, value: icon.Icon) bool {
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.atlas_id == icon.atlasId(value)) return true,
        else => {},
    };
    return false;
}
