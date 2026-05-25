const std = @import("std");
const icon = @import("icon.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const component_gallery = @import("component_gallery.zig");
const site_blog = @import("site_blog.zig");
const site_chrome = @import("site_chrome.zig");

pub const component_catalog_button_id: u32 = 31_001;
pub const academy_button_id: u32 = 31_002;
pub const apps_button_id: u32 = 31_003;

const header_h: f32 = site_chrome.header_h;
const content_wide: f32 = 1180.0;
const content_pad: f32 = 28.0;
const page_top_pad: f32 = 48.0;
const page_bottom_pad: f32 = 120.0;
const section_gap: f32 = 40.0;
const panel_gap: f32 = 16.0;
const panel_radius: f32 = site_chrome.surface_radius;
const hero_h_wide: f32 = 420.0;
const hero_h_compact: f32 = 600.0;
const system_h_wide: f32 = 360.0;
const system_h_compact: f32 = 650.0;
const flow_h_wide: f32 = 430.0;
const flow_h_compact: f32 = 780.0;
const showcase_h_wide: f32 = 390.0;
const showcase_h_compact: f32 = 680.0;
const contract_h_wide: f32 = 330.0;
const contract_h_compact: f32 = 620.0;
const callout_h: f32 = 180.0;
const compact_w: f32 = 760.0;
const narrow_w: f32 = 540.0;
const card_pad: f32 = 18.0;
const line_h: f32 = 18.0;
const stat_h: f32 = 86.0;
const timeline_node: f32 = 30.0;
const timeline_gap: f32 = 18.0;
const sample_button_id: u32 = 31_101;
const sample_input_id: u32 = 31_102;
const sample_switch_id: u32 = 31_103;
const sample_tab_id: u32 = 31_104;

const palette = struct {
    const bg = ui.Color{ .r = 9, .g = 9, .b = 11 };
    const panel = ui.Color{ .r = 18, .g = 18, .b = 20 };
    const panel_alt = ui.Color{ .r = 24, .g = 24, .b = 27 };
    const row = ui.Color{ .r = 32, .g = 32, .b = 36 };
    const border = ui.Color{ .r = 63, .g = 63, .b = 70 };
    const text = ui.Color{ .r = 250, .g = 250, .b = 250 };
    const dim = ui.Color{ .r = 161, .g = 161, .b = 170 };
    const muted = ui.Color{ .r = 113, .g = 113, .b = 122 };
    const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const cyan = ui.Color{ .r = 34, .g = 211, .b = 238 };
    const blue = ui.Color{ .r = 96, .g = 165, .b = 250 };
    const violet = ui.Color{ .r = 167, .g = 139, .b = 250 };
    const amber = ui.Color{ .r = 250, .g = 204, .b = 21 };
    const danger = ui.Color{ .r = 248, .g = 113, .b = 113 };
};

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
};

const Surface = struct {
    title: []const u8,
    detail: []const u8,
    metric: []const u8,
    icon_value: icon.Icon,
    color: ui.Color,
};

const surfaces = [_]Surface{
    .{
        .title = "Landing",
        .detail = "The first runtime proof: local identity, live rendering, and no platform login as root authority.",
        .metric = "runtime signal",
        .icon_value = .terminal,
        .color = palette.primary,
    },
    .{
        .title = "Academy",
        .detail = "A teaching path that explains authority, devices, networks, storage, and app safety in sequence.",
        .metric = "67 lessons",
        .icon_value = .file,
        .color = palette.amber,
    },
    .{
        .title = "Components",
        .detail = "One component catalog rendered by the same EdgeRun scene path across browser and native hosts.",
        .metric = "shared UI",
        .icon_value = .code,
        .color = palette.cyan,
    },
    .{
        .title = "Apps",
        .detail = "App surfaces are allocator-scoped guests with receipts, not bundles of ambient host permissions.",
        .metric = "capability first",
        .icon_value = .app,
        .color = palette.violet,
    },
};

const FlowStep = struct {
    title: []const u8,
    detail: []const u8,
    color: ui.Color,
};

const flow_steps = [_]FlowStep{
    .{ .title = "Author", .detail = "An EdgeRun app creates draft app objects inside the runtime.", .color = palette.primary },
    .{ .title = "Preview", .detail = "The interpreter runs the draft with parent-visible memory for debugging.", .color = palette.cyan },
    .{ .title = "Release", .detail = "The draft becomes canonical WASM, manifest, requirements, and receipts.", .color = palette.blue },
    .{ .title = "Allocate", .detail = "The user's allocator moves memory and storage into child-owned slices.", .color = palette.violet },
    .{ .title = "Share", .detail = "Friends receive executable objects that inherit no network or storage authority.", .color = palette.amber },
};

const Contract = struct {
    title: []const u8,
    detail: []const u8,
};

const contracts = [_]Contract{
    .{ .title = "No inherited network", .detail = "WASM code cannot call the network unless an EdgeRun API grants that exact transition." },
    .{ .title = "No inherited storage", .detail = "Storage is a slice and receipt, not a path the app can wander through." },
    .{ .title = "No parent spying", .detail = "Release children move out of parent-visible memory; parent keeps handles." },
    .{ .title = "User allocator wins", .detail = "Authority bubbles to the user whenever resources or capabilities are granted." },
};

pub fn contentHeight(width: f32) f32 {
    const content_w = @min(content_wide, @max(1.0, width - content_pad * 2.0));
    return header_h + page_top_pad + heroHeight(content_w) + section_gap +
        systemHeight(content_w) + section_gap +
        flowHeight(content_w) + section_gap +
        showcaseHeight(content_w) + section_gap +
        contractHeight(content_w) + section_gap +
        callout_h + page_bottom_pad;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try renderGrid(scene, ui.Rect.init(bounds.x, bounds.y + header_h - state.scroll_y, bounds.w, contentHeight(bounds.w)));

    const content = centered(bounds, content_wide);
    const page_y = header_h + page_top_pad - state.scroll_y;
    const page_clip = ui.Rect.init(bounds.x, bounds.y + header_h, bounds.w, @max(1.0, bounds.h - header_h));
    if (try scene.pushClip(page_clip)) {
        defer scene.popClip();
        var cursor_y = page_y;
        try renderHero(scene, collector, ui.Rect.init(content.x, cursor_y, content.w, heroHeight(content.w)));
        cursor_y += heroHeight(content.w) + section_gap;
        try renderSystem(scene, collector, ui.Rect.init(content.x, cursor_y, content.w, systemHeight(content.w)));
        cursor_y += systemHeight(content.w) + section_gap;
        try renderFlow(scene, ui.Rect.init(content.x, cursor_y, content.w, flowHeight(content.w)));
        cursor_y += flowHeight(content.w) + section_gap;
        try renderShowcase(scene, collector, ui.Rect.init(content.x, cursor_y, content.w, showcaseHeight(content.w)));
        cursor_y += showcaseHeight(content.w) + section_gap;
        try renderContract(scene, ui.Rect.init(content.x, cursor_y, content.w, contractHeight(content.w)));
        cursor_y += contractHeight(content.w) + section_gap;
        try renderCallout(scene, collector, ui.Rect.init(content.x, cursor_y, content.w, callout_h));
    }

    try site_chrome.renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content, .components);
}

fn heroHeight(width: f32) f32 {
    return if (width < compact_w) hero_h_compact else hero_h_wide;
}

fn systemHeight(width: f32) f32 {
    return if (width < compact_w) system_h_compact else system_h_wide;
}

fn flowHeight(width: f32) f32 {
    return if (width < compact_w) flow_h_compact else flow_h_wide;
}

fn showcaseHeight(width: f32) f32 {
    return if (width < compact_w) showcase_h_compact else showcase_h_wide;
}

fn contractHeight(width: f32) f32 {
    return if (width < compact_w) contract_h_compact else contract_h_wide;
}

fn renderHero(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    const split = bounds.w >= compact_w;
    const copy_w = if (split) bounds.w * 0.54 else bounds.w;
    const headline_h: f32 = if (split) 112.0 else 150.0;
    const headline_line_h: f32 = if (bounds.w < narrow_w) 38.0 else 46.0;
    const headline_average_w: f32 = if (bounds.w < narrow_w) 18.0 else 22.0;
    try label(scene, ui.Rect.init(bounds.x, bounds.y, 170.0, 26.0), "EdgeRun Docs", palette.primary);
    try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + 48.0, copy_w, headline_h), "Runtime, authoring, sharing, and UI in one system.", palette.text, .{
        .line_height = headline_line_h,
        .average_char_width = headline_average_w,
        .max_lines = 3,
    });
    const detail_y: f32 = if (split) 182.0 else 218.0;
    try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + detail_y, copy_w, 76.0), "This page is rendered by EdgeRun's own scene, component, route, and WASM browser path. It explains how the landing page, Academy, component preview, and app release model fit together.", palette.dim, .{
        .line_height = 20.0,
        .average_char_width = 9.3,
        .max_lines = 4,
    });
    const button_offset_y: f32 = if (split) 288.0 else 330.0;
    const button_y = bounds.y + button_offset_y;
    try primaryButton(scene, collector, ui.Rect.init(bounds.x, button_y, 176.0, 38.0), "Components", component_catalog_button_id);
    try outlineButton(scene, collector, ui.Rect.init(bounds.x + 190.0, button_y, 142.0, 38.0), "Academy", academy_button_id);

    const diagram = if (split) ui.Rect.init(bounds.x + copy_w + 52.0, bounds.y + 34.0, bounds.w - copy_w - 52.0, 332.0) else ui.Rect.init(bounds.x, bounds.y + 404.0, bounds.w, 150.0);
    try renderRuntimeDiagram(scene, diagram, split);
}

fn renderRuntimeDiagram(scene: *ui.Scene, bounds: ui.Rect, wide: bool) ui.RenderError!void {
    try fill(scene, bounds, palette.panel, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    try text(scene, bounds.x + card_pad, bounds.y + 18.0, bounds.w - card_pad * 2.0, 16.0, "EdgeRun object runtime", palette.text);
    const labels = [_][]const u8{ "author", "preview", "release", "allocate", "share" };
    if (wide) {
        var y = bounds.y + 58.0;
        for (labels, 0..) |value, index| {
            const color = flow_steps[index].color;
            try fill(scene, ui.Rect.init(bounds.x + 22.0, y, 10.0, 10.0), color, 5.0);
            try text(scene, bounds.x + 46.0, y - 3.0, bounds.w - 68.0, 14.0, value, palette.dim);
            if (index + 1 < labels.len) try fill(scene, ui.Rect.init(bounds.x + 26.0, y + 14.0, 2.0, 26.0), palette.border, 0.0);
            y += 44.0;
        }
    } else {
        const cell_w = bounds.w / @as(f32, @floatFromInt(labels.len));
        for (labels, 0..) |value, index| {
            const x = bounds.x + @as(f32, @floatFromInt(index)) * cell_w;
            try fill(scene, ui.Rect.init(x + cell_w * 0.5 - 5.0, bounds.y + 70.0, 10.0, 10.0), flow_steps[index].color, 5.0);
            try scene.pushAlignedText(ui.Rect.init(x + 2.0, bounds.y + 94.0, cell_w - 4.0, 12.0), value, palette.dim, .center);
        }
    }
}

fn renderSystem(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try sectionTitle(scene, bounds, "What this repo already has", "Landing, Academy, Components, and Apps are not separate websites. They are route states rendered by the same EdgeRun UI core.");
    const cols = if (bounds.w < compact_w) @as(usize, 1) else @as(usize, 4);
    const start_y = bounds.y + 92.0;
    const card_h: f32 = if (cols == 1) 124.0 else 210.0;
    const card_w = (bounds.w - panel_gap * @as(f32, @floatFromInt(cols - 1))) / @as(f32, @floatFromInt(cols));
    for (surfaces, 0..) |surface, index| {
        const row = index / cols;
        const col = index % cols;
        const card = ui.Rect.init(bounds.x + @as(f32, @floatFromInt(col)) * (card_w + panel_gap), start_y + @as(f32, @floatFromInt(row)) * (card_h + panel_gap), card_w, card_h);
        try renderSurfaceCard(scene, collector, card, surface, index);
    }
}

fn renderSurfaceCard(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, surface: Surface, index: usize) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.panel, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    try iconQuad(scene, ui.Rect.init(bounds.x + card_pad, bounds.y + card_pad, 24.0, 24.0), surface.icon_value, surface.color);
    try text(scene, bounds.x + 52.0, bounds.y + 21.0, bounds.w - 70.0, 16.0, surface.title, palette.text);
    try label(scene, ui.Rect.init(bounds.x + card_pad, bounds.y + 56.0, @min(150.0, bounds.w - card_pad * 2.0), 24.0), surface.metric, surface.color);
    try scene.pushWrappedText(ui.Rect.init(bounds.x + card_pad, bounds.y + 96.0, bounds.w - card_pad * 2.0, bounds.h - 112.0), surface.detail, palette.dim, .{
        .line_height = line_h,
        .average_char_width = 8.8,
        .max_lines = 4,
    });
    const id = switch (index) {
        1 => academy_button_id,
        2 => component_catalog_button_id,
        3 => apps_button_id,
        else => 0,
    };
    if (id != 0) try collector.addHit(bounds, .button, id);
}

fn renderFlow(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try sectionTitle(scene, bounds, "How app creation works", "Draft apps run visibly in preview. Released apps move into user-allocator slices and only expose handles, receipts, and explicit shares.");
    const start_y = bounds.y + 100.0;
    if (bounds.w < compact_w) {
        var y = start_y;
        for (flow_steps) |step| {
            try renderFlowStep(scene, ui.Rect.init(bounds.x, y, bounds.w, 112.0), step);
            y += 112.0 + timeline_gap;
        }
        return;
    }

    const step_w = (bounds.w - timeline_gap * @as(f32, @floatFromInt(flow_steps.len - 1))) / @as(f32, @floatFromInt(flow_steps.len));
    for (flow_steps, 0..) |step, index| {
        const x = bounds.x + @as(f32, @floatFromInt(index)) * (step_w + timeline_gap);
        if (index + 1 < flow_steps.len) try fill(scene, ui.Rect.init(x + step_w - 2.0, start_y + timeline_node * 0.5, timeline_gap + 4.0, 2.0), palette.border, 0.0);
        try renderFlowStep(scene, ui.Rect.init(x, start_y, step_w, 238.0), step);
    }
}

fn renderFlowStep(scene: *ui.Scene, bounds: ui.Rect, step: FlowStep) ui.RenderError!void {
    try fill(scene, bounds, palette.panel, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    try fill(scene, ui.Rect.init(bounds.x + card_pad, bounds.y + card_pad, timeline_node, timeline_node), step.color, timeline_node * 0.5);
    try text(scene, bounds.x + card_pad, bounds.y + 62.0, bounds.w - card_pad * 2.0, 18.0, step.title, palette.text);
    try scene.pushWrappedText(ui.Rect.init(bounds.x + card_pad, bounds.y + 92.0, bounds.w - card_pad * 2.0, bounds.h - 108.0), step.detail, palette.dim, .{
        .line_height = line_h,
        .average_char_width = 8.6,
        .max_lines = 4,
    });
}

fn renderShowcase(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try sectionTitle(scene, bounds, "The docs page uses the product UI", "Buttons, cards, inputs, progress, switches, tabs, icons, and text all come from the shared EdgeRun component system.");
    const split = bounds.w >= compact_w;
    const preview = if (split) ui.Rect.init(bounds.x, bounds.y + 96.0, bounds.w * 0.48, bounds.h - 96.0) else ui.Rect.init(bounds.x, bounds.y + 96.0, bounds.w, 250.0);
    const explanation = if (split) ui.Rect.init(bounds.x + bounds.w * 0.52, bounds.y + 96.0, bounds.w * 0.48, bounds.h - 96.0) else ui.Rect.init(bounds.x, bounds.y + 368.0, bounds.w, bounds.h - 368.0);
    try renderComponentSample(scene, collector, preview);
    try renderShowcaseCopy(scene, explanation);
}

fn renderComponentSample(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.panel, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    const inset = bounds.insetUniform(card_pad);
    try components.renderComponent(scene, ui.Rect.init(inset.x, inset.y, inset.w, 74.0), .{ .card = .{ .title = "Draft app", .detail = "Preview memory visible to parent" } }, .{ .style = siteStyle() });
    try components.renderComponent(scene, ui.Rect.init(inset.x, inset.y + 92.0, @min(220.0, inset.w), 40.0), .{ .input = .{ .id = sample_input_id, .placeholder = "Search components" } }, .{ .style = siteStyle() });
    try components.collectComponentInteractions(collector, ui.Rect.init(inset.x, inset.y + 92.0, @min(220.0, inset.w), 40.0), .{ .input = .{ .id = sample_input_id, .placeholder = "Search components" } });
    try components.renderComponent(scene, ui.Rect.init(inset.x, inset.y + 152.0, @min(180.0, inset.w), 36.0), .{ .button = .{ .id = sample_button_id, .label = "Release", .trailing_icon = .chevron_right } }, .{ .style = siteStyle() });
    try components.collectComponentInteractions(collector, ui.Rect.init(inset.x, inset.y + 152.0, @min(180.0, inset.w), 36.0), .{ .button = .{ .id = sample_button_id, .label = "Release" } });
    try components.renderComponent(scene, ui.Rect.init(inset.x, inset.y + 208.0, @min(220.0, inset.w), 24.0), .{ .progress = .{ .value = 0.68 } }, .{ .style = siteStyle() });
    if (inset.w > 360.0) {
        const side_x = inset.x + 252.0;
        try components.renderComponent(scene, ui.Rect.init(side_x, inset.y + 94.0, @min(180.0, inset.x + inset.w - side_x), 36.0), .{ .switch_control = .{ .id = sample_switch_id, .label = "Parent-visible", .checked = true } }, .{ .style = siteStyle() });
        try components.renderComponent(scene, ui.Rect.init(side_x, inset.y + 152.0, @min(190.0, inset.x + inset.w - side_x), 34.0), .{ .tabs = .{ .id = sample_tab_id, .first = "Preview", .second = "Release", .active = 0 } }, .{ .style = siteStyle() });
        try components.renderComponent(scene, ui.Rect.init(side_x, inset.y + 208.0, 112.0, 26.0), .{ .badge = .{ .label = "no ambient IO", .variant = .outline } }, .{ .style = siteStyle() });
    }
}

fn renderShowcaseCopy(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const rows = [_]Contract{
        .{ .title = "Scene", .detail = "The page emits EdgeRun draw commands, clips, icons, and text." },
        .{ .title = "Components", .detail = "Controls are canonical component objects rendered by `ui_components.zig`." },
        .{ .title = "Routes", .detail = "`/docs`, `/academy`, `/apps`, and `/docs/components/<slug>` share route state." },
        .{ .title = "Targets", .detail = "Browser, CPU, GPU, Wayland, and native hosts consume the same page contract." },
    };
    var y = bounds.y;
    for (rows) |row| {
        try fill(scene, ui.Rect.init(bounds.x, y, bounds.w, stat_h), palette.panel_alt, panel_radius);
        try text(scene, bounds.x + card_pad, y + 18.0, bounds.w - card_pad * 2.0, 16.0, row.title, palette.text);
        try scene.pushWrappedText(ui.Rect.init(bounds.x + card_pad, y + 42.0, bounds.w - card_pad * 2.0, 36.0), row.detail, palette.dim, .{
            .line_height = 17.0,
            .average_char_width = 8.5,
            .max_lines = 2,
        });
        y += stat_h + 10.0;
    }
}

fn renderContract(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try sectionTitle(scene, bounds, "What shared executables can and cannot do", "The safety model is not a warning dialog. WASM starts with no inherited storage, network, device, identity, or parent memory authority.");
    const cols = if (bounds.w < compact_w) @as(usize, 1) else @as(usize, 2);
    const card_w = (bounds.w - panel_gap * @as(f32, @floatFromInt(cols - 1))) / @as(f32, @floatFromInt(cols));
    const card_h = 104.0;
    const start_y = bounds.y + 96.0;
    for (contracts, 0..) |item, index| {
        const row = index / cols;
        const col = index % cols;
        const card = ui.Rect.init(bounds.x + @as(f32, @floatFromInt(col)) * (card_w + panel_gap), start_y + @as(f32, @floatFromInt(row)) * (card_h + panel_gap), card_w, card_h);
        try fill(scene, card, palette.panel, panel_radius);
        try stroke(scene, card, palette.border, panel_radius);
        try text(scene, card.x + card_pad, card.y + 18.0, card.w - card_pad * 2.0, 16.0, item.title, palette.text);
        try scene.pushWrappedText(ui.Rect.init(card.x + card_pad, card.y + 44.0, card.w - card_pad * 2.0, 44.0), item.detail, palette.dim, .{
            .line_height = 17.0,
            .average_char_width = 8.6,
            .max_lines = 3,
        });
    }
}

fn renderCallout(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.panel, panel_radius);
    try stroke(scene, bounds, palette.primary, panel_radius);
    try text(scene, bounds.x + card_pad, bounds.y + 24.0, bounds.w - card_pad * 2.0, 20.0, "Use this page as the map for the system.", palette.text);
    try scene.pushWrappedText(ui.Rect.init(bounds.x + card_pad, bounds.y + 58.0, bounds.w - card_pad * 2.0, 48.0), "Landing proves the runtime is live. Academy teaches why the authority model matters. Components show the UI vocabulary. Apps and WASM turn that into shareable software.", palette.dim, .{
        .line_height = line_h,
        .average_char_width = 8.8,
        .max_lines = 3,
    });
    const button_y = bounds.y + bounds.h - 56.0;
    try primaryButton(scene, collector, ui.Rect.init(bounds.x + card_pad, button_y, 186.0, 36.0), "Open components", component_catalog_button_id);
}

fn sectionTitle(scene: *ui.Scene, bounds: ui.Rect, title_value: []const u8, detail: []const u8) ui.RenderError!void {
    try text(scene, bounds.x, bounds.y, bounds.w, 24.0, title_value, palette.text);
    try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y + 34.0, bounds.w, 44.0), detail, palette.dim, .{
        .line_height = line_h,
        .average_char_width = 9.0,
        .max_lines = 2,
    });
}

fn primaryButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label_value: []const u8, id: u32) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label_value, .trailing_icon = .chevron_right } }, .{
        .style = siteStyle(),
    });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label_value } });
}

fn outlineButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label_value: []const u8, id: u32) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label_value, .variant = .outline } }, .{
        .style = siteStyle(),
    });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label_value } });
}

fn siteStyle() ui.Style {
    var resolved = site_chrome.style();
    resolved.panel = palette.panel_alt;
    resolved.row = palette.row;
    resolved.border = palette.border;
    resolved.text = palette.text;
    resolved.muted = palette.dim;
    resolved.accent = palette.primary;
    return resolved;
}

fn label(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
    try fill(scene, bounds, palette.row, 5.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + 8.0, bounds.y + 7.0, bounds.w - 16.0, 10.0), value, color, .center);
}

fn renderGrid(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    const grid: f32 = 28.0;
    var x = bounds.x;
    while (x < bounds.x + bounds.w) : (x += grid) {
        try fill(scene, ui.Rect.init(x, bounds.y, 1.0, bounds.h), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 5 }, 0.0);
    }
    var y = bounds.y;
    while (y < bounds.y + bounds.h) : (y += grid) {
        try fill(scene, ui.Rect.init(bounds.x, y, bounds.w, 1.0), ui.Color{ .r = 255, .g = 255, .b = 255, .a = 4 }, 0.0);
    }
}

fn centered(bounds: ui.Rect, max_w: f32) ui.Rect {
    const width = @min(max_w, @max(1.0, bounds.w - content_pad * 2.0));
    return ui.Rect.init(bounds.x + (bounds.w - width) * 0.5, bounds.y, width, bounds.h);
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, radius, 0.0);
}

fn stroke(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .border, radius, 0.0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, .start);
}

fn iconQuad(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    try scene.pushIconQuad(.{ .bounds = bounds, .icon_id = icon.id(value), .color = color });
}

test "docs page renders system documentation with shared components" {
    var commands: [2048]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [128]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeight(1280.0)), .{});

    try std.testing.expect(hasTextPrefix(scene.written(), "Runtime, authoring"));
    try std.testing.expect(hasText(scene.written(), "What this repo already has"));
    try std.testing.expect(hasText(scene.written(), "How app creation works"));
    try std.testing.expect(hasHit(collector.written(), sample_input_id));
    try std.testing.expect(hasHit(collector.written(), component_catalog_button_id));
    try std.testing.expect(hasHit(collector.written(), academy_button_id));
    try std.testing.expect(hasHit(collector.written(), site_chrome.docs_button_id));
    try std.testing.expect(component_gallery.component_catalog.len > 0);
    try std.testing.expect(site_blog.posts.len > 0);
}

test "docs page content height grows for compact layout" {
    try std.testing.expect(contentHeight(390.0) > contentHeight(1280.0));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.eql(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasTextPrefix(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| switch (command) {
        .text => |text_command| if (std.mem.startsWith(u8, text_command.value, value)) return true,
        else => {},
    };
    return false;
}

fn hasHit(regions: []const interaction.Region, id: u32) bool {
    for (regions) |region| if (region.id == id) return true;
    return false;
}
