const bytes = @import("../bytes.zig");
const boot_resource_map = @import("../boot_resource_map.zig");
const data_chunk = @import("data_chunk.zig");
const resource_contract = @import("resource_contract.zig");

pub const page_size: u64 = boot_resource_map.page_size;
pub const ResourceIdStorage = boot_resource_map.ResourceIdStorage;

pub const Error = error{
    BadArgument,
    Duplicate,
    NoSpace,
    OutOfBounds,
};

pub const Resource = struct {
    id: data_chunk.DataChunk,
    kind: resource_contract.ResourceKind,
    bounds: resource_contract.Bounds,

    pub fn init(id: data_chunk.DataChunk, kind: resource_contract.ResourceKind, bounds: resource_contract.Bounds) Resource {
        return .{
            .id = id,
            .kind = kind,
            .bounds = bounds,
        };
    }

    pub fn valid(self: Resource) bool {
        return self.id.valid() and self.id.length != 0 and self.bounds.valid();
    }

    pub fn contains(self: Resource, requested: resource_contract.Bounds) bool {
        if (!requested.valid()) return false;
        const requested_end = checkedEnd(requested.offset, requested.length) orelse return false;
        const resource_end = checkedEnd(self.bounds.offset, self.bounds.length) orelse return false;
        return requested.offset >= self.bounds.offset and requested_end <= resource_end;
    }
};

pub const Inventory = struct {
    resources: []Resource,
    len: usize = 0,

    pub fn init(resources: []Resource) Inventory {
        return .{ .resources = resources };
    }

    pub fn add(self: *Inventory, resource: Resource) Error!void {
        if (!resource.valid()) return error.BadArgument;
        if (self.find(resource.id)) |_| return error.Duplicate;
        if (self.len == self.resources.len) return error.NoSpace;
        self.resources[self.len] = resource;
        self.len += 1;
    }

    pub fn contractFits(self: Inventory, contract: resource_contract.Contract) bool {
        const resource = self.find(contract.resource) orelse return false;
        return resource.kind == contract.kind and resource.contains(contract.bounds);
    }

    pub fn requireContractFits(self: Inventory, contract: resource_contract.Contract) Error!void {
        if (!contract.valid()) return error.BadArgument;
        if (!self.contractFits(contract)) return error.OutOfBounds;
    }

    pub fn find(self: Inventory, id: data_chunk.DataChunk) ?Resource {
        for (self.resources[0..self.len]) |resource| {
            if (sameChunk(resource.id, id)) return resource;
        }
        return null;
    }
};

pub fn addBootResourceMap(inventory: *Inventory, map: boot_resource_map.Map, id_storage: []ResourceIdStorage) Error!void {
    if (id_storage.len < map.memory_regions.len) return error.NoSpace;
    for (map.memory_regions, 0..) |region, index| {
        const id_bytes = boot_resource_map.writeMemoryResourceId(index, &id_storage[index]) orelse return error.NoSpace;
        const resource = memoryRegionToResource(region, data_chunk.DataChunk.init(id_bytes)) orelse continue;
        try inventory.add(resource);
    }
}

pub fn memoryRegionToResource(region: boot_resource_map.MemoryRegion, id: data_chunk.DataChunk) ?Resource {
    if (!region.usable()) return null;
    const length = region.byteLength() orelse return null;
    return Resource.init(id, .memory, resource_contract.Bounds.init(region.physical_start, length));
}

pub const AppMemoryPlan = struct {
    app: data_chunk.DataChunk,
    public_contract: resource_contract.Contract,
    private_contract: resource_contract.Contract,

    pub fn init(app: data_chunk.DataChunk, public_contract: resource_contract.Contract, private_contract: resource_contract.Contract) AppMemoryPlan {
        return .{
            .app = app,
            .public_contract = public_contract,
            .private_contract = private_contract,
        };
    }

    pub fn valid(self: AppMemoryPlan) bool {
        return self.app.valid() and
            self.app.length != 0 and
            self.public_contract.valid() and
            self.private_contract.valid() and
            sameChunk(self.public_contract.app, self.app) and
            sameChunk(self.private_contract.app, self.app) and
            self.public_contract.kind == .memory and
            self.private_contract.kind == .memory and
            (!sameChunk(self.public_contract.resource, self.private_contract.resource) or
                !overlap(self.public_contract.bounds, self.private_contract.bounds));
    }

    pub fn fits(self: AppMemoryPlan, inventory: Inventory) bool {
        return self.valid() and
            inventory.contractFits(self.public_contract) and
            inventory.contractFits(self.private_contract);
    }
};

fn overlap(left: resource_contract.Bounds, right: resource_contract.Bounds) bool {
    const left_end = checkedEnd(left.offset, left.length) orelse return true;
    const right_end = checkedEnd(right.offset, right.length) orelse return true;
    return left.offset < right_end and right.offset < left_end;
}

fn checkedEnd(offset: u64, length: u64) ?u64 {
    return @import("std").math.add(u64, offset, length) catch null;
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and bytes.eql(left.body(), right.body());
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

test "resource inventory defines boot resource universe and validates contracts" {
    const testing = @import("std").testing;
    var resources: [2]Resource = undefined;
    var inventory = Inventory.init(&resources);
    try inventory.add(Resource.init(chunk("memory-bank-0"), .memory, resource_contract.Bounds.init(0x100000, 0x100000)));
    try inventory.add(Resource.init(chunk("cpu-slot-0"), .cpu, resource_contract.Bounds.init(0, 1)));

    const memory_contract = resource_contract.Contract.init(chunk("contract-memory"), chunk("app-a"), chunk("memory-bank-0"), .memory, 10, 20, resource_contract.Bounds.init(0x101000, 0x2000), resource_contract.Pattern.exclusive());
    const cpu_contract = resource_contract.Contract.init(chunk("contract-cpu"), chunk("app-a"), chunk("cpu-slot-0"), .cpu, 10, 20, resource_contract.Bounds.init(0, 1), resource_contract.Pattern.periodic(1, 4));
    const wrong_kind = resource_contract.Contract.init(chunk("contract-wrong"), chunk("app-a"), chunk("cpu-slot-0"), .memory, 10, 20, resource_contract.Bounds.init(0, 1), resource_contract.Pattern.exclusive());
    const out_of_bounds = resource_contract.Contract.init(chunk("contract-oob"), chunk("app-a"), chunk("memory-bank-0"), .memory, 10, 20, resource_contract.Bounds.init(0x1ff000, 0x2000), resource_contract.Pattern.exclusive());

    try testing.expect(inventory.contractFits(memory_contract));
    try testing.expect(inventory.contractFits(cpu_contract));
    try testing.expect(!inventory.contractFits(wrong_kind));
    try testing.expect(!inventory.contractFits(out_of_bounds));
    try testing.expectError(error.OutOfBounds, inventory.requireContractFits(out_of_bounds));
}

test "app memory plan requires public and private regions allocated up front" {
    const testing = @import("std").testing;
    var resources: [1]Resource = undefined;
    var inventory = Inventory.init(&resources);
    try inventory.add(Resource.init(chunk("memory-bank-0"), .memory, resource_contract.Bounds.init(0, 4096)));

    const public_contract = resource_contract.Contract.init(chunk("public-memory"), chunk("app-a"), chunk("memory-bank-0"), .memory, 1, 100, resource_contract.Bounds.init(0, 1024), resource_contract.Pattern.exclusive());
    const private_contract = resource_contract.Contract.init(chunk("private-memory"), chunk("app-a"), chunk("memory-bank-0"), .memory, 1, 100, resource_contract.Bounds.init(1024, 2048), resource_contract.Pattern.exclusive());
    const plan = AppMemoryPlan.init(chunk("app-a"), public_contract, private_contract);

    try testing.expect(plan.valid());
    try testing.expect(plan.fits(inventory));

    const overlapping_private = resource_contract.Contract.init(chunk("private-memory"), chunk("app-a"), chunk("memory-bank-0"), .memory, 1, 100, resource_contract.Bounds.init(512, 2048), resource_contract.Pattern.exclusive());
    try testing.expect(!AppMemoryPlan.init(chunk("app-a"), public_contract, overlapping_private).valid());
}

test "boot resource map exposes only usable memory as resource blocks" {
    const testing = @import("std").testing;
    var resources: [2]Resource = undefined;
    var inventory = Inventory.init(&resources);
    var id_storage: [4]ResourceIdStorage = undefined;

    const regions = [_]boot_resource_map.MemoryRegion{
        boot_resource_map.MemoryRegion.init(.usable, 0x100000, 2),
        boot_resource_map.MemoryRegion.init(.firmware, 0x200000, 2),
        boot_resource_map.MemoryRegion.init(.mmio, 0xfed40000, 1),
        boot_resource_map.MemoryRegion.init(.usable, 0x300000, 1),
    };
    const map = boot_resource_map.Map{
        .memory_regions = &regions,
        .verifier_kind = .software_p256_sha256,
    };

    try addBootResourceMap(&inventory, map, &id_storage);

    try testing.expectEqual(@as(usize, 2), inventory.len);
    try testing.expectEqual(@as(u64, 0x100000), inventory.resources[0].bounds.offset);
    try testing.expectEqual(@as(u64, page_size * 2), inventory.resources[0].bounds.length);
    try testing.expectEqual(@as(u64, 0x300000), inventory.resources[1].bounds.offset);
    try testing.expectEqualStrings("boot-memory-0000000000000000", inventory.resources[0].id.body());
    try testing.expectEqualStrings("boot-memory-0000000000000003", inventory.resources[1].id.body());
}

test "boot resource map rejects overflowing physical ranges" {
    const testing = @import("std").testing;
    var resources: [1]Resource = undefined;
    var inventory = Inventory.init(&resources);
    var id_storage: [1]ResourceIdStorage = undefined;
    const regions = [_]boot_resource_map.MemoryRegion{
        boot_resource_map.MemoryRegion.init(.usable, 0, @import("std").math.maxInt(u64)),
    };
    const map = boot_resource_map.Map{
        .memory_regions = &regions,
        .verifier_kind = .software_p256_sha256,
    };

    try addBootResourceMap(&inventory, map, &id_storage);
    try testing.expectEqual(@as(usize, 0), inventory.len);
}
