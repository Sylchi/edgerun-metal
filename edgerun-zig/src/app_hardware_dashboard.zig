const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const ui = @import("ui.zig");
const object = @import("object.zig");
const component_union = @import("ui/components/Component.zig");
const stack_component = @import("ui/components/Stack.zig");
const row_item = @import("ui/components/RowItem.zig");

const linux = std.os.linux;
const posix = std.posix;

const Component = component_union.Component;
const Stack = stack_component.Stack(Component);

pub const Error = error{
    ReadFailed,
    ParseFailed,
};

const row_count = 10;
const component_count = row_count + 1; // title + rows

const detail_bytes = 80;
const state_bytes = row_count * detail_bytes;

pub const State = struct {
    details: [state_bytes]u8 = [_]u8{0} ** state_bytes,

    pub fn refresh(self: *State) void {
        var offset: usize = 0;

        // Row 0: System
        writeDetail(self.details[offset..][0..detail_bytes], "System: Framework 13 AMD 7840U");
        offset += detail_bytes;

        // Row 1: CPU Temperature
        var cpu_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readFirstThermal(&cpu_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], @as([]const u8, trimBuf(&cpu_buf)));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "CPU temp: N/A");
        }
        offset += detail_bytes;

        // Row 2: Memory
        var mem_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readMem(&mem_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&mem_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "Memory: N/A");
        }
        offset += detail_bytes;

        // Row 3: Battery
        var bat_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readBattery(&bat_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&bat_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "Battery: N/A");
        }
        offset += detail_bytes;

        // Row 4: Keyboard Backlight
        var kbd_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readKbdBacklight(&kbd_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&kbd_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "KBD backlight: N/A");
        }
        offset += detail_bytes;

        // Row 5: EC
        var ec_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readEcInfo(&ec_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&ec_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "EC: N/A");
        }
        offset += detail_bytes;

        // Row 6: AMDGPU
        var gpu_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readAmdgpu(&gpu_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&gpu_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "AMDGPU: N/A");
        }
        offset += detail_bytes;

        // Row 7: TPM
        var tpm_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readTpmInfo(&tpm_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&tpm_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "TPM: N/A");
        }
        offset += detail_bytes;

        // Row 8: PCI devices
        var pci_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readPciCount(&pci_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&pci_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "PCI: N/A");
        }
        offset += detail_bytes;

        // Row 9: Network
        var net_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readNetwork(&net_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&net_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "Network: N/A");
        }
    }

    pub fn render(self: *State, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) !void {
        var cursor = ui.LinearCursor.init(bounds, .column, 4);
        const rows = [_]RowInfo{
            .{ .title = "Platform" },
            .{ .title = "CPU Temp" },
            .{ .title = "Memory" },
            .{ .title = "Battery" },
            .{ .title = "Keyboard Light" },
            .{ .title = "EC" },
            .{ .title = "AMDGPU" },
            .{ .title = "TPM" },
            .{ .title = "PCI Devices" },
            .{ .title = "Network" },
        };

        for (&rows, 0..) |*row, i| {
            const detail_str = self.detail(i);
            const panel_h: f32 = 36;
            const panel_bounds = cursor.take(panel_h);
            if (!panel_bounds.usable()) break;

            try scene.pushRect(panel_bounds, style.panel, .fill, 4, 0);
            const inner = panel_bounds.insetUniform(4);
            if (!inner.valid()) continue;

            const title_h: f32 = 14;
            try scene.pushText(ui.Rect.init(inner.x, inner.y, inner.w, title_h), row.title, style.accent);
            if (inner.h > title_h + 2) {
                const detail_y = inner.y + title_h + 2;
                try scene.pushText(ui.Rect.init(inner.x, detail_y, inner.w, inner.h - title_h - 2), detail_str, style.text);
            }
        }
    }

    fn detail(self: *State, row: usize) []const u8 {
        if (row >= row_count) return "";
        const raw = self.details[row * detail_bytes ..][0..detail_bytes];
        var len: usize = 0;
        while (len < raw.len and raw[len] != 0) : (len += 1) {}
        return raw[0..len];
    }
};

const RowInfo = struct {
    title: []const u8,
};

fn writeDetail(out: []u8, value: []const u8) void {
    bytes.zero(out);
    const len = @min(value.len, out.len - 1);
    _ = bytes.copy(out[0..len], value[0..len]);
}

fn trimBuf(buf: *[detail_bytes]u8) []const u8 {
    var len: usize = 0;
    while (len < buf.len and buf[len] != 0) : (len += 1) {}
    return buf[0..len];
}

// ─── Sysfs readers ───────────────────────────────────────────

fn readSysfsStr(path: []const u8, buf: []u8) !usize {
    const cpath = toC(path);
    const rc = linux.openat(linux.AT.FDCWD, cpath.ptr, linux.O{}, 0);
    if (@as(isize, @bitCast(rc)) < 0) return error.ReadFailed;
    const fd = @as(i32, @intCast(rc));
    defer _ = linux.close(fd);
    const n = linux.read(fd, buf.ptr, buf.len);
    if (n < 0) return error.ReadFailed;
    return @intCast(n);
}

fn toC(s: []const u8) [:0]const u8 {
    return @as([:0]const u8, @ptrCast(s));
}

fn readFirstThermal(buf: *[detail_bytes]u8) !void {
    const idx_path = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp1_input";
    var tmp: [32]u8 = undefined;
    const tmp_n = readSysfsStr(idx_path, &tmp) catch return error.ReadFailed;
    if (tmp_n > 0) {
        const trimmed = std.mem.trimEnd(u8, tmp[0..tmp_n], &[_]u8{ '\n', ' ', '\r' });
        const raw = std.fmt.parseUnsigned(u32, trimmed, 10) catch return error.ParseFailed;
        const celsius = @as(f32, @floatFromInt(raw)) / 1000.0;
        writeBuf(buf, "CPU: {d:5.1} °C", .{celsius});
        return;
    }
    return error.ReadFailed;
}

fn readMem(buf: *[detail_bytes]u8) !void {
    var content: [2048]u8 = undefined;
    const n = try readSysfsStr("/proc/meminfo", &content);
    const text = content[0..n];
    var total_kb: u32 = 0;
    var avail_kb: u32 = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "MemTotal:")) {
            total_kb = parseIntAfterColon(line) catch 0;
        } else if (std.mem.startsWith(u8, line, "MemAvailable:")) {
            avail_kb = parseIntAfterColon(line) catch 0;
        }
    }
    if (total_kb == 0) return error.ParseFailed;
    writeBuf(buf, "Total: {d} MB, Avail: {d} MB", .{ total_kb / 1024, avail_kb / 1024 });
}

fn parseIntAfterColon(line: []const u8) !u32 {
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.ParseFailed;
    const after = std.mem.trim(u8, line[colon + 1 ..], &[_]u8{ ' ', '\t' });
    const space = std.mem.indexOfScalar(u8, after, ' ') orelse after.len;
    return std.fmt.parseUnsigned(u32, after[0..space], 10) catch error.ParseFailed;
}

fn readBattery(buf: *[detail_bytes]u8) !void {
    const bats = [_][]const u8{ "BAT0", "BAT1" };
    for (bats) |bat| {
        var path_buf: [64]u8 = undefined;
        const cap_path = std.fmt.bufPrint(&path_buf, "/sys/class/power_supply/{s}/capacity", .{bat}) catch continue;
        var cap_buf: [16]u8 = undefined;
        const cn = readSysfsStr(cap_path, &cap_buf) catch continue;
        const cap = std.mem.trimEnd(u8, cap_buf[0..cn], &[_]u8{ '\n', ' ', '\r' });
        var st_buf: [16]u8 = undefined;
        const st_path = std.fmt.bufPrint(&path_buf, "/sys/class/power_supply/{s}/status", .{bat}) catch continue;
        const sn = readSysfsStr(st_path, &st_buf) catch continue;
        const st = std.mem.trimEnd(u8, st_buf[0..sn], &[_]u8{ '\n', ' ', '\r' });
        writeBuf(buf, "{s}% ({s})", .{ cap, st });
        return;
    }
    return error.ReadFailed;
}

fn readKbdBacklight(buf: *[detail_bytes]u8) !void {
    var path_buf: [64]u8 = undefined;
    const bright_path = std.fmt.bufPrint(&path_buf, "/sys/class/leds/chromeos::kbd_backlight/brightness", .{}) catch return error.ReadFailed;
    var val_buf: [16]u8 = undefined;
    const vn = readSysfsStr(bright_path, &val_buf) catch return error.ReadFailed;
    const val = std.mem.trimEnd(u8, val_buf[0..vn], &[_]u8{ '\n', ' ', '\r' });
    var max_buf: [16]u8 = undefined;
    const max_path = std.fmt.bufPrint(&path_buf, "/sys/class/leds/chromeos::kbd_backlight/max_brightness", .{}) catch return error.ReadFailed;
    const mn = readSysfsStr(max_path, &max_buf) catch return error.ReadFailed;
    const max = std.mem.trimEnd(u8, max_buf[0..mn], &[_]u8{ '\n', ' ', '\r' });
    writeBuf(buf, "{s}/{s}%", .{ val, max });
}

fn readEcInfo(buf: *[detail_bytes]u8) !void {
    const vers = "/sys/devices/platform/FRMWC004:00/cros-ec-dev.1.auto/cros-ec-sysfs.10.auto/version";
    var ver_buf: [128]u8 = undefined;
    const n = readSysfsStr(vers, &ver_buf) catch {
        writeBuf(buf, "Chrome EC (LPC)", .{});
        return;
    };
    const ver = std.mem.trimEnd(u8, ver_buf[0..n], &[_]u8{ '\n', ' ', '\r' });
    writeBuf(buf, "Chrome EC {s}", .{ver});
}

fn readAmdgpu(buf: *[detail_bytes]u8) !void {
    const dev = "/sys/bus/pci/devices/0000:c1:00.0/device";
    var dev_buf: [16]u8 = undefined;
    const dn = readSysfsStr(dev, &dev_buf) catch return error.ReadFailed;
    const id = std.mem.trimEnd(u8, dev_buf[0..dn], &[_]u8{ '\n', ' ', '\r' });
    const rev_path = "/sys/bus/pci/devices/0000:c1:00.0/revision";
    var rev_buf: [16]u8 = undefined;
    const rn = readSysfsStr(rev_path, &rev_buf) catch return error.ReadFailed;
    const rev = std.mem.trimEnd(u8, rev_buf[0..rn], &[_]u8{ '\n', ' ', '\r' });
    writeBuf(buf, "Radeon 780M (0x{s} rev {s})", .{ id, rev });
}

fn readTpmInfo(buf: *[detail_bytes]u8) !void {
    const path = "/sys/class/tpm/tpm0/tpm_version_major";
    var ver_buf: [16]u8 = undefined;
    if (readSysfsStr(path, &ver_buf)) |n| {
        const ver = std.mem.trimEnd(u8, ver_buf[0..n], &[_]u8{ '\n', ' ', '\r' });
        writeBuf(buf, "TPM {s} (AMD fTPM)", .{ver});
    } else |_| {
        writeBuf(buf, "AMD fTPM (stuck, needs reboot)", .{});
    }
}

fn readPciCount(buf: *[detail_bytes]u8) !void {
    var content: [4096]u8 = undefined;
    const n = try readSysfsStr("/proc/bus/pci/devices", &content);
    const text = content[0..n];
    var count: u32 = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len > 0) count += 1;
    }
    writeBuf(buf, "{d} devices detected", .{count});
}

fn readNetwork(buf: *[detail_bytes]u8) !void {
    var content: [2048]u8 = undefined;
    const n = try readSysfsStr("/proc/net/dev", &content);
    const text = content[0..n];
    var up_count: u32 = 0;
    var total: u32 = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const ifname = std.mem.trim(u8, line[0..colon], &[_]u8{ ' ', '\t' });
        if (std.mem.eql(u8, ifname, "lo")) continue;
        total += 1;
        // Count non-loopback as "up" if it has nonzero bytes
        const parts = std.mem.trim(u8, line[colon + 1 ..], &[_]u8{ ' ', '\t' });
        const space = std.mem.indexOfScalar(u8, parts, ' ') orelse parts.len;
        const rx_bytes = std.fmt.parseUnsigned(u64, parts[0..space], 10) catch 0;
        if (rx_bytes > 0) up_count += 1;
    }
    writeBuf(buf, "{d}/{d} interfaces up", .{ up_count, total });
}

fn writeBuf(buf: *[detail_bytes]u8, comptime format: []const u8, args: anytype) void {
    bytes.zero(buf[0..]);
    _ = std.fmt.bufPrint(buf[0..], format, args) catch {};
}
