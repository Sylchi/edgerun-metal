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
        .webp => decodeWebpWithScratch(bytes, out, scratch),
    };
}

pub fn scratchByteLen(bytes: []const u8, width: usize, height: usize) usize {
    return scratchByteLenChecked(bytes, width, height) catch @panic("image scratch byte length overflow");
}

pub fn pngScratchByteLen(encoded_len: usize, width: usize, height: usize) usize {
    return pngScratchByteLenChecked(encoded_len, width, height) catch @panic("png scratch byte length overflow");
}

pub fn webpScratchByteLen(bytes: []const u8, width: usize, height: usize) usize {
    return webpScratchByteLenChecked(bytes, width, height) catch @panic("webp scratch byte length overflow");
}

fn scratchByteLenChecked(bytes: []const u8, width: usize, height: usize) DecodeError!usize {
    return switch (try detectFormat(bytes)) {
        .jpeg, .tga => 0,
        .png => pngScratchByteLenChecked(bytes.len, width, height),
        .webp => webpScratchByteLenChecked(bytes, width, height),
    };
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

fn checkedAdd(a: usize, b: usize) DecodeError!usize {
    return std.math.add(usize, a, b) catch error.PixelBudget;
}

fn checkedMul(a: usize, b: usize) DecodeError!usize {
    return std.math.mul(usize, a, b) catch error.PixelBudget;
}

pub fn decodeWebpHeader(bytes: []const u8) DecodeError!Header {
    return (try parseWebp(bytes)).header;
}

fn webpScratchByteLenChecked(bytes: []const u8, width: usize, height: usize) DecodeError!usize {
    const info = try parseWebp(bytes);
    if (info.header.width != width or info.header.height != height) return error.BadImage;
    if ((info.feature_flags & webp_vp8x_decode_blocking_flags) != 0) return error.UnsupportedImage;
    if (info.alpha_data) |alpha_data| return webpAlphaScratchByteLen(alpha_data, info.header);
    if (std.mem.eql(u8, info.chunk_type, webp_chunk_vp8)) return 0;
    if (!std.mem.eql(u8, info.chunk_type, webp_chunk_vp8l)) return 0;

    const pixel_count = try pixelCount(info.header);
    const transform_data = try vp8lTransformScratchByteLen(pixel_count);
    const entropy_decode = try vp8lEntropyScratchByteLen(bytes.len);
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

fn decodeVp8FrameWithAlpha(data: []const u8, alpha_data: ?[]const u8, expected_header: Header, out: []ui.Color, scratch: []u8) DecodeError!Header {
    const header = try decodeVp8Frame(data, expected_header, out);
    if (alpha_data) |data_alpha| {
        const count = try pixelCount(header);
        try applyWebpAlpha(data_alpha, header, out[0..count], scratch);
    }
    return header;
}

fn decodeVp8Frame(data: []const u8, expected_header: Header, out: []ui.Color) DecodeError!Header {
    const frame = try parseVp8Frame(data);
    if (frame.header.width != expected_header.width or frame.header.height != expected_header.height) return error.UnsupportedImage;
    const count = try pixelCount(frame.header);
    if (out.len < count) return error.PixelBudget;
    try reconstructVp8Frame(&frame, out[0..count]);
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
    const riff_len: usize = readU32Le(bytes[4..][0..4]);
    if (riff_len < 4) return error.BadImage;
    if (riff_len > std.math.maxInt(usize) - 8) return error.PixelBudget;
    if (riff_len + 8 != bytes.len) return error.BadImage;

    var cursor: usize = riff_header_size;
    var header: ?Header = null;
    var primary_chunk: ?*const [4]u8 = null;
    var primary_data: []const u8 = &.{};
    var vp8_data: ?[]const u8 = null;
    var alpha_data: ?[]const u8 = null;
    var feature_flags: u8 = 0;
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
            const vp8x = try parseWebpVp8x(data);
            header = vp8x.header;
            feature_flags = vp8x.flags;
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
        } else if (std.mem.eql(u8, chunk_type, webp_chunk_alph)) {
            if (alpha_data != null or saw_primary or header == null) return error.BadImage;
            alpha_data = data;
        } else if (isMetadataWebpChunk(chunk_type)) {
            continue;
        } else if (isUnsupportedWebpImageChunk(chunk_type)) {
            return error.UnsupportedImage;
        } else if (isCriticalWebpChunk(chunk_type)) {
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
    const token_partition_slices = try parseVp8TokenPartitions(token_partitions, frame_header.token_partition_count);
    return .{
        .header = header,
        .first_partition = first_partition,
        .token_partitions = token_partitions,
        .token_partition_count = frame_header.token_partition_count,
        .token_partition_slices = token_partition_slices,
        .macroblocks = macroblocks,
        .compressed_header = frame_header,
    };
}

fn reconstructVp8Frame(frame: *const Vp8Frame, out: []ui.Color) DecodeError!void {
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
            const macroblock_header = try parseVp8KeyframeMacroblockHeader(&frame.compressed_header, &header_reader, &intra4_mode_state, mb_x);
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
    var coeff_probabilities = webp_vp8_coeff_default_probabilities;
    const token_probability_update_count = try parseVp8TokenProbabilityUpdates(&reader, &coeff_probabilities);
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
        .coeff_probabilities = coeff_probabilities,
        .use_skip_probability = use_skip_probability,
        .skip_probability = skip_probability,
        .segment_quant_deltas = segmentation.quant_deltas,
        .segment_quant_absolute = segmentation.quant_absolute,
    };
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

fn parseVp8KeyframeMacroblockHeaders(frame_header: *const Vp8CompressedFrameHeader) DecodeError!Vp8MacroblockSummary {
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
            const header = try parseVp8KeyframeMacroblockHeader(frame_header, &reader, &intra4_mode_state, mb_x);
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
    luma_mode: Vp8LumaMode,
    intra4_modes: [webp_vp8_y_block_count]Vp8Intra4Mode,
    chroma_mode: Vp8ChromaMode,
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

fn parseVp8KeyframeMacroblockHeader(frame_header: *const Vp8CompressedFrameHeader, reader: *Vp8BoolReader, intra4_mode_state: *Vp8Intra4ModeState, mb_x: usize) DecodeError!Vp8MacroblockHeader {
    const segment_id = if (frame_header.segment_update_map) try readVp8SegmentId(frame_header, reader) else 0;
    const skip = if (frame_header.use_skip_probability) try reader.readBool(frame_header.skip_probability) else false;
    const luma_mode: Vp8LumaMode = if (try reader.readBool(webp_vp8_intra16_block_size_probability)) vp8LumaModeFromIntra16(try readVp8Intra16Mode(reader)) else .b_pred;
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
        .luma_mode = luma_mode,
        .intra4_modes = intra4_modes,
        .chroma_mode = try readVp8ChromaMode(reader),
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

fn readVp8Intra16Mode(reader: *Vp8BoolReader) DecodeError!Vp8Intra16Mode {
    if (try reader.readBool(webp_vp8_intra16_mode_probability_0)) {
        return if (try reader.readBool(webp_vp8_intra16_mode_probability_1)) .true_motion else .horizontal;
    }
    return if (try reader.readBool(webp_vp8_intra16_mode_probability_2)) .vertical else .dc;
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

fn vp8Intra4ModeProbabilities(top: Vp8Intra4Mode, left: Vp8Intra4Mode) *const [webp_vp8_intra4_probability_count]u8 {
    const offset = (@as(usize, @intFromEnum(top)) * webp_vp8_intra4_mode_count + @as(usize, @intFromEnum(left))) * webp_vp8_intra4_probability_count;
    return webp_vp8_intra4_keyframe_probabilities[offset..][0..webp_vp8_intra4_probability_count];
}

const webp_vp8_intra4_keyframe_probabilities = [_]u8{
    231, 120, 48,  89,  115, 113, 120, 152, 112, 152, 179, 64,  126, 170, 118, 46,  70,  95,
    175, 69,  143, 80,  85,  82,  72,  155, 103, 56,  58,  10,  171, 218, 189, 17,  13,  152,
    144, 71,  10,  38,  171, 213, 144, 34,  26,  114, 26,  17,  163, 44,  195, 21,  10,  173,
    121, 24,  80,  195, 26,  62,  44,  64,  85,  170, 46,  55,  19,  136, 160, 33,  206, 71,
    63,  20,  8,   114, 114, 208, 12,  9,   226, 81,  40,  11,  96,  182, 84,  29,  16,  36,
    134, 183, 89,  137, 98,  101, 106, 165, 148, 72,  187, 100, 130, 157, 111, 32,  75,  80,
    66,  102, 167, 99,  74,  62,  40,  234, 128, 41,  53,  9,   178, 241, 141, 26,  8,   107,
    104, 79,  12,  27,  217, 255, 87,  17,  7,   74,  43,  26,  146, 73,  166, 49,  23,  157,
    65,  38,  105, 160, 51,  52,  31,  115, 128, 87,  68,  71,  44,  114, 51,  15,  186, 23,
    47,  41,  14,  110, 182, 183, 21,  17,  194, 66,  45,  25,  102, 197, 189, 23,  18,  22,
    88,  88,  147, 150, 42,  46,  45,  196, 205, 43,  97,  183, 117, 85,  38,  35,  179, 61,
    39,  53,  200, 87,  26,  21,  43,  232, 171, 56,  34,  51,  104, 114, 102, 29,  93,  77,
    107, 54,  32,  26,  51,  1,   81,  43,  31,  39,  28,  85,  171, 58,  165, 90,  98,  64,
    34,  22,  116, 206, 23,  34,  43,  166, 73,  68,  25,  106, 22,  64,  171, 36,  225, 114,
    34,  19,  21,  102, 132, 188, 16,  76,  124, 62,  18,  78,  95,  85,  57,  50,  48,  51,
    193, 101, 35,  159, 215, 111, 89,  46,  111, 60,  148, 31,  172, 219, 228, 21,  18,  111,
    112, 113, 77,  85,  179, 255, 38,  120, 114, 40,  42,  1,   196, 245, 209, 10,  25,  109,
    100, 80,  8,   43,  154, 1,   51,  26,  71,  88,  43,  29,  140, 166, 213, 37,  43,  154,
    61,  63,  30,  155, 67,  45,  68,  1,   209, 142, 78,  78,  16,  255, 128, 34,  197, 171,
    41,  40,  5,   102, 211, 183, 4,   1,   221, 51,  50,  17,  168, 209, 192, 23,  25,  82,
    125, 98,  42,  88,  104, 85,  117, 175, 82,  95,  84,  53,  89,  128, 100, 113, 101, 45,
    75,  79,  123, 47,  51,  128, 81,  171, 1,   57,  17,  5,   71,  102, 57,  53,  41,  49,
    115, 21,  2,   10,  102, 255, 166, 23,  6,   38,  33,  13,  121, 57,  73,  26,  1,   85,
    41,  10,  67,  138, 77,  110, 90,  47,  114, 101, 29,  16,  10,  85,  128, 101, 196, 26,
    57,  18,  10,  102, 102, 213, 34,  20,  43,  117, 20,  15,  36,  163, 128, 68,  1,   26,
    138, 31,  36,  171, 27,  166, 38,  44,  229, 67,  87,  58,  169, 82,  115, 26,  59,  179,
    63,  59,  90,  180, 59,  166, 93,  73,  154, 40,  40,  21,  116, 143, 209, 34,  39,  175,
    57,  46,  22,  24,  128, 1,   54,  17,  37,  47,  15,  16,  183, 34,  223, 49,  45,  183,
    46,  17,  33,  183, 6,   98,  15,  32,  183, 65,  32,  73,  115, 28,  128, 23,  128, 205,
    40,  3,   9,   115, 51,  192, 18,  6,   223, 87,  37,  9,   115, 59,  77,  64,  21,  47,
    104, 55,  44,  218, 9,   54,  53,  130, 226, 64,  90,  70,  205, 40,  41,  23,  26,  57,
    54,  57,  112, 184, 5,   41,  38,  166, 213, 30,  34,  26,  133, 152, 116, 10,  32,  134,
    75,  32,  12,  51,  192, 255, 160, 43,  51,  39,  19,  53,  221, 26,  114, 32,  73,  255,
    31,  9,   65,  234, 2,   15,  1,   118, 73,  88,  31,  35,  67,  102, 85,  55,  186, 85,
    56,  21,  23,  111, 59,  205, 45,  37,  192, 55,  38,  70,  124, 73,  102, 1,   34,  98,
    102, 61,  71,  37,  34,  53,  31,  243, 192, 69,  60,  71,  38,  73,  119, 28,  222, 37,
    68,  45,  128, 34,  1,   47,  11,  245, 171, 62,  17,  19,  70,  146, 85,  55,  62,  70,
    75,  15,  9,   9,   64,  255, 184, 119, 16,  37,  43,  37,  154, 100, 163, 85,  160, 1,
    63,  9,   92,  136, 28,  64,  32,  201, 85,  86,  6,   28,  5,   64,  255, 25,  248, 1,
    56,  8,   17,  132, 137, 255, 55,  116, 128, 58,  15,  20,  82,  135, 57,  26,  121, 40,
    164, 50,  31,  137, 154, 133, 25,  35,  218, 51,  103, 44,  131, 131, 123, 31,  6,   158,
    86,  40,  64,  135, 148, 224, 45,  183, 128, 22,  26,  17,  131, 240, 154, 14,  1,   209,
    83,  12,  13,  54,  192, 255, 68,  47,  28,  45,  16,  21,  91,  64,  222, 7,   1,   197,
    56,  21,  39,  155, 60,  138, 23,  102, 213, 85,  26,  85,  85,  128, 128, 32,  146, 171,
    18,  11,  7,   63,  144, 171, 4,   4,   246, 35,  27,  10,  146, 174, 171, 12,  26,  128,
    190, 80,  35,  99,  180, 80,  126, 54,  45,  85,  126, 47,  87,  176, 51,  41,  20,  32,
    101, 75,  128, 139, 118, 146, 116, 128, 85,  56,  41,  15,  176, 236, 85,  37,  9,   62,
    146, 36,  19,  30,  171, 255, 97,  27,  20,  71,  30,  17,  119, 118, 255, 17,  18,  138,
    101, 38,  60,  138, 55,  70,  43,  26,  142, 138, 45,  61,  62,  219, 1,   81,  188, 64,
    32,  41,  20,  117, 151, 142, 20,  21,  163, 112, 19,  12,  61,  195, 128, 48,  4,   24,
};

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

const webp_vp8_coeff_bands = [_]usize{
    0, 1, 2, 3, 6, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 7,
    0,
};

const webp_vp8_zigzag = [_]usize{
    0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15,
};

const webp_vp8_dc_quant = [_]i16{
    4,   5,   6,   7,   8,   9,   10,  10,  11,  12,  13,  14,  15,  16,  17,  17,
    18,  19,  20,  20,  21,  21,  22,  22,  23,  23,  24,  25,  25,  26,  27,  28,
    29,  30,  31,  32,  33,  34,  35,  36,  37,  37,  38,  39,  40,  41,  42,  43,
    44,  45,  46,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,
    59,  60,  61,  62,  63,  64,  65,  66,  67,  68,  69,  70,  70,  71,  72,  73,
    74,  75,  76,  77,  78,  79,  80,  81,  82,  83,  84,  85,  86,  87,  88,  89,
    91,  93,  95,  96,  98,  100, 101, 102, 104, 106, 108, 110, 112, 114, 116, 118,
    122, 124, 126, 128, 130, 132, 134, 136, 138, 140, 143, 145, 148, 151, 154, 157,
};

const webp_vp8_ac_quant = [_]i16{
    4,   5,   6,   7,   8,   9,   10,  11,  12,  13,  14,  15,  16,  17,  18,  19,
    20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  32,  33,  34,  35,
    36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  48,  49,  50,  51,
    52,  53,  54,  55,  56,  57,  58,  60,  62,  64,  66,  68,  70,  72,  74,  76,
    78,  80,  82,  84,  86,  88,  90,  92,  94,  96,  98,  100, 102, 104, 106, 108,
    110, 112, 114, 116, 119, 122, 125, 128, 131, 134, 137, 140, 143, 146, 149, 152,
    155, 158, 161, 164, 167, 170, 173, 177, 181, 185, 189, 193, 197, 201, 205, 209,
    213, 217, 221, 225, 229, 234, 239, 245, 249, 254, 259, 264, 269, 274, 279, 284,
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

fn divRoundUp(numerator: usize, denominator: usize) usize {
    return (numerator + denominator - 1) / denominator;
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

fn writeTestVp8FrameTag(bytes: *[3]u8, first_partition_len: usize) void {
    const frame_tag = @as(usize, webp_vp8_show_frame_mask) | (first_partition_len << webp_vp8_first_part_size_shift);
    bytes[0] = @intCast(frame_tag & 0xff);
    bytes[1] = @intCast((frame_tag >> 8) & 0xff);
    bytes[2] = @intCast((frame_tag >> 16) & 0xff);
}
