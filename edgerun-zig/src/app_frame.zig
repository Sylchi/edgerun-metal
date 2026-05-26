const std = @import("std");
const component_gallery = @import("component_gallery.zig");
const components = @import("ui_components.zig");
const interaction = @import("ui_interaction.zig");
const app_blog = @import("app_blog.zig");
const app_docs = @import("app_docs.zig");
const app_landing = @import("app_landing.zig");
const app_navigation = @import("app_navigation.zig");
const app_source = @import("app_source.zig");
const design = @import("app_design.zig");
const ui = @import("ui.zig");
const ui_overlay = @import("ui_overlay.zig");

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
    switch (state.route.view) {
        .landing => try app_landing.render(scene, collector, bounds, .{
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .frame_ms = state.frame_ms,
            .public_identity = state.public_identity,
            .public_identity_ready = state.public_identity_ready,
        }),
        .blog => try app_blog.render(scene, collector, bounds, .{
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .selected_post_id = state.route.selected_blog_post_id,
            .arc_filter_index = state.route.blog_arc_filter_index,
        }),
        .docs => try app_docs.render(scene, collector, bounds, .{
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .selected_doc_index = state.route.selected_doc_index,
            .selected_component_index = state.route.selected_component_index,
        }),
        .components => try app_docs.render(scene, collector, bounds, .{
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .selected_doc_index = app_docs.indexBySlug("component-system"),
            .selected_component_index = state.route.selected_component_index,
        }),
        .source => try app_source.render(scene, collector, bounds, state.source),
    }
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
        .components => app_docs.contentHeightForState(width, .{
            .selected_doc_index = app_docs.indexBySlug("component-system"),
            .selected_component_index = state.route.selected_component_index,
        }),
        .source => app_source.contentHeight(width, state.source),
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
        app_docs.contentHeightForState(width, .{ .selected_doc_index = app_docs.indexBySlug("component-system"), .selected_component_index = button_index }),
        contentHeight(width, .{ .route = .{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("component-system"), .selected_component_index = button_index } }),
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

fn expectHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return;
    return error.MissingHit;
}
