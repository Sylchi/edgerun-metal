const std = @import("std");
const bytes_mod = @import("bytes.zig");
const icon_pack = @import("icon_pack.zig");
const interaction = @import("ui_interaction.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_gpu = @import("render/backends/gpu.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_native_present = @import("render/native_present.zig");
const renderer_software = @import("render/backends/software.zig");
const renderer_gpu_buffer = @import("render/gpu_buffer.zig");
const app_chrome = @import("app_chrome.zig");
const app_agent = @import("app_agent.zig");
const app_cursor = @import("app_cursor.zig");
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const app_navigation = @import("app_navigation.zig");
const app_native_input = @import("app_native_input.zig");
const app_dashboard = @import("app_dashboard.zig");
const app_hardware_dashboard = @import("app_hardware_dashboard.zig");
const icon_component = @import("ui/components/Icon.zig");
const ui = @import("ui.zig");
const text_component = @import("ui/components/Text.zig");

const protocol = @import("wayland/protocol.zig");
const messages = @import("wayland/messages.zig");
const client_import = @import("wayland/client.zig");
const options_import = @import("wayland/options.zig");
const app_import = @import("wayland/app.zig");

const posix = std.posix;
const linux = std.os.linux;

// ── Protocol re-exports ──

pub const display_id = protocol.display_id;
pub const registry_id = protocol.registry_id;
pub const sync_callback_id = protocol.sync_callback_id;
pub const compositor_id = protocol.compositor_id;
pub const shm_id = protocol.shm_id;
pub const wm_base_id = protocol.wm_base_id;
pub const seat_id = protocol.seat_id;
pub const pointer_id = protocol.pointer_id;
pub const surface_id = protocol.surface_id;
pub const xdg_surface_id = protocol.xdg_surface_id;
pub const xdg_toplevel_id = protocol.xdg_toplevel_id;
pub const shm_pool_id = protocol.shm_pool_id;
pub const wl_buffer_id = protocol.wl_buffer_id;
pub const linux_dmabuf_id = protocol.linux_dmabuf_id;
pub const dmabuf_params_id = protocol.dmabuf_params_id;
pub const dmabuf_wl_buffer_id = protocol.dmabuf_wl_buffer_id;
pub const xdg_decoration_manager_id = protocol.xdg_decoration_manager_id;
pub const xdg_toplevel_decoration_id = protocol.xdg_toplevel_decoration_id;

pub const wl_display_sync = protocol.wl_display_sync;
pub const wl_display_get_registry = protocol.wl_display_get_registry;
pub const wl_registry_bind = protocol.wl_registry_bind;
pub const wl_compositor_create_surface = protocol.wl_compositor_create_surface;
pub const wl_seat_get_pointer = protocol.wl_seat_get_pointer;
pub const wl_pointer_set_cursor = protocol.wl_pointer_set_cursor;
pub const wl_shm_create_pool = protocol.wl_shm_create_pool;
pub const wl_shm_pool_create_buffer = protocol.wl_shm_pool_create_buffer;
pub const wl_shm_pool_destroy = protocol.wl_shm_pool_destroy;
pub const wl_surface_attach = protocol.wl_surface_attach;
pub const wl_surface_damage_buffer = protocol.wl_surface_damage_buffer;
pub const wl_surface_commit = protocol.wl_surface_commit;
pub const xdg_wm_base_get_xdg_surface = protocol.xdg_wm_base_get_xdg_surface;
pub const xdg_wm_base_pong = protocol.xdg_wm_base_pong;
pub const xdg_surface_get_toplevel = protocol.xdg_surface_get_toplevel;
pub const xdg_surface_ack_configure = protocol.xdg_surface_ack_configure;
pub const xdg_toplevel_set_title = protocol.xdg_toplevel_set_title;
pub const xdg_toplevel_set_app_id = protocol.xdg_toplevel_set_app_id;
pub const xdg_toplevel_move = protocol.xdg_toplevel_move;
pub const xdg_toplevel_set_minimized = protocol.xdg_toplevel_set_minimized;
pub const xdg_decoration_manager_get_toplevel_decoration = protocol.xdg_decoration_manager_get_toplevel_decoration;
pub const xdg_toplevel_decoration_set_mode = protocol.xdg_toplevel_decoration_set_mode;
pub const zwp_linux_dmabuf_create_params = protocol.zwp_linux_dmabuf_create_params;
pub const zwp_linux_buffer_params_add = protocol.zwp_linux_buffer_params_add;
pub const zwp_linux_buffer_params_create_immed = protocol.zwp_linux_buffer_params_create_immed;

pub const wl_display_error_event = protocol.wl_display_error_event;
pub const wl_registry_global_event = protocol.wl_registry_global_event;
pub const wl_callback_done_event = protocol.wl_callback_done_event;
pub const wl_pointer_enter_event = protocol.wl_pointer_enter_event;
pub const wl_pointer_leave_event = protocol.wl_pointer_leave_event;
pub const wl_pointer_motion_event = protocol.wl_pointer_motion_event;
pub const wl_pointer_button_event = protocol.wl_pointer_button_event;
pub const wl_pointer_axis_event = protocol.wl_pointer_axis_event;
pub const wl_seat_capabilities_event = protocol.wl_seat_capabilities_event;
pub const xdg_wm_base_ping_event = protocol.xdg_wm_base_ping_event;
pub const xdg_surface_configure_event = protocol.xdg_surface_configure_event;
pub const xdg_toplevel_close_event = protocol.xdg_toplevel_close_event;

pub const wl_shm_format_xrgb8888 = protocol.wl_shm_format_xrgb8888;
pub const drm_format_xrgb8888 = protocol.drm_format_xrgb8888;
pub const drm_format_argb8888 = protocol.drm_format_argb8888;
pub const dmabuf_flags_none = protocol.dmabuf_flags_none;
pub const wl_pointer_button_left = protocol.wl_pointer_button_left;
pub const wl_pointer_button_released = protocol.wl_pointer_button_released;
pub const wl_pointer_axis_vertical_scroll = protocol.wl_pointer_axis_vertical_scroll;
pub const wl_seat_capability_pointer = protocol.wl_seat_capability_pointer;
pub const xdg_toplevel_decoration_mode_server_side = protocol.xdg_toplevel_decoration_mode_server_side;
pub const fixed_scale = protocol.fixed_scale;

pub const client_decor_h = protocol.client_decor_h;
pub const client_decor_button_size = protocol.client_decor_button_size;
pub const client_decor_button_gap = protocol.client_decor_button_gap;
pub const client_decor_icon_size = protocol.client_decor_icon_size;
pub const client_decor_minimize_w = protocol.client_decor_minimize_w;
pub const client_decor_minimize_h = protocol.client_decor_minimize_h;
pub const client_decor_close_id = protocol.client_decor_close_id;
pub const client_decor_minimize_id = protocol.client_decor_minimize_id;
pub const client_decor_drag_id = protocol.client_decor_drag_id;
pub const client_decor_bg = protocol.client_decor_bg;
pub const client_decor_border = protocol.client_decor_border;
pub const client_decor_text = protocol.client_decor_text;
pub const client_decor_dim = protocol.client_decor_dim;

pub const ObjectKind = protocol.ObjectKind;
pub const RegistryInterface = protocol.RegistryInterface;
pub const RegistryGlobal = protocol.RegistryGlobal;
pub const RegistryState = protocol.RegistryState;
pub const WaylandState = protocol.WaylandState;
pub const Message = protocol.Message;
pub const MessageWriter = protocol.MessageWriter;
pub const PixelRect = protocol.PixelRect;
pub const DmabufImport = protocol.DmabufImport;
pub const ShmBuffer = protocol.ShmBuffer;

pub const isSupportedDmabufFormat = protocol.isSupportedDmabufFormat;
pub const dmabufFormat = protocol.dmabufFormat;

// ── Messages re-exports ──

pub const makeGetRegistry = messages.makeGetRegistry;
pub const makeSync = messages.makeSync;
pub const makeBind = messages.makeBind;
pub const makeCreateSurface = messages.makeCreateSurface;
pub const makeGetPointer = messages.makeGetPointer;
pub const makeHidePointerCursor = messages.makeHidePointerCursor;
pub const makeCreatePool = messages.makeCreatePool;
pub const makeCreateBuffer = messages.makeCreateBuffer;
pub const makeDestroyPool = messages.makeDestroyPool;
pub const makeDmabufCreateParams = messages.makeDmabufCreateParams;
pub const makeDmabufAddPlane = messages.makeDmabufAddPlane;
pub const makeDmabufCreateImmediate = messages.makeDmabufCreateImmediate;
pub const makeGetXdgSurface = messages.makeGetXdgSurface;
pub const makeGetToplevel = messages.makeGetToplevel;
pub const makeSetTitle = messages.makeSetTitle;
pub const makeSetAppId = messages.makeSetAppId;
pub const makeMove = messages.makeMove;
pub const makeSetMinimized = messages.makeSetMinimized;
pub const makeGetToplevelDecoration = messages.makeGetToplevelDecoration;
pub const makeSetServerSideDecoration = messages.makeSetServerSideDecoration;
pub const makeSurfaceCommit = messages.makeSurfaceCommit;
pub const makeAttach = messages.makeAttach;
pub const makeDamageBuffer = messages.makeDamageBuffer;
pub const makeDamageBufferRect = messages.makeDamageBufferRect;
pub const makePong = messages.makePong;
pub const makeAckConfigure = messages.makeAckConfigure;

pub const nextMessage = messages.nextMessage;
pub const handleMessage = messages.handleMessage;
pub const parseRegistryGlobal = messages.parseRegistryGlobal;
pub const registryInterface = messages.registryInterface;
pub const writeAll = messages.writeAll;
pub const sendFd = messages.sendFd;
pub const truncateFd = messages.truncateFd;

// ── Options re-exports ──

pub const Options = options_import.Options;
pub const PresentMode = options_import.PresentMode;
pub const parseOptions = options_import.parseOptions;
pub const help = options_import.help;
pub const parseHostIp = options_import.parseHostIp;
pub const isHostApiReachable = options_import.isHostApiReachable;
pub const parsePresentMode = options_import.parsePresentMode;
pub const waylandSocketPath = options_import.waylandSocketPath;

// ── Client re-exports ──

pub const WaylandClient = client_import.WaylandClient;

// ── App re-exports ──

pub const AppState = app_import.AppState;
pub const NativeApp = app_import.NativeApp;
pub const renderNativeAppScene = app_import.renderNativeAppScene;
pub const appBackground = app_import.appBackground;
pub const packXrgb8888 = app_import.packXrgb8888;
pub const packXrgb8888Rect = app_import.packXrgb8888Rect;
pub const packXrgb8888Strided = app_import.packXrgb8888Strided;
pub const cursorPixelRect = app_import.cursorPixelRect;
pub const unionPixelRect = app_import.unionPixelRect;
pub const fixedToFloat = app_import.fixedToFloat;
pub const updateHoverHitForState = app_import.updateHoverHitForState;
pub const activateClientDecorationForState = app_import.activateClientDecorationForState;
pub const scrollStateBy = app_import.scrollStateBy;
pub const GpuRecorder = app_import.GpuRecorder;
pub const IrStorage = app_import.IrStorage;
pub const hasText = app_import.hasText;
pub const hasRectColor = app_import.hasRectColor;
pub const hasIcon = app_import.hasIcon;
pub const hasIconId = app_import.hasIconId;
pub const hitRect = app_import.hitRect;

pub const max_commands = app_import.max_commands;
pub const max_clips = app_import.max_clips;
pub const max_interaction_regions = app_import.max_interaction_regions;
pub const default_refresh_hz = app_import.default_refresh_hz;

// ── Entry point ──

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const opts = options_import.parseOptions(args) catch |err| {
        if (err == error.HelpRequested) {
            options_import.help();
            return;
        }
        return err;
    };
    std.debug.print("args={any} options.hardware={}\n", .{ args, opts.hardware });
    const socket_path = try options_import.waylandSocketPath(init, allocator);
    defer allocator.free(socket_path);
    var client = try client_import.WaylandClient.connect(init.io, socket_path);
    defer client.close(init.io);
    try client.bootstrap();
    try client.createWindow(opts.width, opts.height);
    const app = try app_import.NativeApp.create(&client, allocator, opts);
    defer app.destroy();
    app.refreshAgentHostConnectivity();
    app.renderSafe(&client);
    try client.eventLoop(opts.seconds, app);
}

// ── Test helpers ──

fn pixelBufferHasPaint(pixels: []const ui.Color) bool {
    for (pixels) |pixel| {
        if (pixel.a != 0) return true;
    }
    return false;
}

// ── Tests ──

test "wayland bind message encodes registry name interface version and new id" {
    var buffer: [128]u8 = undefined;
    const bytes = try makeBind(&buffer, 17, "wl_compositor", 4, compositor_id);
    try std.testing.expectEqual(@as(u32, registry_id), std.mem.readInt(u32, bytes[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_registry_bind), std.mem.readInt(u16, bytes[4..6], .little));
    try std.testing.expectEqual(@as(u16, 40), std.mem.readInt(u16, bytes[6..8], .little));
    try std.testing.expectEqual(@as(u32, 17), std.mem.readInt(u32, bytes[8..12], .little));
    try std.testing.expectEqual(@as(u32, 14), std.mem.readInt(u32, bytes[12..16], .little));
    try std.testing.expectEqualStrings("wl_compositor", bytes[16..29]);
    try std.testing.expectEqual(@as(u32, 4), std.mem.readInt(u32, bytes[32..36], .little));
    try std.testing.expectEqual(@as(u32, compositor_id), std.mem.readInt(u32, bytes[36..40], .little));
}

test "wayland host parses explicit presentation mode" {
    try std.testing.expectEqual(PresentMode.cpu, try parsePresentMode("cpu"));
    try std.testing.expectEqual(PresentMode.gpu_record, try parsePresentMode("gpu-record"));
    try std.testing.expectEqual(PresentMode.gpu_dmabuf, try parsePresentMode("gpu-dmabuf"));
    try std.testing.expectError(error.InvalidArguments, parsePresentMode("gpu"));

    const args = [_][:0]const u8{ "wayland-window", "--width", "800", "--height", "600", "--seconds", "1", "--present", "gpu-record", "--path", "/academy" };
    const opts = try parseOptions(&args);
    try std.testing.expectEqual(@as(u32, 800), opts.width);
    try std.testing.expectEqual(@as(u32, 600), opts.height);
    try std.testing.expectEqual(@as(u32, 1), opts.seconds);
    try std.testing.expectEqual(PresentMode.gpu_record, opts.present);
    try std.testing.expectEqualStrings("/academy", opts.path);

    const dmabuf_args = [_][:0]const u8{ "wayland-window", "--present", "gpu-dmabuf", "--dmabuf-fd", "17" };
    const dmabuf_options = try parseOptions(&dmabuf_args);
    try std.testing.expectEqual(PresentMode.gpu_dmabuf, dmabuf_options.present);
    try std.testing.expectEqual(@as(posix.fd_t, 17), dmabuf_options.dmabuf_fd.?);

    const allocated_dmabuf_args = [_][:0]const u8{ "wayland-window", "--present", "gpu-dmabuf", "--drm-device", "/dev/dri/card1" };
    const allocated_dmabuf_options = try parseOptions(&allocated_dmabuf_args);
    try std.testing.expectEqual(PresentMode.gpu_dmabuf, allocated_dmabuf_options.present);
    try std.testing.expectEqualStrings("/dev/dri/card1", allocated_dmabuf_options.drm_device);
    try std.testing.expect(allocated_dmabuf_options.dmabuf_fd == null);
}

test "wayland host endpoint parser extracts host without port" {
    const host = parseHostIp("http://192.168.1.201:5001/v1") orelse return error.InvalidArguments;
    try std.testing.expectEqualStrings("192.168.1.201", host);
}

test "wayland host endpoint parser rejects unsupported host format" {
    try std.testing.expect(parseHostIp("localhost:5001/v1") == null);
    try std.testing.expect(parseHostIp("http://192.168.1.201") == null);
    try std.testing.expect(parseHostIp("http://192.168.1:5001") == null);
}

test "wayland registry global parser keeps interface slice and version" {
    var payload: [32]u8 = undefined;
    std.mem.writeInt(u32, payload[0..4], 11, .little);
    std.mem.writeInt(u32, payload[4..8], 7, .little);
    @memcpy(payload[8..14], "wl_shm");
    payload[14] = 0;
    payload[15] = 0;
    std.mem.writeInt(u32, payload[16..20], 1, .little);
    const global = try parseRegistryGlobal(payload[0..20]);
    try std.testing.expectEqual(@as(u32, 11), global.name);
    try std.testing.expectEqual(RegistryInterface.shm, global.interface);
    try std.testing.expectEqual(@as(u32, 1), global.version);
}

test "wayland registry parser discovers linux dmabuf global" {
    var payload: [48]u8 = undefined;
    std.mem.writeInt(u32, payload[0..4], 23, .little);
    std.mem.writeInt(u32, payload[4..8], 20, .little);
    @memcpy(payload[8..27], "zwp_linux_dmabuf_v1");
    payload[27] = 0;
    std.mem.writeInt(u32, payload[28..32], 4, .little);
    const global = try parseRegistryGlobal(payload[0..32]);
    try std.testing.expectEqual(@as(u32, 23), global.name);
    try std.testing.expectEqual(RegistryInterface.linux_dmabuf, global.interface);
    try std.testing.expectEqual(@as(u32, 4), global.version);
}

test "wayland registry parser discovers xdg decoration manager global" {
    var payload: [48]u8 = undefined;
    std.mem.writeInt(u32, payload[0..4], 31, .little);
    std.mem.writeInt(u32, payload[4..8], 27, .little);
    @memcpy(payload[8..34], "zxdg_decoration_manager_v1");
    payload[34] = 0;
    payload[35] = 0;
    std.mem.writeInt(u32, payload[36..40], 1, .little);
    const global = try parseRegistryGlobal(payload[0..40]);
    try std.testing.expectEqual(@as(u32, 31), global.name);
    try std.testing.expectEqual(RegistryInterface.xdg_decoration_manager, global.interface);
    try std.testing.expectEqual(@as(u32, 1), global.version);
}

test "wayland xdg decoration message encoders stay explicit but unused by client chrome" {
    var get_buffer: [64]u8 = undefined;
    const get = try makeGetToplevelDecoration(&get_buffer);
    try std.testing.expectEqual(@as(u32, xdg_decoration_manager_id), std.mem.readInt(u32, get[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_decoration_manager_get_toplevel_decoration), std.mem.readInt(u16, get[4..6], .little));
    try std.testing.expectEqual(@as(u16, 16), std.mem.readInt(u16, get[6..8], .little));
    try std.testing.expectEqual(@as(u32, xdg_toplevel_decoration_id), std.mem.readInt(u32, get[8..12], .little));
    try std.testing.expectEqual(@as(u32, xdg_toplevel_id), std.mem.readInt(u32, get[12..16], .little));

    var mode_buffer: [64]u8 = undefined;
    const mode = try makeSetServerSideDecoration(&mode_buffer);
    try std.testing.expectEqual(@as(u32, xdg_toplevel_decoration_id), std.mem.readInt(u32, mode[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_toplevel_decoration_set_mode), std.mem.readInt(u16, mode[4..6], .little));
    try std.testing.expectEqual(@as(u16, 12), std.mem.readInt(u16, mode[6..8], .little));
    try std.testing.expectEqual(xdg_toplevel_decoration_mode_server_side, std.mem.readInt(u32, mode[8..12], .little));
}

test "wayland xdg toplevel client chrome messages encode move and minimize" {
    var move_buffer: [64]u8 = undefined;
    const move_msg = try makeMove(&move_buffer, 77);
    try std.testing.expectEqual(@as(u32, xdg_toplevel_id), std.mem.readInt(u32, move_msg[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_toplevel_move), std.mem.readInt(u16, move_msg[4..6], .little));
    try std.testing.expectEqual(@as(u16, 16), std.mem.readInt(u16, move_msg[6..8], .little));
    try std.testing.expectEqual(@as(u32, seat_id), std.mem.readInt(u32, move_msg[8..12], .little));
    try std.testing.expectEqual(@as(u32, 77), std.mem.readInt(u32, move_msg[12..16], .little));

    var minimize_buffer: [64]u8 = undefined;
    const minimize = try makeSetMinimized(&minimize_buffer);
    try std.testing.expectEqual(@as(u32, xdg_toplevel_id), std.mem.readInt(u32, minimize[0..4], .little));
    try std.testing.expectEqual(@as(u16, xdg_toplevel_set_minimized), std.mem.readInt(u16, minimize[4..6], .little));
    try std.testing.expectEqual(@as(u16, 8), std.mem.readInt(u16, minimize[6..8], .little));
}

test "wayland pointer cursor message hides native compositor cursor" {
    var buffer: [64]u8 = undefined;
    const serial: u32 = 91;
    const msg = try makeHidePointerCursor(&buffer, serial);

    try std.testing.expectEqual(@as(u32, pointer_id), std.mem.readInt(u32, msg[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_pointer_set_cursor), std.mem.readInt(u16, msg[4..6], .little));
    try std.testing.expectEqual(@as(u16, 24), std.mem.readInt(u16, msg[6..8], .little));
    try std.testing.expectEqual(serial, std.mem.readInt(u32, msg[8..12], .little));
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, msg[12..16], .little));
    try std.testing.expectEqual(@as(i32, 0), std.mem.readInt(i32, msg[16..20], .little));
    try std.testing.expectEqual(@as(i32, 0), std.mem.readInt(i32, msg[20..24], .little));
}

test "wayland dmabuf messages encode params add and immediate buffer creation" {
    var create_params_buffer: [64]u8 = undefined;
    const create_params = try makeDmabufCreateParams(&create_params_buffer);
    try std.testing.expectEqual(@as(u32, linux_dmabuf_id), std.mem.readInt(u32, create_params[0..4], .little));
    try std.testing.expectEqual(@as(u16, zwp_linux_dmabuf_create_params), std.mem.readInt(u16, create_params[4..6], .little));
    try std.testing.expectEqual(@as(u16, 12), std.mem.readInt(u16, create_params[6..8], .little));
    try std.testing.expectEqual(@as(u32, dmabuf_params_id), std.mem.readInt(u32, create_params[8..12], .little));

    var add_buffer: [64]u8 = undefined;
    const modifier: u64 = 0x1122334455667788;
    const add = try makeDmabufAddPlane(&add_buffer, 2, 128, 4096, modifier);
    try std.testing.expectEqual(@as(u32, dmabuf_params_id), std.mem.readInt(u32, add[0..4], .little));
    try std.testing.expectEqual(@as(u16, zwp_linux_buffer_params_add), std.mem.readInt(u16, add[4..6], .little));
    try std.testing.expectEqual(@as(u16, 28), std.mem.readInt(u16, add[6..8], .little));
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, add[8..12], .little));
    try std.testing.expectEqual(@as(u32, 128), std.mem.readInt(u32, add[12..16], .little));
    try std.testing.expectEqual(@as(u32, 4096), std.mem.readInt(u32, add[16..20], .little));
    try std.testing.expectEqual(@as(u32, 0x11223344), std.mem.readInt(u32, add[20..24], .little));
    try std.testing.expectEqual(@as(u32, 0x55667788), std.mem.readInt(u32, add[24..28], .little));

    var create_immed_buffer: [64]u8 = undefined;
    const create_immed = try makeDmabufCreateImmediate(&create_immed_buffer, 1280, 800, drm_format_xrgb8888);
    try std.testing.expectEqual(@as(u32, dmabuf_params_id), std.mem.readInt(u32, create_immed[0..4], .little));
    try std.testing.expectEqual(@as(u16, zwp_linux_buffer_params_create_immed), std.mem.readInt(u16, create_immed[4..6], .little));
    try std.testing.expectEqual(@as(u16, 28), std.mem.readInt(u16, create_immed[6..8], .little));
    try std.testing.expectEqual(@as(u32, dmabuf_wl_buffer_id), std.mem.readInt(u32, create_immed[8..12], .little));
    try std.testing.expectEqual(@as(u32, 1280), std.mem.readInt(u32, create_immed[12..16], .little));
    try std.testing.expectEqual(@as(u32, 800), std.mem.readInt(u32, create_immed[16..20], .little));
    try std.testing.expectEqual(drm_format_xrgb8888, std.mem.readInt(u32, create_immed[20..24], .little));
    try std.testing.expectEqual(dmabuf_flags_none, std.mem.readInt(u32, create_immed[24..28], .little));
}

test "wayland dmabuf import validates fd dimensions stride and format" {
    try std.testing.expect((DmabufImport{
        .fd = 3,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
    }).valid());
    try std.testing.expect((DmabufImport{
        .fd = 4,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
        .format = drm_format_argb8888,
    }).valid());
    try std.testing.expect(!(DmabufImport{
        .fd = -1,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
    }).valid());
    try std.testing.expect(!(DmabufImport{
        .fd = 3,
        .width = 64,
        .height = 64,
        .stride = 63 * @sizeOf(u32),
    }).valid());
    try std.testing.expect(!(DmabufImport{
        .fd = 3,
        .width = 64,
        .height = 64,
        .stride = 64 * @sizeOf(u32),
        .format = 0,
    }).valid());
}

test "wayland dmabuf import derives from gpu backed native wayland surface" {
    const import = try DmabufImport.fromNativeSurface(.{ .wayland = .{
        .surface_id = surface_id,
        .buffer_id = dmabuf_wl_buffer_id,
        .width = 320,
        .height = 240,
        .stride = 320,
        .format = .argb8888,
        .gpu_buffer = .{
            .kind = .dma_buf,
            .handle = 7,
            .offset = 128,
            .modifier = 0x0102030405060708,
        },
    } });
    try std.testing.expectEqual(@as(posix.fd_t, 7), import.fd);
    try std.testing.expectEqual(@as(u32, 320), import.width);
    try std.testing.expectEqual(@as(u32, 240), import.height);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);
    try std.testing.expectEqual(drm_format_argb8888, import.format);
    try std.testing.expectEqual(@as(u32, 128), import.offset);
    try std.testing.expectEqual(@as(u64, 0x0102030405060708), import.modifier);

    try std.testing.expectError(error.InvalidDmabufImport, DmabufImport.fromNativeSurface(.{ .wayland = .{
        .surface_id = surface_id,
        .buffer_id = dmabuf_wl_buffer_id,
        .width = 320,
        .height = 240,
        .stride = 320,
        .gpu_buffer = .{ .kind = .scanout, .handle = 9 },
    } }));
    try std.testing.expectError(error.UnsupportedDmabufSurface, DmabufImport.fromNativeSurface(.{ .drm = .{
        .framebuffer_id = 1,
        .connector_id = 2,
        .crtc_id = 3,
        .width = 320,
        .height = 240,
        .stride = 320,
        .gpu_buffer = .{ .kind = .dma_buf, .handle = 11 },
    } }));
}

test "wayland native app builds dmabuf surface only in explicit fd mode" {
    var app = NativeApp{
        .allocator = std.testing.allocator,
        .width = 320,
        .height = 240,
        .present = .gpu_dmabuf,
        .dmabuf_fd = 19,
        .shm = undefined,
        .pixels = &.{},
        .base_pixels = &.{},
        .font_atlas = undefined,
        .gpu_primitives = &.{},
    };
    app.font_atlas.initUtf8();
    const surface = try app.dmabufSurface();
    const import = try DmabufImport.fromNativeSurface(surface);
    try std.testing.expectEqual(@as(posix.fd_t, 19), import.fd);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);

    app.dmabuf_fd = null;
    try std.testing.expectError(error.MissingDmabufFd, app.dmabufSurface());
}

test "wayland native app builds dmabuf surface from owned drm buffer" {
    var app = NativeApp{
        .allocator = std.testing.allocator,
        .width = 320,
        .height = 240,
        .present = .gpu_dmabuf,
        .dmabuf_fd = null,
        .shm = undefined,
        .pixels = &.{},
        .base_pixels = &.{},
        .font_atlas = undefined,
        .gpu_primitives = &.{},
        .drm_buffer = .{
            .drm_fd = 18,
            .dma_buf_fd = 19,
            .handle = 20,
            .width = 320,
            .height = 240,
            .pitch_bytes = 320 * @sizeOf(u32),
            .size = 320 * 240 * @sizeOf(u32),
        },
    };
    app.font_atlas.initUtf8();
    const surface = try app.dmabufSurface();
    const import = try DmabufImport.fromNativeSurface(surface);
    try std.testing.expectEqual(@as(posix.fd_t, 19), import.fd);
    try std.testing.expectEqual(@as(u32, 320 * @sizeOf(u32)), import.stride);
}

test "wayland attach message can target shm or dmabuf buffers" {
    var shm_buffer: [32]u8 = undefined;
    const shm = try makeAttach(&shm_buffer, wl_buffer_id);
    try std.testing.expectEqual(@as(u32, surface_id), std.mem.readInt(u32, shm[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_surface_attach), std.mem.readInt(u16, shm[4..6], .little));
    try std.testing.expectEqual(@as(u16, 20), std.mem.readInt(u16, shm[6..8], .little));
    try std.testing.expectEqual(@as(u32, wl_buffer_id), std.mem.readInt(u32, shm[8..12], .little));

    var dmabuf_buffer: [32]u8 = undefined;
    const dmabuf = try makeAttach(&dmabuf_buffer, dmabuf_wl_buffer_id);
    try std.testing.expectEqual(@as(u32, dmabuf_wl_buffer_id), std.mem.readInt(u32, dmabuf[8..12], .little));
}

test "wayland damage message can target only cursor rectangle" {
    var buffer: [32]u8 = undefined;
    const damage = try makeDamageBufferRect(&buffer, .{ .x = 3, .y = 5, .w = 7, .h = 11 });
    try std.testing.expectEqual(@as(u32, surface_id), std.mem.readInt(u32, damage[0..4], .little));
    try std.testing.expectEqual(@as(u16, wl_surface_damage_buffer), std.mem.readInt(u16, damage[4..6], .little));
    try std.testing.expectEqual(@as(u16, 24), std.mem.readInt(u16, damage[6..8], .little));
    try std.testing.expectEqual(@as(i32, 3), std.mem.readInt(i32, damage[8..12], .little));
    try std.testing.expectEqual(@as(i32, 5), std.mem.readInt(i32, damage[12..16], .little));
    try std.testing.expectEqual(@as(i32, 7), std.mem.readInt(i32, damage[16..20], .little));
    try std.testing.expectEqual(@as(i32, 11), std.mem.readInt(i32, damage[20..24], .little));
}

test "wayland xdg configure event marks window configured" {
    var payload: [4]u8 = undefined;
    std.mem.writeInt(u32, &payload, 99, .little);
    var state = WaylandState{};
    try handleMessage(&state, .xdg_surface, .{
        .object_id = xdg_surface_id,
        .opcode = xdg_surface_configure_event,
        .payload = &payload,
    });
    try std.testing.expect(state.configured);
}

test "wayland xrgb pack swaps renderer color channels for shm" {
    var out: [8]u8 = undefined;
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3, .a = 4 },
        .{ .r = 5, .g = 6, .b = 7, .a = 8 },
    };
    packXrgb8888(&out, &pixels);
    try std.testing.expectEqualSlices(u8, &.{ 3, 2, 1, 255, 7, 6, 5, 255 }, &out);
}

test "wayland xrgb rect pack updates only cursor damage bytes" {
    var out = [_]u8{0xaa} ** (4 * 4 * @sizeOf(u32));
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3 },    .{ .r = 4, .g = 5, .b = 6 },    .{ .r = 7, .g = 8, .b = 9 },    .{ .r = 10, .g = 11, .b = 12 },
        .{ .r = 13, .g = 14, .b = 15 }, .{ .r = 16, .g = 17, .b = 18 }, .{ .r = 19, .g = 20, .b = 21 }, .{ .r = 22, .g = 23, .b = 24 },
        .{ .r = 25, .g = 26, .b = 27 }, .{ .r = 28, .g = 29, .b = 30 }, .{ .r = 31, .g = 32, .b = 33 }, .{ .r = 34, .g = 35, .b = 36 },
        .{ .r = 37, .g = 38, .b = 39 }, .{ .r = 40, .g = 41, .b = 42 }, .{ .r = 43, .g = 44, .b = 45 }, .{ .r = 46, .g = 47, .b = 48 },
    };

    packXrgb8888Rect(&out, 4 * @sizeOf(u32), 4, 4, &pixels, .{ .x = 1, .y = 1, .w = 2, .h = 2 });

    try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xaa, 0xaa, 0xaa }, out[0..4]);
    try std.testing.expectEqualSlices(u8, &.{ 18, 17, 16, 255 }, out[20..24]);
    try std.testing.expectEqualSlices(u8, &.{ 21, 20, 19, 255 }, out[24..28]);
    try std.testing.expectEqualSlices(u8, &.{ 30, 29, 28, 255 }, out[36..40]);
    try std.testing.expectEqualSlices(u8, &.{ 33, 32, 31, 255 }, out[40..44]);
    try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xaa, 0xaa, 0xaa }, out[60..64]);
}

test "wayland host renders the source app scene through the shared frame" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    var dash_state: app_dashboard.State = .{};
    try renderNativeAppScene(&scene, &collector, 1280, 800, .{
        .route = .{ .view = .backend },
    }, &dash_state, false, null, false);
    try std.testing.expect(hasText(scene.written(), "WORKSPACE"));
    try std.testing.expect(scene.written().len > 0);
}

test "wayland host renders frontend route through canonical ir" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    var dash_b: app_dashboard.State = .{};
    try renderNativeAppScene(&scene, &collector, 1280, 1800, .{ .route = .{ .view = .frontend } }, &dash_b, false, null, false);
    try std.testing.expect(scene.written().len > 0);
}

test "wayland host renders current docs routes through the shared app frame" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    var dash_c: app_dashboard.State = .{};
    try renderNativeAppScene(&scene, &collector, 1280, 1800, .{ .route = app_navigation.fromPath("/docs/fonts") }, &dash_c, false, null, false);

    try std.testing.expect(hasText(scene.written(), "EdgeRun Native"));
}

test "wayland host packs docs overview route at launch size" {
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    var dash_d: app_dashboard.State = .{};
    try renderNativeAppScene(&scene, &collector, 1280, 900, .{ .route = app_navigation.fromPath("/docs") }, &dash_d, false, null, false);

    var ir_storage = IrStorage{};
    const buffers = ir_storage.buffers();
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    try renderer_pipeline.packScene(buffers, &font_atlas, scene.written());

    try std.testing.expect(hasText(scene.written(), "EdgeRun Native"));
    try std.testing.expect(hasText(scene.written(), "Overview"));
    try std.testing.expect(true);
}

test "wayland host renders client side decoration above app content" {
    var state = AppState{};
    state.route = app_navigation.fromPath("/academy");
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    var dash_c: app_dashboard.State = .{};
    try renderNativeAppScene(&scene, &collector, 1280, 800, state, &dash_c, false, null, false);

    try std.testing.expect(hasText(scene.written(), "EDGERUN"));
    try std.testing.expect(hasIcon(scene.written(), icon_component.Icon.named(.x)));
    try std.testing.expectEqual(@as(f32, 0.0), (try hitRect(collector.written(), client_decor_drag_id)).y);
    try std.testing.expect((try hitRect(collector.written(), client_decor_close_id)).x > 1200.0);

    const backend = try hitRect(collector.written(), app_navigation.backend_button_id);
    try std.testing.expect(backend.y >= client_decor_h);
}

test "wayland cursor overlay renders through software presentation receipt" {
    const source = @embedFile("wayland_window_host.zig");
    const direct_raster = "try surface." ++ "rasterizeIr(";
    try std.testing.expect(std.mem.indexOf(u8, source, direct_raster) == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "const receipt = try surface.renderIr(") != null);
    try std.testing.expect(std.mem.indexOf(u8, source, "if (!receipt.valid()) return error.InvalidSoftwareReceipt;") != null);
}

test "wayland gpu recorder accepts canonical ir frame callbacks" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, .{ .x = 0, .y = 0, .w = 32, .h = 32 }, .accent, .clear, 0, 0, 0);

    var primitives: [16]renderer_gpu.Primitive = undefined;
    var gpu_tile_marks: [16]u8 = undefined;
    var gpu_dirty_ids: [16]u32 = undefined;
    var native_tile_marks: [16]u8 = undefined;
    var native_dirty_ids: [16]u32 = undefined;
    var recorder = GpuRecorder{};
    var sink_state = app_import.WaylandCommitSink{};
    const receipt = try renderer_native_present.renderGpuAndSubmit(
        .{ .wayland = .{
            .surface_id = surface_id,
            .buffer_id = wl_buffer_id,
            .width = 64,
            .height = 64,
            .stride = 64,
        } },
        buffers,
        .{},
        recorder.device(),
        .{
            .primitives = &primitives,
            .gpu_tile_marks = &gpu_tile_marks,
            .gpu_dirty_ids = &gpu_dirty_ids,
            .native_tile_marks = &native_tile_marks,
            .native_dirty_ids = &native_dirty_ids,
        },
        default_refresh_hz,
        16,
        16,
        sink_state.sink(),
    );

    try std.testing.expect(receipt.valid());
    try std.testing.expectEqual(renderer_gpu.Rasterization.recorded_commands, receipt.gpu.rasterization);
    try std.testing.expect(sink_state.submitted);
    try std.testing.expectEqual(@as(usize, 1), recorder.began);
    try std.testing.expectEqual(receipt.gpu.primitive_count, recorder.uploaded);
    try std.testing.expectEqual(receipt.gpu.dirty_tile_count, recorder.rendered);
    try std.testing.expectEqual(receipt.gpu.sequence, recorder.last_sequence);
}

test "wayland host pointer input updates hover activation and scroll state" {
    var state = AppState{};
    var commands: [max_commands]ui.Command = undefined;
    var clips: [max_clips]ui.Rect = undefined;
    var regions: [max_interaction_regions]interaction.Region = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var collector = interaction.Collector.init(&regions);
    var dash_c: app_dashboard.State = .{};
    try renderNativeAppScene(&scene, &collector, 1280, 800, state, &dash_c, false, null, false);
    updateHoverHitForState(&state, collector.written());
    try std.testing.expect(state.runtime.hovered == null);

    const backend = try hitRect(collector.written(), app_navigation.backend_button_id);
    state.hover_x = backend.x + backend.w * 0.5;
    state.hover_y = backend.y + backend.h * 0.5;
    updateHoverHitForState(&state, collector.written());
    try std.testing.expect(state.runtime.hovered != null);
    try std.testing.expectEqual(app_cursor.Kind.pointer, state.cursorKind());

    const old_hit = state.runtime.hovered.?.id;
    app_native_input.activateHovered(&state);
    try std.testing.expectEqual(old_hit, state.runtime.hovered.?.id);

    scrollStateBy(&state, 1280, 800, 320.0);
    try std.testing.expectEqual(@as(f32, 320.0), state.scroll_y);
    scrollStateBy(&state, 1280, 800, 200000.0);
    try std.testing.expect(state.scroll_y <= state.contentHeight(1280.0));
}

test "wayland host appends scene cursor from native hover state" {
    var app = NativeApp{
        .allocator = std.testing.allocator,
        .width = 1280,
        .height = 800,
        .present = .cpu,
        .dmabuf_fd = null,
        .shm = undefined,
        .pixels = &.{},
        .base_pixels = &.{},
        .font_atlas = undefined,
        .gpu_primitives = &.{},
    };
    app.font_atlas.initUtf8();
    var scene = ui.Scene.initWithClips(&app.commands, &app.clips);
    var collector = interaction.Collector.init(&app.regions);
    try renderNativeAppScene(&scene, &collector, app.width, app.height, app.state, &app.dashboard_app, app.dashboard, &app.hardware_app, app.hardware);
    app.region_len = collector.written().len;
    const backend = try hitRect(app.regionSlice(), app_navigation.backend_button_id);
    app.state.hover_x = backend.x + backend.w * 0.5;
    app.state.hover_y = backend.y + backend.h * 0.5;
    app.updateHoverHit(app.regionSlice());
    try app_cursor.render(&scene, app.state.hover_x, app.state.hover_y, app.state.cursorKind());

    try std.testing.expectEqual(app_cursor.Kind.pointer, app.state.cursorKind());
    try std.testing.expect(hasIconId(scene.written(), icon_pack.cursor_hand_finger_icon_id));
}

test "wayland host renders vector cursor overlay through native pipeline" {
    var pixels: [64 * 64]ui.Color = [_]ui.Color{ui.Color.clear} ** (64 * 64);
    var app = NativeApp{
        .allocator = std.testing.allocator,
        .width = 64,
        .height = 64,
        .present = .cpu,
        .dmabuf_fd = null,
        .shm = undefined,
        .pixels = &pixels,
        .base_pixels = &.{},
        .font_atlas = undefined,
        .gpu_primitives = &.{},
    };
    app.font_atlas.initUtf8();
    app.state.hover_x = 24.0;
    app.state.hover_y = 24.0;

    const damage = try app.renderCursorOverlay(.pointer);

    try std.testing.expect(damage != null);
    try std.testing.expect(pixelBufferHasPaint(&pixels));
}
