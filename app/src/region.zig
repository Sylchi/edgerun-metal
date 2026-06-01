pub const Region = struct {
    base: []u8,

    pub fn len(self: Region) usize {
        return self.base.len;
    }

    pub fn end(self: Region) usize {
        return @intFromPtr(self.base.ptr) + self.base.len;
    }

    pub fn canAppendSuffix(self: Region, suffix: Region) bool {
        return self.end() == @intFromPtr(suffix.base.ptr);
    }

    pub fn appendSuffix(self: *Region, suffix: Region) bool {
        if (!self.canAppendSuffix(suffix)) return false;
        self.base = self.base.ptr[0 .. self.base.len + suffix.base.len];
        return true;
    }

    pub fn split(self: *Region, size: usize) ?Region {
        if (size > self.base.len) return null;

        const child_start = self.base.len - size;
        const child = self.base[child_start..];
        self.base = self.base[0..child_start];
        return .{ .base = child };
    }

    pub fn takePrefix(self: *Region, size: usize) ?Region {
        if (size > self.base.len) return null;

        const child = self.base[0..size];
        self.base = self.base[size..];
        return .{ .base = child };
    }

    pub fn zero(self: Region) void {
        @memset(self.base, 0);
    }

    pub fn contains(self: Region, slice: []const u8) bool {
        if (slice.len == 0) return false;
        const start = @intFromPtr(self.base.ptr);
        const region_end = start + self.base.len;
        const slice_start = @intFromPtr(slice.ptr);
        const slice_end = slice_start + slice.len;
        return start <= slice_start and slice_end <= region_end;
    }

    pub fn offsetOf(self: Region, slice: []const u8) ?usize {
        if (!self.contains(slice)) return null;
        return @intFromPtr(slice.ptr) - @intFromPtr(self.base.ptr);
    }
};

test "split transfers ownership out of parent" {
    var memory: [16]u8 = undefined;
    var parent = Region{ .base = &memory };
    const child = parent.split(6).?;

    if (parent.len() != 10) return error.TestExpectedEqual;
    if (child.len() != 6) return error.TestExpectedEqual;
}

test "append suffix reclaims adjacent split region" {
    var memory: [16]u8 = undefined;
    var parent = Region{ .base = &memory };
    const child = parent.split(6).?;

    if (!parent.appendSuffix(child)) return error.TestExpectedTrue;
    if (parent.len() != 16) return error.TestExpectedEqual;
}

test "region reports contained slice offset" {
    var memory: [16]u8 = undefined;
    const region = Region{ .base = &memory };
    const slice = memory[4..12];

    if (!region.contains(slice)) return error.TestExpectedTrue;
    if (region.offsetOf(slice).? != 4) return error.TestExpectedEqual;
    if (region.contains(&.{})) return error.TestExpectedFalse;
}
