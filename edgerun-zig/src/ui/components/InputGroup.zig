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

pub const InputGroup = struct {
    id: u32,
    addon: []const u8,
    placeholder: []const u8,

    pub fn node(self: InputGroup) ui.Node {
        return ui.inputGroupNode(self.id, self.addon, self.placeholder);
    }

    pub fn render(self: InputGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderInputGroup(scene, bounds, self.addon, self.placeholder, options);
    }

    pub fn collectInteractions(self: InputGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .input, self.id);
    }

    pub fn measure(self: InputGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_input_group, constraints);
    }

    pub fn toObject(self: InputGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.input_group, self.id, self.addon, self.placeholder, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: InputGroup, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .input_group, self.id, self.addon, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!InputGroup {
        return switch (try component_codec.singleNode(view)) {
            .input_group => |input_group| .{ .id = input_group.id, .addon = input_group.addon, .placeholder = input_group.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

test "input group component serializes to canonical object and deserializes" {
    const input_group = InputGroup{ .id = 91, .addon = "https://", .placeholder = "example.com" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = input_group.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try InputGroup.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(input_group.id, decoded.id);
    try std.testing.expectEqualStrings(input_group.addon, decoded.addon);
    try std.testing.expectEqualStrings(input_group.placeholder, decoded.placeholder);
}

test "input group component renders addon placeholder and input hit" {
    const input_group = InputGroup{ .id = 91, .addon = "https://", .placeholder = "example.com" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try input_group.render(&scene, ui.Rect.init(0, 0, 260, 40), .{});
    try input_group.collectInteractions(&collector, ui.Rect.init(0, 0, 260, 40));

    try std.testing.expect(component_test.hasText(scene.written(), "https://"));
    try std.testing.expect(component_test.hasText(scene.written(), "example.com"));
    try std.testing.expectEqual(ui.HitKind.input, collector.written()[0].kind);
}
