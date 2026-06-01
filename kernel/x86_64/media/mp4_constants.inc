; EdgeRun MP4/ISOBMFF constants.

%ifndef ER_MP4_CONSTANTS_INC
%define ER_MP4_CONSTANTS_INC

MP4_BOX_HEADER_SIZE                 equ 8
MP4_BOX_LARGE_HEADER_SIZE           equ 16
MP4_BOX_TYPE_OFFSET                 equ 4
MP4_BOX_LARGE_SIZE_OFFSET           equ 8
MP4_BOX_SIZE_FIELD_LARGE            equ 1
MP4_BOX_SIZE_FIELD_TO_EOF           equ 0

MP4_BOX_TYPE_FTYP                   equ 0x70797466 ; "ftyp" little-endian load
MP4_BOX_TYPE_MDAT                   equ 0x7461646d ; "mdat" little-endian load
MP4_BOX_TYPE_MOOV                   equ 0x766f6f6d ; "moov" little-endian load
MP4_BOX_TYPE_TRAK                   equ 0x6b617274 ; "trak" little-endian load
MP4_BOX_TYPE_MDIA                   equ 0x6169646d ; "mdia" little-endian load
MP4_BOX_TYPE_MINF                   equ 0x666e696d ; "minf" little-endian load
MP4_BOX_TYPE_STBL                   equ 0x6c627473 ; "stbl" little-endian load
MP4_BOX_TYPE_STSD                   equ 0x64737473 ; "stsd" little-endian load
MP4_BOX_TYPE_STSC                   equ 0x63737473 ; "stsc" little-endian load
MP4_BOX_TYPE_STSZ                   equ 0x7a737473 ; "stsz" little-endian load
MP4_BOX_TYPE_STCO                   equ 0x6f637473 ; "stco" little-endian load
MP4_BOX_TYPE_AV01                   equ 0x31307661 ; "av01" little-endian load
MP4_BOX_TYPE_AV1C                   equ 0x43317661 ; "av1C" little-endian load
MP4_BRAND_AV01                      equ 0x31307661 ; "av01" little-endian load

MP4_FTYP_MAJOR_BRAND                equ 0
MP4_FTYP_MINOR_VERSION              equ 4
MP4_FTYP_COMPATIBLE_BRANDS          equ 8
MP4_BRAND_SIZE                      equ 4
MP4_FTYP_PAYLOAD_MIN                equ MP4_FTYP_COMPATIBLE_BRANDS

MP4_BOX_DESC_TYPE                   equ 0
MP4_BOX_DESC_HEADER_SIZE            equ 4
MP4_BOX_DESC_PAYLOAD_OFFSET         equ 8
MP4_BOX_DESC_PAYLOAD_LEN            equ 12
MP4_BOX_DESC_NEXT_OFFSET            equ 16
MP4_BOX_DESC_SIZE                   equ 24

MP4_FULLBOX_HEADER_SIZE             equ 4
MP4_STSD_ENTRY_COUNT_OFFSET         equ 4
MP4_STSD_FIRST_ENTRY_OFFSET         equ 8
MP4_VISUAL_SAMPLE_ENTRY_CHILD_OFFSET equ 78

MP4_STSC_ENTRY_COUNT_OFFSET         equ 4
MP4_STSC_FIRST_ENTRY_OFFSET         equ 8
MP4_STSC_ENTRY_SIZE                 equ 12
MP4_STSC_ENTRY_FIRST_CHUNK          equ 0
MP4_STSC_ENTRY_SAMPLES_PER_CHUNK    equ 4
MP4_STSC_ENTRY_SAMPLE_DESC_INDEX    equ 8
MP4_STSC_DESC_FIRST_CHUNK           equ 0
MP4_STSC_DESC_SAMPLES_PER_CHUNK     equ 4
MP4_STSC_DESC_SAMPLE_DESC_INDEX     equ 8
MP4_STSC_DESC_SIZE                  equ 16

MP4_STSZ_SAMPLE_SIZE_OFFSET         equ 4
MP4_STSZ_SAMPLE_COUNT_OFFSET        equ 8
MP4_STSZ_FIRST_ENTRY_OFFSET         equ 12
MP4_STSZ_ENTRY_SIZE                 equ 4

MP4_STCO_ENTRY_COUNT_OFFSET         equ 4
MP4_STCO_FIRST_ENTRY_OFFSET         equ 8
MP4_STCO_ENTRY_SIZE                 equ 4

MP4_AV1C_PAYLOAD_MIN                equ 4
MP4_AV1C_MARKER_MASK                equ 0x80
MP4_AV1C_VERSION_MASK               equ 0x7f
MP4_AV1C_VERSION                    equ 1
MP4_AV1C_PROFILE_MASK               equ 0xe0
MP4_AV1C_PROFILE_SHIFT              equ 5
MP4_AV1C_LEVEL_MASK                 equ 0x1f
MP4_AV1C_TIER_MASK                  equ 0x80
MP4_AV1C_TIER_SHIFT                 equ 7
MP4_AV1C_HIGH_BITDEPTH_MASK         equ 0x40
MP4_AV1C_HIGH_BITDEPTH_SHIFT        equ 6
MP4_AV1C_TWELVE_BIT_MASK            equ 0x20
MP4_AV1C_TWELVE_BIT_SHIFT           equ 5
MP4_AV1C_MONOCHROME_MASK            equ 0x10
MP4_AV1C_MONOCHROME_SHIFT           equ 4
MP4_AV1C_SUBSAMPLING_X_MASK         equ 0x08
MP4_AV1C_SUBSAMPLING_X_SHIFT        equ 3
MP4_AV1C_SUBSAMPLING_Y_MASK         equ 0x04
MP4_AV1C_SUBSAMPLING_Y_SHIFT        equ 2
MP4_AV1C_CHROMA_POSITION_MASK       equ 0x03
MP4_AV1C_IPD_PRESENT_MASK           equ 0x10
MP4_AV1C_IPD_PRESENT_SHIFT          equ 4
MP4_AV1C_IPD_MINUS_ONE_MASK         equ 0x0f

MP4_AV1C_DESC_PROFILE               equ 0
MP4_AV1C_DESC_LEVEL                 equ 1
MP4_AV1C_DESC_TIER                  equ 2
MP4_AV1C_DESC_HIGH_BITDEPTH         equ 3
MP4_AV1C_DESC_TWELVE_BIT            equ 4
MP4_AV1C_DESC_MONOCHROME            equ 5
MP4_AV1C_DESC_SUBSAMPLING_X         equ 6
MP4_AV1C_DESC_SUBSAMPLING_Y         equ 7
MP4_AV1C_DESC_CHROMA_POSITION       equ 8
MP4_AV1C_DESC_IPD_PRESENT           equ 9
MP4_AV1C_DESC_IPD_MINUS_ONE         equ 10
MP4_AV1C_DESC_CONFIG_OBU_OFFSET     equ 12
MP4_AV1C_DESC_CONFIG_OBU_LEN        equ 16
MP4_AV1C_DESC_SIZE                  equ 24

%endif
