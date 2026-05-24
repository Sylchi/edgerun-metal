const std = @import("std");
const ui = @import("ui.zig");
const ui_runtime = @import("ui_runtime.zig");

pub const Kind = enum(u32) {
    default = 0,
    pointer = 1,
    text = 2,
    grabbing = 3,
};

pub const css_default = "default";
pub const css_pointer = "pointer";
pub const css_text = "text";
pub const css_grabbing = "grabbing";

pub const wayland_default = "default";
pub const wayland_pointer = "pointer";
pub const wayland_text = "text";
pub const wayland_grabbing = "grabbing";

pub fn fromState(action: ui_runtime.ActionKind, hover: ?ui.HitKind) Kind {
    switch (action) {
        .drag_started, .drag_moved => return .grabbing,
        .none, .hovered, .activated, .dropped, .reordered => {},
    }

    return switch (hover orelse return .default) {
        .input, .textarea => .text,
        .button, .row_item, .checkbox, .switch_control, .slider, .select => .pointer,
    };
}

pub fn css(kind: Kind) []const u8 {
    return switch (kind) {
        .default => css_default,
        .pointer => css_pointer,
        .text => css_text,
        .grabbing => css_grabbing,
    };
}

pub fn waylandName(kind: Kind) [:0]const u8 {
    return switch (kind) {
        .default => wayland_default,
        .pointer => wayland_pointer,
        .text => wayland_text,
        .grabbing => wayland_grabbing,
    };
}

test "cursor intent follows shared hit and drag state" {
    try std.testing.expectEqual(Kind.default, fromState(.none, null));
    try std.testing.expectEqual(Kind.text, fromState(.none, .input));
    try std.testing.expectEqual(Kind.text, fromState(.hovered, .textarea));
    try std.testing.expectEqual(Kind.pointer, fromState(.none, .button));
    try std.testing.expectEqual(Kind.pointer, fromState(.activated, .row_item));
    try std.testing.expectEqual(Kind.grabbing, fromState(.drag_started, .button));
    try std.testing.expectEqual(Kind.grabbing, fromState(.drag_moved, null));
}

test "cursor intent exposes browser css names" {
    try std.testing.expectEqualStrings(css_default, css(.default));
    try std.testing.expectEqualStrings(css_pointer, css(.pointer));
    try std.testing.expectEqualStrings(css_text, css(.text));
    try std.testing.expectEqualStrings(css_grabbing, css(.grabbing));
}
