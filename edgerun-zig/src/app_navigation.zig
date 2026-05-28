const std = @import("std");
const component_gallery = @import("component_gallery.zig");
const app_blog = @import("app_blog.zig");
const app_docs = @import("app_docs.zig");
const app_source = @import("app_source.zig");
const route_ids = @import("app_routing_ids.zig");
const icon_component = @import("ui/components/Icon.zig");

pub const route_path_capacity: usize = 96;
pub const route_hash_capacity: usize = route_path_capacity + 1;
pub const context_source_button_id: u32 = 33_001;
pub const reveal_identity_button_id: u32 = 20_001;

pub const MainButton = enum(u32) {
    logo = 0,
    docs = 1,
    blog = 2,
    source = 3,
    agent = 4,
    components = 5,
};

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
    if (routeFromStaticHit(hit_id)) |route| return route;
    return routeFromDynamicHit(hit_id, current);
}

pub fn actionFromHit(hit_id: u32) ?Action {
    for (action_bindings) |binding| {
        if (binding.id == hit_id) return binding.action;
    }
    return null;
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
    for (dynamic_route_resolvers) |resolve| {
        if (resolve(hit_id, current)) |route| return route;
    }
    return null;
}

pub const HitRoute = struct { id: u32, route: Route };
pub const ActionBinding = struct { id: u32, action: Action };
const ResolveRouteFromHit = *const fn (u32, Route) ?Route;

pub const Contract = struct {
    static_routes: []const HitRoute,
    action_bindings: []const ActionBinding,
};

pub const TopLevelBinding = struct {
    button: MainButton,
    id: u32,
    route: Route,
    icon: icon_component.Icon,
    rail_label: []const u8,
    row_title: []const u8,
    row_detail: []const u8,
};

const top_level_bindings = [_]TopLevelBinding{
    .{
        .button = .logo,
        .id = route_ids.logo_button_id,
        .route = .{ .view = .source },
        .icon = icon_component.Icon.named(.terminal),
        .rail_label = "Overview",
        .row_title = "Overview",
        .row_detail = "top-level app view",
    },
    .{
        .button = .source,
        .id = route_ids.source_button_id,
        .route = .{ .view = .source },
        .icon = icon_component.Icon.named(.code),
        .rail_label = "Source",
        .row_title = "Source",
        .row_detail = "edit app workspace",
    },
    .{
        .button = .agent,
        .id = route_ids.agent_button_id,
        .route = .{ .view = .agent },
        .icon = icon_component.Icon.named(.sparkles),
        .rail_label = "Agent",
        .row_title = "Agent",
        .row_detail = "local model and tools",
    },
    .{
        .button = .components,
        .id = route_ids.component_catalog_button_id,
        .route = .{ .view = .components },
        .icon = icon_component.Icon.named(.app),
        .rail_label = "Components",
        .row_title = "Components",
        .row_detail = "edit and preview system",
    },
    .{
        .button = .docs,
        .id = route_ids.docs_button_id,
        .route = .{ .view = .docs },
        .icon = icon_component.Icon.named(.file),
        .rail_label = "Docs",
        .row_title = "Docs",
        .row_detail = "manual inside workspace",
    },
    .{
        .button = .blog,
        .id = route_ids.blog_button_id,
        .route = .{ .view = .blog },
        .icon = icon_component.Icon.named(.terminal),
        .rail_label = "Academy",
        .row_title = "Academy",
        .row_detail = "lessons inside workspace",
    },
};

pub fn topLevelButtonId(button: MainButton) u32 {
    return topLevelBinding(button).id;
}

pub fn topLevelRoute(button: MainButton) Route {
    return topLevelBinding(button).route;
}

pub fn topLevelBindings() []const TopLevelBinding {
    return &top_level_bindings;
}

pub fn topLevelBinding(button: MainButton) TopLevelBinding {
    for (top_level_bindings) |entry| {
        if (entry.button == button) return entry;
    }
    unreachable;
}

pub fn topLevelWorkspaceBindings() []const TopLevelBinding {
    return top_level_bindings[1..];
}

pub const action_bindings = [_]ActionBinding{
    .{ .id = reveal_identity_button_id, .action = .reveal_identity },
    .{ .id = app_source.compile_button_id, .action = .compile_source },
    .{ .id = app_source.download_button_id, .action = .download_source_release },
    .{ .id = app_source.launch_button_id, .action = .launch_source_release },
    .{ .id = app_source.reset_button_id, .action = .reset_source },
    .{ .id = context_source_button_id, .action = .open_context_source },
};

pub const static_routes = [_]HitRoute{
    .{ .id = route_ids.logo_button_id, .route = .{ .view = .source } },
    .{ .id = route_ids.docs_button_id, .route = .{ .view = .docs } },
    .{ .id = route_ids.blog_button_id, .route = .{ .view = .blog } },
    .{ .id = route_ids.all_lessons_button_id, .route = .{ .view = .blog } },
    .{ .id = route_ids.academy_button_id, .route = .{ .view = .blog } },
    .{ .id = route_ids.source_button_id, .route = .{ .view = .source } },
    .{ .id = route_ids.agent_button_id, .route = .{ .view = .agent } },
    .{ .id = route_ids.docs_source_button_id, .route = .{ .view = .source } },
    .{ .id = route_ids.component_catalog_button_id, .route = .{ .view = .components } },
    .{ .id = app_blog.back_button_id, .route = .{ .view = .blog } },
};

fn routeFromStaticHit(hit_id: u32) ?Route {
    for (static_routes) |binding| {
        if (binding.id == hit_id) return binding.route;
    }
    return null;
}

const dynamic_route_resolvers = [_]ResolveRouteFromHit{
    blogPostFromHit,
    arcFilterFromHit,
    componentCatalogFromHit,
    componentPreviewFromHit,
    docsOrCatalogFromHit,
};

fn blogPostFromHit(hit_id: u32, current: Route) ?Route {
    if (app_blog.postIdFromHit(hit_id)) |post_id| {
        return .{ .view = .blog, .selected_blog_post_id = post_id, .blog_arc_filter_index = current.blog_arc_filter_index };
    }
    return null;
}

fn arcFilterFromHit(hit_id: u32, _: Route) ?Route {
    if (app_blog.arcFilterIndexById(hit_id)) |index| {
        return .{ .view = .blog, .blog_arc_filter_index = index };
    }
    return null;
}

fn componentCatalogFromHit(hit_id: u32, _: Route) ?Route {
    if (component_gallery.indexByCatalogHit(hit_id)) |index| {
        return .{ .view = .components, .selected_component_index = index };
    }
    return null;
}

fn componentPreviewFromHit(hit_id: u32, _: Route) ?Route {
    if (component_gallery.indexByPreviewHit(hit_id)) |index| {
        return .{ .view = .components, .selected_component_index = index };
    }
    return null;
}

fn docsOrCatalogFromHit(hit_id: u32, _: Route) ?Route {
    if (app_docs.indexFromHit(hit_id)) |index| {
        if (isComponentDocIndex(index)) return .{ .view = .components };
        return .{ .view = .docs, .selected_doc_index = index };
    }
    return null;
}

pub fn contract() Contract {
    return .{
        .static_routes = &static_routes,
        .action_bindings = &action_bindings,
    };
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
