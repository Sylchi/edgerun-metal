const BoundedArena = @import("../arena.zig").BoundedArena;
const Region = @import("../region.zig").Region;
const app_mod = @import("../app.zig");
const clock = @import("../clock.zig");
const data_chunk = @import("data_chunk.zig");
const grant = @import("../grant.zig");
const identity = @import("../identity.zig");
const preimage = @import("../preimage.zig");
const resource_contract = @import("resource_contract.zig");
const resource_inventory = @import("resource_inventory.zig");
const store = @import("../store.zig");
const wasm_app = @import("../wasm/app.zig");

const App = app_mod.App;

pub const Error = resource_contract.Error || resource_inventory.Error || @import("../wasm/root.zig").Error || error{
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
        try plan.validate(self.inventory);
        try self.schedule.installChecked(self.inventory, plan.public_contract);
        errdefer self.schedule.len -= 1;
        try self.schedule.installChecked(self.inventory, plan.private_contract);

        const app_memory = self.memoryForContract(plan.private_contract) orelse return error.NoMemory;
        var slots: [0]store.Blob = .{};
        var app = App.initAllocated(
            plan.app,
            BoundedArena.init(Region{ .base = app_memory }),
            store.Store.init(Region{ .base = app_memory[0..0] }, &slots),
            plan.allocation,
        ) orelse return error.BadArgument;

        const spawn_receipt = grant.spawnReceiptAllocated(
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

        const result = try wasm_app.executeExportI64Receipt(&app, wasm_bytes, export_name, .{
            .parent = plan.parent,
            .input = plan.input,
            .app_hash = plan.app_hash,
            .manifest = plan.manifest,
            .clock_start = plan.clock_start,
            .clock_end = plan.clock_end,
            .allocation = plan.allocation,
            .spawn_receipt = spawn_receipt,
        });

        out.* = .{
            .value = result.value,
            .output = result.output,
            .receipt = result.receipt,
        };
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

fn identityChunk(value: *const identity.Identity) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(&value.id.bytes);
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and @import("../bytes.zig").eql(left.body(), right.body());
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
