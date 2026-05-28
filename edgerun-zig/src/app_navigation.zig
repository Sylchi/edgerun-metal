const std = @import("std");
const bytes = @import("bytes.zig");
const icon_component = @import("ui/components/Icon.zig");

pub const route_path_capacity: usize = 96;
pub const route_hash_capacity: usize = route_path_capacity + 1;
pub const backend_button_id: u32 = 30_012;
pub const frontend_button_id: u32 = 30_000;
pub const source_compile_button_id: u32 = 32_001;
pub const source_download_button_id: u32 = 32_002;
pub const source_launch_button_id: u32 = 32_003;
pub const source_reset_button_id: u32 = 32_004;
pub const context_source_button_id: u32 = 33_001;
pub const reveal_identity_button_id: u32 = 15_001;
pub const first_doc_page_button_id: u32 = 31_200;
pub const first_post_button_id: u32 = 40_100;
pub const first_arc_filter_button_id: u32 = 40_900;
pub const all_lessons_button_id: u32 = 40_899;
pub const blog_back_button_id: u32 = 40_001;

pub const SourceAction = enum(u32) {
    compile,
    download,
    launch,
    reset,
};

pub const MainButton = enum(u32) {
    backend = 0,
    frontend = 1,
};

pub const RoutePath = struct {
    pub const backend = "/source";
    pub const frontend = "/";
};

pub const View = enum(u32) {
    backend = 0,
    frontend = 1,
};

pub const Route = struct {
    view: View = .backend,
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

pub const RouteFixture = struct {
    name: []const u8,
    route: Route,
    path: []const u8,
    hash: []const u8,
};

pub const route_fixtures = [_]RouteFixture{
    .{ .name = "backend", .route = .{ .view = .backend }, .path = RoutePath.backend, .hash = "#/source" },
    .{ .name = "frontend", .route = .{ .view = .frontend }, .path = RoutePath.frontend, .hash = "" },
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
        .open_context_source => .{ .view = .backend },
        .reveal_identity,
        .compile_source,
        .download_source_release,
        .launch_source_release,
        .reset_source,
        => null,
    };
}

pub fn routeForSlug(slug: []const u8) Route {
    if (slug.len == 0) return fromPath(RoutePath.frontend);
    var path: [route_path_capacity]u8 = undefined;
    if (slug.len >= path.len) return .{};
    path[0] = '/';
    @memcpy(path[1 .. slug.len + 1], slug);
    return fromPath(path[0 .. slug.len + 1]);
}

pub fn fromPath(path: []const u8) Route {
    const trimmed = trimPath(path);
    return switch (pathKind(trimmed)) {
        .backend => .{ .view = .backend },
        .frontend => .{},
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
    return if (index < 64) index else null;
}

pub fn blogPostButtonId(index: usize) u32 {
    return first_post_button_id + @as(u32, @intCast(index));
}

pub fn blogPostIndexFromButton(hit_id: u32) ?usize {
    if (hit_id < first_post_button_id) return null;
    const index: usize = hit_id - first_post_button_id;
    return if (index < 64) index else null;
}

pub fn blogArcFilterButtonId(index: usize) u32 {
    return first_arc_filter_button_id + @as(u32, @intCast(index));
}

pub fn blogArcFilterIndexFromButton(hit_id: u32) ?usize {
    if (hit_id < first_arc_filter_button_id) return null;
    const index: usize = hit_id - first_arc_filter_button_id;
    return if (index < 8) index else null;
}

pub fn fromHit(hit_id: u32, current: Route) ?Route {
    if (routeFromStaticHit(hit_id)) |route| return route;
    return null;
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
        .backend => RoutePath.backend,
        .frontend => RoutePath.frontend,
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

const PathKind = enum {
    backend,
    frontend,
};

fn pathKind(path: []const u8) PathKind {
    if (bytes.eql(path, RoutePath.backend)) return .backend;
    return .frontend;
}

pub const HitRoute = struct { id: u32, route: Route };
pub const ActionBinding = struct { id: u32, action: Action };

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
        .button = .backend,
        .id = backend_button_id,
        .route = .{ .view = .backend },
        .icon = icon_component.Icon.named(.code),
        .rail_label = "Backend",
        .row_title = "Source",
        .row_detail = "code editor workspace",
    },
    .{
        .button = .frontend,
        .id = frontend_button_id,
        .route = .{ .view = .frontend },
        .icon = icon_component.Icon.named(.eye),
        .rail_label = "Frontend",
        .row_title = "Preview",
        .row_detail = "running app preview",
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
    return &top_level_bindings;
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
    .{ .id = backend_button_id, .route = .{ .view = .backend } },
    .{ .id = frontend_button_id, .route = .{ .view = .frontend } },
};

fn routeFromStaticHit(hit_id: u32) ?Route {
    for (static_routes) |binding| {
        if (binding.id == hit_id) return binding.route;
    }
    return null;
}

pub fn contract() Contract {
    return .{
        .static_routes = &static_routes,
        .action_bindings = &action_bindings,
    };
}

pub fn trimPath(path: []const u8) []const u8 {
    if (path.len == 0) return RoutePath.frontend;
    if (path[0] != '/') return RoutePath.frontend;
    const query_start = std.mem.indexOfScalar(u8, path, '?') orelse path.len;
    const hash_start = std.mem.indexOfScalar(u8, path[0..query_start], '#') orelse query_start;
    const trimmed = path[0..hash_start];
    if (trimmed.len == 0) return RoutePath.frontend;
    return trimmed;
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
}

test "app_navigation route contract is deterministic for top-level views" {
    for (route_fixtures) |snapshot| {
        var path: [route_path_capacity]u8 = undefined;
        var hash: [route_hash_capacity]u8 = undefined;

        const path_len = try writePath(&path, snapshot.route);
        try std.testing.expectEqualStrings(snapshot.path, path[0..path_len]);
        try std.testing.expectEqual(snapshot.route, fromPath(snapshot.path));

        const hash_len = try writeHash(&hash, snapshot.route);
        try std.testing.expectEqualStrings(snapshot.hash, hash[0..hash_len]);
    }

    for (top_level_bindings) |binding| {
        try std.testing.expectEqual(binding.route, routeFor(.{ .button = binding.button }).?);
        try std.testing.expectEqual(binding.route, fromHit(topLevelButtonId(binding.button), .{}) orelse unreachable);
    }

    for (action_bindings) |entry| {
        if (entry.action == .open_context_source) {
            try std.testing.expectEqual(Route{ .view = .backend }, routeFor(.{ .action = entry.action }) orelse unreachable);
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
