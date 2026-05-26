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

pub const Command = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Command) ui.Node {
        return ui.commandNode(self.id, self.placeholder);
    }

    pub fn render(self: Command, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderCommand(scene, bounds, self.placeholder, options);
    }

    pub fn collectInteractions(self: Command, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try component_render.collectCommandInteractions(collector, bounds, self.id);
    }

    pub fn measure(self: Command, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        const preferred = if (options.command_palette == null) component_render.preferred_command else component_render.preferred_command_palette;
        return component_render.measureFixed(preferred, constraints);
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
    try std.testing.expectEqual(command.id + component_render.command_item_id_offset, collector.written()[1].id);
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
