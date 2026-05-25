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

pub const Combobox = struct {
    id: u32,
    placeholder: []const u8,
    selected: []const u8,

    pub fn node(self: Combobox) ui.Node {
        return ui.comboboxNode(self.id, self.placeholder, self.selected);
    }

    pub fn render(self: Combobox, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderCombobox(scene, bounds, self.placeholder, self.selected, options);
    }

    pub fn collectInteractions(self: Combobox, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.comboboxInputBounds(bounds), .input, self.id);
        try collector.addHit(component_render.comboboxOptionBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: Combobox, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_combobox, constraints);
    }

    pub fn toObject(self: Combobox, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.combobox, self.id, self.placeholder, self.selected, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Combobox, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .combobox, self.id, self.placeholder, self.selected);
    }

    pub fn fromView(view: object.View) Error!Combobox {
        return switch (try component_codec.singleNode(view)) {
            .combobox => |combobox| .{ .id = combobox.id, .placeholder = combobox.placeholder, .selected = combobox.selected },
            else => error.UnsupportedComponent,
        };
    }
};

test "combobox component serializes to canonical object and deserializes" {
    const combobox = Combobox{ .id = 991, .placeholder = "Search framework", .selected = "React" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = combobox.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Combobox.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(combobox.id, decoded.id);
    try std.testing.expectEqualStrings(combobox.placeholder, decoded.placeholder);
    try std.testing.expectEqualStrings(combobox.selected, decoded.selected);
}

test "combobox component renders input option and hit regions" {
    const combobox = Combobox{ .id = 991, .placeholder = "Search framework", .selected = "React" };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try combobox.render(&scene, ui.Rect.init(0, 0, 240, 82), .{});
    try combobox.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 82));

    try std.testing.expect(component_test.hasText(scene.written(), "Search framework"));
    try std.testing.expect(component_test.hasText(scene.written(), "React"));
    try std.testing.expect(component_test.hasIcon(scene.written(), @import("../../icon.zig").id(.check)));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.input, collector.written()[0].kind);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[1].kind);
}
