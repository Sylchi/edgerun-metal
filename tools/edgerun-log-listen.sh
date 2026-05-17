#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Provide a repository-wide entrypoint for EdgeRun Metal UDP boot logs.
# Intention:
#   Keep the listener available from root tooling while sharing the metal implementation.

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

exec "${ROOT_DIR}/edgerun-metal/tools/edgerun-log-listen.sh"
