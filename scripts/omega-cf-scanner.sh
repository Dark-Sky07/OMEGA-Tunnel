#!/usr/bin/env bash
#===============================================================================
#  omega-cf-scanner — Cloudflare Clean IP Scanner & Finder
#  Part of Omega VPS All In One Optimizer
#
#  Scans and tests known unblocked Cloudflare CDN IP ranges to find low-latency,
#  clean IPs for VLESS/VMess WebSocket CDN configs in Iran (v2rayNG/V2Box).
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

# Color helpers
if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }

CF_CANDIDATE_IPS=(
  "104.16.132.229|Range 104.16"
  "104.17.210.9|Range 104.17"
  "104.18.2.1|Range 104.18"
  "104.19.155.1|Range 104.19"
  "104.20.12.1|Range 104.20"
  "104.21.45.1|Range 104.21"
  "162.159.192.1|Range 162.159"
  "162.159.138.1|Range 162.159"
  "172.64.32.1|Range 172.64"
  "172.67.74.1|Range 172.67"
  "188.114.96.1|Range 188.114"
  "188.114.97.1|Range 188.114"
  "198.41.214.1|Range 198.41"
  "197.234.240.1|Range 197.234"
)

scan_ips() {
  section "Cloudflare Clean IP Scanner (For CDN & WebSocket Inbounds)"
  printf "  Probing Cloudflare edge IP addresses on Port 443...\n\n"

  printf "  %-18s %-16s %-12s %s\n" "Clean IP Address" "Subnet Group" "TCP Latency" "Status"
  printf "  %-18s %-16s %-12s %s\n" "------------------" "----------------" "------------" "-------------------"

  local results=()

  for item in "${CF_CANDIDATE_IPS[@]}"; do
    IFS='|' read -r ip group <<< "$item"

    local start_time end_time diff_ms
    start_time="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
    
    if timeout 1.0 bash -c "(echo >/dev/tcp/$ip/443) >/dev/null 2>&1"; then
      end_time="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
      diff_ms=$(( end_time - start_time ))
      results+=("${diff_ms}|${ip}|${group}")
    fi
  done

  # Sort by latency ascending
  IFS=$'\n' sorted=($(sort -n <<<"${results[*]}"))
  unset IFS

  local count=0
  for res in "${sorted[@]}"; do
    count=$((count + 1))
    IFS='|' read -r lat ip group <<< "$res"
    local color="$C_G"
    local status="EXCELLENT"
    [ "$lat" -gt 60 ] && status="GOOD" && color="$C_G"
    [ "$lat" -gt 120 ] && status="FAIR" && color="$C_Y"

    printf "  %-18s %-16s %-12s %s[✓ %s]%s\n" "$ip" "$group" "${lat} ms" "$color" "$status" "$C_0"
    [ "$count" -ge 8 ] && break
  done

  printf "\n%s=== HOW TO USE IN V2RAY / 3X-UI ===%s\n" "$C_B" "$C_0"
  printf "  1. In v2rayNG / V2Box client configuration:\n"
  printf "     * Set %sAddress (IP)%s to any of the Clean IPs above (e.g. %s)\n" "$C_W" "$C_0" "${sorted[0]:-104.16.132.229}"
  printf "     * Set %sHost / SNI%s to your Cloudflare domain (e.g. tr.dark-network.info)\n" "$C_W" "$C_0"
  printf "     * Set %sPort%s to 2096, 2053, 2083, or 443 (Cloudflare HTTPS ports)\n" "$C_W" "$C_0"
  printf "  2. Traffic bypasses domestic ISP blocking cleanly without touching your server IP!\n\n"
}

scan_ips
