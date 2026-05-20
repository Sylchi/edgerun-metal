#include "er_pi_zero_w_v1_1_ota.h"
#include "er_mem.h"

enum {
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_MAGIC_OFFSET = 0u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_VERSION_OFFSET = 4u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_HEADER_SIZE_OFFSET = 6u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_STREAM_ID_OFFSET = 8u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_SEQ_OFFSET = 12u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_KIND_OFFSET = 16u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_FLAGS_OFFSET = 18u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_LEN_OFFSET = 20u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_CRC_OFFSET = 24u,
  ER_PI_ZERO_W_V1_1_OTA_ERWIRE_RESERVED_OFFSET = 28u,
  ER_PI_ZERO_W_V1_1_OTA_CRC32_INITIAL = 0xffffffffu,
  ER_PI_ZERO_W_V1_1_OTA_CRC32_POLY = 0xedb88320u,
  ER_PI_ZERO_W_V1_1_OTA_CRC32_BITS_PER_BYTE = 8u,
  ER_PI_ZERO_W_V1_1_OTA_U16_HIGH_SHIFT = 8u,
  ER_PI_ZERO_W_V1_1_OTA_U32_BYTE2_SHIFT = 16u,
  ER_PI_ZERO_W_V1_1_OTA_U32_BYTE3_SHIFT = 24u
};

typedef struct {
  UINT32 Magic;
  UINT16 Version;
  UINT16 HeaderSize;
  UINT32 StreamId;
  UINT32 Seq;
  UINT16 Kind;
  UINT16 Flags;
  UINT32 PayloadLen;
  UINT32 PayloadCrc;
  UINT32 Reserved;
} ErPiZeroWV11OtaErwirePacketHeader;

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
  er_mem_zero((UINT8*)state, (UINTN)sizeof(*state));
  state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_IDLE;
  state->target_block = ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK;
  state->next_block = ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK;
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

UINT8 er_pi_zero_w_v1_1_ota_encode_object_packet_payload(
    const ErVfsObjectPacket* packet,
    UINT8* out_payload,
    UINT32 out_payload_capacity,
    UINT32* out_payload_len) {
  UINT32 payload_len;

  if (packet == 0 ||
      out_payload == 0 ||
      out_payload_len == 0 ||
      packet->header.bytes_len > ER_VFS_OBJECT_PACKET_BYTES) {
    return 0u;
  }
  payload_len = (UINT32)sizeof(packet->header) + packet->header.bytes_len;
  if (payload_len > out_payload_capacity) {
    return 0u;
  }
  er_mem_copy(out_payload,
              (const UINT8*)&packet->header,
              (UINTN)sizeof(packet->header));
  if (packet->header.bytes_len != 0u) {
    er_mem_copy(out_payload + (UINT32)sizeof(packet->header),
                packet->bytes,
                packet->header.bytes_len);
  }
  *out_payload_len = payload_len;
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_ota_erwire_decode(
    const UINT8* frame,
    UINT32 frame_len,
    ErPiZeroWV11OtaErwirePacketHeader* out_header,
    const UINT8** out_payload) {
  UINT32 payload_crc;

  if (frame == 0 ||
      out_header == 0 ||
      out_payload == 0 ||
      frame_len < ER_PI_ZERO_W_V1_1_OTA_ERWIRE_HEADER_BYTES) {
    return 0u;
  }
  out_header->Magic =
      er_pi_zero_w_v1_1_ota_get_le32(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_MAGIC_OFFSET);
  out_header->Version =
      er_pi_zero_w_v1_1_ota_get_le16(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_VERSION_OFFSET);
  out_header->HeaderSize =
      er_pi_zero_w_v1_1_ota_get_le16(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_HEADER_SIZE_OFFSET);
  out_header->StreamId =
      er_pi_zero_w_v1_1_ota_get_le32(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_STREAM_ID_OFFSET);
  out_header->Seq =
      er_pi_zero_w_v1_1_ota_get_le32(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_SEQ_OFFSET);
  out_header->Kind =
      er_pi_zero_w_v1_1_ota_get_le16(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_KIND_OFFSET);
  out_header->Flags =
      er_pi_zero_w_v1_1_ota_get_le16(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_FLAGS_OFFSET);
  out_header->PayloadLen =
      er_pi_zero_w_v1_1_ota_get_le32(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_LEN_OFFSET);
  out_header->PayloadCrc =
      er_pi_zero_w_v1_1_ota_get_le32(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_CRC_OFFSET);
  out_header->Reserved =
      er_pi_zero_w_v1_1_ota_get_le32(
          frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_RESERVED_OFFSET);
  if (out_header->Magic != ER_PI_ZERO_W_V1_1_OTA_ERWIRE_MAGIC ||
      out_header->Version != ER_PI_ZERO_W_V1_1_OTA_ERWIRE_VERSION ||
      out_header->HeaderSize != ER_PI_ZERO_W_V1_1_OTA_ERWIRE_HEADER_BYTES ||
      out_header->Kind != ER_PI_ZERO_W_V1_1_OTA_ERWIRE_KIND_VFS_OBJECT_PACKET ||
      out_header->PayloadLen < (UINT32)sizeof(ErVfsObjectPacketHeader) ||
      out_header->PayloadLen > ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_BYTES_MAX ||
      out_header->Reserved != 0u ||
      frame_len != ER_PI_ZERO_W_V1_1_OTA_ERWIRE_HEADER_BYTES +
                   out_header->PayloadLen) {
    return 0u;
  }
  *out_payload = frame + ER_PI_ZERO_W_V1_1_OTA_ERWIRE_HEADER_BYTES;
  payload_crc = er_pi_zero_w_v1_1_ota_crc32(*out_payload,
                                            out_header->PayloadLen);
  return (UINT8)(payload_crc == out_header->PayloadCrc);
}

UINT8 er_pi_zero_w_v1_1_ota_decode_object_packet_payload(
    const UINT8* frame,
    UINT32 frame_len,
    ErVfsObjectPacket* out_packet) {
  ErPiZeroWV11OtaErwirePacketHeader header;
  const UINT8* payload;
  UINT32 bytes_len;

  if (out_packet == 0 ||
      er_pi_zero_w_v1_1_ota_erwire_decode(frame,
                                          frame_len,
                                          &header,
                                          &payload) == 0u) {
    return 0u;
  }
  bytes_len = header.PayloadLen - (UINT32)sizeof(out_packet->header);
  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  er_mem_copy((UINT8*)&out_packet->header,
              payload,
              (UINTN)sizeof(out_packet->header));
  if (bytes_len > 0u) {
    er_mem_copy(out_packet->bytes,
                payload + (UINT32)sizeof(out_packet->header),
                (UINTN)bytes_len);
  }
  return (UINT8)(out_packet->header.bytes_len == bytes_len &&
                 bytes_len <= ER_VFS_OBJECT_PACKET_BYTES);
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

static UINT8 er_pi_zero_w_v1_1_ota_write_bytes(
    ErPiZeroWV11OtaState* state,
    const UINT8* bytes,
    UINT32 bytes_len,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx) {
  UINT32 copied = 0u;

  if (state == 0 || bytes == 0 || write_block == 0) {
    return 0u;
  }
  while (copied < bytes_len) {
    UINT32 room = ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES - state->buffered_bytes;
    UINT32 chunk = bytes_len - copied;

    if (chunk > room) {
      chunk = room;
    }
    er_mem_copy(state->block + state->buffered_bytes,
                bytes + copied,
                (UINTN)chunk);
    state->buffered_bytes += chunk;
    copied += chunk;
    state->next_offset += chunk;
    if (state->buffered_bytes == ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES &&
        er_pi_zero_w_v1_1_ota_flush_block(state, write_block, write_ctx) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_ota_commit_object(
    ErPiZeroWV11OtaState* state,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx) {
  UINT32 packet_index;

  if (state == 0 ||
      write_block == 0 ||
      state->object_len == 0u ||
      state->accepted_packet_count == 0u ||
      state->packet_count == 0u ||
      state->packet_count > ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY ||
      state->accepted_packet_count != state->packet_count) {
    if (state != 0) {
      state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_WRITE_FAILED;
    }
    return 0u;
  }
  state->next_offset = 0u;
  state->next_block = state->target_block;
  state->buffered_bytes = 0u;
  er_pi_zero_w_v1_1_ota_zero(state->block,
                             ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES);
  for (packet_index = 0u;
       packet_index < state->packet_count;
       ++packet_index) {
    const ErVfsObjectPacket* packet = &state->packets[packet_index];

    if (state->packet_present[packet_index] == 0u ||
        packet->header.packet_index != packet_index ||
        er_pi_zero_w_v1_1_ota_write_bytes(state,
                                          packet->bytes,
                                          packet->header.bytes_len,
                                          write_block,
                                          write_ctx) == 0u) {
      state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_WRITE_FAILED;
      return 0u;
    }
  }
  if (state->next_offset != state->object_len ||
      (state->buffered_bytes != 0u &&
       er_pi_zero_w_v1_1_ota_flush_block(state, write_block, write_ctx) == 0u)) {
    state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_WRITE_FAILED;
    return 0u;
  }
  state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_STORED_UNBOOTABLE;
  state->reboot_required = 0u;
  return 1u;
}

UINT8 er_pi_zero_w_v1_1_ota_receive_frame(
    ErPiZeroWV11OtaState* state,
    const ErCryptoProvider* crypto,
    const UINT8* frame,
    UINT32 frame_len,
    ErPiZeroWV11OtaWriteBlockFn write_block,
    void* write_ctx) {
  ErVfsObjectPacket packet;
  UINT32 packet_index;

  if (state == 0 ||
      crypto == 0 ||
      er_pi_zero_w_v1_1_ota_decode_object_packet_payload(frame,
                                                         frame_len,
                                                         &packet) == 0u ||
      er_vfs_object_packet_valid(crypto, &packet) == 0u ||
      packet.header.packet_count > ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY) {
    if (state != 0) {
      state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED;
    }
    return 0u;
  }
  packet_index = packet.header.packet_index;
  if (state->accepted_packet_count == 0u) {
    state->object_id = packet.header.object_id;
    state->object_len = packet.header.object_len;
    state->packet_count = packet.header.packet_count;
  } else if (state->object_len != packet.header.object_len ||
             state->packet_count != packet.header.packet_count ||
             er_hash_equal(&state->object_id, &packet.header.object_id) == 0u ||
             state->packet_present[packet_index] != 0u) {
    state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_REJECTED;
    return 0u;
  }
  state->packets[packet_index] = packet;
  state->packet_present[packet_index] = 1u;
  state->accepted_packet_count += 1u;
  state->status = ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING;
  state->next_offset = (UINT32)packet.header.offset + packet.header.bytes_len;
  if (state->accepted_packet_count != state->packet_count) {
    return 1u;
  }
  return er_pi_zero_w_v1_1_ota_commit_object(state, write_block, write_ctx);
}
