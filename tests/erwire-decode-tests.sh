#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Validate the host-side erwire decoder used for firmware capture.
# Intention:
#   Keep packet format, CRC, PCI payload decoding, and sequence-gap reporting tested.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly DECODER="${ROOT_DIR}/.build/erwire-decode"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

make_packet_file() {
  local output="$1"
  local kind="$2"
  local seq="$3"
  local payload_expr="$4"

  python3 - "$output" "$kind" "$seq" "$payload_expr" <<'PY'
import binascii
import struct
import sys

output = sys.argv[1]
kind = int(sys.argv[2], 0)
seq = int(sys.argv[3], 0)
payload = eval(sys.argv[4], {"__builtins__": {}}, {})
packet = struct.pack(
    "<IHHIIHHIII",
    0x31575245,
    1,
    32,
    1,
    seq,
    kind,
    3,
    len(payload),
    binascii.crc32(payload) & 0xffffffff,
    0,
) + payload
with open(output, "wb") as f:
    f.write(packet)
PY
}

require_contains() {
  local file="$1"
  local pattern="$2"

  if ! grep -Fq "$pattern" "$file"; then
    printf 'missing expected output: %s\n' "$pattern" >&2
    printf 'actual output:\n' >&2
    cat "$file" >&2
    exit 1
  fi
}

make_packet_file "${TMP_DIR}/log.bin" 1 0 "b'ok'"
"${DECODER}" < "${TMP_DIR}/log.bin" > "${TMP_DIR}/log.out"
require_contains "${TMP_DIR}/log.out" 'kind=log_text(1)'
require_contains "${TMP_DIR}/log.out" 'crc=ok'
require_contains "${TMP_DIR}/log.out" 'text="ok"'
require_contains "${TMP_DIR}/log.out" 'summary packets=1 gaps=0 bad_crc=0 invalid=0'

make_packet_file "${TMP_DIR}/seq0.bin" 1 0 "b'a'"
make_packet_file "${TMP_DIR}/seq2.bin" 1 2 "b'b'"
cat "${TMP_DIR}/seq0.bin" "${TMP_DIR}/seq2.bin" | "${DECODER}" > "${TMP_DIR}/gap.out"
require_contains "${TMP_DIR}/gap.out" 'gap stream=1 expected=1 got=2'
require_contains "${TMP_DIR}/gap.out" 'summary packets=2 gaps=1 bad_crc=0 invalid=0'

python3 - "${TMP_DIR}/bad-crc.bin" <<'PY'
import struct
import sys

payload = b'bad'
packet = struct.pack(
    "<IHHIIHHIII",
    0x31575245,
    1,
    32,
    1,
    0,
    1,
    3,
    len(payload),
    0,
    0,
) + payload
with open(sys.argv[1], "wb") as f:
    f.write(packet)
PY
"${DECODER}" < "${TMP_DIR}/bad-crc.bin" > "${TMP_DIR}/bad-crc.out"
require_contains "${TMP_DIR}/bad-crc.out" 'crc=bad'
require_contains "${TMP_DIR}/bad-crc.out" 'summary packets=1 gaps=0 bad_crc=1 invalid=0'

python3 - "${TMP_DIR}/pci.bin" <<'PY'
import binascii
import struct
import sys

payload = struct.pack(
    "<IIIIIIIIIIIIII",
    2,
    3,
    4,
    5,
    0x12348086,
    0x00000007,
    0x02000001,
    0,
    0xfebc0000,
    0,
    0,
    0,
    0,
    0,
)
packet = struct.pack(
    "<IHHIIHHIII",
    0x31575245,
    1,
    32,
    1,
    0,
    16,
    3,
    len(payload),
    binascii.crc32(payload) & 0xffffffff,
    0,
) + payload
with open(sys.argv[1], "wb") as f:
    f.write(packet)
PY
"${DECODER}" < "${TMP_DIR}/pci.bin" > "${TMP_DIR}/pci.out"
require_contains "${TMP_DIR}/pci.out" 'kind=pci_device(16)'
require_contains "${TMP_DIR}/pci.out" 'bus=2 dev=3 func=4'
require_contains "${TMP_DIR}/pci.out" 'id=0x12348086'
require_contains "${TMP_DIR}/pci.out" 'bar0=0xfebc0000'

make_packet_file "${TMP_DIR}/blob.bin" 2 0 "b'\x07\x00\x00\x00\x04\x00\x00\x00\x0a\x00\x00\x00\x03\x00\x00\x00abc'"
"${DECODER}" < "${TMP_DIR}/blob.bin" > "${TMP_DIR}/blob.out"
require_contains "${TMP_DIR}/blob.out" 'kind=blob_chunk(2)'
require_contains "${TMP_DIR}/blob.out" 'object=7 offset=4 total=10 chunk=3'

python3 - "${TMP_DIR}/bus-io.bin" <<'PY'
import binascii
import struct
import sys

address = struct.pack(
    "<HHIIIIII4xQQ",
    1,          # abi_version
    2,          # bus_kind MMIO
    0x00000004, # read8
    0,
    0,
    0,
    1,
    0,
    0xfed40000,
    4096,
)
op = struct.pack("<HHII4x", 1, 2, 0x00000004, 1) + address + struct.pack("<QI4x", 8, 0)
payload = struct.pack("<HHIQ", 1, 4, 0, 42) + op + struct.pack("<I4x", 0x5a)
packet = struct.pack(
    "<IHHIIHHIII",
    0x31575245,
    1,
    32,
    1,
    0,
    24,
    3,
    len(payload),
    binascii.crc32(payload) & 0xffffffff,
    0,
) + payload
with open(sys.argv[1], "wb") as f:
    f.write(packet)
PY
"${DECODER}" < "${TMP_DIR}/bus-io.bin" > "${TMP_DIR}/bus-io.out"
require_contains "${TMP_DIR}/bus-io.out" 'kind=bus_io_response(24)'
require_contains "${TMP_DIR}/bus-io.out" 'packet_id=42 status=ok(0) access=read8 width=1'
require_contains "${TMP_DIR}/bus-io.out" 'offset=8 value=0x00000000 result=0x0000005a'
require_contains "${TMP_DIR}/bus-io.out" 'bus_kind=mmio(2) bar=1 base=0x00000000fed40000 len=4096'

printf 'erwire-decode tests passed\n'
