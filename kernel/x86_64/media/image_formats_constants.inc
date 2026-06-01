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

JPEG_MARKER_PREFIX                equ 0xff
JPEG_MARKER_SOI                   equ 0xd8
JPEG_MARKER_SOS                   equ 0xda
JPEG_MARKER_SOF0                  equ 0xc0
JPEG_MARKER_SOF2                  equ 0xc2
JPEG_MARKER_RST0                  equ 0xd0
JPEG_MARKER_RST7                  equ 0xd7
JPEG_PRECISION_8                  equ 8
JPEG_MAX_COMPONENTS               equ 3

PNG_SIGNATURE_HI                  equ 0x474e5089
PNG_SIGNATURE_LO                  equ 0x0a1a0a0d
PNG_SIGNATURE_SIZE                equ 8
PNG_CHUNK_OVERHEAD                equ 12
PNG_IHDR_SIZE                     equ 13
PNG_CHUNK_IHDR                    equ 0x52444849
PNG_BIT_DEPTH_U8                  equ 8
PNG_COLOR_GRAYSCALE               equ 0
PNG_COLOR_RGB                     equ 2
PNG_COLOR_GRAYSCALE_ALPHA         equ 4
PNG_COLOR_RGBA                    equ 6
PNG_METHOD_DEFLATE                equ 0
PNG_FILTER_STANDARD               equ 0
PNG_INTERLACE_NONE                equ 0

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
