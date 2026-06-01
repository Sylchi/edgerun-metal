const bytes = @import("bytes.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;
pub const encoded_size = 116;

pub const Scope = enum(u16) {
    public = 1,
    integrity_only = 2,
    machine_app = 3,
    machine_app_user = 4,
    sync_transfer = 5,
};

pub const Algorithm = enum(u16) {
    none = 0,
    blake3 = 1,
    tpm_sealed_aes256 = 2,
    recipient_sealed_aes256 = 3,
};

pub const Policy = struct {
    scope: Scope,
    algorithm: Algorithm,
    device: ?identity.Id = null,
    app: ?identity.Id = null,
    user: ?identity.Id = null,
    flags: u32 = 0,

    pub fn public() Policy {
        return .{ .scope = .public, .algorithm = .none };
    }

    pub fn integrityOnly() Policy {
        return .{ .scope = .integrity_only, .algorithm = .blake3 };
    }

    pub fn machineApp(device: identity.Identity, app: identity.Identity) Policy {
        return machineAppIds(device.id, app.id);
    }

    pub fn machineAppIds(device: identity.Id, app: identity.Id) Policy {
        return .{
            .scope = .machine_app,
            .algorithm = .tpm_sealed_aes256,
            .device = device,
            .app = app,
        };
    }

    pub fn machineAppUser(device: identity.Identity, app: identity.Identity, user: identity.Identity) Policy {
        return machineAppUserIds(device.id, app.id, user.id);
    }

    pub fn machineAppUserIds(device: identity.Id, app: identity.Id, user: identity.Id) Policy {
        return .{
            .scope = .machine_app_user,
            .algorithm = .tpm_sealed_aes256,
            .device = device,
            .app = app,
            .user = user,
        };
    }

    pub fn syncTransfer(source_device: identity.Identity, app: identity.Identity, user: identity.Identity) Policy {
        return .{
            .scope = .sync_transfer,
            .algorithm = .recipient_sealed_aes256,
            .device = source_device.id,
            .app = app.id,
            .user = user.id,
        };
    }

    pub fn valid(self: Policy) bool {
        return switch (self.scope) {
            .public => self.algorithm == .none and self.device == null and self.app == null and self.user == null,
            .integrity_only => self.algorithm == .blake3 and self.device == null and self.app == null and self.user == null,
            .machine_app => self.algorithm == .tpm_sealed_aes256 and validId(self.device) and validId(self.app) and self.user == null,
            .machine_app_user => self.algorithm == .tpm_sealed_aes256 and validId(self.device) and validId(self.app) and validId(self.user),
            .sync_transfer => self.algorithm == .recipient_sealed_aes256 and validId(self.device) and validId(self.app) and validId(self.user),
        };
    }

    pub fn encode(self: Policy, out: []u8) bool {
        if (out.len < encoded_size or !self.valid()) return false;
        @memset(out[0..encoded_size], 0);
        _ = bytes.store16(out[0..2], @intFromEnum(self.scope));
        _ = bytes.store16(out[2..4], @intFromEnum(self.algorithm));
        _ = bytes.store32(out[4..8], self.flags);
        if (self.device) |device| _ = bytes.copy(out[8..40], &device.bytes);
        if (self.app) |app| _ = bytes.copy(out[40..72], &app.bytes);
        if (self.user) |user| _ = bytes.copy(out[72..104], &user.bytes);
        return true;
    }

    pub fn id(self: Policy) ?preimage.Hash {
        var raw: [encoded_size]u8 = undefined;
        if (!self.encode(&raw)) return null;
        return preimage.hash("edgerun:zig:v1:seal-policy", &raw);
    }
};

fn validId(id: ?identity.Id) bool {
    return if (id) |value| value.valid() else false;
}

test "seal policy captures machine app user binding" {
    const clock = @import("clock.zig");
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?;
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("chat")).?, epoch).?;

    const policy = Policy.machineAppUser(device, app, user);
    try expect(policy.valid());
    try expect(bytes.nonzero(&policy.id().?));
    try expect(Policy.public().valid());
    try expect(Policy.integrityOnly().valid());
}

fn expect(condition: bool) !void {
    if (!condition) return error.TestExpectedTrue;
}
