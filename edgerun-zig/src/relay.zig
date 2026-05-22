const std = @import("std");
const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;
pub const max_relays = 8;
pub const RelayPath = bounded.FixedList(identity.Id, max_relays);

pub const RouteError = error{
    InvalidAdmission,
    InvalidRoute,
    InvalidEnvelope,
    WrongRelay,
    WrongDestination,
    ReplayWindow,
    BadSignature,
};

pub const Route = struct {
    admission: preimage.Hash,
    source: identity.Id,
    target: identity.Id,
    action: intent.Action,
    consequence: intent.Consequence,
    policy: preimage.Hash,
    not_before: clock.Stamp,
    not_after: clock.Stamp,
    relays: RelayPath = .{},

    pub fn init(admission: intent.Receipt, source: identity.Identity, target: identity.Identity, action: intent.Action, consequence: intent.Consequence, policy: preimage.Hash) ?Route {
        const admission_id = admission.id() orelse return null;
        if (!admission.permitsAt(admission.intent.epoch, source.id, target.id, action, consequence)) return null;
        if (!bytes.nonzero(&policy)) return null;

        return .{
            .admission = admission_id,
            .source = source.id,
            .target = target.id,
            .action = action,
            .consequence = consequence,
            .policy = policy,
            .not_before = admission.not_before,
            .not_after = admission.not_after,
        };
    }

    pub fn appendRelay(self: *Route, relay: identity.Identity) bool {
        if (relay.kind != .relay and relay.kind != .app) return false;
        return self.relays.append(relay.id);
    }

    pub fn valid(self: Route) bool {
        return bytes.nonzero(&self.admission) and
            self.source.valid() and
            self.target.valid() and
            bytes.nonzero(&self.policy) and
            self.not_before.valid() and
            self.not_after.valid() and
            self.not_before.sameKeeper(self.not_after) and
            self.not_before.order(self.not_after) <= 0;
    }

    pub fn activeAt(self: Route, now: clock.Stamp) bool {
        return self.valid() and
            now.sameKeeper(self.not_before) and
            self.not_before.order(now) <= 0 and
            now.order(self.not_after) <= 0;
    }

    pub fn containsRelay(self: Route, relay: identity.Id) bool {
        for (self.relays.slice()) |route_relay| {
            if (route_relay.eql(relay)) return true;
        }
        return false;
    }

    pub fn id(self: Route) ?preimage.Hash {
        if (!self.valid()) return null;

        var header: [260]u8 = undefined;
        var writer = preimage.Writer.init(&header);
        if (!writer.hash(self.admission) or
            !writer.id(self.source) or
            !writer.id(self.target) or
            !writer.writeU16(@intFromEnum(self.action)) or
            !writer.writeU16(@intFromEnum(self.consequence)) or
            !writer.hash(self.policy) or
            !writer.epoch(self.not_before) or
            !writer.epoch(self.not_after))
        {
            return null;
        }

        var builder = preimage.Builder.init("edgerun:zig:v1:identity-route");
        builder.bytes(writer.written());

        for (self.relays.slice()) |route_relay| {
            builder.id(route_relay);
        }

        return builder.final();
    }
};

pub const Signature = struct {
    signer: identity.Id,
    digest: preimage.Hash,

    pub fn valid(self: Signature) bool {
        return self.signer.valid() and bytes.nonzero(&self.digest);
    }
};

pub const Envelope = struct {
    route: preimage.Hash,
    admission: preimage.Hash,
    from: identity.Id,
    to: identity.Id,
    action: intent.Action,
    consequence: intent.Consequence,
    sequence: u64,
    payload_object: preimage.Hash,
    payload_hash: preimage.Hash,
    signature: Signature,

    pub fn init(route: Route, sequence: u64, payload_object: preimage.Hash, payload_hash: preimage.Hash) ?Envelope {
        if (sequence == 0 or !bytes.nonzero(&payload_object) or !bytes.nonzero(&payload_hash)) return null;
        return .{
            .route = route.id() orelse return null,
            .admission = route.admission,
            .from = route.source,
            .to = route.target,
            .action = route.action,
            .consequence = route.consequence,
            .sequence = sequence,
            .payload_object = payload_object,
            .payload_hash = payload_hash,
            .signature = .{ .signer = route.source, .digest = [_]u8{0} ** id_size },
        };
    }

    pub fn sign(self: *Envelope, signer: identity.Identity) bool {
        if (!signer.id.eql(self.from)) return false;
        self.signature = .{ .signer = signer.id, .digest = self.signatureDigest(signer.id) orelse return false };
        return true;
    }

    pub fn validFor(self: Envelope, route: Route) RouteError!void {
        const route_id = route.id() orelse return error.InvalidRoute;
        if (!bytes.eql(&self.route, &route_id) or
            !bytes.eql(&self.admission, &route.admission) or
            !self.from.eql(route.source) or
            !self.to.eql(route.target) or
            self.action != route.action or
            self.consequence != route.consequence)
        {
            return error.InvalidEnvelope;
        }
        if (!self.verifySignature()) return error.BadSignature;
    }

    pub fn id(self: Envelope) ?preimage.Hash {
        if (!self.signature.valid()) return null;
        const unsigned = self.unsignedDigest() orelse return null;
        var builder = preimage.Builder.init("edgerun:zig:v1:relay-envelope-id");
        builder.hash(unsigned);
        builder.id(self.signature.signer);
        builder.hash(self.signature.digest);
        return builder.final();
    }

    fn verifySignature(self: Envelope) bool {
        if (!self.signature.signer.eql(self.from)) return false;
        const expected = self.signatureDigest(self.signature.signer) orelse return false;
        return bytes.eql(&expected, &self.signature.digest);
    }

    fn signatureDigest(self: Envelope, signer: identity.Id) ?preimage.Hash {
        if (!signer.valid()) return null;
        const unsigned = self.unsignedDigest() orelse return null;
        var builder = preimage.Builder.init("edgerun:zig:v1:relay-envelope-signature");
        builder.id(signer);
        builder.hash(unsigned);
        return builder.final();
    }

    fn unsignedDigest(self: Envelope) ?preimage.Hash {
        if (!bytes.nonzero(&self.route) or
            !bytes.nonzero(&self.admission) or
            !self.from.valid() or
            !self.to.valid() or
            self.sequence == 0 or
            !bytes.nonzero(&self.payload_object) or
            !bytes.nonzero(&self.payload_hash))
        {
            return null;
        }

        var raw: [204]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.hash(self.route) or
            !writer.hash(self.admission) or
            !writer.id(self.from) or
            !writer.id(self.to) or
            !writer.writeU16(@intFromEnum(self.action)) or
            !writer.writeU16(@intFromEnum(self.consequence)) or
            !writer.writeU64(self.sequence) or
            !writer.hash(self.payload_object) or
            !writer.hash(self.payload_hash))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:relay-envelope", writer.written());
    }
};

pub const TransitReceipt = struct {
    relay: identity.Id,
    route: preimage.Hash,
    envelope: preimage.Hash,
    from: identity.Id,
    to: identity.Id,
    sequence: u64,
    previous: preimage.Hash,
    transit: preimage.Hash,

    pub fn valid(self: TransitReceipt) bool {
        return self.relay.valid() and
            bytes.nonzero(&self.route) and
            bytes.nonzero(&self.envelope) and
            self.from.valid() and
            self.to.valid() and
            self.sequence != 0 and
            bytes.nonzero(&self.transit);
    }
};

pub const RelayApp = struct {
    id: identity.Identity,
    sequence: u64 = 0,
    previous: preimage.Hash = [_]u8{0} ** id_size,

    pub fn init(id: identity.Identity) ?RelayApp {
        if (id.kind != .relay and id.kind != .app) return null;
        return .{ .id = id };
    }

    pub fn forward(self: *RelayApp, route: Route, envelope: Envelope, now: clock.Stamp) RouteError!TransitReceipt {
        if (!route.activeAt(now)) return error.ReplayWindow;
        if (!route.containsRelay(self.id.id)) return error.WrongRelay;
        try envelope.validFor(route);

        self.sequence += 1;
        const envelope_id = envelope.id() orelse return error.InvalidEnvelope;
        const route_id = route.id() orelse return error.InvalidRoute;
        const previous = self.previous;
        var raw: [172]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.id(self.id.id) or
            !writer.hash(route_id) or
            !writer.hash(envelope_id) or
            !writer.hash(previous) or
            !writer.writeU64(self.sequence) or
            !writer.id(envelope.to) or
            !writer.writeU32(@intCast(route.relays.len)))
        {
            return error.InvalidRoute;
        }

        const transit = preimage.hash("edgerun:zig:v1:relay-transit", writer.written());
        self.previous = transit;

        return .{
            .relay = self.id.id,
            .route = route_id,
            .envelope = envelope_id,
            .from = envelope.from,
            .to = envelope.to,
            .sequence = self.sequence,
            .previous = previous,
            .transit = transit,
        };
    }
};

pub fn deliverTo(route: Route, envelope: Envelope, recipient: identity.Identity, now: clock.Stamp) RouteError!void {
    if (!recipient.id.eql(route.target) or !envelope.to.eql(recipient.id)) return error.WrongDestination;
    if (!route.activeAt(now)) return error.ReplayWindow;
    try envelope.validFor(route);
}

fn hashMaterial(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:test-material", material);
}

test "relay forwards identity routed envelope without payload authority" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const now = clock.Stamp{ .keeper = keeper, .tick = 7 };
    const user = identity.Identity.init(.user, identity.Source.init(.hash, "user").?, now).?;
    const device = identity.Identity.init(.device, identity.Source.init(.hash, "device").?, now).?;
    const source = identity.Identity.init(.app, identity.Source.init(.hash, "chat app source").?, now).?;
    const target = identity.Identity.init(.app, identity.Source.init(.hash, "chat app target").?, now).?;
    const relay_id = identity.Identity.init(.relay, identity.Source.init(.hash, "public relay").?, now).?;

    const admission = intent.admitWindow(
        user,
        device,
        source,
        target,
        .sync_data,
        .exports_data,
        now,
        now,
        .{ .keeper = keeper, .tick = 9 },
        intent.requestId("sync sealed message object").?,
    ).?;
    var route = Route.init(admission, source, target, .sync_data, .exports_data, hashMaterial("route policy")).?;
    try std.testing.expect(route.appendRelay(relay_id));

    var envelope = Envelope.init(route, 1, hashMaterial("canonical object id"), hashMaterial("recipient sealed payload")).?;
    try std.testing.expect(envelope.sign(source));

    var relay_app = RelayApp.init(relay_id).?;
    const receipt = try relay_app.forward(route, envelope, now);
    try std.testing.expect(receipt.valid());
    try deliverTo(route, envelope, target, now);

    var tampered = envelope;
    tampered.to = source.id;
    try std.testing.expectError(error.InvalidEnvelope, relay_app.forward(route, tampered, now));
}

test "relay rejects messages outside route admission window" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 };
    const start = clock.Stamp{ .keeper = keeper, .tick = 10 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 20 };
    const user = identity.Identity.init(.user, identity.Source.init(.hash, "user replay").?, start).?;
    const device = identity.Identity.init(.device, identity.Source.init(.hash, "device replay").?, start).?;
    const source = identity.Identity.init(.app, identity.Source.init(.hash, "source replay").?, start).?;
    const target = identity.Identity.init(.app, identity.Source.init(.hash, "target replay").?, start).?;
    const relay_id = identity.Identity.init(.relay, identity.Source.init(.hash, "relay replay").?, start).?;

    const admission = intent.admitWindow(user, device, source, target, .sync_data, .exports_data, start, start, end, intent.requestId("route replay").?).?;
    var route = Route.init(admission, source, target, .sync_data, .exports_data, hashMaterial("replay route policy")).?;
    try std.testing.expect(route.appendRelay(relay_id));
    var envelope = Envelope.init(route, 1, hashMaterial("object replay"), hashMaterial("payload replay")).?;
    try std.testing.expect(envelope.sign(source));

    var relay_app = RelayApp.init(relay_id).?;
    try std.testing.expectError(error.ReplayWindow, relay_app.forward(route, envelope, .{ .keeper = keeper, .tick = 21 }));
}
