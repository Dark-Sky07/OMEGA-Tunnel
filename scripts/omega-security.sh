#!/usr/bin/env bash
#===============================================================================
#  omega-security — Anti-Bruteforce, Fail2ban & Security Hardening
#  Part of Omega VPS All In One Optimizer
#
#  Protects VPS against:
#    1. SSH automated brute-force attacks (Fail2ban jail with 24h ban)
#    2. ICMP Ping flood attacks (Rate-limited to 5/s with burst 10)
#    3. SYN flood protection via TCP syncookies
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"
FAIL2BAN_CONF="/etc/fail2ban/jail.d/99-omega-sshd.local"
ACTIVE_FLAG="${BASE_DIR}/security.active"

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

show_status() {
  section "Security & Anti-Bruteforce Status"
  
  printf "  1. Fail2ban SSH Jail:\n"
  if have fail2ban-client && systemctl is-active --quiet fail2ban 2>/dev/null; then
    ok "Fail2ban service is RUNNING"
    local banned_count
    banned_count="$(fail2ban-client status sshd 2>/dev/null | awk '/Currently banned:/ {print $NF}' || echo "0")"
    info "Currently banned attacker IPs: $banned_count"
  else
    warn "Fail2ban is NOT active"
  fi

  printf "\n  2. ICMP Ping-Flood Rate Limiting:\n"
  if iptables -C INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s --limit-burst 10 -j ACCEPT >/dev/null 2>&1; then
    ok "ICMP Rate Limiting is ACTIVE (Max 5 pings/sec)"
  else
    warn "ICMP Rate Limiting is NOT active"
  fi

  printf "\n  3. TCP Syncookies (SYN-Flood Defense):\n"
  local syn_val
  syn_val="$(/sbin/sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || cat /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null || echo "0")"
  if [ "$syn_val" = "1" ]; then
    ok "TCP Syncookies enabled"
  else
    warn "TCP Syncookies disabled"
  fi
}

apply_security() {
  check_root
  section "Applying Security Hardening & Anti-Bruteforce"

  # 1. Install & configure Fail2ban
  if ! have fail2ban-client; then
    info "Installing Fail2ban..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y --no-install-recommends fail2ban >/dev/null 2>&1 || true
  fi

  if have fail2ban-client; then
    info "Configuring SSH brute-force jail (max 5 retries, 24h ban)..."
    mkdir -p /etc/fail2ban/jail.d
    cat << 'EOF' > "$FAIL2BAN_CONF"
[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 5
findtime = 600
bantime = 86400
EOF
    systemctl restart fail2ban 2>/dev/null || true
    systemctl enable fail2ban 2>/dev/null || true
    ok "Fail2ban SSH brute-force protection active."
  fi

  # 2. ICMP Rate Limiting
  info "Applying ICMP Ping-Flood rate limiting..."
  if ! iptables -C INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s --limit-burst 10 -j ACCEPT >/dev/null 2>&1; then
    iptables -I INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s --limit-burst 10 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    ok "ICMP Rate Limiting enabled (Legitimate pings allowed; floods dropped)."
  fi

  # 3. Kernel SYN-flood protection
  /sbin/sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null 2>&1 || true
  ok "TCP Syncookies enabled."

  touch "$ACTIVE_FLAG"
  printf "\n"
  ok "Security hardening applied successfully!"
}

rollback_security() {
  check_root
  section "Rolling back security rules"

  if [ -f "$FAIL2BAN_CONF" ]; then
    rm -f "$FAIL2BAN_CONF"
    systemctl restart fail2ban 2>/dev/null || true
    info "Removed Fail2ban custom jail."
  fi

  while iptables -D INPUT -p icmp --icmp-type echo-request -m limit --limit 5/s --limit-burst 10 -j ACCEPT 2>/dev/null; do :; done
  while iptables -D INPUT -p icmp --icmp-type echo-request -j DROP 2>/dev/null; do :; done
  info "Removed ICMP rate limiting rules."

  rm -f "$ACTIVE_FLAG"
  ok "Security configurations rolled back."
}

CMD="${1:---status}"
case "$CMD" in
  --apply|-a)
    apply_security
    ;;
  --status|-s)
    show_status
    ;;
  --rollback|-r)
    rollback_security
    ;;
  *)
    show_status
    ;;
esac
