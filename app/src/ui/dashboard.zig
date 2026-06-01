const std = @import("std");
const bytes = @import("../bytes.zig");
const ui = @import("core.zig");
const component = @import("components/Component.zig");
const device_tree = @import("device_tree.zig");
const ui_stream = @import("codec.zig");

pub const Error = device_tree.Error || ui.RenderError || error{DashboardBoundsExceeded};

pub const Dashboard = struct {
    devices: []device_tree.DeviceTree,

    pub fn render(self: *Dashboard, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) Error!void {
        const app = component.renderer(scene, null, .{ .style = style });
        try self.renderView(app, bounds);
    }

    pub fn renderView(self: *Dashboard, app: component.View, bounds: ui.Rect) Error!void {
        var cursor = app.column(bounds, device_gap);
        for (self.devices) |*device| {
            const header_h: f32 = device_header_height;
            const panel_bounds = cursor.take(header_h + device_preferred_height);
            if (!panel_bounds.usable()) break;

            try app.fill(panel_bounds, app.options.style.panel, panel_radius);

            const header_rect = ui.Rect.init(
                panel_bounds.x + panel_inset,
                panel_bounds.y + panel_inset,
                panel_bounds.w - panel_inset * 2,
                header_h - panel_inset,
            );
            try app.text(header_rect, device.name, app.options.style.accent);

            const content_bounds = ui.Rect.init(
                panel_bounds.x + panel_inset,
                panel_bounds.y + header_h,
                panel_bounds.w - panel_inset * 2,
                panel_bounds.h - header_h - panel_inset,
            );
            if (content_bounds.valid()) {
                try device.renderView(app, content_bounds);
            }
        }
    }
};

const device_gap: f32 = 8.0;
const device_header_height: f32 = 28.0;
const device_preferred_height: f32 = 80.0;
const panel_radius: f32 = 6.0;
const panel_inset: f32 = 4.0;

test "dashboard renders two device trees from manual nodes" {
    var arena_mem: [4096]u8 = undefined;

    // Device A: simple text display
    var nodes_a = [_]ui.Node{
        ui.textNode("Temperature", null),
        ui.textNode("22.5°C", null),
    };
    const root_a = ui.columnStack(2, 0, &nodes_a);
    const tree_a = device_tree.DeviceTree.init(1, "sensor-1", root_a, arena_mem[0..2048]);

    // Device B: simple text display
    var nodes_b = [_]ui.Node{
        ui.textNode("Humidity", null),
        ui.textNode("65%", null),
    };
    const root_b = ui.columnStack(2, 0, &nodes_b);
    const tree_b = device_tree.DeviceTree.init(2, "sensor-2", root_b, arena_mem[2048..]);

    var devices = [_]device_tree.DeviceTree{ tree_a, tree_b };
    var dashboard = Dashboard{ .devices = &devices };

    var cmds: [128]ui.Command = undefined;
    var scene = ui.Scene.init(&cmds);
    try dashboard.render(&scene, ui.Rect.init(0, 0, 320, 480), .{});

    try std.testing.expect(scene.commandCount() > 0);

    var found_sensor1 = false;
    var found_sensor2 = false;
    var found_temp = false;
    var found_hum = false;
    for (scene.written()) |cmd| switch (cmd) {
        .text => |t| {
            if (bytes.eql(t.value, "sensor-1")) found_sensor1 = true;
            if (bytes.eql(t.value, "sensor-2")) found_sensor2 = true;
            if (bytes.eql(t.value, "22.5°C")) found_temp = true;
            if (bytes.eql(t.value, "65%")) found_hum = true;
        },
        else => {},
    };
    try std.testing.expect(found_sensor1);
    try std.testing.expect(found_sensor2);
    try std.testing.expect(found_temp);
    try std.testing.expect(found_hum);
}

test "dashboard patches propagate across devices" {
    var arena_mem: [4096]u8 = undefined;

    var nodes_a = [_]ui.Node{
        ui.textNode("Temperature", null),
        ui.textNode("22.5°C", null),
    };
    const root_a = ui.columnStack(2, 0, &nodes_a);
    const tree_a = device_tree.DeviceTree.init(1, "sensor-1", root_a, arena_mem[0..2048]);

    var nodes_b = [_]ui.Node{
        ui.textNode("Switch", null),
        ui.textNode("OFF", null),
    };
    const root_b = ui.columnStack(2, 0, &nodes_b);
    const tree_b = device_tree.DeviceTree.init(2, "sensor-2", root_b, arena_mem[2048..]);

    var devices = [_]device_tree.DeviceTree{ tree_a, tree_b };
    var dashboard = Dashboard{ .devices = &devices };

    // Patch device A's value text (component_id=1 → child index 1)
    var patch_buf: [16]u8 = undefined;
    const wire = ui_stream.encodePatch(&patch_buf, 1, ui.Patch{ .text_value = "23.1°C" }).?;
    try devices[0].applyWirePatch(wire);

    // Patch device B's value text
    const wire2 = ui_stream.encodePatch(&patch_buf, 1, ui.Patch{ .text_value = "ON" }).?;
    try devices[1].applyWirePatch(wire2);

    // Render and verify
    var cmds: [128]ui.Command = undefined;
    var scene = ui.Scene.init(&cmds);
    try dashboard.render(&scene, ui.Rect.init(0, 0, 320, 480), .{});

    var found_a = false;
    var found_b = false;
    for (scene.written()) |cmd| switch (cmd) {
        .text => |t| {
            if (bytes.eql(t.value, "23.1°C")) found_a = true;
            if (bytes.eql(t.value, "ON")) found_b = true;
        },
        else => {},
    };
    try std.testing.expect(found_a);
    try std.testing.expect(found_b);
}
