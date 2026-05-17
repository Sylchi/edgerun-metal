#!/usr/bin/env bash
set -euo pipefail

# Purpose: listen for EdgeRun Metal UEFI UDP log datagrams.
# Intention: provide a one-command laptop-side capture path for real hardware boots.

if command -v socat >/dev/null 2>&1; then
  exec socat -u UDP-RECVFROM:9000,reuseaddr,fork -
fi

if command -v nc >/dev/null 2>&1; then
  exec nc -ul 9000
fi

echo "edgerun-log-listen: install socat or nc" >&2
exit 1
