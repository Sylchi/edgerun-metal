const std = @import("std");
const authority = @import("authority.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");
const seal = @import("seal.zig");

pub const id_size = preimage.hash_size;

pub const Transfer = struct {
    user: authority.Principal,
    app: authority.Principal,
    source_device: authority.Principal,
    target_device: authority.Principal,
    object_id: preimage.Hash,
    from_policy: seal.Policy,
    transfer_policy: seal.Policy,
    to_policy: seal.Policy,
    authorization: intent.Receipt,
    chain_id: preimage.Hash,
    epoch: clock.Stamp,

    pub fn valid(self: Transfer) bool {
        return self.user.valid() and
            self.app.valid() and
            self.source_device.valid() and
            self.target_device.valid() and
            self.user.kind == .user and
            self.app.kind == .app and
            self.source_device.kind == .device and
            self.target_device.kind == .device and
            !self.source_device.eql(self.target_device) and
            bytes.nonzero(&self.object_id) and
            self.from_policy.valid() and
            self.transfer_policy.valid() and
            self.to_policy.valid() and
            authority.receiptPermits(self.authorization, self.epoch, self.app, self.target_device, .sync_data, .exports_data) and
            bytes.nonzero(&self.chain_id) and
            self.epoch.valid() and
            policyMatches(self.from_policy, .machine_app_user, self.source_device.id, self.app.id, self.user.id) and
            policyMatches(self.transfer_policy, .sync_transfer, self.source_device.id, self.app.id, self.user.id) and
            policyMatches(self.to_policy, .machine_app_user, self.target_device.id, self.app.id, self.user.id);
    }

    pub fn id(self: Transfer) ?preimage.Hash {
        if (!self.valid()) return null;

        var from_raw: [seal.encoded_size]u8 = undefined;
        var transfer_raw: [seal.encoded_size]u8 = undefined;
        var to_raw: [seal.encoded_size]u8 = undefined;
        _ = self.from_policy.encode(&from_raw);
        _ = self.transfer_policy.encode(&transfer_raw);
        _ = self.to_policy.encode(&to_raw);
        const authorization_id = self.authorization.id().?;

        var epoch_raw: [64]u8 = undefined;
        var writer = preimage.Writer.init(&epoch_raw);
        if (!writer.epoch(self.epoch)) return null;

        var builder = preimage.Builder.init("edgerun:zig:v1:sync-transfer");
        if (!appendPrincipal(&builder, self.user) or
            !appendPrincipal(&builder, self.app) or
            !appendPrincipal(&builder, self.source_device) or
            !appendPrincipal(&builder, self.target_device))
        {
            return null;
        }
        builder.hash(self.object_id);
        builder.bytes(&from_raw);
        builder.bytes(&transfer_raw);
        builder.bytes(&to_raw);
        builder.hash(authorization_id);
        builder.hash(self.chain_id);
        builder.bytes(writer.written());
        return builder.final();
    }
};

pub fn prepare(user: identity.Identity, app: identity.Identity, source_device: identity.Identity, target_device: identity.Identity, object_id: preimage.Hash, authorization: intent.Receipt, chain: authority.Chain, epoch: clock.Stamp) ?Transfer {
    const chain_id = chain.id() orelse return null;
    const transfer = Transfer{
        .user = authority.Principal.user(user) orelse return null,
        .app = authority.Principal.app(app) orelse return null,
        .source_device = authority.Principal.device(source_device) orelse return null,
        .target_device = authority.Principal.device(target_device) orelse return null,
        .object_id = object_id,
        .from_policy = seal.Policy.machineAppUser(source_device, app, user),
        .transfer_policy = seal.Policy.syncTransfer(source_device, app, user),
        .to_policy = seal.Policy.machineAppUser(target_device, app, user),
        .authorization = authorization,
        .chain_id = chain_id,
        .epoch = epoch,
    };
    if (!transfer.valid()) return null;
    return transfer;
}

fn appendPrincipal(builder: *preimage.Builder, principal: authority.Principal) bool {
    var raw: [authority.principal_encoded_size]u8 = undefined;
    if (!principal.encode(&raw)) return false;
    builder.bytes(&raw);
    return true;
}

fn policyMatches(policy: seal.Policy, scope: seal.Scope, device: identity.Id, app: identity.Id, user: identity.Id) bool {
    return policy.scope == scope and
        policy.device != null and policy.device.?.eql(device) and
        policy.app != null and policy.app.?.eql(app) and
        policy.user != null and policy.user.?.eql(user);
}

test "sync transfer reseals from source machine to target machine" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const source = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("source device")).?, epoch).?;
    const target = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("target device")).?, epoch).?;
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("chat")).?, epoch).?;
    const object_id = [_]u8{9} ++ [_]u8{0} ** 31;
    const authorization = intent.admit(user, source, app, target, .sync_data, .exports_data, epoch, intent.requestId("sync messages").?).?;
    var chain = authority.Chain.initUser(user).?;
    try std.testing.expect(chain.appendIdentityIntent(app, .delegated_to_app, authorization));

    const transfer = prepare(user, app, source, target, object_id, authorization, chain, epoch).?;
    try std.testing.expect(transfer.valid());
    try std.testing.expect(transfer.user.eql(authority.Principal.user(user).?));
    try std.testing.expect(transfer.app.eql(authority.Principal.app(app).?));
    try std.testing.expect(transfer.target_device.eql(authority.Principal.device(target).?));
    try std.testing.expectEqual(seal.Scope.sync_transfer, transfer.transfer_policy.scope);
    try std.testing.expect(bytes.nonzero(&transfer.id().?));
}
