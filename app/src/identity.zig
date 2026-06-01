const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const crypto = @import("crypto.zig");

pub const id_size = 32;
pub const hash_size = 32;
pub const material_max = 96;
pub const ed25519_public_size = 32;
pub const p256_public_size = 64;
pub const endpoint_min_size = 1;
pub const delegation_material_size = 96;

pub const InstantiationOperation = enum(u32) {
    verify = 1,
    sign = 2,
    verify_and_sign = 3,
};

pub const Kind = enum(u16) {
    user = 1,
    device = 2,
    app = 3,
    storage = 4,
    relay = 5,
    resource = 6,
    object = 7,
    ephemeral = 8,
    delegated = 9,
};

pub const SourceKind = enum(u16) {
    hash = 1,
    ed25519_public = 2,
    p256_public = 3,
    tpm_p256_public = 4,
    object_id = 5,
    endpoint = 6,
    derived = 7,
    delegation = 8,
    android_keystone_p256_public = 9,
};

pub const Id = struct {
    bytes: [id_size]u8,

    pub fn valid(self: Id) bool {
        return bytes.nonzero(&self.bytes);
    }

    pub fn eql(self: Id, other: Id) bool {
        return bytes.eql(&self.bytes, &other.bytes);
    }
};

pub const Source = struct {
    kind: SourceKind,
    material: [material_max]u8 = [_]u8{0} ** material_max,
    len: usize,

    pub fn init(kind: SourceKind, material: []const u8) ?Source {
        if (material.len == 0 or material.len > material_max) return null;
        if (!bytes.nonzero(material)) return null;

        var source = Source{ .kind = kind, .len = material.len };
        _ = bytes.copy(source.material[0..], material);
        return source;
    }

    pub fn prepare(kind: SourceKind, material: []const u8) ?Source {
        if (!materialLenValid(kind, material.len)) return null;
        return init(kind, material);
    }

    pub fn prepareDelegation(parent: Id, delegate: Id, scope_hash: [hash_size]u8) ?Source {
        if (!parent.valid() or !delegate.valid() or !bytes.nonzero(&scope_hash)) return null;

        var material: [delegation_material_size]u8 = undefined;
        @memcpy(material[0..32], &parent.bytes);
        @memcpy(material[32..64], &delegate.bytes);
        @memcpy(material[64..96], &scope_hash);
        return prepare(.delegation, &material);
    }

    pub fn active(self: *const Source) []const u8 {
        return self.material[0..self.len];
    }

    pub fn id(self: *const Source) Id {
        if (self.kind == .ed25519_public) return .{ .bytes = self.material[0..id_size].* };

        var hasher = crypto.blake3.init(.{});
        var header: [4]u8 = undefined;
        _ = bytes.store16(header[0..2], @intFromEnum(self.kind));
        _ = bytes.store16(header[2..4], @intCast(self.len));
        hasher.update("edgerun:zig:v1:identity-id");
        hasher.update(&header);
        hasher.update(self.active());

        var out: [id_size]u8 = undefined;
        hasher.final(&out);
        return .{ .bytes = out };
    }

    pub fn valid(self: *const Source) bool {
        return materialLenValid(self.kind, self.len) and bytes.nonzero(self.active());
    }
};

pub const Identity = struct {
    kind: Kind,
    epoch: clock.Stamp,
    id: Id,
    source: Source,

    pub fn init(kind: Kind, source: Source, epoch: clock.Stamp) ?Identity {
        if (!source.valid() or !epoch.valid()) return null;
        return .{
            .kind = kind,
            .epoch = epoch,
            .id = source.id(),
            .source = source,
        };
    }

    pub fn instantiate(value: Instantiation) ?Identity {
        if (value.source_kind == .delegation or value.source_kind == .derived) return null;
        const source = Source.prepare(value.source_kind, value.material) orelse return null;
        return init(value.kind, source, value.epoch);
    }

    pub fn instantiateApp(value: AppInstantiation) ?Identity {
        if (!value.parent.valid() or
            value.app_material.len == 0 or
            value.scope_hash.len != hash_size or
            !bytes.nonzero(value.scope_hash) or
            !value.epoch.valid())
        {
            return null;
        }

        const app_source = Source.prepare(.hash, value.app_material) orelse return null;
        const app_anchor = init(.app, app_source, value.epoch) orelse return null;
        var operation_bytes: [4]u8 = undefined;
        _ = bytes.store32(&operation_bytes, @intFromEnum(value.required_parent_operations));
        var scope_hasher = crypto.blake3.init(.{});
        scope_hasher.update("edgerun:zig:v1:identity-app-scope");
        scope_hasher.update(&operation_bytes);
        scope_hasher.update(value.scope_hash);
        var delegated_scope_hash: [hash_size]u8 = undefined;
        scope_hasher.final(&delegated_scope_hash);

        const delegation_source = Source.prepareDelegation(value.parent.id, app_anchor.id, delegated_scope_hash) orelse return null;
        return init(.delegated, delegation_source, value.epoch);
    }

    pub fn valid(self: Identity) bool {
        return self.epoch.valid() and self.id.valid() and self.source.valid() and self.id.eql(self.source.id());
    }

    pub fn eql(self: Identity, other: Identity) bool {
        return self.valid() and
            other.valid() and
            self.kind == other.kind and
            self.epoch.order(other.epoch) == 0 and
            self.source.kind == other.source.kind and
            self.source.len == other.source.len and
            self.id.eql(other.id) and
            bytes.eql(self.source.active(), other.source.active());
    }

    pub fn deriveChild(self: Identity, child_kind: Kind, epoch: clock.Stamp, label: []const u8, material: []const u8) ?Identity {
        if (!self.valid() or
            !epoch.valid() or
            label.len == 0 or
            material.len == 0 or
            !bytes.nonzero(label) or
            !bytes.nonzero(material))
        {
            return null;
        }

        var kind_bytes: [2]u8 = undefined;
        _ = bytes.store16(&kind_bytes, @intFromEnum(child_kind));
        var hasher = crypto.blake3.init(.{});
        hasher.update("edgerun:zig:v1:identity-child");
        hasher.update(&self.id.bytes);
        hasher.update(&kind_bytes);
        hasher.update(label);
        hasher.update(material);
        var child_material: [hash_size]u8 = undefined;
        hasher.final(&child_material);

        const source = Source.prepare(.derived, &child_material) orelse return null;
        return init(child_kind, source, epoch);
    }
};

pub const Instantiation = struct {
    kind: Kind,
    source_kind: SourceKind,
    material: []const u8,
    epoch: clock.Stamp,
};

pub const AppInstantiation = struct {
    parent: Identity,
    app_material: []const u8,
    scope_hash: []const u8,
    epoch: clock.Stamp,
    required_parent_operations: InstantiationOperation,
};

fn materialLenValid(kind: SourceKind, len: usize) bool {
    return switch (kind) {
        .hash, .object_id, .derived => len == hash_size,
        .ed25519_public => len == ed25519_public_size,
        .p256_public, .tpm_p256_public, .android_keystone_p256_public => len == p256_public_size,
        .endpoint => len >= endpoint_min_size and len <= material_max,
        .delegation => len == delegation_material_size,
    };
}

fn hashMaterial(material: []const u8) [hash_size]u8 {
    var out: [hash_size]u8 = undefined;
    crypto.blake3.hash(material, &out, .{});
    return out;
}

test "source is explicit material with deterministic id" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const source = Source.prepare(.hash, &hashMaterial("app manifest")).?;
    const a = Identity.init(.app, source, epoch).?;
    const b = Identity.init(.app, source, epoch).?;

    try expect(a.id.eql(b.id));
    try expect(Identity.init(.app, Source.init(.hash, "short").?, epoch) == null);
}

test "strict source preparation enforces C identity material sizes" {
    try expect(Source.prepare(.hash, "short") == null);
    const source = Source.prepare(.hash, &hashMaterial("manifest")).?;
    try expect(source.valid());
    try expect(Source.prepare(.p256_public, &([_]u8{1} ** 64)) != null);
}

test "ed25519 public source is the routable hidden service identity" {
    const public_key = [_]u8{7} ++ [_]u8{3} ** 31;
    const source = Source.prepare(.ed25519_public, &public_key).?;
    const id = source.id();

    try expect(bytes.eql(&public_key, &id.bytes));
}

test "identity derives child and delegated app identities" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const parent = Identity.instantiate(.{
        .kind = .user,
        .source_kind = .hash,
        .material = &hashMaterial("parent"),
        .epoch = epoch,
    }).?;

    const child = parent.deriveChild(.app, epoch, "chat", "manifest").?;
    try expect(child.valid());
    try expectEqual(Kind.app, child.kind);
    try expectEqual(SourceKind.derived, child.source.kind);

    const delegated = Identity.instantiateApp(.{
        .parent = parent,
        .app_material = &hashMaterial("delegated-app"),
        .scope_hash = &hashMaterial("scope"),
        .epoch = epoch,
        .required_parent_operations = .verify_and_sign,
    }).?;
    try expect(delegated.valid());
    try expectEqual(Kind.delegated, delegated.kind);
    try expectEqual(SourceKind.delegation, delegated.source.kind);

    try expect(Identity.instantiateApp(.{
        .parent = parent,
        .app_material = &hashMaterial("delegated-app"),
        .scope_hash = "short",
        .epoch = epoch,
        .required_parent_operations = .verify_and_sign,
    }) == null);
}

fn expect(condition: bool) !void {
    if (!condition) return error.TestExpectedTrue;
}

fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    if (actual != expected) return error.TestExpectedEqual;
}
