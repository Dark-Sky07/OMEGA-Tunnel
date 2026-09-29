#!/usr/bin/env bash
# ========================================================================
#   OMEGA VPS All In One Optimizer — Iran-Foreign Bridge & Tunnel Doctor
#   File: scripts/omega-bridge.sh
#   Description: Evaluates Latency, Jitter, Packet-Loss, & Tunnel Quality
# ========================================================================

set -u

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

test_target() {
  local target="$1"
  local count="${2:-10}"

  printf "\n%sTesting connection to: %s (%s packets)...%s\n" "$C_B" "$target" "$count" "$C_0"

  if ! ping -c 1 -W 2 "$target" >/dev/null 2>&1; then
    printf "%s[!] Target does not respond to ICMP ping (might be firewall/TCP-only).%s\n" "$C_Y" "$C_0"
    printf "Testing TCP handshake to port 443 / 80... "
    local start
    start=$(date +%s%N)
    if curl -s4m 4 "http://$target" >/dev/null 2>&1 || curl -sk4m 4 "https://$target" >/dev/null 2>&1; then
      local end
      end=$(date +%s%N)
      local lat=$(( (end - start) / 1000000 ))
      printf "%s[CONNECTED - %s ms]%s\n" "$C_G" "$lat" "$C_0"
    else
      printf "%s[UNREACHABLE]%s\n" "$C_R" "$C_0"
    fi
    return
  fi

  local ping_out
  ping_out=$(ping -c "$count" -i 0.2 "$target" 2>&1 || true)

  local loss
  loss=$(echo "$ping_out" | grep -oP '\d+(?=% packet loss)' || echo "100")

  local rtt_line
  rtt_line=$(echo "$ping_out" | grep -oP 'rtt min/avg/max/mdev = \K.*' || echo "")

  printf "  Packet Loss: "
  if [ "$loss" -eq 0 ]; then
    printf "%s0%% (Perfect Line)%s\n" "$C_G" "$C_0"
  elif [ "$loss" -le 5 ]; then
    printf "%s%s%% (Slight Jitter)%s\n" "$C_Y" "$loss" "$C_0"
  else
    printf "%s%s%% (Heavy Throttling)%s\n" "$C_R" "$loss" "$C_0"
  fi

  if [ -n "$rtt_line" ]; then
    local min avg max mdev
    min=$(echo "$rtt_line" | awk -F'/' '{print $1}')
    avg=$(echo "$rtt_line" | awk -F'/' '{print $2}')
    max=$(echo "$rtt_line" | awk -F'/' '{print $3}')
    mdev=$(echo "$rtt_line" | awk -F'/' '{print $4}' | awk '{print $1}')

    printf "  Latency:     %sMin: %s ms | Avg: %s ms | Max: %s ms%s\n" "$C_W" "$min" "$avg" "$max" "$C_0"
    printf "  Jitter:      %s±%s ms%s\n" "$C_C" "$mdev" "$C_0"

    printf "\n%s=== PROTOCOL & TUNNEL RECOMMENDATION ===%s\n" "$C_B" "$C_0"
    if [ "$loss" -le 2 ]; then
      printf "  %s[RECOMMENDATION]%s Line is super stable. Direct VLESS+Reality, Gost, or Rathole will perform flawlessly!\n" "$C_G" "$C_0"
    elif [ "$loss" -le 15 ]; then
      printf "  %s[RECOMMENDATION]%s Moderate packet loss. Hysteria2 (Brutal UDP) or KCP with 15%% FEC is strongly recommended.\n" "$C_Y" "$C_0"
    else
      printf "  %s[CRITICAL]%s Heavy ISP drop rate. Reverse Tunnel (Backhaul) via TLS or WebSocket CDN fallback is mandatory.\n" "$C_R" "$C_0"
    fi
  fi
}

menu() {
  while true; do
    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "          %sOMEGA VPS IRAN-FOREIGN BRIDGE & TUNNEL DOCTOR%s\n" "$C_W" "$C_0"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Test Custom Iran Relay / Bridge IP or Domain\n" "$C_C" "$C_0"
    printf "  %s[2]%s Quick Benchmark to Tehran Asiatech Backbone (185.143.232.1)\n" "$C_C" "$C_0"
    printf "  %s[3]%s Quick Benchmark to MCI Mobile Backbone (194.225.70.1)\n" "$C_C" "$C_0"
    printf "  %s[4]%s Quick Benchmark to Irancell Mobile Backbone (92.42.51.1)\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1)
        printf "Enter Iran Server IP or Hostname: "
        read -r custom_ip
        if [ -n "$custom_ip" ]; then
          test_target "$custom_ip" 10
        fi
        ;;
      2) test_target "185.143.232.1" 10 ;;
      3) test_target "194.225.70.1" 10 ;;
      4) test_target "92.42.51.1" 10 ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

if [ -n "${1:-}" ]; then
  test_target "$1" "${2:-10}"
else
  menu
fi
