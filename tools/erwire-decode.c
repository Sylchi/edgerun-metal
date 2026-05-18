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
#define ERWIRE_MAX_PAYLOAD 1024u
#define ERWIRE_HASH_LEN 32u

typedef struct {
  uint32_t stream_id;
  uint32_t next_seq;
  uint8_t used;
} ErwireStreamState;

static uint8_t g_packet[ERWIRE_HEADER_SIZE + ERWIRE_MAX_PAYLOAD];
static ErwireStreamState g_streams[16];
static volatile sig_atomic_t g_stop;
static uint32_t g_packet_count;
static uint32_t g_gap_count;
static uint32_t g_bad_crc_count;
static uint32_t g_invalid_count;

static uint16_t er_get_u16(const uint8_t* bytes) {
  return (uint16_t)((uint16_t)bytes[0] | ((uint16_t)bytes[1] << 8));
}

static uint32_t er_get_u32(const uint8_t* bytes) {
  return (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8) |
         ((uint32_t)bytes[2] << 16) | ((uint32_t)bytes[3] << 24);
}

static uint64_t er_get_u64(const uint8_t* bytes) {
  return (uint64_t)er_get_u32(bytes) | ((uint64_t)er_get_u32(bytes + 4) << 32);
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
    default:
      return "unknown";
  }
}

static const char* er_bus_kind_name(uint16_t kind) {
  switch (kind) {
    case 1:
      return "pci_config";
    case 2:
      return "mmio";
    case 3:
      return "io_port";
    default:
      return "unknown";
  }
}

static const char* er_bus_status_name(uint32_t status) {
  switch (status) {
    case 0:
      return "ok";
    case 1:
      return "denied";
    case 2:
      return "invalid_address";
    case 3:
      return "invalid_operation";
    case 4:
      return "io_failed";
    default:
      return "unknown";
  }
}

static const char* er_bus_access_name(uint32_t access) {
  switch (access) {
    case 0x00000001u:
      return "read32";
    case 0x00000002u:
      return "write32";
    case 0x00000004u:
      return "read8";
    case 0x00000008u:
      return "write8";
    case 0x00000010u:
      return "read16";
    case 0x00000020u:
      return "write16";
    default:
      return "unknown";
  }
}

static ErwireStreamState* er_stream_state(uint32_t stream_id) {
  uint32_t i;

  for (i = 0; i < 16u; ++i) {
    if (g_streams[i].used != 0u && g_streams[i].stream_id == stream_id) {
      return &g_streams[i];
    }
  }
  for (i = 0; i < 16u; ++i) {
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
    } else if (c >= 0x20u && c < 0x7fu) {
      putchar((int)c);
    } else {
      printf("\\x%02x", c);
    }
  }
  printf("\"");
}

static void er_print_pci_payload(const uint8_t* payload, uint32_t len) {
  uint32_t i;

  if (len < 56u) {
    printf(" pci=truncated");
    return;
  }
  printf(" bus=%u dev=%u func=%u target=%u id=0x%08x cmd=0x%08x class=0x%08x",
         er_get_u32(payload + 0), er_get_u32(payload + 4), er_get_u32(payload + 8),
         er_get_u32(payload + 12), er_get_u32(payload + 16), er_get_u32(payload + 20),
         er_get_u32(payload + 24));
  for (i = 0; i < 6u; ++i) {
    printf(" bar%u=0x%08x", i, er_get_u32(payload + 32u + (i * 4u)));
  }
}

static void er_print_blob_payload(const uint8_t* payload, uint32_t len) {
  uint32_t i;

  if (len < ERWIRE_HASH_LEN + 12u) {
    printf(" blob=truncated");
    return;
  }
  printf(" object=");
  for (i = 0; i < ERWIRE_HASH_LEN; ++i) {
    printf("%02x", payload[i]);
  }
  printf(" offset=%u total=%u chunk=%u",
         er_get_u32(payload + ERWIRE_HASH_LEN),
         er_get_u32(payload + ERWIRE_HASH_LEN + 4u),
         er_get_u32(payload + ERWIRE_HASH_LEN + 8u));
}

static void er_print_bus_address(const uint8_t* address) {
  uint16_t bus_kind = er_get_u16(address + 2);

  printf(" bus_kind=%s(%u)", er_bus_kind_name(bus_kind), bus_kind);
  if (bus_kind == 1u) {
    printf(" bus=%u dev=%u func=%u",
           er_get_u32(address + 8), er_get_u32(address + 12), er_get_u32(address + 16));
  } else if (bus_kind == 2u) {
    printf(" bar=%u base=0x%016llx len=%llu",
           er_get_u32(address + 20),
           (unsigned long long)er_get_u64(address + 32),
           (unsigned long long)er_get_u64(address + 40));
  } else if (bus_kind == 3u) {
    printf(" port=0x%04x", er_get_u32(address + 24));
  }
}

static void er_print_bus_op32_payload(const uint8_t* payload, uint32_t len) {
  const uint8_t* op;
  uint32_t status;
  uint32_t access;

  if (len < 96u) {
    printf(" bus_op32=truncated");
    return;
  }
  status = er_get_u32(payload + 4);
  op = payload + 16;
  access = er_get_u32(op + 4);
  printf(" packet_id=%llu status=%s(%u) access=%s offset=%llu value=0x%08x result=0x%08x",
         (unsigned long long)er_get_u64(payload + 8), er_bus_status_name(status), status,
         er_bus_access_name(access), (unsigned long long)er_get_u64(op + 56),
         er_get_u32(op + 64), er_get_u32(payload + 88));
  er_print_bus_address(op + 8);
}

static void er_print_bus_io_payload(const uint8_t* payload, uint32_t len) {
  const uint8_t* op;
  uint32_t status;
  uint32_t access;

  if (len < 104u) {
    printf(" bus_io=truncated");
    return;
  }
  status = er_get_u32(payload + 4);
  op = payload + 16;
  access = er_get_u32(op + 4);
  printf(" packet_id=%llu status=%s(%u) access=%s width=%u offset=%llu value=0x%08x result=0x%08x",
         (unsigned long long)er_get_u64(payload + 8), er_bus_status_name(status), status,
         er_bus_access_name(access), er_get_u32(op + 8),
         (unsigned long long)er_get_u64(op + 64),
         er_get_u32(op + 72), er_get_u32(payload + 96));
  er_print_bus_address(op + 16);
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

  magic = er_get_u32(packet + 0);
  version = er_get_u16(packet + 4);
  header_size = er_get_u16(packet + 6);
  stream_id = er_get_u32(packet + 8);
  seq = er_get_u32(packet + 12);
  kind = er_get_u16(packet + 16);
  flags = er_get_u16(packet + 18);
  payload_len = er_get_u32(packet + 20);
  payload_crc = er_get_u32(packet + 24);

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

  value = strtoul(s, &end, 10);
  if (end == s || end == 0 || *end != '\0' || value > 65535ul) {
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

    payload_len = er_get_u32(g_packet + 20);
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
  if (argc == 1) {
    return er_decode_stdin();
  }

  if (argc == 2 && strcmp(argv[1], "--udp") == 0) {
    return er_decode_udp(9000u);
  }

  if (argc == 3 && strcmp(argv[1], "--udp") == 0) {
    uint16_t port = 0;

    if (er_parse_port(argv[2], &port) != 0) {
      er_usage(argv[0]);
      return 1;
    }
    return er_decode_udp(port);
  }

  er_usage(argv[0]);
  return 1;
}
