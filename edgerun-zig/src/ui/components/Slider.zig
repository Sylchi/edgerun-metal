const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const component_contract = @import("ComponentContract.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const registration = component_contract.registration("slider", Slider);
const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Slider = struct {
    id: u32,
    label: []const u8,
    value: f32,

    pub fn node(self: Slider) ui.Node {
        return ui.sliderNode(self.id, self.label, self.value);
    }

    pub fn accessibility(self: Slider) common.Accessibility {
        return .{ .role = .slider, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: Slider, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const clamped = ui.clampUnit(self.value);
        const label_h = @min(bounds.h, component_primitives.measuredTextHeight(self.label, bounds.w, slider_label_height, slider_label_max_lines));
        try scene.pushWrappedText(ui.Rect.init(bounds.x, bounds.y, bounds.w, label_h), self.label, options.style.text, component_primitives.textWrap(self.label, slider_label_height, slider_label_max_lines));
        const track_y = bounds.y + @min(label_h + slider_label_track_gap, @max(0.0, bounds.h - slider_track_height));
        const track = ui.Rect.init(bounds.x, track_y, bounds.w, slider_track_height);
        try renderTrack(scene, track, clamped, options);
        const thumb_center = track.x + track.w * clamped;
        const thumb = ui.Rect.init(thumb_center - slider_thumb_size * 0.5, track.y + (track.h - slider_thumb_size) * 0.5, slider_thumb_size, slider_thumb_size);
        try scene.pushRect(thumb, options.style.text, .fill, slider_thumb_size * 0.5, 0.0);
    }

    pub fn collectInteractions(self: Slider, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .slider, self.id);
    }

    pub fn measure(self: Slider, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const label = layout.measureText(self.label, constraints, component_primitives.textMetrics(self.label, slider_label_height, slider_label_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(slider_min_width, label.preferred.w),
            .h = label.preferred.h + slider_label_track_gap + @max(slider_track_height, slider_thumb_size),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(slider_min_width, preferred.w), .h = @min(slider_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.measure_max_width, .h = @max(preferred.h, preferred_slider.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Slider, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.slider, self.id, self.label, component_codec.unitRef(self.value), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Slider, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .slider, self.id, self.label, component_codec.unitRef(self.value));
    }

    pub fn fromView(view: object.View) Error!Slider {
        const slider = try component_codec.nodeView(view, .slider);
        return fromNode(slider);
    }

    pub fn fromNode(slider: @FieldType(ui.Node, "slider")) Error!Slider {
        return .{ .id = slider.id, .label = slider.label, .value = slider.value };
    }
};

fn renderTrack(scene: *ui.Scene, track: ui.Rect, value: f32, options: RenderOptions) ui.RenderError!void {
    if (track.w <= 0.0 or track.h <= 0.0) return;
    try scene.pushRect(track, options.style.row, .fill, slider_track_height * 0.5, 0.0);
    const clamped = ui.clampUnit(value);
    if (clamped <= 0.0) return;
    const fill_width = @min(track.w, @max(0.0, track.w * clamped));
    try scene.pushRect(ui.Rect.init(track.x, track.y, fill_width, track.h), options.style.accent, .fill, slider_track_height * 0.5, 0.0);
}

const slider_label_height: f32 = 14.0;
const slider_label_max_lines: usize = 2;
const slider_label_track_gap: f32 = 12.0;
const slider_track_height: f32 = 6.0;
pub const slider_thumb_size: f32 = 16.0;
const slider_min_width: f32 = 120.0;
const slider_min_height: f32 = 32.0;
pub const preferred_slider = ui.Size{ .w = 220.0, .h = 42.0 };

test "slider component serializes to canonical object and deserializes" {
    const slider = Slider{ .id = 13, .label = "Brightness", .value = 0.72 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = slider.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Slider.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(slider.id, decoded.id);
    try std.testing.expectEqualStrings(slider.label, decoded.label);
    try std.testing.expect(@abs(decoded.value - slider.value) < 0.001);
}

test "slider component clamps rendered fill and thumb to track" {
    const slider = Slider{ .id = 13, .label = "Brightness", .value = 2.0 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(0, 0, 120, 42);

    try slider.render(&scene, bounds, .{});

    const fill = component_test.fillRectColor(scene.written(), ui.Color.accent).?;
    try std.testing.expectEqual(@as(f32, 120.0), fill.w);
    const thumb = component_test.lastFillRect(scene.written()).?;
    try std.testing.expect(thumb.x + thumb.w <= bounds.x + bounds.w + slider_thumb_size * 0.5);
}

test "slider measurement wraps long labels under narrow constraints" {
    const slider = Slider{ .id = 13, .label = "Runtime memory pressure limit", .value = 0.72 };

    const measured = slider.measure(.{ .width = .{ .at_most = slider_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= slider_min_width);
    try std.testing.expect(measured.preferred.h > preferred_slider.h);
}
