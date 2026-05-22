const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");
const seal = @import("seal.zig");

pub const id_size = preimage.hash_size;
pub const header_size = 148;
pub const requirements_size = 28;
pub const owner_size = 36;
pub const envelope_size = 76;
pub const child_size = 84;
pub const magic = "EROBJ001";
pub const max_owners = 16;
pub const max_envelopes = 16;
pub const max_children = 65536;
pub const signature_magic = "ERSIG001";
pub const signature_fixed_body_size = 112;
pub const signature_max_size = 128;

pub const Error = error{
    BadArgument,
    NoSpace,
    Corrupt,
    Unsupported,
};

pub const Kind = enum(u16) {
    bytes = 1,
    tree = 2,
    receipt = 4,
};

pub const Durability = enum(u32) {
    memory = 1,
    durable = 2,
    replicated = 3,
};

pub const Confidentiality = enum(u32) {
    public = 1,
    integrity_only = 2,
    app_private = 3,
    user_private = 4,
    user_app_private = 5,
    device_private = 6,
    layered = 7,
};

pub const Portability = enum(u32) {
    machine_bound = 1,
    user_portable = 2,
    app_portable = 3,
    public_portable = 4,
};

pub const Integrity = enum(u32) {
    hash_only = 1,
    signed = 2,
    sealed = 3,
};

pub const Lifetime = enum(u32) {
    transient = 1,
    session = 2,
    cache = 3,
    retained = 4,
    pinned = 5,
};

pub const Visibility = enum(u32) {
    private = 1,
    app_namespace = 2,
    user_namespace = 3,
    public = 4,
};

pub const Access = enum(u32) {
    explicit_io = 1,
    hot_memory_allowed = 2,
};

pub const Requirements = struct {
    durability: Durability,
    confidentiality: Confidentiality,
    portability: Portability,
    integrity: Integrity,
    lifetime: Lifetime,
    visibility: Visibility,
    access: Access,

    pub fn encode(self: Requirements, out: []u8) bool {
        if (out.len < requirements_size) return false;
        return bytes.store32(out[0..4], @intFromEnum(self.durability)) and
            bytes.store32(out[4..8], @intFromEnum(self.confidentiality)) and
            bytes.store32(out[8..12], @intFromEnum(self.portability)) and
            bytes.store32(out[12..16], @intFromEnum(self.integrity)) and
            bytes.store32(out[16..20], @intFromEnum(self.lifetime)) and
            bytes.store32(out[20..24], @intFromEnum(self.visibility)) and
            bytes.store32(out[24..28], @intFromEnum(self.access));
    }

    pub fn decode(in: []const u8) Error!Requirements {
        if (in.len < requirements_size) return error.Corrupt;
        return .{
            .durability = enumFromInt(Durability, bytes.load32(in[0..4]) orelse return error.Corrupt) orelse return error.Corrupt,
            .confidentiality = enumFromInt(Confidentiality, bytes.load32(in[4..8]) orelse return error.Corrupt) orelse return error.Corrupt,
            .portability = enumFromInt(Portability, bytes.load32(in[8..12]) orelse return error.Corrupt) orelse return error.Corrupt,
            .integrity = enumFromInt(Integrity, bytes.load32(in[12..16]) orelse return error.Corrupt) orelse return error.Corrupt,
            .lifetime = enumFromInt(Lifetime, bytes.load32(in[16..20]) orelse return error.Corrupt) orelse return error.Corrupt,
            .visibility = enumFromInt(Visibility, bytes.load32(in[20..24]) orelse return error.Corrupt) orelse return error.Corrupt,
            .access = enumFromInt(Access, bytes.load32(in[24..28]) orelse return error.Corrupt) orelse return error.Corrupt,
        };
    }

    pub fn hash(self: Requirements) [id_size]u8 {
        var raw: [requirements_size]u8 = undefined;
        _ = self.encode(&raw);

        return preimage.rawHash(&raw);
    }

    pub fn sealPolicy(self: Requirements, device: identity.Identity, app: identity.Identity, user: identity.Identity) ?seal.Policy {
        return switch (self.confidentiality) {
            .public => seal.Policy.public(),
            .integrity_only => seal.Policy.integrityOnly(),
            .app_private, .device_private => seal.Policy.machineApp(device, app),
            .user_private, .user_app_private, .layered => seal.Policy.machineAppUser(device, app, user),
        };
    }
};

pub const Header = struct {
    kind: Kind,
    flags: u32 = 0,
    logical_len: u64,
    owner_count: u16 = 0,
    envelope_count: u16 = 0,
    child_count: u32 = 0,
    body_len: u64,
    epoch: clock.Stamp,
    requirements: Requirements,

    pub fn encode(self: Header, out: []u8) Error!void {
        if (out.len < header_size) return error.NoSpace;
        if (!self.epoch.valid()) return error.BadArgument;

        @memset(out[0..header_size], 0);
        @memcpy(out[0..magic.len], magic);
        _ = bytes.store16(out[8..10], 1);
        _ = bytes.store16(out[10..12], @intFromEnum(self.kind));
        _ = bytes.store32(out[12..16], self.flags);
        _ = bytes.store64(out[16..24], self.logical_len);
        _ = bytes.store16(out[24..26], self.owner_count);
        _ = bytes.store16(out[26..28], self.envelope_count);
        _ = bytes.store32(out[28..32], self.child_count);
        _ = bytes.store64(out[32..40], self.body_len);
        encodeEpoch(self.epoch, out[40..104]);
        _ = self.requirements.encode(out[104..132]);
    }

    pub fn decode(in: []const u8) Error!Header {
        if (in.len < header_size) return error.Corrupt;
        if (!bytes.eql(in[0..magic.len], magic)) return error.Corrupt;
        if ((bytes.load16(in[8..10]) orelse return error.Corrupt) != 1) return error.Corrupt;

        const kind = enumFromInt(Kind, bytes.load16(in[10..12]) orelse return error.Corrupt) orelse
            return error.Corrupt;
        return .{
            .kind = kind,
            .flags = bytes.load32(in[12..16]) orelse return error.Corrupt,
            .logical_len = bytes.load64(in[16..24]) orelse return error.Corrupt,
            .owner_count = bytes.load16(in[24..26]) orelse return error.Corrupt,
            .envelope_count = bytes.load16(in[26..28]) orelse return error.Corrupt,
            .child_count = bytes.load32(in[28..32]) orelse return error.Corrupt,
            .body_len = bytes.load64(in[32..40]) orelse return error.Corrupt,
            .epoch = try decodeEpoch(in[40..104]),
            .requirements = try Requirements.decode(in[104..132]),
        };
    }

    pub fn id(canonical: []const u8) [id_size]u8 {
        return preimage.rawHash(canonical);
    }

    pub fn idForBytes(requirements: Requirements, epoch: clock.Stamp, body: []const u8) ?[id_size]u8 {
        if (!epoch.valid()) return null;
        var header_raw: [header_size]u8 = undefined;
        const header = Header{
            .kind = .bytes,
            .logical_len = body.len,
            .body_len = body.len,
            .epoch = epoch,
            .requirements = requirements,
        };
        header.encode(&header_raw) catch return null;

        var builder = std.crypto.hash.Blake3.init(.{});
        builder.update(&header_raw);
        builder.update(body);
        var out: [id_size]u8 = undefined;
        builder.final(&out);
        return out;
    }
};

pub const OwnerKind = enum(u32) {
    device = 1,
    storage = 2,
    app = 3,
    user = 4,
};

pub const EnvelopeKind = enum(u32) {
    none = 0,
    device = 1,
    storage = 2,
    app = 3,
    user = 4,
    signature = 5,
};

pub const Algorithm = enum(u16) {
    none = 0,
    blake3 = 1,
    aes_gcm_256 = 2,
    xchacha20_poly1305 = 3,
    ed25519 = 4,
    ecdsa_p256_sha256 = 5,
};

pub const Owner = struct {
    kind: OwnerKind,
    node_id: [id_size]u8,

    pub fn valid(self: Owner) bool {
        return bytes.nonzero(&self.node_id);
    }

    pub fn encode(self: Owner, out: []u8) bool {
        if (out.len < owner_size or !self.valid()) return false;
        return bytes.store32(out[0..4], @intFromEnum(self.kind)) and
            bytes.copy(out[4..36], &self.node_id);
    }

    pub fn decode(in: []const u8) Error!Owner {
        if (in.len < owner_size) return error.Corrupt;
        const owner = Owner{
            .kind = enumFromInt(OwnerKind, bytes.load32(in[0..4]) orelse return error.Corrupt) orelse return error.Corrupt,
            .node_id = idFromBytes(in[4..36]),
        };
        if (!owner.valid()) return error.Corrupt;
        return owner;
    }
};

pub const Envelope = struct {
    kind: EnvelopeKind,
    owner_index: u16,
    algorithm: Algorithm,
    flags: u32,
    key_id: [id_size]u8,
    metadata_hash: [id_size]u8,

    pub fn valid(self: Envelope, owner: Owner) bool {
        if (!envelopeOwnerMatches(self.kind, owner.kind) or !envelopeAlgorithmMatches(self.kind, self.algorithm)) return false;
        if (self.kind == .none) return zeroed(&self.key_id) and zeroed(&self.metadata_hash);
        return bytes.nonzero(&self.key_id) and bytes.nonzero(&self.metadata_hash);
    }

    pub fn encode(self: Envelope, owner: Owner, out: []u8) bool {
        if (out.len < envelope_size or !self.valid(owner)) return false;
        return bytes.store32(out[0..4], @intFromEnum(self.kind)) and
            bytes.store16(out[4..6], self.owner_index) and
            bytes.store16(out[6..8], @intFromEnum(self.algorithm)) and
            bytes.store32(out[8..12], self.flags) and
            bytes.copy(out[12..44], &self.key_id) and
            bytes.copy(out[44..76], &self.metadata_hash);
    }

    pub fn decode(in: []const u8) Error!Envelope {
        if (in.len < envelope_size) return error.Corrupt;
        return .{
            .kind = enumFromInt(EnvelopeKind, bytes.load32(in[0..4]) orelse return error.Corrupt) orelse return error.Corrupt,
            .owner_index = bytes.load16(in[4..6]) orelse return error.Corrupt,
            .algorithm = enumFromInt(Algorithm, bytes.load16(in[6..8]) orelse return error.Corrupt) orelse return error.Corrupt,
            .flags = bytes.load32(in[8..12]) orelse return error.Corrupt,
            .key_id = idFromBytes(in[12..44]),
            .metadata_hash = idFromBytes(in[44..76]),
        };
    }
};

pub const Child = struct {
    object_id: [id_size]u8,
    logical_offset: u64,
    logical_len: u64,
    kind: Kind,
    requirements_hash: [id_size]u8,

    pub fn valid(self: Child, expected_offset: u64) bool {
        return self.logical_offset == expected_offset and
            self.logical_len != 0 and
            bytes.nonzero(&self.object_id) and
            bytes.nonzero(&self.requirements_hash);
    }

    pub fn encode(self: Child, out: []u8) bool {
        if (out.len < child_size) return false;
        return bytes.copy(out[0..32], &self.object_id) and
            bytes.store64(out[32..40], self.logical_offset) and
            bytes.store64(out[40..48], self.logical_len) and
            bytes.store16(out[48..50], @intFromEnum(self.kind)) and
            bytes.store16(out[50..52], 0) and
            bytes.copy(out[52..84], &self.requirements_hash);
    }

    pub fn decode(in: []const u8, expected_offset: u64) Error!Child {
        if (in.len < child_size) return error.Corrupt;
        if ((bytes.load16(in[50..52]) orelse return error.Corrupt) != 0) return error.Corrupt;

        const child = Child{
            .object_id = idFromBytes(in[0..32]),
            .logical_offset = bytes.load64(in[32..40]) orelse return error.Corrupt,
            .logical_len = bytes.load64(in[40..48]) orelse return error.Corrupt,
            .kind = enumFromInt(Kind, bytes.load16(in[48..50]) orelse return error.Corrupt) orelse return error.Corrupt,
            .requirements_hash = idFromBytes(in[52..84]),
        };
        if (!child.valid(expected_offset)) return error.Corrupt;
        return child;
    }
};

pub const View = struct {
    canonical: []const u8,
    header: Header,
    owners: []const u8,
    envelopes: []const u8,
    children: []const u8,
    body: []const u8,

    pub fn decode(canonical: []const u8) Error!View {
        if (canonical.len < header_size) return error.Corrupt;
        const header = try Header.decode(canonical[0..header_size]);
        const body_len = std.math.cast(usize, header.body_len) orelse return error.Corrupt;
        const expected_len = try canonicalSize(header.kind, body_len, header.owner_count, header.envelope_count, header.child_count);
        if (expected_len != canonical.len) return error.Corrupt;

        if (header.kind == .tree and body_len != 0) return error.Corrupt;
        if (header.kind != .tree and header.logical_len != header.body_len) return error.Corrupt;

        const owners_start = header_size;
        const envelopes_start = owners_start + @as(usize, header.owner_count) * owner_size;
        const children_start = envelopes_start + @as(usize, header.envelope_count) * envelope_size;
        const body_start = children_start + @as(usize, header.child_count) * child_size;

        var index: usize = 0;
        while (index < header.owner_count) : (index += 1) {
            _ = try Owner.decode(canonical[owners_start + index * owner_size ..][0..owner_size]);
        }

        index = 0;
        while (index < header.envelope_count) : (index += 1) {
            const envelope = try Envelope.decode(canonical[envelopes_start + index * envelope_size ..][0..envelope_size]);
            if (envelope.owner_index >= header.owner_count) return error.Corrupt;
            const owner = try Owner.decode(canonical[owners_start + @as(usize, envelope.owner_index) * owner_size ..][0..owner_size]);
            if (!envelope.valid(owner)) return error.Corrupt;
        }

        var expected_offset: u64 = 0;
        index = 0;
        while (index < header.child_count) : (index += 1) {
            const child = try Child.decode(canonical[children_start + index * child_size ..][0..child_size], expected_offset);
            expected_offset = std.math.add(u64, expected_offset, child.logical_len) catch return error.Corrupt;
        }
        if (header.kind == .tree and expected_offset != header.logical_len) return error.Corrupt;

        return .{
            .canonical = canonical,
            .header = header,
            .owners = canonical[owners_start..envelopes_start],
            .envelopes = canonical[envelopes_start..children_start],
            .children = canonical[children_start..body_start],
            .body = canonical[body_start..][0..body_len],
        };
    }

    pub fn id(self: View) [id_size]u8 {
        return Header.id(self.canonical);
    }

    pub fn ownerAt(self: View, index: usize) Error!Owner {
        if (index >= self.header.owner_count) return error.Corrupt;
        return Owner.decode(self.owners[index * owner_size ..][0..owner_size]);
    }

    pub fn envelopeAt(self: View, index: usize) Error!Envelope {
        if (index >= self.header.envelope_count) return error.Corrupt;
        return Envelope.decode(self.envelopes[index * envelope_size ..][0..envelope_size]);
    }

    pub fn childAt(self: View, index: usize) Error!Child {
        if (index >= self.header.child_count) return error.Corrupt;
        var expected_offset: u64 = 0;
        var cursor: usize = 0;
        while (cursor < index) : (cursor += 1) {
            const child = try Child.decode(self.children[cursor * child_size ..][0..child_size], expected_offset);
            expected_offset = std.math.add(u64, expected_offset, child.logical_len) catch return error.Corrupt;
        }
        return Child.decode(self.children[index * child_size ..][0..child_size], expected_offset);
    }
};

pub const SignatureInfo = struct {
    signer_id: [id_size]u8,
    challenge_id: [id_size]u8,
    subject_id: [id_size]u8,
    algorithm: Algorithm,
    signature: []const u8,

    pub fn valid(self: SignatureInfo) bool {
        return bytes.nonzero(&self.signer_id) and
            bytes.nonzero(&self.challenge_id) and
            bytes.nonzero(&self.subject_id) and
            self.algorithm != .none and
            self.signature.len != 0 and
            self.signature.len <= signature_max_size and
            bytes.nonzero(self.signature);
    }
};

pub fn canonicalSize(kind: Kind, body_len: usize, owners: usize, envelopes: usize, children: usize) Error!usize {
    if (owners > max_owners or envelopes > max_envelopes or children > max_children) return error.BadArgument;
    if ((kind == .bytes or kind == .receipt) and children != 0) return error.BadArgument;
    if (kind == .tree and body_len != 0) return error.BadArgument;

    var total: usize = header_size;
    total = std.math.add(usize, total, std.math.mul(usize, owners, owner_size) catch return error.NoSpace) catch return error.NoSpace;
    total = std.math.add(usize, total, std.math.mul(usize, envelopes, envelope_size) catch return error.NoSpace) catch return error.NoSpace;
    total = std.math.add(usize, total, std.math.mul(usize, children, child_size) catch return error.NoSpace) catch return error.NoSpace;
    total = std.math.add(usize, total, body_len) catch return error.NoSpace;
    return total;
}

pub const NodeWriter = struct {
    out: []u8,

    pub fn bytesNode(self: NodeWriter, req: Requirements, epoch: clock.Stamp, body: []const u8) Error![]u8 {
        return try self.bytesNodeOwned(req, epoch, &.{}, &.{}, body);
    }

    pub fn bytesNodeOwned(self: NodeWriter, req: Requirements, epoch: clock.Stamp, owners: []const Owner, envelopes: []const Envelope, body: []const u8) Error![]u8 {
        return try self.writeNode(.{
            .kind = .bytes,
            .logical_len = body.len,
            .body = body,
            .owners = owners,
            .envelopes = envelopes,
            .children = &.{},
            .requirements = req,
            .epoch = epoch,
        });
    }

    pub fn treeNode(self: NodeWriter, req: Requirements, epoch: clock.Stamp, children: []const Child) Error![]u8 {
        return try self.treeNodeOwned(req, epoch, &.{}, &.{}, children);
    }

    pub fn treeNodeOwned(self: NodeWriter, req: Requirements, epoch: clock.Stamp, owners: []const Owner, envelopes: []const Envelope, children: []const Child) Error![]u8 {
        var logical_len: u64 = 0;
        for (children) |child| {
            if (!child.valid(logical_len)) return error.BadArgument;
            logical_len = std.math.add(u64, logical_len, child.logical_len) catch return error.NoSpace;
        }

        return try self.writeNode(.{
            .kind = .tree,
            .logical_len = logical_len,
            .body = "",
            .owners = owners,
            .envelopes = envelopes,
            .children = children,
            .requirements = req,
            .epoch = epoch,
        });
    }

    pub fn receiptNode(self: NodeWriter, req: Requirements, epoch: clock.Stamp, body: []const u8) Error![]u8 {
        return try self.receiptNodeOwned(req, epoch, &.{}, &.{}, body);
    }

    pub fn receiptNodeOwned(self: NodeWriter, req: Requirements, epoch: clock.Stamp, owners: []const Owner, envelopes: []const Envelope, body: []const u8) Error![]u8 {
        return try self.writeNode(.{
            .kind = .receipt,
            .logical_len = body.len,
            .body = body,
            .owners = owners,
            .envelopes = envelopes,
            .children = &.{},
            .requirements = req,
            .epoch = epoch,
        });
    }

    pub fn signatureReceiptNode(self: NodeWriter, subject_canonical: []const u8, challenge_canonical: []const u8, signer_id: [id_size]u8, algorithm: Algorithm, signature: []const u8, epoch: clock.Stamp) Error![]u8 {
        return try writeSignatureReceipt(subject_canonical, challenge_canonical, signer_id, algorithm, signature, epoch, self.out);
    }

    fn writeNode(self: NodeWriter, spec: WriteSpec) Error![]u8 {
        const total = try canonicalSize(spec.kind, spec.body.len, spec.owners.len, spec.envelopes.len, spec.children.len);
        if (self.out.len < total) return error.NoSpace;
        if (!spec.epoch.valid()) return error.BadArgument;
        if (!validOwners(spec.owners) or !validEnvelopes(spec.owners, spec.envelopes)) return error.BadArgument;

        const raw = self.out[0..total];
        const header = Header{
            .kind = spec.kind,
            .logical_len = spec.logical_len,
            .owner_count = @intCast(spec.owners.len),
            .envelope_count = @intCast(spec.envelopes.len),
            .child_count = @intCast(spec.children.len),
            .body_len = spec.body.len,
            .epoch = spec.epoch,
            .requirements = spec.requirements,
        };
        try header.encode(raw);

        var offset: usize = header_size;
        for (spec.owners) |owner| {
            if (!owner.encode(raw[offset..][0..owner_size])) return error.BadArgument;
            offset += owner_size;
        }
        for (spec.envelopes) |envelope| {
            const owner = spec.owners[envelope.owner_index];
            if (!envelope.encode(owner, raw[offset..][0..envelope_size])) return error.BadArgument;
            offset += envelope_size;
        }
        for (spec.children) |child| {
            if (!child.encode(raw[offset..][0..child_size])) return error.BadArgument;
            offset += child_size;
        }
        copyBytes(raw[offset..][0..spec.body.len], spec.body);
        return raw;
    }
};

fn copyBytes(dest: []u8, source: []const u8) void {
    if (dest.len == 0) return;
    if (@intFromPtr(dest.ptr) <= @intFromPtr(source.ptr)) {
        std.mem.copyForwards(u8, dest, source);
    } else {
        std.mem.copyBackwards(u8, dest, source);
    }
}

pub fn signatureRequirements() Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .integrity_only,
        .portability = .public_portable,
        .integrity = .signed,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };
}

pub fn writeSignatureReceipt(subject_canonical: []const u8, challenge_canonical: []const u8, signer_id: [id_size]u8, algorithm: Algorithm, signature: []const u8, epoch: clock.Stamp, out: []u8) Error![]u8 {
    if (!bytes.nonzero(&signer_id) or !epoch.valid()) return error.BadArgument;
    if (algorithm == .none or signature.len == 0 or signature.len > signature_max_size or !bytes.nonzero(signature)) return error.BadArgument;

    var body_storage: [signature_fixed_body_size + signature_max_size]u8 = undefined;
    const body = try buildSignatureBody(subject_canonical, challenge_canonical, signer_id, algorithm, signature, &body_storage);
    const total = try canonicalSize(.receipt, body.len, 0, 0, 0);
    if (out.len < total) return error.NoSpace;

    return try (NodeWriter{ .out = out[0..total] }).receiptNode(signatureRequirements(), epoch, body);
}

pub fn decodeSignatureReceipt(canonical: []const u8) Error!SignatureInfo {
    const view = try View.decode(canonical);
    if (view.header.kind != .receipt or
        view.header.requirements.integrity != .signed or
        view.body.len < signature_fixed_body_size or
        view.body.len > signature_fixed_body_size + signature_max_size or
        !bytes.eql(view.body[0..signature_magic.len], signature_magic))
    {
        return error.Corrupt;
    }

    const algorithm = enumFromInt(Algorithm, bytes.load16(view.body[104..106]) orelse return error.Corrupt) orelse return error.Corrupt;
    const signature_len = bytes.load16(view.body[106..108]) orelse return error.Corrupt;
    if (algorithm == .none or
        signature_len == 0 or
        signature_len > signature_max_size or
        view.body.len != signature_fixed_body_size + @as(usize, signature_len) or
        (bytes.load32(view.body[108..112]) orelse return error.Corrupt) != 0)
    {
        return error.Corrupt;
    }

    const info = SignatureInfo{
        .signer_id = idFromBytes(view.body[8..40]),
        .challenge_id = idFromBytes(view.body[40..72]),
        .subject_id = idFromBytes(view.body[72..104]),
        .algorithm = algorithm,
        .signature = view.body[112..][0..signature_len],
    };
    if (!info.valid()) return error.Corrupt;
    return info;
}

fn buildSignatureBody(subject_canonical: []const u8, challenge_canonical: []const u8, signer_id: [id_size]u8, algorithm: Algorithm, signature_bytes: []const u8, scratch: []u8) Error![]const u8 {
    const subject = try View.decode(subject_canonical);
    const challenge = try View.decode(challenge_canonical);
    const body_len = signature_fixed_body_size + signature_bytes.len;
    if (scratch.len < body_len) return error.NoSpace;
    if (!writeSignatureBody(scratch[0..body_len], subject.id(), challenge.id(), signer_id, algorithm, signature_bytes)) return error.BadArgument;
    return scratch[0..body_len];
}

fn writeSignatureBody(body: []u8, subject_id: [id_size]u8, challenge_id: [id_size]u8, signer_id: [id_size]u8, algorithm: Algorithm, signature_bytes: []const u8) bool {
    if (body.len != signature_fixed_body_size + signature_bytes.len or
        signature_bytes.len == 0 or
        signature_bytes.len > signature_max_size or
        algorithm == .none or
        !bytes.nonzero(&subject_id) or
        !bytes.nonzero(&challenge_id) or
        !bytes.nonzero(&signer_id) or
        !bytes.nonzero(signature_bytes))
    {
        return false;
    }
    @memset(body, 0);
    @memcpy(body[0..signature_magic.len], signature_magic);
    @memcpy(body[8..40], &signer_id);
    @memcpy(body[40..72], &challenge_id);
    @memcpy(body[72..104], &subject_id);
    _ = bytes.store16(body[104..106], @intFromEnum(algorithm));
    _ = bytes.store16(body[106..108], @intCast(signature_bytes.len));
    @memcpy(body[112..][0..signature_bytes.len], signature_bytes);
    return true;
}

const WriteSpec = struct {
    kind: Kind,
    logical_len: u64,
    owners: []const Owner,
    envelopes: []const Envelope,
    children: []const Child,
    body: []const u8,
    epoch: clock.Stamp,
    requirements: Requirements,
};

fn validOwners(owners: []const Owner) bool {
    for (owners) |owner| {
        if (!owner.valid()) return false;
    }
    return true;
}

fn validEnvelopes(owners: []const Owner, envelopes: []const Envelope) bool {
    for (envelopes) |envelope| {
        if (envelope.owner_index >= owners.len) return false;
        if (!envelope.valid(owners[envelope.owner_index])) return false;
    }
    return true;
}

fn envelopeOwnerMatches(envelope_kind: EnvelopeKind, owner_kind: OwnerKind) bool {
    return switch (envelope_kind) {
        .none, .signature => true,
        .device => owner_kind == .device,
        .storage => owner_kind == .storage,
        .app => owner_kind == .app,
        .user => owner_kind == .user,
    };
}

fn envelopeAlgorithmMatches(envelope_kind: EnvelopeKind, algorithm: Algorithm) bool {
    return switch (envelope_kind) {
        .none => algorithm == .none,
        .signature => algorithm == .ed25519,
        .device, .storage, .app, .user => algorithm == .aes_gcm_256 or algorithm == .xchacha20_poly1305,
    };
}

fn encodeEpoch(epoch: clock.Stamp, out: []u8) void {
    _ = preimage.encodeEpoch(epoch, out);
}

fn decodeEpoch(in: []const u8) Error!clock.Stamp {
    if (in.len < 64) return error.Corrupt;
    var keeper_bytes: [clock.keeper_id_size]u8 = undefined;
    _ = bytes.copy(&keeper_bytes, in[0..32]);

    const stamp = clock.Stamp{
        .keeper = .{ .bytes = keeper_bytes },
        .tick = bytes.load64(in[32..40]) orelse return error.Corrupt,
        .slot = bytes.load64(in[40..48]) orelse return error.Corrupt,
        .epoch = bytes.load64(in[48..56]) orelse return error.Corrupt,
        .era = bytes.load64(in[56..64]) orelse return error.Corrupt,
    };
    if (!stamp.valid()) return error.Corrupt;
    return stamp;
}

fn enumFromInt(comptime E: type, value: anytype) ?E {
    inline for (std.enums.values(E)) |candidate| {
        if (@intFromEnum(candidate) == value) return candidate;
    }
    return null;
}

fn idFromBytes(in: []const u8) [id_size]u8 {
    var out: [id_size]u8 = undefined;
    _ = bytes.copy(&out, in[0..id_size]);
    return out;
}

fn zeroed(in: []const u8) bool {
    return !bytes.nonzero(in);
}

test "requirements are encoded and hashed deterministically" {
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .user_app_private,
        .portability = .machine_bound,
        .integrity = .sealed,
        .lifetime = .retained,
        .visibility = .private,
        .access = .explicit_io,
    };

    try std.testing.expect(bytes.nonzero(&req.hash()));
}

test "requirements derive explicit seal policy" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?;
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("chat")).?, epoch).?;
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .user_app_private,
        .portability = .machine_bound,
        .integrity = .sealed,
        .lifetime = .retained,
        .visibility = .private,
        .access = .explicit_io,
    };
    const policy = req.sealPolicy(device, app, user).?;

    try std.testing.expect(policy.valid());
    try std.testing.expectEqual(seal.Scope.machine_app_user, policy.scope);
}

test "header encode decode owns canonical layout" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };
    const header = Header{
        .kind = .bytes,
        .logical_len = 5,
        .body_len = 5,
        .epoch = .{ .keeper = keeper },
        .requirements = req,
    };

    var raw: [header_size]u8 = undefined;
    try header.encode(&raw);

    const decoded = try Header.decode(&raw);
    try std.testing.expectEqual(Kind.bytes, decoded.kind);
    try std.testing.expectEqual(@as(u64, 5), decoded.body_len);
    try std.testing.expectEqual(Integrity.hash_only, decoded.requirements.integrity);
}

test "owner and child encode decode are symmetric" {
    const node_id = [_]u8{2} ++ [_]u8{0} ** 31;
    const requirement_id = [_]u8{3} ++ [_]u8{0} ** 31;
    const owner = Owner{ .kind = .app, .node_id = node_id };
    const child = Child{
        .object_id = node_id,
        .logical_offset = 0,
        .logical_len = 10,
        .kind = .bytes,
        .requirements_hash = requirement_id,
    };

    var owner_raw: [owner_size]u8 = undefined;
    var child_raw: [child_size]u8 = undefined;
    try std.testing.expect(owner.encode(&owner_raw));
    try std.testing.expect(child.encode(&child_raw));

    const decoded_owner = try Owner.decode(&owner_raw);
    const decoded_child = try Child.decode(&child_raw, 0);
    try std.testing.expectEqual(OwnerKind.app, decoded_owner.kind);
    try std.testing.expectEqual(@as(u64, 10), decoded_child.logical_len);
}

test "envelope encode decode validates owner and algorithm" {
    const owner = Owner{
        .kind = .app,
        .node_id = [_]u8{4} ++ [_]u8{0} ** 31,
    };
    const envelope = Envelope{
        .kind = .app,
        .owner_index = 0,
        .algorithm = .aes_gcm_256,
        .flags = 7,
        .key_id = [_]u8{5} ++ [_]u8{0} ** 31,
        .metadata_hash = [_]u8{6} ++ [_]u8{0} ** 31,
    };

    var raw: [envelope_size]u8 = undefined;
    try std.testing.expect(envelope.encode(owner, &raw));

    const decoded = try Envelope.decode(&raw);
    try std.testing.expect(decoded.valid(owner));
    try std.testing.expectEqual(EnvelopeKind.app, decoded.kind);
    try std.testing.expectEqual(Algorithm.aes_gcm_256, decoded.algorithm);

    const wrong_owner = Owner{
        .kind = .user,
        .node_id = [_]u8{7} ++ [_]u8{0} ** 31,
    };
    try std.testing.expect(!envelope.encode(wrong_owner, &raw));
}

test "view decodes canonical bytes node and owns body slicing" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const req = Requirements{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .public,
        .access = .hot_memory_allowed,
    };

    var raw: [header_size + 5]u8 = undefined;
    const writer = NodeWriter{ .out = &raw };
    const canonical = try writer.bytesNode(req, .{ .keeper = keeper }, "hello");
    const view = try View.decode(canonical);

    try std.testing.expectEqual(Kind.bytes, view.header.kind);
    try std.testing.expectEqualStrings("hello", view.body);
    try std.testing.expect(bytes.nonzero(&view.id()));
}

test "writer builds owned canonical bytes nodes" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .app_private,
        .portability = .machine_bound,
        .integrity = .sealed,
        .lifetime = .retained,
        .visibility = .private,
        .access = .explicit_io,
    };
    const owner = Owner{
        .kind = .app,
        .node_id = [_]u8{8} ++ [_]u8{0} ** 31,
    };
    const envelope = Envelope{
        .kind = .app,
        .owner_index = 0,
        .algorithm = .xchacha20_poly1305,
        .flags = 0,
        .key_id = [_]u8{9} ++ [_]u8{0} ** 31,
        .metadata_hash = [_]u8{10} ++ [_]u8{0} ** 31,
    };

    var raw: [header_size + owner_size + envelope_size + 7]u8 = undefined;
    const writer = NodeWriter{ .out = &raw };
    const canonical = try writer.bytesNodeOwned(req, .{ .keeper = keeper }, &.{owner}, &.{envelope}, "payload");
    const view = try View.decode(canonical);

    try std.testing.expectEqual(Kind.bytes, view.header.kind);
    try std.testing.expectEqual(@as(u16, 1), view.header.owner_count);
    try std.testing.expectEqual(@as(u16, 1), view.header.envelope_count);
    try std.testing.expectEqualStrings("payload", view.body);
    try std.testing.expectEqual(OwnerKind.app, (try view.ownerAt(0)).kind);
    try std.testing.expectEqual(Algorithm.xchacha20_poly1305, (try view.envelopeAt(0)).algorithm);

    const bad_envelope = Envelope{
        .kind = .user,
        .owner_index = 0,
        .algorithm = .xchacha20_poly1305,
        .flags = 0,
        .key_id = [_]u8{11} ++ [_]u8{0} ** 31,
        .metadata_hash = [_]u8{12} ++ [_]u8{0} ** 31,
    };
    try std.testing.expectError(error.BadArgument, writer.bytesNodeOwned(req, .{ .keeper = keeper }, &.{owner}, &.{bad_envelope}, "payload"));
}

test "writer builds canonical tree nodes from child records" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const req = Requirements{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .public,
        .access = .hot_memory_allowed,
    };
    const epoch = clock.Stamp{ .keeper = keeper };

    var first_raw: [header_size + 5]u8 = undefined;
    var second_raw: [header_size + 6]u8 = undefined;
    const first_writer = NodeWriter{ .out = &first_raw };
    const second_writer = NodeWriter{ .out = &second_raw };
    const first = try first_writer.bytesNode(req, epoch, "first");
    const second = try second_writer.bytesNode(req, epoch, "second");

    const children = [_]Child{
        .{
            .object_id = Header.id(first),
            .logical_offset = 0,
            .logical_len = 5,
            .kind = .bytes,
            .requirements_hash = req.hash(),
        },
        .{
            .object_id = Header.id(second),
            .logical_offset = 5,
            .logical_len = 6,
            .kind = .bytes,
            .requirements_hash = req.hash(),
        },
    };

    var tree_raw: [header_size + child_size * 2]u8 = undefined;
    const tree_writer = NodeWriter{ .out = &tree_raw };
    const canonical = try tree_writer.treeNode(req, epoch, &children);
    const view = try View.decode(canonical);

    try std.testing.expectEqual(Kind.tree, view.header.kind);
    try std.testing.expectEqual(@as(u64, 11), view.header.logical_len);
    try std.testing.expectEqual(@as(u32, 2), view.header.child_count);
    try std.testing.expectEqual(@as(usize, 0), view.body.len);
    try std.testing.expectEqual(@as(u64, 0), (try view.childAt(0)).logical_offset);
    try std.testing.expectEqual(@as(u64, 5), (try view.childAt(1)).logical_offset);
}

test "writer builds owned canonical tree nodes" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .app_private,
        .portability = .machine_bound,
        .integrity = .sealed,
        .lifetime = .retained,
        .visibility = .private,
        .access = .explicit_io,
    };
    const epoch = clock.Stamp{ .keeper = keeper };
    const owner = Owner{
        .kind = .app,
        .node_id = [_]u8{13} ++ [_]u8{0} ** 31,
    };
    const envelope = Envelope{
        .kind = .app,
        .owner_index = 0,
        .algorithm = .aes_gcm_256,
        .flags = 0,
        .key_id = [_]u8{14} ++ [_]u8{0} ** 31,
        .metadata_hash = [_]u8{15} ++ [_]u8{0} ** 31,
    };
    const child = Child{
        .object_id = [_]u8{16} ++ [_]u8{0} ** 31,
        .logical_offset = 0,
        .logical_len = 32,
        .kind = .bytes,
        .requirements_hash = req.hash(),
    };

    var raw: [header_size + owner_size + envelope_size + child_size]u8 = undefined;
    const writer = NodeWriter{ .out = &raw };
    const canonical = try writer.treeNodeOwned(req, epoch, &.{owner}, &.{envelope}, &.{child});
    const view = try View.decode(canonical);

    try std.testing.expectEqual(Kind.tree, view.header.kind);
    try std.testing.expectEqual(@as(u64, 32), view.header.logical_len);
    try std.testing.expectEqual(@as(u16, 1), view.header.owner_count);
    try std.testing.expectEqual(@as(u16, 1), view.header.envelope_count);
    try std.testing.expectEqual(@as(u32, 1), view.header.child_count);
    try std.testing.expectEqual(OwnerKind.app, (try view.ownerAt(0)).kind);
    try std.testing.expectEqual(EnvelopeKind.app, (try view.envelopeAt(0)).kind);
    try std.testing.expectEqual(@as(u64, 32), (try view.childAt(0)).logical_len);
}

test "writer builds canonical receipt nodes" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .integrity_only,
        .portability = .public_portable,
        .integrity = .signed,
        .lifetime = .retained,
        .visibility = .app_namespace,
        .access = .explicit_io,
    };

    var raw: [header_size + 7]u8 = undefined;
    const writer = NodeWriter{ .out = &raw };
    const canonical = try writer.receiptNode(req, .{ .keeper = keeper }, "receipt");
    const view = try View.decode(canonical);

    try std.testing.expectEqual(Kind.receipt, view.header.kind);
    try std.testing.expectEqualStrings("receipt", view.body);
    try std.testing.expectEqual(@as(u32, 0), view.header.child_count);
}

test "signature receipts bind signer challenge and subject object ids" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };

    var subject_raw: [header_size + 7]u8 = undefined;
    var challenge_raw: [header_size + 9]u8 = undefined;
    const subject = try (NodeWriter{ .out = &subject_raw }).bytesNode(req, epoch, "subject");
    const challenge = try (NodeWriter{ .out = &challenge_raw }).bytesNode(req, epoch, "challenge");

    const signer_id = [_]u8{22} ++ [_]u8{0} ** 31;
    const signature = [_]u8{0xa5} ** 64;
    var receipt_raw: [header_size + signature_fixed_body_size + signature.len]u8 = undefined;
    const receipt = try (NodeWriter{ .out = &receipt_raw }).signatureReceiptNode(subject, challenge, signer_id, .ecdsa_p256_sha256, &signature, epoch);
    const info = try decodeSignatureReceipt(receipt);

    try std.testing.expectEqualSlices(u8, &signer_id, &info.signer_id);
    try std.testing.expectEqualSlices(u8, &Header.id(challenge), &info.challenge_id);
    try std.testing.expectEqualSlices(u8, &Header.id(subject), &info.subject_id);
    try std.testing.expectEqual(Algorithm.ecdsa_p256_sha256, info.algorithm);
    try std.testing.expectEqualSlices(u8, &signature, info.signature);
}

test "signature receipts reject malformed body policy and zero signatures" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const req = Requirements{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };

    var subject_raw: [header_size + 7]u8 = undefined;
    var challenge_raw: [header_size + 9]u8 = undefined;
    const subject = try (NodeWriter{ .out = &subject_raw }).bytesNode(req, epoch, "subject");
    const challenge = try (NodeWriter{ .out = &challenge_raw }).bytesNode(req, epoch, "challenge");

    const signer_id = [_]u8{23} ++ [_]u8{0} ** 31;
    const zero_signature = [_]u8{0} ** 64;
    var receipt_raw: [header_size + signature_fixed_body_size + 64]u8 = undefined;
    try std.testing.expectError(error.BadArgument, writeSignatureReceipt(subject, challenge, signer_id, .ed25519, &zero_signature, epoch, &receipt_raw));

    const signature = [_]u8{0x5a} ** 64;
    const receipt = try writeSignatureReceipt(subject, challenge, signer_id, .ed25519, &signature, epoch, &receipt_raw);
    receipt[header_size + 108] = 1;
    try std.testing.expectError(error.Corrupt, decodeSignatureReceipt(receipt));
}
