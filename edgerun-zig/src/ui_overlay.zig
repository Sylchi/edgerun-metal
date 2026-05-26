const std = @import("std");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");

pub const Error = ui.RenderError || interaction.Error || error{
    OverlayBudgetExceeded,
    OverlaySurfaceAlreadyFinished,
};

pub const Layer = enum {
    scrim,
    menu,
    popover,
    modal,
    toast,
};

const layer_order = [_]Layer{
    .scrim,
    .menu,
    .popover,
    .modal,
    .toast,
};

pub const Entry = struct {
    layer: Layer,
    command_start: usize,
    command_end: usize,
    region_start: usize,
    region_end: usize,
};

pub const Host = struct {
    commands: []ui.Command,
    command_len: usize = 0,
    regions: []interaction.Region,
    region_len: usize = 0,
    entries: []Entry,
    entry_len: usize = 0,

    pub fn init(commands: []ui.Command, regions: []interaction.Region, entries: []Entry) Host {
        return .{
            .commands = commands,
            .regions = regions,
            .entries = entries,
        };
    }

    pub fn begin(self: *Host, layer: Layer) Surface {
        return .{
            .host = self,
            .layer = layer,
            .command_start = self.command_len,
            .region_start = self.region_len,
            .scene = ui.Scene.init(self.commands[self.command_len..]),
            .collector = interaction.Collector.init(self.regions[self.region_len..]),
        };
    }

    fn commit(self: *Host, surface: *Surface) Error!void {
        if (surface.finished) return error.OverlaySurfaceAlreadyFinished;
        if (self.entry_len == self.entries.len) return error.OverlayBudgetExceeded;

        const command_end = surface.command_start + surface.scene.written().len;
        const region_end = surface.region_start + surface.collector.written().len;
        if (command_end > self.commands.len or region_end > self.regions.len) return error.OverlayBudgetExceeded;

        self.entries[self.entry_len] = .{
            .layer = surface.layer,
            .command_start = surface.command_start,
            .command_end = command_end,
            .region_start = surface.region_start,
            .region_end = region_end,
        };
        self.entry_len += 1;
        self.command_len = command_end;
        self.region_len = region_end;
        surface.finished = true;
    }

    pub fn flush(self: Host, scene: *ui.Scene, collector: *interaction.Collector) Error!void {
        for (layer_order) |layer| {
            for (self.entries[0..self.entry_len]) |entry| {
                if (entry.layer != layer) continue;
                for (self.commands[entry.command_start..entry.command_end]) |command| try scene.push(command);
                for (self.regions[entry.region_start..entry.region_end]) |region| try collector.add(region);
            }
        }
    }
};

pub const Surface = struct {
    host: *Host,
    layer: Layer,
    command_start: usize,
    region_start: usize,
    scene: ui.Scene,
    collector: interaction.Collector,
    finished: bool = false,

    pub fn finish(self: *Surface) Error!void {
        try self.host.commit(self);
    }
};

test "ui overlay host flushes layers in canonical z order" {
    var overlay_commands: [8]ui.Command = undefined;
    var overlay_regions: [4]interaction.Region = undefined;
    var entries: [4]Entry = undefined;
    var host = Host.init(&overlay_commands, &overlay_regions, &entries);

    var modal = host.begin(.modal);
    try modal.scene.pushRect(ui.Rect.init(0, 0, 20, 20), ui.Color{ .r = 2, .g = 0, .b = 0, .a = 255 }, .fill, 0.0, 0.0);
    try modal.finish();

    var scrim = host.begin(.scrim);
    try scrim.scene.pushRect(ui.Rect.init(0, 0, 20, 20), ui.Color{ .r = 1, .g = 0, .b = 0, .a = 255 }, .fill, 0.0, 0.0);
    try scrim.finish();

    var commands: [8]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try host.flush(&scene, &collector);

    try std.testing.expectEqual(@as(usize, 2), scene.written().len);
    try std.testing.expectEqual(@as(u8, 1), rectRed(scene.written()[0]));
    try std.testing.expectEqual(@as(u8, 2), rectRed(scene.written()[1]));
}

test "ui overlay host appends overlay interactions above base content" {
    var overlay_commands: [8]ui.Command = undefined;
    var overlay_regions: [4]interaction.Region = undefined;
    var entries: [4]Entry = undefined;
    var host = Host.init(&overlay_commands, &overlay_regions, &entries);

    var menu = host.begin(.menu);
    try menu.collector.addHit(ui.Rect.init(0, 0, 20, 20), .button, 2);
    try menu.finish();

    var commands: [8]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(0, 0, 20, 20), .button, 1);
    try host.flush(&scene, &collector);

    try std.testing.expectEqual(@as(u32, 2), interaction.hitTest(collector.written(), 10, 10).?.id);
}

fn rectRed(command: ui.Command) u8 {
    return switch (command) {
        .rect => |rect| rect.color.r,
        else => 0,
    };
}
