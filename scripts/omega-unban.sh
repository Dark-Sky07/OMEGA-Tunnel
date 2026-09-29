#!/usr/bin/env bash
# ========================================================================
#   OMEGA VPS All In One Optimizer — IP Reputation & Streaming Unban Healer
#   File: scripts/omega-unban.sh
#   Description: Google Captcha & ChatGPT unban with automated self-healing
# ========================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

GAI_CONF="/etc/gai.conf"
SCRIPT_PATH="/opt/omega-boost/omega-unban.sh"
SERVICE_FILE="/etc/systemd/system/omega-unban.service"
TIMER_FILE="/etc/systemd/system/omega-unban.timer"

notify_telegram() {
  local msg="$1"
  if [ -f "/opt/omega-boost/omega-telegram.sh" ]; then
    bash /opt/omega-boost/omega-telegram.sh send "$msg" >/dev/null 2>&1 || true
  fi
}

check_google() {
  local res
  res=$(curl -s4m 6 "https://www.google.com/search?q=omega+speedtest" -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36" 2>/dev/null || echo "")
  if echo "$res" | grep -qi "sorry/index\|unusual traffic\|recaptcha"; then
    echo "CAPTCHA"
  elif [ -z "$res" ]; then
    echo "TIMEOUT"
  else
    echo "CLEAN"
  fi
}

check_openai() {
  # Query official OpenAI API models endpoint
  # 401 Unauthorized = IP accepted and valid (endpoint reached, just no API token) -> UNLOCKED
  # 403 Forbidden = IP or Country blacklisted by OpenAI -> BLOCKED
  # 000 = Connection timeout / network failure
  local code
  code=$(curl -s4o /dev/null -w "%{http_code}" -m 6 "https://api.openai.com/v1/models" -A "Mozilla/5.0" 2>/dev/null || echo "000")

  if [ "$code" = "401" ] || [ "$code" = "200" ]; then
    echo "UNLOCKED"
  elif [ "$code" = "403" ]; then
    echo "BLOCKED"
  elif [ "$code" = "000" ]; then
    echo "TIMEOUT"
  else
    # Fallback to iOS chat app endpoint
    local ios_code
    ios_code=$(curl -s4o /dev/null -w "%{http_code}" -m 6 "https://ios.chat.openai.com/" -A "Mozilla/5.0" 2>/dev/null || echo "000")
    if [ "$ios_code" = "401" ] || [ "$ios_code" = "200" ] || [ "$ios_code" = "302" ] || [ "$ios_code" = "301" ] || [ "$ios_code" = "404" ]; then
      echo "UNLOCKED"
    else
      echo "BLOCKED ($code)"
    fi
  fi
}

check_netflix() {
  local code
  code=$(curl -s4o /dev/null -w "%{http_code}" -m 6 "https://www.netflix.com/title/80018499" -A "Mozilla/5.0" 2>/dev/null || echo "000")
  if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ]; then
    echo "UNLOCKED"
  elif [ "$code" = "403" ] || [ "$code" = "404" ]; then
    echo "BLOCKED"
  elif [ "$code" = "000" ]; then
    echo "TIMEOUT"
  else
    echo "RESTRICTED ($code)"
  fi
}

check_warp_status() {
  if ip link show 2>/dev/null | grep -qE "wgcf|warp|wg[0-9]"; then
    echo "ACTIVE"
  elif command -v warp-cli >/dev/null 2>&1 && warp-cli status 2>/dev/null | grep -q "Connected"; then
    echo "ACTIVE"
  else
    echo "INACTIVE"
  fi
}

run_diagnostics() {
  printf "\n%s=== IP REPUTATION & STREAMING UNLOCK AUDIT ===%s\n" "$C_B" "$C_0"
  
  printf "Testing Google Search Captcha... "
  local g_stat
  g_stat=$(check_google)
  if [ "$g_stat" = "CLEAN" ]; then
    printf "%s[CLEAN / NO CAPTCHA]%s\n" "$C_G" "$C_0"
  elif [ "$g_stat" = "CAPTCHA" ]; then
    printf "%s[FLAGGED / CAPTCHA DETECTED]%s\n" "$C_R" "$C_0"
  else
    printf "%s[%s]%s\n" "$C_Y" "$g_stat" "$C_0"
  fi

  printf "Testing OpenAI / ChatGPT Access... "
  local o_stat
  o_stat=$(check_openai)
  if [ "$o_stat" = "UNLOCKED" ]; then
    printf "%s[UNLOCKED / ACCESSIBLE]%s\n" "$C_G" "$C_0"
  elif [ "$o_stat" = "BLOCKED" ]; then
    printf "%s[BLOCKED / RESTRICTED]%s\n" "$C_R" "$C_0"
  else
    printf "%s[%s]%s\n" "$C_Y" "$o_stat" "$C_0"
  fi

  printf "Testing Netflix Streaming Status... "
  local n_stat
  n_stat=$(check_netflix)
  if [ "$n_stat" = "UNLOCKED" ]; then
    printf "%s[UNLOCKED]%s\n" "$C_G" "$C_0"
  elif [ "$n_stat" = "BLOCKED" ]; then
    printf "%s[BLOCKED / GEO-LOCKED]%s\n" "$C_R" "$C_0"
  else
    printf "%s[%s]%s\n" "$C_Y" "$n_stat" "$C_0"
  fi

  printf "Testing Cloudflare WARP Status... "
  local w_stat
  w_stat=$(check_warp_status)
  if [ "$w_stat" = "ACTIVE" ]; then
    printf "%s[RUNNING / ACTIVE]%s\n" "$C_G" "$C_0"
  else
    printf "%s[NOT DETECTED / INACTIVE]%s\n" "$C_Y" "$C_0"
  fi

  printf "\n"
  read -r -p "Press [Enter] to return to menu..." _ || true
}

fix_unban() {
  printf "\n%s=== EXECUTING AUTOMATIC UNBAN & HEALING ===%s\n" "$C_B" "$C_0"
  
  # Step 1: Force IPv4 Precedence (Fixes Google Captchas caused by dirty datacenter IPv6)
  printf "Step 1: Enforcing clean IPv4 resolver precedence... "
  if [ -f "$GAI_CONF" ]; then
    sed -i '/precedence ::ffff:0:0\/96/d' "$GAI_CONF"
  fi
  echo "precedence ::ffff:0:0/96 100" >> "$GAI_CONF"
  printf "%s[ENFORCED]%s\n" "$C_G" "$C_0"

  # Step 2: Flush DNS resolver caches
  printf "Step 2: Purging DNS resolver cache... "
  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    resolvectl flush-caches 2>/dev/null || systemd-resolve --flush-caches 2>/dev/null || true
  fi
  printf "%s[FLUSHED]%s\n" "$C_G" "$C_0"

  # Step 3: Rotate WARP Session if WARP is running
  printf "Step 3: Checking Cloudflare WARP rotation... "
  if command -v warp-cli >/dev/null 2>&1 && warp-cli status 2>/dev/null | grep -q "Connected"; then
    warp-cli rotate-keys >/dev/null 2>&1 || true
    warp-cli disconnect >/dev/null 2>&1 || true
    sleep 2
    warp-cli connect >/dev/null 2>&1 || true
    printf "%s[ROTATED FRESH IP]%s\n" "$C_G" "$C_0"
  elif ip link show 2>/dev/null | grep -q "wgcf"; then
    systemctl restart wg-quick@wgcf 2>/dev/null || true
    printf "%s[RESTARTED WGCF]%s\n" "$C_G" "$C_0"
  else
    printf "%s[WARP not active on server]%s\n" "$C_Y" "$C_0"
  fi

  printf "\n%s[SUCCESS] Unban operations applied without restarting panel or disconnecting users!%s\n\n" "$C_G" "$C_0"

  # Re-verify
  printf "Verifying status:\n"
  local new_google
  new_google=$(check_google)
  if [ "$new_google" = "CLEAN" ]; then
    printf "  * Google Captcha:  %s[RESOLVED - NO CAPTCHA]%s\n" "$C_G" "$C_0"
    notify_telegram "✅ *Google Captcha Auto-Healed!*%0AServer IPv4 precedence applied. Google search is now 100% clean."
  else
    printf "  * Google Captcha:  %s[%s]%s\n" "$C_Y" "$new_google" "$C_0"
  fi

  local new_openai
  new_openai=$(check_openai)
  if [ "$new_openai" = "UNLOCKED" ]; then
    printf "  * OpenAI/ChatGPT:  %s[UNLOCKED / ACCESSIBLE]%s\n" "$C_G" "$C_0"
  else
    printf "  * OpenAI/ChatGPT:  %s[%s]%s\n" "$C_R" "$new_openai" "$C_0"
    printf "\n%s[NOTE FOR CHATGPT]%s If your VPS datacenter IP is directly blacklisted by OpenAI,\n" "$C_Y" "$C_0"
    printf "routing OpenAI traffic through Cloudflare WARP via your 3x-ui panel Outbounds is recommended.\n"
  fi

  printf "\n"
  read -r -p "Press [Enter] to return to menu..." _ || true
}

install_daemon() {
  printf "\n%s=== INSTALLING BACKGROUND AUTO-HEAL DAEMON ===%s\n" "$C_B" "$C_0"

  mkdir -p /opt/omega-boost /opt/omega-boost/scripts
  local src_script
  src_script="$(readlink -f "${BASH_SOURCE[0]}")"
  cp -f "$src_script" "$SCRIPT_PATH"
  cp -f "$src_script" "/opt/omega-boost/scripts/omega-unban.sh" 2>/dev/null || true
  chmod +x "$SCRIPT_PATH" "/opt/omega-boost/scripts/omega-unban.sh" 2>/dev/null || true

  cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Omega VPS Auto-Unban and IP Reputation Healer
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash /opt/omega-boost/omega-unban.sh auto-heal
EOF

  cat <<EOF > "$TIMER_FILE"
[Unit]
Description=Run Omega VPS Auto-Unban every 30 minutes
After=network.target

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl daemon-reload
  systemctl enable --now omega-unban.timer >/dev/null 2>&1
  printf "%s[OK] Auto-Heal Daemon is active! Runs automatically every 30 minutes in background.%s\n\n" "$C_G" "$C_0"
}

remove_daemon() {
  systemctl disable --now omega-unban.timer >/dev/null 2>&1 || true
  rm -f "$SERVICE_FILE" "$TIMER_FILE"
  systemctl daemon-reload
  printf "%s[OK] Auto-Heal Daemon removed.%s\n\n" "$C_G" "$C_0"
}

auto_heal_tick() {
  local g
  g=$(check_google)
  local o
  o=$(check_openai)

  if [ "$g" = "CAPTCHA" ] || [ "$o" = "BLOCKED" ]; then
    fix_unban
  fi
}

menu() {
  while true; do
    local daemon_status="${C_R}Inactive${C_0}"
    if systemctl is-active --quiet omega-unban.timer 2>/dev/null; then
      daemon_status="${C_G}Active (Running every 30 min)${C_0}"
    fi

    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "      %sOMEGA VPS IP REPUTATION & AUTO-UNBAN HEALER%s\n" "$C_W" "$C_0"
    printf "  Background Healer Daemon: %b\n" "$daemon_status"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Test Google Captcha & Streaming Reputation (Instant Audit)\n" "$C_C" "$C_0"
    printf "  %s[2]%s Execute 1-Click IP Unban & Captcha Fix (Manual Run)\n" "$C_C" "$C_0"
    printf "  %s[3]%s Enable 24/7 Background Auto-Healer Daemon (Zero-Touch)\n" "$C_C" "$C_0"
    printf "  %s[4]%s Disable Background Auto-Healer Daemon\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1) run_diagnostics ;;
      2) fix_unban ;;
      3) install_daemon; read -r -p "Press [Enter] to return..." _ || true ;;
      4) remove_daemon; read -r -p "Press [Enter] to return..." _ || true ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

if [ "${1:-}" = "auto-heal" ]; then
  auto_heal_tick
elif [ "${1:-}" = "diagnose" ] || [ "${1:-}" = "--diagnose" ]; then
  run_diagnostics
elif [ "${1:-}" = "fix" ] || [ "${1:-}" = "--fix" ]; then
  fix_unban
elif [ "${1:-}" = "enable" ] || [ "${1:-}" = "--enable" ]; then
  install_daemon
elif [ "${1:-}" = "disable" ] || [ "${1:-}" = "--disable" ]; then
  remove_daemon
else
  menu
fi
