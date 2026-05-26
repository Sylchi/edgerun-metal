const std = @import("std");
const renderer_ir = @import("render/ir.zig");
const ui = @import("ui.zig");
const virtio = @import("virtio.zig");

pub const device_id = virtio.modern_device_id_gpu;
pub const device_type = virtio.device_type_gpu;
pub const feature_virgl: u64 = 1 << 0;
pub const feature_edid: u64 = 1 << 1;
pub const feature_resource_uuid: u64 = 1 << 2;
pub const feature_resource_blob: u64 = 1 << 3;
pub const feature_context_init: u64 = 1 << 4;

pub const control_queue: u16 = 0;
pub const cursor_queue: u16 = 1;
const poll_spins: usize = 5_000_000;

pub const ControlType = enum(u32) {
    get_display_info = 0x0100,
    resource_create_2d = 0x0101,
    resource_unref = 0x0102,
    set_scanout = 0x0103,
    resource_flush = 0x0104,
    transfer_to_host_2d = 0x0105,
    resource_attach_backing = 0x0106,
    resource_detach_backing = 0x0107,
    get_capset_info = 0x0108,
    get_capset = 0x0109,
    get_edid = 0x010a,
    resource_assign_uuid = 0x010b,
    resource_create_blob = 0x010c,
    set_scanout_blob = 0x010d,
    ctx_create = 0x0200,
    ctx_destroy = 0x0201,
    ctx_attach_resource = 0x0202,
    ctx_detach_resource = 0x0203,
    resource_create_3d = 0x0204,
    transfer_to_host_3d = 0x0205,
    transfer_from_host_3d = 0x0206,
    submit_3d = 0x0207,
    resp_ok_nodata = 0x1100,
    resp_ok_display_info = 0x1101,
    resp_ok_capset_info = 0x1102,
    resp_ok_capset = 0x1103,
    resp_ok_edid = 0x1104,
    resp_ok_resource_uuid = 0x1105,
    resp_ok_map_info = 0x1106,
    resp_err_unspec = 0x1200,
    resp_err_out_of_memory = 0x1201,
    resp_err_invalid_scanout_id = 0x1202,
    resp_err_invalid_resource_id = 0x1203,
    resp_err_invalid_context_id = 0x1204,
    resp_err_invalid_parameter = 0x1205,
};

pub const Format = enum(u32) {
    b8g8r8a8_unorm = 1,
    b8g8r8x8_unorm = 2,
    a8r8g8b8_unorm = 3,
    x8r8g8b8_unorm = 4,
    r8g8b8a8_unorm = 67,
    x8b8g8r8_unorm = 68,
    a8b8g8r8_unorm = 121,
    r8g8b8x8_unorm = 134,
};

pub const ResourceTarget = enum(u32) {
    buffer = 0,
    texture_1d = 1,
    texture_2d = 2,
    texture_3d = 3,
    texture_cube = 4,
    texture_rect = 5,
    texture_1d_array = 6,
    texture_2d_array = 7,
    texture_cube_array = 8,
};

pub const resource_bind_render_target: u32 = 1 << 1;
pub const resource_bind_sampler_view: u32 = 1 << 3;
pub const resource_flag_y_0_top: u32 = 1 << 0;
pub const pipe_clear_color0: u32 = 1 << 2;

pub const VirglCommand = enum(u8) {
    nop = 0,
    create_object = 1,
    bind_object = 2,
    destroy_object = 3,
    set_viewport_state = 4,
    set_framebuffer_state = 5,
    set_vertex_buffers = 6,
    clear = 7,
    draw_vbo = 8,
};

pub const VirglObject = enum(u8) {
    null = 0,
    blend = 1,
    rasterizer = 2,
    dsa = 3,
    shader = 4,
    vertex_elements = 5,
    sampler_view = 6,
    sampler_state = 7,
    surface = 8,
    query = 9,
    streamout_target = 10,
};

pub fn virglCommand0(command: VirglCommand, object: VirglObject, dword_len: u16) u32 {
    return @as(u32, @intFromEnum(command)) |
        (@as(u32, @intFromEnum(object)) << 8) |
        (@as(u32, dword_len) << 16);
}

pub const VirglClearColor = extern struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

pub const Header = extern struct {
    control_type: ControlType,
    flags: u32 = 0,
    fence_id: u64 = 0,
    context_id: u32 = 0,
    padding: u32 = 0,
};

pub const Rect = extern struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

pub const Display = extern struct {
    rect: Rect,
    enabled: u32,
    flags: u32,
};

pub const DisplayInfoResponse = extern struct {
    header: Header,
    displays: [16]Display,
};

pub const CapsetId = enum(u32) {
    virgl = 1,
    virgl2 = 2,
    gfxstream_vulkan = 3,
    venus = 4,
    cross_domain = 5,
    drm = 6,
};

pub const GetCapsetInfo = extern struct {
    header: Header,
    capset_index: u32,
    padding: u32 = 0,

    pub fn init(capset_index: u32) GetCapsetInfo {
        return .{
            .header = .{ .control_type = .get_capset_info },
            .capset_index = capset_index,
        };
    }
};

pub const CapsetInfoResponse = extern struct {
    header: Header,
    capset_id: u32,
    capset_max_version: u32,
    capset_max_size: u32,
    padding: u32 = 0,

    pub fn ok(self: CapsetInfoResponse) bool {
        return self.header.control_type == .resp_ok_capset_info;
    }
};

pub const ResourceCreate2d = extern struct {
    header: Header,
    resource_id: u32,
    format: Format,
    width: u32,
    height: u32,

    pub fn init(resource_id: u32, width: u32, height: u32, format: Format) ResourceCreate2d {
        return .{
            .header = .{ .control_type = .resource_create_2d },
            .resource_id = resource_id,
            .format = format,
            .width = width,
            .height = height,
        };
    }
};

pub const MemEntry = extern struct {
    address: u64,
    length: u32,
    padding: u32 = 0,
};

pub const ResourceAttachBacking = extern struct {
    header: Header,
    resource_id: u32,
    nr_entries: u32,
    entry: MemEntry,

    pub fn init(resource_id: u32, address: u64, byte_len: u32) ResourceAttachBacking {
        return .{
            .header = .{ .control_type = .resource_attach_backing },
            .resource_id = resource_id,
            .nr_entries = 1,
            .entry = .{ .address = address, .length = byte_len },
        };
    }
};

pub const SetScanout = extern struct {
    header: Header,
    rect: Rect,
    scanout_id: u32,
    resource_id: u32,

    pub fn init(scanout_id: u32, resource_id: u32, width: u32, height: u32) SetScanout {
        return .{
            .header = .{ .control_type = .set_scanout },
            .rect = .{ .x = 0, .y = 0, .width = width, .height = height },
            .scanout_id = scanout_id,
            .resource_id = resource_id,
        };
    }
};

pub const TransferToHost2d = extern struct {
    header: Header,
    rect: Rect,
    offset: u64,
    resource_id: u32,
    padding: u32 = 0,

    pub fn init(resource_id: u32, width: u32, height: u32) TransferToHost2d {
        return .{
            .header = .{ .control_type = .transfer_to_host_2d },
            .rect = .{ .x = 0, .y = 0, .width = width, .height = height },
            .offset = 0,
            .resource_id = resource_id,
        };
    }
};

pub const Box3d = extern struct {
    x: u32,
    y: u32,
    z: u32,
    width: u32,
    height: u32,
    depth: u32,
};

pub const TransferToHost3d = extern struct {
    header: Header,
    box: Box3d,
    offset: u64,
    resource_id: u32,
    level: u32,
    stride: u32,
    layer_stride: u32,

    pub fn init(context_id: u32, resource_id: u32, width: u32, height: u32, stride: u32) TransferToHost3d {
        return .{
            .header = .{ .control_type = .transfer_to_host_3d, .context_id = context_id },
            .box = .{ .x = 0, .y = 0, .z = 0, .width = width, .height = height, .depth = 1 },
            .offset = 0,
            .resource_id = resource_id,
            .level = 0,
            .stride = stride,
            .layer_stride = stride * height,
        };
    }
};

pub const ResourceFlush = extern struct {
    header: Header,
    rect: Rect,
    resource_id: u32,
    padding: u32 = 0,

    pub fn init(resource_id: u32, width: u32, height: u32) ResourceFlush {
        return .{
            .header = .{ .control_type = .resource_flush },
            .rect = .{ .x = 0, .y = 0, .width = width, .height = height },
            .resource_id = resource_id,
        };
    }
};

pub const ResourceCreate3d = extern struct {
    header: Header,
    resource_id: u32,
    target: ResourceTarget,
    format: Format,
    bind: u32,
    width: u32,
    height: u32,
    depth: u32,
    array_size: u32,
    last_level: u32,
    sample_count: u32,
    flags: u32,
    padding: u32 = 0,

    pub fn initColor2d(resource_id: u32, width: u32, height: u32, format: Format) ResourceCreate3d {
        return .{
            .header = .{ .control_type = .resource_create_3d },
            .resource_id = resource_id,
            .target = .texture_2d,
            .format = format,
            .bind = resource_bind_render_target | resource_bind_sampler_view,
            .width = width,
            .height = height,
            .depth = 1,
            .array_size = 1,
            .last_level = 0,
            .sample_count = 0,
            .flags = resource_flag_y_0_top,
        };
    }
};

pub const ContextCreate = extern struct {
    header: Header,
    name_len: u32,
    context_init: u32,
    debug_name: [64]u8 = [_]u8{0} ** 64,

    pub fn init(context_id: u32, capset_id: CapsetId, name: []const u8) ContextCreate {
        var command = ContextCreate{
            .header = .{
                .control_type = .ctx_create,
                .context_id = context_id,
            },
            .name_len = @intCast(@min(name.len, 64)),
            .context_init = @intFromEnum(capset_id) & 0x000000ff,
        };
        @memcpy(command.debug_name[0..command.name_len], name[0..command.name_len]);
        return command;
    }
};

pub const ContextDestroy = extern struct {
    header: Header,

    pub fn init(context_id: u32) ContextDestroy {
        return .{ .header = .{ .control_type = .ctx_destroy, .context_id = context_id } };
    }
};

pub const ContextResource = extern struct {
    header: Header,
    resource_id: u32,
    padding: u32 = 0,

    pub fn attach(context_id: u32, resource_id: u32) ContextResource {
        return .{
            .header = .{ .control_type = .ctx_attach_resource, .context_id = context_id },
            .resource_id = resource_id,
        };
    }

    pub fn detach(context_id: u32, resource_id: u32) ContextResource {
        return .{
            .header = .{ .control_type = .ctx_detach_resource, .context_id = context_id },
            .resource_id = resource_id,
        };
    }
};

pub const Submit3d = extern struct {
    header: Header,
    size: u32,
    padding: u32 = 0,

    pub fn init(context_id: u32, command_byte_len: u32) Submit3d {
        return .{
            .header = .{ .control_type = .submit_3d, .context_id = context_id },
            .size = command_byte_len,
        };
    }
};

pub const Response = extern struct {
    header: Header,

    pub fn okNoData(self: Response) bool {
        return self.header.control_type == .resp_ok_nodata;
    }
};

pub const Error = virtio.Error || error{
    DeviceTimeout,
    InvalidResponse,
    UnsupportedPackedFrame,
};

pub const QueueStorage = struct {
    desc: [virtio.QueueSize]virtio.Desc align(16) = [_]virtio.Desc{.{ .addr = 0, .len = 0, .flags = 0, .next = 0 }} ** virtio.QueueSize,
    avail: virtio.Avail align(2) = .{ .flags = 0, .idx = 0, .ring = [_]u16{0} ** virtio.QueueSize, .used_event = 0 },
    used: virtio.Used align(4) = .{ .flags = 0, .idx = 0, .ring = [_]virtio.UsedElem{.{ .id = 0, .len = 0 }} ** virtio.QueueSize, .avail_event = 0 },
    response: Response align(8) = .{ .header = .{ .control_type = .resp_err_unspec } },
    capset_info_response: CapsetInfoResponse align(8) = .{ .header = .{ .control_type = .resp_err_unspec }, .capset_id = 0, .capset_max_version = 0, .capset_max_size = 0 },

    fn reset(self: *QueueStorage) void {
        @memset(&self.desc, .{ .addr = 0, .len = 0, .flags = 0, .next = 0 });
        self.avail = .{ .flags = 0, .idx = 0, .ring = [_]u16{0} ** virtio.QueueSize, .used_event = 0 };
        self.used = .{ .flags = 0, .idx = 0, .ring = [_]virtio.UsedElem{.{ .id = 0, .len = 0 }} ** virtio.QueueSize, .avail_event = 0 };
        self.response = .{ .header = .{ .control_type = .resp_err_unspec } };
        self.capset_info_response = .{ .header = .{ .control_type = .resp_err_unspec }, .capset_id = 0, .capset_max_version = 0, .capset_max_size = 0 };
    }
};

pub const Device = struct {
    transport: virtio.Transport,
    features: virtio.NegotiatedFeatures,
    queue_notify_off: u16,
    queue_size: u16,
    last_used_idx: u16 = 0,

    pub fn initFromTransport(transport: virtio.Transport, storage: *QueueStorage) Error!Device {
        return initFromTransportWithFeatures(transport, storage, feature_virgl | feature_context_init);
    }

    pub fn initFromTransportWithFeatures(transport: virtio.Transport, storage: *QueueStorage, optional_features: u64) Error!Device {
        storage.reset();
        const features = try transport.negotiateFeatures(virtio.feature_version_1 | optional_features);
        transport.selectQueue(control_queue);
        const queue_notify_off = transport.readQueueNotifyOff();
        const queue_size = try transport.configureSplitQueue(
            control_queue,
            virtio.QueueSize,
            2,
            @intFromPtr(&storage.desc),
            @intFromPtr(&storage.avail),
            @intFromPtr(&storage.used),
        );
        transport.writeStatus(transport.status() | virtio.status_driver_ok);
        return .{
            .transport = transport,
            .features = features,
            .queue_notify_off = queue_notify_off,
            .queue_size = queue_size,
        };
    }

    pub fn findAndInit(storage: *QueueStorage) Error!Device {
        const pci_device = findPciDevice() orelse return error.DeviceNotFound;
        return initFromTransport(try pci_device.map(), storage);
    }

    pub fn virglReady(self: Device) bool {
        return self.features.driver & feature_virgl != 0;
    }

    pub fn contextInitReady(self: Device) bool {
        return self.features.driver & feature_context_init != 0;
    }

    pub fn sendNoData(self: *Device, storage: *QueueStorage, command: anytype) Error!void {
        const response = try self.send(storage, std.mem.asBytes(&command));
        if (!response.okNoData()) return error.InvalidResponse;
    }

    pub fn send(self: *Device, storage: *QueueStorage, command_bytes: []const u8) Error!Response {
        storage.response = .{ .header = .{ .control_type = .resp_err_unspec } };
        _ = try self.sendWithResponse(storage, command_bytes, std.mem.asBytes(&storage.response));
        return storage.response;
    }

    pub fn sendWithResponse(self: *Device, storage: *QueueStorage, command_bytes: []const u8, response_bytes: []u8) Error!void {
        if (command_bytes.len == 0 or command_bytes.len > std.math.maxInt(u32)) return error.InvalidResponse;
        if (response_bytes.len == 0 or response_bytes.len > std.math.maxInt(u32)) return error.InvalidResponse;
        prepareCommandDescriptors(storage, command_bytes, response_bytes);
        virtio.postDescriptor(&storage.avail, self.queue_size, 0);
        self.transport.notifyQueue(self.queue_notify_off, control_queue);
        _ = try waitForCompletion(&storage.used, self.queue_size, &self.last_used_idx);
    }

    pub fn sendWithPayload(self: *Device, storage: *QueueStorage, command_bytes: []const u8, payload: []const u8) Error!Response {
        if (command_bytes.len == 0 or command_bytes.len > std.math.maxInt(u32)) return error.InvalidResponse;
        if (payload.len == 0 or payload.len > std.math.maxInt(u32)) return error.InvalidResponse;
        storage.response = .{ .header = .{ .control_type = .resp_err_unspec } };
        prepareCommandWithPayloadDescriptors(storage, command_bytes, payload, std.mem.asBytes(&storage.response));
        virtio.postDescriptor(&storage.avail, self.queue_size, 0);
        self.transport.notifyQueue(self.queue_notify_off, control_queue);
        _ = try waitForCompletion(&storage.used, self.queue_size, &self.last_used_idx);
        return storage.response;
    }

    pub fn getCapsetInfo(self: *Device, storage: *QueueStorage, capset_index: u32) Error!CapsetInfoResponse {
        storage.capset_info_response = .{ .header = .{ .control_type = .resp_err_unspec }, .capset_id = 0, .capset_max_version = 0, .capset_max_size = 0 };
        const command = GetCapsetInfo.init(capset_index);
        try self.sendWithResponse(storage, std.mem.asBytes(&command), std.mem.asBytes(&storage.capset_info_response));
        if (!storage.capset_info_response.ok()) return error.InvalidResponse;
        return storage.capset_info_response;
    }

    pub fn createContext(self: *Device, storage: *QueueStorage, context_id: u32, capset_id: CapsetId, name: []const u8) Error!void {
        if (capset_id == .virgl and !self.virglReady()) return error.UnsupportedDevice;
        const command = ContextCreate.init(context_id, capset_id, name);
        try self.sendNoData(storage, command);
    }

    pub fn create3dColorResource(self: *Device, storage: *QueueStorage, resource_id: u32, width: u32, height: u32, format: Format) Error!void {
        if (!self.virglReady()) return error.UnsupportedDevice;
        try self.sendNoData(storage, ResourceCreate3d.initColor2d(resource_id, width, height, format));
    }

    pub fn attachResourceBacking(self: *Device, storage: *QueueStorage, resource_id: u32, address: u64, byte_len: u32) Error!void {
        try self.sendNoData(storage, ResourceAttachBacking.init(resource_id, address, byte_len));
    }

    pub fn attachResourceToContext(self: *Device, storage: *QueueStorage, context_id: u32, resource_id: u32) Error!void {
        if (!self.virglReady()) return error.UnsupportedDevice;
        try self.sendNoData(storage, ContextResource.attach(context_id, resource_id));
    }

    pub fn destroyContext(self: *Device, storage: *QueueStorage, context_id: u32) Error!void {
        try self.sendNoData(storage, ContextDestroy.init(context_id));
    }

    pub fn submit3d(self: *Device, storage: *QueueStorage, context_id: u32, command_buffer: []const u8) Error!void {
        if (!self.virglReady()) return error.UnsupportedDevice;
        const submit = Submit3d.init(context_id, @intCast(command_buffer.len));
        const response = try self.sendWithPayload(storage, std.mem.asBytes(&submit), command_buffer);
        if (!response.okNoData()) return error.InvalidResponse;
    }

    pub fn submitVirglNop(self: *Device, storage: *QueueStorage, context_id: u32) Error!void {
        const command_word = virglCommand0(.nop, .null, 0);
        try self.submit3d(storage, context_id, std.mem.asBytes(&command_word));
    }

    pub fn clearVirglColorResource(
        self: *Device,
        storage: *QueueStorage,
        context_id: u32,
        resource_id: u32,
        surface_handle: u32,
        format: Format,
        color: VirglClearColor,
    ) Error!void {
        var commands: [19]u32 = undefined;
        writeVirglClearColorCommands(&commands, resource_id, surface_handle, format, color);
        try self.submit3d(storage, context_id, std.mem.sliceAsBytes(&commands));
    }

    pub fn renderPackedFrameToVirglColorResource(
        self: *Device,
        storage: *QueueStorage,
        context_id: u32,
        resource_id: u32,
        surface_handle: u32,
        format: Format,
        width: u32,
        height: u32,
        buffers: renderer_ir.Buffers,
    ) Error!void {
        const color = try packedFullFrameClearColor(width, height, buffers);
        try self.clearVirglColorResource(storage, context_id, resource_id, surface_handle, format, color);
    }

    pub fn setup2d(self: *Device, storage: *QueueStorage, setup: Setup2d) Error!void {
        try self.sendNoData(storage, setup.resource);
        try self.sendNoData(storage, setup.backing);
        try self.sendNoData(storage, setup.scanout);
    }

    pub fn flush2d(self: *Device, storage: *QueueStorage, resource_id: u32, width: u32, height: u32) Error!void {
        try self.sendNoData(storage, TransferToHost2d.init(resource_id, width, height));
        try self.sendNoData(storage, ResourceFlush.init(resource_id, width, height));
    }

    pub fn transferToHost3d(self: *Device, storage: *QueueStorage, context_id: u32, resource_id: u32, width: u32, height: u32, stride: u32) Error!void {
        if (!self.virglReady()) return error.UnsupportedDevice;
        try self.sendNoData(storage, TransferToHost3d.init(context_id, resource_id, width, height, stride));
    }

    pub fn setScanout(self: *Device, storage: *QueueStorage, scanout_id: u32, resource_id: u32, width: u32, height: u32) Error!void {
        try self.sendNoData(storage, SetScanout.init(scanout_id, resource_id, width, height));
    }

    pub fn flushResource(self: *Device, storage: *QueueStorage, resource_id: u32, width: u32, height: u32) Error!void {
        try self.sendNoData(storage, ResourceFlush.init(resource_id, width, height));
    }
};

pub const Setup2d = struct {
    resource: ResourceCreate2d,
    backing: ResourceAttachBacking,
    scanout: SetScanout,

    pub fn init(resource_id: u32, scanout_id: u32, width: u32, height: u32, pixel_address: u64, pixel_byte_len: u32) Setup2d {
        return .{
            .resource = ResourceCreate2d.init(resource_id, width, height, .b8g8r8x8_unorm),
            .backing = ResourceAttachBacking.init(resource_id, pixel_address, pixel_byte_len),
            .scanout = SetScanout.init(scanout_id, resource_id, width, height),
        };
    }
};

pub fn findPciDevice() ?virtio.ModernPciDevice {
    return virtio.findModernPciDevice(device_id);
}

fn prepareCommandDescriptors(storage: *QueueStorage, command_bytes: []const u8, response_bytes: []u8) void {
    storage.desc[0] = .{
        .addr = @intFromPtr(command_bytes.ptr),
        .len = @intCast(command_bytes.len),
        .flags = virtio.desc_flag_next,
        .next = 1,
    };
    storage.desc[1] = .{
        .addr = @intFromPtr(response_bytes.ptr),
        .len = @intCast(response_bytes.len),
        .flags = virtio.desc_flag_write,
        .next = 0,
    };
}

fn prepareCommandWithPayloadDescriptors(storage: *QueueStorage, command_bytes: []const u8, payload: []const u8, response_bytes: []u8) void {
    storage.desc[0] = .{
        .addr = @intFromPtr(command_bytes.ptr),
        .len = @intCast(command_bytes.len),
        .flags = virtio.desc_flag_next,
        .next = 1,
    };
    storage.desc[1] = .{
        .addr = @intFromPtr(payload.ptr),
        .len = @intCast(payload.len),
        .flags = virtio.desc_flag_next,
        .next = 2,
    };
    storage.desc[2] = .{
        .addr = @intFromPtr(response_bytes.ptr),
        .len = @intCast(response_bytes.len),
        .flags = virtio.desc_flag_write,
        .next = 0,
    };
}

pub fn writeVirglClearColorCommands(
    out: *[19]u32,
    resource_id: u32,
    surface_handle: u32,
    format: Format,
    color: VirglClearColor,
) void {
    out[0] = virglCommand0(.create_object, .surface, 5);
    out[1] = surface_handle;
    out[2] = resource_id;
    out[3] = @intFromEnum(format);
    out[4] = 0;
    out[5] = 0;

    out[6] = virglCommand0(.set_framebuffer_state, .null, 3);
    out[7] = 1;
    out[8] = 0;
    out[9] = surface_handle;

    out[10] = virglCommand0(.clear, .null, 8);
    out[11] = pipe_clear_color0;
    out[12] = @bitCast(color.r);
    out[13] = @bitCast(color.g);
    out[14] = @bitCast(color.b);
    out[15] = @bitCast(color.a);
    const depth_bits: u64 = @bitCast(@as(f64, 1.0));
    out[16] = @truncate(depth_bits);
    out[17] = @truncate(depth_bits >> 32);
    out[18] = 0;
}

pub fn virglClearColorCommandByteLen() usize {
    return 19 * @sizeOf(u32);
}

pub fn packedFullFrameClearColor(width: u32, height: u32, buffers: renderer_ir.Buffers) Error!VirglClearColor {
    if (buffers.liveTextVertices().len != 0 or
        buffers.liveIconVertices().len != 0 or
        buffers.liveIconLineVertices().len != 0 or
        buffers.liveImageVertices().len != 0 or
        buffers.liveOverlayRects().len != 0 or
        buffers.liveOverlayTextVertices().len != 0 or
        buffers.liveOverlayIconVertices().len != 0 or
        buffers.liveOverlayIconLineVertices().len != 0)
    {
        return error.UnsupportedPackedFrame;
    }

    const rects = buffers.liveRects();
    if ((renderer_ir.rectCount(rects) catch return error.UnsupportedPackedFrame) != 1) return error.UnsupportedPackedFrame;
    const rect = renderer_ir.rectAt(rects, 0) catch return error.UnsupportedPackedFrame;
    if (rect.mode != .fill or rect.radius != 0.0 or rect.shadow != 0.0) return error.UnsupportedPackedFrame;
    if (!sameFloat(rect.bounds.x, 0.0) or
        !sameFloat(rect.bounds.y, 0.0) or
        !sameFloat(rect.bounds.w, @floatFromInt(width)) or
        !sameFloat(rect.bounds.h, @floatFromInt(height)))
    {
        return error.UnsupportedPackedFrame;
    }
    return colorToVirglClear(rect.color);
}

pub fn rasterizePackedRectsToBgra(width: u32, height: u32, pixels: []u8, buffers: renderer_ir.Buffers, background: ui.Color) Error!void {
    const byte_len = @as(usize, width) * @as(usize, height) * 4;
    if (pixels.len < byte_len) return error.UnsupportedPackedFrame;
    if (buffers.liveTextVertices().len != 0 or
        buffers.liveIconVertices().len != 0 or
        buffers.liveIconLineVertices().len != 0 or
        buffers.liveImageVertices().len != 0 or
        buffers.liveOverlayTextVertices().len != 0 or
        buffers.liveOverlayIconVertices().len != 0 or
        buffers.liveOverlayIconLineVertices().len != 0)
    {
        return error.UnsupportedPackedFrame;
    }

    fillBgra(pixels[0..byte_len], background);
    try rasterizeRectBufferToBgra(width, height, pixels[0..byte_len], buffers.liveRects());
    try rasterizeRectBufferToBgra(width, height, pixels[0..byte_len], buffers.liveOverlayRects());
}

pub fn copyRgbaPixelsToBgra(width: u32, height: u32, out_bgra: []u8, in_rgba: []const ui.Color) Error!void {
    const pixel_count = @as(usize, width) * @as(usize, height);
    const byte_len = pixel_count * 4;
    if (out_bgra.len < byte_len or in_rgba.len < pixel_count) return error.UnsupportedPackedFrame;
    var index: usize = 0;
    while (index < pixel_count) : (index += 1) {
        const color = in_rgba[index];
        const byte_index = index * 4;
        out_bgra[byte_index + 0] = color.b;
        out_bgra[byte_index + 1] = color.g;
        out_bgra[byte_index + 2] = color.r;
        out_bgra[byte_index + 3] = color.a;
    }
}

fn rasterizeRectBufferToBgra(width: u32, height: u32, pixels: []u8, rects: []const f32) Error!void {
    var iter = renderer_ir.RectIterator.init(rects) catch return error.UnsupportedPackedFrame;
    while (iter.next() catch return error.UnsupportedPackedFrame) |rect| {
        if (rect.mode != .fill or rect.radius != 0.0 or rect.shadow != 0.0) return error.UnsupportedPackedFrame;
        fillRectBgra(width, height, pixels, rect.bounds, rect.color);
    }
}

fn fillBgra(pixels: []u8, color: ui.Color) void {
    var index: usize = 0;
    while (index + 3 < pixels.len) : (index += 4) {
        pixels[index + 0] = color.b;
        pixels[index + 1] = color.g;
        pixels[index + 2] = color.r;
        pixels[index + 3] = color.a;
    }
}

fn fillRectBgra(width: u32, height: u32, pixels: []u8, bounds: ui.Rect, color: ui.Color) void {
    const x0 = clampCoord(@intFromFloat(@floor(bounds.x)), width);
    const y0 = clampCoord(@intFromFloat(@floor(bounds.y)), height);
    const x1 = clampCoord(@intFromFloat(@ceil(bounds.x + bounds.w)), width);
    const y1 = clampCoord(@intFromFloat(@ceil(bounds.y + bounds.h)), height);
    if (x1 <= x0 or y1 <= y0) return;

    var y = y0;
    while (y < y1) : (y += 1) {
        var x = x0;
        while (x < x1) : (x += 1) {
            const index = (@as(usize, y) * @as(usize, width) + @as(usize, x)) * 4;
            pixels[index + 0] = color.b;
            pixels[index + 1] = color.g;
            pixels[index + 2] = color.r;
            pixels[index + 3] = color.a;
        }
    }
}

fn clampCoord(value: i32, limit: u32) u32 {
    if (value <= 0) return 0;
    const unsigned: u32 = @intCast(value);
    return @min(unsigned, limit);
}

fn colorToVirglClear(color: ui.Color) VirglClearColor {
    return .{
        .r = colorChannel(color.r),
        .g = colorChannel(color.g),
        .b = colorChannel(color.b),
        .a = colorChannel(color.a),
    };
}

fn colorChannel(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / 255.0;
}

fn sameFloat(a: f32, b: f32) bool {
    return @abs(a - b) <= 0.001;
}

fn waitForCompletion(used: *const virtio.Used, queue_size: u16, last_used_idx: *u16) Error!virtio.UsedElem {
    var spins: usize = 0;
    while (virtio.nextUsed(used, queue_size, last_used_idx)) |elem| {
        return elem;
    } else {
        while (spins < poll_spins) : (spins += 1) {
            if (virtio.nextUsed(used, queue_size, last_used_idx)) |elem| return elem;
            std.atomic.spinLoopHint();
        }
    }
    return error.DeviceTimeout;
}

test "virtio gpu command layouts match fixed 2d protocol sizes" {
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(Header));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(GetCapsetInfo));
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(CapsetInfoResponse));
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(ResourceCreate2d));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(ResourceAttachBacking));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(SetScanout));
    try std.testing.expectEqual(@as(usize, 56), @sizeOf(TransferToHost2d));
    try std.testing.expectEqual(@as(usize, 72), @sizeOf(TransferToHost3d));
    try std.testing.expectEqual(@as(usize, 48), @sizeOf(ResourceFlush));
    try std.testing.expectEqual(@as(usize, 72), @sizeOf(ResourceCreate3d));
    try std.testing.expectEqual(@as(usize, 96), @sizeOf(ContextCreate));
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(ContextDestroy));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(ContextResource));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(Submit3d));
}

test "setup 2d sequence targets one resource and scanout" {
    const setup = Setup2d.init(1, 0, 640, 480, 0x100000, 640 * 480 * 4);
    try std.testing.expectEqual(ControlType.resource_create_2d, setup.resource.header.control_type);
    try std.testing.expectEqual(ControlType.resource_attach_backing, setup.backing.header.control_type);
    try std.testing.expectEqual(ControlType.set_scanout, setup.scanout.header.control_type);
    try std.testing.expectEqual(@as(u32, 1), setup.resource.resource_id);
    try std.testing.expectEqual(@as(u32, 1), setup.backing.resource_id);
    try std.testing.expectEqual(@as(u32, 1), setup.scanout.resource_id);
    try std.testing.expectEqual(@as(u32, 0), setup.scanout.scanout_id);
}

test "frame update commands cover full resource" {
    const transfer = TransferToHost2d.init(3, 800, 600);
    const flush = ResourceFlush.init(3, 800, 600);
    try std.testing.expectEqual(ControlType.transfer_to_host_2d, transfer.header.control_type);
    try std.testing.expectEqual(ControlType.resource_flush, flush.header.control_type);
    try std.testing.expectEqual(@as(u32, 800), transfer.rect.width);
    try std.testing.expectEqual(@as(u32, 600), flush.rect.height);
    try std.testing.expectEqual(@as(u32, 3), transfer.resource_id);
    try std.testing.expectEqual(@as(u32, 3), flush.resource_id);
}

test "3d transfer command covers full color resource" {
    const transfer = TransferToHost3d.init(7, 3, 800, 600, 800 * 4);
    try std.testing.expectEqual(ControlType.transfer_to_host_3d, transfer.header.control_type);
    try std.testing.expectEqual(@as(u32, 7), transfer.header.context_id);
    try std.testing.expectEqual(@as(u32, 800), transfer.box.width);
    try std.testing.expectEqual(@as(u32, 600), transfer.box.height);
    try std.testing.expectEqual(@as(u32, 1), transfer.box.depth);
    try std.testing.expectEqual(@as(u32, 3), transfer.resource_id);
    try std.testing.expectEqual(@as(u32, 800 * 4), transfer.stride);
    try std.testing.expectEqual(@as(u32, 800 * 600 * 4), transfer.layer_stride);
}

test "packed rect rasterizer writes bgra scanout bytes" {
    var storage = renderer_ir.FixedBuffers(2, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, ui.Rect.init(0, 0, 4, 3), .{ .r = 1, .g = 2, .b = 3, .a = 255 }, .clear, 0, 0, renderer_ir.rectModeCode(.fill));
    try renderer_ir.pushRect(buffers, .base, ui.Rect.init(1, 1, 2, 1), .{ .r = 9, .g = 8, .b = 7, .a = 255 }, .clear, 0, 0, renderer_ir.rectModeCode(.fill));
    var pixels: [4 * 3 * 4]u8 = undefined;

    try rasterizePackedRectsToBgra(4, 3, &pixels, buffers, .clear);

    try std.testing.expectEqualSlices(u8, &.{ 3, 2, 1, 255 }, pixels[0..4]);
    const middle = (1 * 4 + 1) * 4;
    try std.testing.expectEqualSlices(u8, &.{ 7, 8, 9, 255 }, pixels[middle .. middle + 4]);
}

test "rgba software pixels copy to virtio bgra backing" {
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3, .a = 4 },
        .{ .r = 5, .g = 6, .b = 7, .a = 8 },
    };
    var out: [8]u8 = undefined;

    try copyRgbaPixelsToBgra(2, 1, &out, &pixels);

    try std.testing.expectEqualSlices(u8, &.{ 3, 2, 1, 4, 7, 6, 5, 8 }, &out);
}

test "command descriptor chain sends request then writable response" {
    var storage = QueueStorage{};
    const command = ResourceFlush.init(9, 32, 24);
    prepareCommandDescriptors(&storage, std.mem.asBytes(&command), std.mem.asBytes(&storage.response));
    try std.testing.expectEqual(@intFromPtr(std.mem.asBytes(&command).ptr), storage.desc[0].addr);
    try std.testing.expectEqual(@as(u16, virtio.desc_flag_next), storage.desc[0].flags);
    try std.testing.expectEqual(@as(u16, 1), storage.desc[0].next);
    try std.testing.expectEqual(@intFromPtr(std.mem.asBytes(&storage.response).ptr), storage.desc[1].addr);
    try std.testing.expectEqual(@as(u16, virtio.desc_flag_write), storage.desc[1].flags);
}

test "virgl context create encodes capset id and bounded debug name" {
    const command = ContextCreate.init(7, .virgl, "edgerun-gl-context-name-that-is-longer-than-the-fixed-debug-name-buffer-by-design");
    try std.testing.expectEqual(ControlType.ctx_create, command.header.control_type);
    try std.testing.expectEqual(@as(u32, 7), command.header.context_id);
    try std.testing.expectEqual(@as(u32, 64), command.name_len);
    try std.testing.expectEqual(@as(u32, 1), command.context_init);
    try std.testing.expectEqualStrings("edgerun-gl", command.debug_name[0..10]);
}

test "virgl 3d resource create encodes a 2d color target" {
    const command = ResourceCreate3d.initColor2d(9, 640, 360, .b8g8r8a8_unorm);
    try std.testing.expectEqual(ControlType.resource_create_3d, command.header.control_type);
    try std.testing.expectEqual(@as(u32, 9), command.resource_id);
    try std.testing.expectEqual(ResourceTarget.texture_2d, command.target);
    try std.testing.expectEqual(Format.b8g8r8a8_unorm, command.format);
    try std.testing.expect(command.bind & resource_bind_render_target != 0);
    try std.testing.expect(command.bind & resource_bind_sampler_view != 0);
    try std.testing.expectEqual(@as(u32, 1), command.depth);
    try std.testing.expectEqual(@as(u32, 1), command.array_size);
    try std.testing.expectEqual(@as(u32, resource_flag_y_0_top), command.flags);
}

test "virgl command header packs command object and dword length" {
    try std.testing.expectEqual(@as(u32, 0), virglCommand0(.nop, .null, 0));
    try std.testing.expectEqual(@as(u32, 7 | (8 << 8) | (13 << 16)), virglCommand0(.clear, .surface, 13));
}

test "virgl clear color command stream creates surface binds framebuffer and clears" {
    var commands: [19]u32 = undefined;
    writeVirglClearColorCommands(&commands, 2, 77, .b8g8r8a8_unorm, .{ .r = 0.1, .g = 0.2, .b = 0.3, .a = 1.0 });
    try std.testing.expectEqual(virglCommand0(.create_object, .surface, 5), commands[0]);
    try std.testing.expectEqual(@as(u32, 77), commands[1]);
    try std.testing.expectEqual(@as(u32, 2), commands[2]);
    try std.testing.expectEqual(@intFromEnum(Format.b8g8r8a8_unorm), commands[3]);
    try std.testing.expectEqual(virglCommand0(.set_framebuffer_state, .null, 3), commands[6]);
    try std.testing.expectEqual(@as(u32, 1), commands[7]);
    try std.testing.expectEqual(@as(u32, 77), commands[9]);
    try std.testing.expectEqual(virglCommand0(.clear, .null, 8), commands[10]);
    try std.testing.expectEqual(@as(u32, pipe_clear_color0), commands[11]);
    try std.testing.expectEqual(@as(u32, 19 * @sizeOf(u32)), virglClearColorCommandByteLen());
}

test "packed renderer full-frame fill maps to virgl clear color" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, ui.Rect.init(0, 0, 640, 360), .{ .r = 33, .g = 212, .b = 237, .a = 255 }, .clear, 0, 0, renderer_ir.rectModeCode(.fill));

    const color = try packedFullFrameClearColor(640, 360, buffers);
    try std.testing.expectApproxEqAbs(@as(f32, 33.0 / 255.0), color.r, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 212.0 / 255.0), color.g, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 237.0 / 255.0), color.b, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), color.a, 0.0001);
}

test "packed renderer scanout bridge rejects unsupported partial frames" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, ui.Rect.init(8, 8, 320, 180), .accent, .clear, 0, 0, renderer_ir.rectModeCode(.fill));

    try std.testing.expectError(error.UnsupportedPackedFrame, packedFullFrameClearColor(640, 360, buffers));
}

test "submit 3d descriptor chain sends header payload then writable response" {
    var storage = QueueStorage{};
    const submit = Submit3d.init(4, 8);
    const payload = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    prepareCommandWithPayloadDescriptors(&storage, std.mem.asBytes(&submit), &payload, std.mem.asBytes(&storage.response));
    try std.testing.expectEqual(@intFromPtr(std.mem.asBytes(&submit).ptr), storage.desc[0].addr);
    try std.testing.expectEqual(@as(u16, virtio.desc_flag_next), storage.desc[0].flags);
    try std.testing.expectEqual(@as(u16, 1), storage.desc[0].next);
    try std.testing.expectEqual(@intFromPtr(payload[0..].ptr), storage.desc[1].addr);
    try std.testing.expectEqual(@as(u16, virtio.desc_flag_next), storage.desc[1].flags);
    try std.testing.expectEqual(@as(u16, 2), storage.desc[1].next);
    try std.testing.expectEqual(@intFromPtr(std.mem.asBytes(&storage.response).ptr), storage.desc[2].addr);
    try std.testing.expectEqual(@as(u16, virtio.desc_flag_write), storage.desc[2].flags);
}
