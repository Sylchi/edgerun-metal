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
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;
const renderControlFrame = primitives.renderControlFrame;
const renderControlText = primitives.renderControlText;

pub const Command = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Command) ui.Node {
        return ui.commandNode(self.id, self.placeholder);
    }

    pub fn render(self: Command, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const input = inputBounds(bounds);
        try renderControlFrame(scene, input, options.style.panel, options.style.border, command_radius);
        try scene.pushIconQuad(.{ .bounds = ui.Rect.init(input.x + command_icon_x, input.y + (input.h - command_icon_size) * 0.5, command_icon_size, command_icon_size), .icon_id = icon.id(.search), .color = options.style.muted });
        const input_text = if (options.command_palette) |palette| if (palette.query.len == 0) self.placeholder else palette.query else self.placeholder;
        const input_color = if (options.command_palette) |palette| if (palette.query.len == 0) options.style.muted else options.style.text else options.style.muted;
        try scene.pushText(ui.Rect.init(input.x + command_text_x, input.y + (input.h - command_text_h) * 0.5, @max(primitives.min_extent, input.w - command_text_x - command_padding_x), command_text_h), input_text, input_color);

        if (options.command_palette) |palette| {
            const list = listBounds(bounds) orelse return;
            try scene.pushRect(list, options.style.panel, .fill, command_radius, 0.0);
            try scene.pushRect(list, options.style.border, .border, command_radius, 0.0);
            var item_index: usize = 0;
            var visible_index: usize = 0;
            while (item_index < palette.items.len and visible_index < visibleItemCapacity(bounds)) : (item_index += 1) {
                const item = palette.items[item_index];
                if (!itemMatches(palette.query, item)) continue;
                try renderItem(scene, itemBounds(bounds, visible_index).?, item, item_index == palette.selected_index, options);
                visible_index += 1;
            }
            if (visible_index == 0) {
                try scene.pushText(ui.Rect.init(list.x + command_list_padding, list.y + command_list_padding, @max(primitives.min_extent, list.w - command_list_padding * 2.0), command_empty_text_h), command_empty_label, options.style.muted);
            }
        }
    }

    pub fn collectInteractions(self: Command, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(inputBounds(bounds), .input, self.id);
        var index: usize = 0;
        while (index < visibleItemCapacity(bounds)) : (index += 1) {
            if (itemBounds(bounds, index)) |item_bounds| {
                try collector.addHit(item_bounds, .row_item, self.id + command_item_id_offset + @as(u32, @intCast(index)));
            }
        }
    }

    pub fn measure(self: Command, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        const preferred = if (options.command_palette == null) preferred_command else preferred_command_palette;
        return measureFixed(preferred, constraints);
    }

    pub fn toObject(self: Command, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.command, self.id, self.placeholder, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Command, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .command, self.id, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Command {
        return switch (try component_codec.singleNode(view)) {
            .command => |command| .{ .id = command.id, .placeholder = command.placeholder },
            else => error.UnsupportedComponent,
        };
    }
};

fn inputBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(bounds.h, command_input_h));
}

fn listBounds(bounds: ui.Rect) ?ui.Rect {
    if (bounds.h <= command_input_h + command_list_gap) return null;
    return ui.Rect.init(bounds.x, bounds.y + command_input_h + command_list_gap, bounds.w, @max(primitives.min_extent, bounds.h - command_input_h - command_list_gap));
}

fn itemBounds(bounds: ui.Rect, index: usize) ?ui.Rect {
    if (index >= command_max_visible_items) return null;
    const list = listBounds(bounds) orelse return null;
    const y = list.y + command_list_padding + @as(f32, @floatFromInt(index)) * command_item_pitch;
    if (y + command_item_h > list.y + list.h - command_list_padding) return null;
    return ui.Rect.init(list.x + command_list_padding, y, @max(primitives.min_extent, list.w - command_list_padding * 2.0), command_item_h);
}

fn renderItem(scene: *ui.Scene, bounds: ui.Rect, item: common.CommandItem, selected: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (selected) options.style.row else ui.Color.clear, .fill, command_radius, 0.0);
    const detail_w: f32 = if (item.shortcut.len == 0) 0.0 else command_item_detail_w;
    const label_bounds = ui.Rect.init(bounds.x, bounds.y, @max(primitives.min_extent, bounds.w - detail_w), bounds.h);
    try renderControlText(scene, label_bounds, command_item_padding_x, primitives.control_label_height, item.label, if (selected) options.style.text else options.style.muted, .start);
    if (item.shortcut.len != 0) {
        try renderControlText(scene, ui.Rect.init(bounds.x + bounds.w - detail_w, bounds.y, detail_w, bounds.h), command_item_padding_x, primitives.control_label_height, item.shortcut, options.style.muted, .end);
    }
}

fn visibleItemCapacity(bounds: ui.Rect) usize {
    const list = listBounds(bounds) orelse return 0;
    const available_h = @max(0.0, list.h - command_list_padding * 2.0);
    const raw_count: usize = @intFromFloat(@floor((available_h + command_item_pitch - command_item_h) / command_item_pitch));
    return @min(command_max_visible_items, raw_count);
}

fn itemMatches(query: []const u8, item: common.CommandItem) bool {
    if (query.len == 0) return true;
    return asciiContainsFold(item.label, query) or asciiContainsFold(item.detail, query) or asciiContainsFold(item.shortcut, query);
}

fn asciiContainsFold(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (asciiEqualFold(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

fn asciiEqualFold(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_char, right_char| {
        if (asciiLower(left_char) != asciiLower(right_char)) return false;
    }
    return true;
}

fn asciiLower(value: u8) u8 {
    return switch (value) {
        'A'...'Z' => value + ('a' - 'A'),
        else => value,
    };
}

const preferred_command = ui.Size{ .w = 220.0, .h = 36.0 };
const preferred_command_palette = ui.Size{ .w = 260.0, .h = 130.0 };
const command_radius: f32 = 8.0;
const command_input_h: f32 = 36.0;
const command_icon_x: f32 = 8.0;
const command_icon_size: f32 = 14.0;
const command_text_x: f32 = 28.0;
const command_padding_x: f32 = 8.0;
const command_text_h: f32 = 13.0;
const command_item_id_offset: u32 = 1;
const command_list_gap: f32 = 6.0;
const command_list_padding: f32 = 4.0;
const command_item_h: f32 = 24.0;
const command_item_pitch: f32 = 28.0;
const command_item_padding_x: f32 = 8.0;
const command_item_detail_w: f32 = 72.0;
const command_max_visible_items: usize = 3;
const command_empty_label = "No commands found";
const command_empty_text_h: f32 = 14.0;

test "command component serializes to canonical object and deserializes" {
    const command = Command{ .id = 880, .placeholder = "Type a command..." };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = command.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Command.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(command.id, decoded.id);
    try std.testing.expectEqualStrings(command.placeholder, decoded.placeholder);
}

test "command component renders search input and hit region" {
    const command = Command{ .id = 880, .placeholder = "Type a command..." };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try command.render(&scene, ui.Rect.init(0, 0, 220, 36), .{});
    try command.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Type a command..."));
    try std.testing.expect(component_test.hasIcon(scene.written(), @import("../../icon.zig").id(.search)));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.input, collector.written()[0].kind);
}

test "command component filters palette results and exposes row hits" {
    const command = Command{ .id = 880, .placeholder = "Type a command..." };
    const items = [_]common.CommandItem{
        .{ .label = "Open settings", .shortcut = "Ctrl+," },
        .{ .label = "Launch app", .shortcut = "Ctrl+L" },
        .{ .label = "Show receipts", .shortcut = "Ctrl+R" },
    };
    const options = RenderOptions{ .command_palette = .{
        .query = "launch",
        .items = &items,
        .selected_index = 1,
    } };
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    const bounds = ui.Rect.init(0, 0, 260, 130);

    try command.render(&scene, bounds, options);
    try command.collectInteractions(&collector, bounds);

    try std.testing.expect(component_test.hasText(scene.written(), "launch"));
    try std.testing.expect(component_test.hasText(scene.written(), "Launch app"));
    try std.testing.expect(component_test.hasText(scene.written(), "Ctrl+L"));
    try std.testing.expect(!component_test.hasText(scene.written(), "Open settings"));
    try std.testing.expectEqual(@as(usize, 4), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.input, collector.written()[0].kind);
    try std.testing.expectEqual(ui.HitKind.row_item, collector.written()[1].kind);
    try std.testing.expectEqual(command.id + command_item_id_offset, collector.written()[1].id);
}

test "command component renders deterministic empty result state" {
    const command = Command{ .id = 880, .placeholder = "Type a command..." };
    const items = [_]common.CommandItem{
        .{ .label = "Open settings" },
        .{ .label = "Launch app" },
    };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try command.render(&scene, ui.Rect.init(0, 0, 260, 130), .{ .command_palette = .{
        .query = "missing",
        .items = &items,
    } });

    try std.testing.expect(component_test.hasText(scene.written(), "No commands found"));
    try std.testing.expect(!component_test.hasText(scene.written(), "Open settings"));
}
