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
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: HoverCard) ui.Node {
        return ui.hoverCardNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: HoverCard, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTrigger(scene, bounds, hover_card_layout, options.style.panel, options.style.border, primitives.control_text_padding, self.trigger, options.style.text);
        if (options.overlay.isOpen(self.id)) {
            try primitives.renderTitleDetailPanel(scene, primitives.sidePanelContentBounds(bounds, hover_card_layout), self.content, hover_card_detail_label, options, hover_card_panel, options.style.border, options.style.text);
        }
    }

    pub fn collectInteractions(self: HoverCard, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelLayoutHits(collector, bounds, hover_card_layout, self.id);
    }

    pub fn measure(self: HoverCard, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return primitives.measureSidePanelTitleDetail(self.trigger, self.content, hover_card_detail_label, constraints, hover_card_layout, primitives.control_text_padding, hover_card_panel);
    }

    pub fn toObject(self: HoverCard, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.hover_card, self.id, self.trigger, self.content, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: HoverCard, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .hover_card, self.id, self.trigger, self.content);
    }

    pub fn fromView(view: object.View) Error!HoverCard {
        const hover_card = try component_codec.nodeView(view, .hover_card);
        return fromNode(hover_card);
    }

    pub fn fromNode(hover_card: @FieldType(ui.Node, "hover_card")) Error!HoverCard {
        return .{ .id = hover_card.id, .trigger = hover_card.trigger, .content = hover_card.content };
    }
};

const hover_card_layout = primitives.SidePanelLayout{ .trigger_y = 6.0, .trigger_w = 66.0, .trigger_h = 30.0, .gap = 10.0 };
const hover_card_radius: f32 = 8.0;
const hover_card_padding: f32 = 10.0;
const hover_card_panel = primitives.TitleDetailPanel{ .radius = hover_card_radius, .padding = hover_card_padding, .title_y = 8.0, .title_h = 14.0, .detail_y = 25.0, .detail_h = 12.0 };
const hover_card_detail_label = "Hover content";

test "hover card component serializes to canonical object and deserializes" {
    const hover_card = HoverCard{ .id = 997, .trigger = "Hover", .content = "@shadcn" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = hover_card.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try HoverCard.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(hover_card.id, decoded.id);
    try std.testing.expectEqualStrings(hover_card.trigger, decoded.trigger);
    try std.testing.expectEqualStrings(hover_card.content, decoded.content);
}

test "hover card component renders trigger content and hit regions" {
    const hover_card = HoverCard{ .id = 997, .trigger = "Hover", .content = "@shadcn" };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try hover_card.render(&scene, ui.Rect.init(0, 0, 240, 52), .{ .overlay = .{ .open_ids = &.{hover_card.id} } });
    try hover_card.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Hover"));
    try std.testing.expect(component_test.hasText(scene.written(), "@shadcn"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 998), collector.written()[1].id);
}

test "hover card measurement follows trigger and content text" {
    const short = HoverCard{ .id = 997, .trigger = "Hover", .content = "@ui" };
    const long = HoverCard{ .id = 997, .trigger = "Inspect authority", .content = "@runtime-receipts" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
