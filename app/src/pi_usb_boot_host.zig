const std = @import("std");
const bytes = @import("bytes.zig");
const bcm = @import("bcm2708_usb_boot.zig");

const linux = std.os.linux;
const posix = std.posix;

const timeout_ms: u32 = 5000;
const return_timeout_ms: u32 = 20_000;
const wait_poll_ms: u32 = 250;
const default_image_path = ".build/edgerun-metal/pi-zero-w-v1_1/boot/bootcode.bin";
const default_boot_dir = ".build/edgerun-metal/pi-zero-w-v1_1/boot";
const default_kernel_path = ".build/pi-zero-w-v1_1-zig/kernel.img";
const wait_forever_ms: u32 = ~@as(u32, 0);

const file_command_get_size: u32 = 0;
const file_command_read: u32 = 1;
const file_command_done: u32 = 2;
const file_name_bytes: usize = 256;
const file_message_bytes: usize = 4 + file_name_bytes;

const UsbCtrlTransfer = extern struct {
    request_type: u8,
    request: u8,
    value: u16,
    index: u16,
    length: u16,
    timeout: u32,
    data: ?*anyopaque,
};

const UsbBulkTransfer = extern struct {
    endpoint: c_uint,
    len: c_uint,
    timeout: c_uint,
    data: ?*anyopaque,
};

const PayloadResult = struct {
    requested: usize,
    sent: usize,
    completed: bool,
};

const usbdevfs_control = iowr('U', 0, @sizeOf(UsbCtrlTransfer));
const usbdevfs_bulk = iowr('U', 2, @sizeOf(UsbBulkTransfer));
const usbdevfs_claim_interface = ior('U', 15, @sizeOf(c_uint));
const usbdevfs_release_interface = ior('U', 16, @sizeOf(c_uint));

const Options = struct {
    dry_run: bool = false,
    serve_only: bool = false,
    wait: bool = false,
    wait_timeout_ms: u32 = wait_forever_ms,
    image_path: []const u8 = default_image_path,
    boot_dir: []const u8 = default_boot_dir,
    kernel_path: []const u8 = default_kernel_path,
};

const FileRequest = struct {
    command: u32,
    name: []const u8,
};

const DevicePath = struct {
    bytes: [32]u8,
    len: usize,

    fn slice(self: *const DevicePath) []const u8 {
        return self.bytes[0..self.len];
    }
};

const DevicePhase = enum {
    first_stage,
    file_server,
    any,
};

const DeviceInfo = struct {
    path: DevicePath,
    serial_index: u8,

    fn phase(self: DeviceInfo) DevicePhase {
        return if (self.serial_index == 0 or self.serial_index == 3) .first_stage else .file_server;
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    const options = try parseOptions(args);
    const image = try std.Io.Dir.cwd().readFileAlloc(init.io, options.image_path, allocator, .limited(1024 * 1024));
    defer allocator.free(image);

    const header = bcm.secondStageHeader(@intCast(image.len), null);
    std.debug.print("BCM2708 second-stage plan: header={d} bytes bootcode={d} bytes image={s}\n", .{
        header.len,
        image.len,
        options.image_path,
    });

    if (options.dry_run) {
        if (findBootDevice(init.io, allocator, .any)) |dev| {
            std.debug.print("dry-run: found BCM2708 boot device at {s} phase={s} serial-index={d}\n", .{
                dev.path.slice(),
                @tagName(dev.phase()),
                dev.serial_index,
            });
        } else |err| switch (err) {
            error.BootDeviceNotFound => std.debug.print("dry-run: BCM2708 boot device not currently enumerated\n", .{}),
            else => return err,
        }
        return;
    }

    if (options.serve_only) {
        try serveBootFiles(init.io, allocator, options);
        return;
    }

    const dev = try findOrWaitBootDevice(init.io, allocator, options.wait, options.wait_timeout_ms, .first_stage);
    std.debug.print("found BCM2708 first-stage boot device at {s} serial-index={d}\n", .{ dev.path.slice(), dev.serial_index });
    try load(dev.path.slice(), image);
    try serveBootFiles(init.io, allocator, options);
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var image_seen = false;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (bytes.eql(arg, "--dry-run")) {
            options.dry_run = true;
        } else if (bytes.eql(arg, "--serve-only")) {
            options.serve_only = true;
            options.wait = true;
        } else if (bytes.eql(arg, "--wait")) {
            options.wait = true;
        } else if (bytes.eql(arg, "--wait-ms")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.wait = true;
            options.wait_timeout_ms = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (bytes.eql(arg, "--serve-dir")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.boot_dir = args[index];
        } else if (bytes.eql(arg, "--kernel-image")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.kernel_path = args[index];
        } else if (!image_seen) {
            options.image_path = arg;
            image_seen = true;
        } else {
            return error.InvalidArguments;
        }
    }
    return options;
}

fn findOrWaitBootDevice(io: std.Io, allocator: std.mem.Allocator, wait: bool, timeout_ms_total: u32, phase: DevicePhase) !DeviceInfo {
    var waited_ms: u32 = 0;
    while (true) {
        if (findBootDevice(io, allocator, phase)) |dev| return dev else |err| switch (err) {
            error.BootDeviceNotFound => if (!wait) return err,
            else => return err,
        }
        if (timeout_ms_total != wait_forever_ms and waited_ms >= timeout_ms_total) return error.BootDeviceNotFound;
        sleepMillis(wait_poll_ms);
        waited_ms +|= wait_poll_ms;
    }
}

fn findBootDevice(io: std.Io, allocator: std.mem.Allocator, phase: DevicePhase) !DeviceInfo {
    var sys = try std.Io.Dir.openDirAbsolute(io, "/sys/bus/usb/devices", .{ .iterate = true });
    defer sys.close(io);

    var it = sys.iterate();
    while (try it.next(io)) |entry| {
        const vendor = readSysfsTrimmed(io, allocator, entry.name, "idVendor") catch continue;
        defer allocator.free(vendor);
        const product = readSysfsTrimmed(io, allocator, entry.name, "idProduct") catch continue;
        defer allocator.free(product);
        if (!std.ascii.eqlIgnoreCase(vendor, "0a5c")) continue;
        if (!std.ascii.eqlIgnoreCase(product, "2763") and !std.ascii.eqlIgnoreCase(product, "2764")) continue;

        const bus_text = readSysfsTrimmed(io, allocator, entry.name, "busnum") catch continue;
        defer allocator.free(bus_text);
        const dev_text = readSysfsTrimmed(io, allocator, entry.name, "devnum") catch continue;
        defer allocator.free(dev_text);
        const serial_index = readSerialDescriptorIndex(io, allocator, entry.name) catch 0;

        const bus = std.fmt.parseUnsigned(u16, bus_text, 10) catch continue;
        const dev = std.fmt.parseUnsigned(u16, dev_text, 10) catch continue;
        var path: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&path, "/dev/bus/usb/{d:0>3}/{d:0>3}", .{ bus, dev }) catch unreachable;
        const info = DeviceInfo{ .path = .{ .bytes = path, .len = text.len }, .serial_index = serial_index };
        if (phase == .any or info.phase() == phase) return info;
    }
    return error.BootDeviceNotFound;
}

fn readSerialDescriptorIndex(io: std.Io, allocator: std.mem.Allocator, device_name: []const u8) !u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/sys/bus/usb/devices/{s}/descriptors", .{device_name});
    const raw = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(4096));
    defer allocator.free(raw);
    if (raw.len < 17) return error.InvalidDescriptor;
    return raw[16];
}

fn readSysfsTrimmed(io: std.Io, allocator: std.mem.Allocator, device_name: []const u8, leaf: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/sys/bus/usb/devices/{s}/{s}", .{ device_name, leaf });
    const raw = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64));
    defer allocator.free(raw);
    return try allocator.dupe(u8, std.mem.trim(u8, raw, " \t\r\n"));
}

fn load(path: []const u8, image: []const u8) !void {
    const fd = posix.openat(posix.AT.FDCWD, path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch |err| {
        if (err == error.AccessDenied) {
            std.debug.print("usbfs access denied for {s}; /dev/bus/usb permissions require root or a local udev rule\n", .{path});
        }
        return err;
    };
    defer _ = linux.close(fd);

    var interface: c_uint = 0;
    try ioctlOk("claim-interface", fd, usbdevfs_claim_interface, @intFromPtr(&interface));
    defer _ = ioctl(fd, usbdevfs_release_interface, @intFromPtr(&interface));

    const header = bcm.secondStageHeader(@intCast(image.len), null);
    _ = try sendPayload("second-stage-header", fd, &header);
    _ = try sendPayload("second-stage-bootcode", fd, image);
    sleepMillis(1000);
    try readReturnCode(fd);

    std.debug.print("loaded BCM2708 second stage: header={d} bytes bootcode={d} bytes\n", .{ header.len, image.len });
}

fn sendPayload(label: []const u8, fd: posix.fd_t, payload: []const u8) !PayloadResult {
    const request = bcm.writeControlRequest(@intCast(payload.len));
    var control = UsbCtrlTransfer{
        .request_type = request.request_type,
        .request = request.request,
        .value = request.value,
        .index = request.index,
        .length = request.length,
        .timeout = timeout_ms,
        .data = null,
    };
    try ioctlOk("control", fd, usbdevfs_control, @intFromPtr(&control));

    var offset: usize = 0;
    while (offset < payload.len) {
        const chunk_len = @min(payload.len - offset, bcm.max_bulk_bytes);
        var bulk = UsbBulkTransfer{
            .endpoint = bcm.endpoint_out,
            .len = @intCast(chunk_len),
            .timeout = timeout_ms,
            .data = @ptrCast(@constCast(payload[offset .. offset + chunk_len].ptr)),
        };
        ioctlOk("bulk", fd, usbdevfs_bulk, @intFromPtr(&bulk)) catch |err| {
            std.debug.print("payload {s} failed at offset={d} chunk={d} total={d}: {s}\n", .{
                label,
                offset,
                chunk_len,
                payload.len,
                @errorName(err),
            });
            return err;
        };
        offset += chunk_len;
        if (payload.len > bcm.max_bulk_bytes and (offset == payload.len or (offset % (256 * 1024)) == 0)) {
            std.debug.print("payload {s} sent {d}/{d}\n", .{ label, offset, payload.len });
        }
    }
    return .{ .requested = payload.len, .sent = offset, .completed = true };
}

fn readReturnCode(fd: posix.fd_t) !void {
    const request = bcm.readControlRequest(bcm.return_code_bytes);
    var retcode: u32 = 0xffff_ffff;
    var control = UsbCtrlTransfer{
        .request_type = request.request_type,
        .request = request.request,
        .value = request.value,
        .index = request.index,
        .length = request.length,
        .timeout = return_timeout_ms,
        .data = &retcode,
    };
    try ioctlOk("return-code", fd, usbdevfs_control, @intFromPtr(&control));
    if (retcode != 0) {
        std.debug.print("BCM2708 second-stage returned 0x{x}\n", .{retcode});
        return error.BootRomRejectedSecondStage;
    }
}

fn serveBootFiles(io: std.Io, allocator: std.mem.Allocator, options: Options) !void {
    std.debug.print("waiting for BCM2708 second-stage file server\n", .{});
    const dev = try findOrWaitBootDevice(io, allocator, true, options.wait_timeout_ms, .file_server);
    std.debug.print("serving boot files to {s} serial-index={d} from {s}; kernel.img={s}\n", .{
        dev.path.slice(),
        dev.serial_index,
        options.boot_dir,
        options.kernel_path,
    });

    const fd = posix.openat(posix.AT.FDCWD, dev.path.slice(), .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0) catch |err| {
        if (err == error.AccessDenied) {
            std.debug.print("usbfs access denied for {s}; /dev/bus/usb permissions require root or a local udev rule\n", .{dev.path.slice()});
        }
        return err;
    };
    defer _ = linux.close(fd);

    var interface: c_uint = 0;
    try ioctlOk("claim-interface", fd, usbdevfs_claim_interface, @intFromPtr(&interface));
    defer _ = ioctl(fd, usbdevfs_release_interface, @intFromPtr(&interface));

    while (true) {
        var raw = [_]u8{0} ** file_message_bytes;
        try readBytes(fd, &raw, return_timeout_ms);
        const request = decodeFileRequest(&raw) orelse {
            try sendLengthOnly(fd, 0);
            continue;
        };
        if (request.name.len == 0 or request.command == file_command_done) {
            try sendLengthOnly(fd, 0);
            break;
        }
        if (!safeFileName(request.name)) {
            std.debug.print("denying unsafe boot file request: {s}\n", .{request.name});
            try sendLengthOnly(fd, 0);
            continue;
        }

        switch (request.command) {
            file_command_get_size => {
                const size = bootFileSize(io, options, request.name) catch {
                    std.debug.print("boot file missing: {s}\n", .{request.name});
                    try sendLengthOnly(fd, 0);
                    continue;
                };
                try sendLengthOnly(fd, size);
                std.debug.print("boot file size: {s} {d}\n", .{ request.name, size });
            },
            file_command_read => {
                const data = readBootFile(io, allocator, options, request.name) catch {
                    std.debug.print("boot file read failed: {s}\n", .{request.name});
                    try sendLengthOnly(fd, 0);
                    continue;
                };
                defer allocator.free(data);
                const result = try sendPayload(request.name, fd, data);
                std.debug.print("boot file sent: {s} {d}/{d}\n", .{ request.name, result.sent, result.requested });
            },
            else => {
                std.debug.print("unknown boot file command {d} for {s}\n", .{ request.command, request.name });
                try sendLengthOnly(fd, 0);
            },
        }
    }

    std.debug.print("BCM2708 second-stage file server done\n", .{});
}

fn readBytes(fd: posix.fd_t, out: []u8, timeout: u32) !void {
    const request = bcm.readControlRequest(@intCast(out.len));
    var control = UsbCtrlTransfer{
        .request_type = request.request_type,
        .request = request.request,
        .value = request.value,
        .index = request.index,
        .length = request.length,
        .timeout = timeout,
        .data = out.ptr,
    };
    try ioctlOk("read", fd, usbdevfs_control, @intFromPtr(&control));
}

fn sendLengthOnly(fd: posix.fd_t, length: u32) !void {
    const request = bcm.writeControlRequest(length);
    var control = UsbCtrlTransfer{
        .request_type = request.request_type,
        .request = request.request,
        .value = request.value,
        .index = request.index,
        .length = 0,
        .timeout = timeout_ms,
        .data = null,
    };
    try ioctlOk("length-only", fd, usbdevfs_control, @intFromPtr(&control));
}

fn decodeFileRequest(raw: *const [file_message_bytes]u8) ?FileRequest {
    const command = std.mem.readInt(u32, raw[0..4], .little);
    const name_raw = raw[4..];
    const name_len = std.mem.indexOfScalar(u8, name_raw, 0) orelse name_raw.len;
    return .{ .command = command, .name = name_raw[0..name_len] };
}

fn safeFileName(name: []const u8) bool {
    if (name.len == 0 or name.len >= file_name_bytes) return false;
    if (name[0] == '/' or name[0] == '\\' or name[0] == '*') return false;
    if (bytes.indexOf(name, "..") != null) return false;
    for (name) |byte| {
        if (byte == 0 or byte == '\\') return false;
    }
    return true;
}

fn bootFileSize(io: std.Io, options: Options, name: []const u8) !u32 {
    const file = try readBootFile(io, std.heap.page_allocator, options, name);
    defer std.heap.page_allocator.free(file);
    return @intCast(file.len);
}

fn readBootFile(io: std.Io, allocator: std.mem.Allocator, options: Options, name: []const u8) ![]u8 {
    if (bytes.eql(name, "kernel.img")) {
        return std.Io.Dir.cwd().readFileAlloc(io, options.kernel_path, allocator, .limited(16 * 1024 * 1024));
    }
    var path_buf: [512]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ options.boot_dir, name });
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(16 * 1024 * 1024));
}

fn sleepMillis(ms: u32) void {
    const req = linux.timespec{
        .sec = @intCast(ms / 1000),
        .nsec = @intCast((ms % 1000) * 1_000_000),
    };
    _ = linux.nanosleep(&req, null);
}

fn ioctlOk(label: []const u8, fd: posix.fd_t, request: u32, arg: usize) !void {
    const rc = ioctl(fd, request, arg);
    const err = linux.errno(rc);
    switch (err) {
        .SUCCESS => return,
        .PERM => return error.PermissionDenied,
        .ACCES => return error.AccessDenied,
        .NOENT => return error.FileNotFound,
        .NODEV => return error.NoDevice,
        .PIPE => return error.Pipe,
        .TIMEDOUT => return error.Timeout,
        .BUSY => return error.Busy,
        .INVAL => return error.Invalid,
        else => {
            std.debug.print("usbfs {s} ioctl failed errno={s} raw=0x{x}\n", .{ label, @tagName(err), rc });
            return error.IoctlFailed;
        },
    }
}

fn ioctl(fd: posix.fd_t, request: u32, arg: usize) usize {
    return linux.ioctl(fd, request, arg);
}

fn ioc(dir: u32, kind: u8, nr: u8, size: usize) u32 {
    return (dir << 30) | (@as(u32, @intCast(size)) << 16) | (@as(u32, kind) << 8) | nr;
}

fn ior(kind: u8, nr: u8, size: usize) u32 {
    return ioc(2, kind, nr, size);
}

fn iowr(kind: u8, nr: u8, size: usize) u32 {
    return ioc(3, kind, nr, size);
}

test "parses host loader options" {
    const args = [_][:0]const u8{
        "edgerun-pi-usb-boot-host",
        "--dry-run",
        "--serve-only",
        "--wait",
        "--wait-ms",
        "7000",
        "--serve-dir",
        "boot",
        "--kernel-image",
        "zig-kernel.img",
        "bootcode.bin",
    };
    const options = try parseOptions(&args);
    try std.testing.expect(options.dry_run);
    try std.testing.expect(options.serve_only);
    try std.testing.expect(options.wait);
    try std.testing.expectEqual(@as(u32, 7000), options.wait_timeout_ms);
    try std.testing.expectEqualStrings("boot", options.boot_dir);
    try std.testing.expectEqualStrings("zig-kernel.img", options.kernel_path);
    try std.testing.expectEqualStrings("bootcode.bin", options.image_path);

    const defaults = try parseOptions(args[0..1]);
    try std.testing.expect(!defaults.dry_run);
    try std.testing.expectEqualStrings(default_image_path, defaults.image_path);
}

test "classifies BCM2708 boot phases by USB serial descriptor index" {
    const first_zero = DeviceInfo{ .path = .{ .bytes = [_]u8{0} ** 32, .len = 0 }, .serial_index = 0 };
    const first_three = DeviceInfo{ .path = .{ .bytes = [_]u8{0} ** 32, .len = 0 }, .serial_index = 3 };
    const file_server = DeviceInfo{ .path = .{ .bytes = [_]u8{0} ** 32, .len = 0 }, .serial_index = 1 };
    try std.testing.expectEqual(DevicePhase.first_stage, first_zero.phase());
    try std.testing.expectEqual(DevicePhase.first_stage, first_three.phase());
    try std.testing.expectEqual(DevicePhase.file_server, file_server.phase());
}

test "decodes and validates second-stage file requests" {
    var raw = [_]u8{0} ** file_message_bytes;
    std.mem.writeInt(u32, raw[0..4], file_command_read, .little);
    @memcpy(raw[4..14], "kernel.img");

    const request = decodeFileRequest(&raw).?;
    try std.testing.expectEqual(file_command_read, request.command);
    try std.testing.expectEqualStrings("kernel.img", request.name);
    try std.testing.expect(safeFileName(request.name));
    try std.testing.expect(!safeFileName("../kernel.img"));
    try std.testing.expect(!safeFileName("/kernel.img"));
    try std.testing.expect(!safeFileName("*FACTORY_UUID"));
}

test "matches Linux usbfs ioctl numbers" {
    try std.testing.expectEqual(@as(u32, 0xc018_5500), usbdevfs_control);
    try std.testing.expectEqual(@as(u32, 0xc018_5502), usbdevfs_bulk);
    try std.testing.expectEqual(@as(u32, 0x8004_550f), usbdevfs_claim_interface);
    try std.testing.expectEqual(@as(u32, 0x8004_5510), usbdevfs_release_interface);
}
