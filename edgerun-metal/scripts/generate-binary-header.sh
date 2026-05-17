#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 <input> <output> <guard> <array-name> <size-name>" >&2
  exit 2
fi

input="$1"
output="$2"
guard="$3"
array_name="$4"
size_name="$5"

tmp="${output}.tmp"
mkdir -p "$(dirname "$output")"

{
  printf '#ifndef %s\n' "$guard"
  printf '#define %s\n\n' "$guard"
  printf '#include "er_types.h"\n\n'
  printf 'static const UINT8 %s[] = {\n' "$array_name"
  od -An -v -tx1 "$input" | awk '
    {
      printf "  "
      for (i = 1; i <= NF; ++i) {
        printf "0x%s,", $i
        if (i < NF) printf " "
      }
      printf "\n"
    }
  '
  printf '};\n\n'
  printf '#define %s ((UINTN)sizeof(%s))\n\n' "$size_name" "$array_name"
  printf '#endif\n'
} > "$tmp"

mv "$tmp" "$output"
