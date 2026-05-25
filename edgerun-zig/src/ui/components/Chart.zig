const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Chart = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Chart) ui.Node {
        return ui.chartNode(self.id, self.label);
    }

    pub fn render(self: Chart, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderChart(scene, bounds, self.label, options);
    }

    pub fn collectInteractions(self: Chart, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..component_render.chart_bar_count) |index| {
            try collector.addHit(component_render.chartBarBounds(bounds, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: Chart, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_chart, constraints);
    }

    pub fn toObject(self: Chart, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.chart, self.id, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Chart, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .chart, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Chart {
        return switch (try component_codec.singleNode(view)) {
            .chart => |chart| .{ .id = chart.id, .label = chart.label },
            else => error.UnsupportedComponent,
        };
    }
};

test "chart component serializes to canonical object and deserializes" {
    const chart = Chart{ .id = 993, .label = "Visitors" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = chart.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Chart.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(chart.id, decoded.id);
    try std.testing.expectEqualStrings(chart.label, decoded.label);
}

test "chart component renders bars and hit regions" {
    const chart = Chart{ .id = 993, .label = "Visitors" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [component_render.chart_bar_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try chart.render(&scene, ui.Rect.init(0, 0, 240, 90), .{});
    try chart.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 90));

    try std.testing.expect(component_test.hasText(scene.written(), "Visitors"));
    try std.testing.expectEqual(@as(usize, component_render.chart_bar_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 997), collector.written()[4].id);
}
