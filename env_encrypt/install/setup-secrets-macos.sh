#!/usr/bin/env bash

set -euo pipefail

echo "[1/6] Checking Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "[ERROR] Homebrew is not installed."
  echo "Install Homebrew first: https://brew.sh"
  exit 1
fi

echo "[2/6] Installing sops + age..."
if ! command -v sops >/dev/null 2>&1; then
  brew install sops
fi
if ! command -v age >/dev/null 2>&1; then
  brew install age
fi

echo "[3/6] Preparing directories..."
USER_BIN="${HOME}/.local/bin"
AGE_DIR="${HOME}/.config/sops/age"
AGE_KEY_FILE="${AGE_DIR}/keys.txt"
mkdir -p "${AGE_DIR}" "${USER_BIN}"

echo "[4/6] Generating age key (if missing)..."
if [[ ! -f "${AGE_KEY_FILE}" ]]; then
  age-keygen -o "${AGE_KEY_FILE}"
  chmod 600 "${AGE_KEY_FILE}" || true
else
  echo "Existing key found: ${AGE_KEY_FILE}"
fi

echo "[5/6] Exporting PATH and SOPS_AGE_KEY_FILE..."
CURRENT_SHELL="$(basename "${SHELL:-zsh}")"
PROFILE_FILE="${HOME}/.zshrc"
ALT_PROFILE_FILE=""
if [[ "${CURRENT_SHELL}" == "bash" ]]; then
  PROFILE_FILE="${HOME}/.bash_profile"
  ALT_PROFILE_FILE="${HOME}/.bashrc"
fi
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
EXPORT_LINE="export SOPS_AGE_KEY_FILE=\"${AGE_KEY_FILE}\""
touch "${PROFILE_FILE}"
if ! grep -Fq "${PATH_LINE}" "${PROFILE_FILE}"; then
  printf "\n%s\n" "${PATH_LINE}" >> "${PROFILE_FILE}"
fi
if ! grep -Fq "${EXPORT_LINE}" "${PROFILE_FILE}"; then
  printf "\n%s\n" "${EXPORT_LINE}" >> "${PROFILE_FILE}"
fi
if [[ -n "${ALT_PROFILE_FILE}" ]]; then
  touch "${ALT_PROFILE_FILE}"
  if ! grep -Fq "${PATH_LINE}" "${ALT_PROFILE_FILE}"; then
    printf "\n%s\n" "${PATH_LINE}" >> "${ALT_PROFILE_FILE}"
  fi
  if ! grep -Fq "${EXPORT_LINE}" "${ALT_PROFILE_FILE}"; then
    printf "\n%s\n" "${EXPORT_LINE}" >> "${ALT_PROFILE_FILE}"
  fi
fi
export PATH="${HOME}/.local/bin:${PATH}"
export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"

echo "[6/6] Installing global helper commands (encrypt/decrypt)..."
cat > "${USER_BIN}/encrypt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
PLAIN_FILE="${1:-.env}"
ENC_FILE="${2:-.env.enc}"
CONFIG_FILE="${PWD}/env_encrypt/.sops.yaml"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  CONFIG_FILE="${PWD}/.sops.yaml"
fi
sops --config "${CONFIG_FILE}" --filename-override .env encrypt --input-type dotenv --output-type dotenv --output "${ENC_FILE}" "${PLAIN_FILE}"
EOF

cat > "${USER_BIN}/decrypt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
ENC_FILE="${1:-.env.enc}"
OUT_FILE="${2:-.env}"
sops decrypt --filename-override .env "${ENC_FILE}" > "${OUT_FILE}"
EOF

cat > "${USER_BIN}/encrpt" <<'EOF'
#!/usr/bin/env bash
exec encrypt "$@"
EOF

chmod +x "${USER_BIN}/encrypt" "${USER_BIN}/decrypt" "${USER_BIN}/encrpt"

PUBLIC_KEY="$(age-keygen -y "${AGE_KEY_FILE}")"
echo
echo "Setup completed."
echo "- sops: $(command -v sops)"
echo "- age : $(command -v age)"
echo "- key : ${AGE_KEY_FILE}"
echo "- helper: ${USER_BIN}/encrypt, ${USER_BIN}/decrypt, ${USER_BIN}/encrpt"
echo "- public key: ${PUBLIC_KEY}"
echo
echo "IMPORTANT:"
echo "1) Share only the public key above."
echo "2) Never share AGE-SECRET-KEY."
echo "3) Open a new terminal, or run: source ${PROFILE_FILE}"
