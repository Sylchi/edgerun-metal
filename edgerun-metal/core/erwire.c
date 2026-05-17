#include "erwire.h"
#include "er_hw_relay.h"
#include "er_mem.h"

/*
 * Purpose: serialize small binary records into UDP-sized EdgeRun wire packets.
 * Intention: keep the firmware side allocation-free and endian-explicit.
 */

#define ERWIRE_PACKET_MAX (ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD)
#define ERWIRE_BLOB_CHUNK_HEADER_SIZE 16u
#define ERWIRE_PCI_DEVICE_SIZE 56u

static UINT32 g_stream_id = 1u;
static UINT32 g_seq;
static UINT8 g_packet[ERWIRE_PACKET_MAX];

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

static void erwire_put_u16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)(value & 0xffu);
  dst[1] = (UINT8)((value >> 8) & 0xffu);
}

static void erwire_put_u32(UINT8* dst, UINT32 value) {
  dst[0] = (UINT8)(value & 0xffu);
  dst[1] = (UINT8)((value >> 8) & 0xffu);
  dst[2] = (UINT8)((value >> 16) & 0xffu);
  dst[3] = (UINT8)((value >> 24) & 0xffu);
}

static UINT32 erwire_crc32(const UINT8* data, UINT32 len) {
  UINT32 crc = 0xffffffffu;
  UINT32 i;

  if (data == 0) {
    return 0u;
  }
  for (i = 0; i < len; ++i) {
    UINT32 bit;
    crc ^= (UINT32)data[i];
    for (bit = 0; bit < 8u; ++bit) {
      UINT32 mask = 0u - (crc & 1u);
      crc = (crc >> 1) ^ (0xedb88320u & mask);
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

void erwire_send(UINT16 kind, UINT16 flags, const UINT8* payload, UINT32 payload_len) {
  UINT32 send_len;
  ErRelayForwardIntent intent;

  if (payload_len > ERWIRE_MAX_PAYLOAD || (payload_len > 0u && payload == 0)) {
    return;
  }

  erwire_put_u32(&g_packet[0], ERWIRE_MAGIC);
  erwire_put_u16(&g_packet[4], ERWIRE_VERSION);
  erwire_put_u16(&g_packet[6], ERWIRE_HEADER_SIZE);
  erwire_put_u32(&g_packet[8], g_stream_id);
  erwire_put_u32(&g_packet[12], g_seq);
  erwire_put_u16(&g_packet[16], kind);
  erwire_put_u16(&g_packet[18], flags);
  erwire_put_u32(&g_packet[20], payload_len);
  erwire_put_u32(&g_packet[24], erwire_crc32(payload, payload_len));
  erwire_put_u32(&g_packet[28], 0u);

  if (payload_len > 0u) {
    er_mem_copy(&g_packet[ERWIRE_HEADER_SIZE], payload, (UINTN)payload_len);
  }
  send_len = ERWIRE_HEADER_SIZE + payload_len;
  er_mem_zero((UINT8*)&intent, (UINTN)sizeof(intent));
  intent.abi_version = ER_WORK_ABI_VERSION;
  erwire_prepare_memory_endpoint(&intent.from);
  if (er_hw_relay_default_firmware_udp_endpoint(&intent.to) != 0u) {
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

void erwire_send_blob_chunk(UINT32 object_id, UINT32 offset, UINT32 total_size, const UINT8* data, UINT32 len, UINT8 is_last) {
  UINT8 payload[ERWIRE_MAX_PAYLOAD];
  UINT16 flags = ERWIRE_FLAG_FIRST;

  if (len > (ERWIRE_MAX_PAYLOAD - ERWIRE_BLOB_CHUNK_HEADER_SIZE) || (len > 0u && data == 0)) {
    return;
  }
  if (offset != 0u) {
    flags = 0;
  }
  if (is_last != 0u) {
    flags |= ERWIRE_FLAG_LAST;
  }

  erwire_put_u32(&payload[0], object_id);
  erwire_put_u32(&payload[4], offset);
  erwire_put_u32(&payload[8], total_size);
  erwire_put_u32(&payload[12], len);
  er_mem_copy(&payload[ERWIRE_BLOB_CHUNK_HEADER_SIZE], data, (UINTN)len);
  erwire_send(ERWIRE_KIND_BLOB_CHUNK, flags, payload, ERWIRE_BLOB_CHUNK_HEADER_SIZE + len);
}

void erwire_send_pci_device(UINT32 bus, UINT32 dev, UINT32 func, UINT32 target_kind, UINT32 id,
                            UINT32 command_status, UINT32 class_revision, UINT32 header_cacheline,
                            const UINT32* bars) {
  UINT8 payload[ERWIRE_PCI_DEVICE_SIZE];
  UINT32 i;

  erwire_put_u32(&payload[0], bus);
  erwire_put_u32(&payload[4], dev);
  erwire_put_u32(&payload[8], func);
  erwire_put_u32(&payload[12], target_kind);
  erwire_put_u32(&payload[16], id);
  erwire_put_u32(&payload[20], command_status);
  erwire_put_u32(&payload[24], class_revision);
  erwire_put_u32(&payload[28], header_cacheline);
  for (i = 0; i < 6u; ++i) {
    UINT32 value = 0;

    if (bars != 0) {
      value = bars[i];
    }
    erwire_put_u32(&payload[32u + (i * 4u)], value);
  }
  erwire_send(ERWIRE_KIND_PCI_DEVICE, ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST, payload, ERWIRE_PCI_DEVICE_SIZE);
}
