#!/usr/bin/env bash
#===============================================================================
#  omega-monitor — Live Connections, Traffic & Client Monitor
#  Part of Omega VPS All In One Optimizer
#
#  Displays live real-time:
#    - Network Transfer Speed (RX / TX Mbps & MB/s)
#    - TCP / UDP / TIME_WAIT connection counts
#    - Top 10 Connected Client IPs
#    - System CPU & RAM load
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

get_default_iface() {
  ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1
}

get_bytes() {
  local iface="$1"
  local mode="$2" # rx or tx
  if [ "$mode" = "rx" ]; then
    awk -v dev="$iface:" '$1 == dev {print $2}' /proc/net/dev 2>/dev/null || echo 0
  else
    awk -v dev="$iface:" '$1 == dev {print $10}' /proc/net/dev 2>/dev/null || echo 0
  fi
}

run_monitor() {
  local iface
  iface="$(get_default_iface)"
  [ -z "$iface" ] && iface="eth0"

  trap 'printf "\n\033[?25hExiting monitor...\n"; exit 0' INT TERM

  # Hide cursor
  printf "\033[?25l"

  local prev_rx prev_tx prev_time
  prev_rx="$(get_bytes "$iface" "rx")"
  prev_tx="$(get_bytes "$iface" "tx")"
  prev_time="$(date +%s)"

  while true; do
    sleep 2
    local cur_time cur_rx cur_tx
    cur_time="$(date +%s)"
    cur_rx="$(get_bytes "$iface" "rx")"
    cur_tx="$(get_bytes "$iface" "tx")"

    local dt=$(( cur_time - prev_time ))
    [ "$dt" -le 0 ] && dt=1

    local rx_rate_kb=$(( (cur_rx - prev_rx) / 1024 / dt ))
    local tx_rate_kb=$(( (cur_tx - prev_tx) / 1024 / dt ))
    local rx_mbps=$(( rx_rate_kb * 8 / 1024 ))
    local tx_mbps=$(( tx_rate_kb * 8 / 1024 ))

    prev_rx="$cur_rx"
    prev_tx="$cur_tx"
    prev_time="$cur_time"

    # Gather system stats
    local mem_used mem_total
    mem_used="$(free -h 2>/dev/null | awk '/Mem:/ {print $3}')"
    mem_total="$(free -h 2>/dev/null | awk '/Mem:/ {print $2}')"
    local cpu_load
    cpu_load="$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs)"

    local tcp_total tcp_estab tcp_tw udp_total
    tcp_total="$(ss -t -a 2>/dev/null | wc -l)"
    tcp_estab="$(ss -t state established 2>/dev/null | wc -l)"
    tcp_tw="$(ss -t state time-wait 2>/dev/null | wc -l)"
    udp_total="$(ss -u -a 2>/dev/null | wc -l)"

    # Clear screen and draw
    clear 2>/dev/null || printf "\033c"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "          %sOMEGA VPS LIVE CONNECTIONS & TRAFFIC MONITOR%s\n" "$C_W" "$C_0"
    printf "                    (Press %sCtrl+C%s to exit)\n" "$C_R" "$C_0"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    
    printf "  Interface: %-10s  CPU Load (1/5/15m): %s\n" "$iface" "${cpu_load:-unknown}"
    printf "  Memory:    %-10s  Active Connections: %s TCP Estab | %s UDP\n\n" "${mem_used}/${mem_total}" "$tcp_estab" "$udp_total"

    printf "  %sNetwork Speed (%s):%s\n" "$C_W" "$iface" "$C_0"
    printf "    %s↓ DOWNLOAD (RX):%s  %s KB/s  (%s Mbps)\n" "$C_G" "$C_0" "$rx_rate_kb" "$rx_mbps"
    printf "    %s↑ UPLOAD   (TX):%s  %s KB/s  (%s Mbps)\n\n" "$C_B" "$C_0" "$tx_rate_kb" "$tx_mbps"

    printf "  %sSocket States:%s\n" "$C_W" "$C_0"
    printf "    Total TCP: %-8s  Established: %-8s  TIME_WAIT: %-8s\n\n" "$tcp_total" "$tcp_estab" "$tcp_tw"

    printf "  %sTop 8 Connected Remote Client IPs:%s\n" "$C_W" "$C_0"
    printf "  %-6s %-22s %s\n" "Count" "Remote IP Address" "Reverse DNS / Type"
    printf "  %-6s %-22s %s\n" "------" "----------------------" "------------------------"

    # Top client IPs connected
    local top_ips
    top_ips="$(ss -ntu state established 2>/dev/null | awk 'NR>1 {split($5, a, ":"); if (a[1] != "127.0.0.1" && a[1] != "") print a[1]}' | sort | uniq -c | sort -nr | head -n 8)"

    if [ -n "$top_ips" ]; then
      while read -r count ip; do
        if [ -n "$ip" ]; then
          printf "  %-6s %-22s %s\n" "$count" "$ip" "Client Connection"
        fi
      done <<< "$top_ips"
    else
      printf "  %-6s %-22s %s\n" "--" "No active external clients" "--"
    fi

    printf "\n%s------------------------------------------------------------------------%s\n" "$C_B" "$C_0"
    printf "  Updated: %s | Refreshing every 2 seconds...\n" "$(date '+%H:%M:%S')"
  done
}

run_monitor
