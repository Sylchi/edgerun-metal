const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_render = @import("Render.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Card = struct {
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Card) ui.Node {
        return ui.cardNode(self.title, self.detail);
    }

    pub fn render(self: Card, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderSurface(scene, bounds, self.title, self.detail, options);
    }

    pub fn measure(self: Card, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return component_render.measureSurface(self.title, self.detail, constraints);
    }

    pub fn toObject(self: Card, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.card, 0, self.title, self.detail, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Card, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .card, 0, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Card {
        return switch (try component_codec.singleNode(view)) {
            .card => |card| .{ .title = card.title, .detail = card.detail },
            else => error.UnsupportedComponent,
        };
    }
};

test "card component serializes to canonical object and deserializes" {
    const card = Card{ .title = "Project", .detail = "Interactive docs" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = card.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Card.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(card.title, decoded.title);
    try std.testing.expectEqualStrings(card.detail, decoded.detail);
}

test "card component lays out detail-only content without empty title gap" {
    const card = Card{ .title = "", .detail = "Only detail" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try card.render(&scene, ui.Rect.init(0, 0, 220, 80), .{});

    const detail = component_test.textCommandPrefix(scene.written(), "Only").?;
    try std.testing.expectEqual(component_render.surface_padding, detail.text.origin.y);
    const measured = card.measure(.{}, .{});
    try std.testing.expectEqual(component_render.surface_padding * 2.0 + component_render.surface_detail_height, measured.preferred.h);
    try std.testing.expect(measured.preferred.h < (Card{ .title = "Title", .detail = "Only detail" }).measure(.{}, .{}).preferred.h);
}

test "card component renders surface variants through one renderer" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const card = Card{ .title = "Project", .detail = "Interactive docs" };

    try card.render(&scene, ui.Rect.init(0, 0, 220, 96), .{ .surface_variant = .elevated });
    try card.render(&scene, ui.Rect.init(0, 104, 220, 96), .{ .surface_variant = .subtle });

    try std.testing.expect(component_test.hasShadow(scene.written()));
    try std.testing.expect(component_test.hasRectColor(scene.written(), ui.Color.row));
}

test "card component measurement respects at-most constraints" {
    const card = Card{ .title = "Project", .detail = "Interactive docs" };
    const measured = card.measure(.{ .width = .{ .at_most = 120.0 }, .height = .{ .at_most = 44.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 120.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 44.0), measured.preferred.h);
}
