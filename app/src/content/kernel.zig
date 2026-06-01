const bytes = @import("../bytes.zig");
const data_chunk = @import("data_chunk.zig");

pub const Error = error{
    BadArgument,
    Duplicate,
    Expired,
    NoSpace,
    NotFound,
    OutOfBounds,
};

pub const Allocation = struct {
    id: data_chunk.DataChunk,
    owner: data_chunk.DataChunk,
    capacity: u64,

    pub fn init(id: data_chunk.DataChunk, owner: data_chunk.DataChunk, capacity: u64) Allocation {
        return .{
            .id = id,
            .owner = owner,
            .capacity = capacity,
        };
    }

    pub fn valid(self: Allocation) bool {
        return self.id.valid() and
            self.id.length != 0 and
            self.owner.valid() and
            self.owner.length != 0 and
            self.capacity != 0;
    }

    pub fn contains(self: Allocation, range: AddressRange) bool {
        if (!sameChunk(self.id, range.allocation_id)) return false;
        const end = checkedEnd(range.offset, range.length) orelse return false;
        return end <= self.capacity;
    }
};

pub const AddressRange = struct {
    allocation_id: data_chunk.DataChunk,
    offset: u64,
    length: u64,

    pub fn init(allocation_id: data_chunk.DataChunk, offset: u64, length: u64) AddressRange {
        return .{
            .allocation_id = allocation_id,
            .offset = offset,
            .length = length,
        };
    }

    pub fn valid(self: AddressRange) bool {
        return self.allocation_id.valid() and self.allocation_id.length != 0 and self.length != 0;
    }
};

pub const MemoryView = struct {
    id: data_chunk.DataChunk,
    source: AddressRange,
    reader: data_chunk.DataChunk,
    writable: bool = false,
    valid_until_tick: u64,

    pub fn init(id: data_chunk.DataChunk, source: AddressRange, reader: data_chunk.DataChunk, writable: bool, valid_until_tick: u64) MemoryView {
        return .{
            .id = id,
            .source = source,
            .reader = reader,
            .writable = writable,
            .valid_until_tick = valid_until_tick,
        };
    }

    pub fn valid(self: MemoryView) bool {
        return nonempty(self.id) and self.source.valid() and nonempty(self.reader);
    }
};

pub const Allocator = struct {
    allocations: []Allocation,
    len: usize = 0,
    clock_tick: u64 = 0,

    pub fn init(allocations: []Allocation) Allocator {
        return .{
            .allocations = allocations,
        };
    }

    pub fn advance(self: *Allocator, amount: u64) Error!void {
        if (amount == 0) return error.BadArgument;
        self.clock_tick = checkedEnd(self.clock_tick, amount) orelse return error.BadArgument;
    }

    pub fn addAllocation(self: *Allocator, allocation: Allocation) Error!void {
        if (!allocation.valid()) return error.BadArgument;
        if (self.findAllocation(allocation.id)) |_| return error.Duplicate;
        if (self.len == self.allocations.len) return error.NoSpace;
        self.allocations[self.len] = allocation;
        self.len += 1;
    }

    pub fn createView(self: Allocator, view: MemoryView) Error!MemoryView {
        if (!view.valid()) return error.BadArgument;
        if (self.clock_tick > view.valid_until_tick) return error.Expired;
        if (!self.rangeValid(view.source)) return error.OutOfBounds;
        return view;
    }

    pub fn canRead(self: Allocator, view: MemoryView, reader: data_chunk.DataChunk) bool {
        return view.valid() and
            sameChunk(view.reader, reader) and
            self.clock_tick <= view.valid_until_tick and
            self.rangeValid(view.source);
    }

    pub fn canWrite(self: Allocator, view: MemoryView, writer: data_chunk.DataChunk) bool {
        return view.writable and self.canRead(view, writer);
    }

    pub fn rangeValid(self: Allocator, range: AddressRange) bool {
        if (!range.valid()) return false;
        const allocation = self.findAllocation(range.allocation_id) orelse return false;
        return allocation.contains(range);
    }

    fn findAllocation(self: Allocator, allocation_id: data_chunk.DataChunk) ?Allocation {
        for (self.allocations[0..self.len]) |allocation| {
            if (sameChunk(allocation.id, allocation_id)) return allocation;
        }
        return null;
    }
};

fn checkedEnd(offset: u64, length: u64) ?u64 {
    const end = offset +% length;
    return if (end < offset) null else end;
}

fn nonempty(value: data_chunk.DataChunk) bool {
    return value.valid() and value.length != 0;
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and bytes.eql(left.body(), right.body());
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

test "kernel allocation id makes address ranges relative and bounded" {
    var allocation_slots: [1]Allocation = undefined;
    var allocator = Allocator.init(&allocation_slots);
    try allocator.addAllocation(Allocation.init(chunk("alloc-a"), chunk("app-a"), 16));

    if (!allocator.rangeValid(AddressRange.init(chunk("alloc-a"), 4, 8))) return error.TestExpectedTrue;
    if (allocator.rangeValid(AddressRange.init(chunk("alloc-a"), 12, 8))) return error.TestExpectedFalse;
    if (allocator.rangeValid(AddressRange.init(chunk("alloc-b"), 4, 8))) return error.TestExpectedFalse;
}

test "kernel creates time bounded memory views" {
    var allocation_slots: [2]Allocation = undefined;
    var allocator = Allocator.init(&allocation_slots);

    try allocator.addAllocation(Allocation.init(chunk("sender-allocation"), chunk("sender-app"), 64));
    try allocator.addAllocation(Allocation.init(chunk("receiver-allocation"), chunk("receiver-app"), 64));
    const view = try allocator.createView(MemoryView.init(chunk("view-a"), AddressRange.init(chunk("sender-allocation"), 8, 12), chunk("receiver-app"), false, 10));

    if (!allocator.canRead(view, chunk("receiver-app"))) return error.TestExpectedTrue;
    if (allocator.canRead(view, chunk("other-app"))) return error.TestExpectedFalse;
    if (allocator.canWrite(view, chunk("receiver-app"))) return error.TestExpectedFalse;
}

test "kernel rejects expired and out of bounds memory views" {
    var allocation_slots: [1]Allocation = undefined;
    var allocator = Allocator.init(&allocation_slots);

    try allocator.addAllocation(Allocation.init(chunk("sender-allocation"), chunk("sender-app"), 64));
    try allocator.advance(2);

    const expired = MemoryView.init(chunk("view-expired"), AddressRange.init(chunk("sender-allocation"), 0, 4), chunk("receiver-app"), false, 1);
    if (allocator.createView(expired)) |_| return error.TestExpectedError else |err| {
        if (err != error.Expired) return err;
    }

    const out_of_bounds = MemoryView.init(chunk("view-oob"), AddressRange.init(chunk("sender-allocation"), 60, 8), chunk("receiver-app"), false, 4);
    if (allocator.createView(out_of_bounds)) |_| return error.TestExpectedError else |err| {
        if (err != error.OutOfBounds) return err;
    }
}

test "kernel rejects duplicate allocation ids and unknown allocation views" {
    var allocation_slots: [2]Allocation = undefined;
    var allocator = Allocator.init(&allocation_slots);

    try allocator.addAllocation(Allocation.init(chunk("sender-allocation"), chunk("sender-app"), 64));
    if (allocator.addAllocation(Allocation.init(chunk("sender-allocation"), chunk("other-app"), 64))) return error.TestExpectedError else |err| {
        if (err != error.Duplicate) return err;
    }

    const unknown = MemoryView.init(chunk("view-unknown"), AddressRange.init(chunk("missing-allocation"), 0, 4), chunk("receiver-app"), false, 10);
    if (allocator.createView(unknown)) |_| return error.TestExpectedError else |err| {
        if (err != error.OutOfBounds) return err;
    }
}
