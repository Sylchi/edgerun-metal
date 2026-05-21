typedef struct {
  UINT32 write_count;
  UINT32 fail_block;
  UINT32 blocks[4];
  UINT8 bytes[4][ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES];
} TestPiZeroWV11OtaSink;

#define PI_ZERO_W_V1_1_TEST_SRC_MAC_0 0x02u
#define PI_ZERO_W_V1_1_TEST_SRC_MAC_1 0x45u
#define PI_ZERO_W_V1_1_TEST_SRC_MAC_2 0x52u
#define PI_ZERO_W_V1_1_TEST_SRC_MAC_3 0x11u
#define PI_ZERO_W_V1_1_TEST_SRC_MAC_4 0x00u
#define PI_ZERO_W_V1_1_TEST_SRC_MAC_5 0x01u
#define PI_ZERO_W_V1_1_TEST_DST_MAC_0 0x02u
#define PI_ZERO_W_V1_1_TEST_DST_MAC_1 0x45u
#define PI_ZERO_W_V1_1_TEST_DST_MAC_2 0x52u
#define PI_ZERO_W_V1_1_TEST_DST_MAC_3 0x11u
#define PI_ZERO_W_V1_1_TEST_DST_MAC_4 0x00u
#define PI_ZERO_W_V1_1_TEST_DST_MAC_5 0x02u
#define PI_ZERO_W_V1_1_TEST_OTHER_MAC_0 0x02u
#define PI_ZERO_W_V1_1_TEST_OTHER_MAC_1 0x45u
#define PI_ZERO_W_V1_1_TEST_OTHER_MAC_2 0x52u
#define PI_ZERO_W_V1_1_TEST_OTHER_MAC_3 0x11u
#define PI_ZERO_W_V1_1_TEST_OTHER_MAC_4 0x00u
#define PI_ZERO_W_V1_1_TEST_OTHER_MAC_5 0x03u
#define PI_ZERO_W_V1_1_TEST_BROADCAST_BYTE 0xffu

static UINT8 test_pi_zero_w_v1_1_ota_write_block(
    void* ctx,
    UINT32 block_address,
    const UINT8 block[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES]) {
  TestPiZeroWV11OtaSink* sink = (TestPiZeroWV11OtaSink*)ctx;
  UINT32 i;

  if (sink == 0 || block == 0 || sink->write_count >= 4u) {
    return 0u;
  }
  if (sink->fail_block != 0u && sink->fail_block == block_address) {
    return 0u;
  }
  sink->blocks[sink->write_count] = block_address;
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES; ++i) {
    sink->bytes[sink->write_count][i] = block[i];
  }
  sink->write_count += 1u;
  return 1u;
}

static void test_pi_zero_w_v1_1_ota_erwire_object_frame(
    const ErVfsObjectPacket* object_packet,
    UINT8* out_frame,
    UINT32* out_frame_len) {
  UINT8 payload[ERWIRE_MAX_PAYLOAD];
  UINT32 payload_len;

  check_int64("pi zero w ota encode object payload",
              er_pi_zero_w_v1_1_ota_encode_object_packet_payload(
                  object_packet,
                  payload,
                  (UINT32)sizeof(payload),
                  &payload_len),
              1);
  check_int64("pi zero w ota build erwire object packet",
              erwire_build_packet(ERWIRE_KIND_VFS_OBJECT_PACKET,
                                  ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
                                  payload,
                                  payload_len,
                                  out_frame,
                                  ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD,
                                  out_frame_len),
              1);
}

static void test_pi_zero_w_v1_1_ota_eth_frame(
    const ErVfsObjectPacket* object_packet,
    const UINT8 dst_mac[ER_NET_MAC_LEN],
    UINT16 eth_type,
    UINT8* out_frame,
    UINT32* out_frame_len) {
  static const UINT8 src_mac[ER_NET_MAC_LEN] = {
      PI_ZERO_W_V1_1_TEST_SRC_MAC_0,
      PI_ZERO_W_V1_1_TEST_SRC_MAC_1,
      PI_ZERO_W_V1_1_TEST_SRC_MAC_2,
      PI_ZERO_W_V1_1_TEST_SRC_MAC_3,
      PI_ZERO_W_V1_1_TEST_SRC_MAC_4,
      PI_ZERO_W_V1_1_TEST_SRC_MAC_5};
  UINT8 erwire_frame[ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD];
  UINT32 erwire_frame_len;

  test_pi_zero_w_v1_1_ota_erwire_object_frame(object_packet,
                                              erwire_frame,
                                              &erwire_frame_len);
  check_int64("pi zero w ota build l2 erwire frame",
              er_net_build_eth_frame(src_mac,
                                     dst_mac,
                                     eth_type,
                                     erwire_frame,
                                     erwire_frame_len,
                                     out_frame,
                                     ER_NET_FRAME_MAX,
                                     out_frame_len),
              1);
}

static void test_pi_zero_w_v1_1_ota_receiver(void) {
  enum {
    PI_TEST_OTA_IMAGE_LEN = 1500u,
    PI_TEST_OTA_SECOND_PACKET_OFFSET = 1024u,
    PI_TEST_OTA_TARGET_BLOCK = ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK
  };

  ErPiZeroWV11OtaState state;
  TestPiZeroWV11OtaSink sink;
  ErCryptoProvider crypto;
  ErVfsObjectPacket object_packets[2];
  ErVfsObjectPacket decoded_packet;
  UINT8 image[PI_TEST_OTA_IMAGE_LEN];
  UINT8 frame[ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD];
  UINT32 frame_len;
  UINT32 i;

  er_crypto_blake3_provider(&crypto);
  er_mem_zero((UINT8*)&sink, (UINTN)sizeof(sink));
  erwire_init(ER_PI_ZERO_W_V1_1_OTA_ERWIRE_STREAM_ID);
  for (i = 0u; i < PI_TEST_OTA_IMAGE_LEN; ++i) {
    image[i] = (UINT8)(i * 17u + 3u);
  }
  check_int64("pi zero w ota prepare vfs object packet",
              er_vfs_prepare_object_packet(&crypto,
                                           image,
                                           PI_TEST_OTA_IMAGE_LEN,
                                           0u,
                                           0u,
                                           2u,
                                           &object_packets[0]),
              1);
  check_int64("pi zero w ota prepare second vfs object packet",
              er_vfs_prepare_object_packet(&crypto,
                                           image,
                                           PI_TEST_OTA_IMAGE_LEN,
                                           PI_TEST_OTA_SECOND_PACKET_OFFSET,
                                           1u,
                                           2u,
                                           &object_packets[1]),
              1);
  er_pi_zero_w_v1_1_ota_reset(&state);
  check_uint64("pi zero w ota reset status",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_IDLE);
  check_uint64("pi zero w ota reset target",
               state.target_block,
               PI_TEST_OTA_TARGET_BLOCK);

  test_pi_zero_w_v1_1_ota_erwire_object_frame(&object_packets[0],
                                              frame,
                                              &frame_len);
  check_int64("pi zero w ota decode erwire vfs packet",
              er_pi_zero_w_v1_1_ota_decode_object_packet_payload(
                  frame,
                  frame_len,
                  &decoded_packet),
              1);
  check_hash_equal("pi zero w ota decoded object id",
                   &decoded_packet.header.object_id,
                   &object_packets[0].header.object_id);
  check_int64("pi zero w ota receive first vfs object packet",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  &crypto,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  check_uint64("pi zero w ota receiving first packet",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING);
  check_uint64("pi zero w ota first packet no write", sink.write_count, 0u);

  test_pi_zero_w_v1_1_ota_erwire_object_frame(&object_packets[1],
                                              frame,
                                              &frame_len);
  check_int64("pi zero w ota receive second vfs object packet",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  &crypto,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  check_uint64("pi zero w ota committed raw slot",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_COMMITTED);
  check_uint64("pi zero w ota raw slot requests reboot",
               state.reboot_required,
               1u);
  check_uint64("pi zero w ota object length",
               state.object_len,
               PI_TEST_OTA_IMAGE_LEN);
  check_uint64("pi zero w ota blocks written", sink.write_count, 3u);
  check_uint64("pi zero w ota first block address",
               sink.blocks[0],
               PI_TEST_OTA_TARGET_BLOCK);
  check_uint64("pi zero w ota second block address",
               sink.blocks[1],
               PI_TEST_OTA_TARGET_BLOCK + 1u);
  check_uint64("pi zero w ota final block address",
               sink.blocks[2],
               PI_TEST_OTA_TARGET_BLOCK + 2u);
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES; ++i) {
    check_uint64("pi zero w ota first block byte", sink.bytes[0][i], image[i]);
  }
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES; ++i) {
    check_uint64("pi zero w ota second block byte",
                 sink.bytes[1][i],
                 image[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES + i]);
  }
  for (i = 0u;
       i < PI_TEST_OTA_IMAGE_LEN -
           (ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES * 2u);
       ++i) {
    check_uint64("pi zero w ota final block byte",
                 sink.bytes[2][i],
                 image[(ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES * 2u) + i]);
  }
}

static void test_pi_zero_w_v1_1_ota_rejects_bad_sequence(void) {
  enum {
    PI_TEST_OTA_BAD_IMAGE_LEN = 16u
  };

  ErPiZeroWV11OtaState state;
  TestPiZeroWV11OtaSink sink;
  ErCryptoProvider crypto;
  ErVfsObjectPacket object_packet;
  UINT8 image[PI_TEST_OTA_BAD_IMAGE_LEN];
  UINT8 frame[ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD];
  UINT32 frame_len;
  UINT32 i;

  er_crypto_blake3_provider(&crypto);
  er_mem_zero((UINT8*)&sink, (UINTN)sizeof(sink));
  erwire_init(ER_PI_ZERO_W_V1_1_OTA_ERWIRE_STREAM_ID);
  for (i = 0u; i < PI_TEST_OTA_BAD_IMAGE_LEN; ++i) {
    image[i] = (UINT8)(0xa0u + i);
  }
  er_pi_zero_w_v1_1_ota_reset(&state);
  check_int64("pi zero w ota bad vfs prepare",
              er_vfs_prepare_object_packet(&crypto,
                                           image,
                                           PI_TEST_OTA_BAD_IMAGE_LEN,
                                           0u,
                                           0u,
                                           1u,
                                           &object_packet),
              1);
  object_packet.header.packet_id.bytes[0] ^= 1u;
  test_pi_zero_w_v1_1_ota_erwire_object_frame(&object_packet,
                                              frame,
                                              &frame_len);
  check_int64("pi zero w ota rejects malformed vfs packet",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  &crypto,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              0);
  check_uint64("pi zero w ota rejected status",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED);
  check_uint64("pi zero w ota rejected no write", sink.write_count, 0u);
}

static void test_pi_zero_w_v1_1_ota_l2_receiver(void) {
  enum {
    PI_TEST_OTA_L2_IMAGE_LEN = 64u
  };

  static const UINT8 local_mac[ER_NET_MAC_LEN] = {
      PI_ZERO_W_V1_1_TEST_DST_MAC_0,
      PI_ZERO_W_V1_1_TEST_DST_MAC_1,
      PI_ZERO_W_V1_1_TEST_DST_MAC_2,
      PI_ZERO_W_V1_1_TEST_DST_MAC_3,
      PI_ZERO_W_V1_1_TEST_DST_MAC_4,
      PI_ZERO_W_V1_1_TEST_DST_MAC_5};
  static const UINT8 other_mac[ER_NET_MAC_LEN] = {
      PI_ZERO_W_V1_1_TEST_OTHER_MAC_0,
      PI_ZERO_W_V1_1_TEST_OTHER_MAC_1,
      PI_ZERO_W_V1_1_TEST_OTHER_MAC_2,
      PI_ZERO_W_V1_1_TEST_OTHER_MAC_3,
      PI_ZERO_W_V1_1_TEST_OTHER_MAC_4,
      PI_ZERO_W_V1_1_TEST_OTHER_MAC_5};
  static const UINT8 broadcast_mac[ER_NET_MAC_LEN] = {
      PI_ZERO_W_V1_1_TEST_BROADCAST_BYTE,
      PI_ZERO_W_V1_1_TEST_BROADCAST_BYTE,
      PI_ZERO_W_V1_1_TEST_BROADCAST_BYTE,
      PI_ZERO_W_V1_1_TEST_BROADCAST_BYTE,
      PI_ZERO_W_V1_1_TEST_BROADCAST_BYTE,
      PI_ZERO_W_V1_1_TEST_BROADCAST_BYTE};
  ErPiZeroWV11OtaState state;
  TestPiZeroWV11OtaSink sink;
  ErCryptoProvider crypto;
  ErVfsObjectPacket object_packet;
  UINT8 image[PI_TEST_OTA_L2_IMAGE_LEN];
  UINT8 frame[ER_NET_FRAME_MAX];
  UINT32 frame_len;
  UINT32 i;

  er_crypto_blake3_provider(&crypto);
  erwire_init(ER_PI_ZERO_W_V1_1_OTA_ERWIRE_STREAM_ID);
  for (i = 0u; i < PI_TEST_OTA_L2_IMAGE_LEN; ++i) {
    image[i] = (UINT8)(0x30u + i);
  }
  check_int64("pi zero w ota prepare l2 object packet",
              er_vfs_prepare_object_packet(&crypto,
                                           image,
                                           PI_TEST_OTA_L2_IMAGE_LEN,
                                           0u,
                                           0u,
                                           1u,
                                           &object_packet),
              1);

  er_pi_zero_w_v1_1_ota_reset(&state);
  er_mem_zero((UINT8*)&sink, (UINTN)sizeof(sink));
  test_pi_zero_w_v1_1_ota_eth_frame(&object_packet,
                                    broadcast_mac,
                                    ER_NET_ETH_TYPE_EDGERUN,
                                    frame,
                                    &frame_len);
  check_int64("pi zero w ota receive broadcast l2 erwire",
              er_pi_zero_w_v1_1_ota_receive_l2_frame(
                  &state,
                  &crypto,
                  local_mac,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  check_uint64("pi zero w ota l2 broadcast committed",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_COMMITTED);
  check_uint64("pi zero w ota l2 broadcast writes", sink.write_count, 1u);

  er_pi_zero_w_v1_1_ota_reset(&state);
  er_mem_zero((UINT8*)&sink, (UINTN)sizeof(sink));
  test_pi_zero_w_v1_1_ota_eth_frame(&object_packet,
                                    local_mac,
                                    ER_NET_ETH_TYPE_EDGERUN,
                                    frame,
                                    &frame_len);
  check_int64("pi zero w ota receive local l2 erwire",
              er_pi_zero_w_v1_1_ota_receive_l2_frame(
                  &state,
                  &crypto,
                  local_mac,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);

  er_pi_zero_w_v1_1_ota_reset(&state);
  test_pi_zero_w_v1_1_ota_eth_frame(&object_packet,
                                    other_mac,
                                    ER_NET_ETH_TYPE_EDGERUN,
                                    frame,
                                    &frame_len);
  check_int64("pi zero w ota rejects l2 wrong destination",
              er_pi_zero_w_v1_1_ota_receive_l2_frame(
                  &state,
                  &crypto,
                  local_mac,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              0);
  check_uint64("pi zero w ota l2 wrong destination rejected",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED);

  er_pi_zero_w_v1_1_ota_reset(&state);
  test_pi_zero_w_v1_1_ota_eth_frame(&object_packet,
                                    broadcast_mac,
                                    ER_NET_ETH_TYPE_IPV4,
                                    frame,
                                    &frame_len);
  check_int64("pi zero w ota rejects l2 wrong eth type",
              er_pi_zero_w_v1_1_ota_receive_l2_frame(
                  &state,
                  &crypto,
                  local_mac,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              0);
  check_uint64("pi zero w ota l2 wrong eth type rejected",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED);
}
