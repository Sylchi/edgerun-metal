; EdgeRun image format constants.

%ifndef ER_IMAGE_FORMATS_CONSTANTS_INC
%define ER_IMAGE_FORMATS_CONSTANTS_INC

IMAGE_FORMAT_JPEG                 equ 1
IMAGE_FORMAT_JXL                  equ 2
IMAGE_FORMAT_PNG                  equ 3
IMAGE_FORMAT_TGA                  equ 4

IMAGE_JXL_KIND_CODESTREAM         equ 1
IMAGE_JXL_KIND_CONTAINER          equ 2

IMAGE_HEADER_WIDTH                equ 0
IMAGE_HEADER_HEIGHT               equ 4
IMAGE_HEADER_SIZE                 equ 8

ERIMG_MAGIC                       equ 0x313030474d495245
ERIMG_ABI_VERSION                 equ 1
ERIMG_FORMAT_RGBA8                equ 1
ERIMG_HEADER_SIZE                 equ 40
ERIMG_TILE_COUNT_SINGLE           equ 1
ERIMG_MAX_DIMENSION               equ 0xffff
ERIMG_MAGIC_OFFSET                equ 0
ERIMG_ABI_OFFSET                  equ 8
ERIMG_FORMAT_OFFSET               equ 10
ERIMG_FLAGS_OFFSET                equ 12
ERIMG_WIDTH_OFFSET                equ 16
ERIMG_HEIGHT_OFFSET               equ 20
ERIMG_TILE_W_OFFSET               equ 24
ERIMG_TILE_H_OFFSET               equ 26
ERIMG_TILE_COUNT_OFFSET           equ 28
ERIMG_PAYLOAD_LEN_OFFSET          equ 32

JPEG_MARKER_PREFIX                equ 0xff
JPEG_MARKER_SOI                   equ 0xd8
JPEG_MARKER_SOS                   equ 0xda
JPEG_MARKER_SOF0                  equ 0xc0
JPEG_MARKER_SOF2                  equ 0xc2
JPEG_MARKER_DHT                   equ 0xc4
JPEG_MARKER_DQT                   equ 0xdb
JPEG_MARKER_DRI                   equ 0xdd
JPEG_MARKER_EOI                   equ 0xd9
JPEG_MARKER_RST0                  equ 0xd0
JPEG_MARKER_RST3                  equ 0xd3
JPEG_MARKER_RST7                  equ 0xd7
JPEG_PRECISION_8                  equ 8
JPEG_MAX_COMPONENTS               equ 3
JPEG_TABLE_COUNT                  equ 4
JPEG_DC_CLASS                     equ 0
JPEG_AC_CLASS                     equ 1
JPEG_BLOCK_LEN                    equ 64
JPEG_BLOCK_SIDE                   equ 8
JPEG_MAX_SAMPLING_FACTOR          equ 2
JPEG_MAX_COMPONENT_BLOCKS         equ JPEG_MAX_SAMPLING_FACTOR * JPEG_MAX_SAMPLING_FACTOR
JPEG_MAX_CODE_LEN                 equ 16
JPEG_MAX_HUFFMAN_SYMBOLS          equ 256
JPEG_ALPHA_OPAQUE                 equ 0xff000000
JPEG_COLOR_SCALE_BITS             equ 16
JPEG_COLOR_ROUND                  equ 1 << (JPEG_COLOR_SCALE_BITS - 1)
JPEG_YCBCR_R_CR_COEFF            equ 91881
JPEG_YCBCR_G_CB_COEFF            equ 22554
JPEG_YCBCR_G_CR_COEFF            equ 46802
JPEG_YCBCR_B_CB_COEFF            equ 116130
JPEG_IDCT_BASIS_BITS             equ 12
JPEG_IDCT_FINAL_SHIFT            equ JPEG_IDCT_BASIS_BITS * 2 + 2
JPEG_IDCT_FINAL_ROUND            equ 1 << (JPEG_IDCT_FINAL_SHIFT - 1)
JPEG_I16_MIN                     equ -32768
JPEG_I16_MAX                     equ 32767
JPEG_COMPONENT_ID_OFF             equ 0
JPEG_COMPONENT_SAMPLING_OFF       equ 1
JPEG_COMPONENT_QUANT_ID_OFF       equ 2
JPEG_COMPONENT_DC_TABLE_OFF       equ 3
JPEG_COMPONENT_AC_TABLE_OFF       equ 4
JPEG_COMPONENT_PREV_DC_OFF        equ 6
JPEG_COMPONENT_SIZE               equ 8
JPEG_HUFF_CODE_OFF                equ 0
JPEG_HUFF_LEN_OFF                 equ 2
JPEG_HUFF_VALUE_OFF               equ 3
JPEG_HUFF_SYMBOL_SIZE             equ 4
JPEG_HUFF_TABLE_LEN_OFF           equ 0
JPEG_HUFF_TABLE_READY_OFF         equ 4
JPEG_HUFF_TABLE_SYMBOLS_OFF       equ 8
JPEG_HUFF_TABLE_SIZE              equ JPEG_HUFF_TABLE_SYMBOLS_OFF + JPEG_MAX_HUFFMAN_SYMBOLS * JPEG_HUFF_SYMBOL_SIZE
JPEG_STATE_WIDTH_OFF              equ 0
JPEG_STATE_HEIGHT_OFF             equ 4
JPEG_STATE_COMPONENT_COUNT_OFF    equ 8
JPEG_STATE_MAX_H_OFF              equ 12
JPEG_STATE_MAX_V_OFF              equ 16
JPEG_STATE_RESTART_INTERVAL_OFF   equ 20
JPEG_STATE_HAVE_FRAME_OFF         equ 24
JPEG_STATE_COMPONENTS_OFF         equ 28
JPEG_STATE_QUANT_OFF              equ JPEG_STATE_COMPONENTS_OFF + JPEG_MAX_COMPONENTS * JPEG_COMPONENT_SIZE
JPEG_STATE_QUANT_READY_OFF        equ JPEG_STATE_QUANT_OFF + JPEG_TABLE_COUNT * JPEG_BLOCK_LEN * 2
JPEG_STATE_DC_TABLES_OFF          equ JPEG_STATE_QUANT_READY_OFF + JPEG_TABLE_COUNT
JPEG_STATE_AC_TABLES_OFF          equ JPEG_STATE_DC_TABLES_OFF + JPEG_TABLE_COUNT * JPEG_HUFF_TABLE_SIZE
JPEG_STATE_SIZE                   equ JPEG_STATE_AC_TABLES_OFF + JPEG_TABLE_COUNT * JPEG_HUFF_TABLE_SIZE
JPEG_BIT_READER_BYTES_OFF         equ 0
JPEG_BIT_READER_LEN_OFF           equ 8
JPEG_BIT_READER_CURSOR_OFF        equ 12
JPEG_BIT_READER_BUFFER_OFF        equ 16
JPEG_BIT_READER_BITS_LEFT_OFF     equ 17
JPEG_BIT_READER_SIZE              equ 24
JPEG_SCAN_SCRATCH_READER_OFF      equ 0
JPEG_SCAN_SCRATCH_BLOCKS_OFF      equ JPEG_SCAN_SCRATCH_READER_OFF + JPEG_BIT_READER_SIZE
JPEG_SCAN_COMPONENT_STRIDE        equ JPEG_MAX_COMPONENT_BLOCKS * JPEG_BLOCK_LEN * 2
JPEG_SCAN_SCRATCH_SIZE            equ JPEG_SCAN_SCRATCH_BLOCKS_OFF + JPEG_MAX_COMPONENTS * JPEG_SCAN_COMPONENT_STRIDE
JPEG_DECODE_SCRATCH_STATE_OFF     equ 0
JPEG_DECODE_SCRATCH_SCAN_OFF      equ JPEG_DECODE_SCRATCH_STATE_OFF + JPEG_STATE_SIZE
JPEG_DECODE_SCRATCH_SIZE          equ JPEG_DECODE_SCRATCH_SCAN_OFF + JPEG_SCAN_SCRATCH_SIZE

PNG_SIGNATURE_HI                  equ 0x474e5089
PNG_SIGNATURE_LO                  equ 0x0a1a0a0d
PNG_SIGNATURE_SIZE                equ 8
PNG_LENGTH_SIZE                   equ 4
PNG_TYPE_SIZE                     equ 4
PNG_CRC_SIZE                      equ 4
PNG_CHUNK_HEADER_SIZE             equ PNG_LENGTH_SIZE + PNG_TYPE_SIZE
PNG_CHUNK_OVERHEAD                equ 12
PNG_IHDR_SIZE                     equ 13
PNG_CHUNK_IHDR                    equ 0x52444849
PNG_CHUNK_IDAT                    equ 0x54414449
PNG_CHUNK_IEND                    equ 0x444e4549
PNG_CHUNK_RESERVED_INDEX          equ 2
PNG_CHUNK_ANCILLARY_BIT           equ 0x20
PNG_CRC32_POLY                    equ 0xedb88320
PNG_BIT_DEPTH_U8                  equ 8
PNG_COLOR_GRAYSCALE               equ 0
PNG_COLOR_RGB                     equ 2
PNG_COLOR_GRAYSCALE_ALPHA         equ 4
PNG_COLOR_RGBA                    equ 6
PNG_METHOD_DEFLATE                equ 0
PNG_FILTER_STANDARD               equ 0
PNG_INTERLACE_NONE                equ 0
PNG_FILTER_NONE                   equ 0
PNG_FILTER_SUB                    equ 1
PNG_FILTER_UP                     equ 2
PNG_FILTER_AVERAGE                equ 3
PNG_FILTER_PAETH                  equ 4
PNG_ALPHA_OPAQUE                  equ 255
PNG_INFO_WIDTH_OFF                equ 0
PNG_INFO_HEIGHT_OFF               equ 4
PNG_INFO_CHANNELS_OFF             equ 8
PNG_INFO_SIZE                     equ 12
PNG_CHUNK_INFO_LEN_OFF            equ 0
PNG_CHUNK_INFO_TYPE_OFF           equ 4
PNG_CHUNK_INFO_DATA_OFF           equ 8
PNG_CHUNK_INFO_NEXT_OFF           equ 12
PNG_CHUNK_INFO_SIZE               equ 16
ZLIB_HEADER_SIZE                  equ 2
ZLIB_ADLER_SIZE                   equ 4
ZLIB_CM_DEFLATE                   equ 8
ZLIB_CINFO_MAX                    equ 7
DEFLATE_BFINAL_MASK               equ 1
DEFLATE_BTYPE_MASK                equ 6
DEFLATE_BTYPE_STORED              equ 0
DEFLATE_BTYPE_FIXED               equ 2
DEFLATE_BTYPE_DYNAMIC             equ 4
DEFLATE_MAX_BITS                  equ 15
DEFLATE_CL_COUNT                  equ 19
DEFLATE_LL_COUNT                  equ 288
DEFLATE_DIST_COUNT                equ 32
ASCII_UPPER_A                     equ 'A'
ASCII_UPPER_Z                     equ 'Z'
ASCII_LOWER_A                     equ 'a'
ASCII_LOWER_Z                     equ 'z'

JXL_CODESTREAM_SIGNATURE          equ 0x0aff
JXL_CONTAINER_SIGNATURE_0         equ 0x0c000000
JXL_CONTAINER_SIGNATURE_1         equ 0x204c584a
JXL_CONTAINER_SIGNATURE_2         equ 0x0a870a0d
JXL_CONTAINER_SIGNATURE_SIZE      equ 12

TGA_HEADER_SIZE                   equ 18
TGA_FOOTER_SIZE                   equ 26
TGA_TYPE_TRUE_COLOR               equ 2
TGA_ORIGIN_TOP                    equ 0x20
TGA_ALPHA_BITS                    equ 8
TGA_DEPTH_RGB                     equ 24
TGA_DEPTH_RGBA                    equ 32
TGA_DESCRIPTOR_RGBA_TOP_LEFT      equ TGA_ORIGIN_TOP | TGA_ALPHA_BITS
TGA_ID_LEN_INDEX                  equ 0
TGA_COLOR_MAP_TYPE_INDEX          equ 1
TGA_IMAGE_TYPE_INDEX              equ 2
TGA_WIDTH_INDEX                   equ 12
TGA_HEIGHT_INDEX                  equ 14
TGA_DEPTH_INDEX                   equ 16
TGA_DESCRIPTOR_INDEX              equ 17
TGA_ALPHA_OPAQUE                  equ 255

%endif
