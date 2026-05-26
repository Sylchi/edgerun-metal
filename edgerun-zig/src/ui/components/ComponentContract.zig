const std = @import("std");

pub const Registration = struct {
    name: [:0]const u8,
    Payload: type,
};

pub fn registration(comptime name: [:0]const u8, comptime Payload: type) Registration {
    return .{ .name = name, .Payload = Payload };
}

pub fn payload(comptime registrations: anytype, comptime name: []const u8) type {
    comptime {
        @setEvalBranchQuota(10000);
        for (registrations) |entry| {
            if (std.mem.eql(u8, entry.name, name)) return entry.Payload;
        }
        @compileError("unknown component registration: " ++ name);
    }
}

pub fn assertMatches(comptime registrations: anytype, comptime Component: type) void {
    comptime {
        @setEvalBranchQuota(10000);
        const fields = @typeInfo(Component).@"union".fields;
        if (fields.len != registrations.len) @compileError("component union field count does not match registry");
        for (registrations, 0..) |entry, index| {
            const field = fields[index];
            if (!std.mem.eql(u8, field.name, entry.name)) {
                @compileError("component union field order/name does not match registry");
            }
            if (field.type != entry.Payload) {
                @compileError("component union field payload does not match registry");
            }
        }
    }
}
