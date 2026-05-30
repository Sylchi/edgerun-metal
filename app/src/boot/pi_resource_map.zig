const boot_resource_map = @import("../boot_resource_map.zig");

pub const Error = error{
    BadArgument,
    NoSpace,
};

pub fn fromArmMemory(
    physical_start: u64,
    byte_len: u64,
    memory_regions: []boot_resource_map.MemoryRegion,
) Error!boot_resource_map.Map {
    if (memory_regions.len == 0 or byte_len == 0 or byte_len % boot_resource_map.page_size != 0) return error.BadArgument;
    memory_regions[0] = boot_resource_map.MemoryRegion.init(
        .usable,
        physical_start,
        byte_len / boot_resource_map.page_size,
    );
    return .{
        .memory_regions = memory_regions[0..1],
        .verifier_kind = .software_p256_sha256,
    };
}

test "pi adapter produces software-verifier boot resource map" {
    const testing = @import("std").testing;
    var regions: [1]boot_resource_map.MemoryRegion = undefined;

    const map = try fromArmMemory(0x8000, boot_resource_map.page_size * 8, &regions);

    try testing.expectEqual(boot_resource_map.VerifierKind.software_p256_sha256, map.verifier_kind);
    try testing.expectEqual(@as(usize, 1), map.memory_regions.len);
    try testing.expectEqual(boot_resource_map.MemoryKind.usable, map.memory_regions[0].kind);
    try testing.expectEqual(@as(u64, 0x8000), map.memory_regions[0].physical_start);
    try testing.expectEqual(@as(u64, 8), map.memory_regions[0].page_count);
}

test "pi adapter rejects unaligned memory regions" {
    const testing = @import("std").testing;
    var regions: [1]boot_resource_map.MemoryRegion = undefined;

    try testing.expectError(error.BadArgument, fromArmMemory(0x8000, boot_resource_map.page_size + 1, &regions));
}
