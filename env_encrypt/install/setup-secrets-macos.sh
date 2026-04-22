#!/usr/bin/env bash

set -euo pipefail

SOPS_VERSION="v3.12.2"
AGE_VERSION="v1.3.1"
SOPS_SHA256_DARWIN="d3e81973ea6372e22ffe4f3f8690be362559af5c0ae855430c61ebffaaef6ace"
AGE_SHA256_DARWIN_AMD64="2b233301ad21ab7b1eabd9ae1198a164005fa4928fcdd745d47c39f8593209d7"
AGE_SHA256_DARWIN_ARM64="01120ea2cbf0463d4c6bd767f99f3271bbed1cdc8a9aa718a76ba1fe4f01998b"

detect_arch() {
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
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

sha256_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  else
    echo "[ERROR] shasum or sha256sum is required." >&2
    exit 1
  fi
}

verify_sha256() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(sha256_file "${file}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "[ERROR] SHA256 mismatch for ${file}" >&2
    echo "        expected: ${expected}" >&2
    echo "        actual  : ${actual}" >&2
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

echo "[1/7] Preparing directories..."
ARCH="$(detect_arch)"
USER_BIN="${HOME}/.local/bin"
AGE_DIR="${HOME}/.config/sops/age"
AGE_KEY_FILE="${AGE_DIR}/keys.txt"
TMP_DIR="$(mktemp -d)"
mkdir -p "${AGE_DIR}" "${USER_BIN}"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "[2/7] Installing sops..."
SOPS_URL="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.darwin"
download_file "${SOPS_URL}" "${USER_BIN}/sops"
verify_sha256 "${USER_BIN}/sops" "${SOPS_SHA256_DARWIN}"
chmod +x "${USER_BIN}/sops"

echo "[3/7] Installing age..."
AGE_TAR="${TMP_DIR}/age.tar.gz"
AGE_URL="https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-darwin-${ARCH}.tar.gz"
download_file "${AGE_URL}" "${AGE_TAR}"
case "${ARCH}" in
  amd64) verify_sha256 "${AGE_TAR}" "${AGE_SHA256_DARWIN_AMD64}" ;;
  arm64) verify_sha256 "${AGE_TAR}" "${AGE_SHA256_DARWIN_ARM64}" ;;
  *)
    echo "Unsupported architecture for age verification: ${ARCH}" >&2
    exit 1
    ;;
esac
tar -xzf "${AGE_TAR}" -C "${TMP_DIR}"
cp -f "${TMP_DIR}/age/age" "${USER_BIN}/age"
cp -f "${TMP_DIR}/age/age-keygen" "${USER_BIN}/age-keygen"
chmod +x "${USER_BIN}/age" "${USER_BIN}/age-keygen"

echo "[4/7] Generating age key (if missing)..."
if [[ ! -f "${AGE_KEY_FILE}" ]]; then
  "${USER_BIN}/age-keygen" -o "${AGE_KEY_FILE}"
  chmod 600 "${AGE_KEY_FILE}" || true
else
  echo "Existing key found: ${AGE_KEY_FILE}"
fi

echo "[5/7] Exporting PATH and SOPS_AGE_KEY_FILE..."
CURRENT_SHELL="$(basename "${SHELL:-zsh}")"
PROFILE_FILE="${HOME}/.zshrc"
ALT_PROFILE_FILE=""
if [[ "${CURRENT_SHELL}" == "bash" ]]; then
  PROFILE_FILE="${HOME}/.bash_profile"
  ALT_PROFILE_FILE="${HOME}/.bashrc"
fi
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
EXPORT_LINE="export SOPS_AGE_KEY_FILE=\"${AGE_KEY_FILE}\""
append_if_missing "${PROFILE_FILE}" "${PATH_LINE}"
append_if_missing "${PROFILE_FILE}" "${EXPORT_LINE}"
if [[ -n "${ALT_PROFILE_FILE}" ]]; then
  append_if_missing "${ALT_PROFILE_FILE}" "${PATH_LINE}"
  append_if_missing "${ALT_PROFILE_FILE}" "${EXPORT_LINE}"
fi
export PATH="${HOME}/.local/bin:${PATH}"
export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"

echo "[6/7] Installing global helper commands (encrypt/decrypt)..."
cat > "${USER_BIN}/encrypt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
WORK_DIR="${PWD}"
PLAIN_FILE="${1:-${WORK_DIR}/.env}"
ENC_FILE="${2:-${WORK_DIR}/.env.enc}"
CONFIG_FILE="${WORK_DIR}/env_encrypt/.sops.yaml"
if [[ ! -f "${CONFIG_FILE}" ]]; then
  CONFIG_FILE="${WORK_DIR}/.sops.yaml"
fi
sops --config "${CONFIG_FILE}" --filename-override .env encrypt --input-type dotenv --output-type dotenv --output "${ENC_FILE}" "${PLAIN_FILE}"
EOF

cat > "${USER_BIN}/decrypt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
WORK_DIR="${PWD}"
ENC_FILE="${1:-${WORK_DIR}/.env.enc}"
OUT_FILE="${2:-${WORK_DIR}/.env}"
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
echo "1) Share only the public key above."
echo "2) Never share AGE-SECRET-KEY."
echo "3) Open a new terminal, or run: source ${PROFILE_FILE}"
