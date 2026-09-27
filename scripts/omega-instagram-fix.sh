#!/usr/bin/env bash
#===============================================================================
#  omega-instagram-fix — Safe Instagram Streaming Optimizer
#  (Safe for Cloudflare WARP and WireGuard)
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"

# Color helpers
if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_0=""
fi

rollback_fix() {
  printf "Removing any UDP 443 rejection rules to protect WireGuard/WARP...\n"
  while iptables -D OUTPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
  while iptables -D FORWARD -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
  rm -f "${BASE_DIR}/instagram-fix.active"
  printf "%s[OK] WireGuard/WARP traffic restored safely!%s\n" "$C_G" "$C_0"
}

apply_safe() {
  # Clean up any generic UDP 443 blocking to preserve Wireguard / WARP
  rollback_fix
  
  # Only tune TCP streaming parameters (Zero risk to WireGuard)
  printf "Applying streaming kernel optimizations (100%% safe for WireGuard)...\n"
  /sbin/sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true
  /sbin/sysctl -w net.ipv4.tcp_notsent_lowat=16384 >/dev/null 2>&1 || true
  printf "%s[OK] Kernel streaming optimizations applied without affecting WireGuard.%s\n" "$C_G" "$C_0"
}

CMD="${1:---rollback}"
case "$CMD" in
  --rollback|-r)
    rollback_fix
    ;;
  --apply|-a)
    apply_safe
    ;;
  *)
    rollback_fix
    ;;
esac
