#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v cygpath >/dev/null 2>&1; then
  SCRIPT_DIR_WIN="$(cygpath -w "${SCRIPT_DIR}")"
else
  SCRIPT_DIR_WIN="${SCRIPT_DIR}"
fi

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR_WIN}\\setup-secrets-windows.ps1"
