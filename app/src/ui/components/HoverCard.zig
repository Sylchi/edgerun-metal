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

pub const HoverCard = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    trigger: []const u8,
    content: []const u8,

    const serialization = component_codec.TwoStringComponent(HoverCard, "hover_card", "trigger", "content");

    pub fn node(self: HoverCard) ui.Node {
        return ui.hoverCardNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: HoverCard, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTitleDetail(scene, bounds, self.id, options, hover_card_layout, options.style.panel, options.style.border, primitives.control_text_padding, self.trigger, options.style.text, hover_card_panel, self.content, hover_card_detail_label, options.style.text);
    }

    pub fn collectInteractions(self: HoverCard, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelLayoutHits(collector, bounds, hover_card_layout, self.id);
    }

    pub fn measure(self: HoverCard, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return primitives.measureSidePanelTitleDetail(self.trigger, self.content, hover_card_detail_label, constraints, hover_card_layout, primitives.control_text_padding, hover_card_panel);
    }
    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(hover_card: @FieldType(ui.Node, "hover_card")) Error!HoverCard {
        return .{ .id = hover_card.id, .trigger = hover_card.trigger, .content = hover_card.content };
    }
};

const hover_card_layout = primitives.SidePanelLayout{ .trigger_y = 6.0, .trigger_w = 66.0, .trigger_h = 30.0, .gap = 10.0 };
const hover_card_radius: f32 = 8.0;
const hover_card_padding: f32 = 10.0;
const hover_card_panel = primitives.TitleDetailPanel{ .radius = hover_card_radius, .padding = hover_card_padding, .title_y = 8.0, .title_h = 14.0, .detail_y = 25.0, .detail_h = 12.0 };
const hover_card_detail_label = "Hover content";

test "hover card component renders trigger content and hit regions" {
    const hover_card = HoverCard{ .id = 997, .trigger = "Hover", .content = "@shadcn" };
    var h = component_test.InteractiveHarness(20, 2){};
    h.init();

    try h.render(hover_card, ui.Rect.init(0, 0, 240, 52), .{ .overlay = .{ .open_ids = &.{hover_card.id} } });
    try hover_card.collectInteractions(&h.collector, ui.Rect.init(0, 0, 240, 52));

    try h.expectText("Hover");
    try h.expectText("@shadcn");
    try h.expectHitCount(2);
    try h.expectHitId(1, 998);
}

test "hover card measurement follows trigger and content text" {
    const short = HoverCard{ .id = 997, .trigger = "Hover", .content = "@ui" };
    const long = HoverCard{ .id = 997, .trigger = "Inspect authority", .content = "@runtime-receipts" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
