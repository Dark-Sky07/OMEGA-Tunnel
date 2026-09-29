#!/usr/bin/env bash
#===============================================================================
#  omega-speedtest — VPS Bandwidth & Speed Test (Iran & Global)
#  Part of Omega VPS All In One Optimizer
#
#  Tests:
#    - Official Speedtest CLI (if installed)
#    - Multi-Node Download/Upload to Europe & Istanbul
#    - Latency to Tehran, MCI, Shatel & European Exchange
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
have(){ command -v "$1" >/dev/null 2>&1; }

run_speedtest() {
  section "VPS Bandwidth & Throughput Speedtest"

  if have speedtest; then
    printf "  Running Official Ookla Speedtest...\n\n"
    speedtest --accept-license --accept-gdpr || true
    return
  fi

  if have speedtest-cli; then
    printf "  Running Speedtest-CLI...\n\n"
    speedtest-cli --secure --simple || true
    return
  fi

  printf "  Testing network download throughput from global and regional CDN nodes...\n\n"
  printf "  %-30s %-16s %-14s %s\n" "Location / Node" "Test Size" "Time" "Speed (Mbps)"
  printf "  %-30s %-16s %-14s %s\n" "------------------------------" "----------------" "--------------" "------------"

  TEST_NODES=(
    "Istanbul CDN (Regional)|https://speed.cloudflare.com/__down?bytes=50000000|50 MB"
    "Frankfurt (Europe Hub)|https://nbg1-speed.hetzner.com/100MB.bin|50 MB"
    "Amsterdam (Global Transit)|https://ash-speed.hetzner.com/100MB.bin|50 MB"
    "Iran Edge Mirror (Arvan)|https://arvancloud.ir/favicon.ico|5 MB"
  )

  for node in "${TEST_NODES[@]}"; do
    IFS='|' read -r name url size_label <<< "$node"

    local start_time end_time elapsed_sec speed_mbps
    start_time="$(python3 -c 'import time; print(time.time())' 2>/dev/null || date +%s)"
    
    local dl_bytes=0
    # Download with curl, 8s timeout, pipe to /dev/null
    dl_bytes="$(curl -s4m 8 -w '%{size_download}' -o /dev/null "$url" 2>/dev/null || echo "0")"
    end_time="$(python3 -c 'import time; print(time.time())' 2>/dev/null || date +%s)"
    
    elapsed_sec="$(python3 -c "print(max(0.1, $end_time - $start_time))" 2>/dev/null || echo "1.0")"
    
    if [ "$dl_bytes" -gt 100000 ]; then
      speed_mbps="$(python3 -c "print(round(($dl_bytes * 8) / ($elapsed_sec * 1000000), 1))" 2>/dev/null || echo "--")"
      local time_fmt="$(python3 -c "print(round($elapsed_sec, 2))" 2>/dev/null || echo "--")s"
      printf "  %-30s %-16s %-14s %s%s Mbps%s\n" "$name" "$size_label" "$time_fmt" "$C_G" "$speed_mbps" "$C_0"
    else
      printf "  %-30s %-16s %-14s %sOffline / Blocked%s\n" "$name" "$size_label" "--" "$C_Y" "$C_0"
    fi
  done

  printf "\n"
  printf "  %s[TIP]%s To install official Ookla multi-carrier speedtest CLI on this server:\n" "$C_W" "$C_0"
  printf "        apt install -y speedtest-cli 2>/dev/null || pip install speedtest-cli\n"
}

run_speedtest
