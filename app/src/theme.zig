const std = @import("std");

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
