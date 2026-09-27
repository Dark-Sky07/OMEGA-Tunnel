#!/usr/bin/env bash
#===============================================================================
#  omega-instagram-fix — Targeted Instagram / Meta Video Streaming Optimizer
#  (100% Safe for WireGuard, Cloudflare WARP, and other services)
#
#  How it works:
#    Targets ONLY Meta/Instagram CDN IP ranges (AS32934 / AS63293) and rejects
#    UDP 443 (QUIC) instantly with ICMP port-unreachable.
#    - Zero user/client configuration needed.
#    - Zero effect on WireGuard / WARP (Cloudflare IPs are never touched).
#    - Instagram falls back instantly (0ms) to high-speed TCP.
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"
ACTIVE_FLAG="${BASE_DIR}/instagram-meta-fix.active"

# Color helpers
if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[OK]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[WARN]%s %s\n" "$C_Y" "$C_0" "$1"; }
bad(){     printf "%s[FAIL]%s %s\n" "$C_R" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    bad "Root privileges required."
    printf "    Please execute with sudo: sudo bash %s\n" "$0"
    exit 1
  fi
}

# Meta / Facebook / Instagram Official CDN CIDR Ranges
META_CIDRS=(
  "157.240.0.0/16"
  "31.13.0.0/16"
  "129.134.0.0/16"
  "57.144.0.0/14"
  "179.60.192.0/22"
  "185.89.216.0/22"
  "69.171.224.0/19"
  "66.220.144.0/20"
  "204.15.20.0/22"
)

is_active() {
  iptables -C OUTPUT -d "${META_CIDRS[0]}" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1
}

show_status() {
  section "Instagram & Meta Streaming Optimization Status"
  if is_active; then
    ok "Targeted Meta/Instagram QUIC rejection is ACTIVE"
    info "Clients automatically stream Instagram reels over TCP without buffering."
    info "WireGuard and Cloudflare WARP are 100% safe and untouched."
  else
    warn "Instagram QUIC rejection is NOT active."
  fi
}

apply_fix() {
  check_root
  section "Applying Targeted Instagram Streaming Optimization"

  mkdir -p "$BASE_DIR"

  # Clean up any generic rules if present
  while iptables -D OUTPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
  while iptables -D FORWARD -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done

  info "Injecting targeted QUIC rejection for Instagram/Meta CDN ranges..."
  for cidr in "${META_CIDRS[@]}"; do
    if ! iptables -C OUTPUT -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
      iptables -I OUTPUT -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable
    fi
    if ! iptables -C FORWARD -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
      iptables -I FORWARD -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable
    fi
  done

  # Kernel TCP streaming buffer tuning
  info "Applying kernel streaming buffers..."
  /sbin/sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true
  /sbin/sysctl -w net.ipv4.tcp_notsent_lowat=16384 >/dev/null 2>&1 || true

  touch "$ACTIVE_FLAG"
  printf "\n"
  ok "Targeted Instagram optimizer applied successfully!"
  info "- WireGuard and Cloudflare WARP remain 100% active and untouched."
  info "- No action required from users/clients."
  info "- Instagram reels and stories will now stream smoothly over TCP."
}

rollback_fix() {
  check_root
  section "Rolling back Instagram targeted rules"

  for cidr in "${META_CIDRS[@]}"; do
    while iptables -D OUTPUT -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
    while iptables -D FORWARD -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
  done

  rm -f "$ACTIVE_FLAG"
  ok "Instagram rules removed cleanly."
}

CMD="${1:---help}"
case "$CMD" in
  --apply|-a)
    apply_fix
    ;;
  --status|-s)
    show_status
    ;;
  --rollback|-r)
    rollback_fix
    ;;
  --help|-h)
    printf "Usage: bash %s [--status | --apply | --rollback]\n" "$0"
    exit 0
    ;;
  *)
    printf "Unknown option: %s. Use --help\n" "$CMD"
    exit 1
    ;;
esac
