#!/usr/bin/env bash
# ========================================================================
#   OMEGA VPS All In One Optimizer — Telegram Notification Manager
#   File: scripts/omega-telegram.sh
#   Description: Instant alerts for server status, watchdog, & IP unban
# ========================================================================

set -u

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

CONF_DIR="/opt/omega-boost"
CONF_FILE="$CONF_DIR/telegram.conf"

mkdir -p "$CONF_DIR" 2>/dev/null || true

load_config() {
  BOT_TOKEN=""
  CHAT_ID=""
  TG_ENABLED="0"
  if [ -f "$CONF_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONF_FILE"
  fi
}

save_config() {
  cat <<EOF > "$CONF_FILE"
# Omega Telegram Alerts Configuration
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
TG_ENABLED="$TG_ENABLED"
EOF
  chmod 600 "$CONF_FILE"
}

send_msg() {
  local message="$1"
  load_config

  if [ "${TG_ENABLED:-0}" != "1" ] || [ -z "${BOT_TOKEN:-}" ] || [ -z "${CHAT_ID:-}" ]; then
    return 1
  fi

  local host_name
  host_name=$(hostname)
  local server_ip
  server_ip=$(curl -s4m 3 https://api.ipify.org || echo "VPS")

  local payload="🖥️ *OMEGA VPS ALERT* — \`${host_name}\` (${server_ip})%0A%0A${message}"
  
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=${payload}" \
    -d "parse_mode=Markdown" > /dev/null 2>&1 || true
}

configure_bot() {
  load_config
  printf "\n%s=== CONFIGURE TELEGRAM NOTIFICATIONS ===%s\n" "$C_B" "$C_0"
  printf "To receive instant alerts when Xray dies, IP is unbanned, or backups complete:\n"
  printf "  1. Create a bot via @BotFather and copy the HTTP API Token.\n"
  printf "  2. Start your bot or message @userinfobot to get your numeric Chat ID.\n\n"

  printf "Enter Telegram Bot Token [%s]: " "${BOT_TOKEN:-None}"
  read -r input_token
  [ -n "$input_token" ] && BOT_TOKEN="$input_token"

  printf "Enter Your Telegram Chat ID [%s]: " "${CHAT_ID:-None}"
  read -r input_chat
  [ -n "$input_chat" ] && CHAT_ID="$input_chat"

  if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    TG_ENABLED="1"
    save_config
    printf "\n%s[OK] Telegram configuration saved successfully!%s\n" "$C_G" "$C_0"
    test_notification
  else
    printf "\n%s[!] Incomplete configuration. Token or Chat ID was empty.%s\n" "$C_Y" "$C_0"
  fi
}

test_notification() {
  load_config
  if [ -z "${BOT_TOKEN:-}" ] || [ -z "${CHAT_ID:-}" ]; then
    printf "%s[FAIL] Telegram bot is not configured yet. Run configuration first.%s\n" "$C_R" "$C_0"
    return 1
  fi

  printf "Sending test message to Telegram... "
  local res
  res=$(curl -s -w "%{http_code}" -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=🚀 *Omega VPS Optimizer* notification test successful!%0A✅ Server alerts are actively connected." \
    -d "parse_mode=Markdown" -o /tmp/omega-tg-res.json || echo "000")

  if [ "$res" = "200" ]; then
    printf "%s[DELIVERED]%s\n" "$C_G" "$C_0"
    printf "%sCheck your Telegram bot. A test notification was received!%s\n" "$C_W" "$C_0"
  else
    printf "%s[FAILED (HTTP %s)]%s\n" "$C_R" "$res" "$C_0"
    if [ -f /tmp/omega-tg-res.json ]; then
      cat /tmp/omega-tg-res.json
      printf "\n"
    fi
  fi
}

toggle_alerts() {
  load_config
  if [ "${TG_ENABLED:-0}" = "1" ]; then
    TG_ENABLED="0"
    save_config
    printf "%s[DISABLED] Telegram notifications are now muted.%s\n" "$C_Y" "$C_0"
  else
    if [ -n "${BOT_TOKEN:-}" ] && [ -n "${CHAT_ID:-}" ]; then
      TG_ENABLED="1"
      save_config
      printf "%s[ENABLED] Telegram notifications are active!%s\n" "$C_G" "$C_0"
    else
      printf "%s[!] Please configure Bot Token and Chat ID first.%s\n" "$C_R" "$C_0"
    fi
  fi
}

menu() {
  while true; do
    load_config
    local status_text="${C_R}Disabled / Unconfigured${C_0}"
    if [ "${TG_ENABLED:-0}" = "1" ] && [ -n "${BOT_TOKEN:-}" ]; then
      status_text="${C_G}Active & Connected (Chat: ${CHAT_ID})${C_0}"
    fi

    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "          %sOMEGA VPS TELEGRAM NOTIFICATIONS%s\n" "$C_W" "$C_0"
    printf "  Alert Status: %b\n" "$status_text"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Configure Telegram Bot & Chat ID\n" "$C_C" "$C_0"
    printf "  %s[2]%s Send Test Notification Now\n" "$C_C" "$C_0"
    printf "  %s[3]%s Toggle Alerts On/Off\n" "$C_C" "$C_0"
    printf "  %s[4]%s Delete Telegram Configuration\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1) configure_bot ;;
      2) test_notification ;;
      3) toggle_alerts ;;
      4)
        rm -f "$CONF_FILE"
        printf "%s[OK] Configuration deleted.%s\n" "$C_G" "$C_0"
        ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

if [ "${1:-}" = "send" ]; then
  shift
  send_msg "$*"
elif [ "${1:-}" = "test" ]; then
  test_notification
else
  menu
fi
