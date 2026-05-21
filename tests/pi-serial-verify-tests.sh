#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate manifest-driven Raspberry Pi erwire serial capture checking.
# Intention:
#   Keep physical board bring-up criteria on EdgeRun byte packets, not text lines.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/pi-serial-verify-tests"
TOOL_BIN="${BUILD_DIR}/pi-serial-verify"
GEN_BIN="${BUILD_DIR}/pi-erwire-fixture"
GEN_SRC="${BUILD_DIR}/pi-erwire-fixture.c"
MANIFEST="${BUILD_DIR}/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"
SERIAL_LOG="${BUILD_DIR}/serial-erwire.bin"
BAD_LOG="${BUILD_DIR}/serial-erwire-bad.bin"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

"${CC:-${ROOT_DIR}/toolchain/bin/clang}" -std=c11 -Wall -Wextra -Werror -O2 -o "$TOOL_BIN" \
  "${ROOT_DIR}/tools/pi-serial-verify/main.c"

if "$TOOL_BIN" >/tmp/pi-serial-verify-usage.out \
  2>/tmp/pi-serial-verify-usage.err; then
  printf 'pi-serial-verify accepted missing arguments\n' >&2
  exit 1
fi

if ! grep -q "usage: pi-serial-verify <manifest> <serial-log>" \
  /tmp/pi-serial-verify-usage.err; then
  printf 'pi-serial-verify usage text is not explicit\n' >&2
  exit 1
fi

cat >"$GEN_SRC" <<'EOF_C'
#include <stdint.h>
#include <stdio.h>

#include "er_pi_zero_w_v1_1_status.h"

enum {
  ERWIRE_MAGIC = 0x31575245u,
  ERWIRE_VERSION = 1u,
  ERWIRE_HEADER_SIZE = 32u,
  ERWIRE_FLAG_FIRST = 0x0001u,
  ERWIRE_FLAG_LAST = 0x0002u,
  ERWIRE_KIND_NODE_AVAILABLE = 37u,
  ERWIRE_KIND_NODE_HEARTBEAT = 38u,
  ERWIRE_KIND_BLE_ADVERTISEMENT = 42u,
  NODE_AVAILABLE_BYTES = 189u,
  NODE_AVAILABLE_LOG_HEAD_OFFSET = 157u,
  ERWIRE_CRC32_INITIAL = 0xffffffffu,
  ERWIRE_CRC32_POLY = 0xedb88320u,
  ERWIRE_CRC32_BITS_PER_BYTE = 8u
};

static uint32_t crc32(const uint8_t* bytes, uint32_t len) {
  uint32_t crc = ERWIRE_CRC32_INITIAL;
  uint32_t i;

  for (i = 0u; i < len; ++i) {
    uint32_t bit;
    crc ^= (uint32_t)bytes[i];
    for (bit = 0u; bit < ERWIRE_CRC32_BITS_PER_BYTE; ++bit) {
      uint32_t mask = 0u - (crc & 1u);
      crc = (crc >> 1) ^ (ERWIRE_CRC32_POLY & mask);
    }
  }
  return ~crc;
}

static void put_u16(uint8_t** cursor, uint16_t value) {
  (*cursor)[0] = (uint8_t)(value & 0xffu);
  (*cursor)[1] = (uint8_t)((value >> 8u) & 0xffu);
  *cursor += 2u;
}

static void put_u32(uint8_t** cursor, uint32_t value) {
  (*cursor)[0] = (uint8_t)(value & 0xffu);
  (*cursor)[1] = (uint8_t)((value >> 8u) & 0xffu);
  (*cursor)[2] = (uint8_t)((value >> 16u) & 0xffu);
  (*cursor)[3] = (uint8_t)((value >> 24u) & 0xffu);
  *cursor += 4u;
}

static void put_u32_at(uint8_t* bytes, uint32_t offset, uint32_t value) {
  bytes[offset] = (uint8_t)(value & 0xffu);
  bytes[offset + 1u] = (uint8_t)((value >> 8u) & 0xffu);
  bytes[offset + 2u] = (uint8_t)((value >> 16u) & 0xffu);
  bytes[offset + 3u] = (uint8_t)((value >> 24u) & 0xffu);
}

static int packet(uint16_t kind, uint32_t seq, uint8_t payload_byte) {
  uint8_t header[ERWIRE_HEADER_SIZE];
  uint8_t payload[NODE_AVAILABLE_BYTES];
  uint8_t* cursor = header;
  uint32_t payload_len = 4u;
  uint32_t i;

  for (i = 0u; i < NODE_AVAILABLE_BYTES; ++i) {
    payload[i] = 0u;
  }
  payload[0] = payload_byte;
  payload[1] = 2u;
  payload[2] = 3u;
  payload[3] = 4u;
  if (kind == ERWIRE_KIND_NODE_AVAILABLE) {
    payload_len = NODE_AVAILABLE_BYTES;
    put_u32_at(payload,
               NODE_AVAILABLE_LOG_HEAD_OFFSET,
               ER_PI_ZERO_W_V1_1_L2_RAW_RX_UNSUPPORTED);
  }

  put_u32(&cursor, ERWIRE_MAGIC);
  put_u16(&cursor, ERWIRE_VERSION);
  put_u16(&cursor, ERWIRE_HEADER_SIZE);
  put_u32(&cursor, 42u);
  put_u32(&cursor, seq);
  put_u16(&cursor, kind);
  put_u16(&cursor, ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST);
  put_u32(&cursor, payload_len);
  put_u32(&cursor, crc32(payload, payload_len));
  put_u32(&cursor, 0u);
  return fwrite(header, 1u, sizeof(header), stdout) == sizeof(header) &&
         fwrite(payload, 1u, payload_len, stdout) == payload_len ? 0 : 1;
}

int main(int argc, char** argv) {
  if (argc == 2 && argv[1][0] == 'b') {
    return packet(ERWIRE_KIND_NODE_HEARTBEAT, 0u, 9u);
  }
  if (packet(ERWIRE_KIND_NODE_AVAILABLE, 0u, 1u) != 0) {
    return 1;
  }
  if (packet(ERWIRE_KIND_BLE_ADVERTISEMENT, 1u, 7u) != 0) {
    return 1;
  }
  return packet(ERWIRE_KIND_NODE_HEARTBEAT, 1u, 5u);
}
EOF_C

"${CC:-${ROOT_DIR}/toolchain/bin/clang}" -std=c11 -Wall -Wextra -Werror -O2 \
  -I"${ROOT_DIR}/edgerun-metal/devices/pi_zero_w_v1_1" \
  -o "$GEN_BIN" "$GEN_SRC"

cat >"$MANIFEST" <<'EOF_MANIFEST'
board=pi-zero-w-v1_1
serial_protocol=erwire
erwire_expect=node_available
erwire_expect=ble_advertisement
erwire_expect_sdio_probe=l2_raw_rx_unsupported
erwire_expect=node_heartbeat
EOF_MANIFEST

"$GEN_BIN" >"$SERIAL_LOG"
"$TOOL_BIN" "$MANIFEST" "$SERIAL_LOG" >/tmp/pi-serial-verify-ok.out

if ! grep -q "pi-serial-verify: 4 erwire expectations matched" \
  /tmp/pi-serial-verify-ok.out; then
  printf 'pi-serial-verify did not report matched erwire expectations\n' >&2
  exit 1
fi

"$GEN_BIN" bad >"$BAD_LOG"
if "$TOOL_BIN" "$MANIFEST" "$BAD_LOG" >/tmp/pi-serial-verify-bad.out \
  2>/tmp/pi-serial-verify-bad.err; then
  printf 'pi-serial-verify accepted missing node_available packet\n' >&2
  exit 1
fi

if ! grep -q "missing erwire expectation: node_available" \
  /tmp/pi-serial-verify-bad.err; then
  printf 'pi-serial-verify did not name missing erwire expectation\n' >&2
  exit 1
fi

printf 'pi serial verify tests passed\n'
