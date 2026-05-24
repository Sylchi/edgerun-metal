const std = @import("std");
const icon = @import("icon.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");

pub const logo_button_id: u32 = 30_000;
pub const docs_button_id: u32 = 30_001;
pub const apps_button_id: u32 = 30_002;
pub const launch_button_id: u32 = 30_003;
pub const search_button_id: u32 = 30_004;
pub const blog_button_id: u32 = 30_011;
pub const source_button_id: u32 = 30_012;
pub const mobile_menu_button_id: u32 = 30_013;

pub const header_h: f32 = 64.0;
pub const surface_radius: f32 = 8.0;
const compact_header_w: f32 = 720.0;
const compact_mobile_w: f32 = 520.0;
const compact_nav_gap: f32 = 6.0;
const compact_search_w: f32 = 34.0;
const compact_icon_gap: f32 = 8.0;

pub const ActiveNav = enum {
    none,
    docs,
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
    const kbd = ui.Color{ .r = 32, .g = 32, .b = 32 };
};

pub fn renderHeader(scene: *ui.Scene, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) ui.RenderError!void {
    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), palette.border, 0.0);

    if (content.w < compact_header_w) {
        try renderCompactHeader(scene, bounds, content, active);
        return;
    }

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, 32.0, 32.0);
    try fill(scene, logo, palette.primary, 7.0);
    try iconQuad(scene, logo.insetUniform(5.0), .terminal, palette.bg);
    try text(scene, logo.x + 42.0, bounds.y + 23.0, 110.0, 18.0, "EdgeRun", palette.text);
    try hit(scene, ui.Rect.init(logo.x, logo.y, 148.0, logo.h), .button, logo_button_id);

    const nav_y = bounds.y + 18.0;
    const nav_center = content.x + content.w * 0.5;
    try navItem(scene, ui.Rect.init(nav_center - 150.0, nav_y, 68.0, 30.0), "Docs", docs_button_id, active == .docs);
    try navItem(scene, ui.Rect.init(nav_center - 64.0, nav_y, 96.0, 30.0), "Academy", blog_button_id, active == .blog);
    try navItem(scene, ui.Rect.init(nav_center + 50.0, nav_y, 64.0, 30.0), "Apps", apps_button_id, active == .apps);

    const launch = ui.Rect.init(content.x + content.w - 128.0, bounds.y + 16.0, 128.0, 32.0);
    try button(scene, launch, "Launch Desktop", launch_button_id, .primary, null, null);

    const source = ui.Rect.init(launch.x - 46.0, launch.y, 32.0, 32.0);
    try iconButton(scene, source, .github, source_button_id);

    const search = ui.Rect.init(source.x - 154.0, launch.y, 140.0, 32.0);
    try searchButton(scene, search);
}

fn renderCompactHeader(scene: *ui.Scene, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) ui.RenderError!void {
    const logo = ui.Rect.init(content.x, bounds.y + 16.0, 32.0, 32.0);
    try fill(scene, logo, palette.primary, 7.0);
    try iconQuad(scene, logo.insetUniform(5.0), .terminal, palette.bg);
    try text(scene, logo.x + 40.0, bounds.y + 23.0, 78.0, 18.0, "EdgeRun", palette.text);
    try hit(scene, ui.Rect.init(logo.x, logo.y, 118.0, logo.h), .button, logo_button_id);

    if (content.w < compact_mobile_w) {
        const menu = ui.Rect.init(content.x + content.w - compact_search_w, bounds.y + 15.0, compact_search_w, 34.0);
        const source = ui.Rect.init(menu.x - compact_icon_gap - compact_search_w, menu.y, compact_search_w, 34.0);
        try iconButton(scene, source, .github, source_button_id);
        try iconButton(scene, menu, .menu, mobile_menu_button_id);
        return;
    }

    const search = ui.Rect.init(content.x + content.w - compact_search_w, bounds.y + 15.0, compact_search_w, 34.0);
    try compactSearchButton(scene, search);

    const nav_y = bounds.y + 18.0;
    const nav_right = search.x - compact_nav_gap;
    const apps = ui.Rect.init(nav_right - 40.0, nav_y, 40.0, 30.0);
    const blog = ui.Rect.init(apps.x - compact_nav_gap - 74.0, nav_y, 74.0, 30.0);
    const docs = ui.Rect.init(blog.x - compact_nav_gap - 42.0, nav_y, 42.0, 30.0);
    const logo_right = logo.x + 118.0 + compact_nav_gap;
    if (docs.x >= logo_right) {
        try navItem(scene, docs, "Docs", docs_button_id, active == .docs);
        try navItem(scene, blog, "Academy", blog_button_id, active == .blog);
        try navItem(scene, apps, "Apps", apps_button_id, active == .apps);
    }
}

fn searchButton(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.panel, 7.0);
    try scene.pushRect(bounds, palette.border, .border, 7.0, 0.0);
    try iconQuad(scene, ui.Rect.init(bounds.x + 14.0, bounds.y + 8.0, 16.0, 16.0), .search, palette.dim);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + 38.0, bounds.y + 9.0, 52.0, 12.0), "Search", palette.dim, .start);
    const key = ui.Rect.init(bounds.x + bounds.w - 48.0, bounds.y + 6.0, 34.0, 20.0);
    try fill(scene, key, palette.kbd, 4.0);
    try scene.pushRect(key, palette.border, .border, 4.0, 0.0);
    try scene.pushAlignedText(ui.Rect.init(key.x, key.y + 4.0, key.w, 11.0), "K", palette.dim, .center);
    try hit(scene, bounds, .button, search_button_id);
}

fn compactSearchButton(scene: *ui.Scene, bounds: ui.Rect) ui.RenderError!void {
    try fill(scene, bounds, palette.panel, 7.0);
    try scene.pushRect(bounds, palette.border, .border, 7.0, 0.0);
    try iconQuad(scene, bounds.insetUniform(9.0), .search, palette.dim);
    try hit(scene, bounds, .button, search_button_id);
}

fn navItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32, active: bool) ui.RenderError!void {
    if (active) try fill(scene, bounds, palette.active, 6.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x, bounds.y + 8.0, bounds.w, 12.0), label, if (active) palette.primary else palette.dim, .center);
    try hit(scene, bounds, .button, id);
}

fn button(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, id: u32, variant: components.ButtonVariant, leading: ?icon.Icon, trailing: ?icon.Icon) ui.RenderError!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label } }, .{
        .style = style(),
        .button_variant = variant,
        .button_leading_icon = leading,
        .button_trailing_icon = trailing,
    });
}

fn iconButton(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, id: u32) ui.RenderError!void {
    try fill(scene, bounds, ui.Color.clear, 7.0);
    try iconQuad(scene, bounds.insetUniform(6.0), value, palette.text);
    try hit(scene, bounds, .button, id);
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
    try scene.pushIconQuad(.{ .bounds = bounds, .atlas_id = icon.atlasId(value), .color = color });
}

fn hit(scene: *ui.Scene, bounds: ui.Rect, kind: ui.HitKind, id: u32) ui.RenderError!void {
    try scene.pushHit(.{ .slot = 0, .kind = kind, .id = id, .bounds = bounds });
}

test "site chrome header exposes canonical navigation hit targets" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try renderHeader(&scene, ui.Rect.init(0, 0, 1280, header_h), ui.Rect.init(64, 0, 1152, header_h), .blog);

    try expectHit(scene.written(), logo_button_id);
    try expectHit(scene.written(), docs_button_id);
    try expectHit(scene.written(), blog_button_id);
    try expectHit(scene.written(), apps_button_id);
    try expectHit(scene.written(), search_button_id);
    try expectHit(scene.written(), source_button_id);
    try expectHit(scene.written(), launch_button_id);
}

test "site chrome compact header keeps hit targets separated" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try renderHeader(&scene, ui.Rect.init(0, 0, 640, header_h), ui.Rect.init(28, 0, 584, header_h), .none);

    const logo = expectHitRect(scene.written(), logo_button_id);
    const search = expectHitRect(scene.written(), search_button_id);
    try expectNoHorizontalOverlap(logo, search);
    if (hitRect(scene.written(), docs_button_id)) |docs| try expectNoHorizontalOverlap(logo, docs);
    if (hitRect(scene.written(), apps_button_id)) |apps| try expectNoHorizontalOverlap(apps, search);
}

test "site chrome mobile header uses reference icon controls" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    try renderHeader(&scene, ui.Rect.init(0, 0, 390, header_h), ui.Rect.init(28, 0, 334, header_h), .none);

    const logo = expectHitRect(scene.written(), logo_button_id);
    const source = expectHitRect(scene.written(), source_button_id);
    const menu = expectHitRect(scene.written(), mobile_menu_button_id);
    try expectNoHorizontalOverlap(logo, source);
    try expectNoHorizontalOverlap(source, menu);
    try std.testing.expect(hitRect(scene.written(), docs_button_id) == null);
    try std.testing.expect(hitRect(scene.written(), search_button_id) == null);
}

fn expectHit(commands: []const ui.Command, id: u32) !void {
    for (commands) |command| {
        if (command == .hit and command.hit.id == id) return;
    }
    return error.MissingHit;
}

fn expectHitRect(commands: []const ui.Command, id: u32) ui.Rect {
    return hitRect(commands, id) orelse unreachable;
}

fn hitRect(commands: []const ui.Command, id: u32) ?ui.Rect {
    for (commands) |command| {
        if (command == .hit and command.hit.id == id) return command.hit.bounds;
    }
    return null;
}

fn expectNoHorizontalOverlap(left: ui.Rect, right: ui.Rect) !void {
    try std.testing.expect(left.x + left.w <= right.x or right.x + right.w <= left.x);
}
