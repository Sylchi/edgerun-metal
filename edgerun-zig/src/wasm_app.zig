const app_mod = @import("app.zig");
const clock = @import("clock.zig");
const grant = @import("grant.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");
const wasm = @import("wasm.zig");
const byte_utils = @import("bytes.zig");

const App = app_mod.App;

pub const ReceiptContext = struct {
    parent: identity.Id,
    input: preimage.Hash,
    app_hash: preimage.Hash,
    manifest: preimage.Hash,
    clock_start: clock.Stamp,
    clock_end: clock.Stamp,
    allocation: App.DeclaredAllocation,
    spawn_receipt: grant.SpawnReceipt,
};

pub const ReceiptResult = struct {
    value: i64,
    output: preimage.Hash,
    receipt: App.WorkReceipt,
};

pub fn executeExportI64(app: *App, wasm_bytes: []const u8, export_name: []const u8) wasm.Error!i64 {
    const allocation = app.executionAllocation();
    var runtime = wasm.Runtime.init(allocation.memory, allocation.execution_ticks);
    return wasm.executeExportI64(&runtime, wasm_bytes, export_name);
}

pub fn executeExportI64Receipt(app: *App, wasm_bytes: []const u8, export_name: []const u8, context: ReceiptContext) wasm.Error!ReceiptResult {
    const value = try executeExportI64(app, wasm_bytes, export_name);
    const output = outputHashI64(value);
    const receipt = app.completeWork(
        context.parent,
        context.input,
        output,
        context.app_hash,
        context.manifest,
        context.clock_start,
        context.clock_end,
        context.allocation,
        context.spawn_receipt,
    ) orelse return error.Corrupt;
    return .{
        .value = value,
        .output = output,
        .receipt = receipt,
    };
}

pub fn outputHashI64(value: i64) preimage.Hash {
    const raw = byte_utils.stored64(@as(u64, @bitCast(value)));
    return preimage.hash("edgerun:zig:v1:wasm-i64-output", &raw);
}
