const std = @import("std");
const math = @import("../math.zig");
const icon_pack = @import("icon.zig");
const ui = @import("core.zig");
const ui_runtime = @import("runtime.zig");

pub const Kind = enum(u32) {
    default = 0,
    pointer = 1,
    text = 2,
    grabbing = 3,
};

// Cursor proportions are owned scene geometry so every host renders the same
// pointer without asking the compositor for a cursor theme.
pub const svg_size: f32 = 21.0;
pub const pointer_2_hotspot_x: f32 = 2.65;
pub const pointer_2_hotspot_y: f32 = 2.65;
pub const hand_finger_hotspot_x: f32 = 8.3;
pub const hand_finger_hotspot_y: f32 = 2.65;
pub const default_layer_radius: f32 = 1.5;
pub const text_width: f32 = 20.0;
pub const text_height: f32 = 29.0;
pub const text_stem_width: f32 = 4.0;
pub const text_cap_height: f32 = 4.0;
pub const text_center_dot_size: f32 = 5.0;
pub const grabbing_size: f32 = 26.0;
pub const grabbing_finger_width: f32 = 5.0;
pub const grabbing_finger_height: f32 = 14.0;
pub const outline_offset: f32 = 0.75;
pub const shadow_offset: f32 = 1.0;
pub const soft_shadow_blur: f32 = 2.5;
pub const layer_grow: f32 = outline_offset * 2.0;
pub const color = ui.Color{ .r = 245, .g = 245, .b = 245, .a = 245 };
pub const outline = ui.Color{ .r = 5, .g = 5, .b = 5, .a = 190 };
pub const accent = ui.Color{ .r = 74, .g = 222, .b = 128, .a = 225 };
pub const highlight = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 110 };
pub const shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 56 };

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
        .none, .hovered, .focused, .activated, .dropped, .reordered, .dismissed => {},
    }

    return switch (hover orelse return .default) {
        .input, .textarea => .text,
        .button, .row_item, .checkbox, .switch_control, .slider, .select, .overlay_trigger => .pointer,
    };
}

pub fn render(scene: *ui.Scene, x: f32, y: f32, kind: Kind) ui.RenderError!void {
    if (!math.isFiniteF(x) or !math.isFiniteF(y) or x < 0.0 or y < 0.0) return;
    switch (kind) {
        .default => try renderDefault(scene, x, y),
        .pointer => try renderPointer(scene, x, y),
        .text => try renderText(scene, x, y),
        .grabbing => try renderGrabbing(scene, x, y),
    }
}

pub fn damageBounds(x: f32, y: f32, kind: Kind) ?ui.Rect {
    if (!math.isFiniteF(x) or !math.isFiniteF(y) or x < 0.0 or y < 0.0) return null;
    const pad = outline_offset + shadow_offset + soft_shadow_blur + 1.0;
    return switch (kind) {
        .default => iconCursorBounds(x, y, pointer_2_hotspot_x, pointer_2_hotspot_y, pad),
        .pointer => iconCursorBounds(x, y, hand_finger_hotspot_x, hand_finger_hotspot_y, pad),
        .text => centeredBounds(x, y, text_width, text_height, pad),
        .grabbing => centeredBounds(x, y, grabbing_size, grabbing_size, pad),
    };
}

fn iconCursorBounds(x: f32, y: f32, hotspot_x: f32, hotspot_y: f32, pad: f32) ui.Rect {
    return ui.Rect.init(x - hotspot_x - pad, y - hotspot_y - pad, svg_size + pad * 2.0, svg_size + pad * 2.0);
}

fn centeredBounds(x: f32, y: f32, w: f32, h: f32, pad: f32) ui.Rect {
    return ui.Rect.init(x - w * 0.5 - pad, y - h * 0.5 - pad, w + pad * 2.0, h + pad * 2.0);
}

fn renderDefault(scene: *ui.Scene, x: f32, y: f32) ui.RenderError!void {
    try renderSvgCursor(scene, x, y, pointer_2_hotspot_x, pointer_2_hotspot_y, icon_pack.cursor_pointer_2_icon_id, color);
}

fn renderPointer(scene: *ui.Scene, x: f32, y: f32) ui.RenderError!void {
    try renderSvgCursor(scene, x, y, hand_finger_hotspot_x, hand_finger_hotspot_y, icon_pack.cursor_hand_finger_icon_id, color);
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

fn renderSvgCursor(scene: *ui.Scene, x: f32, y: f32, hotspot_x: f32, hotspot_y: f32, icon_id: u32, stroke_color: ui.Color) ui.RenderError!void {
    const left = x - hotspot_x;
    const top = y - hotspot_y;
    const base = ui.Rect.init(left, top, svg_size, svg_size);
    try cursorShadow(scene, ui.Rect.init(left + shadow_offset, top + shadow_offset, svg_size, svg_size), shadow, default_layer_radius, soft_shadow_blur);
    try scene.pushIconQuad(.{ .bounds = base.insetUniform(-outline_offset), .icon_id = icon_id, .color = outline });
    try scene.pushIconQuad(.{ .bounds = base, .icon_id = icon_id, .color = stroke_color });
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

    var found_pointer_svg = false;
    for (scene.written()) |command| switch (command) {
        .icon_quad => |quad| found_pointer_svg = found_pointer_svg or quad.icon_id == icon_pack.cursor_hand_finger_icon_id,
        else => {},
    };
    try std.testing.expect(found_pointer_svg);
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
    try render(&scene, 12.0, @as(f32, @bitCast(@as(u32, 0x7f800000))), .pointer);

    try std.testing.expectEqual(@as(usize, 0), scene.written().len);
}

test "cursor visuals include shadow outline and fill svg layers" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try render(&scene, 24.0, 24.0, .default);

    var found_shadow = false;
    var found_outline = false;
    var found_fill = false;
    for (scene.written()) |command| switch (command) {
        .rect => |rect| found_shadow = found_shadow or rect.mode == .shadow,
        .icon_quad => |quad| if (quad.icon_id == icon_pack.cursor_pointer_2_icon_id) {
            found_outline = found_outline or std.meta.eql(quad.color, outline);
            found_fill = found_fill or std.meta.eql(quad.color, color);
        },
        else => {},
    };

    try std.testing.expect(found_shadow);
    try std.testing.expect(found_outline);
    try std.testing.expect(found_fill);
}
