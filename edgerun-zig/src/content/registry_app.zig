const bytes = @import("../bytes.zig");
const data_chunk = @import("data_chunk.zig");
const kernel = @import("kernel.zig");

pub const Error = kernel.Error || error{
    Unauthorized,
};

pub const EndpointRegistration = struct {
    endpoint_id: data_chunk.DataChunk,
    app_state_id: data_chunk.DataChunk,
    allocation_id: data_chunk.DataChunk,
    accepted_definition_id: data_chunk.DataChunk,
    accepted_sender_id: ?data_chunk.DataChunk = null,
    valid_until_tick: u64,

    pub fn init(endpoint_id: data_chunk.DataChunk, app_state_id: data_chunk.DataChunk, allocation_id: data_chunk.DataChunk, accepted_definition_id: data_chunk.DataChunk, accepted_sender_id: ?data_chunk.DataChunk, valid_until_tick: u64) EndpointRegistration {
        return .{
            .endpoint_id = endpoint_id,
            .app_state_id = app_state_id,
            .allocation_id = allocation_id,
            .accepted_definition_id = accepted_definition_id,
            .accepted_sender_id = accepted_sender_id,
            .valid_until_tick = valid_until_tick,
        };
    }

    pub fn valid(self: EndpointRegistration) bool {
        if (!nonempty(self.endpoint_id) or
            !nonempty(self.app_state_id) or
            !nonempty(self.allocation_id) or
            !nonempty(self.accepted_definition_id))
        {
            return false;
        }
        if (self.accepted_sender_id) |sender| {
            if (!nonempty(sender)) return false;
        }
        return true;
    }

    pub fn accepts(self: EndpointRegistration, from_endpoint_id: data_chunk.DataChunk, definition_id: data_chunk.DataChunk, tick: u64) bool {
        if (!self.valid() or tick > self.valid_until_tick) return false;
        if (!sameChunk(self.accepted_definition_id, definition_id)) return false;
        if (self.accepted_sender_id) |sender| {
            if (!sameChunk(sender, from_endpoint_id)) return false;
        }
        return true;
    }
};

pub const MessageEnvelope = struct {
    from_endpoint_id: data_chunk.DataChunk,
    to_endpoint_id: data_chunk.DataChunk,
    definition_id: data_chunk.DataChunk,
    source_view_id: data_chunk.DataChunk,
    valid_until_tick: u64,

    pub fn init(from_endpoint_id: data_chunk.DataChunk, to_endpoint_id: data_chunk.DataChunk, definition_id: data_chunk.DataChunk, source_view_id: data_chunk.DataChunk, valid_until_tick: u64) MessageEnvelope {
        return .{
            .from_endpoint_id = from_endpoint_id,
            .to_endpoint_id = to_endpoint_id,
            .definition_id = definition_id,
            .source_view_id = source_view_id,
            .valid_until_tick = valid_until_tick,
        };
    }

    pub fn valid(self: MessageEnvelope) bool {
        return nonempty(self.from_endpoint_id) and
            nonempty(self.to_endpoint_id) and
            nonempty(self.definition_id) and
            nonempty(self.source_view_id);
    }
};

pub const Registry = struct {
    entries: []EndpointRegistration,
    len: usize = 0,

    pub fn init(entries: []EndpointRegistration) Registry {
        return .{
            .entries = entries,
        };
    }

    pub fn register(self: *Registry, allocator: kernel.Allocator, entry: EndpointRegistration) Error!void {
        if (!entry.valid()) return error.BadArgument;
        if (allocator.clock_tick > entry.valid_until_tick) return error.Expired;
        if (!allocator.rangeValid(kernel.AddressRange.init(entry.allocation_id, 0, 1))) return error.NotFound;
        if (self.findExact(entry.endpoint_id, entry.accepted_definition_id)) |_| return error.Duplicate;
        if (self.len == self.entries.len) return error.NoSpace;
        self.entries[self.len] = entry;
        self.len += 1;
    }

    pub fn lookup(self: Registry, to_endpoint_id: data_chunk.DataChunk, definition_id: data_chunk.DataChunk, from_endpoint_id: data_chunk.DataChunk, tick: u64) Error!EndpointRegistration {
        if (!nonempty(to_endpoint_id) or !nonempty(definition_id) or !nonempty(from_endpoint_id)) return error.BadArgument;
        var saw_expired = false;
        for (self.entries[0..self.len]) |entry| {
            if (!sameChunk(entry.endpoint_id, to_endpoint_id)) continue;
            if (!sameChunk(entry.accepted_definition_id, definition_id)) continue;
            if (tick > entry.valid_until_tick) {
                saw_expired = true;
                continue;
            }
            if (!entry.accepts(from_endpoint_id, definition_id, tick)) return error.Unauthorized;
            return entry;
        }
        if (saw_expired) return error.Expired;
        return error.NotFound;
    }

    pub fn route(self: Registry, allocator: kernel.Allocator, envelope: MessageEnvelope, source_view: kernel.MemoryView) Error!EndpointRegistration {
        if (!envelope.valid()) return error.BadArgument;
        if (allocator.clock_tick > envelope.valid_until_tick) return error.Expired;
        if (!sameChunk(envelope.source_view_id, source_view.id)) return error.BadArgument;
        if (!allocator.canRead(source_view, envelope.from_endpoint_id)) return error.Unauthorized;
        return self.lookup(envelope.to_endpoint_id, envelope.definition_id, envelope.from_endpoint_id, allocator.clock_tick);
    }

    fn findExact(self: Registry, endpoint_id: data_chunk.DataChunk, definition_id: data_chunk.DataChunk) ?usize {
        for (self.entries[0..self.len], 0..) |entry, index| {
            if (sameChunk(entry.endpoint_id, endpoint_id) and sameChunk(entry.accepted_definition_id, definition_id)) return index;
        }
        return null;
    }
};

fn nonempty(value: data_chunk.DataChunk) bool {
    return value.valid() and value.length != 0;
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and bytes.eql(left.body(), right.body());
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

test "registry app routes message definitions to live endpoints" {
    const testing = @import("std").testing;
    var allocation_slots: [2]kernel.Allocation = undefined;
    var registration_slots: [2]EndpointRegistration = undefined;
    var allocator = kernel.Allocator.init(&allocation_slots);
    var registry = Registry.init(&registration_slots);

    try allocator.addAllocation(kernel.Allocation.init(chunk("sender-allocation"), chunk("sender-app"), 64));
    try allocator.addAllocation(kernel.Allocation.init(chunk("receiver-allocation"), chunk("receiver-app"), 64));
    try registry.register(allocator, EndpointRegistration.init(chunk("receiver-endpoint"), chunk("receiver-state"), chunk("receiver-allocation"), chunk("message-definition"), null, 10));

    const view = try allocator.createView(kernel.MemoryView.init(chunk("view-a"), kernel.AddressRange.init(chunk("sender-allocation"), 8, 12), chunk("sender-endpoint"), false, 10));
    const routed = try registry.route(allocator, MessageEnvelope.init(chunk("sender-endpoint"), chunk("receiver-endpoint"), chunk("message-definition"), chunk("view-a"), 10), view);

    try testing.expectEqualStrings("receiver-state", routed.app_state_id.body());
    try testing.expectEqualStrings("receiver-allocation", routed.allocation_id.body());
}

test "registry app enforces optional sender restrictions" {
    const testing = @import("std").testing;
    var allocation_slots: [2]kernel.Allocation = undefined;
    var registration_slots: [1]EndpointRegistration = undefined;
    var allocator = kernel.Allocator.init(&allocation_slots);
    var registry = Registry.init(&registration_slots);

    try allocator.addAllocation(kernel.Allocation.init(chunk("sender-allocation"), chunk("sender-app"), 64));
    try allocator.addAllocation(kernel.Allocation.init(chunk("receiver-allocation"), chunk("receiver-app"), 64));
    try registry.register(allocator, EndpointRegistration.init(chunk("receiver-endpoint"), chunk("receiver-state"), chunk("receiver-allocation"), chunk("message-definition"), chunk("allowed-sender"), 10));

    const view = try allocator.createView(kernel.MemoryView.init(chunk("view-a"), kernel.AddressRange.init(chunk("sender-allocation"), 0, 4), chunk("allowed-sender"), false, 10));
    _ = try registry.route(allocator, MessageEnvelope.init(chunk("allowed-sender"), chunk("receiver-endpoint"), chunk("message-definition"), chunk("view-a"), 10), view);

    const denied = MessageEnvelope.init(chunk("other-sender"), chunk("receiver-endpoint"), chunk("message-definition"), chunk("view-a"), 10);
    try testing.expectError(error.Unauthorized, registry.route(allocator, denied, view));
}

test "registry app rejects expired registrations and envelopes" {
    const testing = @import("std").testing;
    var allocation_slots: [2]kernel.Allocation = undefined;
    var registration_slots: [1]EndpointRegistration = undefined;
    var allocator = kernel.Allocator.init(&allocation_slots);
    var registry = Registry.init(&registration_slots);

    try allocator.addAllocation(kernel.Allocation.init(chunk("sender-allocation"), chunk("sender-app"), 64));
    try allocator.addAllocation(kernel.Allocation.init(chunk("receiver-allocation"), chunk("receiver-app"), 64));
    try registry.register(allocator, EndpointRegistration.init(chunk("receiver-endpoint"), chunk("receiver-state"), chunk("receiver-allocation"), chunk("message-definition"), null, 1));
    const view = try allocator.createView(kernel.MemoryView.init(chunk("view-a"), kernel.AddressRange.init(chunk("sender-allocation"), 0, 4), chunk("sender-endpoint"), false, 4));
    try allocator.advance(2);

    const expired_registration = MessageEnvelope.init(chunk("sender-endpoint"), chunk("receiver-endpoint"), chunk("message-definition"), chunk("view-a"), 4);
    try testing.expectError(error.Expired, registry.route(allocator, expired_registration, view));

    const expired_envelope = MessageEnvelope.init(chunk("sender-endpoint"), chunk("receiver-endpoint"), chunk("message-definition"), chunk("view-a"), 1);
    try testing.expectError(error.Expired, registry.route(allocator, expired_envelope, view));
}
