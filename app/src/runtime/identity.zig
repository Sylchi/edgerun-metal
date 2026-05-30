const std = @import("std");
const identity_core = @import("../identity.zig");
const clock = @import("../clock.zig");
const state = @import("state.zig");

pub fn initialEntropyPool() [state.entropy_pool_size]u8 {
    return state.initial_entropy_pool;
}

pub fn mixInteractionEntropy(event: state.EntropyEvent, x: f32, y: f32) void {
    state.entropy_event_count +%= 1;
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update("edgerun:zig:wasm-app:interaction-event:v1");
    hasher.update(&state.entropy_pool);
    var record: [21]u8 = undefined;
    record[0] = @intFromEnum(event);
    writeU64(record[1..9], state.entropy_event_count);
    writeU32(record[9..13], @bitCast(x));
    writeU32(record[13..17], @bitCast(y));
    writeU32(record[17..21], @as(u32, @truncate(state.last_command_count)));
    hasher.update(&record);
    hasher.final(&state.entropy_pool);
}

pub fn generateEphemeralIdentity() !void {
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update("edgerun:zig:wasm-app:ephemeral-ed25519-seed:v1");
    hasher.update(&state.entropy_pool);
    var event_bytes: [8]u8 = undefined;
    writeU64(&event_bytes, state.entropy_event_count);
    hasher.update(&event_bytes);
    hasher.final(&state.ephemeral_seed);

    const keypair = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic(state.ephemeral_seed);
    state.ephemeral_public_key = keypair.public_key.toBytes();
    const source = identity_core.Source.prepare(.ed25519_public, &state.ephemeral_public_key) orelse return error.Identity;
    const value = identity_core.Identity.init(.ephemeral, source, epochFromPublicKey(&state.ephemeral_public_key)) orelse return error.Identity;
    if (!value.valid()) return error.Identity;
    state.ephemeral_identity_id = value.id.bytes;
    writePublicIdentityText(&state.ephemeral_identity_id);
    state.ephemeral_identity_ready = true;
}

fn epochFromPublicKey(public_key: *const [identity_core.ed25519_public_size]u8) clock.Stamp {
    var keeper: [clock.keeper_id_size]u8 = undefined;
    std.crypto.hash.Blake3.hash(public_key, &keeper, .{});
    return .{ .keeper = .{ .bytes = keeper } };
}

pub fn publicIdentityText() []const u8 {
    if (!state.ephemeral_identity_ready) return "click reveal";
    return state.public_identity_text[0..];
}

fn writePublicIdentityText(id: *const [identity_core.id_size]u8) void {
    @memcpy(state.public_identity_text[0..state.public_identity_prefix.len], state.public_identity_prefix);
    writeHex(state.public_identity_text[state.public_identity_prefix.len..], id);
}

fn writeHex(out: []u8, value: []const u8) void {
    std.debug.assert(out.len == value.len * 2);
    for (value, 0..) |byte, index| {
        out[index * 2] = hexChar(byte >> 4);
        out[index * 2 + 1] = hexChar(byte & 0x0f);
    }
}

fn hexChar(value: u8) u8 {
    return switch (value) {
        0...9 => '0' + value,
        10...15 => 'a' + value - 10,
        else => unreachable,
    };
}

fn writeU64(out: []u8, value: u64) void {
    std.debug.assert(out.len == 8);
    for (0..8) |index| out[index] = @intCast((value >> @intCast(index * 8)) & 0xff);
}

fn writeU32(out: []u8, value: u32) void {
    std.debug.assert(out.len == 4);
    for (0..4) |index| out[index] = @intCast((value >> @intCast(index * 8)) & 0xff);
}
