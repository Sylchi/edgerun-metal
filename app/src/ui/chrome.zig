const std = @import("std");
const button_component = @import("components/Button.zig");
const icon_component = @import("components/Icon.zig");
const row_item_component = @import("components/RowItem.zig");
const interaction = @import("interaction.zig");
const ui = @import("core.zig");
const ui_component_common = @import("component_common.zig");
const text_component = @import("components/Text.zig");
const design = @import("theme.zig");
const app_navigation = @import("../route/navigation.zig");

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
    const control: ui_component_common.ControlState = .{
        .active = props.active,
        .disabled = !props.enabled,
    };
    const button = button_component.Button{
        .id = props.id,
        .label = props.label,
        .variant = props.variant orelse activeVariant(props.active, .secondary, .outline),
        .icon_slot = props.icon_slot orelse .none,
    };
    try button.render(scene, props.bounds, .{
        .style = design.appStyle(),
        .control = control,
        .control_size = props.control_size orelse .default,
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
    agent,
};

const palette = design.Palette;

pub fn headerMode(content_w: f32) HeaderMode {
    if (content_w < mobile_header_breakpoint_w) return .mobile;
    if (content_w < compact_header_breakpoint_w) return .compact;
    return .desktop;
}

pub fn renderHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, _: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const logo_binding = app_navigation.subNavBinding(.logo);

    try fill(scene, bounds, palette.bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), palette.border, 0.0);

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try fill(scene, logo, palette.primary, 7.0);
    try icon_component.Icon.named(.terminal).renderColor(scene, logo.insetUniform(design.Icon.logo_inset), palette.bg);
    try text(scene, logo.x + 42.0, bounds.y + 23.0, 110.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 148.0, logo.h), .button, logo_binding.id);
}

fn renderCompactHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, _: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const logo_binding = app_navigation.subNavBinding(.logo);

    const logo = ui.Rect.init(content.x, bounds.y + 16.0, design.Icon.logo_box, design.Icon.logo_box);
    try fill(scene, logo, palette.primary, 7.0);
    try icon_component.Icon.named(.terminal).renderColor(scene, logo.insetUniform(design.Icon.logo_inset), palette.bg);
    try text(scene, logo.x + 40.0, bounds.y + 23.0, 78.0, 18.0, "EdgeRun", palette.text);
    try collector.addHit(ui.Rect.init(logo.x, logo.y, 118.0, logo.h), .button, logo_binding.id);
}

pub fn renderNavItem(scene: *ui.Scene, collector: *interaction.Collector, props: NavProps) (ui.RenderError || interaction.Error)!void {
    switch (props.kind) {
        .top_text => {
            const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);
            const label = props.label orelse props.binding.row_title;
            const component = button_component.Button{
                .id = props.binding.id,
                .label = label,
                .variant = variant,
                .icon_slot = props.icon_slot orelse .none,
            };
            try component.render(scene, props.bounds, .{ .style = design.appStyle() });
            try component.collectInteractions(collector, props.bounds);
        },
        .top_icon => {
            const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);
            const label = props.label orelse props.binding.icon.label;
            const icon = props.icon orelse props.binding.icon;
            const component = button_component.IconButton{
                .id = props.binding.id,
                .label = label,
                .icon = icon,
                .variant = variant,
            };
            try component.render(scene, props.bounds, .{ .style = design.appStyle() });
            try component.collectInteractions(collector, props.bounds);
        },
        .workspace_rail => {
            const icon = props.icon orelse props.binding.icon;
            const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);
            const component = button_component.IconButton{
                .id = props.binding.id,
                .label = props.binding.rail_label,
                .icon = icon,
                .variant = variant,
            };
            try component.render(scene, props.bounds, .{ .style = design.appStyle() });
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
                .style = design.appStyle(),
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

test "header renders compact chrome" {
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try renderHeader(&scene, &collector, ui.Rect.init(0, 0, 640, header_h), ui.Rect.init(20, 0, 600, header_h), .none);
    try std.testing.expect(scene.written().len != 0);
}

fn activeVariant(active: bool, on: ui_component_common.ButtonVariant, off: ui_component_common.ButtonVariant) ui_component_common.ButtonVariant {
    return if (active) on else off;
}
