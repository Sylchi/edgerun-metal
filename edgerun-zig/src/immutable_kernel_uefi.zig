const std = @import("std");
const bytes = @import("bytes.zig");
const uefi = std.os.uefi;
const content_kernel = @import("content/kernel.zig");
const registry_app = @import("content/registry_app.zig");
const data_chunk = @import("content/data_chunk.zig");

const debugcon_port: u16 = 0x402;
const line_max: usize = 192;

pub fn main() uefi.Status {
    printLine("EdgeRun immutable kernel substrate");
    printLine("root: memory allocator only");
    return runChecks();
}

fn runChecks() uefi.Status {
    var allocation_slots: [2]content_kernel.Allocation = undefined;
    var registration_slots: [1]registry_app.EndpointRegistration = undefined;
    var allocator = content_kernel.Allocator.init(&allocation_slots);
    var registry = registry_app.Registry.init(&registration_slots);

    allocator.addAllocation(content_kernel.Allocation.init(chunk("sender-allocation"), chunk("sender-app"), 64)) catch |err| return fail("sender allocation", err);
    allocator.addAllocation(content_kernel.Allocation.init(chunk("receiver-allocation"), chunk("receiver-app"), 64)) catch |err| return fail("receiver allocation", err);

    if (!allocator.rangeValid(content_kernel.AddressRange.init(chunk("sender-allocation"), 8, 16))) {
        return failText("valid range rejected");
    }
    if (allocator.rangeValid(content_kernel.AddressRange.init(chunk("sender-allocation"), 60, 8))) {
        return failText("out-of-bounds range accepted");
    }
    printLine("check: allocation-relative-address ok");

    const view = allocator.createView(content_kernel.MemoryView.init(
        chunk("view-a"),
        content_kernel.AddressRange.init(chunk("sender-allocation"), 8, 16),
        chunk("sender-endpoint"),
        false,
        4,
    )) catch |err| return fail("create view", err);
    printLine("check: memory-view ok");

    registry.register(allocator, registry_app.EndpointRegistration.init(
        chunk("receiver-endpoint"),
        chunk("receiver-state"),
        chunk("receiver-allocation"),
        chunk("message-definition"),
        chunk("sender-endpoint"),
        4,
    )) catch |err| return fail("register endpoint", err);

    const routed = registry.route(allocator, registry_app.MessageEnvelope.init(
        chunk("sender-endpoint"),
        chunk("receiver-endpoint"),
        chunk("message-definition"),
        chunk("view-a"),
        4,
    ), view) catch |err| return fail("route message", err);
    if (!sameChunk(routed.app_state_id, chunk("receiver-state"))) {
        return failText("route returned wrong app state");
    }
    printLine("check: registry-route ok");

    _ = registry.route(allocator, registry_app.MessageEnvelope.init(
        chunk("wrong-sender"),
        chunk("receiver-endpoint"),
        chunk("message-definition"),
        chunk("view-a"),
        4,
    ), view) catch |err| switch (err) {
        error.Unauthorized => {
            printLine("check: sender-restriction ok");
        },
        else => return fail("sender restriction", err),
    };

    allocator.advance(5) catch |err| return fail("advance clock", err);
    _ = registry.route(allocator, registry_app.MessageEnvelope.init(
        chunk("sender-endpoint"),
        chunk("receiver-endpoint"),
        chunk("message-definition"),
        chunk("view-a"),
        4,
    ), view) catch |err| switch (err) {
        error.Expired => {
            printLine("check: clock-expiry ok");
            printLine("PASS immutable-kernel-qemu");
            return .success;
        },
        else => return fail("clock expiry", err),
    };

    return failText("expired route unexpectedly succeeded");
}

fn fail(step: []const u8, err: registry_app.Error) uefi.Status {
    printText("FAIL ");
    printText(step);
    printText(" ");
    printError(err);
    printNewline();
    return .aborted;
}

fn failText(message: []const u8) uefi.Status {
    printText("FAIL ");
    printLine(message);
    return .aborted;
}

fn printError(err: registry_app.Error) void {
    switch (err) {
        error.BadArgument => printText("bad-argument"),
        error.Duplicate => printText("duplicate"),
        error.Expired => printText("expired"),
        error.NoSpace => printText("no-space"),
        error.NotFound => printText("not-found"),
        error.OutOfBounds => printText("out-of-bounds"),
        error.Unauthorized => printText("unauthorized"),
    }
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and bytes.eql(left.body(), right.body());
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
