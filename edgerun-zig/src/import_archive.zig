const bytes = @import("bytes.zig");
const file_probe = @import("file_probe.zig");
const preimage = @import("preimage.zig");
const vfs = @import("vfs.zig");

pub const magic = "ERARC001";
pub const version: u16 = 1;
pub const header_size: usize = 24;
pub const entry_header_size: usize = 80;
pub const max_entries: usize = 1_000_000;
pub const max_label_len: usize = vfs.label_max;

const archive_domain = "edgerun:import-archive:v1";
const entry_domain = "edgerun:import-entry:v1";
const payload_domain = "edgerun:import-payload:v1";
const label_domain = "edgerun:import-label:v1";

pub const Error = error{
    BadArgument,
    NoSpace,
    Corrupt,
};

pub const EntryHeader = struct {
    label_len: u16,
    flags: u16,
    payload_len: u64,
    label_hash: preimage.Hash,
    payload_hash: preimage.Hash,
    entry_hash: preimage.Hash,
};

pub const Entry = struct {
    header: EntryHeader,
    label: []const u8,
    payload: []const u8,

    pub fn valid(self: Entry) bool {
        if (!vfs.labelValid(self.label)) return false;
        if (self.header.label_len != self.label.len) return false;
        if (self.header.payload_len != self.payload.len) return false;
        if (!bytes.eql(&self.header.label_hash, &hashLabel(self.label))) return false;
        if (!bytes.eql(&self.header.payload_hash, &hashPayload(self.payload))) return false;
        if (!bytes.eql(&self.header.entry_hash, &hashEntry(self.label, self.payload, self.header.flags))) return false;
        return true;
    }

    pub fn facts(self: Entry) file_probe.Facts {
        return file_probe.factsWithName(self.payload, self.label);
    }
};

pub const ArchiveHeader = struct {
    entry_count: u32,
    body_len: u64,
    archive_hash: preimage.Hash,
};

pub const Archive = struct {
    header: ArchiveHeader,
    body: []const u8,

    pub fn valid(self: Archive) bool {
        if (self.header.entry_count > max_entries) return false;
        if (self.header.body_len != self.body.len) return false;
        return bytes.eql(&self.header.archive_hash, &hashArchiveBody(self.body, self.header.entry_count));
    }
};

pub const EntrySpec = struct {
    label: []const u8,
    payload: []const u8,
    flags: u16 = 0,
};

pub const DecodedEntry = struct {
    entry: Entry,
    used: usize,
};

pub fn entryCanonicalLen(label: []const u8, payload: []const u8) Error!usize {
    if (!vfs.labelValid(label) or label.len > max_label_len) return error.BadArgument;
    return checkedAdd(checkedAdd(entry_header_size, label.len) catch return error.NoSpace, payload.len);
}

pub fn archiveCanonicalLen(entries: []const EntrySpec) Error!usize {
    if (entries.len > max_entries) return error.BadArgument;
    var total = header_size;
    for (entries) |entry| total = try checkedAdd(total, try entryCanonicalLen(entry.label, entry.payload));
    return total;
}

pub fn encode(entries: []const EntrySpec, out: []u8) Error![]u8 {
    const needed = try archiveCanonicalLen(entries);
    if (out.len < needed) return error.NoSpace;
    const body_len = needed - header_size;
    @memset(out[0..needed], 0);
    @memcpy(out[0..magic.len], magic);
    _ = bytes.store16(out[8..10], version);
    _ = bytes.store16(out[10..12], 0);
    _ = bytes.store32(out[12..16], @intCast(entries.len));
    _ = bytes.store64(out[16..24], @intCast(body_len));

    var cursor: usize = header_size;
    for (entries) |entry| cursor += (try encodeEntry(entry, out[cursor..])).len;
    const archive_hash = hashArchiveBody(out[header_size..needed], @intCast(entries.len));
    @memcpy(out[24..56], &archive_hash);
    return out[0..needed];
}

pub fn decode(canonical: []const u8) Error!Archive {
    if (canonical.len < header_size + preimage.hash_size) return error.Corrupt;
    if (!bytes.eql(canonical[0..magic.len], magic)) return error.Corrupt;
    if ((bytes.load16(canonical[8..10]) orelse return error.Corrupt) != version) return error.Corrupt;
    if ((bytes.load16(canonical[10..12]) orelse return error.Corrupt) != 0) return error.Corrupt;
    const entry_count = bytes.load32(canonical[12..16]) orelse return error.Corrupt;
    if (entry_count > max_entries) return error.Corrupt;
    const body_len = bytes.load64(canonical[16..24]) orelse return error.Corrupt;
    if (body_len != canonical.len - header_size - preimage.hash_size) return error.Corrupt;
    var archive_hash: preimage.Hash = undefined;
    @memcpy(&archive_hash, canonical[24..56]);
    const body = canonical[56..];
    const archive = Archive{
        .header = .{ .entry_count = entry_count, .body_len = body_len, .archive_hash = archive_hash },
        .body = body,
    };
    if (!archive.valid()) return error.Corrupt;
    var cursor: usize = 0;
    var count: u32 = 0;
    while (cursor < body.len) : (count += 1) cursor += (try decodeEntryPrefix(body[cursor..])).used;
    if (count != entry_count) return error.Corrupt;
    return archive;
}

pub fn decodeEntryPrefix(bytes_in: []const u8) Error!DecodedEntry {
    if (bytes_in.len < entry_header_size) return error.Corrupt;
    const label_len = bytes.load16(bytes_in[0..2]) orelse return error.Corrupt;
    const flags = bytes.load16(bytes_in[2..4]) orelse return error.Corrupt;
    const payload_len = bytes.load64(bytes_in[4..12]) orelse return error.Corrupt;
    if (label_len == 0 or label_len > max_label_len) return error.Corrupt;
    var label_hash: preimage.Hash = undefined;
    var payload_hash: preimage.Hash = undefined;
    var entry_hash: preimage.Hash = undefined;
    @memcpy(&label_hash, bytes_in[12..44]);
    @memcpy(&payload_hash, bytes_in[44..76]);
    @memcpy(&entry_hash, bytes_in[76..108]);
    const label_start = entry_header_size + preimage.hash_size - 4;
    const label_end = try checkedAdd(label_start, label_len);
    const payload_end = try checkedAdd(label_end, @intCast(payload_len));
    if (payload_end > bytes_in.len) return error.Corrupt;
    const entry = Entry{
        .header = .{
            .label_len = label_len,
            .flags = flags,
            .payload_len = payload_len,
            .label_hash = label_hash,
            .payload_hash = payload_hash,
            .entry_hash = entry_hash,
        },
        .label = bytes_in[label_start..label_end],
        .payload = bytes_in[label_end..payload_end],
    };
    if (!entry.valid()) return error.Corrupt;
    return .{ .entry = entry, .used = payload_end };
}

pub fn firstEntry(archive: Archive) Error!?Entry {
    if (archive.header.entry_count == 0) return null;
    return (try decodeEntryPrefix(archive.body)).entry;
}

fn encodeEntry(entry: EntrySpec, out: []u8) Error![]u8 {
    const needed = try entryCanonicalLen(entry.label, entry.payload);
    if (out.len < needed) return error.NoSpace;
    const label_hash = hashLabel(entry.label);
    const payload_hash = hashPayload(entry.payload);
    const entry_hash = hashEntry(entry.label, entry.payload, entry.flags);
    _ = bytes.store16(out[0..2], @intCast(entry.label.len));
    _ = bytes.store16(out[2..4], entry.flags);
    _ = bytes.store64(out[4..12], @intCast(entry.payload.len));
    @memcpy(out[12..44], &label_hash);
    @memcpy(out[44..76], &payload_hash);
    @memcpy(out[76..108], &entry_hash);
    const label_start = entry_header_size + preimage.hash_size - 4;
    @memcpy(out[label_start..][0..entry.label.len], entry.label);
    @memcpy(out[label_start + entry.label.len ..][0..entry.payload.len], entry.payload);
    return out[0..needed];
}

pub fn hashLabel(label: []const u8) preimage.Hash {
    return preimage.hash(label_domain, label);
}

pub fn hashPayload(payload: []const u8) preimage.Hash {
    return preimage.hash(payload_domain, payload);
}

pub fn hashEntry(label: []const u8, payload: []const u8, flags: u16) preimage.Hash {
    var flag_bytes: [2]u8 = undefined;
    _ = bytes.store16(&flag_bytes, flags);
    var builder = preimage.Builder.init(entry_domain);
    builder.bytes(&flag_bytes);
    builder.bytes(label);
    builder.hash(hashPayload(payload));
    return builder.final();
}

fn hashArchiveBody(body: []const u8, entry_count: u32) preimage.Hash {
    var count_bytes: [4]u8 = undefined;
    _ = bytes.store32(&count_bytes, entry_count);
    var builder = preimage.Builder.init(archive_domain);
    builder.bytes(&count_bytes);
    builder.bytes(body);
    return builder.final();
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return @import("std").math.add(usize, left, right) catch error.NoSpace;
}

test "import archive roundtrips labeled payloads and probes facts" {
    const entries = [_]EntrySpec{
        .{ .label = "src/main.zig", .payload = "pub fn main() void {}\n" },
        .{ .label = "images/raw.jxl", .payload = &.{ 0xff, 0x0a, 0x00, 0x01 } },
    };
    var raw: [1024]u8 = undefined;
    const canonical = try encode(&entries, &raw);
    const archive = try decode(canonical);
    try @import("std").testing.expect(archive.valid());
    try @import("std").testing.expectEqual(@as(u32, entries.len), archive.header.entry_count);
    const first = (try firstEntry(archive)).?;
    try @import("std").testing.expectEqualStrings("src/main.zig", first.label);
    const facts = first.facts();
    try @import("std").testing.expectEqual(file_probe.Family.text, facts.probe.family);
}

test "import archive rejects ambient path labels" {
    const entries = [_]EntrySpec{.{ .label = "../bad", .payload = "x" }};
    var raw: [256]u8 = undefined;
    try @import("std").testing.expectError(error.BadArgument, encode(&entries, &raw));
}
