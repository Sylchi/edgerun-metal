const std = @import("std");
const bytes = @import("../bytes.zig");
const icon_component = @import("../ui/components/Icon.zig");

pub const ObjectId = [32]u8;
pub const object_id_bytes = 32;
pub const object_id_hex_bytes = object_id_bytes * 2;
pub const object_projection_prefix = "/o/";
pub const object_hash_projection_prefix = "#/o/";
pub const path_projection_capacity: usize = object_projection_prefix.len + object_id_hex_bytes;
pub const hash_projection_capacity: usize = object_hash_projection_prefix.len + object_id_hex_bytes;
pub const source_workspace_button_id: u32 = 30_012;
pub const app_preview_button_id: u32 = 30_000;
pub const reveal_identity_button_id: u32 = 15_001;

pub const TypeObject = struct {
    pub const type_definition = hexId("e135fafe25277aae6cb2fe6dbc2666624f6fbc1edd954fb36c6f0a7103ba53e5");
    pub const location = hexId("aa63d9733d7f22608efa74fd8e5b635470892d608bb39ee48228a492855610d3");
    pub const ui_surface = hexId("430640c20e87a74b0473a00687586f2d53231428c8a7a122492445958e17d43b");
    pub const source_workspace = hexId("0d2134ea795c834ebed586d8e35b9644742cdb99eb980d9dff06bf2ce871727c");
    pub const app_preview = hexId("8ac05974c9952c884df4391fbea4af98d8a9c374981f8ba6ccb087e8da5b5401");
    pub const intent = hexId("f6856cf01cce2546fec5239fd0aa71d72f826ae512944953cae326d498e9213f");
};

pub const SurfaceObject = struct {
    pub const source_workspace = hexId("205ac3c9c7ca2ec8c2f83bee439853d05816c53d4f3c3e440367442717aacaa1");
    pub const app_preview = hexId("b95d242bccbc36d7d33f3d2c6ad0ce966a3885cd64340080c32e067e20195963");
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

pub const LocationFixture = struct {
    name: []const u8,
    location: Location,
    path: []const u8,
    hash: []const u8,
};

pub const source_workspace_location_object = hexId("3ceeb2766f06e254fd48cf0a0767fd75117e03b14931b1a0d93a2f0657815a34");
pub const app_preview_location_object = hexId("db0ce6ac80b7fe48a3d8bb96cfb9106428626754c15be4a410d9c197bab19675");

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

pub const LocationFor = union(enum) {
    button: MainButton,
    action: Action,
    object: ObjectId,
};

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

pub fn locationForButton(button: MainButton) Location {
    return topLevelBinding(button).location;
}

pub fn locationForAction(action: Action) ?Location {
    _ = action;
    return null;
}

pub fn locationForObject(object: ObjectId) Location {
    return .{ .object = object };
}

pub fn fromPathProjection(path: []const u8) Location {
    return parseProjection(path) catch .{};
}

pub fn fromHashProjection(hash: []const u8) Location {
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

pub fn writePathProjection(out: []u8, location: Location) error{ProjectionBufferTooSmall}!usize {
    return writeProjection(out, object_projection_prefix, location.object);
}

pub fn writeHashProjection(out: []u8, location: Location) error{ProjectionBufferTooSmall}!usize {
    return writeProjection(out, object_hash_projection_prefix, location.object);
}

pub fn pathProjectionFromHashProjection(hash: []const u8) error{InvalidLocationProjection}![]const u8 {
    if (!bytes.startsWith(hash, object_hash_projection_prefix)) return error.InvalidLocationProjection;
    return hash[1..];
}

pub fn isSourceWorkspace(location: Location) bool {
    return bytes.eql(&location.object, &source_workspace_location_object);
}

pub fn isAppPreview(location: Location) bool {
    return bytes.eql(&location.object, &app_preview_location_object);
}

pub const LocationBinding = struct { id: u32, location: Location };
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

pub fn contract() Contract {
    return .{
        .static_locations = &static_locations,
        .action_bindings = &action_bindings,
    };
}

fn writeProjection(out: []u8, prefix: []const u8, object: ObjectId) error{ProjectionBufferTooSmall}!usize {
    if (prefix.len + object_id_hex_bytes > out.len) return error.ProjectionBufferTooSmall;
    @memcpy(out[0..prefix.len], prefix);
    writeHex(out[prefix.len..][0..object_id_hex_bytes], object);
    return prefix.len + object_id_hex_bytes;
}

fn parseProjection(value: []const u8) error{InvalidLocationProjection}!Location {
    const raw = if (bytes.startsWith(value, object_hash_projection_prefix))
        value[object_hash_projection_prefix.len..]
    else if (bytes.startsWith(value, object_projection_prefix))
        value[object_projection_prefix.len..]
    else
        return error.InvalidLocationProjection;
    if (raw.len != object_id_hex_bytes) return error.InvalidLocationProjection;
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

fn readHex(raw: []const u8, out: *ObjectId) error{InvalidLocationProjection}!void {
    for (out, 0..) |*byte, index| {
        const hi = hexValue(raw[index * 2]) orelse return error.InvalidLocationProjection;
        const lo = hexValue(raw[index * 2 + 1]) orelse return error.InvalidLocationProjection;
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

fn hexId(comptime raw: []const u8) ObjectId {
    comptime {
        if (raw.len != object_id_hex_bytes) @compileError("object id hex must be 32 bytes");
        var out: ObjectId = undefined;
        var index: usize = 0;
        while (index < object_id_bytes) : (index += 1) {
            const hi = hexValue(raw[index * 2]) orelse @compileError("invalid object id hex");
            const lo = hexValue(raw[index * 2 + 1]) orelse @compileError("invalid object id hex");
            out[index] = (hi << 4) | lo;
        }
        return out;
    }
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
        var path: [path_projection_capacity]u8 = undefined;
        var hash: [hash_projection_capacity]u8 = undefined;

        const path_len = try writePathProjection(&path, snapshot.location);
        try std.testing.expectEqualStrings(snapshot.path, path[0..path_len]);
        try std.testing.expectEqual(snapshot.location, fromPathProjection(snapshot.path));

        const hash_len = try writeHashProjection(&hash, snapshot.location);
        try std.testing.expectEqualStrings(snapshot.hash, hash[0..hash_len]);
        try std.testing.expectEqual(snapshot.location, fromHashProjection(snapshot.hash));
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
