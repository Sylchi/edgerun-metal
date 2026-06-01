const std = @import("er_std");
const bytes = @import("bytes.zig");
const control = @import("pi_usb_control.zig");

const linux = std.os.linux;
const posix = std.posix;

const timeout_ms: u32 = 5000;
const wait_poll_ms: u32 = 250;
const wait_forever_ms: u32 = ~@as(u32, 0);

const UsbBulkTransfer = extern struct {
    endpoint: c_uint,
    len: c_uint,
    timeout: c_uint,
    data: ?*anyopaque,
};

const usbdevfs_bulk = iowr('U', 2, @sizeOf(UsbBulkTransfer));
const usbdevfs_claim_interface = ior('U', 15, @sizeOf(c_uint));
const usbdevfs_release_interface = ior('U', 16, @sizeOf(c_uint));

const Options = struct {
    dry_run: bool = false,
    wait: bool = false,
    wait_timeout_ms: u32 = wait_forever_ms,
    sequence: u32 = 1,
    command: CommandLine,
};

const CommandLine = union(enum) {
    gpio_read: u32,
    gpio_write: struct {
        pin: u32,
        value: u32,
    },
    memory_read: struct {
        address: u64,
        length: u32,
    },
};

const DevicePath = struct {
    bytes: [32]u8,
    len: usize,

    fn slice(self: *const DevicePath) []const u8 {
        return self.bytes[0..self.len];
    }
};

pub fn main() !void {}

fn run(args: []const [:0]const u8, io: std.Io, allocator: std.mem.Allocator) !void {
    const options = try parseOptions(args);
    const request = makeProtocolRequest(options) orelse return error.InvalidArguments;
    if (options.dry_run) {
        std.debug.print("Edgerun Pi control plan: sequence={d} command={s} address=0x{x} length={d} value=0x{x}\n", .{
            request.sequence,
            @tagName(request.command),
            request.address,
            request.length,
            request.value,
        });
        return;
    }
    const dev = try findOrWaitDevice(io, allocator, options.wait, options.wait_timeout_ms);
    std.debug.print("found Edgerun Pi control device at {s}\n", .{dev.slice()});
    try transact(dev.slice(), request);
}

fn parseOptions(args: []const [:0]const u8) !Options {
    var dry_run = false;
    var wait = false;
    var wait_timeout_ms: u32 = wait_forever_ms;
    var index: usize = 1;
    while (index < args.len and bytes.startsWith(args[index], "--")) : (index += 1) {
        if (bytes.eql(args[index], "--wait")) {
            wait = true;
        } else if (bytes.eql(args[index], "--dry-run")) {
            dry_run = true;
        } else if (bytes.eql(args[index], "--wait-ms")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            wait = true;
            wait_timeout_ms = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else {
            return error.InvalidArguments;
        }
    }
    if (index >= args.len) return error.InvalidArguments;

    const verb = args[index];
    index += 1;
    const command: CommandLine = if (bytes.eql(verb, "gpio-read")) blk: {
        if (index + 1 != args.len) return error.InvalidArguments;
        break :blk .{ .gpio_read = try std.fmt.parseUnsigned(u32, args[index], 0) };
    } else if (bytes.eql(verb, "gpio-write")) blk: {
        if (index + 2 != args.len) return error.InvalidArguments;
        break :blk .{ .gpio_write = .{
            .pin = try std.fmt.parseUnsigned(u32, args[index], 0),
            .value = try std.fmt.parseUnsigned(u32, args[index + 1], 0),
        } };
    } else if (bytes.eql(verb, "memory-read")) blk: {
        if (index + 2 != args.len) return error.InvalidArguments;
        break :blk .{ .memory_read = .{
            .address = try std.fmt.parseUnsigned(u64, args[index], 0),
            .length = try std.fmt.parseUnsigned(u32, args[index + 1], 0),
        } };
    } else return error.InvalidArguments;

    return .{ .dry_run = dry_run, .wait = wait, .wait_timeout_ms = wait_timeout_ms, .command = command };
}

fn makeProtocolRequest(options: Options) ?control.Request {
    return switch (options.command) {
        .gpio_read => |pin| control.makeRequest(options.sequence, .gpio_read, pin, 4, 0),
        .gpio_write => |cmd| control.makeRequest(options.sequence, .gpio_write, cmd.pin, 0, cmd.value),
        .memory_read => |cmd| control.makeRequest(options.sequence, .memory_read, cmd.address, cmd.length, 0),
    };
}

fn findOrWaitDevice(io: std.Io, allocator: std.mem.Allocator, wait: bool, timeout_ms_total: u32) !DevicePath {
    var waited_ms: u32 = 0;
    while (true) {
        if (findDevice(io, allocator)) |dev| return dev else |err| switch (err) {
            error.ControlDeviceNotFound => if (!wait) return err,
            else => return err,
        }
        if (timeout_ms_total != wait_forever_ms and waited_ms >= timeout_ms_total) return error.ControlDeviceNotFound;
        sleepMillis(wait_poll_ms);
        waited_ms +|= wait_poll_ms;
    }
}

fn findDevice(io: std.Io, allocator: std.mem.Allocator) !DevicePath {
    var sys = try std.Io.Dir.openDirAbsolute(io, "/sys/bus/usb/devices", .{ .iterate = true });
    defer sys.close(io);

    var it = sys.iterate();
    while (try it.next(io)) |entry| {
        const vendor = readSysfsTrimmed(io, allocator, entry.name, "idVendor") catch continue;
        defer allocator.free(vendor);
        const product = readSysfsTrimmed(io, allocator, entry.name, "idProduct") catch continue;
        defer allocator.free(product);
        if (!std.ascii.eqlIgnoreCase(vendor, "4552") or !std.ascii.eqlIgnoreCase(product, "5049")) continue;

        const bus_text = readSysfsTrimmed(io, allocator, entry.name, "busnum") catch continue;
        defer allocator.free(bus_text);
        const dev_text = readSysfsTrimmed(io, allocator, entry.name, "devnum") catch continue;
        defer allocator.free(dev_text);

        const bus = std.fmt.parseUnsigned(u16, bus_text, 10) catch continue;
        const dev = std.fmt.parseUnsigned(u16, dev_text, 10) catch continue;
        var path: [32]u8 = undefined;
        const text = std.fmt.bufPrint(&path, "/dev/bus/usb/{d:0>3}/{d:0>3}", .{ bus, dev }) catch unreachable;
        return .{ .bytes = path, .len = text.len };
    }
    return error.ControlDeviceNotFound;
}

fn readSysfsTrimmed(io: std.Io, allocator: std.mem.Allocator, device_name: []const u8, leaf: []const u8) ![]u8 {
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/sys/bus/usb/devices/{s}/{s}", .{ device_name, leaf });
    const raw = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(64));
    defer allocator.free(raw);
    return try allocator.dupe(u8, std.mem.trim(u8, raw, " \t\r\n"));
}

fn transact(path: []const u8, request: control.Request) !void {
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

    var raw_request = [_]u8{0} ** control.request_header_bytes;
    if (!request.encode(&raw_request)) return error.InvalidRequest;
    try bulkTransfer(fd, control.endpoint_out, &raw_request);

    var raw_response = [_]u8{0} ** control.response_header_bytes;
    try bulkTransfer(fd, control.endpoint_in, &raw_response);
    const response = control.Response.decode(&raw_response, request) orelse return error.InvalidResponse;
    std.debug.print("status={s} length={d} value=0x{x}\n", .{ @tagName(response.status), response.length, response.value });

    if (response.status != .ok) return error.DeviceRejectedRequest;
    if (request.command == .memory_read and response.length != 0) {
        if (response.length > control.max_transfer_bytes) return error.InvalidResponse;
        var buffer: [control.max_transfer_bytes]u8 = undefined;
        const data = buffer[0..response.length];
        try bulkTransfer(fd, control.endpoint_in, data);
        dumpHex(data);
    }
}

fn bulkTransfer(fd: posix.fd_t, endpoint: u8, data: []u8) !void {
    var bulk = UsbBulkTransfer{
        .endpoint = endpoint,
        .len = @intCast(data.len),
        .timeout = timeout_ms,
        .data = data.ptr,
    };
    try ioctlOk("bulk", fd, usbdevfs_bulk, @intFromPtr(&bulk));
}

fn dumpHex(data: []const u8) void {
    var offset: usize = 0;
    while (offset < data.len) : (offset += 1) {
        std.debug.print("{x:0>2}", .{data[offset]});
        if ((offset + 1) % 16 == 0 or offset + 1 == data.len) {
            std.debug.print("\n", .{});
        } else {
            std.debug.print(" ", .{});
        }
    }
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

fn sleepMillis(ms: u32) void {
    const req = linux.timespec{
        .sec = @intCast(ms / 1000),
        .nsec = @intCast((ms % 1000) * 1_000_000),
    };
    _ = linux.nanosleep(&req, null);
}

test "parses Pi control host commands" {
    const gpio_read_args = [_][:0]const u8{ "edgerun-pi-usb-control-host", "--dry-run", "--wait-ms", "1000", "gpio-read", "47" };
    const gpio_read = try parseOptions(&gpio_read_args);
    try std.testing.expect(gpio_read.dry_run);
    try std.testing.expect(gpio_read.wait);
    try std.testing.expectEqual(@as(u32, 1000), gpio_read.wait_timeout_ms);
    try std.testing.expectEqual(@as(u32, 47), gpio_read.command.gpio_read);

    const gpio_write_args = [_][:0]const u8{ "edgerun-pi-usb-control-host", "gpio-write", "47", "1" };
    const gpio_write = try parseOptions(&gpio_write_args);
    try std.testing.expectEqual(@as(u32, 47), gpio_write.command.gpio_write.pin);
    try std.testing.expectEqual(@as(u32, 1), gpio_write.command.gpio_write.value);

    const memory_read_args = [_][:0]const u8{ "edgerun-pi-usb-control-host", "memory-read", "0x20000000", "16" };
    const memory_read = try parseOptions(&memory_read_args);
    try std.testing.expectEqual(@as(u64, 0x2000_0000), memory_read.command.memory_read.address);
    try std.testing.expectEqual(@as(u32, 16), memory_read.command.memory_read.length);
}

test "builds Pi USB control protocol requests" {
    const options = Options{ .command = .{ .gpio_read = 47 } };
    const request = makeProtocolRequest(options).?;
    try std.testing.expectEqual(control.Command.gpio_read, request.command);
    try std.testing.expectEqual(@as(u64, 47), request.address);
    try std.testing.expectEqual(@as(u32, 4), request.length);
}

test "matches Linux usbfs bulk ioctl number" {
    try std.testing.expectEqual(@as(u32, 0xc018_5502), usbdevfs_bulk);
    try std.testing.expectEqual(@as(u32, 0x8004_550f), usbdevfs_claim_interface);
    try std.testing.expectEqual(@as(u32, 0x8004_5510), usbdevfs_release_interface);
}
