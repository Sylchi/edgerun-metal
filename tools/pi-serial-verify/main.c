#define _POSIX_C_SOURCE 200809L

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../../edgerun-metal/devices/pi_zero_w_v1_1/er_pi_zero_w_v1_1_status.h"

/*
 * Purpose:
 *   Validate captured Raspberry Pi bootstrap serial bytes as erwire packets.
 * Intention:
 *   Keep physical board bring-up checks on EdgeRun byte protocol instead of
 *   ad-hoc line parsing.
 */

enum {
  ERPSV_ARGC = 3,
  ERPSV_ARG_MANIFEST = 1,
  ERPSV_ARG_SERIAL_LOG = 2,
  ERPSV_FILE_CAP = 1048576,
  ERPSV_LINE_CAP = 4096,
  ERPSV_ERWIRE_MAGIC = 0x31575245u,
  ERPSV_ERWIRE_VERSION = 1u,
  ERPSV_ERWIRE_HEADER_SIZE = 32u,
  ERPSV_ERWIRE_MAX_PAYLOAD = 1024u,
  ERPSV_ERWIRE_KIND_NODE_AVAILABLE = 37u,
  ERPSV_ERWIRE_KIND_NODE_HEARTBEAT = 38u,
  ERPSV_ERWIRE_KIND_RELAY_ASSIGNMENT = 39u,
  ERPSV_ERWIRE_KIND_BLE_ADVERTISEMENT = 42u,
  ERPSV_NODE_AVAILABLE_BYTES = 189u,
  ERPSV_NODE_AVAILABLE_LOG_HEAD_OFFSET = 157u,
  ERPSV_HEADER_MAGIC_OFFSET = 0u,
  ERPSV_HEADER_VERSION_OFFSET = 4u,
  ERPSV_HEADER_SIZE_OFFSET = 6u,
  ERPSV_HEADER_KIND_OFFSET = 16u,
  ERPSV_HEADER_PAYLOAD_LEN_OFFSET = 20u,
  ERPSV_HEADER_PAYLOAD_CRC_OFFSET = 24u,
  ERPSV_HEADER_RESERVED_OFFSET = 28u,
  ERPSV_BYTE_SHIFT_1 = 8u,
  ERPSV_BYTE_SHIFT_2 = 16u,
  ERPSV_BYTE_SHIFT_3 = 24u,
  ERPSV_U32_BYTE_3 = 3u,
  ERPSV_CRC32_INITIAL = 0xffffffffu,
  ERPSV_CRC32_POLY = 0xedb88320u,
  ERPSV_CRC32_BITS_PER_BYTE = 8u
};

static const char ERPSV_EXPECT_PREFIX[] = "erwire_expect=";
static const char ERPSV_SDIO_EXPECT_PREFIX[] = "erwire_expect_sdio_probe=";

static unsigned char g_erpsv_manifest[ERPSV_FILE_CAP];
static unsigned char g_erpsv_serial_log[ERPSV_FILE_CAP];

static int erpsv_fail(const char* message) {
  fprintf(stderr, "pi-serial-verify: %s\n", message);
  return 1;
}

static int erpsv_read_file(const char* path,
                           unsigned char* buffer,
                           size_t cap,
                           size_t* out_len) {
  FILE* file;
  size_t total = 0u;
  size_t read_len;

  if (path == NULL || buffer == NULL || out_len == NULL || cap == 0u) {
    return erpsv_fail("invalid file read");
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "pi-serial-verify: open failed for %s\n", path);
    return 1;
  }
  while ((read_len = fread(buffer + total, 1u, cap - total, file)) > 0u) {
    total += read_len;
    if (total == cap) {
      if (fgetc(file) != EOF) {
        fclose(file);
        return erpsv_fail("file too large");
      }
      break;
    }
  }
  if (ferror(file) != 0) {
    fclose(file);
    return erpsv_fail("file read failed");
  }
  if (fclose(file) != 0) {
    return erpsv_fail("file close failed");
  }
  *out_len = total;
  return 0;
}

static uint16_t erpsv_get_u16(const unsigned char* bytes) {
  return (uint16_t)((uint16_t)bytes[0] |
                    ((uint16_t)bytes[1] << ERPSV_BYTE_SHIFT_1));
}

static uint32_t erpsv_get_u32(const unsigned char* bytes) {
  return (uint32_t)bytes[0] |
         ((uint32_t)bytes[1] << ERPSV_BYTE_SHIFT_1) |
         ((uint32_t)bytes[2] << ERPSV_BYTE_SHIFT_2) |
         ((uint32_t)bytes[ERPSV_U32_BYTE_3] << ERPSV_BYTE_SHIFT_3);
}

//@optimizer-ignore-function CRC32 verifier must fold every captured erwire payload byte
static uint32_t erpsv_crc32(const unsigned char* data, uint32_t len) {
  uint32_t crc = ERPSV_CRC32_INITIAL;
  uint32_t i;

  for (i = 0u; i < len; ++i) {
    uint32_t bit;
    crc ^= (uint32_t)data[i];
    for (bit = 0u; bit < ERPSV_CRC32_BITS_PER_BYTE; ++bit) {
      uint32_t mask = 0u - (crc & 1u);
      crc = (crc >> 1) ^ (ERPSV_CRC32_POLY & mask);
    }
  }
  return ~crc;
}

static int erpsv_next_line(const unsigned char* text,
                           size_t text_len,
                           size_t* cursor,
                           const unsigned char** out_line,
                           size_t* out_line_len) {
  size_t start;
  size_t end;

  if (text == NULL || cursor == NULL || out_line == NULL ||
      out_line_len == NULL || *cursor >= text_len) {
    return 0;
  }
  start = *cursor;
  end = start;
  while (end < text_len && text[end] != (unsigned char)'\n') {
    ++end;
  }
  *cursor = end;
  if (*cursor < text_len && text[*cursor] == (unsigned char)'\n') {
    ++*cursor;
  }
  if (end > start && text[end - 1u] == (unsigned char)'\r') {
    --end;
  }
  *out_line = text + start;
  *out_line_len = end - start;
  return 1;
}

static int erpsv_line_has_prefix(const unsigned char* line,
                                 size_t line_len,
                                 const char* prefix) {
  size_t prefix_len;

  if (line == NULL || prefix == NULL) {
    return 0;
  }
  prefix_len = strlen(prefix);
  return (int)(line_len >= prefix_len &&
               memcmp(line, prefix, prefix_len) == 0);
}

static uint16_t erpsv_kind_from_name(const unsigned char* name,
                                     size_t name_len) {
  if (name_len == strlen("node_available") &&
      memcmp(name, "node_available", name_len) == 0) {
    return ERPSV_ERWIRE_KIND_NODE_AVAILABLE;
  }
  if (name_len == strlen("node_heartbeat") &&
      memcmp(name, "node_heartbeat", name_len) == 0) {
    return ERPSV_ERWIRE_KIND_NODE_HEARTBEAT;
  }
  if (name_len == strlen("relay_assignment") &&
      memcmp(name, "relay_assignment", name_len) == 0) {
    return ERPSV_ERWIRE_KIND_RELAY_ASSIGNMENT;
  }
  if (name_len == strlen("ble_advertisement") &&
      memcmp(name, "ble_advertisement", name_len) == 0) {
    return ERPSV_ERWIRE_KIND_BLE_ADVERTISEMENT;
  }
  return 0u;
}

static const char* erpsv_kind_name(uint16_t kind) {
  switch (kind) {
    case ERPSV_ERWIRE_KIND_NODE_AVAILABLE:
      return "node_available";
    case ERPSV_ERWIRE_KIND_NODE_HEARTBEAT:
      return "node_heartbeat";
    case ERPSV_ERWIRE_KIND_RELAY_ASSIGNMENT:
      return "relay_assignment";
    case ERPSV_ERWIRE_KIND_BLE_ADVERTISEMENT:
      return "ble_advertisement";
    default:
      return "unknown";
  }
}

static int erpsv_packet_at(const unsigned char* log,
                           size_t log_len,
                           size_t offset,
                           uint16_t* out_kind,
                           uint32_t* out_payload_len,
                           size_t* out_next) {
  uint32_t payload_len;

  if (log == NULL || out_kind == NULL || out_payload_len == NULL ||
      out_next == NULL ||
      offset > log_len ||
      log_len - offset < ERPSV_ERWIRE_HEADER_SIZE ||
      erpsv_get_u32(log + offset + ERPSV_HEADER_MAGIC_OFFSET) != ERPSV_ERWIRE_MAGIC ||
      erpsv_get_u16(log + offset + ERPSV_HEADER_VERSION_OFFSET) != ERPSV_ERWIRE_VERSION ||
      erpsv_get_u16(log + offset + ERPSV_HEADER_SIZE_OFFSET) != ERPSV_ERWIRE_HEADER_SIZE ||
      erpsv_get_u32(log + offset + ERPSV_HEADER_RESERVED_OFFSET) != 0u) {
    return 0;
  }
  payload_len = erpsv_get_u32(log + offset + ERPSV_HEADER_PAYLOAD_LEN_OFFSET);
  if (payload_len > ERPSV_ERWIRE_MAX_PAYLOAD ||
      log_len - offset < ERPSV_ERWIRE_HEADER_SIZE + (size_t)payload_len ||
      erpsv_crc32(log + offset + ERPSV_ERWIRE_HEADER_SIZE, payload_len) !=
          erpsv_get_u32(log + offset + ERPSV_HEADER_PAYLOAD_CRC_OFFSET)) {
    return 0;
  }
  *out_kind = erpsv_get_u16(log + offset + ERPSV_HEADER_KIND_OFFSET);
  *out_payload_len = payload_len;
  *out_next = offset + ERPSV_ERWIRE_HEADER_SIZE + (size_t)payload_len;
  return 1;
}

static int erpsv_find_kind(const unsigned char* log,
                           size_t log_len,
                           size_t* cursor,
                           uint16_t expected_kind) {
  size_t scan;

  if (log == NULL || cursor == NULL || expected_kind == 0u) {
    return 0;
  }
  scan = *cursor;
  while (scan < log_len) {
    uint16_t kind = 0u;
    uint32_t payload_len = 0u;
    size_t next = 0u;
    if (erpsv_packet_at(log, log_len, scan, &kind, &payload_len, &next) != 0) {
      if (kind == expected_kind) {
        *cursor = next;
        return 1;
      }
      scan = next;
    } else {
      ++scan;
    }
  }
  return 0;
}

static uint32_t erpsv_sdio_state_from_name(const unsigned char* name,
                                           size_t name_len) {
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD0_DONE) &&
      memcmp(name, ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD0_DONE, name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD0_DONE;
  }
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD5_DONE) &&
      memcmp(name, ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD5_DONE, name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD5_DONE;
  }
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD3_DONE) &&
      memcmp(name, ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD3_DONE, name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD3_DONE;
  }
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD7_DONE) &&
      memcmp(name, ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD7_DONE, name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD7_DONE;
  }
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD52_DONE) &&
      memcmp(name, ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD52_DONE, name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD52_DONE;
  }
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD53_DONE) &&
      memcmp(name, ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD53_DONE, name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD53_DONE;
  }
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_L2_READY) &&
      memcmp(name, ER_PI_ZERO_W_V1_1_STATUS_NAME_L2_READY, name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_L2_READY;
  }
  if (name_len == strlen(ER_PI_ZERO_W_V1_1_STATUS_NAME_L2_OVER_AIR_RX_UNSUPPORTED) &&
      memcmp(name,
             ER_PI_ZERO_W_V1_1_STATUS_NAME_L2_OVER_AIR_RX_UNSUPPORTED,
             name_len) == 0) {
    return ER_PI_ZERO_W_V1_1_L2_OVER_AIR_RX_UNSUPPORTED;
  }
  return 0u;
}

static const char* erpsv_sdio_state_name(uint32_t state) {
  switch (state) {
    case ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD0_DONE:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD0_DONE;
    case ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD5_DONE:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD5_DONE;
    case ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD3_DONE:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD3_DONE;
    case ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD7_DONE:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD7_DONE;
    case ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD52_DONE:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD52_DONE;
    case ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD53_DONE:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_CMD53_DONE;
    case ER_PI_ZERO_W_V1_1_L2_READY:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_L2_READY;
    case ER_PI_ZERO_W_V1_1_L2_OVER_AIR_RX_UNSUPPORTED:
      return ER_PI_ZERO_W_V1_1_STATUS_NAME_L2_OVER_AIR_RX_UNSUPPORTED;
    default:
      return "unknown";
  }
}

static int erpsv_find_sdio_probe_state(const unsigned char* log,
                                       size_t log_len,
                                       uint32_t expected_state) {
  size_t scan = 0u;

  if (log == NULL || expected_state == 0u) {
    return 0;
  }
  while (scan < log_len) {
    uint16_t kind = 0u;
    uint32_t payload_len = 0u;
    size_t next = 0u;
    if (erpsv_packet_at(log, log_len, scan, &kind, &payload_len, &next) != 0) {
      if (kind == ERPSV_ERWIRE_KIND_NODE_AVAILABLE &&
          payload_len == ERPSV_NODE_AVAILABLE_BYTES) {
        const unsigned char* payload = log + scan + ERPSV_ERWIRE_HEADER_SIZE;
        uint32_t actual_state =
            erpsv_get_u32(payload + ERPSV_NODE_AVAILABLE_LOG_HEAD_OFFSET);
        if (actual_state == expected_state) {
          return 1;
        }
        fprintf(stderr,
                "pi-serial-verify: sdio probe state is %s (0x%08x), expected %s\n",
                erpsv_sdio_state_name(actual_state),
                actual_state,
                erpsv_sdio_state_name(expected_state));
        return 0;
      }
      scan = next;
    } else {
      ++scan;
    }
  }
  return 0;
}

static int erpsv_verify(const unsigned char* manifest,
                        size_t manifest_len,
                        const unsigned char* log,
                        size_t log_len) {
  const unsigned char* line;
  const unsigned char* expected;
  size_t line_len;
  size_t manifest_cursor = 0u;
  size_t log_cursor = 0u;
  size_t expected_len;
  size_t prefix_len = strlen(ERPSV_EXPECT_PREFIX);
  size_t sdio_prefix_len = strlen(ERPSV_SDIO_EXPECT_PREFIX);
  size_t expectation_count = 0u;

  while (erpsv_next_line(manifest, manifest_len, &manifest_cursor, &line,
                         &line_len) != 0) {
    uint16_t expected_kind;
    if (erpsv_line_has_prefix(line, line_len, ERPSV_SDIO_EXPECT_PREFIX) != 0) {
      uint32_t expected_state;
      expected = line + sdio_prefix_len;
      expected_len = line_len - sdio_prefix_len;
      expected_state = erpsv_sdio_state_from_name(expected, expected_len);
      if (expected_state == 0u) {
        return erpsv_fail("unknown sdio probe expectation");
      }
      if (erpsv_find_sdio_probe_state(log, log_len, expected_state) == 0) {
        fprintf(stderr,
                "pi-serial-verify: missing sdio probe expectation: %s\n",
                erpsv_sdio_state_name(expected_state));
        return 1;
      }
      ++expectation_count;
      continue;
    }
    if (erpsv_line_has_prefix(line, line_len, ERPSV_EXPECT_PREFIX) == 0) {
      continue;
    }
    expected = line + prefix_len;
    expected_len = line_len - prefix_len;
    if (expected_len == 0u || expected_len > ERPSV_LINE_CAP) {
      return erpsv_fail("invalid erwire expectation");
    }
    expected_kind = erpsv_kind_from_name(expected, expected_len);
    if (expected_kind == 0u) {
      return erpsv_fail("unknown erwire expectation");
    }
    if (erpsv_find_kind(log, log_len, &log_cursor, expected_kind) == 0) {
      fprintf(stderr, "pi-serial-verify: missing erwire expectation: %s\n",
              erpsv_kind_name(expected_kind));
      return 1;
    }
    ++expectation_count;
  }
  if (expectation_count == 0u) {
    return erpsv_fail("manifest has no erwire expectations");
  }
  printf("pi-serial-verify: %zu erwire expectations matched\n",
         expectation_count);
  return 0;
}

int main(int argc, char** argv) {
  size_t manifest_len;
  size_t serial_log_len;

  if (argc != ERPSV_ARGC) {
    fprintf(stderr,
            "usage: pi-serial-verify <manifest> <serial-log>\n");
    return 2;
  }
  if (erpsv_read_file(argv[ERPSV_ARG_MANIFEST],
                      g_erpsv_manifest,
                      sizeof(g_erpsv_manifest),
                      &manifest_len) != 0 ||
      erpsv_read_file(argv[ERPSV_ARG_SERIAL_LOG],
                      g_erpsv_serial_log,
                      sizeof(g_erpsv_serial_log),
                      &serial_log_len) != 0) {
    return 1;
  }
  return erpsv_verify(g_erpsv_manifest, manifest_len, g_erpsv_serial_log,
                      serial_log_len);
}
