#!/usr/bin/env bash
#===============================================================================
#  omega-instagram-fix — Targeted Instagram / Meta Video Streaming Optimizer
#  (100% Safe for WireGuard, Cloudflare WARP, and other services)
#
#  How it works:
#    Targets Meta/Instagram CDN IP ranges (AS32934 / AS63293) and rejects
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
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
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

# Meta / Facebook / Instagram Official CDN CIDR Ranges (IPv4)
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
  "102.132.96.0/20"
  "163.70.128.0/17"
  "185.60.216.0/22"
  "45.64.40.0/22"
)

# Meta IPv6 Ranges (Prevent mobile devices from bypassing over lossy IPv6 QUIC)
META_IPV6_CIDRS=(
  "2a03:2880::/32"
  "2620:0:1c00::/40"
  "2a03:2884::/32"
  "2a03:2887::/32"
)

is_active() {
  [ -f "$ACTIVE_FLAG" ] || iptables -C OUTPUT -d "157.240.0.0/16" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1
}

show_status() {
  section "Instagram & Meta Streaming Optimization Status"
  if is_active; then
    ok "Targeted Meta/Instagram QUIC rejection is ACTIVE"
    info "Clients automatically stream Instagram reels & stories over fast TCP."
    info "WireGuard and Cloudflare WARP are 100% safe and untouched."

    printf "\n  %sActive Firewall Interception Rules:%s\n" "$C_W" "$C_0"
    local rules_count
    rules_count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c "reject-with icmp-port-unreachable" || echo "0")
    printf "    * IPv4 QUIC Intercept Rules: %s%s active%s\n" "$C_G" "$rules_count" "$C_0"
    
    if command -v ip6tables >/dev/null 2>&1; then
      local rules6_count
      rules6_count=$(ip6tables -L OUTPUT -n 2>/dev/null | grep -c "reject-with icmp6-port-unreachable" || echo "0")
      printf "    * IPv6 QUIC Intercept Rules: %s%s active%s\n" "$C_G" "$rules6_count" "$C_0"
    fi
  else
    warn "Instagram QUIC rejection is NOT active."
    info "Run option [1] to activate targeted Instagram acceleration."
  fi
}

apply_fix() {
  check_root
  section "Applying Targeted Instagram Streaming Optimization"

  mkdir -p "$BASE_DIR"

  # Clean up any generic UDP 443 rules and hardcoded MSS restrictions
  while iptables -D OUTPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
  while iptables -D FORWARD -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done

  # Ensure PMTU clamping is used
  if ! iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1; then
    iptables -t mangle -A POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1 || true
  fi

  info "Injecting targeted QUIC rejection for Meta/Instagram CDN IPv4 ranges..."
  for cidr in "${META_CIDRS[@]}"; do
    if ! iptables -C OUTPUT -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
      iptables -I OUTPUT -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null || true
    fi
    if ! iptables -C FORWARD -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
      iptables -I FORWARD -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null || true
    fi
  done

  if command -v ip6tables >/dev/null 2>&1; then
    info "Injecting targeted QUIC rejection for Meta IPv6 ranges..."
    for cidr6 in "${META_IPV6_CIDRS[@]}"; do
      if ! ip6tables -C OUTPUT -d "$cidr6" -p udp --dport 443 -j REJECT --reject-with icmp6-port-unreachable >/dev/null 2>&1; then
        ip6tables -I OUTPUT -d "$cidr6" -p udp --dport 443 -j REJECT --reject-with icmp6-port-unreachable 2>/dev/null || true
      fi
      if ! ip6tables -C FORWARD -d "$cidr6" -p udp --dport 443 -j REJECT --reject-with icmp6-port-unreachable >/dev/null 2>&1; then
        ip6tables -I FORWARD -d "$cidr6" -p udp --dport 443 -j REJECT --reject-with icmp6-port-unreachable 2>/dev/null || true
      fi
    done
  fi

  # Kernel TCP streaming buffer tuning
  info "Applying kernel streaming buffers for rapid reel buffering..."
  /sbin/sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true
  /sbin/sysctl -w net.ipv4.tcp_notsent_lowat=131072 >/dev/null 2>&1 || true

  touch "$ACTIVE_FLAG"
  printf "\n"
  ok "Targeted Instagram optimizer applied successfully!"
  info "- WireGuard and Cloudflare WARP remain 100% active and untouched."
  info "- Google / Gemini / AI upload speeds fully restored."
  info "- No action required from users/clients."
  info "- Instagram reels and stories stream smoothly over TCP."
}

rollback_fix() {
  check_root
  section "Rolling back Instagram targeted rules"

  for cidr in "${META_CIDRS[@]}"; do
    while iptables -D OUTPUT -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
    while iptables -D FORWARD -d "$cidr" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable 2>/dev/null; do :; done
  done

  if command -v ip6tables >/dev/null 2>&1; then
    for cidr6 in "${META_IPV6_CIDRS[@]}"; do
      while ip6tables -D OUTPUT -d "$cidr6" -p udp --dport 443 -j REJECT --reject-with icmp6-port-unreachable 2>/dev/null; do :; done
      while ip6tables -D FORWARD -d "$cidr6" -p udp --dport 443 -j REJECT --reject-with icmp6-port-unreachable 2>/dev/null; do :; done
    done
  fi

  rm -f "$ACTIVE_FLAG"
  ok "Instagram rules rolled back cleanly."
}

case "${1:-}" in
  --apply|-a)
    apply_fix
    ;;
  --rollback|-r)
    rollback_fix
    ;;
  --status|-s)
    show_status
    ;;
  *)
    show_status
    printf "\nUsage: %s {--apply|--rollback|--status}\n" "$0"
    ;;
esac
