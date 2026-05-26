const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Empty = struct {
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Empty) ui.Node {
        return ui.emptyNode(self.title, self.detail);
    }

    pub fn render(self: Empty, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderEmpty(scene, bounds, self.title, self.detail, options);
    }

    pub fn measure(self: Empty, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_empty, constraints);
    }

    pub fn toObject(self: Empty, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.empty, 0, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Empty, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .empty, 0, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Empty {
        return switch (try component_codec.singleNode(view)) {
            .empty => |empty| .{ .title = empty.title, .detail = empty.detail },
            else => error.UnsupportedComponent,
        };
    }
};

test "empty component serializes to canonical object and deserializes" {
    const empty = Empty{ .title = "No results", .detail = "Try another filter." };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = empty.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Empty.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(empty.title, decoded.title);
    try std.testing.expectEqualStrings(empty.detail, decoded.detail);
}

test "empty component renders media title and description" {
    const empty = Empty{ .title = "No results", .detail = "Try another filter." };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try empty.render(&scene, ui.Rect.init(0, 0, 260, 132), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "No results"));
    try std.testing.expect(component_test.hasText(scene.written(), "Try another filter."));
}
