const std = @import("er_std");
const authority = @import("authority.zig");
const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;
pub const max_relays = 8;
pub const route_header_encoded_size = preimage.hash_size + authority.principal_encoded_size + authority.principal_encoded_size + authority.u16_encoded_size + authority.u16_encoded_size + preimage.hash_size + preimage.epoch_size + preimage.epoch_size;
pub const envelope_unsigned_encoded_size = preimage.hash_size + preimage.hash_size + authority.principal_encoded_size + authority.principal_encoded_size + authority.u16_encoded_size + authority.u16_encoded_size + @sizeOf(u64) + preimage.hash_size + preimage.hash_size;
pub const transit_encoded_size = authority.principal_encoded_size + preimage.hash_size + preimage.hash_size + preimage.hash_size + @sizeOf(u64) + authority.principal_encoded_size + authority.principal_encoded_size + authority.u32_encoded_size;
pub const RelayPath = bounded.FixedList(authority.Principal, max_relays);

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
    source: authority.Principal,
    target: authority.Principal,
    action: intent.Action,
    consequence: intent.Consequence,
    policy: preimage.Hash,
    not_before: clock.Stamp,
    not_after: clock.Stamp,
    relays: RelayPath = .{},

    pub fn init(admission: intent.Receipt, source: identity.Identity, target: identity.Identity, action: intent.Action, consequence: intent.Consequence, policy: preimage.Hash) ?Route {
        const admission_id = admission.id() orelse return null;
        const source_principal = authority.routeEndpoint(source) orelse return null;
        const target_principal = authority.routeEndpoint(target) orelse return null;
        if (!authority.receiptPermits(admission, admission.intent.epoch, source_principal, target_principal, action, consequence)) return null;
        if (!bytes.nonzero(&policy)) return null;

        return .{
            .admission = admission_id,
            .source = source_principal,
            .target = target_principal,
            .action = action,
            .consequence = consequence,
            .policy = policy,
            .not_before = admission.not_before,
            .not_after = admission.not_after,
        };
    }

    pub fn appendRelay(self: *Route, relay: identity.Identity) bool {
        const relay_principal = authority.routeRelay(relay) orelse return false;
        return self.relays.append(relay_principal);
    }

    pub fn valid(self: Route) bool {
        return bytes.nonzero(&self.admission) and
            self.source.valid() and
            self.target.valid() and
            bytes.nonzero(&self.policy) and
            self.relays.len != 0 and
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

    pub fn containsRelay(self: Route, relay: authority.Principal) bool {
        for (self.relays.slice()) |route_relay| {
            if (route_relay.eql(relay)) return true;
        }
        return false;
    }

    pub fn id(self: Route) ?preimage.Hash {
        if (!self.valid()) return null;

        var header: [route_header_encoded_size]u8 = undefined;
        var writer = preimage.Writer.init(&header);
        if (!writer.hash(self.admission) or
            !writePrincipal(&writer, self.source) or
            !writePrincipal(&writer, self.target) or
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
            if (!appendPrincipal(&builder, route_relay)) return null;
        }

        return builder.final();
    }
};

pub const Signature = struct {
    signer: authority.Principal,
    digest: preimage.Hash,

    pub fn valid(self: Signature) bool {
        return self.signer.valid() and bytes.nonzero(&self.digest);
    }
};

pub const Envelope = struct {
    route: preimage.Hash,
    admission: preimage.Hash,
    from: authority.Principal,
    to: authority.Principal,
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
        const signer_principal = authority.routeEndpoint(signer) orelse return false;
        if (!signer_principal.eql(self.from)) return false;
        self.signature = .{ .signer = signer_principal, .digest = self.signatureDigest(signer_principal) orelse return false };
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
        if (!appendPrincipal(&builder, self.signature.signer)) return null;
        builder.hash(self.signature.digest);
        return builder.final();
    }

    fn verifySignature(self: Envelope) bool {
        if (!self.signature.signer.eql(self.from)) return false;
        const expected = self.signatureDigest(self.signature.signer) orelse return false;
        return bytes.eql(&expected, &self.signature.digest);
    }

    fn signatureDigest(self: Envelope, signer: authority.Principal) ?preimage.Hash {
        if (!signer.valid()) return null;
        const unsigned = self.unsignedDigest() orelse return null;
        var builder = preimage.Builder.init("edgerun:zig:v1:relay-envelope-signature");
        if (!appendPrincipal(&builder, signer)) return null;
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

        var raw: [envelope_unsigned_encoded_size]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.hash(self.route) or
            !writer.hash(self.admission) or
            !writePrincipal(&writer, self.from) or
            !writePrincipal(&writer, self.to) or
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
    relay: authority.Principal,
    route: preimage.Hash,
    envelope: preimage.Hash,
    from: authority.Principal,
    to: authority.Principal,
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

    pub fn permits(self: TransitReceipt, route: Route, envelope: Envelope) bool {
        const route_id = route.id() orelse return false;
        const envelope_id = envelope.id() orelse return false;
        return self.valid() and
            route.containsRelay(self.relay) and
            bytes.eql(&self.route, &route_id) and
            bytes.eql(&self.envelope, &envelope_id) and
            self.from.eql(envelope.from) and
            self.to.eql(envelope.to);
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
        const relay_principal = authority.routeRelay(self.id) orelse return error.WrongRelay;
        if (!route.activeAt(now)) return error.ReplayWindow;
        if (!route.containsRelay(relay_principal)) return error.WrongRelay;
        try envelope.validFor(route);

        self.sequence += 1;
        const envelope_id = envelope.id() orelse return error.InvalidEnvelope;
        const route_id = route.id() orelse return error.InvalidRoute;
        const previous = self.previous;
        var raw: [transit_encoded_size]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writePrincipal(&writer, relay_principal) or
            !writer.hash(route_id) or
            !writer.hash(envelope_id) or
            !writer.hash(previous) or
            !writer.writeU64(self.sequence) or
            !writePrincipal(&writer, envelope.from) or
            !writePrincipal(&writer, envelope.to) or
            !writer.writeU32(@intCast(route.relays.len)))
        {
            return error.InvalidRoute;
        }

        const transit = preimage.hash("edgerun:zig:v1:relay-transit", writer.written());
        self.previous = transit;

        return .{
            .relay = relay_principal,
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

pub fn deliverTo(route: Route, envelope: Envelope, transit: TransitReceipt, recipient: identity.Identity, now: clock.Stamp) RouteError!void {
    const recipient_principal = authority.routeEndpoint(recipient) orelse return error.WrongDestination;
    if (!recipient_principal.eql(route.target) or !envelope.to.eql(recipient_principal)) return error.WrongDestination;
    if (!route.activeAt(now)) return error.ReplayWindow;
    try envelope.validFor(route);
    if (!transit.permits(route, envelope)) return error.WrongRelay;
}

fn writePrincipal(writer: *preimage.Writer, principal: authority.Principal) bool {
    var raw: [authority.principal_encoded_size]u8 = undefined;
    if (!principal.encode(&raw)) return false;
    return writer.raw(&raw);
}

fn appendPrincipal(builder: *preimage.Builder, principal: authority.Principal) bool {
    var raw: [authority.principal_encoded_size]u8 = undefined;
    if (!principal.encode(&raw)) return false;
    builder.bytes(&raw);
    return true;
}

fn hashMaterial(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:test-material", material);
}

test "relay forwards identity routed envelope without payload authority" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const now = clock.Stamp{ .keeper = keeper, .tick = 7 };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, now).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, now).?;
    const source = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("chat app source")).?, now).?;
    const target = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("chat app target")).?, now).?;
    const relay_id = identity.Identity.init(.relay, identity.Source.prepare(.hash, &preimage.rawHash("public relay")).?, now).?;

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
    try deliverTo(route, envelope, receipt, target, now);

    var forged_transit = receipt;
    forged_transit.relay = authority.Principal.relay(identity.Identity.init(.relay, identity.Source.prepare(.hash, &preimage.rawHash("wrong relay")).?, now).?).?;
    try std.testing.expectError(error.WrongRelay, deliverTo(route, envelope, forged_transit, target, now));

    var tampered = envelope;
    tampered.to = authority.Principal.app(source).?;
    try std.testing.expectError(error.InvalidEnvelope, relay_app.forward(route, tampered, now));
}

test "relay rejects messages outside route admission window" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 };
    const start = clock.Stamp{ .keeper = keeper, .tick = 10 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 20 };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user replay")).?, start).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device replay")).?, start).?;
    const source = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("source replay")).?, start).?;
    const target = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("target replay")).?, start).?;
    const relay_id = identity.Identity.init(.relay, identity.Source.prepare(.hash, &preimage.rawHash("relay replay")).?, start).?;

    const admission = intent.admitWindow(user, device, source, target, .sync_data, .exports_data, start, start, end, intent.requestId("route replay").?).?;
    var route = Route.init(admission, source, target, .sync_data, .exports_data, hashMaterial("replay route policy")).?;
    try std.testing.expect(route.appendRelay(relay_id));
    var envelope = Envelope.init(route, 1, hashMaterial("object replay"), hashMaterial("payload replay")).?;
    try std.testing.expect(envelope.sign(source));

    var relay_app = RelayApp.init(relay_id).?;
    try std.testing.expectError(error.ReplayWindow, relay_app.forward(route, envelope, .{ .keeper = keeper, .tick = 21 }));
}
