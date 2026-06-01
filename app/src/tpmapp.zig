const authority = @import("authority.zig");
const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");
const seal = @import("seal.zig");

pub const id_size = preimage.hash_size;
pub const EventLog = bounded.SliceList(Event);
const admission_capacity = 16;
const event_encoded_size = authority.u16_encoded_size + authority.principal_encoded_size + preimage.hash_size + preimage.hash_size + preimage.hash_size + preimage.hash_size + preimage.epoch_size;

pub const Error = error{
    BadApp,
    BadPolicy,
    BadRequest,
    NoEventSpace,
    NoAdmissionSpace,
    Unauthorized,
};

pub const EventKind = enum(u16) {
    seal = 1,
    unseal = 2,
    sign = 3,
    random = 4,
};

pub const Event = struct {
    kind: EventKind,
    caller: authority.Principal,
    policy_id: preimage.Hash,
    input_hash: preimage.Hash,
    output_hash: preimage.Hash,
    authorization_id: preimage.Hash,
    epoch: clock.Stamp,

    pub fn valid(self: Event) bool {
        return self.caller.valid() and
            bytes.nonzero(&self.policy_id) and
            bytes.nonzero(&self.input_hash) and
            bytes.nonzero(&self.output_hash) and
            bytes.nonzero(&self.authorization_id) and
            self.epoch.valid();
    }

    pub fn id(self: Event) ?preimage.Hash {
        if (!self.valid()) return null;

        var raw: [event_encoded_size]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.writeU16(@intFromEnum(self.kind)) or
            !writePrincipal(&writer, self.caller) or
            !writer.hash(self.policy_id) or
            !writer.hash(self.input_hash) or
            !writer.hash(self.output_hash) or
            !writer.hash(self.authorization_id) or
            !writer.epoch(self.epoch))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:tpmapp-event", writer.written());
    }
};

pub const Sealed = struct {
    policy: seal.Policy,
    plaintext_hash: preimage.Hash,
    ciphertext_hash: preimage.Hash,
    event_id: preimage.Hash,

    pub fn valid(self: Sealed) bool {
        return self.policy.valid() and
            bytes.nonzero(&self.plaintext_hash) and
            bytes.nonzero(&self.ciphertext_hash) and
            bytes.nonzero(&self.event_id);
    }
};

pub const Signature = struct {
    signer: authority.Principal,
    subject_hash: preimage.Hash,
    signature_hash: preimage.Hash,
    event_id: preimage.Hash,

    pub fn valid(self: Signature) bool {
        return self.signer.valid() and
            bytes.nonzero(&self.subject_hash) and
            bytes.nonzero(&self.signature_hash) and
            bytes.nonzero(&self.event_id);
    }
};

pub const Random = struct {
    caller: authority.Principal,
    len: usize,
    request_hash: preimage.Hash,
    output_hash: preimage.Hash,
    event_id: preimage.Hash,

    pub fn valid(self: Random) bool {
        return self.caller.valid() and
            self.len != 0 and
            bytes.nonzero(&self.request_hash) and
            bytes.nonzero(&self.output_hash) and
            bytes.nonzero(&self.event_id);
    }
};

pub const App = struct {
    id: identity.Identity,
    device: identity.Identity,
    clock: clock.Clock,
    events: EventLog,
    admissions: Admissions = .{},

    const AdmissionRecord = struct {
        receipt: preimage.Hash,
        actor: authority.Principal,
        subject: authority.Principal,
        action: intent.Action,
        consequence: intent.Consequence,
        not_after: clock.Stamp,

        fn valid(self: AdmissionRecord) bool {
            return bytes.nonzero(&self.receipt) and
                self.actor.valid() and
                self.subject.valid() and
                self.not_after.valid();
        }

        fn matches(self: AdmissionRecord, authorization: intent.Receipt, epoch: clock.Stamp, actor: authority.Principal, subject: authority.Principal, action: intent.Action, consequence: intent.Consequence) bool {
            const receipt_id = authorization.id() orelse return false;
            return self.valid() and
                bytes.eql(&self.receipt, &receipt_id) and
                self.actor.eql(actor) and
                self.subject.eql(subject) and
                self.action == action and
                self.consequence == consequence and
                epoch.sameKeeper(self.not_after) and
                epoch.order(self.not_after) <= 0;
        }
    };

    const Admissions = bounded.FixedList(AdmissionRecord, admission_capacity);

    const AdmissionCapability = struct {
        tpm: authority.Principal,
        actor: authority.Principal,
        receipt: preimage.Hash,

        fn permits(self: AdmissionCapability, tpm: authority.Principal, authorization: intent.Receipt) bool {
            const receipt_id = authorization.id() orelse return false;
            return self.tpm.eql(tpm) and
                bytes.eql(&self.receipt, &receipt_id) and
                authority.receiptPermits(authorization, authorization.intent.epoch, self.actor, self.tpm, authorization.intent.action, authorization.intent.consequence);
        }
    };

    pub fn init(id: identity.Identity, device: identity.Identity, local_clock: clock.Clock, events: []Event) ?App {
        if (authority.Principal.tpm(id) == null or authority.Principal.device(device) == null) return null;
        return .{
            .id = id,
            .device = device,
            .clock = local_clock,
            .events = EventLog.init(events) orelse return null,
        };
    }

    fn admissionCapability(self: App, authorization: intent.Receipt, actor: identity.Identity) ?AdmissionCapability {
        if (!authorization.valid()) return null;
        const tpm_principal = self.principal() orelse return null;
        const actor_principal = authority.dataActor(actor) orelse return null;
        return .{
            .tpm = tpm_principal,
            .actor = actor_principal,
            .receipt = authorization.id() orelse return null,
        };
    }

    fn admitAuthorization(self: *App, authorization: intent.Receipt, capability: AdmissionCapability) Error!void {
        if (!authorization.valid() or !capability.permits(self.principal() orelse return error.Unauthorized, authorization)) return error.Unauthorized;
        const receipt_id = authorization.id() orelse return error.Unauthorized;
        for (self.admissions.slice()) |admission| {
            if (!admission.valid()) return error.Unauthorized;
            if (bytes.eql(&admission.receipt, &receipt_id)) return;
        }
        if (self.admissions.full()) return error.NoAdmissionSpace;
        _ = self.admissions.append(.{
            .receipt = receipt_id,
            .actor = capability.actor,
            .subject = capability.tpm,
            .action = authorization.intent.action,
            .consequence = authorization.intent.consequence,
            .not_after = authorization.not_after,
        });
    }

    pub fn admitCallerAuthorization(self: *App, authorization: intent.Receipt, actor: identity.Identity) Error!void {
        const capability = self.admissionCapability(authorization, actor) orelse return error.Unauthorized;
        try self.admitAuthorization(authorization, capability);
    }

    pub fn sealFor(self: *App, caller: identity.Identity, user: ?identity.Identity, policy: seal.Policy, authorization: intent.Receipt, plaintext: []const u8) Error!Sealed {
        const caller_principal = authority.dataActor(caller) orelse return error.Unauthorized;
        const tpm_principal = self.principal() orelse return error.Unauthorized;
        if (!self.authorizationAccepted(authorization, caller_principal, tpm_principal, .seal_data, .writes_private_state)) return error.Unauthorized;
        if (!policyAllowsCaller(policy, authority.Principal.device(self.device) orelse return error.BadPolicy, caller_principal, user)) return error.BadPolicy;

        const plaintext_hash = hashBytes("edgerun:zig:v1:tpmapp:plaintext", plaintext);
        const ciphertext_hash = sealHash(self.id.id, caller.id, policy, plaintext_hash);
        const event_id = try self.record(.seal, caller_principal, policy, plaintext_hash, ciphertext_hash, authorization);
        return .{
            .policy = policy,
            .plaintext_hash = plaintext_hash,
            .ciphertext_hash = ciphertext_hash,
            .event_id = event_id,
        };
    }

    pub fn unsealFor(self: *App, caller: identity.Identity, user: ?identity.Identity, sealed: Sealed, authorization: intent.Receipt) Error!preimage.Hash {
        const caller_principal = authority.dataActor(caller) orelse return error.Unauthorized;
        const tpm_principal = self.principal() orelse return error.Unauthorized;
        if (!self.authorizationAccepted(authorization, caller_principal, tpm_principal, .unseal_data, .reads_private_state)) return error.Unauthorized;
        if (!sealed.valid() or !policyAllowsCaller(sealed.policy, authority.Principal.device(self.device) orelse return error.BadPolicy, caller_principal, user)) return error.BadPolicy;

        const event_id = try self.record(.unseal, caller_principal, sealed.policy, sealed.ciphertext_hash, sealed.plaintext_hash, authorization);
        return event_id;
    }

    pub fn signFor(self: *App, caller: identity.Identity, authorization: intent.Receipt, subject: []const u8) Error!Signature {
        const caller_principal = authority.dataActor(caller) orelse return error.Unauthorized;
        const tpm_principal = self.principal() orelse return error.Unauthorized;
        if (!self.authorizationAccepted(authorization, caller_principal, tpm_principal, .sign_data, .attests_state)) return error.Unauthorized;

        const subject_hash = hashBytes("edgerun:zig:v1:tpmapp:subject", subject);
        const signature_hash = signatureHash(self.id.id, caller.id, subject_hash);
        const policy = seal.Policy.integrityOnly();
        const event_id = try self.record(.sign, caller_principal, policy, subject_hash, signature_hash, authorization);
        return .{
            .signer = tpm_principal,
            .subject_hash = subject_hash,
            .signature_hash = signature_hash,
            .event_id = event_id,
        };
    }

    pub fn randomFor(self: *App, caller: identity.Identity, authorization: intent.Receipt, request: []const u8, out: []u8) Error!Random {
        if (out.len == 0 or request.len == 0) return error.BadRequest;
        const caller_principal = authority.dataActor(caller) orelse return error.Unauthorized;
        const tpm_principal = self.principal() orelse return error.Unauthorized;
        if (!self.authorizationAccepted(authorization, caller_principal, tpm_principal, .random_bytes, .creates_secret_material)) return error.Unauthorized;

        const request_hash = hashBytes("edgerun:zig:v1:tpmapp:rng-request", request);
        fillRandomModel(self.id.id, caller.id, self.clock.now, request_hash, out);
        const output_hash = hashBytes("edgerun:zig:v1:tpmapp:rng-output", out);
        const event_id = try self.record(.random, caller_principal, seal.Policy.integrityOnly(), request_hash, output_hash, authorization);
        return .{
            .caller = caller_principal,
            .len = out.len,
            .request_hash = request_hash,
            .output_hash = output_hash,
            .event_id = event_id,
        };
    }

    pub fn eventAt(self: App, index: usize) ?Event {
        return self.events.at(index);
    }

    pub fn eventCount(self: App) usize {
        return self.events.len;
    }

    fn record(self: *App, kind: EventKind, caller: authority.Principal, policy: seal.Policy, input_hash: preimage.Hash, output_hash: preimage.Hash, authorization: intent.Receipt) Error!preimage.Hash {
        if (self.events.full()) return error.NoEventSpace;
        const policy_id = policy.id() orelse return error.BadPolicy;
        const authorization_id = authorization.id() orelse return error.Unauthorized;
        const event = Event{
            .kind = kind,
            .caller = caller,
            .policy_id = policy_id,
            .input_hash = input_hash,
            .output_hash = output_hash,
            .authorization_id = authorization_id,
            .epoch = self.clock.now,
        };
        const event_id = event.id() orelse return error.BadPolicy;
        if (!self.events.append(event)) return error.NoEventSpace;
        _ = self.clock.advance(1) orelse return error.BadPolicy;
        return event_id;
    }

    fn principal(self: App) ?authority.Principal {
        return authority.Principal.tpm(self.id);
    }

    fn authorizationAccepted(self: App, authorization: intent.Receipt, actor: authority.Principal, subject: authority.Principal, action: intent.Action, consequence: intent.Consequence) bool {
        return authority.receiptPermits(authorization, self.clock.now, actor, subject, action, consequence) and
            self.hasAdmittedAuthorization(authorization, actor, subject, action, consequence);
    }

    fn hasAdmittedAuthorization(self: App, authorization: intent.Receipt, actor: authority.Principal, subject: authority.Principal, action: intent.Action, consequence: intent.Consequence) bool {
        for (self.admissions.slice()) |admission| {
            if (admission.matches(authorization, self.clock.now, actor, subject, action, consequence)) return true;
        }
        return false;
    }
};

fn writePrincipal(writer: *preimage.Writer, principal: authority.Principal) bool {
    var raw: [authority.principal_encoded_size]u8 = undefined;
    if (!principal.encode(&raw)) return false;
    return writer.raw(&raw);
}

fn policyAllowsCaller(policy: seal.Policy, device: authority.Principal, caller: authority.Principal, user: ?identity.Identity) bool {
    if (!policy.valid()) return false;
    if (device.kind != .device or (caller.kind != .app and caller.kind != .storage)) return false;
    return switch (policy.scope) {
        .machine_app => policy.device != null and policy.device.?.eql(device.id) and policy.app != null and policy.app.?.eql(caller.id) and policy.user == null,
        .machine_app_user => user != null and
            user.?.kind == .user and
            policy.device != null and
            policy.device.?.eql(device.id) and
            policy.app != null and
            policy.app.?.eql(caller.id) and
            policy.user != null and
            policy.user.?.eql(user.?.id),
        else => false,
    };
}

fn sealHash(tpm: identity.Id, caller: identity.Id, policy: seal.Policy, plaintext_hash: preimage.Hash) preimage.Hash {
    var policy_raw: [seal.encoded_size]u8 = undefined;
    _ = policy.encode(&policy_raw);
    var builder = preimage.Builder.init("edgerun:zig:v1:tpmapp:seal");
    builder.id(tpm);
    builder.id(caller);
    builder.bytes(&policy_raw);
    builder.hash(plaintext_hash);
    return builder.final();
}

fn signatureHash(tpm: identity.Id, caller: identity.Id, subject_hash: preimage.Hash) preimage.Hash {
    var builder = preimage.Builder.init("edgerun:zig:v1:tpmapp:sign");
    builder.id(tpm);
    builder.id(caller);
    builder.hash(subject_hash);
    return builder.final();
}

fn fillRandomModel(tpm: identity.Id, caller: identity.Id, epoch: clock.Stamp, request_hash: preimage.Hash, out: []u8) void {
    var offset: usize = 0;
    var counter: u64 = 0;
    while (offset < out.len) : (counter += 1) {
        var epoch_raw: [64]u8 = undefined;
        var writer = preimage.Writer.init(&epoch_raw);
        _ = writer.epoch(epoch);
        var builder = preimage.Builder.init("edgerun:zig:v1:tpmapp:rng");
        builder.id(tpm);
        builder.id(caller);
        builder.bytes(writer.written());
        builder.hash(request_hash);
        builder.writeU64(counter);
        const block = builder.final();

        const n = @min(block.len, out.len - offset);
        @memcpy(out[offset..][0..n], block[0..n]);
        offset += n;
    }
}

fn hashBytes(domain: []const u8, value: []const u8) preimage.Hash {
    return preimage.hash(domain, value);
}

const TestIdentities = struct {
    user: identity.Identity,
    device: identity.Identity,
    tpm: identity.Identity,
    chat: identity.Identity,
    other: identity.Identity,
};

fn testIdentities(epoch: clock.Stamp) TestIdentities {
    const tpm_public = [_]u8{0xa7} ** identity.p256_public_size;
    return .{
        .user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?,
        .device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?,
        .tpm = identity.Identity.init(.app, identity.Source.prepare(.tpm_p256_public, &tpm_public).?, epoch).?,
        .chat = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("chat")).?, epoch).?,
        .other = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("other")).?, epoch).?,
    };
}

fn admitForTest(app: *App, authorization: intent.Receipt, actor: identity.Identity) !void {
    try app.admitCallerAuthorization(authorization, actor);
}

test "tpm app seals only for authorized caller-bound policy" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const ids = testIdentities(epoch);
    var events: [4]Event = undefined;
    var tpm = App.init(ids.tpm, ids.device, clock.Clock.init(keeper, .{}).?, &events).?;
    const authorization = intent.admit(ids.user, ids.device, ids.chat, ids.tpm, .seal_data, .writes_private_state, tpm.clock.now, intent.requestId("seal chat data").?).?;
    try admitForTest(&tpm, authorization, ids.chat);
    const policy = seal.Policy.machineAppUser(ids.device, ids.chat, ids.user);

    const sealed = try tpm.sealFor(ids.chat, ids.user, policy, authorization, "message");
    if (!sealed.valid()) return error.TestExpectedTrue;
    if (tpm.eventCount() != 1) return error.TestExpectedEqual;
    if (tpm.eventAt(0).?.kind != .seal) return error.TestExpectedEqual;
    if (!tpm.eventAt(0).?.caller.eql(authority.Principal.app(ids.chat).?)) return error.TestExpectedTrue;
    if (tpm.sealFor(ids.other, ids.user, policy, authorization, "message")) |_| return error.TestExpectedError else |err| {
        if (err != error.Unauthorized) return err;
    }

    const claimed_policy = seal.Policy.machineAppUser(ids.device, ids.other, ids.user);
    const second_authorization = intent.admit(ids.user, ids.device, ids.chat, ids.tpm, .seal_data, .writes_private_state, tpm.clock.now, intent.requestId("seal bad policy").?).?;
    try admitForTest(&tpm, second_authorization, ids.chat);
    if (tpm.sealFor(ids.chat, ids.user, claimed_policy, second_authorization, "message")) |_| return error.TestExpectedError else |err| {
        if (err != error.BadPolicy) return err;
    }
}

test "tpm app identity must be tpm backed" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const ids = testIdentities(epoch);
    var events: [1]Event = undefined;
    const app_identity = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ordinary app is not tpm")).?, epoch).?;

    if (App.init(app_identity, ids.device, clock.Clock.init(keeper, .{}).?, &events) != null) return error.TestExpectedNull;
}

test "tpm app refuses signatures without caller intent" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const ids = testIdentities(epoch);
    var events: [2]Event = undefined;
    var tpm = App.init(ids.tpm, ids.device, clock.Clock.init(keeper, .{}).?, &events).?;
    const wrong_authorization = intent.admit(ids.user, ids.device, ids.other, ids.tpm, .sign_data, .attests_state, tpm.clock.now, intent.requestId("wrong signer").?).?;
    const authorization = intent.admit(ids.user, ids.device, ids.chat, ids.tpm, .sign_data, .attests_state, tpm.clock.now, intent.requestId("sign app state").?).?;

    if (tpm.signFor(ids.chat, wrong_authorization, "state root")) |_| return error.TestExpectedError else |err| {
        if (err != error.Unauthorized) return err;
    }
    if (tpm.signFor(ids.chat, authorization, "state root")) |_| return error.TestExpectedError else |err| {
        if (err != error.Unauthorized) return err;
    }
    if (tpm.admitAuthorization(authorization, tpm.admissionCapability(authorization, ids.other).?)) return error.TestExpectedError else |err| {
        if (err != error.Unauthorized) return err;
    }
    try admitForTest(&tpm, authorization, ids.chat);
    const signature = try tpm.signFor(ids.chat, authorization, "state root");
    if (!signature.valid()) return error.TestExpectedTrue;
    if (!signature.signer.eql(authority.Principal.tpm(ids.tpm).?)) return error.TestExpectedTrue;
    if (tpm.eventCount() != 1) return error.TestExpectedEqual;
}

test "tpm app exposes authorized rng to apps" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const ids = testIdentities(epoch);
    var events: [3]Event = undefined;
    var tpm = App.init(ids.tpm, ids.device, clock.Clock.init(keeper, .{}).?, &events).?;
    const authorization = intent.admit(ids.user, ids.device, ids.chat, ids.tpm, .random_bytes, .creates_secret_material, tpm.clock.now, intent.requestId("message key material").?).?;
    const wrong_authorization = intent.admit(ids.user, ids.device, ids.other, ids.tpm, .random_bytes, .creates_secret_material, tpm.clock.now, intent.requestId("other key material").?).?;
    try admitForTest(&tpm, authorization, ids.chat);

    var key: [32]u8 = undefined;
    const random = try tpm.randomFor(ids.chat, authorization, "message-key", &key);
    if (!random.valid()) return error.TestExpectedTrue;
    if (!random.caller.eql(authority.Principal.app(ids.chat).?)) return error.TestExpectedTrue;
    if (!bytes.nonzero(&key)) return error.TestExpectedTrue;
    if (tpm.eventAt(0).?.kind != .random) return error.TestExpectedEqual;

    var rejected: [16]u8 = undefined;
    if (tpm.randomFor(ids.chat, wrong_authorization, "message-key", &rejected)) |_| return error.TestExpectedError else |err| {
        if (err != error.Unauthorized) return err;
    }
    if (tpm.randomFor(ids.chat, authorization, "", &rejected)) |_| return error.TestExpectedError else |err| {
        if (err != error.BadRequest) return err;
    }
}
