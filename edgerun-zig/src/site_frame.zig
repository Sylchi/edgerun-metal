const std = @import("std");
const component_gallery = @import("component_gallery.zig");
const interaction = @import("ui_interaction.zig");
const site_blog = @import("site_blog.zig");
const site_docs = @import("site_docs.zig");
const site_landing = @import("site_landing.zig");
const site_navigation = @import("site_navigation.zig");
const site_source = @import("site_source.zig");
const ui = @import("ui.zig");

pub const State = struct {
    route: site_navigation.Route = .{},
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    frame_ms: f32 = 0.0,
    public_identity: []const u8 = "",
    public_identity_ready: bool = false,
    component_layout: component_gallery.LayoutMode = .masonry,
    component_grid_gap: f32 = component_gallery.grid_gap_default,
    source: site_source.State = .{},
};

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    switch (state.route.view) {
        .landing => try site_landing.render(scene, collector, bounds, .{
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .frame_ms = state.frame_ms,
            .public_identity = state.public_identity,
            .public_identity_ready = state.public_identity_ready,
        }),
        .blog => try site_blog.render(scene, collector, bounds, .{
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .selected_post_id = state.route.selected_blog_post_id,
            .arc_filter_index = state.route.blog_arc_filter_index,
        }),
        .docs => try site_docs.render(scene, collector, bounds, .{
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .selected_doc_index = state.route.selected_doc_index,
        }),
        .components => try component_gallery.renderComponentGallery(scene, collector, bounds, .{
            .layout = state.component_layout,
            .grid_gap = state.component_grid_gap,
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .selected_component_index = state.route.selected_component_index,
        }),
        .source => try site_source.render(scene, collector, bounds, state.source),
    }
}

pub fn contentHeight(width: f32, state: State) f32 {
    return switch (state.route.view) {
        .landing => site_landing.contentHeight(width),
        .blog => if (state.route.selected_blog_post_id == 0)
            site_blog.indexContentHeightFiltered(width, state.route.blog_arc_filter_index)
        else
            site_blog.postContentHeight(width, state.route.selected_blog_post_id),
        .docs => site_docs.contentHeightForState(width, .{ .selected_doc_index = state.route.selected_doc_index }),
        .components => component_gallery.contentHeightForState(width, .{
            .layout = state.component_layout,
            .grid_gap = state.component_grid_gap,
            .scroll_y = state.scroll_y,
            .hover_x = state.hover_x,
            .hover_y = state.hover_y,
            .selected_component_index = state.route.selected_component_index,
        }),
        .source => site_source.contentHeight(width, state.source),
    };
}

test "site frame renders every top level route through one scene builder" {
    const routes = [_]site_navigation.Route{
        .{ .view = .landing },
        .{ .view = .blog },
        .{ .view = .docs },
        .{ .view = .docs, .selected_doc_index = site_docs.indexBySlug("media") },
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

test "site frame renders every component route from the shared catalog" {
    for (component_gallery.component_catalog, 0..) |_, index| {
        var commands: [4096]ui.Command = undefined;
        var regions: [4096]interaction.Region = undefined;
        var clips: [64]ui.Rect = undefined;
        var scene = ui.Scene.initWithClips(&commands, &clips);
        var collector = interaction.Collector.init(&regions);
        try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 800), .{
            .route = .{
                .view = .components,
                .selected_component_index = index,
            },
        });
        try std.testing.expect(scene.written().len != 0);
    }
}

test "site frame owns content height for route state" {
    const width: f32 = 1280.0;
    try std.testing.expectEqual(site_landing.contentHeight(width), contentHeight(width, .{ .route = .{ .view = .landing } }));
    try std.testing.expectEqual(site_blog.indexContentHeight(width), contentHeight(width, .{ .route = .{ .view = .blog } }));
    try std.testing.expectEqual(site_blog.postContentHeight(width, site_blog.postIdAt(0)), contentHeight(width, .{ .route = .{ .view = .blog, .selected_blog_post_id = site_blog.postIdAt(0) } }));
    try std.testing.expectEqual(site_docs.contentHeight(width), contentHeight(width, .{ .route = .{ .view = .docs } }));
    try std.testing.expectEqual(
        site_docs.contentHeightForState(width, .{ .selected_doc_index = site_docs.indexBySlug("media") }),
        contentHeight(width, .{ .route = .{ .view = .docs, .selected_doc_index = site_docs.indexBySlug("media") } }),
    );
    try std.testing.expectEqual(site_source.contentHeight(width, .{}), contentHeight(width, .{ .route = .{ .view = .source } }));

    const button_index = component_gallery.indexBySlug("button").?;
    try std.testing.expectEqual(
        component_gallery.contentHeightForState(width, .{ .selected_component_index = button_index }),
        contentHeight(width, .{ .route = .{ .view = .components, .selected_component_index = button_index } }),
    );
}

test "host render callers do not bypass the shared site frame builder" {
    try expectNoDirectSiteRenderImports(@embedFile("ui_browser.zig"));
    try expectNoDirectSiteRenderImports(@embedFile("wayland_window_host.zig"));
    try expectNoDirectSiteRenderImports(@embedFile("wayland_egl_host.zig"));
    try expectNoDirectSiteRenderImports(@embedFile("drm_gbm_host.zig"));
}

fn expectNoDirectSiteRenderImports(source: []const u8) !void {
    const forbidden = [_][]const u8{
        "site_landing.render(",
        "site_blog.render(",
        "site_docs.render(",
        "component_gallery.renderComponentGallery(",
    };
    for (forbidden) |needle| {
        try std.testing.expect(std.mem.indexOf(u8, source, needle) == null);
    }
}
