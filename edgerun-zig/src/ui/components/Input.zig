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

pub const Input = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Input) ui.Node {
        return .{ .input = .{ .id = self.id, .placeholder = self.placeholder } };
    }

    pub fn render(self: Input, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderInput(scene, bounds, self.placeholder, options);
    }

    pub fn collectInteractions(self: Input, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .input, self.id);
    }

    pub fn measure(self: Input, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_input, constraints);
    }

    pub fn toObject(self: Input, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.input, self.id, self.placeholder, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Input, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .input, self.id, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Input {
        return switch (try component_codec.singleNode(view)) {
            .input => |input| .{ .id = input.id, .placeholder = input.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

test "input component serializes to canonical object and deserializes" {
    const input = Input{ .id = 10, .placeholder = "Search objects" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = input.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Input.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(input.id, decoded.id);
    try std.testing.expectEqualStrings(input.placeholder, decoded.placeholder);
}
