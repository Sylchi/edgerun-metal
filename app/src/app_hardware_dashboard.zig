const std = @import("std");
const bytes = @import("bytes.zig");
const ui = @import("ui/core.zig");
const icon = @import("ui/icon.zig");
const component_union = @import("ui/components/Component.zig");
const IconComponent = @import("ui/components/Icon.zig");
const RenderOptions = @import("ui/component_common.zig").RenderOptions;
const interaction = @import("ui/interaction.zig");
const ui_runtime = @import("ui/runtime.zig");
const text_metrics = @import("ui/text_metrics.zig");

const linux = std.os.linux;

pub const Error = error{
    ReadFailed,
    ParseFailed,
};

const row_count = 15;
const detail_bytes = 80;
const state_bytes = row_count * detail_bytes;
const unavailable_detail = "unavailable";
const sample_count = 12;
const note_bytes = 240;

const RowDef = struct {
    icon_kind: icon.Icon,
    title: []const u8,
};

const rows = [_]RowDef{
    .{ .icon_kind = .device_desktop, .title = "Platform" },
    .{ .icon_kind = .temperature, .title = "CPU Temp" },
    .{ .icon_kind = .database, .title = "Memory" },
    .{ .icon_kind = .battery, .title = "Battery" },
    .{ .icon_kind = .brightness, .title = "Screen" },
    .{ .icon_kind = .keyboard, .title = "Keyboard" },
    .{ .icon_kind = .server, .title = "EC" },
    .{ .icon_kind = .cpu, .title = "GPU" },
    .{ .icon_kind = .shield_check, .title = "TPM" },
    .{ .icon_kind = .device_desktop, .title = "PCI Devices" },
    .{ .icon_kind = .network, .title = "Network" },
    .{ .icon_kind = .device_floppy, .title = "Storage" },
    .{ .icon_kind = .device_speaker, .title = "Audio" },
    .{ .icon_kind = .camera, .title = "Camera" },
    .{ .icon_kind = .wifi, .title = "Wireless" },
};

const Component = component_union.Component;
const hardware_bg_top = ui.Color{ .r = 8, .g = 9, .b = 10 };
const hardware_bg_bottom = ui.Color{ .r = 9, .g = 9, .b = 11 };
const hardware_panel = ui.Color{ .r = 24, .g = 24, .b = 27, .a = 224 };
const hardware_row = ui.Color{ .r = 39, .g = 39, .b = 42, .a = 158 };
const hardware_border = ui.Color{ .r = 63, .g = 63, .b = 70, .a = 82 };
const hardware_text = ui.Color{ .r = 250, .g = 250, .b = 250 };
const hardware_muted = ui.Color{ .r = 161, .g = 161, .b = 170 };
const hardware_accent = ui.Color{ .r = 23, .g = 166, .b = 135 };
const hardware_accent_blue = ui.Color{ .r = 71, .g = 143, .b = 235 };
const hardware_accent_gold = ui.Color{ .r = 235, .g = 168, .b = 64 };
const hardware_accent_dim = ui.Color{ .r = 23, .g = 80, .b = 68, .a = 26 };
const hardware_orb = ui.Color{ .r = 23, .g = 166, .b = 135, .a = 2 };
const hardware_rim = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 3 };
const hardware_selection = ui.Color{ .r = 161, .g = 161, .b = 170, .a = 150 };
const hardware_selection_fill = ui.Color{ .r = 161, .g = 161, .b = 170, .a = 7 };
const editor_panel = ui.Color{ .r = 24, .g = 24, .b = 27, .a = 246 };
const editor_scrim = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 24 };
const subtle_divider = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 7 };

fn hardwareStyle(accent: ui.Color) ui.Style {
    return .{
        .bg = hardware_bg_top,
        .panel = hardware_panel,
        .row = hardware_row,
        .border = hardware_border,
        .text = hardware_text,
        .muted = hardware_muted,
        .accent = accent,
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
    compact_rows: bool = true,
    status: [detail_bytes]u8 = [_]u8{0} ** detail_bytes,
    screen_brightness: i32 = 0,
    screen_brightness_max: i32 = 1,
    keyboard_brightness: i32 = 0,
    keyboard_brightness_max: i32 = 1,
    screen_brightness_ready: bool = false,
    keyboard_brightness_ready: bool = false,
    selected_component: ?interaction.Region = null,
    context_open: bool = false,
    editor_open: bool = false,
    context_open_frame: u64 = 0,
    editor_open_frame: u64 = 0,
    selected_frame: u64 = 0,
    context_x: f32 = 0.0,
    context_y: f32 = 0.0,
    accent_index: u8 = 0,
    selected_emphasis: bool = true,
    profile_index: u8 = 0,
    note: [note_bytes]u8 = [_]u8{0} ** note_bytes,
    note_len: usize = 0,
    temp_samples: [sample_count]f32 = [_]f32{0.0} ** sample_count,
    temp_sample_len: usize = 0,
    temp_sample_index: usize = 0,
    memory_pressure: f32 = 0.0,
    battery_unit: f32 = 0.0,
    battery_ready: bool = false,

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
    const refresh_interval_frames: u64 = 600;
    const transition_frames: u64 = 14;
    const select_header_id: u32 = 91_001;
    const select_controls_id: u32 = 91_002;
    const select_activity_id: u32 = 91_003;
    const select_inventory_id: u32 = 91_004;
    const select_metric_base_id: u32 = 91_020;
    const select_control_base_id: u32 = 91_040;
    const select_level_base_id: u32 = 91_060;
    const context_open_editor_id: u32 = 91_080;
    const context_close_id: u32 = 91_081;
    const editor_close_id: u32 = 91_082;
    const editor_accent_prev_id: u32 = 91_083;
    const editor_accent_next_id: u32 = 91_084;
    const editor_emphasis_switch_id: u32 = 91_085;
    const profile_input_id: u32 = 91_090;
    const profile_cycle_button_id: u32 = 91_091;
    const note_textarea_id: u32 = 91_092;
    const note_append_button_id: u32 = 91_093;
    const note_clear_button_id: u32 = 91_094;

    pub fn tick(self: *State) bool {
        self.frame += 1;
        var needs_repaint = self.animationActive();
        if (!self.auto_refresh) return needs_repaint;
        if (self.frame - self.last_refresh_frame >= refresh_interval_frames) {
            self.refresh();
            needs_repaint = true;
        }
        return needs_repaint;
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
            context_open_editor_id => {
                self.editor_open = true;
                self.editor_open_frame = self.frame;
                self.context_open = false;
            },
            context_close_id, editor_close_id => {
                self.context_open = false;
                self.editor_open = false;
            },
            editor_accent_prev_id => self.shiftAccent(-1),
            editor_accent_next_id => self.shiftAccent(1),
            editor_emphasis_switch_id => self.selected_emphasis = !self.selected_emphasis,
            profile_input_id, profile_cycle_button_id => self.cycleProfile(),
            note_textarea_id, note_append_button_id => self.appendNote(),
            note_clear_button_id => self.clearNote(),
            else => {},
        }
    }

    pub fn openContext(self: *State, hit: ?interaction.Region, x: f32, y: f32) void {
        const region = hit orelse {
            self.context_open = false;
            return;
        };
        if (isEditorControl(region.id)) return;
        self.selected_component = region;
        self.selected_frame = self.frame;
        self.context_x = x;
        self.context_y = y;
        self.context_open = true;
        self.editor_open = true;
        self.context_open_frame = self.frame;
        self.editor_open_frame = self.frame;
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
        offset += detail_bytes;

        var storage_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readStorage(&storage_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&storage_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var audio_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readAudio(&audio_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&audio_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var camera_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readCamera(&camera_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&camera_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        offset += detail_bytes;

        var wireless_buf: [detail_bytes]u8 = [_]u8{0} ** detail_bytes;
        if (readWireless(&wireless_buf)) |_| {
            writeDetail(self.details[offset..][0..detail_bytes], trimBuf(&wireless_buf));
        } else |_| {
            writeUnavailable(self.details[offset..][0..detail_bytes]);
        }
        self.recordTelemetrySamples();
    }

    pub fn render(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        var dashboard_options = options;
        dashboard_options.style = hardwareStyle(self.accentColor());
        try scene.pushGradientRect(bounds, hardware_bg_top, hardware_bg_bottom, 0.0);
        try scene.pushGradientRect(ui.Rect.init(bounds.x, bounds.y, bounds.w, 96.0), hardware_orb, ui.Color.clear, 0.0);
        try scene.pushRect(ui.Rect.init(bounds.x, bounds.y + bounds.h - 2.0, bounds.w, 2.0), hardware_rim, .fill, 0.0, 0.0);

        const outer = bounds.insetUniform(if (bounds.w >= 1000.0) 22.0 else 12.0);
        if (outer.w >= 980.0) {
            try self.renderWide(scene, collector, outer, dashboard_options);
        } else {
            try self.renderStacked(scene, collector, outer, dashboard_options);
        }
        self.refreshSelectedRegion(collector.written());
        try self.renderSelectionOverlay(scene, bounds);
        try self.renderContextAndEditor(scene, collector, bounds, dashboard_options);
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
        const gap: f32 = if (self.compact_rows) 14.0 else 16.0;
        const header_h: f32 = 78.0;
        const metric_h: f32 = 96.0;
        try self.renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), options);

        const metric_y = bounds.y + header_h + gap;
        const metric_w = (bounds.w - gap * 3.0) * 0.25;
        try self.renderMetrics(scene, collector, ui.Rect.init(bounds.x, metric_y, bounds.w, metric_h), metric_w, gap, options);

        const body_y = metric_y + metric_h + gap;
        const body_h = @max(1.0, bounds.y + bounds.h - body_y);
        const controls_w = @min(370.0, @max(330.0, bounds.w * 0.24));
        const inventory_w = @min(390.0, @max(330.0, bounds.w * 0.25));
        const activity_w = bounds.w - controls_w - inventory_w - gap * 2.0;
        try self.renderControls(scene, collector, ui.Rect.init(bounds.x, body_y, controls_w, body_h), options);
        try self.renderActivity(scene, collector, ui.Rect.init(bounds.x + controls_w + gap, body_y, activity_w, body_h), options);
        try self.renderInventory(scene, collector, ui.Rect.init(bounds.x + controls_w + gap + activity_w + gap, body_y, inventory_w, body_h), options);
    }

    fn renderStacked(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const gap: f32 = 12.0;
        var y = bounds.y;
        try self.renderHeader(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 78.0), options);
        y += 78.0 + gap;
        const metric_w = (bounds.w - gap) * 0.5;
        try self.renderMetrics(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 230.0), metric_w, gap, options);
        y += 230.0 + gap;
        try self.renderControls(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 390.0), options);
        y += 390.0 + gap;
        try self.renderActivity(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, 330.0), options);
        y += 330.0 + gap;
        try self.renderInventory(scene, collector, ui.Rect.init(bounds.x, y, bounds.w, @max(260.0, bounds.y + bounds.h - y)), options);
    }

    fn renderHeader(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        try collector.addHit(bounds, .button, select_header_id);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .elevated } }).renderInteractive(scene, collector, bounds, options);
        try scene.pushGradientRect(bounds.insetUniform(1.0), ui.Color{ .r = 38, .g = 92, .b = 79, .a = 7 }, ui.Color.clear, 12.0);
        const chip = ui.Rect.init(bounds.x + 20.0, bounds.y + 20.0, 36.0, 36.0);
        try scene.pushRect(chip, hardware_accent_dim, .fill, 9.0, 0.0);
        try IconComponent.Icon.named(.device_desktop).renderColor(scene, chip.withHeightCentered(18.0).withWidthCentered(18.0), options.style.accent);
        try scene.pushStrongText(ui.Rect.init(bounds.x + 72.0, bounds.y + 17.0, @max(1.0, bounds.w - 330.0), 22.0), "Hardware Command Center", options.style.text);
        try scene.pushText(ui.Rect.init(bounds.x + 72.0, bounds.y + 46.0, @max(1.0, bounds.w - 330.0), 16.0), fittedText(self.detail(0), @max(1.0, bounds.w - 330.0)), options.style.muted);
        try (Component{ .badge = .{ .label = self.statusLabel(), .variant = .secondary } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x + bounds.w - 230.0, bounds.y + 24.0, 150.0, 28.0), options);
        try (Component{ .icon_button = .{
            .id = refresh_now_button_id,
            .label = "Refresh",
            .icon = IconComponent.Icon.named(.reload),
            .variant = .outline,
        } }).renderInteractive(scene, collector, ui.Rect.init(bounds.x + bounds.w - 54.0, bounds.y + 21.0, 34.0, 34.0), options);
    }

    fn renderMetrics(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, metric_w: f32, gap: f32, options: RenderOptions) !void {
        const cards_per_row: usize = if (bounds.w >= 980.0) 4 else 2;
        const row_h = if (cards_per_row == 4) bounds.h else (bounds.h - gap) * 0.5;
        const data = [_]struct { id: u32, title: []const u8, value: []const u8, detail: []const u8, icon_kind: icon.Icon }{
            .{ .id = select_metric_base_id, .title = "Thermals", .value = self.detail(1), .detail = "CPU sensor", .icon_kind = .temperature },
            .{ .id = select_metric_base_id + 1, .title = "Memory", .value = memoryMetricValue(self.detail(2)), .detail = "Live pressure", .icon_kind = .database },
            .{ .id = select_metric_base_id + 2, .title = "Display", .value = self.detail(4), .detail = "Panel brightness", .icon_kind = .brightness },
            .{ .id = select_metric_base_id + 3, .title = "Keyboard", .value = self.detail(5), .detail = "Backlight level", .icon_kind = .keyboard },
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
            try self.renderMetricCard(scene, collector, rect, entry.id, entry.title, entry.value, entry.detail, entry.icon_kind, options);
        }
    }

    fn renderControls(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        try collector.addHit(bounds, .button, select_controls_id);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .elevated } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(18.0);
        var y = inner.y;
        try self.renderSectionHeader(scene, inner.x, y, "Controls", "Display and keyboard knobs.", .adjustments_plus, options);
        y += 54.0;

        try self.renderControlGroup(scene, collector, ui.Rect.init(inner.x, y, inner.w, 112.0), select_control_base_id, "Screen", self.detail(4), brightness_slider_id, self.screenBrightnessUnit(), brightness_down_button_id, brightness_up_button_id, "Screen -", "Screen +", .brightness_down, .brightness_up, options);
        y += 126.0;

        try self.renderControlGroup(scene, collector, ui.Rect.init(inner.x, y, inner.w, 112.0), select_control_base_id + 1, "Keyboard", self.detail(5), kbd_slider_id, self.keyboardBrightnessUnit(), kbd_down_button_id, kbd_up_button_id, "Keys -", "Keys +", .adjustments_minus, .adjustments_plus, options);
        y += 132.0;

        try scene.pushStrongText(ui.Rect.init(inner.x, y, inner.w, 20.0), "Session", options.style.text);
        y += 30.0;
        try (Component{ .switch_control = .{ .id = auto_refresh_switch_id, .label = "Auto Refresh", .checked = self.auto_refresh } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 32.0), options);
        y += 38.0;
        try (Component{ .switch_control = .{ .id = hide_unavailable_switch_id, .label = "Hide Unavailable", .checked = self.hide_unavailable } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 32.0), options);
        y += 38.0;
        try (Component{ .switch_control = .{ .id = compact_rows_switch_id, .label = "Compact Density", .checked = self.compact_rows } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, 32.0), options);
    }

    fn renderActivity(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        try collector.addHit(bounds, .button, select_activity_id);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .elevated } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(18.0);
        try self.renderSectionHeader(scene, inner.x, inner.y, "Live Hardware", "Telemetry and direct controls.", .cpu, options);
        const chart_h = @min(330.0, @max(190.0, bounds.h * 0.48));
        try (Component{ .chart = .{ .id = 90_020, .label = "System Activity" } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, inner.y + 54.0, inner.w, chart_h), options);

        const lower_y = inner.y + 68.0 + chart_h;
        const card_gap: f32 = 12.0;
        const card_h = @min(122.0, @max(102.0, bounds.y + bounds.h - lower_y - 20.0));
        const half = (inner.w - card_gap) * 0.5;
        try self.renderLevelCard(scene, collector, ui.Rect.init(inner.x, lower_y, half, card_h), select_level_base_id, "Screen Level", self.detail(4), self.screenBrightnessUnit(), .brightness, options);
        try self.renderLevelCard(scene, collector, ui.Rect.init(inner.x + half + card_gap, lower_y, half, card_h), select_level_base_id + 1, "Keyboard Level", self.detail(5), self.keyboardBrightnessUnit(), .keyboard, options);

        const footer_y = lower_y + card_h + 12.0;
        if (footer_y + 76.0 <= bounds.y + bounds.h) {
            try (Component{ .card = .{ .title = "", .detail = "", .variant = .subtle } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, footer_y, inner.w, 76.0), options);
            try scene.pushStrongText(ui.Rect.init(inner.x + 16.0, footer_y + 15.0, inner.w - 32.0, 20.0), "Demo posture", options.style.text);
            try scene.pushText(ui.Rect.init(inner.x + 16.0, footer_y + 42.0, inner.w - 32.0, 18.0), if (self.auto_refresh) "Auto-refresh is live; sliders route through existing handlers." else "Auto-refresh paused; manual refresh remains available.", options.style.muted);
        }
    }

    fn renderInventory(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        try collector.addHit(bounds, .button, select_inventory_id);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .elevated } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(18.0);
        var y = inner.y;
        try self.renderSectionHeader(scene, inner.x, y, "Inventory", "Detected runtime capabilities.", .server, options);
        y += 54.0;
        const row_h: f32 = if (self.compact_rows) 42.0 else 50.0;
        for (&rows, 0..) |row, index| {
            const row_detail = self.detail(index);
            if (self.hide_unavailable and std.mem.eql(u8, row_detail, unavailable_detail)) continue;
            if (y + row_h > inner.y + inner.h) break;
            try (Component{ .row_item = .{
                .id = @intCast(index),
                .title = row.title,
                .detail = row_detail,
                .leading_icon = IconComponent.IconSlot.named(.leading, row.icon_kind),
            } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, y, inner.w, row_h), options);
            y += row_h + 6.0;
        }
    }

    fn renderSectionHeader(self: *State, scene: *ui.Scene, x: f32, y: f32, title: []const u8, detail_text: []const u8, icon_kind: icon.Icon, options: RenderOptions) !void {
        _ = self;
        const chip = ui.Rect.init(x, y + 2.0, 28.0, 28.0);
        try scene.pushRect(chip, hardware_accent_dim, .fill, 7.0, 0.0);
        try IconComponent.Icon.named(icon_kind).renderColor(scene, chip.withHeightCentered(15.0).withWidthCentered(15.0), options.style.accent);
        try scene.pushStrongText(ui.Rect.init(x + 42.0, y, 260.0, 18.0), title, options.style.text);
        try scene.pushText(ui.Rect.init(x + 42.0, y + 23.0, 300.0, 15.0), fittedText(detail_text, 300.0), options.style.muted);
    }

    fn renderMetricCard(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, select_id: u32, title: []const u8, value: []const u8, detail_text: []const u8, icon_kind: icon.Icon, options: RenderOptions) !void {
        _ = self;
        try collector.addHit(bounds, .button, select_id);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .panel } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(14.0);
        const chip = ui.Rect.init(inner.x, inner.y, 28.0, 28.0);
        try scene.pushRect(chip, hardware_accent_dim, .fill, 7.0, 0.0);
        try IconComponent.Icon.named(icon_kind).renderColor(scene, chip.withHeightCentered(15.0).withWidthCentered(15.0), options.style.accent);
        try scene.pushStrongText(ui.Rect.init(inner.x + 40.0, inner.y - 1.0, inner.w - 40.0, 17.0), title, options.style.text);
        try scene.pushText(ui.Rect.init(inner.x + 40.0, inner.y + 21.0, inner.w - 40.0, 14.0), fittedText(detail_text, inner.w - 40.0), options.style.muted);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 58.0, inner.w, 20.0), fittedText(displayValue(value), inner.w), options.style.text);
    }

    fn renderControlGroup(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, select_id: u32, title: []const u8, value: []const u8, slider_id: u32, slider_value: f32, down_id: u32, up_id: u32, down_label: []const u8, up_label: []const u8, down_icon: icon.Icon, up_icon: icon.Icon, options: RenderOptions) !void {
        _ = self;
        try collector.addHit(bounds, .button, select_id);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .subtle } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(14.0);
        try scene.pushStrongText(ui.Rect.init(inner.x, inner.y, inner.w * 0.55, 18.0), title, options.style.text);
        try scene.pushText(ui.Rect.init(inner.x + inner.w * 0.55, inner.y + 1.0, inner.w * 0.45, 15.0), fittedText(displayValue(value), inner.w * 0.45), options.style.muted);
        try (Component{ .slider = .{ .id = slider_id, .label = "", .value = slider_value } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, inner.y + 27.0, inner.w, 26.0), options);
        const half_w = (inner.w - 10.0) * 0.5;
        try (Component{ .button = .{ .id = down_id, .label = down_label, .variant = .outline, .icon_slot = IconComponent.IconSlot.named(.leading, down_icon) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, inner.y + 66.0, half_w, 32.0), options);
        try (Component{ .button = .{ .id = up_id, .label = up_label, .variant = .primary, .icon_slot = IconComponent.IconSlot.named(.leading, up_icon) } }).renderInteractive(scene, collector, ui.Rect.init(inner.x + half_w + 10.0, inner.y + 66.0, half_w, 32.0), options);
    }

    fn renderLevelCard(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, select_id: u32, title: []const u8, value: []const u8, unit: f32, icon_kind: icon.Icon, options: RenderOptions) !void {
        _ = self;
        try collector.addHit(bounds, .button, select_id);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .panel } }).renderInteractive(scene, collector, bounds, options);
        const inner = bounds.insetUniform(16.0);
        const chip = ui.Rect.init(inner.x, inner.y, 28.0, 28.0);
        try scene.pushRect(chip, hardware_accent_dim, .fill, 7.0, 0.0);
        try IconComponent.Icon.named(icon_kind).renderColor(scene, chip.withHeightCentered(16.0).withWidthCentered(16.0), options.style.accent);
        try scene.pushStrongText(ui.Rect.init(inner.x + 40.0, inner.y, inner.w - 40.0, 18.0), title, options.style.text);
        try scene.pushText(ui.Rect.init(inner.x + 40.0, inner.y + 22.0, inner.w - 40.0, 15.0), fittedText(displayValue(value), inner.w - 40.0), options.style.muted);
        try (Component{ .progress = .{ .value = unit } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, inner.y + inner.h - 24.0, inner.w, 18.0), options);
    }

    fn renderSelectionOverlay(self: *State, scene: *ui.Scene, bounds: ui.Rect) !void {
        _ = bounds;
        const selected = self.selected_component orelse return;
        const progress = self.selectionProgress();
        if (self.selected_emphasis) try scene.pushOverlayRect(selected.bounds, scaleAlpha(hardware_selection_fill, progress), .fill, 12.0, 0.0);
        try scene.pushOverlayRect(selected.bounds.insetUniform(-2.0), scaleAlpha(hardware_selection, progress), .border, 14.0, 0.0);
    }

    fn renderContextAndEditor(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        if (self.context_open) try self.renderContextMenu(scene, collector, bounds, options);
        if (self.editor_open) try self.renderEditor(scene, collector, bounds, options);
    }

    fn renderContextMenu(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const mark = scene.cursor();
        const menu_w: f32 = 220.0;
        const menu_h: f32 = 118.0;
        const x = std.math.clamp(self.context_x, bounds.x + 8.0, bounds.x + bounds.w - menu_w - 8.0);
        const y = std.math.clamp(self.context_y, bounds.y + 8.0, bounds.y + bounds.h - menu_h - 8.0);
        const menu = ui.Rect.init(x, y, menu_w, menu_h);
        try scene.pushRect(menu.insetUniform(-2.0), ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 }, .shadow, 14.0, 8.0);
        try scene.pushRect(menu, editor_panel, .fill, 12.0, 0.0);
        try scene.pushRect(menu, options.style.border, .border, 12.0, 0.0);
        try scene.pushStrongText(ui.Rect.init(menu.x + 14.0, menu.y + 12.0, menu.w - 28.0, 18.0), selectedComponentLabel(self.selected_component), options.style.text);
        try scene.pushText(ui.Rect.init(menu.x + 14.0, menu.y + 36.0, menu.w - 28.0, 16.0), "Context menu", options.style.muted);
        try (Component{ .button = .{ .id = context_open_editor_id, .label = "Open editor", .variant = .primary } }).renderInteractive(scene, collector, ui.Rect.init(menu.x + 12.0, menu.y + 66.0, 118.0, 34.0), options);
        try (Component{ .button = .{ .id = context_close_id, .label = "Close", .variant = .outline } }).renderInteractive(scene, collector, ui.Rect.init(menu.x + 138.0, menu.y + 66.0, 70.0, 34.0), options);
        const progress = self.contextProgress();
        scene.applyOpacitySince(mark, progress);
        scene.translateSince(mark, 0.0, (1.0 - progress) * 8.0);
        scene.promoteSinceToOverlay(mark);
    }

    fn renderEditor(self: *State, scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) !void {
        const mark = scene.cursor();
        const panel_w = @min(360.0, @max(300.0, bounds.w * 0.24));
        const panel = ui.Rect.init(bounds.x + bounds.w - panel_w - 18.0, bounds.y + 18.0, panel_w, @min(398.0, bounds.h - 36.0));
        try scene.pushRect(panel.insetUniform(-1.0), ui.Color{ .r = 0, .g = 0, .b = 0, .a = 82 }, .shadow, 16.0, 8.0);
        try scene.pushRect(panel, editor_panel, .fill, 14.0, 0.0);
        try scene.pushRect(panel, options.style.border, .border, 14.0, 0.0);
        try scene.pushGradientRect(ui.Rect.init(panel.x, panel.y, panel.w, 76.0), editor_scrim, ui.Color.clear, 14.0);
        const inner = panel.insetUniform(16.0);
        try scene.pushBoldText(ui.Rect.init(inner.x, inner.y, inner.w - 42.0, 24.0), "Component Editor", options.style.text);
        try (Component{ .icon_button = .{
            .id = editor_close_id,
            .label = "Close editor",
            .icon = IconComponent.Icon.named(.x),
            .variant = .outline,
        } }).renderInteractive(scene, collector, ui.Rect.init(inner.x + inner.w - 34.0, inner.y - 2.0, 32.0, 32.0), options);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 31.0, inner.w, 17.0), selectedComponentLabel(self.selected_component), options.style.muted);
        try scene.pushText(ui.Rect.init(inner.x, inner.y + 54.0, inner.w, 17.0), "Live changes apply immediately.", options.style.muted);

        const preview = ui.Rect.init(inner.x, inner.y + 86.0, inner.w, 74.0);
        try (Component{ .card = .{ .title = "", .detail = "", .variant = .subtle } }).renderInteractive(scene, collector, preview, options);
        try scene.pushStrongText(ui.Rect.init(preview.x + 14.0, preview.y + 12.0, preview.w - 28.0, 19.0), "Selected", options.style.text);
        try scene.pushText(ui.Rect.init(preview.x + 14.0, preview.y + 39.0, preview.w - 28.0, 17.0), selectedComponentLabel(self.selected_component), options.style.muted);

        const accent_y = inner.y + 184.0;
        try scene.pushStrongText(ui.Rect.init(inner.x, accent_y, inner.w, 20.0), "Accent", options.style.text);
        try scene.pushText(ui.Rect.init(inner.x, accent_y + 25.0, inner.w, 18.0), accentName(self.accent_index), options.style.muted);
        const button_w = (inner.w - 10.0) * 0.5;
        try (Component{ .button = .{ .id = editor_accent_prev_id, .label = "Accent -", .variant = .outline } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, accent_y + 52.0, button_w, 34.0), options);
        try (Component{ .button = .{ .id = editor_accent_next_id, .label = "Accent +", .variant = .primary } }).renderInteractive(scene, collector, ui.Rect.init(inner.x + button_w + 10.0, accent_y + 52.0, button_w, 34.0), options);

        try scene.pushRect(ui.Rect.init(inner.x, accent_y + 106.0, inner.w, 1.0), subtle_divider, .fill, 0.0, 0.0);
        try (Component{ .switch_control = .{ .id = editor_emphasis_switch_id, .label = "Selected emphasis", .checked = self.selected_emphasis } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, accent_y + 122.0, inner.w, 32.0), options);
        try (Component{ .switch_control = .{ .id = compact_rows_switch_id, .label = "Compact inventory", .checked = self.compact_rows } }).renderInteractive(scene, collector, ui.Rect.init(inner.x, accent_y + 162.0, inner.w, 32.0), options);
        const progress = self.editorProgress();
        scene.applyOpacitySince(mark, progress);
        scene.translateSince(mark, (1.0 - progress) * 18.0, 0.0);
        scene.promoteSinceToOverlay(mark);
    }

    fn adjustBacklight(self: *State, kind: BacklightKind, direction: i32) void {
        const resolved = readResolvedBacklight(kind) catch |err| return self.setStatus(backlightReadStatusForKind(kind, err));
        self.writeBacklight(kind, resolved.device, steppedBacklightValue(resolved.device, resolved.reading, direction));
    }

    fn refreshSelectedRegion(self: *State, regions: []const interaction.Region) void {
        const selected = self.selected_component orelse return;
        for (regions) |region| {
            if (region.kind == selected.kind and region.id == selected.id) {
                self.selected_component = region;
                return;
            }
        }
    }

    fn accentColor(self: *const State) ui.Color {
        return switch (self.accent_index) {
            0 => hardware_accent,
            1 => hardware_accent_blue,
            else => hardware_accent_gold,
        };
    }

    fn shiftAccent(self: *State, direction: i32) void {
        const count: i32 = 3;
        const current: i32 = @intCast(self.accent_index);
        self.accent_index = @intCast(@mod(current + direction, count));
    }

    fn animationActive(self: *const State) bool {
        return self.contextProgress() < 1.0 or self.editorProgress() < 1.0 or self.selectionProgress() < 1.0;
    }

    fn contextProgress(self: *const State) f32 {
        return if (self.context_open) transitionProgress(self.frame, self.context_open_frame) else 1.0;
    }

    fn editorProgress(self: *const State) f32 {
        return if (self.editor_open) transitionProgress(self.frame, self.editor_open_frame) else 1.0;
    }

    fn selectionProgress(self: *const State) f32 {
        return if (self.selected_component != null) transitionProgress(self.frame, self.selected_frame) else 1.0;
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

fn writeDetail(out: []u8, value: []const u8) void {
    bytes.zero(out);
    const len = @min(value.len, out.len - 1);
    _ = bytes.copy(out[0..len], value[0..len]);
}

fn writeUnavailable(out: []u8) void {
    writeDetail(out, unavailable_detail);
}

fn displayValue(value: []const u8) []const u8 {
    return if (value.len == 0 or std.mem.eql(u8, value, unavailable_detail)) "N/A" else value;
}

fn selectedComponentLabel(selected: ?interaction.Region) []const u8 {
    const region = selected orelse return "No component selected";
    if (region.kind == .row_item and region.id < rows.len) return rows[region.id].title;
    return switch (region.id) {
        State.select_header_id => "Header",
        State.select_controls_id => "Controls panel",
        State.select_activity_id => "Live hardware panel",
        State.select_inventory_id => "Inventory panel",
        State.select_metric_base_id => "Thermals metric",
        State.select_metric_base_id + 1 => "Memory metric",
        State.select_metric_base_id + 2 => "Display metric",
        State.select_metric_base_id + 3 => "Keyboard metric",
        State.select_control_base_id => "Screen controls",
        State.select_control_base_id + 1 => "Keyboard controls",
        State.select_level_base_id => "Screen level card",
        State.select_level_base_id + 1 => "Keyboard level card",
        State.refresh_now_button_id => "Refresh button",
        State.auto_refresh_switch_id => "Auto refresh switch",
        State.hide_unavailable_switch_id => "Hide unavailable switch",
        State.compact_rows_switch_id => "Compact density switch",
        State.brightness_down_button_id => "Screen down button",
        State.brightness_up_button_id => "Screen up button",
        State.kbd_down_button_id => "Keyboard down button",
        State.kbd_up_button_id => "Keyboard up button",
        State.brightness_slider_id => "Screen brightness slider",
        State.kbd_slider_id => "Keyboard brightness slider",
        else => "Component",
    };
}

fn accentName(index: u8) []const u8 {
    return switch (index) {
        0 => "Graphite mint",
        1 => "Instrument blue",
        else => "Warm amber",
    };
}

fn transitionProgress(frame: u64, opened_at: u64) f32 {
    const elapsed = if (frame >= opened_at) frame - opened_at + 1 else 1;
    const unit = @min(@as(f32, 1.0), @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(State.transition_frames)));
    return ui.easingSample(.ease_out, unit);
}

fn scaleAlpha(color: ui.Color, unit: f32) ui.Color {
    var out = color;
    out.a = @intFromFloat(@round(@as(f32, @floatFromInt(color.a)) * ui.clampUnit(unit)));
    return out;
}

fn isEditorControl(id: u32) bool {
    return switch (id) {
        State.context_open_editor_id,
        State.context_close_id,
        State.editor_close_id,
        State.editor_accent_prev_id,
        State.editor_accent_next_id,
        State.editor_emphasis_switch_id,
        => true,
        else => false,
    };
}

fn fittedText(value: []const u8, width: f32) []const u8 {
    return text_metrics.fitPrefix(value, text_metrics.default_text_px, width);
}

fn memoryMetricValue(value: []const u8) []const u8 {
    if (std.mem.startsWith(u8, value, "Total:")) return "Memory online";
    return value;
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

test "hardware dashboard tick reports whether a frame needs repaint" {
    var state = State{ .auto_refresh = false };

    try std.testing.expect(!state.tick());
    try std.testing.expectEqual(@as(u64, 1), state.frame);
}

test "hardware dashboard context menu selects component and opens live editor" {
    var state = State{};
    const region = interaction.Region{ .kind = .button, .id = State.select_metric_base_id + 2, .bounds = ui.Rect.init(10, 20, 120, 80) };

    state.openContext(region, 42.0, 64.0);

    try std.testing.expect(state.context_open);
    try std.testing.expect(state.editor_open);
    try std.testing.expectEqual(region.id, state.selected_component.?.id);
    try std.testing.expectEqualStrings("Display metric", selectedComponentLabel(state.selected_component));
}

test "hardware dashboard editor accent controls wrap deterministically" {
    var state = State{};

    state.activate(.{ .kind = .button, .id = State.editor_accent_prev_id, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expectEqual(@as(u8, 2), state.accent_index);

    state.activate(.{ .kind = .button, .id = State.editor_accent_next_id, .bounds = ui.Rect.init(0, 0, 10, 10) }, null);
    try std.testing.expectEqual(@as(u8, 0), state.accent_index);
}
