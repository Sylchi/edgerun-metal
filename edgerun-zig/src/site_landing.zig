const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const site_chrome = @import("site_chrome.zig");

pub const logo_button_id: u32 = site_chrome.logo_button_id;
pub const docs_button_id: u32 = site_chrome.docs_button_id;
pub const apps_button_id: u32 = site_chrome.apps_button_id;
pub const launch_button_id: u32 = site_chrome.launch_button_id;
pub const search_button_id: u32 = site_chrome.search_button_id;
pub const blog_button_id: u32 = site_chrome.blog_button_id;
pub const source_button_id: u32 = site_chrome.source_button_id;
pub const reveal_identity_button_id: u32 = 20_001;

const max_columns: usize = 4;
const header_h: f32 = site_chrome.header_h;
const section_gap: f32 = 72.0;
const content_wide: f32 = 1180.0;
const content_pad: f32 = 28.0;
const radius: f32 = 10.0;
const terminal_h: f32 = 338.0;
const page_top_pad: f32 = 48.0;
const hero_copy_min_w: f32 = 460.0;
const hero_terminal_min_w: f32 = 460.0;
const hero_split_gap: f32 = 92.0;
const hero_split_min_w: f32 = hero_terminal_min_w + hero_split_gap + hero_copy_min_w;
const hero_split_terminal_y: f32 = 84.0;
const hero_split_copy_y: f32 = 92.0;
const hero_stacked_copy_y: f32 = 44.0;
const hero_stacked_copy_max_w: f32 = 860.0;
const hero_stacked_paragraph_max_w: f32 = 560.0;
const hero_stacked_button_y: f32 = 374.0;
const hero_stacked_terminal_y: f32 = 444.0;
const hero_bottom_pad: f32 = 48.0;
const hero_primary_button_w: f32 = 142.0;
const hero_outline_button_w: f32 = 126.0;
const hero_button_gap: f32 = 14.0;
const hero_inline_title_min_w: f32 = 720.0;
const hero_inline_title_first_w: f32 = 286.0;
const hero_inline_title_accent_w: f32 = 382.0;
const hero_inline_title_gap: f32 = 12.0;
const title_weight_offset: f32 = 0.75;
const terminal_line_h: f32 = 22.0;
const terminal_line_reveal_ms: f32 = 250.0;
const terminal_hold_ms: f32 = 1600.0;
const terminal_cursor_w: f32 = 8.0;
const terminal_cursor_h: f32 = 14.0;
const terminal_cursor_alpha: u8 = 190;
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

const palette = struct {
    const bg = ui.Color{ .r = 11, .g = 11, .b = 11 };
    const card = ui.Color{ .r = 18, .g = 18, .b = 18, .a = 238 };
    const card_alt = ui.Color{ .r = 24, .g = 24, .b = 24, .a = 224 };
    const muted = ui.Color{ .r = 92, .g = 92, .b = 92 };
    const border = ui.Color{ .r = 56, .g = 56, .b = 56 };
    const text = ui.Color{ .r = 242, .g = 242, .b = 242 };
    const dim = ui.Color{ .r = 154, .g = 154, .b = 154 };
    const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const neutral_soft = ui.Color{ .r = 32, .g = 32, .b = 32, .a = 190 };
    const danger = ui.Color{ .r = 239, .g = 68, .b = 68 };
    const orange = ui.Color{ .r = 249, .g = 115, .b = 22 };
    const blue = ui.Color{ .r = 96, .g = 165, .b = 250 };
    const cyan = ui.Color{ .r = 34, .g = 211, .b = 238 };
    const yellow = ui.Color{ .r = 250, .g = 204, .b = 21 };
    const violet = ui.Color{ .r = 167, .g = 139, .b = 250 };
};

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
    .{ .value = "$ edgerun start", .color = palette.dim },
    .{ .value = "EdgeRun v0.4.2-alpha", .color = palette.text },
    .{ .value = "initializing wasm runtime...", .color = palette.dim },
    .{ .value = "runtime loaded (2.1mb)", .color = palette.primary },
    .{ .value = "waiting for click entropy...", .color = palette.dim },
    .{ .value = "keygen runs inside wasm", .color = palette.primary },
    .{ .value = "identity source: ed25519_public", .color = palette.dim },
    .{ .value = "public identity:", .color = palette.text },
    .{ .value = "bootstrapping local app runtime...", .color = palette.dim },
    .{ .value = "mesh network active", .color = palette.primary },
    .{ .value = "your browser app is live", .color = palette.text },
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
    return flowSections(null, bounds, .{}) catch unreachable;
}

pub fn render(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);

    const content = centered(bounds, content_wide);
    const page_y = header_h - state.scroll_y;

    const map_h = header_h + heroSectionHeight(content.w);
    try renderNodeMap(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, map_h), state, content.w >= hero_split_min_w);

    const page_clip = ui.Rect.init(bounds.x, bounds.y + header_h, bounds.w, @max(1.0, bounds.h - header_h));
    if (try scene.pushClip(page_clip)) {
        defer scene.popClip();

        _ = try flowSections(scene, ui.Rect.init(bounds.x, page_y, bounds.w, bounds.h), state);
    }

    try renderHeader(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content);
}

fn flowSections(scene: ?*ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!f32 {
    const content = centered(bounds, content_wide);
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
                .hero => try renderHero(target, section_bounds, state),
                .stats => try renderStats(target, section_bounds),
                .problem => try renderProblem(target, section_bounds),
                .principles => try renderPrinciples(target, section_bounds),
                .architecture => try renderArchitecture(target, section_bounds),
                .impact => try renderImpact(target, section_bounds),
                .cta => try renderCta(target, section_bounds),
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
        .stats => 138.0,
        .problem => 420.0,
        .principles => if (content.w > 720.0) 430.0 else 682.0,
        .architecture => 500.0,
        .impact => impactSectionHeight(content.w),
        .cta => 280.0,
        .footer => 250.0,
    };
}

fn renderHeader(scene: *ui.Scene, bounds: ui.Rect, content: ui.Rect) ui.RenderError!void {
    try site_chrome.renderHeader(scene, bounds, content, .none);
}

fn renderHero(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
    const layout = heroLayout(bounds);
    const stacked = bounds.w < hero_split_min_w;

    try renderTerminal(scene, layout.terminal, state);

    const badge_w = @min(330.0, layout.copy.w);
    const badge_x = if (stacked) layout.copy.x + (layout.copy.w - badge_w) * 0.5 else layout.copy.x;
    const badge = ui.Rect.init(badge_x, layout.copy.y, badge_w, 28.0);
    try nativeBadge(scene, badge, "Written in Zig. Zero dependencies.");
    try iconQuad(scene, ui.Rect.init(badge.x + 12.0, badge.y + 5.0, 18.0, 18.0), .terminal, palette.primary);

    if (stacked and layout.copy.w >= hero_inline_title_min_w) {
        const title_w = hero_inline_title_first_w + hero_inline_title_gap + hero_inline_title_accent_w;
        const title_x = layout.copy.x + (layout.copy.w - title_w) * 0.5;
        try titleLine(scene, ui.Rect.init(title_x, layout.copy.y + 58.0, hero_inline_title_first_w, 58.0), "Your Node is", palette.text);
        try titleLine(scene, ui.Rect.init(title_x + hero_inline_title_first_w + hero_inline_title_gap, layout.copy.y + 58.0, hero_inline_title_accent_w, 58.0), "Already Running", palette.primary);
    } else {
        try title(scene, ui.Rect.init(layout.copy.x, layout.copy.y + 58.0, layout.copy.w, 92.0), "Your Node is");
        try titleAccent(scene, ui.Rect.init(layout.copy.x, layout.copy.y + 118.0, layout.copy.w, 116.0), "Already Running");
    }
    const paragraph_w = if (stacked) @min(layout.copy.w, hero_stacked_paragraph_max_w) else layout.copy.w;
    const paragraph_x = if (stacked) layout.copy.x + (layout.copy.w - paragraph_w) * 0.5 else layout.copy.x;
    try heroParagraph(scene, ui.Rect.init(paragraph_x, layout.copy.y + 244.0, paragraph_w, 88.0), "No signup. No account. No middlemen. EdgeRun starts a node in your browser the moment you arrive. Share your ID, connect directly, communicate privately.");
    const actions_w = hero_primary_button_w + hero_button_gap + hero_outline_button_w;
    const actions_x = if (stacked) layout.copy.x + (layout.copy.w - actions_w) * 0.5 else layout.copy.x;
    try primaryButtonWithTrailingIcon(scene, ui.Rect.init(actions_x, layout.button_y, hero_primary_button_w, 42.0), "Read the Docs", .chevron_right, docs_button_id);
    try outlineButton(scene, ui.Rect.init(actions_x + hero_primary_button_w + hero_button_gap, layout.button_y, hero_outline_button_w, 42.0), "Browse Apps", apps_button_id);
}

const HeroLayout = struct {
    terminal: ui.Rect,
    copy: ui.Rect,
    button_y: f32,
};

fn heroLayout(bounds: ui.Rect) HeroLayout {
    if (bounds.w >= hero_split_min_w) {
        const terminal = ui.Rect.init(bounds.x, bounds.y + hero_split_terminal_y, bounds.w * 0.46, terminal_h);
        const copy = ui.Rect.init(bounds.x + bounds.w * 0.54, bounds.y + hero_split_copy_y, bounds.w * 0.46, 360.0);
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
    const actions_bottom = layout.button_y + 42.0;
    return @max(terminal_bottom, actions_bottom) - bounds.y + hero_bottom_pad;
}

fn renderTerminal(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
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
        try text(scene, bounds.x + 24.0, y, bounds.w - 48.0, 14.0, state.public_identity, palette.primary);
        y += terminal_line_h;
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
        const reveal = ui.Rect.init(bounds.x + 24.0, bounds.y + bounds.h - 54.0, 174.0, 32.0);
        try outlineButton(scene, reveal, "Reveal Identity", reveal_identity_button_id);
    }
}

fn renderStats(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, ui.Color{ .r = 18, .g = 18, .b = 18, .a = 120 }, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 1.0), palette.border, 0.0);
    const content = centered(bounds, content_wide);
    const stats = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "12,847", "", "Active Nodes" },
        .{ "847.3", " TB/s", "Mesh Bandwidth" },
        .{ "2.4", "M", "Messages Today" },
        .{ "0", "", "Zero Accounts Created" },
    };
    const cols = columns(content, 4, 18.0);
    for (stats, 0..) |item, index| {
        const r = colBounds(content, cols, 18.0, index, bounds.y + 38.0, 66.0);
        try text(scene, r.x, r.y, r.w, 24.0, item[0], palette.text);
        try text(scene, r.x + 74.0, r.y + 4.0, 72.0, 16.0, item[1], palette.primary);
        try text(scene, r.x, r.y + 34.0, r.w, 14.0, item[2], palette.dim);
    }
}

fn renderProblem(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const left = ui.Rect.init(bounds.x, bounds.y, bounds.w * 0.48, bounds.h);
    const right = ui.Rect.init(bounds.x + bounds.w * 0.56, bounds.y, bounds.w * 0.44, bounds.h);
    try tag(scene, ui.Rect.init(left.x, left.y, 104.0, 24.0), "THE PROBLEM", palette.danger);
    try heading(scene, ui.Rect.init(left.x, left.y + 44.0, left.w, 74.0), "The Web's", "Centralization Crisis");
    try paragraph(scene, ui.Rect.init(left.x, left.y + 138.0, left.w, 82.0), "Every message, every file, every connection is routed through corporate servers that decrypt, inspect, and monetize your data.");
    try problemItem(scene, ui.Rect.init(left.x, left.y + 250.0, left.w, 48.0), "1", "TLS Termination", "CDNs and load balancers decrypt traffic at every hop.");
    try problemItem(scene, ui.Rect.init(left.x, left.y + 310.0, left.w, 48.0), "2", "Identity Silos", "Your identity exists at the pleasure of platforms.");
    try problemItem(scene, ui.Rect.init(left.x, left.y + 370.0, left.w, 48.0), "3", "Surveillance by Default", "Metadata is logged, analyzed, and sold.");
    try traffic(scene, right);
}

fn renderPrinciples(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try tag(scene, ui.Rect.init(bounds.x + bounds.w * 0.5 - 52.0, bounds.y, 104.0, 24.0), "ARCHITECTURE", palette.primary);
    try alignedText(scene, bounds.x, bounds.y + 44.0, bounds.w, 26.0, "Principles, Not Features", palette.text, .center);
    try alignedText(scene, bounds.x, bounds.y + 82.0, bounds.w, 16.0, "Architectural guarantees enforced by code.", palette.dim, .center);
    const cards_y = bounds.y + 140.0;
    const cols = columns(bounds, if (bounds.w > 720.0) 2 else 1, 16.0);
    const items = [_]struct { icon.Icon, []const u8, []const u8, []const u8 }{
        .{ .shield, "Identity-Routed Work", "Work is addressed by cryptographic identity.", "send(peer_id, encrypted_payload)" },
        .{ .lock, "Sealed Work Objects", "Data is encrypted at the source.", "seal(data, recipient_pubkey)" },
        .{ .user, "User-Governed Resources", "Your devices, your rules.", "policy.admit(request)" },
        .{ .network, "Local Admission Policy", "Each node decides what to accept.", "node.set_policy(my_rules)" },
    };
    for (items, 0..) |item, index| {
        const row: usize = index / cols;
        const col: usize = index % cols;
        const r = colBounds(bounds, cols, 16.0, col, cards_y + @as(f32, @floatFromInt(row)) * 126.0, 110.0);
        try principleCard(scene, r, item[0], item[1], item[2], item[3]);
    }
}

fn renderArchitecture(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const left = ui.Rect.init(bounds.x, bounds.y, bounds.w * 0.36, bounds.h);
    const right = ui.Rect.init(bounds.x + bounds.w * 0.43, bounds.y, bounds.w * 0.57, bounds.h);
    try tag(scene, ui.Rect.init(left.x, left.y, 64.0, 24.0), "STACK", palette.primary);
    try heading(scene, ui.Rect.init(left.x, left.y + 44.0, left.w, 74.0), "Pure Zig.", "Zero Dependencies.");
    try paragraph(scene, ui.Rect.init(left.x, left.y + 138.0, left.w, 96.0), "Every component written from scratch. No inherited vulnerabilities. No black boxes. Compiles to WebAssembly for browser, native for desktop.");
    try outlineButtonWithTrailingIcon(scene, ui.Rect.init(left.x, left.y + 264.0, 180.0, 36.0), "Explore Architecture", .chevron_right, docs_button_id);
    const stack = [_]struct { []const u8, []const u8, ui.Color }{
        .{ "edgerun-metal", "Bare metal bootloader", palette.orange },
        .{ "edgerun-clock", "Distributed time sync", palette.yellow },
        .{ "edgerun-crypto", "BLAKE3, Ed25519, X25519", palette.primary },
        .{ "edgerun-identity", "Key derivation and management", palette.primary },
        .{ "edgerun-object", "Content-addressed storage", palette.blue },
        .{ "edgerun-admission", "Policy engine", palette.cyan },
        .{ "edgerun-relay", "NAT traversal and relay", palette.cyan },
        .{ "edgerun-node", "Runtime orchestration", palette.violet },
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
    try heading(scene, ui.Rect.init(layout.copy.x, layout.copy.y + impact_heading_y, layout.copy.w, impact_heading_h), "What If We Didn't Need", "All Those Data Centers?");
    try impactParagraph(scene, ui.Rect.init(layout.copy.x, layout.copy.y + impact_copy_y, layout.copy.w, impact_copy_h), "Global data centers consume 500+ TWh annually. Edge computing on consumer devices could reduce this footprint while improving privacy and resilience.");
    const scenarios = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "10%", "50 TWh/yr", "Belgium" },
        .{ "30%", "150 TWh/yr", "NL + DK" },
        .{ "50%", "250 TWh/yr", "UK" },
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

fn renderCta(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try alignedText(scene, bounds.x + 40.0, bounds.y + 70.0, bounds.w - 80.0, 30.0, "Cut Out the Middlemen", palette.text, .center);
    try alignedText(scene, bounds.x + 40.0, bounds.y + 118.0, bounds.w - 80.0, 18.0, "Start with the docs. Explore the architecture. Build apps that respect users.", palette.dim, .center);
    const center = bounds.x + bounds.w * 0.5;
    try primaryButtonWithTrailingIcon(scene, ui.Rect.init(center - 146.0, bounds.y + 168.0, 132.0, 38.0), "Get Started", .chevron_right, docs_button_id);
    try outlineButton(scene, ui.Rect.init(center + 14.0, bounds.y + 168.0, 132.0, 38.0), "Browse Apps", apps_button_id);
}

fn renderFooter(scene: *ui.Scene, bounds: ui.Rect, content: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 1.0), palette.border, 0.0);
    try text(scene, content.x, bounds.y + 44.0, 120.0, 18.0, "EdgeRun", palette.text);
    try paragraph(scene, ui.Rect.init(content.x, bounds.y + 78.0, 260.0, 54.0), "A decentralized runtime for user sovereignty. Own your digital identity.");
    try footerColumn(scene, ui.Rect.init(content.x + content.w * 0.36, bounds.y + 44.0, 160.0, 150.0), "Product", &.{ "Documentation", "Blog", "App Store", "Roadmap" });
    try footerColumn(scene, ui.Rect.init(content.x + content.w * 0.58, bounds.y + 44.0, 180.0, 150.0), "Resources", &.{ "Getting Started", "Architecture", "Security Model", "API Reference" });
    try footerColumn(scene, ui.Rect.init(content.x + content.w * 0.81, bounds.y + 44.0, 140.0, 150.0), "Community", &.{ "GitHub", "Discord", "Contributing" });
}

fn renderNodeMap(scene: *ui.Scene, bounds: ui.Rect, state: State, show_status: bool) ui.RenderError!void {
    const grid: f32 = 26.0;
    var x = bounds.x;
    while (x < bounds.x + bounds.w) : (x += grid) {
        var y = bounds.y;
        while (y < bounds.y + bounds.h) : (y += grid) {
            const lng = (x / @max(bounds.w, 1.0)) * 360.0 - 180.0;
            const lat = 90.0 - (y / @max(bounds.h, 1.0)) * 140.0;
            if (isLand(lat, lng)) try fill(scene, ui.Rect.init(x, y, 2.0, 2.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 12 }, 1.0);
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
        try fill(scene, ui.Rect.init(p.x - 5.0, p.y - 5.0, 10.0, 10.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = if (node[2]) 24 else 16 }, 5.0);
        try fill(scene, ui.Rect.init(p.x - 2.0, p.y - 2.0, 4.0, 4.0), if (node[2]) palette.primary else palette.muted, 2.0);
    }
    if (show_status and state.scroll_y <= 1.0) {
        try text(scene, bounds.x + 24.0, bounds.y + bounds.h - 66.0, 170.0, 14.0, "113 nodes online", palette.primary);
        try text(scene, bounds.x + 24.0, bounds.y + bounds.h - 42.0, 190.0, 12.0, "1401.2 TB/s mesh bandwidth", palette.dim);
    }
}

fn tag(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) ui.RenderError!void {
    try fill(scene, bounds, palette.neutral_soft, 5.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 6.0, bounds.w - 16.0, 10.0, label, color, .center);
}

fn title(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try titleWrapped(scene, bounds, value, palette.text);
}

fn titleAccent(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try titleWrapped(scene, bounds, value, palette.primary);
}

fn titleLine(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(bounds.x + title_weight_offset, bounds.y, bounds.w, bounds.h), value, color, .start);
    try scene.pushAlignedText(bounds, value, color, .start);
}

fn titleWrapped(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    const wrap = ui.TextWrap{ .line_height = 58.0, .average_char_width = 27.0, .max_lines = 2 };
    try scene.pushWrappedText(ui.Rect.init(bounds.x + title_weight_offset, bounds.y, bounds.w, bounds.h), value, color, wrap);
    try scene.pushWrappedText(bounds, value, color, wrap);
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
    try scene.pushWrappedText(bounds, value, palette.dim, .{ .line_height = 18.0, .average_char_width = 8.3, .max_lines = 6 });
}

fn heroParagraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, palette.dim, .{ .line_height = 18.0, .average_char_width = 11.5, .max_lines = 6 });
}

fn impactParagraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, palette.dim, .{ .line_height = 18.0, .average_char_width = 10.6, .max_lines = 6 });
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

fn principleCard(scene: *ui.Scene, bounds: ui.Rect, icon_value: icon.Icon, name: []const u8, detail: []const u8, code: []const u8) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    const icon_box = ui.Rect.init(bounds.x + 18.0, bounds.y + 18.0, 40.0, 40.0);
    try fill(scene, icon_box, palette.neutral_soft, 9.0);
    try iconQuad(scene, icon_box.insetUniform(10.0), icon_value, palette.primary);
    try text(scene, bounds.x + 74.0, bounds.y + 18.0, bounds.w - 92.0, 16.0, name, palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 74.0, bounds.y + 40.0, bounds.w - 92.0, 28.0), detail);
    try fill(scene, ui.Rect.init(bounds.x + 74.0, bounds.y + 76.0, @min(bounds.w - 92.0, 210.0), 24.0), palette.neutral_soft, 4.0);
    try text(scene, bounds.x + 82.0, bounds.y + 83.0, bounds.w - 108.0, 11.0, code, palette.primary);
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

fn primaryButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{ .button_variant = .primary });
}

fn primaryButtonWithTrailingIcon(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, icon_value: icon.Icon, id: u32) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{ .button_variant = .primary, .button_trailing_icon = icon_value });
}

fn outlineButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{ .button_variant = .outline });
}

fn outlineButtonWithTrailingIcon(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, icon_value: icon.Icon, id: u32) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{ .button_variant = .outline, .button_trailing_icon = icon_value });
}

fn nativeBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8) ui.RenderError!void {
    try fill(scene, bounds, palette.card_alt, 12.0);
    try stroke(scene, bounds, palette.border, 12.0);
    try alignedText(scene, bounds.x + 28.0, bounds.y + 8.0, bounds.w - 40.0, 12.0, label, palette.primary, .center);
}

fn nativeCard(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, detail_value: []const u8) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .card = .{ .title = title_value, .detail = detail_value } }, .{ .surface_variant = .elevated });
}

fn nativeComponent(scene: *ui.Scene, bounds: ui.Rect, component: components.Component, options: components.RenderOptions) ui.RenderError!void {
    var resolved = options;
    resolved.style = siteStyle();
    try components.renderComponent(scene, bounds, component, resolved);
}

fn siteStyle() ui.Style {
    return site_chrome.style();
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, r: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, r, 0.0);
}

fn stroke(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, r: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .border, r, 0.0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, .start);
}

fn alignedText(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, alignment);
}

fn iconQuad(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    try scene.pushIconQuad(.{ .bounds = bounds, .atlas_id = icon.atlasId(value), .color = color });
}

fn hit(scene: *ui.Scene, bounds: ui.Rect, kind: ui.HitKind, id: u32) ui.RenderError!void {
    try scene.pushHit(.{ .slot = 0, .kind = kind, .id = id, .bounds = bounds });
}

fn centered(bounds: ui.Rect, max_w: f32) ui.Rect {
    const width = @min(max_w, @max(1.0, bounds.w - content_pad * 2.0));
    return ui.Rect.init(bounds.x + (bounds.w - width) * 0.5, bounds.y, width, bounds.h);
}

fn columns(bounds: ui.Rect, desired: usize, gap: f32) usize {
    const by_width: usize = if (bounds.w >= 920.0) desired else if (bounds.w >= 620.0) @min(desired, 2) else 1;
    _ = gap;
    return @max(@as(usize, 1), @min(max_columns, by_width));
}

fn colBounds(bounds: ui.Rect, cols: usize, gap: f32, col: usize, y: f32, h: f32) ui.Rect {
    const width = (bounds.w - gap * @as(f32, @floatFromInt(cols - 1))) / @as(f32, @floatFromInt(cols));
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(col)) * (width + gap), y, width, h);
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

test "landing page renders site sections and primary actions" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try render(&scene, ui.Rect.init(0, 0, 1280, 3600), .{});

    try std.testing.expect(hasText(scene.written(), "EdgeRun"));
    try std.testing.expect(hasText(scene.written(), "Already Running"));
    try std.testing.expect(hasText(scene.written(), "Centralization Crisis"));
    try std.testing.expect(hasText(scene.written(), "Pure Zig."));
    try std.testing.expect(hasText(scene.written(), "Others"));
    try std.testing.expect(hasPieSlice(scene.written()));
    try std.testing.expect(hasHit(scene.written(), docs_button_id));
    try std.testing.expect(hasHit(scene.written(), apps_button_id));
    try std.testing.expect(hasIcon(scene.written(), .search));
    try std.testing.expect(hasIcon(scene.written(), .chevron_right));
    try std.testing.expect(hasIcon(scene.written(), .github));
}

test "landing page clips scrolled content below fixed header" {
    var commands: [4096]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try render(&scene, ui.Rect.init(0, 0, 1280, 900), .{ .scroll_y = 2300.0 });

    const cta = textOrigin(scene.written(), "Cut Out the Middlemen").?;
    try std.testing.expect(cta.y >= header_h);
    try std.testing.expect(!contentTextAboveHeader(scene.written(), "What If We Didn't Need"));
}

test "landing page content height reaches footer without extra scroll space" {
    try std.testing.expectEqual(try flowSections(null, ui.Rect.init(0.0, 0.0, 1280.0, 1.0), .{}), contentHeight(1280.0));
    try std.testing.expect(contentHeight(640.0) > contentHeight(1280.0));
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

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn textOrigin(commands: []const ui.Command, value: []const u8) ?ui.Rect {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return text_command.origin,
        else => {},
    };
    return null;
}

fn contentTextAboveHeader(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| {
            if (std.mem.eql(u8, text_command.value, value) and text_command.origin.y < header_h) return true;
        },
        else => {},
    };
    return false;
}

fn hasIcon(commands: []const ui.Command, value: icon.Icon) bool {
    const atlas_id = icon.atlasId(value);
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.atlas_id == atlas_id) return true,
        else => {},
    };
    return false;
}

fn hasHit(commands: []const ui.Command, id: u32) bool {
    for (commands) |command| switch (command) {
        .hit => |hit_command| if (hit_command.id == id) return true,
        else => {},
    };
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
