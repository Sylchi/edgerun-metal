#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:?output directory required}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

mkdir -p "${OUTPUT_DIR}"

{
  date -Is
} >"${OUTPUT_DIR}/timestamp.txt"

{
  echo "hostname: $(hostname)"
  echo "rev-parse: $(git -c safe.directory='*' -C "${REPO_DIR}" rev-parse HEAD)"
  echo
  echo "git status --short"
  git -c safe.directory='*' -C "${REPO_DIR}" status --short
} >"${OUTPUT_DIR}/git-status.txt"

{
  make -C "${REPO_DIR}" print-path
} >"${OUTPUT_DIR}/build.txt"

{
  systemctl status edgerun-netboot --no-pager || true
} >"${OUTPUT_DIR}/netboot-status.txt"

{
  echo
  journalctl -u edgerun-netboot -n 250 --no-pager || true
} >"${OUTPUT_DIR}/netboot-journal.txt"

{
  ip -br link
  ip -br addr
} >"${OUTPUT_DIR}/network.txt"

{
  ss -lntup || true
} >"${OUTPUT_DIR}/sockets.txt"

{
  ls -l "${REPO_DIR}/build/esp/EFI/BOOT/BOOTX64.EFI" "${REPO_DIR}/build/edgerun-netboot" || true
  ps aux | grep edgerun || true
  sha256sum "${REPO_DIR}/build/esp/EFI/BOOT/BOOTX64.EFI" "${REPO_DIR}/build/edgerun-netboot" || true
} >"${OUTPUT_DIR}/boot-artifacts.txt"
