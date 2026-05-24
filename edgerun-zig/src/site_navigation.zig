const std = @import("std");
const site_blog = @import("site_blog.zig");
const site_chrome = @import("site_chrome.zig");

pub const route_path_capacity: usize = 96;
pub const route_hash_capacity: usize = route_path_capacity + 1;

pub const View = enum(u32) {
    landing = 0,
    blog = 1,
    apps = 2,
    components = 3,
};

pub const Route = struct {
    view: View = .landing,
    selected_blog_post_id: u32 = 0,
    blog_arc_filter_index: ?usize = null,
};

pub fn fromPath(path: []const u8) Route {
    const trimmed = trimPath(path);
    if (std.mem.eql(u8, trimmed, "/academy")) return blogIndex(null);
    if (std.mem.eql(u8, trimmed, "/apps")) return .{ .view = .apps };
    if (std.mem.eql(u8, trimmed, "/docs") or std.mem.eql(u8, trimmed, "/docs/components")) return .{ .view = .components };
    if (std.mem.startsWith(u8, trimmed, "/docs/components/")) return .{ .view = .components };
    if (std.mem.startsWith(u8, trimmed, "/academy/")) {
        const raw_id = std.fmt.parseUnsigned(u32, trimmed["/academy/".len..], 10) catch return blogIndex(null);
        return .{
            .view = .blog,
            .selected_blog_post_id = if (site_blog.postById(raw_id) != null) raw_id else 0,
        };
    }
    return .{};
}

pub fn fromHit(hit_id: u32, current: Route) ?Route {
    return switch (hit_id) {
        site_chrome.logo_button_id,
        => .{},
        site_chrome.docs_button_id => .{ .view = .components },
        site_chrome.blog_button_id,
        site_blog.all_lessons_button_id,
        => blogIndex(null),
        site_chrome.apps_button_id => .{ .view = .apps },
        site_blog.back_button_id => blogIndex(null),
        else => routeFromDynamicHit(hit_id, current),
    };
}

pub fn pathFromBrowserHash(hash: []const u8) error{InvalidBrowserRoute}![]const u8 {
    if (hash.len == 0 or std.mem.eql(u8, hash, "#")) return "/";
    if (std.mem.startsWith(u8, hash, "#/")) return hash[1..];
    return error.InvalidBrowserRoute;
}

pub fn writePath(out: []u8, route: Route) error{RouteBufferTooSmall}!usize {
    const value = switch (route.view) {
        .landing => "/",
        .blog => if (route.selected_blog_post_id == 0) "/academy" else return writePostPath(out, route.selected_blog_post_id),
        .apps => "/apps",
        .components => "/docs/components",
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
    _ = current;
    if (site_blog.postById(hit_id) != null) {
        return .{ .view = .blog, .selected_blog_post_id = hit_id };
    }
    if (site_blog.arcFilterIndexById(hit_id)) |index| {
        return blogIndex(index);
    }
    return null;
}

fn blogIndex(filter_index: ?usize) Route {
    return .{ .view = .blog, .blog_arc_filter_index = filter_index };
}

fn writePostPath(out: []u8, post_id: u32) error{RouteBufferTooSmall}!usize {
    const value = std.fmt.bufPrint(out, "/academy/{d}", .{post_id}) catch return error.RouteBufferTooSmall;
    return value.len;
}

test "navigation parses browser and native site routes" {
    try std.testing.expectEqual(View.landing, fromPath("").view);
    try std.testing.expectEqual(View.blog, fromPath("/academy").view);
    try std.testing.expectEqual(View.apps, fromPath("/apps").view);
    try std.testing.expectEqual(View.components, fromPath("/docs/components").view);
    try std.testing.expectEqual(View.components, fromPath("/docs/components/button").view);
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

    const apps = Route{ .view = .apps };
    const apps_len = try writePath(&path, apps);
    try std.testing.expectEqualStrings("/apps", path[0..apps_len]);
    const apps_hash_len = try writeHash(&hash, apps);
    try std.testing.expectEqualStrings("#/apps", hash[0..apps_hash_len]);

    const components = Route{ .view = .components };
    const components_len = try writePath(&path, components);
    try std.testing.expectEqualStrings("/docs/components", path[0..components_len]);
    const components_hash_len = try writeHash(&hash, components);
    try std.testing.expectEqualStrings("#/docs/components", hash[0..components_hash_len]);
}

test "navigation maps shared hit ids to routes" {
    try std.testing.expectEqual(View.landing, fromHit(site_chrome.logo_button_id, .{}).?.view);
    try std.testing.expectEqual(View.components, fromHit(site_chrome.docs_button_id, .{}).?.view);
    try std.testing.expectEqual(View.blog, fromHit(site_chrome.blog_button_id, .{}).?.view);
    try std.testing.expectEqual(View.apps, fromHit(site_chrome.apps_button_id, .{}).?.view);
    const post_id = site_blog.postIdAt(0);
    try std.testing.expectEqual(post_id, fromHit(post_id, .{}).?.selected_blog_post_id);
}
