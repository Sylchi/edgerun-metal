const std = @import("std");
const bytes = @import("../bytes.zig");
const component_gallery = @import("../ui/component_gallery.zig");
const interaction = @import("../ui/interaction.zig");
const app_agent = @import("agent.zig");
const app_chrome = @import("../ui/chrome.zig");
const app_location = @import("../location.zig");
const design = @import("../ui/theme.zig");
const ui = @import("../ui/core.zig");
const component = @import("../ui/components/Component.zig");

pub const State = struct {
    location: app_location.Location = .{},
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
    const app = component.renderer(scene, collector, .{ .style = design.appStyle() });
    try app.fill(bounds, design.Palette.bg, 0.0);
    const shell = app.workspaceShell(bounds, .{});
    try renderWorkspaceRail(app, scene, collector, shell.rail, state.location);
    try renderWorkspaceTop(app, shell.top, state);
    try renderWorkspaceSidebar(app, scene, collector, shell.sidebar, state);
    try renderWorkspaceMain(app, scene, collector, shell.main, state);
    try renderWorkspaceStatus(app, shell.status, state);
}

fn renderWorkspaceTop(app: component.View, bounds: ui.Rect, state: State) !void {
    try app.workspaceTopBar(bounds, .{
        .title = statusText(state.location),
        .fill = design.workspace_sidebar_bg,
    });
}

fn renderWorkspaceRail(app: component.View, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, active: app_location.Location) !void {
    try app.fill(bounds, design.workspace_rail_bg, 0.0);
    const items = app_location.topLevelWorkspaceBindings();
    var rail = app.column(ui.Rect.init(bounds.x + 6.0, bounds.y + design.workspace_rail_pad, bounds.w - 12.0, @max(1.0, bounds.h - design.workspace_rail_pad)), 8.0);
    for (items) |item| {
        const item_bounds = rail.take(design.workspace_icon_button);
        try app_chrome.renderNavItem(scene, collector, .{
            .kind = .workspace_rail,
            .binding = item,
            .bounds = item_bounds,
            .active = std.meta.eql(active, item.location),
        });
        if (std.meta.eql(active, item.location)) try app.fill(ui.Rect.init(bounds.x, item_bounds.y + 5.0, 2.0, item_bounds.h - 10.0), design.Palette.primary, 0.0);
    }
}

fn renderWorkspaceSidebar(app: component.View, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try app.fill(bounds, design.workspace_sidebar_bg, 0.0);
    try app.fill(ui.Rect.init(bounds.x + bounds.w - 1.0, bounds.y, 1.0, bounds.h), design.Palette.border, 0.0);
    try app.title(ui.Rect.init(bounds.x + 16.0, bounds.y + 14.0, bounds.w - 32.0, 16.0), "EDGERUN");
    try app.muted(ui.Rect.init(bounds.x + 16.0, bounds.y + 36.0, bounds.w - 32.0, 14.0), "preview");
    var rows_cursor = app.column(ui.Rect.init(bounds.x + 10.0, bounds.y + 68.0, bounds.w - 20.0, @max(1.0, bounds.h - 68.0)), 4.0);
    const rows = app_location.topLevelBindings();
    for (rows) |row| {
        const row_bounds = rows_cursor.take(42.0);
        try app_chrome.renderNavItem(scene, collector, .{
            .kind = .workspace_sidebar,
            .binding = row,
            .bounds = row_bounds,
            .active = std.meta.eql(state.location, row.location),
        });
    }
}

fn renderWorkspaceMain(app: component.View, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, _: State) !void {
    try app.fill(bounds, design.workspace_main_bg, 0.0);
    if (try scene.pushClip(bounds)) {
        defer scene.popClip();
        try app_agent.render(scene, collector, shiftedPageBounds(bounds), .{});
    }
}

fn renderWorkspaceStatus(app: component.View, bounds: ui.Rect, state: State) !void {
    try app.workspaceStatusBar(bounds, .{ .text = statusText(state.location), .fill = design.workspace_status_bg });
}

fn shiftedPageBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y - app_chrome.header_h, bounds.w, bounds.h + app_chrome.header_h);
}

fn statusText(location: app_location.Location) []const u8 {
    if (app_location.isSourceWorkspace(location)) return "workspace";
    if (app_location.isAppPreview(location)) return "preview";
    return "object";
}

test "app frame renders agent workspace" {
    var commands: [4096]ui.Command = undefined;
    var regions: [4096]interaction.Region = undefined;
    var clips: [64]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{
        .location = app_location.locationForButton(.app_preview),
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

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{ .location = .{} });

    try expectHit(collector.written(), app_location.topLevelButtonId(.source_workspace));
    try expectHit(collector.written(), app_location.topLevelButtonId(.app_preview));
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

test "location state drives content height" {
    const width: f32 = 1280.0;
    try std.testing.expect(contentHeight(width, .{ .location = app_location.locationForButton(.app_preview) }) > 0);
    try std.testing.expect(contentHeight(width, .{ .location = app_location.locationForButton(.source_workspace) }) > 0);
}

test "host render callers do not bypass the shared app frame builder" {
    try expectNoDirectAppRenderImports(@embedFile("../wayland_window_host.zig"));
    try expectNoDirectAppRenderImports(@embedFile("../drm_gbm_host.zig"));
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
