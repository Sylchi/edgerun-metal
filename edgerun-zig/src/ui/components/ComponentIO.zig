const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const codec = @import("../../ui_codec.zig");
const object = @import("../../object.zig");

pub fn writeObject(comptime Component: type, component: Component, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
    if (!writeRecord(Component, &writer, 0, component)) return null;
    return writer.objectNode(object_out, req, epoch);
}

pub fn writeRecord(comptime Component: type, writer: *codec.Writer, index: usize, component: Component) bool {
    return switch (component) {
        .text => |text_component| text_component.writeRecord(writer, index),
        .card => |card| card.writeRecord(writer, index),
        .badge => |badge| badge.writeRecord(writer, index),
        .avatar => |avatar| avatar.writeRecord(writer, index),
        .kbd => |kbd| kbd.writeRecord(writer, index),
        .separator => |separator| separator.writeRecord(writer, index),
        .button => |button| button.writeRecord(writer, index),
        .input => |input| input.writeRecord(writer, index),
        .textarea => |textarea| textarea.writeRecord(writer, index),
        .select => |select| select.writeRecord(writer, index),
        .checkbox => |checkbox| checkbox.writeRecord(writer, index),
        .switch_control => |switch_control| switch_control.writeRecord(writer, index),
        .progress => |progress| progress.writeRecord(writer, index),
        .slider => |slider| slider.writeRecord(writer, index),
        .row_item => |row| row.writeRecord(writer, index),
    };
}
