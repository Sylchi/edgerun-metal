const std = @import("std");
const ui = @import("../ui.zig");
const image = @import("common.zig");

const marker_prefix: u8 = 0xff;
const marker_soi: u8 = 0xd8;
const marker_eoi: u8 = 0xd9;
const marker_sos: u8 = 0xda;
const marker_dqt: u8 = 0xdb;
const marker_dht: u8 = 0xc4;
const marker_dac: u8 = 0xcc;
const marker_dri: u8 = 0xdd;
const marker_sof0: u8 = 0xc0;
const marker_sof2: u8 = 0xc2;
const marker_rst0: u8 = 0xd0;
const marker_rst7: u8 = 0xd7;

const block_side: usize = 8;
const block_len: usize = block_side * block_side;
const max_components: usize = 3;
const max_sampling_factor: usize = 2;
const max_component_blocks: usize = max_sampling_factor * max_sampling_factor;
const max_tables: usize = 4;
const max_huffman_symbols: usize = 256;
const max_code_len: u8 = 16;
const jpeg_precision_8: u8 = 8;
const jpeg_dc_class: u8 = 0;
const jpeg_ac_class: u8 = 1;
const jpeg_alpha_opaque: u8 = 255;
const byte_bits: u4 = 8;

const zigzag = [_]usize{
    0,  1,  8,  16, 9,  2,  3,  10,
    17, 24, 32, 25, 18, 11, 4,  5,
    12, 19, 26, 33, 40, 48, 41, 34,
    27, 20, 13, 6,  7,  14, 21, 28,
    35, 42, 49, 56, 57, 50, 43, 36,
    29, 22, 15, 23, 30, 37, 44, 51,
    58, 59, 52, 45, 38, 31, 39, 46,
    53, 60, 61, 54, 47, 55, 62, 63,
};

pub fn isJpeg(bytes: []const u8) bool {
    return bytes.len >= 2 and bytes[0] == marker_prefix and bytes[1] == marker_soi;
}

pub fn decodeHeader(bytes: []const u8) image.DecodeError!image.Header {
    var state: State = .{};
    _ = try parse(bytes, &state, false);
    if (!state.have_frame) return error.BadImage;
    return .{ .width = state.width, .height = state.height };
}

pub fn decode(bytes: []const u8, out: []ui.Color) image.DecodeError!image.Header {
    var state: State = .{};
    const scan = try parse(bytes, &state, true);
    if (!state.have_frame or scan.len == 0) return error.BadImage;
    const count = state.width * state.height;
    if (out.len < count) return error.PixelBudget;
    try decodeScan(&state, scan, out[0..count]);
    return .{ .width = state.width, .height = state.height };
}

const Component = struct {
    id: u8 = 0,
    sampling: u8 = 0,
    quant_id: u8 = 0,
    dc_table: u8 = 0,
    ac_table: u8 = 0,
    previous_dc: i16 = 0,

    fn h(self: Component) usize {
        return self.sampling >> 4;
    }

    fn v(self: Component) usize {
        return self.sampling & 0x0f;
    }
};

const HuffmanSymbol = struct {
    code: u16 = 0,
    len: u8 = 0,
    value: u8 = 0,
};

const HuffmanTable = struct {
    symbols: [max_huffman_symbols]HuffmanSymbol = [_]HuffmanSymbol{.{}} ** max_huffman_symbols,
    len: usize = 0,
    ready: bool = false,

    fn decode(self: *const HuffmanTable, reader: *BitReader) image.DecodeError!u8 {
        if (!self.ready) return error.BadImage;
        var code: u16 = 0;
        var len: u8 = 1;
        while (len <= max_code_len) : (len += 1) {
            code = (code << 1) | try reader.readBit();
            var index: usize = 0;
            while (index < self.len) : (index += 1) {
                const symbol = self.symbols[index];
                if (symbol.len == len and symbol.code == code) return symbol.value;
            }
        }
        return error.BadImage;
    }
};

const State = struct {
    width: usize = 0,
    height: usize = 0,
    components: [max_components]Component = [_]Component{.{}} ** max_components,
    component_count: usize = 0,
    max_h: usize = 1,
    max_v: usize = 1,
    quant: [max_tables][block_len]u16 = [_][block_len]u16{[_]u16{0} ** block_len} ** max_tables,
    quant_ready: [max_tables]bool = [_]bool{false} ** max_tables,
    dc: [max_tables]HuffmanTable = [_]HuffmanTable{.{}} ** max_tables,
    ac: [max_tables]HuffmanTable = [_]HuffmanTable{.{}} ** max_tables,
    restart_interval: usize = 0,
    have_frame: bool = false,

    fn componentIndexById(self: *const State, id: u8) image.DecodeError!usize {
        var index: usize = 0;
        while (index < self.component_count) : (index += 1) {
            if (self.components[index].id == id) return index;
        }
        return error.BadImage;
    }
};

fn parse(bytes: []const u8, state: *State, need_scan: bool) image.DecodeError![]const u8 {
    if (!isJpeg(bytes)) return error.UnsupportedImage;
    var cursor: usize = 2;
    while (cursor < bytes.len) {
        const marker = try nextMarker(bytes, &cursor);
        switch (marker) {
            marker_eoi => return if (need_scan) error.BadImage else &.{},
            marker_soi => return error.BadImage,
            marker_rst0...marker_rst7 => return error.BadImage,
            marker_dqt => try parseDqt(bytes, &cursor, state),
            marker_dht => try parseDht(bytes, &cursor, state),
            marker_dac => return error.UnsupportedImage,
            marker_dri => try parseDri(bytes, &cursor, state),
            marker_sof0 => try parseSof0(bytes, &cursor, state),
            marker_sof2 => return error.UnsupportedImage,
            marker_sos => {
                const scan = try parseSos(bytes, &cursor, state);
                return scan;
            },
            else => if (isUnsupportedFrameMarker(marker)) return error.UnsupportedImage else try skipSegment(bytes, &cursor),
        }
    }
    return error.BadImage;
}

fn isUnsupportedFrameMarker(marker: u8) bool {
    return switch (marker) {
        0xc1, 0xc3, 0xc5...0xcb, 0xcd...0xcf => true,
        else => false,
    };
}

fn parseDri(bytes: []const u8, cursor: *usize, state: *State) image.DecodeError!void {
    const payload = try segment(bytes, cursor);
    if (payload.len != 2) return error.BadImage;
    state.restart_interval = readU16Be(payload[0..2]);
}

fn nextMarker(bytes: []const u8, cursor: *usize) image.DecodeError!u8 {
    while (cursor.* < bytes.len and bytes[cursor.*] != marker_prefix) cursor.* += 1;
    if (cursor.* >= bytes.len) return error.BadImage;
    while (cursor.* < bytes.len and bytes[cursor.*] == marker_prefix) cursor.* += 1;
    if (cursor.* >= bytes.len) return error.BadImage;
    const marker = bytes[cursor.*];
    cursor.* += 1;
    if (marker == 0) return error.BadImage;
    return marker;
}

fn segment(bytes: []const u8, cursor: *usize) image.DecodeError![]const u8 {
    if (bytes.len - cursor.* < 2) return error.BadImage;
    const len: usize = readU16Be(bytes[cursor.*..][0..2]);
    if (len < 2 or len > bytes.len - cursor.*) return error.BadImage;
    const payload = bytes[cursor.* + 2 .. cursor.* + len];
    cursor.* += len;
    return payload;
}

fn skipSegment(bytes: []const u8, cursor: *usize) image.DecodeError!void {
    _ = try segment(bytes, cursor);
}

fn parseDqt(bytes: []const u8, cursor: *usize, state: *State) image.DecodeError!void {
    const payload = try segment(bytes, cursor);
    var pos: usize = 0;
    while (pos < payload.len) {
        const info = payload[pos];
        pos += 1;
        const precision = info >> 4;
        const table_id: usize = info & 0x0f;
        if (precision != 0 or table_id >= max_tables) return error.UnsupportedImage;
        if (payload.len - pos < block_len) return error.BadImage;
        var index: usize = 0;
        while (index < block_len) : (index += 1) state.quant[table_id][index] = payload[pos + index];
        state.quant_ready[table_id] = true;
        pos += block_len;
    }
}

fn parseDht(bytes: []const u8, cursor: *usize, state: *State) image.DecodeError!void {
    const payload = try segment(bytes, cursor);
    var pos: usize = 0;
    while (pos < payload.len) {
        const info = payload[pos];
        pos += 1;
        const class = info >> 4;
        const table_id: usize = info & 0x0f;
        if (class > jpeg_ac_class or table_id >= max_tables) return error.UnsupportedImage;
        if (payload.len - pos < max_code_len) return error.BadImage;
        const counts = payload[pos..][0..max_code_len];
        pos += max_code_len;
        var total: usize = 0;
        for (counts) |count| total += count;
        if (total == 0) return error.BadImage;
        if (total > max_huffman_symbols or payload.len - pos < total) return error.BadImage;
        const table = if (class == jpeg_dc_class) &state.dc[table_id] else &state.ac[table_id];
        try buildHuffmanTable(counts, payload[pos..][0..total], table);
        pos += total;
    }
}

fn buildHuffmanTable(counts: []const u8, values: []const u8, table: *HuffmanTable) image.DecodeError!void {
    table.* = .{};
    var slots: i32 = 1;
    var code: u16 = 0;
    var value_index: usize = 0;
    var len: u8 = 1;
    while (len <= max_code_len) : (len += 1) {
        const count = counts[len - 1];
        slots = slots * 2 - count;
        if (slots < 0) return error.BadImage;
        var index: usize = 0;
        while (index < count) : (index += 1) {
            if (value_index >= values.len) return error.BadImage;
            table.symbols[table.len] = .{ .code = code, .len = len, .value = values[value_index] };
            table.len += 1;
            value_index += 1;
            code += 1;
        }
        code <<= 1;
    }
    if (value_index != values.len) return error.BadImage;
    table.ready = true;
}

fn parseSof0(bytes: []const u8, cursor: *usize, state: *State) image.DecodeError!void {
    if (state.have_frame) return error.BadImage;
    const payload = try segment(bytes, cursor);
    if (payload.len < 6) return error.BadImage;
    if (payload[0] != jpeg_precision_8) return error.UnsupportedImage;
    const height = readU16Be(payload[1..][0..2]);
    const width = readU16Be(payload[3..][0..2]);
    const count: usize = payload[5];
    if (width == 0 or height == 0 or count == 0) return error.BadImage;
    if (count > max_components) return error.UnsupportedImage;
    if (payload.len != 6 + count * 3) return error.BadImage;
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const offset = 6 + index * 3;
        const id = payload[offset];
        var previous: usize = 0;
        while (previous < index) : (previous += 1) {
            if (state.components[previous].id == id) return error.BadImage;
        }
        const sampling = payload[offset + 1];
        const h = sampling >> 4;
        const v = sampling & 0x0f;
        if (h == 0 or v == 0 or h > max_sampling_factor or v > max_sampling_factor) return error.UnsupportedImage;
        const quant_id = payload[offset + 2];
        if (quant_id >= max_tables) return error.BadImage;
        state.max_h = @max(state.max_h, h);
        state.max_v = @max(state.max_v, v);
        state.components[index] = .{
            .id = id,
            .sampling = sampling,
            .quant_id = quant_id,
        };
    }
    state.width = width;
    state.height = height;
    state.component_count = count;
    try validateSampling(state);
    state.have_frame = true;
}

fn validateSampling(state: *const State) image.DecodeError!void {
    if (state.component_count == 1) {
        if (state.components[0].h() != 1 or state.components[0].v() != 1) return error.UnsupportedImage;
        return;
    }
    if (state.component_count != 3) return error.UnsupportedImage;
    for (state.components[0..state.component_count]) |component| {
        if (state.max_h % component.h() != 0 or state.max_v % component.v() != 0) return error.UnsupportedImage;
    }
}

fn parseSos(bytes: []const u8, cursor: *usize, state: *State) image.DecodeError![]const u8 {
    if (!state.have_frame) return error.BadImage;
    const payload = try segment(bytes, cursor);
    if (payload.len < 4) return error.BadImage;
    const count: usize = payload[0];
    if (count != state.component_count or payload.len != 1 + count * 2 + 3) return error.BadImage;
    var seen = [_]bool{false} ** max_components;
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const component_index = try state.componentIndexById(payload[1 + index * 2]);
        if (seen[component_index]) return error.BadImage;
        seen[component_index] = true;
        const component = &state.components[component_index];
        const selector = payload[2 + index * 2];
        component.dc_table = selector >> 4;
        component.ac_table = selector & 0x0f;
        if (component.dc_table >= max_tables or component.ac_table >= max_tables) return error.BadImage;
    }
    if (payload[payload.len - 3] != 0 or payload[payload.len - 2] != 63 or payload[payload.len - 1] != 0) {
        return error.UnsupportedImage;
    }
    return bytes[cursor.*..];
}

fn decodeScan(initial_state: *const State, scan: []const u8, out: []ui.Color) image.DecodeError!void {
    var state = initial_state.*;
    for (state.components[0..state.component_count]) |component| {
        if (!state.quant_ready[component.quant_id]) return error.BadImage;
        if (!state.dc[component.dc_table].ready or !state.ac[component.ac_table].ready) return error.BadImage;
    }
    var reader: BitReader = .{ .bytes = scan };
    var blocks: [max_components][max_component_blocks][block_len]i16 =
        [_][max_component_blocks][block_len]i16{[_][block_len]i16{[_]i16{0} ** block_len} ** max_component_blocks} ** max_components;
    const mcu_pixel_width = state.max_h * block_side;
    const mcu_pixel_height = state.max_v * block_side;
    const mcu_w = divCeil(state.width, mcu_pixel_width);
    const mcu_h = divCeil(state.height, mcu_pixel_height);
    const mcu_total = mcu_w * mcu_h;
    var mcu_index: usize = 0;
    var restart_count: usize = 0;
    var expected_restart: u8 = marker_rst0;
    var my: usize = 0;
    while (my < mcu_h) : (my += 1) {
        var mx: usize = 0;
        while (mx < mcu_w) : (mx += 1) {
            var component_index: usize = 0;
            while (component_index < state.component_count) : (component_index += 1) {
                const component = state.components[component_index];
                var by: usize = 0;
                while (by < component.v()) : (by += 1) {
                    var bx: usize = 0;
                    while (bx < component.h()) : (bx += 1) {
                        try decodeBlock(&state, component_index, &reader, &blocks[component_index][by * component.h() + bx]);
                    }
                }
            }
            writeMcu(&state, &blocks, mx * mcu_pixel_width, my * mcu_pixel_height, out);
            mcu_index += 1;
            restart_count += 1;
            if (state.restart_interval != 0 and restart_count == state.restart_interval and mcu_index < mcu_total) {
                try reader.consumeRestart(expected_restart);
                resetDc(&state);
                restart_count = 0;
                expected_restart = if (expected_restart == marker_rst7) marker_rst0 else expected_restart + 1;
            }
        }
    }
    try reader.consumeEoi();
}

fn resetDc(state: *State) void {
    for (state.components[0..state.component_count]) |*component| {
        component.previous_dc = 0;
    }
}

fn decodeBlock(state: *State, component_index: usize, reader: *BitReader, block: *[block_len]i16) image.DecodeError!void {
    @memset(block, 0);
    const component = &state.components[component_index];
    const dc_table = &state.dc[component.dc_table];
    const ac_table = &state.ac[component.ac_table];
    const quant = &state.quant[component.quant_id];
    const dc_len = try dc_table.decode(reader);
    if (dc_len > 11) return error.BadImage;
    const dc_delta = try receiveExtend(reader, dc_len);
    component.previous_dc += dc_delta;
    block[0] = component.previous_dc * @as(i16, @intCast(quant[0]));

    var index: usize = 1;
    while (index < block_len) {
        const symbol = try ac_table.decode(reader);
        if (symbol == 0) break;
        if (symbol == 0xf0) {
            index += 16;
            continue;
        }
        const run = symbol >> 4;
        const size = symbol & 0x0f;
        if (size == 0 or size > 10) return error.BadImage;
        index += run;
        if (index >= block_len) return error.BadImage;
        const coeff = try receiveExtend(reader, size);
        block[zigzag[index]] = coeff * @as(i16, @intCast(quant[index]));
        index += 1;
    }
}

const BitReader = struct {
    bytes: []const u8,
    cursor: usize = 0,
    bit_buffer: u8 = 0,
    bits_left: u4 = 0,

    fn readBit(self: *BitReader) image.DecodeError!u16 {
        if (self.bits_left == 0) {
            self.bit_buffer = try self.nextEntropyByte();
            self.bits_left = byte_bits;
        }
        self.bits_left -= 1;
        return (self.bit_buffer >> @as(u3, @intCast(self.bits_left))) & 1;
    }

    fn readBits(self: *BitReader, count: u8) image.DecodeError!u16 {
        var value: u16 = 0;
        var index: u8 = 0;
        while (index < count) : (index += 1) value = (value << 1) | try self.readBit();
        return value;
    }

    fn nextEntropyByte(self: *BitReader) image.DecodeError!u8 {
        if (self.cursor >= self.bytes.len) return error.BadImage;
        const byte = self.bytes[self.cursor];
        self.cursor += 1;
        if (byte != marker_prefix) return byte;
        if (self.cursor >= self.bytes.len) return error.BadImage;
        const marker = self.bytes[self.cursor];
        self.cursor += 1;
        return switch (marker) {
            0x00 => marker_prefix,
            marker_eoi => error.BadImage,
            marker_rst0...marker_rst7 => error.BadImage,
            else => error.UnsupportedImage,
        };
    }

    fn consumeRestart(self: *BitReader, expected_marker: u8) image.DecodeError!void {
        self.bits_left = 0;
        const marker = try self.consumeMarker();
        if (marker != expected_marker) return error.BadImage;
    }

    fn consumeEoi(self: *BitReader) image.DecodeError!void {
        self.bits_left = 0;
        const marker = try self.consumeMarker();
        if (marker != marker_eoi) return error.BadImage;
        if (self.cursor != self.bytes.len) return error.BadImage;
    }

    fn consumeMarker(self: *BitReader) image.DecodeError!u8 {
        if (self.cursor >= self.bytes.len or self.bytes[self.cursor] != marker_prefix) return error.BadImage;
        while (self.cursor < self.bytes.len and self.bytes[self.cursor] == marker_prefix) self.cursor += 1;
        if (self.cursor >= self.bytes.len) return error.BadImage;
        const marker = self.bytes[self.cursor];
        self.cursor += 1;
        if (marker == 0) return error.BadImage;
        return marker;
    }
};

fn receiveExtend(reader: *BitReader, len: u8) image.DecodeError!i16 {
    if (len == 0) return 0;
    const raw = try reader.readBits(len);
    const threshold: u16 = @as(u16, 1) << @intCast(len - 1);
    if (raw >= threshold) return @intCast(raw);
    const extend: i32 = @as(i32, raw) + 1 - (@as(i32, 1) << @intCast(len));
    return @intCast(extend);
}

fn writeMcu(
    state: *const State,
    blocks: *const [max_components][max_component_blocks][block_len]i16,
    origin_x: usize,
    origin_y: usize,
    out: []ui.Color,
) void {
    const mcu_pixel_width = state.max_h * block_side;
    const mcu_pixel_height = state.max_v * block_side;
    var y: usize = 0;
    while (y < mcu_pixel_height and origin_y + y < state.height) : (y += 1) {
        var x: usize = 0;
        while (x < mcu_pixel_width and origin_x + x < state.width) : (x += 1) {
            const pixel = if (state.component_count == 1)
                grayColor(sampleComponent(state, blocks, 0, x, y))
            else
                ycbcrColor(
                    sampleComponent(state, blocks, 0, x, y),
                    sampleComponent(state, blocks, 1, x, y),
                    sampleComponent(state, blocks, 2, x, y),
                );
            out[(origin_y + y) * state.width + origin_x + x] = pixel;
        }
    }
}

fn sampleComponent(
    state: *const State,
    blocks: *const [max_components][max_component_blocks][block_len]i16,
    component_index: usize,
    mcu_x: usize,
    mcu_y: usize,
) i16 {
    const component = state.components[component_index];
    const sample_x = mcu_x * component.h() / state.max_h;
    const sample_y = mcu_y * component.v() / state.max_v;
    const block_x = sample_x / block_side;
    const block_y = sample_y / block_side;
    const block_index = block_y * component.h() + block_x;
    return idctSample(&blocks[component_index][block_index], sample_x % block_side, sample_y % block_side);
}

fn idctSample(block: *const [block_len]i16, x: usize, y: usize) i16 {
    const pi: f32 = 3.14159265358979323846;
    var sum: f32 = 0;
    var v: usize = 0;
    while (v < block_side) : (v += 1) {
        var u: usize = 0;
        while (u < block_side) : (u += 1) {
            const cu: f32 = if (u == 0) 0.7071067811865476 else 1.0;
            const cv: f32 = if (v == 0) 0.7071067811865476 else 1.0;
            const coeff: f32 = @floatFromInt(block[v * block_side + u]);
            const ux: f32 = @floatFromInt((2 * x + 1) * u);
            const vy: f32 = @floatFromInt((2 * y + 1) * v);
            sum += cu * cv * coeff * @cos(ux * pi / 16.0) * @cos(vy * pi / 16.0);
        }
    }
    return clampI16(@intFromFloat(@round(sum / 4.0 + 128.0)));
}

fn grayColor(value: i16) ui.Color {
    const byte = clampU8(value);
    return .{ .r = byte, .g = byte, .b = byte, .a = jpeg_alpha_opaque };
}

fn ycbcrColor(y: i16, cb: i16, cr: i16) ui.Color {
    const yf: f32 = @floatFromInt(y);
    const cbf: f32 = @as(f32, @floatFromInt(cb)) - 128.0;
    const crf: f32 = @as(f32, @floatFromInt(cr)) - 128.0;
    return .{
        .r = clampU8(@intFromFloat(@round(yf + 1.402 * crf))),
        .g = clampU8(@intFromFloat(@round(yf - 0.344136 * cbf - 0.714136 * crf))),
        .b = clampU8(@intFromFloat(@round(yf + 1.772 * cbf))),
        .a = jpeg_alpha_opaque,
    };
}

fn clampI16(value: i32) i16 {
    if (value < std.math.minInt(i16)) return std.math.minInt(i16);
    if (value > std.math.maxInt(i16)) return std.math.maxInt(i16);
    return @intCast(value);
}

fn clampU8(value: i16) u8 {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return @intCast(value);
}

fn divCeil(value: usize, divisor: usize) usize {
    return (value + divisor - 1) / divisor;
}

fn readU16Be(bytes: *const [2]u8) u16 {
    return (@as(u16, bytes[0]) << 8) | @as(u16, bytes[1]);
}

test "jpeg header parses baseline dimensions" {
    const bytes = testJpegRed();
    try std.testing.expect(isJpeg(bytes));
    const header = try decodeHeader(bytes);
    try std.testing.expectEqual(@as(usize, 8), header.width);
    try std.testing.expectEqual(@as(usize, 8), header.height);
}

test "jpeg decoder produces canonical rgba pixels" {
    const bytes = testJpegRed();
    var pixels: [64]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 8), header.width);
    try std.testing.expectEqual(@as(usize, 8), header.height);
    try std.testing.expect(pixels[0].r > 220);
    try std.testing.expect(pixels[0].g < 32);
    try std.testing.expect(pixels[0].b < 32);
    try std.testing.expectEqual(@as(u8, 255), pixels[0].a);
}

test "jpeg decoder requires entropy stream to end with eoi marker" {
    const bytes = testJpegRed();
    var pixels: [64]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decode(bytes[0 .. bytes.len - 2], &pixels));
}

test "jpeg decoder rejects trailing bytes after eoi marker" {
    const bytes = testJpegRed();
    var with_trailing: [testJpegRed().len + 1]u8 = undefined;
    @memcpy(with_trailing[0..bytes.len], bytes);
    with_trailing[bytes.len] = 0;
    var pixels: [64]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decode(&with_trailing, &pixels));
}

test "jpeg decoder rejects progressive frames explicitly" {
    var bytes = testJpegRed().*;
    replaceMarker(&bytes, marker_sof0, marker_sof2);
    try std.testing.expectError(error.UnsupportedImage, decodeHeader(&bytes));
}

test "jpeg decoder rejects non-baseline frame markers explicitly" {
    var bytes = testJpegRed().*;
    replaceMarker(&bytes, marker_sof0, 0xc1);
    try std.testing.expectError(error.UnsupportedImage, decodeHeader(&bytes));
}

test "jpeg decoder rejects arithmetic coding marker explicitly" {
    var bytes = testJpegRed().*;
    replaceMarker(&bytes, marker_dht, marker_dac);
    try std.testing.expectError(error.UnsupportedImage, decodeHeader(&bytes));
}

test "jpeg decoder rejects standalone restart markers outside entropy data" {
    var bytes = testJpegRed().*;
    replaceMarker(&bytes, marker_dqt, marker_rst0);
    try std.testing.expectError(error.BadImage, decodeHeader(&bytes));
}

test "jpeg decoder rejects repeated frame headers" {
    const bytes = testJpegRed();
    const marker_offset = findMarkerOffset(bytes, marker_sof0);
    const segment_len = readU16Be(bytes[marker_offset + 2 ..][0..2]);
    const duplicate_len = 2 + @as(usize, segment_len);
    var repeated: [testJpegRed().len + 32]u8 = undefined;
    @memcpy(repeated[0 .. marker_offset + duplicate_len], bytes[0 .. marker_offset + duplicate_len]);
    @memcpy(repeated[marker_offset + duplicate_len ..][0..duplicate_len], bytes[marker_offset..][0..duplicate_len]);
    @memcpy(
        repeated[marker_offset + duplicate_len * 2 ..][0 .. bytes.len - marker_offset - duplicate_len],
        bytes[marker_offset + duplicate_len ..],
    );
    try std.testing.expectError(error.BadImage, decodeHeader(repeated[0 .. bytes.len + duplicate_len]));
}

test "jpeg decoder rejects duplicate frame component ids" {
    var bytes = testJpegRed().*;
    const marker_offset = findMarkerOffset(&bytes, marker_sof0);
    const first_id_offset = marker_offset + 2 + 2 + 6;
    const second_id_offset = first_id_offset + 3;
    bytes[second_id_offset] = bytes[first_id_offset];
    try std.testing.expectError(error.BadImage, decodeHeader(&bytes));
}

test "jpeg decoder rejects duplicate scan component ids" {
    var bytes = testJpegRed().*;
    const marker_offset = findMarkerOffset(&bytes, marker_sos);
    const first_id_offset = marker_offset + 2 + 2 + 1;
    const second_id_offset = first_id_offset + 2;
    bytes[second_id_offset] = bytes[first_id_offset];
    var pixels: [64]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decode(&bytes, &pixels));
}

test "jpeg decoder rejects empty huffman tables during parse" {
    var bytes = testJpegRed().*;
    const marker_offset = findMarkerOffset(&bytes, marker_dht);
    const counts_offset = marker_offset + 2 + 2 + 1;
    @memset(bytes[counts_offset..][0..max_code_len], 0);
    try std.testing.expectError(error.BadImage, decodeHeader(&bytes));
}

test "jpeg decoder rejects oversubscribed huffman code trees" {
    var counts = [_]u8{0} ** max_code_len;
    counts[0] = 3;
    var values = [_]u8{ 0, 1, 2 };
    var table: HuffmanTable = .{};
    try std.testing.expectError(error.BadImage, buildHuffmanTable(&counts, &values, &table));
}

test "jpeg decoder supports 4:2:0 chroma subsampling" {
    const bytes = testJpegRed420();
    var pixels: [16 * 16]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 16), header.width);
    try std.testing.expectEqual(@as(usize, 16), header.height);
    try std.testing.expect(pixels[0].r > 220);
    try std.testing.expect(pixels[0].g < 32);
    try std.testing.expect(pixels[0].b < 32);
}

test "jpeg decoder supports 4:2:2 chroma subsampling" {
    const bytes = testJpegGreen422();
    var pixels: [16 * 8]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 16), header.width);
    try std.testing.expectEqual(@as(usize, 8), header.height);
    try std.testing.expect(pixels[0].r < 32);
    try std.testing.expect(pixels[0].g > 220);
    try std.testing.expect(pixels[0].b < 32);
}

test "jpeg decoder consumes restart markers and resets dc predictors" {
    const bytes = testJpegBlueRestart();
    var pixels: [16 * 8]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 16), header.width);
    try std.testing.expectEqual(@as(usize, 8), header.height);
    try std.testing.expect(pixels[0].r < 32);
    try std.testing.expect(pixels[0].g < 32);
    try std.testing.expect(pixels[0].b > 220);
    try std.testing.expect(pixels[15].b > 220);
}

fn replaceMarker(bytes: []u8, from: u8, to: u8) void {
    var index: usize = 0;
    while (index + 1 < bytes.len) : (index += 1) {
        if (bytes[index] == marker_prefix and bytes[index + 1] == from) {
            bytes[index + 1] = to;
            return;
        }
    }
    unreachable;
}

fn findMarkerOffset(bytes: []const u8, marker: u8) usize {
    var index: usize = 0;
    while (index + 1 < bytes.len) : (index += 1) {
        if (bytes[index] == marker_prefix and bytes[index + 1] == marker) return index;
    }
    unreachable;
}

fn testJpegRed() *const [286]u8 {
    return &[_]u8{
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
        0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x04,
        0x03, 0x03, 0x04, 0x05, 0x08, 0x05, 0x05, 0x04, 0x04, 0x05, 0x0a, 0x07,
        0x07, 0x06, 0x08, 0x0c, 0x0a, 0x0c, 0x0c, 0x0b, 0x0a, 0x0b, 0x0b, 0x0d,
        0x0e, 0x12, 0x10, 0x0d, 0x0e, 0x11, 0x0e, 0x0b, 0x0b, 0x10, 0x16, 0x10,
        0x11, 0x13, 0x14, 0x15, 0x15, 0x15, 0x0c, 0x0f, 0x17, 0x18, 0x16, 0x14,
        0x18, 0x12, 0x14, 0x15, 0x14, 0xff, 0xdb, 0x00, 0x43, 0x01, 0x03, 0x04,
        0x04, 0x05, 0x04, 0x05, 0x09, 0x05, 0x05, 0x09, 0x14, 0x0d, 0x0b, 0x0d,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x08, 0x00, 0x08, 0x03,
        0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xff, 0xc4, 0x00,
        0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xff, 0xc4, 0x00, 0x14, 0x10,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xc4, 0x00, 0x15, 0x01, 0x01, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x07, 0x09, 0xff, 0xc4, 0x00, 0x14, 0x11, 0x01, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0xff, 0xda, 0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11, 0x03,
        0x11, 0x00, 0x3f, 0x00, 0x3a, 0x03, 0x15, 0x4d, 0xff, 0xd9,
    };
}

fn testJpegBlueRestart() *const [647]u8 {
    return &[_]u8{
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
        0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x04,
        0x03, 0x03, 0x04, 0x05, 0x08, 0x05, 0x05, 0x04, 0x04, 0x05, 0x0a, 0x07,
        0x07, 0x06, 0x08, 0x0c, 0x0a, 0x0c, 0x0c, 0x0b, 0x0a, 0x0b, 0x0b, 0x0d,
        0x0e, 0x12, 0x10, 0x0d, 0x0e, 0x11, 0x0e, 0x0b, 0x0b, 0x10, 0x16, 0x10,
        0x11, 0x13, 0x14, 0x15, 0x15, 0x15, 0x0c, 0x0f, 0x17, 0x18, 0x16, 0x14,
        0x18, 0x12, 0x14, 0x15, 0x14, 0xff, 0xdb, 0x00, 0x43, 0x01, 0x03, 0x04,
        0x04, 0x05, 0x04, 0x05, 0x09, 0x05, 0x05, 0x09, 0x14, 0x0d, 0x0b, 0x0d,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x08, 0x00, 0x10, 0x03,
        0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xff, 0xc4, 0x00,
        0x1f, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
        0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0xff, 0xc4, 0x00, 0xb5, 0x10, 0x00,
        0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00,
        0x00, 0x01, 0x7d, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21,
        0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81,
        0x91, 0xa1, 0x08, 0x23, 0x42, 0xb1, 0xc1, 0x15, 0x52, 0xd1, 0xf0, 0x24,
        0x33, 0x62, 0x72, 0x82, 0x09, 0x0a, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x25,
        0x26, 0x27, 0x28, 0x29, 0x2a, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3a,
        0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55, 0x56,
        0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6a,
        0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x83, 0x84, 0x85, 0x86,
        0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99,
        0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xb2, 0xb3,
        0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6,
        0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9,
        0xda, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea, 0xf1,
        0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xff, 0xc4, 0x00,
        0x1f, 0x01, 0x00, 0x03, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05,
        0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0xff, 0xc4, 0x00, 0xb5, 0x11, 0x00,
        0x02, 0x01, 0x02, 0x04, 0x04, 0x03, 0x04, 0x07, 0x05, 0x04, 0x04, 0x00,
        0x01, 0x02, 0x77, 0x00, 0x01, 0x02, 0x03, 0x11, 0x04, 0x05, 0x21, 0x31,
        0x06, 0x12, 0x41, 0x51, 0x07, 0x61, 0x71, 0x13, 0x22, 0x32, 0x81, 0x08,
        0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1, 0x09, 0x23, 0x33, 0x52, 0xf0, 0x15,
        0x62, 0x72, 0xd1, 0x0a, 0x16, 0x24, 0x34, 0xe1, 0x25, 0xf1, 0x17, 0x18,
        0x19, 0x1a, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x35, 0x36, 0x37, 0x38, 0x39,
        0x3a, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x53, 0x54, 0x55,
        0x56, 0x57, 0x58, 0x59, 0x5a, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69,
        0x6a, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x82, 0x83, 0x84,
        0x85, 0x86, 0x87, 0x88, 0x89, 0x8a, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97,
        0x98, 0x99, 0x9a, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa,
        0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba, 0xc2, 0xc3, 0xc4,
        0xc5, 0xc6, 0xc7, 0xc8, 0xc9, 0xca, 0xd2, 0xd3, 0xd4, 0xd5, 0xd6, 0xd7,
        0xd8, 0xd9, 0xda, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea,
        0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xff, 0xdd, 0x00,
        0x04, 0x00, 0x01, 0xff, 0xda, 0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11,
        0x03, 0x11, 0x00, 0x3f, 0x00, 0xfc, 0xf7, 0xaf, 0xf5, 0x4c, 0xf8, 0x73,
        0xff, 0xd0, 0xfc, 0xf7, 0xaf, 0xf5, 0x4c, 0xf8, 0x73, 0xff, 0xd9,
    };
}

fn testJpegRed420() *const [288]u8 {
    return &[_]u8{
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
        0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x04,
        0x03, 0x03, 0x04, 0x05, 0x08, 0x05, 0x05, 0x04, 0x04, 0x05, 0x0a, 0x07,
        0x07, 0x06, 0x08, 0x0c, 0x0a, 0x0c, 0x0c, 0x0b, 0x0a, 0x0b, 0x0b, 0x0d,
        0x0e, 0x12, 0x10, 0x0d, 0x0e, 0x11, 0x0e, 0x0b, 0x0b, 0x10, 0x16, 0x10,
        0x11, 0x13, 0x14, 0x15, 0x15, 0x15, 0x0c, 0x0f, 0x17, 0x18, 0x16, 0x14,
        0x18, 0x12, 0x14, 0x15, 0x14, 0xff, 0xdb, 0x00, 0x43, 0x01, 0x03, 0x04,
        0x04, 0x05, 0x04, 0x05, 0x09, 0x05, 0x05, 0x09, 0x14, 0x0d, 0x0b, 0x0d,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x10, 0x00, 0x10, 0x03,
        0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xff, 0xc4, 0x00,
        0x15, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0xff, 0xc4, 0x00, 0x14,
        0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xc4, 0x00, 0x15, 0x01, 0x01,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x07, 0x09, 0xff, 0xc4, 0x00, 0x14, 0x11, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0xff, 0xda, 0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11,
        0x03, 0x11, 0x00, 0x3f, 0x00, 0x9d, 0x00, 0x06, 0x2a, 0x9b, 0xff, 0xd9,
    };
}

fn testJpegGreen422() *const [288]u8 {
    return &[_]u8{
        0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
        0x00, 0x03, 0x02, 0x02, 0x03, 0x02, 0x02, 0x03, 0x03, 0x03, 0x03, 0x04,
        0x03, 0x03, 0x04, 0x05, 0x08, 0x05, 0x05, 0x04, 0x04, 0x05, 0x0a, 0x07,
        0x07, 0x06, 0x08, 0x0c, 0x0a, 0x0c, 0x0c, 0x0b, 0x0a, 0x0b, 0x0b, 0x0d,
        0x0e, 0x12, 0x10, 0x0d, 0x0e, 0x11, 0x0e, 0x0b, 0x0b, 0x10, 0x16, 0x10,
        0x11, 0x13, 0x14, 0x15, 0x15, 0x15, 0x0c, 0x0f, 0x17, 0x18, 0x16, 0x14,
        0x18, 0x12, 0x14, 0x15, 0x14, 0xff, 0xdb, 0x00, 0x43, 0x01, 0x03, 0x04,
        0x04, 0x05, 0x04, 0x05, 0x09, 0x05, 0x05, 0x09, 0x14, 0x0d, 0x0b, 0x0d,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14,
        0x14, 0x14, 0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x08, 0x00, 0x10, 0x03,
        0x01, 0x21, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xff, 0xc4, 0x00,
        0x15, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0xff, 0xc4, 0x00, 0x14,
        0x10, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xc4, 0x00, 0x15, 0x01, 0x01,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x08, 0x09, 0xff, 0xc4, 0x00, 0x14, 0x11, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0xff, 0xda, 0x00, 0x0c, 0x03, 0x01, 0x00, 0x02, 0x11,
        0x03, 0x11, 0x00, 0x3f, 0x00, 0xbb, 0x01, 0xf4, 0xe2, 0x7f, 0xff, 0xd9,
    };
}
