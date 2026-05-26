const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const codec = @import("../../ui_codec.zig");
const component_codec = @import("Codec.zig");
const object = @import("../../object.zig");

pub fn requirements() object.Requirements {
    return component_codec.requirements();
}

pub fn validateView(view: object.View) common.Error!void {
    return component_codec.validateView(view);
}

pub fn validateTreeView(view: object.View) common.Error!void {
    return component_codec.validateTreeView(view);
}

pub fn writeObject(comptime Component: type, component: Component, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
    var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
    if (!writeRecord(Component, &writer, 0, component)) return null;
    return writer.objectNode(object_out, requirements(), epoch);
}

pub fn writeRecord(comptime Component: type, writer: *codec.Writer, index: usize, component: Component) bool {
    return switch (component) {
        inline else => |payload| payload.writeRecord(writer, index),
    };
}
