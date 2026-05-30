const std = @import("std");
const linux = std.os.linux;
const sdk = @import("sdk.zig");
const store = @import("store.zig");

const bench_profiles = sdk.profiles;
const setup_iterations = sdk.benchmark_iterations * 4;
const simulation_iterations = sdk.benchmark_iterations;

pub fn main() !void {
    var memory: [sdk.max_parent_memory_bytes]u8 = undefined;
    var storage_bytes: [sdk.max_parent_storage_bytes]u8 = undefined;
    var slots: [sdk.max_parent_slots]store.Blob = undefined;
    var object_bytes: [sdk.canonical_object_buffer_bytes]u8 = undefined;
    var checksum: u64 = 0xcbf29ce484222325;

    std.debug.print("sdk bench\n", .{});
    for (bench_profiles) |profile| {
        const config = sdk.configForProfile(profile);

        const setup_start = nowNs();
        var setup_index: usize = 0;
        while (setup_index < setup_iterations) : (setup_index += 1) {
            const node = try sdk.setupNode(config);
            checksum = mixHash(checksum, node.ids.app.id.bytes);
        }
        const setup_ns = nowNs() - setup_start;

        const simulation_start = nowNs();
        var simulation_index: usize = 0;
        while (simulation_index < simulation_iterations) : (simulation_index += 1) {
            const result = try sdk.simulate(config, .{
                .memory = &memory,
                .storage = &storage_bytes,
                .slots = &slots,
                .object = &object_bytes,
            });
            checksum = mixHash(checksum, result.object_id);
        }
        const simulation_ns = nowNs() - simulation_start;

        std.debug.print(
            \\  profile: {s}
            \\    setup: {d} iterations in {d} ns ({d} ns/setup)
            \\    simulate: {d} iterations in {d} ns ({d} ns/sim)
            \\    parent memory/storage/slots: {d}/{d}/{d}
            \\    child memory/storage/slots: {d}/{d}/{d}
            \\
        , .{
            sdk.profileName(profile),
            setup_iterations,
            setup_ns,
            setup_ns / setup_iterations,
            simulation_iterations,
            simulation_ns,
            simulation_ns / simulation_iterations,
            config.resources.parent_memory_bytes,
            config.resources.parent_storage_bytes,
            config.resources.parent_storage_slots,
            config.resources.child_memory_bytes,
            config.resources.child_storage_bytes,
            config.resources.child_storage_slots,
        });
    }
    std.debug.print("  checksum: 0x{x}\n", .{checksum});
}

fn nowNs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn mixHash(seed: u64, value: [sdk.identity_hash_size]u8) u64 {
    var sum = seed;
    for (value) |byte| {
        sum = (sum ^ byte) *% 0x100000001b3;
    }
    return sum;
}
