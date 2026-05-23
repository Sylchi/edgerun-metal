const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");

pub const docs_button_id: u32 = 30_001;
pub const apps_button_id: u32 = 30_002;
pub const launch_button_id: u32 = 30_003;
pub const search_button_id: u32 = 30_004;
pub const blog_button_id: u32 = 30_011;

const max_columns: usize = 4;
const header_h: f32 = 64.0;
const section_gap: f32 = 72.0;
const content_wide: f32 = 1180.0;
const content_pad: f32 = 28.0;
const radius: f32 = 10.0;
const terminal_h: f32 = 338.0;
const page_top_pad: f32 = 48.0;

const palette = struct {
    const bg = ui.Color{ .r = 11, .g = 11, .b = 11 };
    const card = ui.Color{ .r = 18, .g = 18, .b = 18, .a = 238 };
    const card_alt = ui.Color{ .r = 24, .g = 24, .b = 24, .a = 224 };
    const muted = ui.Color{ .r = 92, .g = 92, .b = 92 };
    const border = ui.Color{ .r = 56, .g = 56, .b = 56 };
    const text = ui.Color{ .r = 242, .g = 242, .b = 242 };
    const dim = ui.Color{ .r = 154, .g = 154, .b = 154 };
    const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const primary_soft = ui.Color{ .r = 74, .g = 222, .b = 128, .a = 34 };
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
};

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

    try renderNodeMap(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, @max(bounds.h, 680.0)), state);

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
        .hero => 620.0,
        .stats => 138.0,
        .problem => 420.0,
        .principles => if (content.w > 720.0) 430.0 else 682.0,
        .architecture => 500.0,
        .impact => 310.0,
        .cta => 280.0,
        .footer => 250.0,
    };
}

fn renderHeader(scene: *ui.Scene, bounds: ui.Rect, content: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), palette.border, 0.0);

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, 32.0, 32.0);
    try fill(scene, logo, palette.primary, 7.0);
    try iconQuad(scene, logo.insetUniform(8.0), .terminal, palette.bg);
    try text(scene, logo.x + 42.0, bounds.y + 23.0, 110.0, 18.0, "EdgeRun", palette.text);

    const nav_y = bounds.y + 19.0;
    try navItem(scene, ui.Rect.init(content.x + 190.0, nav_y, 68.0, 28.0), "Docs", docs_button_id);
    try navItem(scene, ui.Rect.init(content.x + 266.0, nav_y, 64.0, 28.0), "Blog", blog_button_id);
    try navItem(scene, ui.Rect.init(content.x + 338.0, nav_y, 64.0, 28.0), "Apps", apps_button_id);

    const launch = ui.Rect.init(content.x + content.w - 128.0, bounds.y + 16.0, 128.0, 32.0);
    try primaryButton(scene, launch, "Launch Desktop", launch_button_id);
    const search = ui.Rect.init(launch.x - 126.0, launch.y, 112.0, 32.0);
    try outlineButton(scene, search, "Search", search_button_id);
}

fn renderHero(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
    const split = bounds.w >= 840.0;
    const left = if (split) ui.Rect.init(bounds.x, bounds.y + 84.0, bounds.w * 0.46, terminal_h) else ui.Rect.init(bounds.x, bounds.y + 330.0, bounds.w, terminal_h);
    const right = if (split) ui.Rect.init(bounds.x + bounds.w * 0.54, bounds.y + 92.0, bounds.w * 0.46, 360.0) else ui.Rect.init(bounds.x, bounds.y + 44.0, bounds.w, 260.0);

    try renderTerminal(scene, left);

    const badge = ui.Rect.init(right.x, right.y, @min(330.0, right.w), 28.0);
    try nativeBadge(scene, badge, "Written in Zig. Zero dependencies.");
    try iconQuad(scene, ui.Rect.init(badge.x + 12.0, badge.y + 7.0, 14.0, 14.0), .terminal, palette.primary);

    try title(scene, ui.Rect.init(right.x, right.y + 58.0, right.w, 92.0), "Your Node is");
    try titleAccent(scene, ui.Rect.init(right.x, right.y + 118.0, right.w, 116.0), "Already Running");
    try paragraph(scene, ui.Rect.init(right.x, right.y + 244.0, right.w, 88.0), "No signup. No account. No middlemen. EdgeRun starts a node in your browser the moment you arrive. Share your ID, connect directly, communicate privately.");
    try primaryButton(scene, ui.Rect.init(right.x, right.y + 368.0, 142.0, 42.0), "Read the Docs", docs_button_id);
    try outlineButton(scene, ui.Rect.init(right.x + 156.0, right.y + 368.0, 126.0, 42.0), "Browse Apps", apps_button_id);

    _ = state;
}

fn renderTerminal(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    const header = ui.Rect.init(bounds.x, bounds.y, bounds.w, 40.0);
    try fill(scene, header, palette.card_alt, radius);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + 39.0, bounds.w, 1.0), palette.border, 0.0);
    try fill(scene, ui.Rect.init(header.x + 14.0, header.y + 14.0, 10.0, 10.0), palette.danger, 5.0);
    try fill(scene, ui.Rect.init(header.x + 30.0, header.y + 14.0, 10.0, 10.0), palette.yellow, 5.0);
    try fill(scene, ui.Rect.init(header.x + 46.0, header.y + 14.0, 10.0, 10.0), palette.primary, 5.0);
    try text(scene, header.x + 70.0, header.y + 13.0, 140.0, 12.0, "edgerun - node", palette.dim);

    const lines = [_]struct { []const u8, ui.Color }{
        .{ "$ edgerun start", palette.dim },
        .{ "EdgeRun v0.4.2-alpha", palette.text },
        .{ "initializing wasm runtime...", palette.dim },
        .{ "runtime loaded (2.1mb)", palette.primary },
        .{ "generating node keypair...", palette.dim },
        .{ "ed25519 keypair ready", palette.primary },
        .{ "bootstrapping DHT...", palette.dim },
        .{ "found 847 peers", palette.dim },
        .{ "connected to 12 nodes", palette.dim },
        .{ "mesh network active", palette.primary },
        .{ "your node is live", palette.text },
        .{ "node: af03d91c7b42e8aa", palette.primary },
    };
    var y = bounds.y + 62.0;
    for (lines) |line| {
        try text(scene, bounds.x + 24.0, y, bounds.w - 48.0, 14.0, line[0], line[1]);
        y += 22.0;
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
    try outlineButton(scene, ui.Rect.init(left.x, left.y + 264.0, 180.0, 36.0), "Explore Architecture", docs_button_id);
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
    const left = ui.Rect.init(bounds.x, bounds.y, bounds.w * 0.48, bounds.h);
    const right = ui.Rect.init(bounds.x + bounds.w * 0.54, bounds.y, bounds.w * 0.46, bounds.h);
    try tag(scene, ui.Rect.init(left.x, left.y, 72.0, 24.0), "IMPACT", palette.primary);
    try heading(scene, ui.Rect.init(left.x, left.y + 44.0, left.w, 74.0), "What If We Didn't Need", "All Those Data Centers?");
    try paragraph(scene, ui.Rect.init(left.x, left.y + 138.0, left.w, 84.0), "Global data centers consume 500+ TWh annually. Edge computing on consumer devices could reduce this footprint while improving privacy and resilience.");
    const scenarios = [_]struct { []const u8, []const u8, []const u8 }{
        .{ "10%", "50 TWh/yr", "Belgium" },
        .{ "30%", "150 TWh/yr", "NL + DK" },
        .{ "50%", "250 TWh/yr", "UK" },
    };
    const cols = columns(right, 3, 14.0);
    for (scenarios, 0..) |item, index| {
        const r = colBounds(right, cols, 14.0, index, right.y + 36.0, 190.0);
        try impactCard(scene, r, item[0], item[1], item[2]);
    }
}

fn renderCta(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    try alignedText(scene, bounds.x + 40.0, bounds.y + 70.0, bounds.w - 80.0, 30.0, "Cut Out the Middlemen", palette.text, .center);
    try alignedText(scene, bounds.x + 40.0, bounds.y + 118.0, bounds.w - 80.0, 18.0, "Start with the docs. Explore the architecture. Build apps that respect users.", palette.dim, .center);
    const center = bounds.x + bounds.w * 0.5;
    try primaryButton(scene, ui.Rect.init(center - 146.0, bounds.y + 168.0, 132.0, 38.0), "Get Started", docs_button_id);
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

fn renderNodeMap(scene: *ui.Scene, bounds: ui.Rect, state: State) ui.RenderError!void {
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
        try fill(scene, ui.Rect.init(p.x - 5.0, p.y - 5.0, 10.0, 10.0), if (node[2]) ui.Color{ .r = 74, .g = 222, .b = 128, .a = 34 } else ui.Color{ .r = 255, .g = 255, .b = 255, .a = 20 }, 5.0);
        try fill(scene, ui.Rect.init(p.x - 2.0, p.y - 2.0, 4.0, 4.0), if (node[2]) palette.primary else palette.muted, 2.0);
    }
    if (state.scroll_y <= 1.0) {
        try text(scene, bounds.x + 24.0, bounds.y + bounds.h - 66.0, 170.0, 14.0, "113 nodes online", palette.primary);
        try text(scene, bounds.x + 24.0, bounds.y + bounds.h - 42.0, 190.0, 12.0, "1401.2 TB/s mesh bandwidth", palette.dim);
    }
}

fn navItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try fill(scene, bounds, ui.Color.clear, 6.0);
    try alignedText(scene, bounds.x, bounds.y + 7.0, bounds.w, 12.0, label, palette.dim, .center);
    try hit(scene, bounds, .button, id);
}

fn tag(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, color: ui.Color) ui.RenderError!void {
    var soft = color;
    soft.a = 34;
    try fill(scene, bounds, soft, 5.0);
    try alignedText(scene, bounds.x + 8.0, bounds.y + 6.0, bounds.w - 16.0, 10.0, label, color, .center);
}

fn title(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, palette.text, .{ .line_height = 58.0, .average_char_width = 22.0, .max_lines = 2 });
}

fn titleAccent(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, palette.primary, .{ .line_height = 58.0, .average_char_width = 22.0, .max_lines = 2 });
}

fn heading(scene: *ui.Scene, bounds: ui.Rect, first: []const u8, second: []const u8) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 28.0, first, palette.text);
    try text(scene, bounds.x, bounds.y + 38.0, bounds.w, 28.0, second, palette.dim);
}

fn paragraph(scene: *ui.Scene, bounds: ui.Rect, value: []const u8) ui.RenderError!void {
    try scene.pushWrappedText(bounds, value, palette.dim, .{ .line_height = 18.0, .average_char_width = 8.3, .max_lines = 6 });
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
    const bar = ui.Rect.init(bounds.x + 24.0, bounds.y + 66.0, bounds.w - 48.0, 32.0);
    var x = bar.x;
    for (companies) |company| {
        const w = bar.w * company[1] / 100.0;
        try fill(scene, ui.Rect.init(x, bar.y, w, bar.h), company[2], 2.0);
        x += w;
    }
    var y = bounds.y + 124.0;
    for (companies[0..5]) |company| {
        try fill(scene, ui.Rect.init(bounds.x + 24.0, y + 5.0, 8.0, 8.0), company[2], 2.0);
        try text(scene, bounds.x + 40.0, y, 104.0, 12.0, company[0], palette.dim);
        try text(scene, bounds.x + 150.0, y, 60.0, 12.0, percentLabel(company[1]), palette.text);
        y += 24.0;
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
        else => "",
    };
}

fn principleCard(scene: *ui.Scene, bounds: ui.Rect, icon_value: icon.Icon, name: []const u8, detail: []const u8, code: []const u8) ui.RenderError!void {
    try nativeCard(scene, bounds, "", "");
    const icon_box = ui.Rect.init(bounds.x + 18.0, bounds.y + 18.0, 40.0, 40.0);
    try fill(scene, icon_box, palette.primary_soft, 9.0);
    try iconQuad(scene, icon_box.insetUniform(10.0), icon_value, palette.primary);
    try text(scene, bounds.x + 74.0, bounds.y + 18.0, bounds.w - 92.0, 16.0, name, palette.text);
    try paragraph(scene, ui.Rect.init(bounds.x + 74.0, bounds.y + 40.0, bounds.w - 92.0, 28.0), detail);
    try fill(scene, ui.Rect.init(bounds.x + 74.0, bounds.y + 76.0, @min(bounds.w - 92.0, 210.0), 24.0), ui.Color{ .r = 74, .g = 222, .b = 128, .a = 18 }, 4.0);
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

fn outlineButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{ .button_variant = .outline });
}

fn nativeBadge(scene: *ui.Scene, bounds: ui.Rect, label: []const u8) ui.RenderError!void {
    try nativeComponent(scene, bounds, .{ .badge = .{ .label = label } }, .{ .badge_variant = .accent });
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
    return .{
        .bg = palette.bg,
        .panel = palette.card,
        .row = palette.card_alt,
        .border = palette.border,
        .text = palette.text,
        .muted = palette.dim,
        .accent = palette.primary,
    };
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
    try std.testing.expect(hasHit(scene.written(), docs_button_id));
    try std.testing.expect(hasHit(scene.written(), apps_button_id));
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

fn hasHit(commands: []const ui.Command, id: u32) bool {
    for (commands) |command| switch (command) {
        .hit => |hit_command| if (hit_command.id == id) return true,
        else => {},
    };
    return false;
}
