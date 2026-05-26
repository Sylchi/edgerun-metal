const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
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
const renderControlFrame = primitives.renderControlFrame;
const renderControlStateOverlay = primitives.renderControlStateOverlay;
const renderControlText = primitives.renderControlText;

pub const Field = struct {
    id: u32,
    label: []const u8,
    placeholder: []const u8,

    pub fn node(self: Field) ui.Node {
        return ui.fieldNode(self.id, self.label, self.placeholder);
    }

    pub fn render(self: Field, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushText(labelBounds(bounds), self.label, options.style.text);
        try renderInput(scene, inputBoundsFor(bounds, options), self.placeholder, inputOptions(options));
        if (options.validation) |validation| {
            const color = switch (validation.state) {
                .helper => options.style.muted,
                .invalid => common.state_invalid_border,
            };
            try scene.pushText(validationBounds(bounds), validation.message, color);
        }
    }

    pub fn collectInteractions(self: Field, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(inputBounds(bounds), .input, self.id);
    }

    pub fn measure(self: Field, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        const preferred = if (options.validation == null) preferred_field else preferred_field_with_validation;
        return measureFixed(preferred, constraints);
    }

    pub fn toObject(self: Field, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.field, self.id, self.label, self.placeholder, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Field, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .field, self.id, self.label, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Field {
        return switch (try component_codec.singleNode(view)) {
            .field => |field| .{ .id = field.id, .label = field.label, .placeholder = field.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

fn renderInput(scene: *ui.Scene, bounds: ui.Rect, placeholder: []const u8, options: RenderOptions) ui.RenderError!void {
    try renderControlFrame(scene, bounds, options.style.panel, options.style.border, primitives.control_radius);
    try renderControlStateOverlay(scene, bounds, options, primitives.control_radius);
    try renderControlText(scene, bounds, primitives.control_text_padding, primitives.control_label_height, placeholder, options.style.muted, .start);
}

fn labelBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, field_label_h);
}

fn inputBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + field_label_h + field_gap, bounds.w, @max(primitives.min_extent, bounds.h - field_label_h - field_gap));
}

fn validationBounds(bounds: ui.Rect) ui.Rect {
    const input = inputBoundsWithValidation(bounds);
    return ui.Rect.init(bounds.x, input.y + input.h + field_validation_gap, bounds.w, field_validation_h);
}

fn inputOptions(options: RenderOptions) RenderOptions {
    var next = options;
    if (options.validation) |validation| {
        next.control.invalid = next.control.invalid or validation.state == .invalid;
    }
    return next;
}

fn inputBoundsFor(bounds: ui.Rect, options: RenderOptions) ui.Rect {
    return if (options.validation == null) inputBounds(bounds) else inputBoundsWithValidation(bounds);
}

fn inputBoundsWithValidation(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + field_label_h + field_gap, bounds.w, @max(primitives.min_extent, @min(field_input_h, bounds.h - field_label_h - field_gap)));
}

const preferred_field = ui.Size{ .w = 220.0, .h = 56.0 };
const preferred_field_with_validation = ui.Size{ .w = 220.0, .h = 74.0 };
const field_label_h: f32 = 14.0;
const field_gap: f32 = 6.0;
const field_input_h: f32 = 36.0;
const field_validation_gap: f32 = 6.0;
const field_validation_h: f32 = 12.0;

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
