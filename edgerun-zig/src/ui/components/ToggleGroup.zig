const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const text_component = @import("Text.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

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
        try list_layout.renderSegment(scene, itemBounds(bounds, 0), self.first, active == 0, segmentPaint(options));
        try list_layout.renderSegment(scene, itemBounds(bounds, 1), self.second, active == 1, segmentPaint(options));
        try list_layout.renderSegment(scene, itemBounds(bounds, 2), toggle_group_third_label, active == 2, segmentPaint(options));
    }

    pub fn collectInteractions(self: ToggleGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..toggle_group_item_count) |index| {
            try collector.addHit(itemBounds(bounds, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: ToggleGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const labels = [_][]const u8{ self.first, self.second, toggle_group_third_label };
        return list_layout.measureSegments(&labels, constraints, .{
            .item_count = @intCast(toggle_group_item_count),
            .height = preferred_toggle_group.h,
            .padding = toggle_text_padding,
            .min_width = preferred_toggle_group.w / @as(f32, @floatFromInt(toggle_group_item_count)),
        });
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
        const group = try component_codec.nodeView(view, .toggle_group);
        return fromNode(group);
    }

    pub fn fromNode(group: @FieldType(ui.Node, "toggle_group")) Error!ToggleGroup {
        return .{ .id = group.id, .first = group.first, .second = group.second, .active = activeIndex(group.active) };
    }
};

fn activeIndex(value: u16) u16 {
    return list_layout.clampedIndex(value, toggle_group_item_count);
}

fn encodedId(id: u32, active: u16) u32 {
    return list_layout.encodedIndexedId(id, active, toggle_group_item_count);
}

pub const toggle_group_id_stride: u32 = toggle_group_item_count;

fn segmentPaint(options: RenderOptions) list_layout.SegmentPaint {
    return .{
        .active_fill = options.style.row,
        .inactive_fill = ui.Color.clear,
        .border = options.style.border,
        .active_text = options.style.text,
        .inactive_text = options.style.muted,
        .padding = toggle_text_padding,
    };
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

test "toggle group measurement follows segment labels" {
    const short = ToggleGroup{ .id = 550, .first = "L", .second = "C", .active = 0 };
    const long = ToggleGroup{ .id = 550, .first = "Runtime", .second = "Authority", .active = 0 };

    const short_measured = short.measure(.{}, .{});
    const long_measured = long.measure(.{}, .{});

    try std.testing.expectEqual(preferred_toggle_group.w, short_measured.min.w);
    try std.testing.expect(long_measured.preferred.w > short_measured.preferred.w);
}
