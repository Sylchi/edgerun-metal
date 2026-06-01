const BoundedArena = @import("arena.zig").BoundedArena;
const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const crypto = @import("crypto.zig");
const identity = @import("identity.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");
const Region = @import("region.zig").Region;

pub const hash_size = preimage.hash_size;
pub const key_max = 64;
pub const BlobList = bounded.SliceList(Blob);
pub const IndexEntryList = bounded.SliceList(IndexEntry);
pub const content_type_raw: u32 = 0;
pub const content_type_object: u32 = 1;

pub const EntryKind = enum(u16) {
    blob = 1,
    object = 2,
    receipt = 3,
};

pub const Shape = struct {
    data_bytes: usize,
    slot_count: usize,

    pub fn valid(self: Shape) bool {
        return (self.data_bytes == 0 and self.slot_count == 0) or
            (self.data_bytes != 0 and self.slot_count != 0);
    }

    pub fn empty(self: Shape) bool {
        return self.data_bytes == 0 and self.slot_count == 0;
    }
};

pub const Blob = struct {
    hash: [hash_size]u8,
    bytes: []const u8,
    kind: EntryKind = .blob,
    content_type: u32 = content_type_raw,
    owner: ?identity.Id = null,

    pub fn info(self: Blob) BlobInfo {
        return .{
            .hash = self.hash,
            .kind = self.kind,
            .content_type = self.content_type,
            .size = self.bytes.len,
            .owner = self.owner,
        };
    }
};

pub const BlobInfo = struct {
    hash: [hash_size]u8,
    kind: EntryKind,
    content_type: u32,
    size: usize,
    owner: ?identity.Id,

    pub fn valid(self: BlobInfo) bool {
        return bytes.nonzero(&self.hash) and self.size != 0;
    }
};

pub const IndexEntry = struct {
    owner: identity.Id,
    index_id: u32,
    key: [key_max]u8 = [_]u8{0} ** key_max,
    key_len: usize,
    target_kind: EntryKind,
    content_type: u32,
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
        const value_slot = source.find(target_kind, owner, target_hash) orelse return false;
        const value = source.slots.items[value_slot];

        var stored_key = [_]u8{0} ** key_max;
        _ = bytes.copy(stored_key[0..key.len], key);
        const entry = IndexEntry{
            .owner = owner,
            .index_id = index_id,
            .key = stored_key,
            .key_len = key.len,
            .target_kind = target_kind,
            .content_type = value.content_type,
            .target_hash = target_hash,
            .value_size = value.bytes.len,
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
    owned: Region,
    slots: BlobList,

    pub fn init(data: Region, slots: []Blob) Store {
        return .{ .data = data, .owned = data, .slots = BlobList.from(slots) };
    }

    pub fn initFromArena(arena: *BoundedArena, shape: Shape) ?Store {
        if (!shape.valid()) return null;
        if (shape.empty()) {
            const data = arena.takeRegion(0) orelse return null;
            return Store.init(data, empty_blob_slots[0..]);
        }
        const slots = arena.allocSlice(Blob, shape.slot_count) orelse return null;
        const data = arena.takeRegion(shape.data_bytes) orelse return null;
        return Store.init(data, slots);
    }

    pub fn split(self: *Store, shape: Shape) ?Store {
        if (!shape.valid()) return null;
        if (shape.slot_count > self.slots.items.len - self.slots.len) return null;

        const child_data = self.data.split(shape.data_bytes) orelse return null;
        const owned_start = @intFromPtr(self.owned.base.ptr);
        const child_start = @intFromPtr(child_data.base.ptr);
        if (child_start < owned_start) return null;
        self.owned.base = self.owned.base[0 .. child_start - owned_start];
        const child_slot_start = self.slots.items.len - shape.slot_count;
        const child_slots = self.slots.items[child_slot_start..];
        self.slots.items = self.slots.items[0..child_slot_start];
        return Store.init(child_data, child_slots);
    }

    pub fn canReclaim(self: Store, child: Store) bool {
        return self.data.canAppendSuffix(child.owned) and
            self.owned.canAppendSuffix(child.owned) and
            childSlotsAreSuffix(self.slots.items, child.slots.items);
    }

    pub fn reclaim(self: *Store, child: *Store) bool {
        if (!self.canReclaim(child.*)) return false;
        child.owned.zero();
        clearBlobSlots(child.slots.items);
        if (!self.data.appendSuffix(child.owned)) return false;
        if (!self.owned.appendSuffix(child.owned)) return false;
        self.slots.items = self.slots.items.ptr[0 .. self.slots.items.len + child.slots.items.len];
        child.data = .{ .base = child.data.base[0..0] };
        child.owned = .{ .base = child.owned.base[0..0] };
        child.slots.clear();
        child.slots.items = child.slots.items[0..0];
        return true;
    }

    pub fn slotCount(self: Store) usize {
        return self.slots.len;
    }

    pub fn slotCapacity(self: Store) usize {
        return self.slots.items.len;
    }

    pub fn putRawBlob(self: *Store, value: []const u8) ?[hash_size]u8 {
        return self.putOwned(.blob, null, value);
    }

    pub fn putTypedRawBlob(self: *Store, content_type: u32, value: []const u8) ?[hash_size]u8 {
        return self.putTypedOwnedBlob(null, content_type, value);
    }

    fn putTypedOwnedBlob(self: *Store, owner: ?identity.Id, content_type: u32, value: []const u8) ?[hash_size]u8 {
        return self.putTypedOwned(.blob, owner, content_type, value);
    }

    fn putOwned(self: *Store, kind: EntryKind, owner: ?identity.Id, value: []const u8) ?[hash_size]u8 {
        return self.putTypedOwned(kind, owner, defaultContentType(kind), value);
    }

    fn putTypedOwned(self: *Store, kind: EntryKind, owner: ?identity.Id, content_type: u32, value: []const u8) ?[hash_size]u8 {
        if (owner) |id| {
            if (!id.valid()) return null;
        }
        var hash: [hash_size]u8 = undefined;
        hashEntry(kind, owner, content_type, value, &hash);
        return self.putWithHash(kind, owner, content_type, hash, value);
    }

    pub fn putObject(self: *Store, owner: identity.Id, canonical: []const u8) ?[hash_size]u8 {
        if (!owner.valid()) return null;
        const view = object.View.decode(canonical) catch return null;
        if (view.header.kind == .receipt) return null;
        return self.putWithHash(.object, owner, content_type_object, view.id(), canonical);
    }

    pub fn putReceipt(self: *Store, owner: identity.Id, canonical: []const u8) ?[hash_size]u8 {
        if (!owner.valid()) return null;
        const view = object.View.decode(canonical) catch return null;
        if (view.header.kind != .receipt) return null;
        return self.putWithHash(.receipt, owner, content_type_object, view.id(), canonical);
    }

    fn putWithHash(self: *Store, kind: EntryKind, owner: ?identity.Id, content_type: u32, hash: [hash_size]u8, value: []const u8) ?[hash_size]u8 {
        if (self.find(kind, owner, hash)) |_| return hash;
        const region = self.data.takePrefix(value.len) orelse return null;
        _ = bytes.copy(region.base, value);
        if (!self.slots.append(.{ .hash = hash, .bytes = region.base, .kind = kind, .content_type = content_type, .owner = owner })) return null;
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

    pub fn getBlobInfo(self: Store, hash: [hash_size]u8) ?BlobInfo {
        const index = self.findAny(hash) orelse return null;
        return self.slots.items[index].info();
    }

    pub fn stats(self: Store) Stats {
        return .{
            .slot_capacity = self.slotCapacity(),
            .slot_count = self.slotCount(),
            .data_remaining = self.data.len(),
            .log_root = self.logRoot(),
        };
    }

    pub fn logRoot(self: Store) [hash_size]u8 {
        var builder = preimage.Builder.init("edgerun:zig:v1:store-log-root");
        var raw: [54]u8 = undefined;
        for (self.slots.slice()) |slot| {
            var writer = preimage.Writer.init(&raw);
            if (!writer.writeU16(@intFromEnum(slot.kind)) or
                !writer.writeU32(slot.content_type) or
                !writer.hash(slot.hash) or
                !writer.writeU64(slot.bytes.len) or
                !writer.writeU64(if (slot.owner) |owner| ownerHashPrefix(owner) else 0))
            {
                return [_]u8{0} ** hash_size;
            }
            builder.bytes(writer.written());
        }
        return builder.final();
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

var empty_blob_slots: [0]Blob = .{};

pub const Stats = struct {
    slot_capacity: usize,
    slot_count: usize,
    data_remaining: usize,
    log_root: [hash_size]u8,

    pub fn valid(self: Stats) bool {
        return self.slot_count <= self.slot_capacity and bytes.nonzero(&self.log_root);
    }
};

pub const Error = error{
    Io,
    Corrupt,
    NoSpace,
    BadArgument,
    TooBig,
    NotFound,
};

pub const superblock_size = 68;
pub const record_header_size = 188;
pub const record_crc_size = 184;
pub const record_magic: u32 = 0x45525331;
pub const version: u32 = 1;
pub const record_version: u16 = 2;
pub const max_key = 256;
pub const max_name = 64;
pub const type_raw: u32 = content_type_raw;
pub const type_object: u32 = content_type_object;
pub const index_default: u32 = 0;
pub const value_unknown: u32 = 0;
pub const value_blob: u32 = 1;
pub const value_object: u32 = 2;
pub const sdcard_block_bytes: u32 = 512;
pub const nvme_block_bytes: u32 = 512;

const store_magic = "ERSTORE\x00";
const align_bytes = 8;
const super_version_off = 8;
const super_header_size_off = 12;
const super_log_start_off = 16;
const super_log_end_off = 24;
const super_root_hash_off = 32;
const super_crc_off = 64;
const header_magic_off = 0;
const header_version_off = 4;
const header_type_off = 6;
const header_seq_off = 8;
const header_payload_len_off = 16;
const header_payload_hash_off = 24;
const header_prev_hash_off = 56;
const header_epoch_off = 88;
const header_storage_id_off = 152;
const header_crc_off = 184;
const rec_blob: u16 = 1;
const rec_index_put: u16 = 2;
const rec_blob_type: u16 = 4;
const rec_content_type_define: u16 = 5;
const rec_index_define: u16 = 6;
const rec_object_index_put: u16 = 7;
const type_payload_size = 4 + hash_size;
const project_index_id_off = 0;
const project_value_kind_off = 4;
const project_content_type_off = 8;
const project_value_size_off = 12;
const project_key_len_off = 20;
const project_key_off = 22;
const project_fixed_payload_size = project_key_off + hash_size;

const ProjectPayload = struct {
    index_id: u32,
    value_kind: u32,
    content_type: u32,
    value_size: u64,
    hash: [hash_size]u8,
    key: []const u8,
};

pub const BlockBacking = enum(u32) {
    byte_log = 0,
    sdcard = 1,
    nvme = 2,
    custom = 3,
};

pub const Io = struct {
    ctx: *anyopaque,
    readAt: *const fn (*anyopaque, u64, []u8) bool,
    writeAt: *const fn (*anyopaque, u64, []const u8) bool,
    sync: *const fn (*anyopaque) bool,
    size: *const fn (*anyopaque) ?u64,
    truncate: *const fn (*anyopaque, u64) bool,
};

pub const Config = struct {
    block_backing: BlockBacking = .byte_log,
    block_bytes: u32 = 0,
    storage_identity_id: [hash_size]u8,
    epoch: @import("clock.zig").Stamp,

    pub fn default(storage_identity_id: [hash_size]u8, epoch: @import("clock.zig").Stamp) Config {
        return .{ .storage_identity_id = storage_identity_id, .epoch = epoch };
    }
};

pub const PersistentBlobSlot = struct {
    used: bool = false,
    hash: [hash_size]u8 = [_]u8{0} ** hash_size,
    content_type: u32 = type_raw,
    offset: u64 = 0,
    size: u64 = 0,
};

pub const PersistentIndexSlot = struct {
    used: bool = false,
    index_id: u32 = 0,
    value_kind: u32 = value_unknown,
    content_type: u32 = type_raw,
    key: [max_key]u8 = [_]u8{0} ** max_key,
    key_len: usize = 0,
    hash: [hash_size]u8 = [_]u8{0} ** hash_size,
    value_size: u64 = 0,

    pub fn keyBytes(self: *const PersistentIndexSlot) []const u8 {
        return self.key[0..self.key_len];
    }
};

pub const PersistentStats = struct {
    blob_slots: usize,
    key_slots: usize,
    blob_count: usize,
    key_count: usize,
    log_root: [hash_size]u8,
};

const RecordInfo = struct {
    typ: u16,
    seq: u64,
    payload_len: u64,
    payload_hash: [hash_size]u8,
    prev_hash: [hash_size]u8,
    epoch: @import("clock.zig").Stamp,
    storage_identity_id: [hash_size]u8,
};

pub const PersistentStore = struct {
    io: Io,
    config: Config,
    blobs: []PersistentBlobSlot,
    keys: []PersistentIndexSlot,
    block_scratch: []u8,
    block_bytes: u32,
    log_start: u64,
    log_end: u64,
    next_seq: u64,
    last_record_hash: [hash_size]u8,
    superblock_dirty: bool,
    blob_count: usize,
    key_count: usize,

    pub fn open(io: Io, config: Config, blobs: []PersistentBlobSlot, keys: []PersistentIndexSlot, block_scratch: []u8) Error!PersistentStore {
        if (!config.epoch.valid() or !bytes.nonzero(&config.storage_identity_id) or blobs.len == 0 or keys.len == 0) return error.BadArgument;
        const block_bytes = try configBlockBytes(config);
        if (block_bytes > 1 and block_scratch.len < block_bytes) return error.BadArgument;

        @memset(blobs, .{});
        @memset(keys, .{});

        var store = PersistentStore{
            .io = io,
            .config = config,
            .blobs = blobs,
            .keys = keys,
            .block_scratch = block_scratch,
            .block_bytes = block_bytes,
            .log_start = if (block_bytes > 1) block_bytes else superblock_size,
            .log_end = if (block_bytes > 1) block_bytes else superblock_size,
            .next_seq = 1,
            .last_record_hash = [_]u8{0} ** hash_size,
            .superblock_dirty = false,
            .blob_count = 0,
            .key_count = 0,
        };

        const current_size = try store.ioSize();
        if (current_size == 0) {
            try store.ioTruncate(store.log_start);
            try store.writeSuperblock();
            return store;
        }

        if (current_size < store.log_start) return error.Corrupt;
        if (store.readSuperblock(current_size)) |_| {} else |_| {
            store.log_start = if (block_bytes > 1) block_bytes else superblock_size;
        }
        try store.replay(current_size);
        if (store.alignedSize(store.log_end) != current_size) {
            try store.ioTruncate(store.alignedSize(store.log_end));
        }
        store.superblock_dirty = true;
        return store;
    }

    pub fn sync(self: *PersistentStore) Error!void {
        if (self.superblock_dirty) try self.writeSuperblock();
        if (!self.io.sync(self.io.ctx)) return error.Io;
    }

    pub fn close(self: *PersistentStore) Error!void {
        if (self.superblock_dirty) try self.writeSuperblock();
    }

    pub fn stats(self: *const PersistentStore) PersistentStats {
        return .{
            .blob_slots = self.blobs.len,
            .key_slots = self.keys.len,
            .blob_count = self.blob_count,
            .key_count = self.key_count,
            .log_root = self.last_record_hash,
        };
    }

    pub fn putRawBlob(self: *PersistentStore, payload: []const u8) Error![hash_size]u8 {
        return self.putTypedRawBlob(type_raw, payload);
    }

    pub fn putTypedRawBlob(self: *PersistentStore, content_type: u32, payload: []const u8) Error![hash_size]u8 {
        if (payload.len == 0 or content_type == type_object) return error.BadArgument;
        const hash = preimage.rawHash(payload);
        if (self.findBlob(hash)) |_| return hash;
        const payload_off = try self.appendRecord(rec_blob, payload);
        try self.insertBlob(hash, content_type, payload_off, payload.len);
        if (content_type != type_raw) {
            try self.appendBlobTypeRecord(content_type, hash);
        }
        return hash;
    }

    pub fn putCanonicalObject(self: *PersistentStore, canonical: []const u8) Error![hash_size]u8 {
        const view = object.View.decode(canonical) catch return error.Corrupt;
        const hash = view.id();
        if (self.findBlob(hash)) |_| return hash;
        const payload_off = try self.appendRecord(rec_blob, canonical);
        try self.insertBlob(hash, type_object, payload_off, canonical.len);
        try self.appendBlobTypeRecord(type_object, hash);
        return hash;
    }

    pub fn getBlob(self: *PersistentStore, hash: [hash_size]u8, out: []u8) Error![]const u8 {
        const slot = self.findBlob(hash) orelse return error.NotFound;
        const item = self.blobs[slot];
        if (item.size > out.len) return error.NoSpace;
        const len: usize = @intCast(item.size);
        try self.ioRead(item.offset, out[0..len]);
        return out[0..len];
    }

    pub fn getCanonicalObject(self: *PersistentStore, hash: [hash_size]u8, out: []u8) Error!object.View {
        const slot = self.findBlob(hash) orelse return error.NotFound;
        if (self.blobs[slot].content_type != type_object) return error.NotFound;
        const canonical = try self.getBlob(hash, out);
        const view = object.View.decode(canonical) catch return error.Corrupt;
        if (!bytes.eql(&view.id(), &hash)) return error.Corrupt;
        return view;
    }

    pub fn blobInfo(self: *const PersistentStore, hash: [hash_size]u8) Error!BlobInfo {
        const slot = self.findBlob(hash) orelse return error.NotFound;
        const item = self.blobs[slot];
        return .{ .hash = item.hash, .kind = .blob, .content_type = item.content_type, .size = @intCast(item.size), .owner = null };
    }

    pub fn defineContentType(self: *PersistentStore, content_type: u32, name: []const u8) Error!void {
        if (content_type == type_raw or content_type == type_object or name.len == 0 or name.len > max_name) return error.BadArgument;
        var payload: [6 + max_name]u8 = [_]u8{0} ** (6 + max_name);
        _ = bytes.store32(payload[0..4], content_type);
        _ = bytes.store16(payload[4..6], @intCast(name.len));
        _ = bytes.copy(payload[6..], name);
        _ = try self.appendRecord(rec_content_type_define, payload[0 .. 6 + name.len]);
    }

    pub fn defineIndex(self: *PersistentStore, index_id: u32, content_type: u32, name: []const u8) Error!void {
        if (name.len == 0 or name.len > max_name) return error.BadArgument;
        var payload: [10 + max_name]u8 = [_]u8{0} ** (10 + max_name);
        _ = bytes.store32(payload[0..4], index_id);
        _ = bytes.store32(payload[4..8], content_type);
        _ = bytes.store16(payload[8..10], @intCast(name.len));
        _ = bytes.copy(payload[10..], name);
        _ = try self.appendRecord(rec_index_define, payload[0 .. 10 + name.len]);
    }

    pub fn blobIndexPut(self: *PersistentStore, index_id: u32, key: []const u8, hash: [hash_size]u8) Error!void {
        const blob_slot = self.findBlob(hash) orelse return error.NotFound;
        const blob = self.blobs[blob_slot];
        try self.indexPut(index_id, key, hash, value_blob, blob.content_type, blob.size, rec_index_put);
    }

    pub fn objectIndexPut(self: *PersistentStore, index_id: u32, key: []const u8, hash: [hash_size]u8) Error!void {
        const blob_slot = self.findBlob(hash) orelse return error.NotFound;
        const blob = self.blobs[blob_slot];
        if (blob.content_type != type_object) return error.NotFound;
        try self.indexPut(index_id, key, hash, value_object, type_object, blob.size, rec_object_index_put);
    }

    pub fn indexGet(self: *const PersistentStore, index_id: u32, key: []const u8) Error![hash_size]u8 {
        const slot = self.findKey(index_id, key) orelse return error.NotFound;
        return self.keys[slot].hash;
    }

    pub fn indexGetEntry(self: *const PersistentStore, index_id: u32, key: []const u8) Error!PersistentIndexSlot {
        const slot = self.findKey(index_id, key) orelse return error.NotFound;
        return self.keys[slot];
    }

    pub fn indexScanPrefix(self: *const PersistentStore, index_id: u32, prefix: []const u8, out: []PersistentIndexSlot) Error!usize {
        if (prefix.len > max_key) return error.BadArgument;
        var count: usize = 0;
        for (self.keys) |slot| {
            if (!slot.used or slot.index_id != index_id or slot.key_len < prefix.len) continue;
            if (!bytes.eql(slot.key[0..prefix.len], prefix)) continue;
            if (count == out.len) break;
            out[count] = slot;
            count += 1;
        }
        return count;
    }

    pub fn verify(self: *PersistentStore) Error!void {
        var off = self.log_start;
        var expected_seq: u64 = 1;
        var prev = [_]u8{0} ** hash_size;
        while (off < self.log_end) {
            var header: [record_header_size]u8 = undefined;
            try self.ioRead(off, &header);
            const info = try decodeRecordHeader(&header);
            if (info.seq != expected_seq or !bytes.eql(&info.prev_hash, &prev)) return error.Corrupt;
            const payload_off = off + record_header_size;
            var payload_hash: [hash_size]u8 = undefined;
            try self.hashPayload(payload_off, info.payload_len, &payload_hash);
            if (!bytes.eql(&payload_hash, &info.payload_hash)) return error.Corrupt;
            prev = preimage.rawHash(&header);
            expected_seq += 1;
            off = payload_off + info.payload_len;
        }
    }

    fn indexPut(self: *PersistentStore, index_id: u32, key: []const u8, hash: [hash_size]u8, value_kind_in: u32, content_type: u32, value_size: u64, typ: u16) Error!void {
        if (key.len == 0 or key.len > max_key) return error.BadArgument;
        var payload: [project_fixed_payload_size + max_key]u8 = [_]u8{0} ** (project_fixed_payload_size + max_key);
        const encoded = try encodeProjectPayload(&payload, .{
            .index_id = index_id,
            .value_kind = value_kind_in,
            .content_type = content_type,
            .value_size = value_size,
            .hash = hash,
            .key = key,
        });
        _ = try self.appendRecord(typ, encoded);
        try self.insertKey(index_id, key, hash, value_kind_in, content_type, value_size);
    }

    fn appendRecord(self: *PersistentStore, typ: u16, payload: []const u8) Error!u64 {
        const payload_len: u64 = @intCast(payload.len);
        const payload_hash = preimage.rawHash(payload);
        var header: [record_header_size]u8 = undefined;
        encodeRecordHeader(&header, typ, self.next_seq, payload_len, payload_hash, self.last_record_hash, self.config.epoch, self.config.storage_identity_id);
        const header_off = self.log_end;
        const payload_off = header_off + record_header_size;
        try self.ioWrite(header_off, &header);
        try self.ioWrite(payload_off, payload);
        self.last_record_hash = preimage.rawHash(&header);
        self.log_end = payload_off + payload_len;
        self.next_seq += 1;
        self.superblock_dirty = true;
        return payload_off;
    }

    fn appendBlobTypeRecord(self: *PersistentStore, content_type: u32, hash: [hash_size]u8) Error!void {
        if (content_type == type_raw or !bytes.nonzero(&hash)) return error.BadArgument;
        var payload: [type_payload_size]u8 = undefined;
        _ = bytes.store32(payload[0..4], content_type);
        _ = bytes.copy(payload[4..], &hash);
        _ = try self.appendRecord(rec_blob_type, &payload);
    }

    fn replay(self: *PersistentStore, io_size: u64) Error!void {
        var off = self.log_start;
        var expected_seq: u64 = 1;
        var prev = [_]u8{0} ** hash_size;
        while (off + record_header_size <= io_size) {
            var header: [record_header_size]u8 = undefined;
            self.ioRead(off, &header) catch break;
            const info = decodeRecordHeader(&header) catch break;
            if (info.seq != expected_seq or !bytes.eql(&info.prev_hash, &prev)) break;
            const payload_off = off + record_header_size;
            const end = payload_off + info.payload_len;
            if (end < payload_off or end > io_size) break;
            var payload_hash: [hash_size]u8 = undefined;
            self.hashPayload(payload_off, info.payload_len, &payload_hash) catch break;
            if (!bytes.eql(&payload_hash, &info.payload_hash)) break;
            try self.applyRecord(info.typ, payload_off, info.payload_len);
            prev = preimage.rawHash(&header);
            self.last_record_hash = prev;
            self.next_seq = expected_seq + 1;
            self.log_end = end;
            expected_seq += 1;
            off = end;
        }
    }

    fn applyRecord(self: *PersistentStore, typ: u16, payload_off: u64, payload_len: u64) Error!void {
        switch (typ) {
            rec_blob => {
                var hash: [hash_size]u8 = undefined;
                try self.hashPayload(payload_off, payload_len, &hash);
                try self.insertBlob(hash, type_raw, payload_off, payload_len);
            },
            rec_blob_type => {
                var payload: [type_payload_size]u8 = undefined;
                if (payload_len != payload.len) return error.Corrupt;
                try self.ioRead(payload_off, &payload);
                const content_type = bytes.load32(payload[0..4]) orelse return error.Corrupt;
                const hash = fixedHash(payload[4..][0..hash_size]);
                const slot = self.findBlob(hash) orelse return error.Corrupt;
                self.blobs[slot].content_type = content_type;
            },
            rec_index_put, rec_object_index_put => {
                var payload: [project_fixed_payload_size + max_key]u8 = undefined;
                const len: usize = @intCast(payload_len);
                try self.ioRead(payload_off, payload[0..len]);
                const project = try decodeProjectPayload(payload[0..len]);
                try self.insertKey(project.index_id, project.key, project.hash, project.value_kind, project.content_type, project.value_size);
            },
            rec_content_type_define, rec_index_define => {},
            else => return error.Corrupt,
        }
    }

    fn insertBlob(self: *PersistentStore, hash: [hash_size]u8, content_type: u32, offset: u64, size: anytype) Error!void {
        if (self.findBlob(hash)) |slot| {
            self.blobs[slot].content_type = content_type;
            self.blobs[slot].offset = offset;
            self.blobs[slot].size = @intCast(size);
            return;
        }
        for (self.blobs) |*slot| {
            if (slot.used) continue;
            slot.* = .{ .used = true, .hash = hash, .content_type = content_type, .offset = offset, .size = @intCast(size) };
            self.blob_count += 1;
            return;
        }
        return error.NoSpace;
    }

    fn insertKey(self: *PersistentStore, index_id: u32, key: []const u8, hash: [hash_size]u8, value_kind_in: u32, content_type: u32, value_size: u64) Error!void {
        if (key.len == 0 or key.len > max_key) return error.BadArgument;
        const slot_index = self.findKey(index_id, key) orelse blk: {
            for (self.keys, 0..) |slot, i| {
                if (!slot.used) break :blk i;
            }
            return error.NoSpace;
        };
        const was_used = self.keys[slot_index].used;
        self.keys[slot_index] = .{
            .used = true,
            .index_id = index_id,
            .value_kind = value_kind_in,
            .content_type = content_type,
            .key_len = key.len,
            .hash = hash,
            .value_size = value_size,
        };
        _ = bytes.copy(self.keys[slot_index].key[0..key.len], key);
        if (!was_used) self.key_count += 1;
    }

    fn findBlob(self: *const PersistentStore, hash: [hash_size]u8) ?usize {
        for (self.blobs, 0..) |slot, i| {
            if (slot.used and bytes.eql(&slot.hash, &hash)) return i;
        }
        return null;
    }

    fn findKey(self: *const PersistentStore, index_id: u32, key: []const u8) ?usize {
        for (self.keys, 0..) |slot, i| {
            if (slot.used and slot.index_id == index_id and slot.key_len == key.len and bytes.eql(slot.key[0..slot.key_len], key)) return i;
        }
        return null;
    }

    fn writeSuperblock(self: *PersistentStore) Error!void {
        var raw: [superblock_size]u8 = [_]u8{0} ** superblock_size;
        _ = bytes.copy(raw[0..store_magic.len], store_magic);
        _ = bytes.store32(raw[super_version_off..][0..4], version);
        _ = bytes.store32(raw[super_header_size_off..][0..4], superblock_size);
        _ = bytes.store64(raw[super_log_start_off..][0..8], self.log_start);
        _ = bytes.store64(raw[super_log_end_off..][0..8], self.log_end);
        _ = bytes.copy(raw[super_root_hash_off..][0..hash_size], &self.last_record_hash);
        _ = bytes.store32(raw[super_crc_off..][0..4], crc32(raw[0..super_crc_off]));
        try self.ioWrite(0, &raw);
        self.superblock_dirty = false;
    }

    fn readSuperblock(self: *PersistentStore, io_size: u64) Error!void {
        if (io_size < superblock_size) return error.Corrupt;
        var raw: [superblock_size]u8 = undefined;
        try self.ioRead(0, &raw);
        if (!bytes.eql(raw[0..store_magic.len], store_magic)) return error.Corrupt;
        if ((bytes.load32(raw[super_crc_off..][0..4]) orelse return error.Corrupt) != crc32(raw[0..super_crc_off])) return error.Corrupt;
        if ((bytes.load32(raw[super_version_off..][0..4]) orelse return error.Corrupt) != version) return error.Corrupt;
        self.log_start = bytes.load64(raw[super_log_start_off..][0..8]) orelse return error.Corrupt;
        if (self.log_start != (if (self.block_bytes > 1) self.block_bytes else superblock_size)) return error.Corrupt;
    }

    fn hashPayload(self: *PersistentStore, off: u64, len: u64, out: *[hash_size]u8) Error!void {
        var hasher = crypto.blake3.init(.{});
        var remaining = len;
        var cursor = off;
        var chunk: [512]u8 = undefined;
        while (remaining != 0) {
            const take: usize = @intCast(@min(remaining, chunk.len));
            try self.ioRead(cursor, chunk[0..take]);
            hasher.update(chunk[0..take]);
            cursor += take;
            remaining -= take;
        }
        hasher.final(out);
    }

    fn ioSize(self: *PersistentStore) Error!u64 {
        const size_value = self.io.size(self.io.ctx) orelse return error.Io;
        if (self.block_bytes > 1 and (size_value & (@as(u64, self.block_bytes) - 1)) != 0) return error.Corrupt;
        return size_value;
    }

    fn ioRead(self: *PersistentStore, off: u64, out: []u8) Error!void {
        if (out.len == 0) return;
        if (self.block_bytes <= 1) {
            if (!self.io.readAt(self.io.ctx, off, out)) return error.Io;
            return;
        }
        const end = off + out.len;
        if (end < off or end > try self.ioSize()) return error.Io;
        var cursor = off;
        var written: usize = 0;
        while (written < out.len) {
            const block = @as(u64, self.block_bytes);
            const block_off = cursor & ~(block - 1);
            const in_block: usize = @intCast(cursor - block_off);
            const take = @min(out.len - written, @as(usize, self.block_bytes) - in_block);
            if (in_block == 0 and take == self.block_bytes) {
                if (!self.io.readAt(self.io.ctx, block_off, out[written..][0..take])) return error.Io;
            } else {
                if (!self.io.readAt(self.io.ctx, block_off, self.block_scratch[0..self.block_bytes])) return error.Io;
                _ = bytes.copy(out[written..][0..take], self.block_scratch[in_block..][0..take]);
            }
            cursor += take;
            written += take;
        }
    }

    fn ioWrite(self: *PersistentStore, off: u64, in: []const u8) Error!void {
        if (in.len == 0) return;
        if (self.block_bytes <= 1) {
            if (!self.io.writeAt(self.io.ctx, off, in)) return error.Io;
            return;
        }
        var cursor = off;
        var read: usize = 0;
        const io_size = try self.ioSize();
        while (read < in.len) {
            const block = @as(u64, self.block_bytes);
            const block_off = cursor & ~(block - 1);
            const in_block: usize = @intCast(cursor - block_off);
            const take = @min(in.len - read, @as(usize, self.block_bytes) - in_block);
            if (in_block == 0 and take == self.block_bytes) {
                if (!self.io.writeAt(self.io.ctx, block_off, in[read..][0..take])) return error.Io;
            } else {
                if (block_off < io_size) {
                    if (!self.io.readAt(self.io.ctx, block_off, self.block_scratch[0..self.block_bytes])) return error.Io;
                } else {
                    @memset(self.block_scratch[0..self.block_bytes], 0);
                }
                _ = bytes.copy(self.block_scratch[in_block..][0..take], in[read..][0..take]);
                if (!self.io.writeAt(self.io.ctx, block_off, self.block_scratch[0..self.block_bytes])) return error.Io;
            }
            cursor += take;
            read += take;
        }
    }

    fn ioTruncate(self: *PersistentStore, size_value: u64) Error!void {
        if (!self.io.truncate(self.io.ctx, self.alignedSize(size_value))) return error.Io;
    }

    fn alignedSize(self: *const PersistentStore, size_value: u64) u64 {
        if (self.block_bytes <= 1) return size_value;
        const block = @as(u64, self.block_bytes);
        return (size_value + block - 1) & ~(block - 1);
    }
};

fn configBlockBytes(config: Config) Error!u32 {
    return switch (config.block_backing) {
        .byte_log => if (config.block_bytes == 0 or config.block_bytes == 1) 1 else error.BadArgument,
        .sdcard => if (config.block_bytes == 0 or config.block_bytes == sdcard_block_bytes) sdcard_block_bytes else error.BadArgument,
        .nvme => if (config.block_bytes == 0 or config.block_bytes == nvme_block_bytes) nvme_block_bytes else error.BadArgument,
        .custom => if (config.block_bytes >= align_bytes and config.block_bytes != 0 and (config.block_bytes & (config.block_bytes - 1)) == 0) config.block_bytes else error.BadArgument,
    };
}

fn encodeRecordHeader(
    out: *[record_header_size]u8,
    typ: u16,
    seq: u64,
    payload_len: u64,
    payload_hash: [hash_size]u8,
    prev_hash: [hash_size]u8,
    epoch: @import("clock.zig").Stamp,
    storage_identity_id: [hash_size]u8,
) void {
    @memset(out, 0);
    _ = bytes.store32(out[header_magic_off..][0..4], record_magic);
    _ = bytes.store16(out[header_version_off..][0..2], record_version);
    _ = bytes.store16(out[header_type_off..][0..2], typ);
    _ = bytes.store64(out[header_seq_off..][0..8], seq);
    _ = bytes.store64(out[header_payload_len_off..][0..8], payload_len);
    _ = bytes.copy(out[header_payload_hash_off..][0..hash_size], &payload_hash);
    _ = bytes.copy(out[header_prev_hash_off..][0..hash_size], &prev_hash);
    _ = preimage.encodeEpoch(epoch, out[header_epoch_off..][0..preimage.epoch_size]);
    _ = bytes.copy(out[header_storage_id_off..][0..hash_size], &storage_identity_id);
    _ = bytes.store32(out[header_crc_off..][0..4], crc32(out[0..record_crc_size]));
}

fn decodeRecordHeader(in: *const [record_header_size]u8) Error!RecordInfo {
    if ((bytes.load32(in[header_magic_off..][0..4]) orelse return error.Corrupt) != record_magic) return error.Corrupt;
    if ((bytes.load16(in[header_version_off..][0..2]) orelse return error.Corrupt) != record_version) return error.Corrupt;
    const expected_crc = bytes.load32(in[header_crc_off..][0..4]) orelse return error.Corrupt;
    if (expected_crc != crc32(in[0..record_crc_size])) return error.Corrupt;
    const typ = bytes.load16(in[header_type_off..][0..2]) orelse return error.Corrupt;
    switch (typ) {
        rec_blob, rec_index_put, rec_blob_type, rec_content_type_define, rec_index_define, rec_object_index_put => {},
        else => return error.Corrupt,
    }
    const epoch_stamp = preimage.decodeEpoch(in[header_epoch_off..][0..preimage.epoch_size]) orelse return error.Corrupt;
    const storage_id = fixedHash(in[header_storage_id_off..][0..hash_size]);
    if (!bytes.nonzero(&storage_id)) return error.Corrupt;
    return .{
        .typ = typ,
        .seq = bytes.load64(in[header_seq_off..][0..8]) orelse return error.Corrupt,
        .payload_len = bytes.load64(in[header_payload_len_off..][0..8]) orelse return error.Corrupt,
        .payload_hash = fixedHash(in[header_payload_hash_off..][0..hash_size]),
        .prev_hash = fixedHash(in[header_prev_hash_off..][0..hash_size]),
        .epoch = epoch_stamp,
        .storage_identity_id = storage_id,
    };
}

fn encodeProjectPayload(out: []u8, payload: ProjectPayload) Error![]const u8 {
    if (payload.key.len == 0 or payload.key.len > max_key or out.len < project_fixed_payload_size + payload.key.len) return error.BadArgument;
    if (!bytes.nonzero(&payload.hash)) return error.BadArgument;
    @memset(out[0 .. project_fixed_payload_size + payload.key.len], 0);
    _ = bytes.store32(out[project_index_id_off..][0..4], payload.index_id);
    _ = bytes.store32(out[project_value_kind_off..][0..4], payload.value_kind);
    _ = bytes.store32(out[project_content_type_off..][0..4], payload.content_type);
    _ = bytes.store64(out[project_value_size_off..][0..8], payload.value_size);
    _ = bytes.store16(out[project_key_len_off..][0..2], @intCast(payload.key.len));
    _ = bytes.copy(out[project_key_off..][0..hash_size], &payload.hash);
    _ = bytes.copy(out[project_fixed_payload_size..][0..payload.key.len], payload.key);
    return out[0 .. project_fixed_payload_size + payload.key.len];
}

fn decodeProjectPayload(in: []const u8) Error!ProjectPayload {
    if (in.len < project_fixed_payload_size or in.len > project_fixed_payload_size + max_key) return error.Corrupt;
    const key_len = bytes.load16(in[project_key_len_off..][0..2]) orelse return error.Corrupt;
    if (key_len == 0 or key_len > max_key or in.len != project_fixed_payload_size + key_len) return error.Corrupt;
    const hash = fixedHash(in[project_key_off..][0..hash_size]);
    if (!bytes.nonzero(&hash)) return error.Corrupt;
    return .{
        .index_id = bytes.load32(in[project_index_id_off..][0..4]) orelse return error.Corrupt,
        .value_kind = bytes.load32(in[project_value_kind_off..][0..4]) orelse return error.Corrupt,
        .content_type = bytes.load32(in[project_content_type_off..][0..4]) orelse return error.Corrupt,
        .value_size = bytes.load64(in[project_value_size_off..][0..8]) orelse return error.Corrupt,
        .hash = hash,
        .key = in[project_fixed_payload_size..][0..key_len],
    };
}

fn fixedHash(in: []const u8) [hash_size]u8 {
    var out: [hash_size]u8 = undefined;
    _ = bytes.copy(&out, in[0..hash_size]);
    return out;
}

fn crc32(in: []const u8) u32 {
    var crc: u32 = 0xffff_ffff;
    for (in) |byte| {
        crc ^= byte;
        var bit: u8 = 0;
        while (bit < 8) : (bit += 1) {
            if ((crc & 1) == 0) {
                crc >>= 1;
            } else {
                crc = (crc >> 1) ^ 0xedb8_8320;
            }
        }
    }
    return crc ^ 0xffff_ffff;
}

fn hashEntry(kind: EntryKind, owner: ?identity.Id, content_type: u32, value: []const u8, out: *[hash_size]u8) void {
    var header: [40]u8 = [_]u8{0} ** 40;
    _ = bytes.store16(header[0..2], @intFromEnum(kind));
    _ = bytes.store32(header[4..8], content_type);
    if (owner) |id| _ = bytes.copy(header[8..40], &id.bytes);

    var builder = preimage.Builder.init("edgerun:zig:v1:store-entry");
    builder.bytes(&header);
    builder.bytes(value);
    out.* = builder.final();
}

fn defaultContentType(kind: EntryKind) u32 {
    return switch (kind) {
        .blob => content_type_raw,
        .object, .receipt => content_type_object,
    };
}

fn ownerHashPrefix(owner: identity.Id) u64 {
    return bytes.load64(owner.bytes[0..8]) orelse 0;
}

fn sameOwner(left: ?identity.Id, right: ?identity.Id) bool {
    if (left == null and right == null) return true;
    if (left == null or right == null) return false;
    return left.?.eql(right.?);
}

fn childSlotsAreSuffix(parent: []Blob, child: []Blob) bool {
    const parent_end = @intFromPtr(parent.ptr) + parent.len * @sizeOf(Blob);
    return parent_end == @intFromPtr(child.ptr);
}

fn clearBlobSlots(slots: []Blob) void {
    for (slots) |*slot| {
        slot.* = .{
            .hash = [_]u8{0} ** hash_size,
            .bytes = &.{},
        };
    }
}

fn entryKeyEqual(entry: IndexEntry, key: []const u8) bool {
    return entry.key_len == key.len and bytes.eql(entry.key[0..entry.key_len], key);
}

fn entryKeyStartsWith(entry: IndexEntry, prefix: []const u8) bool {
    return prefix.len <= entry.key_len and bytes.eql(entry.key[0..prefix.len], prefix);
}

const testing = struct {
    fn expect(condition: bool) !void {
        if (!condition) return error.TestExpectedTrue;
    }

    fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
        switch (@typeInfo(@TypeOf(expected))) {
            .array => |array| if (array.child == u8) {
                if (!bytes.eql(expected[0..], actual[0..])) return error.TestExpectedEqual;
                return;
            },
            else => {},
        }
        if (actual != expected) return error.TestExpectedEqual;
    }

    fn expectEqualStrings(expected: []const u8, actual: []const u8) !void {
        if (!bytes.eql(expected, actual)) return error.TestExpectedEqual;
    }

    fn expectError(expected: anyerror, actual: anytype) !void {
        if (actual) |_| return error.TestExpectedError else |err| {
            if (err != expected) return err;
        }
    }
};

test "store consumes caller-owned region without allocation" {
    var data: [64]u8 = undefined;
    var slots: [4]Blob = undefined;
    var store = Store.init(.{ .base = &data }, &slots);

    const hash = store.putRawBlob("hello").?;
    try testing.expectEqualStrings("hello", store.get(hash).?);
    try testing.expectEqual(@as(usize, 59), store.data.len());
}

test "store can be carved from an app-owned arena" {
    var memory: [1024]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    var s = Store.initFromArena(&arena, .{ .data_bytes = 64, .slot_count = 4 }).?;

    const hash = s.putRawBlob("owned storage").?;
    try testing.expectEqualStrings("owned storage", s.get(hash).?);
    try testing.expect(s.data.len() < 64);
    try testing.expect(arena.remaining() < 960);
}

test "ram store can explicitly declare no object storage" {
    const no_storage_bytes = 0;
    const no_storage_slots = 0;
    var memory: [16]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    var s = Store.initFromArena(&arena, .{
        .data_bytes = no_storage_bytes,
        .slot_count = no_storage_slots,
    }).?;

    try testing.expectEqual(@as(usize, no_storage_bytes), s.data.len());
    try testing.expectEqual(@as(usize, no_storage_slots), s.slotCapacity());
    try testing.expect(s.putRawBlob("implicit durable storage") == null);
    try testing.expectEqual(@as(usize, memory.len), arena.remaining());
}

test "store entries are typed and owner scoped" {
    const clock = @import("clock.zig");
    var data: [64]u8 = undefined;
    var slots: [4]Blob = undefined;
    var s = Store.init(.{ .base = &data }, &slots);
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("app")).?, epoch).?;

    const hash = s.putOwned(.blob, app.id, "state").?;
    try testing.expectEqualStrings("state", s.getOwned(.blob, app.id, hash).?);
    try testing.expect(s.getOwned(.blob, null, hash) == null);
}

test "typed blobs expose content type and deterministic stats root" {
    const clock = @import("clock.zig");
    var data: [128]u8 = undefined;
    var slots: [4]Blob = undefined;
    var index_entries: [2]IndexEntry = undefined;
    var s = Store.init(.{ .base = &data }, &slots);
    var index = Index.init(&index_entries);
    const keeper = clock.KeeperId{ .bytes = [_]u8{4} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("typed app")).?, epoch).?;
    const message_type: u32 = 42;

    const before = s.stats();
    const hash = s.putTypedOwnedBlob(app.id, message_type, "message").?;
    const info = s.getBlobInfo(hash).?;
    try testing.expect(info.valid());
    try testing.expectEqual(message_type, info.content_type);
    try testing.expectEqual(@as(usize, 7), info.size);

    const after = s.stats();
    try testing.expect(after.valid());
    try testing.expectEqual(@as(usize, before.slot_count + 1), after.slot_count);
    try testing.expect(!bytes.eql(&before.log_root, &after.log_root));

    try testing.expect(index.put(s, app.id, 5, "messages/latest", .blob, hash));
    try testing.expectEqual(message_type, index.get(app.id, 5, "messages/latest").?.content_type);
}

test "store preserves canonical object and receipt ids" {
    const clock = @import("clock.zig");
    var data: [512]u8 = undefined;
    var slots: [4]Blob = undefined;
    var s = Store.init(.{ .base = &data }, &slots);
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("app")).?, epoch).?;
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
    const object_canonical = try (object.NodeWriter{ .out = &object_raw }).bytesNode(req, epoch, "state");
    const object_id = s.putObject(app.id, object_canonical).?;
    try testing.expect(bytes.eql(&object_id, &object.Header.id(object_canonical)));
    try testing.expectEqualStrings("state", s.getObject(app.id, object_id).?.body);

    var receipt_raw: [object.header_size + 7]u8 = undefined;
    const receipt_canonical = try (object.NodeWriter{ .out = &receipt_raw }).receiptNode(req, epoch, "receipt");
    const receipt_id = s.putReceipt(app.id, receipt_canonical).?;
    try testing.expect(bytes.eql(&receipt_id, &object.Header.id(receipt_canonical)));
    try testing.expectEqualStrings("receipt", s.getReceipt(app.id, receipt_id).?.body);
    try testing.expect(s.putReceipt(app.id, object_canonical) == null);
    try testing.expect(s.putObject(app.id, receipt_canonical) == null);
    try testing.expect(s.getReceipt(app.id, object_id) == null);
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
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("app")).?, epoch).?;

    const alpha = s.putOwned(.blob, app.id, "alpha").?;
    const beta = s.putOwned(.blob, app.id, "beta").?;
    try testing.expect(index.put(s, app.id, 7, "messages/alpha", .blob, alpha));
    try testing.expect(index.put(s, app.id, 7, "messages/beta", .blob, beta));

    const entry = index.get(app.id, 7, "messages/alpha").?;
    try testing.expect(bytes.eql(&entry.target_hash, &alpha));
    try testing.expectEqual(@as(usize, 5), entry.value_size);

    var out: [2]IndexEntry = undefined;
    try testing.expectEqual(@as(usize, 2), index.scanPrefix(app.id, 7, "messages/", &out));

    var cursor = index.cursor(app.id, 7, "messages/").?;
    try testing.expect(bytes.eql(&cursor.next().?.target_hash, &alpha));
    try testing.expect(bytes.eql(&cursor.next().?.target_hash, &beta));
    try testing.expect(cursor.next() == null);
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
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("app")).?, epoch).?;
    const other = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("other")).?, epoch).?;

    const hash = s.putOwned(.blob, app.id, "owned").?;
    try testing.expect(!index.put(s, other.id, 1, "bad", .blob, hash));
}

test "store split delegates data and unused slot capacity" {
    var data: [64]u8 = undefined;
    var slots: [4]Blob = undefined;
    var parent = Store.init(.{ .base = &data }, &slots);
    var child = parent.split(.{ .data_bytes = 24, .slot_count = 2 }).?;

    try testing.expectEqual(@as(usize, 40), parent.data.len());
    try testing.expectEqual(@as(usize, 2), parent.slotCapacity());
    try testing.expectEqual(@as(usize, 24), child.data.len());
    try testing.expectEqual(@as(usize, 2), child.slotCapacity());

    const hash = child.putRawBlob("child data").?;
    try testing.expectEqualStrings("child data", child.get(hash).?);
    try testing.expectEqual(@as(usize, 40), parent.data.len());
}

test "store reclaim returns consumed child storage and clears slots" {
    var data: [64]u8 = undefined;
    var slots: [4]Blob = undefined;
    var parent = Store.init(.{ .base = &data }, &slots);
    var child = parent.split(.{ .data_bytes = 24, .slot_count = 2 }).?;

    const hash = child.putRawBlob("child data").?;
    try testing.expectEqualStrings("child data", child.get(hash).?);
    try testing.expectEqual(@as(usize, 14), child.data.len());

    try testing.expect(parent.reclaim(&child));
    try testing.expectEqual(@as(usize, 64), parent.data.len());
    try testing.expectEqual(@as(usize, 4), parent.slotCapacity());
    try testing.expectEqual(@as(usize, 0), child.data.len());
    try testing.expect(child.get(hash) == null);
}

const PersistentTestIo = struct {
    bytes: [65536]u8 = [_]u8{0} ** 65536,
    used: u64 = 0,
    block_bytes: u32 = 0,
    sync_count: usize = 0,
    read_count: usize = 0,

    fn io(self: *PersistentTestIo) Io {
        return .{
            .ctx = self,
            .readAt = readAt,
            .writeAt = writeAt,
            .sync = syncFn,
            .size = sizeFn,
            .truncate = truncateFn,
        };
    }

    fn readAt(ctx: *anyopaque, off: u64, out: []u8) bool {
        const self: *PersistentTestIo = @ptrCast(@alignCast(ctx));
        if (!self.aligned(off, out.len)) return false;
        if (off > self.used or out.len > self.used - off) return false;
        @memcpy(out, self.bytes[@intCast(off)..][0..out.len]);
        self.read_count += 1;
        return true;
    }

    fn writeAt(ctx: *anyopaque, off: u64, in: []const u8) bool {
        const self: *PersistentTestIo = @ptrCast(@alignCast(ctx));
        if (!self.aligned(off, in.len)) return false;
        const end = off + in.len;
        if (end < off or end > self.bytes.len) return false;
        if (off > self.used) @memset(self.bytes[@intCast(self.used)..@intCast(off)], 0);
        @memcpy(self.bytes[@intCast(off)..][0..in.len], in);
        self.used = @max(self.used, end);
        return true;
    }

    fn syncFn(ctx: *anyopaque) bool {
        const self: *PersistentTestIo = @ptrCast(@alignCast(ctx));
        self.sync_count += 1;
        return true;
    }

    fn sizeFn(ctx: *anyopaque) ?u64 {
        const self: *PersistentTestIo = @ptrCast(@alignCast(ctx));
        return self.used;
    }

    fn truncateFn(ctx: *anyopaque, size_value: u64) bool {
        const self: *PersistentTestIo = @ptrCast(@alignCast(ctx));
        if (!self.aligned(size_value, 0) or size_value > self.bytes.len) return false;
        if (size_value > self.used) @memset(self.bytes[@intCast(self.used)..@intCast(size_value)], 0);
        self.used = size_value;
        return true;
    }

    fn aligned(self: *const PersistentTestIo, off: u64, len: usize) bool {
        if (self.block_bytes == 0) return true;
        const mask = @as(u64, self.block_bytes) - 1;
        return (off & mask) == 0 and ((@as(u64, @intCast(len)) & mask) == 0);
    }
};

fn persistentTestConfig() Config {
    const clock = @import("clock.zig");
    return .{
        .storage_identity_id = [_]u8{9} ++ [_]u8{0} ** 31,
        .epoch = .{ .keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 }, .tick = 1 },
    };
}

test "persistent store replays append log after reopen" {
    var io_state = PersistentTestIo{};
    var blobs_a: [8]PersistentBlobSlot = undefined;
    var keys_a: [8]PersistentIndexSlot = undefined;
    var scratch_a: [sdcard_block_bytes]u8 = undefined;
    var store_a = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_a, &keys_a, &scratch_a);

    try testing.expectEqual(@as(u64, superblock_size), io_state.used);
    const hash = try store_a.putRawBlob("durable bytes");
    const size_after_first = io_state.used;
    try testing.expectEqual(hash, try store_a.putRawBlob("durable bytes"));
    try testing.expectEqual(size_after_first, io_state.used);
    try store_a.close();
    try testing.expectEqual(@as(usize, 0), io_state.sync_count);

    var blobs_b: [8]PersistentBlobSlot = undefined;
    var keys_b: [8]PersistentIndexSlot = undefined;
    var scratch_b: [sdcard_block_bytes]u8 = undefined;
    var store_b = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_b, &keys_b, &scratch_b);
    var out: [32]u8 = undefined;
    try testing.expectEqualStrings("durable bytes", try store_b.getBlob(hash, &out));
    try store_b.sync();
    try testing.expectEqual(@as(usize, 1), io_state.sync_count);
}

test "persistent store replays latest index value" {
    var io_state = PersistentTestIo{};
    var blobs_a: [8]PersistentBlobSlot = undefined;
    var keys_a: [8]PersistentIndexSlot = undefined;
    var scratch_a: [sdcard_block_bytes]u8 = undefined;
    var store_a = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_a, &keys_a, &scratch_a);

    const first = try store_a.putRawBlob("first");
    const second = try store_a.putRawBlob("second");
    try store_a.blobIndexPut(index_default, "row/current", first);
    try store_a.blobIndexPut(index_default, "row/current", second);

    var blobs_b: [8]PersistentBlobSlot = undefined;
    var keys_b: [8]PersistentIndexSlot = undefined;
    var scratch_b: [sdcard_block_bytes]u8 = undefined;
    var store_b = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_b, &keys_b, &scratch_b);
    try testing.expectEqual(second, try store_b.indexGet(index_default, "row/current"));
    const entry = try store_b.indexGetEntry(index_default, "row/current");
    try testing.expectEqual(value_blob, entry.value_kind);
    try testing.expectEqual(@as(u64, 6), entry.value_size);
}

test "persistent store persists canonical object bytes and object indexes" {
    const clock = @import("clock.zig");
    var io_state = PersistentTestIo{};
    var blobs_a: [8]PersistentBlobSlot = undefined;
    var keys_a: [8]PersistentIndexSlot = undefined;
    var scratch_a: [sdcard_block_bytes]u8 = undefined;
    var store_a = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_a, &keys_a, &scratch_a);
    const req = object.Requirements{
        .durability = .durable,
        .confidentiality = .integrity_only,
        .portability = .public_portable,
        .integrity = .signed,
        .lifetime = .retained,
        .visibility = .app_namespace,
        .access = .explicit_io,
    };
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 }, .tick = 1 };
    var raw: [object.header_size + 11]u8 = undefined;
    const canonical = try (object.NodeWriter{ .out = &raw }).bytesNode(req, epoch, "object-body");

    const hash = try store_a.putCanonicalObject(canonical);
    try store_a.objectIndexPut(7, "objects/current", hash);

    var blobs_b: [8]PersistentBlobSlot = undefined;
    var keys_b: [8]PersistentIndexSlot = undefined;
    var scratch_b: [sdcard_block_bytes]u8 = undefined;
    var store_b = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_b, &keys_b, &scratch_b);
    var out: [256]u8 = undefined;
    const view = try store_b.getCanonicalObject(hash, &out);
    try testing.expectEqualStrings("object-body", view.body);
    const entry = try store_b.indexGetEntry(7, "objects/current");
    try testing.expectEqual(value_object, entry.value_kind);
    try testing.expectEqual(type_object, entry.content_type);
}

test "persistent store truncates corrupt tail during recovery" {
    var io_state = PersistentTestIo{};
    var blobs_a: [4]PersistentBlobSlot = undefined;
    var keys_a: [4]PersistentIndexSlot = undefined;
    var scratch_a: [sdcard_block_bytes]u8 = undefined;
    var store_a = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_a, &keys_a, &scratch_a);
    _ = try store_a.putRawBlob("valid");
    const valid_size = io_state.used;
    try testing.expect(PersistentTestIo.writeAt(&io_state, io_state.used, "junk"));
    try testing.expect(io_state.used > valid_size);

    var blobs_b: [4]PersistentBlobSlot = undefined;
    var keys_b: [4]PersistentIndexSlot = undefined;
    var scratch_b: [sdcard_block_bytes]u8 = undefined;
    _ = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs_b, &keys_b, &scratch_b);
    try testing.expectEqual(valid_size, io_state.used);
}

test "persistent store block-backed io stays aligned" {
    var io_state = PersistentTestIo{ .block_bytes = sdcard_block_bytes };
    var config = persistentTestConfig();
    config.block_backing = .sdcard;
    var blobs_a: [4]PersistentBlobSlot = undefined;
    var keys_a: [4]PersistentIndexSlot = undefined;
    var scratch_a: [sdcard_block_bytes]u8 = undefined;
    var store_a = try PersistentStore.open(io_state.io(), config, &blobs_a, &keys_a, &scratch_a);

    try testing.expectEqual(@as(u64, sdcard_block_bytes), io_state.used);
    const hash = try store_a.putRawBlob("block bytes");
    try testing.expectEqual(@as(u64, 0), io_state.used & (sdcard_block_bytes - 1));

    var blobs_b: [4]PersistentBlobSlot = undefined;
    var keys_b: [4]PersistentIndexSlot = undefined;
    var scratch_b: [sdcard_block_bytes]u8 = undefined;
    var store_b = try PersistentStore.open(io_state.io(), config, &blobs_b, &keys_b, &scratch_b);
    var out: [32]u8 = undefined;
    try testing.expectEqualStrings("block bytes", try store_b.getBlob(hash, &out));
}

test "persistent store verify detects payload corruption" {
    var io_state = PersistentTestIo{};
    var blobs: [4]PersistentBlobSlot = undefined;
    var keys: [4]PersistentIndexSlot = undefined;
    var scratch: [sdcard_block_bytes]u8 = undefined;
    var store = try PersistentStore.open(io_state.io(), persistentTestConfig(), &blobs, &keys, &scratch);

    _ = try store.putRawBlob("hash checked");
    io_state.bytes[superblock_size + record_header_size] ^= 0x01;
    try testing.expectError(error.Corrupt, store.verify());
}
