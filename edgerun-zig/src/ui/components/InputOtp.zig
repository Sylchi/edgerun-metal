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

pub const InputOtp = struct {
    id: u32,
    value: []const u8 = "",

    pub fn node(self: InputOtp) ui.Node {
        return ui.inputOtpNode(self.id, self.value);
    }

    pub fn render(self: InputOtp, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderInputOtp(scene, bounds, self.value, options);
    }

    pub fn collectInteractions(self: InputOtp, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..component_render.input_otp_slot_count) |index| {
            try collector.addHit(component_render.inputOtpSlotBounds(bounds, index), .input, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: InputOtp, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_input_otp, constraints);
    }

    pub fn toObject(self: InputOtp, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.input_otp, self.id, self.value, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: InputOtp, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .input_otp, self.id, self.value);
    }

    pub fn fromView(view: object.View) Error!InputOtp {
        return switch (try component_codec.singleNode(view)) {
            .input_otp => |otp| .{ .id = otp.id, .value = otp.value },
            else => error.UnsupportedComponent,
        };
    }
};

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
    var regions: [component_render.input_otp_slot_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try otp.render(&scene, ui.Rect.init(0, 0, 200, 36), .{});
    try otp.collectInteractions(&collector, ui.Rect.init(0, 0, 200, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "1"));
    try std.testing.expect(component_test.hasText(scene.written(), "2"));
    try std.testing.expect(component_test.hasText(scene.written(), "3"));
    try std.testing.expectEqual(@as(usize, component_render.input_otp_slot_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 445), collector.written()[5].id);
}
