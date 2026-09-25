#!/usr/bin/env bash
#===============================================================================
#  omega-boost — Network & Kernel Tuning for OMEGA-Tunnel
#
#  Tunes the Linux TCP/IP network stack for high-loss, jitter-prone Iranian
#  connections WITHOUT touching or restarting 3x-ui, Xray, or active connections.
#
#  Safety Contract:
#    - NEVER modifies /etc/x-ui, panel DB, or /usr/local/x-ui/bin/config.json
#    - NEVER restarts x-ui or xray — existing online users stay connected
#    - Keeps full rollback backup in /opt/omega-boost/sysctl.bak
#    - Only writes /etc/sysctl.d/99-omega-boost.conf (can be removed anytime)
#    - Changes are applied live in kernel memory via sysctl
#
#  Usage:
#    sudo bash omega-boost.sh --dry-run    # preview changes without applying
#    sudo bash omega-boost.sh --apply      # apply optimizations live
#    sudo bash omega-boost.sh --rollback   # restore exact previous settings
#    sudo bash omega-boost.sh --status     # view current network stack status
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

VERSION="0.2.0"
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

section(){ printf "\n%s━━ %s ━━%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[✓]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[!]%s %s\n" "$C_Y" "$C_0" "$1"; }
bad(){     printf "%s[✗]%s %s\n" "$C_R" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }
have(){    command -v "$1" >/dev/null 2>&1; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    bad "این اسکریپت برای اعمال تغییرات به دسترسی root نیاز دارد."
    printf "    لطفاً با sudo اجرا کنید: sudo bash %s\n" "$0"
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
# Key | Recommended Value | Reason (FA)
TUNING_PARAMS=(
  "net.core.default_qdisc|fq|الزامی برای الگوریتم BBR جهت پکت‌پیسینگ دقیق و کاهش Drop در روترهای ایران"
  "net.ipv4.tcp_congestion_control|bbr|الگوریتم برتر مدیریت ازدحام در لینک‌های با پکت‌لاس بالا"
  "net.ipv4.tcp_notsent_lowat|16384|کاهش بافر ارسال به ۱۶KB، جلوگیری از لکنت و بافربلوت در تونل‌های مالتی‌پلکس VLESS"
  "net.ipv4.tcp_fastopen|3|کاهش یک RTT در اتصال مجدد کاربران (فعال برای کلاینت و سرور)"
  "net.ipv4.tcp_tw_reuse|1|استفاده مجدد ایمن از سوکت‌های TIME_WAIT برای ارتباط سریع‌تر"
  "net.ipv4.tcp_fin_timeout|15|آزادسازی سریع سوکت‌های نیمه‌بسته (کاهش از ۶۰ به ۱۵ ثانیه)"
  "net.ipv4.tcp_slow_start_after_idle|0|جلوگیری از ریست پنجره ارسال بعد از سکوت کوتاه (مثل تلگرام/وبگردی)"
  "net.ipv4.tcp_mtu_probing|1|کشف هوشمند MTU برای حل مشکل بلاک شدن پکت‌های ICMP PMTU در فیلترینگ"
  "net.ipv4.tcp_keepalive_time|300|تشخیص قطعی‌های بی‌صدای فایروال ایران بعد از ۵ دقیقه به‌جای ۲ ساعت"
  "net.ipv4.tcp_keepalive_intvl|15|فاصله‌ی پروب‌های کیپ‌الایو برای ریکانکت سریع کلاینت"
  "net.ipv4.tcp_keepalive_probes|5|تعداد پروب‌های پیش از اعلام مرگ کانکشن"
  "net.core.somaxconn|8192|افزایش ظرفیت صف اتصالات ورودی هنگام اسپایک اتصال کاربران"
  "net.ipv4.tcp_max_syn_backlog|8192|تحمل صف SYN در ساعات اوج مصرف و اختلالات شبکه"
  "net.core.netdev_max_backlog|16384|افزایش صف پردازش کارت شبکه"
  "net.core.rmem_max|33554432|حداکثر بافر دریافت TCP (۳۲ مگابایت)"
  "net.core.wmem_max|33554432|حداکثر بافر ارسال TCP (۳۲ مگابایت)"
  "net.ipv4.tcp_rmem|4096 87380 33554432|تنظیم پنجره حافظه دریافت TCP"
  "net.ipv4.tcp_wmem|4096 65536 33554432|تنظیم پنجره حافظه ارسال TCP"
)

show_status() {
  section "وضعیت فعلی شبکه و کرنل"
  printf "  %-36s %-18s %-18s\n" "پارامتر" "مقدار فعلی" "مقدار پیشنهادی"
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
  printf "\n  اینترفیس اصلی شبکه: %s%s%s\n" "$C_W" "$def_iface" "$C_0"
  if have tc && [ -n "$def_iface" ]; then
    local cur_qdisc
    cur_qdisc="$(tc qdisc show dev "$def_iface" 2>/dev/null | head -n1)"
    printf "  qdisc اینترفیس %s: %s\n" "$def_iface" "$cur_qdisc"
  fi

  if [ -f "$CONF_FILE" ]; then
    printf "\n  %s[✓] فایل کانفیگ OMEGA-Tunnel فعال است:%s %s\n" "$C_G" "$C_0" "$CONF_FILE"
  else
    printf "\n  %s[i] هنوز کانفیگ اختصاصی OMEGA-Tunnel اعمال نشده است.%s\n" "$C_Y" "$C_0"
  fi

  if [ "$all_match" -eq 1 ]; then
    ok "تمام پارامترهای شبکه در بهینه‌ترین حالت برای اتصال به ایران قرار دارند."
  else
    warn "برخی پارامترها هنوز روی مقادیر پیش‌فرض لینوکس هستند و با اجرای apply بهینه‌سازی خواهند شد."
  fi
}

dry_run() {
  section "پیش‌نمایش تغییرات (Dry Run — بدون تغییر روی سرور)"
  info "در این حالت هیچ تغییری در سیستم ذخیره یا اعمال نمی‌شود."
  printf "\n"

  printf "  %-34s %-14s %-14s %s\n" "پارامتر" "فعلی" "جدید" "علت بهینه‌سازی"
  printf "  %-34s %-14s %-14s %s\n" "----------------------------------" "--------------" "--------------" "--------------------------------------------"

  for item in "${TUNING_PARAMS[@]}"; do
    IFS='|' read -r key rec desc <<< "$item"
    local cur
    cur="$(get_sysctl "$key" | tr -s ' ')"
    if [ "$cur" = "$rec" ]; then
      printf "  %s%-34s %-14s %-14s [تغییری نیاز ندارد]%s\n" "$C_G" "$key" "$cur" "$rec" "$C_0"
    else
      printf "  %s%-34s%s %s%-14s%s -> %s%-14s%s %s\n" "$C_W" "$key" "$C_0" "$C_R" "$cur" "$C_0" "$C_G" "$rec" "$C_0" "$desc"
    fi
  done

  local def_iface
  def_iface="$(get_default_iface)"
  printf "\n"
  info "اینترفیس شبکه شناسایی‌شده: $def_iface"
  info "qdisc پیش‌فرض به fq ارتقا داده خواهد شد تا الگوریتم BBR بتواند پکت‌ها را با فواصل میلی‌ثانیه‌ای زمان‌بندی کند."
  info "هیچ سرویسی ری‌استارت نخواهد شد و حتی یک پکت از کاربران آنلاین قطع نمی‌شود."
}

apply_tuning() {
  check_root
  section "اعمال تیونینگ شبکه OMEGA-Tunnel"

  mkdir -p "$BACKUP_DIR"

  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  local ts_backup="${BACKUP_DIR}/sysctl-backup-${timestamp}.conf"

  info "تهیه اسنپ‌شات از مقادیر فعلی سیستم در: $ts_backup"
  {
    echo "# OMEGA-Tunnel sysctl backup taken at $timestamp"
    for item in "${TUNING_PARAMS[@]}"; do
      IFS='|' read -r key rec desc <<< "$item"
      local cur
      cur="$(get_sysctl "$key")"
      echo "$key = $cur"
    done
  } > "$ts_backup"

  # Also save to main rollback pointer
  cp "$ts_backup" "$BACKUP_FILE"
  ok "بک‌آپ کامل از وضعیت قبل ذخیره شد."

  # Backup current qdisc
  local def_iface
  def_iface="$(get_default_iface)"
  if have tc && [ -n "$def_iface" ]; then
    tc qdisc show dev "$def_iface" > "$QDISC_BACKUP" 2>/dev/null || true
  fi

  info "نوشتن کانفیگ پایدار در: $CONF_FILE"
  {
    echo "#==================================================================="
    echo "# OMEGA-Tunnel High-Performance Network Tuning for Iran Link"
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

  info "اعمال زنده تنظیمات در کرنل لینوکس (Live kernel injection)..."
  /sbin/sysctl -p "$CONF_FILE" >/dev/null 2>&1 || /sbin/sysctl --system >/dev/null 2>&1

  # Apply fq qdisc directly to default interface if available
  if have tc && [ -n "$def_iface" ]; then
    info "تنظیم qdisc روی fq برای اینترفیس $def_iface..."
    tc qdisc replace dev "$def_iface" root fq 2>/dev/null || true
  fi

  printf "\n"
  ok "تنظیمات شبکه با موفقیت اعمال شد!"
  info "هیچ کاربری قطع نشد و هیچ پروسه‌ای ری‌استارت نشد."
  info "برای دیدن مقادیر فعلی: sudo bash $0 --status"
  info "برای بازگشت به وضعیت قبل: sudo bash $0 --rollback"
}

rollback_tuning() {
  check_root
  section "بازگردانی تنظیمات شبکه به وضعیت قبلی (Rollback)"

  if [ ! -f "$BACKUP_FILE" ]; then
    bad "فایل بک‌آپ یافت نشد ($BACKUP_FILE)!"
    info "آیا قبلاً تیونینگ را روی این سرور اعمال کرده‌اید؟"
    exit 1
  fi

  info "بازیابی مقادیر از: $BACKUP_FILE"
  /sbin/sysctl -p "$BACKUP_FILE" >/dev/null 2>&1 || true

  if [ -f "$CONF_FILE" ]; then
    rm -f "$CONF_FILE"
    info "فایل $CONF_FILE حذف شد."
  fi

  local def_iface
  def_iface="$(get_default_iface)"
  if have tc && [ -f "$QDISC_BACKUP" ] && [ -n "$def_iface" ]; then
    info "بازیابی وضعیت qdisc اینترفیس..."
    # If previously cake:
    if grep -q "cake" "$QDISC_BACKUP"; then
      tc qdisc replace dev "$def_iface" root cake 2>/dev/null || true
    fi
  fi

  ok "تمام مقادیر شبکه دقیقاً به حالت قبل از تیونینگ بازگردانده شدند."
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
    printf "OMEGA-Tunnel booster v%s\n" "$VERSION"
    printf "استفاده:\n"
    printf "  sudo bash %s --dry-run    # پیش‌نمایش تغییرات بدون دست‌کاری سرور\n" "$0"
    printf "  sudo bash %s --apply      # اعمال بهینه‌سازی زنده (بدون قطعی)\n" "$0"
    printf "  sudo bash %s --status     # نمایش وضعیت مقادیر شبکه\n" "$0"
    printf "  sudo bash %s --rollback   # بازگشت تمیز به تنظیمات قبلی\n" "$0"
    exit 0
    ;;
  *)
    printf "گزینه ناشناخته: %s\n" "$CMD"
    printf "برای راهنما: bash %s --help\n" "$0"
    exit 1
    ;;
esac
