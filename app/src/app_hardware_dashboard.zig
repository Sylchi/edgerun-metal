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
    const control_component_count: usize = 12;

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
            brightness_down_button_id => self.adjustBacklight(-5),
            brightness_up_button_id => self.adjustBacklight(5),
            kbd_down_button_id => self.adjustKbdBacklight(-1),
            kbd_up_button_id => self.adjustKbdBacklight(1),
            brightness_slider_id => if (hit) |region| self.setBacklightUnit(region, drag),
            kbd_slider_id => if (hit) |region| self.setKbdBacklightUnit(region, drag),
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

        var screen_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readScreenBacklight(&screen_buf, self)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&screen_buf));
        } else |_| {
            self.screen_brightness_ready = false;
            writeDetail(self.details[offset..][0..detail_bytes], "N/A");
        }
        offset += detail_bytes;

        var kbd_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readKbdBacklight(&kbd_buf, self)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&kbd_buf));
        } else |_| {
            self.keyboard_brightness_ready = false;
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
        var dashboard_options = options;
        dashboard_options.style = hardware_style;
        const compact = self.compact_rows or bounds.w < 760.0;
        try scene.pushGradientRect(bounds, hardware_bg_top, hardware_bg_bottom, 0.0);

        const outer_pad: f32 = if (bounds.w >= 1100.0) 28.0 else 14.0;
        const gap: f32 = if (compact) 10.0 else 14.0;
        const content = bounds.inset(outer_pad, outer_pad);
        try self.renderHeader(scene, collector, content, dashboard_options);

        const body = ui.Rect.init(content.x, content.y + header_h + gap, content.w, @max(1.0, content.h - header_h - gap));
        if (body.w >= 980.0) {
            const metric_h: f32 = 122.0;
            const metric_w = (body.w - gap * 3.0) / 4.0;
            try self.renderMetricCards(scene, ui.Rect.init(body.x, body.y, body.w, metric_h), metric_w, gap);

            const main_y = body.y + metric_h + gap;
            const main_h = @max(1.0, body.h - metric_h - gap);
            const side_w = @max(300.0, @min(380.0, body.w * 0.28));
            const center_w = @max(320.0, body.w - side_w * 2.0 - gap * 2.0);
            try self.renderControlsPanel(scene, collector, ui.Rect.init(body.x, main_y, side_w, main_h), dashboard_options, compact);
            try self.renderTelemetryPanel(scene, ui.Rect.init(body.x + side_w + gap, main_y, center_w, main_h));
            try self.renderInventoryPanel(scene, collector, ui.Rect.init(body.x + side_w + gap + center_w + gap, main_y, side_w, main_h), dashboard_options, compact);
        } else {
            const card_w = (body.w - gap) * 0.5;
            var cursor_y = body.y;
            try self.renderMetricCards(scene, ui.Rect.init(body.x, cursor_y, body.w, 256.0), card_w, gap);
            cursor_y += 256.0 + gap;
            try self.renderControlsPanel(scene, collector, ui.Rect.init(body.x, cursor_y, body.w, 292.0), dashboard_options, compact);
            cursor_y += 292.0 + gap;
            try self.renderTelemetryPanel(scene, ui.Rect.init(body.x, cursor_y, body.w, 300.0));
            cursor_y += 300.0 + gap;
            try self.renderInventoryPanel(scene, collector, ui.Rect.init(body.x, cursor_y, body.w, @max(260.0, body.y + body.h - cursor_y)), dashboard_options, compact);
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

    fn renderHeader(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        try scene.pushStrongText(ui.Rect.init(bounds.x, bounds.y + 4.0, bounds.w, 26.0), "Hardware", hardware_text);
        try scene.pushText(ui.Rect.init(bounds.x, bounds.y + 34.0, bounds.w, 18.0), self.detail(0), hardware_muted);

        const refresh = Component{ .icon_button = .{
            .id = refresh_now_button_id,
            .label = "Refresh",
            .icon = IconComponent.Icon.named(.reload),
            .variant = .outline,
        } };
        const refresh_bounds = ui.Rect.init(bounds.x + bounds.w - 44.0, bounds.y + 8.0, 36.0, 36.0);
        try refresh.render(scene, refresh_bounds, options);
        try refresh.collectInteractions(collector, refresh_bounds, options);

        const badge = Component{ .badge = .{ .label = self.statusLabel(), .variant = .secondary } };
        const badge_w = @min(180.0, @max(76.0, @as(f32, @floatFromInt(self.statusLabel().len)) * 8.0 + 24.0));
        const badge_bounds = ui.Rect.init(refresh_bounds.x - badge_w - 10.0, bounds.y + 13.0, badge_w, 26.0);
        try badge.render(scene, badge_bounds, options);
    }

    fn renderMetricCards(self: *State, scene: *ui.Scene, bounds: ui.Rect, card_w: f32, gap: f32) !void {
        const cards_per_row: usize = if (bounds.w >= 980.0) 4 else 2;
        const row_h = if (cards_per_row == 4) bounds.h else (bounds.h - gap) * 0.5;
        for (0..4) |index| {
            const col = index % cards_per_row;
            const row = index / cards_per_row;
            const card = ui.Rect.init(
                bounds.x + @as(f32, @floatFromInt(col)) * (card_w + gap),
                bounds.y + @as(f32, @floatFromInt(row)) * (row_h + gap),
                card_w,
                row_h,
            );
            switch (index) {
                0 => try self.renderMetricCard(scene, card, .temperature, "CPU TEMP", self.detail(1), "thermal sensor", 0.58, hardware_warning),
                1 => try self.renderMetricCard(scene, card, .database, "MEMORY", self.detail(2), "available memory", 0.66, hardware_accent),
                2 => try self.renderMetricCard(scene, card, .brightness, "SCREEN", self.detail(4), "display backlight", self.screenBrightnessUnit(), hardware_info),
                3 => try self.renderMetricCard(scene, card, .keyboard, "KEYBOARD", self.detail(5), "key backlight", self.keyboardBrightnessUnit(), hardware_success),
                else => unreachable,
            }
        }
    }

    fn renderMetricCard(self: *State, scene: *ui.Scene, bounds: ui.Rect, icon_kind: icon.Icon, eyebrow: []const u8, value: []const u8, detail_text: []const u8, unit: f32, accent: ui.Color) !void {
        _ = self;
        try renderPanel(scene, bounds, true);
        const inner = bounds.insetUniform(16.0);
        const chip = ui.Rect.init(inner.x, inner.y, 34.0, 34.0);
        try scene.pushRect(chip, accent.withAlpha(42), .fill, 8.0, 0.0);
        try IconComponent.Icon.named(icon_kind).renderColor(scene, chip.insetUniform(8.0), accent);
        try scene.pushText(ui.Rect.init(inner.x + 46.0, inner.y + 1.0, inner.w - 46.0, 14.0), eyebrow, hardware_muted);
        try scene.pushStrongText(ui.Rect.init(inner.x + 46.0, inner.y + 24.0, inner.w - 46.0, 26.0), value, hardware_text);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + inner.h - 42.0, inner.w, 16.0), detail_text, hardware_muted);
        try renderMeter(scene, ui.Rect.init(inner.x, inner.y + inner.h - 16.0, inner.w, 6.0), unit, accent);
    }

    fn renderControlsPanel(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions, compact: bool) !void {
        try renderPanel(scene, bounds, false);
        const inner = bounds.insetUniform(18.0);
        try scene.pushStrongText(ui.Rect.init(inner.x, inner.y, inner.w, 20.0), "Controls", hardware_text);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 26.0, inner.w, 16.0), "Screen, keyboard and refresh behavior.", hardware_muted);

        var controls: [control_component_count]Component = undefined;
        controls[0] = .{ .slider = .{ .id = brightness_slider_id, .label = "Screen Brightness", .value = self.screenBrightnessUnit() } };
        controls[1] = .{ .slider = .{ .id = kbd_slider_id, .label = "Keyboard Backlight", .value = self.keyboardBrightnessUnit() } };
        controls[2] = .{ .switch_control = .{ .id = auto_refresh_switch_id, .label = "Auto Refresh", .checked = self.auto_refresh } };
        controls[3] = .{ .switch_control = .{ .id = hide_unavailable_switch_id, .label = "Hide Unavailable", .checked = self.hide_unavailable } };
        controls[4] = .{ .switch_control = .{ .id = compact_rows_switch_id, .label = "Compact Rows", .checked = self.compact_rows } };
        controls[5] = .{ .button = .{ .id = brightness_down_button_id, .label = "Screen -", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .brightness_down) } };
        controls[6] = .{ .button = .{ .id = brightness_up_button_id, .label = "Screen +", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .brightness_up) } };
        controls[7] = .{ .button = .{ .id = kbd_down_button_id, .label = "Keys -", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .adjustments_minus) } };
        controls[8] = .{ .button = .{ .id = kbd_up_button_id, .label = "Keys +", .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, .adjustments_plus) } };
        controls[9] = .{ .card = .{ .title = "Display", .detail = self.screenBrightnessDetail(), .variant = .subtle } };
        controls[10] = .{ .card = .{ .title = "Keyboard", .detail = self.keyboardBrightnessDetail(), .variant = .subtle } };
        controls[11] = .{ .badge = .{ .label = if (self.auto_refresh) "Live" else "Manual", .variant = .outline } };

        var y = inner.y + 54.0;
        const slider_h: f32 = if (compact) 48.0 else 54.0;
        try renderControl(scene, collector, controls[0], ui.Rect.init(inner.x, y, inner.w, slider_h), options);
        y += slider_h + 12.0;
        try renderControl(scene, collector, controls[1], ui.Rect.init(inner.x, y, inner.w, slider_h), options);
        y += slider_h + 14.0;
        for (2..5) |index| {
            try renderControl(scene, collector, controls[index], ui.Rect.init(inner.x, y, inner.w, 30.0), options);
            y += 38.0;
        }
        const button_w = (inner.w - 10.0) * 0.5;
        try renderControl(scene, collector, controls[5], ui.Rect.init(inner.x, y, button_w, 34.0), options);
        try renderControl(scene, collector, controls[6], ui.Rect.init(inner.x + button_w + 10.0, y, button_w, 34.0), options);
        y += 44.0;
        try renderControl(scene, collector, controls[7], ui.Rect.init(inner.x, y, button_w, 34.0), options);
        try renderControl(scene, collector, controls[8], ui.Rect.init(inner.x + button_w + 10.0, y, button_w, 34.0), options);
        if (!compact and bounds.h > 420.0) {
            y += 50.0;
            try renderControl(scene, collector, controls[9], ui.Rect.init(inner.x, y, button_w, 82.0), options);
            try renderControl(scene, collector, controls[10], ui.Rect.init(inner.x + button_w + 10.0, y, button_w, 82.0), options);
        }
    }

    fn renderTelemetryPanel(self: *State, scene: *ui.Scene, bounds: ui.Rect) !void {
        try renderPanel(scene, bounds, false);
        const inner = bounds.insetUniform(18.0);
        try scene.pushStrongText(ui.Rect.init(inner.x, inner.y, inner.w, 20.0), "System Loadout", hardware_text);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 26.0, inner.w, 16.0), self.detail(7), hardware_muted);
        try renderBars(scene, ui.Rect.init(inner.x, inner.y + 60.0, inner.w, @min(170.0, inner.h * 0.38)));

        const y = inner.y + @min(250.0, inner.h * 0.52);
        const tile_w = (inner.w - 12.0) * 0.5;
        try renderMiniTile(scene, ui.Rect.init(inner.x, y, tile_w, 86.0), "TPM", self.detail(8), .shield_check, hardware_success);
        try renderMiniTile(scene, ui.Rect.init(inner.x + tile_w + 12.0, y, tile_w, 86.0), "PCI", self.detail(9), .device_desktop, hardware_info);
        if (inner.h > 390.0) {
            try renderMiniTile(scene, ui.Rect.init(inner.x, y + 100.0, tile_w, 86.0), "Network", self.detail(10), .network, hardware_accent);
            try renderMiniTile(scene, ui.Rect.init(inner.x + tile_w + 12.0, y + 100.0, tile_w, 86.0), "EC", self.detail(6), .server, hardware_warning);
        }
    }

    fn renderInventoryPanel(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions, compact: bool) !void {
        try renderPanel(scene, bounds, false);
        const inner = bounds.insetUniform(18.0);
        try scene.pushStrongText(ui.Rect.init(inner.x, inner.y, inner.w, 20.0), "Inventory", hardware_text);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 26.0, inner.w, 16.0), "Detected hardware paths and capabilities.", hardware_muted);
        var y = inner.y + 54.0;
        const row_h: f32 = if (compact) 42.0 else 50.0;
        for (&rows, 0..) |row, i| {
            const row_detail = self.detail(i);
            if (self.hide_unavailable and std.mem.eql(u8, row_detail, "N/A")) continue;
            if (y + row_h > inner.y + inner.h) break;
            const component = Component{ .row_item = .{
                .id = @intCast(i),
                .title = row.title,
                .detail = row_detail,
                .leading_icon = IconComponent.IconSlot.named(.leading, row.icon_kind),
            } };
            try renderControl(scene, collector, component, ui.Rect.init(inner.x, y, inner.w, row_h), options);
            y += row_h + 6.0;
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

    fn setBacklightUnit(self: *State, region: interaction.Region, drag: ?ui_runtime.DragValue) void {
        const unit = unitFromDrag(region, drag) orelse return;
        var max_buf: [16]u8 = undefined;
        const max_n = readSysfsStr("/sys/class/backlight/amdgpu_bl2/max_brightness", &max_buf) catch return self.setStatus("Screen control unavailable");
        const max_v = std.fmt.parseInt(i32, std.mem.trimEnd(u8, max_buf[0..max_n], &[_]u8{ '\n', '\r', ' ' }), 10) catch return self.setStatus("Screen parse failed");
        const next = @as(i32, @intFromFloat(unit * @as(f32, @floatFromInt(max_v))));
        if (writeSysfsInt("/sys/class/backlight/amdgpu_bl2/brightness", std.math.clamp(next, 1, max_v))) {
            self.setStatus("Screen brightness updated");
            self.refresh();
        } else self.setStatus("Screen brightness write failed");
    }

    fn setKbdBacklightUnit(self: *State, region: interaction.Region, drag: ?ui_runtime.DragValue) void {
        const unit = unitFromDrag(region, drag) orelse return;
        var max_buf: [16]u8 = undefined;
        const max_n = readSysfsStr("/sys/class/leds/chromeos::kbd_backlight/max_brightness", &max_buf) catch return self.setStatus("Keyboard control unavailable");
        const max_v = std.fmt.parseInt(i32, std.mem.trimEnd(u8, max_buf[0..max_n], &[_]u8{ '\n', '\r', ' ' }), 10) catch return self.setStatus("Keyboard parse failed");
        const next = @as(i32, @intFromFloat(unit * @as(f32, @floatFromInt(max_v))));
        if (writeSysfsInt("/sys/class/leds/chromeos::kbd_backlight/brightness", std.math.clamp(next, 0, max_v))) {
            self.setStatus("Keyboard backlight updated");
            self.refresh();
        } else self.setStatus("Keyboard backlight write failed");
    }

    fn screenBrightnessUnit(self: *const State) f32 {
        if (!self.screen_brightness_ready or self.screen_brightness_max <= 0) return 0.0;
        return ui.clampUnit(@as(f32, @floatFromInt(self.screen_brightness)) / @as(f32, @floatFromInt(self.screen_brightness_max)));
    }

    fn keyboardBrightnessUnit(self: *const State) f32 {
        if (!self.keyboard_brightness_ready or self.keyboard_brightness_max <= 0) return 0.0;
        return ui.clampUnit(@as(f32, @floatFromInt(self.keyboard_brightness)) / @as(f32, @floatFromInt(self.keyboard_brightness_max)));
    }

    fn screenBrightnessDetail(self: *const State) []const u8 {
        return if (self.screen_brightness_ready) "Slider and step controls are active." else "Screen backlight controls unavailable.";
    }

    fn keyboardBrightnessDetail(self: *const State) []const u8 {
        return if (self.keyboard_brightness_ready) "Keyboard backlight controls are active." else "Keyboard backlight controls unavailable.";
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

fn readScreenBacklight(buf: *[detail_bytes]u8, state: *State) !void {
    var cur_buf: [16]u8 = undefined;
    var max_buf: [16]u8 = undefined;
    const cur_n = readSysfsStr("/sys/class/backlight/amdgpu_bl2/brightness", &cur_buf) catch return error.ReadFailed;
    const max_n = readSysfsStr("/sys/class/backlight/amdgpu_bl2/max_brightness", &max_buf) catch return error.ReadFailed;
    const cur_text = std.mem.trimEnd(u8, cur_buf[0..cur_n], &[_]u8{ '\n', '\r', ' ' });
    const max_text = std.mem.trimEnd(u8, max_buf[0..max_n], &[_]u8{ '\n', '\r', ' ' });
    const cur_v = std.fmt.parseInt(i32, cur_text, 10) catch return error.ParseFailed;
    const max_v = std.fmt.parseInt(i32, max_text, 10) catch return error.ParseFailed;
    state.screen_brightness = cur_v;
    state.screen_brightness_max = @max(1, max_v);
    state.screen_brightness_ready = true;
    writeBuf(buf, "{s}/{s}", .{ cur_text, max_text });
}

fn readKbdBacklight(buf: *[detail_bytes]u8, state: *State) !void {
    var path_buf: [64]u8 = undefined;
    const bright_path = std.fmt.bufPrint(&path_buf, "/sys/class/leds/chromeos::kbd_backlight/brightness", .{}) catch return error.ReadFailed;
    var val_buf: [16]u8 = undefined;
    const vn = readSysfsStr(bright_path, &val_buf) catch return error.ReadFailed;
    const val = std.mem.trimEnd(u8, val_buf[0..vn], &[_]u8{ '\n', ' ', '\r' });
    var max_buf: [16]u8 = undefined;
    const max_path = std.fmt.bufPrint(&path_buf, "/sys/class/leds/chromeos::kbd_backlight/max_brightness", .{}) catch return error.ReadFailed;
    const mn = readSysfsStr(max_path, &max_buf) catch return error.ReadFailed;
    const max = std.mem.trimEnd(u8, max_buf[0..mn], &[_]u8{ '\n', ' ', '\r' });
    const cur_v = std.fmt.parseInt(i32, val, 10) catch return error.ParseFailed;
    const max_v = std.fmt.parseInt(i32, max, 10) catch return error.ParseFailed;
    state.keyboard_brightness = cur_v;
    state.keyboard_brightness_max = @max(1, max_v);
    state.keyboard_brightness_ready = true;
    writeBuf(buf, "{s}/{s}", .{ val, max });
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

fn unitFromDrag(region: interaction.Region, drag: ?ui_runtime.DragValue) ?f32 {
    const value = drag orelse return null;
    if (value.id != region.id) return null;
    if (region.bounds.w <= 0.0) return null;
    return ui.clampUnit((value.pointer_x - region.bounds.x) / region.bounds.w);
}
