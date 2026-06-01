const std = @import("er_std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const Icon = icon_component.Icon;

pub const Accordion = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
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
        _ = options;
        const title = text_component.Text.measureValue(self.title, .{ .width = .unconstrained, .text_wrap = .nowrap }, primitives.textMetrics(self.title, primitives.control_label_height, accordion_title_max_lines));
        const detail = text_component.Text.measureValue(self.detail, constraints, .{
            .line_height = accordion_detail_height,
            .average_char_width = accordion_detail_average_w,
            .max_lines = accordion_detail_max_lines,
        });
        const closed_h = accordion_trigger_h + separator_height;
        const open_h = closed_h + accordion_content_padding_top + detail.preferred.h;
        const preferred = primitives.constrainPreferredSize(.{
            .w = title.preferred.w + accordion_icon_space,
            .h = if (self.open) open_h else closed_h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = primitives.min_extent + accordion_icon_space, .h = closed_h },
            preferred,
            .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = @max(preferred.h, open_h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Accordion, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Accordion, writer: *component_codec.Writer, index: usize) bool {
        const title_ref = writer.string(self.title) orelse return false;
        const detail_ref = writer.string(self.detail) orelse return false;
        return writer.record(index, .accordion, encodedId(self.id, self.open), title_ref, detail_ref);
    }

    pub fn fromView(view: object.View) Error!Accordion {
        return component_codec.decodeFromView(Accordion, .accordion, view);
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
const accordion_trigger_h: f32 = 36.0;
const accordion_trigger_text_y: f32 = 10.0;
const accordion_icon_space: f32 = 22.0;
const accordion_icon_size: f32 = 14.0;
const accordion_icon_y: f32 = 11.0;
const accordion_content_padding_top: f32 = 8.0;
const accordion_detail_height: f32 = 16.0;
const accordion_detail_average_w: f32 = 7.5;
const accordion_detail_max_lines: usize = 2;
const accordion_title_max_lines: usize = 1;
const separator_height: f32 = 1.0;

test "accordion component renders open content and trigger hit" {
    const accordion = Accordion{ .id = 101, .title = "Is it accessible?", .detail = "Yes. It follows the pattern.", .open = true };
    var h = component_test.InteractiveHarness(16, 1){};
    h.init();

    try h.render(accordion, ui.Rect.init(0, 0, 260, 68), .{});
    try accordion.collectInteractions(&h.collector, ui.Rect.init(0, 0, 260, 68));

    try h.expectText("Is it accessible?");
    try h.expectText("Yes. It follows the pattern.");
    try h.expectHitId(0, 101);
}

test "accordion component hides content when closed" {
    const accordion = Accordion{ .id = 101, .title = "Is it accessible?", .detail = "Hidden answer.", .open = false };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try accordion.render(&scene, ui.Rect.init(0, 0, 260, 68), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Is it accessible?"));
    try std.testing.expect(!component_test.hasText(scene.written(), "Hidden answer."));
}

test "accordion measurement follows title and open detail text" {
    const short = Accordion{ .id = 101, .title = "A", .detail = "B", .open = true };
    const long = Accordion{ .id = 101, .title = "Runtime authority section", .detail = "Receipt details wrap here", .open = true };
    const closed = long;

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
    try std.testing.expect((Accordion{ .id = closed.id, .title = closed.title, .detail = closed.detail, .open = false }).measure(.{}, .{}).preferred.h < long.measure(.{}, .{}).preferred.h);
}
