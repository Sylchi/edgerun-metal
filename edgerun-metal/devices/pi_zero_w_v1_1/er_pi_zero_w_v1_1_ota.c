#include "er_pi_zero_w_v1_1_ota.h"

enum {
  ER_PI_ZERO_W_V1_1_OTA_MAGIC_OFFSET = 0u,
  ER_PI_ZERO_W_V1_1_OTA_VERSION_OFFSET = 4u,
  ER_PI_ZERO_W_V1_1_OTA_COMMAND_OFFSET = 6u,
  ER_PI_ZERO_W_V1_1_OTA_SEQUENCE_OFFSET = 8u,
  ER_PI_ZERO_W_V1_1_OTA_IMAGE_LEN_OFFSET = 12u,
  ER_PI_ZERO_W_V1_1_OTA_IMAGE_CRC32_OFFSET = 16u,
  ER_PI_ZERO_W_V1_1_OTA_PAYLOAD_OFFSET_OFFSET = 20u,
  ER_PI_ZERO_W_V1_1_OTA_PAYLOAD_LEN_OFFSET = 24u,
  ER_PI_ZERO_W_V1_1_OTA_HEADER_LEN_OFFSET = 26u,
  ER_PI_ZERO_W_V1_1_OTA_TARGET_BLOCK_OFFSET = 28u,
  ER_PI_ZERO_W_V1_1_OTA_CRC32_INITIAL = 0xffffffffu,
  ER_PI_ZERO_W_V1_1_OTA_CRC32_POLY = 0xedb88320u,
  ER_PI_ZERO_W_V1_1_OTA_CRC32_BITS_PER_BYTE = 8u,
  ER_PI_ZERO_W_V1_1_OTA_BYTE_MASK = 0xffu,
  ER_PI_ZERO_W_V1_1_OTA_U16_HIGH_SHIFT = 8u,
  ER_PI_ZERO_W_V1_1_OTA_U32_BYTE2_SHIFT = 16u,
  ER_PI_ZERO_W_V1_1_OTA_U32_BYTE3_SHIFT = 24u
};

static UINT16 er_pi_zero_w_v1_1_ota_get_le16(const UINT8* bytes) {
  return (UINT16)((UINT16)bytes[0] |
                  ((UINT16)bytes[1] << ER_PI_ZERO_W_V1_1_OTA_U16_HIGH_SHIFT));
}

static UINT32 er_pi_zero_w_v1_1_ota_get_le32(const UINT8* bytes) {
  return (UINT32)bytes[0] |
         ((UINT32)bytes[1] << ER_PI_ZERO_W_V1_1_OTA_U16_HIGH_SHIFT) |
         ((UINT32)bytes[2] << ER_PI_ZERO_W_V1_1_OTA_U32_BYTE2_SHIFT) |
         ((UINT32)bytes[3] << ER_PI_ZERO_W_V1_1_OTA_U32_BYTE3_SHIFT);
}

static void er_pi_zero_w_v1_1_ota_put_le16(UINT8* bytes, UINT16 value) {
  bytes[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_OTA_BYTE_MASK);
  bytes[1] = (UINT8)(((UINT32)value >> ER_PI_ZERO_W_V1_1_OTA_U16_HIGH_SHIFT) &
                     ER_PI_ZERO_W_V1_1_OTA_BYTE_MASK);
}

static void er_pi_zero_w_v1_1_ota_put_le32(UINT8* bytes, UINT32 value) {
  bytes[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_OTA_BYTE_MASK);
  bytes[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_OTA_U16_HIGH_SHIFT) &
                     ER_PI_ZERO_W_V1_1_OTA_BYTE_MASK);
  bytes[2] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_OTA_U32_BYTE2_SHIFT) &
                     ER_PI_ZERO_W_V1_1_OTA_BYTE_MASK);
  bytes[3] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_OTA_U32_BYTE3_SHIFT) &
                     ER_PI_ZERO_W_V1_1_OTA_BYTE_MASK);
}

static void er_pi_zero_w_v1_1_ota_zero(UINT8* bytes, UINT32 len) {
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    bytes[i] = 0u;
  }
}

void er_pi_zero_w_v1_1_ota_reset(ErPiZeroWV11OtaState* state) {
  if (state == 0) {
    return;
  }
  state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_IDLE;
  state->image_len = 0u;
  state->image_crc32 = 0u;
  state->running_crc32 = ER_PI_ZERO_W_V1_1_OTA_CRC32_INITIAL;
  state->next_offset = 0u;
  state->target_block = ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK;
  state->next_block = ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK;
  state->buffered_bytes = 0u;
  state->reboot_required = 0u;
  er_pi_zero_w_v1_1_ota_zero(state->block,
                             ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES);
}

UINT32 er_pi_zero_w_v1_1_ota_crc32(const UINT8* bytes, UINT32 len) {
  UINT32 crc = ER_PI_ZERO_W_V1_1_OTA_CRC32_INITIAL;
  UINT32 i;

  if (bytes == 0 && len != 0u) {
    return 0u;
  }
  for (i = 0u; i < len; ++i) {
    UINT32 bit;

    crc ^= (UINT32)bytes[i];
    for (bit = 0u;
         bit < ER_PI_ZERO_W_V1_1_OTA_CRC32_BITS_PER_BYTE;
         ++bit) {
      UINT32 mask = 0u - (crc & 1u);

      crc = (crc >> 1u) ^ (ER_PI_ZERO_W_V1_1_OTA_CRC32_POLY & mask);
    }
  }
  return ~crc;
}

static UINT32 er_pi_zero_w_v1_1_ota_crc32_extend(UINT32 running_crc32,
                                                 const UINT8* bytes,
                                                 UINT32 len) {
  UINT32 crc = running_crc32;
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    UINT32 bit;

    crc ^= (UINT32)bytes[i];
    for (bit = 0u;
         bit < ER_PI_ZERO_W_V1_1_OTA_CRC32_BITS_PER_BYTE;
         ++bit) {
      UINT32 mask = 0u - (crc & 1u);

      crc = (crc >> 1u) ^ (ER_PI_ZERO_W_V1_1_OTA_CRC32_POLY & mask);
    }
  }
  return crc;
}

UINT8 er_pi_zero_w_v1_1_ota_header_decode(
    const UINT8* frame,
    UINT32 frame_len,
    ErPiZeroWV11OtaFrameHeader* out_header) {
  if (frame == 0 ||
      out_header == 0 ||
      frame_len < ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES) {
    return 0u;
  }
  out_header->magic =
      er_pi_zero_w_v1_1_ota_get_le32(frame + ER_PI_ZERO_W_V1_1_OTA_MAGIC_OFFSET);
  out_header->version =
      er_pi_zero_w_v1_1_ota_get_le16(frame + ER_PI_ZERO_W_V1_1_OTA_VERSION_OFFSET);
  out_header->command =
      er_pi_zero_w_v1_1_ota_get_le16(frame + ER_PI_ZERO_W_V1_1_OTA_COMMAND_OFFSET);
  out_header->sequence =
      er_pi_zero_w_v1_1_ota_get_le32(frame + ER_PI_ZERO_W_V1_1_OTA_SEQUENCE_OFFSET);
  out_header->image_len =
      er_pi_zero_w_v1_1_ota_get_le32(frame + ER_PI_ZERO_W_V1_1_OTA_IMAGE_LEN_OFFSET);
  out_header->image_crc32 =
      er_pi_zero_w_v1_1_ota_get_le32(frame + ER_PI_ZERO_W_V1_1_OTA_IMAGE_CRC32_OFFSET);
  out_header->offset =
      er_pi_zero_w_v1_1_ota_get_le32(frame + ER_PI_ZERO_W_V1_1_OTA_PAYLOAD_OFFSET_OFFSET);
  out_header->payload_len =
      er_pi_zero_w_v1_1_ota_get_le16(frame + ER_PI_ZERO_W_V1_1_OTA_PAYLOAD_LEN_OFFSET);
  out_header->header_len =
      er_pi_zero_w_v1_1_ota_get_le16(frame + ER_PI_ZERO_W_V1_1_OTA_HEADER_LEN_OFFSET);
  out_header->target_block =
      er_pi_zero_w_v1_1_ota_get_le32(frame + ER_PI_ZERO_W_V1_1_OTA_TARGET_BLOCK_OFFSET);
  return (UINT8)(out_header->magic == ER_PI_ZERO_W_V1_1_OTA_MAGIC &&
                 out_header->version == ER_PI_ZERO_W_V1_1_OTA_ABI_VERSION &&
                 out_header->header_len == ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES &&
                 out_header->payload_len <= ER_PI_ZERO_W_V1_1_OTA_FRAME_PAYLOAD_MAX &&
                 frame_len == (UINT32)out_header->header_len +
                              (UINT32)out_header->payload_len);
}

static UINT8 er_pi_zero_w_v1_1_ota_header_payload_valid(
    const ErPiZeroWV11OtaFrameHeader* header) {
  if (header == 0 ||
      header->image_len == 0u ||
      header->image_len > ER_PI_ZERO_W_V1_1_OTA_IMAGE_BYTES_MAX ||
      header->target_block == 0u) {
    return 0u;
  }
  switch (header->command) {
    case ER_PI_ZERO_W_V1_1_OTA_COMMAND_BEGIN:
    case ER_PI_ZERO_W_V1_1_OTA_COMMAND_COMMIT:
      return (UINT8)(header->offset == 0u && header->payload_len == 0u);
    case ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA:
      return (UINT8)(header->payload_len != 0u &&
                     header->offset < header->image_len &&
                     (UINT32)header->payload_len <=
                         header->image_len - header->offset);
    default:
      return 0u;
  }
}

static UINT8 er_pi_zero_w_v1_1_ota_flush_block(
    ErPiZeroWV11OtaState* state,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx) {
  if (state == 0 || write_block == 0) {
    return 0u;
  }
  if (write_block(write_ctx, state->next_block, state->block) == 0u) {
    state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_WRITE_FAILED;
    return 0u;
  }
  state->next_block += 1u;
  state->buffered_bytes = 0u;
  er_pi_zero_w_v1_1_ota_zero(state->block,
                             ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES);
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_ota_begin(
    ErPiZeroWV11OtaState* state,
    const ErPiZeroWV11OtaFrameHeader* header) {
  if (state == 0 || header == 0 ||
      er_pi_zero_w_v1_1_ota_header_payload_valid(header) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_ota_reset(state);
  state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING;
  state->image_len = header->image_len;
  state->image_crc32 = header->image_crc32;
  state->target_block = header->target_block;
  state->next_block = header->target_block;
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_ota_data(
    ErPiZeroWV11OtaState* state,
    const ErPiZeroWV11OtaFrameHeader* header,
    const UINT8* payload,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx) {
  UINT32 copied;

  if (state == 0 ||
      header == 0 ||
      payload == 0 ||
      state->status != ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING ||
      header->image_len != state->image_len ||
      header->image_crc32 != state->image_crc32 ||
      header->target_block != state->target_block ||
      header->offset != state->next_offset ||
      er_pi_zero_w_v1_1_ota_header_payload_valid(header) == 0u) {
    if (state != 0) {
      state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED;
    }
    return 0u;
  }

  state->running_crc32 =
      er_pi_zero_w_v1_1_ota_crc32_extend(state->running_crc32,
                                         payload,
                                         (UINT32)header->payload_len);
  copied = 0u;
  while (copied < (UINT32)header->payload_len) {
    UINT32 room = ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES - state->buffered_bytes;
    UINT32 chunk = (UINT32)header->payload_len - copied;
    UINT32 i;

    if (chunk > room) {
      chunk = room;
    }
    for (i = 0u; i < chunk; ++i) {
      state->block[state->buffered_bytes + i] = payload[copied + i];
    }
    state->buffered_bytes += chunk;
    copied += chunk;
    if (state->buffered_bytes == ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES &&
        er_pi_zero_w_v1_1_ota_flush_block(state, write_block, write_ctx) == 0u) {
      return 0u;
    }
  }
  state->next_offset += (UINT32)header->payload_len;
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_ota_commit(
    ErPiZeroWV11OtaState* state,
    const ErPiZeroWV11OtaFrameHeader* header,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx) {
  UINT32 final_crc;

  if (state == 0 ||
      header == 0 ||
      state->status != ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING ||
      header->image_len != state->image_len ||
      header->image_crc32 != state->image_crc32 ||
      header->target_block != state->target_block ||
      state->next_offset != state->image_len ||
      er_pi_zero_w_v1_1_ota_header_payload_valid(header) == 0u) {
    if (state != 0) {
      state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED;
    }
    return 0u;
  }
  final_crc = ~state->running_crc32;
  if (final_crc != state->image_crc32) {
    state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED;
    return 0u;
  }
  if (state->buffered_bytes != 0u &&
      er_pi_zero_w_v1_1_ota_flush_block(state, write_block, write_ctx) == 0u) {
    return 0u;
  }
  state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_COMMITTED;
  state->reboot_required = 1u;
  return 1u;
}

UINT8 er_pi_zero_w_v1_1_ota_receive_frame(
    ErPiZeroWV11OtaState* state,
    const UINT8* frame,
    UINT32 frame_len,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx) {
  ErPiZeroWV11OtaFrameHeader header;
  const UINT8* payload;

  if (er_pi_zero_w_v1_1_ota_header_decode(frame, frame_len, &header) == 0u) {
    if (state != 0) {
      state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED;
    }
    return 0u;
  }
  payload = frame + ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES;
  switch (header.command) {
    case ER_PI_ZERO_W_V1_1_OTA_COMMAND_BEGIN:
      return er_pi_zero_w_v1_1_ota_begin(state, &header);
    case ER_PI_ZERO_W_V1_1_OTA_COMMAND_DATA:
      return er_pi_zero_w_v1_1_ota_data(state,
                                        &header,
                                        payload,
                                        write_block,
                                        write_ctx);
    case ER_PI_ZERO_W_V1_1_OTA_COMMAND_COMMIT:
      return er_pi_zero_w_v1_1_ota_commit(state,
                                          &header,
                                          write_block,
                                          write_ctx);
    default:
      if (state != 0) {
        state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED;
      }
      return 0u;
  }
}

UINT8 er_pi_zero_w_v1_1_ota_build_header(
    const ErPiZeroWV11OtaFrameHeader* header,
    UINT8 out_header[ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES]) {
  if (header == 0 || out_header == 0) {
    return 0u;
  }
  er_pi_zero_w_v1_1_ota_zero(out_header,
                             ER_PI_ZERO_W_V1_1_OTA_HEADER_BYTES);
  er_pi_zero_w_v1_1_ota_put_le32(out_header + ER_PI_ZERO_W_V1_1_OTA_MAGIC_OFFSET,
                                 header->magic);
  er_pi_zero_w_v1_1_ota_put_le16(out_header + ER_PI_ZERO_W_V1_1_OTA_VERSION_OFFSET,
                                 header->version);
  er_pi_zero_w_v1_1_ota_put_le16(out_header + ER_PI_ZERO_W_V1_1_OTA_COMMAND_OFFSET,
                                 header->command);
  er_pi_zero_w_v1_1_ota_put_le32(out_header + ER_PI_ZERO_W_V1_1_OTA_SEQUENCE_OFFSET,
                                 header->sequence);
  er_pi_zero_w_v1_1_ota_put_le32(out_header + ER_PI_ZERO_W_V1_1_OTA_IMAGE_LEN_OFFSET,
                                 header->image_len);
  er_pi_zero_w_v1_1_ota_put_le32(out_header + ER_PI_ZERO_W_V1_1_OTA_IMAGE_CRC32_OFFSET,
                                 header->image_crc32);
  er_pi_zero_w_v1_1_ota_put_le32(out_header + ER_PI_ZERO_W_V1_1_OTA_PAYLOAD_OFFSET_OFFSET,
                                 header->offset);
  er_pi_zero_w_v1_1_ota_put_le16(out_header + ER_PI_ZERO_W_V1_1_OTA_PAYLOAD_LEN_OFFSET,
                                 header->payload_len);
  er_pi_zero_w_v1_1_ota_put_le16(out_header + ER_PI_ZERO_W_V1_1_OTA_HEADER_LEN_OFFSET,
                                 header->header_len);
  er_pi_zero_w_v1_1_ota_put_le32(out_header + ER_PI_ZERO_W_V1_1_OTA_TARGET_BLOCK_OFFSET,
                                 header->target_block);
  return 1u;
}
