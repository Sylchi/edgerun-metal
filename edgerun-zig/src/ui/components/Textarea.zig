const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Textarea = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Textarea) ui.Node {
        return ui.textareaNode(self.id, self.placeholder);
    }

    pub fn render(self: Textarea, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, control_radius, 0.0);
        if (contentInset(bounds, textarea_padding)) |text_bounds| {
            try scene.pushWrappedText(text_bounds, self.placeholder, options.style.muted, .{
                .line_height = control_label_height,
                .average_char_width = control_average_char_width,
                .max_lines = textarea_max_lines,
            });
        }
    }

    pub fn collectInteractions(self: Textarea, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .textarea, self.id);
    }

    pub fn measure(self: Textarea, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_textarea, constraints);
    }

    pub fn toObject(self: Textarea, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.textarea, self.id, self.placeholder, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Textarea, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .textarea, self.id, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Textarea {
        return switch (try component_codec.singleNode(view)) {
            .textarea => |textarea| .{ .id = textarea.id, .placeholder = textarea.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

fn measureFixed(preferred: ui.Size, constraints: layout.Constraints) layout.Measurement {
    const resolved_preferred = constrainPreferredSize(preferred, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(preferred.w, resolved_preferred.w), .h = @min(preferred.h, resolved_preferred.h) },
        resolved_preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

fn constrainPreferredSize(preferred: ui.Size, constraints: layout.Constraints) ui.Size {
    return .{
        .w = constraints.width.limit(preferred.w),
        .h = constraints.height.limit(preferred.h),
    };
}

const measure_max_width: f32 = 4096.0;
const control_radius: f32 = tokens.Component.control_radius;
const control_label_height: f32 = tokens.Component.control_label_height;
const control_average_char_width: f32 = tokens.Component.control_average_char_width;
const textarea_padding: f32 = 12.0;
const textarea_max_lines: usize = 4;
pub const preferred_textarea = ui.Size{ .w = 220.0, .h = 88.0 };

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
