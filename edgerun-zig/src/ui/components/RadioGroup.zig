const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const RadioGroup = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    selected: u16 = 0,

    pub fn node(self: RadioGroup) ui.Node {
        return ui.radioGroupNode(self.id, self.first, self.second, selectedIndex(self.selected));
    }

    pub fn render(self: RadioGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderRadioGroup(scene, bounds, self.first, self.second, selectedIndex(self.selected), options);
    }

    pub fn collectInteractions(self: RadioGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.radioOptionBounds(bounds, 0), .button, self.id);
        try collector.addHit(component_render.radioOptionBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: RadioGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_radio_group, constraints);
    }

    pub fn toObject(self: RadioGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: RadioGroup, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .radio_group, encodedId(self.id, self.selected), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!RadioGroup {
        return switch (try component_codec.singleNode(view)) {
            .radio_group => |radio| .{ .id = radio.id, .first = radio.first, .second = radio.second, .selected = selectedIndex(radio.selected) },
            else => error.UnsupportedComponent,
        };
    }
};

fn selectedIndex(value: u16) u16 {
    return @min(value, 1);
}

fn encodedId(id: u32, selected: u16) u32 {
    return id * radio_id_stride + selectedIndex(selected);
}

const radio_id_stride: u32 = 2;

test "radio group component serializes to canonical object and deserializes" {
    const radio = RadioGroup{ .id = 70, .first = "Default", .second = "Comfortable", .selected = 1 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = radio.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try RadioGroup.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(radio.id, decoded.id);
    try std.testing.expectEqualStrings(radio.first, decoded.first);
    try std.testing.expectEqualStrings(radio.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.selected);
}

test "radio group component renders selected indicator and option hits" {
    const radio = RadioGroup{ .id = 70, .first = "Default", .second = "Comfortable", .selected = 1 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try radio.render(&scene, ui.Rect.init(0, 0, 220, 52), .{});
    try radio.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 52));

    try std.testing.expect(component_test.hasFillColor(scene.written(), ui.Color.accent));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 71), collector.written()[1].id);
}
