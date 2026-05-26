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
const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Chart = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Chart) ui.Node {
        return ui.chartNode(self.id, self.label);
    }

    pub fn render(self: Chart, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const plot = plotBounds(bounds, self.label);
        try scene.pushRect(bounds, options.style.panel, .fill, chart_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, chart_radius, 0.0);
        const label = labelBounds(bounds, self.label);
        try scene.pushWrappedText(label, self.label, options.style.text, component_primitives.textWrap(self.label, chart_label_h, chart_label_max_lines));
        try scene.pushRect(ui.Rect.init(plot.x, plot.y + plot.h - separator_height, plot.w, separator_height), options.style.border, .fill, 0.0, 0.0);
        for (0..chart_bar_count) |index| {
            const bar = barBounds(bounds, self.label, index);
            try scene.pushRect(bar, if (index == chart_bar_count - 1) options.style.accent else options.style.row, .fill, chart_bar_radius, 0.0);
        }
    }

    pub fn collectInteractions(self: Chart, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..chart_bar_count) |index| {
            try collector.addHit(barBounds(bounds, self.label, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: Chart, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const inner = constraints.inner(.{ .left = chart_padding, .right = chart_padding });
        const label = layout.measureText(self.label, inner, component_primitives.textMetrics(self.label, chart_label_h, chart_label_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(chart_min_width, label.preferred.w + chart_padding * 2.0),
            .h = chart_padding * 2.0 + label.preferred.h + chart_label_gap + chart_plot_min_h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(chart_min_width, preferred.w), .h = @min(chart_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.measure_max_width, .h = @max(preferred.h, preferred_chart.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Chart, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.chart, self.id, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Chart, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .chart, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Chart {
        const chart = try component_codec.nodeView(view, .chart);
        return fromNode(chart);
    }

    pub fn fromNode(chart: @FieldType(ui.Node, "chart")) Error!Chart {
        return .{ .id = chart.id, .label = chart.label };
    }
};

fn barBounds(bounds: ui.Rect, label: []const u8, index: usize) ui.Rect {
    const plot = plotBounds(bounds, label);
    const gap_total = chart_bar_gap * @as(f32, @floatFromInt(chart_bar_count - 1));
    const bar_w = @max(component_primitives.min_extent, (plot.w - gap_total) / @as(f32, @floatFromInt(chart_bar_count)));
    const h = @max(component_primitives.min_extent, plot.h * chart_bar_values[index]);
    return ui.Rect.init(plot.x + @as(f32, @floatFromInt(index)) * (bar_w + chart_bar_gap), plot.y + plot.h - h, bar_w, h);
}

fn plotBounds(bounds: ui.Rect, label: []const u8) ui.Rect {
    const label_h = labelBounds(bounds, label).h;
    return ui.Rect.init(
        bounds.x + chart_padding,
        bounds.y + chart_padding + label_h + chart_label_gap,
        @max(component_primitives.min_extent, bounds.w - chart_padding * 2.0),
        @max(component_primitives.min_extent, bounds.h - chart_padding * 2.0 - label_h - chart_label_gap),
    );
}

fn labelBounds(bounds: ui.Rect, label: []const u8) ui.Rect {
    const width = @max(component_primitives.min_extent, bounds.w - chart_padding * 2.0);
    const height = if (label.len == 0) chart_label_h else component_primitives.measuredTextHeight(label, width, chart_label_h, chart_label_max_lines);
    return ui.Rect.init(bounds.x + chart_padding, bounds.y + chart_padding, width, @min(height, @max(component_primitives.min_extent, bounds.h - chart_padding * 2.0)));
}

const separator_height: f32 = 1.0;
pub const chart_bar_count: usize = 5;
const chart_radius: f32 = 8.0;
const chart_padding: f32 = 8.0;
const chart_label_h: f32 = 14.0;
const chart_label_max_lines: usize = 2;
const chart_label_gap: f32 = 4.0;
const chart_bar_gap: f32 = 5.0;
const chart_bar_radius: f32 = 5.0;
const chart_plot_min_h: f32 = 64.0;
const chart_min_width: f32 = 120.0;
const chart_min_height: f32 = 72.0;
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

test "chart component measurement wraps long labels under narrow constraints" {
    const chart = Chart{ .id = 993, .label = "Runtime authority decisions" };

    const measured = chart.measure(.{ .width = .{ .at_most = chart_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= chart_min_width);
    try std.testing.expect(measured.preferred.h > preferred_chart.h);
}
