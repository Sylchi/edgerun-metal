const std = @import("er_std");
const bytes = @import("bytes.zig");
const sdk = @import("sdk.zig");
const store = @import("store.zig");

const UsageError = error{
    BadCommand,
    BadProfile,
    ExtraArgument,
};

pub fn main(init: std.process.Init) !void {
    const profile = try parseArgs(init.minimal.args);
    var memory: [sdk.max_parent_memory_bytes]u8 = undefined;
    var storage_bytes: [sdk.max_parent_storage_bytes]u8 = undefined;
    var slots: [sdk.max_parent_slots]store.Blob = undefined;
    var object_bytes: [sdk.canonical_object_buffer_bytes]u8 = undefined;

    const result = try sdk.simulate(sdk.configForProfile(profile), .{
        .memory = &memory,
        .storage = &storage_bytes,
        .slots = &slots,
        .object = &object_bytes,
    });

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};
    try out.print("profile={s}\n", .{profileName(profile)});
    try printHash(out, "keeper", result.node.clock.now.keeper.bytes);
    try printHash(out, "user", result.node.ids.user.id.bytes);
    try printHash(out, "device", result.node.ids.device.id.bytes);
    try printHash(out, "allocator", result.node.ids.allocator.id.bytes);
    try printHash(out, "root_app", result.node.ids.root_app.id.bytes);
    try printHash(out, "app", result.node.ids.app.id.bytes);
    try printHash(out, "object", result.object_id);
    try out.print("app_storage_slots={d}\n", .{result.app_storage.slot_count});
    try out.print("app_storage_remaining={d}\n", .{result.app_storage.data_remaining});
}

fn parseArgs(args_value: std.process.Args) !sdk.Profile {
    var args = std.process.Args.Iterator.init(args_value);
    _ = args.next();
    const command = args.next() orelse return .standard;
    if (!bytes.eql(command, "simulate")) return UsageError.BadCommand;
    const profile_arg = args.next() orelse return .standard;
    if (args.next() != null) return UsageError.ExtraArgument;
    return parseProfile(profile_arg);
}

fn printHash(out: *std.Io.Writer, label: []const u8, value: [sdk.identity_hash_size]u8) !void {
    const encoded = std.fmt.bytesToHex(value, .lower);
    try out.print("{s}={s}\n", .{ label, &encoded });
}

fn parseProfile(value: []const u8) !sdk.Profile {
    if (bytes.eql(value, "minimal")) return .minimal;
    if (bytes.eql(value, "standard")) return .standard;
    if (bytes.eql(value, "ui")) return .ui;
    return UsageError.BadProfile;
}

fn profileName(profile: sdk.Profile) []const u8 {
    return switch (profile) {
        .minimal => "minimal",
        .standard => "standard",
        .ui => "ui",
    };
}
