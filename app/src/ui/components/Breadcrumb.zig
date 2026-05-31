const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const Icon = icon_component.Icon;

pub const Breadcrumb = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    first: []const u8,
    current: []const u8,

    pub fn node(self: Breadcrumb) ui.Node {
        return ui.breadcrumbNode(self.id, self.first, self.current);
    }

    pub fn render(self: Breadcrumb, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const first_bounds = itemBounds(self, bounds, 0);
        const middle_bounds = itemBounds(self, bounds, 1);
        const current_bounds = itemBounds(self, bounds, 2);
        try text_component.Text.renderPlain(scene, first_bounds.withHeightCentered(primitives.control_label_height), self.first, options.style.muted);
        try Icon.named(.chevron_right).renderColor(scene, separatorBounds(self, bounds, 0), options.style.muted);
        try text_component.Text.renderPlain(scene, middle_bounds.withHeightCentered(primitives.control_label_height), breadcrumb_middle_label, options.style.muted);
        try Icon.named(.chevron_right).renderColor(scene, separatorBounds(self, bounds, 1), options.style.muted);
        try text_component.Text.renderPlain(scene, current_bounds.withHeightCentered(primitives.control_label_height), self.current, options.style.text);
    }

    pub fn collectInteractions(self: Breadcrumb, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(itemBounds(self, bounds, 0), .button, self.id);
        try collector.addHit(itemBounds(self, bounds, 1), .button, common.offsetId(self.id, 1));
    }

    pub fn measure(self: Breadcrumb, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const first = labelMeasure(self.first);
        const middle = labelMeasure(breadcrumb_middle_label);
        const current = labelMeasure(self.current);
        const separator_total_w = breadcrumb_separator_gap * 2.0 + breadcrumb_icon_size * 2.0;
        const preferred = primitives.constrainPreferredSize(.{
            .w = first.preferred.w + middle.preferred.w + current.preferred.w + separator_total_w,
            .h = @max(@max(first.preferred.h, middle.preferred.h), current.preferred.h) + breadcrumb_vertical_padding * 2.0,
        }, constraints);
        return layout.Measurement.flexible(
            .{
                .w = primitives.min_extent * 3.0 + separator_total_w,
                .h = primitives.control_label_height + breadcrumb_vertical_padding * 2.0,
            },
            preferred,
            .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Breadcrumb, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.breadcrumb, self.id, self.first, self.current, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Breadcrumb, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .breadcrumb, self.id, self.first, self.current);
    }

    pub fn fromView(view: object.View) Error!Breadcrumb {
        return component_codec.decodeFromView(Breadcrumb, .breadcrumb, view);
    }

    pub fn fromNode(breadcrumb: @FieldType(ui.Node, "breadcrumb")) Error!Breadcrumb {
        return .{ .id = breadcrumb.id, .first = breadcrumb.first, .current = breadcrumb.current };
    }
};

fn itemBounds(self: Breadcrumb, bounds: ui.Rect, index: usize) ui.Rect {
    const first_w = allocatedLabelWidth(self, bounds, 0);
    const middle_w = allocatedLabelWidth(self, bounds, 1);
    const first_x = bounds.x;
    const middle_x = first_x + first_w + breadcrumb_separator_gap + breadcrumb_icon_size;
    const current_x = middle_x + middle_w + breadcrumb_separator_gap + breadcrumb_icon_size;
    return switch (index) {
        0 => ui.Rect.init(first_x, bounds.y, first_w, bounds.h),
        1 => ui.Rect.init(middle_x, bounds.y, middle_w, bounds.h),
        else => ui.Rect.init(current_x, bounds.y, @max(primitives.min_extent, bounds.x + bounds.w - current_x), bounds.h),
    };
}

fn separatorBounds(self: Breadcrumb, bounds: ui.Rect, index: usize) ui.Rect {
    const item = itemBounds(self, bounds, index);
    const x = item.x + item.w + breadcrumb_separator_gap * 0.5;
    return ui.Rect.init(x, bounds.y + (bounds.h - breadcrumb_icon_size) * 0.5, breadcrumb_icon_size, breadcrumb_icon_size);
}

fn allocatedLabelWidth(self: Breadcrumb, bounds: ui.Rect, index: usize) f32 {
    const first = labelMeasure(self.first).preferred.w;
    const middle = labelMeasure(breadcrumb_middle_label).preferred.w;
    const current = labelMeasure(self.current).preferred.w;
    const separator_total_w = breadcrumb_separator_gap * 2.0 + breadcrumb_icon_size * 2.0;
    const available = @max(primitives.min_extent * 3.0, bounds.w - separator_total_w);
    const natural_total = @max(primitives.min_extent, first + middle + current);
    const scale = @min(1.0, available / natural_total);
    return switch (index) {
        0 => @max(primitives.min_extent, first * scale),
        1 => @max(primitives.min_extent, middle * scale),
        else => @max(primitives.min_extent, current * scale),
    };
}

fn labelMeasure(value: []const u8) layout.Measurement {
    return text_component.Text.measureValue(value, .{ .width = .unconstrained, .text_wrap = .nowrap }, primitives.textMetrics(value, primitives.control_label_height, breadcrumb_label_max_lines));
}

const breadcrumb_icon_size: f32 = 12.0;
const breadcrumb_separator_gap: f32 = 6.0;
const breadcrumb_vertical_padding: f32 = 8.0;
const breadcrumb_label_max_lines: usize = 1;
const breadcrumb_middle_label = "Docs";

test "breadcrumb component serializes to canonical object and deserializes" {
    const breadcrumb = Breadcrumb{ .id = 130, .first = "Home", .current = "Button" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = breadcrumb.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Breadcrumb.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(breadcrumb.id, decoded.id);
    try std.testing.expectEqualStrings(breadcrumb.first, decoded.first);
    try std.testing.expectEqualStrings(breadcrumb.current, decoded.current);
}

test "breadcrumb component renders links current page and link hits" {
    const breadcrumb = Breadcrumb{ .id = 130, .first = "Home", .current = "Button" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try breadcrumb.render(&scene, ui.Rect.init(0, 0, 220, 36), .{});
    try breadcrumb.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Home"));
    try std.testing.expect(component_test.hasText(scene.written(), "Docs"));
    try std.testing.expect(component_test.hasText(scene.written(), "Button"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 131), collector.written()[1].id);
}

test "breadcrumb measurement follows label content" {
    const short = Breadcrumb{ .id = 130, .first = "H", .current = "B" };
    const long = Breadcrumb{ .id = 130, .first = "Runtime Home", .current = "Component Authority" };

    const short_measured = short.measure(.{}, .{});
    const long_measured = long.measure(.{}, .{});

    try std.testing.expect(long_measured.preferred.w > short_measured.preferred.w);
}
