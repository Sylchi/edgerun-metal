const std = @import("std");

pub const Icon = enum(u8) {
    activity,
    app,
    bell,
    chat,
    check,
    chevron_right,
    code,
    cpu,
    database,
    eye,
    file,
    key,
    lock,
    menu,
    message_plus,
    network,
    route,
    search,
    send,
    server,
    settings,
    shield,
    sparkles,
    storage,
    terminal,
    trust,
    trash,
    user,
    wallet,
    warning,
    x,
    github,
};

pub const Provider = enum {
    lucide,
    tabler,
};

const Mapping = struct {
    label: []const u8,
    tabler: []const u8,
    lucide: []const u8,
};

const mappings = [_]Mapping{
    .{ .label = "activity", .tabler = "activity", .lucide = "activity" },
    .{ .label = "app", .tabler = "apps", .lucide = "app-window" },
    .{ .label = "bell", .tabler = "bell", .lucide = "bell" },
    .{ .label = "chat", .tabler = "message-circle", .lucide = "message-circle" },
    .{ .label = "check", .tabler = "check", .lucide = "check" },
    .{ .label = "chevron-right", .tabler = "chevron-right", .lucide = "chevron-right" },
    .{ .label = "code", .tabler = "code", .lucide = "code" },
    .{ .label = "cpu", .tabler = "cpu", .lucide = "cpu" },
    .{ .label = "database", .tabler = "database", .lucide = "database" },
    .{ .label = "eye", .tabler = "eye", .lucide = "eye" },
    .{ .label = "file", .tabler = "file", .lucide = "file" },
    .{ .label = "key", .tabler = "key", .lucide = "key" },
    .{ .label = "lock", .tabler = "lock", .lucide = "lock" },
    .{ .label = "menu", .tabler = "menu-2", .lucide = "menu" },
    .{ .label = "message-plus", .tabler = "message-plus", .lucide = "message-circle-plus" },
    .{ .label = "network", .tabler = "network", .lucide = "network" },
    .{ .label = "route", .tabler = "route", .lucide = "route" },
    .{ .label = "search", .tabler = "search", .lucide = "search" },
    .{ .label = "send", .tabler = "arrow-up", .lucide = "arrow-up" },
    .{ .label = "server", .tabler = "server", .lucide = "server" },
    .{ .label = "settings", .tabler = "settings", .lucide = "settings" },
    .{ .label = "shield", .tabler = "shield-check", .lucide = "shield-check" },
    .{ .label = "sparkles", .tabler = "sparkles", .lucide = "sparkles" },
    .{ .label = "storage", .tabler = "database", .lucide = "database" },
    .{ .label = "terminal", .tabler = "terminal-2", .lucide = "square-terminal" },
    .{ .label = "trust", .tabler = "shield-check", .lucide = "shield-check" },
    .{ .label = "trash", .tabler = "trash", .lucide = "trash-2" },
    .{ .label = "user", .tabler = "user", .lucide = "user" },
    .{ .label = "wallet", .tabler = "wallet", .lucide = "wallet" },
    .{ .label = "warning", .tabler = "alert-triangle", .lucide = "triangle-alert" },
    .{ .label = "x", .tabler = "x", .lucide = "x" },
    .{ .label = "github", .tabler = "brand-github", .lucide = "github" },
};

pub fn label(value: Icon) []const u8 {
    return mapping(value).label;
}

pub fn atlasId(value: Icon) u32 {
    return @as(u32, @intFromEnum(value)) + 1;
}

pub fn fromAtlasId(atlas_id: u32) ?Icon {
    if (atlas_id == 0 or atlas_id > mappings.len) return null;
    return @enumFromInt(atlas_id - 1);
}

pub fn providerName(value: Icon, provider: Provider) []const u8 {
    const found = mapping(value);
    return switch (provider) {
        .lucide => found.lucide,
        .tabler => found.tabler,
    };
}

fn mapping(value: Icon) Mapping {
    return mappings[@intFromEnum(value)];
}

test "icon atlas ids are stable and one based" {
    try std.testing.expectEqual(@as(u32, 1), atlasId(.activity));
    try std.testing.expectEqual(@as(u32, 18), atlasId(.search));
    try std.testing.expectEqual(Icon.search, fromAtlasId(18).?);
    try std.testing.expectEqual(Icon.github, fromAtlasId(32).?);
    try std.testing.expect(fromAtlasId(0) == null);
    try std.testing.expect(fromAtlasId(33) == null);
}

test "icon labels and provider names match C mappings" {
    try std.testing.expectEqualStrings("search", label(.search));
    try std.testing.expectEqualStrings("menu-2", providerName(.menu, .tabler));
    try std.testing.expectEqualStrings("app-window", providerName(.app, .lucide));
    try std.testing.expectEqualStrings("triangle-alert", providerName(.warning, .lucide));
    try std.testing.expectEqualStrings("brand-github", providerName(.github, .tabler));
}
