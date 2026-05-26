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
const contentInset = component_primitives.contentInset;
const measureFixed = component_primitives.measureFixed;

pub const InputOtp = struct {
    id: u32,
    value: []const u8 = "",

    pub fn node(self: InputOtp) ui.Node {
        return ui.inputOtpNode(self.id, self.value);
    }

    pub fn render(self: InputOtp, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        for (0..input_otp_slot_count) |index| {
            const slot = slotBounds(bounds, index);
            try scene.pushRect(slot, options.style.panel, .fill, component_primitives.control_radius, 0.0);
            try scene.pushRect(slot, options.style.border, .border, component_primitives.control_radius, 0.0);
            if (index < self.value.len) {
                if (contentInset(slot, input_otp_text_padding)) |text_bounds| {
                    try scene.pushAlignedText(text_bounds.withHeightCentered(component_primitives.control_label_height), self.value[index .. index + 1], options.style.text, .center);
                }
            }
        }
    }

    pub fn collectInteractions(self: InputOtp, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..input_otp_slot_count) |index| {
            try collector.addHit(slotBounds(bounds, index), .input, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: InputOtp, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_input_otp, constraints);
    }

    pub fn toObject(self: InputOtp, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.input_otp, self.id, self.value, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: InputOtp, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .input_otp, self.id, self.value);
    }

    pub fn fromView(view: object.View) Error!InputOtp {
        const input_otp = try component_codec.nodeView(view, .input_otp);
        return fromNode(input_otp);
    }

    pub fn fromNode(input_otp: @FieldType(ui.Node, "input_otp")) Error!InputOtp {
        return .{ .id = input_otp.id, .value = input_otp.value };
    }
};

fn slotBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const x = bounds.x + @as(f32, @floatFromInt(index)) * (input_otp_slot_size + input_otp_slot_gap);
    return ui.Rect.init(x, bounds.y, input_otp_slot_size, @min(bounds.h, input_otp_slot_size));
}

pub const input_otp_slot_count: usize = 6;
const input_otp_slot_size: f32 = 36.0;
const input_otp_slot_gap: f32 = 0.0;
const input_otp_text_padding: f32 = 8.0;
pub const preferred_input_otp = ui.Size{ .w = 200.0, .h = 36.0 };

test "input otp component serializes to canonical object and deserializes" {
    const otp = InputOtp{ .id = 440, .value = "123456" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = otp.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try InputOtp.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(otp.id, decoded.id);
    try std.testing.expectEqualStrings(otp.value, decoded.value);
}

test "input otp component renders slots and hit regions" {
    const otp = InputOtp{ .id = 440, .value = "123" };
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [input_otp_slot_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try otp.render(&scene, ui.Rect.init(0, 0, 200, 36), .{});
    try otp.collectInteractions(&collector, ui.Rect.init(0, 0, 200, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "1"));
    try std.testing.expect(component_test.hasText(scene.written(), "2"));
    try std.testing.expect(component_test.hasText(scene.written(), "3"));
    try std.testing.expectEqual(@as(usize, input_otp_slot_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 445), collector.written()[5].id);
}
