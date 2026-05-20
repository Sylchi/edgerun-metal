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

typedef struct {
  UINT32 frame_len;
  UINT8 sequence;
  UINT8 channel;
  UINT8 data_offset;
  UINT8 next_length;
  UINT8 flow_control;
  UINT8 tx_window;
} ErCyw43438SdpcmHeader;

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
UINT8 er_cyw43438_sdpcm_parse_broadcast_erwire(
    const UINT8* frame,
    UINT32 frame_len,
    UINT8 out_src_mac[ER_NET_MAC_LEN],
    const UINT8** out_erwire,
    UINT32* out_erwire_len);

#endif
