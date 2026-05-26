const std = @import("std");
const clock = @import("../../clock.zig");
const ui = @import("../../ui.zig");

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
        .text => |text| if (std.mem.eql(u8, text.value, value)) return command,
        else => {},
    };
    return null;
}

pub fn textCommandPrefix(commands: []const ui.Command, prefix: []const u8) ?ui.Command {
    for (commands) |command| switch (command) {
        .text => |text| if (std.mem.startsWith(u8, text.value, prefix)) return command,
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
