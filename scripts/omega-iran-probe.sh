#!/usr/bin/env bash
#===============================================================================
#  omega-iran-probe — Iran Operators Latency, Jitter & Packet Loss Probe
#  Part of Omega VPS All In One Optimizer
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

probe_host() {
  local name="$1"
  local ip="$2"
  local port="$3"

  local latency="--"
  local loss="100%"
  local quality=""
  local qual_color=""

  # 1. ICMP Ping (2 packets, 1s timeout)
  local ping_out
  ping_out="$(ping -c 2 -W 1 -q "$ip" 2>/dev/null || true)"

  if echo "$ping_out" | grep -q "min/avg/max"; then
    latency="$(echo "$ping_out" | awk -F'/' '/min\/avg\/max/ {printf "%.1f ms", $5}')"
    loss="$(echo "$ping_out" | awk -F',' '/packet loss/ {print $3}' | awk '{print $1}')"
    local avg_num
    avg_num="$(echo "$latency" | awk '{print int($1)}')"
    if [ "$avg_num" -lt 60 ]; then
      quality="EXCELLENT"; qual_color="$C_G"
    elif [ "$avg_num" -lt 110 ]; then
      quality="GOOD"; qual_color="$C_G"
    elif [ "$avg_num" -lt 180 ]; then
      quality="FAIR"; qual_color="$C_Y"
    else
      quality="HIGH LATENCY"; qual_color="$C_Y"
    fi
  else
    # 2. TCP connect fallback
    local start_time end_time diff_ms
    start_time="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
    if timeout 1.2 bash -c "(echo >/dev/tcp/$ip/$port) >/dev/null 2>&1"; then
      end_time="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
      diff_ms=$(( end_time - start_time ))
      latency="${diff_ms}.0 ms"
      loss="0% (TCP)"
      quality="CONNECTED"; qual_color="$C_G"
    else
      latency="Timeout"
      loss="100%"
      quality="THROTTLED"; qual_color="$C_R"
    fi
  fi

  printf "  %-24s %-16s %-12s %-10s %s%-13s%s\n" "$name" "$ip" "$latency" "$loss" "$qual_color" "$quality" "$C_0"
}

run_probe() {
  section "Probing Connectivity to Iranian Operators & Networks"
  printf "  Testing ping, latency, and packet loss from this VPS to Iran...\n\n"

  printf "  %-24s %-16s %-12s %-10s %s\n" "Operator / ISP" "Target IP" "Latency" "Loss" "Quality"
  printf "  %-24s %-16s %-12s %-10s %s\n" "------------------------" "----------------" "------------" "----------" "-------------"

  probe_host "MCI (Hamrah Aval)" "194.225.0.1" "53"
  probe_host "MCI Mobile Backbone" "178.252.189.65" "80"
  probe_host "MTN Irancell" "5.200.200.200" "53"
  probe_host "RighTel 4G LTE" "217.218.155.155" "53"
  probe_host "Shatel Network" "85.15.1.1" "53"
  probe_host "Mokhaberat (TCI)" "2.188.0.1" "53"
  probe_host "Asiatech Broadband" "185.143.232.1" "53"
  probe_host "Iran Domestic CDN" "185.88.152.1" "80"

  printf "\n"
  printf "  %s[INFO]%s If a specific carrier shows THROTTLED or HIGH LOSS, that operator'\''s\n" "$C_W" "$C_0"
  printf "         gateway is experiencing network throttling or active DPI filtering.\n"
}

run_probe
