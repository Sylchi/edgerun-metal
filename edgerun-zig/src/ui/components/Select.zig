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

pub const Select = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Select) ui.Node {
        return ui.selectNode(self.id, self.label);
    }

    pub fn render(self: Select, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderSelect(scene, bounds, self.label, options);
    }

    pub fn collectInteractions(self: Select, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .select, self.id);
    }

    pub fn measure(self: Select, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_select, constraints);
    }

    pub fn toObject(self: Select, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.select, self.id, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Select, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .select, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Select {
        return switch (try component_codec.singleNode(view)) {
            .select => |select| .{ .id = select.id, .label = select.label },
            else => error.UnsupportedComponent,
        };
    }
};

test "select component serializes to canonical object and deserializes" {
    const select = Select{ .id = 22, .label = "Production" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = select.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Select.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(select.id, decoded.id);
    try std.testing.expectEqualStrings(select.label, decoded.label);
}

test "select component renders chevron through icon primitive" {
    const select = Select{ .id = 22, .label = "Production" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try select.render(&scene, ui.Rect.init(0, 0, 220, 40), .{});

    try std.testing.expect(component_test.hasIcon(scene.written(), icon.id(.chevron_right)));
    try std.testing.expect(!component_test.hasText(scene.written(), "v"));
}
