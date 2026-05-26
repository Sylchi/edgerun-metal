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

pub const Accordion = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    open: bool = false,

    pub fn node(self: Accordion) ui.Node {
        return ui.accordionNode(self.id, self.title, self.detail, self.open);
    }

    pub fn render(self: Accordion, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderAccordion(scene, bounds, self.title, self.detail, self.open, options);
    }

    pub fn collectInteractions(self: Accordion, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, component_render.accordionTriggerBounds(bounds), .button, self.id);
    }

    pub fn measure(self: Accordion, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_accordion, constraints);
    }

    pub fn toObject(self: Accordion, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Accordion, writer: *component_codec.Writer, index: usize) bool {
        const title_ref = writer.string(self.title) orelse return false;
        const detail_ref = writer.string(self.detail) orelse return false;
        return writer.record(index, .accordion, encodedId(self.id, self.open), title_ref, detail_ref);
    }

    pub fn fromView(view: object.View) Error!Accordion {
        return switch (try component_codec.singleNode(view)) {
            .accordion => |accordion| .{ .id = accordion.id, .title = accordion.title, .detail = accordion.detail, .open = accordion.open },
            else => error.UnsupportedComponent,
        };
    }
};

fn encodedId(id: u32, open: bool) u32 {
    const open_value: u32 = if (open) 1 else 0;
    return id * accordion_id_stride + open_value;
}

const accordion_id_stride: u32 = 2;

test "accordion component serializes to canonical object and deserializes" {
    const accordion = Accordion{ .id = 101, .title = "Is it accessible?", .detail = "Yes. It follows the pattern.", .open = true };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = accordion.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Accordion.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(accordion.id, decoded.id);
    try std.testing.expectEqualStrings(accordion.title, decoded.title);
    try std.testing.expectEqualStrings(accordion.detail, decoded.detail);
    try std.testing.expect(decoded.open);
}

test "accordion component renders open content and trigger hit" {
    const accordion = Accordion{ .id = 101, .title = "Is it accessible?", .detail = "Yes. It follows the pattern.", .open = true };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try accordion.render(&scene, ui.Rect.init(0, 0, 260, 68), .{});
    try accordion.collectInteractions(&collector, ui.Rect.init(0, 0, 260, 68));

    try std.testing.expect(component_test.hasText(scene.written(), "Is it accessible?"));
    try std.testing.expect(component_test.hasText(scene.written(), "Yes. It follows the pattern."));
    try std.testing.expectEqual(@as(u32, 101), collector.written()[0].id);
}

test "accordion component hides content when closed" {
    const accordion = Accordion{ .id = 101, .title = "Is it accessible?", .detail = "Hidden answer.", .open = false };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try accordion.render(&scene, ui.Rect.init(0, 0, 260, 68), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Is it accessible?"));
    try std.testing.expect(!component_test.hasText(scene.written(), "Hidden answer."));
}
