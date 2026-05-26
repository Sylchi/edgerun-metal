const boot_resource_map = @import("boot_resource_map.zig");
const pi_resource_map = @import("boot/pi_resource_map.zig");
const resource_contract = @import("content/resource_contract.zig");
const resource_inventory = @import("content/resource_inventory.zig");
const tpm_verifier = @import("content/tpm_verifier.zig");

pub const max_boot_memory_regions = 1;
pub const software_verifier_probe = "pi-zero-w-v1.1-software-verifier";

pub const Error = pi_resource_map.Error || resource_inventory.Error || tpm_verifier.Error || error{
    BadVerifier,
    EmptyInventory,
};

pub const Runtime = struct {
    memory_regions: [max_boot_memory_regions]boot_resource_map.MemoryRegion = undefined,
    resources: [max_boot_memory_regions]resource_inventory.Resource = undefined,
    id_storage: [max_boot_memory_regions]resource_inventory.ResourceIdStorage = undefined,
    inventory: resource_inventory.Inventory = undefined,
    software_executor: tpm_verifier.SoftwareExecutor = tpm_verifier.SoftwareExecutor.init(),

    pub fn initFromArmMemory(self: *Runtime, physical_start: u64, byte_len: u64) Error!void {
        const map = try pi_resource_map.fromArmMemory(physical_start, byte_len, &self.memory_regions);
        if (map.verifier_kind != .software_p256_sha256) return error.BadVerifier;

        self.inventory = resource_inventory.Inventory.init(&self.resources);
        try resource_inventory.addBootResourceMap(&self.inventory, map, &self.id_storage);
        if (self.inventory.len == 0) return error.EmptyInventory;

        self.software_executor = tpm_verifier.SoftwareExecutor.init();
        _ = try self.softwareVerifier().hash(software_verifier_probe);
    }

    pub fn softwareVerifier(self: *Runtime) tpm_verifier.Verifier(tpm_verifier.SoftwareExecutor) {
        return tpm_verifier.Verifier(tpm_verifier.SoftwareExecutor).init(&self.software_executor);
    }

    pub fn bootMemoryResource(self: Runtime) resource_inventory.Resource {
        return self.inventory.resources[0];
    }

    pub fn contractFits(self: Runtime, contract: resource_contract.Contract) bool {
        return self.inventory.contractFits(contract);
    }
};

test "Pi kernel path turns ARM memory into software-verified resource inventory" {
    const testing = @import("std").testing;
    var runtime = Runtime{};

    try runtime.initFromArmMemory(0x8000, boot_resource_map.page_size * 16);

    try testing.expectEqual(@as(usize, 1), runtime.inventory.len);
    try testing.expectEqual(boot_resource_map.MemoryKind.usable, runtime.memory_regions[0].kind);
    try testing.expectEqual(resource_contract.ResourceKind.memory, runtime.bootMemoryResource().kind);
    try testing.expectEqual(@as(u64, 0x8000), runtime.bootMemoryResource().bounds.offset);
    try testing.expectEqual(@as(u64, boot_resource_map.page_size * 16), runtime.bootMemoryResource().bounds.length);

    const digest = try runtime.softwareVerifier().hash(software_verifier_probe);
    try testing.expect(digest[0] != 0 or digest[1] != 0);
}

test "Pi kernel path rejects bad ARM memory handoff" {
    const testing = @import("std").testing;
    var runtime = Runtime{};

    try testing.expectError(error.BadArgument, runtime.initFromArmMemory(0x8000, boot_resource_map.page_size + 1));
    try testing.expectError(error.BadArgument, runtime.initFromArmMemory(0x8000, 0));
}
