const input_i8042_keyboard = @import("input_i8042_keyboard.zig");

const abi_version: u32 = 1;
const event_buffer_bytes: usize = 128;
const status_ok: u32 = 0;
const status_bad_byte: u32 = 1;
const status_event_too_large: u32 = 2;

var state: input_i8042_keyboard.State = .{};
var event_bytes: [event_buffer_bytes]u8 = undefined;
var event_len: usize = 0;

export fn er_keyboard_driver_abi_version() u32 {
    return abi_version;
}

export fn er_keyboard_driver_source_name_ptr() usize {
    return @intFromPtr(input_i8042_keyboard.source_name.ptr);
}

export fn er_keyboard_driver_source_name_len() usize {
    return input_i8042_keyboard.source_name.len;
}

export fn er_keyboard_driver_event_ptr() usize {
    return @intFromPtr(event_bytes[0..].ptr);
}

export fn er_keyboard_driver_event_len() usize {
    return event_len;
}

export fn er_keyboard_driver_event_capacity() usize {
    return event_bytes.len;
}

export fn er_keyboard_driver_reset() void {
    state.reset();
    event_len = 0;
}

export fn er_keyboard_driver_push_i8042_byte(byte: u32) u32 {
    if (byte > 0xff) {
        event_len = 0;
        return status_bad_byte;
    }
    event_len = state.pushByte(@intCast(byte), &event_bytes) catch {
        event_len = 0;
        return status_event_too_large;
    };
    return status_ok;
}
