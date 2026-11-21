# shellcheck shell=bash
# Minimal logging helpers shared by the app modules. Messages never contain option values,
# so secrets such as passwords cannot end up in the app log.

log::info() {
  printf '[INFO] %s\n' "$*"
}

log::warn() {
  printf '[WARN] %s\n' "$*" >&2
}

log::error() {
  printf '[ERROR] %s\n' "$*" >&2
}

# Logs an error and stops the app. NPMplus is never started in a half-configured state.
log::fatal() {
  log::error "$@"
  exit 1
}
