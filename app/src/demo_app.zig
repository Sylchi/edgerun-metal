const std = @import("std");
const ui = @import("ui/core.zig");
const Card = @import("ui/components/Card.zig");
const Text = @import("ui/components/Text.zig");
const Icon = @import("ui/components/Icon.zig");
const surface = @import("wayland/surface.zig");
const protocol = @import("wayland/protocol.zig");
const client = @import("wayland/client.zig");
const options = @import("wayland/options.zig");

const max_commands: usize = 2048;

const DemoApp = struct {
    surface: *surface.Surface,

    pub fn renderSafe(self: *DemoApp, client_ptr: *client.WaylandClient) void {
        self.render(client_ptr) catch |err| {
            std.debug.print("demo render error: {s}\n", .{@errorName(err)});
        };
    }

    fn render(self: *DemoApp, client_ptr: *client.WaylandClient) !void {
        var commands: [max_commands]ui.Command = undefined;
        var scene = ui.Scene.init(&commands);
        const w: f32 = @floatFromInt(self.surface.width);
        const h: f32 = @floatFromInt(self.surface.height);

        try scene.pushRect(ui.Rect.init(0, 0, w, h), .{ .r = 22, .g = 22, .b = 22 }, .fill, 0, 0);

        try Card{ .title = "System Status" }.render(&scene, ui.Rect.init(24, 24, 300, 160), .{});
        try scene.pushRect(ui.Rect.init(44, 100, 260, 20), .{ .r = 60, .g = 60, .b = 60 }, .fill, 4, 0);
        try scene.pushRect(ui.Rect.init(44, 100, 169, 20), .{ .r = 0, .g = 160, .b = 80 }, .fill, 4, 0);
        try Text.renderAligned(&scene, ui.Rect.init(44, 130, 200, 14), "CPU: 65%", .{ .r = 180, .g = 180, .b = 180 }, .start);

        try Card{ .title = "Network" }.render(&scene, ui.Rect.init(348, 24, 280, 160), .{});
        try Icon.named(.wifi).renderColor(&scene, ui.Rect.init(370, 80, 32, 32), .{ .r = 0, .g = 200, .b = 100 });
        try Text.renderAligned(&scene, ui.Rect.init(410, 85, 200, 14), "Connected", .{ .r = 0, .g = 200, .b = 100 }, .start);
        try Text.renderAligned(&scene, ui.Rect.init(370, 120, 200, 12), "192.168.1.42", .{ .r = 140, .g = 140, .b = 140 }, .start);
        try Icon.named(.activity).renderColor(&scene, ui.Rect.init(370, 145, 16, 16), .{ .r = 100, .g = 200, .b = 255 });
        try Text.renderAligned(&scene, ui.Rect.init(392, 145, 200, 12), "Active", .{ .r = 100, .g = 200, .b = 255 }, .start);

        try Card{ .title = "Display" }.render(&scene, ui.Rect.init(24, 208, 300, 120), .{});
        try scene.pushRect(ui.Rect.init(44, 250, 260, 60), .{ .r = 30, .g = 30, .b = 30 }, .fill, 8, 0);
        try Text.renderAligned(&scene, ui.Rect.init(54, 270, 240, 18), "Hello from EdgeRun!", .{ .r = 220, .g = 220, .b = 220 }, .start);
        try Text.renderAligned(&scene, ui.Rect.init(54, 292, 240, 12), "Canonical UI Components", .{ .r = 140, .g = 140, .b = 140 }, .start);

        try Card{ .title = "Storage" }.render(&scene, ui.Rect.init(348, 208, 280, 120), .{});
        try scene.pushRect(ui.Rect.init(368, 280, 240, 20), .{ .r = 60, .g = 60, .b = 60 }, .fill, 4, 0);
        try scene.pushRect(ui.Rect.init(368, 280, 101, 20), .{ .r = 220, .g = 180, .b = 0 }, .fill, 4, 0);
        try Text.renderAligned(&scene, ui.Rect.init(368, 308, 240, 14), "Used: 42% (256 GB / 610 GB)", .{ .r = 140, .g = 140, .b = 140 }, .start);

        try self.surface.renderScene(client_ptr, scene.written(), surface.defaultBackground(), 0, 0, null);
    }

    pub fn handleWaylandInput(self: *DemoApp, client_ptr: *client.WaylandClient, kind: protocol.ObjectKind, message: protocol.Message) !bool {
        _ = self;
        _ = client_ptr;
        _ = kind;
        _ = message;
        return false;
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);
    const opts = options.parseOptions(args) catch |err| {
        if (err == error.HelpRequested) {
            options.help();
            return;
        }
        return err;
    };
    const socket_path = try options.waylandSocketPath(init, allocator);
    defer allocator.free(socket_path);
    var c = try client.WaylandClient.connect(init.io, socket_path);
    defer c.close(init.io);
    try c.bootstrap();
    try c.createWindow(opts.width, opts.height);
    const surf = try surface.Surface.create(allocator, &c, opts);
    errdefer surf.destroy();
    var app = DemoApp{ .surface = surf };
    app.renderSafe(&c);
    try c.eventLoop(opts.seconds, &app);
    surf.destroy();
}
