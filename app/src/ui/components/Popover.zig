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

pub const Popover = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    trigger: []const u8,
    content: []const u8,

    const serialization = component_codec.TwoStringComponent(Popover, "popover", "trigger", "content");

    pub fn node(self: Popover) ui.Node {
        return ui.popoverNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: Popover, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTrigger(scene, bounds, popover_layout, options.style.accent, options.style.border, primitives.control_text_padding, self.trigger, options.style.bg);
        if (options.overlay.isOpen(self.id)) {
            const content_bounds = primitives.sidePanelContentBounds(bounds, popover_layout);
            try scene.pushRect(content_bounds, options.style.panel, .fill, popover_radius, 0.0);
            try scene.pushRect(content_bounds, options.style.border, .border, popover_radius, 0.0);
            try primitives.renderControlText(scene, content_bounds, popover_padding, primitives.control_label_height, self.content, options.style.text, .start);
        }
    }

    pub fn collectInteractions(self: Popover, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelLayoutHits(collector, bounds, popover_layout, self.id);
    }

    pub fn measure(self: Popover, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const trigger = text_component.Text.measureValue(self.trigger, .{ .width = .unconstrained, .text_wrap = .nowrap }, primitives.textMetrics(self.trigger, primitives.control_label_height, 1));
        const content_constraints = constraints.inner(.{ .left = trigger.preferred.w + primitives.control_text_padding * 2.0 + popover_layout.gap + popover_padding, .right = popover_padding });
        const content = text_component.Text.measureValue(self.content, content_constraints, primitives.textMetrics(self.content, primitives.control_label_height, 1));
        const preferred = primitives.constrainPreferredSize(.{
            .w = trigger.preferred.w + primitives.control_text_padding * 2.0 + popover_layout.gap + content.preferred.w + popover_padding * 2.0,
            .h = @max(popover_layout.trigger_y + @max(popover_layout.trigger_h, trigger.preferred.h + primitives.control_text_padding * 2.0), content.preferred.h + popover_padding * 2.0),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = primitives.min_extent * 2.0 + popover_layout.gap, .h = primitives.control_label_height + popover_padding * 2.0 },
            preferred,
            .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }
    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(popover: @FieldType(ui.Node, "popover")) Error!Popover {
        return .{ .id = popover.id, .trigger = popover.trigger, .content = popover.content };
    }
};

const popover_layout = primitives.SidePanelLayout{ .trigger_y = 6.0, .trigger_w = 64.0, .trigger_h = 30.0, .gap = 10.0 };
const popover_radius: f32 = 8.0;
const popover_padding: f32 = 10.0;

test "popover component renders trigger content and hit regions" {
    const popover = Popover{ .id = 995, .trigger = "Open", .content = "Place content" };
    var h = component_test.InteractiveHarness(20, 2){};
    h.init();

    try h.render(popover, ui.Rect.init(0, 0, 240, 52), .{ .overlay = .{ .open_ids = &.{popover.id} } });
    try popover.collectInteractions(&h.collector, ui.Rect.init(0, 0, 240, 52));

    try h.expectText("Open");
    try h.expectText("Place content");
    try h.expectHitCount(2);
    try h.expectHitId(1, 996);
}

test "popover measurement follows trigger and content text" {
    const short = Popover{ .id = 995, .trigger = "Open", .content = "Body" };
    const long = Popover{ .id = 995, .trigger = "Open authority", .content = "Runtime receipt controls" };

    try component_test.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
