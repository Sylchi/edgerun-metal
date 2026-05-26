const std = @import("std");
const uefi = std.os.uefi;
const boot_resource_map = @import("boot_resource_map.zig");
const resource_inventory = @import("content/resource_inventory.zig");
const uefi_resource_map = @import("boot/uefi_resource_map.zig");

const debugcon_port: u16 = 0x402;
const line_max: usize = 192;
const max_boot_resources: usize = 128;
const memory_map_bytes: usize = 131072;
const min_post_exit_memory_bytes: u64 = 4096;
const max_exit_attempts: usize = 2;

var map_buffer: [memory_map_bytes]u8 align(@alignOf(uefi.tables.MemoryDescriptor)) = undefined;
var memory_regions: [max_boot_resources]boot_resource_map.MemoryRegion = undefined;
var resources: [max_boot_resources]resource_inventory.Resource = undefined;
var resource_ids: [max_boot_resources]resource_inventory.ResourceIdStorage = undefined;
var inventory: resource_inventory.Inventory = undefined;
var boot_map: boot_resource_map.Map = undefined;
var usable_resource_count: usize = 0;
var post_exit_marker: u64 = 0;

pub fn main() noreturn {
    printLine("EdgeRun immutable kernel ExitBootServices smoke");
    printLine("root: firmware handoff boundary");
    run() catch |err| {
        printText("FAIL ");
        printError(err);
        printNewline();
        haltForever();
    };
    haltForever();
}

fn run() Error!void {
    const boot_services = uefi.system_table.boot_services orelse return error.BootServicesUnavailable;

    try collectAndValidateMap(boot_services);
    printLine("check: pre-exit memory inventory ok");

    try exitBootServicesWithFreshMap(boot_services);

    writeDebugconLine("check: exited boot services debugcon alive");
    post_exit_marker = 0x4544474552554e31;
    if (post_exit_marker != 0x4544474552554e31) {
        writeDebugconLine("FAIL post-exit static memory");
        haltForever();
    }
    if (usable_resource_count == 0) {
        writeDebugconLine("FAIL post-exit inventory lost");
        haltForever();
    }
    writeDebugconLine("check: post-exit static kernel state ok");
    writeDebugconLine("PASS immutable-kernel-exit-boot-qemu");
}

fn collectAndValidateMap(boot_services: *const uefi.tables.BootServices) Error!void {
    const memory_map = boot_services.getMemoryMap(&map_buffer) catch |err| return mapMemoryMapError(err);
    boot_map = mapFromMemoryMap(memory_map);
    inventory = resource_inventory.Inventory.init(&resources);
    resource_inventory.addBootResourceMap(&inventory, boot_map, &resource_ids) catch |err| return mapInventoryError(err);
    usable_resource_count = inventory.len;
    if (usable_resource_count == 0) return error.NoUsableMemory;
    if (!hasPostExitMemory(inventory)) return error.NoKernelMemory;
}

fn exitBootServicesWithFreshMap(boot_services: *uefi.tables.BootServices) Error!void {
    var attempt: usize = 0;
    while (attempt < max_exit_attempts) : (attempt += 1) {
        const memory_map = boot_services.getMemoryMap(&map_buffer) catch |err| return mapMemoryMapError(err);
        boot_map = mapFromMemoryMap(memory_map);
        inventory = resource_inventory.Inventory.init(&resources);
        resource_inventory.addBootResourceMap(&inventory, boot_map, &resource_ids) catch |err| return mapInventoryError(err);
        usable_resource_count = inventory.len;
        if (usable_resource_count == 0) return error.NoUsableMemory;

        boot_services.exitBootServices(uefi.handle, memory_map.info.key) catch |err| switch (err) {
            error.InvalidParameter => continue,
            else => return mapExitError(err),
        };
        return;
    }
    return error.ExitBootServicesRejected;
}

fn mapFromMemoryMap(memory_map: uefi.tables.MemoryMapSlice) boot_resource_map.Map {
    var len: usize = 0;
    var iterator = memory_map.iterator();
    while (iterator.next()) |descriptor| {
        if (len == memory_regions.len) break;
        memory_regions[len] = uefi_resource_map.fromDescriptor(descriptor.*);
        len += 1;
    }
    return .{
        .memory_regions = memory_regions[0..len],
        .verifier_kind = .tpm_p256_sha256,
    };
}

fn hasPostExitMemory(value: resource_inventory.Inventory) bool {
    for (value.resources[0..value.len]) |resource| {
        if (resource.kind == .memory and resource.bounds.length >= min_post_exit_memory_bytes) return true;
    }
    return false;
}

const Error = error{
    BootServicesUnavailable,
    ExitBootServicesFailed,
    ExitBootServicesRejected,
    MemoryMapInvalid,
    MemoryMapNoSpace,
    NoKernelMemory,
    NoUsableMemory,
    ResourceBadArgument,
    ResourceDuplicate,
    ResourceNoSpace,
    ResourceOutOfBounds,
};

fn mapMemoryMapError(err: uefi.tables.BootServices.GetMemoryMapError) Error {
    return switch (err) {
        error.BufferTooSmall => error.MemoryMapNoSpace,
        error.InvalidParameter => error.MemoryMapInvalid,
        else => error.MemoryMapInvalid,
    };
}

fn mapInventoryError(err: resource_inventory.Error) Error {
    return switch (err) {
        error.BadArgument => error.ResourceBadArgument,
        error.Duplicate => error.ResourceDuplicate,
        error.NoSpace => error.ResourceNoSpace,
        error.OutOfBounds => error.ResourceOutOfBounds,
    };
}

fn mapExitError(err: uefi.tables.BootServices.ExitBootServicesError) Error {
    return switch (err) {
        error.InvalidParameter => error.ExitBootServicesRejected,
        else => error.ExitBootServicesFailed,
    };
}

fn printError(err: Error) void {
    switch (err) {
        error.BootServicesUnavailable => printText("boot-services-unavailable"),
        error.ExitBootServicesFailed => printText("exit-boot-services-failed"),
        error.ExitBootServicesRejected => printText("exit-boot-services-rejected"),
        error.MemoryMapInvalid => printText("memory-map-invalid"),
        error.MemoryMapNoSpace => printText("memory-map-no-space"),
        error.NoKernelMemory => printText("no-kernel-memory"),
        error.NoUsableMemory => printText("no-usable-memory"),
        error.ResourceBadArgument => printText("resource-bad-argument"),
        error.ResourceDuplicate => printText("resource-duplicate"),
        error.ResourceNoSpace => printText("resource-no-space"),
        error.ResourceOutOfBounds => printText("resource-out-of-bounds"),
    }
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

fn writeDebugconLine(message: []const u8) void {
    writeDebugcon(message);
    writeDebugcon("\r\n");
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

fn haltForever() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
