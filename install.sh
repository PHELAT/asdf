#!/bin/sh
#
# Copyright 2026 Mahdi Nouri
# SPDX-License-Identifier: Apache-2.0

set -eu

ASDF_HUMAN_VERSION="1.1.0"
ASDF_UPDATE_VERSION="2026070600"
ASDF_REMOTE_BASE_URL_OVERRIDE="${ASDF_REMOTE_BASE_URL:-}"
ASDF_REMOTE_BASE_URL="https://raw.githubusercontent.com/PHELAT/asdf/main"
ASDF_REMOTE_BASE_URL="${ASDF_REMOTE_BASE_URL_OVERRIDE:-$ASDF_REMOTE_BASE_URL}"
ASDF_ANALYTICS_URL_OVERRIDE="${ASDF_ANALYTICS_URL:-}"
ASDF_ANALYTICS_URL="https://asdf-analytics.phelat.workers.dev/event"
ASDF_ANALYTICS_URL="${ASDF_ANALYTICS_URL_OVERRIDE:-$ASDF_ANALYTICS_URL}"

die() {
  printf 'asdf installer: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "$1 is required"
}

absolute_path() {
  case "$1" in
    /*)
      printf '%s\n' "$1"
      ;;
    *)
      printf '%s/%s\n' "$(pwd -P)" "$1"
      ;;
  esac
}

path_contains_dir() {
  case ":${PATH:-}:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_string() {
  printf '"%s"' "$(json_escape "$1")"
}

send_install_analytics() {
  install_name="$1"
  conflict_fallback="$2"

  [ "${ASDF_ANALYTICS:-1}" != "0" ] || return 0
  command -v curl >/dev/null 2>&1 || return 0

  case "$conflict_fallback" in
    true | 1 | yes) conflict_fallback="true" ;;
    *) conflict_fallback="false" ;;
  esac

  os_name="$(uname -s 2>/dev/null || printf 'unknown')"
  shell_name="$(basename "${SHELL:-unknown}")"
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf 'unknown')"

  payload="$(printf '{"event":%s,"human_version":%s,"update_version":%s,"install_name":%s,"os":%s,"shell":%s,"conflict_fallback":%s,"timestamp":%s}' \
    "$(json_string install)" \
    "$(json_string "$ASDF_HUMAN_VERSION")" \
    "$(json_string "$ASDF_UPDATE_VERSION")" \
    "$(json_string "$install_name")" \
    "$(json_string "$os_name")" \
    "$(json_string "$shell_name")" \
    "$conflict_fallback" \
    "$(json_string "$timestamp")")"

  curl -fsS --max-time 2 \
    -H 'content-type: application/json' \
    -X POST \
    --data "$payload" \
    "$ASDF_ANALYTICS_URL" >/dev/null 2>&1 || :
}

append_completion_block() {
  install_name="$1"

  if [ -z "${HOME:-}" ]; then
    printf 'asdf installer: HOME is not set; skipping shell completion setup\n' >&2
    return 0
  fi

  shell_name="$(basename "${SHELL:-}")"
  case "$shell_name" in
    zsh)
      rc_file="$HOME/.zshrc"
      completion_shell="zsh"
      ;;
    bash)
      rc_file="$HOME/.bashrc"
      completion_shell="bash"
      ;;
    *)
      printf 'asdf installer: could not detect bash or zsh from SHELL; skipping shell completion setup\n' >&2
      return 0
      ;;
  esac

  marker_begin="# >>> asdf completion >>>"
  marker_end="# <<< asdf completion <<<"

  if [ -f "$rc_file" ] && grep -F "$marker_begin" "$rc_file" >/dev/null 2>&1; then
    printf 'asdf installer: shell completion block already present in %s\n' "$rc_file"
    return 0
  fi

  : >>"$rc_file" ||
    die "could not write to $rc_file for shell completion setup"

  {
    printf '\n%s\n' "$marker_begin"
    printf 'if command -v %s >/dev/null 2>&1; then\n' "$install_name"
    printf '  eval "$(%s --completion %s)"\n' "$install_name" "$completion_shell"
    printf 'fi\n'
    printf '%s\n' "$marker_end"
  } >>"$rc_file" ||
    die "could not append shell completion setup to $rc_file"

  printf 'asdf installer: added shell completion setup to %s\n' "$rc_file"
}

if [ -z "${ASDF_INSTALL_DIR:-}" ] && [ -z "${HOME:-}" ]; then
  die "HOME is required unless ASDF_INSTALL_DIR is set"
fi

need_command curl
need_command bash
need_command chmod
need_command mkdir
need_command mv

install_dir="${ASDF_INSTALL_DIR:-$HOME/.local/bin}"
install_dir="$(absolute_path "$install_dir")"

mkdir -p "$install_dir" ||
  die "could not create install directory $install_dir"

install_dir="$(cd "$install_dir" && pwd -P)" ||
  die "could not resolve install directory $install_dir"

requested_name="${ASDF_INSTALL_NAME:-}"
install_name="asdf"
conflict_fallback="false"

if [ -n "$requested_name" ]; then
  case "$requested_name" in
    asdf | asdff)
      install_name="$requested_name"
      ;;
    *)
      die "ASDF_INSTALL_NAME must be asdf or asdff"
      ;;
  esac

  existing_requested="$(command -v "$install_name" 2>/dev/null || true)"
  target_requested="$install_dir/$install_name"
  if [ -n "$existing_requested" ]; then
    existing_requested="$(absolute_path "$existing_requested")"
    if [ "$existing_requested" != "$target_requested" ]; then
      printf 'asdf installer: warning: %s currently resolves to %s on PATH; installed requested name at %s\n' "$install_name" "$existing_requested" "$target_requested" >&2
    fi
  fi
else
  existing_asdf="$(command -v asdf 2>/dev/null || true)"
  target_asdf="$install_dir/asdf"

  if [ -n "$existing_asdf" ]; then
    existing_asdf="$(absolute_path "$existing_asdf")"
  fi

  if [ -n "$existing_asdf" ] && [ "$existing_asdf" != "$target_asdf" ]; then
    install_name="asdff"
    conflict_fallback="true"
    printf 'asdf installer: warning: existing asdf found at %s; installing this project as asdff instead\n' "$existing_asdf" >&2
  fi
fi

target_path="$install_dir/$install_name"
tmp_file=""

cleanup() {
  if [ -n "$tmp_file" ] && [ -f "$tmp_file" ]; then
    rm -f "$tmp_file"
  fi
}

trap cleanup EXIT HUP INT TERM

tmp_file="$(mktemp "$install_dir/.${install_name}.XXXXXX")" ||
  die "could not create a temporary file in $install_dir"

if ! curl -fsSL "$ASDF_REMOTE_BASE_URL/asdf" -o "$tmp_file"; then
  die "could not download asdf from $ASDF_REMOTE_BASE_URL/asdf"
fi

if ! bash -n "$tmp_file" >/dev/null 2>&1; then
  die "downloaded asdf is not a valid bash script"
fi

chmod 755 "$tmp_file" ||
  die "could not make $install_name executable"

mv -f "$tmp_file" "$target_path" ||
  die "could not install $target_path"
tmp_file=""

append_completion_block "$install_name"
send_install_analytics "$install_name" "$conflict_fallback"

printf 'asdf installer: installed %s\n' "$target_path"

if ! path_contains_dir "$install_dir"; then
  printf 'asdf installer: %s is not on PATH\n' "$install_dir" >&2
  printf 'asdf installer: add this to your shell startup file: export PATH="%s:$PATH"\n' "$install_dir" >&2
fi
