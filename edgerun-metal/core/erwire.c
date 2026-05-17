#include "erwire.h"
#include "er_hw_relay.h"
#include "er_mem.h"

/*
 * Purpose: serialize and parse small binary EdgeRun wire packets.
 * Intention: keep the firmware side allocation-free and endian-explicit.
 */

#define ERWIRE_PACKET_MAX (ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD)
#define ERWIRE_BLOB_CHUNK_HEADER_SIZE (ER_HASH_LEN + 12u)
#define ERWIRE_PCI_DEVICE_SIZE 56u
#define ERWIRE_U16_BYTES 2u
#define ERWIRE_U32_BYTES 4u
#define ERWIRE_PCI_BAR_COUNT 6u
#define ERWIRE_BYTE0 0u
#define ERWIRE_BYTE1 1u
#define ERWIRE_BYTE2 2u
#define ERWIRE_BYTE3 3u
#define ERWIRE_U8_MASK 0xffu
#define ERWIRE_U16_HIGH_SHIFT 8u
#define ERWIRE_U32_BYTE2_SHIFT 16u
#define ERWIRE_U32_BYTE3_SHIFT 24u
#define ERWIRE_CRC32_INITIAL 0xffffffffu
#define ERWIRE_CRC32_POLY 0xedb88320u
#define ERWIRE_CRC32_BITS_PER_BYTE 8u
#define ERWIRE_HEADER_MAGIC_OFFSET 0u
#define ERWIRE_HEADER_VERSION_OFFSET 4u
#define ERWIRE_HEADER_SIZE_OFFSET 6u
#define ERWIRE_HEADER_STREAM_ID_OFFSET 8u
#define ERWIRE_HEADER_SEQ_OFFSET 12u
#define ERWIRE_HEADER_KIND_OFFSET 16u
#define ERWIRE_HEADER_FLAGS_OFFSET 18u
#define ERWIRE_HEADER_PAYLOAD_LEN_OFFSET 20u
#define ERWIRE_HEADER_PAYLOAD_CRC_OFFSET 24u
#define ERWIRE_HEADER_RESERVED_OFFSET 28u

static UINT32 g_stream_id = 1u;
static UINT32 g_seq;
static UINT8 g_packet[ERWIRE_PACKET_MAX];
static ErNativeEth* g_native_eth;
static ErChannelEndpoint g_native_eth_endpoint;
static UINT8 g_use_native_eth;

static UINT32 erwire_len(const char* s) {
  UINT32 n = 0;

  if (s == 0) {
    return 0;
  }
  while (s[n] != 0) {
    ++n;
  }
  return n;
}

static UINT16 erwire_get_u16(const UINT8* src) {
  return (UINT16)((UINT16)src[ERWIRE_BYTE0] |
                  (UINT16)((UINT16)src[ERWIRE_BYTE1] << ERWIRE_U16_HIGH_SHIFT));
}

static UINT32 erwire_get_u32(const UINT8* src) {
  return (UINT32)src[ERWIRE_BYTE0] |
         ((UINT32)src[ERWIRE_BYTE1] << ERWIRE_U16_HIGH_SHIFT) |
         ((UINT32)src[ERWIRE_BYTE2] << ERWIRE_U32_BYTE2_SHIFT) |
         ((UINT32)src[ERWIRE_BYTE3] << ERWIRE_U32_BYTE3_SHIFT);
}

static void erwire_put_u16(UINT8* dst, UINT16 value) {
  dst[ERWIRE_BYTE0] = (UINT8)(value & ERWIRE_U8_MASK);
  dst[ERWIRE_BYTE1] = (UINT8)((value >> ERWIRE_U16_HIGH_SHIFT) & ERWIRE_U8_MASK);
}

static void erwire_put_u32(UINT8* dst, UINT32 value) {
  dst[ERWIRE_BYTE0] = (UINT8)(value & ERWIRE_U8_MASK);
  dst[ERWIRE_BYTE1] = (UINT8)((value >> ERWIRE_U16_HIGH_SHIFT) & ERWIRE_U8_MASK);
  dst[ERWIRE_BYTE2] = (UINT8)((value >> ERWIRE_U32_BYTE2_SHIFT) & ERWIRE_U8_MASK);
  dst[ERWIRE_BYTE3] = (UINT8)((value >> ERWIRE_U32_BYTE3_SHIFT) & ERWIRE_U8_MASK);
}

static void erwire_write_u16(UINT8** cursor, UINT16 value) {
  erwire_put_u16(*cursor, value);
  *cursor += ERWIRE_U16_BYTES;
}

static void erwire_write_u32(UINT8** cursor, UINT32 value) {
  erwire_put_u32(*cursor, value);
  *cursor += ERWIRE_U32_BYTES;
}

static UINT32 erwire_crc32(const UINT8* data, UINT32 len) {
  UINT32 crc = ERWIRE_CRC32_INITIAL;
  UINT32 i;

  if (data == 0) {
    return 0u;
  }
  for (i = 0; i < len; ++i) {
    UINT32 bit;
    crc ^= (UINT32)data[i];
    for (bit = 0; bit < ERWIRE_CRC32_BITS_PER_BYTE; ++bit) {
      UINT32 mask = 0u - (crc & 1u);
      crc = (crc >> 1) ^ (ERWIRE_CRC32_POLY & mask);
    }
  }
  return ~crc;
}

static void erwire_prepare_memory_endpoint(ErChannelEndpoint* endpoint) {
  static const char label[] = "erwire";

  if (endpoint == 0) {
    return;
  }
  er_mem_zero((UINT8*)endpoint, (UINTN)sizeof(*endpoint));
  endpoint->abi_version = ER_WORK_ABI_VERSION;
  endpoint->kind = ER_CHANNEL_KIND_MEMORY;
  endpoint->label_len = (UINT16)(sizeof(label) - 1u);
  er_mem_copy((UINT8*)endpoint->label, (const UINT8*)label, (UINTN)(sizeof(label) - 1u));
}

void erwire_init(UINT32 stream_id) {
  g_stream_id = (stream_id == 0u) ? 1u : stream_id;
  g_seq = 0;
}

UINT8 erwire_set_native_eth_sink(ErNativeEth* native_eth) {
  static const char label[] = "erwire-l2";

  if (native_eth == 0 ||
      er_hw_relay_prepare_native_eth_endpoint(native_eth->peer_mac, label,
                                              (UINTN)(sizeof(label) - 1u),
                                              &g_native_eth_endpoint) == 0u) {
    return 0;
  }
  g_native_eth = native_eth;
  g_use_native_eth = 1u;
  return 1;
}

void erwire_clear_native_eth_sink(void) {
  g_native_eth = 0;
  g_use_native_eth = 0u;
  er_mem_zero((UINT8*)&g_native_eth_endpoint, (UINTN)sizeof(g_native_eth_endpoint));
}

UINT8 erwire_parse_packet(const UINT8* packet, UINT32 packet_len,
                          ErwirePacketHeader* out_header,
                          UINT8* out_payload, UINT32 out_capacity,
                          UINT32* out_payload_len) {
  ErwirePacketHeader header;
  UINT32 expected_len;

  if (packet == 0 || out_header == 0 || out_payload_len == 0 ||
      packet_len < ERWIRE_HEADER_SIZE) {
    return 0;
  }
  *out_payload_len = 0u;
  header.Magic = erwire_get_u32(packet + ERWIRE_HEADER_MAGIC_OFFSET);
  header.Version = erwire_get_u16(packet + ERWIRE_HEADER_VERSION_OFFSET);
  header.HeaderSize = erwire_get_u16(packet + ERWIRE_HEADER_SIZE_OFFSET);
  header.StreamId = erwire_get_u32(packet + ERWIRE_HEADER_STREAM_ID_OFFSET);
  header.Seq = erwire_get_u32(packet + ERWIRE_HEADER_SEQ_OFFSET);
  header.Kind = erwire_get_u16(packet + ERWIRE_HEADER_KIND_OFFSET);
  header.Flags = erwire_get_u16(packet + ERWIRE_HEADER_FLAGS_OFFSET);
  header.PayloadLen = erwire_get_u32(packet + ERWIRE_HEADER_PAYLOAD_LEN_OFFSET);
  header.PayloadCrc = erwire_get_u32(packet + ERWIRE_HEADER_PAYLOAD_CRC_OFFSET);
  header.Reserved = erwire_get_u32(packet + ERWIRE_HEADER_RESERVED_OFFSET);

  expected_len = ERWIRE_HEADER_SIZE + header.PayloadLen;
  if (header.Magic != ERWIRE_MAGIC || header.Version != ERWIRE_VERSION ||
      header.HeaderSize != ERWIRE_HEADER_SIZE || header.PayloadLen > ERWIRE_MAX_PAYLOAD ||
      header.Reserved != 0u || expected_len != packet_len ||
      header.PayloadLen > out_capacity ||
      erwire_crc32(packet + ERWIRE_HEADER_SIZE, header.PayloadLen) != header.PayloadCrc) {
    return 0;
  }
  if (header.PayloadLen > 0u && out_payload == 0) {
    return 0;
  }
  *out_header = header;
  if (header.PayloadLen > 0u) {
    er_mem_copy(out_payload, packet + ERWIRE_HEADER_SIZE, (UINTN)header.PayloadLen);
  }
  *out_payload_len = header.PayloadLen;
  return 1;
}

UINT8 erwire_poll_native_eth(ErwirePacketHeader* out_header,
                             UINT8* out_payload, UINT32 out_capacity,
                             UINT32* out_payload_len) {
  UINT8 packet[ERWIRE_PACKET_MAX];
  UINT32 packet_len = 0u;

  if (out_payload_len == 0) {
    return 0;
  }
  *out_payload_len = 0u;
  if (g_use_native_eth == 0u || g_native_eth == 0 ||
      er_native_eth_recv(g_native_eth, packet, (UINT32)sizeof(packet),
                         &packet_len) == 0u) {
    return 0;
  }
  return erwire_parse_packet(packet, packet_len, out_header, out_payload,
                             out_capacity, out_payload_len);
}

void erwire_send(UINT16 kind, UINT16 flags, const UINT8* payload, UINT32 payload_len) {
  UINT8* packet_cursor = g_packet;
  UINT32 send_len;
  ErRelayForwardIntent intent;

  if (payload_len > ERWIRE_MAX_PAYLOAD || (payload_len > 0u && payload == 0)) {
    return;
  }

  erwire_write_u32(&packet_cursor, ERWIRE_MAGIC);
  erwire_write_u16(&packet_cursor, ERWIRE_VERSION);
  erwire_write_u16(&packet_cursor, ERWIRE_HEADER_SIZE);
  erwire_write_u32(&packet_cursor, g_stream_id);
  erwire_write_u32(&packet_cursor, g_seq);
  erwire_write_u16(&packet_cursor, kind);
  erwire_write_u16(&packet_cursor, flags);
  erwire_write_u32(&packet_cursor, payload_len);
  erwire_write_u32(&packet_cursor, erwire_crc32(payload, payload_len));
  erwire_write_u32(&packet_cursor, 0u);

  if (payload_len > 0u) {
    er_mem_copy(&g_packet[ERWIRE_HEADER_SIZE], payload, (UINTN)payload_len);
  }
  send_len = ERWIRE_HEADER_SIZE + payload_len;
  er_mem_zero((UINT8*)&intent, (UINTN)sizeof(intent));
  intent.abi_version = ER_WORK_ABI_VERSION;
  erwire_prepare_memory_endpoint(&intent.from);
  if (g_use_native_eth != 0u && g_native_eth != 0) {
    intent.to = g_native_eth_endpoint;
    (void)er_hw_relay_forward_to_native_eth(g_native_eth, &intent, g_packet, (UINTN)send_len);
  } else if (er_hw_relay_default_firmware_udp_endpoint(&intent.to) != 0u) {
    (void)er_hw_relay_forward_to_firmware_udp(&intent, g_packet, (UINTN)send_len);
  }
  ++g_seq;
}

void erwire_send_text(const char* s) {
  UINT32 len = erwire_len(s);
  UINT32 offset = 0;

  while (offset < len) {
    UINT32 chunk = len - offset;
    UINT16 flags = 0;

    if (chunk > ERWIRE_MAX_PAYLOAD) {
      chunk = ERWIRE_MAX_PAYLOAD;
    }
    if (offset == 0u) {
      flags |= ERWIRE_FLAG_FIRST;
    }
    if (offset + chunk >= len) {
      flags |= ERWIRE_FLAG_LAST;
    }
    erwire_send(ERWIRE_KIND_LOG_TEXT, flags, (const UINT8*)s + offset, chunk);
    offset += chunk;
  }
}

void erwire_send_blob_chunk(const ErHash* object_id, UINT32 offset, UINT32 total_size, const UINT8* data,
                            UINT32 len, UINT8 is_last) {
  UINT8 payload[ERWIRE_MAX_PAYLOAD];
  UINT8* payload_cursor = payload;
  UINT16 flags = ERWIRE_FLAG_FIRST;

  if (object_id == 0 || len > (ERWIRE_MAX_PAYLOAD - ERWIRE_BLOB_CHUNK_HEADER_SIZE) ||
      (len > 0u && data == 0)) {
    return;
  }
  if (offset != 0u) {
    flags = 0;
  }
  if (is_last != 0u) {
    flags |= ERWIRE_FLAG_LAST;
  }

  er_mem_copy(payload_cursor, object_id->bytes, ER_HASH_LEN);
  payload_cursor += ER_HASH_LEN;
  erwire_write_u32(&payload_cursor, offset);
  erwire_write_u32(&payload_cursor, total_size);
  erwire_write_u32(&payload_cursor, len);
  er_mem_copy(&payload[ERWIRE_BLOB_CHUNK_HEADER_SIZE], data, (UINTN)len);
  erwire_send(ERWIRE_KIND_BLOB_CHUNK, flags, payload, ERWIRE_BLOB_CHUNK_HEADER_SIZE + len);
}

void erwire_send_pci_device(UINT32 bus, UINT32 dev, UINT32 func, UINT32 target_kind, UINT32 id,
                            UINT32 command_status, UINT32 class_revision, UINT32 header_cacheline,
                            const UINT32* bars) {
  UINT8 payload[ERWIRE_PCI_DEVICE_SIZE];
  UINT8* payload_cursor = payload;
  UINT32 i;

  erwire_write_u32(&payload_cursor, bus);
  erwire_write_u32(&payload_cursor, dev);
  erwire_write_u32(&payload_cursor, func);
  erwire_write_u32(&payload_cursor, target_kind);
  erwire_write_u32(&payload_cursor, id);
  erwire_write_u32(&payload_cursor, command_status);
  erwire_write_u32(&payload_cursor, class_revision);
  erwire_write_u32(&payload_cursor, header_cacheline);
  for (i = 0; i < ERWIRE_PCI_BAR_COUNT; ++i) {
    UINT32 value = 0;

    if (bars != 0) {
      value = bars[i];
    }
    erwire_write_u32(&payload_cursor, value);
  }
  erwire_send(ERWIRE_KIND_PCI_DEVICE, ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST, payload, ERWIRE_PCI_DEVICE_SIZE);
}
