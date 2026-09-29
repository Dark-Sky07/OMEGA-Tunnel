#!/usr/bin/env bash
#===============================================================================
#  omega-iran-probe — Comprehensive Iranian Operators & Networks Latency Probe
#  Part of Omega VPS All In One Optimizer
#
#  Probes real-time connectivity, latency, and packet loss from this VPS
#  to all major Iranian operators, mobile carriers, broadband ISPs, and CDNs.
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

# Color helpers
if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_DIM=$'\033[2m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_DIM=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
category(){ printf "\n%s  --- [ %s ] ---%s\n" "$C_W" "$1" "$C_0"; }

probe_target() {
  local name="$1"
  local ip="$2"
  local port="$3"

  local latency="--"
  local loss="100%"
  local quality=""
  local qual_color=""

  # 1. First try ICMP Ping (2 packets, 1s timeout)
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
    # 2. TCP connect fallback if ICMP is blocked by carrier firewalls
    local start_time end_time diff_ms
    start_time="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
    if timeout 1.2 bash -c "(echo >/dev/tcp/$ip/$port) >/dev/null 2>&1"; then
      end_time="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s)"
      diff_ms=$(( end_time - start_time ))
      latency="${diff_ms}.0 ms"
      loss="0% (TCP)"
      if [ "$diff_ms" -lt 60 ]; then
        quality="EXCELLENT"; qual_color="$C_G"
      elif [ "$diff_ms" -lt 110 ]; then
        quality="GOOD"; qual_color="$C_G"
      else
        quality="FAIR"; qual_color="$C_Y"
      fi
    else
      latency="Timeout"
      loss="100%"
      quality="THROTTLED"; qual_color="$C_R"
    fi
  fi

  printf "  %-28s %-16s %-12s %-10s %s%-13s%s\n" "$name" "$ip" "$latency" "$loss" "$qual_color" "$quality" "$C_0"
}

run_full_probe() {
  section "Probing Connectivity to Iranian Operators & Networks"
  printf "  Testing ping, latency, and packet loss from this VPS to Iran...\n"

  printf "\n  %-28s %-16s %-12s %-10s %s\n" "Operator / Service" "Target IP" "Latency" "Loss" "Quality"
  printf "  %-28s %-16s %-12s %-10s %s\n" "----------------------------" "----------------" "------------" "----------" "-------------"

  category "Mobile Operators (MCI / Irancell / RighTel)"
  probe_target "MCI Mobile (Hamrah Aval)" "194.225.62.80" "80"
  probe_target "MCI Shop & Gateway" "178.252.189.65" "443"
  probe_target "MTN Irancell Core" "176.65.192.1" "80"
  probe_target "MTN Irancell CDN" "185.128.80.1" "80"
  probe_target "RighTel 4G LTE Core" "37.228.137.98" "443"
  probe_target "RighTel Gateway DNS" "217.218.155.155" "53"

  category "Fixed Broadband & TD-LTE Carriers"
  probe_target "Shatel Network" "94.182.160.1" "80"
  probe_target "Shatel DNS Server" "85.15.1.1" "53"
  probe_target "Mokhaberat (TCI Core)" "5.160.0.1" "80"
  probe_target "Asiatech Datacenter" "185.143.232.1" "80"
  probe_target "Pars Online / HiWeb" "91.98.0.1" "80"
  probe_target "Mobinnet TD-LTE" "188.121.96.1" "80"
  probe_target "Zitel TD-LTE Gateway" "185.231.112.1" "80"
  probe_target "Afranet Backbone" "194.225.70.1" "80"
  probe_target "Fanava Network" "185.105.236.1" "80"

  category "National CDNs, Infrastructure & Banking"
  probe_target "Aparat Video Streaming" "185.88.152.1" "80"
  probe_target "Digikala E-Commerce" "185.143.233.5" "443"
  probe_target "Snapp Core Services" "185.143.234.1" "443"
  probe_target "Bank Melli Shetab Gateway" "94.182.227.1" "443"

  printf "\n"
  printf "  %s[INFO]%s If a specific carrier shows THROTTLED, that operator'\''s\n" "$C_W" "$C_0"
  printf "         international gateway is under active DPI throttling or packet drop.\n"
}

run_full_probe
