#!/usr/bin/env bash
#===============================================================================
#  omega-port-doctor — Port & Firewall Health Doctor
#  Part of Omega VPS All In One Optimizer
#
#  Features:
#    1. Scans all critical VPN, Proxy, Web and Cloudflare ports.
#    2. Detects listening service and PID.
#    3. One-Click Port Opener (opens port in iptables & UFW).
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

# Color helpers
if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[OK]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[WARN]%s %s\n" "$C_Y" "$C_0" "$1"; }
bad(){     printf "%s[FAIL]%s %s\n" "$C_R" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }
have(){    command -v "$1" >/dev/null 2>&1; }

SCAN_PORTS=(
  "22|tcp|SSH Remote Access"
  "80|tcp|Web (HTTP) / Certbot"
  "443|tcp|HTTPS / VLESS Reality"
  "443|udp|Hysteria 2 / QUIC"
  "8443|tcp|Alternative HTTPS"
  "8444|tcp|Xray Inbound"
  "8446|tcp|Xray Inbound"
  "2053|tcp|Cloudflare HTTPS"
  "2083|tcp|Cloudflare HTTPS"
  "2087|tcp|Cloudflare HTTPS"
  "2096|tcp|Cloudflare HTTPS / Xray"
  "3306|tcp|MySQL / Disguised Inbound"
  "1194|tcp|OpenVPN TCP"
  "1195|udp|OpenVPN UDP"
  "1196|tcp|MTG Telegram Proxy"
  "1701|udp|L2TP VPN"
  "500|udp|IPsec IKEv2"
  "4500|udp|IPsec NAT-T"
  "51820|udp|WireGuard"
)

scan_ports() {
  section "Port & Service Diagnostics Doctor"
  printf "  Scanning critical VPN, Panel, and Web ports on this VPS...\n\n"

  printf "  %-7s %-6s %-10s %-24s %s\n" "Port" "Proto" "Status" "Active Process (PID)" "Description"
  printf "  %-7s %-6s %-10s %-24s %s\n" "-------" "------" "----------" "------------------------" "-------------------------"

  for item in "${SCAN_PORTS[@]}"; do
    IFS='|' read -r port proto desc <<< "$item"

    local status="FREE"
    local color="$C_G"
    local proc_info="--"

    if [ "$proto" = "tcp" ]; then
      local match
      match="$(ss -tlnp 2>/dev/null | grep ":${port} " | head -n1)"
      if [ -n "$match" ]; then
        status="IN USE"
        color="$C_Y"
        proc_info="$(echo "$match" | awk -F'users:' '{print $2}' | tr -d '()"' | awk -F',' '{print $1}' | xargs)"
        [ -z "$proc_info" ] && proc_info="Active Listener"
      fi
    else
      local match
      match="$(ss -ulnp 2>/dev/null | grep ":${port} " | head -n1)"
      if [ -n "$match" ]; then
        status="IN USE"
        color="$C_Y"
        proc_info="$(echo "$match" | awk -F'users:' '{print $2}' | tr -d '()"' | awk -F',' '{print $1}' | xargs)"
        [ -z "$proc_info" ] && proc_info="Active UDP Listener"
      fi
    fi

    printf "  %-7s %-6s %s%-10s%s %-24s %s\n" "$port" "$proto" "$color" "$status" "$C_0" "$proc_info" "$desc"
  done
}

open_port() {
  if [ "$(id -u)" -ne 0 ]; then
    bad "Root privileges required to open firewall ports."
    exit 1
  fi

  section "One-Click Firewall Port Opener"
  read -r -p "Enter Port Number to open (e.g. 443): " port_num || port_num=""
  if ! [[ "$port_num" =~ ^[0-9]+$ ]] || [ "$port_num" -le 0 ] || [ "$port_num" -gt 65535 ]; then
    bad "Invalid port number."
    return 1
  fi

  printf "Protocol: [1] TCP  [2] UDP  [3] BOTH (TCP+UDP)\n"
  read -r -p "Choice [1-3]: " proto_sel || proto_sel="3"

  local do_tcp=0
  local do_udp=0
  case "$proto_sel" in
    1) do_tcp=1 ;;
    2) do_udp=1 ;;
    *) do_tcp=1; do_udp=1 ;;
  esac

  if [ "$do_tcp" -eq 1 ]; then
    if ! iptables -C INPUT -p tcp --dport "$port_num" -j ACCEPT >/dev/null 2>&1; then
      iptables -I INPUT -p tcp --dport "$port_num" -j ACCEPT
      ok "Opened TCP Port $port_num in iptables"
    fi
    if have ufw && ufw status | grep -q "Status: active"; then
      ufw allow "${port_num}/tcp" >/dev/null 2>&1 || true
      ok "Opened TCP Port $port_num in UFW"
    fi
  fi

  if [ "$do_udp" -eq 1 ]; then
    if ! iptables -C INPUT -p udp --dport "$port_num" -j ACCEPT >/dev/null 2>&1; then
      iptables -I INPUT -p udp --dport "$port_num" -j ACCEPT
      ok "Opened UDP Port $port_num in iptables"
    fi
    if have ufw && ufw status | grep -q "Status: active"; then
      ufw allow "${port_num}/udp" >/dev/null 2>&1 || true
      ok "Opened UDP Port $port_num in UFW"
    fi
  fi

  printf "\n"
  ok "Port $port_num is now completely open and accessible!"
}

CMD="${1:---scan}"
case "$CMD" in
  --scan|-s)
    scan_ports
    ;;
  --open|-o)
    open_port
    ;;
  *)
    scan_ports
    ;;
esac
