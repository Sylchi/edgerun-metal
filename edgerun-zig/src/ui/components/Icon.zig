const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const icon = @import("../../icon.zig");
const layout = @import("../../layouts/Types.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../../ui.zig");
const component_codec = @import("Codec.zig");
const component_test = @import("TestSupport.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Icon = struct {
    value: icon.Icon,
    label: []const u8,

    pub fn named(value: icon.Icon) Icon {
        return .{ .value = value, .label = icon.label(value) };
    }

    pub fn node(self: Icon) ui.Node {
        return ui.iconNode(self.label, common.optionalIconTag(self.value));
    }

    pub fn accessibility(self: Icon) common.Accessibility {
        return .{ .role = .image, .label = self.label };
    }

    pub fn render(self: Icon, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try renderGlyph(scene, bounds, self.value, options.style.text);
    }

    pub fn measure(self: Icon, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return primitives.measureFixed(.{ .w = default_size, .h = default_size }, constraints);
    }

    pub fn toObject(self: Icon, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Icon, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        return writer.record(index, .icon, 0, label_ref, .{ .offset = 0, .len = common.optionalIconTag(self.value) });
    }

    pub fn fromView(view: object.View) Error!Icon {
        const node_value = try component_codec.nodeView(view, .icon);
        return fromNode(node_value);
    }

    pub fn fromNode(node_value: @FieldType(ui.Node, "icon")) Error!Icon {
        return .{
            .value = (try common.optionalIconFromTag(node_value.icon)) orelse return error.Corrupt,
            .label = node_value.label,
        };
    }
};

pub fn renderGlyph(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    const size = @max(1.0, @min(bounds.w, bounds.h));
    const centered = ui.Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
    try scene.pushIconQuad(.{ .bounds = centered, .icon_id = icon.id(value), .color = color });
}

pub const default_size: f32 = 18.0;

test "icon component serializes to canonical object and deserializes" {
    const icon_component = Icon.named(.search);
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = icon_component.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Icon.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(icon.Icon.search, decoded.value);
    try std.testing.expectEqualStrings(icon.label(.search), decoded.label);
}

test "icon component renders centered glyph" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(4, 8, 24, 32);

    try Icon.named(.search).render(&scene, bounds, .{});

    const command = component_test.iconCommand(scene.written(), icon.id(.search)).?.icon_quad;
    try std.testing.expectEqual(@as(f32, 4.0), command.bounds.x);
    try std.testing.expectEqual(@as(f32, 12.0), command.bounds.y);
    try std.testing.expectEqual(@as(f32, 24.0), command.bounds.w);
    try std.testing.expectEqual(@as(f32, 24.0), command.bounds.h);
}
