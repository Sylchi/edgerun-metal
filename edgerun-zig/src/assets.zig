const std = @import("std");
const icon = @import("icon.zig");
const icon_vector = @import("icon_vector.zig");

pub const Status = enum {
    ok,
    empty_name,
    name_too_long,
    icon_count_exceeded,
    missing_required_icon,
    duplicate_icon,
    icon_provider_name_mismatch,
    invalid_icon_vector,
    font_face_count_exceeded,
    missing_default_font_face,
    missing_font_char,
    invalid_font_atlas,
    emoji_count_exceeded,
    missing_required_emoji,
    duplicate_emoji,
};

pub const Limits = struct {
    max_icon_count: usize,
    max_icon_vector_bytes: usize,
    max_font_faces: usize,
    max_font_atlas_side: u32,
    max_font_atlas_bytes: usize,
    max_emoji_count: usize,
    max_name_len: usize,
};

pub const IconPackEntry = struct {
    value: icon.Icon,
    provider_name: []const u8,
};

pub const IconPackSpec = struct {
    name: []const u8,
    provider: icon.Provider,
    entries: []const IconPackEntry,
    vector_bytes: usize,
};

pub const FontFaceSpec = struct {
    name: []const u8,
    default_face: bool,
    covered_chars: []const u8,
};

pub const FontPackSpec = struct {
    name: []const u8,
    faces: []const FontFaceSpec,
    atlas_width: u32,
    atlas_height: u32,
    atlas_bytes: usize,
};

pub const EmojiSpec = struct {
    key: []const u8,
    label: []const u8,
};

pub const EmojiPackSpec = struct {
    name: []const u8,
    emoji: []const EmojiSpec,
};

pub const AssetPackSpec = struct {
    name: []const u8,
    icons: IconPackSpec,
    fonts: FontPackSpec,
    emoji: EmojiPackSpec,
};

pub const required_font_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.:/#@[](){}<>+=%$!?&, ";

pub fn defaultLimits() Limits {
    return .{
        .max_icon_count = 256,
        .max_icon_vector_bytes = 64 * 1024,
        .max_font_faces = 8,
        .max_font_atlas_side = 4096,
        .max_font_atlas_bytes = 16_777_216,
        .max_emoji_count = 256,
        .max_name_len = 96,
    };
}

pub fn validateIconPack(pack: IconPackSpec, limits: Limits) Status {
    const name_status = validateName(pack.name, limits);
    if (name_status != .ok) return name_status;
    if (pack.entries.len > limits.max_icon_count) return .icon_count_exceeded;
    if (pack.vector_bytes == 0 or pack.vector_bytes > limits.max_icon_vector_bytes) return .invalid_icon_vector;

    for (pack.entries, 0..) |entry, i| {
        for (pack.entries[i + 1 ..]) |other| {
            if (entry.value == other.value) return .duplicate_icon;
        }
        if (!std.mem.eql(u8, entry.provider_name, icon.providerName(entry.value, pack.provider))) {
            return .icon_provider_name_mismatch;
        }
    }

    for (std.enums.values(icon.Icon)) |required| {
        var found = false;
        for (pack.entries) |entry| {
            if (entry.value == required) found = true;
        }
        if (!found) return .missing_required_icon;
    }
    return .ok;
}

pub fn validateFontPack(pack: FontPackSpec, limits: Limits) Status {
    const name_status = validateName(pack.name, limits);
    if (name_status != .ok) return name_status;
    if (pack.faces.len == 0 or pack.faces.len > limits.max_font_faces) return .font_face_count_exceeded;
    if (pack.atlas_width == 0 or pack.atlas_height == 0 or
        pack.atlas_width > limits.max_font_atlas_side or
        pack.atlas_height > limits.max_font_atlas_side or
        pack.atlas_bytes == 0 or pack.atlas_bytes > limits.max_font_atlas_bytes)
    {
        return .invalid_font_atlas;
    }

    var default_face: ?FontFaceSpec = null;
    for (pack.faces) |face| {
        if (face.default_face) default_face = face;
    }
    const face = default_face orelse return .missing_default_font_face;
    for (required_font_chars) |required| {
        if (std.mem.indexOfScalar(u8, face.covered_chars, required) == null) return .missing_font_char;
    }
    return .ok;
}

pub fn validateEmojiPack(pack: EmojiPackSpec, limits: Limits) Status {
    const name_status = validateName(pack.name, limits);
    if (name_status != .ok) return name_status;
    if (pack.emoji.len > limits.max_emoji_count) return .emoji_count_exceeded;
    for (pack.emoji, 0..) |entry, i| {
        for (pack.emoji[i + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.key, other.key)) return .duplicate_emoji;
        }
    }
    for (required_emoji) |required| {
        var found = false;
        for (pack.emoji) |entry| {
            if (std.mem.eql(u8, entry.key, required.key)) found = true;
        }
        if (!found) return .missing_required_emoji;
    }
    return .ok;
}

pub fn validate(pack: AssetPackSpec, limits: Limits) Status {
    const name_status = validateName(pack.name, limits);
    if (name_status != .ok) return name_status;
    const icon_status = validateIconPack(pack.icons, limits);
    if (icon_status != .ok) return icon_status;
    const font_status = validateFontPack(pack.fonts, limits);
    if (font_status != .ok) return font_status;
    return validateEmojiPack(pack.emoji, limits);
}

pub fn tablerInterPack() AssetPackSpec {
    return .{
        .name = "ui-tabler-inter",
        .icons = .{
            .name = "tabler-svg",
            .provider = .tabler,
            .entries = &tabler_icon_entries,
            .vector_bytes = bundledIconVectorBytes(),
        },
        .fonts = .{
            .name = "inter",
            .faces = &inter_font_faces,
            .atlas_width = bundled_font_atlas_side,
            .atlas_height = bundled_font_atlas_side,
            .atlas_bytes = bundled_font_atlas_side * bundled_font_atlas_side,
        },
        .emoji = .{ .name = "ui-semantic-emoji", .emoji = &required_emoji },
    };
}

pub fn lucideGeistPack() AssetPackSpec {
    return .{
        .name = "ui-lucide-geist",
        .icons = .{
            .name = "lucide-svg",
            .provider = .lucide,
            .entries = &lucide_icon_entries,
            .vector_bytes = bundledIconVectorBytes(),
        },
        .fonts = .{
            .name = "geist",
            .faces = &geist_font_faces,
            .atlas_width = bundled_font_atlas_side,
            .atlas_height = bundled_font_atlas_side,
            .atlas_bytes = bundled_font_atlas_side * bundled_font_atlas_side,
        },
        .emoji = .{ .name = "ui-semantic-emoji", .emoji = &required_emoji },
    };
}

fn validateName(name: []const u8, limits: Limits) Status {
    if (name.len == 0) return .empty_name;
    if (name.len > limits.max_name_len) return .name_too_long;
    return .ok;
}

fn iconEntries(comptime provider: icon.Provider) [std.enums.values(icon.Icon).len]IconPackEntry {
    const values = std.enums.values(icon.Icon);
    var entries: [values.len]IconPackEntry = undefined;
    for (values, 0..) |value, i| {
        entries[i] = .{ .value = value, .provider_name = icon.providerName(value, provider) };
    }
    return entries;
}

const bundled_font_atlas_side: u32 = 1024;
const tabler_icon_entries = iconEntries(.tabler);
const lucide_icon_entries = iconEntries(.lucide);
const inter_font_faces = [_]FontFaceSpec{.{ .name = "Inter", .default_face = true, .covered_chars = required_font_chars }};
const geist_font_faces = [_]FontFaceSpec{.{ .name = "Geist", .default_face = true, .covered_chars = required_font_chars }};
const required_emoji = [_]EmojiSpec{
    .{ .key = "check", .label = "check" },
    .{ .key = "warning", .label = "warning" },
    .{ .key = "locked", .label = "locked" },
    .{ .key = "unlocked", .label = "unlocked" },
    .{ .key = "route", .label = "route" },
    .{ .key = "storage", .label = "storage" },
    .{ .key = "document", .label = "document" },
    .{ .key = "surface", .label = "surface" },
};

fn bundledIconVectorBytes() usize {
    var total: usize = 0;
    for (std.enums.values(icon.Icon)) |value| {
        total += icon_vector.data(value).len * @sizeOf(f32);
    }
    return total;
}

test "bundled asset packs validate" {
    const limits = defaultLimits();
    const tabler = tablerInterPack();
    const lucide = lucideGeistPack();
    try std.testing.expectEqual(Status.ok, validate(tabler, limits));
    try std.testing.expectEqual(Status.ok, validate(lucide, limits));
    try std.testing.expectEqualStrings("ui-lucide-geist", lucide.name);
    try std.testing.expectEqualStrings("Geist", lucide.fonts.faces[0].name);
    try std.testing.expectEqual(std.enums.values(icon.Icon).len, tabler.icons.entries.len);
}

test "icon font and emoji validation reject incomplete packs" {
    const limits = defaultLimits();
    var pack = tablerInterPack();
    pack.icons.entries = pack.icons.entries[0 .. pack.icons.entries.len - 1];
    try std.testing.expectEqual(Status.missing_required_icon, validate(pack, limits));

    pack = tablerInterPack();
    const mismatched = [_]IconPackEntry{
        .{ .value = .activity, .provider_name = "activity" },
        .{ .value = .app, .provider_name = "apps" },
    };
    pack.icons.provider = .lucide;
    pack.icons.entries = &mismatched;
    try std.testing.expectEqual(Status.icon_provider_name_mismatch, validateIconPack(pack.icons, limits));

    pack = tablerInterPack();
    const bad_font = [_]FontFaceSpec{.{ .name = "Inter", .default_face = true, .covered_chars = "abc" }};
    pack.fonts.faces = &bad_font;
    try std.testing.expectEqual(Status.missing_font_char, validate(pack, limits));

    pack = tablerInterPack();
    pack.emoji.emoji = pack.emoji.emoji[0 .. pack.emoji.emoji.len - 1];
    try std.testing.expectEqual(Status.missing_required_emoji, validate(pack, limits));
}
