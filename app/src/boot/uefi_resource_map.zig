const std = @import("std");
const uefi = std.os.uefi;
const boot_resource_map = @import("../boot_resource_map.zig");

pub const Error = error{
    NoSpace,
};

pub fn collectMemoryMap(
    boot_services: *const uefi.tables.BootServices,
    map_buffer: []align(@alignOf(uefi.tables.MemoryDescriptor)) u8,
    memory_regions: []boot_resource_map.MemoryRegion,
) Error!boot_resource_map.Map {
    const memory_map = boot_services.getMemoryMap(map_buffer) catch return error.NoSpace;
    var len: usize = 0;
    var iterator = memory_map.iterator();
    while (iterator.next()) |descriptor| {
        if (len == memory_regions.len) return error.NoSpace;
        memory_regions[len] = fromDescriptor(descriptor.*);
        len += 1;
    }
    return .{
        .memory_regions = memory_regions[0..len],
        .verifier_kind = .tpm_p256_sha256,
    };
}

pub fn fromDescriptor(descriptor: uefi.tables.MemoryDescriptor) boot_resource_map.MemoryRegion {
    return boot_resource_map.MemoryRegion.init(
        memoryKind(descriptor.type),
        descriptor.physical_start,
        descriptor.number_of_pages,
    );
}

pub fn memoryKind(memory_type: uefi.tables.MemoryType) boot_resource_map.MemoryKind {
    return switch (memory_type) {
        .conventional_memory => .usable,
        .loader_code, .loader_data, .boot_services_code, .boot_services_data => .firmware,
        .runtime_services_code, .runtime_services_data => .runtime,
        .acpi_reclaim_memory => .acpi_reclaim,
        .acpi_memory_nvs => .acpi_nvs,
        .memory_mapped_io, .memory_mapped_io_port_space => .mmio,
        .persistent_memory => .persistent,
        .reserved_memory_type, .unusable_memory, .unaccepted_memory => .unusable,
        else => .unknown,
    };
}

test "uefi adapter maps conventional memory to neutral usable memory" {
    const testing = @import("std").testing;
    const descriptor = uefi.tables.MemoryDescriptor{
        .type = .conventional_memory,
        .physical_start = 0x100000,
        .virtual_start = 0,
        .number_of_pages = 2,
        .attribute = @bitCast(@as(u64, 0)),
    };

    const region = fromDescriptor(descriptor);

    try testing.expectEqual(boot_resource_map.MemoryKind.usable, region.kind);
    try testing.expectEqual(@as(u64, 0x100000), region.physical_start);
    try testing.expectEqual(@as(u64, 2), region.page_count);
}

test "uefi adapter does not mark firmware or mmio as usable" {
    const testing = @import("std").testing;

    try testing.expectEqual(boot_resource_map.MemoryKind.firmware, memoryKind(.boot_services_data));
    try testing.expectEqual(boot_resource_map.MemoryKind.runtime, memoryKind(.runtime_services_data));
    try testing.expectEqual(boot_resource_map.MemoryKind.mmio, memoryKind(.memory_mapped_io));
}
