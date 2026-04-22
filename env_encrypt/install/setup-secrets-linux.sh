#!/usr/bin/env bash

set -euo pipefail

SOPS_VERSION="v3.12.2"
AGE_VERSION="v1.3.1"
SOPS_CHECKSUMS_SHA256="1c1ec25c8320666319abbe531dc2309b0575110acb74dea3a5f2a2f431eb2a42"
AGE_SHA256_LINUX_AMD64="bdc69c09cbdd6cf8b1f333d372a1f58247b3a33146406333e30c0f26e8f51377"
AGE_SHA256_LINUX_ARM64="c6878a324421b69e3e20b00ba17c04bc5c6dab0030cfe55bf8f68fa8d9e9093a"

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

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${file}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${file}" | awk '{print $1}'
  else
    echo "[ERROR] sha256sum or shasum is required." >&2
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

expected_hash_from_checksums() {
  local checksums_file="$1"
  local artifact_name="$2"
  local value
  value="$(awk -v target="${artifact_name}" '$2==target {print $1; exit}' "${checksums_file}")"
  if [[ -z "${value}" ]]; then
    echo "[ERROR] Could not find '${artifact_name}' in ${checksums_file}" >&2
    exit 1
  fi
  echo "${value}"
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
mkdir -p "${USER_BIN}" "${AGE_DIR}"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "[2/7] Installing sops..."
SOPS_URL="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.${ARCH}"
SOPS_CHECKSUMS_URL="https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.checksums.txt"
SOPS_CHECKSUMS_FILE="${TMP_DIR}/sops-${SOPS_VERSION}.checksums.txt"
download_file "${SOPS_URL}" "${USER_BIN}/sops"
download_file "${SOPS_CHECKSUMS_URL}" "${SOPS_CHECKSUMS_FILE}"
verify_sha256 "${SOPS_CHECKSUMS_FILE}" "${SOPS_CHECKSUMS_SHA256}"
SOPS_EXPECTED_SHA256="$(expected_hash_from_checksums "${SOPS_CHECKSUMS_FILE}" "sops-${SOPS_VERSION}.linux.${ARCH}")"
verify_sha256 "${USER_BIN}/sops" "${SOPS_EXPECTED_SHA256}"
chmod +x "${USER_BIN}/sops"

echo "[3/7] Installing age..."
AGE_TAR="${TMP_DIR}/age.tar.gz"
AGE_URL="https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-${ARCH}.tar.gz"
download_file "${AGE_URL}" "${AGE_TAR}"
case "${ARCH}" in
  amd64) verify_sha256 "${AGE_TAR}" "${AGE_SHA256_LINUX_AMD64}" ;;
  arm64) verify_sha256 "${AGE_TAR}" "${AGE_SHA256_LINUX_ARM64}" ;;
  *)
    echo "Unsupported architecture for age verification: ${ARCH}" >&2
    exit 1
    ;;
esac
tar -xzf "${AGE_TAR}" -C "${TMP_DIR}"
cp -f "${TMP_DIR}/age/age" "${USER_BIN}/age"
cp -f "${TMP_DIR}/age/age-keygen" "${USER_BIN}/age-keygen"
chmod +x "${USER_BIN}/age" "${USER_BIN}/age-keygen"

echo "[4/7] Updating shell profile..."
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
SOPS_KEY_LINE='export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"'
append_if_missing "${HOME}/.bashrc" "${PATH_LINE}"
append_if_missing "${HOME}/.bashrc" "${SOPS_KEY_LINE}"
append_if_missing "${HOME}/.zshrc" "${PATH_LINE}"
append_if_missing "${HOME}/.zshrc" "${SOPS_KEY_LINE}"
export PATH="${HOME}/.local/bin:${PATH}"
export SOPS_AGE_KEY_FILE="${AGE_KEY_FILE}"

echo "[5/7] Generating age key (if missing)..."
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
echo "1) Open a new terminal or run: source ~/.bashrc"
echo "2) Share only the public key above."
echo "3) Never share AGE-SECRET-KEY."
