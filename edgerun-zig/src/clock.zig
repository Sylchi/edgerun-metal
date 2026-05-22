const std = @import("std");
const bytes = @import("bytes.zig");

pub const keeper_id_size = 32;

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
    ticks_per_slot: u64 = 1024,
    slots_per_epoch: u64 = 1024,
    epochs_per_era: u64 = 1024,

    pub fn valid(self: Limits) bool {
        return isPowerOfTwo(self.ticks_per_slot) and
            isPowerOfTwo(self.slots_per_epoch) and
            isPowerOfTwo(self.epochs_per_era);
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

    pub fn advance(self: *Clock, stride: u64) ?Boundary {
        if (stride == 0) return null;
        const tick = self.now.tick +% stride;
        if (tick < self.now.tick) return null;

        self.now.tick = tick;
        var boundary = Boundary{};
        if (self.now.tick == self.limits.ticks_per_slot) {
            self.now.tick = 0;
            self.now.slot += 1;
            boundary.slot = true;
        }
        if (self.now.slot == self.limits.slots_per_epoch) {
            self.now.slot = 0;
            self.now.epoch += 1;
            boundary.epoch = true;
        }
        if (self.now.epoch == self.limits.epochs_per_era) {
            self.now.epoch = 0;
            self.now.era += 1;
            boundary.era = true;
        }
        return boundary;
    }
};

fn isPowerOfTwo(value: u64) bool {
    return value != 0 and (value & (value - 1)) == 0;
}

test "clock advances deterministic boundaries" {
    const keeper = KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    var c = Clock.init(keeper, .{ .ticks_per_slot = 2, .slots_per_epoch = 2, .epochs_per_era = 2 }).?;

    try std.testing.expect(!(c.advance(1).?).slot);
    try std.testing.expect((c.advance(1).?).slot);
    try std.testing.expectEqual(@as(u64, 1), c.now.slot);
}
