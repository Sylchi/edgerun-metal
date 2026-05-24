const std = @import("std");
const image_jpeg = @import("image_jpeg.zig");
const ui = @import("ui.zig");

pub const Header = struct {
    width: usize,
    height: usize,
};

pub const Format = enum {
    jpeg,
    png,
    tga,
    webp,
};

pub const DecodeError = error{
    BadImage,
    UnsupportedImage,
    PixelBudget,
};

pub const EncodeError = error{
    BadImage,
    OutputBudget,
};

const tga_header_size: usize = 18;
const tga_footer_size: usize = 26;
const tga_type_true_color: u8 = 2;
const tga_origin_top: u8 = 1 << 5;
const tga_alpha_bits: u8 = 8;
const tga_depth_rgb: u8 = 24;
const tga_depth_rgba: u8 = 32;
const tga_descriptor_rgba_top_left: u8 = tga_origin_top | tga_alpha_bits;
const tga_signature = "TRUEVISION-XFILE.\x00";
const riff_signature = "RIFF";
const webp_signature = "WEBP";
const webp_chunk_vp8 = "VP8 ";
const webp_chunk_vp8l = "VP8L";
const webp_chunk_vp8x = "VP8X";
const riff_header_size: usize = 12;
const riff_chunk_header_size: usize = 8;
const webp_vp8x_payload_size: usize = 10;
const webp_vp8x_width_index: usize = 4;
const webp_vp8x_height_index: usize = 7;
const webp_vp8l_signature: u8 = 0x2f;
const webp_vp8l_header_size: usize = 5;
const webp_vp8_start_code_offset: usize = 3;
const webp_vp8_frame_header_size: usize = 10;
const webp_vp8_frame_type_key: u32 = 0;
const webp_vp8_max_version: u32 = 3;
const webp_vp8_show_frame: u32 = 1;
const webp_vp8_first_part_size_shift: u5 = 5;
const webp_vp8_frame_type_mask: u32 = 0x01;
const webp_vp8_version_mask: u32 = 0x0e;
const webp_vp8_version_shift: u5 = 1;
const webp_vp8_show_frame_mask: u32 = 0x10;
const webp_vp8_show_frame_shift: u5 = 4;
const webp_vp8_token_partition_count_max: usize = 8;
const webp_vp8_bool_initial_bytes: usize = 2;
const webp_vp8_bool_probability_half: u8 = 128;
const webp_vp8_loop_filter_level_bits: usize = 6;
const webp_vp8_sharpness_level_bits: usize = 3;
const webp_vp8_token_partition_count_bits: usize = 2;
const webp_vp8_token_partition_size_bytes: usize = 3;
const webp_vp8_segment_count: usize = 4;
const webp_vp8_segment_prob_count: usize = 3;
const webp_vp8_quantizer_update_bits: usize = 7;
const webp_vp8_loop_filter_update_bits: usize = 6;
const webp_vp8_loop_filter_delta_count: usize = 4;
const webp_vp8_quant_base_bits: usize = 7;
const webp_vp8_quant_delta_bits: usize = 4;
const webp_vp8_quant_delta_count: usize = 5;
const webp_vp8_coeff_type_count: usize = 4;
const webp_vp8_coeff_band_count: usize = 8;
const webp_vp8_coeff_context_count: usize = 3;
const webp_vp8_coeff_probability_count: usize = 11;
const webp_vp8_coeff_eob_probability_index: usize = 0;
const webp_vp8_coeff_zero_probability_index: usize = 1;
const webp_vp8_coeff_one_probability_index: usize = 2;
const webp_vp8_coeff_large_probability_0: usize = 3;
const webp_vp8_coeff_large_probability_1: usize = 4;
const webp_vp8_coeff_large_probability_2: usize = 5;
const webp_vp8_coeff_large_probability_3: usize = 6;
const webp_vp8_coeff_large_probability_4: usize = 7;
const webp_vp8_coeff_large_probability_5: usize = 8;
const webp_vp8_coeff_large_probability_6: usize = 9;
const webp_vp8_coeff_large_probability_7: usize = 10;
const webp_vp8_coeff_update_probability_default: u8 = 255;
const webp_vp8_skip_probability_bits: usize = 8;
const webp_vp8_macroblock_size: usize = 16;
const webp_vp8_intra16_block_size_probability: u8 = 145;
const webp_vp8_intra16_mode_probability_0: u8 = 156;
const webp_vp8_intra16_mode_probability_1: u8 = 128;
const webp_vp8_intra16_mode_probability_2: u8 = 163;
const webp_vp8_chroma_mode_probability_0: u8 = 142;
const webp_vp8_chroma_mode_probability_1: u8 = 114;
const webp_vp8_chroma_mode_probability_2: u8 = 183;
const webp_vp8_coeff_block_types: usize = 4;
const webp_vp8_coeff_band_entries: usize = 17;
const webp_vp8_y_block_count: usize = 16;
const webp_vp8_chroma_block_count: usize = 8;
const webp_vp8_intra4_dc_mode: usize = 0;
const webp_vp8_intra4_mode_count: usize = 10;
const webp_vp8_intra4_block_width: usize = 4;
const webp_vp8_coeff_min_large_value: i16 = 2;
const webp_vp8_coeff_cat3_base: i16 = 11;
const webp_vp8_coeff_cat4_base: i16 = 19;
const webp_vp8_coeff_cat5_base: i16 = 35;
const webp_vp8_coeff_cat6_base: i16 = 67;
const webp_vp8_key_frame_start_code = [_]u8{ 0x9d, 0x01, 0x2a };
const webp_dimension_mask: u16 = 0x3fff;
const webp_max_canvas_dimension: usize = 16_777_216;
const webp_max_legacy_dimension: usize = 16_384;

const header_id_len_index: usize = 0;
const header_color_map_type_index: usize = 1;
const header_image_type_index: usize = 2;
const header_width_index: usize = 12;
const header_height_index: usize = 14;
const header_depth_index: usize = 16;
const header_descriptor_index: usize = 17;

const png_signature = "\x89PNG\r\n\x1a\n";
const png_length_size: usize = 4;
const png_type_size: usize = 4;
const png_crc_size: usize = 4;
const png_chunk_header_size: usize = png_length_size + png_type_size;
const png_chunk_overhead: usize = png_chunk_header_size + png_crc_size;
const png_ihdr_data_size: usize = 13;
const png_width_index: usize = 0;
const png_height_index: usize = 4;
const png_bit_depth_index: usize = 8;
const png_color_type_index: usize = 9;
const png_compression_index: usize = 10;
const png_filter_index: usize = 11;
const png_interlace_index: usize = 12;
const png_bit_depth_u8: u8 = 8;
const png_color_rgb: u8 = 2;
const png_color_rgba: u8 = 6;
const png_method_deflate: u8 = 0;
const png_filter_standard: u8 = 0;
const png_interlace_none: u8 = 0;
const png_filter_none: u8 = 0;
const png_filter_sub: u8 = 1;
const png_filter_up: u8 = 2;
const png_filter_average: u8 = 3;
const png_filter_paeth: u8 = 4;
const png_alpha_opaque: u8 = 255;
const vp8_neutral_luma: u8 = 128;
const png_chunk_ihdr = "IHDR";
const png_chunk_idat = "IDAT";
const png_chunk_iend = "IEND";
const png_rgba_channels: usize = 4;
const ascii_upper_a: u8 = 'A';
const ascii_upper_z: u8 = 'Z';
const ascii_lower_a: u8 = 'a';
const ascii_lower_z: u8 = 'z';
const png_chunk_ancillary_bit: u8 = 1 << 5;
const png_chunk_reserved_index: usize = 2;
const test_png_rgba_2x1_idat_payload_len: usize = 17;
const test_webp_vp8_base_partition_len: usize = 8;
const test_webp_vp8_first_partition_len: usize = 160;
const test_webp_vp8_first_partition_extra_len: usize = test_webp_vp8_first_partition_len - test_webp_vp8_base_partition_len;
const test_webp_vp8_token_partition_len: usize = 64;
const test_webp_vp8_fixture_tail_len: usize = test_webp_vp8_first_partition_extra_len + test_webp_vp8_token_partition_len;
const test_webp_vp8_chunk_len: usize = webp_vp8_frame_header_size + test_webp_vp8_first_partition_len + test_webp_vp8_token_partition_len;
const test_webp_vp8_len: usize = riff_header_size + riff_chunk_header_size + test_webp_vp8_chunk_len;
const test_webp_vp8x_len: usize = riff_header_size + riff_chunk_header_size + webp_vp8x_payload_size + riff_chunk_header_size + test_webp_vp8_chunk_len;

pub fn detectFormat(bytes: []const u8) DecodeError!Format {
    if (image_jpeg.isJpeg(bytes)) return .jpeg;
    if (isPng(bytes)) return .png;
    if (isTga(bytes)) return .tga;
    if (isWebp(bytes)) return .webp;
    return error.UnsupportedImage;
}

pub fn decodeHeader(bytes: []const u8) DecodeError!Header {
    return switch (try detectFormat(bytes)) {
        .jpeg => image_jpeg.decodeHeader(bytes),
        .png => decodePngHeader(bytes),
        .tga => decodeTgaHeader(bytes),
        .webp => decodeWebpHeader(bytes),
    };
}

pub fn decode(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    return decodeWithScratch(bytes, out, &.{});
}

pub fn decodeWithScratch(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    return switch (try detectFormat(bytes)) {
        .jpeg => image_jpeg.decode(bytes, out),
        .png => decodePng(bytes, out, scratch),
        .tga => decodeTga(bytes, out),
        .webp => decodeWebp(bytes, out),
    };
}

pub fn pngScratchByteLen(encoded_len: usize, width: usize, height: usize) usize {
    return pngScratchByteLenChecked(encoded_len, width, height) catch @panic("png scratch byte length overflow");
}

pub fn decodePngHeader(bytes: []const u8) DecodeError!Header {
    return (try parsePng(bytes, null)).header;
}

fn isPng(bytes: []const u8) bool {
    return bytes.len >= png_signature.len and std.mem.eql(u8, bytes[0..png_signature.len], png_signature);
}

fn isWebp(bytes: []const u8) bool {
    return bytes.len >= riff_header_size and
        std.mem.eql(u8, bytes[0..4], riff_signature) and
        std.mem.eql(u8, bytes[8..12], webp_signature);
}

pub fn decodeWebpHeader(bytes: []const u8) DecodeError!Header {
    return (try parseWebp(bytes)).header;
}

pub fn decodeWebp(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    const info = try parseWebp(bytes);
    if (std.mem.eql(u8, info.chunk_type, webp_chunk_vp8)) {
        return decodeVp8Frame(info.primary_data, info.header, out);
    } else if (std.mem.eql(u8, info.chunk_type, webp_chunk_vp8x)) {
        if (info.vp8_data) |vp8_data| return decodeVp8Frame(vp8_data, info.header, out);
    }
    return error.UnsupportedImage;
}

fn decodeVp8Frame(data: []const u8, expected_header: Header, out: []ui.Color) DecodeError!Header {
    const frame = try parseVp8Frame(data);
    if (frame.header.width != expected_header.width or frame.header.height != expected_header.height) return error.UnsupportedImage;
    if (!frame.flat_dc_keyframe) return error.UnsupportedImage;
    const count = try pixelCount(frame.header);
    if (out.len < count) return error.PixelBudget;
    @memset(out[0..count], .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque });
    return frame.header;
}

const WebpInfo = struct {
    header: Header,
    chunk_type: *const [4]u8,
    primary_data: []const u8,
    vp8_data: ?[]const u8 = null,
};

fn parseWebp(bytes: []const u8) DecodeError!WebpInfo {
    if (!isWebp(bytes)) return error.UnsupportedImage;
    const riff_len: usize = readU32Le(bytes[4..][0..4]);
    if (riff_len < 4) return error.BadImage;
    if (riff_len > std.math.maxInt(usize) - 8) return error.PixelBudget;
    if (riff_len + 8 != bytes.len) return error.BadImage;

    var cursor: usize = riff_header_size;
    var header: ?Header = null;
    var primary_chunk: ?*const [4]u8 = null;
    var primary_data: []const u8 = &.{};
    var vp8_data: ?[]const u8 = null;
    var saw_primary = false;
    while (cursor < bytes.len) {
        if (bytes.len - cursor < riff_chunk_header_size) return error.BadImage;
        const chunk_type = bytes[cursor..][0..4];
        cursor += 4;
        const chunk_len: usize = readU32Le(bytes[cursor..][0..4]);
        cursor += 4;
        if (chunk_len > bytes.len - cursor) return error.BadImage;
        const data = bytes[cursor..][0..chunk_len];
        cursor += chunk_len;
        if ((chunk_len & 1) != 0) {
            if (cursor >= bytes.len) return error.BadImage;
            cursor += 1;
        }

        if (std.mem.eql(u8, chunk_type, webp_chunk_vp8x)) {
            if (saw_primary or header != null) return error.BadImage;
            header = try parseWebpVp8x(data);
            primary_chunk = webp_chunk_vp8x;
            primary_data = data;
        } else if (std.mem.eql(u8, chunk_type, webp_chunk_vp8l)) {
            if (saw_primary) return error.BadImage;
            if (header == null) header = try parseWebpVp8lHeader(data);
            primary_chunk = webp_chunk_vp8l;
            primary_data = data;
            saw_primary = true;
        } else if (std.mem.eql(u8, chunk_type, webp_chunk_vp8)) {
            if (saw_primary) return error.BadImage;
            if (header == null) {
                header = try parseWebpVp8Header(data);
                primary_chunk = webp_chunk_vp8;
            } else {
                _ = try parseWebpVp8Header(data);
            }
            if (primary_data.len == 0) primary_data = data;
            vp8_data = data;
            saw_primary = true;
        } else if (isCriticalWebpChunk(chunk_type)) {
            return error.UnsupportedImage;
        }
    }
    if (!saw_primary or header == null or primary_chunk == null) return error.BadImage;
    return .{ .header = header.?, .chunk_type = primary_chunk.?, .primary_data = primary_data, .vp8_data = vp8_data };
}

fn parseWebpVp8x(data: []const u8) DecodeError!Header {
    if (data.len != webp_vp8x_payload_size) return error.BadImage;
    const width = readU24Le(data[webp_vp8x_width_index..][0..3]) + 1;
    const height = readU24Le(data[webp_vp8x_height_index..][0..3]) + 1;
    if (width == 0 or height == 0 or width > webp_max_canvas_dimension or height > webp_max_canvas_dimension) return error.BadImage;
    return .{ .width = width, .height = height };
}

fn parseWebpVp8lHeader(data: []const u8) DecodeError!Header {
    if (data.len < webp_vp8l_header_size or data[0] != webp_vp8l_signature) return error.BadImage;
    const bits = readU32Le(data[1..][0..4]);
    const width = @as(usize, bits & 0x3fff) + 1;
    const height = @as(usize, (bits >> 14) & 0x3fff) + 1;
    if (width == 0 or height == 0 or width > webp_max_legacy_dimension or height > webp_max_legacy_dimension) return error.BadImage;
    return .{ .width = width, .height = height };
}

fn parseWebpVp8Header(data: []const u8) DecodeError!Header {
    if (data.len < webp_vp8_frame_header_size) return error.BadImage;
    const frame_tag = readU24Le(data[0..3]);
    if ((frame_tag & webp_vp8_frame_type_mask) != webp_vp8_frame_type_key) return error.UnsupportedImage;
    if (!std.mem.eql(u8, data[webp_vp8_start_code_offset..][0..3], &webp_vp8_key_frame_start_code)) return error.BadImage;
    const width = @as(usize, readU16Le(data[6..][0..2]) & webp_dimension_mask);
    const height = @as(usize, readU16Le(data[8..][0..2]) & webp_dimension_mask);
    if (width == 0 or height == 0) return error.BadImage;
    return .{ .width = width, .height = height };
}

const Vp8Frame = struct {
    header: Header,
    first_partition: []const u8,
    token_partitions: []const u8,
    token_partition_count: usize,
    macroblock_count: usize,
    flat_dc_keyframe: bool,
    residual_non_zero: bool,
};

fn parseVp8Frame(data: []const u8) DecodeError!Vp8Frame {
    const header = try parseWebpVp8Header(data);
    const frame_tag = readU24Le(data[0..3]);
    const version = (frame_tag & webp_vp8_version_mask) >> webp_vp8_version_shift;
    const show_frame = (frame_tag & webp_vp8_show_frame_mask) >> webp_vp8_show_frame_shift;
    if (version > webp_vp8_max_version) return error.UnsupportedImage;
    if (show_frame != webp_vp8_show_frame) return error.UnsupportedImage;

    const first_partition_len: usize = @intCast(frame_tag >> webp_vp8_first_part_size_shift);
    if (first_partition_len == 0) return error.BadImage;
    if (first_partition_len > data.len - webp_vp8_frame_header_size) return error.BadImage;
    const first_partition_start = webp_vp8_frame_header_size;
    const first_partition_end = first_partition_start + first_partition_len;
    const first_partition = data[first_partition_start..first_partition_end];
    const frame_header = try parseVp8CompressedFrameHeader(header, first_partition);
    const macroblocks = try parseVp8KeyframeMacroblockHeaders(&frame_header);
    const token_partitions = data[first_partition_end..];
    try validateVp8TokenPartitions(token_partitions, frame_header.token_partition_count);
    const residuals = try parseVp8ResidualTokens(token_partitions, &frame_header, macroblocks);
    return .{
        .header = header,
        .first_partition = first_partition,
        .token_partitions = token_partitions,
        .token_partition_count = frame_header.token_partition_count,
        .macroblock_count = macroblocks.count,
        .flat_dc_keyframe = macroblocks.flat_dc and !residuals.non_zero,
        .residual_non_zero = residuals.non_zero,
    };
}

const Vp8CompressedFrameHeader = struct {
    header: Header,
    reader: Vp8BoolReader,
    token_partition_count: usize,
    segment_update_map: bool,
    segment_probabilities: [webp_vp8_segment_prob_count]u8,
    quant: Vp8QuantIndices,
    refresh_entropy_probabilities: bool,
    token_probability_update_count: usize,
    use_skip_probability: bool,
    skip_probability: u8,
};

const Vp8QuantIndices = struct {
    y_ac: u8,
    y_dc_delta: i8,
    y2_dc_delta: i8,
    y2_ac_delta: i8,
    uv_dc_delta: i8,
    uv_ac_delta: i8,
};

fn parseVp8CompressedFrameHeader(header: Header, data: []const u8) DecodeError!Vp8CompressedFrameHeader {
    var reader = try Vp8BoolReader.init(data);
    _ = try reader.readFlag();
    _ = try reader.readFlag();
    const segmentation = try parseVp8SegmentationHeader(&reader);
    _ = try reader.readFlag();
    _ = try reader.readLiteral(webp_vp8_loop_filter_level_bits);
    _ = try reader.readLiteral(webp_vp8_sharpness_level_bits);
    try parseVp8LoopFilterAdjustments(&reader);
    const partition_bits = try reader.readLiteral(webp_vp8_token_partition_count_bits);
    const quant = try parseVp8QuantIndices(&reader);
    const refresh_entropy_probabilities = try reader.readFlag();
    const token_probability_update_count = try parseVp8TokenProbabilityUpdates(&reader);
    const use_skip_probability = try reader.readFlag();
    const skip_probability: u8 = if (use_skip_probability) @intCast(try reader.readLiteral(webp_vp8_skip_probability_bits)) else 0;
    return .{
        .header = header,
        .reader = reader,
        .token_partition_count = vp8TokenPartitionCount(partition_bits),
        .segment_update_map = segmentation.update_map,
        .segment_probabilities = segmentation.probabilities,
        .quant = quant,
        .refresh_entropy_probabilities = refresh_entropy_probabilities,
        .token_probability_update_count = token_probability_update_count,
        .use_skip_probability = use_skip_probability,
        .skip_probability = skip_probability,
    };
}

const Vp8SegmentationHeader = struct {
    update_map: bool,
    probabilities: [webp_vp8_segment_prob_count]u8,
};

fn parseVp8SegmentationHeader(reader: *Vp8BoolReader) DecodeError!Vp8SegmentationHeader {
    var header = Vp8SegmentationHeader{
        .update_map = false,
        .probabilities = [_]u8{webp_vp8_coeff_update_probability_default} ** webp_vp8_segment_prob_count,
    };
    if (!try reader.readFlag()) return header;
    const update_map = try reader.readFlag();
    header.update_map = update_map;
    const update_data = try reader.readFlag();
    if (update_data) {
        _ = try reader.readFlag();
        var segment: usize = 0;
        while (segment < webp_vp8_segment_count) : (segment += 1) {
            if (try reader.readFlag()) {
                _ = try reader.readLiteral(webp_vp8_quantizer_update_bits);
                _ = try reader.readFlag();
            }
        }
        segment = 0;
        while (segment < webp_vp8_segment_count) : (segment += 1) {
            if (try reader.readFlag()) {
                _ = try reader.readLiteral(webp_vp8_loop_filter_update_bits);
                _ = try reader.readFlag();
            }
        }
    }
    if (update_map) {
        var probability: usize = 0;
        while (probability < webp_vp8_segment_prob_count) : (probability += 1) {
            if (try reader.readFlag()) header.probabilities[probability] = @intCast(try reader.readLiteral(8));
        }
    }
    return header;
}

fn parseVp8LoopFilterAdjustments(reader: *Vp8BoolReader) DecodeError!void {
    if (!try reader.readFlag()) return;
    if (!try reader.readFlag()) return;
    var delta: usize = 0;
    while (delta < webp_vp8_loop_filter_delta_count) : (delta += 1) {
        if (try reader.readFlag()) {
            _ = try reader.readLiteral(webp_vp8_loop_filter_update_bits);
            _ = try reader.readFlag();
        }
    }
    delta = 0;
    while (delta < webp_vp8_loop_filter_delta_count) : (delta += 1) {
        if (try reader.readFlag()) {
            _ = try reader.readLiteral(webp_vp8_loop_filter_update_bits);
            _ = try reader.readFlag();
        }
    }
}

fn parseVp8QuantIndices(reader: *Vp8BoolReader) DecodeError!Vp8QuantIndices {
    return .{
        .y_ac = @intCast(try reader.readLiteral(webp_vp8_quant_base_bits)),
        .y_dc_delta = try readVp8OptionalSignedLiteral(reader, webp_vp8_quant_delta_bits),
        .y2_dc_delta = try readVp8OptionalSignedLiteral(reader, webp_vp8_quant_delta_bits),
        .y2_ac_delta = try readVp8OptionalSignedLiteral(reader, webp_vp8_quant_delta_bits),
        .uv_dc_delta = try readVp8OptionalSignedLiteral(reader, webp_vp8_quant_delta_bits),
        .uv_ac_delta = try readVp8OptionalSignedLiteral(reader, webp_vp8_quant_delta_bits),
    };
}

fn readVp8OptionalSignedLiteral(reader: *Vp8BoolReader, bit_count: usize) DecodeError!i8 {
    if (!try reader.readFlag()) return 0;
    const magnitude: i8 = @intCast(try reader.readLiteral(bit_count));
    if (try reader.readFlag()) return -magnitude;
    return magnitude;
}

fn parseVp8TokenProbabilityUpdates(reader: *Vp8BoolReader) DecodeError!usize {
    var update_count: usize = 0;
    var index: usize = 0;
    while (index < webp_vp8_coeff_update_probability_count) : (index += 1) {
        if (try reader.readBool(vp8CoeffUpdateProbability(index))) {
            _ = try reader.readLiteral(8);
            update_count += 1;
        }
    }
    return update_count;
}

const Vp8MacroblockSummary = struct {
    count: usize,
    non_skipped_count: usize,
    flat_dc: bool,
};

fn parseVp8KeyframeMacroblockHeaders(frame_header: *const Vp8CompressedFrameHeader) DecodeError!Vp8MacroblockSummary {
    var reader = frame_header.reader;
    const mb_w = vp8MacroblockDimension(frame_header.header.width);
    const mb_h = vp8MacroblockDimension(frame_header.header.height);
    if (mb_w > std.math.maxInt(usize) / mb_h) return error.PixelBudget;
    const macroblock_count = mb_w * mb_h;
    var non_skipped_count: usize = 0;
    var flat_dc = true;
    var macroblock: usize = 0;
    while (macroblock < macroblock_count) : (macroblock += 1) {
        const header = try parseVp8KeyframeMacroblockHeader(frame_header, &reader);
        if (!header.skip) non_skipped_count += 1;
        if (!header.flat_luma_dc or header.chroma_mode != .dc) flat_dc = false;
    }
    return .{ .count = macroblock_count, .non_skipped_count = non_skipped_count, .flat_dc = flat_dc };
}

fn vp8MacroblockDimension(pixel_dimension: usize) usize {
    return (pixel_dimension + webp_vp8_macroblock_size - 1) / webp_vp8_macroblock_size;
}

const Vp8MacroblockHeader = struct {
    segment_id: u8,
    skip: bool,
    flat_luma_dc: bool,
    chroma_mode: Vp8ChromaMode,
};

const Vp8Intra16Mode = enum(u8) {
    dc,
    vertical,
    horizontal,
    true_motion,
};

const Vp8ChromaMode = enum(u8) {
    dc,
    vertical,
    horizontal,
    true_motion,
};

fn parseVp8KeyframeMacroblockHeader(frame_header: *const Vp8CompressedFrameHeader, reader: *Vp8BoolReader) DecodeError!Vp8MacroblockHeader {
    const segment_id = if (frame_header.segment_update_map) try readVp8SegmentId(frame_header, reader) else 0;
    const skip = if (frame_header.use_skip_probability) try reader.readBool(frame_header.skip_probability) else false;
    const flat_luma_dc = if (try reader.readBool(webp_vp8_intra16_block_size_probability))
        (try readVp8Intra16Mode(reader)) == .dc
    else
        try readVp8Intra4DcModes(reader);
    return .{
        .segment_id = segment_id,
        .skip = skip,
        .flat_luma_dc = flat_luma_dc,
        .chroma_mode = try readVp8ChromaMode(reader),
    };
}

fn readVp8SegmentId(frame_header: *const Vp8CompressedFrameHeader, reader: *Vp8BoolReader) DecodeError!u8 {
    if (!try reader.readBool(frame_header.segment_probabilities[0])) {
        return if (try reader.readBool(frame_header.segment_probabilities[1])) 1 else 0;
    }
    return if (try reader.readBool(frame_header.segment_probabilities[2])) 3 else 2;
}

fn readVp8Intra16Mode(reader: *Vp8BoolReader) DecodeError!Vp8Intra16Mode {
    if (try reader.readBool(webp_vp8_intra16_mode_probability_0)) {
        return if (try reader.readBool(webp_vp8_intra16_mode_probability_1)) .true_motion else .horizontal;
    }
    return if (try reader.readBool(webp_vp8_intra16_mode_probability_2)) .vertical else .dc;
}

fn readVp8Intra4DcModes(reader: *Vp8BoolReader) DecodeError!bool {
    var top = [_]usize{0} ** webp_vp8_intra4_block_width;
    var left = [_]usize{0} ** webp_vp8_intra4_block_width;
    var flat_dc = true;
    var y: usize = 0;
    while (y < webp_vp8_intra4_block_width) : (y += 1) {
        var previous = left[y];
        var x: usize = 0;
        while (x < webp_vp8_intra4_block_width) : (x += 1) {
            const probability = vp8Intra4DcProbability(top[x], previous);
            if (try reader.readBool(probability)) {
                flat_dc = false;
            }
            top[x] = webp_vp8_intra4_dc_mode;
            previous = webp_vp8_intra4_dc_mode;
        }
        left[y] = previous;
    }
    return flat_dc;
}

fn readVp8ChromaMode(reader: *Vp8BoolReader) DecodeError!Vp8ChromaMode {
    if (!try reader.readBool(webp_vp8_chroma_mode_probability_0)) return .dc;
    if (!try reader.readBool(webp_vp8_chroma_mode_probability_1)) return .vertical;
    return if (try reader.readBool(webp_vp8_chroma_mode_probability_2)) .true_motion else .horizontal;
}

const webp_vp8_intra4_dc_probabilities = [_]u8{
    231, 152, 175, 56, 114, 121, 144, 170, 63, 81,  134, 72, 66,  41, 74, 65,  104, 87,  47, 66,
    88,  43,  39,  56, 39,  34,  107, 68,  34, 62,  193, 60, 112, 40, 88, 61,  100, 142, 41, 51,
    138, 67,  63,  40, 47,  46,  57,  65,  40, 87,  104, 64, 54,  30, 39, 31,  75,  88,  56, 55,
    125, 95,  75,  57, 38,  41,  115, 101, 57, 117, 102, 69, 68,  62, 37, 63,  75,  86,  56, 58,
    164, 51,  86,  22, 45,  56,  83,  85,  18, 35,  190, 85, 101, 56, 71, 101, 146, 138, 32, 112,
};

fn vp8Intra4DcProbability(top: usize, left: usize) u8 {
    if (top >= webp_vp8_intra4_mode_count or left >= webp_vp8_intra4_mode_count) return 0;
    return webp_vp8_intra4_dc_probabilities[top * webp_vp8_intra4_mode_count + left];
}

const Vp8ResidualSummary = struct {
    non_zero: bool,
};

const Vp8CoeffBlock = struct {
    next_index: usize,
    non_zero: bool,
};

fn parseVp8ResidualTokens(data: []const u8, frame_header: *const Vp8CompressedFrameHeader, macroblocks: Vp8MacroblockSummary) DecodeError!Vp8ResidualSummary {
    if (frame_header.token_partition_count != 1) return error.UnsupportedImage;
    if (frame_header.token_probability_update_count != 0) return error.UnsupportedImage;
    if (macroblocks.non_skipped_count == 0) return .{ .non_zero = false };
    var reader = try Vp8BoolReader.init(data);
    var non_zero = false;
    var macroblock: usize = 0;
    while (macroblock < macroblocks.non_skipped_count) : (macroblock += 1) {
        const residual = try parseVp8ResidualMacroblock(&reader);
        non_zero = non_zero or residual.non_zero;
    }
    return .{ .non_zero = non_zero };
}

fn parseVp8ResidualMacroblock(reader: *Vp8BoolReader) DecodeError!Vp8ResidualSummary {
    var non_zero = false;
    const y2 = try readVp8CoeffBlock(reader, 1, 0, 0);
    non_zero = non_zero or y2.non_zero;
    var block: usize = 0;
    while (block < webp_vp8_y_block_count) : (block += 1) {
        const y = try readVp8CoeffBlock(reader, 0, 1, 0);
        non_zero = non_zero or y.non_zero;
    }
    block = 0;
    while (block < webp_vp8_chroma_block_count) : (block += 1) {
        const uv = try readVp8CoeffBlock(reader, 2, 0, 0);
        non_zero = non_zero or uv.non_zero;
    }
    return .{ .non_zero = non_zero };
}

fn readVp8CoeffBlock(reader: *Vp8BoolReader, block_type: usize, start_index: usize, context: usize) DecodeError!Vp8CoeffBlock {
    if (block_type >= webp_vp8_coeff_block_types) return error.BadImage;
    if (start_index >= webp_vp8_coeff_band_entries - 1) return error.BadImage;
    if (context >= webp_vp8_coeff_context_count) return error.BadImage;
    var index = start_index;
    var coeff_context = context;
    var non_zero = false;
    while (index < webp_vp8_coeff_band_entries - 1) {
        if (!try reader.readBool(vp8CoeffProbability(block_type, webp_vp8_coeff_bands[index], coeff_context, webp_vp8_coeff_eob_probability_index))) {
            return .{ .next_index = index, .non_zero = non_zero };
        }
        while (!try reader.readBool(vp8CoeffProbability(block_type, webp_vp8_coeff_bands[index], 0, webp_vp8_coeff_zero_probability_index))) {
            index += 1;
            if (index == webp_vp8_coeff_band_entries - 1) return .{ .next_index = index, .non_zero = non_zero };
        }
        const band = webp_vp8_coeff_bands[index];
        const magnitude = if (!try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_one_probability_index)))
            1
        else
            try readVp8LargeCoeffValue(reader, block_type, band);
        _ = try readVp8SignedCoeff(reader, magnitude);
        non_zero = true;
        coeff_context = if (magnitude == 1) 1 else 2;
        index += 1;
    }
    return .{ .next_index = index, .non_zero = non_zero };
}

fn readVp8LargeCoeffValue(reader: *Vp8BoolReader, block_type: usize, band: usize) DecodeError!i16 {
    if (!try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_large_probability_0))) {
        if (!try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_large_probability_1))) {
            return webp_vp8_coeff_min_large_value;
        }
        return 3 + @as(i16, @intFromBool(try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_large_probability_2))));
    }
    if (!try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_large_probability_3))) {
        if (!try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_large_probability_4))) {
            return 5 + @as(i16, @intFromBool(try reader.readBool(webp_vp8_coeff_cat_extra_probability_0)));
        }
        var value: i16 = 7 + 2 * @as(i16, @intFromBool(try reader.readBool(webp_vp8_coeff_cat_extra_probability_1)));
        value += @as(i16, @intFromBool(try reader.readBool(webp_vp8_coeff_cat_extra_probability_2)));
        return value;
    }

    const high_bit: usize = @intFromBool(try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_large_probability_5)));
    const low_bit: usize = @intFromBool(try reader.readBool(vp8CoeffProbability(block_type, band, 0, webp_vp8_coeff_large_probability_6 + high_bit)));
    const category = 2 * high_bit + low_bit;
    return readVp8CategoryCoeffValue(reader, category);
}

fn readVp8CategoryCoeffValue(reader: *Vp8BoolReader, category: usize) DecodeError!i16 {
    const probabilities = switch (category) {
        0 => webp_vp8_coeff_cat3_probabilities[0..],
        1 => webp_vp8_coeff_cat4_probabilities[0..],
        2 => webp_vp8_coeff_cat5_probabilities[0..],
        3 => webp_vp8_coeff_cat6_probabilities[0..],
        else => return error.BadImage,
    };
    var value: i16 = 0;
    for (probabilities) |probability| {
        value += value + @as(i16, @intFromBool(try reader.readBool(probability)));
    }
    const base: i16 = switch (category) {
        0 => webp_vp8_coeff_cat3_base,
        1 => webp_vp8_coeff_cat4_base,
        2 => webp_vp8_coeff_cat5_base,
        3 => webp_vp8_coeff_cat6_base,
        else => unreachable,
    };
    return value + base;
}

fn readVp8SignedCoeff(reader: *Vp8BoolReader, magnitude: i16) DecodeError!i16 {
    if (magnitude <= 0) return error.BadImage;
    return if (try reader.readFlag()) -magnitude else magnitude;
}

const webp_vp8_coeff_bands = [_]usize{
    0, 1, 2, 3, 6, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 7,
    0,
};

const webp_vp8_coeff_cat_extra_probability_0: u8 = 159;
const webp_vp8_coeff_cat_extra_probability_1: u8 = 165;
const webp_vp8_coeff_cat_extra_probability_2: u8 = 145;
const webp_vp8_coeff_cat3_probabilities = [_]u8{ 173, 148, 140 };
const webp_vp8_coeff_cat4_probabilities = [_]u8{ 176, 155, 140, 135 };
const webp_vp8_coeff_cat5_probabilities = [_]u8{ 180, 157, 141, 134, 130 };
const webp_vp8_coeff_cat6_probabilities = [_]u8{ 254, 254, 243, 230, 196, 177, 153, 140, 133, 130, 129 };

const webp_vp8_coeff_default_probabilities = [_]u8{
    128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
    128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 253, 136, 254, 255, 228, 219, 128, 128, 128, 128, 128,
    189, 129, 242, 255, 227, 213, 255, 219, 128, 128, 128, 106, 126, 227, 252, 214, 209, 255, 255, 128, 128, 128,
    1,   98,  248, 255, 236, 226, 255, 255, 128, 128, 128, 181, 133, 238, 254, 221, 234, 255, 154, 128, 128, 128,
    78,  134, 202, 247, 198, 180, 255, 219, 128, 128, 128, 1,   185, 249, 255, 243, 255, 128, 128, 128, 128, 128,
    184, 150, 247, 255, 236, 224, 128, 128, 128, 128, 128, 77,  110, 216, 255, 236, 230, 128, 128, 128, 128, 128,
    1,   101, 251, 255, 241, 255, 128, 128, 128, 128, 128, 170, 139, 241, 252, 236, 209, 255, 255, 128, 128, 128,
    37,  116, 196, 243, 228, 255, 255, 255, 128, 128, 128, 1,   204, 254, 255, 245, 255, 128, 128, 128, 128, 128,
    207, 160, 250, 255, 238, 128, 128, 128, 128, 128, 128, 102, 103, 231, 255, 211, 171, 128, 128, 128, 128, 128,
    1,   152, 252, 255, 240, 255, 128, 128, 128, 128, 128, 177, 135, 243, 255, 234, 225, 128, 128, 128, 128, 128,
    80,  129, 211, 255, 194, 224, 128, 128, 128, 128, 128, 1,   1,   255, 128, 128, 128, 128, 128, 128, 128, 128,
    246, 1,   255, 128, 128, 128, 128, 128, 128, 128, 128, 255, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
    198, 35,  237, 223, 193, 187, 162, 160, 145, 155, 62,  131, 45,  198, 221, 172, 176, 220, 157, 252, 221, 1,
    68,  47,  146, 208, 149, 167, 221, 162, 255, 223, 128, 1,   149, 241, 255, 221, 224, 255, 255, 128, 128, 128,
    184, 141, 234, 253, 222, 220, 255, 199, 128, 128, 128, 81,  99,  181, 242, 176, 190, 249, 202, 255, 255, 128,
    1,   129, 232, 253, 214, 197, 242, 196, 255, 255, 128, 99,  121, 210, 250, 201, 198, 255, 202, 128, 128, 128,
    23,  91,  163, 242, 170, 187, 247, 210, 255, 255, 128, 1,   200, 246, 255, 234, 255, 128, 128, 128, 128, 128,
    109, 178, 241, 255, 231, 245, 255, 255, 128, 128, 128, 44,  130, 201, 253, 205, 192, 255, 255, 128, 128, 128,
    1,   132, 239, 251, 219, 209, 255, 165, 128, 128, 128, 94,  136, 225, 251, 218, 190, 255, 255, 128, 128, 128,
    22,  100, 174, 245, 186, 161, 255, 199, 128, 128, 128, 1,   182, 249, 255, 232, 235, 128, 128, 128, 128, 128,
    124, 143, 241, 255, 227, 234, 128, 128, 128, 128, 128, 35,  77,  181, 251, 193, 211, 255, 205, 128, 128, 128,
    1,   157, 247, 255, 236, 231, 255, 255, 128, 128, 128, 121, 141, 235, 255, 225, 227, 255, 255, 128, 128, 128,
    45,  99,  188, 251, 195, 217, 255, 224, 128, 128, 128, 1,   1,   251, 255, 213, 255, 128, 128, 128, 128, 128,
    203, 1,   248, 255, 255, 128, 128, 128, 128, 128, 128, 137, 1,   177, 255, 224, 255, 128, 128, 128, 128, 128,
    253, 9,   248, 251, 207, 208, 255, 192, 128, 128, 128, 175, 13,  224, 243, 193, 185, 249, 198, 255, 255, 128,
    73,  17,  171, 221, 161, 179, 236, 167, 255, 234, 128, 1,   95,  247, 253, 212, 183, 255, 255, 128, 128, 128,
    239, 90,  244, 250, 211, 209, 255, 255, 128, 128, 128, 155, 77,  195, 248, 188, 195, 255, 255, 128, 128, 128,
    1,   24,  239, 251, 218, 219, 255, 205, 128, 128, 128, 201, 51,  219, 255, 196, 186, 128, 128, 128, 128, 128,
    69,  46,  190, 239, 201, 218, 255, 228, 128, 128, 128, 1,   191, 251, 255, 255, 128, 128, 128, 128, 128, 128,
    223, 165, 249, 255, 213, 255, 128, 128, 128, 128, 128, 141, 124, 248, 255, 255, 128, 128, 128, 128, 128, 128,
    1,   16,  248, 255, 255, 128, 128, 128, 128, 128, 128, 190, 36,  230, 255, 236, 255, 128, 128, 128, 128, 128,
    149, 1,   255, 128, 128, 128, 128, 128, 128, 128, 128, 1,   226, 255, 128, 128, 128, 128, 128, 128, 128, 128,
    247, 192, 255, 128, 128, 128, 128, 128, 128, 128, 128, 240, 128, 255, 128, 128, 128, 128, 128, 128, 128, 128,
    1,   134, 252, 255, 255, 128, 128, 128, 128, 128, 128, 213, 62,  250, 255, 255, 128, 128, 128, 128, 128, 128,
    55,  93,  255, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
    128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,
    202, 24,  213, 235, 186, 191, 220, 160, 240, 175, 255, 126, 38,  182, 232, 169, 184, 228, 174, 255, 187, 128,
    61,  46,  138, 219, 151, 178, 240, 170, 255, 216, 128, 1,   112, 230, 250, 199, 191, 247, 159, 255, 255, 128,
    166, 109, 228, 252, 211, 215, 255, 174, 128, 128, 128, 39,  77,  162, 232, 172, 180, 245, 178, 255, 255, 128,
    1,   52,  220, 246, 198, 199, 249, 220, 255, 255, 128, 124, 74,  191, 243, 183, 193, 250, 221, 255, 255, 128,
    24,  71,  130, 219, 154, 170, 243, 182, 255, 255, 128, 1,   182, 225, 249, 219, 240, 255, 224, 128, 128, 128,
    149, 150, 226, 252, 216, 205, 255, 171, 128, 128, 128, 28,  108, 170, 242, 183, 194, 254, 223, 255, 255, 128,
    1,   81,  230, 252, 204, 203, 255, 192, 128, 128, 128, 123, 102, 209, 247, 188, 196, 255, 233, 128, 128, 128,
    20,  95,  153, 243, 164, 173, 255, 203, 128, 128, 128, 1,   222, 248, 255, 216, 213, 128, 128, 128, 128, 128,
    168, 175, 246, 252, 235, 205, 255, 255, 128, 128, 128, 47,  116, 215, 255, 211, 212, 255, 255, 128, 128, 128,
    1,   121, 236, 253, 212, 214, 255, 255, 128, 128, 128, 141, 84,  213, 252, 201, 202, 255, 219, 128, 128, 128,
    42,  80,  160, 240, 162, 185, 255, 205, 128, 128, 128, 1,   1,   255, 128, 128, 128, 128, 128, 128, 128, 128,
    244, 1,   255, 128, 128, 128, 128, 128, 128, 128, 128, 238, 1,   255, 128, 128, 128, 128, 128, 128, 128, 128,
};

fn vp8CoeffProbability(block_type: usize, band: usize, context: usize, probability_index: usize) u8 {
    std.debug.assert(block_type < webp_vp8_coeff_block_types);
    std.debug.assert(band < webp_vp8_coeff_band_count);
    std.debug.assert(context < webp_vp8_coeff_context_count);
    std.debug.assert(probability_index < webp_vp8_coeff_probability_count);
    return webp_vp8_coeff_default_probabilities[((block_type * webp_vp8_coeff_band_count + band) * webp_vp8_coeff_context_count + context) * webp_vp8_coeff_probability_count + probability_index];
}

const webp_vp8_coeff_update_probability_count =
    webp_vp8_coeff_type_count *
    webp_vp8_coeff_band_count *
    webp_vp8_coeff_context_count *
    webp_vp8_coeff_probability_count;

const Vp8CoeffUpdateProbability = struct {
    index: usize,
    probability: u8,
};

const webp_vp8_coeff_update_probabilities = [_]Vp8CoeffUpdateProbability{
    .{ .index = 33, .probability = 176 },   .{ .index = 34, .probability = 246 },   .{ .index = 44, .probability = 223 },
    .{ .index = 45, .probability = 241 },   .{ .index = 46, .probability = 252 },   .{ .index = 55, .probability = 249 },
    .{ .index = 56, .probability = 253 },   .{ .index = 57, .probability = 253 },   .{ .index = 67, .probability = 244 },
    .{ .index = 68, .probability = 252 },   .{ .index = 77, .probability = 234 },   .{ .index = 78, .probability = 254 },
    .{ .index = 79, .probability = 254 },   .{ .index = 88, .probability = 253 },   .{ .index = 100, .probability = 246 },
    .{ .index = 101, .probability = 254 },  .{ .index = 110, .probability = 239 },  .{ .index = 111, .probability = 253 },
    .{ .index = 112, .probability = 254 },  .{ .index = 121, .probability = 254 },  .{ .index = 123, .probability = 254 },
    .{ .index = 133, .probability = 248 },  .{ .index = 134, .probability = 254 },  .{ .index = 143, .probability = 251 },
    .{ .index = 145, .probability = 254 },  .{ .index = 166, .probability = 253 },  .{ .index = 167, .probability = 254 },
    .{ .index = 176, .probability = 251 },  .{ .index = 177, .probability = 254 },  .{ .index = 178, .probability = 254 },
    .{ .index = 187, .probability = 254 },  .{ .index = 189, .probability = 254 },  .{ .index = 199, .probability = 254 },
    .{ .index = 200, .probability = 253 },  .{ .index = 202, .probability = 254 },  .{ .index = 209, .probability = 250 },
    .{ .index = 211, .probability = 254 },  .{ .index = 213, .probability = 254 },  .{ .index = 220, .probability = 254 },
    .{ .index = 264, .probability = 217 },  .{ .index = 275, .probability = 225 },  .{ .index = 276, .probability = 252 },
    .{ .index = 277, .probability = 241 },  .{ .index = 278, .probability = 253 },  .{ .index = 281, .probability = 254 },
    .{ .index = 286, .probability = 234 },  .{ .index = 287, .probability = 250 },  .{ .index = 288, .probability = 241 },
    .{ .index = 289, .probability = 250 },  .{ .index = 290, .probability = 253 },  .{ .index = 292, .probability = 253 },
    .{ .index = 293, .probability = 254 },  .{ .index = 298, .probability = 254 },  .{ .index = 308, .probability = 223 },
    .{ .index = 309, .probability = 254 },  .{ .index = 310, .probability = 254 },  .{ .index = 319, .probability = 238 },
    .{ .index = 320, .probability = 253 },  .{ .index = 321, .probability = 254 },  .{ .index = 322, .probability = 254 },
    .{ .index = 331, .probability = 248 },  .{ .index = 332, .probability = 254 },  .{ .index = 341, .probability = 249 },
    .{ .index = 342, .probability = 254 },  .{ .index = 364, .probability = 253 },  .{ .index = 374, .probability = 247 },
    .{ .index = 375, .probability = 254 },  .{ .index = 397, .probability = 253 },  .{ .index = 398, .probability = 254 },
    .{ .index = 407, .probability = 252 },  .{ .index = 430, .probability = 254 },  .{ .index = 431, .probability = 254 },
    .{ .index = 440, .probability = 253 },  .{ .index = 463, .probability = 254 },  .{ .index = 464, .probability = 253 },
    .{ .index = 473, .probability = 250 },  .{ .index = 484, .probability = 254 },  .{ .index = 528, .probability = 186 },
    .{ .index = 529, .probability = 251 },  .{ .index = 530, .probability = 250 },  .{ .index = 539, .probability = 234 },
    .{ .index = 540, .probability = 251 },  .{ .index = 541, .probability = 244 },  .{ .index = 542, .probability = 254 },
    .{ .index = 550, .probability = 251 },  .{ .index = 551, .probability = 251 },  .{ .index = 552, .probability = 243 },
    .{ .index = 553, .probability = 253 },  .{ .index = 554, .probability = 254 },  .{ .index = 556, .probability = 254 },
    .{ .index = 562, .probability = 253 },  .{ .index = 563, .probability = 254 },  .{ .index = 572, .probability = 236 },
    .{ .index = 573, .probability = 253 },  .{ .index = 574, .probability = 254 },  .{ .index = 583, .probability = 251 },
    .{ .index = 584, .probability = 253 },  .{ .index = 585, .probability = 253 },  .{ .index = 586, .probability = 254 },
    .{ .index = 587, .probability = 254 },  .{ .index = 595, .probability = 254 },  .{ .index = 596, .probability = 254 },
    .{ .index = 605, .probability = 254 },  .{ .index = 606, .probability = 254 },  .{ .index = 607, .probability = 254 },
    .{ .index = 628, .probability = 254 },  .{ .index = 638, .probability = 254 },  .{ .index = 639, .probability = 254 },
    .{ .index = 649, .probability = 254 },  .{ .index = 671, .probability = 254 },  .{ .index = 792, .probability = 248 },
    .{ .index = 803, .probability = 250 },  .{ .index = 804, .probability = 254 },  .{ .index = 805, .probability = 252 },
    .{ .index = 806, .probability = 254 },  .{ .index = 814, .probability = 248 },  .{ .index = 815, .probability = 254 },
    .{ .index = 816, .probability = 249 },  .{ .index = 817, .probability = 253 },  .{ .index = 826, .probability = 253 },
    .{ .index = 827, .probability = 253 },  .{ .index = 836, .probability = 246 },  .{ .index = 837, .probability = 253 },
    .{ .index = 838, .probability = 253 },  .{ .index = 847, .probability = 252 },  .{ .index = 848, .probability = 254 },
    .{ .index = 849, .probability = 251 },  .{ .index = 850, .probability = 254 },  .{ .index = 851, .probability = 254 },
    .{ .index = 859, .probability = 254 },  .{ .index = 860, .probability = 252 },  .{ .index = 869, .probability = 248 },
    .{ .index = 870, .probability = 254 },  .{ .index = 871, .probability = 253 },  .{ .index = 880, .probability = 253 },
    .{ .index = 882, .probability = 254 },  .{ .index = 883, .probability = 254 },  .{ .index = 892, .probability = 251 },
    .{ .index = 893, .probability = 254 },  .{ .index = 902, .probability = 245 },  .{ .index = 903, .probability = 251 },
    .{ .index = 904, .probability = 254 },  .{ .index = 913, .probability = 253 },  .{ .index = 914, .probability = 253 },
    .{ .index = 915, .probability = 254 },  .{ .index = 925, .probability = 251 },  .{ .index = 926, .probability = 253 },
    .{ .index = 935, .probability = 252 },  .{ .index = 936, .probability = 253 },  .{ .index = 937, .probability = 254 },
    .{ .index = 947, .probability = 254 },  .{ .index = 958, .probability = 252 },  .{ .index = 968, .probability = 249 },
    .{ .index = 970, .probability = 254 },  .{ .index = 981, .probability = 254 },  .{ .index = 992, .probability = 253 },
    .{ .index = 1001, .probability = 250 }, .{ .index = 1034, .probability = 254 },
};

fn vp8CoeffUpdateProbability(index: usize) u8 {
    var left: usize = 0;
    var right: usize = webp_vp8_coeff_update_probabilities.len;
    while (left < right) {
        const middle = left + (right - left) / 2;
        const entry = webp_vp8_coeff_update_probabilities[middle];
        if (entry.index == index) return entry.probability;
        if (entry.index < index) {
            left = middle + 1;
        } else {
            right = middle;
        }
    }
    return webp_vp8_coeff_update_probability_default;
}

fn vp8TokenPartitionCount(partition_bits: u32) usize {
    return switch (partition_bits) {
        0 => 1,
        1 => 2,
        2 => 4,
        3 => webp_vp8_token_partition_count_max,
        else => unreachable,
    };
}

fn validateVp8TokenPartitions(data: []const u8, partition_count: usize) DecodeError!void {
    if (partition_count == 0 or partition_count > webp_vp8_token_partition_count_max) return error.BadImage;
    const size_table_len = (partition_count - 1) * webp_vp8_token_partition_size_bytes;
    if (data.len < size_table_len) return error.BadImage;
    var cursor: usize = size_table_len;
    var partition_index: usize = 1;
    while (partition_index < partition_count) : (partition_index += 1) {
        const partition_size: usize = readU24Le(data[(partition_index - 1) * webp_vp8_token_partition_size_bytes ..][0..webp_vp8_token_partition_size_bytes]);
        if (partition_size > data.len - cursor) return error.BadImage;
        cursor += partition_size;
    }
}

const Vp8BoolReader = struct {
    data: []const u8,
    input_index: usize,
    range: u32,
    value: u32,
    bit_count: usize,

    fn init(data: []const u8) DecodeError!Vp8BoolReader {
        if (data.len < webp_vp8_bool_initial_bytes) return error.BadImage;
        var value: u32 = 0;
        var index: usize = 0;
        while (index < webp_vp8_bool_initial_bytes) : (index += 1) {
            value = (value << 8) | data[index];
        }
        return .{
            .data = data,
            .input_index = webp_vp8_bool_initial_bytes,
            .range = 255,
            .value = value,
            .bit_count = 0,
        };
    }

    fn readFlag(self: *Vp8BoolReader) DecodeError!bool {
        return self.readBool(webp_vp8_bool_probability_half);
    }

    fn readBool(self: *Vp8BoolReader, probability: u8) DecodeError!bool {
        const split = 1 + (((self.range - 1) * @as(u32, probability)) >> 8);
        const split_scaled = split << 8;
        const result = self.value >= split_scaled;
        if (result) {
            self.range -= split;
            self.value -= split_scaled;
        } else {
            self.range = split;
        }
        while (self.range < 128) {
            self.value <<= 1;
            self.range <<= 1;
            self.bit_count += 1;
            if (self.bit_count == 8) {
                if (self.input_index >= self.data.len) return error.BadImage;
                self.value |= self.data[self.input_index];
                self.input_index += 1;
                self.bit_count = 0;
            }
        }
        return result;
    }

    fn readLiteral(self: *Vp8BoolReader, bit_count: usize) DecodeError!u32 {
        var value: u32 = 0;
        var index: usize = 0;
        while (index < bit_count) : (index += 1) {
            value <<= 1;
            if (try self.readFlag()) value |= 1;
        }
        return value;
    }
};

fn isCriticalWebpChunk(chunk_type: []const u8) bool {
    if (chunk_type.len != 4) return true;
    for (chunk_type) |byte| {
        if (!isAsciiLetter(byte) and byte != ' ') return true;
    }
    return isAsciiUpper(chunk_type[0]);
}

pub fn decodePng(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    const info = try parsePng(bytes, scratch);
    const count = try pixelCount(info.header);
    if (out.len < count) return error.PixelBudget;
    const channels = try pngChannels(info.color_type);
    const decoded_len = try pngDecodedByteLen(info.header, channels);
    const idat_len = info.idat_total;
    const required_scratch_len = try pngScratchLayoutByteLen(idat_len, decoded_len);
    if (scratch.len < required_scratch_len) return error.PixelBudget;

    const compressed = scratch[0..idat_len];
    const decoded = scratch[idat_len..][0..decoded_len];
    const window = scratch[idat_len + decoded_len ..][0..std.compress.flate.max_window_len];
    try inflateZlib(compressed, decoded, window);
    try unfilterPng(decoded, info.header.width, info.header.height, channels);
    writePngPixels(decoded, info.header.width, info.header.height, channels, out[0..count]);
    return info.header;
}

const PngInfo = struct {
    header: Header,
    color_type: u8,
    idat_total: usize,
};

fn parsePng(bytes: []const u8, maybe_idat_out: ?[]u8) DecodeError!PngInfo {
    if (!isPng(bytes)) return error.UnsupportedImage;

    var cursor: usize = png_signature.len;
    var header: ?Header = null;
    var color_type: u8 = 0;
    var idat_total: usize = 0;
    var idat_cursor: usize = 0;
    var saw_idat = false;
    var closed_idat = false;

    while (cursor + png_chunk_overhead <= bytes.len) {
        const length: usize = readU32Be(bytes[cursor..][0..png_length_size]);
        cursor += png_length_size;
        const chunk_type = bytes[cursor..][0..png_type_size];
        cursor += png_type_size;
        try validatePngChunkType(chunk_type);
        if (length > bytes.len - cursor - png_crc_size) return error.BadImage;
        const data = bytes[cursor..][0..length];
        cursor += length;
        const expected_crc = readU32Be(bytes[cursor..][0..png_crc_size]);
        cursor += png_crc_size;
        if (pngChunkCrc(chunk_type, data) != expected_crc) return error.BadImage;

        if (std.mem.eql(u8, chunk_type, png_chunk_ihdr)) {
            if (header != null or cursor != png_signature.len + png_chunk_overhead + png_ihdr_data_size) return error.BadImage;
            if (length != png_ihdr_data_size) return error.BadImage;
            const width = readU32Be(data[png_width_index..][0..4]);
            const height = readU32Be(data[png_height_index..][0..4]);
            if (width == 0 or height == 0) return error.BadImage;
            if (data[png_bit_depth_index] != png_bit_depth_u8) return error.UnsupportedImage;
            color_type = data[png_color_type_index];
            _ = try pngChannels(color_type);
            if (data[png_compression_index] != png_method_deflate) return error.UnsupportedImage;
            if (data[png_filter_index] != png_filter_standard) return error.UnsupportedImage;
            if (data[png_interlace_index] != png_interlace_none) return error.UnsupportedImage;
            header = .{ .width = @intCast(width), .height = @intCast(height) };
        } else if (std.mem.eql(u8, chunk_type, png_chunk_idat)) {
            if (header == null or closed_idat) return error.BadImage;
            saw_idat = true;
            if (idat_total > std.math.maxInt(usize) - length) return error.PixelBudget;
            idat_total += length;
            if (maybe_idat_out) |idat_out| {
                if (idat_cursor + length > idat_out.len) return error.PixelBudget;
                @memcpy(idat_out[idat_cursor..][0..length], data);
                idat_cursor += length;
            }
        } else if (std.mem.eql(u8, chunk_type, png_chunk_iend)) {
            if (header == null or !saw_idat or idat_total == 0 or length != 0) return error.BadImage;
            if (cursor != bytes.len) return error.BadImage;
            return .{
                .header = header.?,
                .color_type = color_type,
                .idat_total = idat_total,
            };
        } else if (header == null) {
            return error.BadImage;
        } else if (isCriticalPngChunk(chunk_type)) {
            return error.UnsupportedImage;
        } else if (saw_idat) {
            closed_idat = true;
        }
    }

    return error.BadImage;
}

fn validatePngChunkType(chunk_type: []const u8) DecodeError!void {
    if (chunk_type.len != png_type_size) return error.BadImage;
    for (chunk_type) |byte| {
        if (!isAsciiLetter(byte)) return error.BadImage;
    }
    if ((chunk_type[png_chunk_reserved_index] & png_chunk_ancillary_bit) != 0) return error.BadImage;
}

fn isCriticalPngChunk(chunk_type: []const u8) bool {
    std.debug.assert(chunk_type.len == png_type_size);
    return (chunk_type[0] & png_chunk_ancillary_bit) == 0;
}

fn isAsciiLetter(byte: u8) bool {
    return (byte >= ascii_upper_a and byte <= ascii_upper_z) or
        (byte >= ascii_lower_a and byte <= ascii_lower_z);
}

fn isAsciiUpper(byte: u8) bool {
    return byte >= ascii_upper_a and byte <= ascii_upper_z;
}

fn pngChannels(color_type: u8) DecodeError!usize {
    return switch (color_type) {
        png_color_rgb => 3,
        png_color_rgba => png_rgba_channels,
        else => return error.UnsupportedImage,
    };
}

fn pngDecodedByteLen(header: Header, channels: usize) DecodeError!usize {
    if (header.width > (std.math.maxInt(usize) - 1) / channels) return error.PixelBudget;
    const row_body = header.width * channels;
    if (header.height > std.math.maxInt(usize) / (row_body + 1)) return error.PixelBudget;
    return header.height * (row_body + 1);
}

fn pngScratchByteLenChecked(encoded_len: usize, width: usize, height: usize) DecodeError!usize {
    const decoded_len = try pngDecodedByteLen(.{ .width = width, .height = height }, png_rgba_channels);
    return pngScratchLayoutByteLen(encoded_len, decoded_len);
}

fn pngScratchLayoutByteLen(idat_len: usize, decoded_len: usize) DecodeError!usize {
    const image_bytes = std.math.add(usize, idat_len, decoded_len) catch return error.PixelBudget;
    return std.math.add(usize, image_bytes, std.compress.flate.max_window_len) catch return error.PixelBudget;
}

fn pixelCount(header: Header) DecodeError!usize {
    if (header.width > std.math.maxInt(usize) / header.height) return error.PixelBudget;
    return header.width * header.height;
}

fn inflateZlib(compressed: []const u8, decoded: []u8, window: []u8) DecodeError!void {
    var reader: std.Io.Reader = .fixed(compressed);
    var decompress: std.compress.flate.Decompress = .init(&reader, .zlib, window);
    decompress.reader.readSliceAll(decoded) catch return error.BadImage;
    var extra: [1]u8 = undefined;
    const extra_len = decompress.reader.readSliceShort(&extra) catch return error.BadImage;
    if (extra_len != 0) return error.BadImage;
}

fn unfilterPng(decoded: []u8, width: usize, height: usize, channels: usize) DecodeError!void {
    const row_body = width * channels;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row_start = y * (row_body + 1);
        const filter = decoded[row_start];
        const row = decoded[row_start + 1 ..][0..row_body];
        const previous: []const u8 = if (y == 0) &.{} else decoded[row_start - row_body ..][0..row_body];
        switch (filter) {
            png_filter_none => {},
            png_filter_sub => unfilterSub(row, channels),
            png_filter_up => unfilterUp(row, previous),
            png_filter_average => unfilterAverage(row, previous, channels),
            png_filter_paeth => unfilterPaeth(row, previous, channels),
            else => return error.UnsupportedImage,
        }
    }
}

fn unfilterSub(row: []u8, channels: usize) void {
    var index: usize = channels;
    while (index < row.len) : (index += 1) {
        row[index] +%= row[index - channels];
    }
}

fn unfilterUp(row: []u8, previous: []const u8) void {
    if (previous.len == 0) return;
    for (row, previous) |*byte, above| {
        byte.* +%= above;
    }
}

fn unfilterAverage(row: []u8, previous: []const u8, channels: usize) void {
    var index: usize = 0;
    while (index < row.len) : (index += 1) {
        const left = if (index >= channels) row[index - channels] else 0;
        const above = if (previous.len == 0) 0 else previous[index];
        row[index] +%= @intCast((@as(u16, left) + @as(u16, above)) / 2);
    }
}

fn unfilterPaeth(row: []u8, previous: []const u8, channels: usize) void {
    var index: usize = 0;
    while (index < row.len) : (index += 1) {
        const left = if (index >= channels) row[index - channels] else 0;
        const above = if (previous.len == 0) 0 else previous[index];
        const upper_left = if (index >= channels and previous.len != 0) previous[index - channels] else 0;
        row[index] +%= paethPredictor(left, above, upper_left);
    }
}

fn paethPredictor(left: u8, above: u8, upper_left: u8) u8 {
    const left_i: i16 = left;
    const above_i: i16 = above;
    const upper_left_i: i16 = upper_left;
    const estimate = left_i + above_i - upper_left_i;
    const left_distance = absI16(estimate - left_i);
    const above_distance = absI16(estimate - above_i);
    const upper_left_distance = absI16(estimate - upper_left_i);
    if (left_distance <= above_distance and left_distance <= upper_left_distance) return left;
    if (above_distance <= upper_left_distance) return above;
    return upper_left;
}

fn absI16(value: i16) u16 {
    return @intCast(if (value < 0) -value else value);
}

fn writePngPixels(decoded: []const u8, width: usize, height: usize, channels: usize, out: []ui.Color) void {
    const row_body = width * channels;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row = decoded[y * (row_body + 1) + 1 ..][0..row_body];
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const source = x * channels;
            out[y * width + x] = .{
                .r = row[source + 0],
                .g = row[source + 1],
                .b = row[source + 2],
                .a = switch (channels) {
                    png_rgba_channels => row[source + 3],
                    else => png_alpha_opaque,
                },
            };
        }
    }
}

fn pngChunkCrc(chunk_type: []const u8, data: []const u8) u32 {
    var crc = std.hash.Crc32.init();
    crc.update(chunk_type);
    crc.update(data);
    return crc.final();
}

pub fn decodeTgaHeader(bytes: []const u8) DecodeError!Header {
    if (bytes.len < tga_header_size) return error.BadImage;
    if (bytes[header_color_map_type_index] != 0) return error.UnsupportedImage;
    if (bytes[header_image_type_index] != tga_type_true_color) return error.UnsupportedImage;
    const depth = bytes[header_depth_index];
    if (depth != tga_depth_rgb and depth != tga_depth_rgba) return error.UnsupportedImage;
    const width = readU16(bytes[header_width_index..][0..2]);
    const height = readU16(bytes[header_height_index..][0..2]);
    if (width == 0 or height == 0) return error.BadImage;
    const pixel_bytes = bytesPerPixel(depth);
    const id_len: usize = bytes[header_id_len_index];
    const required = tga_header_size + id_len + @as(usize, width) * @as(usize, height) * pixel_bytes;
    if (required > bytes.len) return error.BadImage;
    return .{ .width = width, .height = height };
}

fn isTga(bytes: []const u8) bool {
    if (bytes.len < tga_header_size) return false;
    if (bytes[header_color_map_type_index] != 0) return false;
    if (bytes[header_image_type_index] != tga_type_true_color) return false;
    const depth = bytes[header_depth_index];
    return depth == tga_depth_rgb or depth == tga_depth_rgba;
}

pub fn decodeTga(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    const header = try decodeTgaHeader(bytes);
    const count = header.width * header.height;
    if (out.len < count) return error.PixelBudget;

    const depth = bytes[header_depth_index];
    const pixel_bytes = bytesPerPixel(depth);
    const id_len: usize = bytes[header_id_len_index];
    const data = bytes[tga_header_size + id_len ..];
    const top_origin = (bytes[header_descriptor_index] & tga_origin_top) != 0;

    var y: usize = 0;
    while (y < header.height) : (y += 1) {
        const source_y = if (top_origin) y else header.height - 1 - y;
        var x: usize = 0;
        while (x < header.width) : (x += 1) {
            const source = (source_y * header.width + x) * pixel_bytes;
            out[y * header.width + x] = decodePixel(data[source..], depth);
        }
    }
    return header;
}

pub fn encodeTgaRgba(pixels: []const ui.Color, width: usize, height: usize, out: []u8) EncodeError!usize {
    if (width == 0 or height == 0 or pixels.len < width * height) return error.BadImage;
    const body_len = width * height * 4;
    const total_len = tga_header_size + body_len + tga_footer_size;
    if (out.len < total_len) return error.OutputBudget;

    @memset(out[0..total_len], 0);
    out[header_image_type_index] = tga_type_true_color;
    writeU16(out[header_width_index..][0..2], width);
    writeU16(out[header_height_index..][0..2], height);
    out[header_depth_index] = tga_depth_rgba;
    out[header_descriptor_index] = tga_descriptor_rgba_top_left;

    var cursor: usize = tga_header_size;
    for (pixels[0 .. width * height]) |pixel| {
        out[cursor + 0] = pixel.b;
        out[cursor + 1] = pixel.g;
        out[cursor + 2] = pixel.r;
        out[cursor + 3] = pixel.a;
        cursor += 4;
    }
    @memcpy(out[cursor + 8 .. cursor + 8 + tga_signature.len], tga_signature);
    return total_len;
}

fn decodePixel(bytes: []const u8, depth: u8) ui.Color {
    return switch (depth) {
        tga_depth_rgb => .{ .r = bytes[2], .g = bytes[1], .b = bytes[0], .a = 255 },
        tga_depth_rgba => .{ .r = bytes[2], .g = bytes[1], .b = bytes[0], .a = bytes[3] },
        else => unreachable,
    };
}

fn bytesPerPixel(depth: u8) usize {
    return switch (depth) {
        tga_depth_rgb => 3,
        tga_depth_rgba => 4,
        else => unreachable,
    };
}

fn readU16(bytes: *const [2]u8) u16 {
    return @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
}

fn readU16Le(bytes: *const [2]u8) u16 {
    return @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
}

fn readU24Le(bytes: *const [3]u8) u32 {
    return @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16);
}

fn readU32Le(bytes: *const [4]u8) u32 {
    return @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16) |
        (@as(u32, bytes[3]) << 24);
}

fn readU32Be(bytes: *const [4]u8) u32 {
    return (@as(u32, bytes[0]) << 24) |
        (@as(u32, bytes[1]) << 16) |
        (@as(u32, bytes[2]) << 8) |
        @as(u32, bytes[3]);
}

fn writeU32Be(bytes: *[4]u8, value: u32) void {
    bytes[0] = @intCast((value >> 24) & 0xff);
    bytes[1] = @intCast((value >> 16) & 0xff);
    bytes[2] = @intCast((value >> 8) & 0xff);
    bytes[3] = @intCast(value & 0xff);
}

fn writeU32Le(bytes: *[4]u8, value: usize) void {
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
    bytes[2] = @intCast((value >> 16) & 0xff);
    bytes[3] = @intCast((value >> 24) & 0xff);
}

fn writeU16(bytes: *[2]u8, value: usize) void {
    std.debug.assert(value <= std.math.maxInt(u16));
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
}

test "tga rgba encoding roundtrips pixels" {
    const pixels = [_]ui.Color{
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .{ .r = 0, .g = 255, .b = 0, .a = 128 },
        .{ .r = 0, .g = 0, .b = 255, .a = 64 },
        .{ .r = 255, .g = 255, .b = 255, .a = 0 },
    };
    var encoded: [tga_header_size + pixels.len * 4 + tga_footer_size]u8 = undefined;
    const len = try encodeTgaRgba(&pixels, 2, 2, &encoded);
    var decoded: [pixels.len]ui.Color = undefined;
    try std.testing.expectEqual(Format.tga, try detectFormat(encoded[0..len]));
    const header = try decode(encoded[0..len], &decoded);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &pixels, &decoded);
}

test "png rgba decoder validates chunks and returns canonical pixels" {
    const bytes = testPngRgba2x1();
    var pixels: [2]ui.Color = undefined;
    var scratch: [pngScratchByteLen(bytes.len, 2, 1)]u8 = undefined;
    try std.testing.expectEqual(Format.png, try detectFormat(bytes));
    const header = try decodeWithScratch(bytes, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 255, .b = 0, .a = 128 }, pixels[1]);
}

test "png decoder requires explicit scratch" {
    const bytes = testPngRgba2x1();
    var pixels: [2]ui.Color = undefined;
    try std.testing.expectError(error.PixelBudget, decode(bytes, &pixels));
}

test "webp decoder parses vp8x dimensions through shared header path" {
    const bytes = testWebpVp8x();
    try std.testing.expectEqual(Format.webp, try detectFormat(bytes));
    const header = try decodeHeader(bytes);
    try std.testing.expectEqual(@as(usize, 3), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
}

test "webp decoder parses vp8l dimensions" {
    const bytes = testWebpVp8l();
    const header = try decodeWebpHeader(bytes);
    try std.testing.expectEqual(@as(usize, 4), header.width);
    try std.testing.expectEqual(@as(usize, 5), header.height);
}

test "webp decoder parses vp8 keyframe dimensions" {
    const bytes = testWebpVp8();
    const header = try decodeWebpHeader(bytes);
    try std.testing.expectEqual(@as(usize, 6), header.width);
    try std.testing.expectEqual(@as(usize, 7), header.height);
}

test "webp vp8 decoder writes neutral rgba pixels for supported zero residual keyframe" {
    const bytes = testWebpVp8x();
    var pixels: [6]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 3), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
    }, &pixels);
}

test "webp vp8 decoder checks output pixel budget" {
    const bytes = testWebpVp8();
    var pixels: [41]ui.Color = undefined;
    try std.testing.expectError(error.PixelBudget, decode(bytes, &pixels));
}

test "webp vp8l pixel decode remains unsupported" {
    const bytes = testWebpVp8l();
    var pixels: [20]ui.Color = undefined;
    try std.testing.expectError(error.UnsupportedImage, decode(bytes, &pixels));
}

test "webp vp8 decoder rejects malformed first partition sizes" {
    const payload_offset = riff_header_size + riff_chunk_header_size;
    var empty_partition = testWebpVp8().*;
    writeTestVp8FrameTag(empty_partition[payload_offset..][0..3], 0);
    var pixels: [1]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decode(&empty_partition, &pixels));

    var short_bool_partition = testWebpVp8().*;
    writeTestVp8FrameTag(short_bool_partition[payload_offset..][0..3], 1);
    try std.testing.expectError(error.BadImage, decode(&short_bool_partition, &pixels));

    var oversized_partition = testWebpVp8().*;
    writeTestVp8FrameTag(oversized_partition[payload_offset..][0..3], test_webp_vp8_first_partition_len + test_webp_vp8_token_partition_len + 1);
    try std.testing.expectError(error.BadImage, decode(&oversized_partition, &pixels));
}

test "vp8 bool reader decodes zero frame header prefix deterministically" {
    const header = try parseVp8CompressedFrameHeader(.{ .width = 6, .height = 7 }, &[_]u8{0x00} ** test_webp_vp8_first_partition_len);
    try std.testing.expectEqual(@as(usize, 1), header.token_partition_count);
    try std.testing.expectEqual(@as(u8, 0), header.quant.y_ac);
    try std.testing.expectEqual(@as(i8, 0), header.quant.y_dc_delta);
    try std.testing.expectEqual(false, header.refresh_entropy_probabilities);
    try std.testing.expectEqual(@as(usize, 0), header.token_probability_update_count);
    try std.testing.expectEqual(false, header.use_skip_probability);
    try std.testing.expectEqual(@as(u8, 0), header.skip_probability);
}

test "vp8 coefficient update probabilities match sparse schedule" {
    try std.testing.expectEqual(@as(usize, 1056), webp_vp8_coeff_update_probability_count);
    try std.testing.expectEqual(@as(u8, 255), vp8CoeffUpdateProbability(0));
    try std.testing.expectEqual(@as(u8, 176), vp8CoeffUpdateProbability(33));
    try std.testing.expectEqual(@as(u8, 217), vp8CoeffUpdateProbability(264));
    try std.testing.expectEqual(@as(u8, 250), vp8CoeffUpdateProbability(1001));
    try std.testing.expectEqual(@as(u8, 255), vp8CoeffUpdateProbability(1055));
}

test "vp8 coefficient default probabilities expose token tree entries" {
    try std.testing.expectEqual(@as(usize, 1056), webp_vp8_coeff_default_probabilities.len);
    try std.testing.expectEqual(@as(u8, 128), vp8CoeffProbability(0, 0, 0, webp_vp8_coeff_eob_probability_index));
    try std.testing.expectEqual(@as(u8, 136), vp8CoeffProbability(0, 1, 0, webp_vp8_coeff_zero_probability_index));
    try std.testing.expectEqual(@as(u8, 237), vp8CoeffProbability(1, 0, 0, webp_vp8_coeff_one_probability_index));
    try std.testing.expectEqual(@as(u8, 216), vp8CoeffProbability(3, 0, 2, webp_vp8_coeff_large_probability_6));
}

test "vp8 coefficient token reader accepts eob and category paths" {
    var eob_reader = try Vp8BoolReader.init(&[_]u8{0x00} ** 8);
    const eob = try readVp8CoeffBlock(&eob_reader, 0, 1, 0);
    try std.testing.expectEqual(@as(usize, 1), eob.next_index);
    try std.testing.expectEqual(false, eob.non_zero);

    var large_reader = try Vp8BoolReader.init(&[_]u8{0x00} ** 8);
    try std.testing.expectEqual(@as(i16, 2), try readVp8LargeCoeffValue(&large_reader, 0, 1));
    try std.testing.expectEqual(@as(i16, 2), try readVp8SignedCoeff(&large_reader, 2));
}

test "webp decoder rejects malformed riff length and duplicate primary chunks" {
    var bad_len = testWebpVp8x().*;
    bad_len[4] ^= 1;
    try std.testing.expectError(error.BadImage, decodeWebpHeader(&bad_len));

    const first = testWebpVp8();
    const second = testWebpVp8();
    var duplicate: [testWebpVp8().len + testWebpVp8().len - riff_header_size]u8 = undefined;
    @memcpy(duplicate[0..first.len], first);
    @memcpy(duplicate[first.len..], second[riff_header_size..]);
    writeU32Le(duplicate[4..][0..4], duplicate.len - 8);
    try std.testing.expectError(error.BadImage, decodeWebpHeader(&duplicate));
}

test "png decoder rejects corrupt chunk crc" {
    var bytes = [_]u8{
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
        0x89, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
        0x44, 0xae, 0x42, 0x60, 0x82,
    };
    bytes[bytes.len - 1] ^= 1;
    try std.testing.expectError(error.BadImage, decodePngHeader(&bytes));
}

test "png decoder rejects invalid chunk type names" {
    var bytes = testPngRgba2x1().*;
    const chunk_offset = findPngChunkOffset(&bytes, png_chunk_idat);
    bytes[chunk_offset + png_length_size + png_chunk_reserved_index] = ascii_lower_a;
    try std.testing.expectError(error.BadImage, decodePngHeader(&bytes));
}

test "png decoder rejects unknown critical chunks explicitly" {
    var bytes = testPngRgba2x1().*;
    const chunk_offset = findPngChunkOffset(&bytes, png_chunk_idat);
    const length: usize = readU32Be(bytes[chunk_offset..][0..png_length_size]);
    const chunk_type = bytes[chunk_offset + png_length_size ..][0..png_type_size];
    @memcpy(chunk_type, "JDAT");
    const data = bytes[chunk_offset + png_chunk_header_size ..][0..length];
    writeU32Be(bytes[chunk_offset + png_chunk_header_size + length ..][0..png_crc_size], pngChunkCrc(chunk_type, data));
    try std.testing.expectError(error.UnsupportedImage, decodePngHeader(&bytes));
}

test "png decoder rejects empty idat streams" {
    const bytes = testPngRgba2x1();
    const chunk_offset = findPngChunkOffset(bytes, png_chunk_idat);
    const iend_offset = chunk_offset + png_chunk_overhead + test_png_rgba_2x1_idat_payload_len;
    var empty_idat: [testPngRgba2x1().len - test_png_rgba_2x1_idat_payload_len]u8 = undefined;
    @memcpy(empty_idat[0..chunk_offset], bytes[0..chunk_offset]);
    writeU32Be(empty_idat[chunk_offset..][0..png_length_size], 0);
    @memcpy(empty_idat[chunk_offset + png_length_size ..][0..png_type_size], png_chunk_idat);
    writeU32Be(empty_idat[chunk_offset + png_chunk_header_size ..][0..png_crc_size], pngChunkCrc(png_chunk_idat, &.{}));
    @memcpy(
        empty_idat[chunk_offset + png_chunk_overhead ..],
        bytes[iend_offset..],
    );
    try std.testing.expectError(error.BadImage, decodePngHeader(&empty_idat));
}

test "png scratch length calculation rejects overflow" {
    try std.testing.expectError(
        error.PixelBudget,
        pngScratchByteLenChecked(std.math.maxInt(usize), 1, 1),
    );
    try std.testing.expectError(
        error.PixelBudget,
        pngScratchByteLenChecked(1, std.math.maxInt(usize), 1),
    );
}

test "png scanline filters reconstruct bytes deterministically" {
    const channels = 3;
    const width = 2;
    const height = 5;
    var decoded = [_]u8{
        png_filter_none,    10, 20, 30, 40, 50, 60,
        png_filter_sub,     1,  2,  3,  4,  5,  6,
        png_filter_up,      1,  1,  1,  1,  1,  1,
        png_filter_average, 5,  5,  5,  5,  5,  5,
        png_filter_paeth,   5,  5,  5,  5,  5,  5,
    };
    try unfilterPng(&decoded, width, height, channels);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 10, 20, 30, 40, 50, 60 }, decoded[1..7]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 5, 7, 9 }, decoded[8..14]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 2, 3, 4, 6, 8, 10 }, decoded[15..21]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 6, 6, 7, 11, 12, 13 }, decoded[22..28]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 11, 11, 12, 16, 17, 18 }, decoded[29..35]);
}

test "generic decoder rejects unknown bytes before format-specific decode" {
    const bytes = [_]u8{ 0x42, 0x41, 0x44, 0x00 };
    var pixels: [1]ui.Color = undefined;
    try std.testing.expectError(error.UnsupportedImage, detectFormat(&bytes));
    try std.testing.expectError(error.UnsupportedImage, decode(&bytes, &pixels));
}

test "tga decoder rejects unsupported compressed image type" {
    var bytes = [_]u8{0} ** tga_header_size;
    bytes[header_image_type_index] = 10;
    bytes[header_width_index] = 1;
    bytes[header_height_index] = 1;
    bytes[header_depth_index] = tga_depth_rgba;
    try std.testing.expectError(error.UnsupportedImage, decodeTgaHeader(&bytes));
}

fn testPngRgba2x1() *const [74]u8 {
    return &[_]u8{
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0xf4, 0x22, 0x7f,
        0x8a, 0x00, 0x00, 0x00, 0x11, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xc0, 0xf0,
        0x9f, 0xe1, 0x3f, 0x43, 0x03, 0x00, 0x10, 0x79,
        0x03, 0x7e, 0x21, 0xc0, 0xfd, 0x8d, 0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
        0x60, 0x82,
    };
}

fn findPngChunkOffset(bytes: []const u8, chunk_name: []const u8) usize {
    var cursor: usize = png_signature.len;
    while (cursor + png_chunk_overhead <= bytes.len) {
        const length: usize = readU32Be(bytes[cursor..][0..png_length_size]);
        const chunk_type = bytes[cursor + png_length_size ..][0..png_type_size];
        if (std.mem.eql(u8, chunk_type, chunk_name)) return cursor;
        cursor += png_chunk_overhead + length;
    }
    unreachable;
}

fn testWebpVp8x() *const [test_webp_vp8x_len]u8 {
    return &([_]u8{
        'R',  'I',  'F',  'F',  0x08, 0x01, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  'X',
        0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x02, 0x00, 0x00, 0x01, 0x00, 0x00, 'V',  'P',
        '8',  ' ',  0xea, 0x00, 0x00, 0x00, 0x10, 0x14,
        0x00, 0x9d, 0x01, 0x2a, 0x03, 0x00, 0x02, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    } ++ [_]u8{0x00} ** test_webp_vp8_fixture_tail_len);
}

fn testWebpVp8l() *const [26]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x12, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  'L',
        0x05, 0x00, 0x00, 0x00, 0x2f, 0x03, 0x00, 0x01,
        0x00, 0x00,
    };
}

fn testWebpVp8() *const [test_webp_vp8_len]u8 {
    return &([_]u8{
        'R',  'I',  'F',  'F',  0xf6, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  ' ',
        0xea, 0x00, 0x00, 0x00, 0x10, 0x14, 0x00, 0x9d,
        0x01, 0x2a, 0x06, 0x00, 0x07, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    } ++ [_]u8{0x00} ** test_webp_vp8_fixture_tail_len);
}

fn writeTestVp8FrameTag(bytes: *[3]u8, first_partition_len: usize) void {
    const frame_tag = @as(usize, webp_vp8_show_frame_mask) | (first_partition_len << webp_vp8_first_part_size_shift);
    bytes[0] = @intCast(frame_tag & 0xff);
    bytes[1] = @intCast((frame_tag >> 8) & 0xff);
    bytes[2] = @intCast((frame_tag >> 16) & 0xff);
}
