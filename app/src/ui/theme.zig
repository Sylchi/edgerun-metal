const std = @import("std");
const ui = @import("core.zig");
const geometry = @import("geometry.zig");

pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn rgba(r: f32, g: f32, b: f32, a: f32) Color {
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    pub fn rgbU8(r: u8, g: u8, b: u8) Color {
        return rgba(@as(f32, @floatFromInt(r)) / 255.0, @as(f32, @floatFromInt(g)) / 255.0, @as(f32, @floatFromInt(b)) / 255.0, 1.0);
    }

    pub fn rgbaU8(r: u8, g: u8, b: u8, a: u8) Color {
        return rgba(@as(f32, @floatFromInt(r)) / 255.0, @as(f32, @floatFromInt(g)) / 255.0, @as(f32, @floatFromInt(b)) / 255.0, @as(f32, @floatFromInt(a)) / 255.0);
    }

    pub fn withAlpha(self: Color, alpha: f32) Color {
        return .{ .r = self.r, .g = self.g, .b = self.b, .a = alpha };
    }
};

pub const RadiusPreset = enum {
    none,
    compact,
    default,
    soft,

    pub fn next(self: RadiusPreset) RadiusPreset {
        return switch (self) {
            .none => .compact,
            .compact => .default,
            .default => .soft,
            .soft => .none,
        };
    }
};

pub const AccentPreset = enum {
    neutral,
    cyan,
    blue,
    green,
    violet,
    amber,

    pub fn next(self: AccentPreset) AccentPreset {
        return switch (self) {
            .neutral => .cyan,
            .cyan => .blue,
            .blue => .green,
            .green => .violet,
            .violet => .amber,
            .amber => .neutral,
        };
    }
};

pub const Density = enum {
    compact,
    comfortable,
    spacious,

    pub fn next(self: Density) Density {
        return switch (self) {
            .compact => .spacious,
            .comfortable => .compact,
            .spacious => .comfortable,
        };
    }
};

pub const ColorScheme = enum(u32) {
    dark = 0,
    light = 1,
    terminal = 2,

    pub fn next(self: ColorScheme) ColorScheme {
        return switch (self) {
            .dark => .terminal,
            .terminal => .light,
            .light => .dark,
        };
    }

    pub fn fromCode(raw_code: u32) ?ColorScheme {
        return switch (raw_code) {
            0 => .dark,
            1 => .light,
            2 => .terminal,
            else => null,
        };
    }

    pub fn code(self: ColorScheme) u32 {
        return @intFromEnum(self);
    }
};

pub const ColorToken = enum {
    bg,
    sidebar,
    topbar,
    panel,
    row,
    active,
    composer,
    text,
    muted,
    border,
    accent,
    accent_text,
    success,
    warning,
    danger,
    info,
};

pub const DesignColorToken = enum {
    background,
    foreground,
    card,
    card_foreground,
    popover,
    popover_foreground,
    primary,
    primary_foreground,
    secondary,
    secondary_foreground,
    muted,
    muted_foreground,
    accent,
    accent_foreground,
    destructive,
    destructive_foreground,
    border,
    input,
    ring,
    sidebar,
    sidebar_foreground,
    sidebar_primary,
    sidebar_primary_foreground,
    sidebar_accent,
    sidebar_accent_foreground,
    sidebar_border,
    sidebar_ring,
    chart_1,
    chart_2,
    chart_3,
    chart_4,
    chart_5,
};

pub const SemanticColors = struct {
    bg: Color,
    sidebar: Color,
    topbar: Color,
    panel: Color,
    row: Color,
    active: Color,
    composer: Color,
    text: Color,
    muted: Color,
    border: Color,
    accent: Color,
    accent_text: Color,
    success: Color,
    warning: Color,
    danger: Color,
    info: Color,
};

pub const DesignColors = struct {
    background: Color,
    foreground: Color,
    card: Color,
    card_foreground: Color,
    popover: Color,
    popover_foreground: Color,
    primary: Color,
    primary_foreground: Color,
    secondary: Color,
    secondary_foreground: Color,
    muted: Color,
    muted_foreground: Color,
    accent: Color,
    accent_foreground: Color,
    destructive: Color,
    destructive_foreground: Color,
    border: Color,
    input: Color,
    ring: Color,
    sidebar: Color,
    sidebar_foreground: Color,
    sidebar_primary: Color,
    sidebar_primary_foreground: Color,
    sidebar_accent: Color,
    sidebar_accent_foreground: Color,
    sidebar_border: Color,
    sidebar_ring: Color,
    chart_1: Color,
    chart_2: Color,
    chart_3: Color,
    chart_4: Color,
    chart_5: Color,
};

pub const RadiusScale = struct {
    control: f32,
    card: f32,
    panel: f32,
    pill: f32,
};

pub const DesignRadius = struct {
    sm: f32,
    md: f32,
    lg: f32,
    xl: f32,
};

pub const DesignMetrics = struct {
    card_pad_x: f32,
    card_pad_y: f32,
    card_gap: f32,
    field_gap: f32,
    control_h: f32,
    control_pad_x: f32,
    button_h_sm: f32,
    button_h_default: f32,
    button_h_lg: f32,
    icon_button: f32,
    progress_h: f32,
    slider_thumb: f32,
};

pub const DesignSystem = struct {
    colors: DesignColors,
    radius: DesignRadius,
    metrics: DesignMetrics,
};

pub const StylePreset = struct {
    scheme: ColorScheme,
    accent: AccentPreset,
    radius: RadiusPreset,
};

pub const ResolvedTheme = struct {
    preset: StylePreset,
    colors: SemanticColors,
    radius: RadiusScale,
    design: DesignSystem,
    density: Density,
};

pub fn paletteBlack() Color {
    return Color.rgbU8(0, 0, 0);
}
pub fn paletteSlate50() Color {
    return Color.rgbU8(250, 250, 250);
}
pub fn paletteSlate400() Color {
    return Color.rgbU8(161, 161, 170);
}
pub fn paletteSlate700() Color {
    return Color.rgbU8(63, 63, 70);
}
pub fn paletteSlate800() Color {
    return Color.rgbU8(39, 39, 42);
}
pub fn paletteSlate900() Color {
    return Color.rgbU8(24, 24, 27);
}
pub fn paletteSlate950() Color {
    return Color.rgbU8(9, 9, 11);
}
pub fn paletteSky50() Color {
    return Color.rgbU8(240, 249, 255);
}
pub fn paletteCyan600() Color {
    return Color.rgbU8(8, 145, 178);
}
pub fn paletteEmerald500() Color {
    return Color.rgbU8(16, 185, 129);
}
pub fn paletteAmber500() Color {
    return Color.rgbU8(245, 158, 11);
}
pub fn paletteViolet500() Color {
    return Color.rgbU8(139, 92, 246);
}
pub fn paletteRose600() Color {
    return Color.rgbU8(225, 29, 72);
}

pub fn accentColor(accent: AccentPreset) Color {
    return switch (accent) {
        .neutral => paletteSlate400(),
        .green => paletteEmerald500(),
        .violet => paletteViolet500(),
        .amber => paletteAmber500(),
        .blue, .cyan => paletteCyan600(),
    };
}

pub fn radiusScaleFromPreset(preset: RadiusPreset) RadiusScale {
    return switch (preset) {
        .none => .{ .control = 0.0, .card = 0.0, .panel = 0.0, .pill = 0.0 },
        .compact => .{ .control = 6.0, .card = 8.0, .panel = 8.0, .pill = 999.0 },
        .soft => .{ .control = 14.0, .card = 14.0, .panel = 18.0, .pill = 999.0 },
        .default => .{ .control = 8.0, .card = 14.0, .panel = 14.0, .pill = 999.0 },
    };
}

pub fn semanticColorsWithAccent(colors: SemanticColors, accent: Color) SemanticColors {
    var out = colors;
    out.accent = accent;
    out.active = accent.withAlpha(0.42);
    return out;
}

pub fn semanticColorsForScheme(scheme: ColorScheme) SemanticColors {
    switch (scheme) {
        .terminal => return finishSemantic(.{
            .bg = paletteBlack(),
            .sidebar = paletteBlack().withAlpha(0.98),
            .topbar = paletteSlate950().withAlpha(0.96),
            .panel = paletteSlate950().withAlpha(0.94),
            .row = paletteSlate900().withAlpha(0.78),
            .active = paletteSlate700().withAlpha(0.72),
            .composer = paletteSlate950().withAlpha(0.98),
            .text = paletteSlate50(),
            .muted = paletteSlate400(),
            .border = paletteEmerald500().withAlpha(0.34),
            .accent = paletteEmerald500(),
        }),
        .light => return finishSemantic(.{
            .bg = paletteSlate50(),
            .sidebar = paletteSlate50().withAlpha(0.98),
            .topbar = paletteSlate50().withAlpha(0.96),
            .panel = paletteSlate50().withAlpha(0.94),
            .row = paletteSlate400().withAlpha(0.22),
            .active = paletteSlate700().withAlpha(0.72),
            .composer = paletteSlate50().withAlpha(0.98),
            .text = paletteSlate950(),
            .muted = paletteSlate700(),
            .border = paletteSlate400().withAlpha(0.52),
            .accent = paletteCyan600(),
        }),
        .dark => return semanticColorsFromDesign(designCanonical()),
    }
}

pub fn designNeutralDarkColors() DesignColors {
    const background = Color.rgbU8(10, 10, 10);
    const foreground = Color.rgbU8(250, 250, 250);
    const card = Color.rgbU8(23, 23, 23);
    const primary = Color.rgbU8(229, 229, 229);
    const secondary = Color.rgbU8(38, 38, 38);
    const border = Color.rgba(1.0, 1.0, 1.0, 0.10);
    const ring = Color.rgbU8(115, 115, 115);
    return .{
        .background = background,
        .foreground = foreground,
        .card = card,
        .card_foreground = foreground,
        .popover = card,
        .popover_foreground = foreground,
        .primary = primary,
        .primary_foreground = card,
        .secondary = secondary,
        .secondary_foreground = foreground,
        .muted = secondary,
        .muted_foreground = Color.rgbU8(161, 161, 161),
        .accent = secondary,
        .accent_foreground = foreground,
        .destructive = paletteRose600(),
        .destructive_foreground = foreground,
        .border = border,
        .input = Color.rgba(1.0, 1.0, 1.0, 0.15),
        .ring = ring,
        .sidebar = card,
        .sidebar_foreground = foreground,
        .sidebar_primary = primary,
        .sidebar_primary_foreground = card,
        .sidebar_accent = secondary,
        .sidebar_accent_foreground = foreground,
        .sidebar_border = border,
        .sidebar_ring = ring,
        .chart_1 = Color.rgbU8(38, 38, 38),
        .chart_2 = Color.rgbU8(82, 82, 82),
        .chart_3 = Color.rgbU8(115, 115, 115),
        .chart_4 = Color.rgbU8(161, 161, 161),
        .chart_5 = Color.rgbU8(229, 229, 229),
    };
}

pub fn designDefaultRadius() DesignRadius {
    return .{ .sm = 6.0, .md = 8.0, .lg = 10.0, .xl = 14.0 };
}

pub fn designDefaultMetrics() DesignMetrics {
    return .{
        .card_pad_x = 24.0,
        .card_pad_y = 24.0,
        .card_gap = 24.0,
        .field_gap = 12.0,
        .control_h = 36.0,
        .control_pad_x = 10.0,
        .button_h_sm = 32.0,
        .button_h_default = 36.0,
        .button_h_lg = 40.0,
        .icon_button = 36.0,
        .progress_h = 6.0,
        .slider_thumb = 16.0,
    };
}

pub fn designCanonical() DesignSystem {
    return .{ .colors = designNeutralDarkColors(), .radius = designDefaultRadius(), .metrics = designDefaultMetrics() };
}

pub fn semanticColorsFromDesign(design: DesignSystem) SemanticColors {
    return .{
        .bg = design.colors.background,
        .sidebar = design.colors.sidebar,
        .topbar = design.colors.background.withAlpha(0.30),
        .panel = design.colors.card,
        .row = design.colors.secondary,
        .active = design.colors.muted.withAlpha(0.50),
        .composer = design.colors.input.withAlpha(0.30),
        .text = design.colors.foreground,
        .muted = design.colors.muted_foreground,
        .border = design.colors.border,
        .accent = design.colors.primary,
        .accent_text = design.colors.primary_foreground,
        .success = paletteEmerald500(),
        .warning = paletteAmber500(),
        .danger = design.colors.destructive,
        .info = paletteViolet500(),
    };
}

pub fn stylePresetUserDefault() StylePreset {
    return .{ .scheme = .dark, .accent = .neutral, .radius = .default };
}

pub fn stylePresetAuthorVision() StylePreset {
    return .{ .scheme = .terminal, .accent = .green, .radius = .compact };
}

pub fn resolvedTheme(preset: StylePreset) ResolvedTheme {
    var out = ResolvedTheme{
        .preset = preset,
        .design = designCanonical(),
        .colors = semanticColorsForScheme(preset.scheme),
        .radius = radiusScaleFromPreset(preset.radius),
        .density = .comfortable,
    };
    if (preset.accent != .neutral) out.colors = semanticColorsWithAccent(out.colors, accentColor(preset.accent));
    return out;
}

pub fn resolvedThemeUserDefault() ResolvedTheme {
    return resolvedTheme(stylePresetUserDefault());
}

pub fn themeColor(theme: ResolvedTheme, token: ColorToken) Color {
    return switch (token) {
        .bg => theme.colors.bg,
        .sidebar => theme.colors.sidebar,
        .topbar => theme.colors.topbar,
        .panel => theme.colors.panel,
        .row => theme.colors.row,
        .active => theme.colors.active,
        .composer => theme.colors.composer,
        .text => theme.colors.text,
        .muted => theme.colors.muted,
        .border => theme.colors.border,
        .accent => theme.colors.accent,
        .accent_text => theme.colors.accent_text,
        .success => theme.colors.success,
        .warning => theme.colors.warning,
        .danger => theme.colors.danger,
        .info => theme.colors.info,
    };
}

pub fn designThemeColor(theme: ResolvedTheme, token: DesignColorToken) Color {
    return switch (token) {
        .background => theme.design.colors.background,
        .foreground => theme.design.colors.foreground,
        .card => theme.design.colors.card,
        .card_foreground => theme.design.colors.card_foreground,
        .popover => theme.design.colors.popover,
        .popover_foreground => theme.design.colors.popover_foreground,
        .primary => theme.design.colors.primary,
        .primary_foreground => theme.design.colors.primary_foreground,
        .secondary => theme.design.colors.secondary,
        .secondary_foreground => theme.design.colors.secondary_foreground,
        .muted => theme.design.colors.muted,
        .muted_foreground => theme.design.colors.muted_foreground,
        .accent => theme.design.colors.accent,
        .accent_foreground => theme.design.colors.accent_foreground,
        .destructive => theme.design.colors.destructive,
        .destructive_foreground => theme.design.colors.destructive_foreground,
        .border => theme.design.colors.border,
        .input => theme.design.colors.input,
        .ring => theme.design.colors.ring,
        .sidebar => theme.design.colors.sidebar,
        .sidebar_foreground => theme.design.colors.sidebar_foreground,
        .sidebar_primary => theme.design.colors.sidebar_primary,
        .sidebar_primary_foreground => theme.design.colors.sidebar_primary_foreground,
        .sidebar_accent => theme.design.colors.sidebar_accent,
        .sidebar_accent_foreground => theme.design.colors.sidebar_accent_foreground,
        .sidebar_border => theme.design.colors.sidebar_border,
        .sidebar_ring => theme.design.colors.sidebar_ring,
        .chart_1 => theme.design.colors.chart_1,
        .chart_2 => theme.design.colors.chart_2,
        .chart_3 => theme.design.colors.chart_3,
        .chart_4 => theme.design.colors.chart_4,
        .chart_5 => theme.design.colors.chart_5,
    };
}

const PartialSemantic = struct {
    bg: Color,
    sidebar: Color,
    topbar: Color,
    panel: Color,
    row: Color,
    active: Color,
    composer: Color,
    text: Color,
    muted: Color,
    border: Color,
    accent: Color,
};

fn finishSemantic(base: PartialSemantic) SemanticColors {
    return .{
        .bg = base.bg,
        .sidebar = base.sidebar,
        .topbar = base.topbar,
        .panel = base.panel,
        .row = base.row,
        .active = base.active,
        .composer = base.composer,
        .text = base.text,
        .muted = base.muted,
        .border = base.border,
        .accent = base.accent,
        .accent_text = paletteSky50(),
        .success = paletteEmerald500(),
        .warning = paletteAmber500(),
        .danger = paletteRose600(),
        .info = paletteViolet500(),
    };
}

fn expectApprox(actual: f32, expected: f32) !void {
    try std.testing.expectApproxEqAbs(expected, actual, 0.0001);
}

test "color helpers and scheme codes match C behavior" {
    var color = Color.rgbU8(255, 128, 0);
    try expectApprox(color.r, 1.0);
    try expectApprox(color.g, 128.0 / 255.0);
    try expectApprox(color.b, 0.0);
    try expectApprox(color.a, 1.0);
    color = color.withAlpha(0.25);
    try expectApprox(color.a, 0.25);

    try std.testing.expectEqual(ColorScheme.light, ColorScheme.fromCode(1).?);
    try std.testing.expectEqual(ColorScheme.terminal, ColorScheme.fromCode(2).?);
    try std.testing.expect(ColorScheme.fromCode(99) == null);
    try std.testing.expectEqual(@as(u32, 1), ColorScheme.light.code());
    try std.testing.expectEqual(@as(u32, 2), ColorScheme.terminal.code());
    try std.testing.expectEqual(@as(u32, 0), ColorScheme.dark.code());
}

test "theme cycles radius semantic colors and resolved tokens match C behavior" {
    try std.testing.expectEqual(RadiusPreset.compact, RadiusPreset.none.next());
    try std.testing.expectEqual(RadiusPreset.none, RadiusPreset.soft.next());
    try std.testing.expectEqual(AccentPreset.cyan, AccentPreset.neutral.next());
    try std.testing.expectEqual(AccentPreset.neutral, AccentPreset.amber.next());
    try std.testing.expectEqual(Density.compact, Density.comfortable.next());
    try std.testing.expectEqual(ColorScheme.terminal, ColorScheme.dark.next());
    try std.testing.expectEqual(ColorScheme.dark, ColorScheme.light.next());

    const none = radiusScaleFromPreset(.none);
    const soft = radiusScaleFromPreset(.soft);
    try expectApprox(none.card, 0.0);
    try expectApprox(soft.card, 14.0);
    try expectApprox(soft.pill, 999.0);

    const dark = semanticColorsForScheme(.dark);
    try expectApprox(dark.bg.r, 10.0 / 255.0);
    try expectApprox(dark.sidebar.r, 23.0 / 255.0);
    try expectApprox(dark.border.a, 0.10);

    const terminal = semanticColorsForScheme(.terminal);
    try expectApprox(terminal.bg.r, 0.0);
    try expectApprox(terminal.border.g, 185.0 / 255.0);
    try expectApprox(terminal.border.a, 0.34);

    var preset = stylePresetUserDefault();
    preset.accent = .green;
    const resolved = resolvedTheme(preset);
    try expectApprox(resolved.colors.accent.g, 185.0 / 255.0);
    try expectApprox(resolved.colors.active.a, 0.42);
    try expectApprox(resolved.radius.card, 14.0);
    try std.testing.expectEqual(Density.comfortable, resolved.density);
    try expectApprox(resolved.design.colors.card.r, 23.0 / 255.0);
    try expectApprox(resolved.design.colors.primary.r, 229.0 / 255.0);
    try expectApprox(resolved.design.metrics.control_h, 36.0);
    try expectApprox(designThemeColor(resolved, .input).a, 0.15);
    try expectApprox(themeColor(resolved, .accent).g, resolved.colors.accent.g);
    try expectApprox(themeColor(resolved, .danger).r, 225.0 / 255.0);

    const author = resolvedTheme(stylePresetAuthorVision());
    try std.testing.expectEqual(ColorScheme.terminal, author.preset.scheme);
    try expectApprox(author.radius.control, 6.0);
}

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

pub const Rect = geometry.Rect;

pub const space_1: f32 = 4.0;
pub const space_2: f32 = 6.0;
pub const space_3: f32 = 8.0;
pub const space_4: f32 = 10.0;
pub const space_5: f32 = 12.0;
pub const space_6: f32 = 14.0;
pub const space_7: f32 = 16.0;
pub const space_8: f32 = 18.0;
pub const space_9: f32 = 20.0;
pub const space_10: f32 = 22.0;
pub const space_11: f32 = 24.0;
pub const space_12: f32 = 32.0;
pub const space_13: f32 = 40.0;
pub const space_14: f32 = 48.0;
pub const space_15: f32 = 56.0;
pub const space_16: f32 = 64.0;

pub const card_radius_max = space_6;
pub const card_pad_x = space_11;
pub const card_pad_y = space_11;
pub const component_pad_x_dense = space_5;
pub const component_pad_y_dense = space_4;
pub const component_pad_x = card_pad_x;
pub const component_pad_y = card_pad_y;
pub const component_pad_x_spacious = space_12;
pub const component_pad_y_spacious = space_12;
pub const control_pad_x = space_4;
pub const compact_control_h = space_12;
pub const control_h: f32 = 36.0;
pub const large_control_h = space_13;
pub const row_pad_x = space_6;
pub const row_icon: f32 = 34.0;
pub const row_icon_gap = space_5;
pub const row_text_inset = row_pad_x + row_icon + row_icon_gap;
pub const row_h: f32 = 58.0;
pub const list_row_h = row_h;
pub const menu_row_h = space_14;
pub const command_row_h = space_14;
pub const table_row_h = space_16;
pub const operation_row_h: f32 = 78.0;
pub const narrow_viewport_w: f32 = 520.0;
pub const wide_viewport_w: f32 = 1180.0;
pub const surface_inset_x_narrow = space_4;
pub const surface_inset_y_narrow = space_4;
pub const surface_inset_x = space_6;
pub const surface_inset_y = space_6;
pub const surface_inset_x_wide = space_7;
pub const surface_inset_y_wide = space_7;
pub const surface_viewport_inset = space_4;
pub const surface_panel_gap = space_3;
pub const surface_topbar_h: f32 = 42.0;
pub const workspace_chrome_h: f32 = 34.0;
pub const workspace_gap = space_2;
pub const scrollbar_reserved_w = space_4;
pub const scrollbar_track_w: f32 = 3.0;
pub const scrollbar_hit_w = space_4;
pub const scrollbar_edge_inset = space_2;
pub const min_touch_target: f32 = 32.0;


pub const Padding = struct {
    x: f32,
    y: f32,
};

pub const Tokens = struct {
    card_radius_max: f32,
    card_pad_x: f32,
    card_pad_y: f32,
    component_pad_dense: Padding,
    component_pad: Padding,
    component_pad_spacious: Padding,
    control_pad_x: f32,
    control_h: f32,
    compact_control_h: f32,
    large_control_h: f32,
    row_pad_x: f32,
    row_icon: f32,
    row_icon_gap: f32,
    row_text_inset: f32,
    row_h: f32,
    list_row_h: f32,
    menu_row_h: f32,
    command_row_h: f32,
    table_row_h: f32,
    operation_row_h: f32,
    surface_inset_x: f32,
    surface_inset_y: f32,
    surface_viewport_inset: f32,
    surface_panel_gap: f32,
    surface_topbar_h: f32,
    workspace_chrome_h: f32,
    workspace_gap: f32,
    min_touch_target: f32,
};

pub const ResponsiveGrid = struct {
    bounds: Rect = emptyRect(),
    columns: usize = 0,
    column_w: f32 = 0.0,
    gap_x: f32 = 0.0,
    gap_y: f32 = 0.0,
};

pub const UniformGrid = struct {
    bounds: Rect = emptyRect(),
    columns: usize = 0,
    rows: usize = 0,
    cell_w: f32 = 0.0,
    cell_h: f32 = 0.0,
    gap_x: f32 = 0.0,
    gap_y: f32 = 0.0,
};

pub const ResponsiveSidecar = struct {
    side: Rect = emptyRect(),
    main: Rect = emptyRect(),
    stacked: bool = false,
};

pub const VerticalFlow = struct {
    bounds: Rect = emptyRect(),
    cursor_y: f32 = 0.0,
    gap: f32 = 0.0,

    pub fn next(self: *VerticalFlow, preferred_h: f32) Rect {
        if (preferred_h <= 0.0 or !self.bounds.valid()) return emptyRect();
        const remaining_h = geometry.max(self.bounds.y + self.bounds.h - self.cursor_y, 0.0);
        const height = geometry.min(preferred_h, remaining_h);
        const item = Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, height);
        self.cursor_y += height + self.gap;
        return item;
    }

    pub fn remaining(self: VerticalFlow) Rect {
        if (!self.bounds.valid()) return emptyRect();
        const height = geometry.max(self.bounds.y + self.bounds.h - self.cursor_y, 0.0);
        return Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, height);
    }
};

pub const ScrollViewport = struct {
    viewport: Rect = emptyRect(),
    content: Rect = emptyRect(),
    track: Rect = emptyRect(),
    hit: Rect = emptyRect(),
    thumb: Rect = emptyRect(),
    overflow_h: f32 = 0.0,
    scroll_px: f32 = 0.0,
    scrollable: bool = false,
};

pub fn emptyRect() Rect {
    return Rect.init(0.0, 0.0, 0.0, 0.0);
}

pub fn componentPaddingForDensity(density: Density) Padding {
    return switch (density) {
        .compact => .{ .x = component_pad_x_dense, .y = component_pad_y_dense },
        .spacious => .{ .x = component_pad_x_spacious, .y = component_pad_y_spacious },
        .comfortable => .{ .x = component_pad_x, .y = component_pad_y },
    };
}

pub fn componentContentRect(bounds: Rect, density: Density) Rect {
    const pad = componentPaddingForDensity(density);
    return bounds.inset(pad.x, pad.y);
}

pub fn defaultTokens() Tokens {
    return .{
        .card_radius_max = card_radius_max,
        .card_pad_x = card_pad_x,
        .card_pad_y = card_pad_y,
        .component_pad_dense = componentPaddingForDensity(.compact),
        .component_pad = componentPaddingForDensity(.comfortable),
        .component_pad_spacious = componentPaddingForDensity(.spacious),
        .control_pad_x = control_pad_x,
        .control_h = control_h,
        .compact_control_h = compact_control_h,
        .large_control_h = large_control_h,
        .row_pad_x = row_pad_x,
        .row_icon = row_icon,
        .row_icon_gap = row_icon_gap,
        .row_text_inset = row_text_inset,
        .row_h = row_h,
        .list_row_h = list_row_h,
        .menu_row_h = menu_row_h,
        .command_row_h = command_row_h,
        .table_row_h = table_row_h,
        .operation_row_h = operation_row_h,
        .surface_inset_x = surface_inset_x,
        .surface_inset_y = surface_inset_y,
        .surface_viewport_inset = surface_viewport_inset,
        .surface_panel_gap = surface_panel_gap,
        .surface_topbar_h = surface_topbar_h,
        .workspace_chrome_h = workspace_chrome_h,
        .workspace_gap = workspace_gap,
        .min_touch_target = min_touch_target,
    };
}

pub fn responsiveSidecar(bounds: Rect, min_side_w: f32, preferred_side_w: f32, min_main_w: f32, gap: f32, stacked_side_h: f32) ResponsiveSidecar {
    var layout = ResponsiveSidecar{};
    if (!bounds.valid() or min_side_w <= 0.0 or preferred_side_w < min_side_w or min_main_w <= 0.0 or gap < 0.0 or stacked_side_h <= 0.0) return layout;

    const preferred_total_w = preferred_side_w + gap + min_main_w;
    if (bounds.w >= preferred_total_w) {
        layout.side = Rect.init(bounds.x, bounds.y, preferred_side_w, bounds.h);
        layout.main = Rect.init(bounds.x + preferred_side_w + gap, bounds.y, bounds.w - preferred_side_w - gap, bounds.h);
        return layout;
    }

    const minimum_total_w = min_side_w + gap + min_main_w;
    if (bounds.w >= minimum_total_w) {
        const side_w = geometry.max(min_side_w, bounds.w - gap - min_main_w);
        layout.side = Rect.init(bounds.x, bounds.y, side_w, bounds.h);
        layout.main = Rect.init(bounds.x + side_w + gap, bounds.y, bounds.w - side_w - gap, bounds.h);
        return layout;
    }

    layout.stacked = true;
    const side_h = geometry.min(stacked_side_h, bounds.h);
    const main_y = bounds.y + side_h + gap;
    layout.side = Rect.init(bounds.x, bounds.y, bounds.w, side_h);
    layout.main = Rect.init(bounds.x, main_y, bounds.w, geometry.max(bounds.y + bounds.h - main_y, 0.0));
    return layout;
}

pub fn responsiveGrid(bounds: Rect, min_column_w: f32, max_columns: usize, gap_x: f32, gap_y: f32) ResponsiveGrid {
    var grid = ResponsiveGrid{};
    if (!bounds.valid() or min_column_w <= 0.0 or max_columns == 0 or gap_x < 0.0 or gap_y < 0.0) return grid;
    grid.bounds = bounds;
    grid.columns = 1;
    grid.gap_x = gap_x;
    grid.gap_y = gap_y;
    while (grid.columns < max_columns) {
        const next_columns = grid.columns + 1;
        const required_w = min_column_w * @as(f32, @floatFromInt(next_columns)) + gap_x * @as(f32, @floatFromInt(next_columns - 1));
        if (required_w > bounds.w) break;
        grid.columns = next_columns;
    }
    const total_gap = gap_x * @as(f32, @floatFromInt(grid.columns - 1));
    grid.column_w = geometry.max((bounds.w - total_gap) / @as(f32, @floatFromInt(grid.columns)), 0.0);
    return grid;
}

pub fn responsiveGridCell(grid: ResponsiveGrid, index: usize, row_height: f32) Rect {
    return responsiveGridSpan(grid, index, 1, row_height);
}

pub fn responsiveGridRowCount(grid: ResponsiveGrid, item_count: usize) usize {
    if (grid.columns == 0 or item_count == 0) return 0;
    return (item_count + grid.columns - 1) / grid.columns;
}

pub fn responsiveGridRowHeight(grid: ResponsiveGrid, row_count: usize) f32 {
    if (grid.columns == 0 or row_count == 0 or !grid.bounds.valid()) return 0.0;
    return geometry.max((grid.bounds.h - grid.gap_y * @as(f32, @floatFromInt(row_count - 1))) / @as(f32, @floatFromInt(row_count)), 0.0);
}

pub fn responsiveGridHeight(grid: ResponsiveGrid, item_count: usize, row_height: f32) f32 {
    if (row_height <= 0.0) return 0.0;
    const rows = responsiveGridRowCount(grid, item_count);
    if (rows == 0) return 0.0;
    return row_height * @as(f32, @floatFromInt(rows)) + grid.gap_y * @as(f32, @floatFromInt(rows - 1));
}

pub fn responsiveGridSpan(grid: ResponsiveGrid, index: usize, column_span: usize, row_height: f32) Rect {
    if (grid.columns == 0 or grid.column_w <= 0.0 or row_height <= 0.0 or !grid.bounds.valid()) return emptyRect();
    if (column_span == 0) return emptyRect();
    const column = index % grid.columns;
    const row = index / grid.columns;
    const remaining_columns = grid.columns - column;
    const span = @min(column_span, remaining_columns);
    const width = grid.column_w * @as(f32, @floatFromInt(span)) + grid.gap_x * @as(f32, @floatFromInt(span - 1));
    return Rect.init(
        grid.bounds.x + (grid.column_w + grid.gap_x) * @as(f32, @floatFromInt(column)),
        grid.bounds.y + (row_height + grid.gap_y) * @as(f32, @floatFromInt(row)),
        width,
        row_height,
    );
}

pub fn uniformGrid(bounds: Rect, columns: usize, rows: usize, gap_x: f32, gap_y: f32) UniformGrid {
    var grid = UniformGrid{};
    if (!bounds.valid() or columns == 0 or rows == 0 or gap_x < 0.0 or gap_y < 0.0) return grid;
    const total_gap_x = gap_x * @as(f32, @floatFromInt(columns - 1));
    const total_gap_y = gap_y * @as(f32, @floatFromInt(rows - 1));
    const cell_w = (bounds.w - total_gap_x) / @as(f32, @floatFromInt(columns));
    const cell_h = (bounds.h - total_gap_y) / @as(f32, @floatFromInt(rows));
    if (cell_w <= 0.0 or cell_h <= 0.0) return grid;
    grid.bounds = bounds;
    grid.columns = columns;
    grid.rows = rows;
    grid.cell_w = cell_w;
    grid.cell_h = cell_h;
    grid.gap_x = gap_x;
    grid.gap_y = gap_y;
    return grid;
}

pub fn uniformGridCell(grid: UniformGrid, index: usize) Rect {
    return uniformGridSpan(grid, index, 1, 1);
}

pub fn uniformGridSpan(grid: UniformGrid, index: usize, column_span: usize, row_span: usize) Rect {
    if (grid.columns == 0 or grid.rows == 0 or grid.cell_w <= 0.0 or grid.cell_h <= 0.0 or !grid.bounds.valid()) return emptyRect();
    if (column_span == 0 or row_span == 0) return emptyRect();
    const column = index % grid.columns;
    const row = index / grid.columns;
    if (row >= grid.rows) return emptyRect();
    const columns = @min(column_span, grid.columns - column);
    const rows = @min(row_span, grid.rows - row);
    const width = grid.cell_w * @as(f32, @floatFromInt(columns)) + grid.gap_x * @as(f32, @floatFromInt(columns - 1));
    const height = grid.cell_h * @as(f32, @floatFromInt(rows)) + grid.gap_y * @as(f32, @floatFromInt(rows - 1));
    return Rect.init(
        grid.bounds.x + (grid.cell_w + grid.gap_x) * @as(f32, @floatFromInt(column)),
        grid.bounds.y + (grid.cell_h + grid.gap_y) * @as(f32, @floatFromInt(row)),
        width,
        height,
    );
}

pub fn verticalFlow(bounds: Rect, gap: f32) VerticalFlow {
    if (!bounds.valid() or gap < 0.0) return .{};
    return .{ .bounds = bounds, .cursor_y = bounds.y, .gap = gap };
}

pub fn rowIconSlot(row: Rect) Rect {
    return Rect.init(row.x + row_pad_x, row.y, row_icon, row.h).withHeightCentered(row_icon);
}

pub fn rowTextRect(row: Rect, trailing_reserved_w: f32) Rect {
    const width = geometry.max(row.w - row_text_inset - row_pad_x - trailing_reserved_w, 0.0);
    return Rect.init(row.x + row_text_inset, row.y, width, row.h);
}

pub fn surfacePaddingForWidth(width: f32) Padding {
    if (width <= narrow_viewport_w) return .{ .x = surface_inset_x_narrow, .y = surface_inset_y_narrow };
    if (width >= wide_viewport_w) return .{ .x = surface_inset_x_wide, .y = surface_inset_y_wide };
    return .{ .x = surface_inset_x, .y = surface_inset_y };
}

pub fn surfaceContentRect(bounds: Rect) Rect {
    const pad = surfacePaddingForWidth(bounds.w);
    return bounds.inset(pad.x, pad.y);
}

pub fn systemSurfaceSafeRect(bounds: Rect) Rect {
    return bounds.inset(surface_viewport_inset, surface_viewport_inset);
}

pub fn centeredSystemPanel(safe: Rect, min_w: f32, max_w: f32, preferred_h: f32, min_h: f32) Rect {
    const panel_w = if (safe.w >= min_w) geometry.clamp(safe.w, min_w, max_w) else geometry.max(safe.w, 0.0);
    const panel_h = if (safe.h >= min_h) geometry.max(geometry.min(preferred_h, safe.h), min_h) else geometry.max(safe.h, 0.0);
    return Rect.init(safe.x + (safe.w - panel_w) * 0.5, safe.y + (safe.h - panel_h) * 0.5, panel_w, panel_h);
}

pub fn scrollContentRect(bounds: Rect, padding_trbl: ?*const [4]f32) Rect {
    const padding = padding_trbl orelse return Rect.init(bounds.x, bounds.y, 0.0, 0.0);
    const top = padding[0];
    const edge_right = padding[1];
    const bottom = padding[2];
    const left = padding[3];
    return Rect.init(
        bounds.x + left,
        bounds.y + top,
        geometry.max(bounds.w - left - edge_right - scrollbar_reserved_w, 0.0),
        geometry.max(bounds.h - top - bottom, 0.0),
    );
}

pub fn scrollbarTrackRect(bounds: Rect, content: Rect) Rect {
    return Rect.init(bounds.x + bounds.w - scrollbar_edge_inset, content.y, scrollbar_track_w, content.h);
}

pub fn scrollbarHitRect(track: Rect) Rect {
    return Rect.init(track.x - (scrollbar_hit_w - track.w), track.y, scrollbar_hit_w, track.h);
}

pub fn scrollViewport(viewport: Rect, content_h: f32, scroll: f32, min_thumb_h: f32) ScrollViewport {
    var result = ScrollViewport{};
    if (!viewport.valid() or content_h < 0.0 or min_thumb_h < 0.0) return result;
    result.viewport = viewport;
    result.overflow_h = geometry.max(content_h - viewport.h, 0.0);
    result.scroll_px = result.overflow_h * geometry.clamp(scroll, 0.0, 1.0);
    result.content = Rect.init(viewport.x, viewport.y - result.scroll_px, viewport.w, content_h);
    result.scrollable = content_h > viewport.h;
    if (!result.scrollable) return result;
    result.track = scrollbarTrackRect(viewport, viewport);
    result.hit = scrollbarHitRect(result.track);
    var thumb_h = geometry.max(viewport.h * (viewport.h / content_h), min_thumb_h);
    thumb_h = geometry.min(thumb_h, result.track.h);
    const thumb_y = result.track.y + (result.track.h - thumb_h) * geometry.clamp(scroll, 0.0, 1.0);
    result.thumb = Rect.init(result.track.x, thumb_y, result.track.w, thumb_h);
    return result;
}

fn expectRect(actual: Rect, expected: Rect) !void {
    try expectApprox(actual.x, expected.x);
    try expectApprox(actual.y, expected.y);
    try expectApprox(actual.w, expected.w);
    try expectApprox(actual.h, expected.h);
}

test "spacing default matches tokens" {
    const tokens = defaultTokens();
    try expectApprox(tokens.card_radius_max, card_radius_max);
    try expectApprox(tokens.card_pad_x, card_pad_x);
    try expectApprox(tokens.control_h, 36.0);
    try expectApprox(tokens.component_pad.x, component_pad_x);
    try expectApprox(tokens.row_text_inset, row_text_inset);
    try expectApprox(tokens.list_row_h, list_row_h);
    try expectApprox(tokens.workspace_gap, workspace_gap);
    try expectApprox(tokens.min_touch_target, min_touch_target);
}

test "component density padding and surface spacing" {
    const dense = componentPaddingForDensity(.compact);
    const normal = componentPaddingForDensity(.comfortable);
    const spacious = componentPaddingForDensity(.spacious);
    try std.testing.expect(dense.x < normal.x);
    try std.testing.expect(dense.y < normal.y);
    try std.testing.expect(normal.x < spacious.x);
    try std.testing.expect(normal.y < spacious.y);
    try expectApprox(normal.x, card_pad_x);
    try expectApprox(normal.y, card_pad_y);
    try expectRect(
        componentContentRect(Rect.init(10.0, 20.0, 220.0, 140.0), .comfortable),
        Rect.init(10.0 + normal.x, 20.0 + normal.y, 220.0 - normal.x * 2.0, 140.0 - normal.y * 2.0),
    );

    const narrow = surfacePaddingForWidth(390.0);
    const surface_normal = surfacePaddingForWidth(900.0);
    const wide = surfacePaddingForWidth(1440.0);
    try expectApprox(narrow.x, surface_inset_x_narrow);
    try expectApprox(surface_normal.x, surface_inset_x);
    try expectApprox(wide.x, surface_inset_x_wide);
    try std.testing.expect(narrow.x < surface_normal.x);
    try std.testing.expect(surface_normal.x < wide.x);
    try expectRect(surfaceContentRect(Rect.init(0.0, 0.0, 390.0, 260.0)), Rect.init(10.0, 10.0, 370.0, 240.0));
}

test "responsive grid derives columns and cell bounds" {
    const wide = responsiveGrid(Rect.init(10.0, 20.0, 720.0, 400.0), 220.0, 3, 16.0, 18.0);
    const narrow = responsiveGrid(Rect.init(10.0, 20.0, 360.0, 400.0), 220.0, 3, 16.0, 18.0);
    try std.testing.expectEqual(@as(usize, 1), narrow.columns);
    try expectApprox(narrow.column_w, 360.0);
    try std.testing.expectEqual(@as(usize, 3), wide.columns);
    try expectApprox(wide.column_w, (720.0 - 32.0) / 3.0);
    try std.testing.expectEqual(@as(usize, 2), responsiveGridRowCount(wide, 5));
    try expectApprox(responsiveGridRowHeight(wide, 2), (400.0 - 18.0) / 2.0);
    try expectApprox(responsiveGridHeight(wide, 5, 96.0), 96.0 * 2.0 + 18.0);
    try expectRect(responsiveGridCell(wide, 4, 96.0), Rect.init(10.0 + wide.column_w + 16.0, 20.0 + 96.0 + 18.0, wide.column_w, 96.0));
    try expectRect(responsiveGridSpan(wide, 3, 2, 96.0), Rect.init(10.0, 20.0 + 96.0 + 18.0, wide.column_w * 2.0 + 16.0, 96.0));
}

test "responsive sidecar adapts between horizontal and stacked" {
    const wide = responsiveSidecar(Rect.init(10.0, 20.0, 760.0, 420.0), 160.0, 220.0, 300.0, 24.0, 120.0);
    const compressed = responsiveSidecar(Rect.init(10.0, 20.0, 500.0, 420.0), 160.0, 220.0, 300.0, 24.0, 120.0);
    const stacked = responsiveSidecar(Rect.init(10.0, 20.0, 420.0, 420.0), 160.0, 220.0, 300.0, 24.0, 120.0);
    try std.testing.expect(!wide.stacked);
    try expectRect(wide.side, Rect.init(10.0, 20.0, 220.0, 420.0));
    try expectApprox(wide.main.x, wide.side.x + wide.side.w + 24.0);
    try std.testing.expect(!compressed.stacked);
    try expectApprox(compressed.side.w, 176.0);
    try expectApprox(compressed.main.w, 300.0);
    try std.testing.expect(stacked.stacked);
    try expectRect(stacked.side, Rect.init(10.0, 20.0, 420.0, 120.0));
    try expectApprox(stacked.main.y, stacked.side.y + stacked.side.h + 24.0);
}

test "uniform grid vertical flow row and scroll geometry" {
    const grid = uniformGrid(Rect.init(10.0, 20.0, 720.0, 260.0), 3, 2, 16.0, 18.0);
    try std.testing.expectEqual(@as(usize, 3), grid.columns);
    try std.testing.expectEqual(@as(usize, 2), grid.rows);
    try expectApprox(grid.cell_w, (720.0 - 32.0) / 3.0);
    try expectApprox(grid.cell_h, (260.0 - 18.0) / 2.0);
    try expectRect(uniformGridCell(grid, 4), Rect.init(10.0 + grid.cell_w + 16.0, 20.0 + grid.cell_h + 18.0, grid.cell_w, grid.cell_h));
    try expectRect(uniformGridSpan(grid, 3, 2, 1), Rect.init(10.0, 20.0 + grid.cell_h + 18.0, grid.cell_w * 2.0 + 16.0, grid.cell_h));

    var flow = verticalFlow(Rect.init(10.0, 20.0, 320.0, 260.0), 12.0);
    const first = flow.next(110.0);
    const second = flow.next(80.0);
    const remaining_rect = flow.remaining();
    try expectRect(first, Rect.init(10.0, 20.0, 320.0, 110.0));
    try expectRect(second, Rect.init(10.0, 20.0 + 110.0 + 12.0, 320.0, 80.0));
    try expectRect(remaining_rect, Rect.init(10.0, second.y + second.h + 12.0, 320.0, 260.0 - 110.0 - 80.0 - 12.0 * 2.0));
}

test "system panel row and scroll geometry" {
    const row = Rect.init(10.0, 20.0, 360.0, row_h);
    const icon = rowIconSlot(row);
    const text = rowTextRect(row, 120.0);
    try expectRect(icon, Rect.init(24.0, 32.0, row_icon, row_icon));
    try expectApprox(text.x, row.x + row_text_inset);
    try expectApprox(text.w, row.w - row_text_inset - row_pad_x - 120.0);

    const safe = systemSurfaceSafeRect(Rect.init(0.0, 0.0, 360.0, 260.0));
    const panel = centeredSystemPanel(safe, 320.0, 520.0, 320.0, 220.0);
    try expectRect(safe, Rect.init(10.0, 10.0, 340.0, 240.0));
    try std.testing.expect(panel.x >= safe.x);
    try std.testing.expect(panel.y >= safe.y);
    try std.testing.expect(panel.x + panel.w <= safe.x + safe.w);
    try std.testing.expect(panel.y + panel.h <= safe.y + safe.h);

    const bounds = Rect.init(10.0, 20.0, 220.0, 180.0);
    const padding = [4]f32{ 12.0, 14.0, 16.0, 18.0 };
    const content = scrollContentRect(bounds, &padding);
    const track = scrollbarTrackRect(bounds, content);
    const hit = scrollbarHitRect(track);
    try expectRect(content, Rect.init(28.0, 32.0, 220.0 - 18.0 - 14.0 - scrollbar_reserved_w, 180.0 - 12.0 - 16.0));
    try expectApprox(track.w, scrollbar_track_w);
    try expectApprox(track.h, content.h);
    try expectApprox(hit.w, scrollbar_hit_w);
    try expectApprox(hit.h, track.h);
    try std.testing.expect(hit.x <= track.x);

    const viewport = scrollViewport(bounds, 360.0, 0.25, 30.0);
    try std.testing.expect(viewport.scrollable);
    try expectApprox(viewport.overflow_h, 180.0);
    try expectApprox(viewport.scroll_px, 45.0);
    try expectRect(viewport.content, Rect.init(bounds.x, bounds.y - 45.0, bounds.w, 360.0));
    try expectRect(viewport.thumb, Rect.init(track.x, 42.5, track.w, 90.0));
}

pub fn centered(bounds: ui.Rect, max_w: f32) ui.Rect {
    const width = @min(max_w, @max(1.0, bounds.w - content_pad * 2.0));
    return ui.Rect.init(bounds.x + (bounds.w - width) * 0.5, bounds.y, width, bounds.h);
}
