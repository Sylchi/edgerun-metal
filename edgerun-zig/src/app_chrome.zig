const std = @import("std");
const button_component = @import("ui/components/Button.zig");
const icon_component = @import("ui/components/Icon.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const text_component = @import("ui/components/Text.zig");
const design = @import("app_design.zig");
const app_navigation = @import("app_navigation.zig");

pub const logo_button_id: u32 = app_navigation.topLevelButtonId(.logo);
pub const docs_button_id: u32 = app_navigation.topLevelButtonId(.docs);
pub const blog_button_id: u32 = app_navigation.topLevelButtonId(.blog);
pub const source_button_id: u32 = app_navigation.topLevelButtonId(.source);
pub const agent_button_id: u32 = app_navigation.topLevelButtonId(.agent);

pub const header_h: f32 = design.header_h;
pub const surface_radius: f32 = design.surface_radius;
pub const compact_header_breakpoint_w: f32 = 720.0;
pub const mobile_header_breakpoint_w: f32 = 520.0;
const compact_nav_gap: f32 = 6.0;
const compact_icon_w: f32 = design.Icon.button_box;
const compact_icon_gap: f32 = 8.0;
const nav_text_h: f32 = 13.0;
const nav_item_h: f32 = 30.0;
const nav_item_pad: f32 = 28.0;
const nav_average_w: f32 = 7.8;

pub const HeaderMode = enum {
    desktop,
    compact,
    mobile,
};

pub const ActiveNav = enum {
    none,
    docs,
    blog,
    source,
    agent,
};

const palette = design.palette;
const retired_desktop_launch_button_id: u32 = 30_003;

pub fn headerMode(content_w: f32) HeaderMode {
    if (content_w < mobile_header_breakpoint_w) return .mobile;
    if (content_w < compact_header_breakpoint_w) return .compact;
    return .desktop;
}

pub fn renderHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), palette.border, 0.0);

    switch (headerMode(content.w)) {
        .desktop => {},
        .compact, .mobile => {
            try renderCompactHeader(scene, collector, bounds, content, active);
            return;
        },
    }

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try fill(scene, logo, palette.primary, 7.0);
    try icon_component.Icon.named(.terminal).renderColor(scene, logo.insetUniform(design.Icon.logo_inset), palette.bg);
    try text(scene, logo.x + 42.0, bounds.y + 23.0, 110.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 148.0, logo.h), .button, logo_button_id);

    const nav_y = bounds.y + 18.0;
    const nav_center = content.x + content.w * 0.5;
    const docs_w = navWidth("Docs");
    const academy_w = navWidth("Academy");
    const nav_total_w = docs_w + academy_w + compact_nav_gap;
    var nav_x = nav_center - nav_total_w * 0.5;
    try navItem(scene, collector, ui.Rect.init(nav_x, nav_y, docs_w, nav_item_h), "Docs", docs_button_id, active == .docs);
    nav_x += docs_w + compact_nav_gap;
    try navItem(scene, collector, ui.Rect.init(nav_x, nav_y, academy_w, nav_item_h), "Academy", blog_button_id, active == .blog);

    const source = ui.Rect.init(content.x + content.w - design.Icon.logo_box, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try iconButton(scene, collector, source, icon_component.Icon.named(.code), source_button_id, active == .source);
}

fn renderCompactHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const logo = ui.Rect.init(content.x, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try fill(scene, logo, palette.primary, 7.0);
    try icon_component.Icon.named(.terminal).renderColor(scene, logo.insetUniform(design.Icon.logo_inset), palette.bg);
    try text(scene, logo.x + 40.0, bounds.y + 23.0, 78.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 118.0, logo.h), .button, logo_button_id);

    switch (headerMode(content.w)) {
        .mobile => {
            const docs = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, design.Icon.button_box);
            const source = ui.Rect.init(docs.x - compact_icon_gap - compact_icon_w, docs.y, compact_icon_w, design.Icon.button_box);
            try iconButton(scene, collector, source, icon_component.Icon.named(.code), source_button_id, active == .source);
            try iconButton(scene, collector, docs, icon_component.Icon.named(.file), docs_button_id, active == .docs);
            return;
        },
        .compact => {},
        .desktop => unreachable,
    }

    const source = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, design.Icon.button_box);
    try iconButton(scene, collector, source, icon_component.Icon.named(.code), source_button_id, active == .source);

    const nav_y = bounds.y + 18.0;
    const nav_right = source.x - compact_nav_gap;
    const blog_w = navWidth("Academy");
    const docs_w = navWidth("Docs");
    const blog = ui.Rect.init(nav_right - blog_w, nav_y, blog_w, nav_item_h);
    const docs = ui.Rect.init(blog.x - compact_nav_gap - docs_w, nav_y, docs_w, nav_item_h);
    const logo_right = logo.x + 118.0 + compact_nav_gap;
    if (docs.x >= logo_right) {
        try navItem(scene, collector, docs, "Docs", docs_button_id, active == .docs);
        try navItem(scene, collector, blog, "Academy", blog_button_id, active == .blog);
    }
}

fn navItem(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, active: bool) (ui.RenderError || interaction.Error)!void {
    const component = button_component.Button{
        .id = id,
        .label = label,
        .variant = if (active) .secondary else .ghost,
    };
    try component.render(scene, bounds, .{ .style = design.style() });
    try component.collectInteractions(collector, bounds);
}

fn iconButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, value: icon_component.Icon, id: u32, active: bool) (ui.RenderError || interaction.Error)!void {
    const component = button_component.IconButton{
        .id = id,
        .label = value.label,
        .icon = value,
        .variant = if (active) .secondary else .ghost,
    };
    try component.render(scene, bounds, .{ .style = design.style() });
    try component.collectInteractions(collector, bounds);
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, radius, 0.0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try text_component.Text.renderAligned(scene, ui.Rect.init(x, y, w, h), value, color, .start);
}

fn navWidth(value: []const u8) f32 {
    return @max(44.0, @as(f32, @floatFromInt(value.len)) * nav_average_w + nav_item_pad);
}

test "header modes cover compact and mobile breakpoints" {
    try std.testing.expectEqual(HeaderMode.desktop, headerMode(900));
    try std.testing.expectEqual(HeaderMode.compact, headerMode(640));
    try std.testing.expectEqual(HeaderMode.mobile, headerMode(480));
}

test "header renders compact source control" {
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try renderHeader(&scene, &collector, ui.Rect.init(0, 0, 640, header_h), ui.Rect.init(20, 0, 600, header_h), .source);
    try std.testing.expect(scene.written().len != 0);
}
