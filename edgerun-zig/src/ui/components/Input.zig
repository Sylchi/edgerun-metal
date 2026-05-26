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
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;
const renderControlFrame = primitives.renderControlFrame;
const renderControlStateOverlay = primitives.renderControlStateOverlay;
const renderControlText = primitives.renderControlText;
const Icon = icon_component.Icon;

pub const Input = struct {
    id: u32,
    placeholder: []const u8,
    leading_icon: ?Icon = null,

    pub fn node(self: Input) ui.Node {
        return ui.inputDetailNode(self.id, self.placeholder, optionalIconTag(self.leading_icon));
    }

    pub fn accessibility(self: Input) common.Accessibility {
        return .{ .role = .input, .label = self.placeholder, .control_id = self.id };
    }

    pub fn render(self: Input, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const padding = inputPadding(options.control_size);
        try renderControlFrame(scene, bounds, options.style.panel, options.style.border, primitives.control_radius);
        try renderControlStateOverlay(scene, bounds, options, primitives.control_radius);
        const text_bounds = if (self.leading_icon) |slot| with_icon: {
            try icon_component.renderGlyph(scene, ui.Rect.init(bounds.x + padding, bounds.y + (bounds.h - input_icon_size) * 0.5, input_icon_size, input_icon_size), slot.value, options.style.muted);
            break :with_icon ui.Rect.init(bounds.x + padding + input_icon_size + input_icon_gap, bounds.y, @max(primitives.min_extent, bounds.w - padding * 2.0 - input_icon_size - input_icon_gap), bounds.h);
        } else bounds;
        try renderControlText(scene, text_bounds, padding, primitives.control_label_height, self.placeholder, options.style.muted, .start);
    }

    pub fn collectInteractions(self: Input, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .input, self.id);
    }

    pub fn measure(self: Input, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        return measureFixed(preferredSize(options.control_size), constraints);
    }

    pub fn toObject(self: Input, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Input, writer: *component_codec.Writer, index: usize) bool {
        const placeholder_ref = writer.string(self.placeholder) orelse return false;
        return writer.record(index, .input, self.id, placeholder_ref, .{ .offset = optionalIconTag(self.leading_icon), .len = 0 });
    }

    pub fn fromView(view: object.View) Error!Input {
        const input = try component_codec.nodeView(view, .input);
        return fromNode(input);
    }

    pub fn fromNode(input: @FieldType(ui.Node, "input")) Error!Input {
        return .{ .id = input.id, .placeholder = input.placeholder, .leading_icon = try iconFromTag(input.leading_icon) };
    }
};

fn optionalIconTag(slot: ?Icon) u16 {
    return if (slot) |value| common.optionalIconTag(value.value) else 0;
}

fn iconFromTag(tag: u16) Error!?Icon {
    return if (try common.optionalIconFromTag(tag)) |value| Icon.named(value) else null;
}

pub fn preferredSize(size: common.ControlSize) ui.Size {
    return switch (size) {
        .small => .{ .w = 180.0, .h = 32.0 },
        .default => preferred_input,
        .large => .{ .w = 260.0, .h = 48.0 },
    };
}

fn inputPadding(size: common.ControlSize) f32 {
    return switch (size) {
        .small => 10.0,
        .default => primitives.control_text_padding,
        .large => 16.0,
    };
}

const preferred_input = ui.Size{ .w = 220.0, .h = 40.0 };
const input_icon_size: f32 = 16.0;
const input_icon_gap: f32 = 8.0;

test "input component serializes to canonical object and deserializes" {
    const input = Input{ .id = 10, .placeholder = "Search objects", .leading_icon = Icon.named(.search) };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = input.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Input.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(input.id, decoded.id);
    try std.testing.expectEqualStrings(input.placeholder, decoded.placeholder);
    try std.testing.expectEqual(icon.Icon.search, decoded.leading_icon.?.value);
}

test "input component renders placeholder through shared control text" {
    const input = Input{ .id = 10, .placeholder = "Search objects" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try input.render(&scene, ui.Rect.init(4, 8, 220, 40), .{});

    const placeholder = component_test.textCommand(scene.written(), "Search objects").?;
    try std.testing.expectEqual(ui.Color.muted, placeholder.text.color);
    try std.testing.expectEqual(@as(f32, 16.0), placeholder.text.origin.x);
    try std.testing.expectEqual(@as(f32, 20.0), placeholder.text.origin.y);
}

test "input component renders leading icon as component state" {
    const input = Input{ .id = 10, .placeholder = "Search objects", .leading_icon = Icon.named(.search) };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try input.render(&scene, ui.Rect.init(4, 8, 220, 40), .{});

    const placeholder = component_test.textCommand(scene.written(), "Search objects").?;
    try std.testing.expect(component_test.hasIcon(scene.written(), icon.id(.search)));
    try std.testing.expectEqual(@as(f32, 52.0), placeholder.text.origin.x);
}

test "input component measurement respects at-most constraints" {
    const input = Input{ .id = 10, .placeholder = "Search objects" };
    const measured = input.measure(.{ .width = .{ .at_most = 96.0 }, .height = .{ .at_most = 32.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 96.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 32.0), measured.preferred.h);
}

test "input component size variants adjust preferred height and padding" {
    const input = Input{ .id = 10, .placeholder = "Search objects" };
    const small = input.measure(.{}, .{ .control_size = .small });
    const regular = input.measure(.{}, .{});
    const large = input.measure(.{}, .{ .control_size = .large });
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try input.render(&scene, ui.Rect.init(4, 8, 220, 48), .{ .control_size = .large });

    const placeholder = component_test.textCommand(scene.written(), "Search objects").?;
    try std.testing.expect(small.preferred.h < regular.preferred.h);
    try std.testing.expect(large.preferred.h > regular.preferred.h);
    try std.testing.expectEqual(@as(f32, 20.0), placeholder.text.origin.x);
}
