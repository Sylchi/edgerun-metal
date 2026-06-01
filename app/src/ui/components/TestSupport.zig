const std = @import("std");
const bytes = @import("../../bytes.zig");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const ui = @import("../core.zig");

const RenderOptions = common.RenderOptions;

pub fn expect(condition: bool) !void {
    if (!condition) return error.TestExpectedTrue;
}

pub fn epoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
}

pub fn firstTextCommand(commands: []const ui.Command) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => return command,
        else => {},
    };
    return null;
}

pub fn textCommand(commands: []const ui.Command, value: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text| if (bytes.eql(text.value, value)) return command,
        else => {},
    };
    return null;
}

pub fn textCommandPrefix(commands: []const ui.Command, prefix: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text| if (bytes.startsWith(text.value, prefix)) return command,
        else => {},
    };
    return null;
}

pub fn textCount(commands: []const ui.Command) usize {
    var count: usize = 0;
    for (commands) |command| switch (command) {
        .text => count += 1,
        else => {},
    };
    return count;
}

pub fn hasText(commands: []const ui.Command, value: []const u8) bool {
    return textCommand(commands, value) != null;
}

pub fn hasTextColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .text => |text| if (std.meta.eql(text.color, color)) return true,
        else => {},
    };
    return false;
}

pub fn hasIcon(commands: []const ui.Command, icon_id: u32) bool {
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

pub fn iconCommand(commands: []const ui.Command, icon_id: u32) ?ui.Command {
    for (commands) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return command,
        else => {},
    };
    return null;
}

pub fn iconCount(commands: []const ui.Command, icon_id: u32) usize {
    var count: usize = 0;
    for (commands) |command| switch (command) {
        .icon_quad => |quad| {
            if (quad.icon_id == icon_id) count += 1;
        },
        else => {},
    };
    return count;
}

pub fn hasRectColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

pub fn hasRectBounds(commands: []const ui.Command, bounds: ui.Rect) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.bounds, bounds)) return true,
        else => {},
    };
    return false;
}

pub fn hasFillColor(commands: []const ui.Command, color: ui.Color) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (rect.mode == .fill and std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

pub fn fillRectColor(commands: []const ui.Command, color: ui.Color) ?ui.Rect {
    for (commands) |command| switch (command) {
        .rect => |rect| if (rect.mode == .fill and std.meta.eql(rect.color, color)) return rect.bounds,
        else => {},
    };
    return null;
}

pub fn lastFillRect(commands: []const ui.Command) ?ui.Rect {
    var found: ?ui.Rect = null;
    for (commands) |command| switch (command) {
        .rect => |rect| {
            if (rect.mode == .fill) found = rect.bounds;
        },
        else => {},
    };
    return found;
}

pub fn hasBorderAt(commands: []const ui.Command, bounds: ui.Rect) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (rect.mode == .border and std.meta.eql(rect.bounds, bounds)) return true,
        else => {},
    };
    return false;
}

pub fn hasShadow(commands: []const ui.Command) bool {
    for (commands) |command| switch (command) {
        .rect => |rect| if (rect.mode == .shadow and rect.shadow > 0.0) return true,
        else => {},
    };
    return false;
}

pub fn SceneHarness(comptime command_capacity: usize) type {
    return struct {
        const Self = @This();

        commands: [command_capacity]ui.Command = undefined,
        scene: ui.Scene = undefined,

        pub fn init(self: *Self) void {
            self.scene = ui.Scene.init(&self.commands);
        }

        pub fn written(self: *Self) []const ui.Command {
            return self.scene.written();
        }

        pub fn render(self: *Self, subject: anytype, bounds: ui.Rect, options: RenderOptions) !void {
            try subject.render(&self.scene, bounds, options);
        }

        pub fn expectText(self: *Self, value: []const u8) !void {
            try std.testing.expect(hasText(self.written(), value));
        }

        pub fn expectNoText(self: *Self, value: []const u8) !void {
            try std.testing.expect(!hasText(self.written(), value));
        }

        pub fn expectTextPrefix(self: *Self, prefix: []const u8) !void {
            try std.testing.expect(textCommandPrefix(self.written(), prefix) != null);
        }

        pub fn expectIcon(self: *Self, icon_id: u32) !void {
            try std.testing.expect(hasIcon(self.written(), icon_id));
        }

        pub fn expectIconCount(self: *Self, icon_id: u32, count: usize) !void {
            try std.testing.expectEqual(count, iconCount(self.written(), icon_id));
        }

        pub fn expectRectColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(hasRectColor(self.written(), color));
        }

        pub fn expectNoRectColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(!hasRectColor(self.written(), color));
        }

        pub fn expectFillColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(hasFillColor(self.written(), color));
        }

        pub fn expectBorderAt(self: *Self, bounds: ui.Rect) !void {
            try std.testing.expect(hasBorderAt(self.written(), bounds));
        }

        pub fn expectShadow(self: *Self) !void {
            try std.testing.expect(hasShadow(self.written()));
        }
    };
}

pub fn InteractiveHarness(comptime command_capacity: usize, comptime region_capacity: usize) type {
    return struct {
        const Self = @This();

        commands: [command_capacity]ui.Command = undefined,
        regions: [region_capacity]interaction.Region = undefined,
        scene: ui.Scene = undefined,
        collector: interaction.Collector = undefined,

        pub fn init(self: *Self) void {
            self.scene = ui.Scene.init(&self.commands);
            self.collector = interaction.Collector.init(&self.regions);
        }

        pub fn written(self: *Self) []const ui.Command {
            return self.scene.written();
        }

        pub fn hits(self: *Self) []const interaction.Region {
            return self.collector.written();
        }

        pub fn render(self: *Self, subject: anytype, bounds: ui.Rect, options: RenderOptions) !void {
            try subject.render(&self.scene, bounds, options);
        }

        pub fn collect(self: *Self, subject: anytype, bounds: ui.Rect, options: RenderOptions) !void {
            try subject.collectInteractions(&self.collector, bounds, options);
        }

        pub fn renderInteractive(self: *Self, subject: anytype, bounds: ui.Rect, options: RenderOptions) !void {
            try self.render(subject, bounds, options);
            try self.collect(subject, bounds, options);
        }

        pub fn expectText(self: *Self, value: []const u8) !void {
            try std.testing.expect(hasText(self.written(), value));
        }

        pub fn expectNoText(self: *Self, value: []const u8) !void {
            try std.testing.expect(!hasText(self.written(), value));
        }

        pub fn expectTextPrefix(self: *Self, prefix: []const u8) !void {
            try std.testing.expect(textCommandPrefix(self.written(), prefix) != null);
        }

        pub fn expectIcon(self: *Self, icon_id: u32) !void {
            try std.testing.expect(hasIcon(self.written(), icon_id));
        }

        pub fn expectIconCount(self: *Self, icon_id: u32, count: usize) !void {
            try std.testing.expectEqual(count, iconCount(self.written(), icon_id));
        }

        pub fn expectRectColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(hasRectColor(self.written(), color));
        }

        pub fn expectNoRectColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(!hasRectColor(self.written(), color));
        }

        pub fn expectFillColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(hasFillColor(self.written(), color));
        }

        pub fn expectBorderAt(self: *Self, bounds: ui.Rect) !void {
            try std.testing.expect(hasBorderAt(self.written(), bounds));
        }

        pub fn expectShadow(self: *Self) !void {
            try std.testing.expect(hasShadow(self.written()));
        }

        pub fn expectHitCount(self: *Self, count: usize) !void {
            try std.testing.expectEqual(count, self.hits().len);
        }

        pub fn expectHitId(self: *Self, index: usize, id: u32) !void {
            try std.testing.expect(index < self.hits().len);
            try std.testing.expectEqual(id, self.hits()[index].id);
        }

        pub fn expectHitKind(self: *Self, index: usize, kind: ui.HitKind) !void {
            try std.testing.expect(index < self.hits().len);
            try std.testing.expectEqual(kind, self.hits()[index].kind);
        }

        pub fn expectHit(self: *Self, kind: ui.HitKind, id: u32) !void {
            try std.testing.expect(hasHit(self.hits(), kind, id));
        }

        pub fn expectHitIds(self: *Self, expected: []const u32) !void {
            try self.expectHitCount(expected.len);
            for (expected, 0..) |id, index| {
                try self.expectHitId(index, id);
            }
        }
    };
}

pub fn ClippedInteractiveHarness(comptime command_capacity: usize, comptime clip_capacity: usize, comptime region_capacity: usize) type {
    return struct {
        const Self = @This();

        commands: [command_capacity]ui.Command = undefined,
        clips: [clip_capacity]ui.Rect = undefined,
        regions: [region_capacity]interaction.Region = undefined,
        scene: ui.Scene = undefined,
        collector: interaction.Collector = undefined,

        pub fn init(self: *Self) void {
            self.scene = ui.Scene.initWithClips(&self.commands, &self.clips);
            self.collector = interaction.Collector.init(&self.regions);
        }

        pub fn written(self: *Self) []const ui.Command {
            return self.scene.written();
        }

        pub fn hits(self: *Self) []const interaction.Region {
            return self.collector.written();
        }

        pub fn expectText(self: *Self, value: []const u8) !void {
            try std.testing.expect(hasText(self.written(), value));
        }

        pub fn expectNoText(self: *Self, value: []const u8) !void {
            try std.testing.expect(!hasText(self.written(), value));
        }

        pub fn expectTextPrefix(self: *Self, prefix: []const u8) !void {
            try std.testing.expect(textCommandPrefix(self.written(), prefix) != null);
        }

        pub fn expectIcon(self: *Self, icon_id: u32) !void {
            try std.testing.expect(hasIcon(self.written(), icon_id));
        }

        pub fn expectRectColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(hasRectColor(self.written(), color));
        }

        pub fn expectNoRectColor(self: *Self, color: ui.Color) !void {
            try std.testing.expect(!hasRectColor(self.written(), color));
        }

        pub fn expectHitCount(self: *Self, count: usize) !void {
            try std.testing.expectEqual(count, self.hits().len);
        }

        pub fn expectHit(self: *Self, kind: ui.HitKind, id: u32) !void {
            try std.testing.expect(hasHit(self.hits(), kind, id));
        }

        pub fn expectHitId(self: *Self, id: u32) !void {
            try std.testing.expect(hasHitId(self.hits(), id));
        }
    };
}

pub fn InteractionHarness(comptime region_capacity: usize) type {
    return struct {
        const Self = @This();

        regions: [region_capacity]interaction.Region = undefined,
        collector: interaction.Collector = undefined,

        pub fn init(self: *Self) void {
            self.collector = interaction.Collector.init(&self.regions);
        }

        pub fn hits(self: *Self) []const interaction.Region {
            return self.collector.written();
        }

        pub fn expectHitCount(self: *Self, count: usize) !void {
            try std.testing.expectEqual(count, self.hits().len);
        }

        pub fn expectHitId(self: *Self, index: usize, id: u32) !void {
            try std.testing.expect(index < self.hits().len);
            try std.testing.expectEqual(id, self.hits()[index].id);
        }

        pub fn expectHitKind(self: *Self, index: usize, kind: ui.HitKind) !void {
            try std.testing.expect(index < self.hits().len);
            try std.testing.expectEqual(kind, self.hits()[index].kind);
        }
    };
}

pub fn hasHit(regions: []const interaction.Region, kind: ui.HitKind, id: u32) bool {
    for (regions) |region| {
        if (region.kind == kind and region.id == id) return true;
    }
    return false;
}

pub fn hasHitId(regions: []const interaction.Region, id: u32) bool {
    for (regions) |region| {
        if (region.id == id) return true;
    }
    return false;
}
