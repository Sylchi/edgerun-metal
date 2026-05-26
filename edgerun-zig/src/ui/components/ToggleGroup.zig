const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

pub const ToggleGroup = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: ToggleGroup) ui.Node {
        return ui.toggleGroupNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn render(self: ToggleGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = activeIndex(self.active);
        try renderItem(scene, itemBounds(bounds, 0), self.first, active == 0, options);
        try renderItem(scene, itemBounds(bounds, 1), self.second, active == 1, options);
        try renderItem(scene, itemBounds(bounds, 2), toggle_group_third_label, active == 2, options);
    }

    pub fn collectInteractions(self: ToggleGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..toggle_group_item_count) |index| {
            try collector.addHit(itemBounds(bounds, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: ToggleGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_toggle_group, constraints);
    }

    pub fn toObject(self: ToggleGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: ToggleGroup, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .toggle_group, encodedId(self.id, self.active), self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!ToggleGroup {
        return switch (try component_codec.singleNode(view)) {
            .toggle_group => |group| .{ .id = group.id, .first = group.first, .second = group.second, .active = activeIndex(group.active) },
            else => error.UnsupportedComponent,
        };
    }
};

fn activeIndex(value: u16) u16 {
    return @min(value, toggle_group_item_count - 1);
}

fn encodedId(id: u32, active: u16) u32 {
    return id * toggle_group_id_stride + activeIndex(active);
}

pub const toggle_group_id_stride: u32 = toggle_group_item_count;

fn renderItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try component_primitives.renderTextCell(scene, bounds, label, if (active) options.style.row else ui.Color.clear, options.style.border, 0.0, toggle_text_padding, if (active) options.style.text else options.style.muted);
}

fn itemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const item_w = switch (index) {
        1 => toggle_group_middle_w,
        else => toggle_group_side_w,
    };
    const item_x = switch (index) {
        0 => bounds.x,
        1 => bounds.x + toggle_group_side_w,
        else => bounds.x + toggle_group_side_w + toggle_group_middle_w,
    };
    return ui.Rect.init(item_x, bounds.y, item_w, bounds.h);
}

pub const toggle_group_item_count: u32 = 3;
const toggle_group_side_w: f32 = 48.0;
const toggle_group_middle_w: f32 = 64.0;
const toggle_group_third_label = "Right";
const toggle_text_padding: f32 = 8.0;
pub const preferred_toggle_group = ui.Size{ .w = 180.0, .h = 36.0 };

test "toggle group component serializes to canonical object and deserializes" {
    const group = ToggleGroup{ .id = 550, .first = "Left", .second = "Center", .active = 1 };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = group.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try ToggleGroup.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(group.id, decoded.id);
    try std.testing.expectEqualStrings(group.first, decoded.first);
    try std.testing.expectEqualStrings(group.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.active);
}

test "toggle group component renders toggles and hit regions" {
    const group = ToggleGroup{ .id = 550, .first = "Left", .second = "Center", .active = 1 };
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [toggle_group_item_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try group.render(&scene, ui.Rect.init(0, 0, 180, 36), .{});
    try group.collectInteractions(&collector, ui.Rect.init(0, 0, 180, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Left"));
    try std.testing.expect(component_test.hasText(scene.written(), "Center"));
    try std.testing.expect(component_test.hasText(scene.written(), "Right"));
    try std.testing.expectEqual(@as(usize, toggle_group_item_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 552), collector.written()[2].id);
}
