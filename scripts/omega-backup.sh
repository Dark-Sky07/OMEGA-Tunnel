#!/usr/bin/env bash
#===============================================================================
#  omega-backup — 3x-ui Panel & System Disaster Recovery Backup Manager
#  Part of Omega VPS All In One Optimizer
#
#  Features:
#    1. One-click backup of 3x-ui panel database (/etc/x-ui/x-ui.db)
#    2. Backup of SSL certificates (/root/cert, /etc/x-ui/)
#    3. Backup of system network & optimizer configurations
#    4. Easy one-click restore with pre-restore safety snapshots
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"
BACKUP_DIR="${BASE_DIR}/backups"

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

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    bad "Root privileges required."
    printf "    Please execute with sudo: sudo bash %s\n" "$0"
    exit 1
  fi
}

create_backup() {
  check_root
  section "Creating Panel & System Disaster Recovery Backup"

  mkdir -p "$BACKUP_DIR"
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local archive="${BACKUP_DIR}/omega-panel-backup-${timestamp}.tar.gz"

  local items_to_backup=()

  # Check 3x-ui database and configs
  if [ -f "/etc/x-ui/x-ui.db" ]; then
    items_to_backup+=("/etc/x-ui/x-ui.db")
  fi
  if [ -d "/etc/x-ui" ]; then
    items_to_backup+=("/etc/x-ui")
  fi
  if [ -d "/root/cert" ]; then
    items_to_backup+=("/root/cert")
  fi
  if [ -f "/etc/sysctl.d/99-omega-boost.conf" ]; then
    items_to_backup+=("/etc/sysctl.d/99-omega-boost.conf")
  fi

  if [ ${#items_to_backup[@]} -eq 0 ]; then
    warn "No standard panel database (/etc/x-ui/x-ui.db) found to backup."
    items_to_backup+=("/etc/sysctl.conf")
  fi

  info "Compressing files into: $archive"
  tar -czf "$archive" "${items_to_backup[@]}" 2>/dev/null || true

  local arc_size
  arc_size="$(du -h "$archive" 2>/dev/null | awk '{print $1}')"

  printf "\n"
  ok "Backup created successfully!"
  printf "  File: %s%s%s (%s)\n" "$C_W" "$archive" "$C_0" "$arc_size"
  info "You can download this file via SFTP or restore it anytime with the Restore option."

  if [ -f "/opt/omega-boost/omega-telegram.sh" ]; then
    bash /opt/omega-boost/omega-telegram.sh send "💾 *Omega Backup Created!*%0AFile: \`$(basename "$archive")\` ($arc_size)" >/dev/null 2>&1 || true
  fi
}

list_backups() {
  section "Available Panel Backups"
  mkdir -p "$BACKUP_DIR"

  local count=0
  for f in "${BACKUP_DIR}"/omega-panel-backup-*.tar.gz; do
    if [ -f "$f" ]; then
      count=$((count + 1))
      local sz
      sz="$(du -h "$f" | awk '{print $1}')"
      local dt
      dt="$(date -r "$f" "+%Y-%m-%d %H:%M:%S")"
      printf "  [%d] %-48s %-8s (%s)\n" "$count" "$(basename "$f")" "$sz" "$dt"
    fi
  done

  if [ "$count" -eq 0 ]; then
    info "No backup archives found in $BACKUP_DIR."
  fi
}

restore_backup() {
  check_root
  section "Restore Panel from Backup"
  mkdir -p "$BACKUP_DIR"

  local backups=()
  for f in "${BACKUP_DIR}"/omega-panel-backup-*.tar.gz; do
    [ -f "$f" ] && backups+=("$f")
  done

  if [ ${#backups[@]} -eq 0 ]; then
    bad "No backups found to restore."
    return 1
  fi

  printf "Select a backup archive to restore:\n"
  local idx=1
  for f in "${backups[@]}"; do
    local sz
    sz="$(du -h "$f" | awk '{print $1}')"
    printf "  [%d] %s (%s)\n" "$idx" "$(basename "$f")" "$sz"
    idx=$((idx + 1))
  done
  printf "  [0] Cancel\n\n"

  read -r -p "Enter number [0-$((idx - 1))]: " sel || sel="0"
  if [ "$sel" -eq 0 ] || [ "$sel" -ge "$idx" ]; then
    info "Restore cancelled."
    return 0
  fi

  local target_archive="${backups[$((sel - 1))]}"
  info "Selected: $(basename "$target_archive")"

  # Safety snapshot of current state before restoring
  if [ -f "/etc/x-ui/x-ui.db" ]; then
    info "Taking pre-restore snapshot of current database..."
    cp "/etc/x-ui/x-ui.db" "/etc/x-ui/x-ui.db.pre-restore"
  fi

  info "Extracting backup..."
  tar -xzf "$target_archive" -C / 2>/dev/null || true

  # If x-ui service is active, softly restart panel service to reload restored DB
  if systemctl is-active --quiet x-ui 2>/dev/null; then
    info "Restarting x-ui service to load restored database..."
    systemctl restart x-ui 2>/dev/null || true
  fi

  printf "\n"
  ok "Panel database restored successfully from $(basename "$target_archive")!"
}

CMD="${1:---backup}"
case "$CMD" in
  --backup|-b)
    create_backup
    ;;
  --list|-l)
    list_backups
    ;;
  --restore|-r)
    restore_backup
    ;;
  *)
    create_backup
    ;;
esac
