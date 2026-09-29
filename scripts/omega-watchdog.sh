#!/usr/bin/env bash
# ========================================================================
#   OMEGA VPS All In One Optimizer — Xray & Panel Auto-Healing Watchdog
#   File: scripts/omega-watchdog.sh
#   Description: 24/7 zero-downtime watchdog recovering crashed panels
# ========================================================================

set -u

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

LOG_FILE="/var/log/omega-watchdog.log"
SERVICE_FILE="/etc/systemd/system/omega-watchdog.service"
SCRIPT_PATH="/opt/omega-boost/omega-watchdog.sh"

notify_telegram() {
  local msg="$1"
  if [ -f "/opt/omega-boost/omega-telegram.sh" ]; then
    bash /opt/omega-boost/omega-telegram.sh send "$msg" >/dev/null 2>&1 || true
  fi
}

check_and_heal() {
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")

  # Detect installed panels: x-ui or 3x-ui
  local panel_service=""
  if systemctl list-unit-files | grep -q "^x-ui.service"; then
    panel_service="x-ui"
  elif systemctl list-unit-files | grep -q "^3x-ui.service"; then
    panel_service="3x-ui"
  fi

  if [ -z "$panel_service" ]; then
    # Panel not installed on this system
    return 0
  fi

  local need_restart=0
  local reason=""

  if ! systemctl is-active --quiet "$panel_service"; then
    need_restart=1
    reason="Service $panel_service was inactive or failed"
  elif ! pgrep -f "xray-linux" >/dev/null 2>&1; then
    need_restart=1
    reason="Xray core process was unexpectedly dead"
  fi

  if [ "$need_restart" -eq 1 ]; then
    echo "[$timestamp] ALERT: $reason. Auto-recovering..." >> "$LOG_FILE"
    systemctl restart "$panel_service" || true
    sleep 2

    if systemctl is-active --quiet "$panel_service"; then
      echo "[$timestamp] SUCCESS: $panel_service recovered successfully." >> "$LOG_FILE"
      notify_telegram "🐕 *OMEGA WATCHDOG RECOVERY!*%0A🚨 *$reason*%0A✅ *Status:* Panel automatically healed and restarted in under 3 seconds! Client connections restored."
    else
      echo "[$timestamp] FAILED: Could not recover $panel_service." >> "$LOG_FILE"
      notify_telegram "⚠️ *OMEGA WATCHDOG CRITICAL:* Failed to auto-recover $panel_service. Manual intervention required!"
    fi
  fi
}

watchdog_loop() {
  echo "[$(date "+%Y-%m-%d %H:%M:%S")] Omega Watchdog daemon started." >> "$LOG_FILE"
  while true; do
    check_and_heal
    sleep 20
  done
}

enable_watchdog() {
  printf "\n%s=== ENABLING 24/7 AUTO-HEALING WATCHDOG ===%s\n" "$C_B" "$C_0"

  mkdir -p /opt/omega-boost
  cp "$0" "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  touch "$LOG_FILE"

  cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Omega VPS Xray & Panel Auto-Healing Watchdog
After=network.target x-ui.service 3x-ui.service

[Service]
Type=simple
ExecStart=/bin/bash /opt/omega-boost/omega-watchdog.sh daemon
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now omega-watchdog.service >/dev/null 2>&1
  printf "%s[OK] Watchdog is active! Checking panel & core health every 20 seconds.%s\n" "$C_G" "$C_0"
}

disable_watchdog() {
  systemctl disable --now omega-watchdog.service >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE"
  systemctl daemon-reload
  printf "%s[OK] Watchdog service stopped and disabled.%s\n" "$C_G" "$C_0"
}

view_logs() {
  printf "\n%s=== WATCHDOG RECENT EVENTS (LAST 25 LINES) ===%s\n" "$C_B" "$C_0"
  if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
    tail -n 25 "$LOG_FILE"
  else
    printf "%sNo crash events recorded yet. Panel is running smoothly!%s\n" "$C_G" "$C_0"
  fi
  printf "\nPress Enter to return..."
  read -r _
}

test_health() {
  printf "\n%s=== RUNNING INSTANT HEALTH CHECK ===%s\n" "$C_B" "$C_0"
  local panel_service="none"
  if systemctl list-unit-files 2>/dev/null | grep -q "^x-ui.service"; then
    panel_service="x-ui"
  elif systemctl list-unit-files 2>/dev/null | grep -q "^3x-ui.service"; then
    panel_service="3x-ui"
  fi

  printf "Panel Service Detection: "
  if [ "$panel_service" != "none" ]; then
    printf "%s[%s DETECTED]%s\n" "$C_G" "$panel_service" "$C_0"
    printf "Service Status: "
    if systemctl is-active --quiet "$panel_service"; then
      printf "%s[ACTIVE & RUNNING]%s\n" "$C_G" "$C_0"
    else
      printf "%s[INACTIVE]%s\n" "$C_R" "$C_0"
    fi
  else
    printf "%s[NONE FOUND]%s\n" "$C_Y" "$C_0"
  fi

  printf "Xray Process: "
  if pgrep -f "xray-linux" >/dev/null 2>&1; then
    local pid
    pid=$(pgrep -f "xray-linux" | head -n 1)
    printf "%s[RUNNING (PID %s)]%s\n" "$C_G" "$pid" "$C_0"
  else
    printf "%s[NOT DETECTED]%s\n" "$C_Y" "$C_0"
  fi
}

menu() {
  while true; do
    local status="${C_R}Inactive${C_0}"
    if systemctl is-active --quiet omega-watchdog.service 2>/dev/null; then
      status="${C_G}Active & Guarding (PID $(pgrep -f "omega-watchdog.sh daemon" | head -n 1 || echo "?"))${C_0}"
    fi

    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "          %sOMEGA VPS XRAY & PANEL AUTO-HEALING WATCHDOG%s\n" "$C_W" "$C_0"
    printf "  Watchdog Daemon: %b\n" "$status"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Test Panel & Xray Core Health (Instant Check)\n" "$C_C" "$C_0"
    printf "  %s[2]%s Enable 24/7 Background Auto-Healing Watchdog\n" "$C_C" "$C_0"
    printf "  %s[3]%s Disable Background Watchdog Service\n" "$C_C" "$C_0"
    printf "  %s[4]%s View Watchdog Incident Logs\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1) test_health ;;
      2) enable_watchdog ;;
      3) disable_watchdog ;;
      4) view_logs ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

if [ "${1:-}" = "daemon" ]; then
  watchdog_loop
elif [ "${1:-}" = "check" ]; then
  check_and_heal
else
  menu
fi
