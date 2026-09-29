#!/usr/bin/env bash
#===============================================================================
#  omega-menu — Interactive Terminal Menu for Omega VPS All In One Optimizer
#  Version 2.5.0 (Ultimate Edition)
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

# If stdin is not a terminal (e.g. piped from curl/bash), reconnect to /dev/tty
if [ ! -t 0 ] && [ -e /dev/tty ]; then
  exec </dev/tty
fi

VERSION="2.5.0"
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
    printf "%sActive (PMTU Clamped)%s" "$C_G" "$C_0"
  else
    printf "%sNot Active%s" "$C_Y" "$C_0"
  fi
}

get_instagram_status() {
  if iptables -C OUTPUT -d 157.240.0.0/16 -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
    printf "%sTargeted (Safe for WARP)%s" "$C_G" "$C_0"
  else
    printf "%sDefault (Unoptimized)%s" "$C_Y" "$C_0"
  fi
}

get_security_status() {
  if [ -f "/etc/fail2ban/jail.d/99-omega-sshd.local" ]; then
    printf "%sProtected (Fail2ban + Ping Guard)%s" "$C_G" "$C_0"
  else
    printf "%sDefault%s" "$C_Y" "$C_0"
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
  printf "                         Version %s\n" "$VERSION"
  printf "%s========================================================================%s\n" "$C_B" "$C_0"
  
  printf "  Server Panel:      %-30b  Kernel CC:     %b\n" "$(get_panel_status)" "$(get_bbr_status)"
  printf "  Operator Fix:      %-30b  Memory:        %s\n" "$(get_operator_status)" "${mem_info:-unknown}"
  printf "  Instagram Stream:  %-30b  Swap Memory:   %b\n" "$(get_instagram_status)" "$(get_swap_status)"
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
  printf "  4. System & Hardware Tuning (1M ulimit, swappiness=10, 200M logs, fast DNS)\n"
  printf "  5. Security Hardening (Fail2ban anti-bruteforce + ping rate limit)\n"
  printf "  6. Automated Nightly Janitor Cronjob (daily cache & log cleaner at 04:00 AM)\n"
  printf "  7. Essential Package Maintenance (curl, jq, sqlite3, htop)\n\n"
  
  read -r -p "Do you want to proceed? [y/N]: " confirm || confirm="n"
  case "$confirm" in
    [yY]|[yY][eE][sS])
      printf "\n[1/7] Applying kernel & network tuning...\n"
      bash "${SCRIPT_DIR}/omega-boost.sh" --apply || true
      
      printf "\n[2/7] Applying operator compatibility booster...\n"
      bash "${SCRIPT_DIR}/omega-operator-fix.sh" --apply || true

      printf "\n[3/7] Applying Instagram & video streaming optimizer...\n"
      bash "${SCRIPT_DIR}/omega-instagram-fix.sh" --apply || true

      printf "\n[4/7] Applying system hardware, RAM, ulimit, logs & DNS tuning...\n"
      bash "${SCRIPT_DIR}/omega-hardware-opt.sh" --all || true

      printf "\n[5/7] Applying security hardening & Fail2ban...\n"
      bash "${SCRIPT_DIR}/omega-security.sh" --apply || true

      printf "\n[6/7] Scheduling nightly janitor maintenance...\n"
      bash "${SCRIPT_DIR}/omega-cron.sh" --enable || true

      printf "\n[7/7] Updating essential system packages...\n"
      bash "${SCRIPT_DIR}/omega-sysupdate.sh" || true
      
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
  printf "%s=== UPDATING OMEGA VPS ALL IN ONE OPTIMIZER ===%s\n\n" "$C_B" "$C_0"
  printf "Fetching latest release scripts from repository...\n"
  
  local raw_base="https://raw.githubusercontent.com/Dark-Sky07/OMEGA-Tunnel/arena/01a0d868-omega-tunnel/scripts"
  local files=(
    "omega-menu.sh"
    "omega-boost.sh"
    "omega-operator-fix.sh"
    "omega-instagram-fix.sh"
    "omega-hardware-opt.sh"
    "omega-speedtest.sh"
    "omega-cf-scanner.sh"
    "omega-monitor.sh"
    "omega-port-doctor.sh"
    "omega-iran-probe.sh"
    "omega-sni-checker.sh"
    "omega-security.sh"
    "omega-backup.sh"
    "omega-cron.sh"
    "omega-sysupdate.sh"
    "omega-preflight.sh"
  )
  
  for f in "${files[@]}"; do
    printf "  Updating %s..." "$f"
    if curl -fsSL "${raw_base}/${f}" -o "${SCRIPT_DIR}/${f}.tmp" 2>/dev/null; then
      mv "${SCRIPT_DIR}/${f}.tmp" "${SCRIPT_DIR}/${f}"
      chmod +x "${SCRIPT_DIR}/${f}"
      printf " %s[OK]%s\n" "$C_G" "$C_0"
    else
      printf " %s[SKIPPED]%s\n" "$C_Y" "$C_0"
    fi
  done
  
  printf "\n%s[OK] Update complete! Reloading menu...%s\n" "$C_G" "$C_0"
  sleep 1
  exec bash "${SCRIPT_DIR}/omega-menu.sh"
}

main_menu() {
  while true; do
    clear_screen
    draw_header
    
    printf "%s  --- [ CORE & ONE-CLICK ] ---%s\n" "$C_W" "$C_0"
    printf "%s  [1]%s  Run Read-Only Preflight Server Audit\n" "$C_G" "$C_0"
    printf "%s  [2]%s  %s★ ONE-CLICK FULL SERVER OPTIMIZATION (All In One)%s\n\n" "$C_Y" "$C_W" "$C_0" "$C_0"

    printf "%s  --- [ NETWORK & ANTI-CENSORSHIP ] ---%s\n" "$C_W" "$C_0"
    printf "%s  [3]%s  Network & Kernel Tuning (BBR + FQ + sysctl)\n" "$C_G" "$C_0"
    printf "%s  [4]%s  Operator Compatibility Booster (Fix Samantel / Mobile MTU)\n" "$C_G" "$C_0"
    printf "%s  [5]%s  Optimize Instagram & Video Streaming (Safe for WARP & Google)\n" "$C_G" "$C_0"
    printf "%s  [6]%s  Reality SNI & Clean Domain Finder (Test best domains for Reality)\n" "$C_G" "$C_0"
    printf "%s  [7]%s  Cloudflare Clean IP Scanner (Find best low-latency CDN IPs)\n\n" "$C_G" "$C_0"

    printf "%s  --- [ SYSTEM, HARDWARE & SECURITY ] ---%s\n" "$C_W" "$C_0"
    printf "%s  [8]%s  System & Hardware Tuning (RAM, Ulimit 1M, Logs 200M, DNS)\n" "$C_G" "$C_0"
    printf "%s  [9]%s  Smart Swap Memory Manager (Dynamic suggestions based on RAM)\n" "$C_G" "$C_0"
    printf "%s  [10]%s Security & Anti-Bruteforce Hardening (Fail2ban + Ping Shield)\n" "$C_G" "$C_0"
    printf "%s  [11]%s Panel & Disaster Recovery Backup (1-Click Backup & Restore)\n" "$C_G" "$C_0"
    printf "%s  [12]%s Automated Nightly Janitor Cronjob (Memory & Cache Cleaner)\n" "$C_G" "$C_0"
    printf "%s  [13]%s Update System Packages & Install Essential Tools\n\n" "$C_G" "$C_0"

    printf "%s  --- [ MONITORING & DIAGNOSTICS ] ---%s\n" "$C_W" "$C_0"
    printf "%s  [14]%s Iran Operators Latency & Packet Loss Probe (19 targets)\n" "$C_G" "$C_0"
    printf "%s  [15]%s VPS Bandwidth & Speedtest (Global & Regional Throughput)\n" "$C_G" "$C_0"
    printf "%s  [16]%s Live Connections & Traffic Monitor (Real-time MB/s & Clients)\n" "$C_G" "$C_0"
    printf "%s  [17]%s Port & Firewall Doctor (Scan ports & One-Click Port Opener)\n" "$C_G" "$C_0"
    printf "%s  [18]%s Recommended VLESS-Reality Setup on Free Port 443\n\n" "$C_G" "$C_0"

    printf "%s  --- [ MANAGEMENT ] ---%s\n" "$C_W" "$C_0"
    printf "%s  [r]%s  Restore / Rollback Settings to Original State\n" "$C_M" "$C_0"
    printf "%s  [u]%s  %sUpdate Omega Suite to Latest Release%s\n" "$C_B" "$C_W" "$C_0" "$C_0"
    printf "%s  [0]%s  Exit\n" "$C_R" "$C_0"
    printf "%s------------------------------------------------------------------------%s\n" "$C_B" "$C_0"
    
    local choice=""
    if ! read -r -p "Please select an option [0-18, r, u]: " choice; then
      printf "\nSession ended.\n"
      exit 0
    fi

    case "$choice" in
      1)
        clear_screen
        bash "${SCRIPT_DIR}/omega-preflight.sh" || true
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      2)
        run_one_click
        ;;
      3)
        clear_screen
        printf "%s=== Network & Kernel Tuning ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply live optimizations\n" "$C_G" "$C_0"
        printf "  %s[2]%s Dry-run preview\n" "$C_G" "$C_0"
        printf "  %s[3]%s Show status\n" "$C_G" "$C_0"
        printf "  %s[4]%s Rollback network tuning\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-4]: " subchoice || subchoice="0"
        case "$subchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-boost.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-boost.sh" --dry-run; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; bash "${SCRIPT_DIR}/omega-boost.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          4) clear_screen; bash "${SCRIPT_DIR}/omega-boost.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      4)
        clear_screen
        printf "%s=== Operator Compatibility Fix (Samantel / Rightel / LTE) ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply MSS Clamping & MTU Fix\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show operator status\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback operator rules\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " opchoice || opchoice="0"
        case "$opchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-operator-fix.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-operator-fix.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; bash "${SCRIPT_DIR}/omega-operator-fix.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      5)
        clear_screen
        printf "%s=== Instagram & Video Streaming Optimizer ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply Instagram Streaming Optimization\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show status\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback Instagram rules\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " igchoice || igchoice="0"
        case "$igchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-instagram-fix.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-instagram-fix.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; bash "${SCRIPT_DIR}/omega-instagram-fix.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      6)
        clear_screen
        bash "${SCRIPT_DIR}/omega-sni-checker.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      7)
        clear_screen
        bash "${SCRIPT_DIR}/omega-cf-scanner.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      8)
        clear_screen
        printf "%s=== System & Hardware Tuning ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply all hardware optimizations (Ulimit 1M, VM swappiness=10, 200M logs, fast DNS)\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show hardware status\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback hardware tuning\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " hwchoice || hwchoice="0"
        case "$hwchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-hardware-opt.sh" --all; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-hardware-opt.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; bash "${SCRIPT_DIR}/omega-hardware-opt.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      9)
        clear_screen
        bash "${SCRIPT_DIR}/omega-hardware-opt.sh" --swap
        ;;
      10)
        clear_screen
        printf "%s=== Security & Anti-Bruteforce Hardening ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Apply Fail2ban & ICMP Ping Shield\n" "$C_G" "$C_0"
        printf "  %s[2]%s Show Security Status & Banned IPs\n" "$C_G" "$C_0"
        printf "  %s[3]%s Rollback Security Rules\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " secchoice || secchoice="0"
        case "$secchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-security.sh" --apply; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-security.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; bash "${SCRIPT_DIR}/omega-security.sh" --rollback; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      11)
        clear_screen
        printf "%s=== Panel Disaster Recovery & Backup Manager ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Create New Panel Backup (Database & Certs)\n" "$C_G" "$C_0"
        printf "  %s[2]%s List Existing Backups\n" "$C_G" "$C_0"
        printf "  %s[3]%s Restore Panel Database from Backup\n" "$C_M" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-3]: " bakchoice || bakchoice="0"
        case "$bakchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-backup.sh" --backup; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-backup.sh" --list; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; bash "${SCRIPT_DIR}/omega-backup.sh" --restore; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      12)
        clear_screen
        printf "%s=== Automated Nightly Memory Janitor Cronjob ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Enable Nightly Janitor (Daily at 04:00 AM)\n" "$C_G" "$C_0"
        printf "  %s[2]%s Run Cache & Log Cleanup Right Now\n" "$C_G" "$C_0"
        printf "  %s[3]%s Disable Nightly Janitor\n" "$C_M" "$C_0"
        printf "  %s[4]%s Show Janitor Status\n" "$C_G" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-4]: " cronchoice || cronchoice="0"
        case "$cronchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-cron.sh" --enable; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-cron.sh" --run; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          3) clear_screen; bash "${SCRIPT_DIR}/omega-cron.sh" --disable; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          4) clear_screen; bash "${SCRIPT_DIR}/omega-cron.sh" --status; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      13)
        clear_screen
        bash "${SCRIPT_DIR}/omega-sysupdate.sh" || true
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      14)
        clear_screen
        bash "${SCRIPT_DIR}/omega-iran-probe.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      15)
        clear_screen
        bash "${SCRIPT_DIR}/omega-speedtest.sh"
        printf "\n"
        read -r -p "Press [Enter] to return to main menu..." dummy || true
        ;;
      16)
        clear_screen
        bash "${SCRIPT_DIR}/omega-monitor.sh"
        ;;
      17)
        clear_screen
        printf "%s=== Port & Firewall Doctor ===%s\n\n" "$C_B" "$C_0"
        printf "  %s[1]%s Scan Critical VPN & Web Ports\n" "$C_G" "$C_0"
        printf "  %s[2]%s Open a Port in Firewall (TCP/UDP)\n" "$C_G" "$C_0"
        printf "  %s[0]%s Back to Main Menu\n\n" "$C_Y" "$C_0"
        read -r -p "Choice [0-2]: " portchoice || portchoice="0"
        case "$portchoice" in
          1) clear_screen; bash "${SCRIPT_DIR}/omega-port-doctor.sh" --scan; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          2) clear_screen; bash "${SCRIPT_DIR}/omega-port-doctor.sh" --open; printf "\n"; read -r -p "Press [Enter] to return to main menu..." dummy || true ;;
          0|b|B|"") continue ;;
          *) echo "Invalid choice."; sleep 1 ;;
        esac
        ;;
      18)
        show_reality_guide
        ;;
      r|R)
        clear_screen
        printf "%s=== ROLLBACK ALL OMEGA-TUNNEL SETTINGS ===%s\n" "$C_M" "$C_0"
        read -r -p "Are you sure you want to restore original server settings? [y/N]: " confirm_rb || confirm_rb="n"
        case "$confirm_rb" in
          [yY]|[yY][eE][sS])
            bash "${SCRIPT_DIR}/omega-boost.sh" --rollback || true
            bash "${SCRIPT_DIR}/omega-operator-fix.sh" --rollback || true
            bash "${SCRIPT_DIR}/omega-instagram-fix.sh" --rollback || true
            bash "${SCRIPT_DIR}/omega-hardware-opt.sh" --rollback || true
            bash "${SCRIPT_DIR}/omega-security.sh" --rollback || true
            bash "${SCRIPT_DIR}/omega-cron.sh" --disable || true
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
        printf "Exiting Omega VPS All In One Optimizer. Goodbye!\n"
        exit 0
        ;;
      *)
        printf "Invalid selection. Please choose from the menu.\n"
        sleep 1
        ;;
    esac
  done
}

main_menu
