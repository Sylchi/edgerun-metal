const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const text_component = @import("Text.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const measureFixed = primitives.measureFixed;
const Icon = icon_component.Icon;

pub const Accordion = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    open: bool = false,

    pub fn node(self: Accordion) ui.Node {
        return ui.accordionNode(self.id, self.title, self.detail, self.open);
    }

    pub fn render(self: Accordion, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const trigger = triggerBounds(bounds);
        try text_component.Text.renderPlain(scene, ui.Rect.init(trigger.x, trigger.y + accordion_trigger_text_y, @max(primitives.min_extent, trigger.w - accordion_icon_space), primitives.control_label_height), self.title, options.style.text);
        try Icon.named(.chevron_right).renderColor(scene, ui.Rect.init(trigger.x + trigger.w - accordion_icon_size, trigger.y + accordion_icon_y, accordion_icon_size, accordion_icon_size), options.style.muted);
        try scene.pushRect(ui.Rect.init(bounds.x, trigger.y + trigger.h, bounds.w, separator_height), options.style.border, .fill, 0.0, 0.0);
        if (self.open) {
            try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x, trigger.y + trigger.h + accordion_content_padding_top, bounds.w, @max(primitives.min_extent, bounds.h - trigger.h - accordion_content_padding_top)), self.detail, options.style.muted, .{
                .line_height = accordion_detail_height,
                .average_char_width = accordion_detail_average_w,
                .max_lines = accordion_detail_max_lines,
            });
        }
    }

    pub fn collectInteractions(self: Accordion, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, triggerBounds(bounds), .button, self.id);
    }

    pub fn measure(self: Accordion, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_accordion, constraints);
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
        const accordion = try component_codec.nodeView(view, .accordion);
        return fromNode(accordion);
    }

    pub fn fromNode(accordion: @FieldType(ui.Node, "accordion")) Error!Accordion {
        return .{ .id = accordion.id, .title = accordion.title, .detail = accordion.detail, .open = accordion.open };
    }
};

fn encodedId(id: u32, open: bool) u32 {
    const open_value: u32 = if (open) 1 else 0;
    return id * accordion_id_stride + open_value;
}

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, accordion_trigger_h);
}

const accordion_id_stride: u32 = 2;
const preferred_accordion = ui.Size{ .w = 260.0, .h = 68.0 };
const accordion_trigger_h: f32 = 36.0;
const accordion_trigger_text_y: f32 = 10.0;
const accordion_icon_space: f32 = 22.0;
const accordion_icon_size: f32 = 14.0;
const accordion_icon_y: f32 = 11.0;
const accordion_content_padding_top: f32 = 8.0;
const accordion_detail_height: f32 = 16.0;
const accordion_detail_average_w: f32 = 7.5;
const accordion_detail_max_lines: usize = 2;
const separator_height: f32 = 1.0;

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
