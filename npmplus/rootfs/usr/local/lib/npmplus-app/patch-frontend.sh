#!/usr/bin/env bash
# Build-time adjustments of the NPMplus admin UI bundle.
#
# The UI is shipped as one minified bundle, so the two changes below are textual and anchored on
# code that exists exactly once. Each patch is verified; when an upstream update moves the code,
# the image build fails instead of silently shipping an unpatched UI.
set -Eeuo pipefail

BUNDLE_GLOB="${BUNDLE_GLOB:-/app/frontend/assets/index-*.js}"

# shellcheck disable=SC2086 # the glob is meant to expand to the single entry bundle
bundle() {
  ls $BUNDLE_GLOB
}

# Applies a sed expression to the bundle and requires `marker` to occur exactly `expected` times
# afterwards.
patch() {
  local description=$1 expression=$2 marker=$3 expected=$4 file found
  file=$(bundle)
  sed -i "$expression" "$file"
  found=$({ grep -o -F -- "$marker" "$file" || true; } | wc -l)
  if [[ $found -ne $expected ]]; then
    echo "[ERROR] Patch '${description}' found ${found} place(s) in ${file}, expected ${expected}." >&2
    echo "[ERROR] The upstream bundle changed; adjust patch-frontend.sh." >&2
    exit 1
  fi
  echo "[INFO] Patched: ${description}"
}

# The router builds its location from window.location, which is wrong below the ingress path.
# It reads window.__npmplusLocation first (provided by the ingress shim, see ingress/assets/shim.js)
# and falls back to window.location, so opening the UI directly keeps working.
patch "router location for ingress" \
  's/\({pathname:[A-Za-z_$]*,search:[A-Za-z_$]*,hash:[A-Za-z_$]*}=[A-Za-z_$]*||\)\([A-Za-z_$]*\)\.location/\1(\2.__npmplusLocation||\2.location)/' \
  '__npmplusLocation||' 1

# Start in dark mode. A theme the user picked is stored by the UI and still wins.
# shellcheck disable=SC2016 # backticks belong to the JavaScript being patched
patch "dark theme as default" \
  's/window\.matchMedia(`(prefers-color-scheme: dark)`)\.matches/true/' \
  'prefers-color-scheme' 0
