const std = @import("std");
const component_union = @import("components/Component.zig");
const interaction = @import("interaction.zig");
const ui = @import("core.zig");
const ui_component_common = @import("component_common.zig");
const design = @import("theme.zig");
const app_location = @import("../location.zig");

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
    binding: app_location.TopLevelBinding,
    bounds: ui.Rect,
    active: bool,
    label: ?[]const u8 = null,
    icon: ?component_union.Icon = null,
    icon_slot: ?component_union.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub const ActionNavProps = struct {
    id: u32,
    bounds: ui.Rect,
    label: []const u8,
    active: bool = false,
    enabled: bool = true,
    control_size: ?ui_component_common.ControlSize = null,
    icon_slot: ?component_union.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub const RouteNavProps = struct {
    kind: NavKind,
    button: app_location.MainButton,
    bounds: ui.Rect,
    active: bool,
    label: ?[]const u8 = null,
    icon: ?component_union.Icon = null,
    icon_slot: ?component_union.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub const ActionRouteNavProps = struct {
    action: app_location.Action,
    bounds: ui.Rect,
    label: []const u8,
    active: bool = false,
    enabled: bool = true,
    control_size: ?ui_component_common.ControlSize = null,
    icon_slot: ?component_union.IconSlot = null,
    variant: ?ui_component_common.ButtonVariant = null,
};

pub fn renderActionItem(scene: *ui.Scene, collector: *interaction.Collector, props: ActionNavProps) (ui.RenderError || interaction.Error)!void {
    const control: ui_component_common.ControlState = .{
        .active = props.active,
        .disabled = !props.enabled,
    };
    const app = component_union.renderer(scene, collector, .{})
        .withStyle(design.appStyle())
        .withControl(control)
        .withControlSize(props.control_size orelse .default);
    try app.interactive(component_union.button(
        props.id,
        props.label,
        props.variant orelse activeVariant(props.active, .secondary, .outline),
        props.icon_slot orelse .none,
    ), props.bounds);
}

pub fn renderRouteItem(scene: *ui.Scene, collector: *interaction.Collector, props: RouteNavProps) (ui.RenderError || interaction.Error)!void {
    const binding = app_location.topLevelBinding(props.button);
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
    const id = app_location.actionId(props.action);
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
    const logo_binding = app_location.subNavBinding(.logo);
    const app = component_union.renderer(scene, collector, .{ .style = design.appStyle() });

    try app.fill(bounds, palette.bg, 0.0);
    try app.line(ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0));

    try app.interactive(
        component_union.button(logo_binding.id, "EdgeRun", .ghost, component_union.IconSlot.named(.leading, .terminal)),
        ui.Rect.init(content.x, bounds.y + 13.0, 148.0, 36.0),
    );
}

fn renderCompactHeader(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, content: ui.Rect, _: ActiveNav) (ui.RenderError || interaction.Error)!void {
    const logo_binding = app_location.subNavBinding(.logo);
    const app = component_union.renderer(scene, collector, .{ .style = design.appStyle() });

    try app.interactive(
        component_union.button(logo_binding.id, "EdgeRun", .ghost, component_union.IconSlot.named(.leading, .terminal)),
        ui.Rect.init(content.x, bounds.y + 13.0, 118.0, 36.0),
    );
}

pub fn renderNavItem(scene: *ui.Scene, collector: *interaction.Collector, props: NavProps) (ui.RenderError || interaction.Error)!void {
    const app = component_union.renderer(scene, collector, .{ .style = design.appStyle() });
    switch (props.kind) {
        .top_text => {
            const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);
            const label = props.label orelse props.binding.row_title;
            try app.interactive(component_union.button(props.binding.id, label, variant, props.icon_slot orelse .none), props.bounds);
        },
        .top_icon => {
            const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);
            const label = props.label orelse props.binding.icon.label;
            const icon = props.icon orelse props.binding.icon;
            try app.interactive(component_union.iconButton(props.binding.id, label, icon, variant), props.bounds);
        },
        .workspace_rail => {
            const icon = props.icon orelse props.binding.icon;
            const variant = props.variant orelse activeVariant(props.active, .secondary, .ghost);
            try app.interactive(component_union.iconButton(props.binding.id, props.binding.rail_label, icon, variant), props.bounds);
        },
        .workspace_sidebar => {
            const title = props.label orelse props.binding.row_title;
            try app.interactiveWithControl(component_union.rowItem(props.binding.id, title, props.binding.row_detail), props.bounds, .{ .active = props.active });
        },
    }
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
