const std = @import("std");
const ui = @import("ui.zig");

pub const content_wide: f32 = 1180.0;
pub const content_pad: f32 = 28.0;
pub const header_h: f32 = 64.0;

pub const Radius = struct {
    pub const surface: f32 = 8.0;
    pub const control: f32 = 7.0;
};

pub const Control = struct {
    pub const h: f32 = 36.0;
    pub const compact_h: f32 = 32.0;
    pub const min_touch_target: f32 = 32.0;
};

pub const Icon = struct {
    pub const logo_box: f32 = 32.0;
    pub const logo_inset: f32 = 5.0;
    pub const button_box: f32 = 34.0;
    pub const button_inset: f32 = 6.0;
    pub const sidebar: f32 = 16.0;
    pub const card: f32 = 22.0;
    pub const hero_max: f32 = 72.0;
    pub const tile_box: f32 = 40.0;
    pub const tile_inset: f32 = 10.0;
    pub const text_gap: f32 = 12.0;
    pub const tile_text_gap: f32 = 16.0;
};

pub const Type = struct {
    pub const caption_h: f32 = 12.0;
    pub const body_h: f32 = 17.0;
    pub const body_line_h: f32 = 20.0;
    pub const section_h: f32 = 22.0;
    pub const title_h: f32 = 26.0;
    pub const title_line_h: f32 = 46.0;
    pub const code_h: f32 = 13.0;
    pub const average_body_w: f32 = 8.8;
};

pub const Palette = struct {
    pub const bg = ui.Color{ .r = 11, .g = 11, .b = 11 };
    pub const panel = ui.Color{ .r = 19, .g = 20, .b = 22 };
    pub const panel_alt = ui.Color{ .r = 26, .g = 27, .b = 30 };
    pub const panel_hover = ui.Color{ .r = 35, .g = 36, .b = 40 };
    pub const panel_hover_bottom = ui.Color{ .r = 47, .g = 47, .b = 52, .a = 176 };
    pub const panel_alt_hover = ui.Color{ .r = 50, .g = 50, .b = 55, .a = 170 };
    pub const row = ui.Color{ .r = 28, .g = 29, .b = 32 };
    pub const row_hover = ui.Color{ .r = 55, .g = 55, .b = 61, .a = 186 };
    pub const card = panel;
    pub const card_alt = panel_alt;
    pub const code_bg = ui.Color{ .r = 6, .g = 7, .b = 9 };
    pub const sidebar = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 219 };
    pub const border = ui.Color{ .r = 62, .g = 64, .b = 70 };
    pub const border_hover = ui.Color{ .r = 8, .g = 145, .b = 178, .a = 140 };
    pub const text = ui.Color{ .r = 242, .g = 242, .b = 242 };
    pub const dim = ui.Color{ .r = 176, .g = 181, .b = 190 };
    pub const muted = ui.Color{ .r = 126, .g = 135, .b = 149 };
    pub const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    pub const accent = primary;
    pub const green = ui.Color{ .r = 16, .g = 185, .b = 129 };
    pub const neutral_soft = ui.Color{ .r = 32, .g = 32, .b = 32 };
    pub const danger = ui.Color{ .r = 248, .g = 113, .b = 113 };
    pub const orange = ui.Color{ .r = 249, .g = 115, .b = 22 };
    pub const blue = ui.Color{ .r = 96, .g = 165, .b = 250 };
    pub const cyan = ui.Color{ .r = 34, .g = 211, .b = 238 };
    pub const yellow = ui.Color{ .r = 250, .g = 204, .b = 21 };
    pub const amber = ui.Color{ .r = 245, .g = 158, .b = 11 };
    pub const violet = ui.Color{ .r = 167, .g = 139, .b = 250 };
    pub const shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
    pub const shadow_hover = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 160 };
    pub const active = ui.Color{ .r = 24, .g = 52, .b = 33 };
};

pub const State = struct {
    pub const hover_border = ui.Color{ .r = 125, .g = 211, .b = 252 };
    pub const active_border = Palette.cyan;
    pub const focus_border = Palette.yellow;
    pub const invalid_border = Palette.danger;
    pub const disabled_tint = ui.Color{ .r = 10, .g = 14, .b = 20, .a = 142 };
    pub const loading_fill = ui.Color{ .r = 45, .g = 212, .b = 191 };
};

pub const Component = struct {
    pub const control_radius: f32 = 6.0;
    pub const focus_ring_outset: f32 = 2.0;
    pub const state_loading_h: f32 = 3.0;
    pub const row_radius: f32 = 4.0;
    pub const control_text_padding: f32 = 12.0;
    pub const control_label_height: f32 = 16.0;
    pub const control_average_char_width: f32 = 8.5;
    pub const surface_radius: f32 = 10.0;
    pub const surface_padding: f32 = 16.0;
    pub const surface_title_height: f32 = 18.0;
    pub const surface_detail_height: f32 = 16.0;
    pub const surface_detail_gap: f32 = 8.0;
    pub const badge_height: f32 = 24.0;
    pub const badge_text_height: f32 = 13.0;
    pub const badge_padding_x: f32 = 12.0;
};

pub fn appStyle() ui.Style {
    return .{
        .bg = Palette.bg,
        .panel = Palette.panel,
        .row = Palette.row,
        .border = Palette.border,
        .text = Palette.text,
        .muted = Palette.dim,
        .accent = Palette.primary,
    };
}

test "shared ui tokens expose deterministic app style and interaction colors" {
    const value = appStyle();
    try std.testing.expect(std.meta.eql(value.bg, Palette.bg));
    try std.testing.expect(std.meta.eql(value.accent, Palette.primary));
    try std.testing.expect(std.meta.eql(State.focus_border, Palette.yellow));
    try std.testing.expect(std.meta.eql(State.invalid_border, Palette.danger));
    try std.testing.expectEqual(@as(f32, 10.0), Component.surface_radius);
    try std.testing.expectEqual(@as(f32, 24.0), Component.badge_height);
}
