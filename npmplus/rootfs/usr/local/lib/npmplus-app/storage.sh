# shellcheck shell=bash
# Storage layout. NPMplus keeps everything below /data, which Home Assistant hides from the user.
# A few folders people actually want to edit (custom nginx snippets, static web content) are
# therefore kept in the app's config folder and linked into /data.

DATA_DIR="${DATA_DIR:-/data}"
CONFIG_DIR="${CONFIG_DIR:-/config}"

# Folder names that exist in both places.
readonly USER_VISIBLE_DIRECTORIES=(custom_nginx html)

# Drop folder for the data of an old installation (see migration.sh); created so people find it.
readonly IMPORT_DIRECTORY=import

# Makes ${DATA_DIR}/<name> a link to ${CONFIG_DIR}/<name>. Content that already lives in the
# data folder (an earlier start, a restored backup) is moved over first and never overwritten.
storage::expose_directory() {
  local name=$1
  local visible="${CONFIG_DIR}/${name}"
  local internal="${DATA_DIR}/${name}"

  mkdir -p "$visible"
  if [[ -d $internal && ! -L $internal ]]; then
    cp -an "${internal}/." "${visible}/"
    rm -rf "$internal"
  fi
  ln -sfn "$visible" "$internal"
}

storage::prepare() {
  local name
  for name in "${USER_VISIBLE_DIRECTORIES[@]}"; do
    storage::expose_directory "$name"
  done
  mkdir -p "${CONFIG_DIR}/${IMPORT_DIRECTORY}"
}
