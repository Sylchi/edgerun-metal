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

pub const Calendar = struct {
    id: u32,
    month: []const u8,
    selected_day: u16,

    pub fn node(self: Calendar) ui.Node {
        return ui.calendarNode(self.id, self.month, self.selected_day);
    }

    pub fn render(self: Calendar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderCalendar(scene, bounds, self.month, self.selected_day, options);
    }

    pub fn collectInteractions(self: Calendar, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.calendarNavBounds(bounds, 0), .button, self.id);
        try collector.addHit(component_render.calendarNavBounds(bounds, 1), .button, self.id + 1);
        for (0..component_render.calendar_day_count) |index| {
            try collector.addHit(component_render.calendarDayBounds(bounds, index), .button, self.id + component_render.calendar_day_id_offset + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: Calendar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_calendar, constraints);
    }

    pub fn toObject(self: Calendar, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.singleWriter(ui_out) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, req, epoch);
    }

    pub fn writeRecord(self: Calendar, writer: *component_codec.Writer, index: usize) bool {
        const month = writer.string(self.month) orelse return false;
        return writer.record(index, .calendar, self.id, month, .{ .offset = self.selected_day, .len = 0 });
    }

    pub fn fromView(view: object.View) Error!Calendar {
        return switch (try component_codec.singleNode(view)) {
            .calendar => |calendar| .{ .id = calendar.id, .month = calendar.month, .selected_day = calendar.selected_day },
            else => error.UnsupportedComponent,
        };
    }
};

test "calendar component serializes to canonical object and deserializes" {
    const calendar = Calendar{ .id = 992, .month = "May 2026", .selected_day = 25 };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = calendar.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Calendar.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(calendar.id, decoded.id);
    try std.testing.expectEqual(calendar.selected_day, decoded.selected_day);
    try std.testing.expectEqualStrings(calendar.month, decoded.month);
}

test "calendar component renders caption days and hit regions" {
    const calendar = Calendar{ .id = 992, .month = "May 2026", .selected_day = 25 };
    var commands: [80]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [component_render.calendar_day_count + 2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try calendar.render(&scene, ui.Rect.init(0, 0, 240, 152), .{});
    try calendar.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 152));

    try std.testing.expect(component_test.hasText(scene.written(), "May 2026"));
    try std.testing.expect(component_test.hasText(scene.written(), "25"));
    try std.testing.expectEqual(@as(usize, component_render.calendar_day_count + 2), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[0].kind);
    try std.testing.expectEqual(@as(u32, 994), collector.written()[2].id);
}
