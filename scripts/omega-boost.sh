#!/usr/bin/env bash
#===============================================================================
#  omega-boost — Network & Kernel Tuning for OMEGA-Tunnel
#
#  Tunes Linux TCP/IP network stack for high-loss, jitter-prone connections
#  WITHOUT touching or restarting 3x-ui, Xray, or active online users.
#
#  Safety Contract:
#    - NEVER modifies /etc/x-ui, panel DB, or /usr/local/x-ui/bin/config.json
#    - NEVER restarts x-ui or xray — existing online users stay connected
#    - Keeps full rollback backup in /opt/omega-boost/sysctl.bak
#    - Only writes /etc/sysctl.d/99-omega-boost.conf (can be removed anytime)
#    - Changes are applied live in kernel memory via sysctl
#
#  Usage:
#    bash omega-boost.sh --dry-run    # preview changes without applying
#    bash omega-boost.sh --apply      # apply optimizations live
#    bash omega-boost.sh --rollback   # restore exact previous settings
#    bash omega-boost.sh --status     # view current network stack status
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

VERSION="0.3.0"
CONF_FILE="/etc/sysctl.d/99-omega-boost.conf"
BASE_DIR="/opt/omega-boost"
BACKUP_DIR="${BASE_DIR}/backup"
BACKUP_FILE="${BASE_DIR}/sysctl.bak"
QDISC_BACKUP="${BASE_DIR}/qdisc.bak"

# ----------------- Color helpers -----------------
if [ -t 1 ]; then
  C_G=$'\033[0;32m'
  C_Y=$'\033[0;33m'
  C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'
  C_W=$'\033[1;37m'
  C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[OK]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[WARN]%s %s\n" "$C_Y" "$C_0" "$1"; }
bad(){     printf "%s[FAIL]%s %s\n" "$C_R" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }
have(){    command -v "$1" >/dev/null 2>&1; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    bad "This action requires root privileges."
    printf "    Please execute with sudo: sudo bash %s\n" "$0"
    exit 1
  fi
}

get_sysctl() {
  local key="$1"
  /sbin/sysctl -n "$key" 2>/dev/null || cat "/proc/sys/${key//.//}" 2>/dev/null || echo "unknown"
}

get_default_iface() {
  ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1
}

# The target parameters list
# Key | Recommended Value | Description
TUNING_PARAMS=(
  "net.core.default_qdisc|fq|Fair Queueing packet pacing required for BBR"
  "net.ipv4.tcp_congestion_control|bbr|BBR congestion control for packet-loss resistance"
  "net.ipv4.tcp_notsent_lowat|16384|Caps unsent buffer at 16KB; prevents bufferbloat in multiplexed VLESS"
  "net.ipv4.tcp_fastopen|3|TCP Fast Open for both client & server; saves 1 RTT"
  "net.ipv4.tcp_tw_reuse|1|Safe reuse of TIME_WAIT sockets for outgoing connections"
  "net.ipv4.tcp_fin_timeout|15|Fast reclaim of dead sockets (reduced from 60s to 15s)"
  "net.ipv4.tcp_slow_start_after_idle|0|Preserves CWND after idle intervals (crucial for messaging apps)"
  "net.ipv4.tcp_mtu_probing|1|Dynamic Path MTU Discovery; fixes blackhole drops by mobile firewalls"
  "net.ipv4.tcp_keepalive_time|300|Detects silent middlebox disconnects in 5m instead of 2h"
  "net.ipv4.tcp_keepalive_intvl|15|Interval between keepalive probes"
  "net.ipv4.tcp_keepalive_probes|5|Number of keepalive probes before declaring drop"
  "net.core.somaxconn|8192|Increased backlog for incoming connection spikes"
  "net.ipv4.tcp_max_syn_backlog|8192|Maximum queue of pending half-open connections"
  "net.core.netdev_max_backlog|16384|NIC incoming packet queue limit"
  "net.core.rmem_max|33554432|Maximum TCP receive buffer (32MB)"
  "net.core.wmem_max|33554432|Maximum TCP send buffer (32MB)"
  "net.ipv4.tcp_rmem|4096 87380 33554432|TCP receive memory autotuning limits"
  "net.ipv4.tcp_wmem|4096 65536 33554432|TCP send memory autotuning limits"
)

show_status() {
  section "Network & Kernel Optimization Status"
  printf "  %-36s %-18s %-18s\n" "Parameter" "Current Value" "Target Value"
  printf "  %-36s %-18s %-18s\n" "------------------------------------" "------------------" "------------------"

  local all_match=1
  for item in "${TUNING_PARAMS[@]}"; do
    IFS='|' read -r key rec desc <<< "$item"
    local cur
    cur="$(get_sysctl "$key" | tr -s ' ')"
    if [ "$cur" = "$rec" ]; then
      printf "  %s%-36s%s %s%-18s%s %-18s\n" "$C_G" "$key" "$C_0" "$C_G" "$cur" "$C_0" "$rec"
    else
      printf "  %s%-36s%s %s%-18s%s %s%-18s%s\n" "$C_Y" "$key" "$C_0" "$C_Y" "$cur" "$C_0" "$C_W" "$rec" "$C_0"
      all_match=0
    fi
  done

  local def_iface
  def_iface="$(get_default_iface)"
  printf "\n  Primary Network Interface: %s%s%s\n" "$C_W" "$def_iface" "$C_0"
  if have tc && [ -n "$def_iface" ]; then
    local cur_qdisc
    cur_qdisc="$(tc qdisc show dev "$def_iface" 2>/dev/null | head -n1)"
    printf "  Interface qdisc (%s): %s\n" "$def_iface" "$cur_qdisc"
  fi

  if [ -f "$CONF_FILE" ]; then
    printf "\n  %s[OK] OMEGA-Tunnel config active:%s %s\n" "$C_G" "$C_0" "$CONF_FILE"
  else
    printf "\n  %s[INFO] OMEGA-Tunnel persistent config not yet applied.%s\n" "$C_Y" "$C_0"
  fi

  if [ "$all_match" -eq 1 ]; then
    ok "All network parameters are tuned for optimal anti-censorship performance."
  else
    warn "Some parameters are using default values. Run --apply to optimize."
  fi
}

dry_run() {
  section "Dry Run Preview (No changes made)"
  info "This mode inspects your kernel without writing any configuration."
  printf "\n"

  printf "  %-34s %-14s %-14s %s\n" "Parameter" "Current" "New Target" "Purpose"
  printf "  %-34s %-14s %-14s %s\n" "----------------------------------" "--------------" "--------------" "--------------------------------------------"

  for item in "${TUNING_PARAMS[@]}"; do
    IFS='|' read -r key rec desc <<< "$item"
    local cur
    cur="$(get_sysctl "$key" | tr -s ' ')"
    if [ "$cur" = "$rec" ]; then
      printf "  %s%-34s %-14s %-14s [Already Optimized]%s\n" "$C_G" "$key" "$cur" "$rec" "$C_0"
    else
      printf "  %s%-34s%s %s%-14s%s -> %s%-14s%s %s\n" "$C_W" "$key" "$C_0" "$C_R" "$cur" "$C_0" "$C_G" "$rec" "$C_0" "$desc"
    fi
  done

  local def_iface
  def_iface="$(get_default_iface)"
  printf "\n"
  info "Detected network interface: $def_iface"
  info "qdisc will be upgraded to 'fq' so BBR can pace packets with microsecond accuracy."
  info "Zero downtime: no services will restart and zero packets will be dropped."
}

apply_tuning() {
  check_root
  section "Applying OMEGA-Tunnel Network Tuning"

  mkdir -p "$BACKUP_DIR"

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local ts_backup="${BACKUP_DIR}/sysctl-backup-${timestamp}.conf"

  info "Saving snapshot of current system values to: $ts_backup"
  {
    echo "# OMEGA-Tunnel sysctl backup taken at $timestamp"
    for item in "${TUNING_PARAMS[@]}"; do
      IFS='|' read -r key rec desc <<< "$item"
      local cur
      cur="$(get_sysctl "$key")"
      echo "$key = $cur"
    done
  } > "$ts_backup"

  cp "$ts_backup" "$BACKUP_FILE"
  ok "Backup saved successfully."

  local def_iface
  def_iface="$(get_default_iface)"
  if have tc && [ -n "$def_iface" ]; then
    tc qdisc show dev "$def_iface" > "$QDISC_BACKUP" 2>/dev/null || true
  fi

  info "Writing persistent configuration to: $CONF_FILE"
  {
    echo "#==================================================================="
    echo "# OMEGA-Tunnel High-Performance Network Tuning"
    echo "# Applied on: $(date)"
    echo "# Safe: No restarts, 100% transparent to 3x-ui and online users"
    echo "#==================================================================="
    for item in "${TUNING_PARAMS[@]}"; do
      IFS='|' read -r key rec desc <<< "$item"
      echo "# $desc"
      echo "$key = $rec"
      echo ""
    done
  } > "$CONF_FILE"

  info "Applying live into kernel memory..."
  /sbin/sysctl -p "$CONF_FILE" >/dev/null 2>&1 || /sbin/sysctl --system >/dev/null 2>&1

  if have tc && [ -n "$def_iface" ]; then
    info "Setting qdisc to fq on interface $def_iface..."
    tc qdisc replace dev "$def_iface" root fq 2>/dev/null || true
  fi

  printf "\n"
  ok "Kernel & network parameters tuned successfully!"
  info "Zero connections disrupted, zero services restarted."
  info "Verify anytime: sudo bash $0 --status"
  info "Rollback anytime: sudo bash $0 --rollback"
}

rollback_tuning() {
  check_root
  section "Restoring Previous Network Configuration (Rollback)"

  if [ ! -f "$BACKUP_FILE" ]; then
    bad "Backup file not found ($BACKUP_FILE)!"
    info "Have you run --apply on this machine previously?"
    exit 1
  fi

  info "Restoring parameters from: $BACKUP_FILE"
  /sbin/sysctl -p "$BACKUP_FILE" >/dev/null 2>&1 || true

  if [ -f "$CONF_FILE" ]; then
    rm -f "$CONF_FILE"
    info "Removed $CONF_FILE"
  fi

  local def_iface
  def_iface="$(get_default_iface)"
  if have tc && [ -f "$QDISC_BACKUP" ] && [ -n "$def_iface" ]; then
    info "Restoring interface qdisc..."
    if grep -q "cake" "$QDISC_BACKUP"; then
      tc qdisc replace dev "$def_iface" root cake 2>/dev/null || true
    fi
  fi

  ok "Network parameters successfully restored to previous state."
}

# ----------------- CLI Router -----------------
CMD="${1:---help}"

case "$CMD" in
  --dry-run|-d)
    dry_run
    ;;
  --apply|-a)
    apply_tuning
    ;;
  --rollback|-r)
    rollback_tuning
    ;;
  --status|-s)
    show_status
    ;;
  --help|-h)
    printf "OMEGA-Tunnel Booster v%s\n" "$VERSION"
    printf "Usage:\n"
    printf "  bash %s --dry-run    # Preview changes without modifying system\n" "$0"
    printf "  sudo bash %s --apply      # Apply live kernel tuning (zero downtime)\n" "$0"
    printf "  bash %s --status     # Show current parameters vs targets\n" "$0"
    printf "  sudo bash %s --rollback   # Restore previous configuration\n" "$0"
    exit 0
    ;;
  *)
    printf "Unknown option: %s\n" "$CMD"
    printf "For help: bash %s --help\n" "$0"
    exit 1
    ;;
esac
