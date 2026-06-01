const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;

pub const Action = enum(u16) {
    spawn_app = 1,
    grant_resource = 2,
    seal_data = 3,
    unseal_data = 4,
    sync_data = 5,
    emit_ui_event = 6,
    sign_data = 7,
    random_bytes = 8,
};

pub const Consequence = enum(u16) {
    reads_private_state = 1,
    writes_private_state = 2,
    delegates_resources = 3,
    exports_data = 4,
    attests_state = 5,
    creates_secret_material = 6,
};

pub const Intent = struct {
    user: identity.Id,
    device: identity.Id,
    actor: identity.Id,
    subject: identity.Id,
    action: Action,
    consequence: Consequence,
    epoch: clock.Stamp,
    request: [id_size]u8,

    pub fn valid(self: Intent) bool {
        return self.user.valid() and
            self.device.valid() and
            self.actor.valid() and
            self.subject.valid() and
            self.epoch.valid() and
            bytes.nonzero(&self.request);
    }

    pub fn id(self: Intent) ?[id_size]u8 {
        if (!self.valid()) return null;

        var raw: [228]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.id(self.user) or
            !writer.id(self.device) or
            !writer.id(self.actor) or
            !writer.id(self.subject) or
            !writer.writeU16(@intFromEnum(self.action)) or
            !writer.writeU16(@intFromEnum(self.consequence)) or
            !writer.epoch(self.epoch) or
            !writer.hash(self.request))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:intent", writer.written());
    }
};

pub const Receipt = struct {
    intent: Intent,
    admitted_by: identity.Id,
    not_before: clock.Stamp,
    not_after: clock.Stamp,

    pub fn valid(self: Receipt) bool {
        return self.intent.valid() and
            self.admitted_by.valid() and
            self.not_before.valid() and
            self.not_after.valid() and
            self.not_before.sameKeeper(self.not_after) and
            self.not_before.order(self.not_after) <= 0;
    }

    pub fn permits(self: Receipt, actor: identity.Id, subject: identity.Id, action: Action, consequence: Consequence) bool {
        return self.permitsAt(self.intent.epoch, actor, subject, action, consequence);
    }

    pub fn permitsAt(self: Receipt, now: clock.Stamp, actor: identity.Id, subject: identity.Id, action: Action, consequence: Consequence) bool {
        return self.valid() and
            now.sameKeeper(self.not_before) and
            self.not_before.order(now) <= 0 and
            now.order(self.not_after) <= 0 and
            self.intent.actor.eql(actor) and
            self.intent.subject.eql(subject) and
            self.intent.action == action and
            self.intent.consequence == consequence;
    }

    pub fn id(self: Receipt) ?[id_size]u8 {
        if (!self.valid()) return null;

        const intent_id = self.intent.id().?;
        var raw: [192]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.hash(intent_id) or
            !writer.id(self.admitted_by) or
            !writer.epoch(self.not_before) or
            !writer.epoch(self.not_after))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:intent-receipt", writer.written());
    }
};

pub fn requestId(material: []const u8) ?[id_size]u8 {
    if (material.len == 0 or !bytes.nonzero(material)) return null;
    return preimage.hash("edgerun:zig:v1:intent-request", material);
}

pub fn admit(user: identity.Identity, device: identity.Identity, actor: identity.Identity, subject: identity.Identity, action: Action, consequence: Consequence, epoch: clock.Stamp, request: [id_size]u8) ?Receipt {
    return admitWindow(user, device, actor, subject, action, consequence, epoch, epoch, epoch, request);
}

pub fn admitWindow(user: identity.Identity, device: identity.Identity, actor: identity.Identity, subject: identity.Identity, action: Action, consequence: Consequence, epoch: clock.Stamp, not_before: clock.Stamp, not_after: clock.Stamp, request: [id_size]u8) ?Receipt {
    const intent = Intent{
        .user = user.id,
        .device = device.id,
        .actor = actor.id,
        .subject = subject.id,
        .action = action,
        .consequence = consequence,
        .epoch = epoch,
        .request = request,
    };
    if (!intent.valid()) return null;
    const receipt = Receipt{
        .intent = intent,
        .admitted_by = device.id,
        .not_before = not_before,
        .not_after = not_after,
    };
    if (!receipt.valid()) return null;
    return receipt;
}

const TestIdentities = struct {
    user: identity.Identity,
    device: identity.Identity,
    parent: identity.Identity,
    child: identity.Identity,
};

fn testIdentities(epoch: clock.Stamp) TestIdentities {
    return .{
        .user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?,
        .device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?,
        .parent = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("parent")).?, epoch).?,
        .child = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("child")).?, epoch).?,
    };
}

test "intent receipt binds user device actor subject and consequence" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const ids = testIdentities(epoch);

    const receipt = admit(ids.user, ids.device, ids.parent, ids.child, .spawn_app, .delegates_resources, epoch, requestId("spawn preview").?).?;

    if (!receipt.valid()) return error.TestExpectedTrue;
    if (!receipt.permits(ids.parent.id, ids.child.id, .spawn_app, .delegates_resources)) return error.TestExpectedTrue;
    if (receipt.permits(ids.child.id, ids.parent.id, .spawn_app, .delegates_resources)) return error.TestExpectedFalse;
    if (!bytes.nonzero(&receipt.id().?)) return error.TestExpectedTrue;
}

test "intent receipt rejects replay outside admission window" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const ids = testIdentities(.{ .keeper = keeper });
    const start = clock.Stamp{ .keeper = keeper, .tick = 10 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 20 };
    const receipt = admitWindow(ids.user, ids.device, ids.parent, ids.child, .spawn_app, .delegates_resources, start, start, end, requestId("spawn window").?).?;

    if (!receipt.permitsAt(.{ .keeper = keeper, .tick = 15 }, ids.parent.id, ids.child.id, .spawn_app, .delegates_resources)) return error.TestExpectedTrue;
    if (receipt.permitsAt(.{ .keeper = keeper, .tick = 21 }, ids.parent.id, ids.child.id, .spawn_app, .delegates_resources)) return error.TestExpectedFalse;
}
