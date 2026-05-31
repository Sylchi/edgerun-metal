const std = @import("std");
const bytes = @import("bytes.zig");
const ui = @import("ui/core.zig");
const icon = @import("ui/icon.zig");
const component_union = @import("ui/components/Component.zig");
const IconComponent = @import("ui/components/Icon.zig");
const RenderOptions = @import("ui/component_common.zig").RenderOptions;
const interaction = @import("ui/interaction.zig");
const layout = @import("ui/layouts/Types.zig");
const layout_masonry = @import("ui/layouts/Masonry.zig");

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
    frame: u64 = 0,
    last_refresh_frame: u64 = 0,
    auto_refresh: bool = true,
    hide_unavailable: bool = false,
    compact_rows: bool = false,
    status: [detail_bytes]u8 = [_]u8{0} ** detail_bytes,

    const refresh_now_button_id: u32 = 90_001;
    const auto_refresh_toggle_id: u32 = 90_002;
    const hide_unavailable_toggle_id: u32 = 90_003;
    const compact_rows_toggle_id: u32 = 90_004;
    const brightness_down_button_id: u32 = 90_005;
    const brightness_up_button_id: u32 = 90_006;
    const kbd_down_button_id: u32 = 90_007;
    const kbd_up_button_id: u32 = 90_008;
    const refresh_interval_frames: u64 = 120;
    const max_components: usize = 11 + row_count;

    pub fn tick(self: *State) void {
        self.frame += 1;
        if (!self.auto_refresh) return;
        if (self.frame == 1 or self.frame - self.last_refresh_frame >= refresh_interval_frames) self.refresh();
    }

    pub fn activate(self: *State, hit_id: u32) void {
        switch (hit_id) {
            refresh_now_button_id => self.refresh(),
            auto_refresh_toggle_id => self.auto_refresh = !self.auto_refresh,
            hide_unavailable_toggle_id => self.hide_unavailable = !self.hide_unavailable,
            compact_rows_toggle_id => self.compact_rows = !self.compact_rows,
            brightness_down_button_id => self.adjustBacklight(-5),
            brightness_up_button_id => self.adjustBacklight(5),
            kbd_down_button_id => self.adjustKbdBacklight(-1),
            kbd_up_button_id => self.adjustKbdBacklight(1),
            else => {},
        }
    }

    pub fn refresh(self: *State) void {
        self.last_refresh_frame = self.frame;
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

    pub fn render(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        var children: [max_components]Component = undefined;
        var count: usize = 0;

        children[count] = .{ .card = .{
            .title = "Hardware Inventory Demo",
            .detail = self.summaryDetail(),
            .variant = .elevated,
        } };
        count += 1;
        children[count] = .{ .card = .{
            .title = "Controls",
            .detail = "Brightness, keyboard backlight, refresh and filters",
            .variant = .panel,
        } };
        count += 1;
        children[count] = .{ .button = .{
            .id = refresh_now_button_id,
            .label = "Refresh Now",
            .variant = .secondary,
        } };
        count += 1;
        children[count] = .{ .toggle = .{
            .id = auto_refresh_toggle_id,
            .label = "Auto Refresh",
            .pressed = self.auto_refresh,
        } };
        count += 1;
        children[count] = .{ .toggle = .{
            .id = hide_unavailable_toggle_id,
            .label = "Hide Unavailable Rows",
            .pressed = self.hide_unavailable,
        } };
        count += 1;
        children[count] = .{ .toggle = .{
            .id = compact_rows_toggle_id,
            .label = "Compact Rows",
            .pressed = self.compact_rows,
        } };
        count += 1;
        children[count] = .{ .button = .{
            .id = brightness_down_button_id,
            .label = "Screen -",
            .variant = .outline,
        } };
        count += 1;
        children[count] = .{ .button = .{
            .id = brightness_up_button_id,
            .label = "Screen +",
            .variant = .outline,
        } };
        count += 1;
        children[count] = .{ .button = .{
            .id = kbd_down_button_id,
            .label = "Keyboard -",
            .variant = .outline,
        } };
        count += 1;
        children[count] = .{ .button = .{
            .id = kbd_up_button_id,
            .label = "Keyboard +",
            .variant = .outline,
        } };
        count += 1;
        children[count] = .{ .badge = .{
            .label = self.statusLabel(),
            .variant = .secondary,
        } };
        count += 1;

        for (&rows, 0..) |row, i| {
            const row_detail = self.detail(i);
            if (self.hide_unavailable and std.mem.eql(u8, row_detail, "N/A")) continue;
            children[count] = .{ .row_item = .{
                .id = @intCast(i),
                .title = row.title,
                .detail = row_detail,
                .leading_icon = IconComponent.IconSlot.named(.leading, row.icon_kind),
            } };
            count += 1;
        }
        try self.renderMasonry(scene, collector, bounds, options, children[0..count]);
    }

    fn detail(self: *State, row: usize) []const u8 {
        if (row >= row_count) return "";
        const raw = self.details[row * detail_bytes ..][0..detail_bytes];
        var len: usize = 0;
        while (len < raw.len and raw[len] != 0) : (len += 1) {}
        return raw[0..len];
    }

    fn summaryDetail(self: *const State) []const u8 {
        return if (self.auto_refresh) "Live mode: updates every ~30 frames" else "Manual mode: press Refresh Now";
    }

    fn statusLabel(self: *const State) []const u8 {
        var len: usize = 0;
        while (len < self.status.len and self.status[len] != 0) : (len += 1) {}
        return if (len == 0) "Ready" else self.status[0..len];
    }

    fn renderMasonry(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions, children: []const Component) !void {
        var measurements: [max_components]layout.Measurement = undefined;
        var rects: [max_components]ui.Rect = undefined;
        const columns: usize = if (bounds.w >= 1400) 4 else if (bounds.w >= 1000) 3 else if (bounds.w >= 680) 2 else 1;
        const gap: f32 = if (self.compact_rows) 6 else 12;
        var index: usize = 0;
        while (index < children.len) : (index += 1) {
            measurements[index] = children[index].measure(.{
                .width = .{ .at_most = bounds.w },
                .height = .unconstrained,
                .text_wrap = .wrap,
            }, options);
        }
        const placed = layout_masonry.place(bounds, measurements[0..children.len], .{
            .columns = columns,
            .gap = gap,
            .padding = .{ .left = 12, .top = 12, .right = 12, .bottom = 12 },
        }, &rects);
        for (children, placed) |component, rect| {
            try component.render(scene, rect, options);
            try component.collectInteractions(collector, rect, options);
        }
    }

    fn adjustBacklight(self: *State, delta_percent: i32) void {
        var max_buf: [16]u8 = undefined;
        var cur_buf: [16]u8 = undefined;
        const max_n = readSysfsStr("/sys/class/backlight/amdgpu_bl2/max_brightness", &max_buf) catch return self.setStatus("Screen control unavailable");
        const cur_n = readSysfsStr("/sys/class/backlight/amdgpu_bl2/brightness", &cur_buf) catch return self.setStatus("Screen control unavailable");
        const max_v = std.fmt.parseInt(i32, std.mem.trimEnd(u8, max_buf[0..max_n], &[_]u8{ '\n', '\r', ' ' }), 10) catch return self.setStatus("Screen parse failed");
        const cur_v = std.fmt.parseInt(i32, std.mem.trimEnd(u8, cur_buf[0..cur_n], &[_]u8{ '\n', '\r', ' ' }), 10) catch return self.setStatus("Screen parse failed");
        const delta = @divTrunc(max_v * delta_percent, 100);
        const next = std.math.clamp(cur_v + delta, 1, max_v);
        if (writeSysfsInt("/sys/class/backlight/amdgpu_bl2/brightness", next)) {
            self.setStatus("Screen brightness updated");
            self.refresh();
        } else self.setStatus("Screen brightness write failed");
    }

    fn adjustKbdBacklight(self: *State, delta: i32) void {
        var max_buf: [16]u8 = undefined;
        var cur_buf: [16]u8 = undefined;
        const max_n = readSysfsStr("/sys/class/leds/chromeos::kbd_backlight/max_brightness", &max_buf) catch return self.setStatus("Keyboard control unavailable");
        const cur_n = readSysfsStr("/sys/class/leds/chromeos::kbd_backlight/brightness", &cur_buf) catch return self.setStatus("Keyboard control unavailable");
        const max_v = std.fmt.parseInt(i32, std.mem.trimEnd(u8, max_buf[0..max_n], &[_]u8{ '\n', '\r', ' ' }), 10) catch return self.setStatus("Keyboard parse failed");
        const cur_v = std.fmt.parseInt(i32, std.mem.trimEnd(u8, cur_buf[0..cur_n], &[_]u8{ '\n', '\r', ' ' }), 10) catch return self.setStatus("Keyboard parse failed");
        const next = std.math.clamp(cur_v + delta, 0, max_v);
        if (writeSysfsInt("/sys/class/leds/chromeos::kbd_backlight/brightness", next)) {
            self.setStatus("Keyboard backlight updated");
            self.refresh();
        } else self.setStatus("Keyboard backlight write failed");
    }

    fn setStatus(self: *State, value: []const u8) void {
        writeDetail(&self.status, value);
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

fn writeSysfsInt(path: []const u8, value: i32) bool {
    var path_buf: [256]u8 = [_]u8{0} ** 256;
    if (path.len >= path_buf.len) return false;
    @memcpy(path_buf[0..path.len], path);
    const rc = linux.openat(linux.AT.FDCWD, @ptrCast(&path_buf), linux.O{ .ACCMODE = .WRONLY }, 0);
    if (@as(isize, @bitCast(rc)) < 0) return false;
    const fd = @as(i32, @intCast(rc));
    defer _ = linux.close(fd);
    var value_buf: [32]u8 = undefined;
    const raw = std.fmt.bufPrint(&value_buf, "{d}\n", .{value}) catch return false;
    const written = linux.write(fd, raw.ptr, raw.len);
    return written == raw.len;
}
