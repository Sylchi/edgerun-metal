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

pub const Textarea = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Textarea) ui.Node {
        return ui.textareaNode(self.id, self.placeholder);
    }

    pub fn render(self: Textarea, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderTextarea(scene, bounds, self.placeholder, options);
    }

    pub fn collectInteractions(self: Textarea, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .textarea, self.id);
    }

    pub fn measure(self: Textarea, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_textarea, constraints);
    }

    pub fn toObject(self: Textarea, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.textarea, self.id, self.placeholder, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Textarea, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .textarea, self.id, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Textarea {
        return switch (try component_codec.singleNode(view)) {
            .textarea => |textarea| .{ .id = textarea.id, .placeholder = textarea.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

test "textarea component serializes to canonical object and deserializes" {
    const textarea = Textarea{ .id = 21, .placeholder = "Describe this app" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = textarea.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Textarea.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(textarea.id, decoded.id);
    try std.testing.expectEqualStrings(textarea.placeholder, decoded.placeholder);
}
