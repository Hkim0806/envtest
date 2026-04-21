#!/usr/bin/env bash

set -euo pipefail

DEFAULT_ENV_FILE=".env.enc"
IDE_PRIORITY=(code cursor windsurf idea pycharm webstorm phpstorm goland rider studio nvim vim)

usage() {
  cat <<'EOF'
Usage:
  ./scripts/open-ide.sh [IDE] [--env-file <path>]
  ./scripts/open-ide.sh --help

Description:
  Runs an IDE/editor via `sops exec-env` so decrypted env vars are injected
  into the spawned process.

Supported IDE/editor commands:
  code, cursor, windsurf, idea, pycharm, webstorm, phpstorm, goland, rider, studio, nvim, vim

Examples:
  ./scripts/open-ide.sh code
  ./scripts/open-ide.sh cursor
  ./scripts/open-ide.sh idea
  ./scripts/open-ide.sh --env-file .env.dev.enc
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

is_supported_ide() {
  local ide="$1"
  local item
  for item in "${IDE_PRIORITY[@]}"; do
    if [[ "${item}" == "${ide}" ]]; then
      return 0
    fi
  done
  return 1
}

pick_default_ide() {
  local ide
  for ide in "${IDE_PRIORITY[@]}"; do
    if has_cmd "${ide}"; then
      echo "${ide}"
      return 0
    fi
  done
  return 1
}


run_ide_with_env() {
  local ide="$1"
  local env_file="$2"
  local root="$3"

  if ! has_cmd "${ide}"; then
    die "IDE command '${ide}' was not found in PATH."
  fi
  if [[ ! -f "${env_file}" ]]; then
    die "Encrypted env file '${env_file}' does not exist."
  fi

  case "${ide}" in
    code|cursor|windsurf|idea|pycharm|webstorm|phpstorm|goland|rider|studio|nvim|vim)
      echo "Launching '${ide}' with env from '${env_file}' at '${root}'..."
      sops --input-type dotenv exec-env "${env_file}" "bash -lc '${ide} --new-window \"${root}\"'"
      ;;
    *)
      die "Unsupported IDE '${ide}'."
      ;;
  esac
}

main() {
  local ide_arg=""
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
      -*)
        die "Unknown option: $1 (use --help)"
        ;;
      *)
        if [[ -n "${ide_arg}" ]]; then
          die "Too many positional arguments. Use only one IDE name."
        fi
        ide_arg="$1"
        shift
        ;;
    esac
  done

  if [[ -z "${ide_arg}" ]]; then
    ide_arg="$(pick_default_ide)" || die "No supported IDE command found in PATH."
  else
    is_supported_ide "${ide_arg}" || die "Unsupported IDE '${ide_arg}'. Use --help to see supported options."
  fi

  if [[ "${env_file}" != /* ]]; then
    env_file="${root}/${env_file}"
  fi

  run_ide_with_env "${ide_arg}" "${env_file}" "${root}"
}

main "$@"
