; EdgeRun AV1 MP4 self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/mp4_constants.inc"
%include "x86_64/media/av1_constants.inc"
%include "test/test_macros.inc"

extern er_mp4_read_box
extern er_mp4_ftyp_has_brand
extern er_mp4_find_box
extern er_mp4_find_child_box
extern er_mp4_stsd_first_entry
extern er_mp4_sample_entry_find_child
extern er_mp4_sample_tables_find
extern er_mp4_video_stbl_find
extern er_mp4_video_sample_tables_find
extern er_mp4_file_video_sample_tables_find
extern er_mp4_file_video_sample_locate
extern er_mp4_file_video_sample_payload
extern er_mp4_file_video_sample_obu_scan
extern er_mp4_file_video_sample_obu_route
extern er_mp4_visual_sample_entry_decode
extern er_mp4_mdhd_decode
extern er_mp4_tkhd_decode
extern er_mp4_hdlr_decode
extern er_mp4_hdlr_is_video
extern er_mp4_av1c_decode
extern er_mp4_stts_entry
extern er_mp4_stts_sample_time
extern er_mp4_ctts_entry
extern er_mp4_ctts_sample_offset
extern er_mp4_stss_sync_count
extern er_mp4_stss_is_sync_sample
extern er_mp4_stsz_sample_count
extern er_mp4_stsz_sample_size
extern er_mp4_stco_chunk_offset
extern er_mp4_stco_chunk_count
extern er_mp4_co64_chunk_offset
extern er_mp4_co64_chunk_count
extern er_mp4_stsc_entry
extern er_mp4_sample_locate
extern er_mp4_sample_payload
extern er_mp4_is_av1
extern er_av1_obu_decode_unit
extern er_av1_obu_scan_units
extern er_av1_obu_route_sample
extern er_av1_obu_count_units

TEST_BSS_PASSED_FAILED
box_desc:   resb MP4_BOX_DESC_SIZE
entry_desc: resb MP4_BOX_DESC_SIZE
visual_desc: resb MP4_VISUAL_SAMPLE_ENTRY_DESC_SIZE
mdhd_desc:  resb MP4_MDHD_DESC_SIZE
tkhd_desc:  resb MP4_TKHD_DESC_SIZE
hdlr_desc:  resb MP4_HDLR_DESC_SIZE
av1c_desc:  resb MP4_AV1C_DESC_SIZE
stts_desc:  resb MP4_STTS_DESC_SIZE
ctts_desc:  resb MP4_CTTS_DESC_SIZE
stsc_desc:  resb MP4_STSC_DESC_SIZE
tables_desc: resb MP4_SAMPLE_TABLES_SIZE
sample_desc: resb MP4_SAMPLE_DESC_SIZE
sample_time: resb MP4_SAMPLE_TIME_SIZE
payload_desc: resb MP4_SAMPLE_DESC_SIZE
obu_desc:   resb AV1_OBU_DESC_SIZE
obu_stats:  resb AV1_OBU_STATS_SIZE
obu_route:  resb AV1_OBU_ROUTE_SIZE

SECTION .data
mp4_av1:
    db 0x00,0x00,0x00,0x20
    db 'f','t','y','p'
    db 'i','s','o','m'
    db 0x00,0x00,0x02,0x00
    db 'i','s','o','m'
    db 'a','v','0','1'
    db 'i','s','o','2'
    db 'm','p','4','1'
    db 0x00,0x00,0x00,0x10
    db 'm','d','a','t'
    times 8 db 0xaa
mp4_av1_len equ $ - mp4_av1

mp4_large:
    db 0x00,0x00,0x00,0x01
    db 'm','d','a','t'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x18
    times 8 db 0xbb
mp4_large_len equ $ - mp4_large

mp4_to_eof:
    db 0x00,0x00,0x00,0x00
    db 'm','d','a','t'
    times 5 db 0xcc
mp4_to_eof_len equ $ - mp4_to_eof

mp4_trunc:
    db 0x00,0x00,0x00,0x20
    db 'f','t','y','p'
    db 'i','s','o','m'
mp4_trunc_len equ $ - mp4_trunc

mp4_no_av1:
    db 0x00,0x00,0x00,0x18
    db 'f','t','y','p'
    db 'i','s','o','m'
    db 0x00,0x00,0x02,0x00
    db 'i','s','o','m'
    db 'i','s','o','2'
mp4_no_av1_len equ $ - mp4_no_av1

mp4_parent:
    db 0x00,0x00,0x00,0x20
    db 'm','o','o','v'
    db 0x00,0x00,0x00,0x08
    db 'f','r','e','e'
    db 0x00,0x00,0x00,0x10
    db 'm','d','a','t'
    times 8 db 0xdd
mp4_parent_len equ $ - mp4_parent

mp4_sample:
    db 0x00,0x00,0x00,0x08
    db 'f','r','e','e'
    db 0x00,0x00,0x00,0x76
    db 's','t','s','d'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x66
    db 'a','v','0','1'
    times 6 db 0
    db 0x00,0x01
    times 16 db 0
    db 0x07,0x80
    db 0x03,0x32
    times 50 db 0
    db 0x00,0x00,0x00,0x10
    db 'a','v','1','C'
    db 0x81,0x08,0x0c,0x00
    db 0x0a,0x0b,0x00,0x00
mp4_sample_len equ $ - mp4_sample

mp4_tables:
    db 0x00,0x00,0x00,0x20
    db 's','t','s','z'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x03,0xe8
    db 0x00,0x00,0x07,0xd0
    db 0x00,0x00,0x0b,0xb8
mp4_tables_stco equ $ - mp4_tables
    db 0x00,0x00,0x00,0x18
    db 's','t','c','o'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x10,0x00
    db 0x00,0x00,0x20,0x00
mp4_tables_stsc equ $ - mp4_tables
    db 0x00,0x00,0x00,0x28
    db 's','t','s','c'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x04
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
mp4_tables_len equ $ - mp4_tables

mp4_co64_tables:
    db 0x00,0x00,0x00,0x20
    db 'c','o','6','4'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x30,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x40,0x00
mp4_co64_tables_high equ $ - mp4_co64_tables
    db 0x00,0x00,0x00,0x18
    db 'c','o','6','4'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x00
mp4_co64_tables_len equ $ - mp4_co64_tables

mp4_tables_co64_locate:
    db 0x00,0x00,0x00,0x20
    db 's','t','s','z'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x03,0xe8
    db 0x00,0x00,0x07,0xd0
    db 0x00,0x00,0x0b,0xb8
mp4_tables_co64_locate_co64 equ $ - mp4_tables_co64_locate
    db 0x00,0x00,0x00,0x20
    db 'c','o','6','4'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x30,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x40,0x00
mp4_tables_co64_locate_stsc equ $ - mp4_tables_co64_locate
    db 0x00,0x00,0x00,0x28
    db 's','t','s','c'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x04
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
mp4_tables_co64_locate_len equ $ - mp4_tables_co64_locate

mp4_stbl_co64_locate:
    db 0x00,0x00,0x00,0x70
    db 's','t','b','l'
    db 0x00,0x00,0x00,0x20
    db 's','t','s','z'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x03,0xe8
    db 0x00,0x00,0x07,0xd0
    db 0x00,0x00,0x0b,0xb8
    db 0x00,0x00,0x00,0x20
    db 'c','o','6','4'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x30,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x40,0x00
    db 0x00,0x00,0x00,0x28
    db 's','t','s','c'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x04
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
mp4_stbl_co64_locate_len equ $ - mp4_stbl_co64_locate

mp4_moov_video_stbl:
    db 0x00,0x00,0x00,0xe2
    db 'm','o','o','v'
    db 0x00,0x00,0x00,0x31
    db 't','r','a','k'
    db 0x00,0x00,0x00,0x29
    db 'm','d','i','a'
    db 0x00,0x00,0x00,0x21
    db 'h','d','l','r'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 's','o','u','n'
    times 12 db 0x00
    db 0x00
    db 0x00,0x00,0x00,0xa9
    db 't','r','a','k'
    db 0x00,0x00,0x00,0xa1
    db 'm','d','i','a'
    db 0x00,0x00,0x00,0x21
    db 'h','d','l','r'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 'v','i','d','e'
    times 12 db 0x00
    db 0x00
    db 0x00,0x00,0x00,0x78
    db 'm','i','n','f'
    db 0x00,0x00,0x00,0x70
    db 's','t','b','l'
    db 0x00,0x00,0x00,0x20
    db 's','t','s','z'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x03,0xe8
    db 0x00,0x00,0x07,0xd0
    db 0x00,0x00,0x0b,0xb8
    db 0x00,0x00,0x00,0x20
    db 'c','o','6','4'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x30,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x40,0x00
    db 0x00,0x00,0x00,0x28
    db 's','t','s','c'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x04
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
mp4_moov_video_stbl_len equ $ - mp4_moov_video_stbl

mp4_file_video_stbl:
    db 0x00,0x00,0x00,0x18
    db 'f','t','y','p'
    db 'i','s','o','m'
    db 0x00,0x00,0x02,0x00
    db 'i','s','o','m'
    db 'a','v','0','1'
    db 0x00,0x00,0x00,0xe2
    db 'm','o','o','v'
    db 0x00,0x00,0x00,0x31
    db 't','r','a','k'
    db 0x00,0x00,0x00,0x29
    db 'm','d','i','a'
    db 0x00,0x00,0x00,0x21
    db 'h','d','l','r'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 's','o','u','n'
    times 12 db 0x00
    db 0x00
    db 0x00,0x00,0x00,0xa9
    db 't','r','a','k'
    db 0x00,0x00,0x00,0xa1
    db 'm','d','i','a'
    db 0x00,0x00,0x00,0x21
    db 'h','d','l','r'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 'v','i','d','e'
    times 12 db 0x00
    db 0x00
    db 0x00,0x00,0x00,0x78
    db 'm','i','n','f'
    db 0x00,0x00,0x00,0x70
    db 's','t','b','l'
    db 0x00,0x00,0x00,0x20
    db 's','t','s','z'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x03,0xe8
    db 0x00,0x00,0x07,0xd0
    db 0x00,0x00,0x0b,0xb8
    db 0x00,0x00,0x00,0x20
    db 'c','o','6','4'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x30,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x40,0x00
    db 0x00,0x00,0x00,0x28
    db 's','t','s','c'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x04
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x01
mp4_file_video_stbl_len equ $ - mp4_file_video_stbl

mp4_file_video_payload:
    db 0x00,0x00,0x00,0x18
    db 'f','t','y','p'
    db 'i','s','o','m'
    db 0x00,0x00,0x02,0x00
    db 'i','s','o','m'
    db 'a','v','0','1'
    db 0x00,0x00,0x00,0x9d
    db 'm','o','o','v'
    db 0x00,0x00,0x00,0x95
    db 't','r','a','k'
    db 0x00,0x00,0x00,0x8d
    db 'm','d','i','a'
    db 0x00,0x00,0x00,0x21
    db 'h','d','l','r'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 'v','i','d','e'
    times 12 db 0x00
    db 0x00
    db 0x00,0x00,0x00,0x64
    db 'm','i','n','f'
    db 0x00,0x00,0x00,0x5c
    db 's','t','b','l'
    db 0x00,0x00,0x00,0x20
    db 's','t','s','z'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x04
    db 0x00,0x00,0x00,0x05
    db 0x00,0x00,0x00,0x06
    db 0x00,0x00,0x00,0x18
    db 'c','o','6','4'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0xbd
    db 0x00,0x00,0x00,0x1c
    db 's','t','s','c'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x17
    db 'm','d','a','t'
    db 0xaa,0xbb,0xcc,0xdd
    db 0x0a,0x02,0x11,0x22,0x33
    db 0x1a,0x04,0x44,0x55,0x66,0x77
mp4_file_video_payload_len equ $ - mp4_file_video_payload

mp4_time_tables:
    db 0x00,0x00,0x00,0x20
    db 's','t','t','s'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x03,0xe8
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x01,0xf4
mp4_time_tables_stss equ $ - mp4_time_tables
    db 0x00,0x00,0x00,0x1c
    db 's','t','s','s'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x00,0x05
mp4_time_tables_len equ $ - mp4_time_tables

mp4_ctts_tables:
    db 0x00,0x00,0x00,0x20
    db 'c','t','t','s'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x00,0x02
    db 0x00,0x00,0x01,0xf4
    db 0x00,0x00,0x00,0x03
    db 0x00,0x00,0x03,0xe8
mp4_ctts_tables_v1 equ $ - mp4_ctts_tables
    db 0x00,0x00,0x00,0x18
    db 'c','t','t','s'
    db 0x01,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x04
    db 0xff,0xff,0xff,0x9c
mp4_ctts_tables_len equ $ - mp4_ctts_tables

mp4_headers:
    db 0x00,0x00,0x00,0x20
    db 'm','d','h','d'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x75,0x30
    db 0x00,0x04,0x93,0xe0
    db 0x00,0x00,0x00,0x00
mp4_headers_tkhd equ $ - mp4_headers
    db 0x00,0x00,0x00,0x5c
    db 't','k','h','d'
    db 0x00,0x00,0x00,0x07
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x00
    db 0x00,0x04,0x93,0xe0
    times 16 db 0x00
    times 36 db 0x00
    db 0x07,0x80,0x00,0x00
    db 0x03,0x32,0x00,0x00
mp4_headers_mdhd_v1 equ $ - mp4_headers
    db 0x00,0x00,0x00,0x2c
    db 'm','d','h','d'
    db 0x01,0x00,0x00,0x00
    times 16 db 0x00
    db 0x00,0x00,0x75,0x30
    db 0x00,0x00,0x00,0x00
    db 0x00,0x04,0x93,0xe0
    db 0x00,0x00,0x00,0x00
mp4_headers_hdlr_video equ $ - mp4_headers
    db 0x00,0x00,0x00,0x21
    db 'h','d','l','r'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 'v','i','d','e'
    times 12 db 0x00
    db 0x00
mp4_headers_hdlr_audio equ $ - mp4_headers
    db 0x00,0x00,0x00,0x21
    db 'h','d','l','r'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00
    db 's','o','u','n'
    times 12 db 0x00
    db 0x00
mp4_headers_len equ $ - mp4_headers

mp4_mdat:
    db 0x00,0x00,0x00,0x40
    db 'm','d','a','t'
    times 24 db 0x11
    db 0x0a,0x02,0xaa,0xbb,0x1a,0x01,0xcc,0x22,0x01,0xdd,0x32,0x01,0xee
    times 19 db 0x22
mp4_mdat_len equ $ - mp4_mdat

SECTION .text
global _start
_start:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, 32
    jne     .fail_read_ftyp
    test    edx, edx
    jnz     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_FTYP
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_HEADER_SIZE], MP4_BOX_HEADER_SIZE
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 8
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 24
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_NEXT_OFFSET], 32
    jne     .fail_read_ftyp
    inc     qword [rel passed]
    jmp     .read_mdat
.fail_read_ftyp:
    inc     qword [rel failed]

.read_mdat:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    mov     edx, 32
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, 48
    jne     .fail_read_mdat
    test    edx, edx
    jnz     .fail_read_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 40
    jne     .fail_read_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_read_mdat
    inc     qword [rel passed]
    jmp     .av1_brand
.fail_read_mdat:
    inc     qword [rel failed]

.av1_brand:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    mov     rdx, box_desc
    mov     ecx, MP4_BRAND_AV01
    call    er_mp4_ftyp_has_brand
    cmp     eax, 1
    jne     .fail_av1_brand
    test    edx, edx
    jnz     .fail_av1_brand
    inc     qword [rel passed]
    jmp     .is_av1
.fail_av1_brand:
    inc     qword [rel failed]

.is_av1:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    call    er_mp4_is_av1
    cmp     eax, 1
    jne     .fail_is_av1
    test    edx, edx
    jnz     .fail_is_av1
    inc     qword [rel passed]
    jmp     .no_av1
.fail_is_av1:
    inc     qword [rel failed]

.no_av1:
    mov     rdi, mp4_no_av1
    mov     esi, mp4_no_av1_len
    call    er_mp4_is_av1
    test    eax, eax
    jnz     .fail_no_av1
    test    edx, edx
    jnz     .fail_no_av1
    inc     qword [rel passed]
    jmp     .find_mdat
.fail_no_av1:
    inc     qword [rel failed]

.find_mdat:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     ecx, MP4_BOX_TYPE_MDAT
    mov     r8, box_desc
    call    er_mp4_find_box
    cmp     eax, 48
    jne     .fail_find_mdat
    test    edx, edx
    jnz     .fail_find_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MDAT
    jne     .fail_find_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 40
    jne     .fail_find_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_find_mdat
    inc     qword [rel passed]
    jmp     .find_missing
.fail_find_mdat:
    inc     qword [rel failed]

.find_missing:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     ecx, MP4_BOX_TYPE_MOOV
    mov     r8, box_desc
    call    er_mp4_find_box
    test    eax, eax
    jnz     .fail_find_missing
    cmp     edx, ERROR_NO_DATA
    jne     .fail_find_missing
    inc     qword [rel passed]
    jmp     .find_child
.fail_find_missing:
    inc     qword [rel failed]

.find_child:
    mov     rdi, mp4_parent
    mov     esi, mp4_parent_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_find_child
    mov     rdi, mp4_parent
    mov     esi, mp4_parent_len
    mov     rdx, box_desc
    mov     ecx, MP4_BOX_TYPE_MDAT
    mov     r8, entry_desc
    call    er_mp4_find_child_box
    cmp     eax, mp4_parent_len
    jne     .fail_find_child
    test    edx, edx
    jnz     .fail_find_child
    cmp     dword [rel entry_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MDAT
    jne     .fail_find_child
    cmp     dword [rel entry_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 24
    jne     .fail_find_child
    cmp     dword [rel entry_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_find_child
    inc     qword [rel passed]
    jmp     .child_stsd
.fail_find_child:
    inc     qword [rel failed]

.child_stsd:
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     edx, 8
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_child_stsd
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     rdx, box_desc
    mov     rcx, entry_desc
    call    er_mp4_stsd_first_entry
    cmp     eax, mp4_sample_len
    jne     .fail_child_stsd
    test    edx, edx
    jnz     .fail_child_stsd
    cmp     dword [rel entry_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_AV01
    jne     .fail_child_stsd
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     rdx, entry_desc
    mov     rcx, visual_desc
    call    er_mp4_visual_sample_entry_decode
    cmp     eax, 1920
    jne     .fail_child_stsd
    test    edx, edx
    jnz     .fail_child_stsd
    cmp     dword [rel visual_desc + MP4_VISUAL_SAMPLE_ENTRY_DESC_DATA_REF], 1
    jne     .fail_child_stsd
    cmp     dword [rel visual_desc + MP4_VISUAL_SAMPLE_ENTRY_DESC_WIDTH], 1920
    jne     .fail_child_stsd
    cmp     dword [rel visual_desc + MP4_VISUAL_SAMPLE_ENTRY_DESC_HEIGHT], 818
    jne     .fail_child_stsd
    inc     qword [rel passed]
    jmp     .entry_av1c
.fail_child_stsd:
    inc     qword [rel failed]

.entry_av1c:
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     rdx, entry_desc
    mov     ecx, MP4_BOX_TYPE_AV1C
    mov     r8, box_desc
    call    er_mp4_sample_entry_find_child
    cmp     eax, mp4_sample_len
    jne     .fail_entry_av1c
    test    edx, edx
    jnz     .fail_entry_av1c
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_AV1C
    jne     .fail_entry_av1c
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_entry_av1c
    inc     qword [rel passed]
    jmp     .decode_av1c
.fail_entry_av1c:
    inc     qword [rel failed]

.decode_av1c:
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     rdx, box_desc
    mov     rcx, av1c_desc
    call    er_mp4_av1c_decode
    cmp     eax, 4
    jne     .fail_decode_av1c
    test    edx, edx
    jnz     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_PROFILE], 0
    jne     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_LEVEL], 8
    jne     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_SUBSAMPLING_X], 1
    jne     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_SUBSAMPLING_Y], 1
    jne     .fail_decode_av1c
    cmp     dword [rel av1c_desc + MP4_AV1C_DESC_CONFIG_OBU_OFFSET], 122
    jne     .fail_decode_av1c
    cmp     dword [rel av1c_desc + MP4_AV1C_DESC_CONFIG_OBU_LEN], 4
    jne     .fail_decode_av1c
    inc     qword [rel passed]
    jmp     .media_headers
.fail_decode_av1c:
    inc     qword [rel failed]

.media_headers:
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_media_headers
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MDHD
    jne     .fail_media_headers
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     rdx, box_desc
    mov     rcx, mdhd_desc
    call    er_mp4_mdhd_decode
    cmp     eax, 30000
    jne     .fail_media_headers
    test    edx, edx
    jnz     .fail_media_headers
    cmp     dword [rel mdhd_desc + MP4_MDHD_DESC_TIMESCALE], 30000
    jne     .fail_media_headers
    cmp     dword [rel mdhd_desc + MP4_MDHD_DESC_DURATION], 300000
    jne     .fail_media_headers
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     edx, mp4_headers_tkhd
    mov     rcx, entry_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_media_headers
    cmp     dword [rel entry_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_TKHD
    jne     .fail_media_headers
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     rdx, entry_desc
    mov     rcx, tkhd_desc
    call    er_mp4_tkhd_decode
    cmp     eax, 1920
    jne     .fail_media_headers
    test    edx, edx
    jnz     .fail_media_headers
    cmp     dword [rel tkhd_desc + MP4_TKHD_DESC_DURATION], 300000
    jne     .fail_media_headers
    cmp     dword [rel tkhd_desc + MP4_TKHD_DESC_WIDTH], 1920
    jne     .fail_media_headers
    cmp     dword [rel tkhd_desc + MP4_TKHD_DESC_HEIGHT], 818
    jne     .fail_media_headers
    inc     qword [rel passed]
    jmp     .media_header_v1
.fail_media_headers:
    inc     qword [rel failed]

.media_header_v1:
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     edx, mp4_headers_mdhd_v1
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_media_header_v1
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     rdx, box_desc
    mov     rcx, mdhd_desc
    call    er_mp4_mdhd_decode
    cmp     eax, 30000
    jne     .fail_media_header_v1
    test    edx, edx
    jnz     .fail_media_header_v1
    cmp     dword [rel mdhd_desc + MP4_MDHD_DESC_DURATION], 300000
    jne     .fail_media_header_v1
    inc     qword [rel passed]
    jmp     .handler_video
.fail_media_header_v1:
    inc     qword [rel failed]

.handler_video:
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     edx, mp4_headers_hdlr_video
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_handler_video
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_HDLR
    jne     .fail_handler_video
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     rdx, box_desc
    mov     rcx, hdlr_desc
    call    er_mp4_hdlr_decode
    cmp     eax, MP4_HANDLER_TYPE_VIDE
    jne     .fail_handler_video
    test    edx, edx
    jnz     .fail_handler_video
    cmp     dword [rel hdlr_desc + MP4_HDLR_DESC_HANDLER_TYPE], MP4_HANDLER_TYPE_VIDE
    jne     .fail_handler_video
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     rdx, box_desc
    call    er_mp4_hdlr_is_video
    cmp     eax, 1
    jne     .fail_handler_video
    test    edx, edx
    jnz     .fail_handler_video
    inc     qword [rel passed]
    jmp     .handler_audio
.fail_handler_video:
    inc     qword [rel failed]

.handler_audio:
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     edx, mp4_headers_hdlr_audio
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_handler_audio
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     rdx, box_desc
    mov     rcx, hdlr_desc
    call    er_mp4_hdlr_decode
    cmp     eax, MP4_HANDLER_TYPE_SOUN
    jne     .fail_handler_audio
    test    edx, edx
    jnz     .fail_handler_audio
    mov     rdi, mp4_headers
    mov     esi, mp4_headers_len
    mov     rdx, box_desc
    call    er_mp4_hdlr_is_video
    test    eax, eax
    jnz     .fail_handler_audio
    test    edx, edx
    jnz     .fail_handler_audio
    inc     qword [rel passed]
    jmp     .sample_tables
.fail_handler_audio:
    inc     qword [rel failed]

.sample_tables:
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rax, [rel box_desc]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STSZ_DESC], rax
    mov     rax, [rel box_desc + 8]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STSZ_DESC + 8], rax
    mov     rax, [rel box_desc + 16]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STSZ_DESC + 16], rax
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     rdx, box_desc
    call    er_mp4_stsz_sample_count
    cmp     eax, 3
    jne     .fail_sample_tables
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     rdx, box_desc
    xor     ecx, ecx
    call    er_mp4_stsz_sample_size
    cmp     eax, 1000
    jne     .fail_sample_tables
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     rdx, box_desc
    mov     ecx, 2
    call    er_mp4_stsz_sample_size
    cmp     eax, 3000
    jne     .fail_sample_tables
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     edx, mp4_tables_stco
    mov     rcx, entry_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     rdx, entry_desc
    mov     ecx, 1
    call    er_mp4_stco_chunk_offset
    cmp     eax, 0x2000
    jne     .fail_sample_tables
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     rdx, entry_desc
    call    er_mp4_stco_chunk_count
    cmp     eax, 2
    jne     .fail_sample_tables
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rax, [rel entry_desc]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STCO_DESC], rax
    mov     rax, [rel entry_desc + 8]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STCO_DESC + 8], rax
    mov     rax, [rel entry_desc + 16]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STCO_DESC + 16], rax
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     edx, mp4_tables_stsc
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_sample_tables
    mov     rax, [rel box_desc]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STSC_DESC], rax
    mov     rax, [rel box_desc + 8]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STSC_DESC + 8], rax
    mov     rax, [rel box_desc + 16]
    mov     [rel tables_desc + MP4_SAMPLE_TABLES_STSC_DESC + 16], rax
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     rdx, box_desc
    mov     ecx, 1
    mov     r8, stsc_desc
    call    er_mp4_stsc_entry
    cmp     eax, 2
    jne     .fail_sample_tables
    test    edx, edx
    jnz     .fail_sample_tables
    cmp     dword [rel stsc_desc + MP4_STSC_DESC_FIRST_CHUNK], 4
    jne     .fail_sample_tables
    cmp     dword [rel stsc_desc + MP4_STSC_DESC_SAMPLES_PER_CHUNK], 2
    jne     .fail_sample_tables
    cmp     dword [rel stsc_desc + MP4_STSC_DESC_SAMPLE_DESC_INDEX], 1
    jne     .fail_sample_tables
    inc     qword [rel passed]
    jmp     .co64_tables
.fail_sample_tables:
    inc     qword [rel failed]

.co64_tables:
    mov     rdi, mp4_co64_tables
    mov     esi, mp4_co64_tables_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_co64_tables
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    jne     .fail_co64_tables
    mov     rdi, mp4_co64_tables
    mov     esi, mp4_co64_tables_len
    mov     rdx, box_desc
    call    er_mp4_co64_chunk_count
    cmp     eax, 2
    jne     .fail_co64_tables
    test    edx, edx
    jnz     .fail_co64_tables
    mov     rdi, mp4_co64_tables
    mov     esi, mp4_co64_tables_len
    mov     rdx, box_desc
    mov     ecx, 1
    call    er_mp4_co64_chunk_offset
    cmp     eax, 0x4000
    jne     .fail_co64_tables
    test    edx, edx
    jnz     .fail_co64_tables
    mov     rdi, mp4_co64_tables
    mov     esi, mp4_co64_tables_len
    mov     rdx, box_desc
    mov     ecx, 2
    call    er_mp4_co64_chunk_offset
    test    eax, eax
    jnz     .fail_co64_tables
    cmp     edx, ERROR_NO_DATA
    jne     .fail_co64_tables
    mov     rdi, mp4_co64_tables
    mov     esi, mp4_co64_tables_len
    mov     edx, mp4_co64_tables_high
    mov     rcx, entry_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_co64_tables
    mov     rdi, mp4_co64_tables
    mov     esi, mp4_co64_tables_len
    mov     rdx, entry_desc
    xor     ecx, ecx
    call    er_mp4_co64_chunk_offset
    test    eax, eax
    jnz     .fail_co64_tables
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_co64_tables
    inc     qword [rel passed]
    jmp     .time_tables
.fail_co64_tables:
    inc     qword [rel failed]

.time_tables:
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_time_tables
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STTS
    jne     .fail_time_tables
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, box_desc
    mov     ecx, 1
    mov     r8, stts_desc
    call    er_mp4_stts_entry
    cmp     eax, 2
    jne     .fail_time_tables
    test    edx, edx
    jnz     .fail_time_tables
    cmp     dword [rel stts_desc + MP4_STTS_DESC_SAMPLE_COUNT], 3
    jne     .fail_time_tables
    cmp     dword [rel stts_desc + MP4_STTS_DESC_SAMPLE_DELTA], 500
    jne     .fail_time_tables
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, box_desc
    xor     ecx, ecx
    mov     r8, sample_time
    call    er_mp4_stts_sample_time
    test    eax, eax
    jnz     .fail_time_tables
    test    edx, edx
    jnz     .fail_time_tables
    cmp     dword [rel sample_time + MP4_SAMPLE_TIME_DTS], 0
    jne     .fail_time_tables
    cmp     dword [rel sample_time + MP4_SAMPLE_TIME_DURATION], 1000
    jne     .fail_time_tables
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, box_desc
    mov     ecx, 2
    mov     r8, sample_time
    call    er_mp4_stts_sample_time
    cmp     eax, 2000
    jne     .fail_time_tables
    test    edx, edx
    jnz     .fail_time_tables
    cmp     dword [rel sample_time + MP4_SAMPLE_TIME_DTS], 2000
    jne     .fail_time_tables
    cmp     dword [rel sample_time + MP4_SAMPLE_TIME_DURATION], 500
    jne     .fail_time_tables
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, box_desc
    mov     ecx, 4
    mov     r8, sample_time
    call    er_mp4_stts_sample_time
    cmp     eax, 3000
    jne     .fail_time_tables
    test    edx, edx
    jnz     .fail_time_tables
    cmp     dword [rel sample_time + MP4_SAMPLE_TIME_DURATION], 500
    jne     .fail_time_tables
    inc     qword [rel passed]
    jmp     .time_table_oob
.fail_time_tables:
    inc     qword [rel failed]

.time_table_oob:
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, box_desc
    mov     ecx, 5
    mov     r8, sample_time
    call    er_mp4_stts_sample_time
    test    eax, eax
    jnz     .fail_time_table_oob
    cmp     edx, ERROR_NO_DATA
    jne     .fail_time_table_oob
    inc     qword [rel passed]
    jmp     .composition_table
.fail_time_table_oob:
    inc     qword [rel failed]

.composition_table:
    mov     rdi, mp4_ctts_tables
    mov     esi, mp4_ctts_tables_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_composition_table
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CTTS
    jne     .fail_composition_table
    mov     rdi, mp4_ctts_tables
    mov     esi, mp4_ctts_tables_len
    mov     rdx, box_desc
    mov     ecx, 1
    mov     r8, ctts_desc
    call    er_mp4_ctts_entry
    cmp     eax, 2
    jne     .fail_composition_table
    test    edx, edx
    jnz     .fail_composition_table
    cmp     dword [rel ctts_desc + MP4_CTTS_DESC_SAMPLE_COUNT], 3
    jne     .fail_composition_table
    cmp     dword [rel ctts_desc + MP4_CTTS_DESC_SAMPLE_OFFSET], 1000
    jne     .fail_composition_table
    mov     rdi, mp4_ctts_tables
    mov     esi, mp4_ctts_tables_len
    mov     rdx, box_desc
    xor     ecx, ecx
    mov     r8, ctts_desc
    call    er_mp4_ctts_sample_offset
    cmp     eax, 500
    jne     .fail_composition_table
    test    edx, edx
    jnz     .fail_composition_table
    cmp     dword [rel ctts_desc + MP4_CTTS_DESC_SAMPLE_OFFSET], 500
    jne     .fail_composition_table
    mov     rdi, mp4_ctts_tables
    mov     esi, mp4_ctts_tables_len
    mov     rdx, box_desc
    mov     ecx, 4
    mov     r8, ctts_desc
    call    er_mp4_ctts_sample_offset
    cmp     eax, 1000
    jne     .fail_composition_table
    test    edx, edx
    jnz     .fail_composition_table
    mov     eax, [rel sample_time + MP4_SAMPLE_TIME_DTS]
    add     eax, [rel ctts_desc + MP4_CTTS_DESC_SAMPLE_OFFSET]
    cmp     eax, 4000
    jne     .fail_composition_table
    inc     qword [rel passed]
    jmp     .composition_table_v1
.fail_composition_table:
    inc     qword [rel failed]

.composition_table_v1:
    mov     rdi, mp4_ctts_tables
    mov     esi, mp4_ctts_tables_len
    mov     edx, mp4_ctts_tables_v1
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_composition_table_v1
    mov     rdi, mp4_ctts_tables
    mov     esi, mp4_ctts_tables_len
    mov     rdx, box_desc
    mov     ecx, 2
    mov     r8, ctts_desc
    call    er_mp4_ctts_sample_offset
    cmp     eax, -100
    jne     .fail_composition_table_v1
    test    edx, edx
    jnz     .fail_composition_table_v1
    cmp     dword [rel ctts_desc + MP4_CTTS_DESC_SAMPLE_OFFSET], -100
    jne     .fail_composition_table_v1
    inc     qword [rel passed]
    jmp     .composition_table_oob
.fail_composition_table_v1:
    inc     qword [rel failed]

.composition_table_oob:
    mov     rdi, mp4_ctts_tables
    mov     esi, mp4_ctts_tables_len
    mov     rdx, box_desc
    mov     ecx, 4
    mov     r8, ctts_desc
    call    er_mp4_ctts_sample_offset
    test    eax, eax
    jnz     .fail_composition_table_oob
    cmp     edx, ERROR_NO_DATA
    jne     .fail_composition_table_oob
    inc     qword [rel passed]
    jmp     .sync_table
.fail_composition_table_oob:
    inc     qword [rel failed]

.sync_table:
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     edx, mp4_time_tables_stss
    mov     rcx, entry_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_sync_table
    cmp     dword [rel entry_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSS
    jne     .fail_sync_table
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, entry_desc
    call    er_mp4_stss_sync_count
    cmp     eax, 3
    jne     .fail_sync_table
    test    edx, edx
    jnz     .fail_sync_table
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, entry_desc
    xor     ecx, ecx
    call    er_mp4_stss_is_sync_sample
    cmp     eax, 1
    jne     .fail_sync_table
    test    edx, edx
    jnz     .fail_sync_table
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, entry_desc
    mov     ecx, 1
    call    er_mp4_stss_is_sync_sample
    test    eax, eax
    jnz     .fail_sync_table
    test    edx, edx
    jnz     .fail_sync_table
    mov     rdi, mp4_time_tables
    mov     esi, mp4_time_tables_len
    mov     rdx, entry_desc
    mov     ecx, 4
    call    er_mp4_stss_is_sync_sample
    cmp     eax, 1
    jne     .fail_sync_table
    test    edx, edx
    jnz     .fail_sync_table
    inc     qword [rel passed]
    jmp     .sample_table_oob
.fail_sync_table:
    inc     qword [rel failed]

.sample_table_oob:
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    lea     rdx, [rel tables_desc + MP4_SAMPLE_TABLES_STSC_DESC]
    mov     ecx, 2
    mov     r8, stsc_desc
    call    er_mp4_stsc_entry
    test    eax, eax
    jnz     .fail_sample_table_oob
    cmp     edx, ERROR_NO_DATA
    jne     .fail_sample_table_oob
    inc     qword [rel passed]
    jmp     .sample_locate
.fail_sample_table_oob:
    inc     qword [rel failed]

.sample_locate:
    mov     rdi, mp4_tables
    mov     esi, mp4_tables_len
    mov     rdx, tables_desc
    mov     ecx, 2
    mov     r8, sample_desc
    call    er_mp4_sample_locate
    cmp     eax, 0x1bb8
    jne     .fail_sample_locate
    test    edx, edx
    jnz     .fail_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 0x1bb8
    jne     .fail_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN], 3000
    jne     .fail_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_CHUNK_INDEX], 0
    jne     .fail_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_INDEX_IN_CHUNK], 2
    jne     .fail_sample_locate
    inc     qword [rel passed]
    jmp     .sample_locate_co64
.fail_sample_locate:
    inc     qword [rel failed]

.sample_locate_co64:
    mov     rdi, mp4_stbl_co64_locate
    mov     esi, mp4_stbl_co64_locate_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_sample_locate_co64
    mov     rdi, mp4_stbl_co64_locate
    mov     esi, mp4_stbl_co64_locate_len
    mov     rdx, box_desc
    mov     rcx, tables_desc
    call    er_mp4_sample_tables_find
    cmp     eax, MP4_SAMPLE_TABLES_SIZE
    jne     .fail_sample_locate_co64
    test    edx, edx
    jnz     .fail_sample_locate_co64
    cmp     dword [rel tables_desc + MP4_SAMPLE_TABLES_STSZ_DESC + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSZ
    jne     .fail_sample_locate_co64
    cmp     dword [rel tables_desc + MP4_SAMPLE_TABLES_STCO_DESC + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    jne     .fail_sample_locate_co64
    cmp     dword [rel tables_desc + MP4_SAMPLE_TABLES_STSC_DESC + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSC
    jne     .fail_sample_locate_co64
    mov     rdi, mp4_stbl_co64_locate
    mov     esi, mp4_stbl_co64_locate_len
    mov     rdx, tables_desc
    mov     ecx, 2
    mov     r8, sample_desc
    call    er_mp4_sample_locate
    cmp     eax, 0x3bb8
    jne     .fail_sample_locate_co64
    test    edx, edx
    jnz     .fail_sample_locate_co64
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 0x3bb8
    jne     .fail_sample_locate_co64
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN], 3000
    jne     .fail_sample_locate_co64
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_CHUNK_INDEX], 0
    jne     .fail_sample_locate_co64
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_INDEX_IN_CHUNK], 2
    jne     .fail_sample_locate_co64
    inc     qword [rel passed]
    jmp     .video_stbl_find
.fail_sample_locate_co64:
    inc     qword [rel failed]

.video_stbl_find:
    mov     rdi, mp4_moov_video_stbl
    mov     esi, mp4_moov_video_stbl_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_video_stbl_find
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MOOV
    jne     .fail_video_stbl_find
    mov     rdi, mp4_moov_video_stbl
    mov     esi, mp4_moov_video_stbl_len
    mov     rdx, box_desc
    mov     rcx, entry_desc
    call    er_mp4_video_stbl_find
    cmp     eax, mp4_moov_video_stbl_len
    jne     .fail_video_stbl_find
    test    edx, edx
    jnz     .fail_video_stbl_find
    cmp     dword [rel entry_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STBL
    jne     .fail_video_stbl_find
    cmp     dword [rel entry_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 122
    jne     .fail_video_stbl_find
    cmp     dword [rel entry_desc + MP4_BOX_DESC_PAYLOAD_LEN], 104
    jne     .fail_video_stbl_find
    mov     rdi, mp4_moov_video_stbl
    mov     esi, mp4_moov_video_stbl_len
    mov     rdx, box_desc
    mov     rcx, tables_desc
    call    er_mp4_video_sample_tables_find
    cmp     eax, MP4_SAMPLE_TABLES_SIZE
    jne     .fail_video_stbl_find
    test    edx, edx
    jnz     .fail_video_stbl_find
    cmp     dword [rel tables_desc + MP4_SAMPLE_TABLES_STCO_DESC + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    jne     .fail_video_stbl_find
    mov     rdi, mp4_moov_video_stbl
    mov     esi, mp4_moov_video_stbl_len
    mov     rdx, tables_desc
    mov     ecx, 2
    mov     r8, sample_desc
    call    er_mp4_sample_locate
    cmp     eax, 0x3bb8
    jne     .fail_video_stbl_find
    test    edx, edx
    jnz     .fail_video_stbl_find
    inc     qword [rel passed]
    jmp     .file_video_sample_tables
.fail_video_stbl_find:
    inc     qword [rel failed]

.file_video_sample_tables:
    mov     rdi, mp4_file_video_stbl
    mov     esi, mp4_file_video_stbl_len
    mov     rdx, tables_desc
    call    er_mp4_file_video_sample_tables_find
    cmp     eax, MP4_SAMPLE_TABLES_SIZE
    jne     .fail_file_video_sample_tables
    test    edx, edx
    jnz     .fail_file_video_sample_tables
    cmp     dword [rel tables_desc + MP4_SAMPLE_TABLES_STCO_DESC + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    jne     .fail_file_video_sample_tables
    mov     rdi, mp4_file_video_stbl
    mov     esi, mp4_file_video_stbl_len
    mov     rdx, tables_desc
    mov     ecx, 2
    mov     r8, sample_desc
    call    er_mp4_sample_locate
    cmp     eax, 0x3bb8
    jne     .fail_file_video_sample_tables
    test    edx, edx
    jnz     .fail_file_video_sample_tables
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 0x3bb8
    jne     .fail_file_video_sample_tables
    inc     qword [rel passed]
    jmp     .file_video_sample_locate
.fail_file_video_sample_tables:
    inc     qword [rel failed]

.file_video_sample_locate:
    mov     rdi, mp4_file_video_stbl
    mov     esi, mp4_file_video_stbl_len
    mov     edx, 2
    mov     rcx, sample_desc
    call    er_mp4_file_video_sample_locate
    cmp     eax, 0x3bb8
    jne     .fail_file_video_sample_locate
    test    edx, edx
    jnz     .fail_file_video_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 0x3bb8
    jne     .fail_file_video_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN], 3000
    jne     .fail_file_video_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_CHUNK_INDEX], 0
    jne     .fail_file_video_sample_locate
    cmp     dword [rel sample_desc + MP4_SAMPLE_DESC_INDEX_IN_CHUNK], 2
    jne     .fail_file_video_sample_locate
    inc     qword [rel passed]
    jmp     .sample_locate_oob
.fail_file_video_sample_locate:
    inc     qword [rel failed]

.sample_locate_oob:
    mov     rdi, mp4_file_video_stbl
    mov     esi, mp4_file_video_stbl_len
    mov     rdx, tables_desc
    mov     ecx, 3
    mov     r8, sample_desc
    call    er_mp4_sample_locate
    test    eax, eax
    jnz     .fail_sample_locate_oob
    cmp     edx, ERROR_NO_DATA
    jne     .fail_sample_locate_oob
    inc     qword [rel passed]
    jmp     .file_video_sample_payload
.fail_sample_locate_oob:
    inc     qword [rel failed]

.file_video_sample_payload:
    mov     rdi, mp4_file_video_payload
    mov     esi, mp4_file_video_payload_len
    mov     edx, 1
    mov     rcx, payload_desc
    call    er_mp4_file_video_sample_payload
    cmp     eax, 0xc1
    jne     .fail_file_video_sample_payload
    test    edx, edx
    jnz     .fail_file_video_sample_payload
    cmp     dword [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 0xc1
    jne     .fail_file_video_sample_payload
    cmp     dword [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN], 5
    jne     .fail_file_video_sample_payload
    cmp     dword [rel payload_desc + MP4_SAMPLE_DESC_CHUNK_INDEX], 0
    jne     .fail_file_video_sample_payload
    cmp     dword [rel payload_desc + MP4_SAMPLE_DESC_INDEX_IN_CHUNK], 1
    jne     .fail_file_video_sample_payload
    cmp     byte [rel mp4_file_video_payload + 0xc1], 0x0a
    jne     .fail_file_video_sample_payload
    cmp     byte [rel mp4_file_video_payload + 0xc5], 0x33
    jne     .fail_file_video_sample_payload
    inc     qword [rel passed]
    jmp     .file_video_sample_obu_scan
.fail_file_video_sample_payload:
    inc     qword [rel failed]

.file_video_sample_obu_scan:
    mov     rdi, mp4_file_video_payload
    mov     esi, mp4_file_video_payload_len
    mov     edx, 2
    mov     rcx, obu_stats
    call    er_mp4_file_video_sample_obu_scan
    cmp     eax, 1
    jne     .fail_file_video_sample_obu_scan
    test    edx, edx
    jnz     .fail_file_video_sample_obu_scan
    cmp     dword [rel obu_stats + AV1_OBU_STATS_TOTAL], 1
    jne     .fail_file_video_sample_obu_scan
    cmp     dword [rel obu_stats + AV1_OBU_STATS_TYPE_COUNTS + AV1_OBU_TYPE_FRAME_HEADER * 4], 1
    jne     .fail_file_video_sample_obu_scan
    cmp     dword [rel obu_stats + AV1_OBU_STATS_TYPE_COUNTS + AV1_OBU_TYPE_SEQUENCE_HEADER * 4], 0
    jne     .fail_file_video_sample_obu_scan
    inc     qword [rel passed]
    jmp     .file_video_sample_obu_route
.fail_file_video_sample_obu_scan:
    inc     qword [rel failed]

.file_video_sample_obu_route:
    mov     rdi, mp4_file_video_payload
    mov     esi, mp4_file_video_payload_len
    mov     edx, 2
    mov     rcx, obu_route
    call    er_mp4_file_video_sample_obu_route
    cmp     eax, 1
    jne     .fail_file_video_sample_obu_route
    test    edx, edx
    jnz     .fail_file_video_sample_obu_route
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_STATS + AV1_OBU_STATS_TOTAL], 1
    jne     .fail_file_video_sample_obu_route
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_STATS + AV1_OBU_STATS_TYPE_COUNTS + AV1_OBU_TYPE_FRAME_HEADER * 4], 1
    jne     .fail_file_video_sample_obu_route
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_FRAME_HEADER_OFFSET], 2
    jne     .fail_file_video_sample_obu_route
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_FRAME_HEADER_LEN], 4
    jne     .fail_file_video_sample_obu_route
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_SEQUENCE_OFFSET], 0
    jne     .fail_file_video_sample_obu_route
    inc     qword [rel passed]
    jmp     .sample_payload
.fail_file_video_sample_obu_route:
    inc     qword [rel failed]

.sample_payload:
    mov     rdi, mp4_mdat
    mov     esi, mp4_mdat_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_sample_payload
    mov     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 32
    mov     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN], 13
    mov     dword [rel sample_desc + MP4_SAMPLE_DESC_CHUNK_INDEX], 0
    mov     dword [rel sample_desc + MP4_SAMPLE_DESC_INDEX_IN_CHUNK], 0
    mov     rdi, mp4_mdat
    mov     esi, mp4_mdat_len
    mov     rdx, box_desc
    mov     rcx, sample_desc
    mov     r8, payload_desc
    call    er_mp4_sample_payload
    cmp     eax, 32
    jne     .fail_sample_payload
    test    edx, edx
    jnz     .fail_sample_payload
    cmp     dword [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 32
    jne     .fail_sample_payload
    cmp     dword [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN], 13
    jne     .fail_sample_payload
    cmp     byte [rel mp4_mdat + 32], 0x0a
    jne     .fail_sample_payload
    cmp     byte [rel mp4_mdat + 44], 0xee
    jne     .fail_sample_payload
    inc     qword [rel passed]
    jmp     .sample_payload_obu
.fail_sample_payload:
    inc     qword [rel failed]

.sample_payload_obu:
    mov     eax, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET]
    lea     rdi, [rel mp4_mdat + rax]
    mov     esi, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN]
    mov     rdx, obu_desc
    call    er_av1_obu_decode_unit
    cmp     eax, 4
    jne     .fail_sample_payload_obu
    test    edx, edx
    jnz     .fail_sample_payload_obu
    cmp     byte [rel obu_desc + AV1_OBU_DESC_TYPE], AV1_OBU_TYPE_SEQUENCE_HEADER
    jne     .fail_sample_payload_obu
    cmp     byte [rel obu_desc + AV1_OBU_DESC_HAS_SIZE], 1
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_desc + AV1_OBU_DESC_PAYLOAD_OFFSET], 2
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_desc + AV1_OBU_DESC_PAYLOAD_LEN], 2
    jne     .fail_sample_payload_obu
    mov     eax, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET]
    lea     rdi, [rel mp4_mdat + rax]
    mov     esi, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN]
    call    er_av1_obu_count_units
    cmp     eax, 4
    jne     .fail_sample_payload_obu
    test    edx, edx
    jnz     .fail_sample_payload_obu
    mov     eax, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET]
    lea     rdi, [rel mp4_mdat + rax]
    mov     esi, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN]
    mov     rdx, obu_stats
    call    er_av1_obu_scan_units
    cmp     eax, 4
    jne     .fail_sample_payload_obu
    test    edx, edx
    jnz     .fail_sample_payload_obu
    cmp     dword [rel obu_stats + AV1_OBU_STATS_TYPE_COUNTS + AV1_OBU_TYPE_SEQUENCE_HEADER * 4], 1
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_stats + AV1_OBU_STATS_TYPE_COUNTS + AV1_OBU_TYPE_FRAME_HEADER * 4], 1
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_stats + AV1_OBU_STATS_TYPE_COUNTS + AV1_OBU_TYPE_TILE_GROUP * 4], 1
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_stats + AV1_OBU_STATS_TYPE_COUNTS + AV1_OBU_TYPE_FRAME * 4], 1
    jne     .fail_sample_payload_obu
    mov     eax, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET]
    lea     rdi, [rel mp4_mdat + rax]
    mov     esi, [rel payload_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN]
    mov     rdx, obu_route
    call    er_av1_obu_route_sample
    cmp     eax, 4
    jne     .fail_sample_payload_obu
    test    edx, edx
    jnz     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_SEQUENCE_OFFSET], 2
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_SEQUENCE_LEN], 2
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_FRAME_HEADER_OFFSET], 6
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_FRAME_HEADER_LEN], 1
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_TILE_GROUP_OFFSET], 9
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_TILE_GROUP_LEN], 1
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_FRAME_OFFSET], 12
    jne     .fail_sample_payload_obu
    cmp     dword [rel obu_route + AV1_OBU_ROUTE_FRAME_LEN], 1
    jne     .fail_sample_payload_obu
    inc     qword [rel passed]
    jmp     .sample_payload_oob
.fail_sample_payload_obu:
    inc     qword [rel failed]

.sample_payload_oob:
    mov     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], 60
    mov     dword [rel sample_desc + MP4_SAMPLE_DESC_PAYLOAD_LEN], 8
    mov     rdi, mp4_mdat
    mov     esi, mp4_mdat_len
    mov     rdx, box_desc
    mov     rcx, sample_desc
    mov     r8, payload_desc
    call    er_mp4_sample_payload
    test    eax, eax
    jnz     .fail_sample_payload_oob
    cmp     edx, ERROR_NO_DATA
    jne     .fail_sample_payload_oob
    inc     qword [rel passed]
    jmp     .large_box
.fail_sample_payload_oob:
    inc     qword [rel failed]

.large_box:
    mov     rdi, mp4_large
    mov     esi, mp4_large_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, 24
    jne     .fail_large_box
    test    edx, edx
    jnz     .fail_large_box
    cmp     dword [rel box_desc + MP4_BOX_DESC_HEADER_SIZE], MP4_BOX_LARGE_HEADER_SIZE
    jne     .fail_large_box
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_large_box
    inc     qword [rel passed]
    jmp     .to_eof
.fail_large_box:
    inc     qword [rel failed]

.to_eof:
    mov     rdi, mp4_to_eof
    mov     esi, mp4_to_eof_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, mp4_to_eof_len
    jne     .fail_to_eof
    test    edx, edx
    jnz     .fail_to_eof
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 5
    jne     .fail_to_eof
    inc     qword [rel passed]
    jmp     .truncated
.fail_to_eof:
    inc     qword [rel failed]

.truncated:
    mov     rdi, mp4_trunc
    mov     esi, mp4_trunc_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    eax, eax
    jnz     .fail_truncated
    cmp     edx, ERROR_NO_DATA
    jne     .fail_truncated
    inc     qword [rel passed]
    jmp     .invalid
.fail_truncated:
    inc     qword [rel failed]

.invalid:
    xor     rdi, rdi
    mov     esi, mp4_av1_len
    call    er_mp4_is_av1
    test    eax, eax
    jnz     .fail_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_invalid
    inc     qword [rel passed]
    jmp     .done
.fail_invalid:
    inc     qword [rel failed]

.done:
    cmp     qword [rel failed], 0
    je      .exit_ok
    mov     rdi, 1
    mov     rsi, failed
    mov     rdx, 8
    mov     rax, 1
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall
.exit_ok:
    mov     rax, 60
    xor     rdi, rdi
    syscall
