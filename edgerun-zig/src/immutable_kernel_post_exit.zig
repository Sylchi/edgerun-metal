const std = @import("std");
const builtin = @import("builtin");
const app_mod = @import("app.zig");
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const clock = @import("clock.zig");
const content_kernel = @import("content/kernel.zig");
const kernel_runtime = @import("content/kernel_runtime.zig");
const data_chunk = @import("content/data_chunk.zig");
const identity = @import("identity.zig");
const interaction = @import("ui_interaction.zig");
const preimage = @import("preimage.zig");
const registry_app = @import("content/registry_app.zig");
const renderer_font_atlas = @import("render/font_atlas.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const resource_contract = @import("content/resource_contract.zig");
const resource_inventory = @import("content/resource_inventory.zig");
const ui = @import("ui.zig");
const virtio_gpu = @import("virtio_gpu.zig");
const wasm = @import("wasm/root.zig");

const App = app_mod.App;

pub const min_memory_bytes: u64 = 4096;

const state_marker: u64 = 0x4544474552554e31;
const contract_start_tick: u64 = 10;
const contract_end_tick: u64 = 20;
const contract_check_tick: u64 = 12;
const post_exit_contract_bytes: u64 = 64;
const post_exit_app_memory_len: usize = 512;
const post_exit_app_memory_offset: u64 = 0;
const post_exit_public_memory_len: u64 = 64;
const post_exit_private_memory_offset: u64 = 64;
const post_exit_private_memory_len: u64 = 256;
const post_exit_app_execution_ticks: u64 = 8;
const post_exit_expected_execution_used: u64 = 2;
const post_exit_expected_value: i64 = 42;
const virtio_scanout_width: u32 = 320;
const virtio_scanout_height: u32 = 180;
const virtio_scanout_resource_id: u32 = 1;
const virtio_scanout_id: u32 = 0;
const virtio_gl_context_id: u32 = 1;
const virtio_gl_resource_id: u32 = 2;
const virtio_gl_surface_handle: u32 = 1;
const max_app_commands: usize = 4096;
const max_app_clips: usize = 64;
const max_app_interaction_regions: usize = 4096;
const max_app_rects: usize = 8192;
const max_app_text_vertices: usize = 24576;
const max_app_icon_vertices: usize = 4096;
const max_app_icon_line_vertices: usize = 65536;
const max_app_image_vertices: usize = 384;
const max_app_overlay_rects: usize = 512;
const max_app_overlay_text_vertices: usize = 8192;
const max_app_overlay_icon_vertices: usize = 256;
const max_app_overlay_icon_line_vertices: usize = 16384;

const AppIrStorage = renderer_ir.FixedBuffers(
    max_app_rects,
    max_app_text_vertices,
    max_app_icon_vertices,
    max_app_image_vertices,
    max_app_overlay_rects,
    max_app_overlay_text_vertices,
    max_app_overlay_icon_vertices,
    max_app_icon_line_vertices,
    max_app_overlay_icon_line_vertices,
);

pub const Error = error{
    AllocationReceiverFailed,
    AllocationSenderFailed,
    AppIdentityFailed,
    ClockAdvanceFailed,
    ContractAInstallFailed,
    ContractBInstallFailed,
    ContractConflictWrongError,
    ContractOwnerMismatch,
    ContractOwnerMissing,
    ExpiredViewReadable,
    InventoryLost,
    MemoryResourceMissing,
    MemoryResourceTooSmall,
    OutOfBoundsRangeAccepted,
    OverlappingContractAccepted,
    ParentIdentityFailed,
    ReadOnlyViewWritable,
    RegistryAcceptedWrongSender,
    RegistryReceiverAllocationFailed,
    RegistryRegistrationFailed,
    RegistryRouteFailed,
    RegistrySenderAllocationFailed,
    RegistryStateMismatch,
    RegistryViewFailed,
    RegistryWrongSenderError,
    RendererIrFailed,
    SpawnReceiptFailed,
    SpawnReceiptInvalid,
    StaticMemoryLost,
    ValidRangeRejected,
    VirtioGpuDeviceNotFound,
    VirtioGpuInvalidResponse,
    VirtioGpuQueueFailed,
    VirtioGpuTimeout,
    VirtioGpuUnsupported,
    VirtioScanoutTooLarge,
    ViewCreateFailed,
    ViewReadRejected,
    WasmAppAllocationFailed,
    WasmExecutionFailed,
    WasmImageInvalid,
    WasmInventoryFailed,
    WasmMemoryPlanInvalid,
    WasmPrivateContractFailed,
    WasmPublicContractFailed,
    WasmRuntimeBadArgument,
    WasmRuntimeCorruptReceipt,
    WasmRuntimeLaunchFailed,
    WasmRuntimeNoMemory,
    WasmRuntimeOutOfBounds,
    WasmReceiptExecutionMismatch,
    WasmReceiptImageMismatch,
    WasmReceiptInvalid,
    WasmResultMismatch,
};

pub const Reporter = *const fn ([]const u8) void;

pub const State = struct {
    marker: u64,
    allocator_allocations: [2]content_kernel.Allocation,
    allocator: content_kernel.Allocator,
    view: content_kernel.MemoryView,
    contracts: [3]resource_contract.Contract,
    schedule: resource_contract.Schedule,
    app_memory: [post_exit_app_memory_len]u8,
    app_resources: [1]resource_inventory.Resource,
    app_contracts: [2]resource_contract.Contract,
    app_inventory: resource_inventory.Inventory,
    app_schedule: resource_contract.Schedule,
    first_app_runtime: kernel_runtime.Runtime,
    first_app_scratch: kernel_runtime.Scratch,
    wasm_storage: wasm.ExecutionStorage,
    app_scene_commands: [max_app_commands]ui.Command,
    app_scene_clips: [max_app_clips]ui.Rect,
    app_interactions: [max_app_interaction_regions]interaction.Region,
    app_ir_storage: AppIrStorage,
    app_font_atlas: renderer_font_atlas.Atlas,
    app_pixels: [virtio_scanout_width * virtio_scanout_height]ui.Color,
    parent: identity.Identity,
    app: identity.Identity,
    first_app_result: kernel_runtime.RunResult,
    registry_allocations: [2]content_kernel.Allocation,
    registry_entries: [1]registry_app.EndpointRegistration,
    registry_allocator: content_kernel.Allocator,
    registry: registry_app.Registry,
    registry_view: content_kernel.MemoryView,
    virtio_queue: virtio_gpu.QueueStorage,
    virtio_scanout: [virtio_scanout_width * virtio_scanout_height * 4]u8,
};

const return_forty_two_wasm = [_]u8{
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7e, 0x03,
    0x02, 0x01, 0x00, 0x07, 0x08, 0x01, 0x04, 'm',
    'a',  'i',  'n',  0x00, 0x00, 0x0a, 0x06, 0x01,
    0x04, 0x00, 0x42, 0x2a, 0x0b,
};

pub fn hasMemory(value: resource_inventory.Inventory) bool {
    return firstMemoryResource(value) != null;
}

pub fn run(state: *State, inventory: resource_inventory.Inventory, emit: Reporter) Error!void {
    state.marker = state_marker;
    if (state.marker != state_marker) return fail(emit, error.StaticMemoryLost, "FAIL post-exit static memory");
    if (inventory.len == 0) return fail(emit, error.InventoryLost, "FAIL post-exit inventory lost");
    if (!hasMemory(inventory)) return fail(emit, error.MemoryResourceMissing, "FAIL post-exit memory resource missing");
    emit("check: post-exit static kernel state ok");

    try runKernelChecks(state, emit);
    try runResourceContractChecks(state, inventory, emit);
    if (builtin.is_test) {
        emit("check: post-exit virtio-gpu skipped in host test");
    } else {
        try runVirtioGpuChecks(state, emit);
    }
    try runWasmAppChecks(state, emit);
    try runRegistryChecks(state, emit);
}

fn runVirtioGpuChecks(state: *State, emit: Reporter) Error!void {
    emit("check: post-exit virtio-gpu init start");
    var device = virtio_gpu.Device.findAndInit(&state.virtio_queue) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu init");
    if (device.virglReady()) {
        const capset = device.getCapsetInfo(&state.virtio_queue, 0) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu capset");
        if (capset.capset_id == @intFromEnum(virtio_gpu.CapsetId.virgl) or capset.capset_id == @intFromEnum(virtio_gpu.CapsetId.virgl2)) {
            emit("check: post-exit virtio-gpu virgl capset ok");
        } else {
            return fail(emit, error.VirtioGpuUnsupported, "FAIL post-exit virtio-gpu unexpected capset");
        }
        device.createContext(&state.virtio_queue, virtio_gl_context_id, .virgl, "edgerun-gl") catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu context");
        device.create3dColorResource(&state.virtio_queue, virtio_gl_resource_id, virtio_scanout_width, virtio_scanout_height, .b8g8r8a8_unorm) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu resource-3d");
        device.attachResourceBacking(&state.virtio_queue, virtio_gl_resource_id, @intFromPtr(&state.virtio_scanout), @intCast(state.virtio_scanout.len)) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu backing-3d");
        device.attachResourceToContext(&state.virtio_queue, virtio_gl_context_id, virtio_gl_resource_id) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu context-resource");
        emit("check: post-exit virtio-gpu 3d resource ok");
        device.submitVirglNop(&state.virtio_queue, virtio_gl_context_id) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu submit-3d");
        emit("check: post-exit virtio-gpu submit-3d ok");
        try renderVirtioGpuPackedDebugFrame(&device, state, emit);
        emit("check: post-exit virtio-gpu packed-renderer frame ok");
        device.setScanout(&state.virtio_queue, virtio_scanout_id, virtio_gl_resource_id, virtio_scanout_width, virtio_scanout_height) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu scanout-3d");
        device.flushResource(&state.virtio_queue, virtio_gl_resource_id, virtio_scanout_width, virtio_scanout_height) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu flush-3d");
        emit("check: post-exit virtio-gpu scanout-3d flushed");
        if (device.contextInitReady()) {
            emit("check: post-exit virtio-gpu virgl/context-init ok");
        } else {
            emit("check: post-exit virtio-gpu virgl ok");
        }
    } else {
        emit("check: post-exit virtio-gpu 2d-only");

        fillVirtioScanout(&state.virtio_scanout);
        const setup = virtio_gpu.Setup2d.init(
            virtio_scanout_resource_id,
            virtio_scanout_id,
            virtio_scanout_width,
            virtio_scanout_height,
            @intFromPtr(&state.virtio_scanout),
            @intCast(state.virtio_scanout.len),
        );
        device.setup2d(&state.virtio_queue, setup) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu setup");
        device.flush2d(&state.virtio_queue, virtio_scanout_resource_id, virtio_scanout_width, virtio_scanout_height) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu flush");
        emit("check: post-exit virtio-gpu scanout flushed");
    }
    emit("PASS immutable-kernel-exit-boot-virtio-qemu");
}

fn renderVirtioGpuPackedDebugFrame(device: *virtio_gpu.Device, state: *State, emit: Reporter) Error!void {
    var scene = ui.Scene.initWithClips(&state.app_scene_commands, &state.app_scene_clips);
    var collector = interaction.Collector.init(&state.app_interactions);
    app_frame.render(&scene, &collector, ui.Rect.init(0, 0, @floatFromInt(virtio_scanout_width), @floatFromInt(virtio_scanout_height)), .{
        .route = .{ .view = .source },
        .public_identity = "post-exit-virtio-renderer",
        .public_identity_ready = true,
    }) catch return fail(emit, error.RendererIrFailed, "FAIL post-exit virtio-gpu app-frame");
    emit("check: post-exit virtio-gpu app-frame built");

    state.app_font_atlas.initWithFontInPlace(renderer_font_atlas.geist_ascii_font.body());
    const buffers = state.app_ir_storage.buffers();
    renderer_pipeline.packScene(buffers, &state.app_font_atlas, .object, scene.written()) catch return fail(emit, error.RendererIrFailed, "FAIL post-exit virtio-gpu pack-app");
    emit("check: post-exit virtio-gpu app-frame packed");

    const surface = renderer_pipeline.softwareFramebuffer(
        virtio_scanout_width,
        virtio_scanout_height,
        &state.app_pixels,
    ) catch return fail(emit, error.RendererIrFailed, "FAIL post-exit virtio-gpu surface");
    const image_texture = if (buffers.hasImageVertices())
        app_images.cloudMeme() catch return fail(emit, error.RendererIrFailed, "FAIL post-exit virtio-gpu image")
    else
        null;
    const receipt = renderer_pipeline.renderSoftwareFrame(
        surface,
        buffers,
        renderer_pipeline.softwareResources(&state.app_font_atlas, image_texture),
        .bg,
    ) catch return fail(emit, error.RendererIrFailed, "FAIL post-exit virtio-gpu software-render");
    if (!receipt.valid()) return fail(emit, error.RendererIrFailed, "FAIL post-exit virtio-gpu render-receipt");
    emit("check: post-exit virtio-gpu app-frame rasterized");

    virtio_gpu.copyRgbaPixelsToBgra(
        virtio_scanout_width,
        virtio_scanout_height,
        &state.virtio_scanout,
        &state.app_pixels,
    ) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu copy-app");
    emit("check: post-exit virtio-gpu app-frame copied");

    device.transferToHost3d(
        &state.virtio_queue,
        virtio_gl_context_id,
        virtio_gl_resource_id,
        virtio_scanout_width,
        virtio_scanout_height,
        virtio_scanout_width * 4,
    ) catch |err| return fail(emit, mapVirtioGpuError(err), "FAIL post-exit virtio-gpu transfer-packed");
}

fn fillVirtioScanout(out: []u8) void {
    var y: u32 = 0;
    while (y < virtio_scanout_height) : (y += 1) {
        var x: u32 = 0;
        while (x < virtio_scanout_width) : (x += 1) {
            const index: usize = (@as(usize, y) * virtio_scanout_width + x) * 4;
            const accent = ((x / 32) + (y / 32)) % 2 == 0;
            const color = if (accent)
                ui.Color{ .r = 34, .g = 211, .b = 238, .a = 255 }
            else
                ui.Color{ .r = 18, .g = 26, .b = 38, .a = 255 };
            out[index + 0] = color.b;
            out[index + 1] = color.g;
            out[index + 2] = color.r;
            out[index + 3] = 0xff;
        }
    }
}

fn mapVirtioGpuError(err: virtio_gpu.Error) Error {
    return switch (err) {
        error.DeviceNotFound => error.VirtioGpuDeviceNotFound,
        error.DeviceTimeout => error.VirtioGpuTimeout,
        error.InvalidResponse => error.VirtioGpuInvalidResponse,
        error.UnsupportedPackedFrame => error.VirtioGpuUnsupported,
        error.FeatureNegotiationFailed,
        error.InvalidBar,
        error.MissingCapability,
        error.MissingTransport,
        error.QueueSetupFailed,
        error.QueueTooSmall,
        error.UnsupportedDevice,
        => error.VirtioGpuUnsupported,
    };
}

fn runKernelChecks(state: *State, emit: Reporter) Error!void {
    state.allocator = content_kernel.Allocator.init(&state.allocator_allocations);
    state.allocator.addAllocation(content_kernel.Allocation.init(chunk("post-exit-sender"), chunk("post-exit-app-a"), 64)) catch {
        return fail(emit, error.AllocationSenderFailed, "FAIL post-exit allocation sender");
    };
    state.allocator.addAllocation(content_kernel.Allocation.init(chunk("post-exit-receiver"), chunk("post-exit-app-b"), 64)) catch {
        return fail(emit, error.AllocationReceiverFailed, "FAIL post-exit allocation receiver");
    };

    if (!state.allocator.rangeValid(content_kernel.AddressRange.init(chunk("post-exit-sender"), 8, 16))) {
        return fail(emit, error.ValidRangeRejected, "FAIL post-exit valid range rejected");
    }
    if (state.allocator.rangeValid(content_kernel.AddressRange.init(chunk("post-exit-sender"), 60, 8))) {
        return fail(emit, error.OutOfBoundsRangeAccepted, "FAIL post-exit out-of-bounds range accepted");
    }
    emit("check: post-exit allocation-relative-address ok");

    state.view = state.allocator.createView(content_kernel.MemoryView.init(
        chunk("post-exit-view"),
        content_kernel.AddressRange.init(chunk("post-exit-sender"), 8, 16),
        chunk("post-exit-app-b"),
        false,
        4,
    )) catch {
        return fail(emit, error.ViewCreateFailed, "FAIL post-exit view create");
    };
    if (!state.allocator.canRead(state.view, chunk("post-exit-app-b"))) {
        return fail(emit, error.ViewReadRejected, "FAIL post-exit view read rejected");
    }
    if (state.allocator.canWrite(state.view, chunk("post-exit-app-b"))) {
        return fail(emit, error.ReadOnlyViewWritable, "FAIL post-exit read-only view writable");
    }
    emit("check: post-exit memory-view ok");

    state.allocator.advance(5) catch {
        return fail(emit, error.ClockAdvanceFailed, "FAIL post-exit clock advance");
    };
    if (state.allocator.canRead(state.view, chunk("post-exit-app-b"))) {
        return fail(emit, error.ExpiredViewReadable, "FAIL post-exit expired view readable");
    }
    emit("check: post-exit clock-expiry ok");
}

fn runResourceContractChecks(state: *State, inventory: resource_inventory.Inventory, emit: Reporter) Error!void {
    const memory_resource = firstMemoryResource(inventory) orelse return fail(emit, error.MemoryResourceMissing, "FAIL post-exit memory resource missing");
    if (memory_resource.bounds.length < post_exit_contract_bytes * 2) {
        return fail(emit, error.MemoryResourceTooSmall, "FAIL post-exit memory resource too small");
    }

    state.schedule = resource_contract.Schedule.init(&state.contracts);
    const first_contract = resource_contract.Contract.init(
        chunk("post-exit-contract-a"),
        chunk("post-exit-app-a"),
        memory_resource.id,
        .memory,
        contract_start_tick,
        contract_end_tick,
        resource_contract.Bounds.init(memory_resource.bounds.offset, post_exit_contract_bytes),
        resource_contract.Pattern.exclusive(),
    );
    const second_contract = resource_contract.Contract.init(
        chunk("post-exit-contract-b"),
        chunk("post-exit-app-b"),
        memory_resource.id,
        .memory,
        contract_start_tick,
        contract_end_tick,
        resource_contract.Bounds.init(memory_resource.bounds.offset + post_exit_contract_bytes, post_exit_contract_bytes),
        resource_contract.Pattern.exclusive(),
    );
    state.schedule.installChecked(inventory, first_contract) catch {
        return fail(emit, error.ContractAInstallFailed, "FAIL post-exit contract-a install");
    };
    state.schedule.installChecked(inventory, second_contract) catch {
        return fail(emit, error.ContractBInstallFailed, "FAIL post-exit contract-b install");
    };
    const first_owner = state.schedule.ownerAt(memory_resource.id, contract_check_tick) orelse {
        return fail(emit, error.ContractOwnerMissing, "FAIL post-exit contract owner missing");
    };
    if (!sameChunk(first_owner, chunk("post-exit-app-a"))) {
        return fail(emit, error.ContractOwnerMismatch, "FAIL post-exit contract owner mismatch");
    }
    emit("check: post-exit resource-contract ownership ok");

    const overlapping_contract = resource_contract.Contract.init(
        chunk("post-exit-contract-conflict"),
        chunk("post-exit-app-c"),
        memory_resource.id,
        .memory,
        contract_start_tick,
        contract_end_tick,
        resource_contract.Bounds.init(memory_resource.bounds.offset + 1, post_exit_contract_bytes),
        resource_contract.Pattern.exclusive(),
    );
    state.schedule.installChecked(inventory, overlapping_contract) catch |err| switch (err) {
        error.Conflict => {
            emit("check: post-exit resource-contract conflict ok");
            return;
        },
        else => return fail(emit, error.ContractConflictWrongError, "FAIL post-exit wrong contract conflict error"),
    };
    return fail(emit, error.OverlappingContractAccepted, "FAIL post-exit overlapping contract accepted");
}

noinline fn runWasmAppChecks(state: *State, emit: Reporter) Error!void {
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{128} ++ [_]u8{0} ** 31 } };
    state.parent = testIdentity(.app, "post-exit runtime parent", epoch) orelse return fail(emit, error.ParentIdentityFailed, "FAIL post-exit parent identity");
    state.app = testIdentity(.app, "post-exit runtime app", epoch) orelse return fail(emit, error.AppIdentityFailed, "FAIL post-exit app identity");

    const allocation = App.DeclaredAllocation{
        .memory_bytes = post_exit_private_memory_len,
        .storage_bytes = 0,
        .storage_slots = 0,
        .execution_ticks = post_exit_app_execution_ticks,
    };
    const image = kernel_runtime.WasmAppImage.init(&return_forty_two_wasm, "main", allocation) orelse {
        return fail(emit, error.WasmImageInvalid, "FAIL post-exit wasm image invalid");
    };
    const app_chunk = data_chunk.DataChunk.init(&state.app.id.bytes);
    const app_resource = resource_inventory.Resource.init(
        chunk("post-exit-app-memory"),
        .memory,
        resource_contract.Bounds.init(post_exit_app_memory_offset, post_exit_app_memory_len),
    );
    state.app_inventory = resource_inventory.Inventory.init(&state.app_resources);
    state.app_inventory.add(app_resource) catch {
        return fail(emit, error.WasmInventoryFailed, "FAIL post-exit wasm inventory");
    };
    const public_contract = postExitAppMemoryContract("post-exit-public-memory", app_chunk, post_exit_app_memory_offset, post_exit_public_memory_len);
    const private_contract = postExitAppMemoryContract("post-exit-private-memory", app_chunk, post_exit_private_memory_offset, post_exit_private_memory_len);
    const memory_plan = resource_inventory.AppMemoryPlan.init(app_chunk, public_contract, private_contract);
    if (!memory_plan.fits(state.app_inventory)) return fail(emit, error.WasmMemoryPlanInvalid, "FAIL post-exit wasm memory plan");
    emit("check: post-exit wasm memory-plan ok");

    state.app_schedule = resource_contract.Schedule.init(&state.app_contracts);
    state.first_app_runtime = kernel_runtime.Runtime.init(
        state.app_inventory,
        state.app_schedule,
        app_resource,
        &state.app_memory,
    );
    state.first_app_runtime.runWasmImageI64IntoWithStorageAndScratch(.{
        .parent = state.parent,
        .app = state.app,
        .public_contract = public_contract,
        .private_contract = private_contract,
        .input = hash("post-exit wasm input"),
        .clock_start = epoch,
        .clock_end = .{ .keeper = epoch.keeper, .tick = 2 },
    }, image, &state.wasm_storage, &state.first_app_scratch, &state.first_app_result) catch |err| switch (err) {
        error.BadArgument => return fail(emit, error.WasmRuntimeBadArgument, "FAIL post-exit wasm runtime bad argument"),
        error.Corrupt => return fail(emit, error.WasmRuntimeCorruptReceipt, "FAIL post-exit wasm runtime corrupt receipt"),
        error.NoMemory => return fail(emit, error.WasmRuntimeNoMemory, "FAIL post-exit wasm runtime no memory"),
        error.OutOfBounds => return fail(emit, error.WasmRuntimeOutOfBounds, "FAIL post-exit wasm runtime out of bounds"),
        else => return fail(emit, error.WasmRuntimeLaunchFailed, "FAIL post-exit wasm runtime launch"),
    };
    if (state.first_app_runtime.schedule.len != 2) return fail(emit, error.WasmPrivateContractFailed, "FAIL post-exit wasm private contract");
    emit("check: post-exit wasm contracts-installed ok");
    emit("check: post-exit wasm app allocated");
    if (state.first_app_result.value != post_exit_expected_value) return fail(emit, error.WasmResultMismatch, "FAIL post-exit wasm result");
    emit("check: post-exit wasm execution ok");

    if (!state.first_app_result.receipt.valid()) return fail(emit, error.WasmReceiptInvalid, "FAIL post-exit wasm receipt invalid");
    if (!std.mem.eql(u8, &state.first_app_result.receipt.app_hash, &image.code_hash) or
        !std.mem.eql(u8, &state.first_app_result.receipt.manifest, &image.manifest))
    {
        return fail(emit, error.WasmReceiptImageMismatch, "FAIL post-exit wasm receipt image");
    }
    if (state.first_app_result.receipt.execution_used != post_exit_expected_execution_used) {
        return fail(emit, error.WasmReceiptExecutionMismatch, "FAIL post-exit wasm receipt execution");
    }
    emit("check: post-exit wasm receipt ok");
}

fn runRegistryChecks(state: *State, emit: Reporter) Error!void {
    state.registry_allocator = content_kernel.Allocator.init(&state.registry_allocations);
    state.registry = registry_app.Registry.init(&state.registry_entries);
    state.registry_allocator.addAllocation(content_kernel.Allocation.init(chunk("post-exit-route-sender"), chunk("post-exit-route-app-a"), 64)) catch {
        return fail(emit, error.RegistrySenderAllocationFailed, "FAIL post-exit registry sender allocation");
    };
    state.registry_allocator.addAllocation(content_kernel.Allocation.init(chunk("post-exit-route-receiver"), chunk("post-exit-route-app-b"), 64)) catch {
        return fail(emit, error.RegistryReceiverAllocationFailed, "FAIL post-exit registry receiver allocation");
    };

    state.registry.register(state.registry_allocator, registry_app.EndpointRegistration.init(
        chunk("post-exit-receiver-endpoint"),
        chunk("post-exit-receiver-state"),
        chunk("post-exit-route-receiver"),
        chunk("post-exit-message-definition"),
        chunk("post-exit-sender-endpoint"),
        10,
    )) catch {
        return fail(emit, error.RegistryRegistrationFailed, "FAIL post-exit registry registration");
    };

    state.registry_view = state.registry_allocator.createView(content_kernel.MemoryView.init(
        chunk("post-exit-route-view"),
        content_kernel.AddressRange.init(chunk("post-exit-route-sender"), 8, 16),
        chunk("post-exit-sender-endpoint"),
        false,
        10,
    )) catch {
        return fail(emit, error.RegistryViewFailed, "FAIL post-exit registry view");
    };

    const routed = state.registry.route(state.registry_allocator, registry_app.MessageEnvelope.init(
        chunk("post-exit-sender-endpoint"),
        chunk("post-exit-receiver-endpoint"),
        chunk("post-exit-message-definition"),
        chunk("post-exit-route-view"),
        10,
    ), state.registry_view) catch {
        return fail(emit, error.RegistryRouteFailed, "FAIL post-exit registry route");
    };
    if (!sameChunk(routed.app_state_id, chunk("post-exit-receiver-state"))) {
        return fail(emit, error.RegistryStateMismatch, "FAIL post-exit registry state mismatch");
    }
    emit("check: post-exit registry-route ok");

    _ = state.registry.route(state.registry_allocator, registry_app.MessageEnvelope.init(
        chunk("post-exit-wrong-sender"),
        chunk("post-exit-receiver-endpoint"),
        chunk("post-exit-message-definition"),
        chunk("post-exit-route-view"),
        10,
    ), state.registry_view) catch |err| switch (err) {
        error.Unauthorized => {
            emit("check: post-exit registry sender-restriction ok");
            return;
        },
        else => return fail(emit, error.RegistryWrongSenderError, "FAIL post-exit registry wrong sender error"),
    };
    return fail(emit, error.RegistryAcceptedWrongSender, "FAIL post-exit registry accepted wrong sender");
}

fn firstMemoryResource(value: resource_inventory.Inventory) ?resource_inventory.Resource {
    for (value.resources[0..value.len]) |resource| {
        if (resource.kind == .memory and resource.bounds.length >= min_memory_bytes) return resource;
    }
    return null;
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and std.mem.eql(u8, left.body(), right.body());
}

fn testIdentity(kind: identity.Kind, material: []const u8, epoch: clock.Stamp) ?identity.Identity {
    return identity.Identity.init(kind, identity.Source.prepare(.hash, &preimage.rawHash(material)) orelse return null, epoch);
}

fn postExitAppMemoryContract(id: []const u8, app: data_chunk.DataChunk, offset: u64, length: u64) resource_contract.Contract {
    return resource_contract.Contract.init(
        chunk(id),
        app,
        chunk("post-exit-app-memory"),
        .memory,
        contract_start_tick,
        contract_end_tick,
        resource_contract.Bounds.init(offset, length),
        resource_contract.Pattern.exclusive(),
    );
}

fn hash(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:post-exit-kernel", material);
}

fn fail(emit: Reporter, err: Error, message: []const u8) Error {
    emit(message);
    return err;
}

fn ignoreLine(_: []const u8) void {}

test "post-exit kernel state machine runs without firmware services" {
    const testing = std.testing;
    var state: State = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    var inventory = resource_inventory.Inventory.init(&resources);
    try inventory.add(resource_inventory.Resource.init(
        chunk("test-memory"),
        .memory,
        resource_contract.Bounds.init(0, min_memory_bytes),
    ));

    try run(&state, inventory, ignoreLine);

    try testing.expectEqual(@as(u64, state_marker), state.marker);
    try testing.expectEqual(@as(i64, post_exit_expected_value), state.first_app_result.value);
    try testing.expect(state.first_app_result.receipt.valid());
    try testing.expectEqual(@as(usize, 2), state.first_app_runtime.schedule.len);
}

test "post-exit virtio renderer keeps packed icon line batches" {
    const source = @embedFile("immutable_kernel_post_exit.zig");
    try std.testing.expect(std.mem.indexOf(u8, source, "buffers.icon_line_vertex_len" ++ ".* = 0") == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "buffers.overlay_icon_line_vertex_len" ++ ".* = 0") == null);
}

test "post-exit kernel state machine rejects empty handoff inventory" {
    var state: State = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    const inventory = resource_inventory.Inventory.init(&resources);

    try std.testing.expectError(error.InventoryLost, run(&state, inventory, ignoreLine));
}

test "post-exit kernel state machine rejects handoff inventory without usable memory" {
    var state: State = undefined;
    var resources: [1]resource_inventory.Resource = undefined;
    var inventory = resource_inventory.Inventory.init(&resources);
    try inventory.add(resource_inventory.Resource.init(
        chunk("too-small-memory"),
        .memory,
        resource_contract.Bounds.init(0, min_memory_bytes - 1),
    ));

    try std.testing.expect(!hasMemory(inventory));
    try std.testing.expectError(error.MemoryResourceMissing, run(&state, inventory, ignoreLine));
}
