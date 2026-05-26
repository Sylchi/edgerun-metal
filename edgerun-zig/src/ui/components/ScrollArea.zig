const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const ScrollArea = struct {
    pub fn node(self: ScrollArea) ui.Node {
        _ = self;
        return ui.scrollAreaNode();
    }

    pub fn render(self: ScrollArea, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        return component_render.renderScrollArea(scene, bounds, options);
    }

    pub fn measure(self: ScrollArea, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_scroll_area, constraints);
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
        return switch (try component_codec.singleNode(view)) {
            .scroll_area => .{},
            else => error.UnsupportedComponent,
        };
    }
};

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
    const track = component_render.scrollAreaTrackBounds(bounds);
    const metrics = component_render.scrollAreaMetrics(bounds, .{
        .viewport_h = 80.0,
        .content_h = 240.0,
        .offset_y = 80.0,
    });
    const thumb = component_render.scrollAreaThumbBounds(track, metrics);

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

    const metrics = component_render.scrollAreaMetrics(bounds, .{
        .viewport_h = 40.0,
        .content_h = 120.0,
        .offset_y = 999.0,
    });
    try std.testing.expectEqual(@as(f32, 80.0), metrics.offset_y);
    const thumb = component_render.scrollAreaThumbBounds(component_render.scrollAreaTrackBounds(bounds), metrics);
    const track = component_render.scrollAreaTrackBounds(bounds);
    try std.testing.expectEqual(track.y + track.h, thumb.y + thumb.h);
}
