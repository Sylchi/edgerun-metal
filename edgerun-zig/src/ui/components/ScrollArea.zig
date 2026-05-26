const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;

pub const ScrollArea = struct {
    pub fn node(self: ScrollArea) ui.Node {
        _ = self;
        return ui.scrollAreaNode();
    }

    pub fn render(self: ScrollArea, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        try scene.pushRect(bounds, options.style.panel, .fill, scroll_area_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, scroll_area_radius, 0.0);

        const metrics = scrollAreaMetrics(bounds, options.scroll);
        const viewport = viewportBounds(bounds);
        if (try scene.pushClip(viewport)) {
            try scene.pushText(ui.Rect.init(viewport.x, viewport.y + scroll_area_content_y - metrics.offset_y, viewport.w, scroll_area_text_h), scroll_area_label, options.style.text);
            scene.popClip();
        }

        const track = trackBounds(bounds);
        try scene.pushRect(track, options.style.row, .fill, scroll_area_track_radius, 0.0);
        try scene.pushRect(thumbBounds(track, metrics), options.style.border, .fill, scroll_area_track_radius, 0.0);
    }

    pub fn measure(self: ScrollArea, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_scroll_area, constraints);
    }

    pub fn toObject(self: ScrollArea, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        _ = self;
        return component_codec.emptyObject(.scroll_area, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: ScrollArea, writer: *component_codec.Writer, index: usize) bool {
        _ = self;
        return component_codec.emptyRecord(writer, index, .scroll_area);
    }

    pub fn fromView(view: object.View) Error!ScrollArea {
        return fromNode(try component_codec.nodeView(view, .scroll_area));
    }

    pub fn fromNode(scroll_area: @FieldType(ui.Node, "scroll_area")) Error!ScrollArea {
        _ = scroll_area;
        return .{};
    }
};

const ScrollAreaMetrics = struct {
    viewport_h: f32,
    content_h: f32,
    offset_y: f32,

    fn maxOffset(self: ScrollAreaMetrics) f32 {
        return @max(0.0, self.content_h - self.viewport_h);
    }
};

fn scrollAreaMetrics(bounds: ui.Rect, state: ?common.ScrollState) ScrollAreaMetrics {
    const fallback_viewport_h = @max(primitives.min_extent, bounds.h - scroll_area_track_inset_y * 2.0);
    if (state) |value| {
        const viewport_h = @max(primitives.min_extent, value.viewport_h);
        const content_h = @max(viewport_h, value.content_h);
        return .{
            .viewport_h = viewport_h,
            .content_h = content_h,
            .offset_y = std.math.clamp(value.offset_y, 0.0, @max(0.0, content_h - viewport_h)),
        };
    }
    const content_h = fallback_viewport_h / scroll_area_thumb_ratio;
    return .{
        .viewport_h = fallback_viewport_h,
        .content_h = content_h,
        .offset_y = 0.0,
    };
}

fn viewportBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + scroll_area_padding, bounds.y + scroll_area_track_inset_y, @max(primitives.min_extent, bounds.w - scroll_area_scrollbar_w - scroll_area_padding * 2.0), @max(primitives.min_extent, bounds.h - scroll_area_track_inset_y * 2.0));
}

fn trackBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + bounds.w - scroll_area_track_inset_x, bounds.y + scroll_area_track_inset_y, scroll_area_track_w, @max(primitives.min_extent, bounds.h - scroll_area_track_inset_y * 2.0));
}

fn thumbBounds(track: ui.Rect, metrics: ScrollAreaMetrics) ui.Rect {
    const ratio = std.math.clamp(metrics.viewport_h / @max(metrics.viewport_h, metrics.content_h), 0.0, 1.0);
    const thumb_h = @min(track.h, @max(scroll_area_thumb_min_h, track.h * ratio));
    const travel = @max(0.0, track.h - thumb_h);
    const offset_ratio = if (metrics.maxOffset() == 0.0) 0.0 else metrics.offset_y / metrics.maxOffset();
    return ui.Rect.init(track.x, track.y + travel * offset_ratio, track.w, thumb_h);
}

const preferred_scroll_area = ui.Size{ .w = 220.0, .h = 48.0 };
const scroll_area_radius: f32 = 7.0;
const scroll_area_padding: f32 = 8.0;
const scroll_area_content_y: f32 = 6.0;
const scroll_area_text_h: f32 = 14.0;
const scroll_area_scrollbar_w: f32 = 10.0;
const scroll_area_track_inset_x: f32 = 6.0;
const scroll_area_track_inset_y: f32 = 5.0;
const scroll_area_track_w: f32 = 3.0;
const scroll_area_track_radius: f32 = 2.0;
const scroll_area_thumb_min_h: f32 = 12.0;
const scroll_area_thumb_ratio: f32 = 0.45;
const scroll_area_label = "Scrollable content";

test "scroll area component serializes to canonical object and deserializes" {
    const scroll_area = ScrollArea{};
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = scroll_area.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    _ = try ScrollArea.fromView(try object.View.decode(canonical));
}

test "scroll area component renders viewport and scrollbar" {
    const scroll_area = ScrollArea{};
    var commands: [16]ui.Command = undefined;
    var clips: [2]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);

    try scroll_area.render(&scene, ui.Rect.init(0, 0, 220, 48), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Scrollable content"));
    try std.testing.expect(scene.written().len >= 4);
}

test "scroll area component computes thumb from content offset" {
    const bounds = ui.Rect.init(0, 0, 220, 100);
    const track = trackBounds(bounds);
    const metrics = scrollAreaMetrics(bounds, .{
        .viewport_h = 80.0,
        .content_h = 240.0,
        .offset_y = 80.0,
    });
    const thumb = thumbBounds(track, metrics);

    try std.testing.expectEqual(@as(f32, 80.0), metrics.offset_y);
    try std.testing.expectEqual(@as(f32, 160.0), metrics.maxOffset());
    try std.testing.expect(thumb.h >= 12.0);
    try std.testing.expect(thumb.y > track.y);
    try std.testing.expect(thumb.y + thumb.h < track.y + track.h);
}

test "scroll area component clamps overscroll and clips content" {
    const scroll_area = ScrollArea{};
    var commands: [16]ui.Command = undefined;
    var clips: [2]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);

    const bounds = ui.Rect.init(0, 0, 220, 64);
    try scroll_area.render(&scene, bounds, .{
        .scroll = .{
            .viewport_h = 40.0,
            .content_h = 120.0,
            .offset_y = 999.0,
        },
    });

    const metrics = scrollAreaMetrics(bounds, .{
        .viewport_h = 40.0,
        .content_h = 120.0,
        .offset_y = 999.0,
    });
    try std.testing.expectEqual(@as(f32, 80.0), metrics.offset_y);
    const thumb = thumbBounds(trackBounds(bounds), metrics);
    const track = trackBounds(bounds);
    try std.testing.expectEqual(track.y + track.h, thumb.y + thumb.h);
}
