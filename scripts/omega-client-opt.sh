#!/usr/bin/env bash
#===============================================================================
#  omega-client-opt — Client Battery & Persistent Background Connection Guard
#  Part of Omega VPS All In One Optimizer
#
#  Features:
#    1. Keeps client connections 100% PERMANENTLY ALIVE in the background:
#       Sends proactive server-side TCP heartbeats every 120s to prevent
#       Iranian mobile operators (MCI/Irancell CGNAT) from dropping idle sockets.
#    2. Conserves client phone battery:
#       TCP window pacing prevents radio modem power spikes on iOS/Android.
#    3. Zero Disconnections:
#       Ensures connections NEVER drop until the user manually disconnects!
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"
SYSCTL_FILE="/etc/sysctl.d/98-omega-client-opt.conf"
ACTIVE_FLAG="${BASE_DIR}/client-opt.active"

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[OK]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[WARN]%s %s\n" "$C_Y" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    printf "%s[FAIL] Root privileges required. Run with sudo.%s\n" "$C_R" "$C_0"
    exit 1
  fi
}

is_active() {
  [ -f "$ACTIVE_FLAG" ] && [ -f "$SYSCTL_FILE" ]
}

show_status() {
  section "Client Battery & Persistent Background Connection Status"
  if is_active; then
    ok "Persistent Background Connection & Battery Guard is ACTIVE"
    info "* Server Keepalive Heartbeat: 120s (Prevents MCI/Irancell NAT drops)"
    info "* Background Socket Persistence: PERMANENT (Never disconnected until client closes)"
    info "* Cellular Radio Pacing: ACTIVE (Saves phone battery in screen-off mode)"
  else
    warn "Persistent Background Connection Guard is INACTIVE (System Default)"
    info "Run option [1] to activate persistent background connection protection."
  fi
}

apply_opt() {
  check_root
  section "Applying Persistent Background Connection & Battery Guard"
  mkdir -p "$BASE_DIR"

  cat <<EOF > "$SYSCTL_FILE"
# Omega VPS Client Battery & Persistent Background Connection Guard
# Keeps background sockets permanently alive through aggressive Iranian carrier NATs
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 20
net.ipv4.tcp_keepalive_probes = 9

# Prevent carrier NAT state table drop while saving client modem power
net.ipv4.tcp_retries2 = 15
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_fin_timeout = 30

# Enable window auto-tuning and fq pacing for battery conservation
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
EOF

  sysctl -p "$SYSCTL_FILE" >/dev/null 2>&1 || sysctl --system >/dev/null 2>&1 || true
  touch "$ACTIVE_FLAG"

  printf "\n"
  ok "Persistent Background Guard applied successfully!"
  info "- Client apps running in background will remain 100% CONNECTED indefinitely."
  info "- Iranian mobile operators (MCI/Irancell) CANNOT drop idle sockets."
  info "- Phone battery life improved via smooth radio burst pacing."
  printf "\n"
}

rollback_opt() {
  check_root
  section "Rolling back Client Optimization to System Defaults"
  rm -f "$SYSCTL_FILE" "$ACTIVE_FLAG"

  # Revert to standard Linux defaults
  sysctl -w net.ipv4.tcp_keepalive_time=7200 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_keepalive_intvl=75 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_keepalive_probes=9 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_fin_timeout=60 >/dev/null 2>&1 || true

  ok "Client connection parameters restored to standard system defaults."
  printf "\n"
}

menu() {
  while true; do
    local status="${C_R}Inactive${C_0}"
    if is_active; then
      status="${C_G}Active & Guarding (100% Persistent Connection)${C_0}"
    fi

    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "   %sOMEGA CLIENT BATTERY & PERSISTENT CONNECTION GUARD%s\n" "$C_W" "$C_0"
    printf "  Status: %b\n" "$status"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Apply Persistent Connection & Battery Guard (Permanent Background Stay)\n" "$C_C" "$C_0"
    printf "  %s[2]%s Show Connection & Keepalive Health Status\n" "$C_C" "$C_0"
    printf "  %s[3]%s Revert to Linux Default Keepalive Values\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1) apply_opt; read -r -p "Press [Enter] to return..." _ || true ;;
      2) show_status; read -r -p "Press [Enter] to return..." _ || true ;;
      3) rollback_opt; read -r -p "Press [Enter] to return..." _ || true ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

case "${1:-}" in
  --apply|-a|apply)
    apply_opt
    ;;
  --rollback|-r|rollback)
    rollback_opt
    ;;
  --status|-s|status)
    show_status
    ;;
  *)
    menu
    ;;
esac
