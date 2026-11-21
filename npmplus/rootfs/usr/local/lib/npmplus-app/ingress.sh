# shellcheck shell=bash
# Home Assistant ingress support.
#
# The NPMplus admin UI cannot be embedded as it is: it only answers over TLS, forbids framing and
# assumes it lives at the root of its host. Ingress proxies it below /api/hassio_ingress/<token>/
# over plain HTTP inside an iframe. This module adds a small server block to the nginx NPMplus
# already runs (so there is no second process) that
#   * accepts plain HTTP from the ingress gateway only,
#   * serves the UI files itself and passes /api to the backend's unix socket, like the UI virtual
#     host of NPMplus does, but without TLS and with headers that allow the frame,
#   * serves a browser shim that teaches the UI about the ingress path and adds the app footer.

INGRESS_PORT="${INGRESS_PORT:-5594}"
INGRESS_SHARE_DIR="${INGRESS_SHARE_DIR:-/usr/local/share/npmplus-app/ingress}"
NGINX_CONF_DIR="${NGINX_CONF_DIR:-/usr/local/nginx/conf/conf.d}"
UI_ROOT="${UI_ROOT:-/app/frontend}"
# The UI virtual host of NPMplus. Its security policies are the source of ours.
UPSTREAM_UI_CONF="${UPSTREAM_UI_CONF:-/usr/local/nginx/conf/conf.d/npmplus.conf}"

# Prints the content security policy the UI virtual host sends for a location, adjusted for
# ingress: Home Assistant may frame the page, and plain HTTP must not be upgraded to HTTPS
# (Home Assistant itself is often served over HTTP). Taking it from NPMplus keeps the hashes of
# inline scripts and styles right after every update.
ingress::policy() {
  local location=$1 policy
  policy=$(awk -v location="$location" '
      $1 == "location" && $2 == location { inside = 1 }
      inside && /Content-Security-Policy:/ { print; exit }' "$UPSTREAM_UI_CONF" \
    | sed -E 's/.*Content-Security-Policy: ([^"]*)".*/\1/' \
    | sed -e "s/frame-ancestors 'none'/frame-ancestors 'self'/" -e 's/ *upgrade-insecure-requests;//')

  [[ -n $policy ]] || log::fatal "No content security policy for ${location} found in ${UPSTREAM_UI_CONF}"
  printf '%s' "$policy"
}

# The footer is on unless the user switched it off.
ingress::support_footer_flag() {
  if [[ $(options::get interface.support_footer) == false ]]; then
    printf 'false'
  else
    printf 'true'
  fi
}

# Renders the nginx template; every @NAME@ placeholder must be known, so typos fail loudly.
ingress::render_config() {
  local template="${INGRESS_SHARE_DIR}/nginx.conf.tpl"
  local rendered

  rendered=$(sed \
    -e "s|@INGRESS_PORT@|${INGRESS_PORT}|g" \
    -e "s|@SHARE_DIR@|${INGRESS_SHARE_DIR}|g" \
    -e "s|@UI_ROOT@|${UI_ROOT}|g" \
    -e "s|@APP_VERSION@|${NPMPLUS_APP_VERSION:-dev}|g" \
    -e "s|@SUPPORT_FOOTER@|$(ingress::support_footer_flag)|g" \
    -e "s|@CSP_ROOT@|$(ingress::policy /)|g" \
    -e "s|@CSP_API@|$(ingress::policy /api)|g" \
    -e "s|@CSP_DOCS@|$(ingress::policy /api/docs)|g" \
    -e "s|@CSP_GRAVATAR@|$(ingress::policy /images/gravatar/)|g" \
    "$template")

  if grep -q '@[A-Z_]*@' <<< "$rendered"; then
    log::fatal "Unresolved placeholder in ${template}"
  fi
  printf '%s\n' "$rendered"
}

ingress::install() {
  mkdir -p "$NGINX_CONF_DIR"
  ingress::render_config > "${NGINX_CONF_DIR}/ingress.conf"
  log::info "Ingress listens on port ${INGRESS_PORT}"
}
