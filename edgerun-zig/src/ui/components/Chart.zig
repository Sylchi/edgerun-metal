const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

pub const Chart = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Chart) ui.Node {
        return ui.chartNode(self.id, self.label);
    }

    pub fn render(self: Chart, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const plot = plotBounds(bounds);
        try scene.pushRect(bounds, options.style.panel, .fill, chart_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, chart_radius, 0.0);
        try scene.pushText(ui.Rect.init(bounds.x + chart_padding, bounds.y + chart_padding, @max(component_primitives.min_extent, bounds.w - chart_padding * 2.0), chart_label_h), self.label, options.style.text);
        try scene.pushRect(ui.Rect.init(plot.x, plot.y + plot.h - separator_height, plot.w, separator_height), options.style.border, .fill, 0.0, 0.0);
        for (0..chart_bar_count) |index| {
            const bar = barBounds(bounds, index);
            try scene.pushRect(bar, if (index == chart_bar_count - 1) options.style.accent else options.style.row, .fill, chart_bar_radius, 0.0);
        }
    }

    pub fn collectInteractions(self: Chart, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..chart_bar_count) |index| {
            try collector.addHit(barBounds(bounds, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: Chart, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_chart, constraints);
    }

    pub fn toObject(self: Chart, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.chart, self.id, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Chart, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .chart, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Chart {
        const chart = try component_codec.nodeView(view, .chart);
        return .{ .id = chart.id, .label = chart.label };
    }
};

fn barBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const plot = plotBounds(bounds);
    const gap_total = chart_bar_gap * @as(f32, @floatFromInt(chart_bar_count - 1));
    const bar_w = @max(component_primitives.min_extent, (plot.w - gap_total) / @as(f32, @floatFromInt(chart_bar_count)));
    const h = @max(component_primitives.min_extent, plot.h * chart_bar_values[index]);
    return ui.Rect.init(plot.x + @as(f32, @floatFromInt(index)) * (bar_w + chart_bar_gap), plot.y + plot.h - h, bar_w, h);
}

fn plotBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(
        bounds.x + chart_padding,
        bounds.y + chart_padding + chart_label_h + chart_label_gap,
        @max(component_primitives.min_extent, bounds.w - chart_padding * 2.0),
        @max(component_primitives.min_extent, bounds.h - chart_padding * 2.0 - chart_label_h - chart_label_gap),
    );
}

const separator_height: f32 = 1.0;
pub const chart_bar_count: usize = 5;
const chart_radius: f32 = 8.0;
const chart_padding: f32 = 8.0;
const chart_label_h: f32 = 14.0;
const chart_label_gap: f32 = 4.0;
const chart_bar_gap: f32 = 5.0;
const chart_bar_radius: f32 = 5.0;
pub const preferred_chart = ui.Size{ .w = 240.0, .h = 90.0 };
const chart_bar_values = [_]f32{ 0.45, 0.72, 0.38, 0.86, 0.62 };

test "chart component serializes to canonical object and deserializes" {
    const chart = Chart{ .id = 993, .label = "Visitors" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = chart.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Chart.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(chart.id, decoded.id);
    try std.testing.expectEqualStrings(chart.label, decoded.label);
}

test "chart component renders bars and hit regions" {
    const chart = Chart{ .id = 993, .label = "Visitors" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [chart_bar_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try chart.render(&scene, ui.Rect.init(0, 0, 240, 90), .{});
    try chart.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 90));

    try std.testing.expect(component_test.hasText(scene.written(), "Visitors"));
    try std.testing.expectEqual(@as(usize, chart_bar_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 997), collector.written()[4].id);
}
