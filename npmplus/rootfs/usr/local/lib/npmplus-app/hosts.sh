# shellcheck shell=bash
# Name resolution. The app shares the network of the host, so `hostname` is the name the user gave
# the machine under Settings > System > Network. Proxy hosts may target that name instead of an
# address; it is answered with the loopback address, which keeps the traffic on the machine.

HOSTS_FILE="${HOSTS_FILE:-/etc/hosts}"

# Suffix of the name that mDNS announces for the machine on the LAN.
readonly MDNS_SUFFIX=local

# Succeeds when the hosts file already maps the name to 127.0.0.1.
hosts::is_mapped_to_loopback() {
  local name=$1
  awk -v name="$name" '$1 == "127.0.0.1" { for (i = 2; i <= NF; i++) if ($i == name) found = 1 } END { exit !found }' "$HOSTS_FILE"
}

# Lets the name of the machine (and its mDNS variant) resolve to 127.0.0.1.
hosts::map_hostname_to_loopback() {
  local name
  name=$(hostname -s)
  [[ -n $name ]] || return 0

  local candidate missing=()
  for candidate in "$name" "${name}.${MDNS_SUFFIX}"; do
    hosts::is_mapped_to_loopback "$candidate" || missing+=("$candidate")
  done
  [[ ${#missing[@]} -gt 0 ]] || return 0

  # The line goes first, because the resolver returns the addresses in the order of the file. The
  # file is rewritten in place: Docker mounts it into the container, so it cannot be replaced.
  local current
  current=$(cat "$HOSTS_FILE")
  if printf '127.0.0.1 %s\n%s\n' "${missing[*]}" "$current" > "$HOSTS_FILE"; then
    log::info "The host name ${name} now resolves to 127.0.0.1"
  else
    log::warn "Could not write ${HOSTS_FILE}; proxy hosts have to target 127.0.0.1"
  fi
}
