const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const icon = @import("../../icon.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;
const renderControlFrame = primitives.renderControlFrame;
const renderControlText = primitives.renderControlText;

pub const Sheet = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Sheet) ui.Node {
        return ui.sheetNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Sheet, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const trigger = triggerBounds(bounds);
        try renderControlFrame(scene, trigger, options.style.accent, options.style.border, primitives.control_radius);
        try renderControlText(scene, trigger, sheet_trigger_padding, primitives.control_label_height, overlay_open_label, options.style.bg, .center);

        const content = contentBounds(bounds);
        try scene.pushRect(content, options.style.panel, .fill, sheet_radius, 0.0);
        try scene.pushRect(content, options.style.border, .border, sheet_radius, 0.0);
        try scene.pushText(ui.Rect.init(content.x + sheet_padding, content.y + sheet_title_y, @max(primitives.min_extent, content.w - sheet_padding * 2.0 - sheet_close_space), overlay_title_h), self.title, options.style.text);
        try scene.pushText(ui.Rect.init(content.x + sheet_padding, content.y + sheet_detail_y, @max(primitives.min_extent, content.w - sheet_padding * 2.0), overlay_detail_h), self.detail, options.style.muted);
        try scene.pushIconQuad(.{ .bounds = closeBounds(bounds), .icon_id = icon.id(.x), .color = options.style.muted });
    }

    pub fn collectInteractions(self: Sheet, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelHits(collector, triggerBounds(bounds), contentBounds(bounds), self.id);
        try collector.addHit(closeBounds(bounds), .button, self.id + 2);
    }

    pub fn measure(self: Sheet, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_sheet, constraints);
    }

    pub fn toObject(self: Sheet, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.sheet, self.id, self.title, self.detail, ui_out, object_out, epoch);
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

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + sheet_trigger_y, sheet_trigger_w, sheet_trigger_h);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + bounds.w - @min(sheet_content_w, @max(primitives.min_extent, bounds.w - sheet_content_min_left));
    return ui.Rect.init(x, bounds.y, @max(primitives.min_extent, bounds.x + bounds.w - x), bounds.h);
}

fn closeBounds(bounds: ui.Rect) ui.Rect {
    const content = contentBounds(bounds);
    return ui.Rect.init(content.x + content.w - sheet_close_inset - sheet_close_size, content.y + sheet_close_inset, sheet_close_size, sheet_close_size);
}

const overlay_open_label = "Open";
const overlay_title_h: f32 = 14.0;
const overlay_detail_h: f32 = 12.0;
const sheet_trigger_y: f32 = 4.0;
const sheet_trigger_w: f32 = 62.0;
const sheet_trigger_h: f32 = 30.0;
const sheet_trigger_padding: f32 = 8.0;
const sheet_content_w: f32 = 96.0;
const sheet_content_min_left: f32 = 82.0;
const sheet_radius: f32 = 8.0;
const sheet_padding: f32 = 10.0;
const sheet_title_y: f32 = 10.0;
const sheet_detail_y: f32 = 29.0;
const sheet_close_size: f32 = 12.0;
const sheet_close_inset: f32 = 8.0;
const sheet_close_space: f32 = 18.0;
const preferred_sheet = ui.Size{ .w = 240.0, .h = 76.0 };

test "sheet component serializes to canonical object and deserializes" {
    const sheet = Sheet{ .id = 999, .title = "Edit profile", .detail = "Sheet content" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = sheet.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
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
