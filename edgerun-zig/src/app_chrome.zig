const std = @import("std");
const icon = @import("icon.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const button_component = @import("ui/components/Button.zig");
const design = @import("app_design.zig");

pub const logo_button_id: u32 = 30_000;
pub const docs_button_id: u32 = 30_001;
pub const launch_button_id: u32 = 30_003;
pub const blog_button_id: u32 = 30_011;
pub const source_button_id: u32 = 30_012;

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
const header_control_gap: f32 = 12.0;
const launch_label = "Launch Desktop";

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
};

const palette = design.palette;

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
    try iconQuad(scene, logo.insetUniform(design.Icon.logo_inset), .terminal, palette.bg);
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

    const launch_w = button_component.preferredWidth(launch_label, null, null);
    const launch = ui.Rect.init(content.x + content.w - launch_w, bounds.y + 16.0, launch_w, design.compact_control_h);
    try button(scene, collector, launch, launch_label, launch_button_id, .primary, null, null);

    const source = ui.Rect.init(launch.x - header_control_gap - design.Icon.logo_box, launch.y, design.Icon.logo_box, design.Icon.logo_box);
    try iconButton(scene, collector, source, .code, source_button_id, active == .source);
}

fn renderCompactHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const logo = ui.Rect.init(content.x, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try fill(scene, logo, palette.primary, 7.0);
    try iconQuad(scene, logo.insetUniform(design.Icon.logo_inset), .terminal, palette.bg);
    try text(scene, logo.x + 40.0, bounds.y + 23.0, 78.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 118.0, logo.h), .button, logo_button_id);

    switch (headerMode(content.w)) {
        .mobile => {
            const docs = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, design.Icon.button_box);
            const source = ui.Rect.init(docs.x - compact_icon_gap - compact_icon_w, docs.y, compact_icon_w, design.Icon.button_box);
            try iconButton(scene, collector, source, .code, source_button_id, active == .source);
            try iconButton(scene, collector, docs, .file, docs_button_id, active == .docs);
            return;
        },
        .compact => {},
        .desktop => unreachable,
    }

    const source = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, design.Icon.button_box);
    try iconButton(scene, collector, source, .code, source_button_id, active == .source);

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
    if (active) try fill(scene, bounds, palette.active, 6.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x, bounds.y + 7.0, bounds.w, nav_text_h), label, if (active) palette.primary else palette.dim, .center);
    try collector.addHit(bounds, .button, id);
}

fn button(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, variant: components.ButtonVariant, leading: ?icon.Icon, trailing: ?icon.Icon) (ui.RenderError || interaction.Error)!void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label, .variant = variant, .leading_icon = leading, .trailing_icon = trailing } }, .{
        .style = style(),
    });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label } });
}

fn iconButton(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, value: icon.Icon, id: u32, active: bool) (ui.RenderError || interaction.Error)!void {
    try fill(scene, bounds, if (active) palette.active else palette.row, 7.0);
    try scene.pushRect(bounds, if (active) palette.primary else palette.border, .border, 7.0, 0.0);
    try iconQuad(scene, bounds.insetUniform(design.Icon.button_inset), value, if (active) palette.primary else palette.text);
    try collector.addHit(bounds, .button, id);
}

pub fn style() ui.Style {
    return design.style();
}

fn navWidth(label: []const u8) f32 {
    return @max(design.min_touch_target, @as(f32, @floatFromInt(label.len)) * nav_average_w + nav_item_pad);
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

test "app chrome header exposes canonical navigation hit targets" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try renderHeader(&scene, &collector, ui.Rect.init(0, 0, 1280, header_h), ui.Rect.init(64, 0, 1152, header_h), .blog);

    try expectHit(collector.written(), logo_button_id);
    try expectHit(collector.written(), docs_button_id);
    try expectHit(collector.written(), blog_button_id);
    try expectHit(collector.written(), source_button_id);
    try expectHit(collector.written(), launch_button_id);
}

test "app chrome header mode follows mobile and compact breakpoints" {
    try std.testing.expectEqual(HeaderMode.mobile, headerMode(mobile_header_breakpoint_w - 1.0));
    try std.testing.expectEqual(HeaderMode.compact, headerMode(mobile_header_breakpoint_w));
    try std.testing.expectEqual(HeaderMode.compact, headerMode(compact_header_breakpoint_w - 1.0));
    try std.testing.expectEqual(HeaderMode.desktop, headerMode(compact_header_breakpoint_w));
}

test "app chrome compact header keeps hit targets separated" {
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
    if (hitRect(collector.written(), blog_button_id)) |blog| try expectNoHorizontalOverlap(blog, source);
    try expectMissingHit(collector.written(), launch_button_id);
}

test "app chrome mobile header uses reference icon controls" {
    var commands: [128]ui.Command = undefined;
    var clips: [4]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try renderHeader(&scene, &collector, ui.Rect.init(0, 0, 390, header_h), ui.Rect.init(28, 0, 334, header_h), .none);

    const logo = expectHitRect(collector.written(), logo_button_id);
    const source = expectHitRect(collector.written(), source_button_id);
    const docs = expectHitRect(collector.written(), docs_button_id);
    try expectNoHorizontalOverlap(logo, source);
    try expectNoHorizontalOverlap(source, docs);
    try expectTouchTarget(source);
    try expectTouchTarget(docs);
    try expectMissingHit(collector.written(), blog_button_id);
    try expectMissingHit(collector.written(), launch_button_id);
    try std.testing.expectEqual(@as(usize, 3), collector.written().len);
}

fn expectHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return;
    return error.MissingHit;
}

fn expectMissingHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return error.UnexpectedHit;
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

fn expectTouchTarget(bounds: ui.Rect) !void {
    try std.testing.expect(bounds.w >= design.min_touch_target);
    try std.testing.expect(bounds.h >= design.min_touch_target);
}
