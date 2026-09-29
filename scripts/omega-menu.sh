#!/usr/bin/env bash
#===============================================================================
#  omega — Omega VPS All In One Optimizer Interactive TUI Menu
#  Version: 3.0.0 (Grand Master Edition)
#
#  100% English Terminal Output to guarantee pristine rendering across all
#  SSH clients, mobile terminals (Termius, JuiceSSH), and web consoles.
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

VERSION="3.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${SCRIPT_DIR}/omega-watchdog.sh" ] || SCRIPT_DIR="/opt/omega-boost/scripts"
[ -f "${SCRIPT_DIR}/omega-watchdog.sh" ] || SCRIPT_DIR="/opt/omega-boost"

# Helper to find and run modular sub-scripts safely
run_subscript() {
  local script_name="$1"
  shift
  local full_target=""

  if [ -f "${SCRIPT_DIR}/${script_name}" ]; then
    full_target="${SCRIPT_DIR}/${script_name}"
  elif [ -f "/opt/omega-boost/scripts/${script_name}" ]; then
    full_target="/opt/omega-boost/scripts/${script_name}"
  elif [ -f "/opt/omega-boost/${script_name}" ]; then
    full_target="/opt/omega-boost/${script_name}"
  fi

  if [ -n "$full_target" ] && [ -f "$full_target" ]; then
    bash "$full_target" "$@"
  else
    printf "\n%s[ERROR] Script %s not found on system!%s\n" "$C_R" "$script_name" "$C_0"
    printf "Please update by pressing 'u' or running the installer.\n\n"
    read -r -p "Press [Enter] to continue..." _ || true
  fi
}

# Color codes
if [ -t 1 ]; then
  C_0=$'\033[0m'
  C_R=$'\033[0;31m'
  C_G=$'\033[0;32m'
  C_Y=$'\033[0;33m'
  C_B=$'\033[1;34m'
  C_M=$'\033[0;35m'
  C_C=$'\033[0;36m'
  C_W=$'\033[1;37m'
else
  C_0=""; C_R=""; C_G=""; C_Y=""; C_B=""; C_M=""; C_C=""; C_W=""
fi

clear_screen() {
  clear 2>/dev/null || printf "\033c"
}

get_panel_status() {
  if systemctl is-active --quiet x-ui >/dev/null 2>&1; then
    printf "%sRunning (Safe & Untouched)%s" "$C_G" "$C_0"
  elif systemctl is-active --quiet 3x-ui >/dev/null 2>&1; then
    printf "%sRunning (Safe & Untouched)%s" "$C_G" "$C_0"
  elif [ -d "/usr/local/x-ui" ]; then
    printf "%sInstalled (Inactive)%s" "$C_Y" "$C_0"
  else
    printf "%sNot Detected%s" "$C_W" "$C_0"
  fi
}

get_bbr_status() {
  local cc
  cc="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")"
  local qdisc
  qdisc="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown")"
  if [ "$cc" = "bbr" ]; then
    printf "%sActive (BBR + %s)%s" "$C_G" "$qdisc" "$C_0"
  else
    printf "%sInactive (%s)%s" "$C_Y" "$cc" "$C_0"
  fi
}

get_operator_status() {
  if iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1; then
    printf "%sActive (PMTU Clamped)%s" "$C_G" "$C_0"
  else
    printf "%sInactive%s" "$C_Y" "$C_0"
  fi
}

get_instagram_status() {
  if [ -f "/opt/omega-boost/instagram-active.flag" ] || iptables -C OUTPUT -d "157.240.0.0/16" -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
    printf "%sTargeted (Safe for WARP)%s" "$C_G" "$C_0"
  else
    printf "%sInactive%s" "$C_Y" "$C_0"
  fi
}

get_security_status() {
  if systemctl is-active --quiet fail2ban >/dev/null 2>&1; then
    printf "%sProtected (Fail2ban + Ping)%s" "$C_G" "$C_0"
  else
    printf "%sDefault%s" "$C_Y" "$C_0"
  fi
}

get_watchdog_status() {
  if systemctl is-active --quiet omega-watchdog.service >/dev/null 2>&1 || pgrep -f "omega-watchdog.sh daemon" >/dev/null 2>&1; then
    printf "%sActive (Guarded)%s" "$C_G" "$C_0"
  else
    printf "%sInactive%s" "$C_Y" "$C_0"
  fi
}

get_unban_status() {
  if systemctl is-active --quiet omega-unban.timer >/dev/null 2>&1; then
    printf "%sActive (Auto-Heal)%s" "$C_G" "$C_0"
  else
    printf "%sManual%s" "$C_Y" "$C_0"
  fi
}

get_swap_status() {
  local swap_kb
  swap_kb="$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")"
  local swap_gb=$(( swap_kb / 1048576 ))
  if [ "$swap_gb" -gt 0 ]; then
    printf "%s%d GB Active%s" "$C_G" "$swap_gb" "$C_0"
  else
    printf "%sNone%s" "$C_Y" "$C_0"
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

  printf "%s========================================================================%s\n" "$C_B" "$C_0"
  printf "%s                  ____  __  __ _____ ____    _   %s\n" "$C_B" "$C_0"
  printf "%s                 / __ \|  \/  | ____/ ___|  / \  %s\n" "$C_B" "$C_0"
  printf "%s                | |  | | |\/| |  _|| |  _  / _ \ %s\n" "$C_B" "$C_0"
  printf "%s                | |__| | |  | | |__| |_| |/ ___ \%s\n" "$C_B" "$C_0"
  printf "%s                 \____/|_|  |_|_____\____/_/   \_\\%s\n\n" "$C_B" "$C_0"
  printf "%s  __     ______  ____     ___        _   _           _             %s\n" "$C_B" "$C_0"
  printf "%s  \ \   / /  _ \/ ___|   / _ \ _ __ | |_(_)_ __ ___ (_)_______ _ __%s\n" "$C_B" "$C_0"
  printf "%s   \ \ / /| |_) \___ \  | | | | '_ \| __| | '_ \` _ \| |_  / _ \ '__|%s\n" "$C_B" "$C_0"
  printf "%s    \ V / |  __/ ___) | | |_| | |_) | |_| | | | | | | |/ /  __/ |  %s\n" "$C_B" "$C_0"
  printf "%s     \_/  |_|   |____/   \___/| .__/ \__|_|_| |_| |_|_/___\___|_|  %s\n" "$C_B" "$C_0"
  printf "%s                              |_|                                  %s\n" "$C_B" "$C_0"
  printf "                   %sAll In One Server Suite%s\n" "$C_W" "$C_0"
  printf "                         Version %s (Grand Master)\n" "$VERSION"
  printf "%s========================================================================%s\n" "$C_B" "$C_0"
  
  printf "  Server Panel:      %-30b  Kernel CC:     %b\n" "$(get_panel_status)" "$(get_bbr_status)"
  printf "  Operator Fix:      %-30b  Memory:        %s\n" "$(get_operator_status)" "${mem_info:-unknown}"
  printf "  Instagram Stream:  %-30b  Swap Memory:   %b\n" "$(get_instagram_status)" "$(get_swap_status)"
  printf "  Watchdog Guard:    %-30b  Unban Healer:  %b\n" "$(get_watchdog_status)" "$(get_unban_status)"
  printf "  Security Guard:    %-30b  TCP 443:       %b\n" "$(get_security_status)" "$(get_port_status 443 tcp)"
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
  printf "  * Target / SNI:     %sgateway.icloud.com:443%s or %sdl.google.com:443%s\n" "$C_G" "$C_0" "$C_G" "$C_0"
  printf "  * ShortIds:         Click 'Generate' in panel (e.g. 8-byte hex)\n"
  printf "  * Flow:             %sxtls-rprx-vision%s\n\n" "$C_G" "$C_0"

  printf "%s  Why this works for tough operators like Samantel:%s\n" "$C_Y" "$C_0"
  printf "  1. Samantel blocks random high ports (like 8444, 8446) but permits Port 443.\n"
  printf "  2. The PMTU Clamping fix in Omega Optimizer prevents mobile MTU fragmentation drops.\n"
  printf "  3. Reality uses authentic foreign TLS certificates that pass DPI inspection.\n\n"
  
  read -r -p "Press [Enter] to return to main menu..." dummy || true
}

run_one_click() {
  clear_screen
  printf "%s=== ONE-CLICK FULL SERVER OPTIMIZATION ===%s\n" "$C_B" "$C_0"
  printf "This will run all core optimizations together safely:\n"
  printf "  1. Network & Kernel Tuning (BBR + FQ + sysctl buffer tuning)\n"
  printf "  2. Operator Compatibility Booster (Samantel/Mobile PMTU Clamping)\n"
  printf "  3. Instagram & Streaming Optimizer (Targeted QUIC Rejection + fast TCP)\n"
  printf "  4. Smart Anti-Pollution DNS Cache & Anycast Resolvers\n"
  printf "  5. System & Hardware Tuning (1M ulimit, swappiness=10, 200M logs)\n"
  printf "  6. Security Hardening (Fail2ban anti-bruteforce + ping rate limit)\n"
  printf "  7. IP Reputation & Google Captcha Auto-Unban Healer Daemon\n"
  printf "  8. 24/7 Panel & Xray Auto-Healing Watchdog Daemon\n"
  printf "  9. Automated Nightly Janitor Cronjob (daily cache & log cleaner at 04:00 AM)\n"
  printf " 10. Essential Package Maintenance (curl, jq, sqlite3, htop)\n\n"
  
  read -r -p "Do you want to proceed? [y/N]: " confirm || confirm="n"
  case "$confirm" in
    [yY]|[yY][eE][sS])
      printf "\n[1/10] Applying kernel & network tuning...\n"
      run_subscript "omega-boost.sh" --apply || true
      
      printf "\n[2/10] Applying operator compatibility booster...\n"
      run_subscript "omega-operator-fix.sh" --apply || true

      printf "\n[3/10] Applying Instagram & video streaming optimizer...\n"
      run_subscript "omega-instagram-fix.sh" --apply || true

      printf "\n[4/10] Applying smart anti-pollution DNS cache...\n"
      run_subscript "omega-dns.sh" apply || true

      printf "\n[5/10] Applying system hardware, RAM, ulimit, & logs tuning...\n"
      run_subscript "omega-hardware-opt.sh" --all || true

      printf "\n[6/10] Applying security hardening & Fail2ban...\n"
      run_subscript "omega-security.sh" --apply || true

      printf "\n[7/10] Activating background Google/ChatGPT auto-unban daemon...\n"
      run_subscript "omega-unban.sh" enable || true

      printf "\n[8/10] Enabling 24/7 panel & Xray auto-healing watchdog...\n"
      run_subscript "omega-watchdog.sh" enable || true

      printf "\n[9/10] Scheduling nightly janitor maintenance...\n"
      run_subscript "omega-cron.sh" --enable || true

      printf "\n[10/10] Updating essential system packages...\n"
      run_subscript "omega-sysupdate.sh" || true
      
      printf "\n%s[SUCCESS] Full Server Optimization Completed!%s\n" "$C_G" "$C_0"
      ;;
    *)
      printf "Aborted.\n"
      ;;
  esac
  printf "\n"
  read -r -p "Press [Enter] to return to main menu..." dummy || true
}

update_suite() {
  clear_screen
  printf "%s=== UPDATING OMEGA VPS OPTIMIZER TO LATEST RELEASE ===%s\n\n" "$C_B" "$C_0"
  printf "Fetching the latest release scripts from repository...\n"
  curl -fsSL https://raw.githubusercontent.com/Dark-Sky07/OMEGA-Tunnel/arena/01a0d868-omega-tunnel/install.sh | bash
  printf "\n%s[OK] Update complete. Restarting menu in 2 seconds...%s\n" "$C_G" "$C_0"
  sleep 2
  exec /usr/local/bin/omega
}

main_menu() {
  while true; do
    clear_screen
    draw_header

    printf "  %s--- [ CORE & ONE-CLICK ] ---%s\n" "$C_C" "$C_0"
    printf "  %s[1]%s  Run Read-Only Preflight Server Audit\n" "$C_G" "$C_0"
    printf "  %s[2]%s  %s★ ONE-CLICK FULL SERVER OPTIMIZATION (All In One)%s\n\n" "$C_Y" "$C_0" "$C_W" "$C_0"

    printf "  %s--- [ NETWORK & ANTI-CENSORSHIP ] ---%s\n" "$C_C" "$C_0"
    printf "  %s[3]%s  Network & Kernel Tuning (BBR + FQ + sysctl)\n" "$C_G" "$C_0"
    printf "  %s[4]%s  Operator Compatibility Booster (Fix Samantel / Mobile MTU)\n" "$C_G" "$C_0"
    printf "  %s[5]%s  Optimize Instagram & Video Streaming (Safe for WARP & Google)\n" "$C_G" "$C_0"
    printf "  %s[6]%s  Reality SNI & Clean Domain Finder (Test best domains for Reality)\n" "$C_G" "$C_0"
    printf "  %s[7]%s  Cloudflare Clean IP Scanner (Find best low-latency CDN IPs)\n" "$C_G" "$C_0"
    printf "  %s[8]%s  Smart Anti-Pollution DNS Cache (High-speed zero-poisoning Anycast)\n\n" "$C_G" "$C_0"

    printf "  %s--- [ SYSTEM, HARDWARE & REPUTATION ] ---%s\n" "$C_C" "$C_0"
    printf "  %s[9]%s  System & Hardware Tuning (RAM, Ulimit 1M, Logs 200M)\n" "$C_G" "$C_0"
    printf "  %s[10]%s Smart Swap Memory Manager (Dynamic suggestions based on RAM)\n" "$C_G" "$C_0"
    printf "  %s[11]%s IP Reputation & Google/ChatGPT Unban Healer (Auto-Remediation)\n" "$C_G" "$C_0"
    printf "  %s[12]%s Security & Anti-Bruteforce Hardening (Fail2ban + Ping Shield)\n" "$C_G" "$C_0"
    printf "  %s[13]%s Panel & Disaster Recovery Backup (1-Click Backup & Restore)\n" "$C_G" "$C_0"
    printf "  %s[14]%s Automated Nightly Janitor Cronjob (Memory & Cache Cleaner)\n" "$C_G" "$C_0"
    printf "  %s[15]%s Update System Packages & Install Essential Tools\n\n" "$C_G" "$C_0"

    printf "  %s--- [ SELF-HEALING & ALERTS ] ---%s\n" "$C_C" "$C_0"
    printf "  %s[16]%s 24/7 Panel & Xray Core Auto-Healing Watchdog (Zero-Downtime)\n" "$C_G" "$C_0"
    printf "  %s[17]%s Telegram Bot Instant Alerts (Crashes, Unbans, & Backups)\n\n" "$C_G" "$C_0"

    printf "  %s--- [ MONITORING & DIAGNOSTICS ] ---%s\n" "$C_C" "$C_0"
    printf "  %s[18]%s Iran Operators Latency & Packet Loss Probe (19 targets)\n" "$C_G" "$C_0"
    printf "  %s[19]%s Iran-Foreign Tunnel & Bridge Health Doctor (Jitter & Loss)\n" "$C_G" "$C_0"
    printf "  %s[20]%s VPS Bandwidth & Speedtest (Global & Regional Throughput)\n" "$C_G" "$C_0"
    printf "  %s[21]%s Live Connections & Traffic Monitor (Real-time MB/s & Clients)\n" "$C_G" "$C_0"
    printf "  %s[22]%s Port & Firewall Doctor (Scan ports & One-Click Port Opener)\n" "$C_G" "$C_0"
    printf "  %s[23]%s Recommended VLESS-Reality Setup on Free Port 443\n\n" "$C_G" "$C_0"

    printf "  %s--- [ MANAGEMENT ] ---%s\n" "$C_C" "$C_0"
    printf "  %s[r]%s  Restore / Rollback Settings to Original State\n" "$C_M" "$C_0"
    printf "  %s[u]%s  Update Omega Suite to Latest Release\n" "$C_C" "$C_0"
    printf "  %s[0]%s  Exit\n" "$C_Y" "$C_0"
    printf "%s------------------------------------------------------------------------%s\n" "$C_B" "$C_0"
    
    read -r -p "Enter your choice: " choice || choice="0"
    case "$choice" in
      1)
        clear_screen
        run_subscript "omega-preflight.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      2)
        run_one_click
        ;;
      3)
        clear_screen
        printf "%s=== Network & Kernel Optimization ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply BBR + FQ + sysctl Network Buffers\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show Current Network & Kernel Status\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback Network Optimizations\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " netchoice || netchoice="0"
        case "$netchoice" in
          1) clear_screen; run_subscript "omega-boost.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-boost.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; run_subscript "omega-boost.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      4)
        clear_screen
        printf "%s=== Operator Compatibility Booster (Samantel / Rightel / LTE Fix) ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply PMTU Clamping (Fixes Samantel & Mobile MTU Drops)\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show Operator Booster Status\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback Operator Booster Rule\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " opchoice || opchoice="0"
        case "$opchoice" in
          1) clear_screen; run_subscript "omega-operator-fix.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-operator-fix.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; run_subscript "omega-operator-fix.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      5)
        clear_screen
        printf "%s=== Instagram & Streaming Acceleration ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply Instagram & Meta Video Speedup (Safe for WARP)\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show Status & Blocked Meta QUIC Packets\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback Instagram Acceleration\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " igchoice || igchoice="0"
        case "$igchoice" in
          1) clear_screen; run_subscript "omega-instagram-fix.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-instagram-fix.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; run_subscript "omega-instagram-fix.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      6)
        clear_screen
        run_subscript "omega-sni-checker.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      7)
        clear_screen
        run_subscript "omega-cf-scanner.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      8)
        clear_screen
        run_subscript "omega-dns.sh"
        ;;
      9)
        clear_screen
        printf "%s=== System & Hardware Tuning ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply all hardware optimizations (Ulimit 1M, VM swappiness=10, 200M logs)\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show hardware status\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback hardware tuning\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " hwchoice || hwchoice="0"
        case "$hwchoice" in
          1) clear_screen; run_subscript "omega-hardware-opt.sh" --all; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-hardware-opt.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; run_subscript "omega-hardware-opt.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      10)
        clear_screen
        run_subscript "omega-hardware-opt.sh" --swap
        ;;
      11)
        clear_screen
        run_subscript "omega-unban.sh"
        ;;
      12)
        clear_screen
        printf "%s=== Security & Anti-Bruteforce Hardening ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply Fail2ban & ICMP Ping Shield\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show Security Status & Banned IPs\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback Security Rules\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " secchoice || secchoice="0"
        case "$secchoice" in
          1) clear_screen; run_subscript "omega-security.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-security.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; run_subscript "omega-security.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      13)
        clear_screen
        printf "%s=== Panel Disaster Recovery & Backup Manager ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Create New Panel Backup (Database & Certs)\n" "$C_G" "$C_0"
        printf "  %s[2]%s List Existing Backups\n" "$C_G" "$C_0"
        printf "  %s[3]%s Restore Panel Database from Backup\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " bakchoice || bakchoice="0"
        case "$bakchoice" in
          1) clear_screen; run_subscript "omega-backup.sh" --backup; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-backup.sh" --list; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; run_subscript "omega-backup.sh" --restore; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      14)
        clear_screen
        printf "%s=== Automated Nightly Memory Janitor Cronjob ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Enable Nightly Janitor (Daily at 04:00 AM)\n" "$C_G" "$C_0"
        printf "  %s[2]%s Run Cache & Log Cleanup Right Now\n" "$C_G" "$C_0"
        printf "  %s[3]%s Disable Nightly Janitor\n" "$C_M" "$C_0"
        printf "  %s[4]%s Show Janitor Status\n" "$C_G" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-4]: " cronchoice || cronchoice="0"
        case "$cronchoice" in
          1) clear_screen; run_subscript "omega-cron.sh" --enable; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-cron.sh" --run; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; run_subscript "omega-cron.sh" --disable; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          4) clear_screen; run_subscript "omega-cron.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      15)
        clear_screen
        run_subscript "omega-sysupdate.sh" || true
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      16)
        clear_screen
        run_subscript "omega-watchdog.sh"
        ;;
      17)
        clear_screen
        run_subscript "omega-telegram.sh"
        ;;
      18)
        clear_screen
        run_subscript "omega-iran-probe.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      19)
        clear_screen
        run_subscript "omega-bridge.sh"
        ;;
      20)
        clear_screen
        run_subscript "omega-speedtest.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      21)
        clear_screen
        run_subscript "omega-monitor.sh"
        ;;
      22)
        clear_screen
        printf "%s=== Port & Firewall Doctor ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Scan Critical VPN & Web Ports\n" "$C_G" "$C_0"
        printf "  %s[2]%s Open a Port in Firewall (TCP/UDP)\n" "$C_G" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-2]: " portchoice || portchoice="0"
        case "$portchoice" in
          1) clear_screen; run_subscript "omega-port-doctor.sh" --scan; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; run_subscript "omega-port-doctor.sh" --open; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      23)
        show_reality_guide
        ;;
      r|R)
        clear_screen
        printf "%s=== ROLLBACK ALL OMEGA-TUNNEL SETTINGS ===%s\n" "$C_M" "$C_0"
        read -r -p "Are you sure you want to restore original server settings? [y/N]: " confirm_rb || confirm_rb="n"
        case "$confirm_rb" in
          [yY]|[yY][eE][sS])
            run_subscript "omega-boost.sh" --rollback || true
            run_subscript "omega-operator-fix.sh" --rollback || true
            run_subscript "omega-instagram-fix.sh" --rollback || true
            run_subscript "omega-hardware-opt.sh" --rollback || true
            run_subscript "omega-security.sh" --rollback || true
            run_subscript "omega-cron.sh" --disable || true
            run_subscript "omega-dns.sh" rollback || true
            run_subscript "omega-watchdog.sh" disable || true
            printf "\n%s[OK] All modifications rolled back cleanly.%s\n" "$C_G" "$C_0"
            ;;
          *)
            printf "Rollback cancelled.\n"
            ;;
        esac
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      u|U)
        update_suite
        ;;
      0|q|Q)
        clear_screen
        printf "Exiting Omega VPS Optimizer. Run '%somega%s' anytime to reopen.\n\n" "$C_G" "$C_0"
        exit 0
        ;;
      *)
        echo "Invalid choice: $choice"
        sleep 1
        ;;
    esac
  done
}

main_menu
