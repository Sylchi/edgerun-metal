const std = @import("std");
const ui = @import("../../ui.zig");
const common = @import("../common.zig");
const raw_vp8 = @import("../vp8.zig");
const vp8_tables = @import("vp8_tables.zig");

const Header = common.Header;
const DecodeError = common.DecodeError;
const checkedAdd = common.checkedAdd;
const checkedMul = common.checkedMul;
const pixelCount = common.pixelCount;
const divRoundUp = common.divRoundUp;
const readU16Le = common.readU16Le;
const readU24Le = common.readU24Le;
const readU32Le = common.readU32Le;
const writeU32Le = common.writeU32Le;
const writeU24Le = common.writeU24Le;
const writeU16 = common.writeU16;
const png_alpha_opaque = common.alpha_opaque;
const isAsciiLetter = common.isAsciiLetter;
const isAsciiUpper = common.isAsciiUpper;
const decode = decodeWebp;
const decodeWithScratch = decodeWebpWithScratch;
const decodeHeader = decodeWebpHeader;
const scratchByteLen = webpScratchByteLen;

const riff_signature = "RIFF";
const webp_signature = "WEBP";
const webp_chunk_vp8 = "VP8 ";
const webp_chunk_vp8l = "VP8L";
const webp_chunk_vp8x = "VP8X";
const webp_chunk_iccp = "ICCP";
const webp_chunk_exif = "EXIF";
const webp_chunk_xmp = "XMP ";
const webp_chunk_alph = "ALPH";
const webp_chunk_anim = "ANIM";
const webp_chunk_anmf = "ANMF";
const riff_header_size: usize = 12;
const riff_chunk_header_size: usize = 8;
const webp_vp8x_payload_size: usize = 10;
const webp_vp8x_flags_index: usize = 0;
const webp_vp8x_width_index: usize = 4;
const webp_vp8x_height_index: usize = 7;
const webp_vp8x_flag_icc: u8 = 1 << 5;
const webp_vp8x_flag_alpha: u8 = 1 << 4;
const webp_vp8x_flag_exif: u8 = 1 << 3;
const webp_vp8x_flag_xmp: u8 = 1 << 2;
const webp_vp8x_flag_animation: u8 = 1 << 1;
const webp_vp8x_known_flags: u8 =
    webp_vp8x_flag_icc |
    webp_vp8x_flag_alpha |
    webp_vp8x_flag_exif |
    webp_vp8x_flag_xmp |
    webp_vp8x_flag_animation;
const webp_vp8x_decode_blocking_flags: u8 = webp_vp8x_flag_animation;
const webp_anim_payload_size: usize = 6;
const webp_anim_background_blue_index: usize = 0;
const webp_anim_background_green_index: usize = 1;
const webp_anim_background_red_index: usize = 2;
const webp_anim_background_alpha_index: usize = 3;
const webp_anim_loop_count_index: usize = 4;
const webp_anmf_header_size: usize = 16;
const webp_anmf_x_index: usize = 0;
const webp_anmf_y_index: usize = 3;
const webp_anmf_width_index: usize = 6;
const webp_anmf_height_index: usize = 9;
const webp_anmf_duration_index: usize = 12;
const webp_anmf_flags_index: usize = 15;
const webp_anmf_reserved_mask: u8 = 0xfc;
const webp_anmf_blend_flag: u8 = 1 << 1;
const webp_anmf_dispose_flag: u8 = 1 << 0;
const webp_alph_header_size: usize = 1;
const webp_alph_compression_mask: u8 = 0x03;
const webp_alph_filter_mask: u8 = 0x0c;
const webp_alph_filter_shift: u3 = 2;
const webp_alph_preprocessing_mask: u8 = 0x30;
const webp_alph_reserved_mask: u8 = 0xc0;
const webp_alph_compression_none: u8 = 0;
const webp_alph_compression_vp8l: u8 = 1;
const webp_alph_filter_none: u8 = 0;
const webp_alph_filter_horizontal: u8 = 1;
const webp_alph_filter_vertical: u8 = 2;
const webp_alph_filter_gradient: u8 = 3;
const webp_vp8l_signature: u8 = 0x2f;
const webp_vp8l_header_size: usize = 5;
const webp_vp8l_dimension_bits: usize = 14;
const webp_vp8l_dimension_mask: u32 = (1 << webp_vp8l_dimension_bits) - 1;
const webp_vp8l_height_shift: u5 = 14;
const webp_vp8l_alpha_shift: u5 = 28;
const webp_vp8l_version_shift: u5 = 29;
const webp_vp8l_version_mask: u32 = 0x7;
const webp_vp8l_expected_version: u32 = 0;
const webp_vp8l_channel_symbol_count: usize = 256;
const webp_vp8l_length_symbol_count: usize = 24;
const webp_vp8l_length_symbol_base: usize = webp_vp8l_channel_symbol_count;
const webp_vp8l_color_cache_symbol_base: usize = webp_vp8l_channel_symbol_count + webp_vp8l_length_symbol_count;
const webp_vp8l_distance_symbol_count: usize = 40;
const webp_vp8l_green_symbol_count_without_cache: usize = 280;
const webp_vp8l_color_cache_bits_len: usize = 4;
const webp_vp8l_color_cache_min_bits: usize = 1;
const webp_vp8l_color_cache_max_bits: usize = 11;
const webp_vp8l_color_cache_max_size: usize = 1 << webp_vp8l_color_cache_max_bits;
const webp_vp8l_green_symbol_count_with_max_cache: usize = webp_vp8l_green_symbol_count_without_cache + webp_vp8l_color_cache_max_size;
const webp_vp8l_color_cache_hash_multiplier: u32 = 0x1e35a7bd;
const webp_vp8l_color_cache_hash_width: usize = 32;
const webp_vp8l_distance_plane_code_count: usize = 120;
const webp_vp8l_simple_code_symbol_bits: usize = 8;
const webp_vp8l_simple_code_short_symbol_bits: usize = 1;
const webp_vp8l_simple_code_selector_extra_bits: usize = 7;
const webp_vp8l_prefix_code_max_bits: usize = 15;
const webp_vp8l_code_length_code_count: usize = 19;
const webp_vp8l_code_length_code_order = [_]usize{ 17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
const webp_vp8l_normal_code_length_count_base: usize = 4;
const webp_vp8l_normal_code_length_count_bits: usize = 4;
const webp_vp8l_code_length_code_bits: usize = 3;
const webp_vp8l_normal_max_symbol_flag_bits: usize = 1;
const webp_vp8l_normal_length_nbits_base: usize = 2;
const webp_vp8l_normal_length_nbits_scale: usize = 2;
const webp_vp8l_normal_length_nbits_selector_bits: usize = 3;
const webp_vp8l_normal_max_symbol_base: usize = 2;
const webp_vp8l_code_length_repeat_previous: u16 = 16;
const webp_vp8l_code_length_repeat_zero_short: u16 = 17;
const webp_vp8l_code_length_repeat_zero_long: u16 = 18;
const webp_vp8l_code_length_repeat_previous_default: u8 = 8;
const webp_vp8l_code_length_repeat_previous_base: usize = 3;
const webp_vp8l_code_length_repeat_previous_bits: usize = 2;
const webp_vp8l_code_length_repeat_zero_short_base: usize = 3;
const webp_vp8l_code_length_repeat_zero_short_bits: usize = 3;
const webp_vp8l_code_length_repeat_zero_long_base: usize = 11;
const webp_vp8l_code_length_repeat_zero_long_bits: usize = 7;
const webp_vp8l_transform_predictor: u2 = 0;
const webp_vp8l_transform_color: u2 = 1;
const webp_vp8l_transform_subtract_green: u2 = 2;
const webp_vp8l_transform_color_indexing: u2 = 3;
const webp_vp8l_transform_max_count: usize = 4;
const webp_vp8l_transform_size_bits_len: usize = 3;
const webp_vp8l_transform_size_bits_base: usize = 2;
const webp_vp8l_predictor_mode_count: usize = 14;
const webp_vp8l_predictor_black_a: u8 = 255;
const webp_vp8l_predictor_black_rgb: u8 = 0;
const webp_vp8l_predictor_mode_black: u8 = 0;
const webp_vp8l_predictor_mode_left: u8 = 1;
const webp_vp8l_predictor_mode_top: u8 = 2;
const webp_vp8l_predictor_mode_top_right: u8 = 3;
const webp_vp8l_predictor_mode_top_left: u8 = 4;
const webp_vp8l_predictor_mode_avg_left_top_right_top: u8 = 5;
const webp_vp8l_predictor_mode_avg_left_top_left: u8 = 6;
const webp_vp8l_predictor_mode_avg_left_top: u8 = 7;
const webp_vp8l_predictor_mode_avg_top_left_top: u8 = 8;
const webp_vp8l_predictor_mode_avg_top_top_right: u8 = 9;
const webp_vp8l_predictor_mode_avg_avg_left_top_left_avg_top_top_right: u8 = 10;
const webp_vp8l_predictor_mode_select: u8 = 11;
const webp_vp8l_predictor_mode_clamp_full: u8 = 12;
const webp_vp8l_predictor_mode_clamp_half: u8 = 13;
const webp_vp8l_color_transform_bytes_per_element: usize = 3;
const webp_vp8l_color_transform_green_to_red_offset: usize = 0;
const webp_vp8l_color_transform_green_to_blue_offset: usize = 1;
const webp_vp8l_color_transform_red_to_blue_offset: usize = 2;
const webp_vp8l_prefix_entry_symbol_offset: usize = 0;
const webp_vp8l_prefix_entry_bits_offset: usize = 2;
const webp_vp8l_prefix_entry_code_offset: usize = 3;
const webp_vp8l_prefix_entry_bytes: usize = 5;
const webp_vp8l_prefix_code_family_count: usize = 5;
const webp_vp8l_prefix_code_max_storage_bytes_per_group: usize =
    (webp_vp8l_green_symbol_count_with_max_cache +
        webp_vp8l_channel_symbol_count +
        webp_vp8l_channel_symbol_count +
        webp_vp8l_channel_symbol_count +
        webp_vp8l_distance_symbol_count) * webp_vp8l_prefix_entry_bytes;
const webp_vp8l_meta_prefix_bits_len: usize = 3;
const webp_vp8l_meta_prefix_bits_base: usize = 2;
const webp_vp8l_meta_prefix_bytes_per_entry: usize = 2;
const webp_vp8l_meta_prefix_single_group: u16 = 0;
const webp_vp8l_meta_prefix_group_count_max: usize = 1 << 16;
const webp_vp8l_meta_prefix_stack_group_max: usize = 2;
const webp_vp8l_color_table_size_bits: usize = 8;
const webp_vp8l_color_table_max_size: usize = 256;
const webp_vp8l_index_bundle_width_bits_1_or_2: usize = 3;
const webp_vp8l_index_bundle_width_bits_3_or_4: usize = 2;
const webp_vp8l_index_bundle_width_bits_5_to_16: usize = 1;
const webp_vp8l_index_bundle_width_bits_none: usize = 0;
const webp_vp8l_index_bundle_threshold_2: usize = 2;
const webp_vp8l_index_bundle_threshold_4: usize = 4;
const webp_vp8l_index_bundle_threshold_16: usize = 16;
const webp_vp8l_transform_type_bits: usize = 2;
const webp_max_legacy_dimension: usize = 16_384;
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
const webp_vp8_inter_intra16_probability_default = [_]u8{ 112, 86, 140, 37 };
const webp_vp8_inter_chroma_probability_default = [_]u8{ 162, 101, 204 };
const webp_vp8_inter_intra16_probability_count: usize = webp_vp8_inter_intra16_probability_default.len;
const webp_vp8_inter_chroma_probability_count: usize = webp_vp8_inter_chroma_probability_default.len;
const webp_vp8_inter_reference_probability_bits: usize = 8;
const webp_vp8_inter_copy_buffer_bits: usize = 2;
const webp_vp8_motion_vector_component_count: usize = 2;
const webp_vp8_motion_vector_probability_count: usize = 19;
const webp_vp8_motion_vector_probability_update_bits: usize = 7;
const webp_vp8_inter_zero_mode_probability: u8 = 7;
const webp_vp8_inter_nearest_mode_probability: u8 = 1;
const webp_vp8_inter_near_mode_probability: u8 = 1;
const webp_vp8_inter_new_mode_probability: u8 = 143;
const webp_vp8_motion_vector_short_probability_index: usize = 0;
const webp_vp8_motion_vector_sign_probability_index: usize = 1;
const webp_vp8_motion_vector_small_probability_index: usize = 2;
const webp_vp8_motion_vector_small_value_max: i16 = 7;
const webp_vp8_motion_vector_whole_pixel_shift: u4 = 2;
const webp_vp8_motion_vector_fraction_mask: i16 = (@as(i16, 1) << webp_vp8_motion_vector_whole_pixel_shift) - 1;
const webp_vp8_coeff_block_types: usize = 4;
const webp_vp8_coeff_band_entries: usize = 17;
const webp_vp8_y_block_count: usize = 16;
const webp_vp8_chroma_block_count: usize = 8;
const webp_vp8_block_coeff_count: usize = 16;
const webp_vp8_macroblock_coeff_block_count: usize = 25;
const webp_vp8_y2_block_index: usize = 24;
const webp_vp8_intra4_dc_mode: usize = 0;
const webp_vp8_intra4_mode_count: usize = 10;
const webp_vp8_intra4_probability_count: usize = 9;
const webp_vp8_intra4_block_width: usize = 4;
const webp_vp8_chroma_block_size: usize = 8;
const webp_vp8_max_luma_edge: usize = ((webp_max_legacy_dimension + webp_vp8_macroblock_size - 1) / webp_vp8_macroblock_size) * webp_vp8_macroblock_size;
const webp_vp8_max_chroma_edge: usize = webp_vp8_max_luma_edge / 2;
const webp_vp8_plane_edge_default: u8 = 127;
const webp_vp8_plane_left_default: u8 = 129;
const webp_vp8_yuv_center: i32 = 128;
const webp_vp8_yuv_round: i32 = 128;
const webp_vp8_yuv_shift: u5 = 8;
const webp_vp8_yuv_v_to_r: i32 = 359;
const webp_vp8_yuv_u_to_g: i32 = 88;
const webp_vp8_yuv_v_to_g: i32 = 183;
const webp_vp8_yuv_u_to_b: i32 = 454;
const webp_vp8_idct_cospi8sqrt2minus1: i32 = 20091;
const webp_vp8_idct_sinpi8sqrt2: i32 = 35468;
const webp_vp8_idct_round: i32 = 4;
const webp_vp8_idct_shift: u5 = 3;
const webp_vp8_wht_round: i32 = 3;
const webp_vp8_wht_shift: u5 = 3;
const webp_vp8_coeff_min_large_value: i16 = 2;
const webp_vp8_coeff_cat3_base: i16 = 11;
const webp_vp8_coeff_cat4_base: i16 = 19;
const webp_vp8_coeff_cat5_base: i16 = 35;
const webp_vp8_coeff_cat6_base: i16 = 67;
const webp_max_canvas_dimension: usize = 16_777_216;
const vp8_neutral_luma: u8 = 128;
const test_webp_vp8_base_partition_len: usize = 8;
const test_webp_vp8_first_partition_len: usize = 160;
const test_webp_vp8_first_partition_extra_len: usize = test_webp_vp8_first_partition_len - test_webp_vp8_base_partition_len;
const test_webp_vp8_token_partition_len: usize = 64;
const test_webp_vp8_fixture_tail_len: usize = test_webp_vp8_first_partition_extra_len + test_webp_vp8_token_partition_len;
const test_webp_vp8_chunk_len: usize = raw_vp8.key_frame_header_size + test_webp_vp8_first_partition_len + test_webp_vp8_token_partition_len;
const test_webp_vp8_len: usize = riff_header_size + riff_chunk_header_size + test_webp_vp8_chunk_len;
const test_webp_vp8x_len: usize = riff_header_size + riff_chunk_header_size + webp_vp8x_payload_size + riff_chunk_header_size + test_webp_vp8_chunk_len;
const test_webp_vp8_gray_len: usize = 44;
const test_webp_vp8_wide_gray_len: usize = 54;
const test_webp_vp8_red_len: usize = 68;
const test_webp_vp8_testsrc32_len: usize = 526;
const test_webp_vp8l_simple_rgba_len: usize = 34;
const test_webp_vp8l_two_color_len: usize = 40;
const test_webp_vp8l_indexed_len: usize = 38;
const test_webp_vp8l_alpha_2x2_len: usize = 60;
const test_webp_vp8l_red_8x8_len: usize = 36;
const test_webp_vp8x_vp8l_red_8x8_len: usize = 54;
const test_webp_vp8l_testsrc2_8x8_len: usize = 228;
const test_webp_vp8l_normal_code_len: usize = 64;
const test_webp_vp8l_lz77_len: usize = 128;
const test_webp_vp8l_subtract_green_len: usize = 36;
const test_webp_vp8l_color_cache_len: usize = 96;
const test_webp_vp8l_predictor_len: usize = 64;
const test_webp_vp8l_color_index_predictor_len: usize = 128;
const test_webp_vp8l_color_transform_len: usize = 64;
const test_webp_vp8l_meta_prefix_len: usize = 64;
const test_webp_vp8l_meta_prefix_multi_len: usize = 96;
const test_webp_vp8l_meta_prefix_three_group_len: usize = 128;
pub fn isWebp(bytes: []const u8) bool {
    return bytes.len >= riff_header_size and
        std.mem.eql(u8, bytes[0..4], riff_signature) and
        std.mem.eql(u8, bytes[8..12], webp_signature);
}
pub fn decodeWebpHeader(bytes: []const u8) DecodeError!Header {
    return (try parseWebp(bytes)).header;
}

pub const WebpAnimationHeader = struct {
    canvas: Header,
    background: ui.Color,
    loop_count: u16,
    frame_count: usize,
};

pub const WebpAnimationFrameInfo = struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,
    duration_ms: usize,
    blend: bool,
    dispose_to_background: bool,
};

pub const WebpAnimationFrame = struct {
    info: WebpAnimationFrameInfo,
    header: Header,
};

pub const WebpAnimationCanvasDecoder = struct {
    bytes: []const u8,
    header: WebpAnimationHeader,
    frame_cursor_start: usize,
    cursor: usize,
    next_frame_index: usize,
    initialized: bool,
    pending_dispose: ?WebpAnimationFrameInfo,

    pub fn init(bytes: []const u8) DecodeError!WebpAnimationCanvasDecoder {
        const start = try parseWebpAnimationStart(bytes);
        return .{
            .bytes = bytes,
            .header = start.header,
            .frame_cursor_start = start.frame_cursor,
            .cursor = start.frame_cursor,
            .next_frame_index = 0,
            .initialized = false,
            .pending_dispose = null,
        };
    }

    pub fn nextFrame(self: *WebpAnimationCanvasDecoder, out: []ui.Color, scratch: []u8) DecodeError!?WebpAnimationFrame {
        const canvas_count = try pixelCount(self.header.canvas);
        if (out.len < canvas_count) return error.PixelBudget;
        if (!self.initialized) {
            @memset(out[0..canvas_count], self.header.background);
            self.initialized = true;
        }
        if (self.next_frame_index >= self.header.frame_count) return null;

        if (self.pending_dispose) |frame| {
            disposeWebpAnimationFrame(self.header.canvas, frame, self.header.background, out[0..canvas_count]);
            self.pending_dispose = null;
        }

        const frame = try self.readNextFrameInfo();
        var scratch_allocator = Vp8lScratch.init(scratch);
        const frame_count = try pixelCount(.{ .width = frame.width, .height = frame.height });
        const frame_pixels = try scratch_allocator.allocItems(ui.Color, frame_count);
        _ = try decodeWebpAnimationFramePayload(
            frame.payload,
            .{ .width = frame.width, .height = frame.height },
            frame_pixels,
            scratch[scratch_allocator.cursor..],
        );
        compositeWebpAnimationFrame(self.header.canvas, frame.frame, frame_pixels, out[0..canvas_count]);
        if (frame.frame.dispose_to_background) self.pending_dispose = frame.frame;
        self.next_frame_index += 1;
        return .{ .info = frame.frame, .header = self.header.canvas };
    }

    pub fn reset(self: *WebpAnimationCanvasDecoder) void {
        self.cursor = self.frame_cursor_start;
        self.next_frame_index = 0;
        self.initialized = false;
        self.pending_dispose = null;
    }

    fn readNextFrameInfo(self: *WebpAnimationCanvasDecoder) DecodeError!WebpAnimationFrameInfoWithPayload {
        while (self.cursor < self.bytes.len) {
            const chunk = try readWebpChunk(self.bytes, &self.cursor);
            if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_anmf)) {
                return parseWebpAnmf(chunk.data, self.header.canvas);
            } else if (isMetadataWebpChunk(chunk.chunk_type)) {
                continue;
            } else if (isCriticalWebpChunk(chunk.chunk_type)) {
                return error.UnsupportedImage;
            }
        }
        return error.BadImage;
    }
};

pub fn decodeWebpAnimationHeader(bytes: []const u8) DecodeError!WebpAnimationHeader {
    return parseWebpAnimationHeader(bytes);
}

pub fn decodeWebpAnimationFrame(bytes: []const u8, frame_index: usize, out: []ui.Color) DecodeError!WebpAnimationFrame {
    return decodeWebpAnimationFrameWithScratch(bytes, frame_index, out, &.{});
}

pub fn webpAnimationFrameScratchByteLen(bytes: []const u8, frame_index: usize) usize {
    return webpAnimationFrameScratchByteLenChecked(bytes, frame_index) catch @panic("webp animation frame scratch byte length overflow");
}

pub fn webpAnimationCanvasScratchByteLen(bytes: []const u8, frame_index: usize) usize {
    return webpAnimationCanvasScratchByteLenChecked(bytes, frame_index) catch @panic("webp animation canvas scratch byte length overflow");
}

pub fn webpAnimationDecoderScratchByteLen(bytes: []const u8) usize {
    return webpAnimationDecoderScratchByteLenChecked(bytes) catch @panic("webp animation decoder scratch byte length overflow");
}

pub fn decodeWebpAnimationFrameWithScratch(bytes: []const u8, frame_index: usize, out: []ui.Color, scratch: []u8) DecodeError!WebpAnimationFrame {
    const info = try parseWebpAnimationFrameInfo(bytes, frame_index);
    const count = try pixelCount(.{ .width = info.width, .height = info.height });
    if (out.len < count) return error.PixelBudget;
    _ = try decodeWebpAnimationFramePayload(info.payload, .{ .width = info.width, .height = info.height }, out[0..count], scratch);
    return .{ .info = info.frame, .header = .{ .width = info.width, .height = info.height } };
}

pub fn decodeWebpAnimationCanvasFrame(bytes: []const u8, frame_index: usize, out: []ui.Color) DecodeError!WebpAnimationFrame {
    return decodeWebpAnimationCanvasFrameWithScratch(bytes, frame_index, out, &.{});
}

pub fn decodeWebpAnimationCanvasFrameWithScratch(bytes: []const u8, frame_index: usize, out: []ui.Color, scratch: []u8) DecodeError!WebpAnimationFrame {
    const animation = try parseWebpAnimationHeader(bytes);
    if (frame_index >= animation.frame_count) return error.BadImage;
    const canvas_count = try pixelCount(animation.canvas);
    if (out.len < canvas_count) return error.PixelBudget;
    @memset(out[0..canvas_count], animation.background);

    var scratch_allocator = Vp8lScratch.init(scratch);
    const max_frame_pixels = try maxWebpAnimationFramePixels(bytes, frame_index);
    const frame_pixels = try scratch_allocator.allocItems(ui.Color, max_frame_pixels);
    const decode_scratch = scratch[scratch_allocator.cursor..];

    var current_index: usize = 0;
    while (current_index <= frame_index) : (current_index += 1) {
        const frame = try parseWebpAnimationFrameInfo(bytes, current_index);
        const frame_count = try pixelCount(.{ .width = frame.width, .height = frame.height });
        _ = try decodeWebpAnimationFramePayload(frame.payload, .{ .width = frame.width, .height = frame.height }, frame_pixels[0..frame_count], decode_scratch);
        compositeWebpAnimationFrame(animation.canvas, frame.frame, frame_pixels[0..frame_count], out[0..canvas_count]);
        if (current_index != frame_index and frame.frame.dispose_to_background) {
            disposeWebpAnimationFrame(animation.canvas, frame.frame, animation.background, out[0..canvas_count]);
        }
    }

    const frame = try parseWebpAnimationFrameInfo(bytes, frame_index);
    return .{ .info = frame.frame, .header = animation.canvas };
}

pub fn webpScratchByteLen(bytes: []const u8, width: usize, height: usize) usize {
    return webpScratchByteLenChecked(bytes, width, height) catch @panic("webp scratch byte length overflow");
}

fn webpScratchByteLenChecked(bytes: []const u8, width: usize, height: usize) DecodeError!usize {
    const info = try parseWebp(bytes);
    if (info.header.width != width or info.header.height != height) return error.BadImage;
    if ((info.feature_flags & webp_vp8x_decode_blocking_flags) != 0) return error.UnsupportedImage;
    if (info.alpha_data) |alpha_data| return webpAlphaScratchByteLen(alpha_data, info.header);
    if (std.mem.eql(u8, info.chunk_type, webp_chunk_vp8)) return 0;
    if (!std.mem.eql(u8, info.chunk_type, webp_chunk_vp8l)) return 0;

    return webpVp8lScratchByteLen(bytes.len, info.header);
}

fn webpAnimationFrameScratchByteLenChecked(bytes: []const u8, frame_index: usize) DecodeError!usize {
    const info = try parseWebpAnimationFrameInfo(bytes, frame_index);
    return webpAnimationPayloadScratchByteLen(info.payload, .{ .width = info.width, .height = info.height });
}

fn webpAnimationCanvasScratchByteLenChecked(bytes: []const u8, frame_index: usize) DecodeError!usize {
    const animation = try parseWebpAnimationHeader(bytes);
    if (frame_index >= animation.frame_count) return error.BadImage;
    const max_frame_pixels = try maxWebpAnimationFramePixels(bytes, frame_index);
    const pixel_bytes = try checkedMul(max_frame_pixels, @sizeOf(ui.Color));
    const aligned_pixel_bytes = try checkedAdd(pixel_bytes, @alignOf(ui.Color) - 1);
    var max_payload_scratch: usize = 0;
    var current_index: usize = 0;
    while (current_index <= frame_index) : (current_index += 1) {
        const info = try parseWebpAnimationFrameInfo(bytes, current_index);
        const payload_scratch = try webpAnimationPayloadScratchByteLen(info.payload, .{ .width = info.width, .height = info.height });
        max_payload_scratch = @max(max_payload_scratch, payload_scratch);
    }
    return checkedAdd(aligned_pixel_bytes, max_payload_scratch);
}

fn webpAnimationDecoderScratchByteLenChecked(bytes: []const u8) DecodeError!usize {
    const animation = try parseWebpAnimationHeader(bytes);
    if (animation.frame_count == 0) return error.BadImage;
    return webpAnimationCanvasScratchByteLenChecked(bytes, animation.frame_count - 1);
}

fn webpVp8lScratchByteLen(encoded_len: usize, header: Header) DecodeError!usize {
    const pixel_count = try pixelCount(header);
    const transform_data = try vp8lTransformScratchByteLen(pixel_count);
    const entropy_decode = try vp8lEntropyScratchByteLen(encoded_len);
    return checkedAdd(transform_data, entropy_decode);
}

pub fn decodeWebp(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    return decodeWebpWithScratch(bytes, out, &.{});
}

pub fn decodeWebpWithScratch(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    const info = try parseWebp(bytes);
    if ((info.feature_flags & webp_vp8x_decode_blocking_flags) != 0) return error.UnsupportedImage;
    if (std.mem.eql(u8, info.chunk_type, webp_chunk_vp8)) {
        return decodeVp8FrameWithAlpha(info.primary_data, info.alpha_data, info.header, out, scratch);
    } else if (std.mem.eql(u8, info.chunk_type, webp_chunk_vp8l)) {
        if (info.alpha_data != null) return error.BadImage;
        return decodeVp8lFrame(info.primary_data, info.header, out, scratch);
    } else if (std.mem.eql(u8, info.chunk_type, webp_chunk_vp8x)) {
        if (info.vp8_data) |vp8_data| return decodeVp8FrameWithAlpha(vp8_data, info.alpha_data, info.header, out, scratch);
    }
    return error.UnsupportedImage;
}

pub fn decodeVp8KeyFrame(data: []const u8, expected_header: Header, out: []ui.Color) DecodeError!Header {
    const frame_tag = try raw_vp8.parseFrameTag(data);
    switch (frame_tag.frame_type) {
        .key => return decodeVp8Frame(data, expected_header, out),
        .inter => return error.UnsupportedImage,
    }
}

pub fn decodeVp8VideoFrame(data: []const u8, expected_header: Header, out: []ui.Color) DecodeError!Header {
    return decodeVp8VideoFrameWithReference(data, expected_header, out, null);
}

pub fn decodeVp8VideoFrameWithReference(data: []const u8, expected_header: Header, out: []ui.Color, previous: ?[]const u8) DecodeError!Header {
    return decodeVp8FrameWithReference(data, expected_header, out, previous);
}

fn decodeVp8FrameWithAlpha(data: []const u8, alpha_data: ?[]const u8, expected_header: Header, out: []ui.Color, scratch: []u8) DecodeError!Header {
    const header = try decodeVp8KeyFrame(data, expected_header, out);
    if (alpha_data) |data_alpha| {
        const count = try pixelCount(header);
        try applyWebpAlpha(data_alpha, header, out[0..count], scratch);
    }
    return header;
}

fn decodeVp8Frame(data: []const u8, expected_header: Header, out: []ui.Color) DecodeError!Header {
    return decodeVp8FrameWithReference(data, expected_header, out, null);
}

fn decodeVp8FrameWithReference(data: []const u8, expected_header: Header, out: []ui.Color, previous: ?[]const u8) DecodeError!Header {
    const frame = try parseVp8Frame(data, expected_header);
    if (frame.header.width != expected_header.width or frame.header.height != expected_header.height) return error.UnsupportedImage;
    const count = try pixelCount(frame.header);
    if (out.len < count) return error.PixelBudget;
    if (previous) |reference| {
        if (reference.len < count * @sizeOf(ui.Color)) return error.PixelBudget;
    }
    try reconstructVp8Frame(&frame, previous, out[0..count]);
    return frame.header;
}

fn decodeVp8lFrame(data: []const u8, expected_header: Header, out: []ui.Color, scratch: []u8) DecodeError!Header {
    const header = try parseWebpVp8lHeader(data);
    if (header.width != expected_header.width or header.height != expected_header.height) return error.UnsupportedImage;
    const count = try pixelCount(header);
    if (out.len < count) return error.PixelBudget;
    var reader = Vp8lBitReader.init(data[webp_vp8l_header_size..]);
    try decodeVp8lPixels(&reader, header, out[0..count], scratch);
    return header;
}

const WebpAnimationFrameInfoWithPayload = struct {
    frame: WebpAnimationFrameInfo,
    width: usize,
    height: usize,
    payload: []const u8,
};

const WebpAnimationStart = struct {
    header: WebpAnimationHeader,
    frame_cursor: usize,
};

fn parseWebpAnimationHeader(bytes: []const u8) DecodeError!WebpAnimationHeader {
    return (try parseWebpAnimationStart(bytes)).header;
}

fn parseWebpAnimationStart(bytes: []const u8) DecodeError!WebpAnimationStart {
    if (!isWebp(bytes)) return error.UnsupportedImage;
    try validateWebpRiffLen(bytes);

    var cursor: usize = riff_header_size;
    var vp8x: ?WebpVp8xInfo = null;
    var anim: ?WebpAnimInfo = null;
    var frame_cursor: ?usize = null;
    var frame_count: usize = 0;
    while (cursor < bytes.len) {
        const chunk_cursor = cursor;
        const chunk = try readWebpChunk(bytes, &cursor);
        if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8x)) {
            if (vp8x != null or anim != null or frame_count != 0) return error.BadImage;
            vp8x = try parseWebpVp8x(chunk.data);
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_anim)) {
            if (vp8x == null or anim != null or frame_count != 0) return error.BadImage;
            anim = try parseWebpAnim(chunk.data);
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_anmf)) {
            if (vp8x == null or anim == null) return error.BadImage;
            if (frame_cursor == null) frame_cursor = chunk_cursor;
            const frame = try parseWebpAnmf(chunk.data, vp8x.?.header);
            try validateWebpAnimationFramePayload(frame.payload, .{ .width = frame.width, .height = frame.height });
            frame_count = try checkedAdd(frame_count, 1);
        } else if (isMetadataWebpChunk(chunk.chunk_type)) {
            continue;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8) or
            std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8l) or
            std.mem.eql(u8, chunk.chunk_type, webp_chunk_alph))
        {
            return error.BadImage;
        } else if (isCriticalWebpChunk(chunk.chunk_type)) {
            return error.UnsupportedImage;
        }
    }

    if (vp8x == null or anim == null or frame_count == 0) return error.BadImage;
    if ((vp8x.?.flags & webp_vp8x_flag_animation) == 0) return error.BadImage;
    return .{
        .header = .{
            .canvas = vp8x.?.header,
            .background = anim.?.background,
            .loop_count = anim.?.loop_count,
            .frame_count = frame_count,
        },
        .frame_cursor = frame_cursor.?,
    };
}

fn parseWebpAnimationFrameInfo(bytes: []const u8, target_frame_index: usize) DecodeError!WebpAnimationFrameInfoWithPayload {
    if (!isWebp(bytes)) return error.UnsupportedImage;
    try validateWebpRiffLen(bytes);

    var cursor: usize = riff_header_size;
    var vp8x: ?WebpVp8xInfo = null;
    var saw_anim = false;
    var frame_index: usize = 0;
    while (cursor < bytes.len) {
        const chunk = try readWebpChunk(bytes, &cursor);
        if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8x)) {
            if (vp8x != null or saw_anim or frame_index != 0) return error.BadImage;
            vp8x = try parseWebpVp8x(chunk.data);
            if ((vp8x.?.flags & webp_vp8x_flag_animation) == 0) return error.BadImage;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_anim)) {
            if (vp8x == null or saw_anim or frame_index != 0) return error.BadImage;
            _ = try parseWebpAnim(chunk.data);
            saw_anim = true;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_anmf)) {
            if (vp8x == null or !saw_anim) return error.BadImage;
            const frame = try parseWebpAnmf(chunk.data, vp8x.?.header);
            try validateWebpAnimationFramePayload(frame.payload, .{ .width = frame.width, .height = frame.height });
            if (frame_index == target_frame_index) return frame;
            frame_index = try checkedAdd(frame_index, 1);
        } else if (isMetadataWebpChunk(chunk.chunk_type)) {
            continue;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8) or
            std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8l) or
            std.mem.eql(u8, chunk.chunk_type, webp_chunk_alph))
        {
            return error.BadImage;
        } else if (isCriticalWebpChunk(chunk.chunk_type)) {
            return error.UnsupportedImage;
        }
    }
    return error.BadImage;
}

fn decodeWebpAnimationFramePayload(data: []const u8, expected_header: Header, out: []ui.Color, scratch: []u8) DecodeError!Header {
    var cursor: usize = 0;
    var alpha_data: ?[]const u8 = null;
    var vp8_data: ?[]const u8 = null;
    var vp8l_data: ?[]const u8 = null;
    while (cursor < data.len) {
        const chunk = try readWebpFrameChunk(data, &cursor);
        if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_alph)) {
            if (alpha_data != null or vp8_data != null or vp8l_data != null) return error.BadImage;
            alpha_data = chunk.data;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8)) {
            if (vp8_data != null or vp8l_data != null) return error.BadImage;
            vp8_data = chunk.data;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8l)) {
            if (vp8_data != null or vp8l_data != null or alpha_data != null) return error.BadImage;
            vp8l_data = chunk.data;
        } else if (isMetadataWebpChunk(chunk.chunk_type)) {
            continue;
        } else if (isCriticalWebpChunk(chunk.chunk_type)) {
            return error.UnsupportedImage;
        }
    }

    if (vp8_data) |data_vp8| return decodeVp8FrameWithAlpha(data_vp8, alpha_data, expected_header, out, scratch);
    if (vp8l_data) |data_vp8l| return decodeVp8lFrame(data_vp8l, expected_header, out, scratch);
    return error.BadImage;
}

fn webpAnimationPayloadScratchByteLen(data: []const u8, expected_header: Header) DecodeError!usize {
    var cursor: usize = 0;
    var alpha_data: ?[]const u8 = null;
    var vp8_data: ?[]const u8 = null;
    var vp8l_data: ?[]const u8 = null;
    while (cursor < data.len) {
        const chunk = try readWebpFrameChunk(data, &cursor);
        if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_alph)) {
            if (alpha_data != null or vp8_data != null or vp8l_data != null) return error.BadImage;
            alpha_data = chunk.data;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8)) {
            if (vp8_data != null or vp8l_data != null) return error.BadImage;
            const header = try raw_vp8.parseKeyFrameHeader(chunk.data);
            if (header.width != expected_header.width or header.height != expected_header.height) return error.UnsupportedImage;
            vp8_data = chunk.data;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8l)) {
            if (vp8_data != null or vp8l_data != null or alpha_data != null) return error.BadImage;
            const header = try parseWebpVp8lHeader(chunk.data);
            if (header.width != expected_header.width or header.height != expected_header.height) return error.UnsupportedImage;
            vp8l_data = chunk.data;
        } else if (isMetadataWebpChunk(chunk.chunk_type)) {
            continue;
        } else if (isCriticalWebpChunk(chunk.chunk_type)) {
            return error.UnsupportedImage;
        }
    }

    if (vp8_data != null) {
        if (alpha_data) |data_alpha| return webpAlphaScratchByteLen(data_alpha, expected_header);
        return 0;
    }
    if (vp8l_data) |data_vp8l| return webpVp8lScratchByteLen(data_vp8l.len, expected_header);
    return error.BadImage;
}

fn validateWebpAnimationFramePayload(data: []const u8, expected_header: Header) DecodeError!void {
    _ = try webpAnimationPayloadScratchByteLen(data, expected_header);
}

fn maxWebpAnimationFramePixels(bytes: []const u8, max_frame_index: usize) DecodeError!usize {
    var max_pixels: usize = 0;
    var frame_index: usize = 0;
    while (frame_index <= max_frame_index) : (frame_index += 1) {
        const info = try parseWebpAnimationFrameInfo(bytes, frame_index);
        max_pixels = @max(max_pixels, try pixelCount(.{ .width = info.width, .height = info.height }));
    }
    return max_pixels;
}

fn compositeWebpAnimationFrame(canvas: Header, frame: WebpAnimationFrameInfo, frame_pixels: []const ui.Color, out: []ui.Color) void {
    var y: usize = 0;
    while (y < frame.height) : (y += 1) {
        var x: usize = 0;
        while (x < frame.width) : (x += 1) {
            const src = frame_pixels[y * frame.width + x];
            const dst_index = (frame.y + y) * canvas.width + frame.x + x;
            out[dst_index] = if (frame.blend) blendWebpAnimationPixel(src, out[dst_index]) else src;
        }
    }
}

fn disposeWebpAnimationFrame(canvas: Header, frame: WebpAnimationFrameInfo, background: ui.Color, out: []ui.Color) void {
    var y: usize = 0;
    while (y < frame.height) : (y += 1) {
        const row_start = (frame.y + y) * canvas.width + frame.x;
        @memset(out[row_start..][0..frame.width], background);
    }
}

fn blendWebpAnimationPixel(src: ui.Color, dst: ui.Color) ui.Color {
    if (src.a == 0) return dst;
    if (src.a == png_alpha_opaque) return src;
    const inverse_alpha = png_alpha_opaque - @as(usize, src.a);
    const dst_alpha_scaled = @as(usize, dst.a) * inverse_alpha;
    const out_alpha = @as(usize, src.a) + (dst_alpha_scaled / png_alpha_opaque);
    if (out_alpha == 0) return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    return .{
        .r = blendWebpAnimationChannel(src.r, src.a, dst.r, dst.a, inverse_alpha, out_alpha),
        .g = blendWebpAnimationChannel(src.g, src.a, dst.g, dst.a, inverse_alpha, out_alpha),
        .b = blendWebpAnimationChannel(src.b, src.a, dst.b, dst.a, inverse_alpha, out_alpha),
        .a = @intCast(out_alpha),
    };
}

fn blendWebpAnimationChannel(src: u8, src_alpha: u8, dst: u8, dst_alpha: u8, inverse_alpha: usize, out_alpha: usize) u8 {
    const numerator = @as(usize, src) * @as(usize, src_alpha) * png_alpha_opaque +
        @as(usize, dst) * @as(usize, dst_alpha) * inverse_alpha;
    return @intCast(numerator / (out_alpha * png_alpha_opaque));
}

const WebpAnimInfo = struct {
    background: ui.Color,
    loop_count: u16,
};

fn parseWebpAnim(data: []const u8) DecodeError!WebpAnimInfo {
    if (data.len != webp_anim_payload_size) return error.BadImage;
    return .{
        .background = .{
            .r = data[webp_anim_background_red_index],
            .g = data[webp_anim_background_green_index],
            .b = data[webp_anim_background_blue_index],
            .a = data[webp_anim_background_alpha_index],
        },
        .loop_count = readU16Le(data[webp_anim_loop_count_index..][0..2]),
    };
}

fn parseWebpAnmf(data: []const u8, canvas: Header) DecodeError!WebpAnimationFrameInfoWithPayload {
    if (data.len <= webp_anmf_header_size) return error.BadImage;
    const flags = data[webp_anmf_flags_index];
    if ((flags & webp_anmf_reserved_mask) != 0) return error.BadImage;
    const x = try checkedMul(readU24Le(data[webp_anmf_x_index..][0..3]), 2);
    const y = try checkedMul(readU24Le(data[webp_anmf_y_index..][0..3]), 2);
    const width = readU24Le(data[webp_anmf_width_index..][0..3]) + 1;
    const height = readU24Le(data[webp_anmf_height_index..][0..3]) + 1;
    if (width == 0 or height == 0) return error.BadImage;
    if (x > canvas.width or y > canvas.height) return error.BadImage;
    if (width > canvas.width - x or height > canvas.height - y) return error.BadImage;
    return .{
        .frame = .{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .duration_ms = readU24Le(data[webp_anmf_duration_index..][0..3]),
            .blend = (flags & webp_anmf_blend_flag) == 0,
            .dispose_to_background = (flags & webp_anmf_dispose_flag) != 0,
        },
        .width = width,
        .height = height,
        .payload = data[webp_anmf_header_size..],
    };
}

const WebpChunk = struct {
    chunk_type: []const u8,
    data: []const u8,
};

fn validateWebpRiffLen(bytes: []const u8) DecodeError!void {
    const riff_len: usize = readU32Le(bytes[4..][0..4]);
    if (riff_len < 4) return error.BadImage;
    if (riff_len > std.math.maxInt(usize) - 8) return error.PixelBudget;
    if (riff_len + 8 != bytes.len) return error.BadImage;
}

fn readWebpChunk(bytes: []const u8, cursor: *usize) DecodeError!WebpChunk {
    if (bytes.len - cursor.* < riff_chunk_header_size) return error.BadImage;
    return readWebpFrameChunk(bytes, cursor);
}

fn readWebpFrameChunk(bytes: []const u8, cursor: *usize) DecodeError!WebpChunk {
    if (bytes.len - cursor.* < riff_chunk_header_size) return error.BadImage;
    const chunk_type = bytes[cursor.*..][0..4];
    cursor.* += 4;
    const chunk_len: usize = readU32Le(bytes[cursor.*..][0..4]);
    cursor.* += 4;
    if (chunk_len > bytes.len - cursor.*) return error.BadImage;
    const data = bytes[cursor.*..][0..chunk_len];
    cursor.* += chunk_len;
    if ((chunk_len & 1) != 0) {
        if (cursor.* >= bytes.len) return error.BadImage;
        cursor.* += 1;
    }
    return .{ .chunk_type = chunk_type, .data = data };
}

fn webpAlphaScratchByteLen(data: []const u8, header: Header) DecodeError!usize {
    const alpha_info = try parseWebpAlphaInfo(data);
    return switch (alpha_info.compression) {
        webp_alph_compression_none => 0,
        webp_alph_compression_vp8l => blk: {
            const pixel_count = try pixelCount(header);
            const pixel_bytes = try checkedMul(pixel_count, @sizeOf(ui.Color));
            const aligned_pixel_bytes = try checkedAdd(pixel_bytes, @alignOf(ui.Color) - 1);
            const transform_data = try vp8lTransformScratchByteLen(pixel_count);
            const entropy_decode = try vp8lEntropyScratchByteLen(alpha_info.bitstream.len);
            break :blk checkedAdd(aligned_pixel_bytes, try checkedAdd(transform_data, entropy_decode));
        },
        else => error.BadImage,
    };
}

fn applyWebpAlpha(data: []const u8, header: Header, out: []ui.Color, scratch: []u8) DecodeError!void {
    const alpha_info = try parseWebpAlphaInfo(data);
    switch (alpha_info.compression) {
        webp_alph_compression_none => try applyWebpAlphaValues(alpha_info.bitstream, alpha_info.filter, header, out),
        webp_alph_compression_vp8l => try applyWebpCompressedAlpha(alpha_info.bitstream, alpha_info.filter, header, out, scratch),
        else => return error.BadImage,
    }
}

const WebpAlphaInfo = struct {
    compression: u8,
    filter: u8,
    bitstream: []const u8,
};

fn parseWebpAlphaInfo(data: []const u8) DecodeError!WebpAlphaInfo {
    if (data.len < webp_alph_header_size) return error.BadImage;
    const alpha_header = data[0];
    const compression = alpha_header & webp_alph_compression_mask;
    const filter = (alpha_header & webp_alph_filter_mask) >> webp_alph_filter_shift;
    _ = alpha_header & webp_alph_preprocessing_mask;
    _ = alpha_header & webp_alph_reserved_mask;
    if (compression != webp_alph_compression_none and compression != webp_alph_compression_vp8l) return error.BadImage;
    return .{
        .compression = compression,
        .filter = filter,
        .bitstream = data[webp_alph_header_size..],
    };
}

fn applyWebpCompressedAlpha(data: []const u8, filter: u8, header: Header, out: []ui.Color, scratch: []u8) DecodeError!void {
    const count = try pixelCount(header);
    var scratch_allocator = Vp8lScratch.init(scratch);
    const alpha_pixels = try scratch_allocator.allocItems(ui.Color, count);
    var reader = Vp8lBitReader.init(data);
    try decodeVp8lPixels(&reader, header, alpha_pixels, scratch[scratch_allocator.cursor..]);
    var index: usize = 0;
    while (index < count) : (index += 1) out[index].a = alpha_pixels[index].g;
    try applyWebpAlphaFilter(filter, header, out);
}

fn applyWebpAlphaValues(alpha: []const u8, filter: u8, header: Header, out: []ui.Color) DecodeError!void {
    const count = try pixelCount(header);
    if (alpha.len != count) return error.BadImage;
    var index: usize = 0;
    while (index < count) : (index += 1) out[index].a = alpha[index];
    try applyWebpAlphaFilter(filter, header, out);
}

fn applyWebpAlphaFilter(filter: u8, header: Header, out: []ui.Color) DecodeError!void {
    switch (filter) {
        webp_alph_filter_none => return,
        webp_alph_filter_horizontal, webp_alph_filter_vertical, webp_alph_filter_gradient => {},
        else => return error.BadImage,
    }

    var y: usize = 0;
    while (y < header.height) : (y += 1) {
        var x: usize = 0;
        while (x < header.width) : (x += 1) {
            const index = y * header.width + x;
            const predictor = webpAlphaPredictor(filter, header.width, out, x, y);
            out[index].a +%= predictor;
        }
    }
}

fn webpAlphaPredictor(filter: u8, width: usize, out: []const ui.Color, x: usize, y: usize) u8 {
    const index = y * width + x;
    return switch (filter) {
        webp_alph_filter_horizontal => if (x == 0)
            if (y == 0) 0 else out[index - width].a
        else
            out[index - 1].a,
        webp_alph_filter_vertical => if (y == 0)
            if (x == 0) 0 else out[index - 1].a
        else
            out[index - width].a,
        webp_alph_filter_gradient => if (x == 0)
            if (y == 0) 0 else out[index - width].a
        else if (y == 0)
            out[index - 1].a
        else
            webpAlphaGradient(
                out[index - 1].a,
                out[index - width].a,
                out[index - width - 1].a,
            ),
        else => 0,
    };
}

fn webpAlphaGradient(left: u8, top: u8, top_left: u8) u8 {
    return clampU8(@as(i32, left) + @as(i32, top) - @as(i32, top_left));
}

const WebpInfo = struct {
    header: Header,
    chunk_type: *const [4]u8,
    primary_data: []const u8,
    vp8_data: ?[]const u8 = null,
    alpha_data: ?[]const u8 = null,
    feature_flags: u8 = 0,
};

fn parseWebp(bytes: []const u8) DecodeError!WebpInfo {
    if (!isWebp(bytes)) return error.UnsupportedImage;
    try validateWebpRiffLen(bytes);

    var cursor: usize = riff_header_size;
    var header: ?Header = null;
    var primary_chunk: ?*const [4]u8 = null;
    var primary_data: []const u8 = &.{};
    var vp8_data: ?[]const u8 = null;
    var alpha_data: ?[]const u8 = null;
    var feature_flags: u8 = 0;
    var saw_primary = false;
    while (cursor < bytes.len) {
        const chunk = try readWebpChunk(bytes, &cursor);

        if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8x)) {
            if (saw_primary or header != null) return error.BadImage;
            const vp8x = try parseWebpVp8x(chunk.data);
            header = vp8x.header;
            feature_flags = vp8x.flags;
            primary_chunk = webp_chunk_vp8x;
            primary_data = chunk.data;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8l)) {
            if (saw_primary) return error.BadImage;
            if (header == null) header = try parseWebpVp8lHeader(chunk.data);
            primary_chunk = webp_chunk_vp8l;
            primary_data = chunk.data;
            saw_primary = true;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_vp8)) {
            if (saw_primary) return error.BadImage;
            if (header == null) {
                header = try raw_vp8.parseKeyFrameHeader(chunk.data);
                primary_chunk = webp_chunk_vp8;
            } else {
                _ = try raw_vp8.parseKeyFrameHeader(chunk.data);
            }
            if (primary_data.len == 0) primary_data = chunk.data;
            vp8_data = chunk.data;
            saw_primary = true;
        } else if (std.mem.eql(u8, chunk.chunk_type, webp_chunk_alph)) {
            if (alpha_data != null or saw_primary or header == null) return error.BadImage;
            alpha_data = chunk.data;
        } else if (isMetadataWebpChunk(chunk.chunk_type)) {
            continue;
        } else if (isUnsupportedWebpImageChunk(chunk.chunk_type)) {
            return error.UnsupportedImage;
        } else if (isCriticalWebpChunk(chunk.chunk_type)) {
            return error.UnsupportedImage;
        }
    }
    if (!saw_primary or header == null or primary_chunk == null) return error.BadImage;
    if (alpha_data != null) {
        if (vp8_data == null or (feature_flags & webp_vp8x_flag_alpha) == 0) return error.BadImage;
    } else if (vp8_data != null and (feature_flags & webp_vp8x_flag_alpha) != 0) {
        return error.BadImage;
    }
    return .{
        .header = header.?,
        .chunk_type = primary_chunk.?,
        .primary_data = primary_data,
        .vp8_data = vp8_data,
        .alpha_data = alpha_data,
        .feature_flags = feature_flags,
    };
}

const WebpVp8xInfo = struct {
    header: Header,
    flags: u8,
};

fn parseWebpVp8x(data: []const u8) DecodeError!WebpVp8xInfo {
    if (data.len != webp_vp8x_payload_size) return error.BadImage;
    const flags = data[webp_vp8x_flags_index];
    if ((flags & ~webp_vp8x_known_flags) != 0) return error.BadImage;
    const width = readU24Le(data[webp_vp8x_width_index..][0..3]) + 1;
    const height = readU24Le(data[webp_vp8x_height_index..][0..3]) + 1;
    if (width == 0 or height == 0 or width > webp_max_canvas_dimension or height > webp_max_canvas_dimension) return error.BadImage;
    return .{ .header = .{ .width = width, .height = height }, .flags = flags };
}

fn parseWebpVp8lHeader(data: []const u8) DecodeError!Header {
    if (data.len < webp_vp8l_header_size or data[0] != webp_vp8l_signature) return error.BadImage;
    const bits = readU32Le(data[1..][0..4]);
    const version = (bits >> webp_vp8l_version_shift) & webp_vp8l_version_mask;
    if (version != webp_vp8l_expected_version) return error.UnsupportedImage;
    const width = @as(usize, bits & webp_vp8l_dimension_mask) + 1;
    const height = @as(usize, (bits >> webp_vp8l_height_shift) & webp_vp8l_dimension_mask) + 1;
    if (width == 0 or height == 0 or width > webp_max_legacy_dimension or height > webp_max_legacy_dimension) return error.BadImage;
    return .{ .width = width, .height = height };
}

const Vp8lPrefixCode = union(enum) {
    empty: void,
    one: u16,
    two: struct {
        low: u16,
        high: u16,
    },
    normal: Vp8lCanonicalPrefixCode,

    fn read(self: Vp8lPrefixCode, reader: *Vp8lBitReader) DecodeError!u16 {
        return switch (self) {
            .empty => error.BadImage,
            .one => |symbol| symbol,
            .two => |symbols| if (try reader.readFlag()) symbols.high else symbols.low,
            .normal => |code| code.read(reader),
        };
    }
};

const Vp8lPrefixEntry = struct {
    symbol: u16,
    bits: u8,
    code: u16,
};

const Vp8lPrefixStats = struct {
    length_counts: [webp_vp8l_prefix_code_max_bits + 1]usize,
    non_zero_count: usize,
    single_symbol: u16,
};

const Vp8lCanonicalPrefixCode = struct {
    entries: []const u8,
    count: usize,

    fn read(self: Vp8lCanonicalPrefixCode, reader: *Vp8lBitReader) DecodeError!u16 {
        var code: u16 = 0;
        var bits: usize = 1;
        while (bits <= webp_vp8l_prefix_code_max_bits) : (bits += 1) {
            if (try reader.readFlag()) code |= @as(u16, 1) << @intCast(bits - 1);
            const bit_count: u8 = @intCast(bits);
            var entry_index: usize = 0;
            while (entry_index < self.count) : (entry_index += 1) {
                const entry = self.entryAt(entry_index);
                if (entry.bits == bit_count and entry.code == code) return entry.symbol;
            }
        }
        return error.BadImage;
    }

    fn entryAt(self: Vp8lCanonicalPrefixCode, index: usize) Vp8lPrefixEntry {
        const offset = index * webp_vp8l_prefix_entry_bytes;
        return .{
            .symbol = readU16Le(self.entries[offset + webp_vp8l_prefix_entry_symbol_offset ..][0..2]),
            .bits = self.entries[offset + webp_vp8l_prefix_entry_bits_offset],
            .code = readU16Le(self.entries[offset + webp_vp8l_prefix_entry_code_offset ..][0..2]),
        };
    }
};

const Vp8lColorCache = struct {
    enabled: bool,
    bits: usize,
    size: usize,
    entries: [webp_vp8l_color_cache_max_size]ui.Color,

    fn none() Vp8lColorCache {
        return .{
            .enabled = false,
            .bits = 0,
            .size = 0,
            .entries = [_]ui.Color{.{ .r = 0, .g = 0, .b = 0, .a = 0 }} ** webp_vp8l_color_cache_max_size,
        };
    }

    fn init(bits: usize) DecodeError!Vp8lColorCache {
        if (bits < webp_vp8l_color_cache_min_bits or bits > webp_vp8l_color_cache_max_bits) return error.BadImage;
        return .{
            .enabled = true,
            .bits = bits,
            .size = @as(usize, 1) << @intCast(bits),
            .entries = [_]ui.Color{.{ .r = 0, .g = 0, .b = 0, .a = 0 }} ** webp_vp8l_color_cache_max_size,
        };
    }

    fn lookup(self: *const Vp8lColorCache, index: usize) DecodeError!ui.Color {
        if (!self.enabled or index >= self.size) return error.BadImage;
        return self.entries[index];
    }

    fn insert(self: *Vp8lColorCache, pixel: ui.Color) void {
        if (!self.enabled) return;
        self.entries[self.hash(pixel)] = pixel;
    }

    fn hash(self: *const Vp8lColorCache, pixel: ui.Color) usize {
        const argb = (@as(u32, pixel.a) << 24) |
            (@as(u32, pixel.r) << 16) |
            (@as(u32, pixel.g) << 8) |
            @as(u32, pixel.b);
        return @intCast((argb *% webp_vp8l_color_cache_hash_multiplier) >> @intCast(webp_vp8l_color_cache_hash_width - self.bits));
    }
};

const Vp8lDistanceOffset = struct {
    x: i16,
    y: i16,
};

const webp_vp8l_distance_offsets = [_]Vp8lDistanceOffset{
    .{ .x = 0, .y = 1 },  .{ .x = 1, .y = 0 },  .{ .x = 1, .y = 1 },  .{ .x = -1, .y = 1 },
    .{ .x = 0, .y = 2 },  .{ .x = 2, .y = 0 },  .{ .x = 1, .y = 2 },  .{ .x = -1, .y = 2 },
    .{ .x = 2, .y = 1 },  .{ .x = -2, .y = 1 }, .{ .x = 2, .y = 2 },  .{ .x = -2, .y = 2 },
    .{ .x = 0, .y = 3 },  .{ .x = 3, .y = 0 },  .{ .x = 1, .y = 3 },  .{ .x = -1, .y = 3 },
    .{ .x = 3, .y = 1 },  .{ .x = -3, .y = 1 }, .{ .x = 2, .y = 3 },  .{ .x = -2, .y = 3 },
    .{ .x = 3, .y = 2 },  .{ .x = -3, .y = 2 }, .{ .x = 0, .y = 4 },  .{ .x = 4, .y = 0 },
    .{ .x = 1, .y = 4 },  .{ .x = -1, .y = 4 }, .{ .x = 4, .y = 1 },  .{ .x = -4, .y = 1 },
    .{ .x = 3, .y = 3 },  .{ .x = -3, .y = 3 }, .{ .x = 2, .y = 4 },  .{ .x = -2, .y = 4 },
    .{ .x = 4, .y = 2 },  .{ .x = -4, .y = 2 }, .{ .x = 0, .y = 5 },  .{ .x = 3, .y = 4 },
    .{ .x = -3, .y = 4 }, .{ .x = 4, .y = 3 },  .{ .x = -4, .y = 3 }, .{ .x = 5, .y = 0 },
    .{ .x = 1, .y = 5 },  .{ .x = -1, .y = 5 }, .{ .x = 5, .y = 1 },  .{ .x = -5, .y = 1 },
    .{ .x = 2, .y = 5 },  .{ .x = -2, .y = 5 }, .{ .x = 5, .y = 2 },  .{ .x = -5, .y = 2 },
    .{ .x = 4, .y = 4 },  .{ .x = -4, .y = 4 }, .{ .x = 3, .y = 5 },  .{ .x = -3, .y = 5 },
    .{ .x = 5, .y = 3 },  .{ .x = -5, .y = 3 }, .{ .x = 0, .y = 6 },  .{ .x = 6, .y = 0 },
    .{ .x = 1, .y = 6 },  .{ .x = -1, .y = 6 }, .{ .x = 6, .y = 1 },  .{ .x = -6, .y = 1 },
    .{ .x = 2, .y = 6 },  .{ .x = -2, .y = 6 }, .{ .x = 6, .y = 2 },  .{ .x = -6, .y = 2 },
    .{ .x = 4, .y = 5 },  .{ .x = -4, .y = 5 }, .{ .x = 5, .y = 4 },  .{ .x = -5, .y = 4 },
    .{ .x = 3, .y = 6 },  .{ .x = -3, .y = 6 }, .{ .x = 6, .y = 3 },  .{ .x = -6, .y = 3 },
    .{ .x = 0, .y = 7 },  .{ .x = 7, .y = 0 },  .{ .x = 1, .y = 7 },  .{ .x = -1, .y = 7 },
    .{ .x = 5, .y = 5 },  .{ .x = -5, .y = 5 }, .{ .x = 7, .y = 1 },  .{ .x = -7, .y = 1 },
    .{ .x = 4, .y = 6 },  .{ .x = -4, .y = 6 }, .{ .x = 6, .y = 4 },  .{ .x = -6, .y = 4 },
    .{ .x = 2, .y = 7 },  .{ .x = -2, .y = 7 }, .{ .x = 7, .y = 2 },  .{ .x = -7, .y = 2 },
    .{ .x = 3, .y = 7 },  .{ .x = -3, .y = 7 }, .{ .x = 7, .y = 3 },  .{ .x = -7, .y = 3 },
    .{ .x = 5, .y = 6 },  .{ .x = -5, .y = 6 }, .{ .x = 6, .y = 5 },  .{ .x = -6, .y = 5 },
    .{ .x = 8, .y = 0 },  .{ .x = 4, .y = 7 },  .{ .x = -4, .y = 7 }, .{ .x = 7, .y = 4 },
    .{ .x = -7, .y = 4 }, .{ .x = 8, .y = 1 },  .{ .x = 8, .y = 2 },  .{ .x = 6, .y = 6 },
    .{ .x = -6, .y = 6 }, .{ .x = 8, .y = 3 },  .{ .x = 5, .y = 7 },  .{ .x = -5, .y = 7 },
    .{ .x = 7, .y = 5 },  .{ .x = -7, .y = 5 }, .{ .x = 8, .y = 4 },  .{ .x = 6, .y = 7 },
    .{ .x = -6, .y = 7 }, .{ .x = 7, .y = 6 },  .{ .x = -7, .y = 6 }, .{ .x = 8, .y = 5 },
    .{ .x = 7, .y = 7 },  .{ .x = -7, .y = 7 }, .{ .x = 8, .y = 6 },  .{ .x = 8, .y = 7 },
};

const Vp8lPrefixCodes = struct {
    green: Vp8lPrefixCode,
    red: Vp8lPrefixCode,
    blue: Vp8lPrefixCode,
    alpha: Vp8lPrefixCode,
    distance: Vp8lPrefixCode,
};

const Vp8lMetaPrefixImage = struct {
    bytes: []const u8,
    width: usize,
    bits: usize,
    group_count: usize,

    fn groupAt(self: Vp8lMetaPrefixImage, x: usize, y: usize) DecodeError!usize {
        const index = (y >> @intCast(self.bits)) * self.width + (x >> @intCast(self.bits));
        const offset = index * webp_vp8l_meta_prefix_bytes_per_entry;
        if (offset + 1 >= self.bytes.len) return error.BadImage;
        const group = @as(usize, self.bytes[offset]) | (@as(usize, self.bytes[offset + 1]) << 8);
        if (group >= self.group_count) return error.BadImage;
        return group;
    }
};

const Vp8lColorIndexingTransform = struct {
    table: [webp_vp8l_color_table_max_size]ui.Color,
    table_size: usize,
    width_bits: usize,
};

const Vp8lPredictorTransform = struct {
    modes: []const u8,
    size_bits: usize,
    width: usize,
};

const Vp8lColorTransform = struct {
    elements: []const u8,
    size_bits: usize,
    width: usize,
};

const Vp8lScratch = struct {
    data: []u8,
    cursor: usize = 0,

    fn init(data: []u8) Vp8lScratch {
        return .{ .data = data };
    }

    fn alloc(self: *Vp8lScratch, len: usize) DecodeError![]u8 {
        if (len > self.data.len - self.cursor) return error.PixelBudget;
        const slice = self.data[self.cursor..][0..len];
        self.cursor += len;
        return slice;
    }

    fn allocItems(self: *Vp8lScratch, comptime T: type, len: usize) DecodeError![]T {
        const byte_len = std.math.mul(usize, @sizeOf(T), len) catch return error.PixelBudget;
        const base_addr = @intFromPtr(self.data.ptr);
        const current_addr = base_addr + self.cursor;
        const aligned_addr = std.mem.alignForward(usize, current_addr, @alignOf(T));
        const prefix = aligned_addr - current_addr;
        if (prefix > self.data.len - self.cursor) return error.PixelBudget;
        self.cursor += prefix;
        if (byte_len > self.data.len - self.cursor) return error.PixelBudget;
        const bytes = self.data[self.cursor..][0..byte_len];
        self.cursor += byte_len;
        const items: [*]T = @ptrCast(@alignCast(bytes.ptr));
        return items[0..len];
    }
};

const Vp8lTransforms = struct {
    color_indexing: ?Vp8lColorIndexingTransform = null,
    predictor: ?Vp8lPredictorTransform = null,
    color: ?Vp8lColorTransform = null,
    subtract_green: bool = false,
    order: [webp_vp8l_transform_max_count]u2 = [_]u2{0} ** webp_vp8l_transform_max_count,
    headers: [webp_vp8l_transform_max_count]Header = [_]Header{.{ .width = 0, .height = 0 }} ** webp_vp8l_transform_max_count,
    count: usize = 0,

    fn append(self: *Vp8lTransforms, transform_type: u2, header: Header) DecodeError!void {
        if (self.count >= self.order.len) return error.BadImage;
        self.order[self.count] = transform_type;
        self.headers[self.count] = header;
        self.count += 1;
    }
};

fn vp8lTransformScratchByteLen(pixel_count: usize) DecodeError!usize {
    const predictor_bytes = pixel_count;
    const color_transform_bytes = try checkedMul(pixel_count, webp_vp8l_color_transform_bytes_per_element);
    const meta_prefix_bytes = try checkedMul(pixel_count, webp_vp8l_meta_prefix_bytes_per_entry);
    return checkedAdd(try checkedAdd(predictor_bytes, color_transform_bytes), meta_prefix_bytes);
}

fn vp8lEntropyScratchByteLen(encoded_len: usize) DecodeError!usize {
    const bit_count = try checkedMul(encoded_len, 8);
    const stream_group_bound = (bit_count / webp_vp8l_prefix_code_family_count) + 1;
    const group_count = @min(webp_vp8l_meta_prefix_group_count_max, stream_group_bound);
    const group_table = try checkedAdd(
        try checkedMul(group_count, @sizeOf(Vp8lPrefixCodes)),
        @alignOf(Vp8lPrefixCodes) - 1,
    );
    const group_codes = try checkedMul(group_count, webp_vp8l_prefix_code_max_storage_bytes_per_group);
    const transform_entropy_codes = try checkedMul(webp_vp8l_transform_max_count, webp_vp8l_prefix_code_max_storage_bytes_per_group);
    return checkedAdd(try checkedAdd(group_table, group_codes), transform_entropy_codes);
}

fn decodeVp8lPixels(reader: *Vp8lBitReader, header: Header, out: []ui.Color, scratch: []u8) DecodeError!void {
    var scratch_allocator = Vp8lScratch.init(scratch);
    const transforms = try readVp8lTransforms(reader, header, out, &scratch_allocator);
    const coded_header = vp8lCodedHeaderForTransforms(header, transforms);
    const coded_count = try pixelCount(coded_header);
    try decodeVp8lSpatialPixels(reader, coded_header, out[0..coded_count], &scratch_allocator);
    try applyVp8lTransforms(transforms, out);
}

fn readVp8lTransforms(reader: *Vp8lBitReader, header: Header, out: []ui.Color, scratch: *Vp8lScratch) DecodeError!Vp8lTransforms {
    var transforms = Vp8lTransforms{};
    var current_header = header;
    while (try reader.readFlag()) {
        const transform_type: u2 = @intCast(try reader.readBits(webp_vp8l_transform_type_bits));
        switch (transform_type) {
            webp_vp8l_transform_predictor => {
                if (transforms.predictor != null) return error.UnsupportedImage;
                transforms.predictor = try readVp8lPredictorTransform(reader, current_header, out, scratch);
                try transforms.append(transform_type, current_header);
            },
            webp_vp8l_transform_color => {
                if (transforms.color != null) return error.UnsupportedImage;
                transforms.color = try readVp8lColorTransform(reader, current_header, out, scratch);
                try transforms.append(transform_type, current_header);
            },
            webp_vp8l_transform_color_indexing => {
                if (transforms.color_indexing != null) return error.UnsupportedImage;
                transforms.color_indexing = try readVp8lColorIndexingTransform(reader, scratch);
                try transforms.append(transform_type, current_header);
                current_header = vp8lCodedHeaderForColorIndexing(current_header, transforms.color_indexing.?);
            },
            webp_vp8l_transform_subtract_green => {
                if (transforms.subtract_green) return error.UnsupportedImage;
                transforms.subtract_green = true;
                try transforms.append(transform_type, current_header);
            },
        }
    }
    return transforms;
}

fn readVp8lPredictorTransform(reader: *Vp8lBitReader, header: Header, out: []ui.Color, scratch: *Vp8lScratch) DecodeError!Vp8lPredictorTransform {
    const size_bits = @as(usize, @intCast(try reader.readBits(webp_vp8l_transform_size_bits_len))) + webp_vp8l_transform_size_bits_base;
    const block_size = @as(usize, 1) << @intCast(size_bits);
    const transform_width = divRoundUp(header.width, block_size);
    const transform_height = divRoundUp(header.height, block_size);
    const transform_count = std.math.mul(usize, transform_width, transform_height) catch return error.PixelBudget;
    if (out.len < transform_count) return error.PixelBudget;
    const modes = try scratch.alloc(transform_count);
    try decodeVp8lEntropyPixels(reader, out[0..transform_count], scratch);
    for (out[0..transform_count], modes) |pixel, *mode| {
        if (pixel.g >= webp_vp8l_predictor_mode_count) return error.BadImage;
        mode.* = pixel.g;
    }
    return .{
        .modes = modes,
        .size_bits = size_bits,
        .width = transform_width,
    };
}

fn readVp8lColorTransform(reader: *Vp8lBitReader, header: Header, out: []ui.Color, scratch: *Vp8lScratch) DecodeError!Vp8lColorTransform {
    const size_bits = @as(usize, @intCast(try reader.readBits(webp_vp8l_transform_size_bits_len))) + webp_vp8l_transform_size_bits_base;
    const block_size = @as(usize, 1) << @intCast(size_bits);
    const transform_width = divRoundUp(header.width, block_size);
    const transform_height = divRoundUp(header.height, block_size);
    const transform_count = std.math.mul(usize, transform_width, transform_height) catch return error.PixelBudget;
    const byte_count = std.math.mul(usize, transform_count, webp_vp8l_color_transform_bytes_per_element) catch return error.PixelBudget;
    if (out.len < transform_count) return error.PixelBudget;
    const elements = try scratch.alloc(byte_count);
    try decodeVp8lEntropyPixels(reader, out[0..transform_count], scratch);
    for (out[0..transform_count], 0..) |pixel, index| {
        const offset = index * webp_vp8l_color_transform_bytes_per_element;
        elements[offset + webp_vp8l_color_transform_green_to_red_offset] = pixel.b;
        elements[offset + webp_vp8l_color_transform_green_to_blue_offset] = pixel.g;
        elements[offset + webp_vp8l_color_transform_red_to_blue_offset] = pixel.r;
    }
    return .{
        .elements = elements,
        .size_bits = size_bits,
        .width = transform_width,
    };
}

fn readVp8lColorIndexingTransform(reader: *Vp8lBitReader, scratch: *Vp8lScratch) DecodeError!Vp8lColorIndexingTransform {
    const table_size = @as(usize, @intCast(try reader.readBits(webp_vp8l_color_table_size_bits))) + 1;
    var transform = Vp8lColorIndexingTransform{
        .table = undefined,
        .table_size = table_size,
        .width_bits = vp8lIndexBundleWidthBits(table_size),
    };
    try decodeVp8lEntropyPixels(reader, transform.table[0..table_size], scratch);
    applyVp8lColorTableDeltas(transform.table[0..table_size]);
    return transform;
}

fn decodeVp8lSpatialPixels(reader: *Vp8lBitReader, header: Header, out: []ui.Color, scratch: *Vp8lScratch) DecodeError!void {
    var color_cache = try decodeVp8lColorCacheInfo(reader);
    const has_meta_prefix = try reader.readFlag();
    const meta_prefix = if (has_meta_prefix) try readVp8lMetaPrefixImage(reader, header, out, scratch) else null;
    const group_count = if (meta_prefix) |meta| meta.group_count else 1;
    var stack_groups: [webp_vp8l_meta_prefix_stack_group_max]Vp8lPrefixCodes = undefined;
    const groups = if (group_count <= stack_groups.len)
        stack_groups[0..group_count]
    else
        try scratch.allocItems(Vp8lPrefixCodes, group_count);
    var group_index: usize = 0;
    while (group_index < group_count) : (group_index += 1) {
        groups[group_index] = try readVp8lPrefixCodes(reader, webp_vp8l_green_symbol_count_without_cache + color_cache.size, scratch);
    }
    try decodeVp8lDataPixels(reader, header, &color_cache, groups, meta_prefix, out);
}

fn decodeVp8lEntropyPixels(reader: *Vp8lBitReader, out: []ui.Color, scratch: *Vp8lScratch) DecodeError!void {
    var color_cache = try decodeVp8lColorCacheInfo(reader);
    const codes = try readVp8lPrefixCodes(reader, webp_vp8l_green_symbol_count_without_cache + color_cache.size, scratch);
    const groups = [_]Vp8lPrefixCodes{codes};
    try decodeVp8lDataPixels(reader, .{ .width = out.len, .height = 1 }, &color_cache, &groups, null, out);
}

fn decodeVp8lColorCacheInfo(reader: *Vp8lBitReader) DecodeError!Vp8lColorCache {
    if (!try reader.readFlag()) return Vp8lColorCache.none();
    return Vp8lColorCache.init(@intCast(try reader.readBits(webp_vp8l_color_cache_bits_len)));
}

fn decodeVp8lDataPixels(reader: *Vp8lBitReader, header: Header, color_cache: *Vp8lColorCache, groups: []const Vp8lPrefixCodes, meta_prefix: ?Vp8lMetaPrefixImage, out: []ui.Color) DecodeError!void {
    const green_symbol_count = webp_vp8l_green_symbol_count_without_cache + color_cache.size;
    var pixel_index: usize = 0;
    while (pixel_index < out.len) {
        const x = pixel_index % header.width;
        const y = pixel_index / header.width;
        const codes = groups[if (meta_prefix) |meta| try meta.groupAt(x, y) else 0];
        const green = try codes.green.read(reader);
        if (green < webp_vp8l_channel_symbol_count) {
            const red = try codes.red.read(reader);
            const blue = try codes.blue.read(reader);
            const alpha = try codes.alpha.read(reader);
            if (red >= webp_vp8l_channel_symbol_count or blue >= webp_vp8l_channel_symbol_count or alpha >= webp_vp8l_channel_symbol_count) return error.BadImage;
            out[pixel_index] = .{
                .r = @intCast(red),
                .g = @intCast(green),
                .b = @intCast(blue),
                .a = @intCast(alpha),
            };
            color_cache.insert(out[pixel_index]);
            pixel_index += 1;
        } else if (green < webp_vp8l_color_cache_symbol_base) {
            const length = try readVp8lPrefixValue(reader, @intCast(green - webp_vp8l_length_symbol_base));
            const distance_symbol = try codes.distance.read(reader);
            if (distance_symbol >= webp_vp8l_distance_symbol_count) return error.BadImage;
            const distance_code = try readVp8lPrefixValue(reader, distance_symbol);
            const distance = try vp8lPlaneCodeToDistance(header.width, distance_code);
            if (distance > pixel_index or length > out.len - pixel_index) return error.BadImage;
            var copied: usize = 0;
            while (copied < length) : (copied += 1) {
                out[pixel_index + copied] = out[pixel_index + copied - distance];
                color_cache.insert(out[pixel_index + copied]);
            }
            pixel_index += length;
        } else if (green < green_symbol_count) {
            out[pixel_index] = try color_cache.lookup(green - webp_vp8l_color_cache_symbol_base);
            color_cache.insert(out[pixel_index]);
            pixel_index += 1;
        } else {
            return error.BadImage;
        }
    }
}

fn readVp8lMetaPrefixImage(reader: *Vp8lBitReader, header: Header, out: []ui.Color, scratch: *Vp8lScratch) DecodeError!Vp8lMetaPrefixImage {
    const prefix_bits = @as(usize, @intCast(try reader.readBits(webp_vp8l_meta_prefix_bits_len))) + webp_vp8l_meta_prefix_bits_base;
    const block_size = @as(usize, 1) << @intCast(prefix_bits);
    const meta_width = divRoundUp(header.width, block_size);
    const meta_height = divRoundUp(header.height, block_size);
    const meta_count = std.math.mul(usize, meta_width, meta_height) catch return error.PixelBudget;
    const meta_bytes = std.math.mul(usize, meta_count, webp_vp8l_meta_prefix_bytes_per_entry) catch return error.PixelBudget;
    if (out.len < meta_count) return error.PixelBudget;
    const meta_prefixes = try scratch.alloc(meta_bytes);
    try decodeVp8lEntropyPixels(reader, out[0..meta_count], scratch);
    var max_prefix: u16 = 0;
    for (out[0..meta_count], 0..) |pixel, index| {
        const meta_prefix = (@as(u16, pixel.r) << 8) | @as(u16, pixel.g);
        if (meta_prefix > max_prefix) max_prefix = meta_prefix;
        const offset = index * webp_vp8l_meta_prefix_bytes_per_entry;
        meta_prefixes[offset] = @intCast(meta_prefix & 0xff);
        meta_prefixes[offset + 1] = @intCast(meta_prefix >> 8);
    }
    return .{
        .bytes = meta_prefixes,
        .width = meta_width,
        .bits = prefix_bits,
        .group_count = @as(usize, max_prefix) + 1,
    };
}

fn vp8lCodedHeaderForTransforms(header: Header, transforms: Vp8lTransforms) Header {
    if (transforms.color_indexing) |indexing| {
        return vp8lCodedHeaderForColorIndexing(header, indexing);
    }
    return header;
}

fn vp8lCodedHeaderForColorIndexing(header: Header, indexing: Vp8lColorIndexingTransform) Header {
    const pixels_per_bundle = @as(usize, 1) << @intCast(indexing.width_bits);
    const coded_width = (header.width + pixels_per_bundle - 1) / pixels_per_bundle;
    return .{ .width = coded_width, .height = header.height };
}

fn applyVp8lTransforms(transforms: Vp8lTransforms, out: []ui.Color) DecodeError!void {
    var index = transforms.count;
    while (index > 0) {
        index -= 1;
        const transform_header = transforms.headers[index];
        switch (transforms.order[index]) {
            webp_vp8l_transform_color_indexing => {
                if (transforms.color_indexing) |color_indexing| {
                    try applyVp8lColorIndexingTransform(color_indexing, transform_header, out);
                } else {
                    return error.BadImage;
                }
            },
            webp_vp8l_transform_subtract_green => try applyVp8lSubtractGreenTransform(transform_header, out),
            webp_vp8l_transform_color => {
                if (transforms.color) |color| {
                    try applyVp8lColorTransform(color, transform_header, out);
                } else {
                    return error.BadImage;
                }
            },
            webp_vp8l_transform_predictor => {
                if (transforms.predictor) |predictor| {
                    try applyVp8lPredictorTransform(predictor, transform_header, out);
                } else {
                    return error.BadImage;
                }
            },
        }
    }
}

fn applyVp8lColorTransform(transform: Vp8lColorTransform, header: Header, out: []ui.Color) DecodeError!void {
    const count = try pixelCount(header);
    if (out.len < count) return error.PixelBudget;
    var y: usize = 0;
    while (y < header.height) : (y += 1) {
        var x: usize = 0;
        while (x < header.width) : (x += 1) {
            const pixel_index = y * header.width + x;
            const transform_index = ((y >> @intCast(transform.size_bits)) * transform.width + (x >> @intCast(transform.size_bits))) *
                webp_vp8l_color_transform_bytes_per_element;
            out[pixel_index] = inverseVp8lColorTransform(
                out[pixel_index],
                transform.elements[transform_index + webp_vp8l_color_transform_green_to_red_offset],
                transform.elements[transform_index + webp_vp8l_color_transform_green_to_blue_offset],
                transform.elements[transform_index + webp_vp8l_color_transform_red_to_blue_offset],
            );
        }
    }
}

fn inverseVp8lColorTransform(pixel: ui.Color, green_to_red: u8, green_to_blue: u8, red_to_blue: u8) ui.Color {
    const red = wrapVp8lChannel(@as(i32, pixel.r) + vp8lColorTransformDelta(green_to_red, pixel.g));
    const blue = wrapVp8lChannel(@as(i32, pixel.b) +
        vp8lColorTransformDelta(green_to_blue, pixel.g) +
        vp8lColorTransformDelta(red_to_blue, red));
    return .{
        .r = red,
        .g = pixel.g,
        .b = blue,
        .a = pixel.a,
    };
}

fn forwardVp8lColorTransform(pixel: ui.Color, green_to_red: u8, green_to_blue: u8, red_to_blue: u8) ui.Color {
    const red = wrapVp8lChannel(@as(i32, pixel.r) - vp8lColorTransformDelta(green_to_red, pixel.g));
    const blue = wrapVp8lChannel(@as(i32, pixel.b) -
        vp8lColorTransformDelta(green_to_blue, pixel.g) -
        vp8lColorTransformDelta(red_to_blue, pixel.r));
    return .{
        .r = red,
        .g = pixel.g,
        .b = blue,
        .a = pixel.a,
    };
}

fn vp8lColorTransformDelta(transform: u8, channel: u8) i32 {
    const signed_transform: i16 = @as(i8, @bitCast(transform));
    const signed_channel: i16 = @as(i8, @bitCast(channel));
    return (@as(i32, signed_transform) * @as(i32, signed_channel)) >> 5;
}

fn wrapVp8lChannel(value: i32) u8 {
    return @intCast(@mod(value, 256));
}

fn applyVp8lPredictorTransform(transform: Vp8lPredictorTransform, header: Header, out: []ui.Color) DecodeError!void {
    const count = try pixelCount(header);
    if (out.len < count) return error.PixelBudget;
    var y: usize = 0;
    while (y < header.height) : (y += 1) {
        var x: usize = 0;
        while (x < header.width) : (x += 1) {
            const index = y * header.width + x;
            const prediction = vp8lPredictor(transform, header, out, x, y);
            out[index] = addVp8lColors(out[index], prediction);
        }
    }
}

fn vp8lPredictor(transform: Vp8lPredictorTransform, header: Header, out: []const ui.Color, x: usize, y: usize) ui.Color {
    if (x == 0 and y == 0) return vp8lPredictorBlack();
    if (y == 0) return out[y * header.width + x - 1];
    if (x == 0) return out[(y - 1) * header.width + x];

    const left = out[y * header.width + x - 1];
    const top = out[(y - 1) * header.width + x];
    const top_left = out[(y - 1) * header.width + x - 1];
    const top_right = if (x + 1 < header.width) out[(y - 1) * header.width + x + 1] else out[y * header.width];
    const mode = transform.modes[(y >> @intCast(transform.size_bits)) * transform.width + (x >> @intCast(transform.size_bits))];
    return switch (mode) {
        webp_vp8l_predictor_mode_black => vp8lPredictorBlack(),
        webp_vp8l_predictor_mode_left => left,
        webp_vp8l_predictor_mode_top => top,
        webp_vp8l_predictor_mode_top_right => top_right,
        webp_vp8l_predictor_mode_top_left => top_left,
        webp_vp8l_predictor_mode_avg_left_top_right_top => averageVp8lColors(averageVp8lColors(left, top_right), top),
        webp_vp8l_predictor_mode_avg_left_top_left => averageVp8lColors(left, top_left),
        webp_vp8l_predictor_mode_avg_left_top => averageVp8lColors(left, top),
        webp_vp8l_predictor_mode_avg_top_left_top => averageVp8lColors(top_left, top),
        webp_vp8l_predictor_mode_avg_top_top_right => averageVp8lColors(top, top_right),
        webp_vp8l_predictor_mode_avg_avg_left_top_left_avg_top_top_right => averageVp8lColors(averageVp8lColors(left, top_left), averageVp8lColors(top, top_right)),
        webp_vp8l_predictor_mode_select => selectVp8lPredictor(left, top, top_left),
        webp_vp8l_predictor_mode_clamp_full => clampAddSubtractFullVp8lColor(left, top, top_left),
        webp_vp8l_predictor_mode_clamp_half => clampAddSubtractHalfVp8lColor(averageVp8lColors(left, top), top_left),
        else => vp8lPredictorBlack(),
    };
}

fn vp8lPredictorBlack() ui.Color {
    return .{
        .r = webp_vp8l_predictor_black_rgb,
        .g = webp_vp8l_predictor_black_rgb,
        .b = webp_vp8l_predictor_black_rgb,
        .a = webp_vp8l_predictor_black_a,
    };
}

fn addVp8lColors(residual: ui.Color, prediction: ui.Color) ui.Color {
    return .{
        .r = residual.r +% prediction.r,
        .g = residual.g +% prediction.g,
        .b = residual.b +% prediction.b,
        .a = residual.a +% prediction.a,
    };
}

fn subtractVp8lColors(pixel: ui.Color, prediction: ui.Color) ui.Color {
    return .{
        .r = pixel.r -% prediction.r,
        .g = pixel.g -% prediction.g,
        .b = pixel.b -% prediction.b,
        .a = pixel.a -% prediction.a,
    };
}

fn averageVp8lColors(a: ui.Color, b: ui.Color) ui.Color {
    return .{
        .r = averageVp8lChannel(a.r, b.r),
        .g = averageVp8lChannel(a.g, b.g),
        .b = averageVp8lChannel(a.b, b.b),
        .a = averageVp8lChannel(a.a, b.a),
    };
}

fn averageVp8lChannel(a: u8, b: u8) u8 {
    return @intCast((@as(u16, a) + @as(u16, b)) / 2);
}

fn selectVp8lPredictor(left: ui.Color, top: ui.Color, top_left: ui.Color) ui.Color {
    const estimated = Vp8lSignedColor{
        .r = @as(i16, left.r) + @as(i16, top.r) - @as(i16, top_left.r),
        .g = @as(i16, left.g) + @as(i16, top.g) - @as(i16, top_left.g),
        .b = @as(i16, left.b) + @as(i16, top.b) - @as(i16, top_left.b),
        .a = @as(i16, left.a) + @as(i16, top.a) - @as(i16, top_left.a),
    };
    const left_distance = vp8lColorDistance(estimated, left);
    const top_distance = vp8lColorDistance(estimated, top);
    return if (left_distance < top_distance) left else top;
}

const Vp8lSignedColor = struct {
    r: i16,
    g: i16,
    b: i16,
    a: i16,
};

fn vp8lColorDistance(estimated: Vp8lSignedColor, color: ui.Color) i32 {
    return absI32(@as(i32, estimated.r) - color.r) +
        absI32(@as(i32, estimated.g) - color.g) +
        absI32(@as(i32, estimated.b) - color.b) +
        absI32(@as(i32, estimated.a) - color.a);
}

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

fn clampAddSubtractFullVp8lColor(a: ui.Color, b: ui.Color, c: ui.Color) ui.Color {
    return .{
        .r = clampVp8lChannel(@as(i16, a.r) + @as(i16, b.r) - @as(i16, c.r)),
        .g = clampVp8lChannel(@as(i16, a.g) + @as(i16, b.g) - @as(i16, c.g)),
        .b = clampVp8lChannel(@as(i16, a.b) + @as(i16, b.b) - @as(i16, c.b)),
        .a = clampVp8lChannel(@as(i16, a.a) + @as(i16, b.a) - @as(i16, c.a)),
    };
}

fn clampAddSubtractHalfVp8lColor(a: ui.Color, b: ui.Color) ui.Color {
    return .{
        .r = clampVp8lChannel(@as(i16, a.r) + divTruncVp8l(@as(i16, a.r) - @as(i16, b.r), 2)),
        .g = clampVp8lChannel(@as(i16, a.g) + divTruncVp8l(@as(i16, a.g) - @as(i16, b.g), 2)),
        .b = clampVp8lChannel(@as(i16, a.b) + divTruncVp8l(@as(i16, a.b) - @as(i16, b.b), 2)),
        .a = clampVp8lChannel(@as(i16, a.a) + divTruncVp8l(@as(i16, a.a) - @as(i16, b.a), 2)),
    };
}

fn divTruncVp8l(numerator: i16, denominator: i16) i16 {
    return @intCast(@divTrunc(numerator, denominator));
}

fn clampVp8lChannel(value: i16) u8 {
    if (value < 0) return 0;
    if (value > std.math.maxInt(u8)) return std.math.maxInt(u8);
    return @intCast(value);
}

fn applyVp8lSubtractGreenTransform(header: Header, out: []ui.Color) DecodeError!void {
    const count = try pixelCount(header);
    if (out.len < count) return error.PixelBudget;
    for (out[0..count]) |*pixel| {
        pixel.r +%= pixel.g;
        pixel.b +%= pixel.g;
    }
}

fn applyVp8lColorIndexingTransform(indexing: Vp8lColorIndexingTransform, header: Header, out: []ui.Color) DecodeError!void {
    const count = try pixelCount(header);
    if (out.len < count) return error.PixelBudget;
    if (indexing.width_bits == webp_vp8l_index_bundle_width_bits_none) {
        for (out[0..count]) |*pixel| pixel.* = vp8lColorTableLookup(indexing, pixel.g);
        return;
    }

    const pixels_per_bundle = @as(usize, 1) << @intCast(indexing.width_bits);
    const bits_per_index = vp8lPackedIndexBits(indexing.width_bits);
    const index_mask: u8 = @intCast((@as(usize, 1) << @intCast(bits_per_index)) - 1);
    const coded_width = (header.width + pixels_per_bundle - 1) / pixels_per_bundle;
    var y = header.height;
    while (y > 0) {
        y -= 1;
        var x = header.width;
        while (x > 0) {
            x -= 1;
            const coded_index = y * coded_width + x / pixels_per_bundle;
            const packed_green = out[coded_index].g;
            const shift: u3 = @intCast((x & (pixels_per_bundle - 1)) * bits_per_index);
            const color_index = (packed_green >> shift) & index_mask;
            out[y * header.width + x] = vp8lColorTableLookup(indexing, color_index);
        }
    }
}

fn vp8lColorTableLookup(indexing: Vp8lColorIndexingTransform, index: u8) ui.Color {
    if (@as(usize, index) >= indexing.table_size) return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
    return indexing.table[index];
}

fn applyVp8lColorTableDeltas(table: []ui.Color) void {
    var previous = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 0 };
    for (table) |*entry| {
        entry.* = .{
            .r = entry.r +% previous.r,
            .g = entry.g +% previous.g,
            .b = entry.b +% previous.b,
            .a = entry.a +% previous.a,
        };
        previous = entry.*;
    }
}

fn vp8lIndexBundleWidthBits(table_size: usize) usize {
    if (table_size <= webp_vp8l_index_bundle_threshold_2) return webp_vp8l_index_bundle_width_bits_1_or_2;
    if (table_size <= webp_vp8l_index_bundle_threshold_4) return webp_vp8l_index_bundle_width_bits_3_or_4;
    if (table_size <= webp_vp8l_index_bundle_threshold_16) return webp_vp8l_index_bundle_width_bits_5_to_16;
    return webp_vp8l_index_bundle_width_bits_none;
}

fn vp8lPackedIndexBits(width_bits: usize) usize {
    return switch (width_bits) {
        webp_vp8l_index_bundle_width_bits_1_or_2 => 1,
        webp_vp8l_index_bundle_width_bits_3_or_4 => 2,
        webp_vp8l_index_bundle_width_bits_5_to_16 => 4,
        else => 8,
    };
}

fn readVp8lPrefixValue(reader: *Vp8lBitReader, prefix: u16) DecodeError!usize {
    if (prefix < 4) return @as(usize, prefix) + 1;
    const extra_bits: usize = (@as(usize, prefix) - 2) >> 1;
    const offset = (2 + (@as(usize, prefix) & 1)) << @intCast(extra_bits);
    return offset + @as(usize, @intCast(try reader.readBits(extra_bits))) + 1;
}

fn vp8lPlaneCodeToDistance(width: usize, distance_code: usize) DecodeError!usize {
    if (distance_code == 0) return error.BadImage;
    if (distance_code > webp_vp8l_distance_plane_code_count) return distance_code - webp_vp8l_distance_plane_code_count;
    const offset = webp_vp8l_distance_offsets[distance_code - 1];
    const distance = @as(isize, offset.x) + @as(isize, offset.y) * @as(isize, @intCast(width));
    if (distance < 1) return 1;
    return @intCast(distance);
}

fn readVp8lPrefixCodes(reader: *Vp8lBitReader, green_symbol_count: usize, scratch: *Vp8lScratch) DecodeError!Vp8lPrefixCodes {
    return .{
        .green = try readVp8lPrefixCode(reader, green_symbol_count, scratch),
        .red = try readVp8lPrefixCode(reader, webp_vp8l_channel_symbol_count, scratch),
        .blue = try readVp8lPrefixCode(reader, webp_vp8l_channel_symbol_count, scratch),
        .alpha = try readVp8lPrefixCode(reader, webp_vp8l_channel_symbol_count, scratch),
        .distance = try readVp8lPrefixCode(reader, webp_vp8l_distance_symbol_count, scratch),
    };
}

fn readVp8lPrefixCode(reader: *Vp8lBitReader, symbol_count: usize, scratch: *Vp8lScratch) DecodeError!Vp8lPrefixCode {
    if (try reader.readFlag()) return readVp8lSimplePrefixCodeBody(reader, symbol_count);
    return readVp8lNormalPrefixCode(reader, symbol_count, scratch);
}

fn readVp8lSimplePrefixCode(reader: *Vp8lBitReader, symbol_count: usize) DecodeError!Vp8lPrefixCode {
    if (!try reader.readFlag()) return error.BadImage;
    return readVp8lSimplePrefixCodeBody(reader, symbol_count);
}

fn readVp8lSimplePrefixCodeBody(reader: *Vp8lBitReader, symbol_count: usize) DecodeError!Vp8lPrefixCode {
    const num_symbols = @as(usize, @intCast(try reader.readBits(1))) + 1;
    const is_first_8bits = try reader.readFlag();
    const symbol0_bits = webp_vp8l_simple_code_short_symbol_bits + if (is_first_8bits) webp_vp8l_simple_code_selector_extra_bits else 0;
    const symbol0: u16 = @intCast(try reader.readBits(symbol0_bits));
    if (symbol0 >= symbol_count) return error.BadImage;
    if (num_symbols == 1) return .{ .one = symbol0 };
    const symbol1: u16 = @intCast(try reader.readBits(webp_vp8l_simple_code_symbol_bits));
    if (symbol1 >= symbol_count) return error.BadImage;
    if (symbol0 <= symbol1) return .{ .two = .{ .low = symbol0, .high = symbol1 } };
    return .{ .two = .{ .low = symbol1, .high = symbol0 } };
}

fn readVp8lNormalPrefixCode(reader: *Vp8lBitReader, symbol_count: usize, scratch: *Vp8lScratch) DecodeError!Vp8lPrefixCode {
    var code_length_code_lengths = [_]u8{0} ** webp_vp8l_code_length_code_count;
    const num_code_lengths = webp_vp8l_normal_code_length_count_base + @as(usize, @intCast(try reader.readBits(webp_vp8l_normal_code_length_count_bits)));
    if (num_code_lengths > webp_vp8l_code_length_code_count) return error.BadImage;
    var index: usize = 0;
    while (index < num_code_lengths) : (index += 1) {
        code_length_code_lengths[webp_vp8l_code_length_code_order[index]] = @intCast(try reader.readBits(webp_vp8l_code_length_code_bits));
    }
    var code_length_entries: [webp_vp8l_code_length_code_count * webp_vp8l_prefix_entry_bytes]u8 = undefined;
    const code_length_code = try buildVp8lCanonicalPrefixCode(code_length_code_lengths[0..], webp_vp8l_code_length_code_count, code_length_entries[0..]);

    var max_symbol = symbol_count;
    if (try reader.readFlag()) {
        const length_nbits = webp_vp8l_normal_length_nbits_base +
            webp_vp8l_normal_length_nbits_scale * @as(usize, @intCast(try reader.readBits(webp_vp8l_normal_length_nbits_selector_bits)));
        max_symbol = webp_vp8l_normal_max_symbol_base + @as(usize, @intCast(try reader.readBits(length_nbits)));
        if (max_symbol > symbol_count) return error.BadImage;
    }

    var lengths = [_]u8{0} ** webp_vp8l_green_symbol_count_with_max_cache;
    var symbol: usize = 0;
    var code_length_symbols_remaining = max_symbol;
    var previous: u8 = webp_vp8l_code_length_repeat_previous_default;
    while (symbol < symbol_count and code_length_symbols_remaining > 0) {
        code_length_symbols_remaining -= 1;
        const code_length_symbol = try code_length_code.read(reader);
        switch (code_length_symbol) {
            0...15 => {
                const length: u8 = @intCast(code_length_symbol);
                lengths[symbol] = length;
                if (length != 0) previous = length;
                symbol += 1;
            },
            webp_vp8l_code_length_repeat_previous => {
                const repeat = webp_vp8l_code_length_repeat_previous_base +
                    @as(usize, @intCast(try reader.readBits(webp_vp8l_code_length_repeat_previous_bits)));
                try fillVp8lCodeLengths(lengths[0..symbol_count], &symbol, previous, repeat);
            },
            webp_vp8l_code_length_repeat_zero_short => {
                const repeat = webp_vp8l_code_length_repeat_zero_short_base +
                    @as(usize, @intCast(try reader.readBits(webp_vp8l_code_length_repeat_zero_short_bits)));
                try fillVp8lCodeLengths(lengths[0..symbol_count], &symbol, 0, repeat);
            },
            webp_vp8l_code_length_repeat_zero_long => {
                const repeat = webp_vp8l_code_length_repeat_zero_long_base +
                    @as(usize, @intCast(try reader.readBits(webp_vp8l_code_length_repeat_zero_long_bits)));
                try fillVp8lCodeLengths(lengths[0..symbol_count], &symbol, 0, repeat);
            },
            else => return error.BadImage,
        }
    }
    return buildVp8lCanonicalPrefixCodeWithScratch(lengths[0..], symbol_count, scratch);
}

fn fillVp8lCodeLengths(lengths: []u8, symbol: *usize, length: u8, repeat: usize) DecodeError!void {
    if (repeat > lengths.len - symbol.*) return error.BadImage;
    var count: usize = 0;
    while (count < repeat) : (count += 1) {
        lengths[symbol.*] = length;
        symbol.* += 1;
    }
}

fn buildVp8lCanonicalPrefixCode(lengths: []const u8, symbol_count: usize, entries: []u8) DecodeError!Vp8lPrefixCode {
    const stats = try analyzeVp8lPrefixLengths(lengths, symbol_count);
    if (stats.non_zero_count == 0) return .{ .empty = {} };
    if (stats.non_zero_count == 1) return .{ .one = stats.single_symbol };
    const used_entry_bytes = std.math.mul(usize, stats.non_zero_count, webp_vp8l_prefix_entry_bytes) catch return error.PixelBudget;
    if (entries.len < used_entry_bytes) return error.PixelBudget;
    try writeVp8lCanonicalPrefixEntries(lengths, symbol_count, &stats.length_counts, entries[0..used_entry_bytes]);
    return .{ .normal = .{ .entries = entries[0..used_entry_bytes], .count = stats.non_zero_count } };
}

fn buildVp8lCanonicalPrefixCodeWithScratch(lengths: []const u8, symbol_count: usize, scratch: *Vp8lScratch) DecodeError!Vp8lPrefixCode {
    const stats = try analyzeVp8lPrefixLengths(lengths, symbol_count);
    if (stats.non_zero_count == 0) return .{ .empty = {} };
    if (stats.non_zero_count == 1) return .{ .one = stats.single_symbol };

    const used_entry_bytes = std.math.mul(usize, stats.non_zero_count, webp_vp8l_prefix_entry_bytes) catch return error.PixelBudget;
    const entries = try scratch.alloc(used_entry_bytes);
    try writeVp8lCanonicalPrefixEntries(lengths, symbol_count, &stats.length_counts, entries);
    return .{ .normal = .{ .entries = entries, .count = stats.non_zero_count } };
}

fn analyzeVp8lPrefixLengths(lengths: []const u8, symbol_count: usize) DecodeError!Vp8lPrefixStats {
    var length_counts = [_]usize{0} ** (webp_vp8l_prefix_code_max_bits + 1);
    var non_zero_count: usize = 0;
    var single_symbol: u16 = 0;

    var symbol: usize = 0;
    while (symbol < symbol_count) : (symbol += 1) {
        const length = lengths[symbol];
        if (length > webp_vp8l_prefix_code_max_bits) return error.BadImage;
        if (length != 0) {
            length_counts[length] += 1;
            non_zero_count += 1;
            single_symbol = @intCast(symbol);
        }
    }
    return .{
        .length_counts = length_counts,
        .non_zero_count = non_zero_count,
        .single_symbol = single_symbol,
    };
}

fn writeVp8lCanonicalPrefixEntries(lengths: []const u8, symbol_count: usize, length_counts: *const [webp_vp8l_prefix_code_max_bits + 1]usize, entries: []u8) DecodeError!void {
    try validateVp8lPrefixTree(length_counts);

    var next_code = [_]usize{0} ** (webp_vp8l_prefix_code_max_bits + 1);
    var code: usize = 0;
    var bits: usize = 1;
    while (bits <= webp_vp8l_prefix_code_max_bits) : (bits += 1) {
        code = (code + length_counts[bits - 1]) << 1;
        next_code[bits] = code;
    }

    var entry_count: usize = 0;
    var symbol: usize = 0;
    while (symbol < symbol_count) : (symbol += 1) {
        const length = lengths[symbol];
        if (length == 0) continue;
        const assigned_code = next_code[length];
        next_code[length] += 1;
        writeVp8lPrefixEntry(entries[entry_count * webp_vp8l_prefix_entry_bytes ..][0..webp_vp8l_prefix_entry_bytes], .{
            .symbol = @intCast(symbol),
            .bits = @intCast(length),
            .code = reverseVp8lPrefixBits(assigned_code, length),
        });
        entry_count += 1;
    }
}

fn writeVp8lPrefixEntry(bytes: *[webp_vp8l_prefix_entry_bytes]u8, entry: Vp8lPrefixEntry) void {
    writeU16(bytes[webp_vp8l_prefix_entry_symbol_offset..][0..2], entry.symbol);
    bytes[webp_vp8l_prefix_entry_bits_offset] = entry.bits;
    writeU16(bytes[webp_vp8l_prefix_entry_code_offset..][0..2], entry.code);
}

fn validateVp8lPrefixTree(length_counts: []const usize) DecodeError!void {
    var left: isize = 1;
    var bits: usize = 1;
    while (bits <= webp_vp8l_prefix_code_max_bits) : (bits += 1) {
        left = (left << 1) - @as(isize, @intCast(length_counts[bits]));
        if (left < 0) return error.BadImage;
    }
    if (left != 0) return error.BadImage;
}

fn reverseVp8lPrefixBits(code: usize, length: usize) u16 {
    var reversed: u16 = 0;
    var bit: usize = 0;
    while (bit < length) : (bit += 1) {
        if (((code >> @intCast(bit)) & 1) != 0) {
            reversed |= @as(u16, 1) << @intCast(length - bit - 1);
        }
    }
    return reversed;
}

const Vp8lBitReader = struct {
    data: []const u8,
    bit_index: usize,

    fn init(data: []const u8) Vp8lBitReader {
        return .{ .data = data, .bit_index = 0 };
    }

    fn readFlag(self: *Vp8lBitReader) DecodeError!bool {
        return (try self.readBits(1)) != 0;
    }

    fn readBits(self: *Vp8lBitReader, count: usize) DecodeError!u32 {
        if (count > 24) return error.BadImage;
        const bit_len = std.math.mul(usize, self.data.len, 8) catch return error.PixelBudget;
        if (self.bit_index > bit_len or count > bit_len - self.bit_index) return error.BadImage;
        var value: u32 = 0;
        var bit: usize = 0;
        while (bit < count) : (bit += 1) {
            const absolute_bit = self.bit_index + bit;
            const byte = self.data[absolute_bit >> 3];
            const bit_value = (byte >> @intCast(absolute_bit & 7)) & 1;
            value |= @as(u32, bit_value) << @intCast(bit);
        }
        self.bit_index += count;
        return value;
    }
};

const Vp8Frame = struct {
    frame_type: raw_vp8.FrameType,
    header: Header,
    first_partition: []const u8,
    token_partitions: []const u8,
    token_partition_count: usize,
    token_partition_slices: Vp8TokenPartitions,
    macroblocks: Vp8MacroblockSummary,
    compressed_header: Vp8CompressedFrameHeader,
};

const Vp8TokenPartitions = struct {
    count: usize,
    slices: [webp_vp8_token_partition_count_max][]const u8,
};

fn Vp8Edges(comptime size: usize) type {
    return struct {
        top: [size]u8,
        top_right: [webp_vp8_intra4_block_width]u8,
        left: [size]u8,
        top_left: u8,
        has_top: bool,
        has_left: bool,
    };
}

const Vp8PredictionState = struct {
    width: usize,
    has_top: bool,
    top_y: [webp_vp8_max_luma_edge]u8,
    top_u: [webp_vp8_max_chroma_edge]u8,
    top_v: [webp_vp8_max_chroma_edge]u8,
    left_y: [webp_vp8_macroblock_size]u8,
    left_u: [webp_vp8_chroma_block_size]u8,
    left_v: [webp_vp8_chroma_block_size]u8,
    has_left: bool,

    fn init(width: usize) Vp8PredictionState {
        var state = Vp8PredictionState{
            .width = width,
            .has_top = false,
            .top_y = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_max_luma_edge,
            .top_u = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_max_chroma_edge,
            .top_v = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_max_chroma_edge,
            .left_y = [_]u8{webp_vp8_plane_left_default} ** webp_vp8_macroblock_size,
            .left_u = [_]u8{webp_vp8_plane_left_default} ** webp_vp8_chroma_block_size,
            .left_v = [_]u8{webp_vp8_plane_left_default} ** webp_vp8_chroma_block_size,
            .has_left = false,
        };
        state.width = width;
        return state;
    }

    fn startRow(self: *Vp8PredictionState, mb_y: usize) void {
        self.has_top = mb_y != 0;
        self.left_y = [_]u8{webp_vp8_plane_left_default} ** webp_vp8_macroblock_size;
        self.left_u = [_]u8{webp_vp8_plane_left_default} ** webp_vp8_chroma_block_size;
        self.left_v = [_]u8{webp_vp8_plane_left_default} ** webp_vp8_chroma_block_size;
        self.has_left = false;
    }

    fn lumaEdges(self: *const Vp8PredictionState, mb_x: usize) Vp8Edges(webp_vp8_macroblock_size) {
        const offset = mb_x * webp_vp8_macroblock_size;
        var top = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_macroblock_size;
        var top_right = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_intra4_block_width;
        if (self.has_top) @memcpy(&top, self.top_y[offset..][0..webp_vp8_macroblock_size]);
        if (self.has_top) {
            const padded_width = vp8MacroblockDimension(self.width) * webp_vp8_macroblock_size;
            if (offset + webp_vp8_macroblock_size + webp_vp8_intra4_block_width <= padded_width) {
                @memcpy(&top_right, self.top_y[offset + webp_vp8_macroblock_size ..][0..webp_vp8_intra4_block_width]);
            } else {
                @memset(&top_right, top[webp_vp8_macroblock_size - 1]);
            }
        }
        const top_left = if (self.has_top and self.has_left) self.top_y[offset - 1] else webp_vp8_plane_edge_default;
        return .{
            .top = top,
            .top_right = top_right,
            .left = self.left_y,
            .top_left = top_left,
            .has_top = self.has_top,
            .has_left = self.has_left,
        };
    }

    fn uEdges(self: *const Vp8PredictionState, mb_x: usize) Vp8Edges(webp_vp8_chroma_block_size) {
        const offset = mb_x * webp_vp8_chroma_block_size;
        var top = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_chroma_block_size;
        if (self.has_top) @memcpy(&top, self.top_u[offset..][0..webp_vp8_chroma_block_size]);
        const top_left = if (self.has_top and self.has_left) self.top_u[offset - 1] else webp_vp8_plane_edge_default;
        return .{
            .top = top,
            .top_right = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_intra4_block_width,
            .left = self.left_u,
            .top_left = top_left,
            .has_top = self.has_top,
            .has_left = self.has_left,
        };
    }

    fn vEdges(self: *const Vp8PredictionState, mb_x: usize) Vp8Edges(webp_vp8_chroma_block_size) {
        const offset = mb_x * webp_vp8_chroma_block_size;
        var top = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_chroma_block_size;
        if (self.has_top) @memcpy(&top, self.top_v[offset..][0..webp_vp8_chroma_block_size]);
        const top_left = if (self.has_top and self.has_left) self.top_v[offset - 1] else webp_vp8_plane_edge_default;
        return .{
            .top = top,
            .top_right = [_]u8{webp_vp8_plane_edge_default} ** webp_vp8_intra4_block_width,
            .left = self.left_v,
            .top_left = top_left,
            .has_top = self.has_top,
            .has_left = self.has_left,
        };
    }

    fn finishMacroblock(
        self: *Vp8PredictionState,
        mb_x: usize,
        y_plane: *const [webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8,
        u_plane: *const [webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8,
        v_plane: *const [webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8,
    ) void {
        const y_offset = mb_x * webp_vp8_macroblock_size;
        @memcpy(
            self.top_y[y_offset..][0..webp_vp8_macroblock_size],
            y_plane[(webp_vp8_macroblock_size - 1) * webp_vp8_macroblock_size ..][0..webp_vp8_macroblock_size],
        );
        var index: usize = 0;
        while (index < webp_vp8_macroblock_size) : (index += 1) {
            self.left_y[index] = y_plane[index * webp_vp8_macroblock_size + webp_vp8_macroblock_size - 1];
        }

        const uv_offset = mb_x * webp_vp8_chroma_block_size;
        @memcpy(
            self.top_u[uv_offset..][0..webp_vp8_chroma_block_size],
            u_plane[(webp_vp8_chroma_block_size - 1) * webp_vp8_chroma_block_size ..][0..webp_vp8_chroma_block_size],
        );
        @memcpy(
            self.top_v[uv_offset..][0..webp_vp8_chroma_block_size],
            v_plane[(webp_vp8_chroma_block_size - 1) * webp_vp8_chroma_block_size ..][0..webp_vp8_chroma_block_size],
        );
        index = 0;
        while (index < webp_vp8_chroma_block_size) : (index += 1) {
            self.left_u[index] = u_plane[index * webp_vp8_chroma_block_size + webp_vp8_chroma_block_size - 1];
            self.left_v[index] = v_plane[index * webp_vp8_chroma_block_size + webp_vp8_chroma_block_size - 1];
        }
        self.has_left = true;
    }
};

fn parseVp8Frame(data: []const u8, expected_header: Header) DecodeError!Vp8Frame {
    const tag = try raw_vp8.parseFrameTag(data);
    return switch (tag.frame_type) {
        .key => parseVp8KeyFrame(data),
        .inter => parseVp8InterFrame(data, tag, expected_header),
    };
}

fn parseVp8KeyFrame(data: []const u8) DecodeError!Vp8Frame {
    const payload = try raw_vp8.parseKeyFramePayload(data);
    const first_partition = payload.first_partition;
    const frame_header = try parseVp8CompressedFrameHeader(.key, payload.header, first_partition);
    const macroblocks = try parseVp8MacroblockHeaders(&frame_header);
    const token_partitions = payload.token_partitions;
    const token_partition_slices = try parseVp8TokenPartitions(token_partitions, frame_header.token_partition_count);
    return .{
        .frame_type = .key,
        .header = payload.header,
        .first_partition = first_partition,
        .token_partitions = token_partitions,
        .token_partition_count = frame_header.token_partition_count,
        .token_partition_slices = token_partition_slices,
        .macroblocks = macroblocks,
        .compressed_header = frame_header,
    };
}

fn parseVp8InterFrame(data: []const u8, tag: raw_vp8.FrameTag, header: Header) DecodeError!Vp8Frame {
    if (tag.first_partition_len == 0) return error.BadImage;
    if (tag.first_partition_len > data.len - raw_vp8.frame_tag_size) return error.BadImage;
    const first_partition_start = raw_vp8.frame_tag_size;
    const first_partition_end = first_partition_start + tag.first_partition_len;
    const first_partition = data[first_partition_start..first_partition_end];
    const frame_header = try parseVp8CompressedFrameHeader(.inter, header, first_partition);
    const macroblocks = try parseVp8MacroblockHeaders(&frame_header);
    const token_partitions = data[first_partition_end..];
    const token_partition_slices = try parseVp8TokenPartitions(token_partitions, frame_header.token_partition_count);
    return .{
        .frame_type = .inter,
        .header = header,
        .first_partition = first_partition,
        .token_partitions = token_partitions,
        .token_partition_count = frame_header.token_partition_count,
        .token_partition_slices = token_partition_slices,
        .macroblocks = macroblocks,
        .compressed_header = frame_header,
    };
}

fn reconstructVp8Frame(frame: *const Vp8Frame, previous: ?[]const u8, out: []ui.Color) DecodeError!void {
    var header_reader = frame.compressed_header.reader;
    const mb_w = vp8MacroblockDimension(frame.header.width);
    const mb_h = vp8MacroblockDimension(frame.header.height);
    const used_partition_count = @min(frame.token_partition_count, mb_h);
    var token_readers: [webp_vp8_token_partition_count_max]Vp8BoolReader = undefined;
    var partition_index: usize = 0;
    while (partition_index < used_partition_count) : (partition_index += 1) {
        token_readers[partition_index] = try Vp8BoolReader.init(frame.token_partition_slices.slices[partition_index]);
    }

    var prediction = Vp8PredictionState.init(frame.header.width);
    var intra4_mode_state = Vp8Intra4ModeState.init(frame.header.width);
    var mb_y: usize = 0;
    while (mb_y < mb_h) : (mb_y += 1) {
        prediction.startRow(mb_y);
        intra4_mode_state.startRow();
        const token_reader = &token_readers[mb_y % frame.token_partition_count];
        var mb_x: usize = 0;
        while (mb_x < mb_w) : (mb_x += 1) {
            const macroblock_header = try parseVp8MacroblockHeader(&frame.compressed_header, &header_reader, &intra4_mode_state, mb_x);
            switch (macroblock_header.prediction) {
                .intra => {},
                .inter_zero => {
                    if (!macroblock_header.skip) return error.UnsupportedImage;
                    const reference = previous orelse return error.UnsupportedImage;
                    try copyVp8InterZeroMacroblock(frame.header, mb_x, mb_y, reference, out);
                    continue;
                },
            }
            var coeffs = Vp8MacroblockCoeffs{};
            if (!macroblock_header.skip) {
                _ = try parseVp8ResidualMacroblock(token_reader, &frame.compressed_header.coeff_probabilities, macroblock_header.luma_mode, &coeffs);
            }
            reconstructVp8Macroblock(frame, macroblock_header, &coeffs, mb_x, mb_y, &prediction, out);
        }
    }
}

fn reconstructVp8Macroblock(frame: *const Vp8Frame, macroblock_header: Vp8MacroblockHeader, coeffs: *const Vp8MacroblockCoeffs, mb_x: usize, mb_y: usize, prediction: *Vp8PredictionState, out: []ui.Color) void {
    var y_plane = [_]u8{0} ** (webp_vp8_macroblock_size * webp_vp8_macroblock_size);
    var u_plane = [_]u8{0} ** (webp_vp8_chroma_block_size * webp_vp8_chroma_block_size);
    var v_plane = [_]u8{0} ** (webp_vp8_chroma_block_size * webp_vp8_chroma_block_size);

    predictVp8Chroma(macroblock_header.chroma_mode, prediction.uEdges(mb_x), &u_plane);
    predictVp8Chroma(macroblock_header.chroma_mode, prediction.vEdges(mb_x), &v_plane);

    const quant = frame_header_quant(&frame.compressed_header, macroblock_header.segment_id);
    if (macroblock_header.luma_mode == .b_pred) {
        reconstructVp8BPredLuma(quant, prediction.lumaEdges(mb_x), macroblock_header.intra4_modes, coeffs, &y_plane);
    } else {
        predictVp8Luma(macroblock_header.luma_mode, prediction.lumaEdges(mb_x), &y_plane);
        addVp8LumaResidualsWithY2(quant, coeffs, &y_plane);
    }
    addVp8ChromaResiduals(quant, coeffs, &u_plane, &v_plane);
    writeVp8MacroblockRgba(frame.header, mb_x, mb_y, &y_plane, &u_plane, &v_plane, out);
    prediction.finishMacroblock(mb_x, &y_plane, &u_plane, &v_plane);
}

fn copyVp8InterZeroMacroblock(header: Header, mb_x: usize, mb_y: usize, previous: []const u8, out: []ui.Color) DecodeError!void {
    const required_bytes = try checkedMul(try pixelCount(header), @sizeOf(ui.Color));
    if (previous.len < required_bytes) return error.PixelBudget;
    const pixel_x = mb_x * webp_vp8_macroblock_size;
    const pixel_y = mb_y * webp_vp8_macroblock_size;
    var local_y: usize = 0;
    while (local_y < webp_vp8_macroblock_size and pixel_y + local_y < header.height) : (local_y += 1) {
        var local_x: usize = 0;
        while (local_x < webp_vp8_macroblock_size and pixel_x + local_x < header.width) : (local_x += 1) {
            const out_index = (pixel_y + local_y) * header.width + pixel_x + local_x;
            const byte_index = out_index * @sizeOf(ui.Color);
            out[out_index] = .{
                .r = previous[byte_index],
                .g = previous[byte_index + 1],
                .b = previous[byte_index + 2],
                .a = previous[byte_index + 3],
            };
        }
    }
}

fn predictVp8Luma(mode: Vp8LumaMode, edges: Vp8Edges(webp_vp8_macroblock_size), plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8) void {
    switch (mode) {
        .dc => predictVp8Dc(webp_vp8_macroblock_size, edges, plane[0..]),
        .vertical => predictVp8Vertical(webp_vp8_macroblock_size, edges, plane[0..]),
        .horizontal => predictVp8Horizontal(webp_vp8_macroblock_size, edges, plane[0..]),
        .true_motion => predictVp8TrueMotion(webp_vp8_macroblock_size, edges, plane[0..]),
        .b_pred => predictVp8Intra4DcOnly(edges, plane),
    }
}

fn predictVp8Chroma(mode: Vp8ChromaMode, edges: Vp8Edges(webp_vp8_chroma_block_size), plane: *[webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8) void {
    switch (mode) {
        .dc => predictVp8Dc(webp_vp8_chroma_block_size, edges, plane[0..]),
        .vertical => predictVp8Vertical(webp_vp8_chroma_block_size, edges, plane[0..]),
        .horizontal => predictVp8Horizontal(webp_vp8_chroma_block_size, edges, plane[0..]),
        .true_motion => predictVp8TrueMotion(webp_vp8_chroma_block_size, edges, plane[0..]),
    }
}

fn predictVp8Dc(comptime size: usize, edges: Vp8Edges(size), plane: []u8) void {
    const value = vp8DcPredictionValue(size, edges);
    @memset(plane[0 .. size * size], value);
}

fn predictVp8Vertical(comptime size: usize, edges: Vp8Edges(size), plane: []u8) void {
    var y: usize = 0;
    while (y < size) : (y += 1) {
        @memcpy(plane[y * size ..][0..size], &edges.top);
    }
}

fn predictVp8Horizontal(comptime size: usize, edges: Vp8Edges(size), plane: []u8) void {
    var y: usize = 0;
    while (y < size) : (y += 1) {
        @memset(plane[y * size ..][0..size], edges.left[y]);
    }
}

fn predictVp8TrueMotion(comptime size: usize, edges: Vp8Edges(size), plane: []u8) void {
    var y: usize = 0;
    while (y < size) : (y += 1) {
        var x: usize = 0;
        while (x < size) : (x += 1) {
            plane[y * size + x] = clampU8(@as(i32, edges.left[y]) + @as(i32, edges.top[x]) - @as(i32, edges.top_left));
        }
    }
}

fn predictVp8Intra4DcOnly(edges: Vp8Edges(webp_vp8_macroblock_size), plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8) void {
    var block: usize = 0;
    while (block < webp_vp8_y_block_count) : (block += 1) {
        predictVp8Intra4Block(.dc, edges, plane, block);
    }
}

fn predictVp8Intra4Block(mode: Vp8Intra4Mode, edges: Vp8Edges(webp_vp8_macroblock_size), plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block: usize) void {
    const block_x = (block & 3) * webp_vp8_intra4_block_width;
    const block_y = (block >> 2) * webp_vp8_intra4_block_width;
    var a: [webp_vp8_intra4_block_width * 2]u8 = undefined;
    var l: [webp_vp8_intra4_block_width]u8 = undefined;
    var index: usize = 0;
    while (index < a.len) : (index += 1) a[index] = vp8Intra4Top(edges, plane, block_x, block_y, index);
    index = 0;
    while (index < l.len) : (index += 1) l[index] = vp8Intra4Left(edges, plane, block_x, block_y, index);
    const p = vp8Intra4TopLeft(edges, plane, block_x, block_y);
    const e = [_]u8{ l[3], l[2], l[1], l[0], p, a[0], a[1], a[2], a[3] };
    switch (mode) {
        .dc => predictVp8Intra4DcBlockFromEdges(&a, &l, plane, block_x, block_y),
        .true_motion => predictVp8Intra4TrueMotionBlock(&a, &l, p, plane, block_x, block_y),
        .vertical => predictVp8Intra4VerticalBlock(&a, plane, block_x, block_y),
        .horizontal => predictVp8Intra4HorizontalBlock(&l, plane, block_x, block_y),
        .left_down => predictVp8Intra4LeftDownBlock(&a, plane, block_x, block_y),
        .right_down => predictVp8Intra4RightDownBlock(&e, plane, block_x, block_y),
        .vertical_right => predictVp8Intra4VerticalRightBlock(&e, plane, block_x, block_y),
        .vertical_left => predictVp8Intra4VerticalLeftBlock(&a, plane, block_x, block_y),
        .horizontal_down => predictVp8Intra4HorizontalDownBlock(&e, plane, block_x, block_y),
        .horizontal_up => predictVp8Intra4HorizontalUpBlock(&l, plane, block_x, block_y),
    }
}

fn predictVp8Intra4DcBlockFromEdges(a: *const [webp_vp8_intra4_block_width * 2]u8, l: *const [webp_vp8_intra4_block_width]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    var sum: usize = 0;
    var index: usize = 0;
    while (index < webp_vp8_intra4_block_width) : (index += 1) {
        sum += @as(usize, a[index]) + @as(usize, l[index]);
    }
    const value: u8 = @intCast((sum + 4) >> 3);
    var y: usize = 0;
    while (y < webp_vp8_intra4_block_width) : (y += 1) {
        @memset(plane[(block_y + y) * webp_vp8_macroblock_size + block_x ..][0..webp_vp8_intra4_block_width], value);
    }
}

fn predictVp8Intra4TrueMotionBlock(a: *const [webp_vp8_intra4_block_width * 2]u8, l: *const [webp_vp8_intra4_block_width]u8, p: u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    var y: usize = 0;
    while (y < webp_vp8_intra4_block_width) : (y += 1) {
        var x: usize = 0;
        while (x < webp_vp8_intra4_block_width) : (x += 1) {
            plane[(block_y + y) * webp_vp8_macroblock_size + block_x + x] = clampU8(@as(i32, l[y]) + @as(i32, a[x]) - @as(i32, p));
        }
    }
}

fn predictVp8Intra4VerticalBlock(a: *const [webp_vp8_intra4_block_width * 2]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    const values = [_]u8{
        avg3(a[0], a[1], a[2]),
        avg3(a[1], a[2], a[3]),
        avg3(a[2], a[3], a[4]),
        avg3(a[3], a[4], a[5]),
    };
    var y: usize = 0;
    while (y < webp_vp8_intra4_block_width) : (y += 1) {
        @memcpy(plane[(block_y + y) * webp_vp8_macroblock_size + block_x ..][0..webp_vp8_intra4_block_width], &values);
    }
}

fn predictVp8Intra4HorizontalBlock(l: *const [webp_vp8_intra4_block_width]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    var value = avg3(l[2], l[3], l[3]);
    var row: usize = webp_vp8_intra4_block_width;
    while (row > 0) {
        row -= 1;
        @memset(plane[(block_y + row) * webp_vp8_macroblock_size + block_x ..][0..webp_vp8_intra4_block_width], value);
        if (row != 0) value = avg3(l[row - 1], l[row], l[row + 1]);
    }
}

fn predictVp8Intra4LeftDownBlock(a: *const [webp_vp8_intra4_block_width * 2]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    writeVp8Intra4(plane, block_x, block_y, 0, 0, avg3(a[1], a[2], a[3]));
    writeVp8Intra4(plane, block_x, block_y, 0, 1, avg3(a[2], a[3], a[4]));
    writeVp8Intra4(plane, block_x, block_y, 1, 0, avg3(a[2], a[3], a[4]));
    writeVp8Intra4(plane, block_x, block_y, 0, 2, avg3(a[3], a[4], a[5]));
    writeVp8Intra4(plane, block_x, block_y, 1, 1, avg3(a[3], a[4], a[5]));
    writeVp8Intra4(plane, block_x, block_y, 2, 0, avg3(a[3], a[4], a[5]));
    writeVp8Intra4(plane, block_x, block_y, 0, 3, avg3(a[4], a[5], a[6]));
    writeVp8Intra4(plane, block_x, block_y, 1, 2, avg3(a[4], a[5], a[6]));
    writeVp8Intra4(plane, block_x, block_y, 2, 1, avg3(a[4], a[5], a[6]));
    writeVp8Intra4(plane, block_x, block_y, 3, 0, avg3(a[4], a[5], a[6]));
    writeVp8Intra4(plane, block_x, block_y, 1, 3, avg3(a[5], a[6], a[7]));
    writeVp8Intra4(plane, block_x, block_y, 2, 2, avg3(a[5], a[6], a[7]));
    writeVp8Intra4(plane, block_x, block_y, 3, 1, avg3(a[5], a[6], a[7]));
    writeVp8Intra4(plane, block_x, block_y, 2, 3, avg3(a[6], a[7], a[7]));
    writeVp8Intra4(plane, block_x, block_y, 3, 2, avg3(a[6], a[7], a[7]));
    writeVp8Intra4(plane, block_x, block_y, 3, 3, avg3(a[6], a[7], a[7]));
}

fn predictVp8Intra4RightDownBlock(e: *const [9]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    writeVp8Intra4(plane, block_x, block_y, 3, 0, avg3p(e, 1));
    writeVp8Intra4(plane, block_x, block_y, 3, 1, avg3p(e, 2));
    writeVp8Intra4(plane, block_x, block_y, 2, 0, avg3p(e, 2));
    writeVp8Intra4(plane, block_x, block_y, 3, 2, avg3p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 2, 1, avg3p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 1, 0, avg3p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 3, 3, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 2, 2, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 1, 1, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 0, 0, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 2, 3, avg3p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 1, 2, avg3p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 0, 1, avg3p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 1, 3, avg3p(e, 6));
    writeVp8Intra4(plane, block_x, block_y, 0, 2, avg3p(e, 6));
    writeVp8Intra4(plane, block_x, block_y, 0, 3, avg3p(e, 7));
}

fn predictVp8Intra4VerticalRightBlock(e: *const [9]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    writeVp8Intra4(plane, block_x, block_y, 3, 0, avg3p(e, 2));
    writeVp8Intra4(plane, block_x, block_y, 2, 0, avg3p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 3, 1, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 1, 0, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 2, 1, avg2p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 0, 0, avg2p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 3, 2, avg3p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 1, 1, avg3p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 2, 2, avg2p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 0, 1, avg2p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 3, 3, avg3p(e, 6));
    writeVp8Intra4(plane, block_x, block_y, 1, 2, avg3p(e, 6));
    writeVp8Intra4(plane, block_x, block_y, 2, 3, avg2p(e, 6));
    writeVp8Intra4(plane, block_x, block_y, 0, 2, avg2p(e, 6));
    writeVp8Intra4(plane, block_x, block_y, 1, 3, avg3p(e, 7));
    writeVp8Intra4(plane, block_x, block_y, 0, 3, avg2p(e, 7));
}

fn predictVp8Intra4VerticalLeftBlock(a: *const [webp_vp8_intra4_block_width * 2]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    writeVp8Intra4(plane, block_x, block_y, 0, 0, avg2(a[0], a[1]));
    writeVp8Intra4(plane, block_x, block_y, 1, 0, avg3(a[1], a[2], a[3]));
    writeVp8Intra4(plane, block_x, block_y, 2, 0, avg2(a[1], a[2]));
    writeVp8Intra4(plane, block_x, block_y, 0, 1, avg2(a[1], a[2]));
    writeVp8Intra4(plane, block_x, block_y, 1, 1, avg3(a[2], a[3], a[4]));
    writeVp8Intra4(plane, block_x, block_y, 3, 0, avg3(a[2], a[3], a[4]));
    writeVp8Intra4(plane, block_x, block_y, 2, 1, avg2(a[2], a[3]));
    writeVp8Intra4(plane, block_x, block_y, 0, 2, avg2(a[2], a[3]));
    writeVp8Intra4(plane, block_x, block_y, 3, 1, avg3(a[3], a[4], a[5]));
    writeVp8Intra4(plane, block_x, block_y, 1, 2, avg3(a[3], a[4], a[5]));
    writeVp8Intra4(plane, block_x, block_y, 2, 2, avg2(a[3], a[4]));
    writeVp8Intra4(plane, block_x, block_y, 0, 3, avg2(a[3], a[4]));
    writeVp8Intra4(plane, block_x, block_y, 3, 2, avg3(a[4], a[5], a[6]));
    writeVp8Intra4(plane, block_x, block_y, 1, 3, avg3(a[4], a[5], a[6]));
    writeVp8Intra4(plane, block_x, block_y, 2, 3, avg3(a[5], a[6], a[7]));
    writeVp8Intra4(plane, block_x, block_y, 3, 3, avg3(a[6], a[7], a[7]));
}

fn predictVp8Intra4HorizontalDownBlock(e: *const [9]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    writeVp8Intra4(plane, block_x, block_y, 3, 0, avg2p(e, 0));
    writeVp8Intra4(plane, block_x, block_y, 3, 1, avg3p(e, 1));
    writeVp8Intra4(plane, block_x, block_y, 2, 0, avg2p(e, 1));
    writeVp8Intra4(plane, block_x, block_y, 3, 2, avg2p(e, 1));
    writeVp8Intra4(plane, block_x, block_y, 2, 1, avg3p(e, 2));
    writeVp8Intra4(plane, block_x, block_y, 3, 3, avg3p(e, 2));
    writeVp8Intra4(plane, block_x, block_y, 2, 2, avg2p(e, 2));
    writeVp8Intra4(plane, block_x, block_y, 1, 0, avg2p(e, 2));
    writeVp8Intra4(plane, block_x, block_y, 2, 3, avg3p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 1, 1, avg3p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 1, 2, avg2p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 0, 0, avg2p(e, 3));
    writeVp8Intra4(plane, block_x, block_y, 1, 3, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 0, 1, avg3p(e, 4));
    writeVp8Intra4(plane, block_x, block_y, 0, 2, avg3p(e, 5));
    writeVp8Intra4(plane, block_x, block_y, 0, 3, avg3p(e, 6));
}

fn predictVp8Intra4HorizontalUpBlock(l: *const [webp_vp8_intra4_block_width]u8, plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) void {
    writeVp8Intra4(plane, block_x, block_y, 0, 0, avg2(l[0], l[1]));
    writeVp8Intra4(plane, block_x, block_y, 0, 1, avg3(l[1], l[2], l[3]));
    writeVp8Intra4(plane, block_x, block_y, 0, 2, avg2(l[1], l[2]));
    writeVp8Intra4(plane, block_x, block_y, 1, 0, avg2(l[1], l[2]));
    writeVp8Intra4(plane, block_x, block_y, 0, 3, avg3(l[2], l[3], l[3]));
    writeVp8Intra4(plane, block_x, block_y, 1, 1, avg3(l[2], l[3], l[3]));
    writeVp8Intra4(plane, block_x, block_y, 1, 2, avg2(l[2], l[3]));
    writeVp8Intra4(plane, block_x, block_y, 2, 0, avg2(l[2], l[3]));
    writeVp8Intra4(plane, block_x, block_y, 1, 3, avg3(l[2], l[3], l[3]));
    writeVp8Intra4(plane, block_x, block_y, 2, 1, avg3(l[2], l[3], l[3]));
    writeVp8Intra4(plane, block_x, block_y, 2, 2, l[3]);
    writeVp8Intra4(plane, block_x, block_y, 2, 3, l[3]);
    writeVp8Intra4(plane, block_x, block_y, 3, 0, l[3]);
    writeVp8Intra4(plane, block_x, block_y, 3, 1, l[3]);
    writeVp8Intra4(plane, block_x, block_y, 3, 2, l[3]);
    writeVp8Intra4(plane, block_x, block_y, 3, 3, l[3]);
}

fn vp8Intra4Top(edges: Vp8Edges(webp_vp8_macroblock_size), plane: *const [webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize, offset: usize) u8 {
    const x = block_x + offset;
    if (block_y == 0) {
        return if (x < webp_vp8_macroblock_size) edges.top[x] else edges.top_right[x - webp_vp8_macroblock_size];
    }
    return if (x < webp_vp8_macroblock_size)
        plane[(block_y - 1) * webp_vp8_macroblock_size + x]
    else
        edges.top_right[x - webp_vp8_macroblock_size];
}

fn vp8Intra4Left(edges: Vp8Edges(webp_vp8_macroblock_size), plane: *const [webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize, offset: usize) u8 {
    return if (block_x == 0)
        edges.left[block_y + offset]
    else
        plane[(block_y + offset) * webp_vp8_macroblock_size + block_x - 1];
}

fn vp8Intra4TopLeft(edges: Vp8Edges(webp_vp8_macroblock_size), plane: *const [webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize) u8 {
    if (block_y == 0 and block_x == 0) return edges.top_left;
    if (block_y == 0) return edges.top[block_x - 1];
    if (block_x == 0) return edges.left[block_y - 1];
    return plane[(block_y - 1) * webp_vp8_macroblock_size + block_x - 1];
}

fn writeVp8Intra4(plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block_x: usize, block_y: usize, y: usize, x: usize, value: u8) void {
    plane[(block_y + y) * webp_vp8_macroblock_size + block_x + x] = value;
}

fn avg2(x: u8, y: u8) u8 {
    return @intCast((@as(u16, x) + @as(u16, y) + 1) >> 1);
}

fn avg3(x: u8, y: u8, z: u8) u8 {
    return @intCast((@as(u16, x) + @as(u16, y) + @as(u16, y) + @as(u16, z) + 2) >> 2);
}

fn avg2p(values: *const [9]u8, index: usize) u8 {
    return avg2(values[index], values[index + 1]);
}

fn avg3p(values: *const [9]u8, index: usize) u8 {
    return avg3(values[index - 1], values[index], values[index + 1]);
}

fn vp8DcPredictionValue(comptime size: usize, edges: Vp8Edges(size)) u8 {
    var sum: usize = 0;
    if (edges.has_top) {
        for (edges.top) |value| sum += value;
    }
    if (edges.has_left) {
        for (edges.left) |value| sum += value;
    }
    if (edges.has_top and edges.has_left) return @intCast((sum + size) / (2 * size));
    if (edges.has_top or edges.has_left) return @intCast((sum + (size / 2)) / size);
    return vp8_neutral_luma;
}

fn reconstructVp8BPredLuma(
    quant: Vp8Dequant,
    edges: Vp8Edges(webp_vp8_macroblock_size),
    intra4_modes: [webp_vp8_y_block_count]Vp8Intra4Mode,
    coeffs: *const Vp8MacroblockCoeffs,
    y_plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8,
) void {
    var block: usize = 0;
    while (block < webp_vp8_y_block_count) : (block += 1) {
        predictVp8Intra4Block(intra4_modes[block], edges, y_plane, block);
        var block_coeffs = dequantizeVp8YBlockWithOwnDc(&coeffs.blocks[block], quant);
        addVp8IdctBlock(&block_coeffs, yPlaneBlock(y_plane, block), webp_vp8_macroblock_size);
    }
}

fn addVp8LumaResidualsWithY2(
    quant: Vp8Dequant,
    coeffs: *const Vp8MacroblockCoeffs,
    y_plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8,
) void {
    var y2 = dequantizeVp8Y2Block(&coeffs.blocks[webp_vp8_y2_block_index], quant);
    const y_dc = inverseVp8Wht(&y2);
    var block: usize = 0;
    while (block < webp_vp8_y_block_count) : (block += 1) {
        var block_coeffs = dequantizeVp8YBlockWithY2Dc(&coeffs.blocks[block], quant, y_dc[block]);
        addVp8IdctBlock(&block_coeffs, yPlaneBlock(y_plane, block), webp_vp8_macroblock_size);
    }
}

fn addVp8ChromaResiduals(
    quant: Vp8Dequant,
    coeffs: *const Vp8MacroblockCoeffs,
    u_plane: *[webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8,
    v_plane: *[webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8,
) void {
    var block: usize = 0;
    while (block < webp_vp8_chroma_block_count) : (block += 1) {
        const coeff_block = webp_vp8_y_block_count + block;
        var block_coeffs = dequantizeVp8UvBlock(&coeffs.blocks[coeff_block], quant);
        if (block < 4) {
            addVp8IdctBlock(&block_coeffs, uvPlaneBlock(u_plane, block), webp_vp8_chroma_block_size);
        } else {
            addVp8IdctBlock(&block_coeffs, uvPlaneBlock(v_plane, block - 4), webp_vp8_chroma_block_size);
        }
    }
}

const Vp8Dequant = struct {
    y_dc: i16,
    y_ac: i16,
    y2_dc: i16,
    y2_ac: i16,
    uv_dc: i16,
    uv_ac: i16,
};

fn frame_header_quant(frame_header: *const Vp8CompressedFrameHeader, segment_id: u8) Vp8Dequant {
    if (segment_id >= webp_vp8_segment_count) unreachable;
    const segment_base = vp8SegmentQuantBase(frame_header, segment_id);
    const y_dc_index = vp8QuantIndex(segment_base, frame_header.quant.y_dc_delta);
    const y2_dc_index = vp8QuantIndex(segment_base, frame_header.quant.y2_dc_delta);
    const y2_ac_index = vp8QuantIndex(segment_base, frame_header.quant.y2_ac_delta);
    const uv_dc_index = vp8QuantIndex(segment_base, frame_header.quant.uv_dc_delta);
    const uv_ac_index = vp8QuantIndex(segment_base, frame_header.quant.uv_ac_delta);
    return .{
        .y_dc = webp_vp8_dc_quant[y_dc_index],
        .y_ac = webp_vp8_ac_quant[segment_base],
        .y2_dc = webp_vp8_dc_quant[y2_dc_index] * 2,
        .y2_ac = @intCast(@divTrunc(@as(i32, webp_vp8_ac_quant[y2_ac_index]) * 155, 100)),
        .uv_dc = webp_vp8_dc_quant[uv_dc_index],
        .uv_ac = webp_vp8_ac_quant[uv_ac_index],
    };
}

fn vp8SegmentQuantBase(frame_header: *const Vp8CompressedFrameHeader, segment_id: u8) u8 {
    const segment_delta = frame_header.segment_quant_deltas[segment_id];
    const raw = if (frame_header.segment_quant_absolute)
        @as(i16, segment_delta)
    else
        @as(i16, frame_header.quant.y_ac) + @as(i16, segment_delta);
    if (raw < 0) return 0;
    if (raw >= webp_vp8_dc_quant.len) return @intCast(webp_vp8_dc_quant.len - 1);
    return @intCast(raw);
}

fn vp8QuantIndex(base: u8, delta: i8) usize {
    const raw = @as(i16, base) + @as(i16, delta);
    if (raw < 0) return 0;
    if (raw >= webp_vp8_dc_quant.len) return webp_vp8_dc_quant.len - 1;
    return @intCast(raw);
}

fn dequantizeVp8Y2Block(block: *const [webp_vp8_block_coeff_count]i16, quant: Vp8Dequant) [webp_vp8_block_coeff_count]i32 {
    var out: [webp_vp8_block_coeff_count]i32 = undefined;
    out[0] = @as(i32, block[0]) * quant.y2_dc;
    var index: usize = 1;
    while (index < out.len) : (index += 1) {
        out[index] = @as(i32, block[index]) * quant.y2_ac;
    }
    return out;
}

fn dequantizeVp8YBlockWithY2Dc(block: *const [webp_vp8_block_coeff_count]i16, quant: Vp8Dequant, dc: i32) [webp_vp8_block_coeff_count]i32 {
    var out: [webp_vp8_block_coeff_count]i32 = undefined;
    out[0] = dc;
    var index: usize = 1;
    while (index < out.len) : (index += 1) {
        out[index] = @as(i32, block[index]) * quant.y_ac;
    }
    return out;
}

fn dequantizeVp8YBlockWithOwnDc(block: *const [webp_vp8_block_coeff_count]i16, quant: Vp8Dequant) [webp_vp8_block_coeff_count]i32 {
    var out: [webp_vp8_block_coeff_count]i32 = undefined;
    out[0] = @as(i32, block[0]) * quant.y_dc;
    var index: usize = 1;
    while (index < out.len) : (index += 1) {
        out[index] = @as(i32, block[index]) * quant.y_ac;
    }
    return out;
}

fn dequantizeVp8UvBlock(block: *const [webp_vp8_block_coeff_count]i16, quant: Vp8Dequant) [webp_vp8_block_coeff_count]i32 {
    var out: [webp_vp8_block_coeff_count]i32 = undefined;
    out[0] = @as(i32, block[0]) * quant.uv_dc;
    var index: usize = 1;
    while (index < out.len) : (index += 1) {
        out[index] = @as(i32, block[index]) * quant.uv_ac;
    }
    return out;
}

fn inverseVp8Wht(input: *const [webp_vp8_block_coeff_count]i32) [webp_vp8_block_coeff_count]i32 {
    var tmp: [webp_vp8_block_coeff_count]i32 = undefined;
    var out: [webp_vp8_block_coeff_count]i32 = undefined;
    var row: usize = 0;
    while (row < 4) : (row += 1) {
        const offset = row * 4;
        const a1 = input[offset] + input[offset + 3];
        const b1 = input[offset + 1] + input[offset + 2];
        const c1 = input[offset + 1] - input[offset + 2];
        const d1 = input[offset] - input[offset + 3];
        tmp[offset] = a1 + b1;
        tmp[offset + 1] = c1 + d1;
        tmp[offset + 2] = a1 - b1;
        tmp[offset + 3] = d1 - c1;
    }
    var column: usize = 0;
    while (column < 4) : (column += 1) {
        const a1 = tmp[column] + tmp[12 + column];
        const b1 = tmp[4 + column] + tmp[8 + column];
        const c1 = tmp[4 + column] - tmp[8 + column];
        const d1 = tmp[column] - tmp[12 + column];
        out[column] = (a1 + b1 + webp_vp8_wht_round) >> webp_vp8_wht_shift;
        out[4 + column] = (c1 + d1 + webp_vp8_wht_round) >> webp_vp8_wht_shift;
        out[8 + column] = (a1 - b1 + webp_vp8_wht_round) >> webp_vp8_wht_shift;
        out[12 + column] = (d1 - c1 + webp_vp8_wht_round) >> webp_vp8_wht_shift;
    }
    return out;
}

fn addVp8IdctBlock(input: *const [webp_vp8_block_coeff_count]i32, block: Vp8PlaneBlock, stride: usize) void {
    var tmp: [webp_vp8_block_coeff_count]i32 = undefined;
    var row: usize = 0;
    while (row < 4) : (row += 1) {
        const offset = row * 4;
        const a1 = input[offset] + input[offset + 2];
        const b1 = input[offset] - input[offset + 2];
        const temp1 = input[offset + 1] + ((input[offset + 1] * webp_vp8_idct_cospi8sqrt2minus1) >> 16);
        const temp2 = (input[offset + 3] * webp_vp8_idct_sinpi8sqrt2) >> 16;
        const c1 = temp1 - temp2;
        const temp3 = input[offset + 3] + ((input[offset + 3] * webp_vp8_idct_cospi8sqrt2minus1) >> 16);
        const temp4 = (input[offset + 1] * webp_vp8_idct_sinpi8sqrt2) >> 16;
        const d1 = temp3 + temp4;
        tmp[offset] = a1 + d1;
        tmp[offset + 1] = b1 + c1;
        tmp[offset + 2] = b1 - c1;
        tmp[offset + 3] = a1 - d1;
    }

    var column: usize = 0;
    while (column < 4) : (column += 1) {
        const a1 = tmp[column] + tmp[8 + column];
        const b1 = tmp[column] - tmp[8 + column];
        const temp1 = tmp[4 + column] + ((tmp[4 + column] * webp_vp8_idct_cospi8sqrt2minus1) >> 16);
        const temp2 = (tmp[12 + column] * webp_vp8_idct_sinpi8sqrt2) >> 16;
        const c1 = temp1 - temp2;
        const temp3 = tmp[12 + column] + ((tmp[12 + column] * webp_vp8_idct_cospi8sqrt2minus1) >> 16);
        const temp4 = (tmp[4 + column] * webp_vp8_idct_sinpi8sqrt2) >> 16;
        const d1 = temp3 + temp4;
        addVp8Pixel(block.base, block.offset + column, stride, (a1 + d1 + webp_vp8_idct_round) >> webp_vp8_idct_shift);
        addVp8Pixel(block.base, block.offset + stride + column, stride, (b1 + c1 + webp_vp8_idct_round) >> webp_vp8_idct_shift);
        addVp8Pixel(block.base, block.offset + 2 * stride + column, stride, (b1 - c1 + webp_vp8_idct_round) >> webp_vp8_idct_shift);
        addVp8Pixel(block.base, block.offset + 3 * stride + column, stride, (a1 - d1 + webp_vp8_idct_round) >> webp_vp8_idct_shift);
    }
}

const Vp8PlaneBlock = struct {
    base: []u8,
    offset: usize,
};

fn yPlaneBlock(plane: *[webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8, block: usize) Vp8PlaneBlock {
    const block_x = block & 3;
    const block_y = block >> 2;
    return .{ .base = plane[0..], .offset = block_y * 4 * webp_vp8_macroblock_size + block_x * 4 };
}

fn uvPlaneBlock(plane: *[webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8, block: usize) Vp8PlaneBlock {
    const block_x = block & 1;
    const block_y = block >> 1;
    return .{ .base = plane[0..], .offset = block_y * 4 * webp_vp8_chroma_block_size + block_x * 4 };
}

fn addVp8Pixel(plane: []u8, index: usize, stride: usize, delta: i32) void {
    _ = stride;
    plane[index] = clampU8(@as(i32, plane[index]) + delta);
}

fn writeVp8MacroblockRgba(
    header: Header,
    mb_x: usize,
    mb_y: usize,
    y_plane: *const [webp_vp8_macroblock_size * webp_vp8_macroblock_size]u8,
    u_plane: *const [webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8,
    v_plane: *const [webp_vp8_chroma_block_size * webp_vp8_chroma_block_size]u8,
    out: []ui.Color,
) void {
    const pixel_x = mb_x * webp_vp8_macroblock_size;
    const pixel_y = mb_y * webp_vp8_macroblock_size;
    var local_y: usize = 0;
    while (local_y < webp_vp8_macroblock_size and pixel_y + local_y < header.height) : (local_y += 1) {
        var local_x: usize = 0;
        while (local_x < webp_vp8_macroblock_size and pixel_x + local_x < header.width) : (local_x += 1) {
            const luma = y_plane[local_y * webp_vp8_macroblock_size + local_x];
            const chroma_index = (local_y / 2) * webp_vp8_chroma_block_size + (local_x / 2);
            const out_index = (pixel_y + local_y) * header.width + pixel_x + local_x;
            out[out_index] = yuvToRgba(luma, u_plane[chroma_index], v_plane[chroma_index]);
        }
    }
}

fn yuvToRgba(y: u8, u: u8, v: u8) ui.Color {
    const yy = @as(i32, y);
    const uu = @as(i32, u) - webp_vp8_yuv_center;
    const vv = @as(i32, v) - webp_vp8_yuv_center;
    return .{
        .r = clampU8(yy + ((webp_vp8_yuv_v_to_r * vv + webp_vp8_yuv_round) >> webp_vp8_yuv_shift)),
        .g = clampU8(yy - ((webp_vp8_yuv_u_to_g * uu + webp_vp8_yuv_v_to_g * vv + webp_vp8_yuv_round) >> webp_vp8_yuv_shift)),
        .b = clampU8(yy + ((webp_vp8_yuv_u_to_b * uu + webp_vp8_yuv_round) >> webp_vp8_yuv_shift)),
        .a = png_alpha_opaque,
    };
}

fn clampU8(value: i32) u8 {
    if (value <= 0) return 0;
    if (value >= 255) return 255;
    return @intCast(value);
}

const Vp8CompressedFrameHeader = struct {
    frame_type: raw_vp8.FrameType,
    header: Header,
    reader: Vp8BoolReader,
    token_partition_count: usize,
    segment_update_map: bool,
    segment_probabilities: [webp_vp8_segment_prob_count]u8,
    quant: Vp8QuantIndices,
    refresh_entropy_probabilities: bool,
    token_probability_update_count: usize,
    coeff_probabilities: [webp_vp8_coeff_update_probability_count]u8,
    use_skip_probability: bool,
    skip_probability: u8,
    prob_intra: u8,
    prob_last: u8,
    prob_golden: u8,
    intra16_probabilities: [webp_vp8_inter_intra16_probability_count]u8,
    chroma_probabilities: [webp_vp8_inter_chroma_probability_count]u8,
    segment_quant_deltas: [webp_vp8_segment_count]i8,
    segment_quant_absolute: bool,
};

const Vp8QuantIndices = struct {
    y_ac: u8,
    y_dc_delta: i8,
    y2_dc_delta: i8,
    y2_ac_delta: i8,
    uv_dc_delta: i8,
    uv_ac_delta: i8,
};

fn parseVp8CompressedFrameHeader(frame_type: raw_vp8.FrameType, header: Header, data: []const u8) DecodeError!Vp8CompressedFrameHeader {
    var reader = try Vp8BoolReader.init(data);
    switch (frame_type) {
        .key => {
            _ = try reader.readFlag();
            _ = try reader.readFlag();
        },
        .inter => {},
    }
    const segmentation = try parseVp8SegmentationHeader(&reader);
    _ = try reader.readFlag();
    _ = try reader.readLiteral(webp_vp8_loop_filter_level_bits);
    _ = try reader.readLiteral(webp_vp8_sharpness_level_bits);
    try parseVp8LoopFilterAdjustments(&reader);
    const partition_bits = try reader.readLiteral(webp_vp8_token_partition_count_bits);
    const quant = try parseVp8QuantIndices(&reader);
    const refresh_entropy_probabilities = switch (frame_type) {
        .key => try reader.readFlag(),
        .inter => try parseVp8InterReferenceHeader(&reader),
    };
    var coeff_probabilities = webp_vp8_coeff_default_probabilities;
    const token_probability_update_count = try parseVp8TokenProbabilityUpdates(&reader, &coeff_probabilities);
    const use_skip_probability = try reader.readFlag();
    const skip_probability: u8 = if (use_skip_probability) @intCast(try reader.readLiteral(webp_vp8_skip_probability_bits)) else 0;
    var prob_intra: u8 = 0;
    var prob_last: u8 = 0;
    var prob_golden: u8 = 0;
    var intra16_probabilities = webp_vp8_inter_intra16_probability_default;
    var chroma_probabilities = webp_vp8_inter_chroma_probability_default;
    if (frame_type == .inter) {
        prob_intra = @intCast(try reader.readLiteral(webp_vp8_inter_reference_probability_bits));
        prob_last = @intCast(try reader.readLiteral(webp_vp8_inter_reference_probability_bits));
        prob_golden = @intCast(try reader.readLiteral(webp_vp8_inter_reference_probability_bits));
        if (try reader.readFlag()) {
            var index: usize = 0;
            while (index < intra16_probabilities.len) : (index += 1) {
                intra16_probabilities[index] = @intCast(try reader.readLiteral(webp_vp8_inter_reference_probability_bits));
            }
        }
        if (try reader.readFlag()) {
            var index: usize = 0;
            while (index < chroma_probabilities.len) : (index += 1) {
                chroma_probabilities[index] = @intCast(try reader.readLiteral(webp_vp8_inter_reference_probability_bits));
            }
        }
        try parseVp8MotionVectorProbabilityUpdates(&reader);
    }
    return .{
        .frame_type = frame_type,
        .header = header,
        .reader = reader,
        .token_partition_count = vp8TokenPartitionCount(partition_bits),
        .segment_update_map = segmentation.update_map,
        .segment_probabilities = segmentation.probabilities,
        .quant = quant,
        .refresh_entropy_probabilities = refresh_entropy_probabilities,
        .token_probability_update_count = token_probability_update_count,
        .coeff_probabilities = coeff_probabilities,
        .use_skip_probability = use_skip_probability,
        .skip_probability = skip_probability,
        .prob_intra = prob_intra,
        .prob_last = prob_last,
        .prob_golden = prob_golden,
        .intra16_probabilities = intra16_probabilities,
        .chroma_probabilities = chroma_probabilities,
        .segment_quant_deltas = segmentation.quant_deltas,
        .segment_quant_absolute = segmentation.quant_absolute,
    };
}

fn parseVp8InterReferenceHeader(reader: *Vp8BoolReader) DecodeError!bool {
    const refresh_golden = try reader.readFlag();
    const refresh_alternate = try reader.readFlag();
    if (!refresh_golden) _ = try reader.readLiteral(webp_vp8_inter_copy_buffer_bits);
    if (!refresh_alternate) _ = try reader.readLiteral(webp_vp8_inter_copy_buffer_bits);
    _ = try reader.readFlag();
    _ = try reader.readFlag();
    const refresh_entropy_probabilities = try reader.readFlag();
    _ = try reader.readFlag();
    return refresh_entropy_probabilities;
}

fn parseVp8MotionVectorProbabilityUpdates(reader: *Vp8BoolReader) DecodeError!void {
    var component: usize = 0;
    while (component < webp_vp8_motion_vector_component_count) : (component += 1) {
        var probability: usize = 0;
        while (probability < webp_vp8_motion_vector_probability_count) : (probability += 1) {
            if (try reader.readFlag()) _ = try reader.readLiteral(webp_vp8_motion_vector_probability_update_bits);
        }
    }
}

const Vp8SegmentationHeader = struct {
    update_map: bool,
    probabilities: [webp_vp8_segment_prob_count]u8,
    quant_deltas: [webp_vp8_segment_count]i8,
    quant_absolute: bool,
};

fn parseVp8SegmentationHeader(reader: *Vp8BoolReader) DecodeError!Vp8SegmentationHeader {
    var header = Vp8SegmentationHeader{
        .update_map = false,
        .probabilities = [_]u8{webp_vp8_coeff_update_probability_default} ** webp_vp8_segment_prob_count,
        .quant_deltas = [_]i8{0} ** webp_vp8_segment_count,
        .quant_absolute = false,
    };
    if (!try reader.readFlag()) return header;
    const update_map = try reader.readFlag();
    header.update_map = update_map;
    const update_data = try reader.readFlag();
    if (update_data) {
        header.quant_absolute = try reader.readFlag();
        var segment: usize = 0;
        while (segment < webp_vp8_segment_count) : (segment += 1) {
            if (try reader.readFlag()) {
                header.quant_deltas[segment] = try readVp8SignedLiteral(reader, webp_vp8_quantizer_update_bits);
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
    return readVp8SignedLiteral(reader, bit_count);
}

fn readVp8SignedLiteral(reader: *Vp8BoolReader, bit_count: usize) DecodeError!i8 {
    const magnitude: i8 = @intCast(try reader.readLiteral(bit_count));
    if (try reader.readFlag()) return -magnitude;
    return magnitude;
}

fn parseVp8TokenProbabilityUpdates(reader: *Vp8BoolReader, probabilities: *[webp_vp8_coeff_update_probability_count]u8) DecodeError!usize {
    var update_count: usize = 0;
    var index: usize = 0;
    while (index < webp_vp8_coeff_update_probability_count) : (index += 1) {
        if (try reader.readBool(vp8CoeffUpdateProbability(index))) {
            probabilities[index] = @intCast(try reader.readLiteral(8));
            update_count += 1;
        }
    }
    return update_count;
}

const Vp8MacroblockSummary = struct {
    count: usize,
    non_skipped_count: usize,
    flat_dc: bool,
    all_skipped: bool,
    has_segment: bool,
    uniform_modes: bool,
    mode: Vp8MacroblockHeader,
};

fn parseVp8MacroblockHeaders(frame_header: *const Vp8CompressedFrameHeader) DecodeError!Vp8MacroblockSummary {
    var reader = frame_header.reader;
    const mb_w = vp8MacroblockDimension(frame_header.header.width);
    const mb_h = vp8MacroblockDimension(frame_header.header.height);
    if (mb_w > std.math.maxInt(usize) / mb_h) return error.PixelBudget;
    const macroblock_count = mb_w * mb_h;
    var intra4_mode_state = Vp8Intra4ModeState.init(frame_header.header.width);
    var non_skipped_count: usize = 0;
    var flat_dc = true;
    var first_header: ?Vp8MacroblockHeader = null;
    var has_segment = false;
    var uniform_modes = true;
    var mb_y: usize = 0;
    while (mb_y < mb_h) : (mb_y += 1) {
        intra4_mode_state.startRow();
        var mb_x: usize = 0;
        while (mb_x < mb_w) : (mb_x += 1) {
            const macroblock = mb_y * mb_w + mb_x;
            const header = try parseVp8MacroblockHeader(frame_header, &reader, &intra4_mode_state, mb_x);
            if (macroblock == 0) {
                first_header = header;
            } else if (!sameVp8MacroblockModes(first_header.?, header)) {
                uniform_modes = false;
            }
            if (header.segment_id != 0) has_segment = true;
            if (!header.skip) non_skipped_count += 1;
            if (header.luma_mode != .dc or header.chroma_mode != .dc) flat_dc = false;
        }
    }
    return .{
        .count = macroblock_count,
        .non_skipped_count = non_skipped_count,
        .flat_dc = flat_dc,
        .all_skipped = non_skipped_count == 0,
        .has_segment = has_segment,
        .uniform_modes = uniform_modes,
        .mode = first_header orelse return error.BadImage,
    };
}

fn sameVp8MacroblockModes(left: Vp8MacroblockHeader, right: Vp8MacroblockHeader) bool {
    return left.segment_id == right.segment_id and
        left.prediction == right.prediction and
        left.luma_mode == right.luma_mode and
        left.chroma_mode == right.chroma_mode and
        left.skip == right.skip and
        std.mem.eql(Vp8Intra4Mode, &left.intra4_modes, &right.intra4_modes);
}

fn vp8MacroblockDimension(pixel_dimension: usize) usize {
    return (pixel_dimension + webp_vp8_macroblock_size - 1) / webp_vp8_macroblock_size;
}

const Vp8MacroblockHeader = struct {
    segment_id: u8,
    skip: bool,
    prediction: Vp8MacroblockPrediction,
    luma_mode: Vp8LumaMode,
    intra4_modes: [webp_vp8_y_block_count]Vp8Intra4Mode,
    chroma_mode: Vp8ChromaMode,
};

const Vp8MacroblockPrediction = enum {
    intra,
    inter_zero,
};

const Vp8LumaMode = enum(u8) {
    dc,
    vertical,
    horizontal,
    true_motion,
    b_pred,
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

const Vp8Intra4Mode = enum(u8) {
    dc,
    true_motion,
    vertical,
    horizontal,
    right_down,
    vertical_right,
    left_down,
    vertical_left,
    horizontal_down,
    horizontal_up,
};

const Vp8Intra4ModeState = struct {
    top: [webp_vp8_max_luma_edge / webp_vp8_intra4_block_width]Vp8Intra4Mode,
    left: [webp_vp8_intra4_block_width]Vp8Intra4Mode,

    fn init(width: usize) Vp8Intra4ModeState {
        _ = width;
        return .{
            .top = [_]Vp8Intra4Mode{.dc} ** (webp_vp8_max_luma_edge / webp_vp8_intra4_block_width),
            .left = [_]Vp8Intra4Mode{.dc} ** webp_vp8_intra4_block_width,
        };
    }

    fn startRow(self: *Vp8Intra4ModeState) void {
        self.left = [_]Vp8Intra4Mode{.dc} ** webp_vp8_intra4_block_width;
    }
};

fn parseVp8MacroblockHeader(frame_header: *const Vp8CompressedFrameHeader, reader: *Vp8BoolReader, intra4_mode_state: *Vp8Intra4ModeState, mb_x: usize) DecodeError!Vp8MacroblockHeader {
    const segment_id = if (frame_header.segment_update_map) try readVp8SegmentId(frame_header, reader) else 0;
    const skip = if (frame_header.use_skip_probability) try reader.readBool(frame_header.skip_probability) else false;
    if (frame_header.frame_type == .inter and try reader.readBool(frame_header.prob_intra)) {
        try readVp8LastFrameReference(reader, frame_header);
        try readVp8ZeroMotionMode(reader);
        return .{
            .segment_id = segment_id,
            .skip = skip,
            .prediction = .inter_zero,
            .luma_mode = .dc,
            .intra4_modes = [_]Vp8Intra4Mode{.dc} ** webp_vp8_y_block_count,
            .chroma_mode = .dc,
        };
    }
    const luma_mode: Vp8LumaMode = switch (frame_header.frame_type) {
        .key => if (try reader.readBool(webp_vp8_intra16_block_size_probability)) vp8LumaModeFromIntra16(try readVp8Intra16Mode(reader)) else .b_pred,
        .inter => try readVp8InterIntra16Mode(reader, &frame_header.intra16_probabilities),
    };
    const intra4_modes = if (luma_mode == .b_pred)
        try readVp8Intra4Modes(reader, intra4_mode_state, mb_x)
    else blk: {
        const modes = vp8Intra4ModesFromLumaMode(luma_mode);
        updateVp8Intra4ModeState(intra4_mode_state, mb_x, modes);
        break :blk modes;
    };
    return .{
        .segment_id = segment_id,
        .skip = skip,
        .prediction = .intra,
        .luma_mode = luma_mode,
        .intra4_modes = intra4_modes,
        .chroma_mode = switch (frame_header.frame_type) {
            .key => try readVp8ChromaMode(reader),
            .inter => try readVp8InterChromaMode(reader, &frame_header.chroma_probabilities),
        },
    };
}

fn vp8LumaModeFromIntra16(mode: Vp8Intra16Mode) Vp8LumaMode {
    return switch (mode) {
        .dc => .dc,
        .vertical => .vertical,
        .horizontal => .horizontal,
        .true_motion => .true_motion,
    };
}

fn vp8Intra4ModesFromLumaMode(mode: Vp8LumaMode) [webp_vp8_y_block_count]Vp8Intra4Mode {
    const intra4_mode: Vp8Intra4Mode = switch (mode) {
        .dc => .dc,
        .vertical => .vertical,
        .horizontal => .horizontal,
        .true_motion => .true_motion,
        .b_pred => .dc,
    };
    return [_]Vp8Intra4Mode{intra4_mode} ** webp_vp8_y_block_count;
}

fn readVp8SegmentId(frame_header: *const Vp8CompressedFrameHeader, reader: *Vp8BoolReader) DecodeError!u8 {
    if (!try reader.readBool(frame_header.segment_probabilities[0])) {
        return if (try reader.readBool(frame_header.segment_probabilities[1])) 1 else 0;
    }
    return if (try reader.readBool(frame_header.segment_probabilities[2])) 3 else 2;
}

fn readVp8LastFrameReference(reader: *Vp8BoolReader, frame_header: *const Vp8CompressedFrameHeader) DecodeError!void {
    if (try reader.readBool(frame_header.prob_last)) return error.UnsupportedImage;
}

fn readVp8ZeroMotionMode(reader: *Vp8BoolReader) DecodeError!void {
    if (try reader.readBool(webp_vp8_inter_zero_mode_probability)) return error.UnsupportedImage;
}

fn readVp8Intra16Mode(reader: *Vp8BoolReader) DecodeError!Vp8Intra16Mode {
    if (try reader.readBool(webp_vp8_intra16_mode_probability_0)) {
        return if (try reader.readBool(webp_vp8_intra16_mode_probability_1)) .true_motion else .horizontal;
    }
    return if (try reader.readBool(webp_vp8_intra16_mode_probability_2)) .vertical else .dc;
}

fn readVp8InterIntra16Mode(reader: *Vp8BoolReader, probabilities: *const [webp_vp8_inter_intra16_probability_count]u8) DecodeError!Vp8LumaMode {
    if (!try reader.readBool(probabilities[0])) return .dc;
    if (!try reader.readBool(probabilities[1])) {
        return if (try reader.readBool(probabilities[2])) .horizontal else .vertical;
    }
    if (!try reader.readBool(probabilities[3])) return .true_motion;
    return error.UnsupportedImage;
}

fn readVp8Intra4Modes(reader: *Vp8BoolReader, state: *Vp8Intra4ModeState, mb_x: usize) DecodeError![webp_vp8_y_block_count]Vp8Intra4Mode {
    var modes = [_]Vp8Intra4Mode{.dc} ** webp_vp8_y_block_count;
    const top_offset = mb_x * webp_vp8_intra4_block_width;
    var y: usize = 0;
    while (y < webp_vp8_intra4_block_width) : (y += 1) {
        var x: usize = 0;
        while (x < webp_vp8_intra4_block_width) : (x += 1) {
            const top_index = top_offset + x;
            const mode = try readVp8Intra4Mode(reader, state.top[top_index], state.left[y]);
            state.top[top_index] = mode;
            state.left[y] = mode;
            modes[y * webp_vp8_intra4_block_width + x] = mode;
        }
    }
    return modes;
}

fn updateVp8Intra4ModeState(state: *Vp8Intra4ModeState, mb_x: usize, modes: [webp_vp8_y_block_count]Vp8Intra4Mode) void {
    const top_offset = mb_x * webp_vp8_intra4_block_width;
    var x: usize = 0;
    while (x < webp_vp8_intra4_block_width) : (x += 1) {
        state.top[top_offset + x] = modes[(webp_vp8_intra4_block_width - 1) * webp_vp8_intra4_block_width + x];
    }
    var y: usize = 0;
    while (y < webp_vp8_intra4_block_width) : (y += 1) {
        state.left[y] = modes[y * webp_vp8_intra4_block_width + webp_vp8_intra4_block_width - 1];
    }
}

fn readVp8Intra4Mode(reader: *Vp8BoolReader, top: Vp8Intra4Mode, left: Vp8Intra4Mode) DecodeError!Vp8Intra4Mode {
    const probabilities = vp8Intra4ModeProbabilities(top, left);
    if (!try reader.readBool(probabilities[0])) return .dc;
    if (!try reader.readBool(probabilities[1])) return .true_motion;
    if (!try reader.readBool(probabilities[2])) return .vertical;
    if (!try reader.readBool(probabilities[3])) {
        if (!try reader.readBool(probabilities[4])) return .horizontal;
        return if (try reader.readBool(probabilities[5])) .vertical_right else .right_down;
    }
    if (!try reader.readBool(probabilities[6])) return .left_down;
    if (!try reader.readBool(probabilities[7])) return .vertical_left;
    return if (try reader.readBool(probabilities[8])) .horizontal_up else .horizontal_down;
}

fn readVp8ChromaMode(reader: *Vp8BoolReader) DecodeError!Vp8ChromaMode {
    if (!try reader.readBool(webp_vp8_chroma_mode_probability_0)) return .dc;
    if (!try reader.readBool(webp_vp8_chroma_mode_probability_1)) return .vertical;
    return if (try reader.readBool(webp_vp8_chroma_mode_probability_2)) .true_motion else .horizontal;
}

fn readVp8InterChromaMode(reader: *Vp8BoolReader, probabilities: *const [webp_vp8_inter_chroma_probability_count]u8) DecodeError!Vp8ChromaMode {
    if (!try reader.readBool(probabilities[0])) return .dc;
    if (!try reader.readBool(probabilities[1])) return .vertical;
    return if (try reader.readBool(probabilities[2])) .true_motion else .horizontal;
}

fn vp8Intra4ModeProbabilities(top: Vp8Intra4Mode, left: Vp8Intra4Mode) *const [webp_vp8_intra4_probability_count]u8 {
    const offset = (@as(usize, @intFromEnum(top)) * webp_vp8_intra4_mode_count + @as(usize, @intFromEnum(left))) * webp_vp8_intra4_probability_count;
    return webp_vp8_intra4_keyframe_probabilities[offset..][0..webp_vp8_intra4_probability_count];
}

const webp_vp8_intra4_keyframe_probabilities = vp8_tables.webp_vp8_intra4_keyframe_probabilities;

const Vp8ResidualSummary = struct {
    non_zero: bool,
    coeffs: Vp8MacroblockCoeffs,
};

const Vp8CoeffBlock = struct {
    next_index: usize,
    non_zero: bool,
};

const Vp8MacroblockCoeffs = struct {
    blocks: [webp_vp8_macroblock_coeff_block_count][webp_vp8_block_coeff_count]i16 =
        [_][webp_vp8_block_coeff_count]i16{[_]i16{0} ** webp_vp8_block_coeff_count} ** webp_vp8_macroblock_coeff_block_count,
};

fn parseVp8ResidualMacroblock(reader: *Vp8BoolReader, probabilities: *const [webp_vp8_coeff_update_probability_count]u8, luma_mode: Vp8LumaMode, coeffs: *Vp8MacroblockCoeffs) DecodeError!Vp8ResidualSummary {
    var non_zero = false;
    const has_y2 = luma_mode != .b_pred;
    if (has_y2) {
        const y2 = try readVp8CoeffBlock(reader, probabilities, 1, 0, 0, &coeffs.blocks[webp_vp8_y2_block_index]);
        non_zero = non_zero or y2.non_zero;
    }
    var y_non_zero = [_]bool{false} ** webp_vp8_y_block_count;
    var block: usize = 0;
    const y_block_type: usize = if (has_y2) 0 else 3;
    const y_start_index: usize = if (has_y2) 1 else 0;
    while (block < webp_vp8_y_block_count) : (block += 1) {
        const context = vp8YBlockCoeffContext(&y_non_zero, block);
        const y = try readVp8CoeffBlock(reader, probabilities, y_block_type, y_start_index, context, &coeffs.blocks[block]);
        y_non_zero[block] = y.non_zero;
        non_zero = non_zero or y.non_zero;
    }
    var u_non_zero = [_]bool{false} ** 4;
    block = 0;
    while (block < 4) : (block += 1) {
        const coeff_block = webp_vp8_y_block_count + block;
        const context = vp8ChromaBlockCoeffContext(&u_non_zero, block);
        const u = try readVp8CoeffBlock(reader, probabilities, 2, 0, context, &coeffs.blocks[coeff_block]);
        u_non_zero[block] = u.non_zero;
        non_zero = non_zero or u.non_zero;
    }
    var v_non_zero = [_]bool{false} ** 4;
    block = 0;
    while (block < 4) : (block += 1) {
        const coeff_block = webp_vp8_y_block_count + 4 + block;
        const context = vp8ChromaBlockCoeffContext(&v_non_zero, block);
        const v = try readVp8CoeffBlock(reader, probabilities, 2, 0, context, &coeffs.blocks[coeff_block]);
        v_non_zero[block] = v.non_zero;
        non_zero = non_zero or v.non_zero;
    }
    return .{ .non_zero = non_zero, .coeffs = coeffs.* };
}

fn vp8YBlockCoeffContext(non_zero: *const [webp_vp8_y_block_count]bool, block: usize) usize {
    const left = (block & 3) != 0 and non_zero[block - 1];
    const top = block >= 4 and non_zero[block - 4];
    return @as(usize, @intFromBool(left)) + @as(usize, @intFromBool(top));
}

fn vp8ChromaBlockCoeffContext(non_zero: *const [4]bool, block: usize) usize {
    const left = (block & 1) != 0 and non_zero[block - 1];
    const top = block >= 2 and non_zero[block - 2];
    return @as(usize, @intFromBool(left)) + @as(usize, @intFromBool(top));
}

fn readVp8CoeffBlock(reader: *Vp8BoolReader, probabilities: *const [webp_vp8_coeff_update_probability_count]u8, block_type: usize, start_index: usize, context: usize, out: *[webp_vp8_block_coeff_count]i16) DecodeError!Vp8CoeffBlock {
    if (block_type >= webp_vp8_coeff_block_types) return error.BadImage;
    if (start_index >= webp_vp8_coeff_band_entries - 1) return error.BadImage;
    if (context >= webp_vp8_coeff_context_count) return error.BadImage;
    @memset(out, 0);
    var index = start_index;
    var coeff_context = context;
    var non_zero = false;
    while (index < webp_vp8_coeff_band_entries - 1) {
        if (!try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, webp_vp8_coeff_bands[index], coeff_context, webp_vp8_coeff_eob_probability_index))) {
            return .{ .next_index = index, .non_zero = non_zero };
        }
        while (!try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, webp_vp8_coeff_bands[index], coeff_context, webp_vp8_coeff_zero_probability_index))) {
            index += 1;
            if (index == webp_vp8_coeff_band_entries - 1) return .{ .next_index = index, .non_zero = non_zero };
        }
        const band = webp_vp8_coeff_bands[index];
        const magnitude = if (!try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, coeff_context, webp_vp8_coeff_one_probability_index)))
            1
        else
            try readVp8LargeCoeffValue(reader, probabilities, block_type, band, coeff_context);
        out[webp_vp8_zigzag[index]] = try readVp8SignedCoeff(reader, magnitude);
        non_zero = true;
        coeff_context = if (magnitude == 1) 1 else 2;
        index += 1;
    }
    return .{ .next_index = index, .non_zero = non_zero };
}

fn readVp8LargeCoeffValue(reader: *Vp8BoolReader, probabilities: *const [webp_vp8_coeff_update_probability_count]u8, block_type: usize, band: usize, context: usize) DecodeError!i16 {
    if (!try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, context, webp_vp8_coeff_large_probability_0))) {
        if (!try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, context, webp_vp8_coeff_large_probability_1))) {
            return webp_vp8_coeff_min_large_value;
        }
        return 3 + @as(i16, @intFromBool(try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, context, webp_vp8_coeff_large_probability_2))));
    }
    if (!try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, context, webp_vp8_coeff_large_probability_3))) {
        if (!try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, context, webp_vp8_coeff_large_probability_4))) {
            return 5 + @as(i16, @intFromBool(try reader.readBool(webp_vp8_coeff_cat_extra_probability_0)));
        }
        var value: i16 = 7 + 2 * @as(i16, @intFromBool(try reader.readBool(webp_vp8_coeff_cat_extra_probability_1)));
        value += @as(i16, @intFromBool(try reader.readBool(webp_vp8_coeff_cat_extra_probability_2)));
        return value;
    }

    const high_bit: usize = @intFromBool(try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, context, webp_vp8_coeff_large_probability_5)));
    const low_bit: usize = @intFromBool(try reader.readBool(vp8CoeffProbabilityFrom(probabilities, block_type, band, context, webp_vp8_coeff_large_probability_6 + high_bit)));
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

const webp_vp8_coeff_bands = vp8_tables.webp_vp8_coeff_bands;
const webp_vp8_zigzag = vp8_tables.webp_vp8_zigzag;
const webp_vp8_dc_quant = vp8_tables.webp_vp8_dc_quant;
const webp_vp8_ac_quant = vp8_tables.webp_vp8_ac_quant;
const webp_vp8_coeff_cat_extra_probability_0 = vp8_tables.webp_vp8_coeff_cat_extra_probability_0;
const webp_vp8_coeff_cat_extra_probability_1 = vp8_tables.webp_vp8_coeff_cat_extra_probability_1;
const webp_vp8_coeff_cat_extra_probability_2 = vp8_tables.webp_vp8_coeff_cat_extra_probability_2;
const webp_vp8_coeff_cat3_probabilities = vp8_tables.webp_vp8_coeff_cat3_probabilities;
const webp_vp8_coeff_cat4_probabilities = vp8_tables.webp_vp8_coeff_cat4_probabilities;
const webp_vp8_coeff_cat5_probabilities = vp8_tables.webp_vp8_coeff_cat5_probabilities;
const webp_vp8_coeff_cat6_probabilities = vp8_tables.webp_vp8_coeff_cat6_probabilities;
const webp_vp8_coeff_default_probabilities = vp8_tables.webp_vp8_coeff_default_probabilities;

fn vp8CoeffProbability(block_type: usize, band: usize, context: usize, probability_index: usize) u8 {
    return vp8CoeffProbabilityFrom(&webp_vp8_coeff_default_probabilities, block_type, band, context, probability_index);
}

fn vp8CoeffProbabilityFrom(probabilities: *const [webp_vp8_coeff_update_probability_count]u8, block_type: usize, band: usize, context: usize, probability_index: usize) u8 {
    std.debug.assert(block_type < webp_vp8_coeff_block_types);
    std.debug.assert(band < webp_vp8_coeff_band_count);
    std.debug.assert(context < webp_vp8_coeff_context_count);
    std.debug.assert(probability_index < webp_vp8_coeff_probability_count);
    return probabilities[((block_type * webp_vp8_coeff_band_count + band) * webp_vp8_coeff_context_count + context) * webp_vp8_coeff_probability_count + probability_index];
}

const webp_vp8_coeff_update_probability_count =
    webp_vp8_coeff_type_count *
    webp_vp8_coeff_band_count *
    webp_vp8_coeff_context_count *
    webp_vp8_coeff_probability_count;

const webp_vp8_coeff_update_probabilities = vp8_tables.webp_vp8_coeff_update_probabilities;

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

fn parseVp8TokenPartitions(data: []const u8, partition_count: usize) DecodeError!Vp8TokenPartitions {
    if (partition_count == 0 or partition_count > webp_vp8_token_partition_count_max) return error.BadImage;
    var partitions = Vp8TokenPartitions{
        .count = partition_count,
        .slices = [_][]const u8{&.{}} ** webp_vp8_token_partition_count_max,
    };
    const size_table_len = (partition_count - 1) * webp_vp8_token_partition_size_bytes;
    if (data.len < size_table_len) return error.BadImage;
    var cursor: usize = size_table_len;
    var partition_index: usize = 0;
    while (partition_index + 1 < partition_count) : (partition_index += 1) {
        const partition_size: usize = readU24Le(data[partition_index * webp_vp8_token_partition_size_bytes ..][0..webp_vp8_token_partition_size_bytes]);
        if (partition_size > data.len - cursor) return error.BadImage;
        partitions.slices[partition_index] = data[cursor..][0..partition_size];
        cursor += partition_size;
    }
    partitions.slices[partition_index] = data[cursor..];
    return partitions;
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

fn isMetadataWebpChunk(chunk_type: []const u8) bool {
    return std.mem.eql(u8, chunk_type, webp_chunk_iccp) or
        std.mem.eql(u8, chunk_type, webp_chunk_exif) or
        std.mem.eql(u8, chunk_type, webp_chunk_xmp);
}

fn isUnsupportedWebpImageChunk(chunk_type: []const u8) bool {
    return std.mem.eql(u8, chunk_type, webp_chunk_anim) or
        std.mem.eql(u8, chunk_type, webp_chunk_anmf);
}

test "webp decoder parses vp8x dimensions through shared header path" {
    const bytes = testWebpVp8x();
    try std.testing.expect(isWebp(bytes));
    const header = try decodeWebpHeader(bytes);
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

test "webp vp8 decoder reconstructs real single macroblock pixels" {
    const bytes = testWebpVp8Gray();
    var pixels: [4]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
    }, &pixels);
}

test "webp raw vp8 keyframe decoder reconstructs pixels" {
    const bytes = testWebpVp8Gray();
    const payload = bytes[riff_header_size + riff_chunk_header_size ..];
    var pixels: [4]ui.Color = undefined;
    const header = try decodeVp8KeyFrame(payload, .{ .width = 2, .height = 2 }, &pixels);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
        .{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque },
    }, &pixels);
}

test "webp vp8 decoder reconstructs segmented multi macroblock pixels" {
    const bytes = testWebpVp8WideGray();
    var pixels: [32 * 16]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 32), header.width);
    try std.testing.expectEqual(@as(usize, 16), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque }, pixels[16]);
    try std.testing.expectEqual(ui.Color{ .r = 126, .g = 126, .b = 126, .a = png_alpha_opaque }, pixels[pixels.len - 1]);
}

test "webp vp8 decoder applies coefficient probability updates for color" {
    const bytes = testWebpVp8Red();
    var pixels: [16 * 16]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 16), header.width);
    try std.testing.expectEqual(@as(usize, 16), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 239, .g = 15, .b = 15, .a = png_alpha_opaque }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 239, .g = 15, .b = 15, .a = png_alpha_opaque }, pixels[8 * 16 + 8]);
    try std.testing.expectEqual(ui.Color{ .r = 239, .g = 15, .b = 15, .a = png_alpha_opaque }, pixels[pixels.len - 1]);
}

test "webp vp8 decoder handles generated color test pattern" {
    const bytes = testWebpVp8Testsrc32();
    var pixels: [32 * 32]ui.Color = undefined;
    const header = try decode(bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 32), header.width);
    try std.testing.expectEqual(@as(usize, 32), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 14, .g = 18, .b = 19, .a = png_alpha_opaque }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 181, .g = 89, .b = 187, .a = png_alpha_opaque }, pixels[32 * 16 + 16]);
    try std.testing.expectEqual(ui.Color{ .r = 106, .g = 112, .b = 172, .a = png_alpha_opaque }, pixels[pixels.len - 1]);
}

test "vp8 prediction state carries macroblock edges" {
    var state = Vp8PredictionState.init(32);
    state.startRow(0);
    var y_plane = [_]u8{0} ** (webp_vp8_macroblock_size * webp_vp8_macroblock_size);
    var u_plane = [_]u8{0} ** (webp_vp8_chroma_block_size * webp_vp8_chroma_block_size);
    var v_plane = [_]u8{0} ** (webp_vp8_chroma_block_size * webp_vp8_chroma_block_size);
    var row: usize = 0;
    while (row < webp_vp8_macroblock_size) : (row += 1) {
        y_plane[row * webp_vp8_macroblock_size + webp_vp8_macroblock_size - 1] = @intCast(40 + row);
    }
    @memset(u_plane[webp_vp8_chroma_block_size - 1 ..], 90);
    @memset(v_plane[webp_vp8_chroma_block_size - 1 ..], 110);
    state.finishMacroblock(0, &y_plane, &u_plane, &v_plane);

    const edges = state.lumaEdges(1);
    try std.testing.expectEqual(false, edges.has_top);
    try std.testing.expectEqual(true, edges.has_left);
    try std.testing.expectEqual(@as(u8, 40), edges.left[0]);
    try std.testing.expectEqual(@as(u8, 55), edges.left[15]);

    var predicted = [_]u8{0} ** (webp_vp8_macroblock_size * webp_vp8_macroblock_size);
    predictVp8Horizontal(webp_vp8_macroblock_size, edges, &predicted);
    try std.testing.expectEqual(@as(u8, 40), predicted[0]);
    try std.testing.expectEqual(@as(u8, 55), predicted[predicted.len - 1]);
}

test "vp8 inter zero macroblock copies previous rgba pixels" {
    const previous_pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3, .a = png_alpha_opaque },
        .{ .r = 4, .g = 5, .b = 6, .a = png_alpha_opaque },
        .{ .r = 7, .g = 8, .b = 9, .a = png_alpha_opaque },
        .{ .r = 10, .g = 11, .b = 12, .a = png_alpha_opaque },
    };
    const previous_bytes = std.mem.sliceAsBytes(&previous_pixels);
    var out: [previous_pixels.len]ui.Color = undefined;
    try copyVp8InterZeroMacroblock(.{ .width = 2, .height = 2 }, 0, 0, previous_bytes, &out);
    try std.testing.expectEqualSlices(ui.Color, &previous_pixels, &out);
}

test "webp decoder rejects missing alph data and animation during pixel decode" {
    const flags_offset = riff_header_size + riff_chunk_header_size + webp_vp8x_flags_index;

    var alpha = testWebpVp8x().*;
    alpha[flags_offset] = webp_vp8x_flag_alpha;
    var pixels: [6]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decodeHeader(&alpha));
    try std.testing.expectError(error.BadImage, decode(&alpha, &pixels));

    var animation = testWebpVp8x().*;
    animation[flags_offset] = webp_vp8x_flag_animation;
    try std.testing.expectError(error.UnsupportedImage, decode(&animation, &pixels));
}

test "webp decoder rejects reserved vp8x feature flags" {
    const flags_offset = riff_header_size + riff_chunk_header_size + webp_vp8x_flags_index;
    var bytes = testWebpVp8x().*;
    bytes[flags_offset] = 1;
    try std.testing.expectError(error.BadImage, decodeHeader(&bytes));
}

test "webp decoder skips explicit vp8x metadata chunks" {
    const base = testWebpVp8x();
    const metadata_len = 4;
    var bytes: [test_webp_vp8x_len + riff_chunk_header_size + metadata_len]u8 = undefined;
    @memcpy(bytes[0..base.len], base);
    const flags_offset = riff_header_size + riff_chunk_header_size + webp_vp8x_flags_index;
    bytes[flags_offset] = webp_vp8x_flag_exif;
    const chunk_offset = base.len;
    @memcpy(bytes[chunk_offset..][0..4], webp_chunk_exif);
    writeU32Le(bytes[chunk_offset + 4 ..][0..4], metadata_len);
    @memcpy(bytes[chunk_offset + riff_chunk_header_size ..][0..metadata_len], "test");
    writeU32Le(bytes[4..][0..4], bytes.len - 8);

    var pixels: [6]ui.Color = undefined;
    const header = try decode(&bytes, &pixels);
    try std.testing.expectEqual(@as(usize, 3), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
}

test "webp decoder applies raw alph chunk to vp8 pixels" {
    const alpha_payload = [_]u8{
        webp_alph_compression_none,
        0,
        64,
        128,
        192,
        255,
        17,
    };
    var bytes: [test_webp_vp8x_len + riff_chunk_header_size + alpha_payload.len + (alpha_payload.len & 1)]u8 = undefined;
    const encoded = writeTestWebpVp8xAlph(&bytes, &alpha_payload);

    var pixels: [6]ui.Color = undefined;
    const header = try decode(encoded, &pixels);
    try std.testing.expectEqual(@as(usize, 3), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = 0 },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = 64 },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = 128 },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = 192 },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = 255 },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = 17 },
    }, &pixels);
}

test "webp decoder applies filtered raw alph chunk to vp8 pixels" {
    const alpha_payload = [_]u8{
        webp_alph_filter_horizontal << webp_alph_filter_shift,
        10,
        10,
        10,
        30,
        10,
        10,
    };
    var bytes: [test_webp_vp8x_len + riff_chunk_header_size + alpha_payload.len + (alpha_payload.len & 1)]u8 = undefined;
    const encoded = writeTestWebpVp8xAlph(&bytes, &alpha_payload);

    var pixels: [6]ui.Color = undefined;
    _ = try decode(encoded, &pixels);
    try std.testing.expectEqual(@as(u8, 10), pixels[0].a);
    try std.testing.expectEqual(@as(u8, 20), pixels[1].a);
    try std.testing.expectEqual(@as(u8, 30), pixels[2].a);
    try std.testing.expectEqual(@as(u8, 40), pixels[3].a);
    try std.testing.expectEqual(@as(u8, 50), pixels[4].a);
    try std.testing.expectEqual(@as(u8, 60), pixels[5].a);
}

test "webp decoder applies compressed alph chunk to vp8 pixels" {
    var alpha_payload: [64]u8 = undefined;
    @memset(&alpha_payload, 0);
    alpha_payload[0] = webp_alph_compression_vp8l;
    var writer = TestVp8lBitWriter.init(alpha_payload[webp_alph_header_size..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(77);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    const alpha_payload_len = webp_alph_header_size + writer.byteLen();

    var bytes: [test_webp_vp8x_len + riff_chunk_header_size + alpha_payload.len]u8 = undefined;
    const encoded = writeTestWebpVp8xAlph(&bytes, alpha_payload[0..alpha_payload_len]);
    const scratch = try std.testing.allocator.alloc(u8, scratchByteLen(encoded, 3, 2));
    defer std.testing.allocator.free(scratch);

    var pixels: [6]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, scratch);
    try std.testing.expectEqual(@as(usize, 3), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    for (pixels) |pixel| {
        try std.testing.expectEqual(ui.Color{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = 77 }, pixel);
    }
}

test "webp animation header parses vp8x anim and frame metadata" {
    var bytes: [test_webp_vp8x_len + riff_chunk_header_size + webp_anim_payload_size + riff_chunk_header_size + webp_anmf_header_size]u8 = undefined;
    const encoded = writeTestWebpAnimation(&bytes, 25, webp_anmf_blend_flag | webp_anmf_dispose_flag);

    const header = try decodeWebpAnimationHeader(encoded);
    try std.testing.expectEqual(@as(usize, 3), header.canvas.width);
    try std.testing.expectEqual(@as(usize, 2), header.canvas.height);
    try std.testing.expectEqual(ui.Color{ .r = 3, .g = 2, .b = 1, .a = 4 }, header.background);
    try std.testing.expectEqual(@as(u16, 7), header.loop_count);
    try std.testing.expectEqual(@as(usize, 1), header.frame_count);

    var pixels: [6]ui.Color = undefined;
    const frame = try decodeWebpAnimationFrame(encoded, 0, &pixels);
    try std.testing.expectEqual(@as(usize, 0), frame.info.x);
    try std.testing.expectEqual(@as(usize, 0), frame.info.y);
    try std.testing.expectEqual(@as(usize, 3), frame.info.width);
    try std.testing.expectEqual(@as(usize, 2), frame.info.height);
    try std.testing.expectEqual(@as(usize, 25), frame.info.duration_ms);
    try std.testing.expectEqual(false, frame.info.blend);
    try std.testing.expectEqual(true, frame.info.dispose_to_background);
}

test "webp animation frame decoder decodes anmf vp8 payload" {
    var bytes: [test_webp_vp8x_len + riff_chunk_header_size + webp_anim_payload_size + riff_chunk_header_size + webp_anmf_header_size]u8 = undefined;
    const encoded = writeTestWebpAnimation(&bytes, 40, 0);

    var pixels: [6]ui.Color = undefined;
    const frame = try decodeWebpAnimationFrame(encoded, 0, &pixels);
    try std.testing.expectEqual(@as(usize, 0), webpAnimationFrameScratchByteLen(encoded, 0));
    try std.testing.expectEqual(@as(usize, 3), frame.header.width);
    try std.testing.expectEqual(@as(usize, 2), frame.header.height);
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
        .{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque },
    }, &pixels);
    try std.testing.expectError(error.BadImage, decodeWebpAnimationFrame(encoded, 1, &pixels));
}

test "webp animation canvas frame blends and disposes decoded rectangles" {
    var second_frame_bytes: [test_webp_vp8l_simple_rgba_len]u8 = undefined;
    const second_frame = writeTestWebpVp8lSimpleRgba(&second_frame_bytes, .{ .r = 255, .g = 0, .b = 0, .a = 128 });
    var bytes: [512]u8 = undefined;
    const encoded = writeTestWebpAnimationTwoFrames(&bytes, second_frame[riff_header_size..], 35, webp_anmf_dispose_flag);

    const scratch = try std.testing.allocator.alloc(u8, webpAnimationCanvasScratchByteLen(encoded, 1));
    defer std.testing.allocator.free(scratch);
    var canvas: [6]ui.Color = undefined;
    const frame = try decodeWebpAnimationCanvasFrameWithScratch(encoded, 1, &canvas, scratch);

    try std.testing.expectEqual(@as(usize, 3), frame.header.width);
    try std.testing.expectEqual(@as(usize, 2), frame.header.height);
    try std.testing.expectEqual(@as(usize, 35), frame.info.duration_ms);
    try std.testing.expectEqual(true, frame.info.blend);
    try std.testing.expectEqual(true, frame.info.dispose_to_background);
    try std.testing.expectEqual(ui.Color{ .r = 191, .g = 63, .b = 63, .a = 255 }, canvas[0]);
    try std.testing.expectEqual(ui.Color{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque }, canvas[1]);

    const first_frame = try decodeWebpAnimationCanvasFrameWithScratch(encoded, 0, &canvas, scratch);
    try std.testing.expectEqual(@as(usize, 20), first_frame.info.duration_ms);
    for (canvas) |pixel| {
        try std.testing.expectEqual(ui.Color{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque }, pixel);
    }
}

test "webp animation canvas decoder steps frames sequentially" {
    var second_frame_bytes: [test_webp_vp8l_simple_rgba_len]u8 = undefined;
    const second_frame = writeTestWebpVp8lSimpleRgba(&second_frame_bytes, .{ .r = 255, .g = 0, .b = 0, .a = 128 });
    var bytes: [512]u8 = undefined;
    const encoded = writeTestWebpAnimationTwoFrames(&bytes, second_frame[riff_header_size..], 35, webp_anmf_dispose_flag);
    const scratch = try std.testing.allocator.alloc(u8, webpAnimationDecoderScratchByteLen(encoded));
    defer std.testing.allocator.free(scratch);

    var decoder = try WebpAnimationCanvasDecoder.init(encoded);
    var canvas: [6]ui.Color = undefined;
    const first = (try decoder.nextFrame(&canvas, scratch)).?;
    try std.testing.expectEqual(@as(usize, 20), first.info.duration_ms);
    try std.testing.expectEqual(ui.Color{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque }, canvas[0]);

    const second = (try decoder.nextFrame(&canvas, scratch)).?;
    try std.testing.expectEqual(@as(usize, 35), second.info.duration_ms);
    try std.testing.expectEqual(ui.Color{ .r = 191, .g = 63, .b = 63, .a = 255 }, canvas[0]);
    try std.testing.expectEqual(@as(?WebpAnimationFrame, null), try decoder.nextFrame(&canvas, scratch));

    decoder.reset();
    const first_again = (try decoder.nextFrame(&canvas, scratch)).?;
    try std.testing.expectEqual(@as(usize, 20), first_again.info.duration_ms);
    for (canvas) |pixel| {
        try std.testing.expectEqual(ui.Color{ .r = vp8_neutral_luma, .g = vp8_neutral_luma, .b = vp8_neutral_luma, .a = png_alpha_opaque }, pixel);
    }
}

test "webp animation header rejects malformed frame payloads" {
    var missing_payload: [test_webp_vp8x_len + riff_chunk_header_size + webp_anim_payload_size + riff_chunk_header_size + webp_anmf_header_size]u8 = undefined;
    const missing = writeTestWebpAnimation(&missing_payload, 40, 0);
    const missing_anmf_payload_offset = riff_header_size +
        riff_chunk_header_size + webp_vp8x_payload_size +
        riff_chunk_header_size + webp_anim_payload_size +
        riff_chunk_header_size;
    writeU32Le(missing_payload[missing_anmf_payload_offset - 4 ..][0..4], webp_anmf_header_size);
    const missing_len = missing.len - riff_chunk_header_size - test_webp_vp8_chunk_len;
    writeU32Le(missing_payload[4..][0..4], missing_len - 8);
    try std.testing.expectError(error.BadImage, decodeWebpAnimationHeader(missing[0..missing_len]));

    var duplicate_payload: [test_webp_vp8x_len + riff_chunk_header_size + webp_anim_payload_size + riff_chunk_header_size + webp_anmf_header_size + riff_chunk_header_size + test_webp_vp8_chunk_len]u8 = undefined;
    const duplicate = writeTestWebpAnimationWithExtraFrameChunk(&duplicate_payload);
    try std.testing.expectError(error.BadImage, decodeWebpAnimationHeader(duplicate));
}

test "webp decoder rejects malformed alpha chunks explicitly" {
    const base = testWebpVp8x();
    const alpha_len = 4;
    var bytes: [test_webp_vp8x_len + riff_chunk_header_size + alpha_len]u8 = undefined;
    @memcpy(bytes[0..base.len], base);
    const chunk_offset = base.len;
    @memcpy(bytes[chunk_offset..][0..4], webp_chunk_alph);
    writeU32Le(bytes[chunk_offset + 4 ..][0..4], alpha_len);
    @memset(bytes[chunk_offset + riff_chunk_header_size ..][0..alpha_len], 0);
    writeU32Le(bytes[4..][0..4], bytes.len - 8);

    try std.testing.expectError(error.BadImage, decodeHeader(&bytes));
}

test "webp vp8 decoder checks output pixel budget" {
    const bytes = testWebpVp8();
    var pixels: [41]ui.Color = undefined;
    try std.testing.expectError(error.PixelBudget, decode(bytes, &pixels));
}

test "webp vp8l decoder reconstructs simple lossless rgba pixels" {
    var bytes: [test_webp_vp8l_simple_rgba_len]u8 = undefined;
    const encoded = writeTestWebpVp8lSimpleRgba(&bytes, .{ .r = 10, .g = 20, .b = 30, .a = 255 });
    var pixels: [1]ui.Color = undefined;
    const header = try decode(encoded, &pixels);
    try std.testing.expectEqual(@as(usize, 1), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 10, .g = 20, .b = 30, .a = 255 }, pixels[0]);
}

test "webp vp8l decoder reconstructs two-symbol simple prefix pixels" {
    var bytes: [test_webp_vp8l_two_color_len]u8 = undefined;
    const first = ui.Color{ .r = 10, .g = 20, .b = 30, .a = 200 };
    const second = ui.Color{ .r = 11, .g = 21, .b = 31, .a = 255 };
    const encoded = writeTestWebpVp8lTwoColor(&bytes, first, second);
    var pixels: [2]ui.Color = undefined;
    const header = try decode(encoded, &pixels);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(first, pixels[0]);
    try std.testing.expectEqual(second, pixels[1]);
}

test "webp vp8l decoder reconstructs color indexed lossless pixels" {
    const encoded = testWebpVp8lIndexed();
    var pixels: [1]ui.Color = undefined;
    const header = try decode(encoded, &pixels);
    try std.testing.expectEqual(@as(usize, 1), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 11, .g = 20, .b = 31, .a = 255 }, pixels[0]);
}

test "webp vp8l decoder reconstructs generated lossless alpha pixels" {
    const encoded = testWebpVp8lAlpha2x2();
    const scratch = try std.testing.allocator.alloc(u8, scratchByteLen(encoded, 2, 2));
    defer std.testing.allocator.free(scratch);
    var pixels: [2 * 2]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = 0, .g = 0, .b = 0, .a = 0 },
        .{ .r = 0, .g = 255, .b = 0, .a = 128 },
        .{ .r = 0, .g = 0, .b = 255, .a = 255 },
        .{ .r = 255, .g = 255, .b = 255, .a = 64 },
    }, &pixels);
}

test "webp vp8l decoder reconstructs generated lossless red image" {
    const encoded = testWebpVp8lRed8x8();
    var scratch: [512]u8 = undefined;
    var pixels: [8 * 8]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 8), header.width);
    try std.testing.expectEqual(@as(usize, 8), header.height);
    for (pixels) |pixel| {
        try std.testing.expectEqual(ui.Color{ .r = 254, .g = 0, .b = 0, .a = png_alpha_opaque }, pixel);
    }
}

test "webp vp8l decoder accepts extended vp8x lossless containers" {
    const encoded = testWebpVp8xVp8lRed8x8();
    var scratch: [512]u8 = undefined;
    var pixels: [8 * 8]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 8), header.width);
    try std.testing.expectEqual(@as(usize, 8), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 254, .g = 0, .b = 0, .a = png_alpha_opaque }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 254, .g = 0, .b = 0, .a = png_alpha_opaque }, pixels[pixels.len - 1]);
}

test "webp vp8l decoder reconstructs generated lossless test pattern" {
    const encoded = testWebpVp8lTestsrc2_8x8();
    const scratch = try std.testing.allocator.alloc(u8, scratchByteLen(encoded, 8, 8));
    defer std.testing.allocator.free(scratch);
    var pixels: [8 * 8]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, scratch);
    try std.testing.expectEqual(@as(usize, 8), header.width);
    try std.testing.expectEqual(@as(usize, 8), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 254, .g = 0, .b = 0, .a = png_alpha_opaque }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 255, .g = 0, .b = 254, .a = png_alpha_opaque }, pixels[7]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 8, .b = 41, .a = png_alpha_opaque }, pixels[4 * 8 + 4]);
    try std.testing.expectEqual(ui.Color{ .r = 113, .g = 1, .b = 0, .a = png_alpha_opaque }, pixels[pixels.len - 1]);
}

test "webp vp8l scratch sizing rejects mismatched dimensions" {
    const encoded = testWebpVp8lRed8x8();
    try std.testing.expectError(error.BadImage, webpScratchByteLenChecked(encoded, 7, 8));
}

test "webp vp8l decoder applies subtract green transform" {
    var bytes: [test_webp_vp8l_subtract_green_len]u8 = undefined;
    const color = ui.Color{ .r = 10, .g = 20, .b = 30, .a = 255 };
    const encoded = writeTestWebpVp8lSubtractGreen(&bytes, color);
    var pixels: [1]ui.Color = undefined;
    const header = try decode(encoded, &pixels);
    try std.testing.expectEqual(@as(usize, 1), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(color, pixels[0]);
}

test "webp vp8l decoder applies predictor transform" {
    var bytes: [test_webp_vp8l_predictor_len]u8 = undefined;
    const first = ui.Color{ .r = 10, .g = 5, .b = 10, .a = 255 };
    const second = ui.Color{ .r = 25, .g = 15, .b = 25, .a = 255 };
    const encoded = writeTestWebpVp8lPredictorPair(&bytes, first, second);
    var scratch: [1]u8 = undefined;
    var pixels: [2]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(first, pixels[0]);
    try std.testing.expectEqual(second, pixels[1]);
}

test "webp vp8l decoder applies transforms after color indexing on coded dimensions" {
    var bytes: [test_webp_vp8l_color_index_predictor_len]u8 = undefined;
    const first = ui.Color{ .r = 10, .g = 20, .b = 30, .a = 0 };
    const second = ui.Color{ .r = 40, .g = 50, .b = 60, .a = 0 };
    const encoded = writeTestWebpVp8lColorIndexThenPredictor(&bytes, first, second);
    var scratch: [256]u8 = undefined;
    var pixels: [8]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 8), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(first, pixels[0]);
    try std.testing.expectEqual(second, pixels[1]);
    try std.testing.expectEqual(first, pixels[2]);
    try std.testing.expectEqual(second, pixels[7]);
}

test "webp vp8l decoder applies color transform" {
    var bytes: [test_webp_vp8l_color_transform_len]u8 = undefined;
    const color = ui.Color{ .r = 100, .g = 64, .b = 20, .a = 255 };
    const encoded = writeTestWebpVp8lColorTransform(&bytes, color);
    var scratch: [webp_vp8l_color_transform_bytes_per_element]u8 = undefined;
    var pixels: [1]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 1), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(color, pixels[0]);
}

test "webp vp8l decoder accepts single-group meta prefix images" {
    var bytes: [test_webp_vp8l_meta_prefix_len]u8 = undefined;
    const color = ui.Color{ .r = 10, .g = 20, .b = 30, .a = 255 };
    const encoded = writeTestWebpVp8lMetaPrefix(&bytes, color);
    var scratch: [webp_vp8l_meta_prefix_bytes_per_entry]u8 = undefined;
    var pixels: [1]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 1), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(color, pixels[0]);
}

test "webp vp8l decoder selects multiple meta prefix groups" {
    var bytes: [test_webp_vp8l_meta_prefix_multi_len]u8 = undefined;
    const first = ui.Color{ .r = 10, .g = 20, .b = 30, .a = 255 };
    const second = ui.Color{ .r = 40, .g = 50, .b = 60, .a = 255 };
    const encoded = writeTestWebpVp8lMetaPrefixMulti(&bytes, first, second);
    var scratch: [webp_vp8l_meta_prefix_bytes_per_entry * 2]u8 = undefined;
    var pixels: [5]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 5), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(first, pixels[0]);
    try std.testing.expectEqual(first, pixels[3]);
    try std.testing.expectEqual(second, pixels[4]);
}

test "webp vp8l decoder stores meta prefix groups beyond inline stack" {
    var bytes: [test_webp_vp8l_meta_prefix_three_group_len]u8 = undefined;
    const first = ui.Color{ .r = 10, .g = 20, .b = 30, .a = 255 };
    const second = ui.Color{ .r = 40, .g = 50, .b = 60, .a = 255 };
    const third = ui.Color{ .r = 70, .g = 80, .b = 90, .a = 255 };
    const encoded = writeTestWebpVp8lMetaPrefixThreeGroups(&bytes, first, second, third);
    var scratch: [1024]u8 = undefined;
    var pixels: [9]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 9), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(first, pixels[0]);
    try std.testing.expectEqual(first, pixels[3]);
    try std.testing.expectEqual(third, pixels[4]);
    try std.testing.expectEqual(third, pixels[8]);
}

test "webp vp8l decoder requires scratch for meta prefix images" {
    var bytes: [test_webp_vp8l_meta_prefix_len]u8 = undefined;
    const encoded = writeTestWebpVp8lMetaPrefix(&bytes, .{ .r = 10, .g = 20, .b = 30, .a = 255 });
    var pixels: [1]ui.Color = undefined;
    try std.testing.expectError(error.PixelBudget, decode(encoded, &pixels));
}

test "webp vp8l decoder requires scratch for predictor mode tables" {
    var bytes: [test_webp_vp8l_predictor_len]u8 = undefined;
    const encoded = writeTestWebpVp8lPredictorPair(&bytes, .{ .r = 10, .g = 5, .b = 10, .a = 255 }, .{ .r = 25, .g = 15, .b = 25, .a = 255 });
    var pixels: [2]ui.Color = undefined;
    try std.testing.expectError(error.PixelBudget, decode(encoded, &pixels));
}

test "vp8l predictor modes produce deterministic neighbors" {
    var modes = [_]u8{webp_vp8l_predictor_mode_black};
    const transform = Vp8lPredictorTransform{ .modes = &modes, .size_bits = webp_vp8l_transform_size_bits_base, .width = 1 };
    const row0 = [_]ui.Color{
        .{ .r = 10, .g = 20, .b = 30, .a = 40 },
        .{ .r = 20, .g = 30, .b = 40, .a = 50 },
        .{ .r = 30, .g = 40, .b = 50, .a = 60 },
    };
    const row1 = [_]ui.Color{
        .{ .r = 15, .g = 25, .b = 35, .a = 45 },
        .{ .r = 1, .g = 2, .b = 3, .a = 4 },
        .{ .r = 0, .g = 0, .b = 0, .a = 0 },
    };
    var pixels = row0 ++ row1;

    modes[0] = webp_vp8l_predictor_mode_top_right;
    try std.testing.expectEqual(row0[2], vp8lPredictor(transform, .{ .width = 3, .height = 2 }, &pixels, 1, 1));

    modes[0] = webp_vp8l_predictor_mode_avg_left_top;
    try std.testing.expectEqual(averageVp8lColors(row1[0], row0[1]), vp8lPredictor(transform, .{ .width = 3, .height = 2 }, &pixels, 1, 1));

    modes[0] = webp_vp8l_predictor_mode_select;
    try std.testing.expectEqual(selectVp8lPredictor(row1[0], row0[1], row0[0]), vp8lPredictor(transform, .{ .width = 3, .height = 2 }, &pixels, 1, 1));

    modes[0] = webp_vp8l_predictor_mode_clamp_full;
    try std.testing.expectEqual(clampAddSubtractFullVp8lColor(row1[0], row0[1], row0[0]), vp8lPredictor(transform, .{ .width = 3, .height = 2 }, &pixels, 1, 1));
}

test "webp vp8l decoder accepts normal huffman prefix codes" {
    var bytes: [test_webp_vp8l_normal_code_len]u8 = undefined;
    const encoded = writeTestWebpVp8lNormalTransparentBlack(&bytes);
    var pixels: [1]ui.Color = undefined;
    const header = try decode(encoded, &pixels);
    try std.testing.expectEqual(@as(usize, 1), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 0, .b = 0, .a = 0 }, pixels[0]);
}

test "webp vp8l decoder copies lz77 backward references" {
    var bytes: [test_webp_vp8l_lz77_len]u8 = undefined;
    const color = ui.Color{ .r = 10, .g = 5, .b = 30, .a = 255 };
    const encoded = writeTestWebpVp8lLz77Pair(&bytes, color);
    var scratch: [4096]u8 = undefined;
    var pixels: [2]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(color, pixels[0]);
    try std.testing.expectEqual(color, pixels[1]);
}

test "webp vp8l decoder recalls colors from the color cache" {
    var bytes: [test_webp_vp8l_color_cache_len]u8 = undefined;
    const color = ui.Color{ .r = 10, .g = 5, .b = 30, .a = 255 };
    const encoded = writeTestWebpVp8lColorCachePair(&bytes, color);
    var scratch: [4096]u8 = undefined;
    var pixels: [2]ui.Color = undefined;
    const header = try decodeWithScratch(encoded, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(color, pixels[0]);
    try std.testing.expectEqual(color, pixels[1]);
}

test "webp vp8l decoder rejects lz77 copies before the output cursor" {
    var bytes: [test_webp_vp8l_lz77_len]u8 = undefined;
    const encoded = writeTestWebpVp8lLz77BadDistance(&bytes, .{ .r = 10, .g = 5, .b = 30, .a = 255 });
    var scratch: [4096]u8 = undefined;
    var pixels: [2]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decodeWithScratch(encoded, &pixels, &scratch));
}

test "webp vp8l decoder rejects truncated lossless pixel stream" {
    const bytes = testWebpVp8l();
    var pixels: [20]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decode(bytes, &pixels));
}

test "webp vp8 decoder rejects malformed first partition sizes" {
    const payload_offset = riff_header_size + riff_chunk_header_size;
    var empty_partition = testWebpVp8().*;
    try raw_vp8.writeVisibleKeyFrameTag(empty_partition[payload_offset..][0..raw_vp8.frame_tag_size], 0);
    var pixels: [1]ui.Color = undefined;
    try std.testing.expectError(error.BadImage, decode(&empty_partition, &pixels));

    var short_bool_partition = testWebpVp8().*;
    try raw_vp8.writeVisibleKeyFrameTag(short_bool_partition[payload_offset..][0..raw_vp8.frame_tag_size], 1);
    try std.testing.expectError(error.BadImage, decode(&short_bool_partition, &pixels));

    var oversized_partition = testWebpVp8().*;
    try raw_vp8.writeVisibleKeyFrameTag(oversized_partition[payload_offset..][0..raw_vp8.frame_tag_size], test_webp_vp8_first_partition_len + test_webp_vp8_token_partition_len + 1);
    try std.testing.expectError(error.BadImage, decode(&oversized_partition, &pixels));
}

test "vp8 token partition parser exposes explicit partition slices" {
    const bytes = [_]u8{
        0x02, 0x00, 0x00,
        0xaa, 0xbb, 0xcc,
        0xdd, 0xee,
    };
    const partitions = try parseVp8TokenPartitions(&bytes, 2);
    try std.testing.expectEqual(@as(usize, 2), partitions.count);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xaa, 0xbb }, partitions.slices[0]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xcc, 0xdd, 0xee }, partitions.slices[1]);
}

test "vp8 token partition parser rejects truncated size tables and payloads" {
    try std.testing.expectError(error.BadImage, parseVp8TokenPartitions(&[_]u8{ 0x00, 0x00 }, 2));

    const oversized = [_]u8{
        0x04, 0x00, 0x00,
        0xaa, 0xbb,
    };
    try std.testing.expectError(error.BadImage, parseVp8TokenPartitions(&oversized, 2));
    try std.testing.expectError(error.BadImage, parseVp8TokenPartitions(&[_]u8{}, 0));
}

test "vp8 bool reader decodes zero frame header prefix deterministically" {
    const header = try parseVp8CompressedFrameHeader(.key, .{ .width = 6, .height = 7 }, &[_]u8{0x00} ** test_webp_vp8_first_partition_len);
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

test "vp8 intra4 keyframe probabilities expose full submode tree" {
    try std.testing.expectEqual(@as(usize, webp_vp8_intra4_mode_count * webp_vp8_intra4_mode_count * webp_vp8_intra4_probability_count), webp_vp8_intra4_keyframe_probabilities.len);

    try std.testing.expectEqualSlices(u8, &[_]u8{ 231, 120, 48, 89, 115, 113, 120, 152, 112 }, vp8Intra4ModeProbabilities(.dc, .dc));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 112, 19, 12, 61, 195, 128, 48, 4, 24 }, vp8Intra4ModeProbabilities(.horizontal_up, .horizontal_up));

    var reader = try Vp8BoolReader.init(&[_]u8{0x00} ** 8);
    try std.testing.expectEqual(Vp8Intra4Mode.dc, try readVp8Intra4Mode(&reader, .dc, .dc));
}

test "vp8 coefficient token reader accepts eob and category paths" {
    var eob_reader = try Vp8BoolReader.init(&[_]u8{0x00} ** 8);
    var coeffs: [webp_vp8_block_coeff_count]i16 = undefined;
    const eob = try readVp8CoeffBlock(&eob_reader, &webp_vp8_coeff_default_probabilities, 0, 1, 0, &coeffs);
    try std.testing.expectEqual(@as(usize, 1), eob.next_index);
    try std.testing.expectEqual(false, eob.non_zero);
    try std.testing.expectEqualSlices(i16, &([_]i16{0} ** webp_vp8_block_coeff_count), &coeffs);

    var large_reader = try Vp8BoolReader.init(&[_]u8{0x00} ** 8);
    try std.testing.expectEqual(@as(i16, 2), try readVp8LargeCoeffValue(&large_reader, &webp_vp8_coeff_default_probabilities, 0, 1, 0));
    try std.testing.expectEqual(@as(i16, 2), try readVp8SignedCoeff(&large_reader, 2));
}

test "vp8 residual parser omits y2 block for b_pred macroblocks" {
    var intra16_reader = try Vp8BoolReader.init(&[_]u8{0x00} ** 8);
    var intra16_coeffs = Vp8MacroblockCoeffs{};
    _ = try parseVp8ResidualMacroblock(&intra16_reader, &webp_vp8_coeff_default_probabilities, .dc, &intra16_coeffs);

    var b_pred_reader = try Vp8BoolReader.init(&[_]u8{0x00} ** 8);
    var b_pred_coeffs = Vp8MacroblockCoeffs{};
    _ = try parseVp8ResidualMacroblock(&b_pred_reader, &webp_vp8_coeff_default_probabilities, .b_pred, &b_pred_coeffs);

    try std.testing.expect(intra16_reader.bit_count < b_pred_reader.bit_count);
    try std.testing.expectEqualSlices(i16, &([_]i16{0} ** webp_vp8_block_coeff_count), &b_pred_coeffs.blocks[webp_vp8_y2_block_index]);
}

test "vp8 b_pred y blocks dequantize their own dc coefficient" {
    const quant = Vp8Dequant{
        .y_dc = 4,
        .y_ac = 5,
        .y2_dc = 6,
        .y2_ac = 7,
        .uv_dc = 8,
        .uv_ac = 9,
    };
    var block = [_]i16{0} ** webp_vp8_block_coeff_count;
    block[0] = 3;
    block[1] = -2;
    const out = dequantizeVp8YBlockWithOwnDc(&block, quant);
    try std.testing.expectEqual(@as(i32, 12), out[0]);
    try std.testing.expectEqual(@as(i32, -10), out[1]);
}

test "vp8 b_pred reconstruction feeds earlier 4x4 blocks into later predictors" {
    const quant = Vp8Dequant{
        .y_dc = 4,
        .y_ac = 5,
        .y2_dc = 6,
        .y2_ac = 7,
        .uv_dc = 8,
        .uv_ac = 9,
    };
    const edges = Vp8Edges(webp_vp8_macroblock_size){
        .top = [_]u8{100} ** webp_vp8_macroblock_size,
        .top_right = [_]u8{100} ** webp_vp8_intra4_block_width,
        .left = [_]u8{20} ** webp_vp8_macroblock_size,
        .top_left = 80,
        .has_top = true,
        .has_left = true,
    };
    var coeffs = Vp8MacroblockCoeffs{};
    coeffs.blocks[0][0] = 16;
    var plane = [_]u8{0} ** (webp_vp8_macroblock_size * webp_vp8_macroblock_size);
    reconstructVp8BPredLuma(quant, edges, [_]Vp8Intra4Mode{.dc} ** webp_vp8_y_block_count, &coeffs, &plane);

    try std.testing.expectEqual(@as(u8, 68), plane[0]);
    try std.testing.expectEqual(@as(u8, 84), plane[4]);
    try std.testing.expectEqual(@as(u8, 44), plane[4 * webp_vp8_macroblock_size]);
}

test "vp8 intra4 predictors cover non dc subblock modes" {
    const edges = Vp8Edges(webp_vp8_macroblock_size){
        .top = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80 } ++ [_]u8{90} ** 8,
        .top_right = [_]u8{ 100, 110, 120, 130 },
        .left = [_]u8{ 11, 21, 31, 41 } ++ [_]u8{51} ** 12,
        .top_left = 7,
        .has_top = true,
        .has_left = true,
    };

    var vertical_left = [_]u8{0} ** (webp_vp8_macroblock_size * webp_vp8_macroblock_size);
    predictVp8Intra4Block(.vertical_left, edges, &vertical_left, 0);
    try std.testing.expectEqual(@as(u8, 15), vertical_left[0]);
    try std.testing.expectEqual(@as(u8, 40), vertical_left[webp_vp8_macroblock_size + 1]);
    try std.testing.expectEqual(@as(u8, 78), vertical_left[3 * webp_vp8_macroblock_size + 3]);

    var horizontal_up = [_]u8{0} ** (webp_vp8_macroblock_size * webp_vp8_macroblock_size);
    predictVp8Intra4Block(.horizontal_up, edges, &horizontal_up, 0);
    try std.testing.expectEqual(@as(u8, 16), horizontal_up[0]);
    try std.testing.expectEqual(@as(u8, 39), horizontal_up[webp_vp8_macroblock_size + 3]);
    try std.testing.expectEqual(@as(u8, 41), horizontal_up[3 * webp_vp8_macroblock_size + 3]);
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

fn writeTestWebpVp8xAlph(bytes: []u8, alpha_payload: []const u8) []const u8 {
    const base = testWebpVp8x();
    const insert_offset = riff_header_size + riff_chunk_header_size + webp_vp8x_payload_size;
    const padded_alpha_len = alpha_payload.len + (alpha_payload.len & 1);
    const total_len = base.len + riff_chunk_header_size + padded_alpha_len;
    if (bytes.len < total_len) @panic("test WebP ALPH output buffer too small");

    @memset(bytes[0..total_len], 0);
    @memcpy(bytes[0..insert_offset], base[0..insert_offset]);
    bytes[riff_header_size + riff_chunk_header_size + webp_vp8x_flags_index] |= webp_vp8x_flag_alpha;
    @memcpy(bytes[insert_offset..][0..4], webp_chunk_alph);
    writeU32Le(bytes[insert_offset + 4 ..][0..4], alpha_payload.len);
    @memcpy(bytes[insert_offset + riff_chunk_header_size ..][0..alpha_payload.len], alpha_payload);

    const vp8_offset = insert_offset + riff_chunk_header_size + padded_alpha_len;
    @memcpy(bytes[vp8_offset..][0 .. base.len - insert_offset], base[insert_offset..]);
    writeU32Le(bytes[4..][0..4], total_len - 8);
    return bytes[0..total_len];
}

fn writeTestWebpAnimation(bytes: []u8, duration_ms: usize, flags: u8) []const u8 {
    const base = testWebpVp8x();
    const vp8_chunk_offset = riff_header_size + riff_chunk_header_size + webp_vp8x_payload_size;
    const anmf_payload_len = webp_anmf_header_size + (base.len - vp8_chunk_offset);
    const total_len = vp8_chunk_offset +
        riff_chunk_header_size + webp_anim_payload_size +
        riff_chunk_header_size + anmf_payload_len;
    if (bytes.len < total_len) @panic("test WebP animation output buffer too small");

    @memset(bytes[0..total_len], 0);
    @memcpy(bytes[0..vp8_chunk_offset], base[0..vp8_chunk_offset]);
    bytes[riff_header_size + riff_chunk_header_size + webp_vp8x_flags_index] = webp_vp8x_flag_animation;

    var cursor = vp8_chunk_offset;
    @memcpy(bytes[cursor..][0..4], webp_chunk_anim);
    writeU32Le(bytes[cursor + 4 ..][0..4], webp_anim_payload_size);
    bytes[cursor + riff_chunk_header_size + webp_anim_background_blue_index] = 1;
    bytes[cursor + riff_chunk_header_size + webp_anim_background_green_index] = 2;
    bytes[cursor + riff_chunk_header_size + webp_anim_background_red_index] = 3;
    bytes[cursor + riff_chunk_header_size + webp_anim_background_alpha_index] = 4;
    writeU16(bytes[cursor + riff_chunk_header_size + webp_anim_loop_count_index ..][0..2], 7);
    cursor += riff_chunk_header_size + webp_anim_payload_size;

    @memcpy(bytes[cursor..][0..4], webp_chunk_anmf);
    writeU32Le(bytes[cursor + 4 ..][0..4], anmf_payload_len);
    const anmf_offset = cursor + riff_chunk_header_size;
    writeU24Le(bytes[anmf_offset + webp_anmf_x_index ..][0..3], 0);
    writeU24Le(bytes[anmf_offset + webp_anmf_y_index ..][0..3], 0);
    writeU24Le(bytes[anmf_offset + webp_anmf_width_index ..][0..3], 2);
    writeU24Le(bytes[anmf_offset + webp_anmf_height_index ..][0..3], 1);
    writeU24Le(bytes[anmf_offset + webp_anmf_duration_index ..][0..3], duration_ms);
    bytes[anmf_offset + webp_anmf_flags_index] = flags;
    @memcpy(bytes[anmf_offset + webp_anmf_header_size ..][0 .. base.len - vp8_chunk_offset], base[vp8_chunk_offset..]);

    writeU32Le(bytes[4..][0..4], total_len - 8);
    return bytes[0..total_len];
}

fn writeTestWebpAnimationWithExtraFrameChunk(bytes: []u8) []const u8 {
    const encoded = writeTestWebpAnimation(bytes, 40, 0);
    const base = testWebpVp8x();
    const vp8_chunk_offset = riff_header_size + riff_chunk_header_size + webp_vp8x_payload_size;
    const extra_len = base.len - vp8_chunk_offset;
    const total_len = encoded.len + extra_len;
    if (bytes.len < total_len) @panic("test WebP animation output buffer too small");

    @memcpy(bytes[encoded.len..][0..extra_len], base[vp8_chunk_offset..]);
    const anmf_len_offset = vp8_chunk_offset + riff_chunk_header_size + webp_anim_payload_size + 4;
    const previous_anmf_payload_len = readU32Le(bytes[anmf_len_offset..][0..4]);
    writeU32Le(bytes[anmf_len_offset..][0..4], previous_anmf_payload_len + extra_len);
    writeU32Le(bytes[4..][0..4], total_len - 8);
    return bytes[0..total_len];
}

fn writeTestWebpAnimationTwoFrames(bytes: []u8, second_frame_chunk: []const u8, second_duration_ms: usize, second_flags: u8) []const u8 {
    const base = testWebpVp8x();
    const vp8_chunk_offset = riff_header_size + riff_chunk_header_size + webp_vp8x_payload_size;
    const first_frame_chunk = base[vp8_chunk_offset..];
    const first_anmf_payload_len = webp_anmf_header_size + first_frame_chunk.len;
    const second_anmf_payload_len = webp_anmf_header_size + second_frame_chunk.len;
    const total_len = vp8_chunk_offset +
        riff_chunk_header_size + webp_anim_payload_size +
        riff_chunk_header_size + first_anmf_payload_len +
        riff_chunk_header_size + second_anmf_payload_len;
    if (bytes.len < total_len) @panic("test WebP animation output buffer too small");

    @memset(bytes[0..total_len], 0);
    @memcpy(bytes[0..vp8_chunk_offset], base[0..vp8_chunk_offset]);
    bytes[riff_header_size + riff_chunk_header_size + webp_vp8x_flags_index] = webp_vp8x_flag_animation | webp_vp8x_flag_alpha;

    var cursor = vp8_chunk_offset;
    @memcpy(bytes[cursor..][0..4], webp_chunk_anim);
    writeU32Le(bytes[cursor + 4 ..][0..4], webp_anim_payload_size);
    bytes[cursor + riff_chunk_header_size + webp_anim_background_blue_index] = 1;
    bytes[cursor + riff_chunk_header_size + webp_anim_background_green_index] = 2;
    bytes[cursor + riff_chunk_header_size + webp_anim_background_red_index] = 3;
    bytes[cursor + riff_chunk_header_size + webp_anim_background_alpha_index] = 4;
    writeU16(bytes[cursor + riff_chunk_header_size + webp_anim_loop_count_index ..][0..2], 7);
    cursor += riff_chunk_header_size + webp_anim_payload_size;

    cursor = writeTestWebpAnmf(bytes, cursor, first_frame_chunk, 3, 2, 20, 0);
    cursor = writeTestWebpAnmf(bytes, cursor, second_frame_chunk, 1, 1, second_duration_ms, second_flags);
    writeU32Le(bytes[4..][0..4], total_len - 8);
    return bytes[0..cursor];
}

fn writeTestWebpAnmf(bytes: []u8, cursor: usize, frame_chunk: []const u8, width: usize, height: usize, duration_ms: usize, flags: u8) usize {
    const anmf_payload_len = webp_anmf_header_size + frame_chunk.len;
    @memcpy(bytes[cursor..][0..4], webp_chunk_anmf);
    writeU32Le(bytes[cursor + 4 ..][0..4], anmf_payload_len);
    const anmf_offset = cursor + riff_chunk_header_size;
    writeU24Le(bytes[anmf_offset + webp_anmf_x_index ..][0..3], 0);
    writeU24Le(bytes[anmf_offset + webp_anmf_y_index ..][0..3], 0);
    writeU24Le(bytes[anmf_offset + webp_anmf_width_index ..][0..3], width - 1);
    writeU24Le(bytes[anmf_offset + webp_anmf_height_index ..][0..3], height - 1);
    writeU24Le(bytes[anmf_offset + webp_anmf_duration_index ..][0..3], duration_ms);
    bytes[anmf_offset + webp_anmf_flags_index] = flags;
    @memcpy(bytes[anmf_offset + webp_anmf_header_size ..][0..frame_chunk.len], frame_chunk);
    return cursor + riff_chunk_header_size + anmf_payload_len;
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

fn testWebpVp8lIndexed() *const [test_webp_vp8l_indexed_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x1e, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  'L',
        0x11, 0x00, 0x00, 0x00, 0x2f, 0x00, 0x00, 0x00,
        0x00, 0x07, 0x50, 0x8a, 0x2e, 0xf4, 0xa3, 0xff,
        0x81, 0x88, 0xe8, 0x7f, 0x00, 0x00,
    };
}

fn testWebpVp8lAlpha2x2() *const [test_webp_vp8l_alpha_2x2_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x34, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  'L',
        0x27, 0x00, 0x00, 0x00, 0x2f, 0x01, 0x40, 0x00,
        0x10, 0x1f, 0x30, 0xff, 0x02, 0x82, 0x22, 0xff,
        0x47, 0x13, 0x10, 0x14, 0xf9, 0x3f, 0x9a, 0x40,
        0x80, 0x90, 0xc6, 0x7f, 0x94, 0x00, 0xfc, 0xa5,
        0x84, 0x92, 0x00, 0x01, 0x50, 0x94, 0x91, 0x88,
        0xfe, 0xc7, 0x00, 0x00,
    };
}

fn testWebpVp8lRed8x8() *const [test_webp_vp8l_red_8x8_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x1c, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  'L',
        0x0f, 0x00, 0x00, 0x00, 0x2f, 0x07, 0xc0, 0x01,
        0x00, 0x07, 0x10, 0xf5, 0x8f, 0xfe, 0x07, 0x22,
        0xa2, 0xff, 0x01, 0x00,
    };
}

fn testWebpVp8xVp8lRed8x8() *const [test_webp_vp8x_vp8l_red_8x8_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x2e, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  'X',
        0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x07, 0x00, 0x00, 0x07, 0x00, 0x00, 'V',  'P',
        '8',  'L',  0x0f, 0x00, 0x00, 0x00, 0x2f, 0x07,
        0xc0, 0x01, 0x00, 0x07, 0x10, 0xf5, 0x8f, 0xfe,
        0x07, 0x22, 0xa2, 0xff, 0x01, 0x00,
    };
}

fn testWebpVp8lTestsrc2_8x8() *const [test_webp_vp8l_testsrc2_8x8_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0xdc, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  'L',
        0xd0, 0x00, 0x00, 0x00, 0x2f, 0x07, 0xc0, 0x01,
        0x00, 0x5f, 0xc1, 0x26, 0xb6, 0xad, 0x46, 0x97,
        0xd8, 0x25, 0x13, 0xd8, 0xc0, 0x0e, 0x8a, 0x69,
        0xe9, 0x10, 0xc0, 0xe6, 0xbc, 0x36, 0x98, 0xd8,
        0xb6, 0xad, 0xe4, 0xfd, 0xe6, 0xfe, 0x21, 0xfe,
        0x86, 0x4e, 0x1f, 0x32, 0x99, 0xa9, 0x90, 0xdc,
        0x95, 0x71, 0x00, 0x00, 0x46, 0x4e, 0x19, 0x2f,
        0xbe, 0xb8, 0x46, 0x13, 0xb7, 0x45, 0x5b, 0xd4,
        0xdf, 0xb6, 0x39, 0xff, 0xc1, 0x07, 0x82, 0x3e,
        0x46, 0x52, 0x78, 0x58, 0x72, 0x57, 0x08, 0xe0,
        0x09, 0x30, 0xec, 0xfc, 0x02, 0x6e, 0x98, 0xf2,
        0x77, 0x8b, 0x0d, 0xb3, 0x4b, 0xaf, 0xb4, 0x27,
        0x32, 0xe1, 0x0e, 0xd4, 0xac, 0xa6, 0x3f, 0x53,
        0xcc, 0x93, 0xc1, 0x37, 0x22, 0x4d, 0x26, 0xa1,
        0xbf, 0xc2, 0x20, 0x15, 0xde, 0x48, 0x12, 0x9e,
        0xd8, 0x01, 0xa2, 0x17, 0xf0, 0x11, 0xbc, 0x34,
        0x7e, 0xc2, 0xef, 0x8b, 0xda, 0x3e, 0xcc, 0x75,
        0xd1, 0x6f, 0xcf, 0x2e, 0x32, 0x73, 0x01, 0x3d,
        0xf9, 0x49, 0x1d, 0x73, 0x21, 0x00, 0x64, 0x4a,
        0x73, 0xba, 0x7d, 0xe6, 0xd6, 0x0d, 0xfd, 0x1e,
        0xc0, 0x30, 0x92, 0x64, 0x53, 0xf7, 0xcc, 0x6f,
        0xdb, 0xce, 0x3f, 0x41, 0xc6, 0x10, 0xd1, 0xff,
        0x80, 0x29, 0xf4, 0xd7, 0x74, 0x46, 0x30, 0x46,
        0xc1, 0x96, 0x0d, 0x0b, 0xf4, 0x45, 0xcb, 0x3d,
        0xc7, 0x85, 0x2e, 0x6f, 0x98, 0xb0, 0xe6, 0xb7,
        0xa6, 0x52, 0xe9, 0xbb, 0x22, 0xc9, 0x71, 0xde,
        0x25, 0xde, 0xaf, 0x18,
    };
}

fn writeTestWebpVp8lSimpleRgba(bytes: *[test_webp_vp8l_simple_rgba_len]u8, pixel: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 1, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(pixel.g);
    writer.writeSimplePrefixCode(pixel.r);
    writer.writeSimplePrefixCode(pixel.b);
    writer.writeSimplePrefixCode(pixel.a);
    writer.writeSimplePrefixCode(0);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lTwoColor(bytes: *[test_webp_vp8l_two_color_len]u8, first: ui.Color, second: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 2, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCodePair(first.g, second.g);
    writer.writeSimplePrefixCodePair(first.r, second.r);
    writer.writeSimplePrefixCodePair(first.b, second.b);
    writer.writeSimplePrefixCodePair(first.a, second.a);
    writer.writeSimplePrefixCodePair(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(1, 1);
    writer.writeBits(1, 1);
    writer.writeBits(1, 1);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lSubtractGreen(bytes: *[test_webp_vp8l_subtract_green_len]u8, pixel: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 1, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(1, 1);
    writer.writeBits(webp_vp8l_transform_subtract_green, webp_vp8l_transform_type_bits);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(pixel.g);
    writer.writeSimplePrefixCode(pixel.r -% pixel.g);
    writer.writeSimplePrefixCode(pixel.b -% pixel.g);
    writer.writeSimplePrefixCode(pixel.a);
    writer.writeSimplePrefixCode(0);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lPredictorPair(bytes: *[test_webp_vp8l_predictor_len]u8, first: ui.Color, second: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 2, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;
    const first_residual = subtractVp8lColors(first, vp8lPredictorBlack());
    const second_residual = subtractVp8lColors(second, first);

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(1, 1);
    writer.writeBits(webp_vp8l_transform_predictor, webp_vp8l_transform_type_bits);
    writer.writeBits(0, webp_vp8l_transform_size_bits_len);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(webp_vp8l_predictor_mode_left);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(png_alpha_opaque);
    writer.writeSimplePrefixCode(0);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCodePair(first_residual.g, second_residual.g);
    writer.writeSimplePrefixCodePair(first_residual.r, second_residual.r);
    writer.writeSimplePrefixCodePair(first_residual.b, second_residual.b);
    writer.writeSimplePrefixCode(first_residual.a);
    writer.writeSimplePrefixCode(0);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(1, 1);
    writer.writeBits(1, 1);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lColorIndexThenPredictor(bytes: *[test_webp_vp8l_color_index_predictor_len]u8, first: ui.Color, second: ui.Color) []const u8 {
    const packed_indices: u8 = 0xaa;
    const second_delta = subtractVp8lColors(second, first);

    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 8, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(1, 1);
    writer.writeBits(webp_vp8l_transform_color_indexing, webp_vp8l_transform_type_bits);
    writer.writeBits(1, webp_vp8l_color_table_size_bits);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCodePair(first.g, second_delta.g);
    writer.writeSimplePrefixCodePair(first.r, second_delta.r);
    writer.writeSimplePrefixCode(first.b);
    writer.writeSimplePrefixCode(first.a);
    writer.writeSimplePrefixCodePair(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(1, 1);

    writer.writeBits(1, 1);
    writer.writeBits(webp_vp8l_transform_predictor, webp_vp8l_transform_type_bits);
    writer.writeBits(0, webp_vp8l_transform_size_bits_len);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(webp_vp8l_predictor_mode_black);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(png_alpha_opaque);
    writer.writeSimplePrefixCode(0);

    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(packed_indices);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lColorTransform(bytes: *[test_webp_vp8l_color_transform_len]u8, pixel: ui.Color) []const u8 {
    const green_to_red: u8 = 32;
    const green_to_blue: u8 = 0;
    const red_to_blue: u8 = 0;
    const residual = forwardVp8lColorTransform(pixel, green_to_red, green_to_blue, red_to_blue);

    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 1, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(1, 1);
    writer.writeBits(webp_vp8l_transform_color, webp_vp8l_transform_type_bits);
    writer.writeBits(0, webp_vp8l_transform_size_bits_len);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(green_to_blue);
    writer.writeSimplePrefixCode(red_to_blue);
    writer.writeSimplePrefixCode(green_to_red);
    writer.writeSimplePrefixCode(png_alpha_opaque);
    writer.writeSimplePrefixCode(0);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(residual.g);
    writer.writeSimplePrefixCode(residual.r);
    writer.writeSimplePrefixCode(residual.b);
    writer.writeSimplePrefixCode(residual.a);
    writer.writeSimplePrefixCode(0);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lMetaPrefix(bytes: *[test_webp_vp8l_meta_prefix_len]u8, pixel: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 1, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(0, webp_vp8l_meta_prefix_bits_len);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(png_alpha_opaque);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(pixel.g);
    writer.writeSimplePrefixCode(pixel.r);
    writer.writeSimplePrefixCode(pixel.b);
    writer.writeSimplePrefixCode(pixel.a);
    writer.writeSimplePrefixCode(0);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lMetaPrefixMulti(bytes: *[test_webp_vp8l_meta_prefix_multi_len]u8, first: ui.Color, second: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 5, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(0, webp_vp8l_meta_prefix_bits_len);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCodePair(0, 1);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(png_alpha_opaque);
    writer.writeSimplePrefixCode(0);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);

    writer.writeSimplePrefixCode(first.g);
    writer.writeSimplePrefixCode(first.r);
    writer.writeSimplePrefixCode(first.b);
    writer.writeSimplePrefixCode(first.a);
    writer.writeSimplePrefixCode(0);

    writer.writeSimplePrefixCode(second.g);
    writer.writeSimplePrefixCode(second.r);
    writer.writeSimplePrefixCode(second.b);
    writer.writeSimplePrefixCode(second.a);
    writer.writeSimplePrefixCode(0);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lMetaPrefixThreeGroups(bytes: *[test_webp_vp8l_meta_prefix_three_group_len]u8, first: ui.Color, second: ui.Color, third: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 9, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(0, webp_vp8l_meta_prefix_bits_len);
    writer.writeBits(0, 1);
    writer.writeSimplePrefixCodePair(0, 2);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(0);
    writer.writeSimplePrefixCode(png_alpha_opaque);
    writer.writeSimplePrefixCode(0);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(1, 1);

    writer.writeSimplePrefixCode(first.g);
    writer.writeSimplePrefixCode(first.r);
    writer.writeSimplePrefixCode(first.b);
    writer.writeSimplePrefixCode(first.a);
    writer.writeSimplePrefixCode(0);

    writer.writeSimplePrefixCode(second.g);
    writer.writeSimplePrefixCode(second.r);
    writer.writeSimplePrefixCode(second.b);
    writer.writeSimplePrefixCode(second.a);
    writer.writeSimplePrefixCode(0);

    writer.writeSimplePrefixCode(third.g);
    writer.writeSimplePrefixCode(third.r);
    writer.writeSimplePrefixCode(third.b);
    writer.writeSimplePrefixCode(third.a);
    writer.writeSimplePrefixCode(0);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lNormalTransparentBlack(bytes: *[test_webp_vp8l_normal_code_len]u8) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 1, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeNormalSingleZeroPrefixCode();
    writer.writeNormalSingleZeroPrefixCode();
    writer.writeNormalSingleZeroPrefixCode();
    writer.writeNormalSingleZeroPrefixCode();
    writer.writeNormalSingleZeroPrefixCode();

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lLz77Pair(bytes: *[test_webp_vp8l_lz77_len]u8, color: ui.Color) []const u8 {
    return writeTestWebpVp8lLz77(bytes, color, false);
}

fn writeTestWebpVp8lLz77BadDistance(bytes: *[test_webp_vp8l_lz77_len]u8, color: ui.Color) []const u8 {
    return writeTestWebpVp8lLz77(bytes, color, true);
}

fn writeTestWebpVp8lColorCachePair(bytes: *[test_webp_vp8l_color_cache_len]u8, color: ui.Color) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 2, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;
    const cache_bits = webp_vp8l_color_cache_min_bits;
    const cache_index = vp8lColorCacheHash(color, cache_bits);
    const cache_symbol = webp_vp8l_color_cache_symbol_base + cache_index;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);
    writer.writeBits(cache_bits, webp_vp8l_color_cache_bits_len);
    writer.writeBits(0, 1);
    writer.writeNormalTwoSymbolPrefixCode(color.g, cache_symbol, webp_vp8l_green_symbol_count_without_cache + (@as(usize, 1) << @intCast(cache_bits)));
    writer.writeSimplePrefixCode(color.r);
    writer.writeSimplePrefixCode(color.b);
    writer.writeSimplePrefixCode(color.a);
    writer.writeSimplePrefixCode(0);
    writer.writeBits(0, 1);
    writer.writeBits(1, 1);

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn writeTestWebpVp8lLz77(bytes: *[test_webp_vp8l_lz77_len]u8, color: ui.Color, copy_first: bool) []const u8 {
    @memset(bytes, 0);
    writeTestWebpVp8lHeader(bytes[0..], 2, 1);
    const payload_offset = riff_header_size + riff_chunk_header_size;

    var writer = TestVp8lBitWriter.init(bytes[payload_offset + webp_vp8l_header_size ..]);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeBits(0, 1);
    writer.writeNormalTwoSymbolPrefixCode(color.g, webp_vp8l_length_symbol_base, webp_vp8l_green_symbol_count_without_cache);
    writer.writeSimplePrefixCode(color.r);
    writer.writeSimplePrefixCode(color.b);
    writer.writeSimplePrefixCode(color.a);
    writer.writeSimplePrefixCode(1);
    if (copy_first) {
        writer.writeBits(1, 1);
    } else {
        writer.writeBits(0, 1);
        writer.writeBits(1, 1);
    }

    return finishTestWebpVp8l(bytes[0..], writer.byteLen());
}

fn vp8lColorCacheHash(pixel: ui.Color, bits: usize) usize {
    const argb = (@as(u32, pixel.a) << 24) |
        (@as(u32, pixel.r) << 16) |
        (@as(u32, pixel.g) << 8) |
        @as(u32, pixel.b);
    return @intCast((argb *% webp_vp8l_color_cache_hash_multiplier) >> @intCast(webp_vp8l_color_cache_hash_width - bits));
}

fn normalMaxSymbolSelector(max_symbol: usize) usize {
    var selector: usize = 0;
    while (selector < (1 << webp_vp8l_normal_length_nbits_selector_bits)) : (selector += 1) {
        const length_nbits = webp_vp8l_normal_length_nbits_base + webp_vp8l_normal_length_nbits_scale * selector;
        if (max_symbol - webp_vp8l_normal_max_symbol_base < (@as(usize, 1) << @intCast(length_nbits))) return selector;
    }
    unreachable;
}

fn writeTestWebpVp8lHeader(bytes: []u8, width: usize, height: usize) void {
    @memcpy(bytes[0..4], riff_signature);
    @memcpy(bytes[8..12], webp_signature);
    @memcpy(bytes[12..16], webp_chunk_vp8l);
    const payload_offset = riff_header_size + riff_chunk_header_size;
    bytes[payload_offset] = webp_vp8l_signature;
    const bits = @as(u32, @intCast(width - 1)) |
        (@as(u32, @intCast(height - 1)) << webp_vp8l_height_shift);
    writeU32Le(bytes[payload_offset + 1 ..][0..4], bits);
}

fn finishTestWebpVp8l(bytes: []u8, payload_body_len: usize) []const u8 {
    const chunk_len = webp_vp8l_header_size + payload_body_len;
    writeU32Le(bytes[16..20], chunk_len);
    const padded_chunk_len = chunk_len + (chunk_len & 1);
    const riff_len = 4 + riff_chunk_header_size + padded_chunk_len;
    writeU32Le(bytes[4..8], riff_len);
    return bytes[0 .. riff_len + 8];
}

const TestVp8lBitWriter = struct {
    data: []u8,
    bit_index: usize,

    fn init(data: []u8) TestVp8lBitWriter {
        return .{ .data = data, .bit_index = 0 };
    }

    fn writeSimplePrefixCode(self: *TestVp8lBitWriter, symbol: u8) void {
        self.writeBits(1, 1);
        self.writeBits(0, 1);
        self.writeBits(1, 1);
        self.writeBits(symbol, webp_vp8l_simple_code_symbol_bits);
    }

    fn writeSimplePrefixCodePair(self: *TestVp8lBitWriter, low: u8, high: u8) void {
        self.writeBits(1, 1);
        self.writeBits(1, 1);
        self.writeBits(1, 1);
        self.writeBits(low, webp_vp8l_simple_code_symbol_bits);
        self.writeBits(high, webp_vp8l_simple_code_symbol_bits);
    }

    fn writeNormalSingleZeroPrefixCode(self: *TestVp8lBitWriter) void {
        self.writeBits(0, 1);
        self.writeBits(0, webp_vp8l_normal_code_length_count_bits);
        self.writeBits(0, webp_vp8l_code_length_code_bits);
        self.writeBits(0, webp_vp8l_code_length_code_bits);
        self.writeBits(1, webp_vp8l_code_length_code_bits);
        self.writeBits(1, webp_vp8l_code_length_code_bits);
        self.writeBits(1, webp_vp8l_normal_max_symbol_flag_bits);
        self.writeBits(0, webp_vp8l_normal_length_nbits_selector_bits);
        self.writeBits(0, webp_vp8l_normal_length_nbits_base);
        self.writeBits(1, 1);
        self.writeBits(0, 1);
    }

    fn writeNormalTwoSymbolPrefixCode(self: *TestVp8lBitWriter, low: usize, high: usize, max_symbol: usize) void {
        const selector = normalMaxSymbolSelector(max_symbol);
        const length_nbits = webp_vp8l_normal_length_nbits_base + webp_vp8l_normal_length_nbits_scale * selector;
        self.writeBits(0, 1);
        self.writeBits(0, webp_vp8l_normal_code_length_count_bits);
        self.writeBits(0, webp_vp8l_code_length_code_bits);
        self.writeBits(1, webp_vp8l_code_length_code_bits);
        self.writeBits(2, webp_vp8l_code_length_code_bits);
        self.writeBits(2, webp_vp8l_code_length_code_bits);
        self.writeBits(1, webp_vp8l_normal_max_symbol_flag_bits);
        self.writeBits(@intCast(selector), webp_vp8l_normal_length_nbits_selector_bits);
        self.writeBits(@intCast(max_symbol - webp_vp8l_normal_max_symbol_base), length_nbits);
        self.writeCodeLengthZeros(low);
        self.writeCodeLengthSymbolOne();
        self.writeCodeLengthZeros(high - low - 1);
        self.writeCodeLengthSymbolOne();
        self.writeCodeLengthZeros(max_symbol - high - 1);
    }

    fn writeCodeLengthZeros(self: *TestVp8lBitWriter, count: usize) void {
        var remaining = count;
        while (remaining > 0) {
            if (remaining >= webp_vp8l_code_length_repeat_zero_long_base) {
                const repeat = @min(remaining, webp_vp8l_code_length_repeat_zero_long_base + ((@as(usize, 1) << webp_vp8l_code_length_repeat_zero_long_bits) - 1));
                self.writeBits(0, 1);
                self.writeBits(@intCast(repeat - webp_vp8l_code_length_repeat_zero_long_base), webp_vp8l_code_length_repeat_zero_long_bits);
                remaining -= repeat;
            } else {
                self.writeBits(1, 2);
                remaining -= 1;
            }
        }
    }

    fn writeCodeLengthSymbolOne(self: *TestVp8lBitWriter) void {
        self.writeBits(3, 2);
    }

    fn writeBits(self: *TestVp8lBitWriter, value: u32, count: usize) void {
        var bit: usize = 0;
        while (bit < count) : (bit += 1) {
            if (((value >> @intCast(bit)) & 1) != 0) {
                const absolute_bit = self.bit_index + bit;
                self.data[absolute_bit >> 3] |= @as(u8, 1) << @intCast(absolute_bit & 7);
            }
        }
        self.bit_index += count;
    }

    fn byteLen(self: *const TestVp8lBitWriter) usize {
        return (self.bit_index + 7) / 8;
    }
};

fn testWebpVp8() *const [test_webp_vp8_len]u8 {
    return &([_]u8{
        'R',  'I',  'F',  'F',  0xf6, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  ' ',
        0xea, 0x00, 0x00, 0x00, 0x10, 0x14, 0x00, 0x9d,
        0x01, 0x2a, 0x06, 0x00, 0x07, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    } ++ [_]u8{0x00} ** test_webp_vp8_fixture_tail_len);
}

fn testWebpVp8Gray() *const [test_webp_vp8_gray_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x24, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  ' ',
        0x18, 0x00, 0x00, 0x00, 0x50, 0x01, 0x00, 0x9d,
        0x01, 0x2a, 0x02, 0x00, 0x02, 0x00, 0x01, 0x40,
        0x26, 0x25, 0xa4, 0x00, 0x04, 0x74, 0x00, 0x00,
        0xe4, 0x40, 0x00, 0x00,
    };
}

fn testWebpVp8WideGray() *const [test_webp_vp8_wide_gray_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x2e, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  ' ',
        0x22, 0x00, 0x00, 0x00, 0xb0, 0x02, 0x00, 0x9d,
        0x01, 0x2a, 0x20, 0x00, 0x10, 0x00, 0x3e, 0x6d,
        0x2c, 0x93, 0x45, 0xa4, 0x22, 0xa1, 0x98, 0x04,
        0x00, 0x40, 0x06, 0xc4, 0xb4, 0x80, 0x00, 0x4a,
        0xc4, 0x00, 0x00, 0xe4, 0x40, 0x00,
    };
}

fn testWebpVp8Red() *const [test_webp_vp8_red_len]u8 {
    return &[_]u8{
        'R',  'I',  'F',  'F',  0x3c, 0x00, 0x00, 0x00,
        'W',  'E',  'B',  'P',  'V',  'P',  '8',  ' ',
        0x30, 0x00, 0x00, 0x00, 0xd0, 0x01, 0x00, 0x9d,
        0x01, 0x2a, 0x10, 0x00, 0x10, 0x00, 0x01, 0x40,
        0x26, 0x25, 0xa0, 0x02, 0x74, 0xba, 0x01, 0xf8,
        0x00, 0x03, 0xb0, 0x00, 0xfe, 0xf2, 0xeb, 0x7f,
        0xfc, 0xd8, 0x15, 0xcd, 0x73, 0xef, 0xf7, 0xff,
        0xd2, 0xe0, 0xfd, 0x2e, 0x0f, 0xd2, 0xe0, 0xff,
        0xd2, 0x90, 0x00, 0x00,
    };
}

fn testWebpVp8Testsrc32() *const [test_webp_vp8_testsrc32_len]u8 {
    return &[_]u8{
        0x52, 0x49, 0x46, 0x46, 0x06, 0x02, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
        0x56, 0x50, 0x38, 0x20, 0xfa, 0x01, 0x00, 0x00, 0xb0, 0x0c, 0x00, 0x9d,
        0x01, 0x2a, 0x20, 0x00, 0x20, 0x00, 0x3e, 0x91, 0x3c, 0x9a, 0x48, 0x25,
        0xa3, 0xa2, 0xa1, 0x28, 0x0d, 0x50, 0xb0, 0x12, 0x09, 0x6c, 0x00, 0x9d,
        0x33, 0x5a, 0x39, 0x9f, 0x80, 0x7e, 0x33, 0x7e, 0xc0, 0x71, 0x81, 0x77,
        0x03, 0x24, 0x0f, 0x90, 0x2f, 0xa8, 0xfe, 0x4e, 0xff, 0x60, 0xde, 0x00,
        0xfe, 0x8d, 0xf9, 0x01, 0xc0, 0x03, 0xf4, 0xef, 0xd7, 0x8f, 0xa4, 0x03,
        0xcc, 0x03, 0xfa, 0x07, 0xb0, 0x07, 0xea, 0x4f, 0x4d, 0x17, 0xb0, 0xe7,
        0xec, 0x6f, 0xec, 0xcf, 0xb3, 0xd5, 0xda, 0x57, 0xd0, 0x18, 0xa8, 0x13,
        0x79, 0x7c, 0x7d, 0x66, 0x72, 0x5f, 0x9b, 0xa4, 0xec, 0xe1, 0xa0, 0x0e,
        0x64, 0x7f, 0x77, 0xea, 0xf7, 0xa5, 0x77, 0x7a, 0x38, 0x00, 0x00, 0xfe,
        0xfe, 0xa0, 0x9f, 0x00, 0x5d, 0xcf, 0xf3, 0x82, 0x36, 0x81, 0x83, 0xe0,
        0x8a, 0x97, 0xac, 0x2f, 0xf6, 0x30, 0x49, 0xf6, 0x66, 0xdf, 0x1a, 0x0b,
        0xa7, 0xba, 0xf7, 0xfe, 0xa7, 0x58, 0xfc, 0xf1, 0x35, 0xd4, 0xd2, 0x3c,
        0x46, 0xe7, 0xca, 0x41, 0xc5, 0x6f, 0x95, 0xb8, 0x79, 0x0a, 0x2a, 0xb3,
        0xf0, 0xd1, 0xc2, 0xd1, 0x39, 0x86, 0x61, 0x26, 0x4a, 0xa4, 0x58, 0x4b,
        0xaa, 0x4d, 0x24, 0xa5, 0xcf, 0x2d, 0xc0, 0x1e, 0x47, 0x0a, 0x54, 0x07,
        0xdf, 0x9b, 0xcb, 0x55, 0x77, 0xfc, 0xff, 0x11, 0xaf, 0xff, 0xa4, 0x49,
        0xec, 0x1e, 0x5a, 0x23, 0xce, 0x1b, 0xcf, 0x51, 0x65, 0x9a, 0xa7, 0xa9,
        0x60, 0x73, 0x77, 0xd2, 0x70, 0x81, 0xf6, 0xca, 0xe9, 0x2f, 0xfc, 0xd7,
        0x05, 0x07, 0x58, 0x29, 0x95, 0x06, 0xdd, 0x05, 0xad, 0x4a, 0x66, 0xc2,
        0xd5, 0xbf, 0xc5, 0x12, 0x05, 0x88, 0x73, 0x65, 0x7c, 0x69, 0x20, 0x89,
        0xdf, 0x29, 0xe7, 0x0f, 0x80, 0xf3, 0xfa, 0xac, 0xd9, 0xb4, 0x05, 0xbc,
        0x95, 0x94, 0x1d, 0xb1, 0x86, 0x1a, 0x8d, 0xa7, 0xbf, 0x09, 0x5b, 0x3f,
        0x0c, 0x96, 0xc1, 0x24, 0x2e, 0x86, 0xed, 0xd0, 0xfd, 0x2b, 0x19, 0x88,
        0x49, 0x8e, 0xdd, 0x1c, 0x56, 0xe0, 0x6d, 0x89, 0xe5, 0xa2, 0x3f, 0x65,
        0x7f, 0xd5, 0xcc, 0x7c, 0x89, 0x2b, 0xe3, 0x67, 0x6e, 0x45, 0xe3, 0xa6,
        0xbe, 0x6f, 0x09, 0xba, 0x31, 0x7f, 0xed, 0x3a, 0x6f, 0x9e, 0x5b, 0x9f,
        0xa4, 0x57, 0xc7, 0xfe, 0x3f, 0xc9, 0xdf, 0xe0, 0x42, 0xff, 0xe7, 0x53,
        0x49, 0x00, 0x9e, 0xeb, 0x59, 0x54, 0x8f, 0xb9, 0xc9, 0xff, 0x8b, 0x84,
        0xdc, 0x41, 0x8b, 0x8f, 0xba, 0xdb, 0x07, 0x6f, 0xc3, 0x8b, 0xba, 0xb9,
        0xcb, 0x3a, 0x9b, 0x3b, 0x6e, 0x8c, 0x04, 0x9e, 0x4e, 0xe2, 0xfe, 0x59,
        0x3e, 0xbd, 0x6f, 0xa2, 0xc4, 0x2c, 0x25, 0x0c, 0x7f, 0xfe, 0x0e, 0xc6,
        0x68, 0x50, 0x69, 0x46, 0x0d, 0x27, 0xaf, 0x43, 0x78, 0x5b, 0x4a, 0xb9,
        0xba, 0x44, 0x0a, 0x5f, 0x65, 0xf8, 0xb1, 0x78, 0x34, 0x98, 0xf9, 0x90,
        0x78, 0xc8, 0xc8, 0xf3, 0x08, 0xe7, 0x69, 0x43, 0x4e, 0x0b, 0xd0, 0xc0,
        0x59, 0x72, 0x8a, 0xa2, 0x29, 0xbd, 0x0d, 0x0b, 0xff, 0x6f, 0x7c, 0x7f,
        0xef, 0xbf, 0x9a, 0x85, 0x90, 0xdd, 0x72, 0x31, 0x20, 0x55, 0x4c, 0xfa,
        0x94, 0xab, 0x80, 0xfc, 0xfd, 0xed, 0x1d, 0xf6, 0x4b, 0xc8, 0xaa, 0xcb,
        0x7e, 0x8d, 0xff, 0x9a, 0x15, 0xde, 0x03, 0xe6, 0xa8, 0x01, 0xc9, 0xef,
        0x50, 0x6e, 0xbd, 0x53, 0x4e, 0x82, 0x4f, 0xe6, 0x33, 0x2f, 0x49, 0x54,
        0xa6, 0x59, 0xd2, 0x24, 0x06, 0x7f, 0xfc, 0xaa, 0x81, 0x6c, 0xa2, 0x5f,
        0xff, 0xcc, 0x0a, 0x2d, 0xdf, 0x14, 0x20, 0x3d, 0xfe, 0x76, 0xfb, 0x1c,
        0xf3, 0x23, 0x77, 0xcc, 0xda, 0x4e, 0x44, 0x40, 0x00, 0x00,
    };
}
