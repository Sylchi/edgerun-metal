const std = @import("std");
const bytes = @import("../bytes.zig");
const preimage = @import("../preimage.zig");
const data_chunk = @import("data_chunk.zig");

pub const magic = "ERMETA01";
pub const version: u16 = 1;
pub const header_size: usize = 8 + 2 + 2 + 4 + preimage.hash_size;
pub const entry_header_size: usize = 1 + 3 + 4 + preimage.hash_size;
pub const confidence_scale: u32 = 1_000_000;
pub const max_entries: usize = 4096;

pub const Error = data_chunk.Error || error{
    BadArgument,
};

pub const Kind = enum(u8) {
    text = 1,
    facet = 2,
    tag = 3,
    relation = 4,
    evidence = 5,
};

pub const Entry = struct {
    kind: Kind,
    confidence_ppm: u32 = confidence_scale,
    key: data_chunk.DataChunk,
    value: data_chunk.DataChunk,
    target: ?preimage.Hash = null,

    pub fn text(key: []const u8, value: []const u8) Entry {
        return .{ .kind = .text, .key = data_chunk.DataChunk.init(key), .value = data_chunk.DataChunk.init(value) };
    }

    pub fn facet(key: []const u8, value: []const u8) Entry {
        return .{ .kind = .facet, .key = data_chunk.DataChunk.init(key), .value = data_chunk.DataChunk.init(value) };
    }

    pub fn tag(value: []const u8) Entry {
        return .{ .kind = .tag, .key = data_chunk.DataChunk.init(""), .value = data_chunk.DataChunk.init(value) };
    }

    pub fn relation(relation_type: []const u8, target: preimage.Hash) Entry {
        return .{ .kind = .relation, .key = data_chunk.DataChunk.init(relation_type), .value = data_chunk.DataChunk.init(""), .target = target };
    }

    pub fn evidence(evidence_type: []const u8, target: preimage.Hash) Entry {
        return .{ .kind = .evidence, .key = data_chunk.DataChunk.init(evidence_type), .value = data_chunk.DataChunk.init(""), .target = target };
    }

    pub fn valid(self: Entry) bool {
        if (self.confidence_ppm > confidence_scale) return false;
        if (!self.key.valid() or !self.value.valid()) return false;
        switch (self.kind) {
            .text, .facet => return self.key.length != 0 and self.value.length != 0 and self.target == null,
            .tag => return self.key.length == 0 and self.value.length != 0 and self.target == null,
            .relation, .evidence => return self.key.length != 0 and self.value.length == 0 and self.target != null,
        }
    }

    pub fn canonicalLen(self: Entry) Error!usize {
        if (!self.valid()) return error.BadArgument;
        return checkedAdd(entry_header_size, checkedAdd(self.key.canonicalLen(), self.value.canonicalLen()) catch return error.NoSpace);
    }

    pub fn encode(self: Entry, out: []u8) Error![]u8 {
        const needed = try self.canonicalLen();
        if (out.len < needed) return error.NoSpace;
        out[0] = @intFromEnum(self.kind);
        out[1] = 0;
        out[2] = 0;
        out[3] = 0;
        _ = bytes.store32(out[4..8], self.confidence_ppm);
        if (self.target) |target| {
            @memcpy(out[8..40], &target);
        } else {
            @memset(out[8..40], 0);
        }
        var cursor: usize = entry_header_size;
        cursor += (try self.key.encode(out[cursor..])).len;
        cursor += (try self.value.encode(out[cursor..])).len;
        return out[0..cursor];
    }
};

pub const Metadata = struct {
    subject: preimage.Hash,
    confidence_ppm: u32 = confidence_scale,
    entries: []const Entry,

    pub fn valid(self: Metadata) bool {
        if (!bytes.nonzero(&self.subject) or self.confidence_ppm > confidence_scale or self.entries.len > max_entries) return false;
        for (self.entries, 0..) |entry, index| {
            if (!entry.valid()) return false;
            if (index != 0 and entryOrder(self.entries[index - 1], entry) != .lt) return false;
        }
        return true;
    }

    pub fn canonicalLen(self: Metadata) Error!usize {
        if (!self.valid()) return error.BadArgument;
        var total: usize = header_size;
        for (self.entries) |entry| total = try checkedAdd(total, try entry.canonicalLen());
        return total;
    }

    pub fn encode(self: Metadata, out: []u8) Error![]u8 {
        const needed = try self.canonicalLen();
        if (out.len < needed) return error.NoSpace;
        @memcpy(out[0..magic.len], magic);
        _ = bytes.store16(out[8..10], version);
        _ = bytes.store16(out[10..12], 0);
        _ = bytes.store32(out[12..16], self.confidence_ppm);
        @memcpy(out[16..48], &self.subject);
        var cursor: usize = header_size;
        for (self.entries) |entry| cursor += (try entry.encode(out[cursor..])).len;
        return out[0..cursor];
    }
};

pub const DecodedEntry = struct {
    entry: Entry,
    used: usize,
};

pub fn decode(canonical: []const u8, out_entries: []Entry) Error!Metadata {
    if (canonical.len < header_size) return error.Corrupt;
    if (!bytes.eql(canonical[0..magic.len], magic)) return error.Corrupt;
    if ((bytes.load16(canonical[8..10]) orelse return error.Corrupt) != version) return error.Corrupt;
    if ((bytes.load16(canonical[10..12]) orelse return error.Corrupt) != 0) return error.Corrupt;
    const confidence_ppm = bytes.load32(canonical[12..16]) orelse return error.Corrupt;
    var subject: preimage.Hash = undefined;
    @memcpy(&subject, canonical[16..48]);
    var cursor: usize = header_size;
    var count: usize = 0;
    while (cursor < canonical.len) : (count += 1) {
        if (count >= out_entries.len) return error.NoSpace;
        const decoded = try decodeEntryPrefix(canonical[cursor..]);
        out_entries[count] = decoded.entry;
        cursor += decoded.used;
    }
    const metadata = Metadata{ .subject = subject, .confidence_ppm = confidence_ppm, .entries = out_entries[0..count] };
    if (!metadata.valid()) return error.Corrupt;
    return metadata;
}

pub fn decodeEntryPrefix(canonical: []const u8) Error!DecodedEntry {
    if (canonical.len < entry_header_size) return error.Corrupt;
    if (canonical[1] != 0 or canonical[2] != 0 or canonical[3] != 0) return error.Corrupt;
    const kind = kindFromTag(canonical[0]) orelse return error.Corrupt;
    const confidence_ppm = bytes.load32(canonical[4..8]) orelse return error.Corrupt;
    var target_raw: preimage.Hash = undefined;
    @memcpy(&target_raw, canonical[8..40]);
    var cursor: usize = entry_header_size;
    const key_decoded = try data_chunk.decodePrefix(canonical[cursor..]);
    cursor += key_decoded.used;
    const value_decoded = try data_chunk.decodePrefix(canonical[cursor..]);
    cursor += value_decoded.used;
    const target = if (bytes.nonzero(&target_raw)) target_raw else null;
    const entry = Entry{
        .kind = kind,
        .confidence_ppm = confidence_ppm,
        .key = key_decoded.chunk,
        .value = value_decoded.chunk,
        .target = target,
    };
    if (!entry.valid()) return error.Corrupt;
    return .{ .entry = entry, .used = cursor };
}

pub fn id(metadata_canonical: []const u8) Error!preimage.Hash {
    var entries: [max_entries]Entry = undefined;
    _ = try decode(metadata_canonical, &entries);
    return preimage.hash("edgerun:metadata:v1", metadata_canonical);
}

fn kindFromTag(tag: u8) ?Kind {
    return switch (tag) {
        @intFromEnum(Kind.text) => .text,
        @intFromEnum(Kind.facet) => .facet,
        @intFromEnum(Kind.tag) => .tag,
        @intFromEnum(Kind.relation) => .relation,
        @intFromEnum(Kind.evidence) => .evidence,
        else => null,
    };
}

fn entryOrder(left: Entry, right: Entry) std.math.Order {
    const kind_order = std.math.order(@intFromEnum(left.kind), @intFromEnum(right.kind));
    if (kind_order != .eq) return kind_order;
    const key_order = std.mem.order(u8, left.key.body(), right.key.body());
    if (key_order != .eq) return key_order;
    const value_order = std.mem.order(u8, left.value.body(), right.value.body());
    if (value_order != .eq) return value_order;
    const left_target = left.target orelse [_]u8{0} ** preimage.hash_size;
    const right_target = right.target orelse [_]u8{0} ** preimage.hash_size;
    return std.mem.order(u8, &left_target, &right_target);
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch error.NoSpace;
}

test "metadata object encodes sorted indexable claims" {
    const subject = preimage.rawHash("subject object");
    const project = preimage.rawHash("project_portable_debug_tool");
    const entries = [_]Entry{
        Entry.text("description", "Short natural language description"),
        Entry.text("name", "Human readable name"),
        Entry.text("type", "component"),
        Entry.facet("domain", "electronics"),
        Entry.facet("function", "power"),
        Entry.facet("location", "bin_a"),
        Entry.facet("status", "available"),
        Entry.facet("subtype", "buck_converter"),
        Entry.tag("esp32"),
        Entry.tag("lazada"),
        Entry.tag("power"),
        Entry.relation("used_in", project),
    };
    const metadata = Metadata{ .subject = subject, .confidence_ppm = 900_000, .entries = &entries };
    var canonical: [4096]u8 = undefined;
    const encoded = try metadata.encode(&canonical);
    var decoded_entries: [entries.len]Entry = undefined;
    const decoded = try decode(encoded, &decoded_entries);
    try std.testing.expect(decoded.valid());
    try std.testing.expectEqualSlices(u8, &subject, &decoded.subject);
    try std.testing.expectEqual(@as(u32, 900_000), decoded.confidence_ppm);
    try std.testing.expectEqual(entries.len, decoded.entries.len);
    try std.testing.expectEqualStrings("domain", decoded.entries[3].key.body());
    try std.testing.expectEqualStrings("electronics", decoded.entries[3].value.body());
}

test "metadata object rejects unsorted claims" {
    const subject = preimage.rawHash("subject object");
    const entries = [_]Entry{
        Entry.tag("z"),
        Entry.tag("a"),
    };
    const metadata = Metadata{ .subject = subject, .entries = &entries };
    var canonical: [256]u8 = undefined;
    try std.testing.expectError(error.BadArgument, metadata.encode(&canonical));
}
