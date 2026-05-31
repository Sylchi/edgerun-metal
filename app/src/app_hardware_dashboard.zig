const std = @import("std");
const bytes = @import("bytes.zig");
const ui = @import("ui/core.zig");
const icon = @import("ui/icon.zig");
const component_union = @import("ui/components/Component.zig");
const IconComponent = @import("ui/components/Icon.zig");
const RenderOptions = @import("ui/component_common.zig").RenderOptions;
const interaction = @import("ui/interaction.zig");
const ui_runtime = @import("ui/runtime.zig");

const linux = std.os.linux;

pub const Error = error{
    ReadFailed,
    ParseFailed,
};

const row_count = 11;
const detail_bytes = 80;
const state_bytes = row_count * detail_bytes;
const unavailable_detail = "unavailable";

const RowDef = struct {
    icon_kind: icon.Icon,
    title: []const u8,
};

const rows = [_]RowDef{
    .{ .icon_kind = .device_desktop, .title = "Platform" },
    .{ .icon_kind = .temperature,    .title = "CPU Temp" },
    .{ .icon_kind = .database,       .title = "Memory" },
    .{ .icon_kind = .battery,        .title = "Battery" },
    .{ .icon_kind = .brightness,     .title = "Screen" },
    .{ .icon_kind = .keyboard,       .title = "Keyboard" },
    .{ .icon_kind = .server,         .title = "EC" },
    .{ .icon_kind = .cpu,            .title = "GPU" },
    .{ .icon_kind = .shield_check,   .title = "TPM" },
    .{ .icon_kind = .device_desktop, .title = "PCI Devices" },
    .{ .icon_kind = .network,        .title = "Network" },
};

const Component = component_union.Component;
const hardware_bg_top = ui.Color{ .r = 7, .g = 8, .b = 10 };
const hardware_bg_bottom = ui.Color{ .r = 14, .g = 15, .b = 17 };

fn hardwareStyle() ui.Style {
    return .{
        .bg = hardware_bg_top,
        .panel = .{ .r = 24, .g = 24, .b = 25 },
        .row = .{ .r = 33, .g = 33, .b = 35 },
        .border = .{ .r = 50, .g = 50, .b = 54 },
        .text = .{ .r = 239, .g = 239, .b = 241 },
        .muted = .{ .r = 151, .g = 151, .b = 157 },
        .accent = .{ .r = 13, .g = 191, .b = 141 },
    };
}

const BacklightKind = enum {
    screen,
    keyboard,
};

const BacklightDevice = struct {
    title: []const u8,
    current_path: []const u8,
    max_path: []const u8,
    min_value: i32,
    step_percent: i32,
    unavailable_status: []const u8,
    parse_status: []const u8,
    write_failed_status: []const u8,
    updated_status: []const u8,
};

const BacklightReading = struct {
    current: i32,
    max: i32,
};

const ResolvedBacklight = struct {
    device: BacklightDevice,
    reading: BacklightReading,
};

const screen_backlights = [_]BacklightDevice{
    .{
        .title = "Screen",
        .current_path = "/sys/class/backlight/amdgpu_bl2/brightness",
        .max_path = "/sys/class/backlight/amdgpu_bl2/max_brightness",
        .min_value = 1,
        .step_percent = 5,
        .unavailable_status = "Screen control unavailable",
        .parse_status = "Screen parse failed",
        .write_failed_status = "Screen brightness write failed",
        .updated_status = "Screen brightness updated",
    },
    .{
        .title = "Screen",
        .current_path = "/sys/class/backlight/intel_backlight/brightness",
        .max_path = "/sys/class/backlight/intel_backlight/max_brightness",
        .min_value = 1,
        .step_percent = 5,
        .unavailable_status = "Screen control unavailable",
        .parse_status = "Screen parse failed",
        .write_failed_status = "Screen brightness write failed",
        .updated_status = "Screen brightness updated",
    },
};

const keyboard_backlights = [_]BacklightDevice{
    .{
        .title = "Keyboard",
        .current_path = "/sys/class/leds/chromeos::kbd_backlight/brightness",
        .max_path = "/sys/class/leds/chromeos::kbd_backlight/max_brightness",
        .min_value = 0,
        .step_percent = 0,
        .unavailable_status = "Keyboard control unavailable",
        .parse_status = "Keyboard parse failed",
        .write_failed_status = "Keyboard backlight write failed",
        .updated_status = "Keyboard backlight updated",
    },
};

const ec_version_paths = [_][]const u8{
    "/sys/devices/platform/FRMWC004:00/cros-ec-dev.1.auto/cros-ec-sysfs.10.auto/version",
};

pub const State = struct {
    details: [state_bytes]u8 = [_]u8{0} ** state_bytes,
    frame: u64 = 0,
    last_refresh_frame: u64 = 0,
    auto_refresh: bool = true,
    hide_unavailable: bool = false,
    compact_rows: bool = false,
    status: [detail_bytes]u8 = [_]u8{0} ** detail_bytes,
    screen_brightness: i32 = 0,
    screen_brightness_max: i32 = 1,
    keyboard_brightness: i32 = 0,
    keyboard_brightness_max: i32 = 1,
    screen_brightness_ready: bool = false,
    keyboard_brightness_ready: bool = false,

    const refresh_now_button_id: u32 = 90_001;
    const auto_refresh_switch_id: u32 = 90_002;
    const hide_unavailable_switch_id: u32 = 90_003;
    const compact_rows_switch_id: u32 = 90_004;
    const brightness_down_button_id: u32 = 90_005;
    const brightness_up_button_id: u32 = 90_006;
    const kbd_down_button_id: u32 = 90_007;
    const kbd_up_button_id: u32 = 90_008;
    const brightness_slider_id: u32 = 90_009;
    const kbd_slider_id: u32 = 90_010;
    const refresh_interval_frames: u64 = 120;

    pub fn tick(self: *State) void {
        self.frame += 1;
        if (!self.auto_refresh) return;
        if (self.frame == 1 or self.frame - self.last_refresh_frame >= refresh_interval_frames) self.refresh();
    }

    pub fn activate(self: *State, hit: ?interaction.Region, drag: ?ui_runtime.DragValue) void {
        const hit_id = if (hit) |value| value.id else 0;
        switch (hit_id) {
            refresh_now_button_id => self.refresh(),
            auto_refresh_switch_id => self.auto_refresh = !self.auto_refresh,
            hide_unavailable_switch_id => self.hide_unavailable = !self.hide_unavailable,
            compact_rows_switch_id => self.compact_rows = !self.compact_rows,
            brightness_down_button_id => self.adjustBacklight(.screen, -1),
            brightness_up_button_id => self.adjustBacklight(.screen, 1),
            kbd_down_button_id => self.adjustBacklight(.keyboard, -1),
            kbd_up_button_id => self.adjustBacklight(.keyboard, 1),
            brightness_slider_id => if (hit) |region| self.setBacklightUnit(.screen, region, drag),
            kbd_slider_id => if (hit) |region| self.setBacklightUnit(.keyboard, region, drag),
            else => {},
        }
    }

    pub fn refresh(self: *State) void {
        self.last_refresh_frame = self.frame;
        var offset: usize = 0;

        var platform_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readPlatform(&platform_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&platform_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var cpu_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readFirstThermal(&cpu_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&cpu_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var mem_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readMem(&mem_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&mem_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var bat_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readBattery(&bat_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&bat_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var screen_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readBacklightRow(.screen, &screen_buf, self)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&screen_buf));
        } else |_| {
            self.screen_brightness_ready = false;
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var kbd_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readBacklightRow(.keyboard, &kbd_buf, self)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&kbd_buf));
        } else |_| {
            self.keyboard_brightness_ready = false;
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var ec_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readEcInfo(&ec_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&ec_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var gpu_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readGpu(&gpu_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&gpu_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var tpm_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readTpmInfo(&tpm_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&tpm_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var pci_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readPciCount(&pci_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&pci_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var net_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readNetwork(&net_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&net_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
    }

    pub fn render(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        var dashboard_options = options;
        dashboard_options.style = hardwareStyle();
        try scene.pushGradientRect(bounds, hardware_bg_top, hardware_bg_bottom, 0.0);

        const outer = bounds.insetUniform(if (bounds.w >= 1000.0) 20.0 else 12.0);
        if (outer.w >= 980.0) {
            try self.renderWide(scene, collector, outer, dashboard_options);
        } else {
            try self.renderStacked(scene, collector, outer, dashboard_options);
        }
    }

    fn detail(self: *const State, row: usize) []const u8 {
        if (row >= row_count) return "";
        const raw = self.details[row * detail_bytes ..][0..detail_bytes];
        var len: usize = 0;
        while (len < raw.len and raw[len] != 0) : (len += 1) {}
        return raw[0..len];
    }

    fn statusLabel(self: *const State) []const u8 {
        var len: usize = 0;
        while (len < self.status.len and self.status[len] != 0) : (len += 1) {}
        return if (len == 0) "Ready" else self.status[0..len];
    }

    fn renderWide(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const gap: f32 = if (self.compact_rows) 10.0 else 14.0;
        try self.renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, 74.0), options);

        const metric_y = bounds.y + 74.0 + gap;
        const metric_w = (bounds.w - gap * 3.0) * 0.25;
        try self.renderMetrics(scene, collector, ui.Rect.init(bounds.x, metric_y, bounds.w, 104.0), metric_w, gap, options);

        const body_y = metric_y + 104.0 + gap;
        const body_h = @max(1.0, bounds.y + bounds.h - body_y);
        const side_w = @min(360.0, @max(304.0, bounds.w * 0.28));
        const center_w = bounds.w - side_w * 2.0 - gap * 2.0;
        try self.renderControls(scene, collector, ui.Rect.init(bounds.x, body_y, side_w, body_h), options);
        try self.renderActivity(scene, collector, ui.Rect.init(bounds.x + side_w + gap, body_y, center_w, body_h), options);
        try self.renderInventory(scene, collector, ui.Rect.init(bounds.x + side_w + gap + center_w + gap, body_y, side_w, body_h), options);
    }

    fn renderStacked(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const gap: f32 = 12.0;
        var y = bounds.y;
        try self.renderHeader(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 74.0), options);
        y += 74.0 + gap;
        const metric_w = (bounds.w - gap) * 0.5;
        try self.renderMetrics(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 220.0), metric_w, gap, options);
        y += 220.0 + gap;
        try self.renderControls(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 320.0), options);
        y += 320.0 + gap;
        try self.renderActivity(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 240.0), options);
        y += 240.0 + gap;
        try self.renderInventory(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, @max(260.0, bounds.y + bounds.h - y)), options);
    }

    fn renderHeader(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const title_w = @max(260.0, bounds.w - 222.0);
        try (Component{ .card = .{ .title = "Hardware", .detail = self.detail(0), .variant = .elevated } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, bounds.y, title_w, bounds.h), options);
        try (Component{ .badge = .{ .label = self.statusLabel(), .variant = .secondary } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x + bounds.w - 210.0, bounds.y + 19.0, 152.0, 28.0), options);
        try (Component{ .icon_button = .{
            .id = refresh_now_button_id,
            .label = "Refresh",
            .icon = IconComponent.Icon.named(.reload),
            .variant = .outline,
        } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x + bounds.w - 44.0, bounds.y + 15.0, 40.0, 40.0), options);
    }

    fn renderMetrics(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, metric_w: f32, gap: f32, options: RenderOptions) !void {
        const cards_per_row: usize = if (bounds.w >= 980.0) 4 else 2;
        const row_h = if (cards_per_row == 4) bounds.h else (bounds.h - gap) * 0.5;
        const data = [_]struct { title: []const u8, detail: []const u8 }{
            .{ .title = "CPU Temp", .detail = self.detail(1) },
            .{ .title = "Memory", .detail = self.detail(2) },
            .{ .title = "Screen", .detail = self.detail(4) },
            .{ .title = "Keyboard", .detail = self.detail(5) },
        };
        for (data, 0..) |entry, index| {
            const col = index % cards_per_row;
            const row = index / cards_per_row;
            const rect = ui.Rect.init(
                bounds.x + @as(f32, @floatFromInt(col)) * (metric_w + gap),
                bounds.y + @as(f32, @floatFromInt(row)) * (row_h + gap),
                metric_w,
                row_h,
            );
            try (Component{ .card = .{ .title = entry.title, .detail = entry.detail, .variant = .panel } }).renderInteractive(scene, collector, rect, options);
        }
    }

    fn renderControls(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        var y = bounds.y;
        try (Component{ .card = .{ .title = "Controls", .detail = "Display and keyboard hardware knobs.", .variant = .elevated } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 78.0), options);
        y += 92.0;

        try (Component{ .slider = .{ .id = brightness_slider_id, .label = "Screen Brightness", .value = self.screenBrightnessUnit() } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 56.0), options);
        y += 66.0;
        const half_w = (bounds.w - 10.0) * 0.5;
        try (Component{ .button = .{ .id = brightness_down_button_id, .label = "Screen -", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .brightness_down) } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, half_w, 36.0), options);
        try (Component{ .button = .{ .id = brightness_up_button_id, .label = "Screen +", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .brightness_up) } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x + half_w + 10.0, y, half_w, 36.0), options);
        y += 50.0;

        try (Component{ .slider = .{ .id = kbd_slider_id, .label = "Keyboard Backlight", .value = self.keyboardBrightnessUnit() } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 56.0), options);
        y += 66.0;
        try (Component{ .button = .{ .id = kbd_down_button_id, .label = "Keys -", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .adjustments_minus) } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, half_w, 36.0), options);
        try (Component{ .button = .{ .id = kbd_up_button_id, .label = "Keys +", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .adjustments_plus) } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x + half_w + 10.0, y, half_w, 36.0), options);
        y += 54.0;

        try (Component{ .switch_control = .{ .id = auto_refresh_switch_id, .label = "Auto Refresh", .checked = self.auto_refresh } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 32.0), options);
        y += 40.0;
        try (Component{ .switch_control = .{ .id = hide_unavailable_switch_id, .label = "Hide Unavailable", .checked = self.hide_unavailable } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 32.0), options);
        y += 40.0;
        try (Component{ .switch_control = .{ .id = compact_rows_switch_id, .label = "Compact Density", .checked = self.compact_rows } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 32.0), options);
    }

    fn renderActivity(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        try (Component{ .chart = .{ .id = 90_020, .label = "System Activity" } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(190.0, bounds.h * 0.42)), options);
        const y = bounds.y + @min(204.0, bounds.h * 0.45);
        try (Component{ .card = .{ .title = "Screen Level", .detail = self.detail(4), .variant = .panel } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 78.0), options);
        try (Component{ .progress = .{ .value = self.screenBrightnessUnit() } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y + 88.0, bounds.w, 18.0), options);
        try (Component{ .card = .{ .title = "Keyboard Level", .detail = self.detail(5), .variant = .panel } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y + 124.0, bounds.w, 78.0), options);
        try (Component{ .progress = .{ .value = self.keyboardBrightnessUnit() } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y + 212.0, bounds.w, 18.0), options);
    }

    fn renderInventory(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        var y = bounds.y;
        try (Component{ .card = .{ .title = "Inventory", .detail = "Detected hardware paths and runtime capabilities.", .variant = .elevated } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 78.0), options);
        y += 92.0;
        const row_h: f32 = if (self.compact_rows) 44.0 else 52.0;
        for (&rows, 0..) |row, index| {
            const row_detail = self.detail(index);
            if (self.hide_unavailable and std.mem.eql(u8, row_detail, unavailable_detail)) continue;
            if (y + row_h > bounds.y + bounds.h) break;
            try (Component{ .row_item = .{
                .id = @intCast(index),
                .title = row.title,
                .detail = row_detail,
                .leading_icon = IconComponent.IconSlot.named(.leading, row.icon_kind),
            } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, row_h), options);
            y += row_h + 8.0;
        }
    }

    fn adjustBacklight(self: *State, kind: BacklightKind, direction: i32) void {
        const resolved = readResolvedBacklight(kind) catch |err| return self.setStatus(backlightReadStatusForKind(kind, err));
        self.writeBacklight(kind, resolved.device, steppedBacklightValue(resolved.device, resolved.reading, direction));
    }

    fn setStatus(self: *State, value: []const u8) void {
        writeDetail(&self.status, value);
    }

    fn setBacklightUnit(self: *State, kind: BacklightKind, region: interaction.Region, drag: ?ui_runtime.DragValue) void {
        const unit = unitFromDrag(region, drag) orelse return;
        const resolved = readResolvedBacklight(kind) catch |err| return self.setStatus(backlightReadStatusForKind(kind, err));
        self.writeBacklight(kind, resolved.device, unitBacklightValue(resolved.device, resolved.reading, unit));
    }

    fn writeBacklight(self: *State, kind: BacklightKind, device: BacklightDevice, value: i32) void {
        writeBacklightValue(device, value) catch return self.setStatus(device.write_failed_status);
        self.setStatus(device.updated_status);
        switch (kind) {
            .screen => self.screen_brightness = value,
            .keyboard => self.keyboard_brightness = value,
        }
        if (readBacklight(device)) |reading| {
            self.updateBacklightState(kind, reading);
            self.refresh();
        } else |_| {}
    }

    fn updateBacklightState(self: *State, kind: BacklightKind, reading: BacklightReading) void {
        switch (kind) {
            .screen => {
                self.screen_brightness = reading.current;
                self.screen_brightness_max = reading.max;
                self.screen_brightness_ready = true;
            },
            .keyboard => {
                self.keyboard_brightness = reading.current;
                self.keyboard_brightness_max = reading.max;
                self.keyboard_brightness_ready = true;
            },
        }
    }

    fn screenBrightnessUnit(self: *const State) f32 {
        if (!self.screen_brightness_ready or self.screen_brightness_max <= 0) return 0.0;
        return ui.clampUnit(@as(f32, @floatFromInt(self.screen_brightness)) / @as(f32, @floatFromInt(self.screen_brightness_max)));
    }

    fn keyboardBrightnessUnit(self: *const State) f32 {
        if (!self.keyboard_brightness_ready or self.keyboard_brightness_max <= 0) return 0.0;
        return ui.clampUnit(@as(f32, @floatFromInt(self.keyboard_brightness)) / @as(f32, @floatFromInt(self.keyboard_brightness_max)));
    }

};

fn renderComponent(scene: *ui.Scene, collector: *interaction.Collector, component: Component, bounds: ui.Rect, options: RenderOptions) !void {
    try component.renderInteractive(scene, collector, bounds, options);
}

fn writeDetail(out: []u8, value: []const u8) void {
    bytes.zero(out);
    const len = @min(value.len, out.len - 1);
    _ = bytes.copy(out[0..len], value[0..len]);
}

fn writeUnavailable(out: []u8) void {
    writeDetail(out, unavailable_detail);
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

fn readPlatform(buf: *[detail_bytes]u8) !void {
    var name_buf: [64]u8 = undefined;
    const name_n = readSysfsStr("/sys/devices/virtual/dmi/id/product_name", &name_buf) catch return error.ReadFailed;
    const name = std.mem.trimEnd(u8, name_buf[0..name_n], &[_]u8{ '\n', ' ', '\r' });
    if (name.len == 0) return error.ParseFailed;

    var version_buf: [64]u8 = undefined;
    if (readSysfsStr("/sys/devices/virtual/dmi/id/product_version", &version_buf)) |version_n| {
        const version = std.mem.trimEnd(u8, version_buf[0..version_n], &[_]u8{ '\n', ' ', '\r' });
        if (version.len != 0 and !std.mem.eql(u8, version, "None")) {
            writeBuf(buf, "{s} {s}", .{ name, version });
            return;
        }
    } else |_| {}
    writeBuf(buf, "{s}", .{name});
}

fn readFirstThermal(buf: *[detail_bytes]u8) !void {
    const thermal_paths = [_][]const u8{
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
        "/sys/class/hwmon/hwmon1/temp1_input",
        "/sys/class/hwmon/hwmon2/temp1_input",
        "/sys/class/hwmon/hwmon3/temp1_input",
        "/sys/class/hwmon/hwmon4/temp1_input",
        "/sys/class/hwmon/hwmon5/temp1_input",
        "/sys/class/hwmon/hwmon6/temp1_input",
        "/sys/devices/platform/coretemp.0/hwmon/hwmon6/temp1_input",
    };
    var tmp: [32]u8 = undefined;
    for (thermal_paths) |idx_path| {
        const tmp_n = readSysfsStr(idx_path, &tmp) catch continue;
        if (tmp_n == 0) continue;
        const trimmed = std.mem.trimEnd(u8, tmp[0..tmp_n], &[_]u8{ '\n', ' ', '\r' });
        const raw = std.fmt.parseUnsigned(u32, trimmed, 10) catch continue;
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

fn readBacklightRow(kind: BacklightKind, buf: *[detail_bytes]u8, state: *State) !void {
    const resolved = try readResolvedBacklight(kind);
    state.updateBacklightState(kind, resolved.reading);
    writeBuf(buf, "{d}/{d}", .{ resolved.reading.current, resolved.reading.max });
}

fn readResolvedBacklight(kind: BacklightKind) !ResolvedBacklight {
    for (backlightDevices(kind)) |device| {
        const reading = readBacklight(device) catch continue;
        return .{ .device = device, .reading = reading };
    }
    return error.ReadFailed;
}

fn readBacklight(device: BacklightDevice) !BacklightReading {
    var cur_buf: [16]u8 = undefined;
    var max_buf: [16]u8 = undefined;
    const cur_n = readSysfsStr(device.current_path, &cur_buf) catch return error.ReadFailed;
    const max_n = readSysfsStr(device.max_path, &max_buf) catch return error.ReadFailed;
    const cur_text = std.mem.trimEnd(u8, cur_buf[0..cur_n], &[_]u8{ '\n', '\r', ' ' });
    const max_text = std.mem.trimEnd(u8, max_buf[0..max_n], &[_]u8{ '\n', '\r', ' ' });
    const cur_v = std.fmt.parseInt(i32, cur_text, 10) catch return error.ParseFailed;
    const max_v = std.fmt.parseInt(i32, max_text, 10) catch return error.ParseFailed;
    return .{
        .current = cur_v,
        .max = @max(1, max_v),
    };
}

fn writeBacklightValue(device: BacklightDevice, value: i32) !void {
    if (!writeSysfsInt(device.current_path, value)) return error.WriteFailed;
}

fn backlightDevices(kind: BacklightKind) []const BacklightDevice {
    return switch (kind) {
        .screen => &screen_backlights,
        .keyboard => &keyboard_backlights,
    };
}

fn firstBacklightDevice(kind: BacklightKind) BacklightDevice {
    return backlightDevices(kind)[0];
}

fn backlightReadStatus(device: BacklightDevice, err: anyerror) []const u8 {
    _ = device.title;
    return switch (err) {
        error.ReadFailed => device.unavailable_status,
        error.ParseFailed => device.parse_status,
        else => device.unavailable_status,
    };
}

fn backlightReadStatusForKind(kind: BacklightKind, err: anyerror) []const u8 {
    return backlightReadStatus(firstBacklightDevice(kind), err);
}

fn steppedBacklightValue(device: BacklightDevice, reading: BacklightReading, direction: i32) i32 {
    const raw_step = if (device.step_percent == 0) 1 else @divTrunc(reading.max * device.step_percent, 100);
    const step = @max(1, raw_step);
    return std.math.clamp(reading.current + step * direction, device.min_value, reading.max);
}

fn unitBacklightValue(device: BacklightDevice, reading: BacklightReading, unit: f32) i32 {
    const next = @as(i32, @intFromFloat(ui.clampUnit(unit) * @as(f32, @floatFromInt(reading.max))));
    return std.math.clamp(next, device.min_value, reading.max);
}

fn readEcInfo(buf: *[detail_bytes]u8) !void {
    var ver_buf: [128]u8 = undefined;
    for (ec_version_paths) |path| {
        const n = readSysfsStr(path, &ver_buf) catch continue;
        const ver = std.mem.trimEnd(u8, ver_buf[0..n], &[_]u8{ '\n', ' ', '\r' });
        if (ver.len == 0) continue;
        writeBuf(buf, "EC {s}", .{ver});
        return;
    }
    return error.ReadFailed;
}

fn readGpu(buf: *[detail_bytes]u8) !void {
    const dev = "/sys/class/drm/card0/device/device";
    var dev_buf: [16]u8 = undefined;
    const dn = readSysfsStr(dev, &dev_buf) catch return error.ReadFailed;
    const id = std.mem.trimEnd(u8, dev_buf[0..dn], &[_]u8{ '\n', ' ', '\r' });
    const rev_path = "/sys/class/drm/card0/device/revision";
    var rev_buf: [16]u8 = undefined;
    const rn = readSysfsStr(rev_path, &rev_buf) catch return error.ReadFailed;
    const rev = std.mem.trimEnd(u8, rev_buf[0..rn], &[_]u8{ '\n', ' ', '\r' });
    writeBuf(buf, "device {s} rev {s}", .{ id, rev });
}

fn readTpmInfo(buf: *[detail_bytes]u8) !void {
    const path = "/sys/class/tpm/tpm0/tpm_version_major";
    var ver_buf: [16]u8 = undefined;
    const n = readSysfsStr(path, &ver_buf) catch return error.ReadFailed;
    const ver = std.mem.trimEnd(u8, ver_buf[0..n], &[_]u8{ '\n', ' ', '\r' });
    if (ver.len == 0) return error.ParseFailed;
    writeBuf(buf, "TPM {s}", .{ver});
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

fn unitFromDrag(region: interaction.Region, drag: ?ui_runtime.DragValue) ?f32 {
    const value = drag orelse return null;
    if (value.id != region.id) return null;
    if (region.bounds.w <= 0.0) return null;
    return ui.clampUnit((value.pointer_x - region.bounds.x) / region.bounds.w);
}

test "backlight step controls clamp deterministically" {
    const reading = BacklightReading{ .current = 5, .max = 10 };
    try std.testing.expectEqual(@as(i32, 4), steppedBacklightValue(firstBacklightDevice(.keyboard), reading, -1));
    try std.testing.expectEqual(@as(i32, 6), steppedBacklightValue(firstBacklightDevice(.keyboard), reading, 1));
    try std.testing.expectEqual(@as(i32, 1), steppedBacklightValue(firstBacklightDevice(.screen), .{ .current = 1, .max = 10 }, -1));
    try std.testing.expectEqual(@as(i32, 10), steppedBacklightValue(firstBacklightDevice(.screen), .{ .current = 10, .max = 10 }, 1));
}

test "backlight slider values clamp to device range" {
    const reading = BacklightReading{ .current = 5, .max = 10 };
    try std.testing.expectEqual(@as(i32, 1), unitBacklightValue(firstBacklightDevice(.screen), reading, -1.0));
    try std.testing.expectEqual(@as(i32, 5), unitBacklightValue(firstBacklightDevice(.screen), reading, 0.5));
    try std.testing.expectEqual(@as(i32, 10), unitBacklightValue(firstBacklightDevice(.screen), reading, 2.0));
    try std.testing.expectEqual(@as(i32, 0), unitBacklightValue(firstBacklightDevice(.keyboard), reading, -1.0));
}
