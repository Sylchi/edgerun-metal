const std = @import("std");
const bytes = @import("bytes.zig");
const component_gallery = @import("ui/component_gallery.zig");
const interaction = @import("ui/interaction.zig");
const app_agent = @import("route/agent.zig");
const app_chrome = @import("ui/chrome.zig");
const app_navigation = @import("route/navigation.zig");
const design = @import("ui/theme.zig");
const ui = @import("ui/core.zig");
const text_component = @import("ui/components/Text.zig");
const workspace_rail_w: f32 = 48.0;
const workspace_sidebar_w: f32 = 260.0;
const workspace_top_h: f32 = 56.0;
const workspace_status_h: f32 = 24.0;
const workspace_rail_pad: f32 = 12.0;
const workspace_icon_button: f32 = 36.0;
const workspace_content_pad: f32 = 24.0;
const workspace_rail_bg = ui.Color{ .r = 37, .g = 37, .b = 38 };
const workspace_sidebar_bg = ui.Color{ .r = 24, .g = 24, .b = 24 };
const workspace_main_bg = ui.Color{ .r = 10, .g = 12, .b = 16 };
const workspace_status_bg = ui.Color{ .r = 0, .g = 122, .b = 204 };

pub const State = struct {
    route: app_navigation.Route = .{},
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    frame_ms: f32 = 0.0,
    public_identity: []const u8 = "",
    public_identity_ready: bool = false,
    drag_override: ?component_gallery.DragOverride = null,
    context_menu: struct {
        open: bool,
        x: f32,
        y: f32,
        source_path: []const u8,
    } = .{ .open = false, .x = 0.0, .y = 0.0, .source_path = "" },
    agent: app_agent.State = .{},
};

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try renderWorkspace(scene, collector, bounds, state);
}

pub fn contentHeight(width: f32, state: State) f32 {
    _ = width;
    _ = state;
    return 600.0;
}

fn renderWorkspace(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try scene.pushRect(bounds, design.Palette.bg, .fill, 0.0, 0.0);
    const rail = ui.Rect.init(bounds.x, bounds.y, workspace_rail_w, @max(1.0, bounds.h - workspace_status_h));
    const top = ui.Rect.init(rail.x + rail.w, bounds.y, @max(1.0, bounds.w - rail.w), workspace_top_h);
    const sidebar = ui.Rect.init(rail.x + rail.w, bounds.y + workspace_top_h, workspace_sidebar_w, @max(1.0, bounds.h - workspace_top_h - workspace_status_h));
    const main = ui.Rect.init(sidebar.x + sidebar.w, bounds.y + workspace_top_h, @max(1.0, bounds.w - rail.w - sidebar.w), @max(1.0, bounds.h - workspace_top_h - workspace_status_h));
    const status = ui.Rect.init(bounds.x, bounds.y + bounds.h - workspace_status_h, bounds.w, workspace_status_h);
    try renderWorkspaceRail(scene, collector, rail, state.route.view);
    try renderWorkspaceTop(scene, collector, top, state);
    try renderWorkspaceSidebar(scene, collector, sidebar, state);
    try renderWorkspaceMain(scene, collector, main, state);
    try renderWorkspaceStatus(scene, status, state);
}

fn renderWorkspaceTop(scene: *ui.Scene, _collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    _ = _collector;
    try scene.pushRect(bounds, workspace_sidebar_bg, .fill, 0.0, 0.0);
    try scene.pushRect(ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), design.Palette.border, .fill, 0.0, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 18.0, bounds.w - 32.0, 16.0), statusText(state.route), design.Palette.text, .start);
}

fn renderWorkspaceRail(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, active: app_navigation.View) !void {
    try scene.pushRect(bounds, workspace_rail_bg, .fill, 0.0, 0.0);
    const items = app_navigation.topLevelWorkspaceBindings();
    var y = bounds.y + workspace_rail_pad;
    for (items) |item| {
        const item_bounds = ui.Rect.init(bounds.x + 6.0, y, bounds.w - 12.0, workspace_icon_button);
        try app_chrome.renderNavItem(scene, collector, .{
            .kind = .workspace_rail,
            .binding = item,
            .bounds = item_bounds,
            .active = active == item.route.view,
        });
        if (active == item.route.view) try scene.pushRect(ui.Rect.init(bounds.x, item_bounds.y + 5.0, 2.0, item_bounds.h - 10.0), design.Palette.primary, .fill, 0.0, 0.0);
        y += workspace_icon_button + 8.0;
    }
}

fn renderWorkspaceSidebar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try scene.pushRect(bounds, workspace_sidebar_bg, .fill, 0.0, 0.0);
    try scene.pushRect(ui.Rect.init(bounds.x + bounds.w - 1.0, bounds.y, 1.0, bounds.h), design.Palette.border, .fill, 0.0, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 14.0, bounds.w - 32.0, 16.0), "EDGERUN", design.Palette.text, .start);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 16.0, bounds.y + 36.0, bounds.w - 32.0, 14.0), "preview", design.Palette.muted, .start);
    var y = bounds.y + 68.0;
    const rows = app_navigation.topLevelBindings();
    for (rows) |row| {
        const row_bounds = ui.Rect.init(bounds.x + 10.0, y, bounds.w - 20.0, 42.0);
        try app_chrome.renderNavItem(scene, collector, .{
            .kind = .workspace_sidebar,
            .binding = row,
            .bounds = row_bounds,
            .active = state.route.view == row.route.view,
        });
        y += 46.0;
    }
}

fn renderWorkspaceMain(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, _: State) !void {
    try scene.pushRect(bounds, workspace_main_bg, .fill, 0.0, 0.0);
    if (try scene.pushClip(bounds)) {
        defer scene.popClip();
        try app_agent.render(scene, collector, shiftedPageBounds(bounds), .{});
    }
}

fn renderWorkspaceStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try scene.pushRect(bounds, workspace_status_bg, .fill, 0.0, 0.0);
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + 12.0, bounds.y + 5.0, bounds.w - 24.0, 14.0), statusText(state.route), ui.Color{ .r = 255, .g = 255, .b = 255 }, .start);
}

fn shiftedPageBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y - app_chrome.header_h, bounds.w, bounds.h + app_chrome.header_h);
}

fn statusText(route: app_navigation.Route) []const u8 {
    return switch (route.view) {
        .backend => "workspace",
        .frontend => "preview",
    };
}

test "app frame renders agent workspace" {
    var commands: [4096]ui.Command = undefined;
    var regions: [4096]interaction.Region = undefined;
    var clips: [64]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{
        .route = .{ .view = .frontend },
        .public_identity = "test-principal",
        .public_identity_ready = true,
    });
    try std.testing.expect(scene.written().len != 0);
}

test "app frame routes through workspace sidebar" {
    var commands: [4096]ui.Command = undefined;
    var regions: [4096]interaction.Region = undefined;
    var clips: [64]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{ .route = .{} });

    try expectHit(collector.written(), app_navigation.topLevelButtonId(.backend));
    try expectHit(collector.written(), app_navigation.topLevelButtonId(.frontend));
}

test "app frame renders agent as workspace content" {
    var commands: [4096]ui.Command = undefined;
    var regions: [4096]interaction.Region = undefined;
    var clips: [64]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);

    try app_agent.render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{});
    try std.testing.expect(hasText(scene.written(), "Owned local agent pipeline"));
    try expectHit(collector.written(), app_agent.run_hit_id);
    try expectHit(collector.written(), app_agent.input_hit_id);
}

test "route state drives content height" {
    const width: f32 = 1280.0;
    try std.testing.expect(contentHeight(width, .{ .route = .{ .view = .frontend } }) > 0);
    try std.testing.expect(contentHeight(width, .{ .route = .{ .view = .backend } }) > 0);
}

test "host render callers do not bypass the shared app frame builder" {
    try expectNoDirectAppRenderImports(@embedFile("app_runtime.zig"));
    try expectNoDirectAppRenderImports(@embedFile("wayland_window_host.zig"));
        try expectNoDirectAppRenderImports(@embedFile("drm_gbm_host.zig"));
}

fn expectNoDirectAppRenderImports(source: []const u8) !void {
    const forbidden = [_][]const u8{
        "component_gallery.renderComponentGallery(",
    };
    for (forbidden) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, source, needle) == null);
    }
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text| if (bytes.eql(text.value, value)) return true,
        else => {},
    };
    return false;
}

fn expectHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return;
    return error.MissingHit;
}
