#!/usr/bin/env bash
# Start script of the NPMplus app. It translates the Home Assistant configuration into what
# NPMplus expects and then hands over to the startup sequence of the upstream image.
# shellcheck source-path=SCRIPTDIR/rootfs/usr/local/lib/npmplus-app
set -Eeuo pipefail

LIB_DIR="${NPMPLUS_APP_LIB:-/usr/local/lib/npmplus-app}"

# shellcheck source=log.sh
source "${LIB_DIR}/log.sh"
# shellcheck source=options.sh
source "${LIB_DIR}/options.sh"
# shellcheck source=storage.sh
source "${LIB_DIR}/storage.sh"
# shellcheck source=migration.sh
source "${LIB_DIR}/migration.sh"
# shellcheck source=ingress.sh
source "${LIB_DIR}/ingress.sh"

main() {
  options::export_environment
  storage::prepare
  migration::run
  ingress::install

  log::info "Handing over to NPMplus"
  exec /usr/local/bin/entrypoint.sh
}

# Run only when executed; sourcing the file lets tests call the functions directly.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
