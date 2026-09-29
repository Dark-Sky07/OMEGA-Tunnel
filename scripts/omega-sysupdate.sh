#!/usr/bin/env bash
#===============================================================================
#  omega-sysupdate — System Update & Essential Packages Installer
#
#  Safely updates package repositories, installs essential networking tools
#  (curl, jq, sqlite3, iptables, socat, htop, etc.), and cleans package caches.
#
#  Safety Contract:
#    - NEVER touches x-ui, xray, or existing panel services
#    - Non-interactive mode (DEBIAN_FRONTEND=noninteractive) avoids prompt lockups
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export DEBIAN_FRONTEND=noninteractive
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

if [ "$(id -u)" -ne 0 ]; then
  bad "Root privileges required for system update."
  printf "    Please execute with sudo: sudo bash %s\n" "$0"
  exit 1
fi

section "Step 1: Updating Package Lists"
apt-get update -y
ok "Package lists updated."

section "Step 2: Installing Essential Tools & Dependencies"
ESSENTIAL_PKGS=(
  "curl"
  "wget"
  "jq"
  "sqlite3"
  "iptables"
  "socat"
  "cron"
  "tar"
  "unzip"
  "htop"
  "net-tools"
  "ca-certificates"
  "dnsutils"
  "iproute2"
)

info "Installing: ${ESSENTIAL_PKGS[*]}"
apt-get install -y --no-install-recommends "${ESSENTIAL_PKGS[@]}"
ok "Essential packages installed."

section "Step 3: Upgrading System Packages"
info "Running non-interactive distribution upgrade..."
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
ok "System packages upgraded."

section "Step 4: Cleaning Up Unused Packages & Cache"
apt-get autoremove -y >/dev/null 2>&1 || true
apt-get clean >/dev/null 2>&1 || true
ok "Package cache cleaned."

printf "\n"
ok "System update & maintenance completed successfully!"
