const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Avatar = struct {
    label: []const u8,

    pub fn node(self: Avatar) ui.Node {
        return ui.avatarNode(self.label);
    }

    pub fn render(self: Avatar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderAvatar(scene, bounds, self.label, options);
    }

    pub fn measure(self: Avatar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_avatar, constraints);
    }

    pub fn toObject(self: Avatar, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.avatar, 0, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Avatar, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .avatar, 0, self.label);
    }

    pub fn fromView(view: object.View) Error!Avatar {
        return switch (try component_codec.singleNode(view)) {
            .avatar => |avatar| .{ .label = avatar.label },
            else => error.UnsupportedComponent,
        };
    }
};

test "avatar component serializes to canonical object and deserializes" {
    const avatar = Avatar{ .label = "ER" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = avatar.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Avatar.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings("ER", decoded.label);
}

test "avatar component centers initials through shared control text" {
    const avatar = Avatar{ .label = "ER" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try avatar.render(&scene, ui.Rect.init(10, 20, 64, 48), .{});

    const label = component_test.textCommand(scene.written(), "ER").?;
    try std.testing.expectEqual(ui.TextAlign.center, label.text.alignment);
    try std.testing.expectEqual(@as(f32, 28.0), label.text.origin.x);
    try std.testing.expectEqual(@as(f32, 37.0), label.text.origin.y);
}
