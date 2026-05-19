#!/usr/bin/env sh
set -eu

usage() {
  printf 'usage: %s <qemu-smoke> <qemu-runner> <qemu.conf> <esp-dir> <work-dir> <timeout-seconds>\n' "$0" >&2
}

require_log_text() {
  label="$1"
  text="$2"
  log_path="$3"

  if grep -F "$text" "$log_path" >/dev/null 2>&1; then
    return 0
  fi

  printf 'qemu swtpm persistence: missing %s: %s\n' "$label" "$text" >&2
  printf 'qemu swtpm persistence: log: %s\n' "$log_path" >&2
  return 1
}

if [ "$#" -ne 6 ]; then
  usage
  exit 2
fi

smoke="$1"
runner="$2"
config="$3"
esp_dir="$4"
work_dir="$5"
timeout_seconds="$6"
first_log="$work_dir/first.log"
second_log="$work_dir/second.log"

rm -rf "$work_dir"
mkdir -p "$work_dir/swtpm-state"

"$smoke" "$runner" "$config" "$esp_dir" "$first_log" "$timeout_seconds" 'boot admission var: default written'
"$smoke" "$runner" "$config" "$esp_dir" "$second_log" "$timeout_seconds" 'boot admission var: found'

require_log_text 'first boot TPM discovery' 'TPM: CRB present' "$first_log"
require_log_text 'first boot missing admission variable' 'boot admission var: missing' "$first_log"
require_log_text 'first boot admission write' 'boot admission var: default written' "$first_log"
require_log_text 'second boot TPM discovery' 'TPM: CRB present' "$second_log"
require_log_text 'second boot persisted admission variable' 'boot admission var: found' "$second_log"
require_log_text 'second boot stored local admission' 'boot admission: stored local channel=native-eth' "$second_log"

printf 'qemu swtpm persistence: EFI admission variable persisted across reboot\n'
