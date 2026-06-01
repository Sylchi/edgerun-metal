const std = @import("er_std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Resizable = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    ratio: f32 = 0.58,

    pub fn node(self: Resizable) ui.Node {
        return ui.resizableNode(self.id, self.ratio);
    }

    pub fn render(self: Resizable, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const ratio = options.drag_value orelse self.ratio;
        const handle = handleBounds(bounds, ratio);
        const left = ui.Rect.init(bounds.x, bounds.y, @max(component_primitives.min_extent, handle.x - bounds.x), bounds.h);
        const right_x = handle.x + handle.w;
        const right = ui.Rect.init(right_x, bounds.y, @max(component_primitives.min_extent, bounds.x + bounds.w - right_x), bounds.h);
        try scene.pushRect(left, options.style.panel, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(right, options.style.row, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(handle, options.style.border, .fill, resizable_handle_radius, 0.0);
    }

    pub fn collectInteractions(self: Resizable, collector: *interaction.Collector, bounds: ui.Rect, options: RenderOptions) interaction.Error!void {
        const ratio = options.drag_value orelse self.ratio;
        try collector.addHit(handleBounds(bounds, ratio).insetUniform(-resizable_handle_hit_outset), .slider, self.id);
    }

    pub fn measure(self: Resizable, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        const preferred = component_primitives.constrainPreferredSize(resizableIntrinsicSize(), constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(resizable_min_width, preferred.w), .h = @min(resizable_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Resizable, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.resizable, self.id, component_codec.unitRef(self.ratio), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Resizable, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .resizable, self.id, component_codec.unitRef(self.ratio));
    }

    pub fn fromView(view: object.View) Error!Resizable {
        return component_codec.decodeFromView(Resizable, .resizable, view);
    }

    pub fn fromNode(resizable: @FieldType(ui.Node, "resizable")) Error!Resizable {
        return .{ .id = resizable.id, .ratio = resizable.ratio };
    }
};

fn handleBounds(bounds: ui.Rect, ratio: f32) ui.Rect {
    const clamped_ratio = @min(@max(ratio, 0.0), 1.0);
    const center_x = bounds.x + bounds.w * clamped_ratio;
    return ui.Rect.init(center_x - resizable_handle_w * 0.5, bounds.y, resizable_handle_w, bounds.h);
}

fn resizableIntrinsicSize() ui.Size {
    return .{ .w = resizable_min_width, .h = resizable_min_height };
}

const resizable_handle_w: f32 = 6.0;
const resizable_handle_radius: f32 = 3.0;
const resizable_handle_hit_outset: f32 = 6.0;
const resizable_min_width: f32 = 96.0;
const resizable_min_height: f32 = 36.0;

test "resizable component renders panels and handle hit region" {
    const resizable = Resizable{ .id = 770, .ratio = 0.58 };
    var h = component_test.InteractiveHarness(16, 1){};
    h.init();

    try h.render(resizable, ui.Rect.init(0, 0, 220, 36), .{});
    try resizable.collectInteractions(&h.collector, ui.Rect.init(0, 0, 220, 36), .{});

    try std.testing.expect(h.written().len >= 3);
    try h.expectHitCount(1);
    try h.expectHitKind(0, .slider);
    try h.expectHitId(0, 770);
}

test "resizable measurement derives from handle geometry" {
    const resizable = Resizable{ .id = 770, .ratio = 0.58 };

    const measured = resizable.measure(.{}, .{});

    try std.testing.expectEqual(resizableIntrinsicSize().w, measured.preferred.w);
    try std.testing.expectEqual(resizableIntrinsicSize().h, measured.preferred.h);
}
