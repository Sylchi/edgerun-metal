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

pub const Breadcrumb = struct {
    id: u32,
    first: []const u8,
    current: []const u8,

    pub fn node(self: Breadcrumb) ui.Node {
        return ui.breadcrumbNode(self.id, self.first, self.current);
    }

    pub fn render(self: Breadcrumb, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderBreadcrumb(scene, bounds, self.first, self.current, options);
    }

    pub fn collectInteractions(self: Breadcrumb, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.breadcrumbItemBounds(bounds, 0), .button, self.id);
        try collector.addHit(component_render.breadcrumbItemBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: Breadcrumb, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_breadcrumb, constraints);
    }

    pub fn toObject(self: Breadcrumb, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.breadcrumb, self.id, self.first, self.current, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Breadcrumb, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .breadcrumb, self.id, self.first, self.current);
    }

    pub fn fromView(view: object.View) Error!Breadcrumb {
        return switch (try component_codec.singleNode(view)) {
            .breadcrumb => |breadcrumb| .{ .id = breadcrumb.id, .first = breadcrumb.first, .current = breadcrumb.current },
            else => error.UnsupportedComponent,
        };
    }
};

test "breadcrumb component serializes to canonical object and deserializes" {
    const breadcrumb = Breadcrumb{ .id = 130, .first = "Home", .current = "Button" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = breadcrumb.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Breadcrumb.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(breadcrumb.id, decoded.id);
    try std.testing.expectEqualStrings(breadcrumb.first, decoded.first);
    try std.testing.expectEqualStrings(breadcrumb.current, decoded.current);
}

test "breadcrumb component renders links current page and link hits" {
    const breadcrumb = Breadcrumb{ .id = 130, .first = "Home", .current = "Button" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try breadcrumb.render(&scene, ui.Rect.init(0, 0, 220, 36), .{});
    try breadcrumb.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Home"));
    try std.testing.expect(component_test.hasText(scene.written(), "Docs"));
    try std.testing.expect(component_test.hasText(scene.written(), "Button"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 131), collector.written()[1].id);
}
