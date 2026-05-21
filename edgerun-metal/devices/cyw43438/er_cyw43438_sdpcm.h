#ifndef ER_CYW43438_SDPCM_H
#define ER_CYW43438_SDPCM_H

/*
 * Purpose: define the CYW43438 SDPCM frame header used on SDIO function 2.
 * Intention: keep wireless update frames on the firmware-owned data path
 * instead of the UART-only erwire bootstrap path.
 */

#include "er_types.h"
#include "er_net_frame.h"

#define ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES 4u
#define ER_CYW43438_SDPCM_SOFTWARE_HEADER_BYTES 8u
#define ER_CYW43438_SDPCM_HEADER_BYTES \
  (ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES + \
   ER_CYW43438_SDPCM_SOFTWARE_HEADER_BYTES)
#define ER_CYW43438_SDPCM_HEADER_CHECK_VALUE 0xffffu
#define ER_CYW43438_SDPCM_FRAME_LEN_MAX 0xffffu
#define ER_CYW43438_SDPCM_PAYLOAD_MAX \
  (ER_CYW43438_SDPCM_FRAME_LEN_MAX - ER_CYW43438_SDPCM_HEADER_BYTES)
#define ER_CYW43438_SDPCM_SEQUENCE_MASK 0x000000ffu
#define ER_CYW43438_SDPCM_CHANNEL_MASK 0x00000f00u
#define ER_CYW43438_SDPCM_CHANNEL_SHIFT 8u
#define ER_CYW43438_SDPCM_NEXT_LENGTH_MASK 0x00ff0000u
#define ER_CYW43438_SDPCM_NEXT_LENGTH_SHIFT 16u
#define ER_CYW43438_SDPCM_DATA_OFFSET_MASK 0xff000000u
#define ER_CYW43438_SDPCM_DATA_OFFSET_SHIFT 24u
#define ER_CYW43438_SDPCM_FLOW_CONTROL_MASK 0x000000ffu
#define ER_CYW43438_SDPCM_WINDOW_MASK 0x0000ff00u
#define ER_CYW43438_SDPCM_WINDOW_SHIFT 8u
#define ER_CYW43438_SDPCM_CHANNEL_CONTROL 0u
#define ER_CYW43438_SDPCM_CHANNEL_EVENT 1u
#define ER_CYW43438_SDPCM_CHANNEL_DATA 2u
#define ER_CYW43438_SDPCM_CHANNEL_GLOM 3u
#define ER_CYW43438_SDPCM_CHANNEL_TEST 15u
#define ER_CYW43438_SDPCM_BROADCAST_BYTE 0xffu
#define ER_CYW43438_BCDC_HEADER_BYTES 4u
#define ER_CYW43438_BCDC_DCMD_HEADER_BYTES 16u
#define ER_CYW43438_BCDC_DCMD_PAYLOAD_MAX 1024u
#define ER_CYW43438_BCDC_DCMD_FRAME_MAX \
  (ER_CYW43438_SDPCM_HEADER_BYTES + ER_CYW43438_BCDC_DCMD_HEADER_BYTES + \
   ER_CYW43438_BCDC_DCMD_PAYLOAD_MAX)
#define ER_CYW43438_BCDC_CMD_UP 2u
#define ER_CYW43438_BCDC_CMD_SET_INFRA 20u
#define ER_CYW43438_BCDC_CMD_SET_AUTH 22u
#define ER_CYW43438_BCDC_CMD_SET_CHANNEL 30u
#define ER_CYW43438_BCDC_CMD_SET_WSEC 134u
#define ER_CYW43438_BCDC_CMD_SET_VAR 263u
#define ER_CYW43438_BCDC_CMD_SET_SSID 26u
#define ER_CYW43438_BCDC_STATUS_OK 0u
#define ER_CYW43438_BCDC_IF_STA 0u
#define ER_CYW43438_BCDC_OPEN_AUTH 0u
#define ER_CYW43438_BCDC_INFRA_STA 1u
#define ER_CYW43438_BCDC_WSEC_OPEN 0u
#define ER_CYW43438_BCDC_SSID_CAP 32u
#define ER_CYW43438_BCDC_BSSID_BYTES ER_NET_MAC_LEN
#define ER_CYW43438_BCDC_JOIN_PARAMS_BYTES \
  (sizeof(UINT32) + ER_CYW43438_BCDC_SSID_CAP)
#define ER_CYW43438_BCDC_EXT_JOIN_PARAMS_BYTES 64u

typedef struct {
  UINT32 frame_len;
  UINT8 sequence;
  UINT8 channel;
  UINT8 data_offset;
  UINT8 next_length;
  UINT8 flow_control;
  UINT8 tx_window;
} ErCyw43438SdpcmHeader;

typedef struct {
  UINT32 cmd;
  UINT32 len;
  UINT32 flags;
  UINT32 status;
  const UINT8* payload;
  UINT32 payload_len;
} ErCyw43438BcdcDcmd;

UINT8 er_cyw43438_sdpcm_channel_valid(UINT8 channel);
UINT8 er_cyw43438_sdpcm_build_frame(UINT8 sequence,
                                    UINT8 channel,
                                    const UINT8* payload,
                                    UINT32 payload_len,
                                    UINT8* out_frame,
                                    UINT32 out_frame_capacity,
                                    UINT32* out_frame_len);
UINT8 er_cyw43438_sdpcm_parse_frame(const UINT8* frame,
                                    UINT32 frame_len,
                                    ErCyw43438SdpcmHeader* out_header,
                                    const UINT8** out_payload,
                                    UINT32* out_payload_len);
UINT8 er_cyw43438_bcdc_build_int_dcmd(UINT8 sequence,
                                      UINT16 request_id,
                                      UINT32 command,
                                      UINT32 value,
                                      UINT8* out_frame,
                                      UINT32 out_frame_capacity,
                                      UINT32* out_frame_len);
UINT8 er_cyw43438_bcdc_build_iovar_int_dcmd(UINT8 sequence,
                                            UINT16 request_id,
                                            const char* name,
                                            UINT32 value,
                                            UINT8* out_frame,
                                            UINT32 out_frame_capacity,
                                            UINT32* out_frame_len);
UINT8 er_cyw43438_bcdc_build_set_ssid_dcmd(UINT8 sequence,
                                           UINT16 request_id,
                                           const UINT8* ssid,
                                           UINT32 ssid_len,
                                           UINT8* out_frame,
                                           UINT32 out_frame_capacity,
                                           UINT32* out_frame_len);
UINT8 er_cyw43438_bcdc_parse_dcmd_response(const UINT8* frame,
                                           UINT32 frame_len,
                                           UINT16 expected_request_id,
                                           ErCyw43438BcdcDcmd* out_dcmd);
UINT8 er_cyw43438_sdpcm_parse_raw_l2_erwire(
    const UINT8* frame,
    UINT32 frame_len,
    const UINT8 expected_dst_mac[ER_NET_MAC_LEN],
    UINT8 out_src_mac[ER_NET_MAC_LEN],
    const UINT8** out_erwire,
    UINT32* out_erwire_len);

#endif
