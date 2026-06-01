const bytes = @import("bytes.zig");

pub const keeper_id_size = 32;
pub const default_ticks_per_slot = 1024;
pub const default_slots_per_epoch = 1024;
pub const default_epochs_per_era = 1024;
pub const default_stride = 1;

pub const KeeperId = struct {
    bytes: [keeper_id_size]u8,

    pub fn valid(self: KeeperId) bool {
        return bytes.nonzero(&self.bytes);
    }

    pub fn eql(self: KeeperId, other: KeeperId) bool {
        return bytes.eql(&self.bytes, &other.bytes);
    }
};

pub const Stamp = struct {
    keeper: KeeperId,
    tick: u64 = 0,
    slot: u64 = 0,
    epoch: u64 = 0,
    era: u64 = 0,

    pub fn valid(self: Stamp) bool {
        return self.keeper.valid();
    }

    pub fn sameKeeper(self: Stamp, other: Stamp) bool {
        return self.keeper.eql(other.keeper);
    }

    pub fn order(self: Stamp, other: Stamp) i2 {
        const keeper_order = bytes.order(&self.keeper.bytes, &other.keeper.bytes);
        if (keeper_order != 0) return keeper_order;
        if (self.era != other.era) return if (self.era < other.era) -1 else 1;
        if (self.epoch != other.epoch) return if (self.epoch < other.epoch) -1 else 1;
        if (self.slot != other.slot) return if (self.slot < other.slot) -1 else 1;
        if (self.tick != other.tick) return if (self.tick < other.tick) -1 else 1;
        return 0;
    }
};

pub const Limits = struct {
    ticks_per_slot: u64 = default_ticks_per_slot,
    slots_per_epoch: u64 = default_slots_per_epoch,
    epochs_per_era: u64 = default_epochs_per_era,

    pub fn valid(self: Limits) bool {
        return isPowerOfTwo(self.ticks_per_slot) and
            isPowerOfTwo(self.slots_per_epoch) and
            isPowerOfTwo(self.epochs_per_era);
    }
};

pub const Modifier = struct {
    tick_stride: u64 = default_stride,

    pub fn valid(self: Modifier) bool {
        return self.tick_stride != 0;
    }
};

pub const Boundary = struct {
    slot: bool = false,
    epoch: bool = false,
    era: bool = false,
};

pub const Clock = struct {
    now: Stamp,
    limits: Limits,

    pub fn init(keeper: KeeperId, limits: Limits) ?Clock {
        if (!keeper.valid() or !limits.valid()) return null;
        return .{ .now = .{ .keeper = keeper }, .limits = limits };
    }

    pub fn advanceDefault(self: *Clock) ?Boundary {
        return self.advanceWith(.{});
    }

    pub fn advance(self: *Clock, stride: u64) ?Boundary {
        return self.advanceWith(.{ .tick_stride = stride });
    }

    pub fn advanceWith(self: *Clock, modifier: Modifier) ?Boundary {
        if (!self.limits.valid() or !modifier.valid()) return null;
        if (modifier.tick_stride > ~@as(u64, 0) - self.now.tick) return null;

        var next_era = self.now.era;
        var next_epoch = self.now.epoch;
        var next_slot = self.now.slot;
        var boundary = Boundary{};

        const total_ticks = self.now.tick + modifier.tick_stride;
        const next_tick = total_ticks & (self.limits.ticks_per_slot - 1);
        const slot_steps = total_ticks >> shiftForPowerOfTwo(self.limits.ticks_per_slot).?;
        if (slot_steps == 0) {
            self.now.tick = next_tick;
            return boundary;
        }
        if (slot_steps > ~@as(u64, 0) - next_slot) return null;

        const total_slots = next_slot + slot_steps;
        next_slot = total_slots & (self.limits.slots_per_epoch - 1);
        const epoch_steps = total_slots >> shiftForPowerOfTwo(self.limits.slots_per_epoch).?;
        boundary.slot = true;
        if (epoch_steps == 0) {
            self.now.tick = next_tick;
            self.now.slot = next_slot;
            return boundary;
        }
        if (epoch_steps > ~@as(u64, 0) - next_epoch) return null;

        const total_epochs = next_epoch + epoch_steps;
        next_epoch = total_epochs & (self.limits.epochs_per_era - 1);
        const era_steps = total_epochs >> shiftForPowerOfTwo(self.limits.epochs_per_era).?;
        boundary.epoch = true;
        if (era_steps == 0) {
            self.now.tick = next_tick;
            self.now.slot = next_slot;
            self.now.epoch = next_epoch;
            return boundary;
        }
        if (era_steps > ~@as(u64, 0) - next_era) return null;

        next_era += era_steps;
        self.now.tick = next_tick;
        self.now.slot = next_slot;
        self.now.epoch = next_epoch;
        self.now.era = next_era;
        boundary.era = true;
        return boundary;
    }
};

fn isPowerOfTwo(value: u64) bool {
    return value != 0 and (value & (value - 1)) == 0;
}

fn shiftForPowerOfTwo(value: u64) ?u6 {
    if (!isPowerOfTwo(value)) return null;
    return @intCast(@ctz(value));
}

test "clock advances deterministic boundaries" {
    const keeper = KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    var c = Clock.init(keeper, .{ .ticks_per_slot = 2, .slots_per_epoch = 2, .epochs_per_era = 2 }).?;

    try expect(!(c.advance(1).?).slot);
    try expect((c.advance(1).?).slot);
    try expectEqual(@as(u64, 1), c.now.slot);
}

test "clock advances arbitrary strides across epoch and era boundaries" {
    const keeper = KeeperId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 };
    var c = Clock.init(keeper, .{ .ticks_per_slot = 4, .slots_per_epoch = 4, .epochs_per_era = 4 }).?;

    const boundary = c.advance(4 * 4 * 4 + 5).?;
    try expect(boundary.slot);
    try expect(boundary.epoch);
    try expect(boundary.era);
    try expectEqual(@as(u64, 1), c.now.era);
    try expectEqual(@as(u64, 0), c.now.epoch);
    try expectEqual(@as(u64, 1), c.now.slot);
    try expectEqual(@as(u64, 1), c.now.tick);
}

test "clock rejects zero stride and overflow" {
    const keeper = KeeperId{ .bytes = [_]u8{3} ++ [_]u8{0} ** 31 };
    var c = Clock.init(keeper, .{ .ticks_per_slot = 2, .slots_per_epoch = 2, .epochs_per_era = 2 }).?;

    try expect(c.advance(0) == null);
    c.now.tick = ~@as(u64, 0);
    try expect(c.advance(1) == null);
}

fn expect(condition: bool) !void {
    if (!condition) return error.TestExpectedTrue;
}

fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    if (actual != expected) return error.TestExpectedEqual;
}
