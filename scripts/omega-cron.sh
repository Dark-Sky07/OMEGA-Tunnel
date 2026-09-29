#!/usr/bin/env bash
#===============================================================================
#  omega-cron — Automated Memory Janitor & Maintenance Cronjob
#  Part of Omega VPS All In One Optimizer
#
#  Schedules a nightly automated maintenance job at 04:00 AM:
#    1. Reclaims dead RAM cache (sync; echo 3 > /proc/sys/vm/drop_caches)
#    2. Vacuums systemd journal logs older than 3 days
#    3. Cleans stale temporary files
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

CRON_FILE="/etc/cron.d/omega-janitor"

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

show_status() {
  section "Automated Memory & Maintenance Janitor Status"
  if [ -f "$CRON_FILE" ]; then
    ok "Automated Janitor is ACTIVE (Scheduled daily at 04:00 AM)"
    info "Schedule: $(cat "$CRON_FILE" | grep -v '^#')"
  else
    warn "Automated Janitor is NOT scheduled."
  fi
}

enable_cron() {
  check_root
  section "Enabling Nightly Memory Janitor Cronjob"

  cat << 'EOF' > "$CRON_FILE"
# Omega VPS Nightly Janitor: Cleans dead RAM cache and vacuums logs at 04:00 AM
0 4 * * * root sync; echo 3 > /proc/sys/vm/drop_caches; journalctl --vacuum-time=3d --vacuum-size=200M >/dev/null 2>&1; find /tmp -type f -atime +3 -delete 2>/dev/null
EOF
  chmod 644 "$CRON_FILE"
  systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true

  ok "Nightly janitor scheduled successfully at 04:00 AM!"
  info "Your RAM, cache, and SSD storage will be refreshed automatically every night."
}

disable_cron() {
  check_root
  section "Disabling Automated Janitor"
  rm -f "$CRON_FILE"
  systemctl restart cron 2>/dev/null || systemctl restart crond 2>/dev/null || true
  ok "Automated janitor removed."
}

run_now() {
  check_root
  section "Running Immediate Cache Clean & Log Vacuum"
  info "Syncing filesystem and freeing dead RAM cache..."
  sync
  echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
  
  info "Vacuuming journal logs..."
  journalctl --vacuum-time=3d --vacuum-size=200M >/dev/null 2>&1 || true
  
  ok "RAM cache freed and logs vacuumed successfully!"
}

CMD="${1:---status}"
case "$CMD" in
  --enable|-e)
    enable_cron
    ;;
  --disable|-d)
    disable_cron
    ;;
  --run|-r)
    run_now
    ;;
  --status|-s)
    show_status
    ;;
  *)
    show_status
    ;;
esac
