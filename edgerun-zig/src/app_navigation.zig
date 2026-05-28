const std = @import("std");
const bytes = @import("bytes.zig");
const component_gallery = @import("component_gallery.zig");
const app_blog = @import("app_blog.zig");
const app_docs = @import("app_docs.zig");
const icon_component = @import("ui/components/Icon.zig");

pub const route_path_capacity: usize = 96;
pub const route_hash_capacity: usize = route_path_capacity + 1;
pub const logo_button_id: u32 = 30_000;
pub const docs_button_id: u32 = 30_001;
pub const blog_button_id: u32 = 30_011;
pub const source_button_id: u32 = 30_012;
pub const agent_button_id: u32 = 30_013;
pub const component_catalog_button_id: u32 = 31_001;
pub const academy_button_id: u32 = 31_002;
pub const docs_source_button_id: u32 = 31_003;
pub const first_doc_page_button_id: u32 = 31_200;
pub const source_compile_button_id: u32 = 32_001;
pub const source_download_button_id: u32 = 32_002;
pub const source_launch_button_id: u32 = 32_003;
pub const source_reset_button_id: u32 = 32_004;
pub const blog_back_button_id: u32 = 40_001;
pub const first_post_button_id: u32 = 40_100;
pub const all_lessons_button_id: u32 = 40_899;
pub const first_arc_filter_button_id: u32 = 40_900;
pub const context_source_button_id: u32 = 33_001;
pub const reveal_identity_button_id: u32 = 15_001;

pub const SourceAction = enum(u32) {
    compile,
    download,
    launch,
    reset,
};

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
    view: View = .landing,
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

const ResolveRouteFromHit = *const fn (u32, Route) ?Route;
const MatchesRouteHit = *const fn (u32) bool;
const ResolveDynamicFallback = *const fn (Route) Route;

pub const RouteFixture = struct {
    name: []const u8,
    route: Route,
    path: []const u8,
    hash: []const u8,
};

pub const route_fixtures = [_]RouteFixture{
    .{ .name = "landing", .route = .{ .view = .landing }, .path = RoutePath.root, .hash = "" },
    .{ .name = "blog", .route = .{ .view = .blog }, .path = RoutePath.academy, .hash = "#/academy" },
    .{ .name = "docs", .route = .{ .view = .docs }, .path = RoutePath.docs, .hash = "#/docs" },
    .{ .name = "components", .route = .{ .view = .components }, .path = RoutePath.component_catalog, .hash = "#/docs/components" },
    .{ .name = "source", .route = .{ .view = .source }, .path = RoutePath.source, .hash = "#/source" },
    .{ .name = "agent", .route = .{ .view = .agent }, .path = RoutePath.agent, .hash = "#/agent" },
};

pub const RouteFor = union(enum) {
    button: MainButton,
    action: Action,
    slug: []const u8,
};

pub fn routeFor(target: RouteFor) ?Route {
    return switch (target) {
        .button => |button| routeForButton(button),
        .action => |action| routeForAction(action),
        .slug => |slug| routeForSlug(slug),
    };
}

pub fn routeForButton(button: MainButton) Route {
    return topLevelBinding(button).route;
}

pub fn routeForAction(action: Action) ?Route {
    return switch (action) {
        .open_context_source => .{ .view = .source },
        .reveal_identity,
        .compile_source,
        .download_source_release,
        .launch_source_release,
        .reset_source,
        => null,
    };
}

fn fallbackCurrentRoute(current: Route) Route {
    return current;
}

pub fn routeForSlug(slug: []const u8) Route {
    if (slug.len == 0) return fromPath(RoutePath.root);
    var path: [route_path_capacity]u8 = undefined;
    if (slug.len >= path.len) return .{ .view = .landing };
    path[0] = '/';
    @memcpy(path[1 .. slug.len + 1], slug);
    return fromPath(path[0 .. slug.len + 1]);
}

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
        .root => .{ .view = .landing },
        .academy => blogIndex(null),
        .source => .{ .view = .source },
        .agent => .{ .view = .agent },
        .docs => .{ .view = .docs },
        .component_catalog => .{ .view = .components },
        .component_detail => .{ .view = .components, .selected_component_index = component_gallery.indexBySlug(trimmed[RoutePath.component_detail_prefix.len..]) },
        .docs_detail => .{ .view = .docs, .selected_doc_index = docIndexBySlug(trimmed[RoutePath.docs_detail_prefix.len..]) },
        .academy_detail => academyPostRoute(trimmed[RoutePath.academy_detail_prefix.len..]),
        .unknown => .{ .view = .landing },
    };
}

pub fn sourceActionButtonId(action: SourceAction) u32 {
    return source_compile_button_id + @as(u32, @intCast(@intFromEnum(action)));
}

pub fn docsPageButtonId(index: usize) u32 {
    return first_doc_page_button_id + @as(u32, @intCast(index));
}

pub fn docsPageIndexFromButton(hit_id: u32) ?usize {
    if (hit_id < first_doc_page_button_id) return null;
    const index: usize = hit_id - first_doc_page_button_id;
    return if (index < app_docs.doc_pages.len) index else null;
}

pub fn blogPostButtonId(index: usize) u32 {
    return first_post_button_id + @as(u32, @intCast(index));
}

pub fn blogPostIndexFromButton(hit_id: u32) ?usize {
    if (hit_id < first_post_button_id) return null;
    const index: usize = hit_id - first_post_button_id;
    return if (index < app_blog.posts.len) index else null;
}

pub fn blogArcFilterButtonId(index: usize) u32 {
    return first_arc_filter_button_id + @as(u32, @intCast(index));
}

pub fn blogArcFilterIndexFromButton(hit_id: u32) ?usize {
    if (hit_id < first_arc_filter_button_id) return null;
    const index: usize = hit_id - first_arc_filter_button_id;
    return app_blogArcFilterIndex(index);
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

pub fn actionId(action: Action) u32 {
    for (action_bindings) |binding| {
        if (binding.action == action) return binding.id;
    }
    unreachable;
}

pub fn pathFromHash(hash: []const u8) error{InvalidRouteHash}![]const u8 {
    if (hash.len == 0 or bytes.eql(hash, "#")) return "/";
    if (bytes.startsWith(hash, "#/")) return hash[1..];
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
    if (bytes.eql(path, RoutePath.root)) return .root;
    if (bytes.eql(path, RoutePath.academy)) return .academy;
    if (bytes.eql(path, RoutePath.docs)) return .docs;
    if (bytes.eql(path, RoutePath.component_catalog)) return .component_catalog;
    if (bytes.eql(path, RoutePath.source)) return .source;
    if (bytes.eql(path, RoutePath.agent)) return .agent;
    if (bytes.startsWith(path, RoutePath.academy_detail_prefix)) return .academy_detail;
    if (bytes.startsWith(path, RoutePath.component_detail_prefix)) return .component_detail;
    if (bytes.startsWith(path, RoutePath.docs_detail_prefix)) return .docs_detail;
    return .unknown;
}

fn routeFromDynamicHit(hit_id: u32, current: Route) ?Route {
    for (dynamic_route_resolvers) |resolve| {
        if (!resolve.match(hit_id)) continue;
        if (resolve.resolve(hit_id, current)) |route| return route;
        return resolve.fallback(current);
    }
    return null;
}

pub const HitRoute = struct { id: u32, route: Route };
pub const ActionBinding = struct { id: u32, action: Action };

pub const DynamicRouteResolver = struct {
    name: []const u8,
    match: MatchesRouteHit,
    resolve: ResolveRouteFromHit,
    fallback: ResolveDynamicFallback,
};

pub const Contract = struct {
    static_routes: []const HitRoute,
    action_bindings: []const ActionBinding,
    dynamic_route_resolvers: []const DynamicRouteResolver,
};

pub const DynamicRouteFixture = struct {
    name: []const u8,
    hit_id: u32,
    expected: Route,
};

const dynamic_route_fixtures = blk: {
    const post_id = app_blog.postIdAt(0);
    const docs_index = docIndexBySlug("component-system") orelse 0;
    const docs_expected: Route = if (docSlugByIndex(docs_index)) |slug|
        if (bytes.eql(slug, "component-system"))
            .{ .view = .components }
        else
            .{ .view = .docs, .selected_doc_index = docs_index }
    else
        .{ .view = .docs };

    break :blk [_]DynamicRouteFixture{
        .{ .name = "blog-post", .hit_id = app_blog.postIdAt(0), .expected = .{ .view = .blog, .selected_blog_post_id = post_id } },
        .{ .name = "component-docs-tab", .hit_id = docsPageButtonId(docs_index), .expected = docs_expected },
        .{ .name = "arc-filter", .hit_id = app_blog.arcFilterButtonId(0), .expected = .{ .view = .blog, .blog_arc_filter_index = 0 } },
        .{ .name = "component-catalog-card", .hit_id = component_gallery.first_catalog_card_id, .expected = .{ .view = .components, .selected_component_index = 0 } },
        .{ .name = "component-preview", .hit_id = component_gallery.previewHitForIndexForTest(0), .expected = .{ .view = .components, .selected_component_index = 0 } },
    };
};

pub const dynamic_route_fixture_count: usize = dynamic_route_fixtures.len;

pub fn dynamicRouteFixtures() []const DynamicRouteFixture {
    return &dynamic_route_fixtures;
}

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
        .id = logo_button_id,
        .route = .{ .view = .landing },
        .icon = icon_component.Icon.named(.terminal),
        .rail_label = "Overview",
        .row_title = "Overview",
        .row_detail = "top-level app view",
    },
    .{
        .button = .source,
        .id = source_button_id,
        .route = .{ .view = .source },
        .icon = icon_component.Icon.named(.code),
        .rail_label = "Source",
        .row_title = "Source",
        .row_detail = "edit app workspace",
    },
    .{
        .button = .agent,
        .id = agent_button_id,
        .route = .{ .view = .agent },
        .icon = icon_component.Icon.named(.sparkles),
        .rail_label = "Agent",
        .row_title = "Agent",
        .row_detail = "local model and tools",
    },
    .{
        .button = .components,
        .id = component_catalog_button_id,
        .route = .{ .view = .components },
        .icon = icon_component.Icon.named(.app),
        .rail_label = "Components",
        .row_title = "Components",
        .row_detail = "edit and preview system",
    },
    .{
        .button = .docs,
        .id = docs_button_id,
        .route = .{ .view = .docs },
        .icon = icon_component.Icon.named(.file),
        .rail_label = "Docs",
        .row_title = "Docs",
        .row_detail = "manual inside workspace",
    },
    .{
        .button = .blog,
        .id = blog_button_id,
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
    .{ .id = sourceActionButtonId(.compile), .action = .compile_source },
    .{ .id = sourceActionButtonId(.download), .action = .download_source_release },
    .{ .id = sourceActionButtonId(.launch), .action = .launch_source_release },
    .{ .id = sourceActionButtonId(.reset), .action = .reset_source },
    .{ .id = context_source_button_id, .action = .open_context_source },
};

pub const static_routes = [_]HitRoute{
    .{ .id = logo_button_id, .route = .{ .view = .landing } },
    .{ .id = docs_button_id, .route = .{ .view = .docs } },
    .{ .id = blog_button_id, .route = .{ .view = .blog } },
    .{ .id = all_lessons_button_id, .route = .{ .view = .blog } },
    .{ .id = academy_button_id, .route = .{ .view = .blog } },
    .{ .id = source_button_id, .route = .{ .view = .source } },
    .{ .id = agent_button_id, .route = .{ .view = .agent } },
    .{ .id = docs_source_button_id, .route = .{ .view = .source } },
    .{ .id = component_catalog_button_id, .route = .{ .view = .components } },
    .{ .id = blog_back_button_id, .route = .{ .view = .blog } },
};

fn routeFromStaticHit(hit_id: u32) ?Route {
    for (static_routes) |binding| {
        if (binding.id == hit_id) return binding.route;
    }
    return null;
}

const dynamic_route_resolvers = [_]DynamicRouteResolver{
    .{ .name = "blog-post", .match = isBlogPostHit, .resolve = blogPostFromHit, .fallback = fallbackCurrentRoute },
    .{ .name = "arc-filter", .match = isArcFilterHit, .resolve = arcFilterFromHit, .fallback = fallbackCurrentRoute },
    .{ .name = "catalog-card", .match = isCatalogCardHit, .resolve = componentCatalogFromHit, .fallback = fallbackCurrentRoute },
    .{ .name = "component-preview", .match = isComponentPreviewHit, .resolve = componentPreviewFromHit, .fallback = fallbackCurrentRoute },
    .{ .name = "docs", .match = isDocsFamilyHit, .resolve = docsOrCatalogFromHit, .fallback = fallbackCurrentRoute },
};

fn isBlogPostHit(hit_id: u32) bool {
    return blogPostIdFromHit(hit_id) != null;
}

fn isArcFilterHit(hit_id: u32) bool {
    return app_blog.arcFilterIndexById(hit_id) != null;
}

fn isCatalogCardHit(hit_id: u32) bool {
    return component_gallery.indexByCatalogHit(hit_id) != null;
}

fn isComponentPreviewHit(hit_id: u32) bool {
    return component_gallery.indexByPreviewHit(hit_id) != null;
}

fn isDocsFamilyHit(hit_id: u32) bool {
    return docIndexFromHit(hit_id) != null;
}

fn blogPostFromHit(hit_id: u32, current: Route) ?Route {
    if (blogPostIdFromHit(hit_id)) |post_id| {
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
    if (docIndexFromHit(hit_id)) |index| {
        if (isComponentDocIndex(index)) return .{ .view = .components };
        return .{ .view = .docs, .selected_doc_index = index };
    }
    return null;
}

pub fn contract() Contract {
    return .{
        .static_routes = &static_routes,
        .action_bindings = &action_bindings,
        .dynamic_route_resolvers = &dynamic_route_resolvers,
    };
}

fn academyPostRoute(slug: []const u8) Route {
    if (blogPostIdBySlug(slug)) |post_id| return .{ .view = .blog, .selected_blog_post_id = post_id };
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
    const slug = blogPostSlug(post_id) orelse return error.RouteBufferTooSmall;
    return writePrefixPath(out, RoutePath.academy_detail_prefix, slug);
}

fn writeDocPath(out: []u8, index: usize) error{RouteBufferTooSmall}!usize {
    const slug = docSlugByIndex(index) orelse return error.RouteBufferTooSmall;
    return writePrefixPath(out, RoutePath.docs_detail_prefix, slug);
}

fn writeComponentPath(out: []u8, index: usize) error{RouteBufferTooSmall}!usize {
    const slug = componentSlugByIndex(index) orelse return error.RouteBufferTooSmall;
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

fn docIndexBySlug(slug: []const u8) ?usize {
    for (app_docs.doc_pages, 0..) |page, index| {
        if (bytes.eql(page.slug, slug)) return index;
    }
    return null;
}

fn docIndexFromHit(hit_id: u32) ?usize {
    return docsPageIndexFromButton(hit_id);
}

fn docSlugByIndex(index: usize) ?[]const u8 {
    if (index >= app_docs.doc_pages.len) return null;
    return app_docs.doc_pages[index].slug;
}

fn componentSlugByIndex(index: usize) ?[]const u8 {
    if (index >= component_gallery.component_catalog.len) return null;
    return component_gallery.component_catalog[index].slug;
}

fn app_blogArcFilterIndex(index: usize) ?usize {
    return if (index < app_blogArcSectionCount()) index else null;
}

fn app_blogArcSectionCount() usize {
    return 5;
}

fn blogPostIdFromHit(hit_id: u32) ?u32 {
    return if (blogPostIndexFromId(hit_id) != null) hit_id else null;
}

fn blogPostIndexFromId(post_id: u32) ?usize {
    if (post_id < first_post_button_id) return null;
    const index: usize = @intCast(post_id - first_post_button_id);
    return if (index < app_blog.posts.len) index else null;
}

fn blogPostSlug(post_id: u32) ?[]const u8 {
    const index = blogPostIndexFromId(post_id) orelse return null;
    return blogSlugByIndex(index);
}

fn blogPostIdBySlug(slug: []const u8) ?u32 {
    for (app_blog.posts, 0..) |_, index| {
        if (bytes.eql(blogSlugByIndex(index), slug)) {
            return blogPostButtonId(index);
        }
    }
    return null;
}

fn blogSlugByIndex(index: usize) []const u8 {
    return switch (index) {
        0 => "device-city",
        1 => "cpu-instructions",
        2 => "ram-desk",
        3 => "storage-long-term",
        4 => "gpu-draws-reality",
        5 => "os-referee",
        6 => "apps-are-guests",
        7 => "drivers-firmware",
        8 => "keys-tpms-secure-boot",
        else => "lesson",
    };
}

fn isComponentDocIndex(index: usize) bool {
    const slug = docSlugByIndex(index) orelse return false;
    return bytes.eql(slug, "component-system");
}

comptime {
    if (top_level_bindings.len != @typeInfo(MainButton).@"enum".fields.len) {
        @compileError("top_level_bindings must cover every MainButton enum value");
    }
    var seen_buttons: [@typeInfo(MainButton).@"enum".fields.len]bool = [_]bool{false} ** @typeInfo(MainButton).@"enum".fields.len;
    for (top_level_bindings) |entry| {
        const idx = @intFromEnum(entry.button);
        if (idx >= seen_buttons.len) @compileError("top_level_bindings contains unknown MainButton");
        if (seen_buttons[idx]) @compileError("top_level_bindings contains duplicate MainButton entries");
        seen_buttons[idx] = true;
    }
    for (seen_buttons) |seen| {
        if (!seen) @compileError("top_level_bindings missing a MainButton entry");
    }
}

comptime {
    var seen_actions: [@typeInfo(Action).@"enum".fields.len]bool = [_]bool{false} ** @typeInfo(Action).@"enum".fields.len;
    for (action_bindings) |entry| {
        const idx = @intFromEnum(entry.action);
        if (idx >= seen_actions.len) @compileError("action_bindings contains unknown Action");
        if (seen_actions[idx]) @compileError("action_bindings contains duplicate actions");
        seen_actions[idx] = true;
    }
    for (seen_actions) |seen| {
        if (!seen) @compileError("action_bindings missing binding for Action");
    }
}

comptime {
    if (dynamic_route_resolvers.len == 0) {
        @compileError("dynamic_route_resolvers must not be empty");
    }
}

comptime {
    for (static_routes, 0..) |left, i| {
        var j: usize = i + 1;
        while (j < static_routes.len) : (j += 1) {
            if (left.id == static_routes[j].id) {
                @compileError("static_routes contains duplicate hit id");
            }
        }
    }

    for (action_bindings, 0..) |left, i| {
        var j: usize = i + 1;
        while (j < action_bindings.len) : (j += 1) {
            if (left.action == action_bindings[j].action) {
                @compileError("action_bindings contains duplicate action");
            }
            if (left.id == action_bindings[j].id) {
                @compileError("action_bindings contains duplicate hit id");
            }
        }
    }

    for (action_bindings) |entry| {
        var i: usize = 0;
        while (i < top_level_bindings.len) : (i += 1) {
            if (entry.id == top_level_bindings[i].id) {
                @compileError("action id collides with top-level route id");
            }
        }
        i = 0;
        while (i < static_routes.len) : (i += 1) {
            if (entry.id == static_routes[i].id) {
                @compileError("action id collides with static route id");
            }
        }
    }

    for (dynamic_route_resolvers, 0..) |left, i| {
        var j: usize = i + 1;
        while (j < dynamic_route_resolvers.len) : (j += 1) {
            if (bytes.eql(left.name, dynamic_route_resolvers[j].name)) {
                @compileError("dynamic_route_resolvers contains duplicate name");
            }
        }
    }
}

test "app_navigation route contract is deterministic for top-level and dynamic families" {
    for (route_fixtures) |snapshot| {
        var path: [route_path_capacity]u8 = undefined;
        var hash: [route_hash_capacity]u8 = undefined;

        const path_len = try writePath(&path, snapshot.route);
        try std.testing.expectEqualStrings(snapshot.path, path[0..path_len]);
        try std.testing.expectEqual(snapshot.route, fromPath(snapshot.path));

        const hash_len = try writeHash(&hash, snapshot.route);
        try std.testing.expectEqualStrings(snapshot.hash, hash[0..hash_len]);
    }

    for (dynamicRouteFixtures()) |entry| {
        const route = fromHit(entry.hit_id, .{ .view = .source }) orelse unreachable;
        try std.testing.expectEqual(entry.expected, route);
    }

    for (top_level_bindings) |binding| {
        try std.testing.expectEqual(binding.route, routeFor(.{ .button = binding.button }).?);
        try std.testing.expectEqual(binding.route, fromHit(topLevelButtonId(binding.button), .{}) orelse unreachable);
    }

    for (action_bindings) |entry| {
        if (entry.action == .open_context_source) {
            try std.testing.expectEqual(Route{ .view = .source }, routeFor(.{ .action = entry.action }) orelse unreachable);
        } else {
            try std.testing.expectEqual(@as(?Route, null), routeFor(.{ .action = entry.action }));
        }
        try std.testing.expectEqual(entry.action, actionFromHit(entry.id).?);
    }
}

test "app_navigation static route and action ids are deterministic through shared contract" {
    for (static_routes) |entry| {
        if (fromHit(entry.id, .{})) |actual| {
            try std.testing.expectEqual(entry.route, actual);
        } else {
            try std.testing.expect(false);
        }
    }

    for (action_bindings) |entry| {
        if (actionFromHit(entry.id)) |actual| {
            try std.testing.expectEqual(entry.action, actual);
        } else {
            try std.testing.expect(false);
        }
    }
}

test "app_navigation dynamic fallback routes keep current state" {
    const samples = [_]Route{
        .{},
        .{ .view = .blog, .selected_blog_post_id = app_blog.postIdAt(0) },
        .{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("media") },
        .{ .view = .components, .selected_component_index = 0 },
        .{ .view = .source },
    };

    for (dynamic_route_resolvers) |resolver| {
        for (samples) |sample| {
            const fallback = resolver.fallback(sample);
            try std.testing.expectEqual(sample.view, fallback.view);
            try std.testing.expectEqual(sample.selected_blog_post_id, fallback.selected_blog_post_id);
            try std.testing.expectEqual(sample.blog_arc_filter_index, fallback.blog_arc_filter_index);
            try std.testing.expectEqual(sample.selected_doc_index, fallback.selected_doc_index);
            try std.testing.expectEqual(sample.selected_component_index, fallback.selected_component_index);
        }
    }
}
