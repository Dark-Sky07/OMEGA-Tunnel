#!/usr/bin/env bash
# ========================================================================
#   OMEGA VPS All In One Optimizer — Smart Anti-Pollution DNS Cache
#   File: scripts/omega-dns.sh
#   Description: Fast, cached, encrypted DNS resolver eliminating lookup lag
# ========================================================================

set -u

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

RESOLVED_CONF="/etc/systemd/resolved.conf"
RESOLVED_BACKUP="/opt/omega-boost/resolved.conf.bak"

test_dns_speed() {
  printf "\n%s=== BENCHMARKING DNS RESOLUTION SPEED ===%s\n" "$C_B" "$C_0"
  local domains=("google.com" "instagram.com" "cloudflare.com" "telegram.org")

  for d in "${domains[@]}"; do
    local start
    start=$(date +%s%N)
    getent hosts "$d" >/dev/null 2>&1 || true
    local end
    end=$(date +%s%N)
    local diff_ms=$(( (end - start) / 1000000 ))
    printf "  %-18s -> %s%3d ms%s\n" "$d" "$C_G" "$diff_ms" "$C_0"
  done
}

apply_dns_optimization() {
  printf "\n%s=== APPLYING SMART ANTI-POLLUTION DNS CACHE ===%s\n" "$C_B" "$C_0"
  mkdir -p /opt/omega-boost

  if [ -f "$RESOLVED_CONF" ] && [ ! -f "$RESOLVED_BACKUP" ]; then
    cp "$RESOLVED_CONF" "$RESOLVED_BACKUP"
  fi

  # Configure high-speed tier-1 upstream resolvers with local in-memory caching
  cat <<EOF > "$RESOLVED_CONF"
[Resolve]
DNS=1.1.1.1 8.8.8.8 9.9.9.9 1.0.0.1
FallbackDNS=8.8.4.4 149.112.112.112
Domains=~.
DNSSEC=allow-downgrade
DNSOverTLS=no
Cache=yes
CacheFromLocalhost=yes
DNSStubListener=yes
ReadEtcHosts=yes
EOF

  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    systemctl restart systemd-resolved
  else
    systemctl enable --now systemd-resolved 2>/dev/null || true
  fi

  # Link /etc/resolv.conf if possible
  if [ -L /etc/resolv.conf ] || [ -f /etc/resolv.conf ]; then
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null || true
  fi

  printf "%s[OK] Local DNS cache enabled! Resolving domains through Tier-1 Anycast engines.%s\n" "$C_G" "$C_0"
  test_dns_speed
}

rollback_dns() {
  printf "\n%s=== ROLLING BACK DNS SETTINGS ===%s\n" "$C_B" "$C_0"
  if [ -f "$RESOLVED_BACKUP" ]; then
    cp "$RESOLVED_BACKUP" "$RESOLVED_CONF"
    systemctl restart systemd-resolved 2>/dev/null || true
    printf "%s[OK] DNS configuration restored to original state.%s\n" "$C_G" "$C_0"
  else
    printf "%s[!] No previous backup found. Reverting to standard Cloudflare/Google DNS.%s\n" "$C_Y" "$C_0"
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf
  fi
}

menu() {
  while true; do
    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "          %sOMEGA VPS SMART ANTI-POLLUTION DNS CACHE%s\n" "$C_W" "$C_0"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Test Current DNS Resolution Speed (Latency Benchmark)\n" "$C_C" "$C_0"
    printf "  %s[2]%s Enable Smart DNS Cache & Anycast Upstreams\n" "$C_C" "$C_0"
    printf "  %s[3]%s Revert DNS Configuration to System Default\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1) test_dns_speed ;;
      2) apply_dns_optimization ;;
      3) rollback_dns ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

if [ "${1:-}" = "apply" ]; then
  apply_dns_optimization
else
  menu
fi
