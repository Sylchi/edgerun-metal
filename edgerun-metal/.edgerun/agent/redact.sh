#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:?output directory required}"

for file in "$TARGET_DIR"/*.txt "$TARGET_DIR"/*.log; do
  [ -f "$file" ] || continue
  sed -i \
    -E 's/(token|secret|password|authorization|api[_-]?key|github[_-]?token)[^[:space:]]*/\1=[REDACTED]/Ig' \
    "$file"
sed -i \
    -E 's/[A-Za-z0-9.\/+_=-]{40,}/[REDACTED_TOKEN]/g' \
    "$file"
  sed -i \
    -E 's/[A-Za-z0-9.\/+_=-]{30,}(=)?[[:space:]]*$/[REDACTED_SECRET]/g' \
    "$file"
done

for file in "$TARGET_DIR"/*.txt "$TARGET_DIR"/*.log; do
  [ -f "$file" ] || continue
  sed -i \
    -e '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/c\-----BEGIN PRIVATE KEY----- [REDACTED] -----END PRIVATE KEY-----' \
    "$file"
done
