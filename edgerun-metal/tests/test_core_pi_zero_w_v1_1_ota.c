typedef struct {
  UINT32 write_count;
  UINT32 fail_block;
  UINT32 blocks[4];
  UINT8 bytes[4][ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES];
} TestPiZeroWV11OtaSink;

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

static void test_pi_zero_w_v1_1_ota_frame(
    UINT16 command,
    UINT32 sequence,
    UINT32 image_len,
    UINT32 image_crc32,
    UINT32 offset,
    UINT32 target_block,
    const UINT8* payload,
    UINT16 payload_len,
    UINT8* out_frame,
    UINT32* out_frame_len) {
  ErPiZeroWV11OtaFrameHeader header;
  UINT32 i;

  header.magic = ER_PI_ZERO_W_V1_1_OTA_MAGIC;
  header.version = ER_PI_ZERO_W_V1_1_OTA_ABI_VERSION;
  header.command = command;
  header.sequence = sequence;
  header.image_len = image_len;
  header.image_crc32 = image_crc32;
  header.offset = offset;
  header.payload_len = payload_len;
  header.header_len = ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES;
  header.target_block = target_block;
  check_int64("pi zero w ota build header",
              er_pi_zero_w_v1_1_ota_build_header(&header, out_frame),
              1);
  for (i = 0u; i < payload_len; ++i) {
    out_frame[ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES + i] = payload[i];
  }
  *out_frame_len = ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES + payload_len;
}

static void test_pi_zero_w_v1_1_ota_receiver(void) {
  enum {
    PI_TEST_OTA_IMAGE_LEN = 700u,
    PI_TEST_OTA_CHUNK_LEN = 96u,
    PI_TEST_OTA_FIRST_FLUSH_OFFSET = 480u,
    PI_TEST_OTA_TAIL_OFFSET = 672u,
    PI_TEST_OTA_TAIL_LEN = 28u,
    PI_TEST_OTA_TARGET_BLOCK = 9000u
  };

  ErPiZeroWV11OtaState state;
  TestPiZeroWV11OtaSink sink;
  ErPiZeroWV11OtaFrameHeader decoded;
  UINT8 image[PI_TEST_OTA_IMAGE_LEN];
  UINT8 frame[ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES +
              ER_PI_ZERO_W_V1_1_OTA_FRAME_PAYLOAD_MAX];
  UINT32 frame_len;
  UINT32 image_crc32;
  UINT32 i;

  er_mem_zero((UINT8*)&sink, (UINTN)sizeof(sink));
  for (i = 0u; i < PI_TEST_OTA_IMAGE_LEN; ++i) {
    image[i] = (UINT8)(i * 17u + 3u);
  }
  image_crc32 = er_pi_zero_w_v1_1_ota_crc32(image, PI_TEST_OTA_IMAGE_LEN);
  er_pi_zero_w_v1_1_ota_reset(&state);
  check_uint64("pi zero w ota reset status",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_IDLE);
  check_uint64("pi zero w ota reset target",
               state.target_block,
               ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK);

  test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_BEGIN,
                                1u,
                                PI_TEST_OTA_IMAGE_LEN,
                                image_crc32,
                                0u,
                                PI_TEST_OTA_TARGET_BLOCK,
                                0,
                                0u,
                                frame,
                                &frame_len);
  check_int64("pi zero w ota decode begin",
              er_pi_zero_w_v1_1_ota_header_decode(frame,
                                                  frame_len,
                                                  &decoded),
              1);
  check_uint64("pi zero w ota decoded target",
               decoded.target_block,
               PI_TEST_OTA_TARGET_BLOCK);
  check_int64("pi zero w ota begin",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  check_uint64("pi zero w ota receiving",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING);

  for (i = 0u; i < PI_TEST_OTA_FIRST_FLUSH_OFFSET; i += PI_TEST_OTA_CHUNK_LEN) {
    test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA,
                                  2u + (i / PI_TEST_OTA_CHUNK_LEN),
                                  PI_TEST_OTA_IMAGE_LEN,
                                  image_crc32,
                                  i,
                                  PI_TEST_OTA_TARGET_BLOCK,
                                  image + i,
                                  PI_TEST_OTA_CHUNK_LEN,
                                  frame,
                                  &frame_len);
    check_int64("pi zero w ota data before flush",
                er_pi_zero_w_v1_1_ota_receive_frame(
                    &state,
                    frame,
                    frame_len,
                    test_pi_zero_w_v1_1_ota_write_block,
                    &sink),
                1);
  }
  check_uint64("pi zero w ota no full block yet", sink.write_count, 0u);
  check_uint64("pi zero w ota next offset before flush",
               state.next_offset,
               PI_TEST_OTA_FIRST_FLUSH_OFFSET);

  test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA,
                                7u,
                                PI_TEST_OTA_IMAGE_LEN,
                                image_crc32,
                                PI_TEST_OTA_FIRST_FLUSH_OFFSET,
                                PI_TEST_OTA_TARGET_BLOCK,
                                image + PI_TEST_OTA_FIRST_FLUSH_OFFSET,
                                PI_TEST_OTA_CHUNK_LEN,
                                frame,
                                &frame_len);
  check_int64("pi zero w ota data flush",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  check_uint64("pi zero w ota first block written", sink.write_count, 1u);
  check_uint64("pi zero w ota first block address",
               sink.blocks[0],
               PI_TEST_OTA_TARGET_BLOCK);
  check_uint64("pi zero w ota next offset second",
               state.next_offset,
               PI_TEST_OTA_FIRST_FLUSH_OFFSET + PI_TEST_OTA_CHUNK_LEN);
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES; ++i) {
    check_uint64("pi zero w ota first block byte", sink.bytes[0][i], image[i]);
  }

  test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA,
                                8u,
                                PI_TEST_OTA_IMAGE_LEN,
                                image_crc32,
                                PI_TEST_OTA_FIRST_FLUSH_OFFSET +
                                    PI_TEST_OTA_CHUNK_LEN,
                                PI_TEST_OTA_TARGET_BLOCK,
                                image + PI_TEST_OTA_FIRST_FLUSH_OFFSET +
                                    PI_TEST_OTA_CHUNK_LEN,
                                PI_TEST_OTA_CHUNK_LEN,
                                frame,
                                &frame_len);
  check_int64("pi zero w ota data tail full",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA,
                                9u,
                                PI_TEST_OTA_IMAGE_LEN,
                                image_crc32,
                                PI_TEST_OTA_TAIL_OFFSET,
                                PI_TEST_OTA_TARGET_BLOCK,
                                image + PI_TEST_OTA_TAIL_OFFSET,
                                PI_TEST_OTA_TAIL_LEN,
                                frame,
                                &frame_len);
  check_int64("pi zero w ota data tail partial",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);

  test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_COMMIT,
                                4u,
                                PI_TEST_OTA_IMAGE_LEN,
                                image_crc32,
                                0u,
                                PI_TEST_OTA_TARGET_BLOCK,
                                0,
                                0u,
                                frame,
                                &frame_len);
  check_int64("pi zero w ota commit",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  check_uint64("pi zero w ota committed",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_COMMITTED);
  check_uint64("pi zero w ota reboot required", state.reboot_required, 1u);
  check_uint64("pi zero w ota final block written", sink.write_count, 2u);
  check_uint64("pi zero w ota final block address",
               sink.blocks[1],
               PI_TEST_OTA_TARGET_BLOCK + 1u);
  for (i = 0u; i < PI_TEST_OTA_IMAGE_LEN - ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES;
       ++i) {
    check_uint64("pi zero w ota final block byte",
                 sink.bytes[1][i],
                 image[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES + i]);
  }
}

static void test_pi_zero_w_v1_1_ota_rejects_bad_sequence(void) {
  enum {
    PI_TEST_OTA_BAD_IMAGE_LEN = 16u,
    PI_TEST_OTA_BAD_TARGET_BLOCK = 44u
  };

  ErPiZeroWV11OtaState state;
  TestPiZeroWV11OtaSink sink;
  UINT8 image[PI_TEST_OTA_BAD_IMAGE_LEN];
  UINT8 frame[ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES +
              ER_PI_ZERO_W_V1_1_OTA_FRAME_PAYLOAD_MAX];
  UINT32 frame_len;
  UINT32 image_crc32;
  UINT32 i;

  er_mem_zero((UINT8*)&sink, (UINTN)sizeof(sink));
  for (i = 0u; i < PI_TEST_OTA_BAD_IMAGE_LEN; ++i) {
    image[i] = (UINT8)(0xa0u + i);
  }
  image_crc32 =
      er_pi_zero_w_v1_1_ota_crc32(image, PI_TEST_OTA_BAD_IMAGE_LEN);
  er_pi_zero_w_v1_1_ota_reset(&state);
  test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_BEGIN,
                                1u,
                                PI_TEST_OTA_BAD_IMAGE_LEN,
                                image_crc32,
                                0u,
                                PI_TEST_OTA_BAD_TARGET_BLOCK,
                                0,
                                0u,
                                frame,
                                &frame_len);
  check_int64("pi zero w ota bad begin",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              1);
  test_pi_zero_w_v1_1_ota_frame(ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA,
                                2u,
                                PI_TEST_OTA_BAD_IMAGE_LEN,
                                image_crc32,
                                4u,
                                PI_TEST_OTA_BAD_TARGET_BLOCK,
                                image,
                                PI_TEST_OTA_BAD_IMAGE_LEN,
                                frame,
                                &frame_len);
  check_int64("pi zero w ota rejects skipped offset",
              er_pi_zero_w_v1_1_ota_receive_frame(
                  &state,
                  frame,
                  frame_len,
                  test_pi_zero_w_v1_1_ota_write_block,
                  &sink),
              0);
  check_uint64("pi zero w ota rejected status",
               state.status,
               ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED);
}
