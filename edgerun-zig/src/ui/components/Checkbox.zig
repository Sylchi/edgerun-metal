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
const icon = @import("../../icon.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Checkbox = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Checkbox) ui.Node {
        return ui.checkboxNode(self.id, self.label, self.checked);
    }

    pub fn render(self: Checkbox, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderCheckbox(scene, bounds, self.label, self.checked, options);
    }

    pub fn collectInteractions(self: Checkbox, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .checkbox, self.id);
    }

    pub fn measure(self: Checkbox, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_checkbox, constraints);
    }

    pub fn toObject(self: Checkbox, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.checkbox, self.id, self.label, component_codec.boolRef(self.checked), ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Checkbox, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .checkbox, self.id, self.label, component_codec.boolRef(self.checked));
    }

    pub fn fromView(view: object.View) Error!Checkbox {
        return switch (try component_codec.singleNode(view)) {
            .checkbox => |checkbox| .{ .id = checkbox.id, .label = checkbox.label, .checked = checkbox.checked },
            else => error.UnsupportedComponent,
        };
    }
};

test "checkbox component serializes to canonical object and deserializes" {
    const checkbox = Checkbox{ .id = 11, .label = "Enable sync", .checked = true };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = checkbox.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Checkbox.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(checkbox.id, decoded.id);
    try std.testing.expectEqualStrings(checkbox.label, decoded.label);
    try std.testing.expectEqual(checkbox.checked, decoded.checked);
}

test "checkbox component renders checked mark through icon primitive" {
    const checked = Checkbox{ .id = 11, .label = "Enable sync", .checked = true };
    const unchecked = Checkbox{ .id = 12, .label = "Disable sync", .checked = false };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try checked.render(&scene, ui.Rect.init(0, 0, 220, 28), .{});
    try unchecked.render(&scene, ui.Rect.init(0, 36, 220, 28), .{});

    try std.testing.expectEqual(@as(usize, 1), component_test.iconCount(scene.written(), icon.id(.check)));
}
