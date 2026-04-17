#!/usr/bin/env bash
set -euo pipefail

readonly USER_NAME="atelier"
readonly USER_GROUP="atelier"
readonly HOME_DIR="/data/home/atelier"
readonly ATELIER_ROOT="/opt/atelier"

log() {
  printf '%s [INFO] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

ensure_dir() {
  local path="$1"
  mkdir -p "${path}"
  chown "${USER_NAME}:${USER_GROUP}" "${path}"
}

ensure_symlink() {
  local link_path="$1"
  local target_path="$2"

  if [[ -L "${link_path}" ]]; then
    local current_target
    current_target="$(readlink "${link_path}")"
    if [[ "${current_target}" == "${target_path}" ]]; then
      return 0
    fi

    ln -sfn "${target_path}" "${link_path}"
    chown -h "${USER_NAME}:${USER_GROUP}" "${link_path}"
    log "Updated symlink ${link_path} -> ${target_path}"
    return 0
  fi

  if [[ -e "${link_path}" ]]; then
    log "Leaving existing path in place: ${link_path}"
    return 0
  fi

  ln -s "${target_path}" "${link_path}"
  chown -h "${USER_NAME}:${USER_GROUP}" "${link_path}"
  log "Created symlink ${link_path} -> ${target_path}"
}

ensure_writable_copy() {
  local dest_path="$1"
  local source_path="$2"

  if [[ -L "${dest_path}" ]]; then
    local resolved_target
    resolved_target="$(readlink -f "${dest_path}")"

    if [[ "${resolved_target}" == "${source_path}" ]]; then
      rm -f "${dest_path}"
      log "Replacing symlinked path with writable copy: ${dest_path}"
    else
      log "Leaving existing symlink in place: ${dest_path}"
      return 0
    fi
  elif [[ -e "${dest_path}" ]]; then
    log "Leaving existing path in place: ${dest_path}"
    return 0
  fi

  mkdir -p "$(dirname "${dest_path}")"

  if [[ -d "${source_path}" ]]; then
    mkdir -p "${dest_path}"
    cp -a "${source_path}/." "${dest_path}/"
  else
    cp -a "${source_path}" "${dest_path}"
  fi

  chown -R "${USER_NAME}:${USER_GROUP}" "${dest_path}"
  log "Seeded writable path ${dest_path} from ${source_path}"
}

disable_lazyvim_go_extra() {
  local lazyvim_path="${HOME_DIR}/.config/nvim/lazyvim.json"
  local temp_path

  if [[ ! -f "${lazyvim_path}" ]]; then
    return 0
  fi

  temp_path="$(mktemp)"

  if ! jq '
    if (.extras | type?) == "array" then
      .extras |= map(select(. != "lazyvim.plugins.extras.lang.go"))
    else
      .
    end
  ' "${lazyvim_path}" >"${temp_path}"; then
    rm -f "${temp_path}"
    log "Leaving LazyVim config unchanged after jq parse failure: ${lazyvim_path}"
    return 0
  fi

  if cmp -s "${lazyvim_path}" "${temp_path}"; then
    rm -f "${temp_path}"
    return 0
  fi

  mv "${temp_path}" "${lazyvim_path}"
  chown "${USER_NAME}:${USER_GROUP}" "${lazyvim_path}"
  log "Removed LazyVim Go extra from ${lazyvim_path}"
}

patch_fzf_shell_integration() {
  local init_path="${HOME_DIR}/.config/zsh/init.zsh"
  local temp_path

  if [[ ! -f "${init_path}" ]]; then
    return 0
  fi

  if ! grep -Fqx 'source <(fzf --zsh)' "${init_path}"; then
    return 0
  fi

  temp_path="$(mktemp)"

  awk '
    $0 == "source <(fzf --zsh)" {
      print "if fzf --zsh >/dev/null 2>&1; then"
      print "  source <(fzf --zsh)"
      print "elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then"
      print "  source /usr/share/doc/fzf/examples/key-bindings.zsh"
      print "  [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh"
      print "elif [[ -f /usr/share/fzf/key-bindings.zsh ]]; then"
      print "  source /usr/share/fzf/key-bindings.zsh"
      print "  [[ -f /usr/share/fzf/completion.zsh ]] && source /usr/share/fzf/completion.zsh"
      print "fi"
      next
    }
    { print }
  ' "${init_path}" >"${temp_path}"

  mv "${temp_path}" "${init_path}"
  chown "${USER_NAME}:${USER_GROUP}" "${init_path}"
  log "Patched fzf shell integration in ${init_path}"
}

main() {
  install -d -m 0755 -o "${USER_NAME}" -g "${USER_GROUP}" "${HOME_DIR}"
  ensure_dir "${HOME_DIR}/.local"
  ensure_dir "${HOME_DIR}/.local/share"
  ensure_dir "${HOME_DIR}/.local/state"
  ensure_dir "${HOME_DIR}/.local/bin"
  ensure_dir "${HOME_DIR}/.cache"
  ensure_dir "${HOME_DIR}/.ssh"
  ensure_dir "${HOME_DIR}/.claude"
  ensure_dir "${HOME_DIR}/workspace"

  touch "${HOME_DIR}/.histfile"
  chown "${USER_NAME}:${USER_GROUP}" "${HOME_DIR}/.histfile"

  ensure_symlink "${HOME_DIR}/.local/share/atelier" "${ATELIER_ROOT}"
  ensure_writable_copy "${HOME_DIR}/.config" "${ATELIER_ROOT}/config/dot-config"
  ensure_writable_copy "${HOME_DIR}/.zshrc" "${ATELIER_ROOT}/config/dot-zshrc"
  ensure_writable_copy "${HOME_DIR}/.zprofile" "${ATELIER_ROOT}/config/dot-zprofile"
  ensure_writable_copy "${HOME_DIR}/.claude/settings.json" "${ATELIER_ROOT}/config/dot-claude/settings.json"
  ensure_writable_copy "${HOME_DIR}/.claude/statusline-command.sh" "${ATELIER_ROOT}/config/dot-claude/statusline-command.sh"
  ensure_symlink "${HOME_DIR}/workspace/homeassistant" "/homeassistant"
  disable_lazyvim_go_extra
  patch_fzf_shell_integration

  chmod 0700 "${HOME_DIR}/.ssh"
  chmod 0755 "${HOME_DIR}/workspace"
  chown "${USER_NAME}:${USER_GROUP}" \
    "${HOME_DIR}" \
    "${HOME_DIR}/.local" \
    "${HOME_DIR}/.local/share" \
    "${HOME_DIR}/.local/state" \
    "${HOME_DIR}/.local/bin" \
    "${HOME_DIR}/.cache" \
    "${HOME_DIR}/.ssh" \
    "${HOME_DIR}/.claude" \
    "${HOME_DIR}/workspace"
}

main "$@"
