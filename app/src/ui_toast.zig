const std = @import("std");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const Toast = @import("ui/components/Toast.zig").Toast;
const design = @import("app_design.zig");
const compositor = @import("render/compositor.zig");

pub const Error = compositor.Error || error{
    ToastBudgetExceeded,
};

pub const default_lifetime_ms: f32 = 4800.0;
pub const max_visible: usize = 4;

const toast_w: f32 = 320.0;
const toast_h: f32 = 58.0;
const toast_gap: f32 = 10.0;
const edge_margin: f32 = 18.0;

pub const Entry = struct {
    id: u32,
    title: []const u8,
    detail: []const u8 = "",
    created_ms: f32,
    lifetime_ms: f32 = default_lifetime_ms,

    pub fn alive(self: Entry, frame_ms: f32) bool {
        if (self.lifetime_ms <= 0.0) return false;
        if (frame_ms < self.created_ms) return true;
        return frame_ms - self.created_ms < self.lifetime_ms;
    }
};

pub const Manager = struct {
    entries: []Entry,
    len: usize = 0,

    pub fn init(entries: []Entry) Manager {
        return .{ .entries = entries };
    }

    pub fn push(self: *Manager, id: u32, title: []const u8, detail: []const u8, frame_ms: f32) Error!void {
        try self.pushWithLifetime(id, title, detail, frame_ms, default_lifetime_ms);
    }

    pub fn pushWithLifetime(self: *Manager, id: u32, title: []const u8, detail: []const u8, frame_ms: f32, lifetime_ms: f32) Error!void {
        if (self.len == self.entries.len) return error.ToastBudgetExceeded;
        self.entries[self.len] = .{
            .id = id,
            .title = title,
            .detail = detail,
            .created_ms = frame_ms,
            .lifetime_ms = lifetime_ms,
        };
        self.len += 1;
    }

    pub fn expire(self: *Manager, frame_ms: f32) void {
        var write_index: usize = 0;
        for (self.entries[0..self.len]) |entry| {
            if (!entry.alive(frame_ms)) continue;
            self.entries[write_index] = entry;
            write_index += 1;
        }
        self.len = write_index;
    }

    pub fn visibleCount(self: Manager, frame_ms: f32) usize {
        var count: usize = 0;
        var index = self.len;
        while (index > 0 and count < max_visible) {
            index -= 1;
            if (self.entries[index].alive(frame_ms)) count += 1;
        }
        return count;
    }

    pub fn render(self: Manager, host: *compositor.Host, bounds: ui.Rect, frame_ms: f32) Error!void {
        var surface = host.begin(.toast);
        var visible_index: usize = 0;
        var index = self.len;
        while (index > 0 and visible_index < max_visible) {
            index -= 1;
            const entry = self.entries[index];
            if (!entry.alive(frame_ms)) continue;
            const rect = stackedBounds(bounds, visible_index);
            const toast = Toast{ .id = entry.id, .title = entry.title, .detail = entry.detail };
            try toast.render(&surface.scene, rect, .{ .style = design.style() });
            try toast.collectInteractions(&surface.collector, rect);
            visible_index += 1;
        }
        try surface.finish();
    }
};

pub fn stackedBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const step = toast_h + toast_gap;
    const x = bounds.x + @max(edge_margin, bounds.w - toast_w - edge_margin);
    const y = bounds.y + @max(edge_margin, bounds.h - edge_margin - toast_h - @as(f32, @floatFromInt(index)) * step);
    const width = @min(toast_w, @max(design.min_touch_target, bounds.w - edge_margin * 2.0));
    return ui.Rect.init(x, y, width, toast_h);
}

test "toast manager expires entries deterministically" {
    var storage: [4]Entry = undefined;
    var manager = Manager.init(&storage);
    try manager.pushWithLifetime(1, "Saved", "First", 0.0, 100.0);
    try manager.pushWithLifetime(2, "Built", "Second", 50.0, 200.0);

    manager.expire(120.0);
    try std.testing.expectEqual(@as(usize, 1), manager.len);
    try std.testing.expectEqual(@as(u32, 2), manager.entries[0].id);
}

test "toast manager renders newest visible toasts as a bottom right stack" {
    var storage: [6]Entry = undefined;
    var manager = Manager.init(&storage);
    try manager.push(1, "One", "First", 0.0);
    try manager.push(2, "Two", "Second", 10.0);
    try manager.push(3, "Three", "Third", 20.0);

    var overlay_commands: [64]ui.Command = undefined;
    var overlay_regions: [16]interaction.Region = undefined;
    var entries: [4]compositor.Entry = undefined;
    var host = compositor.Host.init(&overlay_commands, &overlay_regions, &entries);
    try manager.render(&host, ui.Rect.init(0, 0, 800, 600), 30.0);

    var commands: [64]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [16]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try host.flush(&scene, &collector);

    try std.testing.expectEqual(@as(usize, 3), collector.written().len);
    try std.testing.expectEqual(stackedBounds(ui.Rect.init(0, 0, 800, 600), 0).y, collector.written()[0].bounds.y);
    try std.testing.expect(collector.written()[0].bounds.y > collector.written()[1].bounds.y);
}

test "toast manager skips expired and clips visible stack count" {
    var storage: [6]Entry = undefined;
    var manager = Manager.init(&storage);
    try manager.pushWithLifetime(1, "Expired", "", 0.0, 10.0);
    try manager.push(2, "Two", "", 20.0);
    try manager.push(3, "Three", "", 30.0);
    try manager.push(4, "Four", "", 40.0);
    try manager.push(5, "Five", "", 50.0);
    try manager.push(6, "Six", "", 60.0);

    try std.testing.expectEqual(max_visible, manager.visibleCount(70.0));
}
