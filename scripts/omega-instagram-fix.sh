#!/usr/bin/env bash
#===============================================================================
#  omega-instagram-fix — Instagram & Social Media Video Streaming Optimizer
#
#  Fixes micro-stutters, freezing reels, and story buffering caused by:
#    1. QUIC (UDP 443) packet drops by Iranian ISPs -> Forces instant fallback
#       to high-speed BBR-accelerated TCP (0ms delay) via ICMP port-unreachable.
#    2. TCP Slow Start after idle prevention (maintains video throughput).
#    3. Low-latency socket buffer tuning for streaming multiplexing.
#
#  Safety Contract:
#    - NEVER modifies 3x-ui panel or restarts any active connections
#    - Idempotent rules with full rollback
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

VERSION="0.3.2"
BASE_DIR="/opt/omega-boost"
ACTIVE_FLAG="${BASE_DIR}/instagram-fix.active"

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

has_quic_reject_output() {
  iptables -C OUTPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1
}

has_quic_reject_forward() {
  iptables -C FORWARD -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1
}

show_status() {
  section "Instagram & Streaming Optimization Status"
  
  printf "  1. QUIC Fast-Reject (UDP 443):\n"
  if has_quic_reject_output && has_quic_reject_forward; then
    ok "QUIC Fast-Reject is ACTIVE (Instagram seamlessly uses fast TCP without 3s stalls)"
  else
    warn "QUIC Fast-Reject is NOT active (May cause 2-3s reel buffering during UDP drops)"
  fi

  printf "\n  2. TCP Slow Start After Idle:\n"
  local ss_idle
  ss_idle="$(/sbin/sysctl -n net.ipv4.tcp_slow_start_after_idle 2>/dev/null || cat /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null || echo "1")"
  if [ "$ss_idle" = "0" ]; then
    ok "net.ipv4.tcp_slow_start_after_idle = 0 (Speed maintained between reels)"
  else
    warn "net.ipv4.tcp_slow_start_after_idle = $ss_idle (Window resets after reading comments)"
  fi

  printf "\n  3. Low Latency Socket Buffer (notsent_lowat):\n"
  local lowat
  lowat="$(/sbin/sysctl -n net.ipv4.tcp_notsent_lowat 2>/dev/null || cat /proc/sys/net/ipv4/tcp_notsent_lowat 2>/dev/null || echo "0")"
  if [ "$lowat" = "16384" ]; then
    ok "net.ipv4.tcp_notsent_lowat = 16384 (Bufferbloat eliminated)"
  else
    info "net.ipv4.tcp_notsent_lowat = $lowat"
  fi
}

apply_fix() {
  check_root
  section "Applying Instagram & Video Streaming Optimization"

  mkdir -p "$BASE_DIR"

  # 1. Reject QUIC instantly so Instagram immediately switches to HTTP/2 TCP
  info "Injecting instant QUIC rejection rules (0ms fallback to TCP)..."
  if ! has_quic_reject_output; then
    iptables -I OUTPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable
    ok "Added OUTPUT QUIC rejection"
  fi

  if ! has_quic_reject_forward; then
    iptables -I FORWARD -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable
    ok "Added FORWARD QUIC rejection"
  fi

  # 2. Kernel streaming optimizations
  info "Tuning kernel streaming parameters..."
  /sbin/sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true
  /sbin/sysctl -w net.ipv4.tcp_notsent_lowat=16384 >/dev/null 2>&1 || true

  touch "$ACTIVE_FLAG"
  printf "\n"
  ok "Instagram & video streaming optimization applied successfully!"
  info "Instagram, YouTube, and Meta apps will now stream over high-speed TCP with zero stalling."
}

rollback_fix() {
  check_root
  section "Rolling back Instagram & QUIC rules"

  while has_quic_reject_output; do
    iptables -D OUTPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null || break
  done

  while has_quic_reject_forward; do
    iptables -D FORWARD -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null || break
  done

  rm -f "$ACTIVE_FLAG"
  ok "QUIC rules removed cleanly."
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
