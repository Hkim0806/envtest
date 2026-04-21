#!/usr/bin/env bash

set -euo pipefail

SOPS_VERSION="v3.12.2"
AGE_VERSION="v1.3.1"

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      echo "Unsupported architecture: ${arch}" >&2
      exit 1
      ;;
  esac
}

download_file() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "${url}" -o "${out}"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "${out}" "${url}"
  else
    echo "[ERROR] curl or wget is required." >&2
    exit 1
  fi
}

append_if_missing() {
  local file="$1"
  local line="$2"
  touch "${file}"
  if ! grep -Fq "${line}" "${file}"; then
    printf "\n%s\n" "${line}" >> "${file}"
  fi
}

echo "[1/6] Preparing directories..."
ARCH="$(detect_arch)"
USER_BIN="${HOME}/.local/bin"
AGE_DIR="${HOME}/.config/sops/age"
AGE_KEY_FILE="${AGE_DIR}/keys.txt"
TMP_DIR="$(mktemp -d)"
mkdir -p "${USER_BIN}" "${AGE_DIR}"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "[2/6] Installing sops..."
SOPS_URL="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${ARCH}"
download_file "${SOPS_URL}" "${USER_BIN}/sops"
chmod +x "${USER_BIN}/sops"

echo "[3/6] Installing age..."
AGE_TAR="${TMP_DIR}/age.tar.gz"
AGE_URL="https://dl.filippo.io/age/${AGE_VERSION}?for=linux/${ARCH}"
download_file "${AGE_URL}" "${AGE_TAR}"
tar -xzf "${AGE_TAR}" -C "${TMP_DIR}"
cp -f "${TMP_DIR}/age/age" "${USER_BIN}/age"
cp -f "${TMP_DIR}/age/age-keygen" "${USER_BIN}/age-keygen"
chmod +x "${USER_BIN}/age" "${USER_BIN}/age-keygen"

echo "[4/6] Updating shell profile..."
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
SOPS_KEY_LINE='export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"'
append_if_missing "${HOME}/.bashrc" "${PATH_LINE}"
append_if_missing "${HOME}/.bashrc" "${SOPS_KEY_LINE}"
append_if_missing "${HOME}/.zshrc" "${PATH_LINE}"
append_if_missing "${HOME}/.zshrc" "${SOPS_KEY_LINE}"
export PATH="${HOME}/.local/bin:${PATH}"
export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"

echo "[5/6] Generating age key (if missing)..."
if [[ ! -f "${AGE_KEY_FILE}" ]]; then
  "${USER_BIN}/age-keygen" -o "${AGE_KEY_FILE}"
  chmod 600 "${AGE_KEY_FILE}" || true
else
  echo "Existing key found: ${AGE_KEY_FILE}"
fi

echo "[6/7] Installing global helper commands (encrypt/decrypt)..."
cat > "${USER_BIN}/encrypt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
PLAIN_FILE="${1:-.env}"
ENC_FILE="${2:-.env.enc}"
sops encrypt --input-type dotenv --output-type dotenv --output "${ENC_FILE}" "${PLAIN_FILE}"
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

echo "[7/7] Verifying install..."
"${USER_BIN}/sops" --version | head -n 1
"${USER_BIN}/age" --version
"${USER_BIN}/age-keygen" --version
PUBLIC_KEY="$("${USER_BIN}/age-keygen" -y "${AGE_KEY_FILE}")"

echo
echo "Setup completed."
echo "- sops: ${USER_BIN}/sops"
echo "- age : ${USER_BIN}/age"
echo "- key : ${AGE_KEY_FILE}"
echo "- helper: ${USER_BIN}/encrypt, ${USER_BIN}/decrypt, ${USER_BIN}/encrpt"
echo "- public key: ${PUBLIC_KEY}"
echo
echo "IMPORTANT:"
echo "1) Open a new terminal or run: source ~/.bashrc"
echo "2) Share only the public key above."
echo "3) Never share AGE-SECRET-KEY."
