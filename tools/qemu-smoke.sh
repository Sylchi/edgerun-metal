#!/usr/bin/env sh
set -eu

usage() {
  printf 'usage: %s <qemu-runner> <qemu.conf> <esp-dir> <log-path> <timeout-seconds> <ready-text>\n' "$0" >&2
}

require_log_text() {
  label="$1"
  text="$2"
  log_path="$3"

  if grep -F "$text" "$log_path" >/dev/null 2>&1; then
    return 0
  fi

  printf 'qemu smoke: missing %s: %s\n' "$label" "$text" >&2
  return 1
}

log_has_boot_sentinels() {
  log_path="$1"
  ready_text="$2"

  grep -F 'BdsDxe: starting' "$log_path" >/dev/null 2>&1 &&
    grep -F 'EdgeRun Metal Core v0.2' "$log_path" >/dev/null 2>&1 &&
    grep -F 'UEFI boot OK' "$log_path" >/dev/null 2>&1 &&
    grep -F "$ready_text" "$log_path" >/dev/null 2>&1
}

stop_qemu() {
  qemu_pid="$1"

  if kill -0 "$qemu_pid" >/dev/null 2>&1; then
    kill "$qemu_pid" >/dev/null 2>&1 || true
    wait "$qemu_pid" >/dev/null 2>&1 || true
  fi
}

if [ "$#" -ne 6 ]; then
  usage
  exit 2
fi

runner="$1"
config="$2"
esp_dir="$3"
log_path="$4"
timeout_seconds="$5"
ready_text="$6"
elapsed_seconds=0
log_dir="${log_path%/*}"

case "$timeout_seconds" in
  ''|*[!0-9]*)
    printf 'qemu smoke: timeout must be decimal seconds\n' >&2
    exit 2
    ;;
esac

if [ "$timeout_seconds" -eq 0 ]; then
  printf 'qemu smoke: timeout must be positive\n' >&2
  exit 2
fi

if [ "$log_dir" != "$log_path" ]; then
  mkdir -p "$log_dir"
fi
rm -f "$log_path"

"$runner" "$config" "$esp_dir" >"$log_path" 2>&1 &
qemu_pid="$!"

while [ "$elapsed_seconds" -lt "$timeout_seconds" ]; do
  if log_has_boot_sentinels "$log_path" "$ready_text"; then
    stop_qemu "$qemu_pid"
    require_log_text 'firmware start' 'BdsDxe: starting' "$log_path"
    require_log_text 'kernel banner' 'EdgeRun Metal Core v0.2' "$log_path"
    require_log_text 'uefi boot' 'UEFI boot OK' "$log_path"
    require_log_text 'ready state' "$ready_text" "$log_path"
    if grep -F 'virtio gpu unavailable' "$log_path" >/dev/null 2>&1; then
      printf 'qemu smoke: VirtIO GPU discovery failed\n' >&2
      exit 1
    fi
    printf 'qemu smoke: boot reached ready state: %s\n' "$ready_text"
    exit 0
  fi

  if ! kill -0 "$qemu_pid" >/dev/null 2>&1; then
    wait "$qemu_pid" >/dev/null 2>&1 || true
    break
  fi

  sleep 1
  elapsed_seconds=$((elapsed_seconds + 1))
done

stop_qemu "$qemu_pid"
require_log_text 'firmware start' 'BdsDxe: starting' "$log_path" || true
require_log_text 'kernel banner' 'EdgeRun Metal Core v0.2' "$log_path" || true
require_log_text 'uefi boot' 'UEFI boot OK' "$log_path" || true
require_log_text 'ready state' "$ready_text" "$log_path" || true
printf 'qemu smoke: boot did not reach ready state within %s seconds: %s\n' "$timeout_seconds" "$ready_text" >&2
printf 'qemu smoke: log: %s\n' "$log_path" >&2
exit 1
