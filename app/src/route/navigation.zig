const std = @import("std");
const bytes = @import("../bytes.zig");
const preimage = @import("../preimage.zig");
const icon_component = @import("../ui/components/Icon.zig");

pub const ObjectId = preimage.Hash;
pub const object_id_bytes = preimage.hash_size;
pub const object_id_hex_bytes = object_id_bytes * 2;
pub const object_projection_prefix = "/o/";
pub const object_hash_projection_prefix = "#/o/";
pub const location_path_capacity: usize = object_projection_prefix.len + object_id_hex_bytes;
pub const location_hash_capacity: usize = object_hash_projection_prefix.len + object_id_hex_bytes;
pub const route_path_capacity: usize = location_path_capacity;
pub const route_hash_capacity: usize = location_hash_capacity;
pub const source_workspace_button_id: u32 = 30_012;
pub const app_preview_button_id: u32 = 30_000;
pub const backend_button_id: u32 = source_workspace_button_id;
pub const frontend_button_id: u32 = app_preview_button_id;
pub const reveal_identity_button_id: u32 = 15_001;

pub const TypeObject = struct {
    pub const type_definition = preimage.hash("edgerun:object:type", "type");
    pub const location = preimage.hash("edgerun:object:type", "location");
    pub const ui_surface = preimage.hash("edgerun:object:type", "ui.surface");
    pub const source_workspace = preimage.hash("edgerun:object:type", "source.workspace");
    pub const app_preview = preimage.hash("edgerun:object:type", "app.preview");
    pub const intent = preimage.hash("edgerun:object:type", "intent");
};

pub const SurfaceObject = struct {
    pub const source_workspace = typedObjectId(TypeObject.ui_surface, "surface:source-workspace");
    pub const app_preview = typedObjectId(TypeObject.ui_surface, "surface:app-preview");
};

pub const Action = enum(u32) {
    reveal_identity,
    download_source_release,
    launch_source_release,
    reset_source,
    open_context_source,
};

pub const SubNavBinding = enum {
    logo,
    docs,
    blog,
    source,
};

pub const MainButton = enum(u32) {
    source_workspace = 0,
    app_preview = 1,
};

pub const Location = struct {
    object: ObjectId = source_workspace_location_object,
};

pub const Route = Location;

pub const LocationFixture = struct {
    name: []const u8,
    location: Location,
    path: []const u8,
    hash: []const u8,
};

pub const RouteFixture = LocationFixture;

pub const source_workspace_location_object = locationObjectId(SurfaceObject.source_workspace);
pub const app_preview_location_object = locationObjectId(SurfaceObject.app_preview);

pub const location_fixtures = [_]LocationFixture{
    .{
        .name = "source-workspace",
        .location = .{ .object = source_workspace_location_object },
        .path = comptimeProjection(object_projection_prefix, source_workspace_location_object),
        .hash = comptimeProjection(object_hash_projection_prefix, source_workspace_location_object),
    },
    .{
        .name = "app-preview",
        .location = .{ .object = app_preview_location_object },
        .path = comptimeProjection(object_projection_prefix, app_preview_location_object),
        .hash = comptimeProjection(object_hash_projection_prefix, app_preview_location_object),
    },
};

pub const route_fixtures = location_fixtures;

pub const LocationFor = union(enum) {
    button: MainButton,
    action: Action,
    object: ObjectId,
};

pub const RouteFor = LocationFor;

pub fn subNavBinding(kind: SubNavBinding) TopLevelBinding {
    return switch (kind) {
        .logo, .docs, .blog => topLevelBinding(.app_preview),
        .source => topLevelBinding(.source_workspace),
    };
}

pub fn locationFor(target: LocationFor) ?Location {
    return switch (target) {
        .button => |button| locationForButton(button),
        .action => |action| locationForAction(action),
        .object => |object| .{ .object = object },
    };
}

pub fn routeFor(target: RouteFor) ?Route {
    return locationFor(target);
}

pub fn locationForButton(button: MainButton) Location {
    return topLevelBinding(button).location;
}

pub fn routeForButton(button: MainButton) Route {
    return locationForButton(button);
}

pub fn locationForAction(action: Action) ?Location {
    _ = action;
    return null;
}

pub fn routeForAction(action: Action) ?Route {
    return locationForAction(action);
}

pub fn locationForObject(object: ObjectId) Location {
    return .{ .object = object };
}

pub fn routeForSlug(slug: []const u8) Route {
    _ = slug;
    return .{};
}

pub fn fromPath(path: []const u8) Location {
    return parseProjection(path) catch .{};
}

pub fn fromHash(hash: []const u8) Location {
    return parseProjection(hash) catch .{};
}

pub fn fromHit(hit_id: u32, _current: Location) ?Location {
    _ = _current;
    for (static_locations) |binding| {
        if (binding.id == hit_id) return binding.location;
    }
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

pub fn writePath(out: []u8, location: Location) error{RouteBufferTooSmall}!usize {
    return writeProjection(out, object_projection_prefix, location.object);
}

pub fn writeHash(out: []u8, location: Location) error{RouteBufferTooSmall}!usize {
    return writeProjection(out, object_hash_projection_prefix, location.object);
}

pub fn pathFromHash(hash: []const u8) error{InvalidRouteHash}![]const u8 {
    if (!bytes.startsWith(hash, object_hash_projection_prefix)) return error.InvalidRouteHash;
    return hash[1..];
}

pub fn isSourceWorkspace(location: Location) bool {
    return bytes.eql(&location.object, &source_workspace_location_object);
}

pub fn isAppPreview(location: Location) bool {
    return bytes.eql(&location.object, &app_preview_location_object);
}

pub const LocationBinding = struct { id: u32, location: Location };
pub const HitRoute = LocationBinding;
pub const ActionBinding = struct { id: u32, action: Action };

pub const Contract = struct {
    static_locations: []const LocationBinding,
    action_bindings: []const ActionBinding,
};

pub const TopLevelBinding = struct {
    button: MainButton,
    id: u32,
    location: Location,
    icon: icon_component.Icon,
    rail_label: []const u8,
    row_title: []const u8,
    row_detail: []const u8,
};

const top_level_bindings = [_]TopLevelBinding{
    .{
        .button = .source_workspace,
        .id = source_workspace_button_id,
        .location = .{ .object = source_workspace_location_object },
        .icon = icon_component.Icon.named(.code),
        .rail_label = "Source",
        .row_title = "Source",
        .row_detail = "object workspace",
    },
    .{
        .button = .app_preview,
        .id = app_preview_button_id,
        .location = .{ .object = app_preview_location_object },
        .icon = icon_component.Icon.named(.eye),
        .rail_label = "Preview",
        .row_title = "Preview",
        .row_detail = "app surface object",
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
    .{ .id = 90_002, .action = .download_source_release },
    .{ .id = 90_003, .action = .launch_source_release },
    .{ .id = 90_004, .action = .reset_source },
    .{ .id = 90_005, .action = .open_context_source },
};

pub const static_locations = [_]LocationBinding{
    .{ .id = source_workspace_button_id, .location = .{ .object = source_workspace_location_object } },
    .{ .id = app_preview_button_id, .location = .{ .object = app_preview_location_object } },
};

pub const static_routes = static_locations;

pub fn contract() Contract {
    return .{
        .static_locations = &static_locations,
        .action_bindings = &action_bindings,
    };
}

fn typedObjectId(type_id: ObjectId, name: []const u8) ObjectId {
    var builder = preimage.Builder.init("edgerun:object:typed");
    builder.hash(type_id);
    builder.bytes(name);
    return builder.final();
}

fn locationObjectId(surface: ObjectId) ObjectId {
    var builder = preimage.Builder.init("edgerun:object:location");
    builder.hash(TypeObject.location);
    builder.hash(surface);
    return builder.final();
}

fn writeProjection(out: []u8, prefix: []const u8, object: ObjectId) error{RouteBufferTooSmall}!usize {
    if (prefix.len + object_id_hex_bytes > out.len) return error.RouteBufferTooSmall;
    @memcpy(out[0..prefix.len], prefix);
    writeHex(out[prefix.len..][0..object_id_hex_bytes], object);
    return prefix.len + object_id_hex_bytes;
}

fn parseProjection(value: []const u8) error{InvalidRouteHash}!Location {
    const raw = if (bytes.startsWith(value, object_hash_projection_prefix))
        value[object_hash_projection_prefix.len..]
    else if (bytes.startsWith(value, object_projection_prefix))
        value[object_projection_prefix.len..]
    else
        return error.InvalidRouteHash;
    if (raw.len != object_id_hex_bytes) return error.InvalidRouteHash;
    var object: ObjectId = undefined;
    try readHex(raw, &object);
    return .{ .object = object };
}

fn writeHex(out: []u8, value: ObjectId) void {
    for (value, 0..) |byte, index| {
        out[index * 2] = hexChar(byte >> 4);
        out[index * 2 + 1] = hexChar(byte & 0x0f);
    }
}

fn readHex(raw: []const u8, out: *ObjectId) error{InvalidRouteHash}!void {
    for (out, 0..) |*byte, index| {
        const hi = hexValue(raw[index * 2]) orelse return error.InvalidRouteHash;
        const lo = hexValue(raw[index * 2 + 1]) orelse return error.InvalidRouteHash;
        byte.* = (hi << 4) | lo;
    }
}

fn hexChar(value: u8) u8 {
    return if (value < 10) '0' + value else 'a' + (value - 10);
}

fn hexValue(value: u8) ?u8 {
    return switch (value) {
        '0'...'9' => value - '0',
        'a'...'f' => value - 'a' + 10,
        'A'...'F' => value - 'A' + 10,
        else => null,
    };
}

fn comptimeProjection(comptime prefix: []const u8, comptime object: ObjectId) []const u8 {
    comptime {
        var out: [prefix.len + object_id_hex_bytes]u8 = undefined;
        @memcpy(out[0..prefix.len], prefix);
        for (object, 0..) |byte, index| {
            out[prefix.len + index * 2] = hexChar(byte >> 4);
            out[prefix.len + index * 2 + 1] = hexChar(byte & 0x0f);
        }
        const final = out;
        return &final;
    }
}

comptime {
    if (top_level_bindings.len != @typeInfo(MainButton).@"enum".fields.len) {
        @compileError("top_level_bindings must cover every MainButton enum value");
    }
}

test "navigation projections are content object ids" {
    for (location_fixtures) |snapshot| {
        var path: [location_path_capacity]u8 = undefined;
        var hash: [location_hash_capacity]u8 = undefined;

        const path_len = try writePath(&path, snapshot.location);
        try std.testing.expectEqualStrings(snapshot.path, path[0..path_len]);
        try std.testing.expectEqual(snapshot.location, fromPath(snapshot.path));

        const hash_len = try writeHash(&hash, snapshot.location);
        try std.testing.expectEqualStrings(snapshot.hash, hash[0..hash_len]);
        try std.testing.expectEqual(snapshot.location, fromHash(snapshot.hash));
    }

    try std.testing.expect(isSourceWorkspace(locationForButton(.source_workspace)));
    try std.testing.expect(isAppPreview(locationForButton(.app_preview)));
}

test "navigation hit ids resolve to object locations and intents" {
    for (static_locations) |entry| {
        try std.testing.expectEqual(entry.location, fromHit(entry.id, .{}) orelse unreachable);
    }

    for (action_bindings) |entry| {
        try std.testing.expectEqual(entry.action, actionFromHit(entry.id).?);
    }
}
