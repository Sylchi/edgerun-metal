const std = @import("std");
const bytes_mod = @import("../bytes.zig");

pub const PresentMode = enum {
    cpu,
    gpu_record,
    gpu_dmabuf,
};

pub const Options = struct {
    width: u32 = default_width,
    height: u32 = default_height,
    seconds: u32 = default_seconds,
    present: PresentMode = .cpu,
    drm_device: []const u8 = @import("../linux_drm.zig").default_device_path,
    dmabuf_fd: ?std.posix.fd_t = null,
    path: []const u8 = "/",
    dashboard: bool = false,
    hardware: bool = false,
};

const default_width: u32 = 960;
const default_height: u32 = 540;
const default_seconds: u32 = 5;

pub fn parseOptions(args: []const [:0]const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (bytes_mod.eql(arg, "--width")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.width = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (bytes_mod.eql(arg, "--height")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.height = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (bytes_mod.eql(arg, "--seconds")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.seconds = try std.fmt.parseUnsigned(u32, args[index], 10);
        } else if (bytes_mod.eql(arg, "--present")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.present = try parsePresentMode(args[index]);
        } else if (bytes_mod.eql(arg, "--drm-device")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.drm_device = args[index];
        } else if (bytes_mod.eql(arg, "--dmabuf-fd")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.dmabuf_fd = try std.fmt.parseInt(std.posix.fd_t, args[index], 10);
        } else if (bytes_mod.eql(arg, "--path")) {
            index += 1;
            if (index >= args.len) return error.InvalidArguments;
            options.path = args[index];
        } else if (bytes_mod.eql(arg, "--dashboard")) {
            options.dashboard = true;
        } else if (bytes_mod.eql(arg, "--hardware")) {
            options.hardware = true;
        } else if (bytes_mod.eql(arg, "--help")) {
            return error.HelpRequested;
        } else {
            return error.InvalidArguments;
        }
    }
    if (options.width == 0 or options.height == 0 or options.seconds == 0) return error.InvalidArguments;
    return options;
}

pub fn help() void {
    const out = std.debug;
    out.print(
        \\Usage: edgerun-wayland-window [options]
        \\
        \\Options:
        \\  --width <px>        Window width (default: 960)
        \\  --height <px>       Window height (default: 540)
        \\  --seconds <n>       Run for n seconds (default: 5)
        \\  --dashboard         Show network dashboard
        \\  --hardware          Show hardware dashboard
        \\  --help              Show this help
        \\
    , .{});
}

pub fn parsePresentMode(value: []const u8) !PresentMode {
    if (bytes_mod.eql(value, "cpu")) return .cpu;
    if (bytes_mod.eql(value, "gpu-record")) return .gpu_record;
    if (bytes_mod.eql(value, "gpu-dmabuf")) return .gpu_dmabuf;
    return error.InvalidArguments;
}

pub fn parseHostIp(url: []const u8) ?[]const u8 {
    var authority = url;
    if (std.mem.startsWith(u8, authority, "http://")) {
        authority = authority[7..];
    } else if (std.mem.startsWith(u8, authority, "https://")) {
        authority = authority[8..];
    }
    if (std.mem.indexOfScalar(u8, authority, '/')) |slash| {
        authority = authority[0..slash];
    }
    const colon = std.mem.lastIndexOfScalar(u8, authority, ':') orelse return null;
    if (colon == 0 or colon + 1 >= authority.len) return null;
    const host = authority[0..colon];
    if (!isValidIPv4(host)) return null;
    return host;
}

fn isValidIPv4(host: []const u8) bool {
    var dot_count: usize = 0;
    var segment_len: usize = 0;
    var value: u16 = 0;

    if (host.len == 0) return false;
    for (host) |ch| {
        if (ch == '.') {
            if (segment_len == 0) return false;
            if (dot_count >= 3) return false;
            dot_count += 1;
            segment_len = 0;
            value = 0;
            continue;
        }
        if (ch < '0' or ch > '9') return false;
        if (segment_len >= 3) return false;
        const next = value * 10 + (ch - '0');
        if (next > 255) return false;
        value = next;
        segment_len += 1;
    }
    if (dot_count != 3 or segment_len == 0) return false;
    return true;
}

pub fn isHostApiReachable(host_url: []const u8) bool {
    const host = parseHostIp(host_url) orelse return false;
    var ifstatus_buf: [4096]u8 = undefined;
    const app_dashboard = @import("../app_dashboard.zig");
    const ifstatus_bytes = app_dashboard.readIfstatusBytes(&ifstatus_buf) catch return false;
    return std.mem.indexOf(u8, ifstatus_bytes, host) != null;
}

pub fn waylandSocketPath(init: std.process.Init, allocator: std.mem.Allocator) ![]u8 {
    const runtime_dir = init.environ_map.get("XDG_RUNTIME_DIR") orelse return error.MissingWaylandRuntime;
    const display = init.environ_map.get("WAYLAND_DISPLAY") orelse "wayland-0";
    if (std.mem.indexOfScalar(u8, display, '/')) |_| return allocator.dupe(u8, display);
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ runtime_dir, display });
}
