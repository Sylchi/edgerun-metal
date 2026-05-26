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

pub const ButtonGroup = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: ButtonGroup) ui.Node {
        return ui.buttonGroupNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn render(self: ButtonGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = activeIndex(self.active);
        try list_layout.renderSegment(scene, segmentBounds(bounds, 0), self.first, active == 0, segmentPaint(options));
        try list_layout.renderSegment(scene, segmentBounds(bounds, 1), self.second, active == 1, segmentPaint(options));
    }

    pub fn collectInteractions(self: ButtonGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try list_layout.collectEqualSegmentHits(collector, bounds, self.id, group_item_count);
    }

    pub fn measure(self: ButtonGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const labels = [_][]const u8{ self.first, self.second };
        return list_layout.measureSegments(&labels, constraints, .{
            .item_count = @intCast(group_item_count),
            .padding = toggle_text_padding,
        });
    }

    pub fn toObject(self: ButtonGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: ButtonGroup, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .button_group, encodedId(self.id, self.active), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!ButtonGroup {
        const group = try component_codec.nodeView(view, .button_group);
        return fromNode(group);
    }

    pub fn fromNode(group: @FieldType(ui.Node, "button_group")) Error!ButtonGroup {
        return .{ .id = group.id, .first = group.first, .second = group.second, .active = activeIndex(group.active) };
    }
};

fn activeIndex(value: u16) u16 {
    return list_layout.clampedIndex(value, group_item_count);
}

fn encodedId(id: u32, active: u16) u32 {
    return list_layout.encodedIndexedId(id, active, group_item_count);
}

fn segmentPaint(options: RenderOptions) list_layout.SegmentPaint {
    return .{
        .active_fill = options.style.text,
        .inactive_fill = options.style.panel,
        .border = options.style.border,
        .active_text = options.style.panel,
        .inactive_text = options.style.text,
        .padding = toggle_text_padding,
    };
}

fn segmentBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return list_layout.equalSegmentBounds(bounds, index, group_item_count);
}

const group_item_count: u16 = 2;
const toggle_text_padding: f32 = 8.0;

test "button group component serializes to canonical object and deserializes" {
    const group = ButtonGroup{ .id = 90, .first = "Left", .second = "Right", .active = 1 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = group.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try ButtonGroup.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(group.id, decoded.id);
    try std.testing.expectEqualStrings(group.first, decoded.first);
    try std.testing.expectEqualStrings(group.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.active);
}

test "button group component renders segments and hit regions" {
    const group = ButtonGroup{ .id = 90, .first = "Left", .second = "Right", .active = 1 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try group.render(&scene, ui.Rect.init(0, 0, 160, 36), .{});
    try group.collectInteractions(&collector, ui.Rect.init(0, 0, 160, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Left"));
    try std.testing.expect(component_test.hasText(scene.written(), "Right"));
    try std.testing.expectEqual(@as(u32, 91), collector.written()[1].id);
}

test "button group measurement follows segment labels" {
    const short = ButtonGroup{ .id = 90, .first = "L", .second = "R", .active = 0 };
    const long = ButtonGroup{ .id = 90, .first = "Runtime", .second = "Authority", .active = 0 };

    const short_measured = short.measure(.{}, .{});
    const long_measured = long.measure(.{}, .{});

    try std.testing.expect(short_measured.min.w < short_measured.preferred.w);
    try std.testing.expect(long_measured.preferred.w > short_measured.preferred.w);
}
