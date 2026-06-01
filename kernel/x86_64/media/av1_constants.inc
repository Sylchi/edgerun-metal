; EdgeRun AV1 bitstream constants.

%ifndef ER_AV1_CONSTANTS_INC
%define ER_AV1_CONSTANTS_INC

AV1_OBU_HEADER_FORBIDDEN_MASK       equ 0x80
AV1_OBU_HEADER_TYPE_MASK            equ 0x78
AV1_OBU_HEADER_TYPE_SHIFT           equ 3
AV1_OBU_HEADER_EXTENSION_MASK       equ 0x04
AV1_OBU_HEADER_HAS_SIZE_MASK        equ 0x02
AV1_OBU_HEADER_RESERVED_MASK        equ 0x01

AV1_OBU_EXTENSION_TEMPORAL_MASK     equ 0xe0
AV1_OBU_EXTENSION_TEMPORAL_SHIFT    equ 5
AV1_OBU_EXTENSION_SPATIAL_MASK      equ 0x18
AV1_OBU_EXTENSION_SPATIAL_SHIFT     equ 3
AV1_OBU_EXTENSION_RESERVED_MASK     equ 0x07

AV1_OBU_HEADER_BASE_LEN             equ 1
AV1_OBU_HEADER_EXT_LEN              equ 2
AV1_LEB128_MAX_BYTES                equ 8
AV1_LEB128_PAYLOAD_MASK             equ 0x7f
AV1_LEB128_CONTINUE_MASK            equ 0x80
AV1_LEB128_BITS_PER_BYTE            equ 7
AV1_LEB128_U32_MAX                  equ 0xffffffff

AV1_OBU_TYPE_SEQUENCE_HEADER        equ 1
AV1_OBU_TYPE_TEMPORAL_DELIMITER     equ 2
AV1_OBU_TYPE_FRAME_HEADER           equ 3
AV1_OBU_TYPE_TILE_GROUP             equ 4
AV1_OBU_TYPE_METADATA               equ 5
AV1_OBU_TYPE_FRAME                  equ 6
AV1_OBU_TYPE_REDUNDANT_FRAME_HEADER equ 7
AV1_OBU_TYPE_TILE_LIST              equ 8
AV1_OBU_TYPE_PADDING                equ 15
AV1_OBU_TYPE_MAX                    equ 15
AV1_OBU_VALID_TYPE_MASK             equ 0x81fe

AV1_OBU_DESC_TYPE                   equ 0
AV1_OBU_DESC_EXTENSION              equ 1
AV1_OBU_DESC_HAS_SIZE               equ 2
AV1_OBU_DESC_TEMPORAL_ID            equ 3
AV1_OBU_DESC_SPATIAL_ID             equ 4
AV1_OBU_DESC_HEADER_LEN             equ 5
AV1_OBU_DESC_SIZE_FIELD_LEN         equ 6
AV1_OBU_DESC_PAYLOAD_OFFSET         equ 8
AV1_OBU_DESC_PAYLOAD_LEN            equ 12
AV1_OBU_DESC_TOTAL_LEN              equ 16
AV1_OBU_DESC_SIZE                   equ 24

AV1_ID_MAX                          equ 7

AV1_IVF_HEADER_SIZE                 equ 32
AV1_IVF_FRAME_HEADER_SIZE           equ 12
AV1_IVF_SIGNATURE                   equ 0x46494b44 ; "DKIF" little-endian
AV1_IVF_CODEC_AV01                  equ 0x31305641 ; "AV01" little-endian
AV1_IVF_DIMENSION_MAX               equ 0xffff
AV1_IVF_FILE_VERSION                equ 4
AV1_IVF_FILE_HEADER_LEN             equ 6
AV1_IVF_FILE_CODEC                  equ 8
AV1_IVF_FILE_WIDTH                  equ 12
AV1_IVF_FILE_HEIGHT                 equ 14
AV1_IVF_FILE_TIMEBASE_DEN           equ 16
AV1_IVF_FILE_TIMEBASE_NUM           equ 20
AV1_IVF_FILE_FRAME_COUNT            equ 24
AV1_IVF_FILE_RESERVED               equ 28
AV1_IVF_FRAME_RECORD_LEN            equ 0
AV1_IVF_FRAME_RECORD_TIMESTAMP      equ 4
AV1_IVF_DEFAULT_TIMEBASE_DEN        equ 30
AV1_IVF_DEFAULT_TIMEBASE_NUM        equ 1
AV1_IVF_SINGLE_FRAME_COUNT          equ 1
AV1_IVF_FIRST_TIMESTAMP             equ 0

AV1_IVF_HDR_CODEC                   equ 0
AV1_IVF_HDR_WIDTH                   equ 4
AV1_IVF_HDR_HEIGHT                  equ 6
AV1_IVF_HDR_TIMEBASE_DEN            equ 8
AV1_IVF_HDR_TIMEBASE_NUM            equ 12
AV1_IVF_HDR_FRAME_COUNT             equ 16
AV1_IVF_HDR_SIZE                    equ 24

AV1_IVF_FRAME_PAYLOAD_OFFSET        equ 0
AV1_IVF_FRAME_PAYLOAD_LEN           equ 4
AV1_IVF_FRAME_TIMESTAMP             equ 8
AV1_IVF_FRAME_SIZE                  equ 16
AV1_IVF_SCAN_HDR                    equ 0
AV1_IVF_SCAN_FRAME                  equ AV1_IVF_HDR_SIZE
AV1_IVF_SCAN_PREV_TIMESTAMP         equ AV1_IVF_SCAN_FRAME + AV1_IVF_FRAME_SIZE
AV1_IVF_SCAN_STACK_SIZE             equ 48

AV1_BITS_BUF                        equ 0
AV1_BITS_LEN                        equ 8
AV1_BITS_POS                        equ 12
AV1_BITS_SIZE                       equ 16

AV1_SEQ_PROFILE                     equ 0
AV1_SEQ_STILL_PICTURE               equ 1
AV1_SEQ_REDUCED_STILL               equ 2
AV1_SEQ_LEVEL_IDX                   equ 3
AV1_SEQ_WIDTH_BITS                  equ 4
AV1_SEQ_HEIGHT_BITS                 equ 5
AV1_SEQ_MAX_WIDTH                   equ 8
AV1_SEQ_MAX_HEIGHT                  equ 12
AV1_SEQ_BIT_DEPTH                   equ 16
AV1_SEQ_MONO_CHROME                 equ 17
AV1_SEQ_COLOR_RANGE                 equ 18
AV1_SEQ_SUBSAMPLING_X               equ 19
AV1_SEQ_SUBSAMPLING_Y               equ 20
AV1_SEQ_CHROMA_SAMPLE_POSITION      equ 21
AV1_SEQ_FILM_GRAIN                  equ 22
AV1_SEQ_SIZE                        equ 24

AV1_FRAME_TYPE                      equ 0
AV1_FRAME_SHOW_FRAME                equ 1
AV1_FRAME_WIDTH                     equ 4
AV1_FRAME_HEIGHT                    equ 8
AV1_FRAME_RENDER_WIDTH              equ 12
AV1_FRAME_RENDER_HEIGHT             equ 16
AV1_FRAME_ALLOW_INTRABC             equ 20
AV1_FRAME_HEADER_BITS               equ 24
AV1_FRAME_TILE_OFFSET               equ 28
AV1_FRAME_TILE_LEN                  equ 32
AV1_FRAME_SIZE                      equ 40

AV1_TILE_GROUP_START                equ 0
AV1_TILE_GROUP_END                  equ 4
AV1_TILE_GROUP_DATA_OFFSET          equ 8
AV1_TILE_GROUP_DATA_LEN             equ 12
AV1_TILE_GROUP_SIZE                 equ 16

AV1_IMAGE_WIDTH                     equ 0
AV1_IMAGE_HEIGHT                    equ 4
AV1_IMAGE_Y_PTR                     equ 8
AV1_IMAGE_U_PTR                     equ 16
AV1_IMAGE_V_PTR                     equ 24
AV1_IMAGE_Y_LEN                     equ 32
AV1_IMAGE_U_LEN                     equ 36
AV1_IMAGE_V_LEN                     equ 40
AV1_IMAGE_SIZE                      equ 48

AV1_REDUCED_SEQ                     equ 0
AV1_REDUCED_FRAME                   equ AV1_REDUCED_SEQ + AV1_SEQ_SIZE
AV1_REDUCED_TILE_OFFSET             equ AV1_REDUCED_FRAME + AV1_FRAME_SIZE
AV1_REDUCED_TILE_LEN                equ AV1_REDUCED_TILE_OFFSET + 4
AV1_REDUCED_SEEN_SEQUENCE           equ AV1_REDUCED_TILE_LEN + 4
AV1_REDUCED_SEEN_FRAME              equ AV1_REDUCED_SEEN_SEQUENCE + 1
AV1_REDUCED_SIZE                    equ 80

AV1_REDUCED_ENC_SEQ_DESC            equ 0
AV1_REDUCED_ENC_PAYLOAD             equ AV1_SEQ_SIZE
AV1_REDUCED_ENC_SEQ_LEN             equ AV1_REDUCED_ENC_PAYLOAD + 16
AV1_REDUCED_ENC_FRAME_LEN           equ AV1_REDUCED_ENC_SEQ_LEN + 4
AV1_REDUCED_ENC_STACK_SIZE          equ AV1_REDUCED_ENC_FRAME_LEN + 4

AV1_REDUCED_IVF_DESC                equ 0
AV1_REDUCED_IVF_WIDTH               equ AV1_IVF_HDR_SIZE
AV1_REDUCED_IVF_HEIGHT              equ AV1_REDUCED_IVF_WIDTH + 4
AV1_REDUCED_IVF_PAYLOAD_LEN         equ AV1_REDUCED_IVF_HEIGHT + 4
AV1_REDUCED_IVF_STACK_SIZE          equ AV1_REDUCED_IVF_PAYLOAD_LEN + 4

AV1_REDUCED_RAW_IVF_DESC            equ 0
AV1_REDUCED_RAW_SEQ_DESC            equ AV1_IVF_HDR_SIZE
AV1_REDUCED_RAW_PAYLOAD             equ AV1_REDUCED_RAW_SEQ_DESC + AV1_SEQ_SIZE
AV1_REDUCED_RAW_SEQ_LEN             equ AV1_REDUCED_RAW_PAYLOAD + 16
AV1_REDUCED_RAW_FRAME_LEN           equ AV1_REDUCED_RAW_SEQ_LEN + 4
AV1_REDUCED_RAW_TILE_LEN            equ AV1_REDUCED_RAW_FRAME_LEN + 4
AV1_REDUCED_RAW_IMAGE_PTR           equ AV1_REDUCED_RAW_TILE_LEN + 4
AV1_REDUCED_RAW_STACK_SIZE          equ 96
AV1_REDUCED_IVF_FRAME_HDR           equ 0
AV1_REDUCED_IVF_FRAME_DESC          equ AV1_IVF_HDR_SIZE
AV1_REDUCED_IVF_FRAME_STACK_SIZE    equ 48
AV1_REDUCED_APPEND_IVF_DESC         equ 0
AV1_REDUCED_APPEND_FRAME_DESC       equ AV1_IVF_HDR_SIZE
AV1_REDUCED_APPEND_STACK_SIZE       equ 48

AV1_FRAME_TYPE_KEY                  equ 0
AV1_SEQ_PROFILE_MAIN                equ 0
AV1_SEQ_LEVEL_2_0                   equ 0
AV1_SEQ_WIDTH_BITS_MIN              equ 1
AV1_SEQ_WIDTH_BITS_MAX              equ 16
AV1_SEQ_HEIGHT_BITS_MIN             equ 1
AV1_SEQ_HEIGHT_BITS_MAX             equ 16
AV1_SEQ_BIT_DEPTH_8                 equ 8
AV1_CHROMA_SAMPLE_POSITION_UNKNOWN  equ 0
AV1_SINGLE_TILE_COUNT               equ 1

%endif
