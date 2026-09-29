#!/usr/bin/env bash
#===============================================================================
#  omega-domain-checker — Domain & Subdomain Censor Health Checker
#  Part of Omega VPS All In One Optimizer
#
#  Tests whether your subscription domain, CDN domain, or SNI is:
#    1. DNS Poisoned in Iran (10.10.34.34 or fake loopback)
#    2. SNI Blocked via Deep Packet Inspection (DPI TCP RST)
#    3. Clean and fully accessible across Iranian ISPs
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_C=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[OK]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[WARN]%s %s\n" "$C_Y" "$C_0" "$1"; }
bad(){     printf "%s[BLOCKED]%s %s\n" "$C_R" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }

check_domain() {
  local domain="$1"
  # Clean domain from http://, https://, and trailing slashes
  domain=$(echo "$domain" | sed -E 's|^https?://||; s|/.*$||')

  if [ -z "$domain" ]; then
    printf "%s[!] Domain cannot be empty.%s\n" "$C_R" "$C_0"
    return
  fi

  section "Censorship Audit for: $domain"

  # Step 1: Global Clean DNS resolution
  printf "Step 1: Global Clean Resolution (Cloudflare 1.1.1.1)... "
  local clean_ip
  clean_ip=$(dig +short +time=2 +tries=1 "@1.1.1.1" "$domain" A 2>/dev/null | tail -n 1 || echo "")
  if [ -z "$clean_ip" ]; then
    clean_ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n 1 || echo "")
  fi

  if [ -n "$clean_ip" ]; then
    printf "%s%s%s\n" "$C_G" "$clean_ip" "$C_0"
  else
    printf "%s[FAILED TO RESOLVE GLOBALLY]%s\n" "$C_R" "$C_0"
    warn "Domain does not have valid public DNS records."
    return
  fi

  # Step 2: Iran DNS Resolvers Check
  printf "Step 2: Checking Iranian National DNS Resolvers:\n"
  local iran_resolvers=(
    "178.22.122.100|Shecan DNS"
    "10.202.10.202|403.online"
    "194.225.70.1|MCI Mobile DNS"
  )

  local is_poisoned=0
  for item in "${iran_resolvers[@]}"; do
    local rip="${item%%|*}"
    local rname="${item##*|}"
    printf "  * %-20s (%s)... " "$rname" "$rip"
    local resolved
    resolved=$(dig +short +time=3 +tries=1 "@$rip" "$domain" A 2>/dev/null | tail -n 1 || echo "")

    if [ "$resolved" = "10.10.34.34" ] || [ "$resolved" = "10.10.34.35" ]; then
      printf "%s[POISONED (10.10.34.34 Peivandha)]%s\n" "$C_R" "$C_0"
      is_poisoned=1
    elif [ "$resolved" = "127.0.0.1" ] || [ "$resolved" = "0.0.0.0" ]; then
      printf "%s[POISONED (Fake Loopback %s)]%s\n" "$C_R" "$resolved" "$C_0"
      is_poisoned=1
    elif [ -z "$resolved" ]; then
      printf "%s[TIMEOUT / NO RESPONSE]%s\n" "$C_Y" "$C_0"
    else
      printf "%s[MATCH - %s]%s\n" "$C_G" "$resolved" "$C_0"
    fi
  done

  # Step 3: TLS SNI Handshake Test
  printf "\nStep 3: Testing TLS SNI Handshake (Port 443)... "
  local ssl_check
  ssl_check=$(echo | timeout 4 openssl s_client -connect "${clean_ip}:443" -servername "$domain" -tls1_2 -brief 2>&1 || true)

  local sni_ok=0
  if echo "$ssl_check" | grep -qi "CONNECTION ESTABLISHED"; then
    printf "%s[HANDSHAKE SUCCESSFUL]%s\n" "$C_G" "$C_0"
    sni_ok=1
  elif echo "$ssl_check" | grep -qi "handshake failure\|reset by peer\|alert"; then
    printf "%s[TLS HANDSHAKE BLOCKED / RESET]%s\n" "$C_R" "$C_0"
  else
    printf "%s[TIMEOUT / NO RESPONSE]%s\n" "$C_Y" "$C_0"
  fi

  # Step 4: Overall Censorship Verdict
  printf "\n%s=== CENSORSHIP & ACCESSIBILITY VERDICT ===%s\n" "$C_B" "$C_0"
  if [ "$is_poisoned" -eq 1 ]; then
    bad "DOMAIN IS DNS-POISONED IN IRAN!"
    info "- Iranian ISP resolvers return fake redirection IPs."
    info "- Recommendation: Switch your subscription/CDN domain or use Cloudflare Clean IP with custom Host."
  elif [ "$sni_ok" -eq 0 ]; then
    warn "SNI MAY BE THROTTLED OR BLOCKED BY IRANIAN DPI"
    info "- The TLS handshake experienced reset or timeouts on port 443."
    info "- Recommendation: Test another SNI domain in Reality finder (Menu [6])."
  else
    ok "DOMAIN IS CLEAN & UNBLOCKED!"
    info "- Zero DNS poisoning detected across domestic operators."
    info "- Valid TLS SNI handshake established smoothly."
    info "- Perfect for subscription links, VLESS-Reality SNI, or Cloudflare CDN inbounds."
  fi
  printf "\n"
}

menu() {
  while true; do
    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "          %sOMEGA DOMAIN & SUBDOMAIN CENSOR HEALTH CHECKER%s\n" "$C_W" "$C_0"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s Audit Custom Domain or Subdomain\n" "$C_C" "$C_0"
    printf "  %s[2]%s Quick Test Popular Reality SNIs (gateway.icloud.com, dl.google.com)\n" "$C_C" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1)
        printf "Enter Domain or Subdomain (e.g. sub.mydomain.com): "
        read -r input_dom
        if [ -n "$input_dom" ]; then
          check_domain "$input_dom"
          read -r -p "Press [Enter] to return..." _ || true
        fi
        ;;
      2)
        check_domain "gateway.icloud.com"
        check_domain "dl.google.com"
        read -r -p "Press [Enter] to return..." _ || true
        ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

if [ -n "${1:-}" ]; then
  check_domain "$1"
else
  menu
fi
