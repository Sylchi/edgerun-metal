const std = @import("std");
const ui = @import("ui.zig");
const ui_runtime = @import("ui_runtime.zig");

pub const Kind = enum(u32) {
    default = 0,
    pointer = 1,
    text = 2,
    grabbing = 3,
};

// Cursor proportions follow the MIT-licensed Tabler cursor/pointer family,
// rendered as EdgeRun scene primitives instead of embedding SVG/path support.
pub const default_width: f32 = 19.0;
pub const default_height: f32 = 25.0;
pub const default_tip_size: f32 = 4.0;
pub const default_layer_radius: f32 = 1.5;
pub const pointer_size: f32 = 18.0;
pub const pointer_dot_size: f32 = 4.0;
pub const pointer_ring_size: f32 = 10.0;
pub const text_width: f32 = 20.0;
pub const text_height: f32 = 29.0;
pub const text_stem_width: f32 = 4.0;
pub const text_cap_height: f32 = 4.0;
pub const text_center_dot_size: f32 = 5.0;
pub const grabbing_size: f32 = 26.0;
pub const grabbing_finger_width: f32 = 5.0;
pub const grabbing_finger_height: f32 = 14.0;
pub const outline_offset: f32 = 1.0;
pub const shadow_offset: f32 = 1.5;
pub const soft_shadow_blur: f32 = 4.0;
pub const glow_blur: f32 = 2.5;
pub const layer_grow: f32 = outline_offset * 2.0;
pub const color = ui.Color{ .r = 245, .g = 245, .b = 245, .a = 245 };
pub const color_bottom = ui.Color{ .r = 220, .g = 223, .b = 228, .a = 245 };
pub const outline = ui.Color{ .r = 5, .g = 5, .b = 5, .a = 210 };
pub const accent = ui.Color{ .r = 74, .g = 222, .b = 128, .a = 225 };
pub const highlight = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 110 };
pub const shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 82 };
pub const glow = ui.Color{ .r = 74, .g = 222, .b = 128, .a = 44 };

const default_tip_x: f32 = 0.0;
const default_tip_y: f32 = 0.0;
const default_upper_x: f32 = 2.0;
const default_upper_y: f32 = 4.0;
const default_upper_w: f32 = 7.0;
const default_upper_h: f32 = 5.0;
const default_body_x: f32 = 3.0;
const default_body_y: f32 = 8.0;
const default_body_w: f32 = 11.0;
const default_body_h: f32 = 6.0;
const default_lower_x: f32 = 6.0;
const default_lower_y: f32 = 14.0;
const default_lower_w: f32 = 8.0;
const default_lower_h: f32 = 4.0;
const default_tail_x: f32 = 9.0;
const default_tail_y: f32 = 17.0;
const default_tail_w: f32 = 5.0;
const default_tail_h: f32 = 8.0;
const default_highlight_x: f32 = 3.0;
const default_highlight_y: f32 = 5.0;
const default_highlight_w: f32 = 5.0;
const default_highlight_h: f32 = 3.0;
const default_accent_x: f32 = 11.0;
const default_accent_y: f32 = 19.0;
const default_accent_w: f32 = 3.0;
const default_accent_h: f32 = 5.0;

const text_accent_offset_x: f32 = 4.0;
const text_accent_offset_y: f32 = 2.0;

const hand_finger_0_x: f32 = 4.0;
const hand_finger_0_y: f32 = 5.0;
const hand_finger_1_x: f32 = 9.0;
const hand_finger_1_y: f32 = 2.0;
const hand_finger_2_x: f32 = 14.0;
const hand_finger_2_y: f32 = 5.0;
const hand_finger_3_x: f32 = 19.0;
const hand_finger_3_y: f32 = 10.0;
const hand_palm_x: f32 = 5.0;
const hand_palm_y: f32 = 15.0;
const hand_palm_w: f32 = 18.0;
const hand_palm_h: f32 = 10.0;
const hand_cuff_x: f32 = 5.0;
const hand_cuff_y: f32 = 17.0;
const hand_cuff_w: f32 = 15.0;
const hand_cuff_h: f32 = 5.0;
const hand_highlight_x: f32 = 6.0;
const hand_highlight_y: f32 = 5.0;
const hand_highlight_w: f32 = 3.0;
const hand_highlight_h: f32 = 5.0;

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

pub fn render(scene: *ui.Scene, x: f32, y: f32, kind: Kind) ui.RenderError!void {
    if (!std.math.isFinite(x) or !std.math.isFinite(y) or x < 0.0 or y < 0.0) return;
    switch (kind) {
        .default => try renderDefault(scene, x, y),
        .pointer => try renderPointer(scene, x, y),
        .text => try renderText(scene, x, y),
        .grabbing => try renderGrabbing(scene, x, y),
    }
}

pub fn damageBounds(x: f32, y: f32, kind: Kind) ?ui.Rect {
    if (!std.math.isFinite(x) or !std.math.isFinite(y) or x < 0.0 or y < 0.0) return null;
    const pad = outline_offset + shadow_offset + soft_shadow_blur + 1.0;
    return switch (kind) {
        .default => ui.Rect.init(x - pad, y - pad, default_width + pad * 2.0, default_height + pad * 2.0),
        .pointer => centeredBounds(x, y, pointer_size, pointer_size, pad),
        .text => centeredBounds(x, y, text_width, text_height, pad),
        .grabbing => centeredBounds(x, y, grabbing_size, grabbing_size, pad),
    };
}

fn centeredBounds(x: f32, y: f32, w: f32, h: f32, pad: f32) ui.Rect {
    return ui.Rect.init(x - w * 0.5 - pad, y - h * 0.5 - pad, w + pad * 2.0, h + pad * 2.0);
}

fn renderDefault(scene: *ui.Scene, x: f32, y: f32) ui.RenderError!void {
    try cursorShadow(scene, ui.Rect.init(x + shadow_offset, y + shadow_offset, default_width, default_height), shadow, default_layer_radius, soft_shadow_blur);
    try renderDefaultLayer(scene, x - outline_offset, y - outline_offset, outline, layer_grow);
    try renderDefaultLayer(scene, x, y, color, 0.0);
    try cursorRect(scene, x + default_highlight_x, y + default_highlight_y, default_highlight_w, default_highlight_h, highlight, default_layer_radius);
    try cursorRect(scene, x + default_accent_x, y + default_accent_y, default_accent_w, default_accent_h, accent, default_layer_radius);
}

fn renderPointer(scene: *ui.Scene, x: f32, y: f32) ui.RenderError!void {
    const radius = pointer_size * 0.5;
    const left = x - radius;
    const top = y - radius;
    try cursorShadow(scene, ui.Rect.init(left + shadow_offset, top + shadow_offset, pointer_size, pointer_size), shadow, radius, soft_shadow_blur);
    try cursorShadow(scene, ui.Rect.init(x - pointer_ring_size * 0.5, y - pointer_ring_size * 0.5, pointer_ring_size, pointer_ring_size), glow, pointer_ring_size * 0.5, glow_blur);
    try cursorRect(scene, left - outline_offset, top - outline_offset, pointer_size + layer_grow, pointer_size + layer_grow, outline, radius + outline_offset);
    try cursorGradient(scene, ui.Rect.init(left, top, pointer_size, pointer_size), color, color_bottom, radius);
    try cursorRect(scene, x - pointer_dot_size * 0.5, y - pointer_dot_size * 0.5, pointer_dot_size, pointer_dot_size, accent, pointer_dot_size * 0.5);
    try cursorRect(scene, x - pointer_ring_size * 0.5, y - pointer_ring_size * 0.5, pointer_ring_size * 0.5, text_cap_height, highlight, text_cap_height * 0.5);
}

fn renderText(scene: *ui.Scene, x: f32, y: f32) ui.RenderError!void {
    const left = x - text_width * 0.5;
    const top = y - text_height * 0.5;
    const stem_x = x - text_stem_width * 0.5;
    try cursorShadow(scene, ui.Rect.init(stem_x + shadow_offset, top + shadow_offset, text_stem_width, text_height), shadow, text_stem_width * 0.5, soft_shadow_blur);
    try renderTextLayer(scene, left - outline_offset, top - outline_offset, stem_x - outline_offset, outline, layer_grow);
    try renderTextLayer(scene, left, top, stem_x, color, 0.0);
    try cursorRect(scene, stem_x + text_stem_width + text_accent_offset_x, y - text_accent_offset_y, text_center_dot_size, text_cap_height, accent, text_cap_height * 0.5);
}

fn renderGrabbing(scene: *ui.Scene, x: f32, y: f32) ui.RenderError!void {
    const left = x - grabbing_size * 0.5;
    const top = y - grabbing_size * 0.5;
    try cursorShadow(scene, ui.Rect.init(left + shadow_offset, top + shadow_offset, grabbing_size, grabbing_size), shadow, grabbing_size * 0.35, soft_shadow_blur);
    try renderHandLayer(scene, left - outline_offset, top - outline_offset, outline, layer_grow);
    try renderHandLayer(scene, left, top, color, 0.0);
    try cursorRect(scene, left + hand_cuff_x, top + hand_cuff_y, hand_cuff_w, hand_cuff_h, accent, hand_cuff_h * 0.5);
    try cursorRect(scene, left + hand_highlight_x, top + hand_highlight_y, hand_highlight_w, hand_highlight_h, highlight, hand_highlight_w * 0.5);
}

fn renderDefaultLayer(scene: *ui.Scene, x: f32, y: f32, fill: ui.Color, grow: f32) ui.RenderError!void {
    const radius = default_layer_radius + grow * 0.5;
    try cursorRect(scene, x + default_tip_x, y + default_tip_y, default_tip_size + grow, default_tip_size + grow, fill, radius);
    try cursorRect(scene, x + default_upper_x, y + default_upper_y, default_upper_w + grow, default_upper_h + grow, fill, radius);
    try cursorRect(scene, x + default_body_x, y + default_body_y, default_body_w + grow, default_body_h + grow, fill, radius);
    try cursorRect(scene, x + default_lower_x, y + default_lower_y, default_lower_w + grow, default_lower_h + grow, fill, radius);
    try cursorRect(scene, x + default_tail_x, y + default_tail_y, default_tail_w + grow, default_tail_h + grow, fill, radius);
}

fn renderTextLayer(scene: *ui.Scene, left: f32, top: f32, stem_x: f32, fill: ui.Color, grow: f32) ui.RenderError!void {
    try cursorRect(scene, stem_x, top, text_stem_width + grow, text_height + grow, fill, 2.0 + grow * 0.5);
    try cursorRect(scene, left, top, text_width + grow, text_cap_height + grow, fill, 2.0 + grow * 0.5);
    try cursorRect(scene, left, top + text_height - text_cap_height, text_width + grow, text_cap_height + grow, fill, 2.0 + grow * 0.5);
}

fn renderHandLayer(scene: *ui.Scene, left: f32, top: f32, fill: ui.Color, grow: f32) ui.RenderError!void {
    const w = grabbing_finger_width + grow;
    const h = grabbing_finger_height + grow;
    const r = grabbing_finger_width * 0.5 + grow * 0.5;
    try cursorRect(scene, left + hand_finger_0_x, top + hand_finger_0_y, w, h, fill, r);
    try cursorRect(scene, left + hand_finger_1_x, top + hand_finger_1_y, w, h + outline_offset, fill, r);
    try cursorRect(scene, left + hand_finger_2_x, top + hand_finger_2_y, w, h - outline_offset, fill, r);
    try cursorRect(scene, left + hand_finger_3_x, top + hand_finger_3_y, w, h - text_cap_height, fill, r);
    try cursorRect(scene, left + hand_palm_x, top + hand_palm_y, hand_palm_w + grow, hand_palm_h + grow, fill, hand_palm_h * 0.5 + grow * 0.5);
}

fn cursorRect(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, fill: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(ui.Rect.init(x, y, w, h), fill, .fill, radius, 0.0);
}

fn cursorGradient(scene: *ui.Scene, bounds: ui.Rect, top_color: ui.Color, bottom_color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushGradientRect(bounds, top_color, bottom_color, radius);
}

fn cursorShadow(scene: *ui.Scene, bounds: ui.Rect, fill: ui.Color, radius: f32, blur: f32) ui.RenderError!void {
    try scene.pushRect(bounds, fill, .shadow, radius, blur);
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

test "cursor renders into the scene instead of host cursor APIs" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try render(&scene, 12.0, 12.0, .pointer);

    var found_accent = false;
    for (scene.written()) |command| switch (command) {
        .rect => |rect| found_accent = found_accent or std.meta.eql(rect.color, accent),
        else => {},
    };
    try std.testing.expect(found_accent);
}

test "each cursor state renders deterministic scene commands" {
    inline for (std.meta.fields(Kind)) |field| {
        var commands: [32]ui.Command = undefined;
        var scene = ui.Scene.init(&commands);
        try render(&scene, 32.0, 32.0, @enumFromInt(field.value));
        try std.testing.expect(scene.written().len > 0);
        try std.testing.expect(scene.written().len <= commands.len);
    }
}

test "cursor renderer ignores invalid pointer coordinates" {
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, -1.0, 12.0, .default);
    try render(&scene, 12.0, std.math.inf(f32), .pointer);

    try std.testing.expectEqual(@as(usize, 0), scene.written().len);
}

test "cursor visuals include shadow outline fill and accent layers" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try render(&scene, 24.0, 24.0, .default);

    var found_shadow = false;
    var found_outline = false;
    var found_fill = false;
    var found_accent = false;
    for (scene.written()) |command| switch (command) {
        .rect => |rect| {
            found_shadow = found_shadow or rect.mode == .shadow;
            found_outline = found_outline or std.meta.eql(rect.color, outline);
            found_fill = found_fill or std.meta.eql(rect.color, color);
            found_accent = found_accent or std.meta.eql(rect.color, accent);
        },
        else => {},
    };

    try std.testing.expect(found_shadow);
    try std.testing.expect(found_outline);
    try std.testing.expect(found_fill);
    try std.testing.expect(found_accent);
}
