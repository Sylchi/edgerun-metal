const std = @import("std");
const button_component = @import("ui/components/Button.zig");
const icon_component = @import("ui/components/Icon.zig");
const row_item_component = @import("ui/components/RowItem.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const ui_component_common = @import("ui_component_common.zig");
const text_component = @import("ui/components/Text.zig");
const design = @import("app_design.zig");
const app_navigation = @import("app_navigation.zig");

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

pub const NavKind = enum {
    top_text,
    top_icon,
    workspace_rail,
    workspace_sidebar,
};

pub const NavProps = struct {
    kind: NavKind,
    binding: app_navigation.TopLevelBinding,
    bounds: ui.Rect,
    active: bool,
    label: ?[]const u8 = null,
    icon: ?icon_component.Icon = null,
    icon_slot: ?icon_component.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub const ActionNavProps = struct {
    id: u32,
    bounds: ui.Rect,
    label: []const u8,
    active: bool = false,
    enabled: bool = true,
    control_size: ?ui_component_common.ControlSize = null,
    icon_slot: ?icon_component.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub const RouteNavProps = struct {
    kind: NavKind,
    button: app_navigation.MainButton,
    bounds: ui.Rect,
    active: bool,
    label: ?[]const u8 = null,
    icon: ?icon_component.Icon = null,
    icon_slot: ?icon_component.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub const ActionRouteNavProps = struct {
    action: app_navigation.Action,
    bounds: ui.Rect,
    label: []const u8,
    active: bool = false,
    enabled: bool = true,
    control_size: ?ui_component_common.ControlSize = null,
    icon_slot: ?icon_component.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub fn renderActionItem(scene: *ui.Scene, collector: *interaction.Collector, props: ActionNavProps) (ui.RenderError || interaction.Error)!void {
    const control = if (props.active)
        .{ .active = true, .disabled = !props.enabled, .control_size = props.control_size orelse .default }
    else
        .{ .disabled = !props.enabled, .control_size = props.control_size orelse .default };
    const button = button_component.Button{
        .id = props.id,
        .label = props.label,
        .variant = props.variant orelse if (props.active) .secondary else .outline,
        .icon_slot = props.icon_slot orelse .none,
    };
    try button.render(scene, props.bounds, .{
        .style = design.style(),
        .control = control,
    });
    try button.collectInteractions(collector, props.bounds);
}

pub fn renderRouteItem(scene: *ui.Scene, collector: *interaction.Collector, props: RouteNavProps) (ui.RenderError || interaction.Error)!void {
    const binding = app_navigation.topLevelBinding(props.button);
    try renderNavItem(scene, collector, .{
        .kind = props.kind,
        .binding = binding,
        .bounds = props.bounds,
        .active = props.active,
        .label = props.label,
        .icon = props.icon,
        .icon_slot = props.icon_slot,
        .variant = props.variant,
    });
}

pub fn renderActionRouteItem(scene: *ui.Scene, collector: *interaction.Collector, props: ActionRouteNavProps) (ui.RenderError || interaction.Error)!void {
    const id = app_navigation.actionId(props.action);
    try renderActionItem(scene, collector, .{
        .id = id,
        .bounds = props.bounds,
        .label = props.label,
        .active = props.active,
        .enabled = props.enabled,
        .control_size = props.control_size,
        .icon_slot = props.icon_slot,
        .variant = props.variant,
    });
}

pub const ActiveNav = enum {
    none,
    docs,
    blog,
    source,
    agent,
};

const palette = design.palette;

pub fn headerMode(content_w: f32) HeaderMode {
    if (content_w < mobile_header_breakpoint_w) return .mobile;
    if (content_w < compact_header_breakpoint_w) return .compact;
    return .desktop;
}

pub fn renderHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const docs_binding = app_navigation.topLevelBinding(.docs);
    const blog_binding = app_navigation.topLevelBinding(.blog);
    const source_binding = app_navigation.topLevelBinding(.source);

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
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 148.0, logo.h), .button, app_navigation.topLevelBinding(.logo).id);

    const nav_y = bounds.y + 18.0;
    const nav_center = content.x + content.w * 0.5;
    const docs_w = navWidth(docs_binding.row_title);
    const academy_w = navWidth(blog_binding.row_title);
    const nav_total_w = docs_w + academy_w + compact_nav_gap;
    var nav_x = nav_center - nav_total_w * 0.5;
    try renderNavItem(scene, collector, .{
        .kind = .top_text,
        .binding = docs_binding,
        .bounds = ui.Rect.init(nav_x, nav_y, docs_w, nav_item_h),
        .active = isActive(.docs, active),
    });
    nav_x += docs_w + compact_nav_gap;
    try renderNavItem(scene, collector, .{
        .kind = .top_text,
        .binding = blog_binding,
        .bounds = ui.Rect.init(nav_x, nav_y, academy_w, nav_item_h),
        .active = isActive(.blog, active),
    });

    const source = ui.Rect.init(content.x + content.w - design.Icon.logo_box, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try renderNavItem(scene, collector, .{
        .kind = .top_icon,
        .binding = source_binding,
        .bounds = source,
        .active = isActive(.source, active),
    });
}

fn renderCompactHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, active: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const source_binding = app_navigation.topLevelBinding(.source);
    const docs_binding = app_navigation.topLevelBinding(.docs);

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try fill(scene, logo, palette.primary, 7.0);
    try icon_component.Icon.named(.terminal).renderColor(scene, logo.insetUniform(design.Icon.logo_inset), palette.bg);
    try text(scene, logo.x + 40.0, bounds.y + 23.0, 78.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 118.0, logo.h), .button, app_navigation.topLevelBinding(.logo).id);

    switch (headerMode(content.w)) {
        .mobile => {
            const docs = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, design.Icon.button_box);
            const source = ui.Rect.init(docs.x - compact_icon_gap - compact_icon_w, docs.y, compact_icon_w, design.Icon.button_box);
            try renderNavItem(scene, collector, .{
                .kind = .top_icon,
                .binding = source_binding,
                .bounds = source,
                .active = isActive(.source, active),
            });
            try renderNavItem(scene, collector, .{
                .kind = .top_icon,
                .binding = docs_binding,
                .bounds = docs,
                .active = isActive(.docs, active),
            });
            return;
        },
        .compact => {},
        .desktop => unreachable,
    }

    const source = ui.Rect.init(content.x + content.w - compact_icon_w, bounds.y + 15.0, compact_icon_w, design.Icon.button_box);
    try renderNavItem(scene, collector, .{
        .kind = .top_icon,
        .binding = source_binding,
        .bounds = source,
        .active = isActive(.source, active),
    });

    const nav_y = bounds.y + 18.0;
    const nav_right = source.x - compact_nav_gap;
    const blog = app_navigation.topLevelBinding(.blog);
    const docs = app_navigation.topLevelBinding(.docs);
    const blog_w = navWidth(blog.row_title);
    const docs_w = navWidth(docs.row_title);
    const blog_bounds = ui.Rect.init(nav_right - blog_w, nav_y, blog_w, nav_item_h);
    const docs_bounds = ui.Rect.init(blog_bounds.x - compact_nav_gap - docs_w, nav_y, docs_w, nav_item_h);
    const logo_right = logo.x + 118.0 + compact_nav_gap;
    if (docs_bounds.x >= logo_right) {
        try renderNavItem(scene, collector, .{
            .kind = .top_text,
            .binding = docs,
            .bounds = docs_bounds,
            .active = isActive(.docs, active),
        });
        try renderNavItem(scene, collector, .{
            .kind = .top_text,
            .binding = blog,
            .bounds = blog_bounds,
            .active = isActive(.blog, active),
        });
    }
}

fn isActive(button: app_navigation.MainButton, active: ActiveNav) bool {
    return switch (button) {
        .docs => active == .docs,
        .blog => active == .blog,
        .source => active == .source,
        .agent => active == .agent,
        else => false,
    };
}

pub fn renderNavItem(scene: *ui.Scene, collector: *interaction.Collector, props: NavProps) (ui.RenderError || interaction.Error)!void {
    switch (props.kind) {
    .top_text => {
        const variant = props.variant orelse if (props.active) .secondary else .ghost;
        const label = props.label orelse props.binding.row_title;
        const component = button_component.Button{
            .id = props.binding.id,
            .label = label,
            .variant = variant,
            .icon_slot = props.icon_slot orelse .none,
        };
        try component.render(scene, props.bounds, .{ .style = design.style() });
        try component.collectInteractions(collector, props.bounds);
    },
    .top_icon => {
        const variant = props.variant orelse if (props.active) .secondary else .ghost;
        const label = props.label orelse props.binding.icon.label;
        const icon = props.icon orelse props.binding.icon;
        const component = button_component.IconButton{
            .id = props.binding.id,
            .label = label,
            .icon = icon,
            .variant = variant,
        };
        try component.render(scene, props.bounds, .{ .style = design.style() });
        try component.collectInteractions(collector, props.bounds);
    },
    .workspace_rail => {
        const icon = props.icon orelse props.binding.icon;
        const variant = props.variant orelse if (props.active) .secondary else .ghost;
        const component = button_component.IconButton{
            .id = props.binding.id,
            .label = props.binding.rail_label,
            .icon = icon,
            .variant = variant,
        };
        try component.render(scene, props.bounds, .{ .style = design.style() });
        try component.collectInteractions(collector, props.bounds);
    },
    .workspace_sidebar => {
        const title = props.label orelse props.binding.row_title;
        const component = row_item_component.RowItem{
            .id = props.binding.id,
            .title = title,
            .detail = props.binding.row_detail,
        };
        try component.render(scene, props.bounds, .{
            .style = design.style(),
            .control = .{ .active = props.active },
        });
        try component.collectInteractions(collector, props.bounds);
    },
    }
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
