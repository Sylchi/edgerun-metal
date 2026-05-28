const std = @import("std");
const bytes = @import("bytes.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const text_component = @import("ui/components/Text.zig");
const badge_component = @import("ui/components/Badge.zig");
const card_component = @import("ui/components/Card.zig");
const icon_component = @import("ui/components/Icon.zig");
const app_chrome = @import("app_chrome.zig");
const design = @import("app_design.zig");
const app_layout = @import("app_layout.zig");
const app_navigation = @import("app_navigation.zig");

const max_columns: usize = 4;
const header_h: f32 = app_chrome.header_h;
const section_gap: f32 = 72.0;
const content_wide: f32 = design.content_wide;
const content_pad: f32 = design.content_pad;
const radius: f32 = design.surface_radius;
const terminal_h: f32 = 338.0;
const page_top_pad: f32 = 48.0;
const hero_copy_min_w: f32 = 460.0;
const hero_terminal_min_w: f32 = 420.0;
const hero_terminal_max_w: f32 = 520.0;
const hero_split_gap: f32 = 92.0;
const hero_split_min_w: f32 = hero_terminal_min_w + hero_split_gap + hero_copy_min_w;
const hero_split_terminal_y: f32 = 76.0;
const hero_split_copy_y: f32 = 78.0;
const hero_split_min_h: f32 = 612.0;
const hero_stacked_copy_y: f32 = 44.0;
const hero_stacked_copy_max_w: f32 = 860.0;
const hero_stacked_paragraph_max_w: f32 = 560.0;
const hero_stacked_button_y: f32 = 374.0;
const hero_stacked_terminal_y: f32 = 444.0;
const hero_bottom_pad: f32 = 34.0;
const hero_primary_button_weight: f32 = 0.54;
const hero_button_gap: f32 = 14.0;
const action_button_h: f32 = 42.0;
const action_pair_min_w: f32 = 260.0;
const hero_inline_title_min_w: f32 = 720.0;
const hero_inline_title_first_w: f32 = 286.0;
const hero_inline_title_accent_w: f32 = 382.0;
const hero_inline_title_gap: f32 = 12.0;
const hero_mobile_title_max_w: f32 = 520.0;
const hero_mobile_title_line_h: f32 = 46.0;
const hero_mobile_title_average_w: f32 = 24.0;
const title_weight_offset: f32 = 0.75;
const terminal_line_h: f32 = 22.0;
const terminal_line_reveal_ms: f32 = 250.0;
const terminal_hold_ms: f32 = 1600.0;
const terminal_cursor_w: f32 = 8.0;
const terminal_cursor_h: f32 = 14.0;
const terminal_cursor_alpha: u8 = 190;
const terminal_hint_gap: f32 = 14.0;
const impact_card_count: usize = 3;
const impact_card_gap: f32 = 14.0;
const impact_card_h: f32 = 190.0;
const impact_card_min_w: f32 = 168.0;
const impact_split_min_w: f32 = 1120.0;
const impact_split_text_fraction: f32 = 0.48;
const impact_split_gap_fraction: f32 = 0.06;
const impact_heading_y: f32 = 44.0;
const impact_heading_h: f32 = 74.0;
const impact_copy_y: f32 = 138.0;
const impact_copy_h: f32 = 108.0;
const impact_cards_split_y: f32 = 36.0;
const impact_cards_stacked_y: f32 = 286.0;
const traffic_total_percent: f32 = 100.0;
const traffic_pie_max_size: f32 = 190.0;
const traffic_pie_fraction: f32 = 0.36;
const traffic_legend_gap: f32 = 30.0;
const traffic_legend_row_h: f32 = 24.0;
const traffic_legend_swatch: f32 = 8.0;
const stats_compact_w: f32 = 620.0;
const stats_compact_h: f32 = 190.0;
const stats_default_h: f32 = 138.0;
const stats_compact_y: f32 = 32.0;
const stats_default_y: f32 = 38.0;
const stats_row_h: f32 = 66.0;
const node_land_alpha: u8 = 5;
const node_online_halo_alpha: u8 = 12;
const node_offline_halo_alpha: u8 = 8;

const palette = design.palette;
const fill = app_layout.fill;
const stroke = app_layout.stroke;
const text = app_layout.text;

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    frame_ms: f32 = 0.0,
    public_identity: []const u8 = "pending",
    public_identity_ready: bool = false,
};

const TerminalLine = struct {
    value: []const u8,
    color: ui.Color,
};

const terminal_lines = [_]TerminalLine{
    .{ .value = "$ edgerun boot", .color = palette.dim },
    .{ .value = "app wasm loaded", .color = palette.primary },
    .{ .value = "compiler wasm embedded", .color = palette.primary },
    .{ .value = "source object mounted", .color = palette.text },
    .{ .value = "ui system: repo-owned", .color = palette.text },
    .{ .value = "npm packages: 0", .color = palette.primary },
    .{ .value = "host filesystem: none", .color = palette.primary },
    .{ .value = "web host: byte bridge only", .color = palette.dim },
    .{ .value = "ready to compile next artifact", .color = palette.primary },
    .{ .value = "runs through web/native/cpu/gpu", .color = palette.text },
};
const terminal_identity_line_index: usize = 8;
const terminal_line_count: usize = terminal_lines.len + 1;

const SectionKind = enum {
    hero,
    stats,
    problem,
    principles,
    architecture,
    impact,
    cta,
    footer,
};

const Section = struct {
    kind: SectionKind,
    gap_after: f32,
};

const sections = [_]Section{
    .{ .kind = .hero, .gap_after = 0.0 },
    .{ .kind = .stats, .gap_after = section_gap },
    .{ .kind = .problem, .gap_after = section_gap },
    .{ .kind = .principles, .gap_after = section_gap },
    .{ .kind = .architecture, .gap_after = section_gap },
    .{ .kind = .impact, .gap_after = section_gap },
    .{ .kind = .cta, .gap_after = 56.0 },
    .{ .kind = .footer, .gap_after = 0.0 },
};

pub fn contentHeight(width: f32) f32 {
    const bounds = ui.Rect.init(0.0, 0.0, @max(1.0, width), 1.0);
    return flowSections(null, null, bounds, .{}) catch unreachable;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.bg, 0.0);

    const content = app_layout.centered(bounds, content_wide, content_pad);
    const page_y = header_h - state.scroll_y;

    const map_y = page_y;
    const map_h = page_top_pad + heroSectionHeight(content.w) + hero_bottom_pad;
    try renderNodeMap(scene, ui.Rect.init(bounds.x, map_y, bounds.w, map_h), state, false);

    const page_clip = ui.Rect.init(bounds.x, bounds.y + header_h, bounds.w, @max(1.0, bounds.h - header_h));
    if (try scene.pushClip(page_clip)) {
        defer scene.popClip();

        _ = try flowSections(scene, collector, ui.Rect.init(bounds.x, page_y, bounds.w, bounds.h), state);
    }

    try renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content);
}

fn flowSections(scene: ?*ui.Scene, collector: ?*interaction.Collector, bounds: ui.Rect, state: State) (ui.RenderError || interaction.Error)!f32 {
    const content = app_layout.centered(bounds, content_wide, content_pad);
    var cursor_y = bounds.y + page_top_pad;
    for (sections) |section| {
        const section_h = sectionHeight(content, section.kind);
        const section_bounds = switch (section.kind) {
            .stats => ui.Rect.init(bounds.x, cursor_y, bounds.w, section_h),
            .footer => ui.Rect.init(bounds.x, cursor_y, bounds.w, section_h),
            else => ui.Rect.init(content.x, cursor_y, content.w, section_h),
        };
        if (scene) |target| {
            switch (section.kind) {
                .hero => try renderHero(target, collector.?, section_bounds, state),
                .stats => try renderStats(target, section_bounds),
                .problem => try renderProblem(target, section_bounds),
                .principles => try renderPrinciples(target, section_bounds),
                .architecture => try renderArchitecture(target, collector.?, section_bounds),
                .impact => try renderImpact(target, section_bounds),
                .cta => try renderCta(target, collector.?, section_bounds),
                .footer => try renderFooter(target, section_bounds, content),
            }
        }
        cursor_y += section_h + section.gap_after;
    }
    return cursor_y;
}

fn sectionHeight(content: ui.Rect, kind: SectionKind) f32 {
    return switch (kind) {
        .hero => heroSectionHeight(content.w),
        .stats => if (content.w < stats_compact_w) stats_compact_h else stats_default_h,
        .problem => if (content.w > 760.0) 420.0 else 720.0,
        .principles => if (content.w > 720.0) 430.0 else 682.0,
        .architecture => if (content.w > 760.0) 500.0 else 760.0,
        .impact => impactSectionHeight(content.w),
        .cta => 280.0,
        .footer => 250.0,
    };
}

fn renderHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try app_chrome.renderHeader(scene, collector, bounds, content, .none);
}

fn renderHero(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) (ui.RenderError || interaction.Error)!void {
    const layout = heroLayout(bounds);
    const stacked = bounds.w < hero_split_min_w;

    try renderTerminal(scene, collector, layout.terminal, state);
    try renderTerminalHint(scene, layout.terminal, state, stacked);

    const badge_w = @min(300.0, layout.copy.w);
    const badge_x = if (stacked) layout.copy.x + (layout.copy.w - badge_w) * 0.5 else layout.copy.x;
    const badge = ui.Rect.init(badge_x, layout.copy.y, badge_w, 28.0);
    try nativeBadge(scene, badge, "Self-compiling. Zero dependency chain.");
    try icon_component.Icon.named(.terminal).renderColor(scene, ui.Rect.init(badge.x + 12.0, badge.y + 5.0, 18.0, 18.0), palette.primary);

    if (stacked and layout.copy.w < hero_mobile_title_max_w) {
        try titleMobile(scene, ui.Rect.init(layout.copy.x, layout.copy.y + 58.0, layout.copy.w, 54.0), "The App", palette.text);
        try titleMobile(scene, ui.Rect.init(layout.copy.x, layout.copy.y + 118.0, layout.copy.w, 102.0), "Builds Itself", palette.primary);
    } else if (stacked and layout.copy.w >= hero_inline_title_min_w) {
        const title_w = hero_inline_title_first_w + hero_inline_title_gap + hero_inline_title_accent_w;
        const title_x = layout.copy.x + (layout.copy.w - title_w) * 0.5;
        try titleLine(scene, ui.Rect.init(title_x, layout.copy.y + 58.0, hero_inline_title_first_w, 58.0), "The App", palette.text);
        try titleLine(scene, ui.Rect.init(title_x + hero_inline_title_first_w + hero_inline_title_gap, layout.copy.y + 58.0, hero_inline_title_accent_w, 58.0), "Builds Itself", palette.primary);
    } else {
        try title(scene, ui.Rect.init(layout.copy.x, layout.copy.y + 58.0, layout.copy.w, 92.0), "The App");
        try titleAccent(scene, ui.Rect.init(layout.copy.x, layout.copy.y + 118.0, layout.copy.w, 116.0), "Builds Itself");
    }
    const paragraph_w = if (stacked) @min(layout.copy.w, hero_stacked_paragraph_max_w) else @min(layout.copy.w, 500.0);
    const paragraph_x = if (stacked) layout.copy.x + (layout.copy.w - paragraph_w) * 0.5 else layout.copy.x;
    try heroParagraph(scene, ui.Rect.init(paragraph_x, layout.copy.y + 244.0, paragraph_w, 88.0), "EdgeRun carries its compiler, source object, UI system, object store, and receipts inside the app. Edit source, build, and run the next artifact.");
    const actions = actionPairBounds(if (stacked) layout.copy else ui.Rect.init(layout.copy.x, layout.button_y, layout.copy.w, action_button_h), layout.button_y);
    const source = app_navigation.subNavBinding(.source);
    const docs = app_navigation.subNavBinding(.docs);
    try app_chrome.renderNavItem(scene, collector, .{
        .kind = .top_text,
        .binding = source,
        .bounds = actions.primary,
        .active = false,
        .label = "View Source",
        .variant = .primary,
        .icon_slot = icon_component.IconSlot.of(.trailing, icon_component.Icon.named(.chevron_right)),
    });
    try app_chrome.renderNavItem(scene, collector, .{
        .kind = .top_text,
        .binding = docs,
        .bounds = actions.secondary,
        .active = false,
        .label = "Read Docs",
        .variant = .outline,
    });
}

const HeroLayout = struct {
    terminal: ui.Rect,
    copy: ui.Rect,
    button_y: f32,
};

fn heroLayout(bounds: ui.Rect) HeroLayout {
    if (bounds.w >= hero_split_min_w) {
        const terminal_w = @min(hero_terminal_max_w, @max(hero_terminal_min_w, bounds.w * 0.44));
        const copy_x = bounds.x + terminal_w + hero_split_gap;
        const copy_w = @max(hero_copy_min_w, bounds.x + bounds.w - copy_x);
        const terminal = ui.Rect.init(bounds.x, bounds.y + hero_split_terminal_y, terminal_w, terminal_h);
        const copy = ui.Rect.init(copy_x, bounds.y + hero_split_copy_y, copy_w, 360.0);
        return .{
            .terminal = terminal,
            .copy = copy,
            .button_y = copy.y + 368.0,
        };
    }

    const copy_w = @min(bounds.w, hero_stacked_copy_max_w);
    const copy_x = bounds.x + (bounds.w - copy_w) * 0.5;
    return .{
        .terminal = ui.Rect.init(bounds.x, bounds.y + hero_stacked_terminal_y, bounds.w, terminal_h),
        .copy = ui.Rect.init(copy_x, bounds.y + hero_stacked_copy_y, copy_w, hero_stacked_terminal_y - hero_stacked_copy_y),
        .button_y = bounds.y + hero_stacked_button_y,
    };
}

fn heroSectionHeight(width: f32) f32 {
    const bounds = ui.Rect.init(0.0, 0.0, width, 1.0);
    const layout = heroLayout(bounds);
    const terminal_bottom = layout.terminal.y + layout.terminal.h;
    const actions = actionPairBounds(layout.copy, layout.button_y);
    const actions_bottom = @max(actions.primary.y + actions.primary.h, actions.secondary.y + actions.secondary.h);
    const measured = @max(terminal_bottom, actions_bottom) - bounds.y + hero_bottom_pad;
    return if (width >= hero_split_min_w) @max(measured, hero_split_min_h) else measured;
}

fn renderTerminal(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) (ui.RenderError || interaction.Error)!void {
    try nativeCard(scene, bounds, "", "");
    const header = ui.Rect.init(bounds.x, bounds.y, bounds.w, 40.0);
    try fill(scene, header, palette.card_alt, radius);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + 39.0, bounds.w, 1.0), palette.border, 0.0);
    try fill(scene, ui.Rect.init(header.x + 14.0, header.y + 14.0, 10.0, 10.0), palette.danger, 5.0);
    try fill(scene, ui.Rect.init(header.x + 30.0, header.y + 14.0, 10.0, 10.0), palette.yellow, 5.0);
    try fill(scene, ui.Rect.init(header.x + 46.0, header.y + 14.0, 10.0, 10.0), palette.primary, 5.0);
    try text(scene, header.x + 70.0, header.y + 13.0, 140.0, 12.0, "edgerun - node", palette.dim);

    const visible = terminalVisibleLineCount(state.frame_ms);
    var y = bounds.y + 62.0;
    for (terminal_lines[0..@min(visible, terminal_identity_line_index)]) |line| {
        try text(scene, bounds.x + 24.0, y, bounds.w - 48.0, 14.0, line.value, line.color);
        y += terminal_line_h;
    }
    if (visible > terminal_identity_line_index) {
        const identity_h: f32 = if (state.public_identity_ready) 36.0 else 14.0;
        try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + 24.0, y, bounds.w - 48.0, identity_h), state.public_identity, palette.primary, .{
            .line_height = 16.0,
            .average_char_width = 8.2,
            .max_lines = 2,
        });
        y += if (state.public_identity_ready) 38.0 else terminal_line_h;
    }
    if (visible > terminal_identity_line_index + 1) {
        for (terminal_lines[terminal_identity_line_index..@min(visible - 1, terminal_lines.len)]) |line| {
            try text(scene, bounds.x + 24.0, y, bounds.w - 48.0, 14.0, line.value, line.color);
            y += terminal_line_h;
        }
    }
    var cursor_color = palette.primary;
    cursor_color.a = terminal_cursor_alpha;
    try fill(scene, ui.Rect.init(bounds.x + 24.0, y, terminal_cursor_w, terminal_cursor_h), cursor_color, 1.0);

    if (!state.public_identity_ready) {
        const reveal = ui.Rect.init(bounds.x + 24.0, bounds.y + bounds.h - 54.0, 196.0, 32.0);
        try app_chrome.renderActionItem(scene, collector, .{
            .id = app_navigation.reveal_identity_button_id,
            .bounds = reveal,
            .label = "Click to Reveal ID",
            .variant = .outline,
        });
    }
}

fn renderTerminalHint(scene: *ui.Scene, terminal: ui.Rect, state: State, stacked: bool) ui.RenderError!void {
    const hint_y = terminal.y + terminal.h + terminal_hint_gap;
    const hint_w = if (stacked) terminal.w else @min(terminal.w, 480.0);
    const hint_x = if (stacked) terminal.x + (terminal.w - hint_w) * 0.5 else terminal.x;
    const message = if (state.public_identity_ready)
        "This app runtime has a live identity, embedded compiler bytes, and a source workspace in its own memory."
    else
        "Reveal creates an ephemeral identity inside the WASM app. The host only presents the surface.";
    try text_component.Text.renderWrapped(scene, ui.Rect.init(hint_x, hint_y, hint_w, 36.0), message, palette.dim, .{
        .line_height = 18.0,
        .average_char_width = 8.5,
        .max_lines = 2,
    });
}

fn renderStats(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.card, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 1.0), palette.border, 0.0);
    const content = app_layout.centered(bounds, content_wide, content_pad);
    const stats = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "1", "", "App Artifact" },
        .{ "0", "", "Package Installs" },
        .{ "5", "", "Render Targets" },
        .{ "1", "", "Compiler Loop" },
    };
    const compact = content.w < stats_compact_w;
    const cols: usize = if (compact) 2 else columns(content, 4, 18.0);
    const start_y = bounds.y + if (compact) stats_compact_y else stats_default_y;
    for (stats, 0..) |item, index| {
        const row = index / cols;
        const col = index % cols;
        const r = app_layout.columnBounds(content, cols, 18.0, col, start_y + @as(f32, @floatFromInt(row)) * stats_row_h, stats_row_h);
        try text(scene, r.x, r.y, r.w, 24.0, item[0], palette.text);
        try text(scene, r.x + 74.0, r.y + 4.0, 72.0, 16.0, item[1], palette.primary);
        try text(scene, r.x, r.y + 34.0, r.w, 14.0, item[2], palette.dim);
    }
}

fn renderProblem(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const compact = bounds.w <= 760.0;
    const left = if (compact) ui.Rect.init(bounds.x, bounds.y, bounds.w, 360.0) else ui.Rect.init(bounds.x, bounds.y, bounds.w * 0.48, bounds.h);
    const right = if (compact) ui.Rect.init(bounds.x, bounds.y + 420.0, bounds.w, 280.0) else ui.Rect.init(bounds.x + bounds.w * 0.56, bounds.y, bounds.w * 0.44, bounds.h);
    try tag(scene, ui.Rect.init(left.x, left.y, 104.0, 24.0), "THE PROBLEM", palette.danger);
    try heading(scene, ui.Rect.init(left.x, left.y + 44.0, left.w, 74.0), "Apps Became", "Dependency Towers");
    try paragraph(scene, ui.Rect.init(left.x, left.y + 138.0, left.w, 82.0), "Modern apps often need clouds, registries, build services, host filesystems, web frameworks, and platform accounts before they can even begin.");
    try problemItem(scene, ui.Rect.init(left.x, left.y + 250.0, left.w, 48.0), "1", "Builds Live Elsewhere", "The compiler, source, and release path are usually outside the app.");
    try problemItem(scene, ui.Rect.init(left.x, left.y + 310.0, left.w, 48.0), "2", "UI Is Borrowed", "The surface depends on framework and host behavior.");
    try problemItem(scene, ui.Rect.init(left.x, left.y + 370.0, left.w, 48.0), "3", "Trust Is Ambient", "Permissions and updates are hard to explain after the fact.");
    try traffic(scene, right);
}

fn renderPrinciples(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try tag(scene, ui.Rect.init(bounds.x + bounds.w * 0.5 - 52.0, bounds.y, 104.0, 24.0), "ARCHITECTURE", palette.primary);
    try alignedText(scene, bounds.x, bounds.y + 44.0, bounds.w, 26.0, "One App Loop", palette.text, .center);
    try alignedText(scene, bounds.x, bounds.y + 82.0, bounds.w, 16.0, "Source, compiler, UI, runtime, receipts.", palette.dim, .center);
    const cards_y = bounds.y + 140.0;
    const cols = columns(bounds, if (bounds.w > 720.0) 2 else 1, 16.0);
    const items = [_]struct { icon_component.Icon, []const u8, []const u8, []const u8 }{
        .{ icon_component.Icon.named(.code), "Compiler Inside", "The app ships with compiler bytes.", "compile(source_object)" },
        .{ icon_component.Icon.named(.apps), "Built-In UI", "Components render through one IR.", "scene -> render_ir" },
        .{ icon_component.Icon.named(.shield), "Receipts For Work", "Execution leaves a checkable trail.", "work -> receipt" },
        .{ icon_component.Icon.named(.cpu), "Runs Across Targets", "Web, native, CPU, GPU, hardware.", "present(target)" },
    };
    for (items, 0..) |item, index| {
        const row: usize = index / cols;
        const col: usize = index % cols;
        const r = app_layout.columnBounds(bounds, cols, 16.0, col, cards_y + @as(f32, @floatFromInt(row)) * 126.0, 110.0);
        try principleCard(scene, r, item[0], item[1], item[2], item[3]);
    }
}

fn renderArchitecture(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    const compact = bounds.w <= 760.0;
    const left = if (compact) ui.Rect.init(bounds.x, bounds.y, bounds.w, 250.0) else ui.Rect.init(bounds.x, bounds.y, bounds.w * 0.36, bounds.h);
    const right = if (compact) ui.Rect.init(bounds.x, bounds.y + 306.0, bounds.w, 440.0) else ui.Rect.init(bounds.x + bounds.w * 0.43, bounds.y, bounds.w * 0.57, bounds.h);
    try tag(scene, ui.Rect.init(left.x, left.y, 64.0, 24.0), "STACK", palette.primary);
    try heading(scene, ui.Rect.init(left.x, left.y + 44.0, left.w, 74.0), "No Package", "Tower.");
    try paragraph(scene, ui.Rect.init(left.x, left.y + 138.0, left.w, 96.0), "The web host loads one WASM app. That app owns the source workspace, compiler bytes, UI scene, render buffers, and release artifact.");
    const source_button_y: f32 = if (compact) 218.0 else 264.0;
    const source_button = actionButtonBounds(left, left.y + source_button_y, 180.0);
    const source = app_navigation.subNavBinding(.source);
    try app_chrome.renderNavItem(scene, collector, .{
        .kind = .top_text,
        .binding = source,
        .bounds = source_button,
        .active = false,
        .label = "Open Source",
        .variant = .outline,
        .icon_slot = icon_component.IconSlot.of(.trailing, icon_component.Icon.named(.chevron_right)),
    });
    const stack = [_]struct { []const u8, []const u8, ui.Color }{
        .{ "app wasm", "tiny runtime and UI shell", palette.primary },
        .{ "compiler wasm", "embedded Zig-to-WASM path", palette.yellow },
        .{ "source object", "canonical editable workspace", palette.blue },
        .{ "ui components", "built-in app surface", palette.cyan },
        .{ "render ir", "web cpu gpu native", palette.cyan },
        .{ "object store", "canonical bytes and ids", palette.primary },
        .{ "receipts", "work can be explained", palette.violet },
        .{ "boot path", "QEMU TPM Pi bring-up", palette.orange },
    };
    var y = right.y;
    for (stack, 0..) |item, index| {
        try stackRow(scene, ui.Rect.init(right.x, y, right.w, 48.0), index + 1, item[0], item[1], item[2]);
        y += 56.0;
    }
}

fn renderImpact(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const layout = impactLayout(bounds);
    try tag(scene, ui.Rect.init(layout.copy.x, layout.copy.y, 72.0, 24.0), "IMPACT", palette.primary);
    try heading(scene, ui.Rect.init(layout.copy.x, layout.copy.y + impact_heading_y, layout.copy.w, impact_heading_h), "Software That", "Carries Its Tools");
    try impactParagraph(scene, ui.Rect.init(layout.copy.x, layout.copy.y + impact_copy_y, layout.copy.w, impact_copy_h), "If the app carries its compiler, UI, source object, and receipt model, sharing software becomes less like installing a mystery bundle and more like running a checkable object.");
    const scenarios = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "0", "npm installs", "for the app" },
        .{ "1", "ui contract", "all targets" },
        .{ "1", "receipt trail", "per run" },
    };
    for (scenarios, 0..) |item, index| {
        const r = layout.card(index);
        try impactCard(scene, r, item[0], item[1], item[2]);
    }
}

const ImpactLayout = struct {
    copy: ui.Rect,
    cards: ui.Rect,
    cols: usize,

    fn card(self: ImpactLayout, index: usize) ui.Rect {
        const col = index % self.cols;
        const row = index / self.cols;
        const width = (self.cards.w - impact_card_gap * @as(f32, @floatFromInt(self.cols - 1))) / @as(f32, @floatFromInt(self.cols));
        return ui.Rect.init(
            self.cards.x + @as(f32, @floatFromInt(col)) * (width + impact_card_gap),
            self.cards.y + @as(f32, @floatFromInt(row)) * (impact_card_h + impact_card_gap),
            width,
            impact_card_h,
        );
    }
};

fn impactLayout(bounds: ui.Rect) ImpactLayout {
    const split = bounds.w >= impact_split_min_w;
    if (split) {
        const copy_w = bounds.w * impact_split_text_fraction;
        const gap_w = bounds.w * impact_split_gap_fraction;
        const cards_w = bounds.w - copy_w - gap_w;
        const cards = ui.Rect.init(bounds.x + copy_w + gap_w, bounds.y + impact_cards_split_y, cards_w, impact_card_h);
        return .{
            .copy = ui.Rect.init(bounds.x, bounds.y, copy_w, bounds.h),
            .cards = cards,
            .cols = impactCardColumns(cards.w),
        };
    }

    const cards = ui.Rect.init(bounds.x, bounds.y + impact_cards_stacked_y, bounds.w, impactCardsHeight(bounds.w));
    return .{
        .copy = ui.Rect.init(bounds.x, bounds.y, bounds.w, impact_cards_stacked_y),
        .cards = cards,
        .cols = impactCardColumns(cards.w),
    };
}

fn impactSectionHeight(width: f32) f32 {
    const bounds = ui.Rect.init(0.0, 0.0, width, 1.0);
    const layout = impactLayout(bounds);
    return @max(impact_copy_y + impact_copy_h, (layout.cards.y - bounds.y) + impactCardsHeight(layout.cards.w)) + content_pad;
}

fn impactCardsHeight(width: f32) f32 {
    const cols = impactCardColumns(width);
    const rows = (impact_card_count + cols - 1) / cols;
    return @as(f32, @floatFromInt(rows)) * impact_card_h + @as(f32, @floatFromInt(rows - 1)) * impact_card_gap;
}

fn impactCardColumns(width: f32) usize {
    var cols: usize = impact_card_count;
    while (cols > 1) : (cols -= 1) {
        const required = impact_card_min_w * @as(f32, @floatFromInt(cols)) + impact_card_gap * @as(f32, @floatFromInt(cols - 1));
        if (width >= required) return cols;
    }
    return 1;
}

fn renderCta(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try nativeCard(scene, bounds, "", "");
    try alignedText(scene, bounds.x + 40.0, bounds.y + 70.0, bounds.w - 80.0, 30.0, "Open The Self-Compiling App", palette.text, .center);
    try alignedText(scene, bounds.x + 40.0, bounds.y + 118.0, bounds.w - 80.0, 18.0, "Read the source object, edit it, and compile the next artifact from inside the app.", palette.dim, .center);
    const actions = actionPairBounds(bounds.insetLtrb(40.0, 0.0, 40.0, 0.0), bounds.y + 168.0);
        const source = app_navigation.subNavBinding(.source);
    const docs = app_navigation.subNavBinding(.docs);
    try app_chrome.renderNavItem(scene, collector, .{
        .kind = .top_text,
        .binding = source,
        .bounds = actions.primary,
        .active = false,
        .label = "View Source",
        .variant = .primary,
        .icon_slot = icon_component.IconSlot.of(.trailing, icon_component.Icon.named(.chevron_right)),
    });
    try app_chrome.renderNavItem(scene, collector, .{
        .kind = .top_text,
        .binding = docs,
        .bounds = actions.secondary,
        .active = false,
        .label = "Read Docs",
        .variant = .outline,
    });
}

fn renderFooter
(scene: *ui.Scene, bounds: ui.Rect, content: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 1.0), palette.border, 0.0);
    try text(scene, content.x, bounds.y + 44.0, 120.0, 18.0, "EdgeRun", palette.text);
    try paragraph(scene, ui.Rect.init(content.x, bounds.y + 78.0, @min(content.w, 360.0), 54.0), "A self-compiling app system with built-in UI, canonical objects, and work receipts.");

    const compact = content.w < 720.0;
    const column_y_offset: f32 = if (compact) 150.0 else 44.0;
    const column_y = bounds.y + column_y_offset;
    const column_area = if (compact)
        ui.Rect.init(content.x, column_y, content.w, 90.0)
    else
        ui.Rect.init(content.x + content.w * 0.36, column_y, content.w * 0.64, 150.0);
    const gap: f32 = if (compact) 12.0 else 24.0;
    const column_w = @max(1.0, (column_area.w - gap * 2.0) / 3.0);
    try footerColumn(scene, ui.Rect.init(column_area.x, column_area.y, column_w, column_area.h), "App", &.{ "Source", "Components", "Docs", "Academy" });
    try footerColumn(scene, ui.Rect.init(column_area.x + column_w + gap, column_area.y, column_w, column_area.h), "Runtime", &.{ "WASM", "Objects", "Receipts", "Renderer" });
    try footerColumn(scene, ui.Rect.init(column_area.x + (column_w + gap) * 2.0, column_area.y, column_w, column_area.h), "Hardware", &.{ "QEMU", "TPM", "Pi Zero", "DRM" });
}

fn renderNodeMap(scene: *ui.Scene, bounds: ui.Rect, state: State, show_status: bool) ui.RenderError!void {
    const grid: f32 = 26.0;
    var x = bounds.x;
    while (x < bounds.x + bounds.w) : (x += grid) {
        var y = bounds.y;
        while (y < bounds.y + bounds.h) : (y += grid) {
            const lng = (x / @max(bounds.w, 1.0)) * 360.0 - 180.0;
            const lat = 90.0 - (y / @max(bounds.h, 1.0)) * 140.0;
            if (isLand(lat, lng)) try fill(scene, ui.Rect.init(x, y, 2.0, 2.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = node_land_alpha }, 1.0);
        }
    }
    const nodes = [_]struct { f32, f32, bool }{
        .{ 40.7, -74.0, true }, .{ 34.0, -118.2, true },  .{ 37.8, -122.4, true }, .{ 51.5, -0.1, true },
        .{ 48.9, 2.3, true },   .{ 52.5, 13.4, true },    .{ 35.7, 139.7, true },  .{ 37.6, 127.0, true },
        .{ 1.3, 103.8, true },  .{ -33.9, 151.2, false }, .{ 19.4, -99.1, true },  .{ -23.5, -46.6, false },
        .{ 28.6, 77.2, true },  .{ 31.2, 121.5, true },   .{ 43.7, -79.4, true },  .{ 47.6, -122.3, true },
    };
    for (nodes) |node| {
        const p = latLng(bounds, node[0], node[1]);
        try fill(scene, ui.Rect.init(p.x - 5.0, p.y - 5.0, 10.0, 10.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = if (node[2]) node_online_halo_alpha else node_offline_halo_alpha }, 5.0);
        try fill(scene, ui.Rect.init(p.x - 2.0, p.y - 2.0, 4.0, 4.0), if (node[2]) palette.primary else palette.muted, 2.0);
    }
    if (show_status and state.scroll_y <= 1.0) {
        try text(scene, bounds.x + 24.0, bounds.y + bounds.h - 66.0, 170.0, 14.0, "113 nodes online", palette.primary);
        try text(scene, bounds.x + 24.0, bounds.y + bounds.h - 42.0, 190.0, 12.0, "1401.2 TB/s mesh bandwidth", palette.dim);
    }
}

fn tag(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) ui.RenderError!void {
    var tag_style = appStyle();
    tag_style.accent = color;
    try (badge_component.Badge{ .label = label, .variant = .outline }).render(scene, bounds, .{ .style = tag_style });
}

fn title(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try titleWrapped(scene, bounds, value, palette.text);
}

fn titleAccent(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try titleWrapped(scene, bounds, value, palette.primary);
}

fn titleLine(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    try text_component.Text.renderAligned(scene, ui.Rect.init(bounds.x + title_weight_offset, bounds.y, bounds.w, bounds.h), value, color, .start);
    try text_component.Text.renderAligned(scene, bounds, value, color, .start);
}

fn titleMobile(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    const wrap = ui.TextWrap{ .line_height = hero_mobile_title_line_h, .average_char_width = hero_mobile_title_average_w, .max_lines = 2 };
    try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + title_weight_offset, bounds.y, bounds.w, bounds.h), value, color, wrap);
    try text_component.Text.renderWrapped(scene, bounds, value, color, wrap);
}

fn titleWrapped(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    const wrap = ui.TextWrap{ .line_height = 58.0, .average_char_width = 27.0, .max_lines = 2 };
    try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + title_weight_offset, bounds.y, bounds.w, bounds.h), value, color, wrap);
    try text_component.Text.renderWrapped(scene, bounds, value, color, wrap);
}

fn terminalVisibleLineCount(frame_ms: f32) usize {
    if (frame_ms <= 0.0) return terminal_line_count;
    const total = @as(f32, @floatFromInt(terminal_line_count));
    const cycle_ms = total * terminal_line_reveal_ms + terminal_hold_ms;
    const cycles = @floor(frame_ms / cycle_ms);
    const elapsed = frame_ms - cycles * cycle_ms;
    const visible = @as(usize, @intFromFloat(@floor(elapsed / terminal_line_reveal_ms))) + 1;
    return @max(@as(usize, 1), @min(terminal_line_count, visible));
}

fn heading(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 28.0, first, palette.text);
    try text(scene, bounds.x, bounds.y + 38.0, bounds.w, 28.0, second, palette.dim);
}

fn paragraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try text_component.Text.renderWrapped(scene, bounds, value, palette.dim, .{ .line_height = 18.0, .average_char_width = 8.3, .max_lines = 6 });
}

fn heroParagraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try text_component.Text.renderWrapped(scene, bounds, value, palette.dim, .{ .line_height = 18.0, .average_char_width = 11.5, .max_lines = 6 });
}

fn impactParagraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try text_component.Text.renderWrapped(scene, bounds, value, palette.dim, .{ .line_height = 18.0, .average_char_width = 10.6, .max_lines = 6 });
}

fn problemItem(scene: *ui.Scene, bounds: ui.Rect, number: []const u8, title_value: []const u8, detail: []const u8) ui.RenderError!void {
    const badge = ui.Rect.init(bounds.x, bounds.y + 5.0, 32.0, 32.0);
    try fill(scene, badge, ui.Color{ .r = 239, .g = 68, .b = 68, .a = 28 }, 16.0);
    try alignedText(scene, badge.x, badge.y + 9.0, badge.w, 12.0, number, palette.danger, .center);
    try text(scene, bounds.x + 46.0, bounds.y, bounds.w - 46.0, 16.0, title_value, palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 46.0, bounds.y + 22.0, bounds.w - 46.0, 28.0), detail);
}

fn traffic(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try text(scene, bounds.x + 24.0, bounds.y + 24.0, bounds.w - 48.0, 14.0, "Global web traffic through top 5 companies", palette.dim);
    const companies = [_]struct { []const u8, f32, ui.Color }{
        .{ "Cloudflare", 19.5, palette.orange },
        .{ "Google", 15.2, palette.blue },
        .{ "Fastly", 8.3, palette.danger },
        .{ "Amazon", 7.8, palette.yellow },
        .{ "Akamai", 6.1, palette.cyan },
        .{ "Others", 43.1, palette.muted },
    };
    const pie_size = @min(traffic_pie_max_size, bounds.w * traffic_pie_fraction);
    const pie = ui.Rect.init(bounds.x + 38.0, bounds.y + 78.0, pie_size, pie_size);
    var start_turn: f32 = 0.0;
    for (companies) |company| {
        const end_turn = start_turn + company[1] / traffic_total_percent;
        try scene.pushPieSlice(pie, company[2], start_turn, end_turn);
        start_turn = end_turn;
    }
    try scene.pushRect(pie, palette.border, .border, pie_size * 0.5, 0.0);

    const legend_x = pie.x + pie.w + traffic_legend_gap;
    const legend_w = @max(1.0, bounds.x + bounds.w - 24.0 - legend_x);
    var y = pie.y + 2.0;
    for (companies) |company| {
        try fill(scene, ui.Rect.init(legend_x, y + 5.0, traffic_legend_swatch, traffic_legend_swatch), company[2], 2.0);
        try text(scene, legend_x + 20.0, y, @max(1.0, legend_w - 88.0), 12.0, company[0], palette.dim);
        try text(scene, legend_x + legend_w - 60.0, y, 60.0, 12.0, percentLabel(company[1]), palette.text);
        y += traffic_legend_row_h;
    }
    try fill(scene, ui.Rect.init(bounds.x + 24.0, bounds.y + bounds.h - 64.0, bounds.w - 48.0, 1.0), palette.border, 0.0);
    try paragraph(scene, ui.Rect.init(bounds.x + 24.0, bounds.y + bounds.h - 46.0, bounds.w - 48.0, 32.0), "56.9% of internet traffic flows through just 5 companies. Your data. Their servers.");
}

fn percentLabel(value: f32) []const u8 {
    return switch (@as(i32, @intFromFloat(value * 10.0))) {
        195 => "19.5%",
        152 => "15.2%",
        83 => "8.3%",
        78 => "7.8%",
        61 => "6.1%",
        431 => "43.1%",
        else => "",
    };
}

fn principleCard(scene: *ui.Scene, bounds: ui.Rect, icon_value: icon_component.Icon, name: []const u8, detail: []const u8, code: []const u8) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    const icon_box = ui.Rect.init(bounds.x + 18.0, bounds.y + 18.0, design.Icon.tile_box, design.Icon.tile_box);
    const text_x = icon_box.x + icon_box.w + design.Icon.tile_text_gap;
    const text_w = bounds.x + bounds.w - text_x - 18.0;
    try fill(scene, icon_box, palette.neutral_soft, 9.0);
    try icon_value.renderColor(scene, icon_box.insetUniform(design.Icon.tile_inset), palette.primary);
    try text(scene, text_x, bounds.y + 18.0, text_w, 16.0, name, palette.text);
    try paragraph(scene, ui.Rect.init(text_x, bounds.y + 40.0, text_w, 28.0), detail);
    try fill(scene, ui.Rect.init(text_x, bounds.y + 76.0, @min(text_w, 210.0), 24.0), palette.neutral_soft, 4.0);
    try text(scene, text_x + 8.0, bounds.y + 83.0, @max(1.0, text_w - 16.0), 11.0, code, palette.primary);
}

fn stackRow(scene: *ui.Scene, bounds: ui.Rect, index: usize, name: []const u8, detail: []const u8, color: ui.Color) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try alignedText(scene, bounds.x + 12.0, bounds.y + 18.0, 28.0, 12.0, twoDigit(index), palette.dim, .end);
    try text(scene, bounds.x + 58.0, bounds.y + 17.0, 170.0, 13.0, name, color);
    try text(scene, bounds.x + bounds.w * 0.55, bounds.y + 17.0, bounds.w * 0.38, 13.0, detail, palette.dim);
}

fn twoDigit(index: usize) []const u8 {
    return switch (index) {
        1 => "01",
        2 => "02",
        3 => "03",
        4 => "04",
        5 => "05",
        6 => "06",
        7 => "07",
        8 => "08",
        else => "00",
    };
}

fn impactCard(scene: *ui.Scene, bounds: ui.Rect, adoption: []const u8, savings: []const u8, equivalent: []const u8) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try alignedText(scene, bounds.x, bounds.y + 28.0, bounds.w, 28.0, adoption, palette.primary, .center);
    try alignedText(scene, bounds.x, bounds.y + 64.0, bounds.w, 12.0, "adoption", palette.dim, .center);
    try fill(scene, ui.Rect.init(bounds.x + 22.0, bounds.y + 98.0, bounds.w - 44.0, 1.0), palette.border, 0.0);
    try alignedText(scene, bounds.x, bounds.y + 118.0, bounds.w, 18.0, savings, palette.text, .center);
    try alignedText(scene, bounds.x, bounds.y + 150.0, bounds.w, 12.0, equivalent, palette.dim, .center);
}

fn footerColumn(scene: *ui.Scene, bounds: ui.Rect, heading_value: []const u8, items: []const []const u8) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 14.0, heading_value, palette.text);
    var y = bounds.y + 34.0;
    for (items) |item| {
        try text(scene, bounds.x, y, bounds.w, 12.0, item, palette.dim);
        y += 26.0;
    }
}

const ActionPair = struct {
    primary: ui.Rect,
    secondary: ui.Rect,
};

fn actionPairBounds(bounds: ui.Rect, y: f32) ActionPair {
    const row = bounds.w >= action_pair_min_w;
    if (row) {
        const available = @max(1.0, bounds.w - hero_button_gap);
        const primary_w = @max(design.min_touch_target, available * hero_primary_button_weight);
        const secondary_w = @max(design.min_touch_target, available - primary_w);
        const total_w = primary_w + hero_button_gap + secondary_w;
        const x = bounds.x + @max(0.0, (bounds.w - total_w) * 0.5);
        return .{
            .primary = ui.Rect.init(x, y, primary_w, action_button_h),
            .secondary = ui.Rect.init(x + primary_w + hero_button_gap, y, secondary_w, action_button_h),
        };
    }
    const width = @max(design.min_touch_target, bounds.w);
    return .{
        .primary = ui.Rect.init(bounds.x, y, width, action_button_h),
        .secondary = ui.Rect.init(bounds.x, y + action_button_h + hero_button_gap, width, action_button_h),
    };
}

fn actionButtonBounds(bounds: ui.Rect, y: f32, preferred_w: f32) ui.Rect {
    return ui.Rect.init(bounds.x, y, @min(preferred_w, @max(design.min_touch_target, bounds.w)), 36.0);
}

fn nativeBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8) ui.RenderError!void {
    try (badge_component.Badge{
        .label = label,
        .variant = .secondary,
    }).render(scene, bounds, .{ .style = appStyle() });
}

fn nativeCard(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
    try (card_component.Card{ .title = title_value, .detail = detail_value, .variant = .elevated }).render(scene, bounds, .{ .style = appStyle() });
}

fn nativeComponent(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, component: anytype) (ui.RenderError || interaction.Error)!void {
    try component.render(scene, bounds, .{ .style = appStyle() });
    if (comptime @hasDecl(@TypeOf(component), "collectInteractions")) {
        const fn_info = @typeInfo(@TypeOf(@TypeOf(component).collectInteractions)).@"fn";
        if (fn_info.params.len >= 4) {
            try component.collectInteractions(collector, bounds, .{ .style = appStyle() });
        } else {
            try component.collectInteractions(collector, bounds);
        }
    }
}

fn appStyle() ui.Style {
    var resolved = design.style();
    resolved.panel = palette.card;
    resolved.row = palette.card_alt;
    return resolved;
}

fn alignedText(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    try text_component.Text.renderAligned(scene, ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, alignment);
}

fn columns(bounds: ui.Rect, desired: usize, gap: f32) usize {
    const by_width: usize = if (bounds.w >= 920.0) desired else if (bounds.w >= 620.0) @min(desired, 2) else 1;
    _ = gap;
    return @max(@as(usize, 1), @min(max_columns, by_width));
}

const Point = struct { x: f32, y: f32 };

fn latLng(bounds: ui.Rect, lat: f32, lng: f32) Point {
    return .{
        .x = bounds.x + ((lng + 180.0) / 360.0) * bounds.w,
        .y = bounds.y + ((90.0 - lat) / 140.0) * bounds.h - bounds.h * 0.1,
    };
}

fn isLand(lat: f32, lng: f32) bool {
    if (lat > 25.0 and lat < 70.0 and lng > -130.0 and lng < -60.0) return true;
    if (lat > -55.0 and lat < 10.0 and lng > -80.0 and lng < -35.0) return true;
    if (lat > 35.0 and lat < 70.0 and lng > -10.0 and lng < 40.0) return true;
    if (lat > -35.0 and lat < 35.0 and lng > -20.0 and lng < 50.0) return true;
    if (lat > 10.0 and lat < 70.0 and lng > 40.0 and lng < 145.0) return true;
    if (lat > -45.0 and lat < -10.0 and lng > 110.0 and lng < 155.0) return true;
    if (lat > 30.0 and lat < 45.0 and lng > 125.0 and lng < 145.0) return true;
    return false;
}

test "landing page renders app sections and primary actions" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [128]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 3600), .{});

    try std.testing.expect(hasText(scene.written(), "EdgeRun"));
    try std.testing.expect(hasText(scene.written(), "Builds Itself"));
    try std.testing.expect(hasText(scene.written(), "Dependency Towers"));
    try std.testing.expect(hasText(scene.written(), "No Package"));
    try std.testing.expect(hasText(scene.written(), "Others"));
    try std.testing.expect(hasText(scene.written(), "Click to Reveal ID"));
    try std.testing.expect(!hasText(scene.written(), "113 nodes online"));
    try std.testing.expect(hasPieSlice(scene.written()));
    try std.testing.expect(hasHit(collector.written(), app_navigation.subNavBinding(.docs).id));
    try std.testing.expect(hasHit(collector.written(), app_navigation.subNavBinding(.source).id));
    try std.testing.expect(hasIcon(scene.written(), icon_component.Icon.named(.chevron_right)));
    try std.testing.expect(hasIcon(scene.written(), icon_component.Icon.named(.code)));
}

test "landing page clips scrolled content below fixed header" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [128]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, 900), .{ .scroll_y = 2300.0 });

    const cta = textOrigin(scene.written(), "Open The Self-Compiling App").?;
    try std.testing.expect(cta.y >= header_h);
    try std.testing.expect(!contentTextAboveHeader(scene.written(), "Software That"));
}

test "landing page content height reaches footer without extra scroll space" {
    try std.testing.expectEqual(try flowSections(null, null, ui.Rect.init(0.0, 0.0, 1280.0, 1.0), .{}), contentHeight(1280.0));
    try std.testing.expect(contentHeight(640.0) > contentHeight(1280.0));
}

test "compact stats render as two reference columns" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try renderStats(&scene, ui.Rect.init(0.0, 0.0, 390.0, stats_compact_h));

    const artifact = textOrigin(scene.written(), "App Artifact").?;
    const installs = textOrigin(scene.written(), "Package Installs").?;
    const targets = textOrigin(scene.written(), "Render Targets").?;
    try std.testing.expect(installs.x > artifact.x);
    try std.testing.expect(targets.y > artifact.y);
    try std.testing.expect(targets.x == artifact.x);
}

test "impact section cards stay inside measured section" {
    const wide = ui.Rect.init(0.0, 0.0, content_wide, impactSectionHeight(content_wide));
    const medium = ui.Rect.init(0.0, 0.0, 968.0, impactSectionHeight(968.0));
    const compact_width = impact_card_min_w * 2.0 + impact_card_gap - 1.0;
    const compact = ui.Rect.init(0.0, 0.0, compact_width, impactSectionHeight(compact_width));

    const wide_layout = impactLayout(wide);
    try std.testing.expectEqual(@as(usize, 3), wide_layout.cols);
    for (0..impact_card_count) |index| {
        try std.testing.expect(rectInside(wide, wide_layout.card(index)));
    }

    const medium_layout = impactLayout(medium);
    try std.testing.expect(medium_layout.cards.y > medium_layout.copy.y);
    for (0..impact_card_count) |index| {
        try std.testing.expect(rectInside(medium, medium_layout.card(index)));
    }

    const compact_layout = impactLayout(compact);
    try std.testing.expect(compact_layout.cols < wide_layout.cols);
    for (0..impact_card_count) |index| {
        try std.testing.expect(rectInside(compact, compact_layout.card(index)));
    }
}

test "stacked hero keeps actions clear of terminal" {
    const narrow = ui.Rect.init(0.0, 0.0, 768.0, heroSectionHeight(768.0));
    const layout = heroLayout(narrow);
    try std.testing.expect(layout.button_y + 42.0 < layout.terminal.y);
    try std.testing.expect(rectInside(narrow, layout.terminal));
}

test "split hero keeps actions inside measured section" {
    const split = ui.Rect.init(0.0, 0.0, hero_split_min_w, heroSectionHeight(hero_split_min_w));
    const layout = heroLayout(split);
    try std.testing.expect(layout.button_y + 42.0 < split.y + split.h);
    try std.testing.expect(rectInside(split, layout.terminal));
}

test "terminal animation reveals deterministic line counts" {
    try std.testing.expectEqual(terminal_line_count, terminalVisibleLineCount(0.0));
    try std.testing.expectEqual(@as(usize, 1), terminalVisibleLineCount(1.0));
    try std.testing.expectEqual(@as(usize, 2), terminalVisibleLineCount(terminal_line_reveal_ms));
    try std.testing.expectEqual(terminal_line_count, terminalVisibleLineCount(terminal_line_reveal_ms * @as(f32, @floatFromInt(terminal_line_count)) + 1.0));
}

test "hero node map scrolls with page content" {
    var commands_top: [1024]ui.Command = undefined;
    var scene_top = ui.Scene.init(&commands_top);
    try renderNodeMap(&scene_top, ui.Rect.init(0.0, header_h, 1280.0, 720.0), .{}, false);

    var commands_scrolled: [1024]ui.Command = undefined;
    var scene_scrolled = ui.Scene.init(&commands_scrolled);
    try renderNodeMap(&scene_scrolled, ui.Rect.init(0.0, header_h - 120.0, 1280.0, 720.0), .{}, false);

    const first_top = firstNodeMapNode(scene_top.written()).?;
    const first_scrolled = firstNodeMapNode(scene_scrolled.written()).?;
    try std.testing.expectApproxEqAbs(first_top.y - 120.0, first_scrolled.y, 0.01);
}

fn firstNodeMapNode(commands: []const ui.Command) ?ui.Rect {
    for (commands) |command| switch (command) {
        .rect => |rect_command| {
            if (rect_command.bounds.w == 10.0 and rect_command.bounds.h == 10.0 and rect_command.color.a == node_online_halo_alpha) return rect_command.bounds;
        },
        else => {},
    };
    return null;
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (bytes.eql(text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn textOrigin(commands: []const ui.Command, value: []const u8) ?ui.Rect {
    for (commands) |command| switch (command) {
        .text => |text_command| if (bytes.eql(text_command.value, value)) return text_command.origin,
        else => {},
    };
    return null;
}

fn contentTextAboveHeader(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| {
            if (bytes.eql(text_command.value, value) and text_command.origin.y < header_h) return true;
        },
        else => {},
    };
    return false;
}

fn hasIcon(commands: []const ui.Command, value: icon_component.Icon) bool {
    const icon_id = value.tag();
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

fn hasHit(regions: []const interaction.Region, id: u32) bool {
    for (regions) |region| if (region.id == id) return true;
    return false;
}

fn hasPieSlice(commands: []const ui.Command) bool {
    for (commands) |command| switch (command) {
        .rect => |rect_command| if (rect_command.mode == .pie_slice) return true,
        else => {},
    };
    return false;
}

fn rectInside(outer: ui.Rect, inner: ui.Rect) bool {
    return inner.x >= outer.x and
        inner.y >= outer.y and
        inner.x + inner.w <= outer.x + outer.w and
        inner.y + inner.h <= outer.y + outer.h;
}
