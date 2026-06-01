const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const RadioGroup = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    first: []const u8,
    second: []const u8,
    selected: u16 = 0,

    pub fn node(self: RadioGroup) ui.Node {
        return ui.radioGroupNode(self.id, self.first, self.second, list_layout.clampedIndex(self.selected, radio_item_count));
    }

    pub fn render(self: RadioGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const selected = list_layout.clampedIndex(self.selected, radio_item_count);
        try renderOption(scene, optionBounds(bounds, 0), self.first, selected == 0, options);
        try renderOption(scene, optionBounds(bounds, 1), self.second, selected == 1, options);
    }

    pub fn collectInteractions(self: RadioGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(optionBounds(bounds, 0), .button, self.id);
        try collector.addHit(optionBounds(bounds, 1), .button, common.offsetId(self.id, 1));
    }

    pub fn measure(self: RadioGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const first = labelMeasure(self.first);
        const second = labelMeasure(self.second);
        const option_h = optionHeight();
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = radio_box_size + radio_text_gap + @max(first.preferred.w, second.preferred.w),
            .h = option_h * @as(f32, @floatFromInt(radio_item_count)) + radio_option_gap * @as(f32, @floatFromInt(radio_item_count - 1)),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = radio_box_size + radio_text_gap + component_primitives.min_extent, .h = option_h },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: RadioGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: RadioGroup, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .radio_group, list_layout.encodedIndexedId(self.id, self.selected, radio_item_count), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!RadioGroup {
        return component_codec.decodeFromView(RadioGroup, .radio_group, view);
    }

    pub fn fromNode(radio: @FieldType(ui.Node, "radio_group")) Error!RadioGroup {
        return .{ .id = radio.id, .first = radio.first, .second = radio.second, .selected = list_layout.clampedIndex(radio.selected, radio_item_count) };
    }
};

const radio_item_count: u16 = 2;

fn renderOption(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    const outer = ui.Rect.init(bounds.x, bounds.y + (bounds.h - radio_box_size) * 0.5, radio_box_size, radio_box_size);
    try scene.pushRect(outer, options.style.panel, .fill, radio_box_size * 0.5, 0.0);
    try scene.pushRect(outer, options.style.border, .border, radio_box_size * 0.5, 0.0);
    if (selected) {
        const dot = ui.Rect.init(outer.x + (outer.w - radio_dot_size) * 0.5, outer.y + (outer.h - radio_dot_size) * 0.5, radio_dot_size, radio_dot_size);
        try scene.pushRect(dot, options.style.accent, .fill, radio_dot_size * 0.5, 0.0);
    }
    const label_x = outer.x + outer.w + radio_text_gap;
    try text_component.Text.renderPlain(scene, ui.Rect.init(label_x, bounds.y, @max(component_primitives.min_extent, bounds.x + bounds.w - label_x), bounds.h).withHeightCentered(component_primitives.control_label_height), label, options.style.text);
}

fn optionBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const option_h = optionHeight();
    const y = bounds.y + @as(f32, @floatFromInt(index)) * (option_h + radio_option_gap);
    return ui.Rect.init(bounds.x, y, bounds.w, option_h);
}

fn optionHeight() f32 {
    return @max(radio_box_size, component_primitives.control_label_height);
}

fn labelMeasure(value: []const u8) layout.Measurement {
    return text_component.Text.measureValue(value, .{ .width = .unconstrained, .text_wrap = .nowrap }, component_primitives.textMetrics(value, component_primitives.control_label_height, radio_label_max_lines));
}

const radio_box_size: f32 = 18.0;
const radio_text_gap: f32 = 10.0;
const radio_dot_size: f32 = 8.0;
const radio_option_gap: f32 = 6.0;
const radio_label_max_lines: usize = 1;

test "radio group component renders selected indicator and option hits" {
    const radio = RadioGroup{ .id = 70, .first = "Default", .second = "Comfortable", .selected = 1 };
    var h = component_test.InteractiveHarness(16, 2){};
    h.init();

    try h.render(radio, ui.Rect.init(0, 0, 220, 52), .{});
    try radio.collectInteractions(&h.collector, ui.Rect.init(0, 0, 220, 52));

    try h.expectFillColor(ui.Color.accent);
    try h.expectHitCount(2);
    try h.expectHitId(1, 71);
}

test "radio group measurement follows option labels" {
    const short = RadioGroup{ .id = 70, .first = "A", .second = "B", .selected = 0 };
    const long = RadioGroup{ .id = 70, .first = "Default", .second = "Comfortable runtime mode", .selected = 1 };

    try component_test.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
