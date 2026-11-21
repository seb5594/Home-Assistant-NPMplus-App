# shellcheck shell=bash
# Home Assistant ingress support.
#
# The NPMplus admin UI cannot be embedded as it is: it only answers over TLS, forbids framing and
# assumes it lives at the root of its host. Ingress proxies it below /api/hassio_ingress/<token>/
# over plain HTTP inside an iframe. This module adds a small nginx server (inside the nginx NPMplus
# already runs, so there is no second process) that
#   * accepts plain HTTP from the ingress gateway only,
#   * forwards to the UI over TLS and relaxes the framing headers,
#   * serves a browser shim that teaches the UI about the ingress path and adds the app footer.

INGRESS_PORT="${INGRESS_PORT:-5594}"
INGRESS_SHARE_DIR="${INGRESS_SHARE_DIR:-/usr/local/share/npmplus-app/ingress}"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/usr/local/nginx/conf/conf.d}"

# Renders the nginx template; every @NAME@ placeholder must be known, so typos fail loudly.
ingress::render_config() {
  local template="${INGRESS_SHARE_DIR}/nginx.conf.tpl"
  local rendered

  rendered=$(sed \
    -e "s|@INGRESS_PORT@|${INGRESS_PORT}|g" \
    -e "s|@UI_PORT@|${NPM_PORT:-81}|g" \
    -e "s|@SHARE_DIR@|${INGRESS_SHARE_DIR}|g" \
    -e "s|@APP_VERSION@|${NPMPLUS_APP_VERSION:-dev}|g" \
    -e "s|@SUPPORT_FOOTER@|$(ingress::support_footer_flag)|g" \
    "$template")

  if grep -q '@[A-Z_]*@' <<< "$rendered"; then
    log::fatal "Unresolved placeholder in ${template}"
  fi
  printf '%s\n' "$rendered"
}

# The footer is on unless the user switched it off.
ingress::support_footer_flag() {
  if [[ $(options::get interface.support_footer) == false ]]; then
    printf 'false'
  else
    printf 'true'
  fi
}

ingress::install() {
  mkdir -p "$NGINX_CONF_DIR"
  ingress::render_config > "${NGINX_CONF_DIR}/ingress.conf"
  log::info "Ingress listens on port ${INGRESS_PORT}"
}
