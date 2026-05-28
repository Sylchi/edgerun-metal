const std = @import("std");
const bytes = @import("bytes.zig");
const codec = @import("ui_codec.zig");
const linux = std.os.linux;
const posix = std.posix;

const SIOCGIFADDR: u32 = 0x8915;

const Error = error{
    CodecFailed,
    StringFailed,
    RecordFailed,
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

pub fn main(init: std.process.Init) !void {
    var iface_count: usize = 0;
    const dir0 = std.Io.Dir.openDirAbsolute(init.io, "/sys/class/net", .{ .iterate = true }) catch return error.DirectoryFailed;
    defer dir0.close(init.io);
    {
        var iter = dir0.iterate();
        while (try iter.next(init.io)) |entry| {
            if (!bytes.eql(entry.name, "lo")) iface_count += 1;
        }
    }

    const n_iface = @min(@as(u16, @intCast(iface_count)), 32);
    const node_count: u16 = 2 + n_iface * 2;
    const root_count: u16 = node_count;
    if (node_count == 0) return;

    var codec_buf: [8192]u8 = undefined;
    var writer = codec.Writer.init(&codec_buf, node_count, root_count, .column, 2, 4) orelse return error.CodecFailed;

    const header_ref = writer.string("Network Interfaces") orelse return error.StringFailed;
    if (!writer.record(0, .text, 0, header_ref, .{})) return error.RecordFailed;
    if (!writer.record(1, .separator, 0, .{}, .{})) return error.RecordFailed;

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

    var idx: u16 = 2;
    {
        var dir = std.Io.Dir.openDirAbsolute(init.io, "/sys/class/net", .{ .iterate = true }) catch return error.DirectoryFailed;
        defer dir.close(init.io);
        var iter = dir.iterate();
        while (try iter.next(init.io)) |entry| {
            if (bytes.eql(entry.name, "lo")) continue;
            if (idx >= node_count) break;

            const ifname = entry.name;
            const ip = getIP(sock_fd, ifname, &ip_buf);
            const state = readSysfs(init.io, "operstate", ifname, &state_buf) catch "?";
            const mac = readSysfs(init.io, "address", ifname, &mac_buf) catch "??:??:??:??:??:??";
            const rx = readIntSysfs(init.io, "statistics/rx_bytes", ifname, &num_buf);
            const tx = readIntSysfs(init.io, "statistics/tx_bytes", ifname, &num_buf);
            const rx_fmt = formatBytes(rx, &rx_fmt_buf);
            const tx_fmt = formatBytes(tx, &tx_fmt_buf);

            const line1 = std.fmt.bufPrint(&line_buf, "{s}  {s}  {s}", .{ ifname, ip, state }) catch "iface-error";
            const ref1 = writer.string(line1) orelse return error.StringFailed;
            if (!writer.record(idx, .text, idx, ref1, .{})) return error.RecordFailed;
            idx += 1;
            if (idx >= node_count) break;

            const line2 = std.fmt.bufPrint(&line_buf, "  mac {s}  rx {s}  tx {s}", .{ mac, rx_fmt, tx_fmt }) catch "stats-error";
            const ref2 = writer.string(line2) orelse return error.StringFailed;
            if (!writer.record(idx, .text, idx, ref2, .{})) return error.RecordFailed;
            idx += 1;
        }
    }

    const out = writer.written();
    _ = linux.write(1, out.ptr, @intCast(out.len));
}
