# shellcheck shell=bash
# One-time import of an existing Nginx Proxy Manager setup (proxy hosts, users, certificates,
# access lists, custom nginx snippets), so nobody has to configure everything again.
#
# Sources
#   community_app  The Home Assistant Community App "Nginx Proxy Manager". Its data sits in the app
#                  config folder, which this app can read through the all_app_configs mapping.
#   import_folder  Any other installation. Copy its data folder (and the letsencrypt folder) into
#                  <app config>/import first; see docs/MIGRATION.md.
#
# The source is only read, never changed. NPMplus data that already exists is never overwritten.

APP_CONFIGS_DIR="${APP_CONFIGS_DIR:-/app_configs}"
IMPORT_DIR="${IMPORT_DIR:-${CONFIG_DIR}/${IMPORT_DIRECTORY}}"
MIGRATIONS_DIR="${MIGRATIONS_DIR:-/app/migrations}"
IMPORT_DATABASE="${IMPORT_DATABASE:-/usr/local/lib/npmplus-app/import_database.py}"
NPMPLUS_DATABASE="${DATA_DIR:-/data}/npmplus/database.sqlite"

# Slug of the Community App; the part before it is a hash of the repository it was installed from.
readonly COMMUNITY_APP_FOLDER_PATTERN='*_nginxproxymanager'

# Where Nginx Proxy Manager keeps things (left) and where NPMplus expects them (right, below /data).
readonly IMPORT_DIRECTORIES=(
  "access:access"
  "custom_ssl:tls/custom"
  "letsencrypt:tls/certbot"
  "nginx/custom:custom_nginx"
  "nginx/default_www:html"
)

# Paths certbot recorded in its renewal files while it ran inside Nginx Proxy Manager.
readonly NPMPLUS_CERTBOT_DIR=/data/tls/certbot

# Prints the folder to import from, or stops the app with a hint on what is missing.
migration::locate_source() {
  local mode=$1 folder
  local -a candidates=()

  case $mode in
    community_app)
      while IFS= read -r folder; do
        [[ -f ${folder}/database.sqlite ]] && candidates+=("$folder")
      done < <(find "$APP_CONFIGS_DIR" -mindepth 1 -maxdepth 1 -name "$COMMUNITY_APP_FOLDER_PATTERN" 2> /dev/null | sort)
      ((${#candidates[@]} > 0)) \
        || log::fatal "No data of the Nginx Proxy Manager app found below ${APP_CONFIGS_DIR}. Is it installed? Otherwise use migration.source: import_folder."
      ((${#candidates[@]} == 1)) \
        || log::fatal "Found several Nginx Proxy Manager data folders (${candidates[*]}). Use migration.source: import_folder for the one you want."
      printf '%s\n' "${candidates[0]}"
      ;;
    import_folder)
      [[ -f ${IMPORT_DIR}/database.sqlite ]] \
        || log::fatal "No database.sqlite in ${IMPORT_DIR}. Copy the data of your old installation there first."
      printf '%s\n' "$IMPORT_DIR"
      ;;
    *)
      log::fatal "Unknown migration source '${mode}'"
      ;;
  esac
}

migration::copy_directories() {
  local source=$1 entry from to

  for entry in "${IMPORT_DIRECTORIES[@]}"; do
    from="${source}/${entry%%:*}"
    to="${DATA_DIR}/${entry#*:}"
    [[ -d $from ]] || continue
    mkdir -p "$to"
    cp -a "${from}/." "${to}/"
    log::info "Imported ${entry%%:*}"
  done
}

# Renewal files point at /etc/letsencrypt (or the app config folder) and at the old webroot used
# for HTTP-01 challenges. Without rewriting them, renewals would write the challenge files where
# NPMplus' nginx does not serve them.
migration::rewrite_certbot_paths() {
  local renewal="${DATA_DIR}/tls/certbot/renewal"
  [[ -d $renewal ]] || return 0

  find "$renewal" -type f -name '*.conf' -exec sed -i \
    -e "s|/config/letsencrypt-acme-challenge|${NPMPLUS_CERTBOT_DIR}/acme-challenge|g" \
    -e "s|/data/letsencrypt-acme-challenge|${NPMPLUS_CERTBOT_DIR}/acme-challenge|g" \
    -e "s|/etc/letsencrypt|${NPMPLUS_CERTBOT_DIR}|g" \
    -e "s|/config/letsencrypt|${NPMPLUS_CERTBOT_DIR}|g" \
    {} +
}

migration::run() {
  local mode source
  mode=$(options::get migration.source)
  [[ -z $mode || $mode == none ]] && return 0

  if [[ -s $NPMPLUS_DATABASE ]]; then
    log::warn "NPMplus already has data, so the import (${mode}) is skipped. Set migration.source to none to hide this message."
    return 0
  fi

  source=$(migration::locate_source "$mode")
  log::info "Importing Nginx Proxy Manager data from ${source}"

  python3 "$IMPORT_DATABASE" "${source}/database.sqlite" "$NPMPLUS_DATABASE" "$MIGRATIONS_DIR" \
    || log::fatal "Import aborted. The source data was not modified."
  migration::copy_directories "$source"
  migration::rewrite_certbot_paths

  log::info "Import finished. You can set migration.source to none now."
}
