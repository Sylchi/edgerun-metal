const std = @import("std");
const icon_component = @import("components/Icon.zig");
const ui = @import("core.zig");

pub const Error = error{
    InvalidScene,
    CommandBudgetExceeded,
    ClipBudgetExceeded,
    UnsupportedComponent,
};

pub const Axis = enum {
    horizontal,
    vertical,
};

pub const CardStyle = struct {
    radius: f32 = 8.0,
    fill: ui.Color = .panel,
    border: ui.Color = .border,
    shadow: ui.Color = .{ .r = 0, .g = 0, .b = 0, .a = 20 },
};

pub const Painter = struct {
    scene: ?*ui.Scene,

    pub fn init(scene: ?*ui.Scene) Painter {
        return .{ .scene = scene };
    }

    pub fn fillRect(self: Painter, bounds: ui.Rect, radius: f32, color: ui.Color) Error!void {
        const scene = try self.activeScene();
        scene.pushRect(bounds, color, .fill, radius, 0.0) catch |err| return mapRenderError(err);
    }

    pub fn borderRect(self: Painter, bounds: ui.Rect, radius: f32, color: ui.Color) Error!void {
        const scene = try self.activeScene();
        scene.pushRect(bounds, color, .border, radius, 0.0) catch |err| return mapRenderError(err);
    }

    pub fn shadowRect(self: Painter, bounds: ui.Rect, radius: f32, color: ui.Color, shadow: f32) Error!void {
        const scene = try self.activeScene();
        scene.pushRect(bounds, color, .shadow, radius, shadow) catch |err| return mapRenderError(err);
    }

    pub fn panel(self: Painter, bounds: ui.Rect, radius: f32, fill: ui.Color, border: ui.Color) Error!void {
        try self.fillRect(bounds, radius, fill);
        try self.borderRect(bounds, radius, border);
    }

    pub fn card(self: Painter, bounds: ui.Rect, style: CardStyle) Error!void {
        try self.shadowRect(bounds, style.radius, style.shadow, 8.0);
        try self.panel(bounds, style.radius, style.fill, style.border);
    }

    pub fn softCard(self: Painter, bounds: ui.Rect, radius: f32, fill: ui.Color) Error!void {
        var shadow = bounds;
        shadow.y += 10.0;
        try self.shadowRect(shadow, radius, .{ .r = 0, .g = 0, .b = 0, .a = 56 }, 24.0);
        try self.fillRect(bounds, radius, fill);
    }

    pub fn divider(self: Painter, x: f32, y: f32, length: f32, axis: Axis, color: ui.Color) Error!void {
        const bounds = switch (axis) {
            .vertical => ui.Rect.init(x, y, 1.0, length),
            .horizontal => ui.Rect.init(x, y, length, 1.0),
        };
        try self.fillRect(bounds, 0.0, color);
    }

    pub fn dragSource(self: Painter, scope_id: u32, item_id: u32, index: usize, bounds: ui.Rect) Error!void {
        const scene = try self.activeScene();
        scene.pushDragSource(.{ .scope_id = scope_id, .item_id = item_id, .index = index, .bounds = bounds }) catch |err| return mapRenderError(err);
    }

    pub fn dropTarget(self: Painter, scope_id: u32, index: usize, bounds: ui.Rect) Error!void {
        const scene = try self.activeScene();
        scene.pushDropTarget(.{ .scope_id = scope_id, .index = index, .bounds = bounds }) catch |err| return mapRenderError(err);
    }

    pub fn semanticIcon(self: Painter, bounds: ui.Rect, value: icon_component.Icon, color: ui.Color) Error!void {
        const scene = try self.activeScene();
        value.renderColor(scene, bounds, color) catch |err| return mapRenderError(err);
    }

    pub fn textQuad(self: Painter, bounds: ui.Rect, tex_u0: f32, tex_v0: f32, tex_u1: f32, tex_v1: f32, color: ui.Color) Error!void {
        const scene = try self.activeScene();
        scene.pushTextQuad(.{ .bounds = bounds, .u0 = tex_u0, .v0 = tex_v0, .u1 = tex_u1, .v1 = tex_v1, .color = color }) catch |err| return mapRenderError(err);
    }

    pub fn transition(self: Painter, value: ui.Transition) Error!void {
        const scene = try self.activeScene();
        scene.pushTransition(value) catch |err| return mapRenderError(err);
    }

    fn activeScene(self: Painter) Error!*ui.Scene {
        return self.scene orelse error.InvalidScene;
    }
};

fn mapRenderError(err: ui.RenderError) Error {
    return switch (err) {
        error.CommandBudgetExceeded => error.CommandBudgetExceeded,
        error.ClipBudgetExceeded => error.ClipBudgetExceeded,
        error.InvalidBounds => error.CommandBudgetExceeded,
        error.UnsupportedComponent => error.UnsupportedComponent,
    };
}

test "painter rejects missing scene" {
    const painter = Painter.init(null);
    try std.testing.expectError(error.InvalidScene, painter.fillRect(ui.Rect.init(0, 0, 1, 1), 0, .text));
}

test "painter facade pushes scene commands" {
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const painter = Painter.init(&scene);

    try painter.softCard(ui.Rect.init(10.0, 20.0, 100.0, 40.0), 8.0, .panel);
    try painter.panel(ui.Rect.init(0.0, 0.0, 30.0, 20.0), 6.0, .text, .border);
    try painter.divider(5.0, 6.0, 50.0, .horizontal, .border);
    try painter.divider(7.0, 8.0, 30.0, .vertical, .border);
    try painter.dragSource(9, 10, 2, ui.Rect.init(2.0, 3.0, 4.0, 5.0));
    try painter.dropTarget(9, 2, ui.Rect.init(3.0, 4.0, 5.0, 6.0));
    try painter.semanticIcon(ui.Rect.init(20.0, 0.0, 16.0, 16.0), icon_component.Icon.named(.search), .text);
    try painter.textQuad(ui.Rect.init(0.0, 20.0, 16.0, 16.0), 0.0, 0.0, 1.0, 1.0, .text);
    try painter.transition(.{ .id = 7, .property = .opacity, .from = 0.0, .to = 1.0, .duration_ms = 120 });

    var rects: usize = 0;
    var drag_sources: usize = 0;
    var drop_targets: usize = 0;
    var icon_quads: usize = 0;
    var text_quads: usize = 0;
    var transitions: usize = 0;
    for (scene.written()) |command| switch (command) {
        .rect => rects += 1,
        .drag_source => drag_sources += 1,
        .drop_target => drop_targets += 1,
        .icon_quad => icon_quads += 1,
        .text_quad => text_quads += 1,
        .transition => transitions += 1,
        else => {},
    };

    try std.testing.expectEqual(@as(usize, 6), rects);
    try std.testing.expectEqual(@as(usize, 1), drag_sources);
    try std.testing.expectEqual(@as(usize, 1), drop_targets);
    try std.testing.expectEqual(@as(usize, 1), icon_quads);
    try std.testing.expectEqual(@as(usize, 1), text_quads);
    try std.testing.expectEqual(@as(usize, 1), transitions);
}
