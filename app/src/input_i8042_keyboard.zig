const std = @import("std");
const app_input_event = @import("input/event.zig");

pub const source_name = "framework13-i8042-at-translated-set2";
pub const resource_id = "framework13-i8042-keyboard";

pub const Error = error{
    EventBufferTooSmall,
};

const scancode_extended_prefix: u8 = 0xe0;
const scancode_release_mask: u8 = 0x80;
const scancode_code_mask: u8 = 0x7f;

const sc_escape: u8 = 0x01;
const sc_1: u8 = 0x02;
const sc_2: u8 = 0x03;
const sc_3: u8 = 0x04;
const sc_4: u8 = 0x05;
const sc_5: u8 = 0x06;
const sc_6: u8 = 0x07;
const sc_7: u8 = 0x08;
const sc_8: u8 = 0x09;
const sc_9: u8 = 0x0a;
const sc_0: u8 = 0x0b;
const sc_minus: u8 = 0x0c;
const sc_equal: u8 = 0x0d;
const sc_backspace: u8 = 0x0e;
const sc_tab: u8 = 0x0f;
const sc_q: u8 = 0x10;
const sc_w: u8 = 0x11;
const sc_e: u8 = 0x12;
const sc_r: u8 = 0x13;
const sc_t: u8 = 0x14;
const sc_y: u8 = 0x15;
const sc_u: u8 = 0x16;
const sc_i: u8 = 0x17;
const sc_o: u8 = 0x18;
const sc_p: u8 = 0x19;
const sc_left_bracket: u8 = 0x1a;
const sc_right_bracket: u8 = 0x1b;
const sc_enter: u8 = 0x1c;
const sc_left_ctrl: u8 = 0x1d;
const sc_a: u8 = 0x1e;
const sc_s: u8 = 0x1f;
const sc_d: u8 = 0x20;
const sc_f: u8 = 0x21;
const sc_g: u8 = 0x22;
const sc_h: u8 = 0x23;
const sc_j: u8 = 0x24;
const sc_k: u8 = 0x25;
const sc_l: u8 = 0x26;
const sc_semicolon: u8 = 0x27;
const sc_quote: u8 = 0x28;
const sc_backquote: u8 = 0x29;
const sc_left_shift: u8 = 0x2a;
const sc_backslash: u8 = 0x2b;
const sc_z: u8 = 0x2c;
const sc_x: u8 = 0x2d;
const sc_c: u8 = 0x2e;
const sc_v: u8 = 0x2f;
const sc_b: u8 = 0x30;
const sc_n: u8 = 0x31;
const sc_m: u8 = 0x32;
const sc_comma: u8 = 0x33;
const sc_period: u8 = 0x34;
const sc_slash: u8 = 0x35;
const sc_right_shift: u8 = 0x36;
const sc_left_alt: u8 = 0x38;
const sc_space: u8 = 0x39;
const sc_caps_lock: u8 = 0x3a;
const sc_home: u8 = 0x47;
const sc_arrow_up: u8 = 0x48;
const sc_page_up: u8 = 0x49;
const sc_arrow_left: u8 = 0x4b;
const sc_arrow_right: u8 = 0x4d;
const sc_end: u8 = 0x4f;
const sc_arrow_down: u8 = 0x50;
const sc_page_down: u8 = 0x51;
const sc_insert: u8 = 0x52;
const sc_delete: u8 = 0x53;
const sc_left_meta: u8 = 0x5b;
const sc_right_meta: u8 = 0x5c;

pub const State = struct {
    extended: bool = false,
    left_shift: bool = false,
    right_shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    meta: bool = false,
    caps_lock: bool = false,

    pub fn reset(self: *State) void {
        self.* = .{};
    }

    pub fn pushByte(self: *State, byte: u8, out: []u8) Error!usize {
        if (byte == scancode_extended_prefix) {
            self.extended = true;
            return 0;
        }

        const extended = self.extended;
        self.extended = false;
        const released = (byte & scancode_release_mask) != 0;
        const code = byte & scancode_code_mask;

        if (self.updateModifier(code, extended, released)) return try self.writeEvent(out, code, extended, released);
        const key = keyFor(code, extended, self.shiftActive(), self.caps_lock) orelse return 0;
        return try self.writeKeyEvent(out, if (released) .key_up else .key_down, key.key, key.code);
    }

    fn updateModifier(self: *State, code: u8, extended: bool, released: bool) bool {
        switch (code) {
            sc_left_shift => {
                if (!extended) {
                    self.left_shift = !released;
                    return true;
                }
                return false;
            },
            sc_right_shift => {
                if (!extended) {
                    self.right_shift = !released;
                    return true;
                }
                return false;
            },
            sc_left_ctrl => {
                self.ctrl = !released;
                return true;
            },
            sc_left_alt => {
                self.alt = !released;
                return true;
            },
            sc_left_meta, sc_right_meta => {
                if (extended) {
                    self.meta = !released;
                    return true;
                }
                return false;
            },
            sc_caps_lock => {
                if (!released and !extended) self.caps_lock = !self.caps_lock;
                return true;
            },
            else => return false,
        }
    }

    fn writeEvent(self: State, out: []u8, code: u8, extended: bool, released: bool) Error!usize {
        const key = keyFor(code, extended, self.shiftActive(), self.caps_lock) orelse return 0;
        return self.writeKeyEvent(out, if (released) .key_up else .key_down, key.key, key.code);
    }

    fn writeKeyEvent(self: State, out: []u8, kind: app_input_event.Kind, key: []const u8, code: []const u8) Error!usize {
        return app_input_event.writeBytes(out, kind, 0.0, 0.0, 0.0, self.flags(), key, code, "", "") catch error.EventBufferTooSmall;
    }

    fn flags(self: State) u32 {
        var out: u32 = 0;
        if (self.ctrl) out |= app_input_event.flag_ctrl;
        if (self.meta) out |= app_input_event.flag_meta;
        if (self.alt) out |= app_input_event.flag_alt;
        if (self.shiftActive()) out |= app_input_event.flag_shift;
        return out;
    }

    fn shiftActive(self: State) bool {
        return self.left_shift or self.right_shift;
    }
};

const Key = struct {
    key: []const u8,
    code: []const u8,
};

fn keyFor(code: u8, extended: bool, shifted: bool, caps_lock: bool) ?Key {
    if (extended) return extendedKeyFor(code);
    return switch (code) {
        sc_escape => named("Escape", "Escape"),
        sc_1 => printable(if (shifted) "!" else "1", "Digit1"),
        sc_2 => printable(if (shifted) "@" else "2", "Digit2"),
        sc_3 => printable(if (shifted) "#" else "3", "Digit3"),
        sc_4 => printable(if (shifted) "$" else "4", "Digit4"),
        sc_5 => printable(if (shifted) "%" else "5", "Digit5"),
        sc_6 => printable(if (shifted) "^" else "6", "Digit6"),
        sc_7 => printable(if (shifted) "&" else "7", "Digit7"),
        sc_8 => printable(if (shifted) "*" else "8", "Digit8"),
        sc_9 => printable(if (shifted) "(" else "9", "Digit9"),
        sc_0 => printable(if (shifted) ")" else "0", "Digit0"),
        sc_minus => printable(if (shifted) "_" else "-", "Minus"),
        sc_equal => printable(if (shifted) "+" else "=", "Equal"),
        sc_backspace => named("Backspace", "Backspace"),
        sc_tab => named("Tab", "Tab"),
        sc_q => letter("q", shifted, caps_lock),
        sc_w => letter("w", shifted, caps_lock),
        sc_e => letter("e", shifted, caps_lock),
        sc_r => letter("r", shifted, caps_lock),
        sc_t => letter("t", shifted, caps_lock),
        sc_y => letter("y", shifted, caps_lock),
        sc_u => letter("u", shifted, caps_lock),
        sc_i => letter("i", shifted, caps_lock),
        sc_o => letter("o", shifted, caps_lock),
        sc_p => letter("p", shifted, caps_lock),
        sc_left_bracket => printable(if (shifted) "{" else "[", "BracketLeft"),
        sc_right_bracket => printable(if (shifted) "}" else "]", "BracketRight"),
        sc_enter => named("Enter", "Enter"),
        sc_left_ctrl => named("Control", "ControlLeft"),
        sc_a => letter("a", shifted, caps_lock),
        sc_s => letter("s", shifted, caps_lock),
        sc_d => letter("d", shifted, caps_lock),
        sc_f => letter("f", shifted, caps_lock),
        sc_g => letter("g", shifted, caps_lock),
        sc_h => letter("h", shifted, caps_lock),
        sc_j => letter("j", shifted, caps_lock),
        sc_k => letter("k", shifted, caps_lock),
        sc_l => letter("l", shifted, caps_lock),
        sc_semicolon => printable(if (shifted) ":" else ";", "Semicolon"),
        sc_quote => printable(if (shifted) "\"" else "'", "Quote"),
        sc_backquote => printable(if (shifted) "~" else "`", "Backquote"),
        sc_left_shift => named("Shift", "ShiftLeft"),
        sc_backslash => printable(if (shifted) "|" else "\\", "Backslash"),
        sc_z => letter("z", shifted, caps_lock),
        sc_x => letter("x", shifted, caps_lock),
        sc_c => letter("c", shifted, caps_lock),
        sc_v => letter("v", shifted, caps_lock),
        sc_b => letter("b", shifted, caps_lock),
        sc_n => letter("n", shifted, caps_lock),
        sc_m => letter("m", shifted, caps_lock),
        sc_comma => printable(if (shifted) "<" else ",", "Comma"),
        sc_period => printable(if (shifted) ">" else ".", "Period"),
        sc_slash => printable(if (shifted) "?" else "/", "Slash"),
        sc_right_shift => named("Shift", "ShiftRight"),
        sc_left_alt => named("Alt", "AltLeft"),
        sc_space => printable(" ", "Space"),
        sc_caps_lock => named("CapsLock", "CapsLock"),
        else => null,
    };
}

fn extendedKeyFor(code: u8) ?Key {
    return switch (code) {
        sc_left_ctrl => named("Control", "ControlRight"),
        sc_left_alt => named("Alt", "AltRight"),
        sc_home => named("Home", "Home"),
        sc_arrow_up => named("ArrowUp", "ArrowUp"),
        sc_page_up => named("PageUp", "PageUp"),
        sc_arrow_left => named("ArrowLeft", "ArrowLeft"),
        sc_arrow_right => named("ArrowRight", "ArrowRight"),
        sc_end => named("End", "End"),
        sc_arrow_down => named("ArrowDown", "ArrowDown"),
        sc_page_down => named("PageDown", "PageDown"),
        sc_insert => named("Insert", "Insert"),
        sc_delete => named("Delete", "Delete"),
        sc_left_meta => named("Meta", "MetaLeft"),
        sc_right_meta => named("Meta", "MetaRight"),
        else => null,
    };
}

fn named(key: []const u8, code: []const u8) Key {
    return .{ .key = key, .code = code };
}

fn printable(key: []const u8, code: []const u8) Key {
    return .{ .key = key, .code = code };
}

fn letter(lower: []const u8, shifted: bool, caps_lock: bool) Key {
    const upper = switch (lower[0]) {
        'a' => "A",
        'b' => "B",
        'c' => "C",
        'd' => "D",
        'e' => "E",
        'f' => "F",
        'g' => "G",
        'h' => "H",
        'i' => "I",
        'j' => "J",
        'k' => "K",
        'l' => "L",
        'm' => "M",
        'n' => "N",
        'o' => "O",
        'p' => "P",
        'q' => "Q",
        'r' => "R",
        's' => "S",
        't' => "T",
        'u' => "U",
        'v' => "V",
        'w' => "W",
        'x' => "X",
        'y' => "Y",
        'z' => "Z",
        else => lower,
    };
    return .{ .key = if (shifted != caps_lock) upper else lower, .code = letterCode(lower[0]) };
}

fn letterCode(byte: u8) []const u8 {
    return switch (byte) {
        'a' => "KeyA",
        'b' => "KeyB",
        'c' => "KeyC",
        'd' => "KeyD",
        'e' => "KeyE",
        'f' => "KeyF",
        'g' => "KeyG",
        'h' => "KeyH",
        'i' => "KeyI",
        'j' => "KeyJ",
        'k' => "KeyK",
        'l' => "KeyL",
        'm' => "KeyM",
        'n' => "KeyN",
        'o' => "KeyO",
        'p' => "KeyP",
        'q' => "KeyQ",
        'r' => "KeyR",
        's' => "KeyS",
        't' => "KeyT",
        'u' => "KeyU",
        'v' => "KeyV",
        'w' => "KeyW",
        'x' => "KeyX",
        'y' => "KeyY",
        'z' => "KeyZ",
        else => "",
    };
}

fn decodeOne(state: *State, byte: u8, out: []u8) !?app_input_event.Record {
    const len = try state.pushByte(byte, out);
    if (len == 0) return null;
    return try app_input_event.parseBytes(out[0..len]);
}

test "i8042 keyboard decodes Framework translated letter input to canonical event bytes" {
    var state = State{};
    var out: [128]u8 = undefined;

    const record = (try decodeOne(&state, sc_a, &out)).?;

    try std.testing.expectEqual(app_input_event.Kind.key_down, record.kind);
    try std.testing.expectEqualStrings("a", record.key);
    try std.testing.expectEqualStrings("KeyA", record.code);
    try std.testing.expectEqual(@as(u32, 0), record.shift);
}

test "i8042 keyboard tracks modifiers before emitting shifted text" {
    var state = State{};
    var out: [128]u8 = undefined;

    const shift = (try decodeOne(&state, sc_left_shift, &out)).?;
    try std.testing.expectEqual(app_input_event.Kind.key_down, shift.kind);
    try std.testing.expectEqualStrings("Shift", shift.key);
    try std.testing.expectEqual(@as(u32, 1), shift.shift);

    const letter_record = (try decodeOne(&state, sc_a, &out)).?;
    try std.testing.expectEqualStrings("A", letter_record.key);
    try std.testing.expectEqual(@as(u32, 1), letter_record.shift);

    const release_shift = (try decodeOne(&state, sc_left_shift | scancode_release_mask, &out)).?;
    try std.testing.expectEqual(app_input_event.Kind.key_up, release_shift.kind);
    try std.testing.expectEqual(@as(u32, 0), release_shift.shift);
}

test "i8042 keyboard decodes extended arrows and release events" {
    var state = State{};
    var out: [128]u8 = undefined;

    try std.testing.expect(try decodeOne(&state, scancode_extended_prefix, &out) == null);
    const down = (try decodeOne(&state, sc_arrow_up, &out)).?;
    try std.testing.expectEqual(app_input_event.Kind.key_down, down.kind);
    try std.testing.expectEqualStrings("ArrowUp", down.key);

    try std.testing.expect(try decodeOne(&state, scancode_extended_prefix, &out) == null);
    const up = (try decodeOne(&state, sc_arrow_up | scancode_release_mask, &out)).?;
    try std.testing.expectEqual(app_input_event.Kind.key_up, up.kind);
    try std.testing.expectEqualStrings("ArrowUp", up.key);
}

test "i8042 keyboard toggles caps lock deterministically" {
    var state = State{};
    var out: [128]u8 = undefined;

    _ = try decodeOne(&state, sc_caps_lock, &out);
    const capped = (try decodeOne(&state, sc_a, &out)).?;
    try std.testing.expectEqualStrings("A", capped.key);

    _ = try decodeOne(&state, sc_caps_lock, &out);
    const lower = (try decodeOne(&state, sc_a, &out)).?;
    try std.testing.expectEqualStrings("a", lower.key);
}
