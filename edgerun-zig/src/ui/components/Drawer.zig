const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
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

pub const Drawer = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Drawer) ui.Node {
        return ui.drawerNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Drawer, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const trigger = triggerBounds(bounds);
        try renderControlFrame(scene, trigger, options.style.accent, options.style.border, primitives.control_radius);
        try renderControlText(scene, trigger, drawer_trigger_padding, primitives.control_label_height, overlay_open_label, options.style.bg, .center);

        const content = contentBounds(bounds);
        try scene.pushRect(content, options.style.panel, .fill, drawer_radius, 0.0);
        try scene.pushRect(content, options.style.border, .border, drawer_radius, 0.0);
        try scene.pushRect(handleBounds(content), options.style.muted, .fill, drawer_handle_radius, 0.0);
        try scene.pushText(ui.Rect.init(content.x + drawer_padding, content.y + drawer_title_y, @max(primitives.min_extent, content.w - drawer_padding * 2.0), overlay_title_h), self.title, options.style.text);
        try scene.pushText(ui.Rect.init(content.x + drawer_padding, content.y + drawer_detail_y, @max(primitives.min_extent, content.w - drawer_padding * 2.0), overlay_detail_h), self.detail, options.style.muted);
    }

    pub fn collectInteractions(self: Drawer, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelHits(collector, triggerBounds(bounds), contentBounds(bounds), self.id);
    }

    pub fn measure(self: Drawer, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_drawer, constraints);
    }

    pub fn toObject(self: Drawer, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.drawer, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Drawer, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .drawer, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Drawer {
        return switch (try component_codec.singleNode(view)) {
            .drawer => |drawer| .{ .id = drawer.id, .title = drawer.title, .detail = drawer.detail },
            else => error.UnsupportedComponent,
        };
    }
};

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + drawer_trigger_y, drawer_trigger_w, drawer_trigger_h);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const y = bounds.y + drawer_content_y;
    return ui.Rect.init(bounds.x + drawer_content_inset_x, y, @max(primitives.min_extent, bounds.w - drawer_content_inset_x * 2.0), @max(primitives.min_extent, bounds.y + bounds.h - y));
}

fn handleBounds(content: ui.Rect) ui.Rect {
    return ui.Rect.init(content.x + (content.w - drawer_handle_w) * 0.5, content.y + drawer_handle_y, drawer_handle_w, drawer_handle_h);
}

const overlay_open_label = "Open";
const overlay_title_h: f32 = 14.0;
const overlay_detail_h: f32 = 12.0;
const drawer_trigger_y: f32 = 4.0;
const drawer_trigger_w: f32 = 62.0;
const drawer_trigger_h: f32 = 30.0;
const drawer_trigger_padding: f32 = 8.0;
const drawer_content_y: f32 = 38.0;
const drawer_content_inset_x: f32 = 10.0;
const drawer_radius: f32 = 10.0;
const drawer_padding: f32 = 12.0;
const drawer_handle_w: f32 = 58.0;
const drawer_handle_h: f32 = 4.0;
const drawer_handle_y: f32 = 5.0;
const drawer_handle_radius: f32 = 2.0;
const drawer_title_y: f32 = 14.0;
const drawer_detail_y: f32 = 31.0;
const preferred_drawer = ui.Size{ .w = 240.0, .h = 76.0 };

test "drawer component serializes to canonical object and deserializes" {
    const drawer = Drawer{ .id = 998, .title = "Edit profile", .detail = "Drawer content" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = drawer.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Drawer.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(drawer.id, decoded.id);
    try std.testing.expectEqualStrings(drawer.title, decoded.title);
    try std.testing.expectEqualStrings(drawer.detail, decoded.detail);
}

test "drawer component renders trigger content and hit regions" {
    const drawer = Drawer{ .id = 998, .title = "Edit profile", .detail = "Drawer content" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try drawer.render(&scene, ui.Rect.init(0, 0, 240, 76), .{});
    try drawer.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 76));

    try std.testing.expect(component_test.hasText(scene.written(), "Edit profile"));
    try std.testing.expect(component_test.hasText(scene.written(), "Drawer content"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 999), collector.written()[1].id);
}
