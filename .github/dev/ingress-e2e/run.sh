#!/usr/bin/env bash
# Builds the app, starts it next to a mock Home Assistant and runs the browser flow against the
# ingress. Needs Docker and Playwright (`require('playwright')` must resolve) and a root shell:
# the Supervisor's address is added to the loopback interface so the app accepts the mock.
#
# Usage: .github/dev/ingress-e2e/run.sh
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
APP_DIR="${HERE}/../../../npmplus"
IMAGE=npmplus-app:ingress-e2e
CONTAINER=npmplus-app-ingress-e2e
WORKDIR=$(mktemp -d)

cleanup() {
  docker rm -f "$CONTAINER" > /dev/null 2>&1 || true
  [[ -n ${MOCK_PID:-} ]] && kill "$MOCK_PID" 2> /dev/null || true
  rm -rf -- "$WORKDIR"
}
trap cleanup EXIT

# A proxy, if the build host needs one, is handed through for `apk add`.
docker build --network host --tag "$IMAGE" \
  ${HTTPS_PROXY:+--build-arg "HTTPS_PROXY=${HTTPS_PROXY}" --build-arg "HTTP_PROXY=${HTTPS_PROXY}"} "$APP_DIR"
docker run --rm --network host --cap-add NET_ADMIN --entrypoint ip "$IMAGE" \
  addr add 172.30.32.2/32 dev lo 2> /dev/null || true

# A fresh data folder with a stand-in ACME account (so no registration is attempted) and options
# that suit a test host: no ACME profile lookup, no IPv6.
mkdir -p "${WORKDIR}/data/tls/certbot/accounts/acme-v02.api.letsencrypt.org/directory/test" "${WORKDIR}/config"
echo '{}' > "${WORKDIR}/data/tls/certbot/accounts/acme-v02.api.letsencrypt.org/directory/test/regr.json"
echo '{"certificates": {"profile": "none"}, "network": {"disable_ipv6": true}, "migration": {"source": "none"}}' \
  > "${WORKDIR}/data/options.json"
docker run --detach --name "$CONTAINER" --network host --env TZ=UTC \
  --volume "${WORKDIR}/data:/data" --volume "${WORKDIR}/config:/config" "$IMAGE" > /dev/null

node "${HERE}/mock-home-assistant.mjs" &
MOCK_PID=$!

for _ in $(seq 1 90); do
  curl -fs --interface 172.30.32.2 http://127.0.0.1:5594/healthz > /dev/null 2>&1 && break
  sleep 1
done
curl -fs --interface 172.30.32.2 http://127.0.0.1:5594/healthz > /dev/null \
  || { docker logs "$CONTAINER" | tail -30; echo "The app did not become healthy" >&2; exit 1; }

(cd "$WORKDIR" && node "${HERE}/ingress-flow.cjs")
