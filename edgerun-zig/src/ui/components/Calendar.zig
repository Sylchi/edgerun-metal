const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const icon = @import("../../icon.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;
const renderControlText = primitives.renderControlText;

pub const Calendar = struct {
    id: u32,
    month: []const u8,
    selected_day: u16,

    pub fn node(self: Calendar) ui.Node {
        return ui.calendarNode(self.id, self.month, self.selected_day);
    }

    pub fn render(self: Calendar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, calendar_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, calendar_radius, 0.0);
        try renderNav(scene, navBounds(bounds, 0), "<", options);
        try renderNav(scene, navBounds(bounds, 1), ">", options);
        try scene.pushAlignedText(captionBounds(bounds), self.month, options.style.text, .center);

        for (calendar_weekday_labels, 0..) |label, index| {
            try scene.pushAlignedText(weekdayBounds(bounds, index), label, options.style.muted, .center);
        }
        for (calendar_day_labels, 0..) |label, index| {
            const day = @as(u16, @intCast(index + 1));
            try renderDay(scene, dayBounds(bounds, index), label, day == self.selected_day, options);
        }
    }

    pub fn collectInteractions(self: Calendar, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(navBounds(bounds, 0), .button, self.id);
        try collector.addHit(navBounds(bounds, 1), .button, self.id + 1);
        for (0..calendar_day_count) |index| {
            try collector.addHit(dayBounds(bounds, index), .button, self.id + calendar_day_id_offset + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: Calendar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_calendar, constraints);
    }

    pub fn toObject(self: Calendar, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.singleWriter(ui_out) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Calendar, writer: *component_codec.Writer, index: usize) bool {
        const month = writer.string(self.month) orelse return false;
        return writer.record(index, .calendar, self.id, month, .{ .offset = self.selected_day, .len = 0 });
    }

    pub fn fromView(view: object.View) Error!Calendar {
        const calendar = try component_codec.nodeView(view, .calendar);
        return fromNode(calendar);
    }

    pub fn fromNode(calendar: @FieldType(ui.Node, "calendar")) Error!Calendar {
        return .{ .id = calendar.id, .month = calendar.month, .selected_day = calendar.selected_day };
    }
};

fn navBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const y = bounds.y + calendar_padding;
    return switch (index) {
        0 => ui.Rect.init(bounds.x + calendar_padding, y, calendar_nav_size, calendar_nav_size),
        else => ui.Rect.init(bounds.x + bounds.w - calendar_padding - calendar_nav_size, y, calendar_nav_size, calendar_nav_size),
    };
}

fn dayBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const grid = gridBounds(bounds);
    const col = index % calendar_column_count;
    const row = index / calendar_column_count;
    return ui.Rect.init(
        grid.x + @as(f32, @floatFromInt(col)) * (calendar_cell_size + calendar_cell_gap),
        grid.y + @as(f32, @floatFromInt(row)) * (calendar_cell_size + calendar_cell_gap),
        calendar_cell_size,
        calendar_cell_size,
    );
}

fn captionBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + calendar_nav_size + calendar_padding * 2.0, bounds.y + calendar_padding, @max(primitives.min_extent, bounds.w - (calendar_nav_size + calendar_padding * 2.0) * 2.0), calendar_caption_h);
}

fn weekdayBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const grid = gridBounds(bounds);
    return ui.Rect.init(grid.x + @as(f32, @floatFromInt(index)) * (calendar_cell_size + calendar_cell_gap), bounds.y + calendar_weekday_y, calendar_cell_size, calendar_weekday_h);
}

fn gridBounds(bounds: ui.Rect) ui.Rect {
    const grid_w = @as(f32, @floatFromInt(calendar_column_count)) * calendar_cell_size + @as(f32, @floatFromInt(calendar_column_count - 1)) * calendar_cell_gap;
    return ui.Rect.init(bounds.x + (bounds.w - grid_w) * 0.5, bounds.y + calendar_grid_y, grid_w, @max(primitives.min_extent, bounds.h - calendar_grid_y - calendar_padding));
}

fn renderNav(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, ui.Color.clear, .fill, primitives.control_radius, 0.0);
    try renderControlText(scene, bounds, calendar_nav_text_padding, calendar_day_text_h, label, options.style.muted, .center);
}

fn renderDay(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (selected) options.style.accent else ui.Color.clear, .fill, primitives.control_radius, 0.0);
    try renderControlText(scene, bounds, calendar_day_text_padding, calendar_day_text_h, label, if (selected) options.style.bg else options.style.text, .center);
}

const preferred_calendar = ui.Size{ .w = 240.0, .h = 152.0 };
const calendar_day_count: usize = 28;
const calendar_day_id_offset: u32 = 2;
const calendar_column_count: usize = 7;
const calendar_radius: f32 = 8.0;
const calendar_padding: f32 = 8.0;
const calendar_nav_size: f32 = 24.0;
const calendar_caption_h: f32 = 24.0;
const calendar_weekday_y: f32 = 36.0;
const calendar_weekday_h: f32 = 16.0;
const calendar_grid_y: f32 = 56.0;
const calendar_cell_size: f32 = 22.0;
const calendar_cell_gap: f32 = 2.0;
const calendar_day_text_h: f32 = 12.0;
const calendar_day_text_padding: f32 = 2.0;
const calendar_nav_text_padding: f32 = 4.0;
const calendar_weekday_labels = [_][]const u8{ "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" };
const calendar_day_labels = [_][]const u8{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28" };

test "calendar component serializes to canonical object and deserializes" {
    const calendar = Calendar{ .id = 992, .month = "May 2026", .selected_day = 25 };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = calendar.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Calendar.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(calendar.id, decoded.id);
    try std.testing.expectEqual(calendar.selected_day, decoded.selected_day);
    try std.testing.expectEqualStrings(calendar.month, decoded.month);
}

test "calendar component renders caption days and hit regions" {
    const calendar = Calendar{ .id = 992, .month = "May 2026", .selected_day = 25 };
    var commands: [80]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [calendar_day_count + 2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try calendar.render(&scene, ui.Rect.init(0, 0, 240, 152), .{});
    try calendar.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 152));

    try std.testing.expect(component_test.hasText(scene.written(), "May 2026"));
    try std.testing.expect(component_test.hasText(scene.written(), "25"));
    try std.testing.expectEqual(@as(usize, calendar_day_count + 2), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[0].kind);
    try std.testing.expectEqual(@as(u32, 994), collector.written()[2].id);
}
