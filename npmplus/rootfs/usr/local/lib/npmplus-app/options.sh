# shellcheck shell=bash
# Translates the Home Assistant app options into the environment variables NPMplus reads.
#
# The translation table lives in option-env.map. Adding an option therefore means one line in
# config.yaml, one in that map and one in the translations; no shell code changes.

OPTIONS_FILE="${OPTIONS_FILE:-/data/options.json}"
OPTION_ENV_MAP="${OPTION_ENV_MAP:-/usr/local/share/npmplus-app/option-env.map}"
OPTION_ENV_PROGRAM="${OPTION_ENV_PROGRAM:-/usr/local/share/npmplus-app/options-to-environment.jq}"

# Reads a single option by its dotted path ("migration.source"); prints nothing when it is unset.
options::get() {
  jq --raw-output --arg path "$1" \
    'getpath($path | split(".")) | select(. != null) | tostring' "$OPTIONS_FILE"
}

# Exports every mapped option that has a value and logs how many there were (never the values).
options::export_environment() {
  local name value count=0

  [[ -f $OPTIONS_FILE ]] || log::fatal "Options file ${OPTIONS_FILE} not found"

  while IFS='=' read -r -d '' name value; do
    export "${name}=${value}"
    count=$((count + 1))
  done < <(jq --join-output --rawfile map "$OPTION_ENV_MAP" --from-file "$OPTION_ENV_PROGRAM" "$OPTIONS_FILE")

  options::export_extra_environment
  log::info "Applied ${count} configured option(s)"
}

# `advanced.extra_environment` is the escape hatch for upstream variables that have no dedicated
# option yet. Entries look like NAME=value and win over the options above.
options::export_extra_environment() {
  local entry name value
  while IFS= read -r entry; do
    [[ -n $entry ]] || continue
    name=${entry%%=*}
    value=${entry#*=}
    export "${name}=${value}"
    log::info "Extra environment variable set: ${name}"
  done < <(jq --raw-output '.advanced.extra_environment // [] | .[]' "$OPTIONS_FILE")
}
