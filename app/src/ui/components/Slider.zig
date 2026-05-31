const std = @import("std");
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

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Slider = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    label: []const u8,
    value: f32,

    pub fn node(self: Slider) ui.Node {
        return ui.sliderNode(self.id, self.label, self.value);
    }

    pub fn accessibility(self: Slider) common.Accessibility {
        return .{ .role = .slider, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: Slider, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const value = options.drag_value orelse self.value;
        const clamped = ui.clampUnit(value);
        const label_h = if (self.label.len == 0) 0.0 else @min(bounds.h, component_primitives.measuredTextHeight(self.label, bounds.w, slider_label_height, slider_label_max_lines));
        if (self.label.len != 0) {
            try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, label_h), self.label, options.style.text, component_primitives.textWrap(self.label, slider_label_height, slider_label_max_lines));
        }
        const track_y = if (self.label.len == 0)
            bounds.y + (bounds.h - slider_track_height) * 0.5
        else
            bounds.y + @min(label_h + slider_label_track_gap, @max(0.0, bounds.h - slider_track_height));
        const track = ui.Rect.init(bounds.x, track_y, bounds.w, slider_track_height);
        try renderTrack(scene, track, clamped, options);
        const thumb_center = std.math.clamp(track.x + track.w * clamped, track.x + slider_thumb_size * 0.5, track.x + track.w - slider_thumb_size * 0.5);
        const thumb = ui.Rect.init(thumb_center - slider_thumb_size * 0.5, track.y + (track.h - slider_thumb_size) * 0.5, slider_thumb_size, slider_thumb_size);
        try scene.pushRect(thumb.insetUniform(-slider_thumb_shadow_inset), slider_thumb_shadow, .shadow, slider_thumb_size * 0.5, slider_thumb_shadow_size);
        try scene.pushRect(thumb, options.style.panel, .fill, slider_thumb_size * 0.5, 0.0);
        try scene.pushRect(thumb.insetUniform(3.0), options.style.accent, .fill, (slider_thumb_size - 6.0) * 0.5, 0.0);
        try component_primitives.renderControlStateOverlay(scene, bounds, options, slider_track_height * 0.5);
    }

    pub fn collectInteractions(self: Slider, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .slider, self.id);
    }

    pub fn measure(self: Slider, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const label = text_component.Text.measureValue(self.label, constraints, component_primitives.textMetrics(self.label, slider_label_height, slider_label_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(slider_min_width, label.preferred.w),
            .h = label.preferred.h + slider_label_track_gap + @max(slider_track_height, slider_thumb_size),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(slider_min_width, preferred.w), .h = @min(slider_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Slider, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.slider, self.id, self.label, component_codec.unitRef(self.value), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Slider, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .slider, self.id, self.label, component_codec.unitRef(self.value));
    }

    pub fn fromView(view: object.View) Error!Slider {
        return component_codec.decodeFromView(Slider, .slider, view);
    }

    pub fn fromNode(slider: @FieldType(ui.Node, "slider")) Error!Slider {
        return .{ .id = slider.id, .label = slider.label, .value = slider.value };
    }
};

fn renderTrack(scene: *ui.Scene, track: ui.Rect, value: f32, options: RenderOptions) ui.RenderError!void {
    if (track.w <= 0.0 or track.h <= 0.0) return;
    try scene.pushRect(track.insetUniform(-slider_track_shadow_inset), slider_track_shadow, .shadow, slider_track_height * 0.5, slider_track_shadow_size);
    try scene.pushGradientRect(track, options.style.row, slider_track_floor, slider_track_height * 0.5);
    try scene.pushRect(track, options.style.border, .border, slider_track_height * 0.5, 0.0);
    const clamped = ui.clampUnit(value);
    if (clamped <= 0.0) return;
    const fill_width = @min(track.w, @max(0.0, track.w * clamped));
    const fill = ui.Rect.init(track.x, track.y, fill_width, track.h);
    try scene.pushRect(fill, options.style.accent, .fill, slider_track_height * 0.5, 0.0);
}

const slider_label_height: f32 = 14.0;
const slider_label_max_lines: usize = 2;
const slider_label_track_gap: f32 = 12.0;
const slider_track_height: f32 = 8.0;
pub const slider_thumb_size: f32 = 18.0;
const slider_thumb_shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 64 };
const slider_thumb_shadow_inset: f32 = 1.0;
const slider_thumb_shadow_size: f32 = 4.0;
const slider_track_shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 46 };
const slider_track_floor = ui.Color{ .r = 5, .g = 7, .b = 10, .a = 34 };
const slider_track_shadow_inset: f32 = 1.0;
const slider_track_shadow_size: f32 = 2.0;
const slider_min_width: f32 = 120.0;
const slider_min_height: f32 = 32.0;

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

test "slider with empty label centers track and keeps thumb inside bounds" {
    const slider = Slider{ .id = 13, .label = "", .value = 0.0 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(10, 20, 120, 34);

    try slider.render(&scene, bounds, .{});

    const thumb = component_test.lastFillRect(scene.written()).?;
    try std.testing.expect(thumb.x >= bounds.x);
    try std.testing.expect(thumb.x + thumb.w <= bounds.x + bounds.w);
    for (scene.written()) |command| switch (command) {
        .text => return error.UnexpectedText,
        else => {},
    };
}

test "slider measurement wraps long labels under narrow constraints" {
    const slider = Slider{ .id = 13, .label = "Runtime memory pressure limit", .value = 0.72 };
    const compact = Slider{ .id = 13, .label = "Brightness", .value = 0.72 };

    const measured = slider.measure(.{ .width = .{ .at_most = slider_min_width }, .text_wrap = .wrap }, .{});
    const compact_measured = compact.measure(.{ .width = .{ .at_most = slider_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= slider_min_width);
    try std.testing.expect(measured.preferred.h > compact_measured.preferred.h);
}
