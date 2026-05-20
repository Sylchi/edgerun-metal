/*
 * Purpose: decode EdgeRun erwire packets captured from the boot relay stream.
 * Intention: make structured boot data readable on the desktop without changing metal runtime semantics.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
#include <unistd.h>

#include "er_driver_abi.h"

#define ERWIRE_MAGIC 0x31575245u
#define ERWIRE_VERSION 1u
#define ERWIRE_HEADER_SIZE 32u
#define ERWIRE_KIND_LOG_TEXT 1u
#define ERWIRE_KIND_BLOB_CHUNK 2u
#define ERWIRE_KIND_PCI_DEVICE 16u
#define ERWIRE_KIND_BUS_OP32_REQUEST 20u
#define ERWIRE_KIND_BUS_OP32_RESPONSE 21u
#define ERWIRE_KIND_ACPI_TABLE 22u
#define ERWIRE_KIND_BUS_IO_REQUEST 23u
#define ERWIRE_KIND_BUS_IO_RESPONSE 24u
#define ERWIRE_KIND_NODE_AVAILABLE 37u
#define ERWIRE_KIND_NODE_HEARTBEAT 38u
#define ERWIRE_KIND_RELAY_ASSIGNMENT 39u
#define ERWIRE_MAX_PAYLOAD 1024u
#define ERWIRE_HASH_LEN 32u
#define ERWIRE_STREAM_STATE_COUNT 16u
#define ERWIRE_LE_BYTE_SHIFT_1 8u
#define ERWIRE_LE_BYTE_SHIFT_2 16u
#define ERWIRE_LE_BYTE_SHIFT_3 24u
#define ERWIRE_U64_HIGH_WORD_SHIFT 32u
#define ERWIRE_BYTE_INDEX_0 0u
#define ERWIRE_BYTE_INDEX_1 1u
#define ERWIRE_BYTE_INDEX_2 2u
#define ERWIRE_BYTE_INDEX_3 3u
#define ERWIRE_U32_SIZE 4u
#define ERWIRE_ASCII_PRINTABLE_MIN 0x20u
#define ERWIRE_ASCII_PRINTABLE_MAX 0x7fu
#define ERWIRE_HEADER_MAGIC_OFFSET 0u
#define ERWIRE_HEADER_VERSION_OFFSET 4u
#define ERWIRE_HEADER_SIZE_OFFSET 6u
#define ERWIRE_HEADER_STREAM_ID_OFFSET 8u
#define ERWIRE_HEADER_SEQ_OFFSET 12u
#define ERWIRE_HEADER_KIND_OFFSET 16u
#define ERWIRE_HEADER_FLAGS_OFFSET 18u
#define ERWIRE_HEADER_PAYLOAD_LEN_OFFSET 20u
#define ERWIRE_HEADER_PAYLOAD_CRC_OFFSET 24u
#define ERWIRE_BLOB_META_SIZE 12u
#define ERWIRE_BLOB_TOTAL_OFFSET 4u
#define ERWIRE_BLOB_CHUNK_OFFSET 8u
#define ERWIRE_PORT_PARSE_BASE 10
#define ERWIRE_PORT_MAX 65535ul
#define ERWIRE_DEFAULT_UDP_PORT 9000u
#define ERWIRE_ARGC_STDIN 1
#define ERWIRE_ARGC_UDP_DEFAULT 2
#define ERWIRE_ARGC_UDP_PORT 3
#define ERWIRE_ARG_UDP 1
#define ERWIRE_ARG_PORT 2

typedef struct {
  uint32_t stream_id;
  uint32_t next_seq;
  uint8_t used;
} ErwireStreamState;

static uint8_t g_packet[ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD];
static ErwireStreamState g_streams[ERWIRE_STREAM_STATE_COUNT];
static volatile sig_atomic_t g_stop;
static uint32_t g_packet_count;
static uint32_t g_gap_count;
static uint32_t g_bad_crc_count;
static uint32_t g_invalid_count;

static uint16_t er_get_u16(const uint8_t* bytes) {
  return (uint16_t)((uint16_t)bytes[ERWIRE_BYTE_INDEX_0] |
                    ((uint16_t)bytes[ERWIRE_BYTE_INDEX_1] << ERWIRE_LE_BYTE_SHIFT_1));
}

static uint32_t er_get_u32(const uint8_t* bytes) {
  return (uint32_t)bytes[ERWIRE_BYTE_INDEX_0] |
         ((uint32_t)bytes[ERWIRE_BYTE_INDEX_1] << ERWIRE_LE_BYTE_SHIFT_1) |
         ((uint32_t)bytes[ERWIRE_BYTE_INDEX_2] << ERWIRE_LE_BYTE_SHIFT_2) |
         ((uint32_t)bytes[ERWIRE_BYTE_INDEX_3] << ERWIRE_LE_BYTE_SHIFT_3);
}

static uint64_t er_get_u64(const uint8_t* bytes) {
  return (uint64_t)er_get_u32(bytes) |
         ((uint64_t)er_get_u32(bytes + ERWIRE_U32_SIZE) << ERWIRE_U64_HIGH_WORD_SHIFT);
}

//@optimizer-ignore-function CRC32 decoder must fold every payload byte through the bit-serial polynomial
static uint32_t er_crc32(const uint8_t* data, uint32_t len) {
  uint32_t crc = 0xffffffffu;
  uint32_t i;

  for (i = 0; i < len; ++i) {
    uint32_t bit;
    crc ^= (uint32_t)data[i];
    for (bit = 0; bit < 8u; ++bit) {
      uint32_t mask = 0u - (crc & 1u);
      crc = (crc >> 1) ^ (0xedb88320u & mask);
    }
  }

  return ~crc;
}

static const char* er_kind_name(uint16_t kind) {
  switch (kind) {
    case ERWIRE_KIND_LOG_TEXT:
      return "log_text";
    case ERWIRE_KIND_BLOB_CHUNK:
      return "blob_chunk";
    case ERWIRE_KIND_PCI_DEVICE:
      return "pci_device";
    case ERWIRE_KIND_BUS_OP32_REQUEST:
      return "bus_op32_request";
    case ERWIRE_KIND_BUS_OP32_RESPONSE:
      return "bus_op32_response";
    case ERWIRE_KIND_ACPI_TABLE:
      return "acpi_table";
    case ERWIRE_KIND_BUS_IO_REQUEST:
      return "bus_io_request";
    case ERWIRE_KIND_BUS_IO_RESPONSE:
      return "bus_io_response";
    case ERWIRE_KIND_NODE_AVAILABLE:
      return "node_available";
    case ERWIRE_KIND_NODE_HEARTBEAT:
      return "node_heartbeat";
    case ERWIRE_KIND_RELAY_ASSIGNMENT:
      return "relay_assignment";
    default:
      return "unknown";
  }
}

static const char* er_bus_kind_name(uint16_t kind) {
  switch (kind) {
    case ER_DRIVER_ABI_BUS_KIND_PCI_CONFIG:
      return "pci_config";
    case ER_DRIVER_ABI_BUS_KIND_MMIO32:
      return "mmio";
    case ER_DRIVER_ABI_BUS_KIND_IO_PORT:
      return "io_port";
    default:
      return "unknown";
  }
}

static const char* er_bus_status_name(uint32_t status) {
  switch (status) {
    case ER_DRIVER_ABI_BUS_STATUS_OK:
      return "ok";
    case ER_DRIVER_ABI_BUS_STATUS_DENIED:
      return "denied";
    case ER_DRIVER_ABI_BUS_STATUS_INVALID_ADDRESS:
      return "invalid_address";
    case ER_DRIVER_ABI_BUS_STATUS_INVALID_OPERATION:
      return "invalid_operation";
    case ER_DRIVER_ABI_BUS_STATUS_IO_FAILED:
      return "io_failed";
    default:
      return "unknown";
  }
}

static const char* er_bus_access_name(uint32_t access) {
  switch (access) {
    case ER_DRIVER_ABI_BUS_ACCESS_READ32:
      return "read32";
    case ER_DRIVER_ABI_BUS_ACCESS_WRITE32:
      return "write32";
    case ER_DRIVER_ABI_BUS_ACCESS_READ8:
      return "read8";
    case ER_DRIVER_ABI_BUS_ACCESS_WRITE8:
      return "write8";
    case ER_DRIVER_ABI_BUS_ACCESS_READ16:
      return "read16";
    case ER_DRIVER_ABI_BUS_ACCESS_WRITE16:
      return "write16";
    default:
      return "unknown";
  }
}

static ErwireStreamState* er_stream_state(uint32_t stream_id) {
  uint32_t i;

  for (i = 0; i < ERWIRE_STREAM_STATE_COUNT; ++i) {
    if (g_streams[i].used != 0u && g_streams[i].stream_id == stream_id) {
      return &g_streams[i];
    }
  }
  for (i = 0; i < ERWIRE_STREAM_STATE_COUNT; ++i) {
    if (g_streams[i].used == 0u) {
      g_streams[i].used = 1u;
      g_streams[i].stream_id = stream_id;
      g_streams[i].next_seq = 0u;
      return &g_streams[i];
    }
  }
  return 0;
}

static void er_note_sequence(uint32_t stream_id, uint32_t seq) {
  ErwireStreamState* state = er_stream_state(stream_id);

  if (state == 0) {
    return;
  }
  if (seq != state->next_seq) {
    printf("gap stream=%u expected=%u got=%u\n", stream_id, state->next_seq, seq);
    ++g_gap_count;
  }
  state->next_seq = seq + 1u;
}

static void er_print_text_payload(const uint8_t* payload, uint32_t len) {
  uint32_t i;

  printf(" text=\"");
  for (i = 0; i < len; ++i) {
    uint8_t c = payload[i];
    if (c == '\r') {
      printf("\\r");
    } else if (c == '\n') {
      printf("\\n");
    } else if (c == '"' || c == '\\') {
      printf("\\%c", (char)c);
    } else if (c >= ERWIRE_ASCII_PRINTABLE_MIN && c < ERWIRE_ASCII_PRINTABLE_MAX) {
      putchar((int)c);
    } else {
      printf("\\x%02x", c);
    }
  }
  printf("\"");
}

static void er_print_pci_payload(const uint8_t* payload, uint32_t len) {
  uint32_t i;

  if (len < ER_DRIVER_ABI_PCI_DISCOVERY_BYTES) {
    printf(" pci=truncated");
    return;
  }
  printf(" bus=%u dev=%u func=%u target=%u id=0x%08x cmd=0x%08x class=0x%08x",
         er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_BUS_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_DEV_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_FUNC_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_TARGET_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_ID_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_COMMAND_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_CLASS_OFFSET));
  for (i = 0; i < ER_DRIVER_ABI_PCI_DISCOVERY_BAR_COUNT; ++i) {
    printf(" bar%u=0x%08x", i, er_get_u32(payload + ER_DRIVER_ABI_PCI_DISCOVERY_BAR_BASE_OFFSET + (i * ERWIRE_U32_SIZE)));
  }
}

static void er_print_blob_payload(const uint8_t* payload, uint32_t len) {
  uint32_t i;

  if (len < ERWIRE_HASH_LEN + ERWIRE_BLOB_META_SIZE) {
    printf(" blob=truncated");
    return;
  }
  printf(" object=");
  for (i = 0; i < ERWIRE_HASH_LEN; ++i) {
    printf("%02x", payload[i]);
  }
  printf(" offset=%u total=%u chunk=%u",
         er_get_u32(payload + ERWIRE_HASH_LEN),
         er_get_u32(payload + ERWIRE_HASH_LEN + ERWIRE_BLOB_TOTAL_OFFSET),
         er_get_u32(payload + ERWIRE_HASH_LEN + ERWIRE_BLOB_CHUNK_OFFSET));
}

static void er_print_bus_address(const uint8_t* address) {
  uint16_t bus_kind = er_get_u16(address + ER_DRIVER_ABI_BUS_ADDRESS_KIND_OFFSET);

  printf(" bus_kind=%s(%u)", er_bus_kind_name(bus_kind), bus_kind);
  if (bus_kind == ER_DRIVER_ABI_BUS_KIND_PCI_CONFIG) {
    printf(" bus=%u dev=%u func=%u",
           er_get_u32(address + ER_DRIVER_ABI_BUS_ADDRESS_PCI_BUS_OFFSET),
           er_get_u32(address + ER_DRIVER_ABI_BUS_ADDRESS_PCI_DEV_OFFSET),
           er_get_u32(address + ER_DRIVER_ABI_BUS_ADDRESS_PCI_FUNC_OFFSET));
  } else if (bus_kind == ER_DRIVER_ABI_BUS_KIND_MMIO32) {
    printf(" bar=%u base=0x%016llx len=%llu",
           er_get_u32(address + ER_DRIVER_ABI_BUS_ADDRESS_MMIO_BAR_OFFSET),
           (unsigned long long)er_get_u64(address + ER_DRIVER_ABI_BUS_ADDRESS_MMIO_BASE_OFFSET),
           (unsigned long long)er_get_u64(address + ER_DRIVER_ABI_BUS_ADDRESS_MMIO_LEN_OFFSET));
  } else if (bus_kind == ER_DRIVER_ABI_BUS_KIND_IO_PORT) {
    printf(" port=0x%04x", er_get_u32(address + ER_DRIVER_ABI_BUS_ADDRESS_IO_PORT_OFFSET));
  }
}

static void er_print_bus_op32_payload(const uint8_t* payload, uint32_t len) {
  const uint8_t* op;
  uint32_t status;
  uint32_t access;

  if (len < ER_DRIVER_ABI_BUS_PACKET_OP32_BYTES) {
    printf(" bus_op32=truncated");
    return;
  }
  status = er_get_u32(payload + ER_DRIVER_ABI_BUS_PACKET_STATUS_OFFSET);
  op = payload + ER_DRIVER_ABI_BUS_PACKET_OP_OFFSET;
  access = er_get_u32(op + ER_DRIVER_ABI_BUS_OP_ACCESS_OFFSET);
  printf(" packet_id=%llu status=%s(%u) access=%s offset=%llu value=0x%08x result=0x%08x",
         (unsigned long long)er_get_u64(payload + ER_DRIVER_ABI_BUS_PACKET_ID_OFFSET),
         er_bus_status_name(status), status,
         er_bus_access_name(access), (unsigned long long)er_get_u64(op + ER_DRIVER_ABI_BUS_OP32_OFFSET_OFFSET),
         er_get_u32(op + ER_DRIVER_ABI_BUS_OP32_VALUE_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_BUS_PACKET_OP32_RESULT_OFFSET));
  er_print_bus_address(op + ER_DRIVER_ABI_BUS_OP32_ADDRESS_OFFSET);
}

static void er_print_bus_io_payload(const uint8_t* payload, uint32_t len) {
  const uint8_t* op;
  uint32_t status;
  uint32_t access;

  if (len < ER_DRIVER_ABI_BUS_PACKET_IO_BYTES) {
    printf(" bus_io=truncated");
    return;
  }
  status = er_get_u32(payload + ER_DRIVER_ABI_BUS_PACKET_STATUS_OFFSET);
  op = payload + ER_DRIVER_ABI_BUS_PACKET_OP_OFFSET;
  access = er_get_u32(op + ER_DRIVER_ABI_BUS_OP_ACCESS_OFFSET);
  printf(" packet_id=%llu status=%s(%u) access=%s width=%u offset=%llu value=0x%08x result=0x%08x",
         (unsigned long long)er_get_u64(payload + ER_DRIVER_ABI_BUS_PACKET_ID_OFFSET),
         er_bus_status_name(status), status,
         er_bus_access_name(access), er_get_u32(op + ER_DRIVER_ABI_BUS_IO_OP_WIDTH_OFFSET),
         (unsigned long long)er_get_u64(op + ER_DRIVER_ABI_BUS_IO_OP_OFFSET_OFFSET),
         er_get_u32(op + ER_DRIVER_ABI_BUS_IO_OP_VALUE_OFFSET),
         er_get_u32(payload + ER_DRIVER_ABI_BUS_PACKET_IO_RESULT_OFFSET));
  er_print_bus_address(op + ER_DRIVER_ABI_BUS_IO_OP_ADDRESS_OFFSET);
}

static int er_decode_packet(const uint8_t* packet, uint32_t len) {
  uint32_t magic;
  uint16_t version;
  uint16_t header_size;
  uint32_t stream_id;
  uint32_t seq;
  uint16_t kind;
  uint16_t flags;
  uint32_t payload_len;
  uint32_t payload_crc;
  const uint8_t* payload;

  if (len < ERWIRE_HEADER_SIZE) {
    fprintf(stderr, "erwire-decode: short packet\n");
    ++g_invalid_count;
    return 1;
  }

  magic = er_get_u32(packet + ERWIRE_HEADER_MAGIC_OFFSET);
  version = er_get_u16(packet + ERWIRE_HEADER_VERSION_OFFSET);
  header_size = er_get_u16(packet + ERWIRE_HEADER_SIZE_OFFSET);
  stream_id = er_get_u32(packet + ERWIRE_HEADER_STREAM_ID_OFFSET);
  seq = er_get_u32(packet + ERWIRE_HEADER_SEQ_OFFSET);
  kind = er_get_u16(packet + ERWIRE_HEADER_KIND_OFFSET);
  flags = er_get_u16(packet + ERWIRE_HEADER_FLAGS_OFFSET);
  payload_len = er_get_u32(packet + ERWIRE_HEADER_PAYLOAD_LEN_OFFSET);
  payload_crc = er_get_u32(packet + ERWIRE_HEADER_PAYLOAD_CRC_OFFSET);

  if (magic != ERWIRE_MAGIC || version != ERWIRE_VERSION ||
      header_size != ERWIRE_HEADER_SIZE || payload_len > ERWIRE_MAX_PAYLOAD ||
      len != ERWIRE_HEADER_SIZE + payload_len) {
    fprintf(stderr, "erwire-decode: invalid packet header\n");
    ++g_invalid_count;
    return 1;
  }

  payload = packet + ERWIRE_HEADER_SIZE;
  er_note_sequence(stream_id, seq);
  ++g_packet_count;
  if (er_crc32(payload, payload_len) != payload_crc) {
    ++g_bad_crc_count;
  }

  printf("erwire stream=%u seq=%u kind=%s(%u) flags=0x%04x len=%u crc=%s",
         stream_id, seq, er_kind_name(kind), kind, flags, payload_len,
         er_crc32(payload, payload_len) == payload_crc ? "ok" : "bad");

  if (kind == ERWIRE_KIND_LOG_TEXT) {
    er_print_text_payload(payload, payload_len);
  } else if (kind == ERWIRE_KIND_BLOB_CHUNK) {
    er_print_blob_payload(payload, payload_len);
  } else if (kind == ERWIRE_KIND_PCI_DEVICE) {
    er_print_pci_payload(payload, payload_len);
  } else if (kind == ERWIRE_KIND_BUS_OP32_REQUEST || kind == ERWIRE_KIND_BUS_OP32_RESPONSE) {
    er_print_bus_op32_payload(payload, payload_len);
  } else if (kind == ERWIRE_KIND_BUS_IO_REQUEST || kind == ERWIRE_KIND_BUS_IO_RESPONSE) {
    er_print_bus_io_payload(payload, payload_len);
  }

  putchar('\n');
  return 0;
}

static void er_print_summary(void) {
  printf("summary packets=%u gaps=%u bad_crc=%u invalid=%u\n",
         g_packet_count, g_gap_count, g_bad_crc_count, g_invalid_count);
}

static void er_handle_signal(int sig) {
  (void)sig;
  g_stop = 1;
}

static int er_parse_port(const char* s, uint16_t* out_port) {
  char* end = 0;
  unsigned long value;

  if (s == 0 || out_port == 0 || s[0] == '\0') {
    return -1;
  }

  value = strtoul(s, &end, ERWIRE_PORT_PARSE_BASE);
  if (end == s || end == 0 || *end != '\0' || value > ERWIRE_PORT_MAX) {
    return -1;
  }

  *out_port = (uint16_t)value;
  return 0;
}

//@optimizer-ignore-function stream decoder must read and decode each framed packet from stdin
static int er_decode_stdin(void) {
  for (;;) {
    size_t got = fread(g_packet, 1u, ERWIRE_HEADER_SIZE, stdin);
    uint32_t payload_len;

    if (got == 0u) {
      er_print_summary();
      return 0;
    }
    if (got != ERWIRE_HEADER_SIZE) {
      fprintf(stderr, "erwire-decode: partial header\n");
      return 1;
    }

    payload_len = er_get_u32(g_packet + ERWIRE_HEADER_PAYLOAD_LEN_OFFSET);
    if (payload_len > ERWIRE_MAX_PAYLOAD) {
      fprintf(stderr, "erwire-decode: payload too large\n");
      return 1;
    }
    if (fread(g_packet + ERWIRE_HEADER_SIZE, 1u, payload_len, stdin) != payload_len) {
      fprintf(stderr, "erwire-decode: partial payload\n");
      return 1;
    }
    if (er_decode_packet(g_packet, ERWIRE_HEADER_SIZE + payload_len) != 0) {
      return 1;
    }
  }
}

//@optimizer-ignore-function UDP decoder must receive and decode each datagram until stopped
static int er_decode_udp(uint16_t port) {
  int fd;
  struct sockaddr_in addr;

  fd = socket(AF_INET, SOCK_DGRAM, 0);
  if (fd < 0) {
    perror("erwire-decode: socket");
    return 1;
  }

  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_ANY);
  addr.sin_port = htons(port);

  if (bind(fd, (const struct sockaddr*)&addr, (socklen_t)sizeof(addr)) != 0) {
    perror("erwire-decode: bind");
    close(fd);
    return 1;
  }

  (void)signal(SIGINT, er_handle_signal);
  (void)signal(SIGTERM, er_handle_signal);

  printf("erwire-decode: listening udp/%u\n", (unsigned)port);
  fflush(stdout);
  while (g_stop == 0) {
    ssize_t len = recv(fd, g_packet, sizeof(g_packet), 0);

    if (len < 0) {
      if (g_stop != 0) {
        break;
      }
      perror("erwire-decode: recv");
      close(fd);
      return 1;
    }
    if (len == 0) {
      continue;
    }
    (void)er_decode_packet(g_packet, (uint32_t)len);
    fflush(stdout);
  }
  er_print_summary();
  close(fd);
  return 0;
}

static void er_usage(const char* argv0) {
  fprintf(stderr, "usage: %s [--udp [port]]\n", argv0 == 0 ? "erwire-decode" : argv0);
}

int main(int argc, char** argv) {
  if (argc == ERWIRE_ARGC_STDIN) {
    return er_decode_stdin();
  }

  if (argc == ERWIRE_ARGC_UDP_DEFAULT && strcmp(argv[ERWIRE_ARG_UDP], "--udp") == 0) {
    return er_decode_udp(ERWIRE_DEFAULT_UDP_PORT);
  }

  if (argc == ERWIRE_ARGC_UDP_PORT && strcmp(argv[ERWIRE_ARG_UDP], "--udp") == 0) {
    uint16_t port = 0;

    if (er_parse_port(argv[ERWIRE_ARG_PORT], &port) != 0) {
      er_usage(argv[0]);
      return 1;
    }
    return er_decode_udp(port);
  }

  er_usage(argv[0]);
  return 1;
}
