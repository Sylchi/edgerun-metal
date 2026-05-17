#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Generate a C header embedding a WebAssembly module from WAT source.
# Intention:
#   Keep driver/app modules source-first while preserving freestanding metal builds.

if [ "$#" -ne 5 ]; then
  printf 'usage: %s <input.wat> <output.h> <guard> <array_name> <size_name>\n' "$0" >&2
  exit 1
fi

readonly INPUT_WAT="$1"
readonly OUTPUT_H="$2"
readonly GUARD="$3"
readonly ARRAY_NAME="$4"
readonly SIZE_NAME="$5"
readonly TMP_WASM="$(mktemp)"

cleanup() {
  rm -f "${TMP_WASM}"
}
trap cleanup EXIT

wat2wasm "${INPUT_WAT}" -o "${TMP_WASM}"
mkdir -p "$(dirname "${OUTPUT_H}")"

python3 - "${INPUT_WAT}" "${TMP_WASM}" "${OUTPUT_H}" "${GUARD}" "${ARRAY_NAME}" "${SIZE_NAME}" <<'PY'
import os
import sys

input_wat, input_wasm, output_h, guard, array_name, size_name = sys.argv[1:]
data = open(input_wasm, "rb").read()
source = os.path.relpath(input_wat, os.path.dirname(os.path.dirname(output_h)))

with open(output_h, "w", encoding="ascii") as out:
    out.write(f"/* Generated from {source} */\n")
    out.write(f"#ifndef {guard}\n")
    out.write(f"#define {guard}\n")
    out.write(f"static const UINT8 {array_name}[] = {{\n")
    for offset in range(0, len(data), 12):
        chunk = data[offset:offset + 12]
        values = ", ".join(f"0x{byte:02x}" for byte in chunk)
        comma = "," if offset + 12 < len(data) else ""
        out.write(f"  {values}{comma}\n")
    out.write("};\n")
    out.write(f"static const UINT32 {size_name} = {len(data)}u;\n")
    out.write("#endif\n")
PY
