#include "test_core_internal.h"

static UINT16 test_sdpcm_le16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[0] | ((UINT16)bytes[1] << 8u));
}

static UINT32 test_sdpcm_le32(const UINT8* bytes) {
  return ((UINT32)bytes[0]) | ((UINT32)bytes[1] << 8u) |
         ((UINT32)bytes[2] << 16u) | ((UINT32)bytes[3] << 24u);
}

static void test_cyw43438_sdpcm_build_and_parse_data_frame(void) {
  UINT8 payload[4] = {0xdeu, 0xadu, 0xbeu, 0xefu};
  UINT8 frame[ER_CYW43438_SDPCM_HEADER_BYTES + sizeof(payload)] = {0u};
  UINT32 frame_len = 0u;
  ErCyw43438SdpcmHeader header = {0u};
  const UINT8* parsed_payload = 0;
  UINT32 parsed_payload_len = 0u;
  UINT32 software_header;
  UINT32 expected_frame_len;

  expected_frame_len = ER_CYW43438_SDPCM_HEADER_BYTES + (UINT32)sizeof(payload);
  check_uint64("sdpcm build data frame",
               er_cyw43438_sdpcm_build_frame(
                   7u,
                   ER_CYW43438_SDPCM_CHANNEL_DATA,
                   payload,
                   (UINT32)sizeof(payload),
                   frame,
                   (UINT32)sizeof(frame),
                   &frame_len),
               1u);
  check_uint64("sdpcm frame len", frame_len, expected_frame_len);
  check_uint64("sdpcm hwhdr len",
               test_sdpcm_le16(frame),
               expected_frame_len);
  check_uint64("sdpcm hwhdr checksum",
               (UINT16)(test_sdpcm_le16(frame) ^
                        test_sdpcm_le16(frame + sizeof(UINT16))),
               ER_CYW43438_SDPCM_HEADER_CHECK_VALUE);

  software_header = test_sdpcm_le32(
      frame + ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES);
  check_uint64("sdpcm software seq",
               software_header & ER_CYW43438_SDPCM_SEQUENCE_MASK,
               7u);
  check_uint64("sdpcm software channel",
               (software_header & ER_CYW43438_SDPCM_CHANNEL_MASK) >>
                   ER_CYW43438_SDPCM_CHANNEL_SHIFT,
               ER_CYW43438_SDPCM_CHANNEL_DATA);
  check_uint64("sdpcm software data offset",
               (software_header & ER_CYW43438_SDPCM_DATA_OFFSET_MASK) >>
                   ER_CYW43438_SDPCM_DATA_OFFSET_SHIFT,
               ER_CYW43438_SDPCM_HEADER_BYTES);
  check_uint64("sdpcm software flow window",
               test_sdpcm_le32(frame + ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES +
                               sizeof(UINT32)),
               0u);

  check_uint64("sdpcm parse data frame",
               er_cyw43438_sdpcm_parse_frame(frame,
                                             frame_len,
                                             &header,
                                             &parsed_payload,
                                             &parsed_payload_len),
               1u);
  check_uint64("sdpcm parsed len", header.frame_len, expected_frame_len);
  check_uint64("sdpcm parsed seq", header.sequence, 7u);
  check_uint64("sdpcm parsed channel",
               header.channel,
               ER_CYW43438_SDPCM_CHANNEL_DATA);
  check_uint64("sdpcm parsed data offset",
               header.data_offset,
               ER_CYW43438_SDPCM_HEADER_BYTES);
  check_uint64("sdpcm parsed next len", header.next_length, 0u);
  check_uint64("sdpcm parsed flow", header.flow_control, 0u);
  check_uint64("sdpcm parsed tx window", header.tx_window, 0u);
  check_uint64("sdpcm parsed payload len",
               parsed_payload_len,
               (UINT32)sizeof(payload));
  check_uint64("sdpcm parsed payload pointer",
               (UINT64)(UINTN)parsed_payload,
               (UINT64)(UINTN)(frame + ER_CYW43438_SDPCM_HEADER_BYTES));
  check_uint64("sdpcm parsed payload byte0", parsed_payload[0], payload[0]);
  check_uint64("sdpcm parsed payload byte3", parsed_payload[3], payload[3]);
}

static void test_cyw43438_sdpcm_rejects_invalid_frames(void) {
  UINT8 payload[1] = {0x42u};
  UINT8 frame[ER_CYW43438_SDPCM_HEADER_BYTES + sizeof(payload)] = {0u};
  UINT32 frame_len = 0u;
  ErCyw43438SdpcmHeader header = {0u};
  const UINT8* parsed_payload = 0;
  UINT32 parsed_payload_len = 0u;
  UINT32 software_header;

  check_uint64("sdpcm invalid build channel",
               er_cyw43438_sdpcm_build_frame(
                   0u,
                   4u,
                   payload,
                   (UINT32)sizeof(payload),
                   frame,
                   (UINT32)sizeof(frame),
                   &frame_len),
               0u);
  check_uint64("sdpcm undersized capacity",
               er_cyw43438_sdpcm_build_frame(
                   0u,
                   ER_CYW43438_SDPCM_CHANNEL_DATA,
                   payload,
                   (UINT32)sizeof(payload),
                   frame,
                   ER_CYW43438_SDPCM_HEADER_BYTES,
                   &frame_len),
               0u);
  check_uint64("sdpcm null payload with nonzero len",
               er_cyw43438_sdpcm_build_frame(
                   0u,
                   ER_CYW43438_SDPCM_CHANNEL_DATA,
                   0,
                   (UINT32)sizeof(payload),
                   frame,
                   (UINT32)sizeof(frame),
                   &frame_len),
               0u);
  check_uint64("sdpcm valid build for rejection cases",
               er_cyw43438_sdpcm_build_frame(
                   0u,
                   ER_CYW43438_SDPCM_CHANNEL_DATA,
                   payload,
                   (UINT32)sizeof(payload),
                   frame,
                   (UINT32)sizeof(frame),
                   &frame_len),
               1u);

  frame[sizeof(UINT16)] ^= 1u;
  check_uint64("sdpcm bad checksum",
               er_cyw43438_sdpcm_parse_frame(frame,
                                             frame_len,
                                             &header,
                                             &parsed_payload,
                                             &parsed_payload_len),
               0u);
  frame[sizeof(UINT16)] ^= 1u;

  software_header = test_sdpcm_le32(
      frame + ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES);
  software_header &= ~ER_CYW43438_SDPCM_CHANNEL_MASK;
  software_header |= 4u << ER_CYW43438_SDPCM_CHANNEL_SHIFT;
  frame[ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES] =
      (UINT8)(software_header & 0xffu);
  frame[ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES + 1u] =
      (UINT8)((software_header >> 8u) & 0xffu);
  frame[ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES + 2u] =
      (UINT8)((software_header >> 16u) & 0xffu);
  frame[ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES + 3u] =
      (UINT8)((software_header >> 24u) & 0xffu);
  check_uint64("sdpcm parse invalid channel",
               er_cyw43438_sdpcm_parse_frame(frame,
                                             frame_len,
                                             &header,
                                             &parsed_payload,
                                             &parsed_payload_len),
               0u);

  check_uint64("sdpcm rebuild for bad offset",
               er_cyw43438_sdpcm_build_frame(
                   0u,
                   ER_CYW43438_SDPCM_CHANNEL_DATA,
                   payload,
                   (UINT32)sizeof(payload),
                   frame,
                   (UINT32)sizeof(frame),
                   &frame_len),
               1u);
  frame[ER_CYW43438_SDPCM_HARDWARE_HEADER_BYTES + 3u] =
      (UINT8)(frame_len + 1u);
  check_uint64("sdpcm parse bad data offset",
               er_cyw43438_sdpcm_parse_frame(frame,
                                             frame_len,
                                             &header,
                                             &parsed_payload,
                                             &parsed_payload_len),
               0u);
  check_uint64("sdpcm parse short frame",
               er_cyw43438_sdpcm_parse_frame(frame,
                                             ER_CYW43438_SDPCM_HEADER_BYTES -
                                                 1u,
                                             &header,
                                             &parsed_payload,
                                             &parsed_payload_len),
               0u);
}

static void test_cyw43438_sdpcm_extracts_raw_l2_erwire(void) {
  UINT8 src_mac[ER_NET_MAC_LEN] = {0x02u, 0x45u, 0x52u, 0x5au, 0x57u, 0x01u};
  UINT8 local_mac[ER_NET_MAC_LEN] = {0x02u, 0x45u, 0x52u, 0x5au, 0x57u, 0x02u};
  UINT8 other_mac[ER_NET_MAC_LEN] = {0x02u, 0x45u, 0x52u, 0x5au, 0x57u, 0x03u};
  UINT8 dst_mac[ER_NET_MAC_LEN] = {
      ER_CYW43438_SDPCM_BROADCAST_BYTE,
      ER_CYW43438_SDPCM_BROADCAST_BYTE,
      ER_CYW43438_SDPCM_BROADCAST_BYTE,
      ER_CYW43438_SDPCM_BROADCAST_BYTE,
      ER_CYW43438_SDPCM_BROADCAST_BYTE,
      ER_CYW43438_SDPCM_BROADCAST_BYTE};
  UINT8 erwire[3] = {0x45u, 0x52u, 0x57u};
  UINT8 eth_frame[ER_NET_ETH_HEADER_LEN + sizeof(erwire)] = {0u};
  UINT8 sdpcm_frame[ER_CYW43438_SDPCM_HEADER_BYTES + sizeof(eth_frame)] = {0u};
  UINT8 parsed_src_mac[ER_NET_MAC_LEN] = {0u};
  UINT32 eth_frame_len = 0u;
  UINT32 sdpcm_frame_len = 0u;
  const UINT8* parsed_erwire = 0;
  UINT32 parsed_erwire_len = 0u;

  check_uint64("sdpcm test eth frame build",
               er_net_build_eth_frame(src_mac,
                                      dst_mac,
                                      ER_NET_ETH_TYPE_EDGERUN,
                                      erwire,
                                      (UINT32)sizeof(erwire),
                                      eth_frame,
                                      (UINT32)sizeof(eth_frame),
                                      &eth_frame_len),
               1u);
  check_uint64("sdpcm test frame build",
               er_cyw43438_sdpcm_build_frame(
                   9u,
                   ER_CYW43438_SDPCM_CHANNEL_DATA,
                   eth_frame,
                   eth_frame_len,
                   sdpcm_frame,
                   (UINT32)sizeof(sdpcm_frame),
                   &sdpcm_frame_len),
               1u);
  check_uint64("sdpcm raw l2 broadcast erwire parse",
               er_cyw43438_sdpcm_parse_raw_l2_erwire(sdpcm_frame,
                                                     sdpcm_frame_len,
                                                     local_mac,
                                                     parsed_src_mac,
                                                     &parsed_erwire,
                                                     &parsed_erwire_len),
               1u);
  check_uint64("sdpcm raw l2 erwire len",
               parsed_erwire_len,
               (UINT32)sizeof(erwire));
  check_uint64("sdpcm raw l2 erwire pointer",
               (UINT64)(UINTN)parsed_erwire,
               (UINT64)(UINTN)(sdpcm_frame +
                               ER_CYW43438_SDPCM_HEADER_BYTES +
                               ER_NET_ETH_HEADER_LEN));
  check_uint64("sdpcm raw l2 source byte0",
               parsed_src_mac[0],
               src_mac[0]);
  check_uint64("sdpcm raw l2 source byte5",
               parsed_src_mac[5],
               src_mac[5]);
  check_uint64("sdpcm raw l2 erwire byte0", parsed_erwire[0], erwire[0]);
  check_uint64("sdpcm raw l2 erwire byte2", parsed_erwire[2], erwire[2]);

  check_uint64("sdpcm test unicast eth frame build",
               er_net_build_eth_frame(src_mac,
                                      local_mac,
                                      ER_NET_ETH_TYPE_EDGERUN,
                                      erwire,
                                      (UINT32)sizeof(erwire),
                                      eth_frame,
                                      (UINT32)sizeof(eth_frame),
                                      &eth_frame_len),
               1u);
  check_uint64("sdpcm test unicast frame build",
               er_cyw43438_sdpcm_build_frame(
                   10u,
                   ER_CYW43438_SDPCM_CHANNEL_DATA,
                   eth_frame,
                   eth_frame_len,
                   sdpcm_frame,
                   (UINT32)sizeof(sdpcm_frame),
                   &sdpcm_frame_len),
               1u);
  check_uint64("sdpcm raw l2 local erwire parse",
               er_cyw43438_sdpcm_parse_raw_l2_erwire(sdpcm_frame,
                                                     sdpcm_frame_len,
                                                     local_mac,
                                                     parsed_src_mac,
                                                     &parsed_erwire,
                                                     &parsed_erwire_len),
               1u);
  check_uint64("sdpcm raw l2 rejects other local mac",
               er_cyw43438_sdpcm_parse_raw_l2_erwire(sdpcm_frame,
                                                     sdpcm_frame_len,
                                                     other_mac,
                                                     parsed_src_mac,
                                                     &parsed_erwire,
                                                     &parsed_erwire_len),
               0u);
}

static void test_cyw43438_sdpcm_frames(void) {
  check_uint64("sdpcm control channel valid",
               er_cyw43438_sdpcm_channel_valid(
                   ER_CYW43438_SDPCM_CHANNEL_CONTROL),
               1u);
  check_uint64("sdpcm event channel valid",
               er_cyw43438_sdpcm_channel_valid(
                   ER_CYW43438_SDPCM_CHANNEL_EVENT),
               1u);
  check_uint64("sdpcm data channel valid",
               er_cyw43438_sdpcm_channel_valid(
                   ER_CYW43438_SDPCM_CHANNEL_DATA),
               1u);
  check_uint64("sdpcm glom channel valid",
               er_cyw43438_sdpcm_channel_valid(
                   ER_CYW43438_SDPCM_CHANNEL_GLOM),
               1u);
  check_uint64("sdpcm test channel valid",
               er_cyw43438_sdpcm_channel_valid(
                   ER_CYW43438_SDPCM_CHANNEL_TEST),
               1u);
  check_uint64("sdpcm reserved channel invalid",
               er_cyw43438_sdpcm_channel_valid(4u),
               0u);
  test_cyw43438_sdpcm_build_and_parse_data_frame();
  test_cyw43438_sdpcm_rejects_invalid_frames();
  test_cyw43438_sdpcm_extracts_raw_l2_erwire();
}
