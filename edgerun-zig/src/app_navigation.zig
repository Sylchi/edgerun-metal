const std = @import("std");
const component_gallery = @import("component_gallery.zig");
const app_blog = @import("app_blog.zig");
const app_chrome = @import("app_chrome.zig");
const app_docs = @import("app_docs.zig");
const app_landing = @import("app_landing.zig");
const app_source = @import("app_source.zig");
const app_agent = @import("app_agent.zig");

pub const route_path_capacity: usize = 96;
pub const route_hash_capacity: usize = route_path_capacity + 1;
pub const context_source_button_id: u32 = 33_001;

pub const RoutePath = struct {
    pub const root = "/";
    pub const academy = "/academy";
    pub const academy_detail_prefix = "/academy/";
    pub const docs = "/docs";
    pub const docs_detail_prefix = "/docs/";
    pub const component_catalog = "/docs/components";
    pub const component_detail_prefix = "/docs/components/";
    pub const source = "/source";
    pub const agent = "/agent";
};

pub const View = enum(u32) {
    landing = 0,
    blog = 1,
    components = 2,
    docs = 3,
    source = 4,
    agent = 5,
};

pub const Route = struct {
    view: View = .source,
    selected_blog_post_id: u32 = 0,
    blog_arc_filter_index: ?usize = null,
    selected_doc_index: ?usize = null,
    selected_component_index: ?usize = null,
};

pub const Action = enum(u32) {
    reveal_identity,
    compile_source,
    download_source_release,
    launch_source_release,
    reset_source,
    open_context_source,
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
    agent,
    unknown,
};

pub fn fromPath(path: []const u8) Route {
    const trimmed = trimPath(path);
    return switch (pathKind(trimmed)) {
        .root => .{ .view = .source },
        .academy => blogIndex(null),
        .source => .{ .view = .source },
        .agent => .{ .view = .agent },
        .docs => .{ .view = .docs },
        .component_catalog => .{ .view = .components },
        .component_detail => .{ .view = .components, .selected_component_index = component_gallery.indexBySlug(trimmed[RoutePath.component_detail_prefix.len..]) },
        .docs_detail => .{ .view = .docs, .selected_doc_index = app_docs.indexBySlug(trimmed[RoutePath.docs_detail_prefix.len..]) },
        .academy_detail => academyPostRoute(trimmed[RoutePath.academy_detail_prefix.len..]),
        .unknown => .{ .view = .source },
    };
}

pub fn fromHit(hit_id: u32, current: Route) ?Route {
    return switch (hit_id) {
        app_chrome.logo_button_id,
        => .{ .view = .source },
        app_chrome.docs_button_id => .{ .view = .docs },
        app_chrome.blog_button_id,
        app_blog.all_lessons_button_id,
        app_docs.academy_button_id,
        => blogIndex(null),
        app_chrome.source_button_id => .{ .view = .source },
        app_chrome.agent_button_id => .{ .view = .agent },
        app_docs.source_button_id => .{ .view = .source },
        app_docs.component_catalog_button_id => .{ .view = .components },
        app_blog.back_button_id => blogIndex(null),
        else => routeFromDynamicHit(hit_id, current),
    };
}

pub fn actionFromHit(hit_id: u32) ?Action {
    return switch (hit_id) {
        app_landing.reveal_identity_button_id => .reveal_identity,
        app_source.compile_button_id => .compile_source,
        app_source.download_button_id => .download_source_release,
        app_source.launch_button_id => .launch_source_release,
        app_source.reset_button_id => .reset_source,
        context_source_button_id => .open_context_source,
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
        .docs => if (route.selected_component_index) |index| return writeComponentPath(out, index) else if (route.selected_doc_index) |index| {
            if (isComponentDocIndex(index)) return writeComponentCatalogPath(out);
            return writeDocPath(out, index);
        } else RoutePath.docs,
        .source => RoutePath.source,
        .agent => RoutePath.agent,
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
    @memcpy(out[1 .. 1 + path_len], path[0..path_len]);
    return path_len + 1;
}

fn pathKind(path: []const u8) PathKind {
    if (std.mem.eql(u8, path, RoutePath.root)) return .root;
    if (std.mem.eql(u8, path, RoutePath.academy)) return .academy;
    if (std.mem.eql(u8, path, RoutePath.docs)) return .docs;
    if (std.mem.eql(u8, path, RoutePath.component_catalog)) return .component_catalog;
    if (std.mem.eql(u8, path, RoutePath.source)) return .source;
    if (std.mem.eql(u8, path, RoutePath.agent)) return .agent;
    if (std.mem.startsWith(u8, path, RoutePath.academy_detail_prefix)) return .academy_detail;
    if (std.mem.startsWith(u8, path, RoutePath.component_detail_prefix)) return .component_detail;
    if (std.mem.startsWith(u8, path, RoutePath.docs_detail_prefix)) return .docs_detail;
    return .unknown;
}

fn routeFromDynamicHit(hit_id: u32, current: Route) ?Route {
    if (app_blog.postIdFromHit(hit_id)) |post_id| return .{ .view = .blog, .selected_blog_post_id = post_id, .blog_arc_filter_index = current.blog_arc_filter_index };
    if (app_blog.arcFilterIndexFromHit(hit_id)) |index| return .{ .view = .blog, .blog_arc_filter_index = index };
    if (component_gallery.indexByCatalogHit(hit_id)) |index| return .{ .view = .components, .selected_component_index = index };
    if (component_gallery.indexByPreviewHit(hit_id)) |index| return .{ .view = .components, .selected_component_index = index };
    if (app_docs.indexFromHit(hit_id)) |index| {
        if (isComponentDocIndex(index)) return .{ .view = .components };
        return .{ .view = .docs, .selected_doc_index = index };
    }
    return null;
}

fn academyPostRoute(slug: []const u8) Route {
    if (app_blog.postIdBySlug(slug)) |post_id| return .{ .view = .blog, .selected_blog_post_id = post_id };
    return blogIndex(null);
}

fn blogIndex(arc_filter_index: ?usize) Route {
    return .{ .view = .blog, .blog_arc_filter_index = arc_filter_index };
}

pub fn trimPath(path: []const u8) []const u8 {
    if (path.len == 0) return RoutePath.root;
    if (path[0] != '/') return RoutePath.root;
    const query_start = std.mem.indexOfScalar(u8, path, '?') orelse path.len;
    const hash_start = std.mem.indexOfScalar(u8, path[0..query_start], '#') orelse query_start;
    const trimmed = path[0..hash_start];
    if (trimmed.len == 0) return RoutePath.root;
    return trimmed;
}

fn writePostPath(out: []u8, post_id: u32) error{RouteBufferTooSmall}!usize {
    const slug = app_blog.postSlug(post_id) orelse return error.RouteBufferTooSmall;
    return writePrefixPath(out, RoutePath.academy_detail_prefix, slug);
}

fn writeDocPath(out: []u8, index: usize) error{RouteBufferTooSmall}!usize {
    const slug = app_docs.slugByIndex(index) orelse return error.RouteBufferTooSmall;
    return writePrefixPath(out, RoutePath.docs_detail_prefix, slug);
}

fn writeComponentPath(out: []u8, index: usize) error{RouteBufferTooSmall}!usize {
    const slug = component_gallery.slugByIndex(index) orelse return error.RouteBufferTooSmall;
    return writePrefixPath(out, RoutePath.component_detail_prefix, slug);
}

fn writeComponentCatalogPath(out: []u8) error{RouteBufferTooSmall}!usize {
    const value = RoutePath.component_catalog;
    if (value.len > out.len) return error.RouteBufferTooSmall;
    @memcpy(out[0..value.len], value);
    return value.len;
}

fn writePrefixPath(out: []u8, prefix: []const u8, suffix: []const u8) error{RouteBufferTooSmall}!usize {
    const len = prefix.len + suffix.len;
    if (len > out.len) return error.RouteBufferTooSmall;
    @memcpy(out[0..prefix.len], prefix);
    @memcpy(out[prefix.len..len], suffix);
    return len;
}

fn isComponentDocIndex(index: usize) bool {
    return index == app_docs.component_catalog_doc_index;
}
