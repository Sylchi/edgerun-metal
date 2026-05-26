const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const text_component = @import("Text.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = primitives.constrainPreferredSize;
const renderControlFrame = primitives.renderControlFrame;
const renderControlStateOverlay = primitives.renderControlStateOverlay;

pub const Field = struct {
    id: u32,
    label: []const u8,
    placeholder: []const u8,

    pub fn node(self: Field) ui.Node {
        return ui.fieldNode(self.id, self.label, self.placeholder);
    }

    pub fn accessibility(self: Field) common.Accessibility {
        return .{ .role = .input, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: Field, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try text_component.Text.renderWrapped(scene, labelBounds(bounds, self.label), self.label, options.style.text, primitives.textWrap(self.label, field_label_h, field_label_max_lines));
        try renderInput(scene, inputBoundsFor(bounds, self.label, options), self.placeholder, inputOptions(options));
        if (options.validation) |validation| {
            const color = switch (validation.state) {
                .helper => options.style.muted,
                .invalid => common.state_invalid_border,
            };
            try text_component.Text.renderWrapped(scene, validationBounds(bounds, self.label, validation.message), validation.message, color, primitives.textWrap(validation.message, field_validation_line_h, field_validation_max_lines));
        }
    }

    pub fn collectInteractions(self: Field, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(inputBounds(bounds), .input, self.id);
    }

    pub fn measure(self: Field, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        const label = layout.measureText(self.label, constraints, primitives.textMetrics(self.label, field_label_h, field_label_max_lines));
        const input = measureInput(self.placeholder, constraints);
        const validation = if (options.validation) |validation|
            layout.measureText(validation.message, constraints, primitives.textMetrics(validation.message, field_validation_line_h, field_validation_max_lines))
        else
            layout.Measurement.fixed(.{ .w = 0.0, .h = 0.0 });
        const validation_gap: f32 = if (options.validation == null) 0.0 else field_validation_gap;
        const preferred = constrainPreferredSize(.{
            .w = @max(field_min_width, @max(label.preferred.w, @max(input.preferred.w, validation.preferred.w))),
            .h = label.preferred.h + field_gap + input.preferred.h + validation_gap + validation.preferred.h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(field_min_width, preferred.w), .h = @min(field_min_height, preferred.h) },
            preferred,
            .{ .w = primitives.measure_max_width, .h = @max(preferred.h, preferred_field_with_validation.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Field, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.field, self.id, self.label, self.placeholder, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Field, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .field, self.id, self.label, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Field {
        const field = try component_codec.nodeView(view, .field);
        return fromNode(field);
    }

    pub fn fromNode(field: @FieldType(ui.Node, "field")) Error!Field {
        return .{ .id = field.id, .label = field.label, .placeholder = field.placeholder };
    }
};

fn renderInput(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, primitives.control_radius);
    try renderControlStateOverlay(scene, bounds, options, primitives.control_radius);
    if (primitives.contentInset(bounds, primitives.control_text_padding)) |inner| {
        const text_h = @min(inner.h, primitives.measuredTextHeight(placeholder, inner.w, primitives.control_label_height, field_placeholder_max_lines));
        try text_component.Text.renderWrapped(scene, inner.withHeightCentered(text_h), placeholder, options.style.muted, primitives.textWrap(placeholder, primitives.control_label_height, field_placeholder_max_lines));
    }
}

fn measureInput(placeholder: []const u8, constraints: layout.Constraints) layout.Measurement {
    const inner = constraints.inner(.{ .left = primitives.control_text_padding, .right = primitives.control_text_padding });
    const text = layout.measureText(placeholder, inner, primitives.textMetrics(placeholder, primitives.control_label_height, field_placeholder_max_lines));
    const preferred = constrainPreferredSize(.{
        .w = text.preferred.w + primitives.control_text_padding * 2.0,
        .h = @max(field_input_h, text.preferred.h),
    }, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(field_min_width, preferred.w), .h = @min(field_input_h, preferred.h) },
        preferred,
        .{ .w = primitives.measure_max_width, .h = @max(preferred.h, field_input_h) },
    ).applyExact(constraints);
}

fn labelBounds(bounds: ui.Rect, label: []const u8) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, labelHeight(bounds, label));
}

fn inputBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + field_label_h + field_gap, bounds.w, @max(primitives.min_extent, bounds.h - field_label_h - field_gap));
}

fn validationBounds(bounds: ui.Rect, label: []const u8, message: []const u8) ui.Rect {
    const input = inputBoundsWithValidation(bounds, label);
    const y = input.y + input.h + field_validation_gap;
    const measured_h = primitives.measuredTextHeight(message, bounds.w, field_validation_line_h, field_validation_max_lines);
    return ui.Rect.init(bounds.x, y, bounds.w, @min(measured_h, @max(primitives.min_extent, bounds.y + bounds.h - y)));
}

fn inputOptions(options: RenderOptions) RenderOptions {
    var next = options;
    if (options.validation) |validation| {
        next.control.invalid = next.control.invalid or validation.state == .invalid;
    }
    return next;
}

fn inputBoundsFor(bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.Rect {
    return if (options.validation == null) inputBoundsForLabel(bounds, label) else inputBoundsWithValidation(bounds, label);
}

fn inputBoundsForLabel(bounds: ui.Rect, label: []const u8) ui.Rect {
    const label_h = labelHeight(bounds, label);
    return ui.Rect.init(bounds.x, bounds.y + label_h + field_gap, bounds.w, @max(primitives.min_extent, bounds.h - label_h - field_gap));
}

fn inputBoundsWithValidation(bounds: ui.Rect, label: []const u8) ui.Rect {
    const label_h = labelHeight(bounds, label);
    return ui.Rect.init(bounds.x, bounds.y + label_h + field_gap, bounds.w, @max(primitives.min_extent, @min(field_input_h, bounds.h - label_h - field_gap)));
}

fn labelHeight(bounds: ui.Rect, label: []const u8) f32 {
    return @min(bounds.h, primitives.measuredTextHeight(label, bounds.w, field_label_h, field_label_max_lines));
}

const preferred_field = ui.Size{ .w = 220.0, .h = 56.0 };
const preferred_field_with_validation = ui.Size{ .w = 220.0, .h = 74.0 };
const field_label_h: f32 = 14.0;
const field_label_max_lines: usize = 2;
const field_gap: f32 = 6.0;
const field_input_h: f32 = 36.0;
const field_placeholder_max_lines: usize = 2;
const field_validation_gap: f32 = 6.0;
const field_validation_line_h: f32 = 12.0;
const field_validation_max_lines: usize = 2;
const field_min_width: f32 = 120.0;
const field_min_height: f32 = 48.0;

test "field component serializes to canonical object and deserializes" {
    const field = Field{ .id = 330, .label = "Email", .placeholder = "m@example.com" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = field.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Field.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(field.id, decoded.id);
    try std.testing.expectEqualStrings(field.label, decoded.label);
    try std.testing.expectEqualStrings(field.placeholder, decoded.placeholder);
}

test "field component renders label input and hit region" {
    const field = Field{ .id = 330, .label = "Email", .placeholder = "m@example.com" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try field.render(&scene, ui.Rect.init(0, 0, 220, 56), .{});
    try field.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 56));

    try std.testing.expect(component_test.hasText(scene.written(), "Email"));
    try std.testing.expect(component_test.hasText(scene.written(), "m@example.com"));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(@as(u32, 330), collector.written()[0].id);
}

test "field component renders helper and invalid validation text" {
    const field = Field{ .id = 330, .label = "Email", .placeholder = "m@example.com" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try field.render(&scene, ui.Rect.init(0, 0, 220, 74), .{
        .validation = .{ .state = .invalid, .message = "Use a work email" },
    });

    const message = component_test.textCommand(scene.written(), "Use a work email").?;
    try std.testing.expectEqual(common.state_invalid_border, message.text.color);
    try std.testing.expect(component_test.hasRectColor(scene.written(), common.state_invalid_border));
}

test "field component measurement reserves helper text height" {
    const field = Field{ .id = 330, .label = "Email", .placeholder = "m@example.com" };
    const plain = field.measure(.{}, .{});
    const helper = field.measure(.{}, .{
        .validation = .{ .state = .helper, .message = "Visible to your team" },
    });

    try std.testing.expectEqual(preferred_field.h, plain.preferred.h);
    try std.testing.expectEqual(preferred_field_with_validation.h, helper.preferred.h);
}

test "field component measurement wraps long visible text under narrow constraints" {
    const field = Field{ .id = 330, .label = "Work identity email address", .placeholder = "runtime.identity@example.com" };
    const narrow = layout.Constraints{ .width = .{ .at_most = field_min_width }, .text_wrap = .wrap };
    const plain = field.measure(narrow, .{});
    const helper = field.measure(narrow, .{
        .validation = .{ .state = .helper, .message = "Visible to the signed runtime authority." },
    });

    try std.testing.expect(plain.preferred.w <= field_min_width);
    try std.testing.expect(plain.preferred.h > preferred_field.h);
    try std.testing.expect(helper.preferred.h > plain.preferred.h);
}
