const std = @import("std");

const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const crypto = @import("crypto.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");
const seal = @import("seal.zig");

pub const hash_size = preimage.hash_size;
pub const contact_canonical_max = 2 + 2 + 2 + 2 + max_contact_route_bytes + max_name_bytes + max_route_bytes + max_public_key_bytes;
pub const max_contact_route_bytes = 96;
pub const max_name_bytes = 64;
pub const max_route_bytes = 128;
pub const max_public_key_bytes = 96;
pub const max_message_body_bytes = 1024;
pub const sealed_header_size = 114;

const snapshot_magic = "ERCHAT01";
const sealed_magic = "ERCHSEAL";
const version: u16 = 1;

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

pub const ContactImport = struct {
    contact_route: []const u8,
    name: []const u8,
    route: []const u8,
    public_key: []const u8,

    pub fn valid(self: ContactImport) bool {
        return self.contact_route.len != 0 and self.contact_route.len <= max_contact_route_bytes and
            self.name.len != 0 and self.name.len <= max_name_bytes and
            self.route.len != 0 and self.route.len <= max_route_bytes and
            self.public_key.len != 0 and self.public_key.len <= max_public_key_bytes;
    }
};

pub const Contact = struct {
    id: identity.Id,
    details_hash: preimage.Hash,
    epoch: clock.Stamp,
    contact_route: [max_contact_route_bytes]u8 = [_]u8{0} ** max_contact_route_bytes,
    contact_route_len: usize = 0,
    name: [max_name_bytes]u8 = [_]u8{0} ** max_name_bytes,
    name_len: usize = 0,
    route: [max_route_bytes]u8 = [_]u8{0} ** max_route_bytes,
    route_len: usize = 0,
    public_key: [max_public_key_bytes]u8 = [_]u8{0} ** max_public_key_bytes,
    public_key_len: usize = 0,

    pub fn contactRouteBytes(self: *const Contact) []const u8 {
        return self.contact_route[0..self.contact_route_len];
    }

    pub fn nameBytes(self: *const Contact) []const u8 {
        return self.name[0..self.name_len];
    }

    pub fn routeBytes(self: *const Contact) []const u8 {
        return self.route[0..self.route_len];
    }

    pub fn publicKeyBytes(self: *const Contact) []const u8 {
        return self.public_key[0..self.public_key_len];
    }
};

pub const Message = struct {
    id: preimage.Hash,
    contact_id: identity.Id,
    body_hash: preimage.Hash,
    direction: Direction,
    body: [max_message_body_bytes]u8 = [_]u8{0} ** max_message_body_bytes,
    body_len: usize = 0,

    pub fn bodyBytes(self: *const Message) []const u8 {
        return self.body[0..self.body_len];
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
            _ = bytes.copy(contact.contact_route[0..value.contact_route.len], value.contact_route);
            _ = bytes.copy(contact.name[0..value.name.len], value.name);
            _ = bytes.copy(contact.route[0..value.route.len], value.route);
            _ = bytes.copy(contact.public_key[0..value.public_key.len], value.public_key);
            contact.contact_route_len = value.contact_route.len;
            contact.name_len = value.name.len;
            contact.route_len = value.route.len;
            contact.public_key_len = value.public_key.len;

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
            if (!contact_id.valid() or self.findContactIndex(contact_id) == null) return error.NotFound;
            if (body.len == 0 or body.len > max_message_body_bytes) return error.BadArgument;
            if (self.message_count == self.messages.len) return error.NoSpace;

            var msg = Message{
                .id = messageId(contact_id, direction, body, @intCast(self.message_count)),
                .contact_id = contact_id,
                .body_hash = preimage.hash("edgerun:zig:v1:encrypted-chat-message-body", body),
                .direction = direction,
            };
            _ = bytes.copy(msg.body[0..body.len], body);
            msg.body_len = body.len;
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
                size += 134 + c.contact_route_len + c.name_len + c.route_len + c.public_key_len;
            }
            i = 0;
            while (i < self.message_count) : (i += 1) {
                const m = &self.messages[i];
                size += 99 + m.body_len;
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
                try writer.writeU16(@intCast(c.contact_route_len));
                try writer.writeU16(@intCast(c.name_len));
                try writer.writeU16(@intCast(c.route_len));
                try writer.writeU16(@intCast(c.public_key_len));
                try writer.raw(c.contactRouteBytes());
                try writer.raw(c.nameBytes());
                try writer.raw(c.routeBytes());
                try writer.raw(c.publicKeyBytes());
            }

            i = 0;
            while (i < self.message_count) : (i += 1) {
                const m = &self.messages[i];
                try writer.raw(&m.id);
                try writer.raw(&m.contact_id.bytes);
                try writer.raw(&m.body_hash);
                try writer.byte(@intFromEnum(m.direction));
                try writer.writeU16(@intCast(m.body_len));
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
                contact.contact_route_len = try reader.readU16();
                contact.name_len = try reader.readU16();
                contact.route_len = try reader.readU16();
                contact.public_key_len = try reader.readU16();
                if (!contact.id.valid() or !contact.epoch.valid() or
                    contact.contact_route_len == 0 or contact.contact_route_len > max_contact_route_bytes or
                    contact.name_len == 0 or contact.name_len > max_name_bytes or
                    contact.route_len == 0 or contact.route_len > max_route_bytes or
                    contact.public_key_len == 0 or contact.public_key_len > max_public_key_bytes)
                {
                    return error.Corrupt;
                }
                _ = bytes.copy(contact.contact_route[0..contact.contact_route_len], try reader.raw(contact.contact_route_len));
                _ = bytes.copy(contact.name[0..contact.name_len], try reader.raw(contact.name_len));
                _ = bytes.copy(contact.route[0..contact.route_len], try reader.raw(contact.route_len));
                _ = bytes.copy(contact.public_key[0..contact.public_key_len], try reader.raw(contact.public_key_len));
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
                };
                msg.body_len = try reader.readU16();
                if (!bytes.nonzero(&msg.id) or !msg.contact_id.valid() or msg.body_len == 0 or msg.body_len > max_message_body_bytes) return error.Corrupt;
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
    const route_hash = preimage.hash("edgerun:zig:v1:encrypted-chat-contact-route", value.contact_route);
    const source = identity.Source.prepare(.derived, &route_hash) orelse return null;
    return source.id();
}

pub fn contactDetailsHash(value: ContactImport) ?preimage.Hash {
    var raw: [contact_canonical_max]u8 = undefined;
    const canonical = canonicalContact(value, &raw) orelse return null;
    return preimage.hash("edgerun:zig:v1:encrypted-chat-contact", canonical);
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
    writer.writeU16(@intCast(value.contact_route.len)) catch return null;
    writer.writeU16(@intCast(value.name.len)) catch return null;
    writer.writeU16(@intCast(value.route.len)) catch return null;
    writer.writeU16(@intCast(value.public_key.len)) catch return null;
    writer.raw(value.contact_route) catch return null;
    writer.raw(value.name) catch return null;
    writer.raw(value.route) catch return null;
    writer.raw(value.public_key) catch return null;
    return writer.written();
}

fn parseContactLine(line: []const u8) ?ContactImport {
    const first = bytes.indexOf(line, "|") orelse return null;
    const rest = line[first + 1 ..];
    const second_rel = bytes.indexOf(rest, "|") orelse return null;
    const second = first + 1 + second_rel;
    const tail = line[second + 1 ..];
    const third_rel = bytes.indexOf(tail, "|") orelse return null;
    const third = second + 1 + third_rel;
    const contact_route = trim(line[0..first]);
    const name = trim(line[first + 1 .. second]);
    const route = trim(line[second + 1 .. third]);
    const public_key = trim(line[third + 1 ..]);
    const value = ContactImport{ .contact_route = contact_route, .name = name, .route = route, .public_key = public_key };
    return if (value.valid()) value else null;
}

fn trim(value: []const u8) []const u8 {
    var start: usize = 0;
    var end: usize = value.len;
    while (start < end and (value[start] == ' ' or value[start] == '\t')) : (start += 1) {}
    while (end > start and (value[end - 1] == ' ' or value[end - 1] == '\t')) : (end -= 1) {}
    return value[start..end];
}

fn messageId(contact_id: identity.Id, direction: Direction, body: []const u8, sequence: u64) preimage.Hash {
    var dir = [_]u8{@intFromEnum(direction)};
    var builder = preimage.Builder.init("edgerun:zig:v1:encrypted-chat-message");
    builder.id(contact_id);
    builder.bytes(&dir);
    builder.writeU64(sequence);
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

test "contact id is the user-created route given to that contact" {
    const testing = std.testing;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
    const device = testIdentity(.device, "chat device", epoch);
    const app = testIdentity(.app, "encrypted chat app", epoch);
    const user = testIdentity(.user, "chat user", epoch);
    var chat = try ChatState(8, 8).init(device, app, user, epoch);

    const alice_v1 = ContactImport{ .contact_route = "route-to-me-for-alice-1", .name = "Alice", .route = "alice.onion", .public_key = "alice-key-1" };
    const alice_v1_updated = ContactImport{ .contact_route = "route-to-me-for-alice-1", .name = "Alice A.", .route = "alice-new.onion", .public_key = "alice-key-2" };
    const alice_v2 = ContactImport{ .contact_route = "route-to-me-for-alice-2", .name = "Alice", .route = "alice-new.onion", .public_key = "alice-key-2" };
    const id_v1 = try chat.importContact(alice_v1, epoch);
    const id_v1_again = try chat.importContact(alice_v1_updated, epoch);
    const id_v2 = try chat.importContact(alice_v2, epoch);

    try testing.expect(id_v1.eql(id_v1_again));
    try testing.expect(!id_v1.eql(id_v2));
    try testing.expectEqual(@as(usize, 2), chat.contact_count);
    try testing.expectEqualStrings("route-to-me-for-alice-1", chat.findContact(id_v1).?.contactRouteBytes());
    try testing.expectEqualStrings("Alice A.", chat.findContact(id_v1).?.nameBytes());
    try testing.expectEqualStrings("alice-new.onion", chat.findContact(id_v1).?.routeBytes());
    try testing.expectEqualStrings("route-to-me-for-alice-2", chat.findContact(id_v2).?.contactRouteBytes());
    try testing.expectEqualStrings("alice-new.onion", chat.findContact(id_v2).?.routeBytes());
}

test "imports contact text appends messages and seals snapshot" {
    const testing = std.testing;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 }, .tick = 9 };
    const device = testIdentity(.device, "chat seal device", epoch);
    const app = testIdentity(.app, "encrypted chat seal app", epoch);
    const user = testIdentity(.user, "chat seal user", epoch);
    var chat = try ChatState(8, 8).init(device, app, user, epoch);

    const imported = try chat.importContactsText(
        \\route-to-me-for-alice|Alice|alice.onion|alice-key
        \\route-to-me-for-bob|Bob|bob.onion|bob-key
    , epoch);
    try testing.expectEqual(@as(usize, 2), imported);
    const alice = deriveContactId(.{ .contact_route = "route-to-me-for-alice", .name = "Alice", .route = "alice.onion", .public_key = "alice-key" }).?;
    _ = try chat.appendMessage(alice, .outbound, "hello over our onion route");

    var plaintext: [4096]u8 = undefined;
    var sealed_buf: [4096]u8 = undefined;
    const sealed_snapshot = try chat.sealSnapshot(chat.sealPolicy(), "first-import", &sealed_buf, &plaintext);
    try testing.expect(sealed_snapshot.len > sealed_header_size);
    try testing.expect(bytes.indexOf(sealed_snapshot, "hello over our onion route") == null);

    var restored = try ChatState(8, 8).init(device, app, user, epoch);
    var open_buf: [4096]u8 = undefined;
    try restored.unsealSnapshot(restored.sealPolicy(), sealed_snapshot, &open_buf);
    try testing.expectEqual(@as(usize, 2), restored.contact_count);
    try testing.expectEqual(@as(usize, 1), restored.message_count);
    try testing.expectEqualStrings("hello over our onion route", restored.messages[0].bodyBytes());

    sealed_buf[sealed_snapshot.len - 1] ^= 1;
    try testing.expectError(error.AuthFailed, restored.unsealSnapshot(restored.sealPolicy(), sealed_buf[0..sealed_snapshot.len], &open_buf));
}
