const std = @import("std");
const bytes = @import("bytes.zig");
const ui = @import("ui.zig");
const icon = @import("icon.zig");
const component_union = @import("ui/components/Component.zig");
const RowItem = @import("ui/components/RowItem.zig").RowItem;
const Stack = @import("ui/components/Stack.zig").Stack;
const IconComponent = @import("ui/components/Icon.zig");
const RenderOptions = @import("ui_component_common.zig").RenderOptions;

const linux = std.os.linux;

pub const Error = error{
    ReadFailed,
    ParseFailed,
};

const row_count = 10;
const detail_bytes = 80;
const state_bytes = row_count * detail_bytes;

const RowDef = struct {
    icon_kind: icon.Icon,
    title: []const u8,
};

const rows = [_]RowDef{
    .{ .icon_kind = .device_desktop, .title = "Platform" },
    .{ .icon_kind = .temperature,    .title = "CPU Temp" },
    .{ .icon_kind = .database,       .title = "Memory" },
    .{ .icon_kind = .battery,        .title = "Battery" },
    .{ .icon_kind = .keyboard,       .title = "Keyboard" },
    .{ .icon_kind = .server,         .title = "EC" },
    .{ .icon_kind = .cpu,            .title = "AMDGPU" },
    .{ .icon_kind = .shield_check,   .title = "TPM" },
    .{ .icon_kind = .device_desktop, .title = "PCI Devices" },
    .{ .icon_kind = .network,        .title = "Network" },
};

const Component = component_union.Component;

pub const State = struct {
    details: [state_bytes]u8 = [_]u8{0} ** state_bytes,

    pub fn refresh(self: *State) void {
        var offset: usize = 0;

        writeDetail(self.details[offset..][0..detail_bytes], "System: Framework 13 AMD 7840U");
        offset += detail_bytes;

        var cpu_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readFirstThermal(&cpu_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&cpu_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var mem_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readMem(&mem_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&mem_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var bat_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readBattery(&bat_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&bat_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var kbd_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readKbdBacklight(&kbd_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&kbd_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var ec_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readEcInfo(&ec_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&ec_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var gpu_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readAmdgpu(&gpu_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&gpu_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var tpm_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readTpmInfo(&tpm_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&tpm_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var pci_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readPciCount(&pci_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&pci_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var net_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readNetwork(&net_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&net_buf));
        } else |_| {
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
    }

    pub fn render(self: *State, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) !void {
        var children: [1 + row_count]Component = undefined;
        children[0] = .{ .text = .{ .value = "Hardware Overview" } };
        for (&rows, 0..) |row, i| {
            children[i + 1] = .{ .row_item = .{
                .id = @intCast(i),
                .title = row.title,
                .detail = self.detail(i),
                .leading_icon = IconComponent.IconSlot.named(.leading, row.icon_kind),
            } };
        }
        const stack = Stack(Component){
            .axis = .column,
            .gap = 4,
            .padding = 8,
            .children = &children,
        };
        try stack.render(scene, bounds, options);
    }

    fn detail(self: *State, row: usize) []const u8 {
        if (row >= row_count) return "";
        const raw = self.details[row * detail_bytes ..][0..detail_bytes];
        var len: usize = 0;
        while (len < raw.len and raw[len] != 0) : (len += 1) {}
        return raw[0..len];
    }
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

fn readSysfsStr(path: []const u8, buf: []u8) !usize {
    var path_buf: [256]u8 = [_]u8{0} ** 256;
    if (path.len >= path_buf.len) return error.ReadFailed;
    @memcpy(path_buf[0..path.len], path);
    const rc = linux.openat(linux.AT.FDCWD, @ptrCast(&path_buf), linux.O{}, 0);
    if (@as(isize, @bitCast(rc)) < 0) return error.ReadFailed;
    const fd = @as(i32, @intCast(rc));
    defer _ = linux.close(fd);
    const n = linux.read(fd, buf.ptr, buf.len);
    if (n < 0) return error.ReadFailed;
    return @intCast(n);
}

fn readFirstThermal(buf: *[detail_bytes]u8) !void {
    const idx_path = "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp1_input";
    var tmp: [32]u8 = undefined;
    const tmp_n = readSysfsStr(idx_path, &tmp) catch return error.ReadFailed;
    if (tmp_n > 0) {
        const trimmed = std.mem.trimEnd(u8, tmp[0..tmp_n], &[_]u8{ '\n', ' ', '\r' });
        const raw = std.fmt.parseUnsigned(u32, trimmed, 10) catch return error.ParseFailed;
        const celsius = @as(f32, @floatFromInt(raw)) / 1000.0;
        writeBuf(buf, "{d:5.1} °C", .{celsius});
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
