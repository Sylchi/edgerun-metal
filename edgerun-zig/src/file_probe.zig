const std = @import("std");
const media = @import("media/root.zig");

pub const Error = error{
    UnsupportedFile,
};

pub const Family = enum(u16) {
    image = 1,
    text = 2,
    archive = 3,
    binary = 4,
    unknown = 65535,
};

pub const ImageSubtype = enum(u16) {
    erimg = 1,
    jpeg = 2,
    jxl = 3,
    png = 4,
    tga = 5,
    webp = 6,
};

pub const TextSubtype = enum(u16) {
    utf8 = 1,
};

pub const ArchiveSubtype = enum(u16) {
    zip = 1,
};

pub const Capability = packed struct(u32) {
    runtime: bool = false,
    import: bool = false,
    metadata_only: bool = false,
    text_indexable: bool = false,
    _reserved: u28 = 0,
};

pub const Probe = struct {
    family: Family,
    subtype: u16,
    size: u64,
    capability: Capability,

    pub fn imageSubtype(self: Probe) ?ImageSubtype {
        if (self.family != .image) return null;
        return imageSubtypeFromInt(self.subtype);
    }

    pub fn textSubtype(self: Probe) ?TextSubtype {
        if (self.family != .text) return null;
        return switch (self.subtype) {
            @intFromEnum(TextSubtype.utf8) => .utf8,
            else => null,
        };
    }

    pub fn archiveSubtype(self: Probe) ?ArchiveSubtype {
        if (self.family != .archive) return null;
        return switch (self.subtype) {
            @intFromEnum(ArchiveSubtype.zip) => .zip,
            else => null,
        };
    }
};

pub fn probe(bytes: []const u8) Probe {
    return probeWithName(bytes, "");
}

pub fn probeWithName(bytes: []const u8, name: []const u8) Probe {
    if (media.detectFormat(bytes)) |_| {
        return imageProbe(.erimg, bytes.len, .{ .runtime = true });
    } else |_| {}

    if (media.importDetectFormat(bytes)) |format| {
        return switch (format) {
            .jpeg => imageProbe(.jpeg, bytes.len, .{ .import = true }),
            .jxl => imageProbe(.jxl, bytes.len, .{ .import = true, .metadata_only = true }),
            .png => imageProbe(.png, bytes.len, .{ .import = true }),
            .tga => imageProbe(.tga, bytes.len, .{ .import = true }),
            .webp => imageProbe(.webp, bytes.len, .{ .import = true }),
        };
    } else |_| {}

    if (isZip(bytes)) return .{
        .family = .archive,
        .subtype = @intFromEnum(ArchiveSubtype.zip),
        .size = @intCast(bytes.len),
        .capability = .{ .metadata_only = true },
    };

    if (looksUtf8Text(bytes, name)) return .{
        .family = .text,
        .subtype = @intFromEnum(TextSubtype.utf8),
        .size = @intCast(bytes.len),
        .capability = .{ .text_indexable = true },
    };

    return .{
        .family = if (bytes.len == 0) .unknown else .binary,
        .subtype = 0,
        .size = @intCast(bytes.len),
        .capability = .{},
    };
}

fn imageProbe(subtype: ImageSubtype, size: usize, capability: Capability) Probe {
    return .{
        .family = .image,
        .subtype = @intFromEnum(subtype),
        .size = @intCast(size),
        .capability = capability,
    };
}

fn imageSubtypeFromInt(value: u16) ?ImageSubtype {
    return switch (value) {
        @intFromEnum(ImageSubtype.erimg) => .erimg,
        @intFromEnum(ImageSubtype.jpeg) => .jpeg,
        @intFromEnum(ImageSubtype.jxl) => .jxl,
        @intFromEnum(ImageSubtype.png) => .png,
        @intFromEnum(ImageSubtype.tga) => .tga,
        @intFromEnum(ImageSubtype.webp) => .webp,
        else => null,
    };
}

fn isZip(bytes: []const u8) bool {
    if (bytes.len < 4) return false;
    return std.mem.eql(u8, bytes[0..4], &.{ 0x50, 0x4b, 0x03, 0x04 }) or
        std.mem.eql(u8, bytes[0..4], &.{ 0x50, 0x4b, 0x05, 0x06 }) or
        std.mem.eql(u8, bytes[0..4], &.{ 0x50, 0x4b, 0x07, 0x08 });
}

fn looksUtf8Text(bytes: []const u8, name: []const u8) bool {
    if (bytes.len == 0) return hasTextExtension(name);
    if (hasNul(bytes)) return false;
    if (std.unicode.utf8ValidateSlice(bytes)) {
        if (hasTextExtension(name)) return true;
        return printableRatioPermille(bytes) >= 800;
    }
    return false;
}

fn hasNul(bytes: []const u8) bool {
    for (bytes) |byte| if (byte == 0) return true;
    return false;
}

fn printableRatioPermille(bytes: []const u8) u16 {
    if (bytes.len == 0) return 1000;
    var printable: usize = 0;
    for (bytes) |byte| {
        if ((byte >= 0x20 and byte <= 0x7e) or byte == '\n' or byte == '\r' or byte == '\t') printable += 1;
    }
    return @intCast((printable * 1000) / bytes.len);
}

fn hasTextExtension(name: []const u8) bool {
    return endsWithIgnoreCase(name, ".txt") or
        endsWithIgnoreCase(name, ".md") or
        endsWithIgnoreCase(name, ".zig") or
        endsWithIgnoreCase(name, ".c") or
        endsWithIgnoreCase(name, ".h") or
        endsWithIgnoreCase(name, ".json") or
        endsWithIgnoreCase(name, ".yaml") or
        endsWithIgnoreCase(name, ".yml") or
        endsWithIgnoreCase(name, ".toml") or
        endsWithIgnoreCase(name, ".log") or
        endsWithIgnoreCase(name, ".html") or
        endsWithIgnoreCase(name, ".css") or
        endsWithIgnoreCase(name, ".js") or
        endsWithIgnoreCase(name, ".ts");
}

fn endsWithIgnoreCase(value: []const u8, suffix: []const u8) bool {
    if (suffix.len > value.len) return false;
    return std.ascii.eqlIgnoreCase(value[value.len - suffix.len ..], suffix);
}

test "file probe classifies ERIMG as runtime image" {
    const ui = @import("ui.zig");
    const runtime_image = @import("media/runtime_image.zig");
    const pixels = [_]ui.Color{.{ .r = 1, .g = 2, .b = 3, .a = 255 }};
    var canonical: [runtime_image.header_size + @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try runtime_image.encodeRgba(1, 1, &pixels, &canonical);
    const result = probe(encoded);
    try std.testing.expectEqual(Family.image, result.family);
    try std.testing.expectEqual(ImageSubtype.erimg, result.imageSubtype().?);
    try std.testing.expect(result.capability.runtime);
    try std.testing.expect(!result.capability.import);
}

test "file probe classifies JPEG XL as metadata-only import image" {
    const bytes = [_]u8{ 0xff, 0x0a, 0x00, 0x01 };
    const result = probe(&bytes);
    try std.testing.expectEqual(Family.image, result.family);
    try std.testing.expectEqual(ImageSubtype.jxl, result.imageSubtype().?);
    try std.testing.expect(result.capability.import);
    try std.testing.expect(result.capability.metadata_only);
}

test "file probe classifies text by extension and utf8" {
    const result = probeWithName("pub fn main() void {}\n", "main.zig");
    try std.testing.expectEqual(Family.text, result.family);
    try std.testing.expectEqual(TextSubtype.utf8, result.textSubtype().?);
    try std.testing.expect(result.capability.text_indexable);
}

test "file probe classifies zip signatures" {
    const bytes = [_]u8{ 0x50, 0x4b, 0x03, 0x04, 0, 0, 0, 0 };
    const result = probe(&bytes);
    try std.testing.expectEqual(Family.archive, result.family);
    try std.testing.expectEqual(ArchiveSubtype.zip, result.archiveSubtype().?);
}
