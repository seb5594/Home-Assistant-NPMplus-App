#!/usr/bin/env bash
# Build-time compression of the admin UI files.
#
# nginx already serves .gz, .br and .zst files next to the originals as they are (gzip_static,
# brotli_static and zstd_static are on), but NPMplus ships none, so every request is compressed on
# the fly at a low level. Compressing once at the highest level makes the transfers smaller and
# the requests cheaper.
#
# index.html stays as it is: the ingress server rewrites it on its way out, which does not work on
# compressed content, and it is tiny.
set -Eeuo pipefail

UI_ROOT="${UI_ROOT:-/app/frontend}"
# Smaller files gain nothing from compression.
MINIMUM_SIZE=512

compress() {
  local file=$1
  gzip -9kf "$file"
  brotli --quality=11 --keep --force "$file"
  zstd --ultra -22 --keep --force --quiet "$file"
}

count=0
while IFS= read -r file; do
  compress "$file"
  count=$((count + 1))
done < <(find "$UI_ROOT" -type f \( -name '*.js' -o -name '*.css' -o -name '*.svg' -o -name '*.json' \) \
  -size +"${MINIMUM_SIZE}c" ! -name 'index.html')

echo "[INFO] Precompressed ${count} files below ${UI_ROOT}"
