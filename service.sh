#!/bin/bash
# Installed root-owned; accepts only fixed modes and validated IPv4 arguments.
set -u
export LC_ALL=C
REQUEST="$1"
SERVICE="$2"
valid_ipv4() {
  local address="$1" octet
  [[ "$address" =~ ^(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})\.(0|[1-9][0-9]{0,2})$ ]] || return 1
  local IFS=.
  for octet in $address; do
    (( 10#$octet <= 255 )) || return 1
  done
}
while true; do
  mode= timestamp= ip= mask= router= extra=
  if [[ -f "$REQUEST" ]]; then
    IFS=' ' read -r mode timestamp ip mask router extra < "$REQUEST" || true
    case "$timestamp" in
      ''|*[!0-9]*) timestamp=0 ;;
    esac
    # Reject oversized values before shell arithmetic, and ignore stale requests.
    if [[ ${#timestamp} -le 11 && -z "$extra" ]]; then
      now=$(/bin/date +%s)
      age=$((now - 10#$timestamp))
      if (( age >= 0 && age <= 15 )); then
        info=$(/usr/sbin/networksetup -getinfo "$SERVICE" 2>/dev/null) || info=''
        case "$mode" in
          manual)
            if valid_ipv4 "$ip" && valid_ipv4 "$mask" && valid_ipv4 "$router"; then
              if ! [[ "$info" == *"Manual Configuration"* && "$info" == *"IP address: $ip"$'\n'* && "$info" == *"Subnet mask: $mask"$'\n'* && "$info" == *"Router: $router"$'\n'* ]]; then
                /usr/sbin/networksetup -setmanual "$SERVICE" "$ip" "$mask" "$router"
              fi
            fi
            ;;
          dhcp)
            if [[ -z "$ip$mask$router" && "$info" != *"DHCP Configuration"* ]]; then
              /usr/sbin/networksetup -setdhcp "$SERVICE"
            fi
            ;;
        esac
      fi
    fi
  fi
  /bin/sleep 5
done
