const std = @import("std");
const Component = @import("ui/components/Component.zig").Component;
const ui = @import("ui.zig");
const clock = @import("clock.zig");
const common = @import("ui_component_common.zig");
const layout_types = @import("layouts/Types.zig");
const object = @import("object.zig");
const component_codec = @import("ui/components/Codec.zig");

const max_components: usize = 64;
const max_commands: usize = 1024;
const ui_buf_size: usize = 256;
const canonical_buf_size: usize = 1024;

var slots: [max_components]Component = undefined;
var slots_valid: [max_components]bool = [_]bool{false} ** max_components;
var command_storage: [max_commands]ui.Command = undefined;
var ui_out: [ui_buf_size]u8 = undefined;
var canonical_out: [canonical_buf_size]u8 = undefined;
var epoch: clock.Stamp = .{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };

fn findFreeSlot() ?usize {
    for (&slots_valid, 0..) |*valid, i| {
        if (!valid.*) {
            valid.* = true;
            slots[i] = undefined;
            return i;
        }
    }
    return null;
}

fn stringFromWasm(ptr: [*]const u8, len: u32) []const u8 {
    return ptr[0..len];
}

export fn er_ui_wasm_version() u32 {
    return 1;
}

export fn er_ui_wasm_max_slots() u32 {
    return max_components;
}

export fn er_ui_wasm_slot_count() u32 {
    var count: u32 = 0;
    for (&slots_valid) |valid| {
        if (valid) count += 1;
    }
    return count;
}

export fn er_ui_wasm_alloc() i32 {
    const slot = findFreeSlot() orelse return -1;
    return @intCast(slot);
}

export fn er_ui_wasm_free(idx: u32) i32 {
    if (idx >= max_components) return -1;
    if (!slots_valid[idx]) return -1;
    slots_valid[idx] = false;
    return 0;
}

export fn er_ui_wasm_clear() void {
    for (&slots_valid) |*v| v.* = false;
}

export fn er_ui_wasm_deserialize(ptr: [*]const u8, len: u32) i32 {
    const slot = findFreeSlot() orelse return -1;
    const bytes = ptr[0..len];
    slots[slot] = Component.fromObject(bytes) catch {
        slots_valid[slot] = false;
        return -1;
    };
    slots_valid[slot] = true;
    return @intCast(slot);
}

export fn er_ui_wasm_serialize(idx: u32, out_ptr: [*]u8, out_cap: u32) i32 {
    if (idx >= max_components or !slots_valid[idx]) return -1;
    @memset(&ui_out, 0);
    @memset(&canonical_out, 0);
    const canonical = slots[idx].toObject(&ui_out, &canonical_out, epoch) orelse return -1;
    if (canonical.len > out_cap) return -1;
    @memcpy(out_ptr[0..canonical.len], canonical);
    return @intCast(canonical.len);
}

export fn er_ui_wasm_render(idx: u32, cmd_out_ptr: [*]u8, cmd_out_cap: u32, x: f32, y: f32, w: f32, h: f32) i32 {
    _ = cmd_out_ptr;
    _ = cmd_out_cap;
    if (idx >= max_components or !slots_valid[idx]) return -1;
    var scene = ui.Scene.init(&command_storage);
    const bounds = ui.Rect.init(x, y, w, h);
    slots[idx].render(&scene, bounds, .{}) catch return -1;
    const commands = scene.written();
    return @intCast(commands.len);
}

export fn er_ui_wasm_measure(idx: u32, w: f32, h: f32) u64 {
    if (idx >= max_components or !slots_valid[idx]) return 0;
    const constraints = layout_types.Constraints{
        .width = if (w >= 0) .{ .at_most = w } else .unconstrained,
        .height = if (h >= 0) .{ .at_most = h } else .unconstrained,
    };
    const measurement = slots[idx].measure(constraints, .{});
    const w_bits: u32 = @bitCast(@as(f32, @floatCast(measurement.preferred.w)));
    const h_bits: u32 = @bitCast(@as(f32, @floatCast(measurement.preferred.h)));
    return (@as(u64, w_bits) << 32) | h_bits;
}

export fn er_ui_wasm_new_text(slot: u32, value_ptr: [*]const u8, value_len: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const value = stringFromWasm(value_ptr, value_len);
    slots[slot] = Component{ .text = .{ .value = value } };
    slots_valid[slot] = true;
    return 0;
}

export fn er_ui_wasm_new_button(slot: u32, id: u32, label_ptr: [*]const u8, label_len: u32, variant: u32, leading_icon: u32, trailing_icon: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const label = stringFromWasm(label_ptr, label_len);
    slots[slot] = Component.fromNode(ui.buttonDetailNode(
        id, label, @intCast(variant), @intCast(leading_icon), @intCast(trailing_icon),
    )) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_row_item(slot: u32, id: u32, title_ptr: [*]const u8, title_len: u32, detail_ptr: [*]const u8, detail_len: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const title = stringFromWasm(title_ptr, title_len);
    const detail = stringFromWasm(detail_ptr, detail_len);
    const node = ui.Node{ .row_item = .{ .id = id, .title = title, .detail = detail } };
    slots[slot] = Component.fromNode(node) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_badge(slot: u32, label_ptr: [*]const u8, label_len: u32, variant: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const label = stringFromWasm(label_ptr, label_len);
    slots[slot] = Component.fromNode(ui.badgeVariantNode(label, @intCast(variant))) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_checkbox(slot: u32, id: u32, label_ptr: [*]const u8, label_len: u32, checked: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const label = stringFromWasm(label_ptr, label_len);
    slots[slot] = Component.fromNode(ui.checkboxNode(id, label, checked != 0)) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_input(slot: u32, id: u32, placeholder_ptr: [*]const u8, placeholder_len: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const placeholder = stringFromWasm(placeholder_ptr, placeholder_len);
    slots[slot] = Component.fromNode(ui.inputNode(id, placeholder)) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_slider(slot: u32, id: u32, label_ptr: [*]const u8, label_len: u32, value: f32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const label = stringFromWasm(label_ptr, label_len);
    slots[slot] = Component.fromNode(ui.sliderNode(id, label, value)) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_card(slot: u32, title_ptr: [*]const u8, title_len: u32, detail_ptr: [*]const u8, detail_len: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const title = stringFromWasm(title_ptr, title_len);
    const detail = stringFromWasm(detail_ptr, detail_len);
    slots[slot] = Component.fromNode(ui.cardVariantNode(title, detail, 0)) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_separator(slot: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    slots[slot] = Component.fromNode(ui.separatorNode()) catch return -1;
    return 0;
}

export fn er_ui_wasm_new_icon(slot: u32, label_ptr: [*]const u8, label_len: u32, icon_value: u32) i32 {
    if (slot >= max_components or !slots_valid[slot]) return -1;
    const label = stringFromWasm(label_ptr, label_len);
    slots[slot] = Component.fromNode(ui.iconNode(label, @intCast(icon_value))) catch return -1;
    return 0;
}
