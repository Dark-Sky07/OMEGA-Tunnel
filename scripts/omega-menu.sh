#!/usr/bin/env bash
#===============================================================================
#  omega-menu — Interactive Terminal Menu for OMEGA-Tunnel
#
#  Comprehensive server management, network optimization, operator booster,
#  and system maintenance. 100% English interface for terminal compatibility.
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

VERSION="0.3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="/opt/omega-boost"

# Color helpers
if [ -t 1 ]; then
  C_G=$'\033[0;32m'
  C_Y=$'\033[0;33m'
  C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'
  C_M=$'\033[1;35m'
  C_W=$'\033[1;37m'
  C_DIM=$'\033[2m'
  C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_M=""; C_W=""; C_DIM=""; C_0=""
fi

clear_screen() {
  clear 2>/dev/null || printf "\033c"
}

get_public_ip() {
  curl -s4m 2 https://api.ipify.org || curl -s4m 2 https://icanhazip.com || echo "Unknown"
}

get_bbr_status() {
  local cc
  cc="$(/sbin/sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")"
  local qd
  qd="$(/sbin/sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")"
  if [ "$cc" = "bbr" ] && [ "$qd" = "fq" ]; then
    printf "%sActive (BBR + FQ)%s" "$C_G" "$C_0"
  elif [ "$cc" = "bbr" ]; then
    printf "%sActive (BBR, qdisc: %s)%s" "$C_Y" "$qd" "$C_0"
  else
    printf "%sInactive (%s)%s" "$C_R" "$cc" "$C_0"
  fi
}

get_panel_status() {
  if systemctl is-active --quiet x-ui 2>/dev/null; then
    printf "%sRunning (Safe & Untouched)%s" "$C_G" "$C_0"
  elif [ -d "/usr/local/x-ui" ]; then
    printf "%sInstalled (Inactive)%s" "$C_Y" "$C_0"
  else
    printf "%sNot Detected%s" "$C_DIM" "$C_0"
  fi
}

get_operator_status() {
  if iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1; then
    printf "%sActive (MSS Clamped)%s" "$C_G" "$C_0"
  else
    printf "%sNot Active%s" "$C_Y" "$C_0"
  fi
}

get_port_status() {
  local port="$1"
  local proto="$2"
  if [ "$proto" = "tcp" ]; then
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
      printf "%sIn Use%s" "$C_R" "$C_0"
    else
      printf "%sFREE%s" "$C_G" "$C_0"
    fi
  else
    if ss -ulnp 2>/dev/null | grep -q ":${port} "; then
      printf "%sIn Use%s" "$C_R" "$C_0"
    else
      printf "%sFREE%s" "$C_G" "$C_0"
    fi
  fi
}

draw_header() {
  local mem_info
  mem_info="$(free -h 2>/dev/null | awk '/Mem:/ {print $3 "/" $2}')"
  local load_info
  load_info="$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | xargs)"

  printf "%s========================================================================%s\n" "$C_B" "$C_0"
  printf "%s    ____  __  __ _____ ____    _       _____                             %s\n" "$C_B" "$C_0"
  printf "%s   / __ \|  \/  | ____/ ___|  / \     |_   _|   _ _ __  _ __   ___ _ __  %s\n" "$C_B" "$C_0"
  printf "%s  | |  | | |\/| |  _|| |  _  / _ \      | || | | | '_ \| '_ \ / _ \ '__| %s\n" "$C_B" "$C_0"
  printf "%s  | |__| | |  | | |__| |_| |/ ___ \     | || |_| | | | | | | |  __/ |    %s\n" "$C_B" "$C_0"
  printf "%s   \____/|_|  |_|_____\____/_/   \_\    |_| \__,_|_| |_|_| |_|\___|_|    %s\n" "$C_B" "$C_0"
  printf "          %sServer Booster & Iranian Carrier Anti-Censorship Suite%s\n" "$C_W" "$C_0"
  printf "                         Version %s\n" "$VERSION"
  printf "%s========================================================================%s\n" "$C_B" "$C_0"
  
  printf "  Server Panel:      %-30b  Kernel CC:     %b\n" "$(get_panel_status)" "$(get_bbr_status)"
  printf "  Operator Fix:      %-30b  Memory:        %s\n" "$(get_operator_status)" "${mem_info:-unknown}"
  printf "  TCP Port 443:      %-30b  UDP Port 443:  %b\n" "$(get_port_status 443 tcp)" "$(get_port_status 443 udp)"
  printf "%s------------------------------------------------------------------------%s\n" "$C_B" "$C_0"
}

show_reality_guide() {
  clear_screen
  printf "%s=== RECOMMENDED VLESS + REALITY CONFIGURATION (PORT 443) ===%s\n\n" "$C_B" "$C_0"
  printf "  Port 443 TCP is %b on your server!\n" "$(get_port_status 443 tcp)"
  printf "  Adding an inbound on port 443 inside your 3x-ui panel provides the cleanest\n"
  printf "  and most durable connection for Samantel, Irancell, MCI, and Rightel.\n\n"
  
  printf "%s  Recommended 3x-ui Inbound Settings:%s\n" "$C_W" "$C_0"
  printf "  * Protocol:         %svless%s\n" "$C_G" "$C_0"
  printf "  * Port:             %s443%s (Standard HTTPS port - Never blocked by Samantel)\n" "$C_G" "$C_0"
  printf "  * Transmission:     %stcp%s\n" "$C_G" "$C_0"
  printf "  * Security:         %sreality%s\n" "$C_G" "$C_0"
  printf "  * uTLS:             %schrome%s (or firefox / ios)\n" "$C_G" "$C_0"
  printf "  * Target / SNI:     %swww.yahoo.com:443%s or %sdl.google.com:443%s\n" "$C_G" "$C_0" "$C_G" "$C_0"
  printf "  * ShortIds:         Click 'Generate' in panel (e.g. 8-byte hex)\n"
  printf "  * Flow:             %sxtls-rprx-vision%s\n\n" "$C_G" "$C_0"

  printf "%s  Why this works for tough operators like Samantel:%s\n" "$C_Y" "$C_0"
  printf "  1. Samantel blocks random high ports (like 8444, 8446) but permits Port 443.\n"
  printf "  2. The MSS Clamping fix in OMEGA-Tunnel prevents mobile MTU fragmentation drops.\n"
  printf "  3. Reality uses authentic foreign TLS certificates that pass DPI inspection.\n\n"
  
  read -r -p "Press [Enter] to return to main menu..." dummy
}

run_diagnostics() {
  clear_screen
  printf "%s=== CONNECTION & LATENCY DIAGNOSTICS ===%s\n\n" "$C_B" "$C_0"
  
  printf "1. Ping to Cloudflare DNS (1.1.1.1):\n"
  ping -c 4 1.1.1.1 2>/dev/null || echo "Ping failed"
  
  printf "\n2. Ping to Google DNS (8.8.8.8):\n"
  ping -c 4 8.8.8.8 2>/dev/null || echo "Ping failed"
  
  printf "\n3. DNS Resolution Test (Yahoo & Cloudflare):\n"
  time nslookup www.yahoo.com 2>/dev/null | grep -E "Address|Name" || host www.yahoo.com 2>/dev/null || echo "DNS query finished"

  printf "\n"
  read -r -p "Press [Enter] to return to main menu..." dummy
}

run_one_click() {
  clear_screen
  printf "%s=== ONE-CLICK FULL SERVER OPTIMIZATION ===%s\n" "$C_B" "$C_0"
  printf "This will run:\n"
  printf "  1. System Update & Essential Tools Installation\n"
  printf "  2. Network & Kernel Tuning (BBR + FQ + sysctl buffer tuning)\n"
  printf "  3. Operator Compatibility Booster (Samantel/Mobile MSS Clamping)\n\n"
  
  read -r -p "Do you want to proceed? [y/N]: " confirm
  case "$confirm" in
    [yY]|[yY][eE][sS])
      printf "\n[1/3] Updating system packages...\n"
      bash "${SCRIPT_DIR}/omega-sysupdate.sh" || true
      
      printf "\n[2/3] Applying kernel & network tuning...\n"
      bash "${SCRIPT_DIR}/omega-boost.sh" --apply || true
      
      printf "\n[3/3] Applying operator compatibility booster...\n"
      bash "${SCRIPT_DIR}/omega-operator-fix.sh" --apply || true
      
      printf "\n%s[SUCCESS] One-Click Optimization Completed!%s\n" "$C_G" "$C_0"
      ;;
    *)
      printf "Aborted.\n"
      ;;
  esac
  printf "\n"
  read -r -p "Press [Enter] to return to main menu..." dummy
}

main_menu() {
  while true; do
    clear_screen
    draw_header
    
    printf "%s  [1]%s Run Read-Only Preflight Server Audit\n" "$C_G" "$C_0"
    printf "%s  [2]%s Apply Network & Kernel Tuning (BBR + FQ + sysctl)\n" "$C_G" "$C_0"
    printf "%s  [3]%s Apply Operator Compatibility Booster (Fix Samantel / Mobile MTU)\n" "$C_G" "$C_0"
    printf "%s  [4]%s Update System & Install Essential Tools (curl, jq, sqlite3, htop)\n" "$C_G" "$C_0"
    printf "%s  [5]%s %s★ ONE-CLICK FULL SERVER OPTIMIZATION (Steps 2 + 3 + 4)%s\n" "$C_Y" "$C_W" "$C_0" "$C_0"
    printf "%s  [6]%s Recommended VLESS-Reality Setup on Free Port 443\n" "$C_G" "$C_0"
    printf "%s  [7]%s Connection & Latency Diagnostics\n" "$C_G" "$C_0"
    printf "%s  [8]%s Restore / Rollback Settings to Original State\n" "$C_M" "$C_0"
    printf "%s  [0]%s Exit\n" "$C_R" "$C_0"
    printf "%s------------------------------------------------------------------------%s\n" "$C_B" "$C_0"
    
    read -r -p "Please select an option [0-8]: " choice
    case "$choice" in
      1)
        clear_screen
        bash "${SCRIPT_DIR}/omega-preflight.sh" || true
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy
        ;;
      2)
        clear_screen
        printf "Select action for Network Tuning:\n"
        printf "  [1] Apply live optimizations\n"
        printf "  [2] Dry-run preview\n"
        printf "  [3] Show status\n"
        printf "  [4] Rollback network tuning\n"
        read -r -p "Choice [1-4]: " subchoice
        clear_screen
        case "$subchoice" in
          1) bash "${SCRIPT_DIR}/omega-boost.sh" --apply ;;
          2) bash "${SCRIPT_DIR}/omega-boost.sh" --dry-run ;;
          3) bash "${SCRIPT_DIR}/omega-boost.sh" --status ;;
          4) bash "${SCRIPT_DIR}/omega-boost.sh" --rollback ;;
          *) echo "Invalid choice." ;;
        esac
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy
        ;;
      3)
        clear_screen
        printf "Select action for Operator Compatibility Fix:\n"
        printf "  [1] Apply MSS Clamping & MTU Fix (Samantel / Rightel / LTE)\n"
        printf "  [2] Show operator status\n"
        printf "  [3] Rollback operator rules\n"
        read -r -p "Choice [1-3]: " opchoice
        clear_screen
        case "$opchoice" in
          1) bash "${SCRIPT_DIR}/omega-operator-fix.sh" --apply ;;
          2) bash "${SCRIPT_DIR}/omega-operator-fix.sh" --status ;;
          3) bash "${SCRIPT_DIR}/omega-operator-fix.sh" --rollback ;;
          *) echo "Invalid choice." ;;
        esac
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy
        ;;
      4)
        clear_screen
        bash "${SCRIPT_DIR}/omega-sysupdate.sh" || true
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy
        ;;
      5)
        run_one_click
        ;;
      6)
        show_reality_guide
        ;;
      7)
        run_diagnostics
        ;;
      8)
        clear_screen
        printf "%s=== ROLLBACK ALL OMEGA-TUNNEL SETTINGS ===%s\n" "$C_M" "$C_0"
        read -r -p "Are you sure you want to restore original server settings? [y/N]: " confirm_rb
        case "$confirm_rb" in
          [yY]|[yY][eE][sS])
            bash "${SCRIPT_DIR}/omega-boost.sh" --rollback || true
            bash "${SCRIPT_DIR}/omega-operator-fix.sh" --rollback || true
            printf "\n%s[OK] All modifications rolled back cleanly.%s\n" "$C_G" "$C_0"
            ;;
          *)
            printf "Rollback cancelled.\n"
            ;;
        esac
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy
        ;;
      0|q|Q)
        clear_screen
        printf "Exiting OMEGA-Tunnel menu. Goodbye!\n"
        exit 0
        ;;
      *)
        printf "Invalid selection. Please choose between 0 and 8.\n"
        sleep 1
        ;;
    esac
  done
}

main_menu
