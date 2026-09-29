#!/usr/bin/env bash
#===============================================================================
#  omega-hardware-opt — Hardware, RAM, Swap, Ulimit & Disk Optimizer
#  Part of Omega VPS All In One Optimizer
#
#  Optimizes:
#    1. Interactive Smart Swap Manager (dynamic suggestions based on RAM)
#    2. Virtual Memory tuning (swappiness=10, dirty ratios for low CPU freeze)
#    3. File Descriptors & Socket limits (1,048,576 file descriptors)
#    4. Journald & SSD Disk log vacuuming (prevents disk bloat)
#    5. Conntrack Table optimization (262,144 table size; prevents drops)
#    6. DNS Caching acceleration (systemd-resolved zero-latency cache)
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"
VM_CONF="/etc/sysctl.d/97-omega-vm.conf"
LIMITS_CONF="/etc/security/limits.d/99-omega-limits.conf"
SYSTEMD_LIMITS_DIR="/etc/systemd/system.conf.d"
SYSTEMD_LIMITS_CONF="${SYSTEMD_LIMITS_DIR}/99-omega-limits.conf"
JOURNAL_DIR="/etc/systemd/journald.conf.d"
JOURNAL_CONF="${JOURNAL_DIR}/99-omega-journal.conf"
RESOLVED_DIR="/etc/systemd/resolved.conf.d"
RESOLVED_CONF="${RESOLVED_DIR}/99-omega-dns.conf"

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

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    bad "Root privileges required."
    printf "    Please execute with sudo: sudo bash %s\n" "$0"
    exit 1
  fi
}

get_ram_gb() {
  local ram_kb
  ram_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "2097152")"
  echo $(( (ram_kb + 1048575) / 1048576 ))
}

get_swap_gb() {
  local swap_kb
  swap_kb="$(awk '/SwapTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo "0")"
  echo $(( swap_kb / 1048576 ))
}

get_free_disk_gb() {
  df -BG / 2>/dev/null | awk 'NR==2 {gsub("G","",$4); print $4}'
}

# ----------------- Swap Manager -----------------
manage_swap() {
  check_root
  section "Smart Swap Memory Manager"
  
  local ram_gb
  ram_gb="$(get_ram_gb)"
  local cur_swap_gb
  cur_swap_gb="$(get_swap_gb)"
  local free_disk
  free_disk="$(get_free_disk_gb)"
  
  printf "  Total Physical RAM:  %s%s GB%s\n" "$C_W" "$ram_gb" "$C_0"
  printf "  Current Active Swap: %s%s GB%s\n" "$C_W" "$cur_swap_gb" "$C_0"
  printf "  Free Disk Space:     %s%s GB%s\n\n" "$C_W" "$free_disk" "$C_0"

  local opt1=$(( ram_gb / 2 ))
  [ "$opt1" -lt 1 ] && opt1=1
  local opt2=$ram_gb
  local opt3=$(( ram_gb * 2 ))

  printf "  Choose Swap Size based on your system specs:\n"
  printf "    %s[1]%s %d GB (Light buffer - recommended for low disk)\n" "$C_G" "$C_0" "$opt1"
  printf "    %s[2]%s %d GB (Standard - 1x RAM, highly recommended)\n" "$C_G" "$C_0" "$opt2"
  printf "    %s[3]%s %d GB (Heavy traffic buffer - 2x RAM)\n" "$C_G" "$C_0" "$opt3"
  printf "    %s[4]%s Custom Size (enter your own value in GB)\n" "$C_G" "$C_0"
  printf "    %s[5]%s Disable / Remove Swap file\n" "$C_R" "$C_0"
  printf "    %s[0]%s Cancel / Back\n\n" "$C_Y" "$C_0"

  read -r -p "  Select option [0-5]: " choice || choice="0"
  local target_gb=0

  case "$choice" in
    1) target_gb=$opt1 ;;
    2) target_gb=$opt2 ;;
    3) target_gb=$opt3 ;;
    4)
      read -r -p "  Enter custom swap size in GB (e.g. 3): " custom_size || custom_size="0"
      if [[ "$custom_size" =~ ^[0-9]+$ ]] && [ "$custom_size" -gt 0 ]; then
        target_gb=$custom_size
      else
        bad "Invalid size entered."
        return 1
      fi
      ;;
    5)
      disable_swap
      return 0
      ;;
    *)
      info "Swap configuration cancelled."
      return 0
      ;;
  esac

  if [ "$target_gb" -gt 0 ]; then
    if [ "$target_gb" -ge "$free_disk" ]; then
      bad "Not enough free disk space ($free_disk GB available, requested $target_gb GB)!"
      return 1
    fi
    create_swap "$target_gb"
  fi
}

create_swap() {
  local size_gb="$1"
  info "Configuring ${size_gb}GB swap file at /swapfile..."
  
  # Deactivate existing swapfile if active
  if swapon --show 2>/dev/null | grep -q "/swapfile"; then
    info "Turning off current /swapfile..."
    swapoff /swapfile 2>/dev/null || true
  fi

  rm -f /swapfile

  # Allocate space
  if have fallocate; then
    fallocate -l "${size_gb}G" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=$((size_gb * 1024)) status=progress
  else
    dd if=/dev/zero of=/swapfile bs=1M count=$((size_gb * 1024)) status=progress
  fi

  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile

  # Persist in /etc/fstab safely
  if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    ok "Added /swapfile to /etc/fstab"
  fi

  ok "${size_gb}GB Swap created and activated successfully!"
}

disable_swap() {
  info "Deactivating and removing /swapfile..."
  if swapon --show 2>/dev/null | grep -q "/swapfile"; then
    swapoff /swapfile 2>/dev/null || true
  fi
  rm -f /swapfile
  sed -i '\|/swapfile|d' /etc/fstab 2>/dev/null || true
  ok "Swap disabled and removed."
}

# ----------------- Virtual Memory Tuning -----------------
tune_vm() {
  check_root
  info "Applying Virtual Memory (RAM) tuning..."
  cat << 'EOF' > "$VM_CONF"
# Omega VPS Virtual Memory Tuning
# Optimizes RAM utilization and avoids CPU freezes during disk writes
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50
EOF
  /sbin/sysctl -p "$VM_CONF" >/dev/null 2>&1 || true
  ok "RAM & Virtual memory parameters optimized (swappiness=10, dirty_ratio=15)."
}

# ----------------- File Limits (Ulimit) -----------------
tune_ulimit() {
  check_root
  info "Optimizing file descriptors and socket limits to 1,048,576..."
  
  # Kernel sysctl
  /sbin/sysctl -w fs.file-max=1048576 >/dev/null 2>&1 || true

  # Security limits
  mkdir -p /etc/security/limits.d
  cat << 'EOF' > "$LIMITS_CONF"
# Omega VPS High Connection Limits
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
* soft nproc 524288
* hard nproc 524288
root soft nproc 524288
root hard nproc 524288
EOF

  # Systemd limits
  mkdir -p "$SYSTEMD_LIMITS_DIR"
  cat << 'EOF' > "$SYSTEMD_LIMITS_CONF"
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=524288
EOF
  systemctl daemon-reexec 2>/dev/null || true
  ok "Connection & file descriptor limits increased to 1,048,576 (No more 'Too many open files')."
}

# ----------------- Journald Log Cleaner -----------------
tune_logs() {
  check_root
  info "Cleaning journal logs and setting 200MB maximum log cap..."
  
  # Vacuum existing logs
  if have journalctl; then
    journalctl --vacuum-time=3d >/dev/null 2>&1 || true
    journalctl --vacuum-size=200M >/dev/null 2>&1 || true
  fi

  # Configure persistent log size cap
  mkdir -p "$JOURNAL_DIR"
  cat << 'EOF' > "$JOURNAL_CONF"
[Journal]
SystemMaxUse=200M
SystemKeepFree=1G
MaxRetentionSec=7day
EOF
  systemctl restart systemd-journald 2>/dev/null || true
  ok "Journald log vacuumed and capped at 200MB (Saved disk space & SSD wear)."
}

# ----------------- Conntrack Optimizer -----------------
tune_conntrack() {
  check_root
  info "Optimizing connection tracking (conntrack) table..."
  
  # Check if nf_conntrack module is loaded or can be loaded
  modprobe nf_conntrack 2>/dev/null || modprobe ip_conntrack 2>/dev/null || true

  cat << 'EOF' > /etc/sysctl.d/96-omega-conntrack.conf
# Omega VPS Conntrack Tuning
net.netfilter.nf_conntrack_max = 262144
net.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_established = 7200
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
EOF
  /sbin/sysctl -p /etc/sysctl.d/96-omega-conntrack.conf >/dev/null 2>&1 || true
  ok "Conntrack table expanded to 262,144 entries with fast socket reclamation."
}

# ----------------- DNS Cache Accelerator -----------------
tune_dns() {
  check_root
  info "Accelerating local DNS cache (systemd-resolved)..."
  
  if systemctl is-active --quiet systemd-resolved 2>/dev/null || [ -d "/etc/systemd" ]; then
    mkdir -p "$RESOLVED_DIR"
    cat << 'EOF' > "$RESOLVED_CONF"
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
FallbackDNS=1.0.0.1 8.8.4.4
Cache=yes
CacheTimeMaxSec=86400
DNSStubListener=yes
EOF
    systemctl restart systemd-resolved 2>/dev/null || true
    ok "DNS Caching active: frequent domains (Instagram/Google/Telegram) resolved in 0ms."
  fi
}

show_status() {
  section "Hardware & System Optimization Status"
  
  local ram_gb
  ram_gb="$(get_ram_gb)"
  local swap_gb
  swap_gb="$(get_swap_gb)"
  local ulimit_val
  ulimit_val="$(ulimit -n 2>/dev/null || echo "unknown")"
  local swappiness_val
  swappiness_val="$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "unknown")"

  printf "  Physical RAM:        %s%s GB%s\n" "$C_W" "$ram_gb" "$C_0"
  printf "  Active Swap:         %s%s GB%s\n" "$C_W" "$swap_gb" "$C_0"
  printf "  Current File Limit:  %s%s%s (Target: 1048576)\n" "$C_W" "$ulimit_val" "$C_0"
  printf "  vm.swappiness:       %s%s%s (Target: 10)\n" "$C_W" "$swappiness_val" "$C_0"

  printf "\n  Configuration files:\n"
  [ -f "$VM_CONF" ] && ok "RAM/VM tuning: ACTIVE ($VM_CONF)" || warn "RAM/VM tuning: Not applied"
  [ -f "$LIMITS_CONF" ] && ok "Ulimit 1M limits: ACTIVE ($LIMITS_CONF)" || warn "Ulimit limits: Default"
  [ -f "$JOURNAL_CONF" ] && ok "Journald 200M cap: ACTIVE ($JOURNAL_CONF)" || warn "Journald log cap: Default"
  [ -f "/etc/sysctl.d/96-omega-conntrack.conf" ] && ok "Conntrack 262k: ACTIVE" || warn "Conntrack: Default"
  [ -f "$RESOLVED_CONF" ] && ok "Fast DNS Caching: ACTIVE" || warn "DNS Caching: Default"
}

apply_all_automated() {
  check_root
  section "Applying All System & Hardware Optimizations"
  tune_vm
  tune_ulimit
  tune_logs
  tune_conntrack
  tune_dns
  printf "\n"
  ok "All hardware & system tuning applied successfully!"
}

rollback_all() {
  check_root
  section "Rolling Back System & Hardware Optimizations"
  rm -f "$VM_CONF" "$LIMITS_CONF" "$SYSTEMD_LIMITS_CONF" "$JOURNAL_CONF" "$RESOLVED_CONF" "/etc/sysctl.d/96-omega-conntrack.conf"
  /sbin/sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
  systemctl restart systemd-journald 2>/dev/null || true
  systemctl restart systemd-resolved 2>/dev/null || true
  ok "System & hardware configurations removed cleanly."
}

# ----------------- CLI Router -----------------
CMD="${1:---status}"
case "$CMD" in
  --swap|-s)
    manage_swap
    ;;
  --all|-a)
    apply_all_automated
    ;;
  --status)
    show_status
    ;;
  --rollback|-r)
    rollback_all
    ;;
  --help|-h)
    printf "Usage: bash %s [--status | --all | --swap | --rollback]\n" "$0"
    exit 0
    ;;
  *)
    show_status
    ;;
esac
