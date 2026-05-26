const std = @import("std");
const component_gallery = @import("component_gallery.zig");
const site_blog = @import("site_blog.zig");
const site_chrome = @import("site_chrome.zig");
const site_docs = @import("site_docs.zig");
const site_landing = @import("site_landing.zig");
const site_source = @import("site_source.zig");

pub const route_path_capacity: usize = 96;
pub const route_hash_capacity: usize = route_path_capacity + 1;

pub const RoutePath = struct {
    pub const root = "/";
    pub const academy = "/academy";
    pub const academy_detail_prefix = "/academy/";
    pub const docs = "/docs";
    pub const docs_detail_prefix = "/docs/";
    pub const component_catalog = "/docs/components";
    pub const component_detail_prefix = "/docs/components/";
    pub const source = "/source";
};

pub const View = enum(u32) {
    landing = 0,
    blog = 1,
    components = 2,
    docs = 3,
    source = 4,
};

pub const Route = struct {
    view: View = .landing,
    selected_blog_post_id: u32 = 0,
    blog_arc_filter_index: ?usize = null,
    selected_doc_index: ?usize = null,
    selected_component_index: ?usize = null,
};

pub const Action = enum(u32) {
    launch_app,
    reveal_identity,
    compile_source,
    download_source_release,
    launch_source_release,
    reset_source,
};

const PathKind = enum {
    root,
    academy,
    academy_detail,
    docs,
    docs_detail,
    component_catalog,
    component_detail,
    source,
    unknown,
};

pub fn fromPath(path: []const u8) Route {
    const trimmed = trimPath(path);
    return switch (pathKind(trimmed)) {
        .root => .{},
        .academy => blogIndex(null),
        .source => .{ .view = .source },
        .docs => .{ .view = .docs },
        .component_catalog => .{ .view = .components },
        .component_detail => .{ .view = .components, .selected_component_index = component_gallery.indexBySlug(trimmed[RoutePath.component_detail_prefix.len..]) },
        .docs_detail => .{ .view = .docs, .selected_doc_index = site_docs.indexBySlug(trimmed[RoutePath.docs_detail_prefix.len..]) },
        .academy_detail => academyPostRoute(trimmed[RoutePath.academy_detail_prefix.len..]),
        .unknown => .{},
    };
}

pub fn fromHit(hit_id: u32, current: Route) ?Route {
    return switch (hit_id) {
        site_chrome.logo_button_id,
        => .{},
        site_chrome.docs_button_id => .{ .view = .docs },
        site_chrome.blog_button_id,
        site_blog.all_lessons_button_id,
        site_docs.academy_button_id,
        => blogIndex(null),
        site_chrome.source_button_id => .{ .view = .source },
        site_docs.source_button_id => .{ .view = .source },
        site_docs.component_catalog_button_id => .{ .view = .components },
        site_blog.back_button_id => blogIndex(null),
        else => routeFromDynamicHit(hit_id, current),
    };
}

pub fn actionFromHit(hit_id: u32) ?Action {
    return switch (hit_id) {
        site_chrome.launch_button_id => .launch_app,
        site_landing.reveal_identity_button_id => .reveal_identity,
        site_source.compile_button_id => .compile_source,
        site_source.download_button_id => .download_source_release,
        site_source.launch_button_id => .launch_source_release,
        site_source.reset_button_id => .reset_source,
        else => null,
    };
}

pub fn pathFromHash(hash: []const u8) error{InvalidRouteHash}![]const u8 {
    if (hash.len == 0 or std.mem.eql(u8, hash, "#")) return "/";
    if (std.mem.startsWith(u8, hash, "#/")) return hash[1..];
    return error.InvalidRouteHash;
}

pub fn writePath(out: []u8, route: Route) error{RouteBufferTooSmall}!usize {
    const value = switch (route.view) {
        .landing => RoutePath.root,
        .blog => if (route.selected_blog_post_id == 0) RoutePath.academy else return writePostPath(out, route.selected_blog_post_id),
        .components => if (route.selected_component_index) |index| return writeComponentPath(out, index) else RoutePath.component_catalog,
        .docs => if (route.selected_doc_index) |index| return writeDocPath(out, index) else RoutePath.docs,
        .source => RoutePath.source,
    };
    if (value.len > out.len) return error.RouteBufferTooSmall;
    @memcpy(out[0..value.len], value);
    return value.len;
}

pub fn writeHash(out: []u8, route: Route) error{RouteBufferTooSmall}!usize {
    var path: [route_path_capacity]u8 = undefined;
    const path_len = try writePath(&path, route);
    if (path_len == 1 and path[0] == '/') return 0;
    if (path_len + 1 > out.len) return error.RouteBufferTooSmall;
    out[0] = '#';
    @memcpy(out[1 .. path_len + 1], path[0..path_len]);
    return path_len + 1;
}

pub fn trimPath(path: []const u8) []const u8 {
    if (path.len == 0) return "/";
    const query = std.mem.indexOfScalar(u8, path, '?') orelse path.len;
    const hash = std.mem.indexOfScalar(u8, path[0..query], '#') orelse query;
    const trimmed = path[0..hash];
    return if (trimmed.len == 0) "/" else trimmed;
}

fn routeFromDynamicHit(hit_id: u32, current: Route) ?Route {
    switch (current.view) {
        .components => if (component_gallery.indexByCatalogHit(hit_id)) |index| {
            return .{ .view = .components, .selected_component_index = index };
        },
        .blog => {
            if (site_blog.postById(hit_id) != null) {
                return .{ .view = .blog, .selected_blog_post_id = hit_id };
            }
            if (site_blog.arcFilterIndexById(hit_id)) |index| {
                return blogIndex(index);
            }
        },
        .docs => if (site_docs.indexByHit(hit_id)) |index| {
            if (site_docs.doc_pages[index].section == .source) return .{ .view = .source };
            return .{ .view = .docs, .selected_doc_index = if (index == 0) null else index };
        },
        .landing, .source => {},
    }
    return null;
}

fn blogIndex(filter_index: ?usize) Route {
    return .{ .view = .blog, .blog_arc_filter_index = filter_index };
}

fn academyPostRoute(raw: []const u8) Route {
    const raw_id = std.fmt.parseUnsigned(u32, raw, 10) catch return blogIndex(null);
    return .{
        .view = .blog,
        .selected_blog_post_id = if (site_blog.postById(raw_id) != null) raw_id else 0,
    };
}

fn pathKind(trimmed: []const u8) PathKind {
    if (std.mem.eql(u8, trimmed, RoutePath.root)) return .root;
    if (std.mem.eql(u8, trimmed, RoutePath.academy)) return .academy;
    if (std.mem.eql(u8, trimmed, RoutePath.source)) return .source;
    if (std.mem.eql(u8, trimmed, RoutePath.docs)) return .docs;
    if (std.mem.eql(u8, trimmed, RoutePath.component_catalog)) return .component_catalog;
    if (std.mem.startsWith(u8, trimmed, RoutePath.component_detail_prefix)) return .component_detail;
    if (std.mem.startsWith(u8, trimmed, RoutePath.docs_detail_prefix)) return .docs_detail;
    if (std.mem.startsWith(u8, trimmed, RoutePath.academy_detail_prefix)) return .academy_detail;
    return .unknown;
}

fn writePostPath(out: []u8, post_id: u32) error{RouteBufferTooSmall}!usize {
    const value = std.fmt.bufPrint(out, RoutePath.academy_detail_prefix ++ "{d}", .{post_id}) catch return error.RouteBufferTooSmall;
    return value.len;
}

fn writeComponentPath(out: []u8, index: usize) error{RouteBufferTooSmall}!usize {
    if (index >= component_gallery.component_catalog.len) return writePath(out, .{ .view = .components });
    const value = component_gallery.component_catalog[index].route;
    if (value.len > out.len) return error.RouteBufferTooSmall;
    @memcpy(out[0..value.len], value);
    return value.len;
}

fn writeDocPath(out: []u8, index: usize) error{RouteBufferTooSmall}!usize {
    if (index >= site_docs.doc_pages.len or index == 0) return writePath(out, .{ .view = .docs });
    const value = site_docs.doc_pages[index].route;
    if (value.len > out.len) return error.RouteBufferTooSmall;
    @memcpy(out[0..value.len], value);
    return value.len;
}

test "navigation parses browser and native site routes" {
    try std.testing.expectEqual(View.landing, fromPath("").view);
    try std.testing.expectEqual(View.blog, fromPath("/academy").view);
    try std.testing.expectEqual(View.landing, fromPath("/apps").view);
    try std.testing.expectEqual(View.source, fromPath("/source").view);
    try std.testing.expectEqual(View.docs, fromPath("/docs").view);
    try std.testing.expectEqual(View.docs, fromPath("/docs/media").view);
    try std.testing.expectEqual(site_docs.indexBySlug("media").?, fromPath("/docs/media").selected_doc_index.?);
    try std.testing.expectEqual(View.docs, fromPath("/docs/component-system").view);
    try std.testing.expectEqual(site_docs.indexBySlug("component-system").?, fromPath("/docs/component-system").selected_doc_index.?);
    try std.testing.expectEqual(View.components, fromPath("/docs/components").view);
    try std.testing.expectEqual(View.components, fromPath("/docs/components/button").view);
    try std.testing.expectEqual(component_gallery.indexBySlug("button").?, fromPath("/docs/components/button").selected_component_index.?);
    const post_id = site_blog.postIdAt(0);
    var post_path: [route_path_capacity]u8 = undefined;
    const post_path_text = try std.fmt.bufPrint(&post_path, "/academy/{d}", .{post_id});
    try std.testing.expectEqual(post_id, fromPath(post_path_text).selected_blog_post_id);
    try std.testing.expectEqual(@as(u32, 0), fromPath("/academy/not-a-post").selected_blog_post_id);
}

test "navigation writes browser hash routes from shared state" {
    var path: [route_path_capacity]u8 = undefined;
    var hash: [route_hash_capacity]u8 = undefined;

    try std.testing.expectEqual(@as(usize, 1), try writePath(&path, .{}));
    try std.testing.expectEqualStrings("/", path[0..1]);
    try std.testing.expectEqual(@as(usize, 0), try writeHash(&hash, .{}));

    const source = Route{ .view = .source };
    const source_len = try writePath(&path, source);
    try std.testing.expectEqualStrings("/source", path[0..source_len]);
    const source_hash_len = try writeHash(&hash, source);
    try std.testing.expectEqualStrings("#/source", hash[0..source_hash_len]);

    const docs = Route{ .view = .docs };
    const docs_len = try writePath(&path, docs);
    try std.testing.expectEqualStrings("/docs", path[0..docs_len]);
    const docs_hash_len = try writeHash(&hash, docs);
    try std.testing.expectEqualStrings("#/docs", hash[0..docs_hash_len]);

    const media = Route{ .view = .docs, .selected_doc_index = site_docs.indexBySlug("media") };
    const media_len = try writePath(&path, media);
    try std.testing.expectEqualStrings("/docs/media", path[0..media_len]);
    const media_hash_len = try writeHash(&hash, media);
    try std.testing.expectEqualStrings("#/docs/media", hash[0..media_hash_len]);

    const components = Route{ .view = .components };
    const components_len = try writePath(&path, components);
    try std.testing.expectEqualStrings("/docs/components", path[0..components_len]);
    const components_hash_len = try writeHash(&hash, components);
    try std.testing.expectEqualStrings("#/docs/components", hash[0..components_hash_len]);

    const button = Route{ .view = .components, .selected_component_index = component_gallery.indexBySlug("button") };
    const button_len = try writePath(&path, button);
    try std.testing.expectEqualStrings("/docs/components/button", path[0..button_len]);
    const button_hash_len = try writeHash(&hash, button);
    try std.testing.expectEqualStrings("#/docs/components/button", hash[0..button_hash_len]);
}

test "navigation maps shared hit ids to routes" {
    try std.testing.expectEqual(View.landing, fromHit(site_chrome.logo_button_id, .{}).?.view);
    try std.testing.expectEqual(View.docs, fromHit(site_chrome.docs_button_id, .{}).?.view);
    try std.testing.expectEqual(View.blog, fromHit(site_chrome.blog_button_id, .{}).?.view);
    try std.testing.expectEqual(View.source, fromHit(site_chrome.source_button_id, .{}).?.view);
    try std.testing.expectEqual(View.components, fromHit(site_docs.component_catalog_button_id, .{}).?.view);
    try std.testing.expectEqual(site_docs.indexBySlug("media").?, fromHit(site_docs.first_doc_page_button_id + @as(u32, @intCast(site_docs.indexBySlug("media").?)), .{ .view = .docs }).?.selected_doc_index.?);
    try std.testing.expectEqual(site_docs.indexBySlug("component-system").?, fromHit(site_docs.first_doc_page_button_id + @as(u32, @intCast(site_docs.indexBySlug("component-system").?)), .{ .view = .docs }).?.selected_doc_index.?);
    try std.testing.expectEqual(component_gallery.indexBySlug("button").?, fromHit(component_gallery.first_catalog_card_id + 7, .{ .view = .components }).?.selected_component_index.?);
    const post_id = site_blog.postIdAt(0);
    try std.testing.expectEqual(post_id, fromHit(post_id, .{ .view = .blog }).?.selected_blog_post_id);
    try std.testing.expect(fromHit(component_gallery.first_catalog_card_id + 7, .{}) == null);
    try std.testing.expect(fromHit(post_id, .{}) == null);
}

test "navigation maps shared hit ids to site actions" {
    try std.testing.expectEqual(Action.launch_app, actionFromHit(site_chrome.launch_button_id).?);
    try std.testing.expectEqual(Action.reveal_identity, actionFromHit(site_landing.reveal_identity_button_id).?);
    try std.testing.expectEqual(Action.compile_source, actionFromHit(site_source.compile_button_id).?);
    try std.testing.expectEqual(Action.download_source_release, actionFromHit(site_source.download_button_id).?);
    try std.testing.expectEqual(Action.launch_source_release, actionFromHit(site_source.launch_button_id).?);
    try std.testing.expectEqual(Action.reset_source, actionFromHit(site_source.reset_button_id).?);
    try std.testing.expect(actionFromHit(site_chrome.docs_button_id) == null);
}
