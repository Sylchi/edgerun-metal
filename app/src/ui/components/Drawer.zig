const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const text_component = @import("Text.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Drawer = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    title: []const u8,
    detail: []const u8,

    const serialization = component_codec.TwoStringComponent(Drawer, "drawer", "title", "detail");

    pub fn node(self: Drawer) ui.Node {
        return ui.drawerNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Drawer, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderControlTrigger(scene, triggerBounds(bounds), options.style.accent, options.style.border, drawer_trigger_padding, overlay_open_label, options.style.bg);
        if (options.overlay.isOpen(self.id)) {
            const content = contentBounds(bounds);
            try primitives.renderTitleDetailPanel(scene, content, self.title, self.detail, options, drawer_panel, options.style.border, options.style.text);
            try scene.pushRect(handleBounds(content), options.style.muted, .fill, drawer_handle_radius, 0.0);
        }
    }

    pub fn collectInteractions(self: Drawer, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelHits(collector, triggerBounds(bounds), contentBounds(bounds), self.id);
    }

    pub fn measure(self: Drawer, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const trigger = text_component.Text.measureValue(overlay_open_label, .{ .width = .unconstrained, .text_wrap = .nowrap }, primitives.textMetrics(overlay_open_label, primitives.control_label_height, 1));
        const panel = primitives.measureTitleDetailPanel(self.title, self.detail, constraints.inner(.{ .left = drawer_content_inset_x, .right = drawer_content_inset_x, .top = drawer_content_y }), drawer_panel);
        const preferred = primitives.constrainPreferredSize(.{
            .w = @max(trigger.preferred.w + drawer_trigger_padding * 2.0, panel.preferred.w + drawer_content_inset_x * 2.0),
            .h = drawer_content_y + panel.preferred.h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = primitives.min_extent + drawer_content_inset_x * 2.0, .h = drawer_content_y + panel.min.h },
            preferred,
            .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = @max(preferred.h, drawer_content_y + panel.max.h) },
        ).applyExact(constraints);
    }
    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(drawer: @FieldType(ui.Node, "drawer")) Error!Drawer {
        return .{ .id = drawer.id, .title = drawer.title, .detail = drawer.detail };
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
const drawer_panel = primitives.TitleDetailPanel{ .radius = drawer_radius, .padding = drawer_padding, .title_y = 14.0, .title_h = 14.0, .detail_y = 31.0, .detail_h = 12.0 };

test "drawer component renders trigger content and hit regions" {
    const drawer = Drawer{ .id = 998, .title = "Edit profile", .detail = "Drawer content" };
    var h = component_test.InteractiveHarness(24, 2){};
    h.init();

    try h.render(drawer, ui.Rect.init(0, 0, 240, 76), .{ .overlay = .{ .open_ids = &.{drawer.id} } });
    try drawer.collectInteractions(&h.collector, ui.Rect.init(0, 0, 240, 76));

    try h.expectText("Edit profile");
    try h.expectText("Drawer content");
    try h.expectHitCount(2);
    try h.expectHitId(1, 999);
}

test "drawer measurement follows title and detail text" {
    const short = Drawer{ .id = 998, .title = "Edit", .detail = "Body" };
    const long = Drawer{ .id = 998, .title = "Edit runtime authority", .detail = "Drawer content with receipt controls" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
