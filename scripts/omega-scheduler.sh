#!/usr/bin/env bash
#===============================================================================
#  omega-scheduler — Iran Peak-Hours Smart Performance Scheduler
#  Part of Omega VPS All In One Optimizer
#
#  Automatically switches server network parameters into High-Aggression Mode
#  during Iran's heavy censorship peak hours (20:00 to 01:30 Tehran Time).
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"
STATE_FILE="${BASE_DIR}/scheduler.state"
SERVICE_FILE="/etc/systemd/system/omega-scheduler.service"
TIMER_FILE="/etc/systemd/system/omega-scheduler.timer"

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[OK]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[WARN]%s %s\n" "$C_Y" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }

get_tehran_hour() {
  TZ="Asia/Tehran" date +%H | sed 's/^0//'
}

apply_peak_mode() {
  section "Engaging Heavy Peak-Hours Combat Mode"
  mkdir -p "$BASE_DIR"

  # Maximize network memory buffers to withstand ISP throttling and packet drops
  sysctl -w net.core.rmem_max=67108864 >/dev/null 2>&1 || true
  sysctl -w net.core.wmem_max=67108864 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_rmem="4096 87380 67108864" >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_wmem="4096 65536 67108864" >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_notsent_lowat=131072 >/dev/null 2>&1 || true

  # Fast TCP retransmissions for lossy peak hours
  sysctl -w net.ipv4.tcp_retries1=3 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_retries2=8 >/dev/null 2>&1 || true

  echo "PEAK" > "$STATE_FILE"
  ok "Peak-Hours Aggressive Mode ENGAGED!"
  info "- Network buffers expanded to 64MB to resist throttling."
  info "- Fast TCP retransmission active for lossy peak periods."
  printf "\n"
}

apply_balanced_mode() {
  section "Switching to Balanced Mode"
  mkdir -p "$BASE_DIR"

  # Standard balanced buffers
  sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1 || true
  sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_rmem="4096 87380 16777216" >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_wmem="4096 65536 16777216" >/dev/null 2>&1 || true
  sysctl -w net.ipv4.tcp_retries2=15 >/dev/null 2>&1 || true

  echo "BALANCED" > "$STATE_FILE"
  ok "Balanced Mode active."
  info "- System resources conserved during off-peak hours."
  printf "\n"
}

evaluate_schedule() {
  local hour
  hour=$(get_tehran_hour)

  # Peak filtering hours in Iran: 20:00 to 01:00 (hours 20, 21, 22, 23, 0, 1)
  if [ "$hour" -ge 20 ] || [ "$hour" -le 1 ]; then
    apply_peak_mode
  else
    apply_balanced_mode
  fi
}

enable_scheduler() {
  section "Enabling Automated Iran Peak-Hours Scheduler"

  local src_script
  src_script="$(readlink -f "${BASH_SOURCE[0]}")"
  mkdir -p /opt/omega-boost /opt/omega-boost/scripts
  cp -f "$src_script" "/opt/omega-boost/omega-scheduler.sh"
  cp -f "$src_script" "/opt/omega-boost/scripts/omega-scheduler.sh" 2>/dev/null || true
  chmod +x "/opt/omega-boost/omega-scheduler.sh" "/opt/omega-boost/scripts/omega-scheduler.sh" 2>/dev/null || true

  cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Omega VPS Iran Peak-Hours Dynamic Performance Scheduler
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /opt/omega-boost/omega-scheduler.sh auto
EOF

  cat <<EOF > "$TIMER_FILE"
[Unit]
Description=Evaluate Iran Peak-Hours Mode every hour
After=network.target

[Timer]
OnBootSec=2min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now omega-scheduler.timer >/dev/null 2>&1
  ok "Automated Scheduler ACTIVE! Checks Iran local time hourly."
  evaluate_schedule
}

disable_scheduler() {
  systemctl disable --now omega-scheduler.timer >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$TIMER_FILE"
  systemctl daemon-reload
  apply_balanced_mode
  ok "Automated Scheduler disabled. Returned to Balanced Mode."
}

show_status() {
  local th_time
  th_time=$(TZ="Asia/Tehran" date "+%Y-%m-%d %H:%M:%S Tehran Time")
  local current_state
  current_state=$(cat "$STATE_FILE" 2>/dev/null || echo "BALANCED")

  local timer_status="${C_R}Disabled (Manual)${C_0}"
  if systemctl is-active --quiet omega-scheduler.timer 2>/dev/null; then
    timer_status="${C_G}Active (24/7 Automated Hourly Sync)${C_0}"
  fi

  section "Iran Peak-Hours Scheduler Status"
  printf "  * Current Tehran Time: %s%s%s\n" "$C_W" "$th_time" "$C_0"
  printf "  * Scheduler Timer:     %b\n" "$timer_status"
  printf "  * Active Profile:      "
  if [ "$current_state" = "PEAK" ]; then
    printf "%s[PEAK COMBAT MODE (64MB Buffers)]%s\n" "$C_G" "$C_0"
  else
    printf "%s[BALANCED MODE (16MB Buffers)]%s\n" "$C_C" "$C_0"
  fi
  printf "\n"
}

menu() {
  while true; do
    local state
    state=$(cat "$STATE_FILE" 2>/dev/null || echo "BALANCED")
    local timer_stat="${C_R}Manual${C_0}"
    if systemctl is-active --quiet omega-scheduler.timer 2>/dev/null; then
      timer_stat="${C_G}Automated (Tehran Clock)${C_0}"
    fi

    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "          %sOMEGA IRAN PEAK-HOURS SMART SCHEDULER%s\n" "$C_W" "$C_0"
    printf "  Mode: %s | Profile: %s\n" "$timer_stat" "$state"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Enable Automated Hourly Scheduler (Auto Peak/Balanced)\n" "$C_C" "$C_0"
    printf "  %s[2]%s Force Peak-Hours Combat Mode Now (64MB Max Buffers)\n" "$C_C" "$C_0"
    printf "  %s[3]%s Force Balanced Off-Peak Mode Now\n" "$C_C" "$C_0"
    printf "  %s[4]%s Show Detailed Time & Profile Status\n" "$C_C" "$C_0"
    printf "  %s[5]%s Disable Automated Scheduler\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1) enable_scheduler; read -r -p "Press [Enter] to return..." _ || true ;;
      2) apply_peak_mode; read -r -p "Press [Enter] to return..." _ || true ;;
      3) apply_balanced_mode; read -r -p "Press [Enter] to return..." _ || true ;;
      4) show_status; read -r -p "Press [Enter] to return..." _ || true ;;
      5) disable_scheduler; read -r -p "Press [Enter] to return..." _ || true ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

case "${1:-}" in
  auto)
    evaluate_schedule
    ;;
  peak)
    apply_peak_mode
    ;;
  balanced)
    apply_balanced_mode
    ;;
  enable)
    enable_scheduler
    ;;
  disable)
    disable_scheduler
    ;;
  status)
    show_status
    ;;
  *)
    menu
    ;;
esac
