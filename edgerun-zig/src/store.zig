const std = @import("std");
const BoundedArena = @import("arena.zig").BoundedArena;
const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const identity = @import("identity.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");
const Region = @import("region.zig").Region;

pub const hash_size = preimage.hash_size;
pub const key_max = 64;
pub const BlobList = bounded.SliceList(Blob);
pub const IndexEntryList = bounded.SliceList(IndexEntry);

pub const EntryKind = enum(u16) {
    blob = 1,
    object = 2,
    receipt = 3,
};

pub const Blob = struct {
    hash: [hash_size]u8,
    bytes: []const u8,
    kind: EntryKind = .blob,
    owner: ?identity.Id = null,
};

pub const IndexEntry = struct {
    owner: identity.Id,
    index_id: u32,
    key: [key_max]u8 = [_]u8{0} ** key_max,
    key_len: usize,
    target_kind: EntryKind,
    target_hash: [hash_size]u8,
    value_size: usize,

    pub fn keyBytes(self: *const IndexEntry) []const u8 {
        return self.key[0..self.key_len];
    }

    pub fn valid(self: IndexEntry) bool {
        return self.owner.valid() and
            self.index_id != 0 and
            self.key_len != 0 and
            self.key_len <= key_max and
            bytes.nonzero(self.key[0..self.key_len]) and
            bytes.nonzero(&self.target_hash);
    }
};

pub const Index = struct {
    entries: IndexEntryList,

    pub fn init(entries: []IndexEntry) Index {
        return .{ .entries = IndexEntryList.from(entries) };
    }

    pub fn put(self: *Index, source: Store, owner: identity.Id, index_id: u32, key: []const u8, target_kind: EntryKind, target_hash: [hash_size]u8) bool {
        if (!owner.valid() or index_id == 0 or key.len == 0 or key.len > key_max) return false;
        const value = source.getOwned(target_kind, owner, target_hash) orelse return false;

        var stored_key = [_]u8{0} ** key_max;
        _ = bytes.copy(stored_key[0..key.len], key);
        const entry = IndexEntry{
            .owner = owner,
            .index_id = index_id,
            .key = stored_key,
            .key_len = key.len,
            .target_kind = target_kind,
            .target_hash = target_hash,
            .value_size = value.len,
        };
        if (!entry.valid()) return false;

        if (self.find(owner, index_id, key)) |slot| {
            self.entries.items[slot] = entry;
            return true;
        }
        return self.entries.append(entry);
    }

    pub fn get(self: Index, owner: identity.Id, index_id: u32, key: []const u8) ?IndexEntry {
        const slot = self.find(owner, index_id, key) orelse return null;
        return self.entries.items[slot];
    }

    pub fn scanPrefix(self: Index, owner: identity.Id, index_id: u32, prefix: []const u8, out: []IndexEntry) usize {
        var written: usize = 0;
        for (self.entries.slice()) |entry| {
            if (written == out.len) break;
            if (!entry.owner.eql(owner) or entry.index_id != index_id) continue;
            if (!entryKeyStartsWith(entry, prefix)) continue;
            out[written] = entry;
            written += 1;
        }
        return written;
    }

    pub fn cursor(self: *const Index, owner: identity.Id, index_id: u32, prefix: []const u8) ?IndexCursor {
        if (!owner.valid() or index_id == 0 or prefix.len > key_max) return null;
        var stored_prefix = [_]u8{0} ** key_max;
        _ = bytes.copy(stored_prefix[0..prefix.len], prefix);
        return .{
            .index = self,
            .owner = owner,
            .index_id = index_id,
            .prefix = stored_prefix,
            .prefix_len = prefix.len,
        };
    }

    fn find(self: Index, owner: identity.Id, index_id: u32, key: []const u8) ?usize {
        for (self.entries.slice(), 0..) |entry, slot| {
            if (entry.owner.eql(owner) and entry.index_id == index_id and entryKeyEqual(entry, key)) return slot;
        }
        return null;
    }
};

pub const IndexCursor = struct {
    index: *const Index,
    owner: identity.Id,
    index_id: u32,
    prefix: [key_max]u8,
    prefix_len: usize,
    position: usize = 0,

    pub fn next(self: *IndexCursor) ?IndexEntry {
        while (self.position < self.index.entries.len) {
            const entry = self.index.entries.items[self.position];
            self.position += 1;
            if (!entry.owner.eql(self.owner) or entry.index_id != self.index_id) continue;
            if (!entryKeyStartsWith(entry, self.prefix[0..self.prefix_len])) continue;
            return entry;
        }
        return null;
    }
};

pub const Store = struct {
    data: Region,
    slots: BlobList,

    pub fn init(data: Region, slots: []Blob) Store {
        return .{ .data = data, .slots = BlobList.from(slots) };
    }

    pub fn initFromArena(arena: *BoundedArena, data_bytes: usize, slot_count: usize) ?Store {
        const slots = arena.allocSlice(Blob, slot_count) orelse return null;
        const data = arena.takeRegion(data_bytes) orelse return null;
        return Store.init(data, slots);
    }

    pub fn split(self: *Store, data_bytes: usize, slot_count: usize) ?Store {
        if (slot_count > self.slots.items.len - self.slots.len) return null;

        const child_data = self.data.split(data_bytes) orelse return null;
        const child_slot_start = self.slots.items.len - slot_count;
        const child_slots = self.slots.items[child_slot_start..];
        self.slots.items = self.slots.items[0..child_slot_start];
        return Store.init(child_data, child_slots);
    }

    pub fn slotCount(self: Store) usize {
        return self.slots.len;
    }

    pub fn slotCapacity(self: Store) usize {
        return self.slots.items.len;
    }

    pub fn put(self: *Store, value: []const u8) ?[hash_size]u8 {
        return self.putOwned(.blob, null, value);
    }

    pub fn putOwned(self: *Store, kind: EntryKind, owner: ?identity.Id, value: []const u8) ?[hash_size]u8 {
        if (owner) |id| {
            if (!id.valid()) return null;
        }
        var hash: [hash_size]u8 = undefined;
        hashEntry(kind, owner, value, &hash);
        return self.putWithHash(kind, owner, hash, value);
    }

    pub fn putObject(self: *Store, owner: identity.Id, canonical: []const u8) ?[hash_size]u8 {
        if (!owner.valid()) return null;
        const view = object.View.decode(canonical) catch return null;
        if (view.header.kind == .receipt) return null;
        return self.putWithHash(.object, owner, view.id(), canonical);
    }

    pub fn putReceipt(self: *Store, owner: identity.Id, canonical: []const u8) ?[hash_size]u8 {
        if (!owner.valid()) return null;
        const view = object.View.decode(canonical) catch return null;
        if (view.header.kind != .receipt) return null;
        return self.putWithHash(.receipt, owner, view.id(), canonical);
    }

    fn putWithHash(self: *Store, kind: EntryKind, owner: ?identity.Id, hash: [hash_size]u8, value: []const u8) ?[hash_size]u8 {
        if (self.find(kind, owner, hash)) |_| return hash;
        const region = self.data.takePrefix(value.len) orelse return null;
        _ = bytes.copy(region.base, value);
        if (!self.slots.append(.{ .hash = hash, .bytes = region.base, .kind = kind, .owner = owner })) return null;
        return hash;
    }

    pub fn get(self: Store, hash: [hash_size]u8) ?[]const u8 {
        const index = self.findAny(hash) orelse return null;
        return self.slots.items[index].bytes;
    }

    pub fn getOwned(self: Store, kind: EntryKind, owner: ?identity.Id, hash: [hash_size]u8) ?[]const u8 {
        const index = self.find(kind, owner, hash) orelse return null;
        return self.slots.items[index].bytes;
    }

    pub fn getObject(self: Store, owner: identity.Id, hash: [hash_size]u8) ?object.View {
        if (!owner.valid()) return null;
        const canonical = self.getOwned(.object, owner, hash) orelse return null;
        const view = object.View.decode(canonical) catch return null;
        if (view.header.kind == .receipt) return null;
        return view;
    }

    pub fn getReceipt(self: Store, owner: identity.Id, hash: [hash_size]u8) ?object.View {
        if (!owner.valid()) return null;
        const canonical = self.getOwned(.receipt, owner, hash) orelse return null;
        const view = object.View.decode(canonical) catch return null;
        if (view.header.kind != .receipt) return null;
        return view;
    }

    fn findAny(self: Store, hash: [hash_size]u8) ?usize {
        for (self.slots.slice(), 0..) |slot, index| {
            if (bytes.eql(&slot.hash, &hash)) return index;
        }
        return null;
    }

    fn find(self: Store, kind: EntryKind, owner: ?identity.Id, hash: [hash_size]u8) ?usize {
        for (self.slots.slice(), 0..) |slot, index| {
            if (slot.kind == kind and sameOwner(slot.owner, owner) and bytes.eql(&slot.hash, &hash)) return index;
        }
        return null;
    }
};

fn hashEntry(kind: EntryKind, owner: ?identity.Id, value: []const u8, out: *[hash_size]u8) void {
    var header: [36]u8 = [_]u8{0} ** 36;
    _ = bytes.store16(header[0..2], @intFromEnum(kind));
    if (owner) |id| _ = bytes.copy(header[4..36], &id.bytes);

    var builder = preimage.Builder.init("edgerun:zig:v1:store-entry");
    builder.bytes(&header);
    builder.bytes(value);
    out.* = builder.final();
}

fn sameOwner(left: ?identity.Id, right: ?identity.Id) bool {
    if (left == null and right == null) return true;
    if (left == null or right == null) return false;
    return left.?.eql(right.?);
}

fn entryKeyEqual(entry: IndexEntry, key: []const u8) bool {
    return entry.key_len == key.len and bytes.eql(entry.key[0..entry.key_len], key);
}

fn entryKeyStartsWith(entry: IndexEntry, prefix: []const u8) bool {
    return prefix.len <= entry.key_len and bytes.eql(entry.key[0..prefix.len], prefix);
}

test "store consumes caller-owned region without allocation" {
    var data: [64]u8 = undefined;
    var slots: [4]Blob = undefined;
    var store = Store.init(.{ .base = &data }, &slots);

    const hash = store.put("hello").?;
    try std.testing.expectEqualStrings("hello", store.get(hash).?);
    try std.testing.expectEqual(@as(usize, 59), store.data.len());
}

test "store can be carved from an app-owned arena" {
    var memory: [1024]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    var s = Store.initFromArena(&arena, 64, 4).?;

    const hash = s.put("owned storage").?;
    try std.testing.expectEqualStrings("owned storage", s.get(hash).?);
    try std.testing.expect(s.data.len() < 64);
    try std.testing.expect(arena.remaining() < 960);
}

test "store entries are typed and owner scoped" {
    const clock = @import("clock.zig");
    var data: [64]u8 = undefined;
    var slots: [4]Blob = undefined;
    var s = Store.init(.{ .base = &data }, &slots);
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.init(.hash, "app").?, epoch).?;

    const hash = s.putOwned(.object, app.id, "state").?;
    try std.testing.expectEqualStrings("state", s.getOwned(.object, app.id, hash).?);
    try std.testing.expect(s.getOwned(.blob, app.id, hash) == null);
}

test "store preserves canonical object and receipt ids" {
    const clock = @import("clock.zig");
    var data: [512]u8 = undefined;
    var slots: [4]Blob = undefined;
    var s = Store.init(.{ .base = &data }, &slots);
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.init(.hash, "app").?, epoch).?;
    const req = object.Requirements{
        .durability = .durable,
        .confidentiality = .integrity_only,
        .portability = .public_portable,
        .integrity = .signed,
        .lifetime = .retained,
        .visibility = .app_namespace,
        .access = .explicit_io,
    };

    var object_raw: [object.header_size + 5]u8 = undefined;
    const object_canonical = (object.NodeWriter{ .out = &object_raw }).bytesNode(req, epoch, "state").?;
    const object_id = s.putObject(app.id, object_canonical).?;
    try std.testing.expect(bytes.eql(&object_id, &object.Header.id(object_canonical)));
    try std.testing.expectEqualStrings("state", s.getObject(app.id, object_id).?.body);

    var receipt_raw: [object.header_size + 7]u8 = undefined;
    const receipt_canonical = (object.NodeWriter{ .out = &receipt_raw }).receiptNode(req, epoch, "receipt").?;
    const receipt_id = s.putReceipt(app.id, receipt_canonical).?;
    try std.testing.expect(bytes.eql(&receipt_id, &object.Header.id(receipt_canonical)));
    try std.testing.expectEqualStrings("receipt", s.getReceipt(app.id, receipt_id).?.body);
    try std.testing.expect(s.putReceipt(app.id, object_canonical) == null);
    try std.testing.expect(s.putObject(app.id, receipt_canonical) == null);
    try std.testing.expect(s.getReceipt(app.id, object_id) == null);
}

test "index maps app-owned keys to existing store entries" {
    const clock = @import("clock.zig");
    var data: [128]u8 = undefined;
    var slots: [4]Blob = undefined;
    var index_entries: [4]IndexEntry = undefined;
    var s = Store.init(.{ .base = &data }, &slots);
    var index = Index.init(&index_entries);
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.init(.hash, "app").?, epoch).?;

    const alpha = s.putOwned(.blob, app.id, "alpha").?;
    const beta = s.putOwned(.blob, app.id, "beta").?;
    try std.testing.expect(index.put(s, app.id, 7, "messages/alpha", .blob, alpha));
    try std.testing.expect(index.put(s, app.id, 7, "messages/beta", .blob, beta));

    const entry = index.get(app.id, 7, "messages/alpha").?;
    try std.testing.expect(bytes.eql(&entry.target_hash, &alpha));
    try std.testing.expectEqual(@as(usize, 5), entry.value_size);

    var out: [2]IndexEntry = undefined;
    try std.testing.expectEqual(@as(usize, 2), index.scanPrefix(app.id, 7, "messages/", &out));

    var cursor = index.cursor(app.id, 7, "messages/").?;
    try std.testing.expect(bytes.eql(&cursor.next().?.target_hash, &alpha));
    try std.testing.expect(bytes.eql(&cursor.next().?.target_hash, &beta));
    try std.testing.expect(cursor.next() == null);
}

test "index rejects targets outside the owner scope" {
    const clock = @import("clock.zig");
    var data: [128]u8 = undefined;
    var slots: [4]Blob = undefined;
    var index_entries: [2]IndexEntry = undefined;
    var s = Store.init(.{ .base = &data }, &slots);
    var index = Index.init(&index_entries);
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.init(.hash, "app").?, epoch).?;
    const other = identity.Identity.init(.app, identity.Source.init(.hash, "other").?, epoch).?;

    const hash = s.putOwned(.blob, app.id, "owned").?;
    try std.testing.expect(!index.put(s, other.id, 1, "bad", .blob, hash));
}

test "store split delegates data and unused slot capacity" {
    var data: [64]u8 = undefined;
    var slots: [4]Blob = undefined;
    var parent = Store.init(.{ .base = &data }, &slots);
    var child = parent.split(24, 2).?;

    try std.testing.expectEqual(@as(usize, 40), parent.data.len());
    try std.testing.expectEqual(@as(usize, 2), parent.slotCapacity());
    try std.testing.expectEqual(@as(usize, 24), child.data.len());
    try std.testing.expectEqual(@as(usize, 2), child.slotCapacity());

    const hash = child.put("child data").?;
    try std.testing.expectEqualStrings("child data", child.get(hash).?);
    try std.testing.expectEqual(@as(usize, 40), parent.data.len());
}
