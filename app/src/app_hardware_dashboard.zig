const std = @import("er_std");
const bytes = @import("bytes.zig");
const ui = @import("ui/core.zig");
const icon = @import("ui/icon.zig");
const component_union = @import("ui/components/Component.zig");
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
            profile_input_id => self.cycleProfile(),
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
        const dashboard_options = options.withStyle(hardwareStyle(self.accentColor()));
        const app = component_union.renderer(scene, collector, dashboard_options);
        try self.renderView(app, bounds);
    }

    pub fn renderView(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        try app.gradient(bounds, hardware_bg_top, hardware_bg_bottom, 0.0);
        try app.topScrim(bounds, hardware_orb, 96.0, 0.0);
        try app.fill(ui.Rect.init(bounds.x, bounds.y + bounds.h - 2.0, bounds.w, 2.0), hardware_rim, 0.0);

        const outer = bounds.insetUniform(if (bounds.w >= 1000.0) 22.0 else 12.0);
        if (outer.w >= 980.0) {
            try self.renderWide(app, outer);
        } else {
            try self.renderStacked(app, outer);
        }
        self.refreshSelectedRegion(app.interactionRegions());
        try self.renderSelectionOverlay(app, bounds);
        try self.renderContextAndEditor(app, bounds);
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

    fn renderWide(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        const gap: f32 = if (self.compact_rows) 14.0 else 16.0;
        const header_h: f32 = 78.0;
        const metric_h: f32 = 96.0;
        try self.renderHeader(app, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h));

        const metric_y = bounds.y + header_h + gap;
        try self.renderMetrics(app, ui.Rect.init(bounds.x, metric_y, bounds.w, metric_h), gap);

        const body_y = metric_y + metric_h + gap;
        const body_h = @max(1.0, bounds.y + bounds.h - body_y);
        const controls_w = @min(370.0, @max(330.0, bounds.w * 0.24));
        const inventory_w = @min(390.0, @max(330.0, bounds.w * 0.25));
        const activity_w = bounds.w - controls_w - inventory_w - gap * 2.0;
        try self.renderControls(app, ui.Rect.init(bounds.x, body_y, controls_w, body_h));
        try self.renderActivity(app, ui.Rect.init(bounds.x + controls_w + gap, body_y, activity_w, body_h));
        try self.renderInventory(app, ui.Rect.init(bounds.x + controls_w + gap + activity_w + gap, body_y, inventory_w, body_h));
    }

    fn renderStacked(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        const gap: f32 = 12.0;
        var stack = app.column(bounds, gap);
        try self.renderHeader(app, stack.take(78.0));
        try self.renderMetrics(app, stack.take(230.0), gap);
        try self.renderControls(app, stack.take(390.0));
        try self.renderActivity(app, stack.take(330.0));
        const inventory = stack.remaining();
        try self.renderInventory(app, ui.Rect.init(inventory.x, inventory.y, inventory.w, @max(260.0, inventory.h)));
    }

    fn renderHeader(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        const badges = [_]component_union.HeaderBadge{
            .{ .label = self.statusLabel(), .variant = .secondary, .width = 150.0 },
        };
        try app.pageHeader(bounds, .{
            .id = select_header_id,
            .title = "Hardware Command Center",
            .detail = fittedText(self.detail(0), @max(1.0, bounds.w - 330.0)),
            .icon = .device_desktop,
            .accent = hardware_accent_dim,
            .badges = &badges,
            .trailing_action = .{ .id = refresh_now_button_id, .label = "Refresh", .icon = .reload, .variant = .outline },
        });
    }

    fn renderMetrics(self: *State, app: component_union.View, bounds: ui.Rect, gap: f32) !void {
        const cards_per_row: usize = if (bounds.w >= 980.0) 4 else 2;
        const row_h = if (cards_per_row == 4) bounds.h else (bounds.h - gap) * 0.5;
        const grid = app.grid(bounds, cards_per_row, gap, row_h);
        const data = [_]struct { id: u32, title: []const u8, value: []const u8, detail: []const u8, icon_kind: icon.Icon }{
            .{ .id = select_metric_base_id, .title = "Thermals", .value = self.detail(1), .detail = "CPU sensor", .icon_kind = .temperature },
            .{ .id = select_metric_base_id + 1, .title = "Memory", .value = memoryMetricValue(self.detail(2)), .detail = "Live pressure", .icon_kind = .database },
            .{ .id = select_metric_base_id + 2, .title = "Display", .value = self.detail(4), .detail = "Panel brightness", .icon_kind = .brightness },
            .{ .id = select_metric_base_id + 3, .title = "Keyboard", .value = self.detail(5), .detail = "Backlight level", .icon_kind = .keyboard },
        };
        for (data, 0..) |entry, index| {
            const card = grid.item(index);
            try app.metricCard(card, .{
                .id = entry.id,
                .title = entry.title,
                .detail = fittedText(entry.detail, @max(1.0, card.w - 68.0)),
                .value = fittedText(displayValue(entry.value), @max(1.0, card.w - 28.0)),
                .icon = entry.icon_kind,
            });
        }
    }

    fn renderControls(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        const body = try app.panelScaffold(bounds, .{
            .id = select_controls_id,
            .variant = .elevated,
            .title = "Controls",
            .detail = fittedText("Display and keyboard knobs.", 300.0),
            .icon = .adjustments_plus,
            .inset = 18.0,
            .header_gap = 12.0,
        });
        var stack = app.column(body, 0.0);

        const controls = [_]struct {
            id: u32,
            title: []const u8,
            value: []const u8,
            slider_id: u32,
            slider_value: f32,
            down_id: u32,
            down_label: []const u8,
            down_icon: icon.Icon,
            up_id: u32,
            up_label: []const u8,
            up_icon: icon.Icon,
        }{
            .{ .id = select_control_base_id, .title = "Screen", .value = self.detail(4), .slider_id = brightness_slider_id, .slider_value = self.screenBrightnessUnit(), .down_id = brightness_down_button_id, .down_label = "Screen -", .down_icon = .brightness_down, .up_id = brightness_up_button_id, .up_label = "Screen +", .up_icon = .brightness_up },
            .{ .id = select_control_base_id + 1, .title = "Keyboard", .value = self.detail(5), .slider_id = kbd_slider_id, .slider_value = self.keyboardBrightnessUnit(), .down_id = kbd_down_button_id, .down_label = "Keys -", .down_icon = .adjustments_minus, .up_id = kbd_up_button_id, .up_label = "Keys +", .up_icon = .adjustments_plus },
        };
        for (controls, 0..) |control, index| {
            const row = stack.take(112.0);
            try app.controlGroup(row, .{
                .id = control.id,
                .title = control.title,
                .value = fittedText(displayValue(control.value), @max(1.0, row.w * 0.45)),
                .slider_id = control.slider_id,
                .slider_value = control.slider_value,
                .down_id = control.down_id,
                .down_label = control.down_label,
                .down_icon = control.down_icon,
                .up_id = control.up_id,
                .up_label = control.up_label,
                .up_icon = control.up_icon,
            });
            stack.skip(if (index == controls.len - 1) 20.0 else 14.0);
        }

        try app.title(stack.take(20.0), "Session");
        stack.skip(10.0);
        try app.switchAt(stack.take(32.0), auto_refresh_switch_id, "Auto Refresh", self.auto_refresh);
        stack.skip(6.0);
        try app.switchAt(stack.take(32.0), hide_unavailable_switch_id, "Hide Unavailable", self.hide_unavailable);
        stack.skip(6.0);
        try app.switchAt(stack.take(32.0), compact_rows_switch_id, "Compact Density", self.compact_rows);
        stack.skip(14.0);

        if (stack.remaining().h >= 68.0) {
            try app.title(stack.take(20.0), "Profile");
            stack.skip(8.0);
            try app.selectAt(stack.take(40.0), profile_input_id, profileName(self.profile_index), .adjustments);
        }
    }

    fn renderActivity(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        const body = try app.panelScaffold(bounds, .{
            .id = select_activity_id,
            .variant = .elevated,
            .title = "Live Hardware",
            .detail = fittedText("Telemetry and direct controls.", 300.0),
            .icon = .cpu,
            .inset = 18.0,
            .header_gap = 12.0,
        });
        const chart_h = @min(330.0, @max(190.0, bounds.h * 0.48));
        try app.chartAt(ui.Rect.init(body.x, body.y, body.w, chart_h), 90_020, "System Activity");

        const lower_y = body.y + 14.0 + chart_h;
        const card_gap: f32 = 12.0;
        const card_h = @min(122.0, @max(102.0, bounds.y + bounds.h - lower_y - 20.0));
        const half = (body.w - card_gap) * 0.5;
        const levels = [_]struct { id: u32, title: []const u8, value: []const u8, unit: f32, icon_kind: icon.Icon }{
            .{ .id = select_level_base_id, .title = "Screen Level", .value = self.detail(4), .unit = self.screenBrightnessUnit(), .icon_kind = .brightness },
            .{ .id = select_level_base_id + 1, .title = "Keyboard Level", .value = self.detail(5), .unit = self.keyboardBrightnessUnit(), .icon_kind = .keyboard },
        };
        for (levels, 0..) |level, index| {
            try app.metricCard(ui.Rect.init(body.x + @as(f32, @floatFromInt(index)) * (half + card_gap), lower_y, half, card_h), .{
                .id = level.id,
                .title = level.title,
                .detail = fittedText(displayValue(level.value), @max(1.0, half - 72.0)),
                .value = "",
                .icon = level.icon_kind,
                .progress = level.unit,
            });
        }

        const footer_y = lower_y + card_h + 12.0;
        if (footer_y + 76.0 <= bounds.y + bounds.h) {
            try app.subtleAt(
                ui.Rect.init(body.x, footer_y, body.w, 76.0),
                "Demo posture",
                if (self.auto_refresh) "Auto-refresh is live; sliders route through existing handlers." else "Auto-refresh paused; manual refresh remains available.",
            );
        }
    }

    fn renderInventory(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        var items: [row_count]component_union.PanelListItem = undefined;
        const projected = self.writeInventoryItems(&items);
        try app.panelList(bounds, .{
            .id = select_inventory_id,
            .variant = .elevated,
            .title = "Inventory",
            .detail = fittedText("Detected runtime capabilities.", 300.0),
            .icon = .server,
            .inset = 18.0,
            .header_gap = 12.0,
            .row_h = if (self.compact_rows) 42.0 else 50.0,
            .gap = 6.0,
            .items = projected,
            .empty_title = "No inventory",
            .empty_detail = "No detected runtime capabilities.",
        });
    }

    fn writeInventoryItems(self: *const State, items: *[row_count]component_union.PanelListItem) []const component_union.PanelListItem {
        var item_count: usize = 0;
        for (&rows, 0..) |row, index| {
            const row_detail = self.detail(index);
            if (self.hide_unavailable and std.mem.eql(u8, row_detail, unavailable_detail)) continue;
            items[item_count] = .{
                .id = @intCast(index),
                .title = row.title,
                .detail = row_detail,
                .icon = row.icon_kind,
            };
            item_count += 1;
        }
        return items[0..item_count];
    }

    fn renderSelectionOverlay(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        _ = bounds;
        const selected = self.selected_component orelse return;
        try app.selectionOverlay(selected.bounds, hardware_selection, hardware_selection_fill, self.selectionProgress(), self.selected_emphasis);
    }

    fn renderContextAndEditor(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        if (self.context_open) try self.renderContextMenu(app, bounds);
        if (self.editor_open) try self.renderEditor(app, bounds);
    }

    fn renderContextMenu(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        try app.contextActionPanel(bounds, .{
            .x = self.context_x,
            .y = self.context_y,
            .title = selectedComponentLabel(self.selected_component),
            .detail = "Context menu",
            .primary_id = context_open_editor_id,
            .primary_label = "Open editor",
            .secondary_id = context_close_id,
            .secondary_label = "Close",
            .fill = editor_panel,
            .border = app.options.style.border,
            .shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 },
            .progress = self.contextProgress(),
        });
    }

    fn renderEditor(self: *State, app: component_union.View, bounds: ui.Rect) !void {
        const switches = [_]component_union.EditorSwitchSpec{
            .{ .id = editor_emphasis_switch_id, .label = "Selected emphasis", .checked = self.selected_emphasis },
            .{ .id = compact_rows_switch_id, .label = "Compact inventory", .checked = self.compact_rows },
        };
        try app.propertyEditorPanel(bounds, .{
            .title = "Component Editor",
            .detail = selectedComponentLabel(self.selected_component),
            .close_id = editor_close_id,
            .preview_detail = selectedComponentLabel(self.selected_component),
            .section_title = "Accent",
            .section_detail = accentName(self.accent_index),
            .prev_id = editor_accent_prev_id,
            .prev_label = "Accent -",
            .next_id = editor_accent_next_id,
            .next_label = "Accent +",
            .switches = &switches,
            .fill = editor_panel,
            .border = app.options.style.border,
            .shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 82 },
            .scrim = editor_scrim,
            .progress = self.editorProgress(),
        });
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

    fn cycleProfile(self: *State) void {
        self.profile_index = (self.profile_index + 1) % 3;
        self.setStatus(profileName(self.profile_index));
    }

    fn appendNote(self: *State) void {
        const text = selectedComponentLabel(self.selected_component);
        if (text.len == 0) return;
        if (self.note_len != 0 and self.note_len < self.note.len - 1) {
            self.note[self.note_len] = '\n';
            self.note_len += 1;
        }
        const available = self.note.len - self.note_len;
        if (available <= 1) return self.setStatus("Note full");
        const copied = @min(text.len, available - 1);
        _ = bytes.copy(self.note[self.note_len..][0..copied], text[0..copied]);
        self.note_len += copied;
        self.note[self.note_len] = 0;
        self.setStatus("Note updated");
    }

    fn clearNote(self: *State) void {
        bytes.zero(self.note[0..]);
        self.note_len = 0;
        self.setStatus("Note cleared");
    }

    fn recordTelemetrySamples(self: *State) void {
        if (parseTemperatureCelsius(self.detail(1))) |temperature| {
            self.temp_samples[self.temp_sample_index] = temperature;
            self.temp_sample_index = (self.temp_sample_index + 1) % self.temp_samples.len;
            self.temp_sample_len = @min(self.temp_sample_len + 1, self.temp_samples.len);
        }
        self.memory_pressure = parseMemoryPressure(self.detail(2)) orelse self.memory_pressure;
        self.battery_unit = parseBatteryUnit(self.detail(3)) orelse self.battery_unit;
        self.battery_ready = !std.mem.eql(u8, self.detail(3), unavailable_detail);
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

fn profileName(index: u8) []const u8 {
    return switch (index % 3) {
        0 => "Bring-up",
        1 => "Diagnostics",
        else => "Operator",
    };
}

fn transitionProgress(frame: u64, opened_at: u64) f32 {
    const elapsed = if (frame >= opened_at) frame - opened_at + 1 else 1;
    const unit = @min(@as(f32, 1.0), @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(State.transition_frames)));
    return ui.easingSample(.ease_out, unit);
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

fn parseTemperatureCelsius(value: []const u8) ?f32 {
    var fields = std.mem.tokenizeAny(u8, value, " ");
    const first = fields.next() orelse return null;
    return std.fmt.parseFloat(f32, first) catch null;
}

fn parseMemoryPressure(value: []const u8) ?f32 {
    if (!std.mem.startsWith(u8, value, "Total:")) return null;
    var total_mb: u32 = 0;
    var avail_mb: u32 = 0;
    var fields = std.mem.tokenizeAny(u8, value, " ,:");
    while (fields.next()) |field| {
        if (std.mem.eql(u8, field, "Total")) {
            const raw = fields.next() orelse return null;
            total_mb = std.fmt.parseUnsigned(u32, raw, 10) catch return null;
        } else if (std.mem.eql(u8, field, "Avail")) {
            const raw = fields.next() orelse return null;
            avail_mb = std.fmt.parseUnsigned(u32, raw, 10) catch return null;
        }
    }
    if (total_mb == 0 or avail_mb > total_mb) return null;
    return 1.0 - (@as(f32, @floatFromInt(avail_mb)) / @as(f32, @floatFromInt(total_mb)));
}

fn parseBatteryUnit(value: []const u8) ?f32 {
    const percent = std.mem.indexOfScalar(u8, value, '%') orelse return null;
    const raw = std.mem.trim(u8, value[0..percent], &[_]u8{ ' ', '\t' });
    const battery = std.fmt.parseUnsigned(u32, raw, 10) catch return null;
    return ui.clampUnit(@as(f32, @floatFromInt(battery)) / 100.0);
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

fn readStorage(buf: *[detail_bytes]u8) !void {
    var content: [4096]u8 = undefined;
    const n = try readSysfsStr("/proc/mounts", &content);
    const text = content[0..n];
    var rw_count: u32 = 0;
    var total: u32 = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, ' ');
        _ = fields.next() orelse continue;
        const mountpoint = fields.next() orelse continue;
        const fstype = fields.next() orelse continue;
        const opts = fields.next() orelse continue;
        if (std.mem.eql(u8, fstype, "proc") or
            std.mem.eql(u8, fstype, "sysfs") or
            std.mem.eql(u8, fstype, "devtmpfs") or
            std.mem.eql(u8, fstype, "devpts") or
            std.mem.eql(u8, fstype, "tmpfs"))
        {
            continue;
        }
        total += 1;
        if (std.mem.indexOf(u8, opts, "rw") != null) rw_count += 1;
        if (std.mem.eql(u8, mountpoint, "/")) {
            writeBuf(buf, "root {s}", .{opts});
            return;
        }
    }
    if (total == 0) return error.ParseFailed;
    writeBuf(buf, "{d}/{d} mounts writable", .{ rw_count, total });
}

fn readAudio(buf: *[detail_bytes]u8) !void {
    var content: [1024]u8 = undefined;
    if (readSysfsStr("/proc/asound/cards", &content)) |n| {
        const text = content[0..n];
        if (std.mem.indexOf(u8, text, "no soundcards") == null) {
            var count: u32 = 0;
            var lines = std.mem.splitScalar(u8, text, '\n');
            while (lines.next()) |line| {
                const trimmed = std.mem.trim(u8, line, &[_]u8{ ' ', '\t' });
                if (trimmed.len != 0 and trimmed[0] >= '0' and trimmed[0] <= '9') count += 1;
            }
            if (count != 0) {
                writeBuf(buf, "{d} ALSA cards", .{count});
                return;
            }
        }
    } else |_| {}

    const nodes = countDirEntries("/dev/snd") catch return error.ReadFailed;
    if (nodes == 0) return error.ParseFailed;
    writeBuf(buf, "{d} sound nodes", .{nodes});
}

fn readCamera(buf: *[detail_bytes]u8) !void {
    const prefixes = [_][]const u8{ "video", "media" };
    const nodes = countDirPrefixes("/dev", &prefixes) catch return error.ReadFailed;
    if (nodes == 0) return error.ParseFailed;
    writeBuf(buf, "{d} camera nodes", .{nodes});
}

fn readWireless(buf: *[detail_bytes]u8) !void {
    var content: [2048]u8 = undefined;
    if (readSysfsStr("/proc/net/wireless", &content)) |n| {
        const text = content[0..n];
        var count: u32 = 0;
        var first_if: []const u8 = "";
        var first_quality: []const u8 = "";
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |line| {
            const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const ifname = std.mem.trim(u8, line[0..colon], &[_]u8{ ' ', '\t' });
            if (ifname.len == 0) continue;
            count += 1;
            if (first_if.len == 0) {
                first_if = ifname;
                var fields = std.mem.tokenizeAny(u8, line[colon + 1 ..], " \t");
                _ = fields.next();
                first_quality = fields.next() orelse "";
            }
        }
        if (count != 0) {
            if (first_quality.len != 0) {
                writeBuf(buf, "{s} link {s}", .{ first_if, first_quality });
            } else {
                writeBuf(buf, "{d} wireless links", .{count});
            }
            return;
        }
    } else |_| {}

    const prefixes = [_][]const u8{ "wlan", "wl" };
    var radio_buf: [32]u8 = [_]u8{0} ** 32;
    const radio = firstDirPrefix("/sys/class/net", &prefixes, &radio_buf) catch return error.ReadFailed;
    if (radio.len == 0) return error.ParseFailed;
    var path_buf: [96]u8 = undefined;
    const state_path = std.fmt.bufPrint(&path_buf, "/sys/class/net/{s}/operstate", .{radio}) catch return error.ParseFailed;
    var state_buf: [24]u8 = undefined;
    const sn = readSysfsStr(state_path, &state_buf) catch return error.ReadFailed;
    const state = std.mem.trimEnd(u8, state_buf[0..sn], &[_]u8{ '\n', ' ', '\r' });
    writeBuf(buf, "{s} {s}", .{ radio, state });
}

fn countDirEntries(path: []const u8) !u32 {
    const fd = try openDir(path);
    defer _ = linux.close(fd);
    var dir_buf: [2048]u8 = undefined;
    var count: u32 = 0;
    while (try nextDirBatch(fd, &dir_buf)) |bytes_read| {
        var offset: usize = 0;
        while (offset < bytes_read) {
            const entry = dirEntryName(dir_buf[offset..bytes_read]) orelse return error.ParseFailed;
            if (!isDotDir(entry.name)) count += 1;
            offset += entry.reclen;
        }
    }
    return count;
}

fn countDirPrefixes(path: []const u8, prefixes: []const []const u8) !u32 {
    const fd = try openDir(path);
    defer _ = linux.close(fd);
    var dir_buf: [2048]u8 = undefined;
    var count: u32 = 0;
    while (try nextDirBatch(fd, &dir_buf)) |bytes_read| {
        var offset: usize = 0;
        while (offset < bytes_read) {
            const entry = dirEntryName(dir_buf[offset..bytes_read]) orelse return error.ParseFailed;
            if (!isDotDir(entry.name) and hasAnyPrefix(entry.name, prefixes)) count += 1;
            offset += entry.reclen;
        }
    }
    return count;
}

fn firstDirPrefix(path: []const u8, prefixes: []const []const u8, out: *[32]u8) ![]const u8 {
    const fd = try openDir(path);
    defer _ = linux.close(fd);
    var dir_buf: [2048]u8 = undefined;
    while (try nextDirBatch(fd, &dir_buf)) |bytes_read| {
        var offset: usize = 0;
        while (offset < bytes_read) {
            const entry = dirEntryName(dir_buf[offset..bytes_read]) orelse return error.ParseFailed;
            if (!isDotDir(entry.name) and hasAnyPrefix(entry.name, prefixes)) {
                const len = @min(entry.name.len, out.len - 1);
                bytes.zero(out[0..]);
                _ = bytes.copy(out[0..len], entry.name[0..len]);
                return out[0..len];
            }
            offset += entry.reclen;
        }
    }
    return "";
}

const DirEntry = struct {
    name: []const u8,
    reclen: usize,
};

fn openDir(path: []const u8) !i32 {
    var path_buf: [256]u8 = [_]u8{0} ** 256;
    if (path.len >= path_buf.len) return error.ReadFailed;
    @memcpy(path_buf[0..path.len], path);
    const rc = linux.openat(linux.AT.FDCWD, @ptrCast(&path_buf), linux.O{ .ACCMODE = .RDONLY, .DIRECTORY = true }, 0);
    if (@as(isize, @bitCast(rc)) < 0) return error.ReadFailed;
    return @intCast(rc);
}

fn nextDirBatch(fd: i32, dir_buf: *[2048]u8) !?usize {
    const rc = linux.getdents64(fd, dir_buf.ptr, dir_buf.len);
    if (@as(isize, @bitCast(rc)) < 0) return error.ReadFailed;
    if (rc == 0) return null;
    return rc;
}

fn dirEntryName(raw: []const u8) ?DirEntry {
    const reclen_offset: usize = 16;
    const name_offset: usize = 19;
    if (raw.len < name_offset) return null;
    const reclen = std.mem.readInt(u16, raw[reclen_offset..][0..2], .little);
    if (reclen < name_offset or reclen > raw.len) return null;
    const name_raw = raw[name_offset..reclen];
    var name_len: usize = 0;
    while (name_len < name_raw.len and name_raw[name_len] != 0) : (name_len += 1) {}
    return .{
        .name = name_raw[0..name_len],
        .reclen = reclen,
    };
}

fn isDotDir(name: []const u8) bool {
    return std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..");
}

fn hasAnyPrefix(name: []const u8, prefixes: []const []const u8) bool {
    for (prefixes) |prefix| {
        if (std.mem.startsWith(u8, name, prefix)) return true;
    }
    return false;
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
