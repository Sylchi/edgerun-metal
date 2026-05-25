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
        .text => |text_component| text_component.writeRecord(writer, index),
        .accordion => |accordion| accordion.writeRecord(writer, index),
        .alert => |alert| alert.writeRecord(writer, index),
        .alert_dialog => |dialog| dialog.writeRecord(writer, index),
        .aspect_ratio => |aspect_ratio| aspect_ratio.writeRecord(writer, index),
        .calendar => |calendar| calendar.writeRecord(writer, index),
        .carousel => |carousel| carousel.writeRecord(writer, index),
        .chart => |chart| chart.writeRecord(writer, index),
        .combobox => |combobox| combobox.writeRecord(writer, index),
        .card => |card| card.writeRecord(writer, index),
        .empty => |empty| empty.writeRecord(writer, index),
        .badge => |badge| badge.writeRecord(writer, index),
        .avatar => |avatar| avatar.writeRecord(writer, index),
        .kbd => |kbd| kbd.writeRecord(writer, index),
        .label => |label| label.writeRecord(writer, index),
        .separator => |separator| separator.writeRecord(writer, index),
        .scroll_area => |scroll_area| scroll_area.writeRecord(writer, index),
        .skeleton => |skeleton| skeleton.writeRecord(writer, index),
        .spinner => |spinner| spinner.writeRecord(writer, index),
        .breadcrumb => |breadcrumb| breadcrumb.writeRecord(writer, index),
        .menubar => |menubar| menubar.writeRecord(writer, index),
        .navigation_menu => |menu| menu.writeRecord(writer, index),
        .command => |command| command.writeRecord(writer, index),
        .context_menu => |menu| menu.writeRecord(writer, index),
        .dialog => |dialog| dialog.writeRecord(writer, index),
        .direction => |direction| direction.writeRecord(writer, index),
        .drawer => |drawer| drawer.writeRecord(writer, index),
        .dropdown_menu => |menu| menu.writeRecord(writer, index),
        .field => |field| field.writeRecord(writer, index),
        .hover_card => |hover_card| hover_card.writeRecord(writer, index),
        .input_otp => |otp| otp.writeRecord(writer, index),
        .button => |button| button.writeRecord(writer, index),
        .button_group => |group| group.writeRecord(writer, index),
        .toggle_group => |group| group.writeRecord(writer, index),
        .toggle => |toggle| toggle.writeRecord(writer, index),
        .input => |input| input.writeRecord(writer, index),
        .input_group => |input_group| input_group.writeRecord(writer, index),
        .textarea => |textarea| textarea.writeRecord(writer, index),
        .select => |select| select.writeRecord(writer, index),
        .checkbox => |checkbox| checkbox.writeRecord(writer, index),
        .radio_group => |radio| radio.writeRecord(writer, index),
        .switch_control => |switch_control| switch_control.writeRecord(writer, index),
        .pagination => |pagination| pagination.writeRecord(writer, index),
        .popover => |popover| popover.writeRecord(writer, index),
        .resizable => |resizable| resizable.writeRecord(writer, index),
        .sheet => |sheet| sheet.writeRecord(writer, index),
        .sidebar => |sidebar| sidebar.writeRecord(writer, index),
        .progress => |progress| progress.writeRecord(writer, index),
        .slider => |slider| slider.writeRecord(writer, index),
        .tabs => |tabs| tabs.writeRecord(writer, index),
        .table => |table| table.writeRecord(writer, index),
        .tooltip => |tooltip| tooltip.writeRecord(writer, index),
        .toast => |toast| toast.writeRecord(writer, index),
        .row_item => |row| row.writeRecord(writer, index),
    };
}
