const std = @import("std");

const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const crypto = @import("crypto.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");
const seal = @import("seal.zig");

pub const hash_size = preimage.hash_size;
pub const contact_canonical_max = identity.id_size * 2 + 1 + max_name_bytes;
pub const max_name_bytes = 64;
pub const max_message_body_bytes = 1024;
pub const max_media_ref_bytes = 160;
pub const max_media_mime_bytes = 48;
pub const sealed_header_size = 114;

const snapshot_magic = "ERCHAT01";
const sealed_magic = "ERCHSEAL";
const version: u16 = 3;

pub const Error = error{
    BadArgument,
    Corrupt,
    NoSpace,
    NotFound,
    AuthFailed,
};

pub const Direction = enum(u8) {
    inbound = 1,
    outbound = 2,
};

pub const MediaKind = enum(u8) {
    none = 0,
    image = 1,
    video = 2,
};

pub const ContactImport = struct {
    identity_id: identity.Id,
    name: []const u8,

    pub fn valid(self: ContactImport) bool {
        return self.identity_id.valid() and
            self.name.len != 0 and self.name.len <= max_name_bytes;
    }
};

pub const Contact = struct {
    id: identity.Id,
    details_hash: preimage.Hash,
    epoch: clock.Stamp,
    name: [max_name_bytes]u8 = [_]u8{0} ** max_name_bytes,
    name_len: usize = 0,

    pub fn nameBytes(self: *const Contact) []const u8 {
        return self.name[0..self.name_len];
    }
};

pub const Message = struct {
    id: preimage.Hash,
    contact_id: identity.Id,
    body_hash: preimage.Hash,
    direction: Direction,
    media_kind: MediaKind = .none,
    media_ref: [max_media_ref_bytes]u8 = [_]u8{0} ** max_media_ref_bytes,
    media_ref_len: usize = 0,
    media_mime: [max_media_mime_bytes]u8 = [_]u8{0} ** max_media_mime_bytes,
    media_mime_len: usize = 0,
    media_size: u64 = 0,
    body: [max_message_body_bytes]u8 = [_]u8{0} ** max_message_body_bytes,
    body_len: usize = 0,

    pub fn bodyBytes(self: *const Message) []const u8 {
        return self.body[0..self.body_len];
    }

    pub fn mediaRefBytes(self: *const Message) []const u8 {
        return self.media_ref[0..self.media_ref_len];
    }

    pub fn mediaMimeBytes(self: *const Message) []const u8 {
        return self.media_mime[0..self.media_mime_len];
    }
};

pub fn ChatState(comptime max_contacts: usize, comptime max_messages: usize) type {
    return struct {
        const Self = @This();

        device: identity.Identity,
        app: identity.Identity,
        user: identity.Identity,
        epoch: clock.Stamp,
        contacts: [max_contacts]Contact = undefined,
        contact_count: usize = 0,
        messages: [max_messages]Message = undefined,
        message_count: usize = 0,

        pub fn init(device: identity.Identity, app: identity.Identity, user: identity.Identity, epoch: clock.Stamp) Error!Self {
            if (!device.valid() or !app.valid() or !user.valid() or !epoch.valid()) return error.BadArgument;
            return .{ .device = device, .app = app, .user = user, .epoch = epoch };
        }

        pub fn sealPolicy(self: *const Self) seal.Policy {
            return seal.Policy.machineAppUser(self.device, self.app, self.user);
        }

        pub fn importContact(self: *Self, value: ContactImport, epoch: clock.Stamp) Error!identity.Id {
            if (!value.valid() or !epoch.valid()) return error.BadArgument;
            const contact_id = deriveContactId(value) orelse return error.BadArgument;
            var contact = Contact{
                .id = contact_id,
                .details_hash = contactDetailsHash(value) orelse return error.BadArgument,
                .epoch = epoch,
            };
            _ = bytes.copy(contact.name[0..value.name.len], value.name);
            contact.name_len = value.name.len;

            if (self.findContactIndex(contact_id)) |index| {
                self.contacts[index] = contact;
                return contact_id;
            }
            if (self.contact_count == self.contacts.len) return error.NoSpace;
            self.contacts[self.contact_count] = contact;
            self.contact_count += 1;
            return contact_id;
        }

        pub fn importContactsText(self: *Self, raw: []const u8, epoch: clock.Stamp) Error!usize {
            var imported: usize = 0;
            var pos: usize = 0;
            while (pos < raw.len) {
                const start = pos;
                while (pos < raw.len and raw[pos] != '\n' and raw[pos] != '\r') : (pos += 1) {}
                const line = trim(raw[start..pos]);
                while (pos < raw.len and (raw[pos] == '\n' or raw[pos] == '\r')) : (pos += 1) {}
                if (line.len == 0) continue;
                const parsed = parseContactLine(line) orelse return error.Corrupt;
                _ = try self.importContact(parsed, epoch);
                imported += 1;
            }
            return imported;
        }

        pub fn appendMessage(self: *Self, contact_id: identity.Id, direction: Direction, body: []const u8) Error!preimage.Hash {
            return self.appendMessageWithMedia(contact_id, direction, body, .none, "", "", 0);
        }

        pub fn appendMediaMessage(self: *Self, contact_id: identity.Id, direction: Direction, body: []const u8, media_kind: MediaKind, media_ref: []const u8, media_mime: []const u8, media_size: u64) Error!preimage.Hash {
            if (media_kind == .none) return error.BadArgument;
            return self.appendMessageWithMedia(contact_id, direction, body, media_kind, media_ref, media_mime, media_size);
        }

        fn appendMessageWithMedia(self: *Self, contact_id: identity.Id, direction: Direction, body: []const u8, media_kind: MediaKind, media_ref: []const u8, media_mime: []const u8, media_size: u64) Error!preimage.Hash {
            if (!contact_id.valid() or self.findContactIndex(contact_id) == null) return error.NotFound;
            if (body.len == 0 or body.len > max_message_body_bytes) return error.BadArgument;
            if (!validMedia(media_kind, media_ref, media_mime, media_size)) return error.BadArgument;
            if (self.message_count == self.messages.len) return error.NoSpace;

            var msg = Message{
                .id = messageId(contact_id, direction, body, media_kind, media_ref, @intCast(self.message_count)),
                .contact_id = contact_id,
                .body_hash = preimage.hash("edgerun:zig:v1:encrypted-chat-message-body", body),
                .direction = direction,
                .media_kind = media_kind,
                .media_size = media_size,
            };
            _ = bytes.copy(msg.body[0..body.len], body);
            msg.body_len = body.len;
            _ = bytes.copy(msg.media_ref[0..media_ref.len], media_ref);
            _ = bytes.copy(msg.media_mime[0..media_mime.len], media_mime);
            msg.media_ref_len = media_ref.len;
            msg.media_mime_len = media_mime.len;
            self.messages[self.message_count] = msg;
            self.message_count += 1;
            return msg.id;
        }

        pub fn findContact(self: *const Self, id: identity.Id) ?*const Contact {
            const index = self.findContactIndex(id) orelse return null;
            return &self.contacts[index];
        }

        pub fn findContactIndex(self: *const Self, id: identity.Id) ?usize {
            if (!id.valid()) return null;
            var index: usize = 0;
            while (index < self.contact_count) : (index += 1) {
                if (self.contacts[index].id.eql(id)) return index;
            }
            return null;
        }

        pub fn plaintextSize(self: *const Self) usize {
            var size: usize = 14;
            var i: usize = 0;
            while (i < self.contact_count) : (i += 1) {
                const c = &self.contacts[i];
                size += 130 + c.name_len;
            }
            i = 0;
            while (i < self.message_count) : (i += 1) {
                const m = &self.messages[i];
                size += 112 + m.media_ref_len + m.media_mime_len + m.body_len;
            }
            return size;
        }

        pub fn encodePlaintext(self: *const Self, out: []u8) Error![]const u8 {
            if (out.len < self.plaintextSize()) return error.NoSpace;
            var writer = SliceWriter.init(out);
            try writer.raw(snapshot_magic);
            try writer.writeU16(version);
            try writer.writeU16(@intCast(self.contact_count));
            try writer.writeU16(@intCast(self.message_count));

            var i: usize = 0;
            while (i < self.contact_count) : (i += 1) {
                const c = &self.contacts[i];
                try writer.raw(&c.id.bytes);
                try writer.raw(&c.details_hash);
                try writer.raw(&c.epoch.keeper.bytes);
                try writer.writeU64(c.epoch.tick);
                try writer.writeU64(c.epoch.slot);
                try writer.writeU64(c.epoch.epoch);
                try writer.writeU64(c.epoch.era);
                try writer.writeU16(@intCast(c.name_len));
                try writer.raw(c.nameBytes());
            }

            i = 0;
            while (i < self.message_count) : (i += 1) {
                const m = &self.messages[i];
                try writer.raw(&m.id);
                try writer.raw(&m.contact_id.bytes);
                try writer.raw(&m.body_hash);
                try writer.byte(@intFromEnum(m.direction));
                try writer.byte(@intFromEnum(m.media_kind));
                try writer.writeU16(@intCast(m.media_ref_len));
                try writer.writeU16(@intCast(m.media_mime_len));
                try writer.writeU64(m.media_size);
                try writer.writeU16(@intCast(m.body_len));
                try writer.raw(m.mediaRefBytes());
                try writer.raw(m.mediaMimeBytes());
                try writer.raw(m.bodyBytes());
            }
            return writer.written();
        }

        pub fn loadPlaintext(self: *Self, raw: []const u8) Error!void {
            var reader = SliceReader.init(raw);
            if (!bytes.eql(try reader.raw(snapshot_magic.len), snapshot_magic)) return error.Corrupt;
            if ((try reader.readU16()) != version) return error.Corrupt;
            const contact_total = try reader.readU16();
            const message_total = try reader.readU16();
            if (contact_total > max_contacts or message_total > max_messages) return error.NoSpace;

            var new_contacts: [max_contacts]Contact = undefined;
            var ci: usize = 0;
            while (ci < contact_total) : (ci += 1) {
                var contact = Contact{
                    .id = .{ .bytes = toArray32(try reader.raw(32)) },
                    .details_hash = toArray32(try reader.raw(32)),
                    .epoch = .{
                        .keeper = .{ .bytes = toArray32(try reader.raw(32)) },
                        .tick = try reader.readU64(),
                        .slot = try reader.readU64(),
                        .epoch = try reader.readU64(),
                        .era = try reader.readU64(),
                    },
                };
                contact.name_len = try reader.readU16();
                if (!contact.id.valid() or !contact.epoch.valid() or
                    contact.name_len == 0 or contact.name_len > max_name_bytes)
                {
                    return error.Corrupt;
                }
                _ = bytes.copy(contact.name[0..contact.name_len], try reader.raw(contact.name_len));
                new_contacts[ci] = contact;
            }

            var new_messages: [max_messages]Message = undefined;
            var mi: usize = 0;
            while (mi < message_total) : (mi += 1) {
                var msg = Message{
                    .id = toArray32(try reader.raw(32)),
                    .contact_id = .{ .bytes = toArray32(try reader.raw(32)) },
                    .body_hash = toArray32(try reader.raw(32)),
                    .direction = switch (try reader.byte()) {
                        @intFromEnum(Direction.inbound) => .inbound,
                        @intFromEnum(Direction.outbound) => .outbound,
                        else => return error.Corrupt,
                    },
                    .media_kind = switch (try reader.byte()) {
                        @intFromEnum(MediaKind.none) => .none,
                        @intFromEnum(MediaKind.image) => .image,
                        @intFromEnum(MediaKind.video) => .video,
                        else => return error.Corrupt,
                    },
                };
                msg.media_ref_len = try reader.readU16();
                msg.media_mime_len = try reader.readU16();
                msg.media_size = try reader.readU64();
                msg.body_len = try reader.readU16();
                if (!bytes.nonzero(&msg.id) or !msg.contact_id.valid() or msg.body_len == 0 or msg.body_len > max_message_body_bytes) return error.Corrupt;
                if (msg.media_ref_len > max_media_ref_bytes or msg.media_mime_len > max_media_mime_bytes) return error.Corrupt;
                if (!validMediaLengths(msg.media_kind, msg.media_ref_len, msg.media_mime_len, msg.media_size)) return error.Corrupt;
                _ = bytes.copy(msg.media_ref[0..msg.media_ref_len], try reader.raw(msg.media_ref_len));
                _ = bytes.copy(msg.media_mime[0..msg.media_mime_len], try reader.raw(msg.media_mime_len));
                _ = bytes.copy(msg.body[0..msg.body_len], try reader.raw(msg.body_len));
                if (!bytes.eql(&msg.body_hash, &preimage.hash("edgerun:zig:v1:encrypted-chat-message-body", msg.bodyBytes()))) return error.Corrupt;
                new_messages[mi] = msg;
            }
            if (!reader.done()) return error.Corrupt;

            self.contacts = new_contacts;
            self.contact_count = contact_total;
            self.messages = new_messages;
            self.message_count = message_total;
        }

        pub fn sealSnapshot(self: *const Self, policy: seal.Policy, nonce_material: []const u8, out: []u8, plaintext_scratch: []u8) Error![]const u8 {
            const plaintext = try self.encodePlaintext(plaintext_scratch);
            return sealBytes(policy, nonce_material, plaintext, out);
        }

        pub fn unsealSnapshot(self: *Self, policy: seal.Policy, sealed_bytes: []const u8, plaintext_scratch: []u8) Error!void {
            const plaintext = try unsealBytes(policy, sealed_bytes, plaintext_scratch);
            try self.loadPlaintext(plaintext);
        }
    };
}

pub fn deriveContactId(value: ContactImport) ?identity.Id {
    if (!value.valid()) return null;
    return value.identity_id;
}

pub fn contactDetailsHash(value: ContactImport) ?preimage.Hash {
    var raw: [contact_canonical_max]u8 = undefined;
    const canonical = canonicalContact(value, &raw) orelse return null;
    return preimage.hash("edgerun:zig:v1:encrypted-chat-contact", canonical);
}

pub fn writeContactLink(out: []u8, value: ContactImport) Error![]const u8 {
    if (!value.valid()) return error.BadArgument;
    if (out.len < identity.id_size * 2 + 1 + value.name.len) return error.NoSpace;
    writeHex(out[0 .. identity.id_size * 2], &value.identity_id.bytes);
    out[identity.id_size * 2] = '|';
    _ = bytes.copy(out[identity.id_size * 2 + 1 ..][0..value.name.len], value.name);
    return out[0 .. identity.id_size * 2 + 1 + value.name.len];
}

pub fn sealBytes(policy: seal.Policy, nonce_material: []const u8, plaintext: []const u8, out: []u8) Error![]const u8 {
    if (!policy.valid() or nonce_material.len == 0 or plaintext.len == 0) return error.BadArgument;
    if (out.len < sealed_header_size + plaintext.len) return error.NoSpace;
    const policy_id = policy.id() orelse return error.BadArgument;
    const key = deriveSealKey(policy);
    const nonce = deriveNonce(policy_id, nonce_material, plaintext);

    var writer = SliceWriter.init(out);
    try writer.raw(sealed_magic);
    try writer.writeU16(version);
    try writer.raw(&policy_id);
    try writer.writeU64(plaintext.len);
    try writer.raw(&nonce);
    const tag_pos = writer.pos;
    try writer.raw(&([_]u8{0} ** 32));
    const cipher_start = writer.pos;
    xorStream(out[cipher_start..][0..plaintext.len], plaintext, key, nonce);
    writer.pos += plaintext.len;

    const tag = authTag(policy_id, key, nonce, plaintext.len, out[cipher_start..][0..plaintext.len]);
    _ = bytes.copy(out[tag_pos..][0..32], &tag);
    return writer.written();
}

pub fn unsealBytes(policy: seal.Policy, sealed_bytes: []const u8, out: []u8) Error![]const u8 {
    if (!policy.valid()) return error.BadArgument;
    var reader = SliceReader.init(sealed_bytes);
    if (!bytes.eql(try reader.raw(sealed_magic.len), sealed_magic)) return error.Corrupt;
    if ((try reader.readU16()) != version) return error.Corrupt;
    const expected_policy_id = policy.id() orelse return error.BadArgument;
    const policy_id = toArray32(try reader.raw(32));
    if (!bytes.eql(&policy_id, &expected_policy_id)) return error.AuthFailed;
    const plaintext_len = try reader.readU64();
    if (plaintext_len > out.len or plaintext_len > sealed_bytes.len) return error.NoSpace;
    const nonce = toArray32(try reader.raw(32));
    const stored_tag = toArray32(try reader.raw(32));
    const ciphertext = try reader.raw(@intCast(plaintext_len));
    if (!reader.done()) return error.Corrupt;

    const key = deriveSealKey(policy);
    const actual_tag = authTag(policy_id, key, nonce, plaintext_len, ciphertext);
    if (!bytes.eql(&stored_tag, &actual_tag)) return error.AuthFailed;
    xorStream(out[0..@intCast(plaintext_len)], ciphertext, key, nonce);
    return out[0..@intCast(plaintext_len)];
}

fn canonicalContact(value: ContactImport, out: []u8) ?[]const u8 {
    if (!value.valid() or out.len < contact_canonical_max) return null;
    var writer = SliceWriter.init(out);
    writer.writeU16(@intCast(value.name.len)) catch return null;
    writer.raw(&value.identity_id.bytes) catch return null;
    writer.raw(value.name) catch return null;
    return writer.written();
}

fn parseContactLine(line: []const u8) ?ContactImport {
    const first = bytes.indexOf(line, "|") orelse return null;
    const identity_hex = trim(line[0..first]);
    const name = trim(line[first + 1 ..]);
    var id: [identity.id_size]u8 = undefined;
    parseHexIdentity(identity_hex, &id) orelse return null;
    const value = ContactImport{ .identity_id = .{ .bytes = id }, .name = name };
    return if (value.valid()) value else null;
}

fn writeHex(out: []u8, raw: []const u8) void {
    var index: usize = 0;
    while (index < raw.len) : (index += 1) {
        out[index * 2] = hexChar(raw[index] >> 4);
        out[index * 2 + 1] = hexChar(raw[index] & 0x0f);
    }
}

fn parseHexIdentity(raw: []const u8, out: *[identity.id_size]u8) ?void {
    if (raw.len != identity.id_size * 2) return null;
    var index: usize = 0;
    while (index < identity.id_size) : (index += 1) {
        const hi = hexValue(raw[index * 2]) orelse return null;
        const lo = hexValue(raw[index * 2 + 1]) orelse return null;
        out[index] = (hi << 4) | lo;
    }
    return if (bytes.nonzero(out)) {} else null;
}

fn hexChar(value: u8) u8 {
    return if (value < 10) '0' + value else 'a' + value - 10;
}

fn hexValue(value: u8) ?u8 {
    return switch (value) {
        '0'...'9' => value - '0',
        'a'...'f' => value - 'a' + 10,
        'A'...'F' => value - 'A' + 10,
        else => null,
    };
}

fn trim(value: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = value.len;
    while (start < end and (value[start] == ' ' or value[start] == '\t')) : (start += 1) {}
    while (end > start and (value[end - 1] == ' ' or value[end - 1] == '\t')) : (end -= 1) {}
    return value[start..end];
}

fn validMedia(kind: MediaKind, media_ref: []const u8, media_mime: []const u8, media_size: u64) bool {
    if (media_ref.len > max_media_ref_bytes or media_mime.len > max_media_mime_bytes) return false;
    return validMediaLengths(kind, media_ref.len, media_mime.len, media_size);
}

fn validMediaLengths(kind: MediaKind, media_ref_len: usize, media_mime_len: usize, media_size: u64) bool {
    return switch (kind) {
        .none => media_ref_len == 0 and media_mime_len == 0 and media_size == 0,
        .image, .video => media_ref_len != 0 and media_mime_len != 0 and media_size != 0,
    };
}

fn messageId(contact_id: identity.Id, direction: Direction, body: []const u8, media_kind: MediaKind, media_ref: []const u8, sequence: u64) preimage.Hash {
    var dir = [_]u8{@intFromEnum(direction)};
    var kind = [_]u8{@intFromEnum(media_kind)};
    var builder = preimage.Builder.init("edgerun:zig:v1:encrypted-chat-message");
    builder.id(contact_id);
    builder.bytes(&dir);
    builder.bytes(&kind);
    builder.writeU64(sequence);
    builder.bytes(media_ref);
    builder.bytes(body);
    return builder.final();
}

fn deriveSealKey(policy: seal.Policy) preimage.Hash {
    var raw: [seal.encoded_size]u8 = undefined;
    _ = policy.encode(&raw);
    return preimage.hash("edgerun:zig:v1:encrypted-chat-seal-key", &raw);
}

fn deriveNonce(policy_id: preimage.Hash, nonce_material: []const u8, plaintext: []const u8) preimage.Hash {
    var builder = preimage.Builder.init("edgerun:zig:v1:encrypted-chat-seal-nonce");
    builder.hash(policy_id);
    builder.bytes(nonce_material);
    builder.hash(preimage.rawHash(plaintext));
    return builder.final();
}

fn authTag(policy_id: preimage.Hash, key: preimage.Hash, nonce: preimage.Hash, plaintext_len: u64, ciphertext: []const u8) preimage.Hash {
    var builder = preimage.Builder.init("edgerun:zig:v1:encrypted-chat-seal-auth");
    builder.hash(policy_id);
    builder.hash(key);
    builder.hash(nonce);
    builder.writeU64(plaintext_len);
    builder.bytes(ciphertext);
    return builder.final();
}

fn xorStream(out: []u8, in: []const u8, key: preimage.Hash, nonce: preimage.Hash) void {
    var offset: usize = 0;
    var counter: u64 = 0;
    while (offset < in.len) : (counter += 1) {
        var builder = preimage.Builder.init("edgerun:zig:v1:encrypted-chat-seal-stream");
        builder.hash(key);
        builder.hash(nonce);
        builder.writeU64(counter);
        const block = builder.final();
        var bi: usize = 0;
        while (bi < block.len and offset < in.len) : ({
            bi += 1;
            offset += 1;
        }) {
            out[offset] = in[offset] ^ block[bi];
        }
    }
}

fn toArray32(value: []const u8) [32]u8 {
    var out: [32]u8 = undefined;
    _ = bytes.copy(&out, value[0..32]);
    return out;
}

const SliceWriter = struct {
    buf: []u8,
    pos: usize = 0,

    fn init(buf: []u8) SliceWriter {
        return .{ .buf = buf };
    }

    fn written(self: SliceWriter) []const u8 {
        return self.buf[0..self.pos];
    }

    fn reserve(self: *SliceWriter, len: usize) Error![]u8 {
        if (len > self.buf.len - self.pos) return error.NoSpace;
        const out = self.buf[self.pos..][0..len];
        self.pos += len;
        return out;
    }

    fn byte(self: *SliceWriter, value: u8) Error!void {
        (try self.reserve(1))[0] = value;
    }

    fn writeU16(self: *SliceWriter, value: u16) Error!void {
        if (!bytes.store16(try self.reserve(2), value)) return error.NoSpace;
    }

    fn writeU64(self: *SliceWriter, value: u64) Error!void {
        if (!bytes.store64(try self.reserve(8), value)) return error.NoSpace;
    }

    fn raw(self: *SliceWriter, value: []const u8) Error!void {
        _ = bytes.copy(try self.reserve(value.len), value);
    }
};

const SliceReader = struct {
    buf: []const u8,
    pos: usize = 0,

    fn init(buf: []const u8) SliceReader {
        return .{ .buf = buf };
    }

    fn done(self: SliceReader) bool {
        return self.pos == self.buf.len;
    }

    fn raw(self: *SliceReader, len: usize) Error![]const u8 {
        if (len > self.buf.len - self.pos) return error.Corrupt;
        const out = self.buf[self.pos..][0..len];
        self.pos += len;
        return out;
    }

    fn byte(self: *SliceReader) Error!u8 {
        return (try self.raw(1))[0];
    }

    fn readU16(self: *SliceReader) Error!u16 {
        return bytes.load16(try self.raw(2)) orelse error.Corrupt;
    }

    fn readU64(self: *SliceReader) Error!u64 {
        return bytes.load64(try self.raw(8)) orelse error.Corrupt;
    }
};

fn testIdentity(kind: identity.Kind, label: []const u8, epoch: clock.Stamp) identity.Identity {
    return identity.Identity.init(kind, identity.Source.prepare(.hash, &preimage.rawHash(label)).?, epoch).?;
}

test "contact id is the hidden service identity" {
    const testing = std.testing;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
    const device = testIdentity(.device, "chat device", epoch);
    const app = testIdentity(.app, "encrypted chat app", epoch);
    const user = testIdentity(.user, "chat user", epoch);
    var chat = try ChatState(8, 8).init(device, app, user, epoch);

    const alice_identity = identity.Id{ .bytes = [_]u8{7} ++ [_]u8{3} ** 31 };
    const bob_identity = identity.Id{ .bytes = [_]u8{8} ++ [_]u8{4} ** 31 };
    const alice_v1 = ContactImport{ .identity_id = alice_identity, .name = "Alice" };
    const alice_v1_updated = ContactImport{ .identity_id = alice_identity, .name = "Alice A." };
    const bob = ContactImport{ .identity_id = bob_identity, .name = "Bob" };
    const id_v1 = try chat.importContact(alice_v1, epoch);
    const id_v1_again = try chat.importContact(alice_v1_updated, epoch);
    const id_v2 = try chat.importContact(bob, epoch);

    try testing.expect(id_v1.eql(id_v1_again));
    try testing.expect(!id_v1.eql(id_v2));
    try testing.expect(id_v1.eql(alice_identity));
    try testing.expectEqual(@as(usize, 2), chat.contact_count);
    try testing.expectEqualStrings("Alice A.", chat.findContact(id_v1).?.nameBytes());
    try testing.expectEqualStrings("Bob", chat.findContact(id_v2).?.nameBytes());
}

test "imports contact text appends messages and seals snapshot" {
    const testing = std.testing;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 }, .tick = 9 };
    const device = testIdentity(.device, "chat seal device", epoch);
    const app = testIdentity(.app, "encrypted chat seal app", epoch);
    const user = testIdentity(.user, "chat seal user", epoch);
    var chat = try ChatState(8, 8).init(device, app, user, epoch);

    const alice_identity = identity.Id{ .bytes = [_]u8{7} ++ [_]u8{3} ** 31 };
    const bob_identity = identity.Id{ .bytes = [_]u8{8} ++ [_]u8{4} ** 31 };
    var alice_line_buf: [contact_canonical_max]u8 = undefined;
    var bob_line_buf: [contact_canonical_max]u8 = undefined;
    const alice_line = try writeContactLink(&alice_line_buf, .{ .identity_id = alice_identity, .name = "Alice" });
    const bob_line = try writeContactLink(&bob_line_buf, .{ .identity_id = bob_identity, .name = "Bob" });
    var import_buf: [contact_canonical_max * 2 + 1]u8 = undefined;
    const import_text = try std.fmt.bufPrint(&import_buf, "{s}\n{s}", .{ alice_line, bob_line });
    const imported = try chat.importContactsText(import_text, epoch);
    try testing.expectEqual(@as(usize, 2), imported);
    const alice = deriveContactId(.{ .identity_id = alice_identity, .name = "Alice" }).?;
    _ = try chat.appendMessage(alice, .outbound, "hello over our identity route");
    _ = try chat.appendMediaMessage(alice, .inbound, "photo proof", .image, "object://image/alice-proof", "image/erimg", 4096);
    _ = try chat.appendMediaMessage(alice, .outbound, "video proof", .video, "object://video/alice-proof", "video/ivf", 8192);

    var link_buf: [contact_canonical_max]u8 = undefined;
    const share_line = try writeContactLink(&link_buf, .{ .identity_id = alice_identity, .name = "Alice" });
    try testing.expectEqualStrings(alice_line, share_line);

    var plaintext: [4096]u8 = undefined;
    var sealed_buf: [4096]u8 = undefined;
    const sealed_snapshot = try chat.sealSnapshot(chat.sealPolicy(), "first-import", &sealed_buf, &plaintext);
    try testing.expect(sealed_snapshot.len > sealed_header_size);
    try testing.expect(bytes.indexOf(sealed_snapshot, "hello over our identity route") == null);

    var restored = try ChatState(8, 8).init(device, app, user, epoch);
    var open_buf: [4096]u8 = undefined;
    try restored.unsealSnapshot(restored.sealPolicy(), sealed_snapshot, &open_buf);
    try testing.expectEqual(@as(usize, 2), restored.contact_count);
    try testing.expectEqual(@as(usize, 3), restored.message_count);
    try testing.expectEqualStrings("hello over our identity route", restored.messages[0].bodyBytes());
    try testing.expectEqual(MediaKind.image, restored.messages[1].media_kind);
    try testing.expectEqualStrings("object://image/alice-proof", restored.messages[1].mediaRefBytes());
    try testing.expectEqualStrings("image/erimg", restored.messages[1].mediaMimeBytes());
    try testing.expectEqual(@as(u64, 4096), restored.messages[1].media_size);
    try testing.expectEqual(MediaKind.video, restored.messages[2].media_kind);
    try testing.expectEqualStrings("object://video/alice-proof", restored.messages[2].mediaRefBytes());
    try testing.expectEqualStrings("video/ivf", restored.messages[2].mediaMimeBytes());
    try testing.expectEqual(@as(u64, 8192), restored.messages[2].media_size);

    sealed_buf[sealed_snapshot.len - 1] ^= 1;
    try testing.expectError(error.AuthFailed, restored.unsealSnapshot(restored.sealPolicy(), sealed_buf[0..sealed_snapshot.len], &open_buf));
}
