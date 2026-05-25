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

pub const Field = struct {
    id: u32,
    label: []const u8,
    placeholder: []const u8,

    pub fn node(self: Field) ui.Node {
        return ui.fieldNode(self.id, self.label, self.placeholder);
    }

    pub fn render(self: Field, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderField(scene, bounds, self.label, self.placeholder, options);
    }

    pub fn collectInteractions(self: Field, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.fieldInputBounds(bounds), .input, self.id);
    }

    pub fn measure(self: Field, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_field, constraints);
    }

    pub fn toObject(self: Field, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.field, self.id, self.label, self.placeholder, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Field, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .field, self.id, self.label, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Field {
        return switch (try component_codec.singleNode(view)) {
            .field => |field| .{ .id = field.id, .label = field.label, .placeholder = field.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

test "field component serializes to canonical object and deserializes" {
    const field = Field{ .id = 330, .label = "Email", .placeholder = "m@example.com" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = field.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Field.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(field.id, decoded.id);
    try std.testing.expectEqualStrings(field.label, decoded.label);
    try std.testing.expectEqualStrings(field.placeholder, decoded.placeholder);
}

test "field component renders label input and hit region" {
    const field = Field{ .id = 330, .label = "Email", .placeholder = "m@example.com" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try field.render(&scene, ui.Rect.init(0, 0, 220, 56), .{});
    try field.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 56));

    try std.testing.expect(component_test.hasText(scene.written(), "Email"));
    try std.testing.expect(component_test.hasText(scene.written(), "m@example.com"));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(@as(u32, 330), collector.written()[0].id);
}
