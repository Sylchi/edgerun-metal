const std = @import("std");
const component_gallery = @import("component_gallery.zig");
const components = @import("ui_components.zig");
const icon = @import("icon.zig");
const interaction = @import("ui_interaction.zig");
const app_blog = @import("app_blog.zig");
const app_chrome = @import("app_chrome.zig");
const app_docs = @import("app_docs.zig");
const app_landing = @import("app_landing.zig");
const app_navigation = @import("app_navigation.zig");
const app_source = @import("app_source.zig");
const design = @import("app_design.zig");
const ui = @import("ui.zig");
const ui_overlay = @import("ui_overlay.zig");

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
    component_layout: component_gallery.LayoutMode = .masonry,
    component_grid_gap: f32 = component_gallery.grid_gap_default,
    source: app_source.State = .{},
    context_menu: ContextMenu = .{},
};

pub const ContextMenu = struct {
    open: bool = false,
    x: f32 = 0.0,
    y: f32 = 0.0,
    source_path: []const u8 = "",
};

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try renderWorkspace(scene, collector, bounds, state);
    var overlay_commands: [overlay_command_capacity]ui.Command = undefined;
    var overlay_regions: [overlay_region_capacity]interaction.Region = undefined;
    var overlay_entries: [overlay_entry_capacity]ui_overlay.Entry = undefined;
    var overlay_host = ui_overlay.Host.init(&overlay_commands, &overlay_regions, &overlay_entries);
    if (state.context_menu.open) try renderContextMenu(&overlay_host, bounds, state.context_menu);
    try overlay_host.flush(scene, collector);
}

pub fn contentHeight(width: f32, state: State) f32 {
    return switch (state.route.view) {
        .landing => app_landing.contentHeight(width),
        .blog => if (state.route.selected_blog_post_id == 0)
            app_blog.indexContentHeightFiltered(width, state.route.blog_arc_filter_index)
        else
            app_blog.postContentHeight(width, state.route.selected_blog_post_id),
        .docs => app_docs.contentHeightForState(width, .{ .selected_doc_index = state.route.selected_doc_index, .selected_component_index = state.route.selected_component_index }),
        .components => workspace_content_pad * 2.0 + component_gallery.docsContentHeight(@max(1.0, width - workspace_content_pad * 2.0), state.route.selected_component_index),
        .source => app_source.contentHeight(width, state.source),
    };
}

fn renderWorkspace(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try scene.pushRect(bounds, design.palette.bg, .fill, 0.0, 0.0);
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

fn renderWorkspaceTop(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    switch (state.route.view) {
        .source => try app_source.renderWorkspaceTopBar(scene, collector, bounds, state.source),
        else => {
            try scene.pushRect(bounds, workspace_sidebar_bg, .fill, 0.0, 0.0);
            try scene.pushRect(ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), design.palette.border, .fill, 0.0, 0.0);
            try scene.pushAlignedText(ui.Rect.init(bounds.x + 16.0, bounds.y + 18.0, bounds.w - 32.0, 16.0), statusText(state.route), design.palette.text, .start);
        },
    }
}

fn renderWorkspaceRail(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, active: app_navigation.View) !void {
    try scene.pushRect(bounds, workspace_rail_bg, .fill, 0.0, 0.0);
    const items = [_]struct { id: u32, icon_value: icon.Icon, label: []const u8, view: app_navigation.View }{
        .{ .id = app_chrome.source_button_id, .icon_value = .code, .label = "Source", .view = .source },
        .{ .id = app_docs.component_catalog_button_id, .icon_value = .app, .label = "Components", .view = .components },
        .{ .id = app_chrome.docs_button_id, .icon_value = .file, .label = "Docs", .view = .docs },
        .{ .id = app_chrome.blog_button_id, .icon_value = .terminal, .label = "Academy", .view = .blog },
    };
    var y = bounds.y + workspace_rail_pad;
    for (items) |item| {
        const item_bounds = ui.Rect.init(bounds.x + 6.0, y, bounds.w - 12.0, workspace_icon_button);
        const component = components.Component{ .icon_button = .{
            .id = item.id,
            .label = item.label,
            .icon_value = item.icon_value,
            .variant = if (active == item.view) .secondary else .ghost,
        } };
        try components.renderComponent(scene, item_bounds, component, .{ .style = design.style() });
        try components.collectComponentInteractions(collector, item_bounds, component);
        if (active == item.view) try scene.pushRect(ui.Rect.init(bounds.x, item_bounds.y + 5.0, 2.0, item_bounds.h - 10.0), design.palette.primary, .fill, 0.0, 0.0);
        y += workspace_icon_button + 8.0;
    }
}

fn renderWorkspaceSidebar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const route = state.route;
    if (route.view == .source) {
        try app_source.renderWorkspaceSidebar(scene, collector, bounds, state.source);
        return;
    }
    try scene.pushRect(bounds, workspace_sidebar_bg, .fill, 0.0, 0.0);
    try scene.pushRect(ui.Rect.init(bounds.x + bounds.w - 1.0, bounds.y, 1.0, bounds.h), design.palette.border, .fill, 0.0, 0.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + 16.0, bounds.y + 14.0, bounds.w - 32.0, 16.0), "EDGERUN", design.palette.text, .start);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + 16.0, bounds.y + 36.0, bounds.w - 32.0, 14.0), sidebarDetail(route), design.palette.muted, .start);
    var y = bounds.y + 68.0;
    const rows = [_]struct { id: u32, title: []const u8, detail: []const u8, view: app_navigation.View }{
        .{ .id = app_chrome.source_button_id, .title = "Source", .detail = "edit app workspace", .view = .source },
        .{ .id = app_docs.component_catalog_button_id, .title = "Components", .detail = "edit and preview system", .view = .components },
        .{ .id = app_chrome.docs_button_id, .title = "Docs", .detail = "manual inside workspace", .view = .docs },
        .{ .id = app_chrome.blog_button_id, .title = "Academy", .detail = "lessons inside workspace", .view = .blog },
    };
    for (rows) |row| {
        const row_bounds = ui.Rect.init(bounds.x + 10.0, y, bounds.w - 20.0, 42.0);
        const component = components.Component{ .row_item = .{ .id = row.id, .title = row.title, .detail = row.detail } };
        try components.renderComponent(scene, row_bounds, component, .{
            .style = design.style(),
            .control = .{ .active = route.view == row.view },
        });
        try components.collectComponentInteractions(collector, row_bounds, component);
        y += 46.0;
    }
}

fn renderWorkspaceMain(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try scene.pushRect(bounds, workspace_main_bg, .fill, 0.0, 0.0);
    if (try scene.pushClip(bounds)) {
        defer scene.popClip();
        switch (state.route.view) {
            .source => try app_source.renderWorkspace(scene, collector, bounds, state.source),
            .landing => try app_landing.render(scene, collector, shiftedPageBounds(bounds), .{
                .scroll_y = state.scroll_y,
                .hover_x = state.hover_x,
                .hover_y = state.hover_y,
                .frame_ms = state.frame_ms,
                .public_identity = state.public_identity,
                .public_identity_ready = state.public_identity_ready,
            }),
            .blog => try app_blog.render(scene, collector, shiftedPageBounds(bounds), .{
                .scroll_y = state.scroll_y,
                .hover_x = state.hover_x,
                .hover_y = state.hover_y,
                .selected_post_id = state.route.selected_blog_post_id,
                .arc_filter_index = state.route.blog_arc_filter_index,
            }),
            .docs => try app_docs.render(scene, collector, shiftedPageBounds(bounds), .{
                .scroll_y = state.scroll_y,
                .hover_x = state.hover_x,
                .hover_y = state.hover_y,
                .selected_doc_index = state.route.selected_doc_index,
                .selected_component_index = state.route.selected_component_index,
            }),
            .components => try component_gallery.renderDocsContent(
                scene,
                collector,
                workspaceContentBounds(bounds, state.scroll_y),
                state.route.selected_component_index,
                state.hover_x,
                state.hover_y,
            ),
        }
    }
}

fn renderWorkspaceStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    if (state.route.view == .source) {
        try app_source.renderWorkspaceStatus(scene, bounds, state.source);
        return;
    }
    try scene.pushRect(bounds, workspace_status_bg, .fill, 0.0, 0.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + 12.0, bounds.y + 5.0, bounds.w - 24.0, 14.0), statusText(state.route), ui.Color{ .r = 255, .g = 255, .b = 255 }, .start);
}

fn shiftedPageBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y - app_chrome.header_h, bounds.w, bounds.h + app_chrome.header_h);
}

fn workspaceContentBounds(bounds: ui.Rect, scroll_y: f32) ui.Rect {
    return ui.Rect.init(
        bounds.x + workspace_content_pad,
        bounds.y + workspace_content_pad - scroll_y,
        @max(1.0, bounds.w - workspace_content_pad * 2.0),
        @max(1.0, bounds.h + scroll_y - workspace_content_pad * 2.0),
    );
}

fn sidebarDetail(route: app_navigation.Route) []const u8 {
    return switch (route.view) {
        .source => "workspace",
        .docs => "documentation",
        .blog => "academy",
        .components => "components",
        .landing => "overview",
    };
}

fn statusText(route: app_navigation.Route) []const u8 {
    return switch (route.view) {
        .source => "Source | app-owned VFS | compiler ready",
        .docs => "Docs | contained workspace tab",
        .blog => "Academy | contained workspace tab",
        .components => "Components | edit and preview workspace",
        .landing => "Overview | contained workspace tab",
    };
}

const overlay_command_capacity: usize = 64;
const overlay_region_capacity: usize = 32;
const overlay_entry_capacity: usize = 8;

fn renderContextMenu(host: *ui_overlay.Host, bounds: ui.Rect, menu: ContextMenu) !void {
    var scrim = host.begin(.scrim);
    try renderOverlayScrim(&scrim.scene, bounds);
    try scrim.finish();

    var panel_surface = host.begin(.menu);
    try renderContextMenuPanel(&panel_surface.scene, &panel_surface.collector, bounds, menu);
    try panel_surface.finish();
}

fn renderOverlayScrim(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try scene.pushRect(ui.Rect.init(bounds.x, bounds.y, bounds.w, bounds.h), ui.Color{ .r = 0, .g = 0, .b = 0, .a = 24 }, .fill, 0.0, 0.0);
}

fn renderContextMenuPanel(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, menu: ContextMenu) !void {
    const palette = design.palette;
    const menu_w: f32 = 280.0;
    const menu_h: f32 = 88.0;
    const pad: f32 = 10.0;
    const x = std.math.clamp(menu.x, bounds.x + pad, bounds.x + @max(pad, bounds.w - menu_w - pad));
    const y = std.math.clamp(menu.y, bounds.y + pad, bounds.y + @max(pad, bounds.h - menu_h - pad));
    const panel = ui.Rect.init(x, y, menu_w, menu_h);
    try scene.pushRect(panel, palette.shadow, .shadow, design.surface_radius, 16.0);
    try components.renderComponent(scene, panel, .{ .card = .{
        .title = "",
        .detail = "",
        .variant = .elevated,
    } }, .{ .style = design.style() });
    try scene.pushAlignedText(ui.Rect.init(panel.x + 14.0, panel.y + 12.0, panel.w - 28.0, 16.0), "Component source", palette.dim, .start);
    const row = ui.Rect.init(panel.x + 8.0, panel.y + 38.0, panel.w - 16.0, 40.0);
    const row_component = components.Component{ .row_item = .{
        .id = app_navigation.context_source_button_id,
        .title = "Open exact source",
        .detail = menu.source_path,
    } };
    try components.renderComponent(scene, row, row_component, .{ .style = design.style() });
    try components.collectComponentInteractions(collector, row, row_component);
}

test "app frame renders every top level route through one scene builder" {
    const routes = [_]app_navigation.Route{
        .{ .view = .landing },
        .{ .view = .blog },
        .{ .view = .docs },
        .{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("media") },
        .{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("component-system") },
        .{ .view = .components },
        .{ .view = .source },
    };
    for (routes) |route| {
        var commands: [4096]ui.Command = undefined;
        var regions: [4096]interaction.Region = undefined;
        var clips: [64]ui.Rect = undefined;
        var scene = ui.Scene.initWithClips(&commands, &clips);
        var collector = interaction.Collector.init(&regions);
        try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{
            .route = route,
            .public_identity = "test-principal",
            .public_identity_ready = true,
        });
        try std.testing.expect(scene.written().len != 0);
    }
}

test "app frame routes through workspace sidebar instead of top navbar" {
    var commands: [4096]ui.Command = undefined;
    var regions: [4096]interaction.Region = undefined;
    var clips: [64]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{ .route = .{ .view = .components } });

    try std.testing.expect(hasText(scene.written(), "Components"));
    try expectHit(collector.written(), app_chrome.source_button_id);
    try expectHit(collector.written(), app_docs.component_catalog_button_id);
    try expectHit(collector.written(), app_chrome.docs_button_id);
    try expectHit(collector.written(), app_chrome.blog_button_id);
    try expectNoHit(collector.written(), app_chrome.logo_button_id);
}

test "app frame uses source editor as workspace shell without nested chrome" {
    var commands: [8192]ui.Command = undefined;
    var regions: [4096]interaction.Region = undefined;
    var clips: [64]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{
        .route = .{ .view = .source },
        .source = .{
            .label = "src/app_runtime.zig",
            .source = "const std = @import(\"std\");\n",
            .workspace_bytes = 2048,
            .file_bytes = 28,
            .release_bytes = 4096,
            .status = "ready: editing src/app_runtime.zig inside the app-owned VFS object",
        },
    });

    const sidebar_x = workspace_rail_w;
    const main_x = workspace_rail_w + workspace_sidebar_w;
    const top_bottom = workspace_top_h;
    const status_top = 800.0 - workspace_status_h;

    try std.testing.expectEqual(@as(usize, 1), countText(scene.written(), "EXPLORER"));
    try std.testing.expectEqual(@as(usize, 1), countText(scene.written(), "EdgeRun Workspace"));
    try std.testing.expectEqual(@as(usize, 1), countText(scene.written(), "APP-OWNED VFS"));
    try std.testing.expectEqual(@as(usize, 0), countText(scene.written(), "artifact.wasm"));

    try expectHitWithin(collector.written(), app_source.compile_button_id, ui.Rect.init(workspace_rail_w, 0.0, 1280.0 - workspace_rail_w, workspace_top_h));
    try expectHitWithin(collector.written(), app_source.download_button_id, ui.Rect.init(workspace_rail_w, 0.0, 1280.0 - workspace_rail_w, workspace_top_h));
    try expectHitWithin(collector.written(), app_source.launch_button_id, ui.Rect.init(workspace_rail_w, 0.0, 1280.0 - workspace_rail_w, workspace_top_h));
    try expectHitWithin(collector.written(), app_source.reset_button_id, ui.Rect.init(workspace_rail_w, 0.0, 1280.0 - workspace_rail_w, workspace_top_h));
    try expectHitWithin(collector.written(), app_source.explorer_file_id_base, ui.Rect.init(sidebar_x, top_bottom, workspace_sidebar_w, status_top - top_bottom));
    try expectHitWithin(collector.written(), app_source.editor_textarea_id, ui.Rect.init(main_x, top_bottom, 1280.0 - main_x, status_top - top_bottom));
}

test "app frame renders source jump context menu as shared ui" {
    var commands: [4096]ui.Command = undefined;
    var regions: [256]interaction.Region = undefined;
    var clips: [32]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 900, 640), .{
        .route = .{ .view = .docs },
        .context_menu = .{
            .open = true,
            .x = 240.0,
            .y = 180.0,
            .source_path = "src/ui/components/Button.zig",
        },
    });

    try std.testing.expect(hasText(scene.written(), "Open exact source"));
    try std.testing.expect(hasText(scene.written(), "src/ui/components/Button.zig"));
    try expectHit(collector.written(), app_navigation.context_source_button_id);
}

test "app frame renders every component route from the shared catalog" {
    for (component_gallery.component_catalog, 0..) |_, index| {
        var commands: [4096]ui.Command = undefined;
        var regions: [4096]interaction.Region = undefined;
        var clips: [64]ui.Rect = undefined;
        var scene = ui.Scene.initWithClips(&commands, &clips);
        var collector = interaction.Collector.init(&regions);
        try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{
            .route = .{
                .view = .docs,
                .selected_doc_index = app_docs.indexBySlug("component-system"),
                .selected_component_index = index,
            },
        });
        try std.testing.expect(scene.written().len != 0);
    }
}

test "app frame owns content height for route state" {
    const width: f32 = 1280.0;
    try std.testing.expectEqual(app_landing.contentHeight(width), contentHeight(width, .{ .route = .{ .view = .landing } }));
    try std.testing.expectEqual(app_blog.indexContentHeight(width), contentHeight(width, .{ .route = .{ .view = .blog } }));
    try std.testing.expectEqual(app_blog.postContentHeight(width, app_blog.postIdAt(0)), contentHeight(width, .{ .route = .{ .view = .blog, .selected_blog_post_id = app_blog.postIdAt(0) } }));
    try std.testing.expectEqual(app_docs.contentHeight(width), contentHeight(width, .{ .route = .{ .view = .docs } }));
    try std.testing.expectEqual(
        app_docs.contentHeightForState(width, .{ .selected_doc_index = app_docs.indexBySlug("media") }),
        contentHeight(width, .{ .route = .{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("media") } }),
    );
    try std.testing.expectEqual(app_source.contentHeight(width, .{}), contentHeight(width, .{ .route = .{ .view = .source } }));

    const button_index = component_gallery.indexBySlug("button").?;
    try std.testing.expectEqual(
        workspace_content_pad * 2.0 + component_gallery.docsContentHeight(width - workspace_content_pad * 2.0, button_index),
        contentHeight(width, .{ .route = .{ .view = .components, .selected_component_index = button_index } }),
    );
}

test "host render callers do not bypass the shared app frame builder" {
    try expectNoDirectAppRenderImports(@embedFile("app_runtime.zig"));
    try expectNoDirectAppRenderImports(@embedFile("wayland_window_host.zig"));
    try expectNoDirectAppRenderImports(@embedFile("wayland_egl_host.zig"));
    try expectNoDirectAppRenderImports(@embedFile("drm_gbm_host.zig"));
}

fn expectNoDirectAppRenderImports(source: []const u8) !void {
    const forbidden = [_][]const u8{
        "app_landing.render(",
        "app_blog.render(",
        "app_docs.render(",
        "component_gallery.renderComponentGallery(",
    };
    for (forbidden) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, source, needle) == null);
    }
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text| if (std.mem.eql(u8, text.value, value)) return true,
        else => {},
    };
    return false;
}

fn countText(commands: []const ui.Command, value: []const u8) usize {
    var count: usize = 0;
    for (commands) |command| switch (command) {
        .text => |text| {
            if (std.mem.eql(u8, text.value, value)) count += 1;
        },
        else => {},
    };
    return count;
}

fn expectHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return;
    return error.MissingHit;
}

fn expectHitWithin(regions: []const interaction.Region, id: u32, bounds: ui.Rect) !void {
    for (regions) |region| {
        if (region.id != id) continue;
        try std.testing.expect(region.bounds.x >= bounds.x);
        try std.testing.expect(region.bounds.y >= bounds.y);
        try std.testing.expect(region.bounds.x + region.bounds.w <= bounds.x + bounds.w);
        try std.testing.expect(region.bounds.y + region.bounds.h <= bounds.y + bounds.h);
        return;
    }
    return error.MissingHit;
}

fn expectNoHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return error.UnexpectedHit;
}
