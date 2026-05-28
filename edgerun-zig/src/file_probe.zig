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
    has_dimensions: bool = false,
    high_entropy: bool = false,
    likely_generated: bool = false,
    likely_source: bool = false,
    _reserved: u24 = 0,
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

pub const Dimensions = struct {
    width: u32 = 0,
    height: u32 = 0,
};

pub const Facts = struct {
    probe: Probe,
    extension: []const u8 = "",
    entropy_milli_bits: u16 = 0,
    printable_permille: u16 = 0,
    line_count: u32 = 0,
    dimensions: Dimensions = .{},

    pub fn hasDimensions(self: Facts) bool {
        return self.dimensions.width != 0 and self.dimensions.height != 0;
    }
};

pub fn probe(bytes: []const u8) Probe {
    return facts(bytes).probe;
}

pub fn probeWithName(bytes: []const u8, name: []const u8) Probe {
    return factsWithName(bytes, name).probe;
}

pub fn facts(bytes: []const u8) Facts {
    return factsWithName(bytes, "");
}

pub fn factsWithName(bytes: []const u8, name: []const u8) Facts {
    const ext = extensionSlice(name);
    const entropy = entropyMilliBits(bytes);
    const printable = printableRatioPermille(bytes);
    var out = Facts{
        .probe = .{
            .family = if (bytes.len == 0) .unknown else .binary,
            .subtype = 0,
            .size = @intCast(bytes.len),
            .capability = .{ .high_entropy = entropy >= 7500 },
        },
        .extension = ext,
        .entropy_milli_bits = entropy,
        .printable_permille = printable,
        .line_count = countLines(bytes),
    };

    if (media.detectFormat(bytes)) |_| {
        out.probe = imageProbe(.erimg, bytes.len, .{ .runtime = true, .has_dimensions = true, .high_entropy = entropy >= 7500 });
        if (media.decodeHeader(bytes)) |header| out.dimensions = .{ .width = @intCast(header.width), .height = @intCast(header.height) } else |_| {}
        return out;
    } else |_| {}

    if (media.importDetectFormat(bytes)) |format| {
        out.probe = switch (format) {
            .jpeg => imageProbe(.jpeg, bytes.len, .{ .import = true, .high_entropy = entropy >= 7500 }),
            .jxl => imageProbe(.jxl, bytes.len, .{ .import = true, .metadata_only = true, .high_entropy = entropy >= 7500 }),
            .png => imageProbe(.png, bytes.len, .{ .import = true, .high_entropy = entropy >= 7500 }),
            .tga => imageProbe(.tga, bytes.len, .{ .import = true, .high_entropy = entropy >= 7500 }),
            .webp => imageProbe(.webp, bytes.len, .{ .import = true, .high_entropy = entropy >= 7500 }),
        };
        if (media.importHeader(bytes)) |header| {
            out.dimensions = .{ .width = @intCast(header.width), .height = @intCast(header.height) };
            out.probe.capability.has_dimensions = true;
        } else |_| {}
        return out;
    } else |_| {}

    if (isZip(bytes)) {
        out.probe = .{
            .family = .archive,
            .subtype = @intFromEnum(ArchiveSubtype.zip),
            .size = @intCast(bytes.len),
            .capability = .{ .metadata_only = true, .high_entropy = entropy >= 7500 },
        };
        return out;
    }

    if (looksUtf8Text(bytes, name)) {
        out.probe = .{
            .family = .text,
            .subtype = @intFromEnum(TextSubtype.utf8),
            .size = @intCast(bytes.len),
            .capability = .{
                .text_indexable = true,
                .likely_source = hasSourceExtension(name),
                .likely_generated = hasGeneratedPathHint(name),
                .high_entropy = false,
            },
        };
        return out;
    }

    if (hasGeneratedPathHint(name)) out.probe.capability.likely_generated = true;
    return out;
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

fn countLines(bytes: []const u8) u32 {
    var count: u32 = if (bytes.len == 0) 0 else 1;
    for (bytes) |byte| {
        if (byte == '\n') count = count + 1;
    }
    return count;
}

fn printableRatioPermille(bytes: []const u8) u16 {
    if (bytes.len == 0) return 1000;
    var printable: usize = 0;
    for (bytes) |byte| {
        if ((byte >= 0x20 and byte <= 0x7e) or byte == '\n' or byte == '\r' or byte == '\t') printable += 1;
    }
    return @intCast((printable * 1000) / bytes.len);
}

fn entropyMilliBits(bytes: []const u8) u16 {
    if (bytes.len == 0) return 0;
    var counts = [_]usize{0} ** 256;
    for (bytes) |byte| counts[byte] += 1;
    var entropy: f64 = 0.0;
    const len_f: f64 = @floatFromInt(bytes.len);
    for (counts) |count| {
        if (count == 0) continue;
        const p = @as(f64, @floatFromInt(count)) / len_f;
        entropy -= p * std.math.log2(p);
    }
    return @intFromFloat(@round(std.math.clamp(entropy * 1000.0, 0.0, 8000.0)));
}

fn extensionSlice(name: []const u8) []const u8 {
    var slash_index: usize = 0;
    var index: usize = 0;
    while (index < name.len) : (index += 1) {
        if (name[index] == '/' or name[index] == '\\') slash_index = index + 1;
    }
    var dot_index: ?usize = null;
    index = slash_index;
    while (index < name.len) : (index += 1) {
        if (name[index] == '.') dot_index = index;
    }
    return if (dot_index) |dot| name[dot..] else "";
}

fn hasTextExtension(name: []const u8) bool {
    return hasSourceExtension(name) or
        endsWithIgnoreCase(name, ".txt") or
        endsWithIgnoreCase(name, ".md") or
        endsWithIgnoreCase(name, ".json") or
        endsWithIgnoreCase(name, ".yaml") or
        endsWithIgnoreCase(name, ".yml") or
        endsWithIgnoreCase(name, ".toml") or
        endsWithIgnoreCase(name, ".log") or
        endsWithIgnoreCase(name, ".html") or
        endsWithIgnoreCase(name, ".css");
}

fn hasSourceExtension(name: []const u8) bool {
    return endsWithIgnoreCase(name, ".zig") or
        endsWithIgnoreCase(name, ".c") or
        endsWithIgnoreCase(name, ".h") or
        endsWithIgnoreCase(name, ".cpp") or
        endsWithIgnoreCase(name, ".hpp") or
        endsWithIgnoreCase(name, ".rs") or
        endsWithIgnoreCase(name, ".go") or
        endsWithIgnoreCase(name, ".js") or
        endsWithIgnoreCase(name, ".ts") or
        endsWithIgnoreCase(name, ".py") or
        endsWithIgnoreCase(name, ".sh");
}

fn hasGeneratedPathHint(name: []const u8) bool {
    return containsPathPart(name, "node_modules") or
        containsPathPart(name, "zig-cache") or
        containsPathPart(name, ".zig-cache") or
        containsPathPart(name, "target") or
        containsPathPart(name, "dist") or
        containsPathPart(name, "build") or
        containsPathPart(name, ".git");
}

fn containsPathPart(name: []const u8, part: []const u8) bool {
    if (part.len == 0) return false;
    var cursor: usize = 0;
    while (cursor < name.len) {
        const slash = std.mem.indexOfScalarPos(u8, name, cursor, '/') orelse name.len;
        if (std.ascii.eqlIgnoreCase(name[cursor..slash], part)) return true;
        cursor = slash + 1;
    }
    return false;
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
    const result = facts(encoded);
    try std.testing.expectEqual(Family.image, result.probe.family);
    try std.testing.expectEqual(ImageSubtype.erimg, result.probe.imageSubtype().?);
    try std.testing.expect(result.probe.capability.runtime);
    try std.testing.expect(result.probe.capability.has_dimensions);
    try std.testing.expectEqual(@as(u32, 1), result.dimensions.width);
}

test "file probe classifies JPEG XL as metadata-only import image" {
    const bytes = [_]u8{ 0xff, 0x0a, 0x00, 0x01 };
    const result = facts(&bytes);
    try std.testing.expectEqual(Family.image, result.probe.family);
    try std.testing.expectEqual(ImageSubtype.jxl, result.probe.imageSubtype().?);
    try std.testing.expect(result.probe.capability.import);
    try std.testing.expect(result.probe.capability.metadata_only);
}

test "file probe returns text facts by extension and utf8" {
    const result = factsWithName("pub fn main() void {}\n", "src/main.zig");
    try std.testing.expectEqual(Family.text, result.probe.family);
    try std.testing.expectEqual(TextSubtype.utf8, result.probe.textSubtype().?);
    try std.testing.expect(result.probe.capability.text_indexable);
    try std.testing.expect(result.probe.capability.likely_source);
    try std.testing.expectEqualStrings(".zig", result.extension);
    try std.testing.expectEqual(@as(u32, 2), result.line_count);
}

test "file probe marks generated path hints" {
    const result = factsWithName("console.log(1)\n", "node_modules/pkg/index.js");
    try std.testing.expect(result.probe.capability.likely_generated);
    try std.testing.expect(result.probe.capability.likely_source);
}

test "file probe classifies zip signatures" {
    const bytes = [_]u8{ 0x50, 0x4b, 0x03, 0x04, 0, 0, 0, 0 };
    const result = facts(&bytes);
    try std.testing.expectEqual(Family.archive, result.probe.family);
    try std.testing.expectEqual(ArchiveSubtype.zip, result.probe.archiveSubtype().?);
}
