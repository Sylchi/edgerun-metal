const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const text_component = @import("Text.zig");
const icon = @import("../icon.zig");
const icon_pack = @import("../icon_pack.zig");
const layout = @import("../layouts/Types.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../core.zig");
const component_codec = @import("Codec.zig");
const component_test = @import("TestSupport.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const IconSlot = union(enum) {
    none,
    leading: Icon,
    trailing: Icon,
    status: Icon,
    media: Icon,

    pub fn named(kind: SlotKind, value: icon.Icon) IconSlot {
        return of(kind, Icon.named(value));
    }

    pub fn of(kind: SlotKind, value: Icon) IconSlot {
        return switch (kind) {
            .leading => .{ .leading = value },
            .trailing => .{ .trailing = value },
            .status => .{ .status = value },
            .media => .{ .media = value },
        };
    }

    pub fn optional(self: IconSlot) ?Icon {
        return switch (self) {
            .none => null,
            .leading, .trailing, .status, .media => |slot| slot,
        };
    }

    pub fn tag(self: IconSlot) u16 {
        return common.optionalIconTag(if (self.optional()) |slot| slot.value else null);
    }

    pub fn fromTag(kind: SlotKind, encoded_tag: u16) Error!IconSlot {
        return if (try common.optionalIconFromTag(encoded_tag)) |value| named(kind, value) else .none;
    }
};

pub const SlotKind = enum {
    leading,
    trailing,
    status,
    media,
};

pub const Icon = struct {
    value: icon.Icon,
    label: []const u8,

    pub fn named(value: icon.Icon) Icon {
        return .{ .value = value, .label = icon.label(value) };
    }

    pub fn node(self: Icon) ui.Node {
        return ui.iconNode(self.label, self.tag());
    }

    pub fn tag(self: Icon) u16 {
        return common.optionalIconTag(self.value);
    }

    pub fn accessibility(self: Icon) common.Accessibility {
        return .{ .role = .image, .label = self.label };
    }

    pub fn render(self: Icon, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try renderIconGlyph(scene, bounds, self.value, options.style.text);
    }

    pub fn renderColor(self: Icon, scene: *ui.Scene, bounds: ui.Rect, color: ui.Color) ui.RenderError!void {
        try renderIconGlyph(scene, bounds, self.value, color);
    }

    pub fn measure(self: Icon, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureIconIntrinsic(constraints);
    }

    pub fn toObject(self: Icon, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Icon, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        return writer.record(index, .icon, 0, label_ref, .{ .offset = 0, .len = common.optionalIconTag(self.value) });
    }

    pub fn fromView(view: object.View) Error!Icon {
        return component_codec.decodeFromView(Icon, .icon, view);
    }

    pub fn fromNode(node_value: @FieldType(ui.Node, "icon")) Error!Icon {
        return .{
            .value = (try common.optionalIconFromTag(node_value.icon)) orelse return error.Corrupt,
            .label = node_value.label,
        };
    }
};

fn measureIconIntrinsic(constraints: layout.Constraints) layout.Measurement {
    const preferred = primitives.constrainPreferredSize(.{ .w = default_size, .h = default_size }, constraints);
    return layout.Measurement.flexible(preferred, preferred, preferred).applyExact(constraints);
}

fn renderIconGlyph(scene: *ui.Scene, bounds: ui.Rect, value: icon.Icon, color: ui.Color) ui.RenderError!void {
    const size = @max(1.0, @min(bounds.w, bounds.h));
    const centered = ui.Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
    try scene.pushIconQuad(.{ .bounds = centered, .icon_id = icon_pack.iconId(value), .color = color });
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

test "icon slot can be constructed from icon component value" {
    const component = Icon.named(.code);
    const slot = IconSlot.of(.leading, component);

    try std.testing.expectEqual(component, slot.leading);
    try std.testing.expectEqual(component.tag(), slot.tag());
}

test "icon component renders centered glyph" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(4, 8, 24, 32);

    try Icon.named(.search).render(&scene, bounds, .{});

    const command = component_test.iconCommand(scene.written(), icon_pack.iconId(.search)).?.icon_quad;
    try std.testing.expectEqual(@as(f32, 4.0), command.bounds.x);
    try std.testing.expectEqual(@as(f32, 12.0), command.bounds.y);
    try std.testing.expectEqual(@as(f32, 24.0), command.bounds.w);
    try std.testing.expectEqual(@as(f32, 24.0), command.bounds.h);
}

test "icon component measurement derives from icon geometry" {
    const measured = Icon.named(.search).measure(.{}, .{});

    try std.testing.expectEqual(default_size, measured.preferred.w);
    try std.testing.expectEqual(default_size, measured.preferred.h);
}
