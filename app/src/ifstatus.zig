const std = @import("er_std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const object = @import("object.zig");
const linux = std.os.linux;
const posix = std.posix;

const component = @import("ui/components/Component.zig");
const Component = component.Component;
const Stack = @import("ui/components/Stack.zig").Stack(Component);

const SIOCGIFADDR: u32 = 0x8915;

const Error = error{
    CodecFailed,
    DirectoryFailed,
    SocketFailed,
    SysfsFailed,
};

fn ioctl(fd: posix.fd_t, request: u32, arg: usize) usize {
    return linux.ioctl(fd, request, arg);
}

fn readSysfs(io: std.Io, suffix: []const u8, ifname: []const u8, buf: []u8) Error![]const u8 {
    var path_buf: [256]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "/sys/class/net/{s}/{s}", .{ ifname, suffix }) catch return error.SysfsFailed;
    const content = std.Io.Dir.cwd().readFile(io, path, buf) catch return error.SysfsFailed;
    return std.mem.trimEnd(u8, content, " \n\r");
}

fn readIntSysfs(io: std.Io, suffix: []const u8, ifname: []const u8, buf: []u8) u64 {
    const text = readSysfs(io, suffix, ifname, buf) catch return 0;
    return std.fmt.parseInt(u64, std.mem.trim(u8, text, " \t\n\r"), 10) catch 0;
}

fn formatBytes(val: u64, buf: []u8) []const u8 {
    if (val < 1024) return std.fmt.bufPrint(buf, "{} B", .{val}) catch "? B";
    if (val < 1024 * 1024) return std.fmt.bufPrint(buf, "{} KB", .{val / 1024}) catch "? KB";
    if (val < 1024 * 1024 * 1024) return std.fmt.bufPrint(buf, "{} MB", .{val / (1024 * 1024)}) catch "? MB";
    return std.fmt.bufPrint(buf, "{} GB", .{val / (1024 * 1024 * 1024)}) catch "? GB";
}

fn getIP(sock_fd: posix.fd_t, ifname: []const u8, buf: []u8) []const u8 {
    var ifr: [40]u8 = .{0} ** 40;
    const copy_len = @min(ifname.len, @as(usize, 15));
    @memcpy(ifr[0..copy_len], ifname[0..copy_len]);
    const rc = ioctl(sock_fd, SIOCGIFADDR, @intFromPtr(&ifr));
    if (rc != 0) return "-";
    const ip_bytes = ifr[20..24];
    return std.fmt.bufPrint(buf, "{d}.{d}.{d}.{d}", .{ ip_bytes[0], ip_bytes[1], ip_bytes[2], ip_bytes[3] }) catch "bad-ip";
}

pub fn main() !void {
    const io: std.Io = .{};
    var iface_count: usize = 0;
    const dir0 = std.Io.Dir.openDirAbsolute(io, "/sys/class/net", .{ .iterate = true }) catch return error.DirectoryFailed;
    defer dir0.close(io);
    {
        var iter = dir0.iterate();
        while (try iter.next(io)) |entry| {
            if (!bytes.eql(entry.name, "lo")) iface_count += 1;
        }
    }

    const n_iface = @min(@as(u16, @intCast(iface_count)), 32);
    const node_count: usize = 2 + n_iface * 2;
    if (node_count == 0) return;

    var storage: [8192]u8 = undefined;
    var storage_pos: usize = 0;

    const store = struct {
        fn put(buf: *[8192]u8, pos: *usize, value: []const u8) []const u8 {
            if (pos.* + value.len > buf.len) return value;
            const start = pos.*;
            pos.* += value.len;
            @memcpy(buf[start..][0..value.len], value);
            return buf[start..][0..value.len];
        }
    }.put;

    const header_text = store(&storage, &storage_pos, "Network Interfaces");

    var components: [66]Component = undefined;
    components[0] = component.text(header_text);
    components[1] = component.separator();

    var ip_buf: [16]u8 = undefined;
    var state_buf: [8]u8 = undefined;
    var mac_buf: [18]u8 = undefined;
    var num_buf: [32]u8 = undefined;
    var rx_fmt_buf: [16]u8 = undefined;
    var tx_fmt_buf: [16]u8 = undefined;
    var line_buf: [128]u8 = undefined;

    const sock_rc = linux.socket(2, 2, 0);
    if (sock_rc < 0) return error.SocketFailed;
    const sock_fd: posix.fd_t = @intCast(sock_rc);
    defer _ = linux.close(sock_fd);

    var idx: usize = 2;
    {
        var dir = std.Io.Dir.openDirAbsolute(io, "/sys/class/net", .{ .iterate = true }) catch return error.DirectoryFailed;
        defer dir.close(io);
        var iter = dir.iterate();
        while (try iter.next(io)) |entry| {
            if (bytes.eql(entry.name, "lo")) continue;
            if (idx >= node_count) break;

            const ifname = entry.name;
            const ip = getIP(sock_fd, ifname, &ip_buf);
            const state = readSysfs(io, "operstate", ifname, &state_buf) catch "?";
            const mac = readSysfs(io, "address", ifname, &mac_buf) catch "??:??:??:??:??:??";
            const rx = readIntSysfs(io, "statistics/rx_bytes", ifname, &num_buf);
            const tx = readIntSysfs(io, "statistics/tx_bytes", ifname, &num_buf);
            const rx_fmt = formatBytes(rx, &rx_fmt_buf);
            const tx_fmt = formatBytes(tx, &tx_fmt_buf);

            const line1_raw = std.fmt.bufPrint(&line_buf, "{s}  {s}  {s}", .{ ifname, ip, state }) catch "iface-error";
            const line1 = store(&storage, &storage_pos, line1_raw);
            components[idx] = component.text(line1);
            idx += 1;

            const line2_raw = std.fmt.bufPrint(&line_buf, "  mac {s}  rx {s}  tx {s}", .{ mac, rx_fmt, tx_fmt }) catch "stats-error";
            const line2 = store(&storage, &storage_pos, line2_raw);
            components[idx] = component.text(line2);
            idx += 1;
        }
    }

    const stack = Stack{ .axis = .column, .gap = 2, .padding = 4, .children = components[0..idx] };
    var ui_raw: [8192]u8 = undefined;
    var object_raw: [object.header_size + 8192]u8 = undefined;
    const keeper_bytes: [clock.keeper_id_size]u8 = .{0} ** 31 ++ .{1} ** 1;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = keeper_bytes } };
    const canonical = stack.toObject(&ui_raw, &object_raw, epoch) orelse return error.CodecFailed;
    _ = linux.write(1, canonical.ptr, @intCast(canonical.len));
}
