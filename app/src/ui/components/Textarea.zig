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
const component_primitives = @import("Primitives.zig");
const tokens = @import("../theme.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const contentInset = component_primitives.contentInset;

pub const Textarea = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    placeholder: []const u8,
    value: []const u8 = "",

    pub fn node(self: Textarea) ui.Node {
        return ui.textareaNode(self.id, self.placeholder);
    }

    pub fn accessibility(self: Textarea) common.Accessibility {
        return .{ .role = .input, .label = self.placeholder, .control_id = self.id };
    }

    pub fn render(self: Textarea, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, component_primitives.control_radius, 0.0);
        if (contentInset(bounds, textarea_padding)) |text_bounds| {
            const text = self.displayValue();
            const color = if (self.value.len == 0) options.style.muted else options.style.text;
            try text_component.Text.renderWrapped(scene, text_bounds, text, color, .{
                .line_height = component_primitives.control_label_height,
                .average_char_width = control_average_char_width,
                .max_lines = textarea_max_lines,
            });
        }
    }

    pub fn collectInteractions(self: Textarea, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .textarea, self.id);
    }

    pub fn measure(self: Textarea, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const text = text_component.Text.measureValue(
            self.placeholder,
            constraints.inner(.{ .left = textarea_padding, .right = textarea_padding, .top = textarea_padding, .bottom = textarea_padding }),
            .{
                .line_height = component_primitives.control_label_height,
                .average_char_width = control_average_char_width,
                .max_lines = textarea_max_lines,
            },
        ).withInsets(.{ .left = textarea_padding, .right = textarea_padding, .top = textarea_padding, .bottom = textarea_padding });
        const preferred = component_primitives.constrainPreferredSize(text.preferred, constraints);
        return layout.Measurement.flexible(
            .{
                .w = @min(textarea_min_width, preferred.w),
                .h = @min(component_primitives.control_label_height + textarea_padding * 2.0, preferred.h),
            },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = @max(preferred.h, text.max.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Textarea, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.textarea, self.id, self.placeholder, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Textarea, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .textarea, self.id, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Textarea {
        return component_codec.decodeFromView(Textarea, .textarea, view);
    }

    pub fn fromNode(textarea: @FieldType(ui.Node, "textarea")) Error!Textarea {
        return .{ .id = textarea.id, .placeholder = textarea.placeholder };
    }

    fn displayValue(self: Textarea) []const u8 {
        return if (self.value.len == 0) self.placeholder else self.value;
    }
};

pub const TextGrid = struct {
    first_line: usize = 0,
    line_height: f32,
    char_width: f32,
    gutter_width: f32 = 0.0,
    padding_left: f32 = 0.0,
    padding_top: f32 = 0.0,
};

pub fn cursorFromPoint(value: []const u8, bounds: ui.Rect, x: f32, y: f32, grid: TextGrid) usize {
    const local_x = @max(0.0, x - bounds.x - grid.padding_left - grid.gutter_width);
    const local_y = @max(0.0, y - bounds.y - grid.padding_top);
    const line_offset: usize = @intFromFloat(@floor(local_y / @max(1.0, grid.line_height)));
    const target_line = grid.first_line + line_offset;
    const target_column: usize = @intFromFloat(@floor(local_x / @max(1.0, grid.char_width)));
    const start = lineStartAt(value, target_line);
    const end = lineEndAt(value, start);
    return start + @min(target_column, end - start);
}

fn lineStartAt(value: []const u8, target_line: usize) usize {
    var line: usize = 0;
    var index: usize = 0;
    while (index < value.len and line < target_line) : (index += 1) {
        if (value[index] == '\n') line += 1;
    }
    return index;
}

fn lineEndAt(value: []const u8, start: usize) usize {
    var index = @min(start, value.len);
    while (index < value.len and value[index] != '\n') : (index += 1) {}
    return index;
}

const control_average_char_width: f32 = tokens.Component.control_average_char_width;
const textarea_padding: f32 = 12.0;
const textarea_max_lines: usize = 4;
const textarea_min_width: f32 = 96.0;

test "textarea component serializes to canonical object and deserializes" {
    const textarea = Textarea{ .id = 21, .placeholder = "Describe this app" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = textarea.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Textarea.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(textarea.id, decoded.id);
    try std.testing.expectEqualStrings(textarea.placeholder, decoded.placeholder);
}

test "textarea component wraps placeholder inside shared control inset" {
    const textarea = Textarea{ .id = 21, .placeholder = "Describe this app state" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try textarea.render(&scene, ui.Rect.init(4, 8, 72, 88), .{});

    const first = component_test.firstTextCommand(scene.written()).?;
    try std.testing.expectEqual(ui.Color.muted, first.text.color);
    try std.testing.expectEqual(@as(f32, 16.0), first.text.origin.x);
    try std.testing.expectEqual(@as(f32, 20.0), first.text.origin.y);
    try std.testing.expect(component_test.textCount(scene.written()) > 1);
}

test "textarea component renders value when present" {
    const textarea = Textarea{ .id = 21, .placeholder = "Describe this app state", .value = "Live note" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try textarea.render(&scene, ui.Rect.init(4, 8, 160, 88), .{});

    const value = component_test.textCommand(scene.written(), "Live note").?;
    try std.testing.expectEqual(ui.Color.text, value.text.color);
    try std.testing.expect(component_test.textCommand(scene.written(), "Describe this app state") == null);
}


test "textarea text grid maps pointer position to byte cursor" {
    const value = "aa\nbbbb\nc";
    const bounds = ui.Rect.init(10.0, 20.0, 240.0, 120.0);
    const grid = TextGrid{
        .first_line = 0,
        .line_height = 18.0,
        .char_width = 10.0,
        .gutter_width = 40.0,
        .padding_left = 8.0,
        .padding_top = 6.0,
    };

    try std.testing.expectEqual(@as(usize, 0), cursorFromPoint(value, bounds, 58.0, 26.0, grid));
    try std.testing.expectEqual(@as(usize, 4), cursorFromPoint(value, bounds, 68.0, 44.0, grid));
    try std.testing.expectEqual(@as(usize, 7), cursorFromPoint(value, bounds, 200.0, 44.0, grid));
    try std.testing.expectEqual(value.len, cursorFromPoint(value, bounds, 200.0, 80.0, grid));
}

test "textarea measurement follows placeholder text" {
    const short = Textarea{ .id = 21, .placeholder = "Note" };
    const long = Textarea{ .id = 21, .placeholder = "Describe the runtime authority and receipt flow" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
