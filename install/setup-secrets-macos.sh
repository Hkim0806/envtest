#!/usr/bin/env bash

set -euo pipefail

echo "[1/5] Checking Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "[ERROR] Homebrew is not installed."
  echo "Install Homebrew first: https://brew.sh"
  exit 1
fi

echo "[2/5] Installing sops + age..."
if ! command -v sops >/dev/null 2>&1; then
  brew install sops
fi
if ! command -v age >/dev/null 2>&1; then
  brew install age
fi

echo "[3/5] Preparing key directory..."
AGE_DIR="${HOME}/.config/sops/age"
AGE_KEY_FILE="${AGE_DIR}/keys.txt"
mkdir -p "${AGE_DIR}"

echo "[4/5] Generating age key (if missing)..."
if [[ ! -f "${AGE_KEY_FILE}" ]]; then
  age-keygen -o "${AGE_KEY_FILE}"
  chmod 600 "${AGE_KEY_FILE}" || true
else
  echo "Existing key found: ${AGE_KEY_FILE}"
fi

echo "[5/5] Exporting SOPS_AGE_KEY_FILE..."
CURRENT_SHELL="$(basename "${SHELL:-zsh}")"
PROFILE_FILE="${HOME}/.zshrc"
if [[ "${CURRENT_SHELL}" == "bash" ]]; then
  PROFILE_FILE="${HOME}/.bashrc"
fi
EXPORT_LINE="export SOPS_AGE_KEY_FILE=\"${AGE_KEY_FILE}\""
touch "${PROFILE_FILE}"
if ! grep -Fq "${EXPORT_LINE}" "${PROFILE_FILE}"; then
  printf "\n%s\n" "${EXPORT_LINE}" >> "${PROFILE_FILE}"
fi
export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"

PUBLIC_KEY="$(age-keygen -y "${AGE_KEY_FILE}")"
echo
echo "Setup completed."
echo "- sops: $(command -v sops)"
echo "- age : $(command -v age)"
echo "- key : ${AGE_KEY_FILE}"
echo "- public key: ${PUBLIC_KEY}"
echo
echo "IMPORTANT:"
echo "1) Share only the public key above."
echo "2) Never share AGE-SECRET-KEY."
echo "3) Open a new terminal, or run: source ${PROFILE_FILE}"

