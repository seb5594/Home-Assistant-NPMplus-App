#!/usr/bin/env bash
# Scenarios export their sandbox variables inside a subshell and call helpers defined outside it.
# shellcheck disable=SC2030,SC2031
# shellcheck source-path=SCRIPTDIR/../../npmplus
set -Eeuo pipefail

# Runs inside the built image. Every scenario works in its own temporary folder and reports
# a "PASS: <name>" line, which the pipeline counts.
RUN_SCRIPT="${RUN_SCRIPT:-/run.sh}"
WORKDIR=$(mktemp -d)
trap 'rm -rf -- "$WORKDIR"' EXIT

# ---- helpers -----------------------------------------------------------------------------------

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_equals() { # expected actual message
  [[ $1 == "$2" ]] || fail "$3 (expected '$1', got '$2')"
}

assert_contains() { # text needle message
  [[ $1 == *"$2"* ]] || fail "$3 (missing '$2' in: $1)"
}

assert_file() { # path message
  [[ -e $1 ]] || fail "$2 (no such file: $1)"
}

assert_no_file() { # path message
  [[ ! -e $1 ]] || fail "$2 (unexpected file: $1)"
}

# Runs a scenario in a subshell with a fresh sandbox below $WORKDIR and the app code sourced
# against it. Usage: scenario <name> <function>
scenario() {
  local name=$1 body=$2
  local sandbox="${WORKDIR}/${name}"
  mkdir -p "${sandbox}"/{data,config,app_configs,addon_configs}
  (
    export OPTIONS_FILE="${sandbox}/options.json" DATA_DIR="${sandbox}/data" CONFIG_DIR="${sandbox}/config"
    export APP_CONFIGS_DIRS="${sandbox}/app_configs ${sandbox}/addon_configs" NGINX_CONF_DIR="${sandbox}/nginx-conf.d"
    export SANDBOX="$sandbox"
    echo '{}' > "$OPTIONS_FILE"
    # shellcheck source=run.sh
    source "$RUN_SCRIPT"
    "$body"
  )
  echo "PASS: ${name}"
}

write_options() { # json
  printf '%s\n' "$1" > "$OPTIONS_FILE"
}

# An Nginx Proxy Manager style database that records every migration this NPMplus knows.
make_database() { # path [extra migration name]
  python3 - "$1" "${2:-}" <<'PYTHON'
import os
import sqlite3
import sys

path, extra = sys.argv[1], sys.argv[2]
database = sqlite3.connect(path)
database.execute("CREATE TABLE migrations (id INTEGER PRIMARY KEY, name TEXT, batch INTEGER, migration_time TEXT)")
names = sorted(os.listdir("/app/migrations")) + ([extra] if extra else [])
database.executemany("INSERT INTO migrations (name, batch) VALUES (?, 1)", [(name,) for name in names])
database.execute("CREATE TABLE user (id INTEGER PRIMARY KEY, email TEXT)")
database.execute("INSERT INTO user (email) VALUES ('admin@example.org')")
database.commit()
PYTHON
}

# A data folder the way the Community App for Nginx Proxy Manager leaves it.
make_community_source() { # target folder
  local source=$1
  mkdir -p "${source}"/{access,custom_ssl/npm-3,letsencrypt/renewal,letsencrypt/archive/npm-2,letsencrypt/live/npm-2,nginx/custom,nginx/default_www}
  make_database "${source}/database.sqlite"
  echo 'user:hash' > "${source}/access/1"
  echo 'custom-certificate' > "${source}/custom_ssl/npm-3/fullchain.pem"
  echo 'certificate' > "${source}/letsencrypt/archive/npm-2/fullchain1.pem"
  ln -s ../../archive/npm-2/fullchain1.pem "${source}/letsencrypt/live/npm-2/fullchain.pem"
  cat > "${source}/letsencrypt/renewal/npm-2.conf" <<'EOF'
archive_dir = /etc/letsencrypt/archive/npm-2
[renewalparams]
webroot_path = /config/letsencrypt-acme-challenge,
[[webroot_map]]
example.org = /data/letsencrypt-acme-challenge
EOF
  echo 'client_max_body_size 5g;' > "${source}/nginx/custom/http.conf"
  echo '<h1>hello</h1>' > "${source}/nginx/default_www/index.html"
}

checksum_tree() { # folder: content and symlink fingerprint of a whole tree
  (cd "$1" && find . -type f -exec sha256sum {} + | sort && find . -type l -exec readlink {} + | sort)
}

# ---- options -----------------------------------------------------------------------------------

options_are_exported() {
  write_options '{
    "certificates": {"profile": "none", "verify_acme_tls": false, "renew_interval_hours": 6, "email": ""},
    "network": {"disable_ipv6": true},
    "logging": {"goaccess": true},
    "advanced": {"extra_environment": ["INITIAL_DEFAULT_PAGE=444", "custom_lowercase=works"]}
  }'
  options::export_environment > /dev/null
  assert_equals none "$ACME_PROFILE" "a string option is exported"
  assert_equals false "$ACME_SERVER_TLS_VERIFY" "false is a value, not an unset option"
  assert_equals 6 "$CERTBOT_RUN_INTERVAL" "a number is exported"
  assert_equals true "$DISABLE_IPV6" "a boolean option is exported"
  assert_equals works "$(printenv custom_lowercase)" "extra variables may use any valid name"
  assert_equals true "$GOA" "true is exported"
  assert_equals 444 "$INITIAL_DEFAULT_PAGE" "extra environment is exported"
  [[ -z ${ACME_EMAIL+x} ]] || fail "an empty option must not be exported"
  [[ -z ${ACME_SERVER+x} ]] || fail "an unset option must not be exported"
}

options_do_not_leak_into_the_log() {
  write_options '{"account": {"initial_admin_password": "s3cret-value"}, "advanced": {"extra_environment": ["COOKIE_SECRET=another-secret"]}}'
  local output
  output=$(options::export_environment)
  [[ $output != *s3cret-value* && $output != *another-secret* ]] || fail "secrets must not be logged"
}

every_mapped_variable_exists_upstream() {
  local entry name missing=()
  while IFS= read -r entry; do
    [[ -z $entry || $entry == \#* ]] && continue
    name=${entry#*=}
    grep -rqw --exclude-dir=node_modules -- "$name" /usr/local/bin /usr/local/nginx/conf /app 2> /dev/null \
      || missing+=("$name")
  done < "$OPTION_ENV_MAP"
  ((${#missing[@]} == 0)) || fail "NPMplus does not know: ${missing[*]}"
}

# ---- storage -----------------------------------------------------------------------------------

storage_links_user_folders() {
  mkdir -p "${DATA_DIR}/custom_nginx"
  echo 'from data' > "${DATA_DIR}/custom_nginx/old.conf"
  mkdir -p "${CONFIG_DIR}/custom_nginx"
  echo 'from config' > "${CONFIG_DIR}/custom_nginx/keep.conf"
  echo 'newer' > "${CONFIG_DIR}/custom_nginx/old.conf"

  storage::prepare
  storage::prepare # a second start changes nothing

  [[ -L ${DATA_DIR}/custom_nginx ]] || fail "custom_nginx must be a link"
  assert_equals 'newer' "$(cat "${CONFIG_DIR}/custom_nginx/old.conf")" "existing files in the config folder win"
  assert_file "${CONFIG_DIR}/custom_nginx/keep.conf" "files in the config folder stay"
  [[ -L ${DATA_DIR}/html ]] || fail "html must be a link"
  assert_file "${CONFIG_DIR}/import" "the import folder is created for people to find"
}

# ---- migration ---------------------------------------------------------------------------------

migration_is_off_by_default() {
  migration::run
  assert_no_file "$NPMPLUS_DATABASE" "nothing is imported without a source"
}

migration_imports_the_community_app() {
  local source="${SANDBOX}/app_configs/a0d7b954_nginxproxymanager" before
  make_community_source "$source"
  before=$(checksum_tree "$source")
  write_options '{"migration": {"source": "community_app"}}'
  storage::prepare

  migration::run > /dev/null

  assert_equals 1 "$(python3 -c "import sqlite3,sys;print(sqlite3.connect(sys.argv[1]).execute('SELECT count(*) FROM user').fetchone()[0])" "$NPMPLUS_DATABASE")" "database copied"
  assert_equals 600 "$(stat -c %a "$NPMPLUS_DATABASE")" "database is private"
  assert_file "${DATA_DIR}/access/1" "access lists"
  assert_file "${DATA_DIR}/tls/custom/npm-3/fullchain.pem" "custom certificates"
  assert_file "${DATA_DIR}/tls/certbot/archive/npm-2/fullchain1.pem" "certbot archive"
  [[ -L ${DATA_DIR}/tls/certbot/live/npm-2/fullchain.pem ]] || fail "certbot links stay links"
  assert_equals '../../archive/npm-2/fullchain1.pem' "$(readlink "${DATA_DIR}/tls/certbot/live/npm-2/fullchain.pem")" "certbot links stay relative"
  assert_file "${CONFIG_DIR}/custom_nginx/http.conf" "custom nginx snippets land in the visible folder"
  assert_file "${CONFIG_DIR}/html/index.html" "default site content lands in the visible folder"

  local renewal
  renewal=$(cat "${DATA_DIR}/tls/certbot/renewal/npm-2.conf")
  assert_contains "$renewal" "archive_dir = /data/tls/certbot/archive/npm-2" "renewal config points into the new location"
  assert_contains "$renewal" "webroot_path = /data/tls/certbot/acme-challenge," "webroot of HTTP-01 challenges follows"
  assert_contains "$renewal" "example.org = /data/tls/certbot/acme-challenge" "webroot map follows"
  [[ $renewal != *letsencrypt-acme-challenge* && $renewal != */etc/letsencrypt* ]] || fail "no old paths may remain"

  assert_equals "$before" "$(checksum_tree "$source")" "the source is never modified"
}

migration_finds_the_legacy_mount_point() {
  # Older Supervisors, and the legacy map type, mount the configuration folders at /addon_configs.
  make_community_source "${SANDBOX}/addon_configs/a0d7b954_nginxproxymanager"
  write_options '{"migration": {"source": "community_app"}}'
  storage::prepare
  migration::run > /dev/null
  assert_file "$NPMPLUS_DATABASE" "the database is found below the legacy mount point"
  assert_file "${DATA_DIR}/access/1" "its files are imported as well"
}

migration_skips_existing_data() {
  make_community_source "${SANDBOX}/app_configs/a0d7b954_nginxproxymanager"
  mkdir -p "${DATA_DIR}/npmplus"
  echo 'existing' > "$NPMPLUS_DATABASE"
  write_options '{"migration": {"source": "community_app"}}'

  local output
  output=$(migration::run 2>&1)

  assert_equals existing "$(cat "$NPMPLUS_DATABASE")" "existing data is never overwritten"
  assert_contains "$output" "import (community_app) is skipped" "the user is told why"
}

migration_refuses_databases_from_newer_releases() {
  local source="${SANDBOX}/app_configs/a0d7b954_nginxproxymanager" output status=0
  make_community_source "$source"
  rm -f "${source}/database.sqlite"
  make_database "${source}/database.sqlite" "29990101000000_from_the_future.js"
  write_options '{"migration": {"source": "community_app"}}'

  output=$( (migration::run) 2>&1) || status=$?

  assert_equals 1 "$status" "the start is aborted"
  assert_contains "$output" "29990101000000_from_the_future.js" "the unknown migration is named"
  assert_no_file "$NPMPLUS_DATABASE" "nothing is imported"
  assert_no_file "${DATA_DIR}/access" "no file is copied"
}

migration_reports_a_missing_source() {
  local output status=0
  write_options '{"migration": {"source": "community_app"}}'
  output=$( (migration::run) 2>&1) || status=$?
  assert_equals 1 "$status" "the start is aborted"
  assert_contains "$output" "No data of the Nginx Proxy Manager app found" "the reason is explained"

  write_options '{"migration": {"source": "import_folder"}}'
  output=$( (migration::run) 2>&1) || status=$?
  assert_contains "$output" "Copy the data of your old installation" "the import folder needs data"
}

migration_imports_a_manual_folder() {
  make_community_source "${CONFIG_DIR}/import"
  write_options '{"migration": {"source": "import_folder"}}'
  storage::prepare
  migration::run > /dev/null
  assert_file "$NPMPLUS_DATABASE" "database imported from the import folder"
}

migration_reads_a_database_in_use() {
  local source="${SANDBOX}/app_configs/a0d7b954_nginxproxymanager"
  make_community_source "$source"
  # A writer that has not committed yet, like an old app that is still running.
  python3 - "${source}/database.sqlite" <<'PYTHON' &
import sqlite3, sys, time
database = sqlite3.connect(sys.argv[1])
database.execute("BEGIN IMMEDIATE")
database.execute("INSERT INTO user (email) VALUES ('uncommitted@example.org')")
time.sleep(4)
PYTHON
  local writer=$!
  sleep 1
  write_options '{"migration": {"source": "community_app"}}'
  storage::prepare
  migration::run > /dev/null
  wait "$writer"
  assert_file "$NPMPLUS_DATABASE" "a locked database is still readable"
}

# ---- ingress -----------------------------------------------------------------------------------

ingress_config_is_valid_nginx() {
  write_options '{}'
  ingress::install > /dev/null
  local config="${SANDBOX}/nginx-conf.d/ingress.conf"
  assert_file "$config" "config written"
  [[ $(cat "$config") != *@*@* ]] || fail "all placeholders are replaced"
  assert_contains "$(cat "$config")" "listen 5594 default_server;" "ingress port"

  mkdir -p "${SANDBOX}/nginx"
  cat > "${SANDBOX}/nginx/nginx.conf" <<EOF
daemon off;
error_log stderr;
pid ${SANDBOX}/nginx/nginx.pid;
events {}
http {
  access_log off;
  include ${config};
}
EOF
  nginx -t -p "${SANDBOX}/nginx" -c "${SANDBOX}/nginx/nginx.conf" 2>&1 | grep -q "test is successful" \
    || fail "nginx rejects the ingress config"
}

ingress_serves_every_route_of_the_upstream_ui() {
  # The ingress server mirrors the locations of the UI virtual host. A new one upstream must fail here.
  write_options '{}'
  local rendered location missing=()
  rendered=$(ingress::render_config)
  while IFS= read -r location; do
    grep -qE "^[[:space:]]*location (= )?${location} " <<< "$rendered" || missing+=("$location")
  done < <(awk '$1 == "location" { print $2 }' "$UPSTREAM_UI_CONF")
  ((${#missing[@]} == 0)) || fail "the ingress server lacks the upstream UI routes: ${missing[*]}"
}

ingress_uses_the_socket_of_the_upstream_backend() {
  local socket
  socket=$(sed -n 's/^[[:space:]]*server \(unix:[^;]*\);.*/\1/p' "$UPSTREAM_UI_CONF" | head -n 1)
  assert_contains "$(cat "${INGRESS_SHARE_DIR}/nginx.conf.tpl")" "server ${socket};" "backend socket"
}

ingress_policies_follow_upstream_and_allow_the_frame() {
  write_options '{}'
  local rendered
  rendered=$(ingress::render_config)
  assert_contains "$rendered" "frame-ancestors 'self'" "Home Assistant may frame the page"
  [[ $rendered != *"frame-ancestors 'none'"* ]] || fail "the frame ban must be gone"
  [[ $rendered != *upgrade-insecure-requests* ]] || fail "plain HTTP must not be upgraded"
  assert_contains "$(ingress::policy /)" "sha256-" "the hashes of inline scripts come along"
}

ingress_template_typos_fail_loudly() {
  local status=0
  INGRESS_SHARE_DIR="${SANDBOX}/share"
  mkdir -p "$INGRESS_SHARE_DIR"
  echo 'listen @INGRES_PORT@;' > "${INGRESS_SHARE_DIR}/nginx.conf.tpl"
  (ingress::render_config > /dev/null 2>&1) || status=$?
  assert_equals 1 "$status" "an unknown placeholder stops the start"
}

# ---- image -------------------------------------------------------------------------------------

frontend_is_patched() {
  local bundle
  bundle=$(ls /app/frontend/assets/index-*.js)
  grep -q '__npmplusLocation||' "$bundle" || fail "router patch missing"
  grep -q 'prefers-color-scheme' "$bundle" && fail "dark default patch missing"
  return 0
}

frontend_is_precompressed() {
  local bundle
  bundle=$(ls /app/frontend/assets/index-*.js)
  [[ -s ${bundle}.gz && -s ${bundle}.br && -s ${bundle}.zst ]] || fail "the main bundle has no compressed variants"
  # The variants must carry the patched content, not the original one.
  gzip -dc "${bundle}.gz" | cmp -s - "$bundle" || fail "the gzip variant differs from the bundle"
  brotli -dc "${bundle}.br" | cmp -s - "$bundle" || fail "the brotli variant differs from the bundle"
  zstd -dcq "${bundle}.zst" | cmp -s - "$bundle" || fail "the zstd variant differs from the bundle"
  assert_no_file /app/frontend/index.html.gz "index.html must stay uncompressed for the ingress rewrite"
}

ingress_shim_is_valid_javascript() {
  node --check /usr/local/share/npmplus-app/ingress/assets/shim.js
}

# The image is put together from an upstream release and the shared base image. These programs
# fail first when the two drift apart, for example after a new Alpine release.
upstream_programs_run_on_the_base_image() {
  nginx -V 2>&1 | grep -q "http_v3_module" || fail "nginx does not start or lacks HTTP/3"
  nginx -V 2>&1 | grep -q "lua-nginx-module" || fail "nginx lacks the Lua module"
  certbot --version > /dev/null || fail "certbot does not run (is the Python of the venv still installed?)"
  node --version > /dev/null || fail "node does not run"
  (cd /app && node --input-type=module -e "await import('better-sqlite3')") || fail "the native sqlite module does not load"
  goaccess --version > /dev/null || fail "goaccess does not run"
  jq --version > /dev/null || fail "jq does not run"
}

# ---- run ---------------------------------------------------------------------------------------

scenario options_are_exported options_are_exported
scenario options_do_not_leak_into_the_log options_do_not_leak_into_the_log
scenario every_mapped_variable_exists_upstream every_mapped_variable_exists_upstream
scenario storage_links_user_folders storage_links_user_folders
scenario migration_is_off_by_default migration_is_off_by_default
scenario migration_imports_the_community_app migration_imports_the_community_app
scenario migration_finds_the_legacy_mount_point migration_finds_the_legacy_mount_point
scenario migration_skips_existing_data migration_skips_existing_data
scenario migration_refuses_databases_from_newer_releases migration_refuses_databases_from_newer_releases
scenario migration_reports_a_missing_source migration_reports_a_missing_source
scenario migration_imports_a_manual_folder migration_imports_a_manual_folder
scenario migration_reads_a_database_in_use migration_reads_a_database_in_use
scenario ingress_config_is_valid_nginx ingress_config_is_valid_nginx
scenario ingress_serves_every_route_of_the_upstream_ui ingress_serves_every_route_of_the_upstream_ui
scenario ingress_uses_the_socket_of_the_upstream_backend ingress_uses_the_socket_of_the_upstream_backend
scenario ingress_policies_follow_upstream_and_allow_the_frame ingress_policies_follow_upstream_and_allow_the_frame
scenario ingress_template_typos_fail_loudly ingress_template_typos_fail_loudly
scenario frontend_is_patched frontend_is_patched
scenario frontend_is_precompressed frontend_is_precompressed
scenario ingress_shim_is_valid_javascript ingress_shim_is_valid_javascript
scenario upstream_programs_run_on_the_base_image upstream_programs_run_on_the_base_image
