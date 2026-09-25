#!/usr/bin/env bash
#===============================================================================
#  omega-preflight — READ-ONLY preflight audit for OMEGA-Tunnel
#
#  Inspects a foreign VPS that already runs a 3x-ui based panel ("Omega")
#  and reports everything the OMEGA-Tunnel booster needs to know,
#  WITHOUT changing a single thing on the server.
#
#  Safety contract (READ-ONLY):
#    - never touches /etc/x-ui, /usr/local/x-ui, the panel DB or its service
#    - never edits xray configs, never restarts any service
#    - never modifies firewall, sysctl, kernel or network state
#    - the only file it writes is its own text report in /tmp
#    - the panel DB, if readable, is opened strictly in read-only mode
#
#  Usage:
#    sudo bash omega-preflight.sh          # full audit (recommended)
#    bash omega-preflight.sh --no-net      # skip internet probes
#===============================================================================

set -u

VERSION="0.1.0"
NO_NET=0
case "${1:-}" in
  --no-net) NO_NET=1 ;;
  -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
esac

REPORT="/tmp/omega-preflight-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$REPORT") 2>&1

# ---------- pretty helpers ----------------------------------------------------
if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_0=""
fi

OK_COUNT=0; WARN_COUNT=0; ERR_COUNT=0
section(){ printf "\n%s━━ %s ━━%s\n" "$C_B" "$1" "$C_0"; }
ok(){    printf "%s[✓]%s %s\n" "$C_G" "$C_0" "$1"; OK_COUNT=$((OK_COUNT+1)); }
warn(){  printf "%s[!]%s %s\n" "$C_Y" "$C_0" "$1"; WARN_COUNT=$((WARN_COUNT+1)); }
bad(){   printf "%s[✗]%s %s\n" "$C_R" "$C_0" "$1"; ERR_COUNT=$((ERR_COUNT+1)); }
info(){  printf "    %s\n" "$1"; }
have(){  command -v "$1" >/dev/null 2>&1; }

printf "OMEGA-Tunnel preflight v%s  (READ-ONLY audit)\n" "$VERSION"
printf "date: %s   host: %s   user: %s\n" \
  "$(date '+%F %T')" "$(hostname 2>/dev/null || echo '?')" "$(id -un 2>/dev/null || echo '?')"

IS_ROOT=0
[ "$(id -u 2>/dev/null || echo 1)" = "0" ] && IS_ROOT=1
if [ "$IS_ROOT" -ne 1 ]; then
  warn "Not running as root — process names, firewall and panel DB details will be hidden."
  warn "Recommended:  sudo bash $0"
fi

#===============================================================================
section "1) System"
#===============================================================================
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  info "OS: ${PRETTY_NAME:-unknown}"
fi
info "Kernel: $(uname -r 2>/dev/null || echo '?')"
have systemd-detect-virt && info "Virtualization: $(systemd-detect-virt 2>/dev/null || echo 'unknown')"
info "Uptime: $(uptime -p 2>/dev/null || uptime 2>/dev/null | sed 's/^ *//' || echo '?')"
have nproc && info "CPU cores: $(nproc)"
have free  && free -h 2>/dev/null | awk 'NR<=2{printf "    %s\n",$0}'
have df    && df -h / 2>/dev/null | awk 'NR==2{printf "    Disk /: %s used of %s (%s)\n",$3,$2,$5}'

#===============================================================================
section "2) Panel (3x-ui / Omega) detection"
#===============================================================================
XUI_DIR="/usr/local/x-ui"
XUI_DB="/etc/x-ui/x-ui.db"

PANEL_RUNNING=0
if have systemctl; then
  if systemctl is-active --quiet x-ui 2>/dev/null; then
    PANEL_RUNNING=1
    ok "x-ui service: active"
    info "Running since: $(systemctl show -p ActiveEnterTimestamp --value x-ui 2>/dev/null || echo '?')"
  elif systemctl list-unit-files 2>/dev/null | grep -q '^x-ui'; then
    warn "x-ui service installed but NOT active"
  else
    bad "x-ui unit not found via systemctl (checking processes...)"
  fi
fi
if [ "$PANEL_RUNNING" -eq 0 ] && have ps; then
  P="$(ps aux 2>/dev/null | grep -i '[x]-ui' | head -n 3)"
  if [ -n "$P" ]; then
    PANEL_RUNNING=1
    ok "x-ui process detected via ps"
    printf '%s\n' "$P" | awk '{printf "    %s\n",$0}'
  else
    bad "No x-ui process found — is the panel installed on this machine?"
  fi
fi

[ -d "$XUI_DIR" ] && info "Panel dir present: $XUI_DIR"
XR_BIN="$(ls "$XUI_DIR"/bin/xray-linux-* 2>/dev/null | head -n 1 || true)"
if [ -n "$XR_BIN" ] && [ -x "$XR_BIN" ]; then
  info "Xray binary: $XR_BIN"
  info "Xray version: $("$XR_BIN" -version 2>/dev/null | head -n 1 || echo '?')"
fi
[ -f "$XUI_DIR/bin/config.json" ] && \
  info "Panel-managed xray config: $XUI_DIR/bin/config.json (booster will NEVER edit this)"

# --- read-only peek into the panel DB (mode=ro guarantees no locking/writes) ---
DB_OK=0
if have sqlite3 && [ -f "$XUI_DB" ]; then
  dbq(){ sqlite3 "file:$XUI_DB?mode=ro" "$1" 2>/dev/null; }
  if dbq "SELECT 1;" >/dev/null 2>&1; then
    DB_OK=1
    ok "Panel DB found: $XUI_DB  (opened READ-ONLY)"
    W="$(dbq "SELECT value FROM settings WHERE key='webPort';")"
    [ -n "$W" ] && info "Panel web port: $W"
    S="$(dbq "SELECT value FROM settings WHERE key='subPort';")"
    [ -n "$S" ] && info "Subscription port: $S"
    N_ALL="$(dbq "SELECT count(*) FROM inbounds;")"
    N_EN="$(dbq "SELECT count(*) FROM inbounds WHERE enable=1;")"
    [ -n "$N_ALL" ] && info "Inbounds: ${N_EN:-?} enabled / $N_ALL total"
    N_CL="$(dbq "SELECT count(*) FROM client_traffics;")"
    [ -n "$N_CL" ] && info "Client configs: $N_CL"
    dbq "SELECT '    inbound: '||remark||'  |  port '||port||'  |  '||protocol \
         FROM inbounds WHERE enable=1 ORDER BY port;" 2>/dev/null | head -n 40
  fi
fi
if [ "$DB_OK" -eq 0 ]; then
  warn "Panel DB not readable (sqlite3 missing, or panel runs in Docker). Port scan below still applies."
fi

# --- docker-based panel? ------------------------------------------------------
if have docker && docker ps >/dev/null 2>&1; then
  DC="$(docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}' 2>/dev/null | grep -iE 'x-ui|3x-ui|xray' | head -n 5 || true)"
  if [ -n "$DC" ]; then
    warn "Panel appears to run inside Docker — booster will adapt (paths differ):"
    printf '%s\n' "$DC" | awk '{printf "    %s\n",$0}'
  fi
fi

#===============================================================================
section "3) Network stack (what the booster would tune)"
#===============================================================================
CUR_CC="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '?')"
AVAIL_CC="$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null || echo '')"
QDISC="$(sysctl -n net.core.default_qdisc 2>/dev/null || echo '?')"

case " $AVAIL_CC " in
  *" bbr "*) ok "BBR is available in the kernel" ;;
  *) warn "BBR not listed in tcp_available_congestion_control (module may need loading once)" ;;
esac
if [ "$CUR_CC" = "bbr" ]; then
  ok "Congestion control already: bbr"
else
  warn "Congestion control: $CUR_CC  →  booster would switch to bbr (applies live, NO restart needed)"
fi
info "Default qdisc: $QDISC  →  booster would use fq"
info "Available CC algorithms: $AVAIL_CC"
info "rmem_max=$(sysctl -n net.core.rmem_max 2>/dev/null || echo '?')  wmem_max=$(sysctl -n net.core.wmem_max 2>/dev/null || echo '?')"

IFACE="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
if [ -n "$IFACE" ]; then
  info "Default interface: $IFACE  (MTU $(cat "/sys/class/net/$IFACE/mtu" 2>/dev/null || echo '?'))"
  have tc && info "qdisc on $IFACE: $(tc qdisc show dev "$IFACE" 2>/dev/null | head -n 1)"
fi

#===============================================================================
section "4) Listening ports (conflict map for the booster)"
#===============================================================================
if have ss; then
  ss -tulnp ${IS_ROOT:+-p} 2>/dev/null | awk 'NR>1{printf "    %s\n",$0}' | head -n 60
  echo
  for p in 80 443 8443 2053 2083 2087 2096; do
    if ss -tlnH "sport = :$p" 2>/dev/null | grep -q .; then
      warn "TCP $p IN USE  →  booster will never touch it"
    else
      ok "TCP $p free"
    fi
  done
  if ss -ulnH "sport = :443" 2>/dev/null | grep -q .; then
    warn "UDP 443 IN USE"
  else
    ok "UDP 443 free  →  candidate for an isolated Hysteria2 inbound"
  fi
else
  warn "'ss' not available (iproute2) — cannot build a port map"
fi

#===============================================================================
section "5) Firewall"
#===============================================================================
FW="unknown"
if have ufw && [ "$IS_ROOT" = 1 ]; then
  FW="$(ufw status 2>/dev/null | head -n 1 || echo 'unknown')"
  info "ufw: $FW"
elif have firewall-cmd; then
  FW="$(firewall-cmd --state 2>/dev/null || echo 'inactive/unknown')"
  info "firewalld: $FW"
else
  info "ufw/firewalld not detected"
fi
if have iptables && [ "$IS_ROOT" = 1 ]; then
  N="$(iptables -S 2>/dev/null | wc -l | tr -d ' ')"
  info "iptables rules: $N  (booster policy: APPEND-ONLY, snapshot before any change, never flush)"
fi
have nft && nft list tables 2>/dev/null | sed 's/^/    nft table: /' | head -n 10

#===============================================================================
section "6) Related services & existing booster leftovers"
#===============================================================================
for svc in x-ui xray hysteria hysteria-server sing-box nginx caddy haproxy trojan-go wg-quick dockerd; do
  if have systemctl && systemctl is-active --quiet "$svc" 2>/dev/null; then
    info "active service: $svc"
  fi
done
for d in /etc/hysteria /usr/local/etc/xray /etc/sing-box /root/hysteria /opt/omega-boost; do
  [ -e "$d" ] && info "existing path: $d"
done
true

#===============================================================================
section "7) Connectivity from this server"
#===============================================================================
if [ "$NO_NET" = 1 ]; then
  info "skipped (--no-net)"
else
  if have curl; then
    GEO="$(curl -s --max-time 8 https://ipinfo.io/json 2>/dev/null || true)"
    if [ -n "$GEO" ] && have python3; then
      printf '%s' "$GEO" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(f"    Server IP: {d.get(\"ip\",\"?\")}  |  {d.get(\"city\",\"?\")}, {d.get(\"country\",\"?\")}  |  AS{d.get(\"org\",\"?\")}")' 2>/dev/null \
        || printf '%s\n' "$GEO" | head -n 8 | sed 's/^/    /'
    elif [ -n "$GEO" ]; then
      printf '%s\n' "$GEO" | head -n 8 | sed 's/^/    /'
    else
      warn "Could not fetch geo info (ipinfo.io unreachable from here?)"
    fi
  else
    warn "curl not available"
  fi
  if have ping; then
    for t in 1.1.1.1 4.2.2.4; do
      R="$(ping -c 3 -W 2 "$t" 2>/dev/null | tail -n 1 || true)"
      if [ -n "$R" ]; then info "ping $t: $R"; else warn "ping $t: no reply (ICMP may be blocked — not a problem)"; fi
    done
  fi
fi

#===============================================================================
section "Summary"
#===============================================================================
printf "Results: %s✓ %d ok%s  %s! %d warnings%s  %s✗ %d errors%s\n\n" \
  "$C_G" "$OK_COUNT" "$C_0" "$C_Y" "$WARN_COUNT" "$C_0" "$C_R" "$ERR_COUNT" "$C_0"

if [ "$PANEL_RUNNING" -eq 1 ]; then
  info "Panel detected and running. Nothing on this server was modified by this audit."
  info "The OMEGA-Tunnel booster will be tailored to: free ports above, panel paths, and kernel capabilities."
else
  info "Panel NOT detected as running — double-check you are on the right server."
fi
info "Report saved to: $REPORT"
info "Next step: send this report back so the booster config is generated around your exact port/panel layout."
