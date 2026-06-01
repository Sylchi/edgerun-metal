const std = @import("er_std");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const contentInset = component_primitives.contentInset;

pub const InputOtp = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    value: []const u8 = "",

    const serialization = component_codec.OneStringComponent(InputOtp, "input_otp", "value");

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
                    try text_component.Text.renderAligned(scene, text_bounds.withHeightCentered(component_primitives.control_label_height), self.value[index .. index + 1], options.style.text, .center);
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
        const preferred = component_primitives.constrainPreferredSize(inputOtpIntrinsicSize(), constraints);
        return layout.Measurement.flexible(preferred, preferred, preferred).applyExact(constraints);
    }

    pub const toObject = serialization.toObject;
    pub const writeRecord = serialization.writeRecord;
    pub const fromView = serialization.fromView;

    pub fn fromNode(input_otp: @FieldType(ui.Node, "input_otp")) Error!InputOtp {
        return .{ .id = input_otp.id, .value = input_otp.value };
    }
};

fn slotBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const x = bounds.x + @as(f32, @floatFromInt(index)) * (input_otp_slot_size + input_otp_slot_gap);
    return ui.Rect.init(x, bounds.y, input_otp_slot_size, @min(bounds.h, input_otp_slot_size));
}

fn inputOtpIntrinsicSize() ui.Size {
    const slot_count: f32 = @floatFromInt(input_otp_slot_count);
    const gap_count: f32 = @floatFromInt(input_otp_slot_count - 1);
    return .{
        .w = input_otp_slot_size * slot_count + input_otp_slot_gap * gap_count,
        .h = input_otp_slot_size,
    };
}

pub const input_otp_slot_count: usize = 6;
const input_otp_slot_size: f32 = 36.0;
const input_otp_slot_gap: f32 = 0.0;
const input_otp_text_padding: f32 = 8.0;

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

test "input otp measurement derives size from slot geometry" {
    const otp = InputOtp{ .id = 440, .value = "123456" };

    const measured = otp.measure(.{}, .{});

    try std.testing.expectEqual(inputOtpIntrinsicSize().w, measured.preferred.w);
    try std.testing.expectEqual(inputOtpIntrinsicSize().h, measured.preferred.h);
}
