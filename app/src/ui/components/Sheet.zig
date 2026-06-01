const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const text_component = @import("Text.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const layout = @import("../layouts/Types.zig");
const button_component = @import("Button.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const Icon = icon_component.Icon;
const IconButton = button_component.IconButton;

pub const Sheet = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Sheet) ui.Node {
        return ui.sheetNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Sheet, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderControlTrigger(scene, triggerBounds(bounds), options.style.accent, options.style.border, sheet_trigger_padding, overlay_open_label, options.style.bg);
        if (options.overlay.isOpen(self.id)) {
            const content = contentBounds(bounds);
            try primitives.renderTitleDetailPanel(scene, content, self.title, self.detail, options, sheet_panel, options.style.border, options.style.text);
            try closeButton(self.id).render(scene, closeBounds(bounds), options);
        }
    }

    pub fn collectInteractions(self: Sheet, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelHits(collector, triggerBounds(bounds), contentBounds(bounds), self.id);
        try closeButton(self.id).collectInteractions(collector, closeBounds(bounds));
    }

    pub fn measure(self: Sheet, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const trigger = text_component.Text.measureValue(overlay_open_label, .{ .width = .unconstrained, .text_wrap = .nowrap }, primitives.textMetrics(overlay_open_label, primitives.control_label_height, 1));
        const panel = primitives.measureTitleDetailPanel(self.title, self.detail, constraints, sheet_panel);
        const preferred = primitives.constrainPreferredSize(.{
            .w = @max(trigger.preferred.w + sheet_trigger_padding * 2.0, panel.preferred.w + sheet_content_min_left),
            .h = @max(sheet_trigger_y + @max(sheet_trigger_h, trigger.preferred.h + sheet_trigger_padding * 2.0), panel.preferred.h),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = primitives.min_extent + sheet_content_min_left, .h = panel.min.h },
            preferred,
            .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = @max(preferred.h, panel.max.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Sheet, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.sheet, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Sheet, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .sheet, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Sheet {
        return component_codec.decodeFromView(Sheet, .sheet, view);
    }

    pub fn fromNode(sheet: @FieldType(ui.Node, "sheet")) Error!Sheet {
        return .{ .id = sheet.id, .title = sheet.title, .detail = sheet.detail };
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

fn closeButton(id: u32) IconButton {
    return .{ .id = primitives.overlaySecondaryId(id), .label = "Close sheet", .icon = Icon.named(.x), .variant = .ghost };
}

const overlay_open_label = "Open";
const sheet_trigger_y: f32 = 4.0;
const sheet_trigger_w: f32 = 62.0;
const sheet_trigger_h: f32 = 30.0;
const sheet_trigger_padding: f32 = 8.0;
const sheet_content_w: f32 = 96.0;
const sheet_content_min_left: f32 = 82.0;
const sheet_radius: f32 = 8.0;
const sheet_padding: f32 = 10.0;
const sheet_close_size: f32 = 28.0;
const sheet_close_inset: f32 = 8.0;
const sheet_close_space: f32 = 34.0;
const sheet_panel = primitives.TitleDetailPanel{ .radius = sheet_radius, .padding = sheet_padding, .title_y = 10.0, .title_h = 14.0, .detail_y = 29.0, .detail_h = 12.0, .title_right_inset = sheet_close_space };

test "sheet component renders trigger content and hit regions" {
    const sheet = Sheet{ .id = 999, .title = "Edit profile", .detail = "Sheet content" };
    var h = component_test.InteractiveHarness(24, 3){};
    h.init();

    try h.render(sheet, ui.Rect.init(0, 0, 240, 76), .{ .overlay = .{ .open_ids = &.{sheet.id} } });
    try sheet.collectInteractions(&h.collector, ui.Rect.init(0, 0, 240, 76));

    try h.expectTextPrefix("Edit");
    try h.expectTextPrefix("Sheet");
    try h.expectHitCount(3);
    try h.expectHitId(2, 1001);
}

test "sheet measurement follows title and detail text" {
    const short = Sheet{ .id = 999, .title = "Edit", .detail = "Body" };
    const long = Sheet{ .id = 999, .title = "Edit runtime authority", .detail = "Sheet content with receipt controls" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
