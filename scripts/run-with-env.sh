#!/usr/bin/env bash

set -euo pipefail

DEFAULT_ENV_FILE=".env.enc"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run-with-env.sh [--env-file <path>] -- <command> [args...]
  ./scripts/run-with-env.sh [--env-file <path>] <command> [args...]

Examples:
  ./scripts/run-with-env.sh npm run dev
  ./scripts/run-with-env.sh --env-file .env.dev.enc -- npm run dev
EOF
}

project_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  (cd "${script_dir}/.." && pwd)
}

die() {
  echo "Error: $*" >&2
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

main() {
  local env_file="${DEFAULT_ENV_FILE}"
  local root
  root="$(project_root)"
  has_cmd sops || die "sops command not found in PATH."

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --env-file)
        [[ $# -ge 2 ]] || die "--env-file requires a value."
        env_file="$2"
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        break
        ;;
    esac
  done

  [[ $# -gt 0 ]] || die "No command provided. Use --help."

  if [[ "${env_file}" != /* ]]; then
    env_file="${root}/${env_file}"
  fi
  [[ -f "${env_file}" ]] || die "Encrypted env file '${env_file}' does not exist."

  sops exec-env --filename-override .env "${env_file}" "$@"
}

main "$@"
