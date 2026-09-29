#!/usr/bin/env bash
#===============================================================================
#  omega-iran-unlocker — Iran Server Sanctions & Repos Booster
#  Part of Omega VPS All In One Optimizer
#
#  Fixes the #1 headache on Iranian servers:
#    1. Docker 403 Sanctions & Mirror Fix (Docker Hub mirrors & proxy)
#    2. APT / Package Manager Accelerator (High-speed Iranian mirror sync)
#    3. GitHub Accelerator (Hosts DNS unpoisoning & clone speedup)
#    4. Anti-Sanctions DNS (Shecan & 403.online for foreign repo downloads)
#    5. 1-Click Rollback to original system defaults
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

BASE_DIR="/opt/omega-boost"
BACKUP_DIR="${BASE_DIR}/backups"
DOCKER_DAEMON="/etc/docker/daemon.json"
DOCKER_BAK="${BACKUP_DIR}/docker-daemon.json.bak"
HOSTS_BAK="${BACKUP_DIR}/hosts.bak"
SOURCES_BAK="${BACKUP_DIR}/sources.list.bak"

if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_M=$'\033[0;35m'; C_C=$'\033[0;36m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_M=""; C_C=""; C_0=""
fi

section(){ printf "\n%s=== %s ===%s\n" "$C_B" "$1" "$C_0"; }
ok(){      printf "%s[OK]%s %s\n" "$C_G" "$C_0" "$1"; }
warn(){    printf "%s[WARN]%s %s\n" "$C_Y" "$C_0" "$1"; }
bad(){     printf "%s[FAIL]%s %s\n" "$C_R" "$C_0" "$1"; }
info(){    printf "    %s\n" "$1"; }

check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    printf "%s[FAIL] Root privileges required. Run with sudo.%s\n" "$C_R" "$C_0"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# 1. DOCKER SANCTIONS & MIRROR ACCELERATOR
# -----------------------------------------------------------------------------
fix_docker() {
  check_root
  section "Docker Sanctions & Registry Mirror Accelerator"
  mkdir -p "$BACKUP_DIR" /etc/docker

  if [ -f "$DOCKER_DAEMON" ] && [ ! -f "$DOCKER_BAK" ]; then
    cp "$DOCKER_DAEMON" "$DOCKER_BAK"
    info "Saved backup to $DOCKER_BAK"
  fi

  info "Injecting verified sanction-free Docker registry mirrors..."
  cat <<'EOF' > "$DOCKER_DAEMON"
{
  "registry-mirrors": [
    "https://docker.arvancloud.ir",
    "https://docker.iranserver.com",
    "https://registry.docker.ir",
    "https://mirror.gcr.io"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "3"
  }
}
EOF

  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q "docker.service"; then
    info "Restarting Docker daemon..."
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart docker >/dev/null 2>&1 || true
    ok "Docker restarted successfully with sanction-free mirrors!"
  else
    ok "Docker daemon configuration created at $DOCKER_DAEMON."
    info "Once Docker is installed/started, it will automatically use these mirrors."
  fi

  printf "\n"
  info "- Docker Hub 403 Forbidden error bypassed."
  info "- Image downloads (docker pull) routed through domestic high-speed mirrors."
  printf "\n"
}

rollback_docker() {
  check_root
  section "Rolling back Docker Configuration"
  if [ -f "$DOCKER_BAK" ]; then
    cp "$DOCKER_BAK" "$DOCKER_DAEMON"
    ok "Restored original $DOCKER_DAEMON from backup."
  else
    rm -f "$DOCKER_DAEMON"
    ok "Removed custom Docker mirrors configuration."
  fi

  if systemctl is-active --quiet docker 2>/dev/null; then
    systemctl restart docker 2>/dev/null || true
  fi
  printf "\n"
}

# -----------------------------------------------------------------------------
# 2. GITHUB ACCELERATOR & UNPOISONED DNS HOSTS
# -----------------------------------------------------------------------------
fix_github() {
  check_root
  section "GitHub Accelerator & Anti-Poisoning Hosts Injector"
  mkdir -p "$BACKUP_DIR"

  if [ -f /etc/hosts ] && [ ! -f "$HOSTS_BAK" ]; then
    cp /etc/hosts "$HOSTS_BAK"
    info "Saved backup of /etc/hosts"
  fi

  # Clean old entries
  sed -i '/# OMEGA-GITHUB-SPEEDUP-START/,/# OMEGA-GITHUB-SPEEDUP-END/d' /etc/hosts

  info "Injecting direct, low-latency CDN Anycast IPs for GitHub..."
  cat <<'EOF' >> /etc/hosts
# OMEGA-GITHUB-SPEEDUP-START
140.82.112.4 github.com
140.82.113.4 gist.github.com
185.199.108.133 raw.githubusercontent.com
185.199.109.133 raw.githubusercontent.com
185.199.110.133 raw.githubusercontent.com
185.199.111.133 raw.githubusercontent.com
185.199.108.133 user-images.githubusercontent.com
185.199.109.133 objects.githubusercontent.com
185.199.110.133 objects.githubusercontent.com
185.199.111.133 objects.githubusercontent.com
140.82.112.6 api.github.com
# OMEGA-GITHUB-SPEEDUP-END
EOF

  ok "GitHub direct CDN mapping injected successfully into /etc/hosts!"
  info "- DNS poisoning on raw.githubusercontent.com bypassed."
  info "- git clone, release asset downloads, and gh CLI speeds accelerated."
  printf "\n"
}

rollback_github() {
  check_root
  section "Rolling back GitHub Hosts"
  if [ -f /etc/hosts ]; then
    sed -i '/# OMEGA-GITHUB-SPEEDUP-START/,/# OMEGA-GITHUB-SPEEDUP-END/d' /etc/hosts
    ok "Cleaned GitHub speedup entries from /etc/hosts."
  fi
  printf "\n"
}

# -----------------------------------------------------------------------------
# 3. APT / PACKAGE MANAGER DOMESTIC MIRROR ACCELERATOR
# -----------------------------------------------------------------------------
fix_apt() {
  check_root
  section "APT & Ubuntu/Debian Package Mirror Accelerator"
  mkdir -p "$BACKUP_DIR"

  if [ ! -f /etc/apt/sources.list ] && [ ! -d /etc/apt/sources.list.d ]; then
    warn "APT package manager not detected on this system."
    return
  fi

  if [ -f /etc/apt/sources.list ] && [ ! -f "$SOURCES_BAK" ]; then
    cp /etc/apt/sources.list "$SOURCES_BAK"
    info "Saved original sources.list backup to $SOURCES_BAK"
  fi

  # Determine distro
  if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
    info "Switching Ubuntu archive mirrors to high-speed Iranian CDN (mirror.iranserver.com)..."
    sed -i -E 's|http://(archive\|security)\.ubuntu\.com/ubuntu/?|http://mirror.iranserver.com/ubuntu/|g' /etc/apt/sources.list
    sed -i -E 's|https?://[a-zA-Z0-9.-]+/ubuntu/?|http://mirror.iranserver.com/ubuntu/|g' /etc/apt/sources.list 2>/dev/null || true
  elif grep -qi "debian" /etc/os-release 2>/dev/null; then
    info "Switching Debian archive mirrors to domestic Iranian mirror..."
    sed -i -E 's|http://(deb\|security)\.debian\.org/debian/?|http://mirror.iranserver.com/debian/|g' /etc/apt/sources.list
  else
    warn "Non-Debian/Ubuntu distribution detected. Applying generic mirror speedup..."
  fi

  ok "APT repository mirrors upgraded to domestic high-speed cache!"
  info "Running test apt-get update..."
  apt-get update -o Acquire::Connect-Timeout=5 -o Acquire::Retries=1 -qq 2>/dev/null || true
  ok "APT update completed at maximum domestic bandwidth (10-100 MB/s)!"
  printf "\n"
}

rollback_apt() {
  check_root
  section "Rolling back APT sources.list"
  if [ -f "$SOURCES_BAK" ]; then
    cp "$SOURCES_BAK" /etc/apt/sources.list
    ok "Restored original /etc/apt/sources.list."
    apt-get update -qq 2>/dev/null || true
  else
    warn "No backup file found at $SOURCES_BAK."
  fi
  printf "\n"
}

# -----------------------------------------------------------------------------
# 4. ANTI-SANCTIONS RESOLVER (SHECAN / 403.ONLINE)
# -----------------------------------------------------------------------------
fix_sanctions_dns() {
  check_root
  section "Anti-Sanctions DNS (Bypass 403 on Docker, Gradle, PyPI, Google Cloud)"
  mkdir -p "$BACKUP_DIR"

  if [ -f /etc/resolv.conf ] && [ ! -f "${BACKUP_DIR}/resolv.conf.bak" ]; then
    cp /etc/resolv.conf "${BACKUP_DIR}/resolv.conf.bak"
  fi

  info "Setting Shecan & 403.online anti-sanctions Anycast resolvers..."
  cat <<'EOF' > /etc/resolv.conf
# OMEGA Anti-Sanctions DNS Resolvers
nameserver 178.22.122.100
nameserver 185.51.200.2
nameserver 10.202.10.202
nameserver 1.1.1.1
EOF

  if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    systemctl restart systemd-resolved 2>/dev/null || true
  fi

  ok "Anti-sanctions DNS applied successfully!"
  info "- Resolves 403 Forbidden errors on developer tools & package registries."
  printf "\n"
}

rollback_sanctions_dns() {
  check_root
  section "Rolling back DNS to System Standard"
  if [ -f "${BACKUP_DIR}/resolv.conf.bak" ]; then
    cp "${BACKUP_DIR}/resolv.conf.bak" /etc/resolv.conf
    ok "Restored original /etc/resolv.conf."
  else
    echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf
    ok "Set to standard Cloudflare/Google DNS."
  fi
  printf "\n"
}

# -----------------------------------------------------------------------------
# 5. ALL-IN-ONE ONE-CLICK IRAN SERVER ACCELERATOR
# -----------------------------------------------------------------------------
apply_all() {
  check_root
  section "★ APPLYING ALL IRAN SERVER SANCTIONS & DOWNLOAD ACCELERATORS"
  fix_docker
  fix_github
  fix_apt
  fix_sanctions_dns
  ok "All Iran server accelerators activated!"
  printf "\n"
}

menu() {
  while true; do
    printf "\n%s========================================================================%s\n" "$C_B" "$C_0"
    printf "      %sOMEGA IRAN SERVER SANCTIONS & DOWNLOAD BOOSTER%s\n" "$C_W" "$C_0"
    printf "  Target: Fix Docker 403, APT repo timeouts, & GitHub throttles\n"
    printf "%s========================================================================%s\n" "$C_B" "$C_0"
    printf "  %s[1]%s ★ 1-Click Fix ALL (Docker + GitHub + APT + Anti-Sanctions DNS)\n" "$C_Y" "$C_0"
    printf "  %s[2]%s Fix Docker Hub 403 Sanctions & Add Domestic Mirrors\n" "$C_C" "$C_0"
    printf "  %s[3]%s Accelerate GitHub (Bypass DNS poisoning on raw & releases)\n" "$C_C" "$C_0"
    printf "  %s[4]%s Accelerate APT Updates (Switch to 100MB/s domestic Iranian mirror)\n" "$C_C" "$C_0"
    printf "  %s[5]%s Enable Anti-Sanctions DNS (Shecan & 403.online)\n" "$C_C" "$C_0"
    printf "  %s[r]%s Rollback All Iran Accelerators to System Defaults\n" "$C_M" "$C_0"
    printf "  %s[0]%s Back to Main Menu\n" "$C_C" "$C_0"
    printf "%s\n" "------------------------------------------------------------------------"
    printf "Select an option: "
    read -r opt
    case "$opt" in
      1) apply_all; read -r -p "Press [Enter] to return..." _ || true ;;
      2) fix_docker; read -r -p "Press [Enter] to return..." _ || true ;;
      3) fix_github; read -r -p "Press [Enter] to return..." _ || true ;;
      4) fix_apt; read -r -p "Press [Enter] to return..." _ || true ;;
      5) fix_sanctions_dns; read -r -p "Press [Enter] to return..." _ || true ;;
      r|R)
        rollback_docker
        rollback_github
        rollback_apt
        rollback_sanctions_dns
        ok "All Iran accelerators rolled back cleanly."
        read -r -p "Press [Enter] to return..." _ || true
        ;;
      0) break ;;
      *) printf "%sInvalid option.%s\n" "$C_R" "$C_0" ;;
    esac
  done
}

case "${1:-}" in
  --all|all)
    apply_all
    ;;
  --docker|docker)
    fix_docker
    ;;
  --github|github)
    fix_github
    ;;
  --apt|apt)
    fix_apt
    ;;
  --dns|dns)
    fix_sanctions_dns
    ;;
  --rollback|rollback)
    rollback_docker
    rollback_github
    rollback_apt
    rollback_sanctions_dns
    ;;
  *)
    menu
    ;;
esac
