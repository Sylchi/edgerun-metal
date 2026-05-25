const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const icon = @import("../../icon.zig");
const interaction = @import("../../ui_interaction.zig");
const layout = @import("../../layouts/Types.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../../ui.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Button = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Button) ui.Node {
        return .{ .button = .{ .id = self.id, .label = self.label } };
    }

    pub fn render(self: Button, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderButton(scene, bounds, self, options);
    }

    pub fn collectInteractions(self: Button, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectButtonInteractions(collector, bounds, self);
    }

    pub fn measure(self: Button, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureButton(self.label, constraints);
    }

    pub fn toObject(self: Button, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.button, self.id, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Button, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .button, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Button {
        return switch (try component_codec.singleNode(view)) {
            .button => |button| .{ .id = button.id, .label = button.label },
            else => error.UnsupportedComponent,
        };
    }
};

fn renderButton(scene: *ui.Scene, bounds: ui.Rect, button: Button, options: RenderOptions) ui.RenderError!void {
    const text_color = switch (options.button_variant) {
        .primary => options.style.bg,
        .secondary => options.style.text,
        .outline => options.style.text,
        .ghost => options.style.muted,
        .destructive => ui.Color{ .r = 255, .g = 255, .b = 255 },
        .link => options.style.accent,
    };
    switch (options.button_variant) {
        .primary => {
            try scene.pushRect(bounds, options.style.accent, .fill, radius, 0.0);
            try scene.pushRect(bounds, options.style.accent, .border, radius, 0.0);
        },
        .secondary => {
            try scene.pushRect(bounds, options.style.row, .fill, radius, 0.0);
            try scene.pushRect(bounds, options.style.border, .border, radius, 0.0);
        },
        .outline => {
            try scene.pushRect(bounds, options.style.panel, .fill, radius, 0.0);
            try scene.pushRect(bounds, options.style.border, .border, radius, 0.0);
        },
        .destructive => {
            try scene.pushRect(bounds, button_danger, .fill, radius, 0.0);
            try scene.pushRect(bounds, button_danger, .border, radius, 0.0);
        },
        .ghost => {
            try scene.pushRect(bounds, ui.Color.clear, .fill, radius, 0.0);
        },
        .link => {},
    }
    try renderContent(scene, bounds, button.label, text_color, options.button_leading_icon, options.button_trailing_icon);
}

fn collectButtonInteractions(collector: *interaction.Collector, bounds: ui.Rect, button: Button) interaction.Error!void {
    try collector.addHit(bounds, .button, button.id);
}

fn measureButton(label: []const u8, constraints: layout.Constraints) layout.Measurement {
    const preferred_width = @max(min_width, estimatedLabelWidth(label) + label_padding * 2.0);
    return layout.Measurement.flexible(
        .{ .w = min_width, .h = height },
        .{ .w = preferred_width, .h = height },
        .{ .w = max_width, .h = height },
    ).applyExact(constraints);
}

fn renderContent(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, text_color: ui.Color, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon) ui.RenderError!void {
    const has_leading = leading_icon != null;
    const has_trailing = trailing_icon != null;
    if (!has_leading and !has_trailing) {
        try scene.pushAlignedText(textBounds(bounds), label, text_color, .center);
        return;
    }

    const icon_count: usize = @intFromBool(has_leading) + @intFromBool(has_trailing);
    const label_w = estimatedLabelWidth(label);
    const content_w = label_w +
        @as(f32, @floatFromInt(icon_count)) * icon_size +
        @as(f32, @floatFromInt(icon_count)) * icon_gap;
    var cursor_x = bounds.x + @max(content_min_x, (bounds.w - content_w) * 0.5);
    const icon_y = bounds.y + (bounds.h - icon_size) * 0.5;
    const text_y = bounds.y + (bounds.h - label_height) * 0.5;

    if (leading_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, icon_size, icon_size),
            .icon_id = icon.id(value),
            .color = text_color,
        });
        cursor_x += icon_size + icon_gap;
    }

    try scene.pushAlignedText(ui.Rect.init(cursor_x, text_y, label_w, label_height), label, text_color, .start);
    cursor_x += label_w + icon_gap;

    if (trailing_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, icon_size, icon_size),
            .icon_id = icon.id(value),
            .color = text_color,
        });
    }
}

fn textBounds(bounds: ui.Rect) ui.Rect {
    const margin = @min(label_padding, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + margin, bounds.y + (bounds.h - label_height) * 0.5, @max(1.0, bounds.w - margin * 2.0), label_height);
}

fn estimatedLabelWidth(label: []const u8) f32 {
    return @max(label_min_width, @as(f32, @floatFromInt(label.len)) * label_average_w);
}

pub const radius: f32 = 7.0;
pub const height: f32 = 36.0;
pub const label_height: f32 = 16.0;
pub const label_padding: f32 = 14.0;

const label_average_w: f32 = 8.0;
const label_min_width: f32 = 8.0;
const icon_size: f32 = 18.0;
const icon_gap: f32 = 8.0;
const content_min_x: f32 = 14.0;
const min_width: f32 = 44.0;
const max_width: f32 = 4096.0;
const button_danger = ui.Color{ .r = 225, .g = 29, .b = 72 };

test "button component serializes to canonical object and deserializes" {
    const button = Button{ .id = 7, .label = "Run" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Button.fromView(try object.View.decode(canonical));

    try @import("std").testing.expectEqual(@as(u32, 7), decoded.id);
    try @import("std").testing.expectEqualStrings("Run", decoded.label);
}

test "button component measurement follows label width" {
    const short = measureButton("Go", .{});
    const long = measureButton("Continue lesson", .{});

    try std.testing.expect(long.preferred.w > short.preferred.w);
    try std.testing.expectEqual(height, long.preferred.h);
}

test "button component renders extended reference variants" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try renderButton(&scene, ui.Rect.init(0, 0, 120, height), .{ .id = 1, .label = "Delete" }, .{ .button_variant = .destructive });
    try renderButton(&scene, ui.Rect.init(0, 44, 120, height), .{ .id = 2, .label = "Docs" }, .{ .button_variant = .link });

    try std.testing.expect(hasRectColor(scene.written(), button_danger));
    try std.testing.expect(!hasRectBounds(scene.written(), ui.Rect.init(0, 44, 120, height)));
    try std.testing.expect(hasTextColor(scene.written(), ui.Color.accent));
}

fn hasRectColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

fn hasRectBounds(commands: []const ui.Command, bounds: ui.Rect) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.bounds, bounds)) return true,
        else => {},
    };
    return false;
}

fn hasTextColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .text => |text| if (std.meta.eql(text.color, color)) return true,
        else => {},
    };
    return false;
}
