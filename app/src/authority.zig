const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;
pub const max_steps = 8;
pub const u16_encoded_size = 2;
pub const u32_encoded_size = 4;
pub const principal_kind_encoded_size = u16_encoded_size;
pub const principal_reserved_encoded_size = u16_encoded_size;
pub const principal_encoded_size = principal_kind_encoded_size + principal_reserved_encoded_size + identity.id_size;
pub const chain_header_encoded_size = principal_encoded_size + principal_encoded_size + u32_encoded_size;
pub const step_encoded_size = u16_encoded_size + principal_encoded_size + principal_encoded_size + preimage.hash_size + preimage.epoch_size;
pub const packet_encoded_size = 576;
pub const approval_encoded_size = 228;
pub const Steps = bounded.FixedList(Step, max_steps);

pub const StepKind = enum(u16) {
    user_admitted = 1,
    delegated_to_device = 2,
    delegated_to_allocator = 3,
    delegated_to_ui = 4,
    delegated_to_app = 5,
    delegated_to_storage = 6,
};

pub const PacketKind = enum(u16) {
    storage_write = 1,
    state_transition = 2,
    key_use = 3,
};

pub const Capability = enum(u32) {
    app_private_storage = 1,
    user_private_storage = 2,
    external_key_use = 4,
    zk_state_transition = 8,
};

pub const PrincipalKind = enum(u16) {
    user = 1,
    device = 2,
    app = 3,
    storage = 4,
    tpm = 5,
    external_verifier = 6,
    relay = 7,
    service = 8,
};

pub const Principal = struct {
    kind: PrincipalKind,
    id: identity.Id,

    pub fn user(value: identity.Identity) ?Principal {
        if (value.kind != .user) return null;
        return fromIdentity(.user, value);
    }

    pub fn device(value: identity.Identity) ?Principal {
        if (value.kind != .device) return null;
        return fromIdentity(.device, value);
    }

    pub fn app(value: identity.Identity) ?Principal {
        if (value.kind != .app and value.kind != .delegated) return null;
        return fromIdentity(.app, value);
    }

    pub fn storage(value: identity.Identity) ?Principal {
        if (value.kind != .storage) return null;
        return fromIdentity(.storage, value);
    }

    pub fn tpm(value: identity.Identity) ?Principal {
        if (value.kind != .app) return null;
        if (value.source.kind != .tpm_p256_public) return null;
        return fromIdentity(.tpm, value);
    }

    pub fn externalVerifier(value: identity.Identity) ?Principal {
        if (value.kind != .app and value.kind != .delegated) return null;
        return fromIdentity(.external_verifier, value);
    }

    pub fn relay(value: identity.Identity) ?Principal {
        if (value.kind != .relay) return null;
        return fromIdentity(.relay, value);
    }

    pub fn service(value: identity.Identity) ?Principal {
        if (value.kind != .app and value.kind != .storage and value.kind != .delegated) return null;
        return fromIdentity(.service, value);
    }

    pub fn fromIdentity(kind: PrincipalKind, value: identity.Identity) ?Principal {
        if (!value.valid()) return null;
        return fromId(kind, value.id);
    }

    pub fn fromId(kind: PrincipalKind, id: identity.Id) ?Principal {
        const principal = Principal{ .kind = kind, .id = id };
        return if (principal.valid()) principal else null;
    }

    pub fn valid(self: Principal) bool {
        return self.id.valid();
    }

    pub fn eql(self: Principal, other: Principal) bool {
        return self.kind == other.kind and self.id.eql(other.id);
    }

    pub fn encode(self: Principal, out: []u8) bool {
        if (!self.valid() or out.len < principal_encoded_size) return false;
        const reserved_start = principal_kind_encoded_size;
        const id_start = reserved_start + principal_reserved_encoded_size;
        return bytes.store16(out[0..principal_kind_encoded_size], @intFromEnum(self.kind)) and
            bytes.store16(out[reserved_start..id_start], 0) and
            bytes.copy(out[id_start..principal_encoded_size], &self.id.bytes);
    }
};

pub fn receiptPermits(authorization: intent.Receipt, now: clock.Stamp, actor: Principal, subject: Principal, action: intent.Action, consequence: intent.Consequence) bool {
    return actor.valid() and
        subject.valid() and
        authorization.permitsAt(now, actor.id, subject.id, action, consequence);
}

pub fn dataActor(value: identity.Identity) ?Principal {
    return switch (value.kind) {
        .app, .delegated => Principal.app(value),
        .storage => Principal.storage(value),
        else => null,
    };
}

pub fn routeEndpoint(value: identity.Identity) ?Principal {
    return dataActor(value);
}

pub fn routeRelay(value: identity.Identity) ?Principal {
    return switch (value.kind) {
        .relay => Principal.relay(value),
        .app, .delegated => Principal.service(value),
        else => null,
    };
}

pub fn stepTarget(kind: StepKind, value: identity.Identity) ?Principal {
    return switch (kind) {
        .user_admitted => Principal.user(value),
        .delegated_to_device => Principal.device(value),
        .delegated_to_allocator,
        .delegated_to_ui,
        .delegated_to_app,
        => Principal.app(value) orelse Principal.service(value),
        .delegated_to_storage => Principal.storage(value) orelse Principal.service(value),
    };
}

pub const Step = struct {
    kind: StepKind,
    from: Principal,
    to: Principal,
    receipt: preimage.Hash,
    epoch: clock.Stamp,

    pub fn valid(self: Step) bool {
        return self.from.valid() and
            self.to.valid() and
            self.targetMatchesKind() and
            bytes.nonzero(&self.receipt) and
            self.epoch.valid();
    }

    fn targetMatchesKind(self: Step) bool {
        return switch (self.kind) {
            .user_admitted => self.to.kind == .user,
            .delegated_to_device => self.to.kind == .device,
            .delegated_to_allocator,
            .delegated_to_ui,
            .delegated_to_app,
            => self.to.kind == .app or self.to.kind == .service,
            .delegated_to_storage => self.to.kind == .storage or self.to.kind == .service,
        };
    }
};

pub const Chain = struct {
    root: Principal,
    terminal: Principal,
    steps: Steps = .{},

    pub fn init(root: Principal) ?Chain {
        if (!root.valid() or root.kind != .user) return null;
        return .{
            .root = root,
            .terminal = root,
        };
    }

    pub fn initUser(root: identity.Identity) ?Chain {
        return init(Principal.user(root) orelse return null);
    }

    pub fn append(self: *Chain, step: Step) bool {
        if (self.steps.full() or !step.valid()) return false;
        if (!step.from.eql(self.terminal)) return false;

        if (!self.steps.append(step)) return false;
        self.terminal = step.to;
        return true;
    }

    pub fn appendIntent(self: *Chain, to: Principal, kind: StepKind, receipt: intent.Receipt) bool {
        const receipt_id = receipt.id() orelse return false;
        return self.append(.{
            .kind = kind,
            .from = self.terminal,
            .to = to,
            .receipt = receipt_id,
            .epoch = receipt.intent.epoch,
        });
    }

    pub fn appendIdentityIntent(self: *Chain, to: identity.Identity, kind: StepKind, receipt: intent.Receipt) bool {
        const target = stepTarget(kind, to) orelse return false;
        return self.appendIntent(target, kind, receipt);
    }

    pub fn valid(self: Chain) bool {
        if (!self.root.valid() or !self.terminal.valid()) return false;
        if (self.root.kind != .user) return false;
        var current = self.root;
        for (self.steps.slice()) |step| {
            if (!step.valid() or !step.from.eql(current)) return false;
            current = step.to;
        }
        return current.eql(self.terminal);
    }

    pub fn id(self: Chain) ?preimage.Hash {
        if (!self.valid()) return null;

        var builder = preimage.Builder.init("edgerun:zig:v1:authority-chain");
        var header: [chain_header_encoded_size]u8 = undefined;
        var writer = preimage.Writer.init(&header);
        if (!writePrincipal(&writer, self.root) or
            !writePrincipal(&writer, self.terminal) or
            !writer.writeU32(@intCast(self.steps.len)))
        {
            return null;
        }
        builder.bytes(writer.written());

        var raw_step: [step_encoded_size]u8 = undefined;
        for (self.steps.slice()) |step| {
            writer = preimage.Writer.init(&raw_step);
            if (!writer.writeU16(@intFromEnum(step.kind)) or
                !writePrincipal(&writer, step.from) or
                !writePrincipal(&writer, step.to) or
                !writer.hash(step.receipt) or
                !writer.epoch(step.epoch))
            {
                return null;
            }
            builder.bytes(writer.written());
        }

        return builder.final();
    }
};

pub const Packet = struct {
    kind: PacketKind,
    root: Principal,
    device: Principal,
    actor: Principal,
    subject: Principal,
    manifest: preimage.Hash,
    code_hash: preimage.Hash,
    capability_flags: u32,
    resource_grant: preimage.Hash,
    allocation: preimage.Hash,
    pre_state: preimage.Hash,
    post_state: preimage.Hash,
    input_root: preimage.Hash,
    output_root: preimage.Hash,
    clock_start: clock.Stamp,
    clock_end: clock.Stamp,
    action: intent.Action,
    consequence: intent.Consequence,
    proof: preimage.Hash,

    pub fn valid(self: Packet) bool {
        return self.root.valid() and
            self.root.kind == .user and
            self.device.valid() and
            self.device.kind == .device and
            self.actor.valid() and
            (self.actor.kind == .app or self.actor.kind == .storage or self.actor.kind == .service) and
            self.subject.valid() and
            bytes.nonzero(&self.manifest) and
            bytes.nonzero(&self.code_hash) and
            self.capability_flags != 0 and
            bytes.nonzero(&self.resource_grant) and
            bytes.nonzero(&self.allocation) and
            bytes.nonzero(&self.pre_state) and
            bytes.nonzero(&self.post_state) and
            bytes.nonzero(&self.input_root) and
            bytes.nonzero(&self.output_root) and
            self.clock_start.valid() and
            self.clock_end.valid() and
            self.clock_start.sameKeeper(self.clock_end) and
            self.clock_start.order(self.clock_end) <= 0 and
            bytes.nonzero(&self.proof) and
            self.capabilityMatchesKind();
    }

    pub fn id(self: Packet) ?preimage.Hash {
        var raw: [packet_encoded_size]u8 = undefined;
        const encoded = self.encode(&raw) orelse return null;
        return preimage.hash("edgerun:zig:v1:authority-packet", encoded);
    }

    pub fn hasCapability(self: Packet, capability: Capability) bool {
        return (self.capability_flags & @intFromEnum(capability)) != 0;
    }

    pub fn actionPermittedBy(self: Packet, receipt: intent.Receipt, now: clock.Stamp) bool {
        const receipt_id = receipt.id() orelse return false;
        return self.valid() and
            bytes.eql(&self.resource_grant, &receipt_id) and
            receipt.intent.user.eql(self.root.id) and
            receipt.intent.device.eql(self.device.id) and
            receipt.intent.actor.eql(self.actor.id) and
            receipt.intent.subject.eql(self.subject.id) and
            receiptPermits(receipt, now, self.actor, self.subject, self.action, self.consequence);
    }

    pub fn encode(self: Packet, out: []u8) ?[]const u8 {
        if (!self.valid() or out.len < packet_encoded_size) return null;
        var writer = preimage.Writer.init(out[0..packet_encoded_size]);
        if (!writer.writeU16(@intFromEnum(self.kind)) or
            !writer.writeU16(0) or
            !writer.writeU32(self.capability_flags) or
            !writePrincipal(&writer, self.root) or
            !writePrincipal(&writer, self.device) or
            !writePrincipal(&writer, self.actor) or
            !writePrincipal(&writer, self.subject) or
            !writer.hash(self.manifest) or
            !writer.hash(self.code_hash) or
            !writer.hash(self.resource_grant) or
            !writer.hash(self.allocation) or
            !writer.hash(self.pre_state) or
            !writer.hash(self.post_state) or
            !writer.hash(self.input_root) or
            !writer.hash(self.output_root) or
            !writer.epoch(self.clock_start) or
            !writer.epoch(self.clock_end) or
            !writer.writeU16(@intFromEnum(self.action)) or
            !writer.writeU16(@intFromEnum(self.consequence)) or
            !writer.writeU32(0) or
            !writer.hash(self.proof))
        {
            return null;
        }
        return writer.written();
    }

    fn capabilityMatchesKind(self: Packet) bool {
        return switch (self.kind) {
            .storage_write => self.hasCapability(.app_private_storage) or self.hasCapability(.user_private_storage),
            .state_transition => self.hasCapability(.zk_state_transition),
            .key_use => self.hasCapability(.external_key_use) and self.hasCapability(.zk_state_transition),
        };
    }
};

pub const ExternalApproval = struct {
    approver: Principal,
    packet: preimage.Hash,
    not_before: clock.Stamp,
    not_after: clock.Stamp,
    signature: preimage.Hash,

    pub fn valid(self: ExternalApproval) bool {
        return self.approver.valid() and
            (self.approver.kind == .external_verifier or self.approver.kind == .service) and
            bytes.nonzero(&self.packet) and
            self.not_before.valid() and
            self.not_after.valid() and
            self.not_before.sameKeeper(self.not_after) and
            self.not_before.order(self.not_after) <= 0 and
            bytes.nonzero(&self.signature);
    }

    pub fn permits(self: ExternalApproval, packet: Packet, now: clock.Stamp) bool {
        const packet_id = packet.id() orelse return false;
        return self.valid() and
            packet.valid() and
            bytes.eql(&self.packet, &packet_id) and
            now.sameKeeper(self.not_before) and
            self.not_before.order(now) <= 0 and
            now.order(self.not_after) <= 0;
    }

    pub fn id(self: ExternalApproval) ?preimage.Hash {
        var raw: [approval_encoded_size]u8 = undefined;
        const encoded = self.encode(&raw) orelse return null;
        return preimage.hash("edgerun:zig:v1:external-approval", encoded);
    }

    pub fn encode(self: ExternalApproval, out: []u8) ?[]const u8 {
        if (!self.valid() or out.len < approval_encoded_size) return null;
        var writer = preimage.Writer.init(out[0..approval_encoded_size]);
        if (!writePrincipal(&writer, self.approver) or
            !writer.hash(self.packet) or
            !writer.epoch(self.not_before) or
            !writer.epoch(self.not_after) or
            !writer.hash(self.signature))
        {
            return null;
        }
        return writer.written();
    }
};

fn writePrincipal(writer: *preimage.Writer, principal: Principal) bool {
    var raw: [principal_encoded_size]u8 = undefined;
    if (!principal.encode(&raw)) return false;
    return writer.raw(&raw);
}

test "authority chain is ordered and deterministic" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?;
    const allocator = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocator")).?, epoch).?;
    const request = intent.requestId("delegate allocator").?;
    const receipt = intent.admit(user, device, user, allocator, .grant_resource, .delegates_resources, epoch, request).?;

    var chain = Chain.init(Principal.user(user).?).?;
    if (!chain.appendIntent(Principal.app(allocator).?, .delegated_to_allocator, receipt)) return error.TestExpectedTrue;
    if (!chain.valid()) return error.TestExpectedTrue;
    if (!bytes.nonzero(&chain.id().?)) return error.TestExpectedTrue;
}

test "tpm principal requires a tpm backed app identity" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{4} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ordinary app")).?, epoch).?;
    const public = [_]u8{0xa5} ** identity.p256_public_size;
    const tpm = identity.Identity.init(.app, identity.Source.prepare(.tpm_p256_public, &public).?, epoch).?;

    if (Principal.tpm(app) != null) return error.TestExpectedNull;
    if (Principal.tpm(tpm).?.kind != .tpm) return error.TestExpectedEqual;
}

test "authority packet binds resource grant manifest state and proof" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 };
    const start = clock.Stamp{ .keeper = keeper, .tick = 4 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 6 };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("packet user")).?, start).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("packet device")).?, start).?;
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("packet app")).?, start).?;
    const other = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("packet other")).?, start).?;
    const receipt = intent.admitWindow(user, device, app, app, .sync_data, .exports_data, start, start, end, intent.requestId("packet storage export").?).?;
    const packet = Packet{
        .kind = .state_transition,
        .root = Principal.user(user).?,
        .device = Principal.device(device).?,
        .actor = Principal.app(app).?,
        .subject = Principal.app(app).?,
        .manifest = preimage.hash("edgerun:test", "manifest"),
        .code_hash = preimage.hash("edgerun:test", "code"),
        .capability_flags = @intFromEnum(Capability.zk_state_transition),
        .resource_grant = receipt.id().?,
        .allocation = preimage.hash("edgerun:test", "allocation"),
        .pre_state = preimage.hash("edgerun:test", "pre"),
        .post_state = preimage.hash("edgerun:test", "post"),
        .input_root = preimage.hash("edgerun:test", "input"),
        .output_root = preimage.hash("edgerun:test", "output"),
        .clock_start = start,
        .clock_end = end,
        .action = .sync_data,
        .consequence = .exports_data,
        .proof = preimage.hash("edgerun:test", "proof"),
    };

    if (!packet.valid()) return error.TestExpectedTrue;
    if (!bytes.nonzero(&packet.id().?)) return error.TestExpectedTrue;
    if (!packet.actionPermittedBy(receipt, start)) return error.TestExpectedTrue;

    const wrong_receipt = intent.admitWindow(user, device, app, other, .sync_data, .exports_data, start, start, end, intent.requestId("wrong packet grant").?).?;
    if (packet.actionPermittedBy(wrong_receipt, start)) return error.TestExpectedFalse;
}

test "external approval binds exact authority packet and clock window" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{3} ++ [_]u8{0} ** 31 };
    const start = clock.Stamp{ .keeper = keeper, .tick = 1 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 3 };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("approval user")).?, start).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("approval device")).?, start).?;
    const server = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("approval server")).?, start).?;
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("approval app")).?, start).?;
    const receipt = intent.admitWindow(user, device, app, app, .unseal_data, .reads_private_state, start, start, end, intent.requestId("approval key use").?).?;
    var packet = Packet{
        .kind = .key_use,
        .root = Principal.user(user).?,
        .device = Principal.device(device).?,
        .actor = Principal.app(app).?,
        .subject = Principal.app(app).?,
        .manifest = preimage.hash("edgerun:test", "approval manifest"),
        .code_hash = preimage.hash("edgerun:test", "approval code"),
        .capability_flags = @intFromEnum(Capability.external_key_use) | @intFromEnum(Capability.zk_state_transition),
        .resource_grant = receipt.id().?,
        .allocation = preimage.hash("edgerun:test", "approval allocation"),
        .pre_state = preimage.hash("edgerun:test", "approval pre"),
        .post_state = preimage.hash("edgerun:test", "approval post"),
        .input_root = preimage.hash("edgerun:test", "approval input"),
        .output_root = preimage.hash("edgerun:test", "approval output"),
        .clock_start = start,
        .clock_end = end,
        .action = .unseal_data,
        .consequence = .reads_private_state,
        .proof = preimage.hash("edgerun:test", "approval proof"),
    };
    const approval = ExternalApproval{
        .approver = Principal.externalVerifier(server).?,
        .packet = packet.id().?,
        .not_before = start,
        .not_after = end,
        .signature = preimage.hash("edgerun:test", "approval signature"),
    };

    if (!approval.permits(packet, start)) return error.TestExpectedTrue;
    if (!bytes.nonzero(&approval.id().?)) return error.TestExpectedTrue;
    if (approval.permits(packet, .{ .keeper = keeper, .tick = 4 })) return error.TestExpectedFalse;

    packet.post_state = preimage.hash("edgerun:test", "tampered post");
    if (approval.permits(packet, start)) return error.TestExpectedFalse;
}
