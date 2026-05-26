const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const icon = @import("../../icon.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

pub const Empty = struct {
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Empty) ui.Node {
        return ui.emptyNode(self.title, self.detail);
    }

    pub fn render(self: Empty, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, ui.Color.clear, .fill, empty_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, empty_radius, 0.0);
        const media = ui.Rect.init(bounds.x + (bounds.w - empty_media_size) * 0.5, bounds.y + empty_padding, empty_media_size, empty_media_size);
        try scene.pushRect(media, options.style.row, .fill, media.w * 0.5, 0.0);
        try scene.pushIconQuad(.{ .bounds = media.insetUniform(empty_media_icon_inset), .icon_id = icon.id(.sparkles), .color = options.style.text });
        try scene.pushAlignedText(ui.Rect.init(bounds.x + empty_padding, media.y + media.h + empty_gap, @max(component_primitives.min_extent, bounds.w - empty_padding * 2.0), empty_title_height), self.title, options.style.text, .center);
        try scene.pushWrappedText(ui.Rect.init(bounds.x + empty_padding, media.y + media.h + empty_gap + empty_title_height + empty_detail_gap, @max(component_primitives.min_extent, bounds.w - empty_padding * 2.0), empty_detail_height * empty_detail_max_lines), self.detail, options.style.muted, .{
            .line_height = empty_detail_height,
            .average_char_width = empty_detail_average_w,
            .max_lines = empty_detail_max_lines,
        });
    }

    pub fn measure(self: Empty, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_empty, constraints);
    }

    pub fn toObject(self: Empty, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.empty, 0, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Empty, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .empty, 0, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Empty {
        return switch (try component_codec.singleNode(view)) {
            .empty => |empty| .{ .title = empty.title, .detail = empty.detail },
            else => error.UnsupportedComponent,
        };
    }
};

const empty_radius: f32 = 8.0;
const empty_padding: f32 = 24.0;
const empty_media_size: f32 = 40.0;
const empty_media_icon_inset: f32 = 8.0;
const empty_gap: f32 = 10.0;
const empty_title_height: f32 = 20.0;
const empty_detail_gap: f32 = 4.0;
const empty_detail_height: f32 = 16.0;
const empty_detail_average_w: f32 = 7.5;
const empty_detail_max_lines: usize = 2;
pub const preferred_empty = ui.Size{ .w = 260.0, .h = 132.0 };

test "empty component serializes to canonical object and deserializes" {
    const empty = Empty{ .title = "No results", .detail = "Try another filter." };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = empty.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Empty.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(empty.title, decoded.title);
    try std.testing.expectEqualStrings(empty.detail, decoded.detail);
}

test "empty component renders media title and description" {
    const empty = Empty{ .title = "No results", .detail = "Try another filter." };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try empty.render(&scene, ui.Rect.init(0, 0, 260, 132), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "No results"));
    try std.testing.expect(component_test.hasText(scene.written(), "Try another filter."));
}
