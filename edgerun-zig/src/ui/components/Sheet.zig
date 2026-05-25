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

pub const Sheet = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Sheet) ui.Node {
        return ui.sheetNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Sheet, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderSheet(scene, bounds, self.title, self.detail, options);
    }

    pub fn collectInteractions(self: Sheet, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.sheetTriggerBounds(bounds), .button, self.id);
        try collector.addHit(component_render.sheetContentBounds(bounds), .button, self.id + 1);
        try collector.addHit(component_render.sheetCloseBounds(bounds), .button, self.id + 2);
    }

    pub fn measure(self: Sheet, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_sheet, constraints);
    }

    pub fn toObject(self: Sheet, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.sheet, self.id, self.title, self.detail, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Sheet, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .sheet, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Sheet {
        return switch (try component_codec.singleNode(view)) {
            .sheet => |sheet| .{ .id = sheet.id, .title = sheet.title, .detail = sheet.detail },
            else => error.UnsupportedComponent,
        };
    }
};

test "sheet component serializes to canonical object and deserializes" {
    const sheet = Sheet{ .id = 999, .title = "Edit profile", .detail = "Sheet content" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = sheet.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Sheet.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(sheet.id, decoded.id);
    try std.testing.expectEqualStrings(sheet.title, decoded.title);
    try std.testing.expectEqualStrings(sheet.detail, decoded.detail);
}

test "sheet component renders trigger content and hit regions" {
    const sheet = Sheet{ .id = 999, .title = "Edit profile", .detail = "Sheet content" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [3]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try sheet.render(&scene, ui.Rect.init(0, 0, 240, 76), .{});
    try sheet.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 76));

    try std.testing.expect(component_test.hasText(scene.written(), "Edit profile"));
    try std.testing.expect(component_test.hasText(scene.written(), "Sheet content"));
    try std.testing.expectEqual(@as(usize, 3), collector.written().len);
    try std.testing.expectEqual(@as(u32, 1001), collector.written()[2].id);
}
