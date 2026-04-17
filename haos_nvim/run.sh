#!/usr/bin/env bash
set -euo pipefail

readonly CONFIG_PATH="/data/options.json"
readonly HOME_DIR="/data/home/atelier"
readonly SSH_DIR="/data/ssh"
readonly AUTHORIZED_KEYS_PATH="${SSH_DIR}/authorized_keys"
readonly SSHD_CONFIG_PATH="${SSH_DIR}/sshd_config"

log() {
  local level="$1"
  shift
  printf '%s [%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "${level}" "$*"
}

fail() {
  log ERROR "$*"
  exit 1
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    fail "Expected file not found: ${path}"
  fi
}

require_dir() {
  local path="$1"
  if [[ ! -d "${path}" ]]; then
    fail "Expected directory not found: ${path}"
  fi
}

generate_host_key() {
  local type="$1"
  local path="$2"

  if [[ -f "${path}" ]]; then
    return 0
  fi

  log INFO "Generating SSH host key ${path}"
  ssh-keygen -q -t "${type}" -N '' -f "${path}"
}

map_sshd_log_level() {
  local addon_level="${1:-info}"

  case "${addon_level,,}" in
    trace) printf 'DEBUG3\n' ;;
    debug) printf 'DEBUG\n' ;;
    info) printf 'INFO\n' ;;
    notice) printf 'VERBOSE\n' ;;
    warning) printf 'INFO\n' ;;
    error) printf 'ERROR\n' ;;
    fatal) printf 'FATAL\n' ;;
    *)
      log WARNING "Unknown log_level '${addon_level}', defaulting to INFO"
      printf 'INFO\n'
      ;;
  esac
}

render_authorized_keys() {
  local count

  count="$(
    jq '
      .authorized_keys // []
      | map(select(type == "string"))
      | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
      | map(select(length > 0))
      | length
    ' "${CONFIG_PATH}"
  )"

  if [[ "${count}" == "0" ]]; then
    fail "The add-on requires at least one non-empty entry in authorized_keys."
  fi

  jq -r '
    .authorized_keys // []
    | map(select(type == "string"))
    | map(gsub("^[[:space:]]+|[[:space:]]+$"; ""))
    | map(select(length > 0))
    | .[]
  ' "${CONFIG_PATH}" >"${AUTHORIZED_KEYS_PATH}"

  chmod 0600 "${AUTHORIZED_KEYS_PATH}"
  chown root:root "${AUTHORIZED_KEYS_PATH}"

  log INFO "Rendered ${count} authorized SSH key(s)"
}

main() {
  require_file "${CONFIG_PATH}"
  require_dir /homeassistant

  mkdir -p "${SSH_DIR}" /var/run/sshd
  chmod 0700 "${SSH_DIR}"

  local log_level sshd_log_level
  log_level="$(jq -r '.log_level // "info"' "${CONFIG_PATH}")"
  sshd_log_level="$(map_sshd_log_level "${log_level}")"

  /opt/ha_nvim/scripts/bootstrap-home.sh

  if ! sudo -u atelier test -w /homeassistant; then
    log WARNING "atelier cannot write directly to /homeassistant with the current mount permissions"
  fi

  generate_host_key ed25519 "${SSH_DIR}/ssh_host_ed25519_key"
  generate_host_key rsa "${SSH_DIR}/ssh_host_rsa_key"

  chmod 0600 "${SSH_DIR}/ssh_host_ed25519_key" "${SSH_DIR}/ssh_host_rsa_key"
  chmod 0644 "${SSH_DIR}/ssh_host_ed25519_key.pub" "${SSH_DIR}/ssh_host_rsa_key.pub"
  chown root:root \
    "${SSH_DIR}/ssh_host_ed25519_key" \
    "${SSH_DIR}/ssh_host_ed25519_key.pub" \
    "${SSH_DIR}/ssh_host_rsa_key" \
    "${SSH_DIR}/ssh_host_rsa_key.pub"

  render_authorized_keys

  /opt/ha_nvim/scripts/write-sshd-config.sh "${SSHD_CONFIG_PATH}" "${AUTHORIZED_KEYS_PATH}" "${sshd_log_level}"

  log INFO "Starting sshd on port 2222"
  exec /usr/sbin/sshd -D -e -f "${SSHD_CONFIG_PATH}"
}

main "$@"
