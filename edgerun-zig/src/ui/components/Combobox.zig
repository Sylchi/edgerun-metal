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
const contentInset = primitives.contentInset;
const measureFixed = primitives.measureFixed;
const renderControlFrame = primitives.renderControlFrame;
const renderControlText = primitives.renderControlText;

pub const Combobox = struct {
    id: u32,
    placeholder: []const u8,
    selected: []const u8,

    pub fn node(self: Combobox) ui.Node {
        return ui.comboboxNode(self.id, self.placeholder, self.selected);
    }

    pub fn render(self: Combobox, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const input = inputBounds(bounds);
        try renderControlFrame(scene, input, options.style.panel, options.style.border, primitives.control_radius);
        if (contentInset(input, primitives.control_text_padding)) |input_content| {
            const text_bounds = ui.Rect.init(input_content.x, input_content.y, @max(primitives.min_extent, input_content.w - combobox_icon_space), input_content.h);
            try scene.pushAlignedText(text_bounds.withHeightCentered(primitives.control_label_height), self.placeholder, options.style.muted, .start);
            try icon_component.renderGlyph(scene, ui.Rect.init(input_content.x + input_content.w - combobox_icon_size, input_content.y + (input_content.h - combobox_icon_size) * 0.5, combobox_icon_size, combobox_icon_size), .chevron_right, options.style.muted);
        }

        const popup = popupBounds(bounds);
        try scene.pushRect(popup, options.style.panel, .fill, combobox_popup_radius, 0.0);
        try scene.pushRect(popup, options.style.border, .border, combobox_popup_radius, 0.0);
        try renderOption(scene, optionBounds(bounds), self.selected, true, options);
    }

    pub fn collectInteractions(self: Combobox, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(inputBounds(bounds), .input, self.id);
        try collector.addHit(optionBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: Combobox, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_combobox, constraints);
    }

    pub fn toObject(self: Combobox, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.combobox, self.id, self.placeholder, self.selected, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Combobox, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .combobox, self.id, self.placeholder, self.selected);
    }

    pub fn fromView(view: object.View) Error!Combobox {
        const combobox = try component_codec.nodeView(view, .combobox);
        return fromNode(combobox);
    }

    pub fn fromNode(combobox: @FieldType(ui.Node, "combobox")) Error!Combobox {
        return .{ .id = combobox.id, .placeholder = combobox.placeholder, .selected = combobox.selected };
    }
};

fn inputBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(combobox_input_h, bounds.h));
}

fn optionBounds(bounds: ui.Rect) ui.Rect {
    const popup = popupBounds(bounds);
    return ui.Rect.init(popup.x + combobox_popup_padding, popup.y + combobox_popup_padding, @max(primitives.min_extent, popup.w - combobox_popup_padding * 2.0), @max(primitives.min_extent, popup.h - combobox_popup_padding * 2.0));
}

fn popupBounds(bounds: ui.Rect) ui.Rect {
    const y = bounds.y + combobox_input_h + combobox_popup_gap;
    return ui.Rect.init(bounds.x, y, bounds.w, @max(primitives.min_extent, bounds.y + bounds.h - y));
}

fn renderOption(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, primitives.control_radius, 0.0);
    try renderControlText(scene, ui.Rect.init(bounds.x, bounds.y, @max(primitives.min_extent, bounds.w - combobox_option_indicator_w), bounds.h), combobox_option_padding, primitives.control_label_height, label, options.style.text, .start);
    if (selected) {
        try icon_component.renderGlyph(scene, ui.Rect.init(bounds.x + bounds.w - combobox_icon_size - combobox_option_padding, bounds.y + (bounds.h - combobox_icon_size) * 0.5, combobox_icon_size, combobox_icon_size), .check, options.style.accent);
    }
}

const preferred_combobox = ui.Size{ .w = 240.0, .h = 82.0 };
const combobox_input_h: f32 = 36.0;
const combobox_popup_gap: f32 = 6.0;
const combobox_popup_radius: f32 = 8.0;
const combobox_popup_padding: f32 = 4.0;
const combobox_icon_size: f32 = 14.0;
const combobox_icon_space: f32 = 22.0;
const combobox_option_padding: f32 = 8.0;
const combobox_option_indicator_w: f32 = 28.0;

test "combobox component serializes to canonical object and deserializes" {
    const combobox = Combobox{ .id = 991, .placeholder = "Search framework", .selected = "React" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = combobox.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Combobox.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(combobox.id, decoded.id);
    try std.testing.expectEqualStrings(combobox.placeholder, decoded.placeholder);
    try std.testing.expectEqualStrings(combobox.selected, decoded.selected);
}

test "combobox component renders input option and hit regions" {
    const combobox = Combobox{ .id = 991, .placeholder = "Search framework", .selected = "React" };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try combobox.render(&scene, ui.Rect.init(0, 0, 240, 82), .{});
    try combobox.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 82));

    try std.testing.expect(component_test.hasText(scene.written(), "Search framework"));
    try std.testing.expect(component_test.hasText(scene.written(), "React"));
    try std.testing.expect(component_test.hasIcon(scene.written(), @import("../../icon.zig").id(.check)));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.input, collector.written()[0].kind);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[1].kind);
}
