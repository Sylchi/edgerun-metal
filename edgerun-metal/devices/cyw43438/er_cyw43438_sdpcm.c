#include "er_cyw43438_sdpcm.h"

#include "er_mem.h"

#define ER_CYW43438_SDPCM_ETH_DST_OFFSET 0u
#define ER_CYW43438_SDPCM_ETH_SRC_OFFSET ER_NET_MAC_LEN
#define ER_CYW43438_SDPCM_ETH_TYPE_OFFSET \
  (ER_CYW43438_SDPCM_ETH_SRC_OFFSET + ER_NET_MAC_LEN)
#define ER_CYW43438_SDPCM_BE_HIGH_SHIFT 8u
#define ER_CYW43438_SDPCM_BYTE_MASK 0xffu
#define ER_CYW43438_BCDC_PROTO_VER 2u
#define ER_CYW43438_BCDC_FLAG_VER_SHIFT 4u
#define ER_CYW43438_BCDC_FLAG_VER_MASK 0xf0u
#define ER_CYW43438_BCDC_DCMD_SET 0x00000002u
#define ER_CYW43438_BCDC_DCMD_ID_MASK 0xffff0000u
#define ER_CYW43438_BCDC_DCMD_ID_SHIFT 16u
#define ER_CYW43438_BCDC_DCMD_IF_MASK 0x0000f000u
#define ER_CYW43438_BCDC_DCMD_IF_SHIFT 12u
#define ER_CYW43438_BCDC_DCMD_ERROR 0x00000001u
#define ER_CYW43438_BCDC_DCMD_CMD_OFFSET 0u
#define ER_CYW43438_BCDC_DCMD_LEN_OFFSET 4u
#define ER_CYW43438_BCDC_DCMD_FLAGS_OFFSET 8u
#define ER_CYW43438_BCDC_DCMD_STATUS_OFFSET 12u
#define ER_CYW43438_BCDC_SSID_LEN_OFFSET 0u
#define ER_CYW43438_BCDC_SSID_BYTES_OFFSET 4u
#define ER_CYW43438_BCDC_INT_BYTES 4u
#define ER_CYW43438_BCDC_DATA_OFFSET_WORD_BYTES 4u

static void er_cyw43438_sdpcm_put_le16(UINT8* out, UINT16 value) {
  out[0] = (UINT8)(value & 0xffu);
  out[1] = (UINT8)((value >> 8u) & 0xffu);
}

static UINT16 er_cyw43438_sdpcm_get_le16(const UINT8* in) {
  return (UINT16)((UINT16)in[0] | ((UINT16)in[1] << 8u));
}

static void er_cyw43438_sdpcm_put_le32(UINT8* out, UINT32 value) {
  out[0] = (UINT8)(value & 0xffu);
  out[1] = (UINT8)((value >> 8u) & 0xffu);
  out[2] = (UINT8)((value >> 16u) & 0xffu);
  out[3] = (UINT8)((value >> 24u) & 0xffu);
}

static UINT32 er_cyw43438_sdpcm_get_le32(const UINT8* in) {
  return ((UINT32)in[0]) | ((UINT32)in[1] << 8u) |
         ((UINT32)in[2] << 16u) | ((UINT32)in[3] << 24u);
}

static UINT8 er_cyw43438_bcdc_payload_offset(const UINT8* payload,
                                             UINT32 payload_len,
                                             UINT32* out_offset) {
  UINT32 offset;

  if (payload == 0 || out_offset == 0 ||
      payload_len < ER_CYW43438_BCDC_HEADER_BYTES ||
      (payload[0] & ER_CYW43438_BCDC_FLAG_VER_MASK) !=
          (ER_CYW43438_BCDC_PROTO_VER << ER_CYW43438_BCDC_FLAG_VER_SHIFT)) {
    return 0u;
  }
  offset = ER_CYW43438_BCDC_HEADER_BYTES +
           ((UINT32)payload[3] * ER_CYW43438_BCDC_DATA_OFFSET_WORD_BYTES);
  if (offset > payload_len) {
    return 0u;
  }
  *out_offset = offset;
  return 1u;
}

static UINT16 er_cyw43438_sdpcm_get_be16(const UINT8* in) {
  return (UINT16)(((UINT16)in[0] << ER_CYW43438_SDPCM_BE_HIGH_SHIFT) |
                  (UINT16)in[1]);
}

static UINT8 er_cyw43438_sdpcm_is_broadcast_mac(const UINT8* mac) {
  UINT32 i;

  if (mac == 0) {
    return 0u;
  }
  for (i = 0u; i < ER_NET_MAC_LEN; ++i) {
    if (mac[i] != ER_CYW43438_SDPCM_BROADCAST_BYTE) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_cyw43438_sdpcm_dst_mac_matches(const UINT8* mac,
                                               const UINT8* expected_mac) {
  if (expected_mac == 0) {
    return 0u;
  }
  if (er_cyw43438_sdpcm_is_broadcast_mac(mac) != 0u) {
    return 1u;
  }
  return er_mem_equal(mac, expected_mac, ER_NET_MAC_LEN);
}

UINT8 er_cyw43438_sdpcm_channel_valid(UINT8 channel) {
  switch (channel) {
  case ER_CYW43438_SDPCM_CHANNEL_CONTROL:
  case ER_CYW43438_SDPCM_CHANNEL_EVENT:
  case ER_CYW43438_SDPCM_CHANNEL_DATA:
  case ER_CYW43438_SDPCM_CHANNEL_GLOM:
  case ER_CYW43438_SDPCM_CHANNEL_TEST:
    return 1u;
  default:
    return 0u;
  }
}

UINT8 er_cyw43438_sdpcm_build_frame(UINT8 sequence,
                                    UINT8 channel,
                                    const UINT8* payload,
                                    UINT32 payload_len,
                                    UINT8* out_frame,
                                    UINT32 out_frame_capacity,
                                    UINT32* out_frame_len) {
  UINT32 frame_len;
  UINT16 frame_len16;
  UINT32 software_header;

  if (out_frame_len == 0 || out_frame == 0 ||
      er_cyw43438_sdpcm_channel_valid(channel) == 0u) {
    return 0u;
  }
  if (payload_len > 0u && payload == 0) {
    return 0u;
  }
  if (payload_len > ER_CYW43438_SDPCM_PAYLOAD_MAX) {
    return 0u;
  }
  frame_len = ER_CYW43438_SDPCM_HEADER_BYTES + payload_len;
  if (frame_len > out_frame_capacity) {
    return 0u;
  }

  frame_len16 = (UINT16)frame_len;
  er_cyw43438_sdpcm_put_le16(out_frame, frame_len16);
  er_cyw43438_sdpcm_put_le16(out_frame + sizeof(UINT16),
                             (UINT16)(~frame_len16));

  software_header = ((UINT32)sequence & ER_CYW43438_SDPCM_SEQUENCE_MASK) |
                    (((UINT32)channel << ER_CYW43438_SDPCM_CHANNEL_SHIFT) &
                     ER_CYW43438_SDPCM_CHANNEL_MASK) |
                    ((ER_CYW43438_SDPCM_HEADER_BYTES
                      << ER_CYW43438_SDPCM_DATA_OFFSET_SHIFT) &
                     ER_CYW43438_SDPCM_DATA_OFFSET_MASK);
  er_cyw43438_sdpcm_put_le32(
      out_frame + ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES,
      software_header);
  er_cyw43438_sdpcm_put_le32(
      out_frame + ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES + sizeof(UINT32),
      0u);
  er_mem_copy(out_frame + ER_CYW43438_SDPCM_HEADER_BYTES, payload, payload_len);
  *out_frame_len = frame_len;
  return 1u;
}

UINT8 er_cyw43438_sdpcm_parse_frame(const UINT8* frame,
                                    UINT32 frame_len,
                                    ErCyw43438SdpcmHeader* out_header,
                                    const UINT8** out_payload,
                                    UINT32* out_payload_len) {
  UINT16 header_len;
  UINT16 header_checksum;
  UINT32 software_header;
  UINT32 window_header;
  UINT8 channel;
  UINT8 data_offset;

  if (frame == 0 || out_header == 0 || out_payload == 0 ||
      out_payload_len == 0) {
    return 0u;
  }
  if (frame_len < ER_CYW43438_SDPCM_HEADER_BYTES) {
    return 0u;
  }

  header_len = er_cyw43438_sdpcm_get_le16(frame);
  header_checksum = er_cyw43438_sdpcm_get_le16(frame + sizeof(UINT16));
  if ((UINT16)(header_len ^ header_checksum) !=
      ER_CYW43438_SDPCM_HEADER_CHECK_VALUE) {
    return 0u;
  }
  if ((UINT32)header_len < ER_CYW43438_SDPCM_HEADER_BYTES ||
      (UINT32)header_len > frame_len) {
    return 0u;
  }

  software_header = er_cyw43438_sdpcm_get_le32(
      frame + ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES);
  channel = (UINT8)((software_header & ER_CYW43438_SDPCM_CHANNEL_MASK) >>
                   ER_CYW43438_SDPCM_CHANNEL_SHIFT);
  data_offset =
      (UINT8)((software_header & ER_CYW43438_SDPCM_DATA_OFFSET_MASK) >>
              ER_CYW43438_SDPCM_DATA_OFFSET_SHIFT);
  if (er_cyw43438_sdpcm_channel_valid(channel) == 0u ||
      data_offset < ER_CYW43438_SDPCM_HEADER_BYTES ||
      (UINT32)data_offset > (UINT32)header_len) {
    return 0u;
  }

  window_header = er_cyw43438_sdpcm_get_le32(
      frame + ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES + sizeof(UINT32));
  out_header->frame_len = (UINT32)header_len;
  out_header->sequence =
      (UINT8)(software_header & ER_CYW43438_SDPCM_SEQUENCE_MASK);
  out_header->channel = channel;
  out_header->data_offset = data_offset;
  out_header->next_length =
      (UINT8)((software_header & ER_CYW43438_SDPCM_NEXT_LENGTH_MASK) >>
              ER_CYW43438_SDPCM_NEXT_LENGTH_SHIFT);
  out_header->flow_control =
      (UINT8)(window_header & ER_CYW43438_SDPCM_FLOW_CONTROL_MASK);
  out_header->tx_window =
      (UINT8)((window_header & ER_CYW43438_SDPCM_WINDOW_MASK) >>
              ER_CYW43438_SDPCM_WINDOW_SHIFT);
  *out_payload = frame + data_offset;
  *out_payload_len = (UINT32)header_len - (UINT32)data_offset;
  return 1u;
}

static UINT32 er_cyw43438_bcdc_dcmd_flags(UINT16 request_id, UINT8 ifidx) {
  return ((((UINT32)request_id << ER_CYW43438_BCDC_DCMD_ID_SHIFT) &
           ER_CYW43438_BCDC_DCMD_ID_MASK) |
          (((UINT32)ifidx << ER_CYW43438_BCDC_DCMD_IF_SHIFT) &
           ER_CYW43438_BCDC_DCMD_IF_MASK) |
          ER_CYW43438_BCDC_DCMD_SET);
}

static UINT8 er_cyw43438_bcdc_build_dcmd(UINT8 sequence,
                                         UINT16 request_id,
                                         UINT32 command,
                                         const UINT8* payload,
                                         UINT32 payload_len,
                                         UINT8* out_frame,
                                         UINT32 out_frame_capacity,
                                         UINT32* out_frame_len) {
  UINT8 dcmd[ER_CYW43438_BCDC_DCMD_HEADER_BYTES +
             ER_CYW43438_BCDC_DCMD_PAYLOAD_MAX];

  if (out_frame == 0 ||
      out_frame_len == 0 ||
      (payload_len != 0u && payload == 0) ||
      payload_len > ER_CYW43438_BCDC_DCMD_PAYLOAD_MAX) {
    return 0u;
  }
  er_mem_zero(dcmd, (UINTN)sizeof(dcmd));
  er_cyw43438_sdpcm_put_le32(dcmd + ER_CYW43438_BCDC_DCMD_CMD_OFFSET,
                             command);
  er_cyw43438_sdpcm_put_le32(dcmd + ER_CYW43438_BCDC_DCMD_LEN_OFFSET,
                             payload_len);
  er_cyw43438_sdpcm_put_le32(dcmd + ER_CYW43438_BCDC_DCMD_FLAGS_OFFSET,
                             er_cyw43438_bcdc_dcmd_flags(
                                 request_id,
                                 ER_CYW43438_BCDC_IF_STA));
  er_cyw43438_sdpcm_put_le32(dcmd + ER_CYW43438_BCDC_DCMD_STATUS_OFFSET,
                             ER_CYW43438_BCDC_STATUS_OK);
  er_mem_copy(dcmd + ER_CYW43438_BCDC_DCMD_HEADER_BYTES,
              payload,
              payload_len);
  return er_cyw43438_sdpcm_build_frame(
      sequence,
      ER_CYW43438_SDPCM_CHANNEL_CONTROL,
      dcmd,
      ER_CYW43438_BCDC_DCMD_HEADER_BYTES + payload_len,
      out_frame,
      out_frame_capacity,
      out_frame_len);
}

UINT8 er_cyw43438_bcdc_build_int_dcmd(UINT8 sequence,
                                      UINT16 request_id,
                                      UINT32 command,
                                      UINT32 value,
                                      UINT8* out_frame,
                                      UINT32 out_frame_capacity,
                                      UINT32* out_frame_len) {
  UINT8 payload[ER_CYW43438_BCDC_INT_BYTES];

  er_cyw43438_sdpcm_put_le32(payload, value);
  return er_cyw43438_bcdc_build_dcmd(sequence,
                                     request_id,
                                     command,
                                     payload,
                                     (UINT32)sizeof(payload),
                                     out_frame,
                                     out_frame_capacity,
                                     out_frame_len);
}

static UINT8 er_cyw43438_bcdc_name_len(const char* name, UINT32* out_len) {
  UINT32 len;

  if (name == 0 || out_len == 0) {
    return 0u;
  }
  len = 0u;
  while (name[len] != 0) {
    ++len;
    if (len >= ER_CYW43438_BCDC_DCMD_PAYLOAD_MAX) {
      return 0u;
    }
  }
  *out_len = len + 1u;
  return 1u;
}

UINT8 er_cyw43438_bcdc_build_iovar_int_dcmd(UINT8 sequence,
                                            UINT16 request_id,
                                            const char* name,
                                            UINT32 value,
                                            UINT8* out_frame,
                                            UINT32 out_frame_capacity,
                                            UINT32* out_frame_len) {
  UINT8 payload[ER_CYW43438_BCDC_DCMD_PAYLOAD_MAX];
  UINT32 name_len;
  UINT32 i;

  if (er_cyw43438_bcdc_name_len(name, &name_len) == 0u ||
      name_len + ER_CYW43438_BCDC_INT_BYTES >
          ER_CYW43438_BCDC_DCMD_PAYLOAD_MAX) {
    return 0u;
  }
  er_mem_zero(payload, (UINTN)sizeof(payload));
  for (i = 0u; i < name_len; ++i) {
    payload[i] = (UINT8)name[i];
  }
  er_cyw43438_sdpcm_put_le32(payload + name_len, value);
  return er_cyw43438_bcdc_build_dcmd(sequence,
                                     request_id,
                                     ER_CYW43438_BCDC_CMD_SET_VAR,
                                     payload,
                                     name_len + ER_CYW43438_BCDC_INT_BYTES,
                                     out_frame,
                                     out_frame_capacity,
                                     out_frame_len);
}

UINT8 er_cyw43438_bcdc_build_set_ssid_dcmd(UINT8 sequence,
                                           UINT16 request_id,
                                           const UINT8* ssid,
                                           UINT32 ssid_len,
                                           UINT8* out_frame,
                                           UINT32 out_frame_capacity,
                                           UINT32* out_frame_len) {
  UINT8 payload[ER_CYW43438_BCDC_JOIN_PARAMS_BYTES];

  if (ssid == 0 ||
      ssid_len == 0u ||
      ssid_len > ER_CYW43438_BCDC_SSID_CAP) {
    return 0u;
  }
  er_mem_zero(payload, (UINTN)sizeof(payload));
  er_cyw43438_sdpcm_put_le32(payload + ER_CYW43438_BCDC_SSID_LEN_OFFSET,
                             ssid_len);
  er_mem_copy(payload + ER_CYW43438_BCDC_SSID_BYTES_OFFSET,
              ssid,
              ssid_len);
  return er_cyw43438_bcdc_build_dcmd(sequence,
                                     request_id,
                                     ER_CYW43438_BCDC_CMD_SET_SSID,
                                     payload,
                                     (UINT32)sizeof(payload),
                                     out_frame,
                                     out_frame_capacity,
                                     out_frame_len);
}

UINT8 er_cyw43438_bcdc_parse_dcmd_response(const UINT8* frame,
                                           UINT32 frame_len,
                                           UINT16 expected_request_id,
                                           ErCyw43438BcdcDcmd* out_dcmd) {
  ErCyw43438SdpcmHeader header;
  const UINT8* payload;
  UINT32 payload_len;
  UINT32 flags;
  UINT16 request_id;

  if (out_dcmd == 0 ||
      er_cyw43438_sdpcm_parse_frame(frame,
                                    frame_len,
                                    &header,
                                    &payload,
                                    &payload_len) == 0u ||
      header.channel != ER_CYW43438_SDPCM_CHANNEL_CONTROL ||
      payload_len < ER_CYW43438_BCDC_DCMD_HEADER_BYTES) {
    return 0u;
  }
  flags = er_cyw43438_sdpcm_get_le32(
      payload + ER_CYW43438_BCDC_DCMD_FLAGS_OFFSET);
  request_id = (UINT16)((flags & ER_CYW43438_BCDC_DCMD_ID_MASK) >>
                        ER_CYW43438_BCDC_DCMD_ID_SHIFT);
  if (request_id != expected_request_id ||
      (flags & ER_CYW43438_BCDC_DCMD_ERROR) != 0u) {
    return 0u;
  }
  out_dcmd->cmd = er_cyw43438_sdpcm_get_le32(
      payload + ER_CYW43438_BCDC_DCMD_CMD_OFFSET);
  out_dcmd->len = er_cyw43438_sdpcm_get_le32(
      payload + ER_CYW43438_BCDC_DCMD_LEN_OFFSET);
  out_dcmd->flags = flags;
  out_dcmd->status = er_cyw43438_sdpcm_get_le32(
      payload + ER_CYW43438_BCDC_DCMD_STATUS_OFFSET);
  out_dcmd->payload = payload + ER_CYW43438_BCDC_DCMD_HEADER_BYTES;
  out_dcmd->payload_len =
      payload_len - ER_CYW43438_BCDC_DCMD_HEADER_BYTES;
  return (UINT8)(out_dcmd->status == ER_CYW43438_BCDC_STATUS_OK);
}

UINT8 er_cyw43438_sdpcm_parse_raw_l2_erwire(
    const UINT8* frame,
    UINT32 frame_len,
    const UINT8 expected_dst_mac[ER_NET_MAC_LEN],
    UINT8 out_src_mac[ER_NET_MAC_LEN],
    const UINT8** out_erwire,
    UINT32* out_erwire_len) {
  ErCyw43438SdpcmHeader header;
  const UINT8* payload;
  UINT32 payload_len;
  UINT32 payload_offset;

  if (expected_dst_mac == 0 || out_src_mac == 0 ||
      out_erwire == 0 || out_erwire_len == 0 ||
      er_cyw43438_sdpcm_parse_frame(
          frame,
          frame_len,
          &header,
          &payload,
          &payload_len) == 0u ||
      header.channel != ER_CYW43438_SDPCM_CHANNEL_DATA) {
    return 0u;
  }
  if (er_cyw43438_bcdc_payload_offset(payload,
                                      payload_len,
                                      &payload_offset) != 0u) {
    payload += payload_offset;
    payload_len -= payload_offset;
  }
  if (payload_len <= ER_NET_ETH_HEADER_LEN ||
      er_cyw43438_sdpcm_dst_mac_matches(
          payload + ER_CYW43438_SDPCM_ETH_DST_OFFSET,
          expected_dst_mac) == 0u ||
      er_cyw43438_sdpcm_get_be16(
          payload + ER_CYW43438_SDPCM_ETH_TYPE_OFFSET) !=
          ER_NET_ETH_TYPE_EDGERUN) {
    return 0u;
  }
  er_mem_copy(out_src_mac,
              payload + ER_CYW43438_SDPCM_ETH_SRC_OFFSET,
              ER_NET_MAC_LEN);
  *out_erwire = payload + ER_NET_ETH_HEADER_LEN;
  *out_erwire_len = payload_len - ER_NET_ETH_HEADER_LEN;
  return 1u;
}
