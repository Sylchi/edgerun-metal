const BoundedArena = @import("../arena.zig").BoundedArena;
const Region = @import("../region.zig").Region;
const app_mod = @import("../app.zig");
const bytes = @import("../bytes.zig");
const clock = @import("../clock.zig");
const data_chunk = @import("data_chunk.zig");
const grant = @import("../grant.zig");
const identity = @import("../identity.zig");
const preimage = @import("../preimage.zig");
const resource_contract = @import("resource_contract.zig");
const resource_inventory = @import("resource_inventory.zig");
const store = @import("../store.zig");
const wasm = @import("../wasm/root.zig");
const wasm_app = @import("../wasm/app.zig");

const App = app_mod.App;

pub const Error = resource_contract.Error || resource_inventory.Error || wasm.Error || error{
    BadArgument,
    Corrupt,
    NoMemory,
};

pub const Runtime = struct {
    inventory: resource_inventory.Inventory,
    schedule: resource_contract.Schedule,
    boot_memory_resource: resource_inventory.Resource,
    boot_memory: []u8,

    pub fn init(
        inventory: resource_inventory.Inventory,
        schedule: resource_contract.Schedule,
        boot_memory_resource: resource_inventory.Resource,
        boot_memory: []u8,
    ) Runtime {
        return .{
            .inventory = inventory,
            .schedule = schedule,
            .boot_memory_resource = boot_memory_resource,
            .boot_memory = boot_memory,
        };
    }

    pub fn runWasmI64(self: *Runtime, plan: LaunchPlan, wasm_bytes: []const u8, export_name: []const u8) Error!RunResult {
        var result: RunResult = undefined;
        try self.runWasmI64Into(plan, wasm_bytes, export_name, &result);
        return result;
    }

    pub fn runWasmI64Into(self: *Runtime, plan: LaunchPlan, wasm_bytes: []const u8, export_name: []const u8, out: *RunResult) Error!void {
        var storage: wasm.ExecutionStorage = .{};
        try self.runWasmI64IntoWithStorage(plan, wasm_bytes, export_name, &storage, out);
    }

    pub fn runWasmI64WithStorage(self: *Runtime, plan: LaunchPlan, wasm_bytes: []const u8, export_name: []const u8, storage: *wasm.ExecutionStorage) Error!RunResult {
        var result: RunResult = undefined;
        try self.runWasmI64IntoWithStorage(plan, wasm_bytes, export_name, storage, &result);
        return result;
    }

    pub fn runWasmI64IntoWithStorage(self: *Runtime, plan: LaunchPlan, wasm_bytes: []const u8, export_name: []const u8, storage: *wasm.ExecutionStorage, out: *RunResult) Error!void {
        var scratch: Scratch = undefined;
        try self.runWasmI64IntoWithStorageAndScratch(plan, wasm_bytes, export_name, storage, &scratch, out);
    }

    pub fn runWasmI64IntoWithStorageAndScratch(self: *Runtime, plan: LaunchPlan, wasm_bytes: []const u8, export_name: []const u8, storage: *wasm.ExecutionStorage, scratch: *Scratch, out: *RunResult) Error!void {
        try plan.validate(self.inventory);
        try self.schedule.installChecked(self.inventory, plan.public_contract);
        errdefer self.schedule.len -= 1;
        try self.schedule.installChecked(self.inventory, plan.private_contract);

        const app_memory = self.memoryForContract(plan.private_contract) orelse return error.NoMemory;
        scratch.slots = .{};
        scratch.app = App.initAllocated(
            plan.app,
            BoundedArena.init(Region{ .base = app_memory }),
            store.Store.init(Region{ .base = app_memory[0..0] }, &scratch.slots),
            plan.allocation,
        ) orelse return error.BadArgument;

        scratch.spawn_receipt = grant.spawnReceiptAllocated(
            plan.parent,
            plan.app,
            plan.clock_start,
            plan.allocation.memory_bytes,
            plan.allocation.storage_bytes,
            plan.allocation.storage_slots,
            plan.allocation.execution_ticks,
            plan.allocation.route_handles,
            plan.allocation.device_handles,
            plan.allocation.route_handle,
            plan.allocation.device_handle,
        ) orelse return error.BadArgument;

        scratch.value = try wasm_app.executeExportI64ArgsWithStorage(&scratch.app, wasm_bytes, export_name, &.{}, storage);
        scratch.output = wasm_app.outputHashI64(scratch.value);
        if (scratch.app.executionRemaining() > plan.allocation.execution_ticks) return error.Corrupt;
        const receipt = App.WorkReceipt{
            .parent = plan.parent.id,
            .app = scratch.app.id.id,
            .input = plan.input,
            .output = scratch.output,
            .app_hash = plan.app_hash,
            .manifest = plan.manifest,
            .clock_start = plan.clock_start,
            .clock_end = plan.clock_end,
            .allocation = plan.allocation,
            .execution_used = plan.allocation.execution_ticks - scratch.app.executionRemaining(),
            .spawn_receipt = scratch.spawn_receipt,
        };
        if (!receipt.valid()) return error.Corrupt;

        out.* = .{
            .value = scratch.value,
            .output = scratch.output,
            .receipt = receipt,
        };
    }

    pub fn runWasmImageI64(self: *Runtime, request: LaunchRequest, image: WasmAppImage) Error!RunResult {
        var result: RunResult = undefined;
        try self.runWasmImageI64Into(request, image, &result);
        return result;
    }

    pub fn runWasmImageI64Into(self: *Runtime, request: LaunchRequest, image: WasmAppImage, out: *RunResult) Error!void {
        var storage: wasm.ExecutionStorage = .{};
        try self.runWasmImageI64IntoWithStorage(request, image, &storage, out);
    }

    pub fn runWasmImageI64IntoWithStorage(self: *Runtime, request: LaunchRequest, image: WasmAppImage, storage: *wasm.ExecutionStorage, out: *RunResult) Error!void {
        var scratch: Scratch = undefined;
        try self.runWasmImageI64IntoWithStorageAndScratch(request, image, storage, &scratch, out);
    }

    pub fn runWasmImageI64IntoWithStorageAndScratch(self: *Runtime, request: LaunchRequest, image: WasmAppImage, storage: *wasm.ExecutionStorage, scratch: *Scratch, out: *RunResult) Error!void {
        if (!image.valid()) return error.Corrupt;
        try self.runWasmI64IntoWithStorageAndScratch(request.bindImage(image), image.wasm_bytes, image.export_name, storage, scratch, out);
    }

    fn memoryForContract(self: Runtime, contract: resource_contract.Contract) ?[]u8 {
        if (!sameChunk(contract.resource, self.boot_memory_resource.id)) return null;
        if (!self.boot_memory_resource.contains(contract.bounds)) return null;
        const offset = contract.bounds.offset - self.boot_memory_resource.bounds.offset;
        const end = offset + contract.bounds.length;
        if (end > self.boot_memory.len) return null;
        return self.boot_memory[@intCast(offset)..@intCast(end)];
    }
};

pub const WasmAppImage = struct {
    wasm_bytes: []const u8,
    export_name: []const u8,
    code_hash: preimage.Hash,
    manifest: preimage.Hash,
    allocation: App.DeclaredAllocation,

    pub fn init(wasm_bytes: []const u8, export_name: []const u8, allocation: App.DeclaredAllocation) ?WasmAppImage {
        if (wasm_bytes.len == 0 or export_name.len == 0 or !allocation.valid()) return null;
        const code_hash = hashCode(wasm_bytes);
        return .{
            .wasm_bytes = wasm_bytes,
            .export_name = export_name,
            .code_hash = code_hash,
            .manifest = hashManifest(code_hash, export_name, allocation),
            .allocation = allocation,
        };
    }

    pub fn valid(self: WasmAppImage) bool {
        return self.wasm_bytes.len != 0 and
            self.export_name.len != 0 and
            self.allocation.valid() and
            bytes.eql(&self.code_hash, &hashCode(self.wasm_bytes)) and
            bytes.eql(&self.manifest, &hashManifest(self.code_hash, self.export_name, self.allocation));
    }
};

pub const LaunchRequest = struct {
    parent: identity.Identity,
    app: identity.Identity,
    public_contract: resource_contract.Contract,
    private_contract: resource_contract.Contract,
    input: preimage.Hash,
    clock_start: clock.Stamp,
    clock_end: clock.Stamp,

    pub fn bindImage(self: LaunchRequest, image: WasmAppImage) LaunchPlan {
        return .{
            .parent = self.parent,
            .app = self.app,
            .public_contract = self.public_contract,
            .private_contract = self.private_contract,
            .allocation = image.allocation,
            .input = self.input,
            .app_hash = image.code_hash,
            .manifest = image.manifest,
            .clock_start = self.clock_start,
            .clock_end = self.clock_end,
        };
    }
};

pub const LaunchPlan = struct {
    parent: identity.Identity,
    app: identity.Identity,
    public_contract: resource_contract.Contract,
    private_contract: resource_contract.Contract,
    allocation: App.DeclaredAllocation,
    input: preimage.Hash,
    app_hash: preimage.Hash,
    manifest: preimage.Hash,
    clock_start: clock.Stamp,
    clock_end: clock.Stamp,

    pub fn validate(self: LaunchPlan, inventory: resource_inventory.Inventory) Error!void {
        if (self.parent.kind != .app or self.app.kind != .app) return error.BadArgument;
        if (!self.allocation.valid()) return error.BadArgument;
        if (self.allocation.memory_bytes != self.private_contract.bounds.length) return error.BadArgument;
        if (!self.clock_start.valid() or !self.clock_end.valid() or !self.clock_start.sameKeeper(self.clock_end) or self.clock_start.order(self.clock_end) > 0) return error.BadArgument;
        if (!bytesNonzero(&self.input) or !bytesNonzero(&self.app_hash) or !bytesNonzero(&self.manifest)) return error.BadArgument;
        const plan = resource_inventory.AppMemoryPlan.init(identityChunk(&self.app), self.public_contract, self.private_contract);
        if (!plan.fits(inventory)) return error.OutOfBounds;
    }
};

pub const RunResult = struct {
    value: i64,
    output: preimage.Hash,
    receipt: App.WorkReceipt,
};

pub const Scratch = struct {
    slots: [0]store.Blob,
    app: App,
    spawn_receipt: grant.SpawnReceipt,
    value: i64,
    output: preimage.Hash,
};

fn identityChunk(value: *const identity.Identity) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(&value.id.bytes);
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and bytes.eql(left.body(), right.body());
}

fn bytesNonzero(value: []const u8) bool {
    for (value) |byte| {
        if (byte != 0) return true;
    }
    return false;
}

fn testIdentity(kind: identity.Kind, material: []const u8, epoch: clock.Stamp) identity.Identity {
    return identity.Identity.init(kind, identity.Source.prepare(.hash, &preimage.rawHash(material)).?, epoch).?;
}

fn testHash(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:kernel-runtime-test", material);
}

fn hashCode(wasm_bytes: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:wasm-app-image-code", wasm_bytes);
}

fn hashManifest(code_hash: preimage.Hash, export_name: []const u8, allocation: App.DeclaredAllocation) preimage.Hash {
    const allocation_id = allocation.id() orelse [_]u8{0} ** preimage.hash_size;
    var builder = preimage.Builder.init("edgerun:zig:v1:wasm-app-image-manifest");
    builder.hash(code_hash);
    builder.bytes(export_name);
    builder.hash(allocation_id);
    return builder.final();
}

fn testContract(
    id: []const u8,
    app: data_chunk.DataChunk,
    resource: data_chunk.DataChunk,
    offset: u64,
    length: u64,
    start_tick: u64,
    end_tick: u64,
) resource_contract.Contract {
    return resource_contract.Contract.init(
        data_chunk.DataChunk.init(id),
        app,
        resource,
        .memory,
        start_tick,
        end_tick,
        resource_contract.Bounds.init(offset, length),
        resource_contract.Pattern.exclusive(),
    );
}

const return_forty_two_wasm = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7e, 0x03,
    0x02, 0x01, 0x00, 0x07, 0x08, 0x01, 0x04, 'm',
    'a',  'i',  'n',  0x00, 0x00, 0x0a, 0x06, 0x01,
    0x04, 0x00, 0x42, 0x2a, 0x0b,
};

test "kernel runtime launches a wasm app from resource contracts and emits a work receipt" {
    const testing = @import("std").testing;
    var memory: [512]u8 = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    var contracts: [2]resource_contract.Contract = undefined;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{121} ++ [_]u8{0} ** 31 } };
    const parent = testIdentity(.app, "runtime parent", epoch);
    const app = testIdentity(.app, "runtime child app", epoch);
    const app_chunk = data_chunk.DataChunk.init(&app.id.bytes);
    const resource = resource_inventory.Resource.init(data_chunk.DataChunk.init("boot-memory-0"), .memory, resource_contract.Bounds.init(0, memory.len));
    var inventory = resource_inventory.Inventory.init(&resources);
    try inventory.add(resource);
    var runtime = Runtime.init(inventory, resource_contract.Schedule.init(&contracts), resource, &memory);
    const allocation = App.DeclaredAllocation{
        .memory_bytes = 256,
        .storage_bytes = 0,
        .storage_slots = 0,
        .execution_ticks = 8,
    };

    const plan = LaunchPlan{
        .parent = parent,
        .app = app,
        .public_contract = testContract("public-memory", app_chunk, resource.id, 0, 64, 1, 10),
        .private_contract = testContract("private-memory", app_chunk, resource.id, 64, 256, 1, 10),
        .allocation = allocation,
        .input = testHash("input"),
        .app_hash = testHash("wasm"),
        .manifest = testHash("manifest"),
        .clock_start = epoch,
        .clock_end = .{ .keeper = epoch.keeper, .tick = 2 },
    };
    const memory_plan = resource_inventory.AppMemoryPlan.init(app_chunk, plan.public_contract, plan.private_contract);
    try testing.expect(memory_plan.valid());
    try testing.expect(inventory.contractFits(plan.public_contract));
    try testing.expect(inventory.contractFits(plan.private_contract));
    try testing.expect(memory_plan.fits(inventory));

    const result = try runtime.runWasmI64(plan, &return_forty_two_wasm, "main");

    try testing.expectEqual(@as(i64, 42), result.value);
    try testing.expect(result.receipt.valid());
    try testing.expect(result.receipt.parent.eql(parent.id));
    try testing.expect(result.receipt.app.eql(app.id));
    try testing.expectEqual(@as(u64, 2), result.receipt.execution_used);
    try testing.expectEqual(@as(usize, 2), runtime.schedule.len);
}

test "kernel runtime can execute wasm using caller-owned execution storage" {
    const testing = @import("std").testing;
    var memory: [512]u8 = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    var contracts: [2]resource_contract.Contract = undefined;
    var storage: wasm.ExecutionStorage = .{};
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{123} ++ [_]u8{0} ** 31 } };
    const parent = testIdentity(.app, "runtime storage parent", epoch);
    const app = testIdentity(.app, "runtime storage child app", epoch);
    const app_chunk = data_chunk.DataChunk.init(&app.id.bytes);
    const resource = resource_inventory.Resource.init(data_chunk.DataChunk.init("boot-memory-storage"), .memory, resource_contract.Bounds.init(0, memory.len));
    var inventory = resource_inventory.Inventory.init(&resources);
    try inventory.add(resource);
    var runtime = Runtime.init(inventory, resource_contract.Schedule.init(&contracts), resource, &memory);
    const allocation = App.DeclaredAllocation{
        .memory_bytes = 256,
        .storage_bytes = 0,
        .storage_slots = 0,
        .execution_ticks = 8,
    };

    const result = try runtime.runWasmI64WithStorage(.{
        .parent = parent,
        .app = app,
        .public_contract = testContract("public-memory-storage", app_chunk, resource.id, 0, 64, 1, 10),
        .private_contract = testContract("private-memory-storage", app_chunk, resource.id, 64, 256, 1, 10),
        .allocation = allocation,
        .input = testHash("storage input"),
        .app_hash = testHash("storage wasm"),
        .manifest = testHash("storage manifest"),
        .clock_start = epoch,
        .clock_end = .{ .keeper = epoch.keeper, .tick = 2 },
    }, &return_forty_two_wasm, "main", &storage);

    try testing.expectEqual(@as(i64, 42), result.value);
    try testing.expect(result.receipt.valid());
    try testing.expectEqual(@as(u64, 2), result.receipt.execution_used);
    try testing.expectEqual(@as(usize, 2), runtime.schedule.len);
}

test "kernel runtime binds wasm image into launch plan" {
    const testing = @import("std").testing;
    var memory: [512]u8 = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    var contracts: [2]resource_contract.Contract = undefined;
    var storage: wasm.ExecutionStorage = .{};
    var scratch: Scratch = undefined;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{124} ++ [_]u8{0} ** 31 } };
    const parent = testIdentity(.app, "runtime image parent", epoch);
    const app = testIdentity(.app, "runtime image child app", epoch);
    const app_chunk = data_chunk.DataChunk.init(&app.id.bytes);
    const resource = resource_inventory.Resource.init(data_chunk.DataChunk.init("boot-memory-image"), .memory, resource_contract.Bounds.init(0, memory.len));
    var inventory = resource_inventory.Inventory.init(&resources);
    try inventory.add(resource);
    var runtime = Runtime.init(inventory, resource_contract.Schedule.init(&contracts), resource, &memory);
    const image = WasmAppImage.init(&return_forty_two_wasm, "main", .{
        .memory_bytes = 256,
        .storage_bytes = 0,
        .storage_slots = 0,
        .execution_ticks = 8,
    }).?;
    var result: RunResult = undefined;

    try runtime.runWasmImageI64IntoWithStorageAndScratch(.{
        .parent = parent,
        .app = app,
        .public_contract = testContract("public-memory-image", app_chunk, resource.id, 0, 64, 1, 10),
        .private_contract = testContract("private-memory-image", app_chunk, resource.id, 64, 256, 1, 10),
        .input = testHash("image input"),
        .clock_start = epoch,
        .clock_end = .{ .keeper = epoch.keeper, .tick = 2 },
    }, image, &storage, &scratch, &result);

    try testing.expectEqual(@as(i64, 42), result.value);
    try testing.expect(result.receipt.valid());
    try testing.expectEqualSlices(u8, &image.code_hash, &result.receipt.app_hash);
    try testing.expectEqualSlices(u8, &image.manifest, &result.receipt.manifest);
    try testing.expectEqual(@as(usize, 2), runtime.schedule.len);
}

test "kernel runtime rejects corrupted wasm image identity" {
    const testing = @import("std").testing;
    var memory: [512]u8 = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    var contracts: [2]resource_contract.Contract = undefined;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{125} ++ [_]u8{0} ** 31 } };
    const parent = testIdentity(.app, "runtime corrupt image parent", epoch);
    const app = testIdentity(.app, "runtime corrupt image child app", epoch);
    const app_chunk = data_chunk.DataChunk.init(&app.id.bytes);
    const resource = resource_inventory.Resource.init(data_chunk.DataChunk.init("boot-memory-corrupt-image"), .memory, resource_contract.Bounds.init(0, memory.len));
    var inventory = resource_inventory.Inventory.init(&resources);
    try inventory.add(resource);
    var runtime = Runtime.init(inventory, resource_contract.Schedule.init(&contracts), resource, &memory);
    var image = WasmAppImage.init(&return_forty_two_wasm, "main", .{
        .memory_bytes = 256,
        .storage_bytes = 0,
        .storage_slots = 0,
        .execution_ticks = 8,
    }).?;
    image.manifest = testHash("wrong manifest");

    try testing.expectError(error.Corrupt, runtime.runWasmImageI64(.{
        .parent = parent,
        .app = app,
        .public_contract = testContract("public-memory-corrupt-image", app_chunk, resource.id, 0, 64, 1, 10),
        .private_contract = testContract("private-memory-corrupt-image", app_chunk, resource.id, 64, 256, 1, 10),
        .input = testHash("corrupt image input"),
        .clock_start = epoch,
        .clock_end = .{ .keeper = epoch.keeper, .tick = 2 },
    }, image));
    try testing.expectEqual(@as(usize, 0), runtime.schedule.len);
}

test "kernel runtime rejects overlapping app memory contracts before execution" {
    const testing = @import("std").testing;
    var memory: [512]u8 = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    var contracts: [2]resource_contract.Contract = undefined;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{122} ++ [_]u8{0} ** 31 } };
    const parent = testIdentity(.app, "overlap parent", epoch);
    const app = testIdentity(.app, "overlap child", epoch);
    const app_chunk = data_chunk.DataChunk.init(&app.id.bytes);
    const resource = resource_inventory.Resource.init(data_chunk.DataChunk.init("boot-memory-0"), .memory, resource_contract.Bounds.init(0, memory.len));
    var inventory = resource_inventory.Inventory.init(&resources);
    try inventory.add(resource);
    var runtime = Runtime.init(inventory, resource_contract.Schedule.init(&contracts), resource, &memory);

    try testing.expectError(error.OutOfBounds, runtime.runWasmI64(.{
        .parent = parent,
        .app = app,
        .public_contract = testContract("public-memory", app_chunk, resource.id, 0, 128, 1, 10),
        .private_contract = testContract("private-memory", app_chunk, resource.id, 64, 256, 1, 10),
        .allocation = .{
            .memory_bytes = 256,
            .storage_bytes = 0,
            .storage_slots = 0,
            .execution_ticks = 8,
        },
        .input = testHash("input"),
        .app_hash = testHash("wasm"),
        .manifest = testHash("manifest"),
        .clock_start = epoch,
        .clock_end = .{ .keeper = epoch.keeper, .tick = 2 },
    }, &return_forty_two_wasm, "main"));
    try testing.expectEqual(@as(usize, 0), runtime.schedule.len);
}
