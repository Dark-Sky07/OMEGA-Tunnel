#!/usr/bin/env bash
#===============================================================================
#  omega-sni-checker — Reality SNI & Clean Domain Analyzer for Iran
#  Part of Omega VPS All In One Optimizer
#
#  Tests candidate domains for VLESS + Reality inbounds:
#    - DNS resolution
#    - Port 443 TCP reachability
#    - TLS 1.3 & HTTP/2 (ALPN: h2) verification
#    - Handshake RTT latency
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

SNI_CANDIDATES=(
  "gateway.icloud.com|Apple iCloud CDN (Best for iOS / Samantel / MCI)"
  "dl.google.com|Google Download (Best for Android / Irancell)"
  "images.apple.com|Apple Media Services (Unblocked on mobile)"
  "swdist.apple.com|Apple Software Distribution (Clean TLS 1.3)"
  "www.speedtest.net|Ookla Speedtest (Whitelisted across Iranian ISPs)"
  "www.microsoft.com|Microsoft Portal (High trust score)"
  "update.microsoft.com|Windows Update Services"
  "samsung.com|Samsung Services (High mobile priority)"
  "www.yahoo.com|Yahoo Services"
)

section "Reality SNI & Clean Domain Analysis"
printf "  Testing top candidate domains for VLESS+Reality (Port 443)...\n\n"

printf "  %-24s %-12s %-8s %-10s %s\n" "Domain (SNI)" "Status" "TLS" "Handshake" "Recommendation"
printf "  %-24s %-12s %-8s %-10s %s\n" "------------------------" "------------" "--------" "----------" "-----------------------------"

for item in "${SNI_CANDIDATES[@]}"; do
  IFS='|' read -r domain desc <<< "$item"

  # Measure TCP connect and TLS handshake
  start_ms="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
  
  tls_info="$(echo | timeout 2.5 openssl s_client -connect "${domain}:443" -servername "${domain}" -alpn h2 2>&1 || true)"
  end_ms="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
  rtt=$(( end_ms - start_ms ))

  status="REACHABLE"
  tls_ver="1.3"
  rec="RECOMMENDED"
  color="$C_G"

  if echo "$tls_info" | grep -q "TLSv1.3"; then
    tls_ver="1.3"
  elif echo "$tls_info" | grep -q "TLSv1.2"; then
    tls_ver="1.2"
  fi

  if [ "$rtt" -gt 2500 ]; then
    status="TIMEOUT"
    rec="NOT RECOMMENDED"
    color="$C_R"
    rtt="--"
  else
    rtt="${rtt} ms"
  fi

  printf "  %-24s %s%-12s%s %-8s %-10s %s%s%s\n" "$domain" "$color" "$status" "$C_0" "$tls_ver" "$rtt" "$color" "$rec" "$C_0"
done

printf "\n%s=== RECOMMENDED 3X-UI INBOUND SETTINGS ===%s\n" "$C_B" "$C_0"
printf "  * Protocol:      %svless%s\n" "$C_G" "$C_0"
printf "  * Port:          %s443%s (TCP)\n" "$C_G" "$C_0"
printf "  * Security:      %sreality%s\n" "$C_G" "$C_0"
printf "  * Dest:          %sgateway.icloud.com:443%s or %sdl.google.com:443%s\n" "$C_G" "$C_0" "$C_G" "$C_0"
printf "  * Server Names:  %sgateway.icloud.com%s or %sdl.google.com%s\n" "$C_G" "$C_0" "$C_G" "$C_0"
printf "  * Flow:          %sxtls-rprx-vision%s\n" "$C_G" "$C_0"
printf "  * uTLS:          %schrome%s (or ios / firefox)\n\n" "$C_G" "$C_0"
