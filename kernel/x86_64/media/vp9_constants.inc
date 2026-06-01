; EdgeRun VP9 bitstream constants.

%ifndef ER_VP9_CONSTANTS_INC
%define ER_VP9_CONSTANTS_INC

VP9_FRAME_MARKER                    equ 2
VP9_FRAME_MARKER_MASK               equ 0x03
VP9_PROFILE_LOW_MASK                equ 0x04
VP9_PROFILE_LOW_SHIFT               equ 2
VP9_PROFILE_HIGH_MASK               equ 0x08
VP9_PROFILE_HIGH_SHIFT              equ 3
VP9_PROFILE_RESERVED_MASK           equ 0x10
VP9_SHOW_EXISTING_MASK              equ 0x10
VP9_SHOW_EXISTING_SHIFT             equ 4
VP9_SHOW_EXISTING_FRAME_INDEX_MASK  equ 0xe0
VP9_SHOW_EXISTING_FRAME_INDEX_SHIFT equ 5
VP9_FRAME_TYPE_MASK                 equ 0x20
VP9_FRAME_TYPE_SHIFT                equ 5
VP9_SHOW_FRAME_MASK                 equ 0x40
VP9_SHOW_FRAME_SHIFT                equ 6
VP9_ERROR_RESILIENT_MASK            equ 0x80
VP9_ERROR_RESILIENT_SHIFT           equ 7

VP9_FRAME_TYPE_KEY                  equ 0
VP9_FRAME_TYPE_INTER                equ 1
VP9_PROFILE_MAX                     equ 3
VP9_SHOW_EXISTING_HEADER_SIZE       equ 1
VP9_INTER_HEADER_SIZE               equ 1
VP9_KEY_HEADER_SIZE                 equ 10
VP9_SYNC_CODE_OFFSET                equ 1
VP9_SYNC_CODE_0                     equ 0x49
VP9_SYNC_CODE_1                     equ 0x83
VP9_SYNC_CODE_2                     equ 0x42
VP9_FRAME_WIDTH_OFFSET              equ 4
VP9_FRAME_HEIGHT_OFFSET             equ 6
VP9_RENDER_WIDTH_OFFSET             equ 8
VP9_RENDER_HEIGHT_OFFSET            equ 10
VP9_DIMENSION_MAX                   equ 0xffff

VP9_HEADER_DESC_MARKER              equ 0
VP9_HEADER_DESC_PROFILE             equ 1
VP9_HEADER_DESC_SHOW_EXISTING       equ 2
VP9_HEADER_DESC_EXISTING_FRAME_IDX  equ 3
VP9_HEADER_DESC_FRAME_TYPE          equ 4
VP9_HEADER_DESC_SHOW_FRAME          equ 5
VP9_HEADER_DESC_ERROR_RESILIENT     equ 6
VP9_HEADER_DESC_WIDTH               equ 8
VP9_HEADER_DESC_HEIGHT              equ 10
VP9_HEADER_DESC_RENDER_WIDTH        equ 12
VP9_HEADER_DESC_RENDER_HEIGHT       equ 14
VP9_HEADER_DESC_SIZE                equ 16

%endif
