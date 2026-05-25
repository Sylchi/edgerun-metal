const std = @import("std");
const icon = @import("icon.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");

pub const logo_button_id: u32 = 30_000;
pub const docs_button_id: u32 = 30_001;
pub const apps_button_id: u32 = 30_002;
pub const launch_button_id: u32 = 30_003;
pub const blog_button_id: u32 = 30_011;
pub const source_button_id: u32 = 30_012;
pub const mobile_menu_button_id: u32 = 30_013;

pub const header_h: f32 = 64.0;
pub const surface_radius: f32 = 8.0;
const compact_header_w: f32 = 720.0;
const compact_mobile_w: f32 = 520.0;
const compact_nav_gap: f32 = 6.0;
const compact_icon_w: f32 = 34.0;
const compact_icon_gap: f32 = 8.0;

pub const ActiveNav = enum {
    none,
    components,
    blog,
    apps,
};

const palette = struct {
    const bg = ui.Color{ .r = 11, .g = 11, .b = 11 };
    const panel = ui.Color{ .r = 18, .g = 18, .b = 18 };
    const row = ui.Color{ .r = 24, .g = 24, .b = 24 };
    const border = ui.Color{ .r = 56, .g = 56, .b = 56 };
    const text = ui.Color{ .r = 242, .g = 242, .b = 242 };
    const dim = ui.Color{ .r = 154, .g = 154, .b = 154 };
    const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const active = ui.Color{ .r = 24, .g = 52, .b = 33 };
};

pub fn renderHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), palette.border, 0.0);

    if (content.w < compact_header_w) {
        try renderCompactHeader(scene, collector, bounds, content, active);
        return;
    }

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, 32.0, 32.0);
    try fill(scene, logo, palette.primary, 7.0);
    try iconQuad(scene, logo.insetUniform(5.0), .terminal, palette.bg);
    try text(scene, logo.x + 42.0, bounds.y + 23.0, 110.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 148.0, logo.h), .button, logo_button_id);

    const nav_y = bounds.y + 18.0;
    const nav_center = content.x + content.w * 0.5;
    try navItem(scene, collector, ui.Rect.init(nav_center - 178.0, nav_y, 116.0, 30.0), "Components", docs_button_id, active == .components);
    try navItem(scene, collector, ui.Rect.init(nav_center - 48.0, nav_y, 96.0, 30.0), "Academy", blog_button_id, active == .blog);
    try navItem(scene, collector, ui.Rect.init(nav_center + 62.0, nav_y, 64.0, 30.0), "Apps", apps_button_id, active == .apps);

    const launch = ui.Rect.init(content.x + content.w - 128.0, bounds.y + 16.0, 128.0, 32.0);
    try button(scene, collector, launch, "Launch Desktop", launch_button_id, .primary, null, null);

    const source = ui.Rect.init(launch.x - 46.0, launch.y, 32.0, 32.0);
    try iconButton(scene, collector, source, .github, source_button_id);
}

fn renderCompactHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const logo = ui.Rect.init(content.x, bounds.y + 16.0, 32.0, 32.0);
    try fill(scene, logo, palette.primary, 7.0);
    try iconQuad(scene, logo.insetUniform(5.0), .terminal, palette.bg);
    try text(scene, logo.x + 40.0, bounds.y + 23.0, 78.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 118.0, logo.h), .button, logo_button_id);

    if (content.w < compact_mobile_w) {
        const menu = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, 34.0);
        const source = ui.Rect.init(menu.x - compact_icon_gap - compact_icon_w, menu.y, compact_icon_w, 34.0);
        try iconButton(scene, collector, source, .github, source_button_id);
        try iconButton(scene, collector, menu, .menu, mobile_menu_button_id);
        return;
    }

    const source = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, 34.0);
    try iconButton(scene, collector, source, .github, source_button_id);

    const nav_y = bounds.y + 18.0;
    const nav_right = source.x - compact_nav_gap;
    const apps = ui.Rect.init(nav_right - 40.0, nav_y, 40.0, 30.0);
    const blog = ui.Rect.init(apps.x - compact_nav_gap - 74.0, nav_y, 74.0, 30.0);
    const docs = ui.Rect.init(blog.x - compact_nav_gap - 42.0, nav_y, 42.0, 30.0);
    const logo_right = logo.x + 118.0 + compact_nav_gap;
    if (docs.x >= logo_right) {
        try navItem(scene, collector, docs, "UI", docs_button_id, active == .components);
        try navItem(scene, collector, blog, "Academy", blog_button_id, active == .blog);
        try navItem(scene, collector, apps, "Apps", apps_button_id, active == .apps);
    }
}

fn navItem(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, active: bool) (ui.RenderError || interaction.Error)!void {
    if (active) try fill(scene, bounds, palette.active, 6.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x, bounds.y + 8.0, bounds.w, 12.0), label, if (active) palette.primary else palette.dim, .center);
    try collector.addHit(bounds, .button, id);
}

fn button(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, variant: components.ButtonVariant, leading: ?icon.Icon, trailing: ?icon.Icon) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label, .variant = variant, .leading_icon = leading, .trailing_icon = trailing } }, .{
        .style = style(),
    });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label } });
}

fn iconButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, value: icon.Icon, id: u32) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, ui.Color.clear, 7.0);
    try iconQuad(scene, bounds.insetUniform(6.0), value, palette.text);
    try collector.addHit(bounds, .button, id);
}

pub fn style() ui.Style {
    return .{
        .bg = palette.bg,
        .panel = palette.panel,
        .row = palette.row,
        .border = palette.border,
        .text = palette.text,
        .muted = palette.dim,
        .accent = palette.primary,
    };
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, r: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, r, 0.0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, .start);
}

fn iconQuad(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    try scene.pushIconQuad(.{ .bounds = bounds, .icon_id = icon.id(value), .color = color });
}

test "site chrome header exposes canonical navigation hit targets" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try renderHeader(&scene, &collector, ui.Rect.init(0, 0, 1280, header_h), ui.Rect.init(64, 0, 1152, header_h), .blog);

    try expectHit(collector.written(), logo_button_id);
    try expectHit(collector.written(), docs_button_id);
    try expectHit(collector.written(), blog_button_id);
    try expectHit(collector.written(), apps_button_id);
    try expectHit(collector.written(), source_button_id);
    try expectHit(collector.written(), launch_button_id);
}

test "site chrome compact header keeps hit targets separated" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try renderHeader(&scene, &collector, ui.Rect.init(0, 0, 640, header_h), ui.Rect.init(28, 0, 584, header_h), .none);

    const logo = expectHitRect(collector.written(), logo_button_id);
    const source = expectHitRect(collector.written(), source_button_id);
    try expectNoHorizontalOverlap(logo, source);
    if (hitRect(collector.written(), docs_button_id)) |docs| try expectNoHorizontalOverlap(logo, docs);
    if (hitRect(collector.written(), apps_button_id)) |apps| try expectNoHorizontalOverlap(apps, source);
}

test "site chrome mobile header uses reference icon controls" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try renderHeader(&scene, &collector, ui.Rect.init(0, 0, 390, header_h), ui.Rect.init(28, 0, 334, header_h), .none);

    const logo = expectHitRect(collector.written(), logo_button_id);
    const source = expectHitRect(collector.written(), source_button_id);
    const menu = expectHitRect(collector.written(), mobile_menu_button_id);
    try expectNoHorizontalOverlap(logo, source);
    try expectNoHorizontalOverlap(source, menu);
    try std.testing.expect(hitRect(collector.written(), docs_button_id) == null);
}

fn expectHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return;
    return error.MissingHit;
}

fn expectHitRect(regions: []const interaction.Region, id: u32) ui.Rect {
    return hitRect(regions, id) orelse unreachable;
}

fn hitRect(regions: []const interaction.Region, id: u32) ?ui.Rect {
    for (regions) |region| if (region.id == id) return region.bounds;
    return null;
}

fn expectNoHorizontalOverlap(left: ui.Rect, right: ui.Rect) !void {
    try std.testing.expect(left.x + left.w <= right.x or right.x + right.w <= left.x);
}
