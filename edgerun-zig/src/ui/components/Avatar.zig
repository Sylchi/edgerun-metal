const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const contentInset = component_primitives.contentInset;
const measureFixed = component_primitives.measureFixed;

pub const Avatar = struct {
    label: []const u8,

    pub fn node(self: Avatar) ui.Node {
        return ui.avatarNode(self.label);
    }

    pub fn render(self: Avatar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const size = @min(avatar_size, @max(component_primitives.min_extent, @min(bounds.w, bounds.h)));
        const avatar_bounds = ui.Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
        try scene.pushRect(avatar_bounds, options.style.row, .fill, size * 0.5, 0.0);
        try scene.pushRect(avatar_bounds, options.style.border, .border, size * 0.5, 0.0);
        if (contentInset(avatar_bounds, avatar_label_inset)) |text_bounds| {
            try scene.pushAlignedText(text_bounds.withHeightCentered(avatar_text_height), self.label, options.style.text, .center);
        }
    }

    pub fn measure(self: Avatar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_avatar, constraints);
    }

    pub fn toObject(self: Avatar, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.avatar, 0, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Avatar, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .avatar, 0, self.label);
    }

    pub fn fromView(view: object.View) Error!Avatar {
        const avatar = try component_codec.nodeView(view, .avatar);
        return .{ .label = avatar.label };
    }
};

const avatar_size: f32 = 40.0;
const avatar_text_height: f32 = 14.0;
const avatar_label_inset: f32 = 6.0;
pub const preferred_avatar = ui.Size{ .w = 40.0, .h = 40.0 };

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
