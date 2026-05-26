const std = @import("std");
const uefi = std.os.uefi;
const app_mod = @import("app.zig");
const clock = @import("clock.zig");
const data_chunk = @import("content/data_chunk.zig");
const identity = @import("identity.zig");
const kernel_runtime = @import("content/kernel_runtime.zig");
const preimage = @import("preimage.zig");
const resource_contract = @import("content/resource_contract.zig");
const resource_inventory = @import("content/resource_inventory.zig");
const wasm = @import("wasm/root.zig");

const App = app_mod.App;

const debugcon_port: u16 = 0x402;
const line_max: usize = 192;
const boot_memory_len: usize = 512;
const public_memory_offset: u64 = 0;
const public_memory_len: u64 = 64;
const private_memory_offset: u64 = 64;
const private_memory_len: u64 = 256;
const schedule_start_tick: u64 = 1;
const schedule_end_tick: u64 = 10;
const receipt_clock_tick: u64 = 2;
const execution_ticks: u64 = 8;
const expected_execution_used: u64 = 2;
const expected_value: i64 = 42;

var boot_memory: [boot_memory_len]u8 = undefined;
var resources: [1]resource_inventory.Resource = undefined;
var contracts: [2]resource_contract.Contract = undefined;
var epoch_slot: clock.Stamp = undefined;
var parent_slot: identity.Identity = undefined;
var app_slot: identity.Identity = undefined;
var app_chunk_slot: data_chunk.DataChunk = undefined;
var resource_slot: resource_inventory.Resource = undefined;
var inventory_slot: resource_inventory.Inventory = undefined;
var runtime_slot: kernel_runtime.Runtime = undefined;
var request_slot: kernel_runtime.LaunchRequest = undefined;
var image_slot: kernel_runtime.WasmAppImage = undefined;
var result_slot: kernel_runtime.RunResult = undefined;
var scratch_slot: kernel_runtime.Scratch = undefined;
var wasm_storage: wasm.ExecutionStorage = .{};

const return_forty_two_wasm = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7e, 0x03,
    0x02, 0x01, 0x00, 0x07, 0x08, 0x01, 0x04, 'm',
    'a',  'i',  'n',  0x00, 0x00, 0x0a, 0x06, 0x01,
    0x04, 0x00, 0x42, 0x2a, 0x0b,
};

pub fn main() uefi.Status {
    printLine("EdgeRun immutable kernel runtime smoke");
    printLine("root: signed resource contract runs wasm app");
    return runChecks();
}

noinline fn runChecks() uefi.Status {
    printLine("check: runtime start");
    return runRuntimeChecks();
}

noinline fn runRuntimeChecks() uefi.Status {
    printLine("check: runtime stack ok");
    return runPlanStage();
}

noinline fn runPlanStage() uefi.Status {
    epoch_slot = clock.Stamp{ .keeper = .{ .bytes = [_]u8{127} ++ [_]u8{0} ** 31 } };
    printLine("check: runtime epoch ok");
    return runIdentityStage();
}

noinline fn runIdentityStage() uefi.Status {
    parent_slot = testIdentity(.app, "qemu runtime parent", epoch_slot) orelse return failText("parent identity");
    printLine("check: runtime parent identity ok");
    app_slot = testIdentity(.app, "qemu runtime app", epoch_slot) orelse return failText("app identity");
    printLine("check: runtime app identity ok");
    return runResourceStage();
}

noinline fn runResourceStage() uefi.Status {
    app_chunk_slot = data_chunk.DataChunk.init(&app_slot.id.bytes);
    printLine("check: runtime app chunk ok");
    return runInventoryStage();
}

noinline fn runInventoryStage() uefi.Status {
    resource_slot = resource_inventory.Resource.init(
        data_chunk.DataChunk.init("qemu-runtime-memory"),
        .memory,
        resource_contract.Bounds.init(0, boot_memory.len),
    );
    printLine("check: runtime inputs ok");
    printLine("check: runtime inventory add start");
    inventory_slot = resource_inventory.Inventory.init(&resources);
    inventory_slot.add(resource_slot) catch |err| return failInventory("resource inventory", err);
    printLine("check: runtime inventory ok");
    return runRuntimeInitStage();
}

noinline fn runRuntimeInitStage() uefi.Status {
    runtime_slot = kernel_runtime.Runtime.init(
        inventory_slot,
        resource_contract.Schedule.init(&contracts),
        resource_slot,
        &boot_memory,
    );
    printLine("check: runtime init ok");
    return runLaunchPlanStage();
}

noinline fn runLaunchPlanStage() uefi.Status {
    const allocation = App.DeclaredAllocation{
        .memory_bytes = private_memory_len,
        .storage_bytes = 0,
        .storage_slots = 0,
        .execution_ticks = execution_ticks,
    };
    image_slot = kernel_runtime.WasmAppImage.init(&return_forty_two_wasm, "main", allocation) orelse return failText("wasm image invalid");
    request_slot = kernel_runtime.LaunchRequest{
        .parent = parent_slot,
        .app = app_slot,
        .public_contract = contract("qemu-runtime-public", app_chunk_slot, resource_slot.id, public_memory_offset, public_memory_len),
        .private_contract = contract("qemu-runtime-private", app_chunk_slot, resource_slot.id, private_memory_offset, private_memory_len),
        .input = hash("qemu runtime input"),
        .clock_start = epoch_slot,
        .clock_end = .{ .keeper = epoch_slot.keeper, .tick = receipt_clock_tick },
    };
    printLine("check: runtime launch-image ok");

    return runWasmStage();
}

noinline fn runWasmStage() uefi.Status {
    printLine("check: runtime wasm start");
    return runWasmExecuteStage();
}

noinline fn runWasmExecuteStage() uefi.Status {
    printLine("check: runtime wasm execute start");
    runtime_slot.runWasmImageI64IntoWithStorageAndScratch(
        request_slot,
        image_slot,
        &wasm_storage,
        &scratch_slot,
        &result_slot,
    ) catch |err| return failRuntime("wasm image execute", err);
    printLine("check: runtime wasm returned");
    return runVerifyResultStage();
}

noinline fn runVerifyResultStage() uefi.Status {
    if (result_slot.value != expected_value) return failText("wrong wasm result");
    if (!result_slot.receipt.valid()) return failText("invalid work receipt");
    if (!result_slot.receipt.parent.eql(parent_slot.id)) return failText("receipt parent mismatch");
    if (!result_slot.receipt.app.eql(app_slot.id)) return failText("receipt app mismatch");
    if (!std.mem.eql(u8, &result_slot.receipt.app_hash, &image_slot.code_hash)) return failText("receipt code hash mismatch");
    if (!std.mem.eql(u8, &result_slot.receipt.manifest, &image_slot.manifest)) return failText("receipt manifest mismatch");
    if (result_slot.receipt.execution_used != expected_execution_used) return failText("receipt execution mismatch");
    if (runtime_slot.schedule.len != contracts.len) return failText("schedule length mismatch");

    printLine("check: kernel-runtime-wasm-receipt ok");
    printLine("PASS immutable-kernel-runtime-qemu");
    return .success;
}

fn contract(
    id: []const u8,
    app: data_chunk.DataChunk,
    resource: data_chunk.DataChunk,
    offset: u64,
    length: u64,
) resource_contract.Contract {
    return resource_contract.Contract.init(
        data_chunk.DataChunk.init(id),
        app,
        resource,
        .memory,
        schedule_start_tick,
        schedule_end_tick,
        resource_contract.Bounds.init(offset, length),
        resource_contract.Pattern.exclusive(),
    );
}

fn testIdentity(kind: identity.Kind, material: []const u8, epoch: clock.Stamp) ?identity.Identity {
    return identity.Identity.init(kind, identity.Source.prepare(.hash, &preimage.rawHash(material)) orelse return null, epoch);
}

fn hash(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:kernel-runtime-qemu", material);
}

fn failRuntime(step: []const u8, err: kernel_runtime.Error) uefi.Status {
    printText("FAIL ");
    printText(step);
    printText(" ");
    printRuntimeError(err);
    printNewline();
    return .aborted;
}

fn printRuntimeError(err: kernel_runtime.Error) void {
    switch (err) {
        error.ArithmeticTrap => printText("arithmetic-trap"),
        error.BadArgument => printText("bad-argument"),
        error.Conflict => printText("conflict"),
        error.Corrupt => printText("corrupt"),
        error.Duplicate => printText("duplicate"),
        error.FlushFailed => printText("flush-failed"),
        error.HashFailed => printText("hash-failed"),
        error.LoadKeyFailed => printText("load-key-failed"),
        error.MemoryGrowthRequiresAuthority => printText("memory-growth-requires-authority"),
        error.MissingExport => printText("missing-export"),
        error.MissingImport => printText("missing-import"),
        error.NoExecution => printText("no-execution"),
        error.NoMemory => printText("no-memory"),
        error.NoSpace => printText("no-space"),
        error.NotFound => printText("not-found"),
        error.OutOfBounds => printText("out-of-bounds"),
        error.StackOverflow => printText("stack-overflow"),
        error.StackUnderflow => printText("stack-underflow"),
        error.TableGrowthRequiresAuthority => printText("table-growth-requires-authority"),
        error.Trap => printText("trap"),
        error.Unsupported => printText("unsupported"),
        error.VerifyFailed => printText("verify-failed"),
    }
}

fn failInventory(step: []const u8, err: resource_inventory.Error) uefi.Status {
    printText("FAIL ");
    printText(step);
    printText(" ");
    printInventoryError(err);
    printNewline();
    return .aborted;
}

fn printInventoryError(err: resource_inventory.Error) void {
    switch (err) {
        error.BadArgument => printText("bad-argument"),
        error.Duplicate => printText("duplicate"),
        error.NoSpace => printText("no-space"),
        error.OutOfBounds => printText("out-of-bounds"),
    }
}

fn failText(message: []const u8) uefi.Status {
    printText("FAIL ");
    printLine(message);
    return .aborted;
}

fn printLine(message: []const u8) void {
    printText(message);
    printNewline();
}

fn printNewline() void {
    printText("\r\n");
}

fn printText(message: []const u8) void {
    writeDebugcon(message);
    writeConsole(message);
}

fn writeConsole(message: []const u8) void {
    const out = uefi.system_table.con_out orelse return;
    var wide: [line_max:0]u16 = undefined;
    var index: usize = 0;
    while (index < message.len and index < line_max) : (index += 1) {
        wide[index] = message[index];
    }
    wide[index] = 0;
    _ = out.outputString(@ptrCast(&wide)) catch false;
}

fn writeDebugcon(message: []const u8) void {
    for (message) |byte| {
        outb(debugcon_port, byte);
    }
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}
