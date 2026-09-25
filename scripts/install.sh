#!/usr/bin/env bash
#===============================================================================
#  OMEGA-Tunnel Automated One-Liner Installer
#
#  Installs the OMEGA-Tunnel suite into /opt/omega-boost and registers
#  the 'omega' system command for convenient menu access.
#
#  Safety:
#    - NEVER modifies or restarts 3x-ui or online user connections
#    - Completely isolated in /opt/omega-boost
#===============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
set -u

INSTALL_DIR="/opt/omega-boost"
SCRIPTS_DIR="${INSTALL_DIR}/scripts"
BIN_LINK="/usr/local/bin/omega"
REPO_BRANCH="arena/01a0d868-omega-tunnel"
RAW_BASE="https://raw.githubusercontent.com/Dark-Sky07/OMEGA-Tunnel/${REPO_BRANCH}"

# Color helpers
if [ -t 1 ]; then
  C_G=$'\033[0;32m'; C_Y=$'\033[0;33m'; C_R=$'\033[0;31m'
  C_B=$'\033[1;36m'; C_W=$'\033[1;37m'; C_0=$'\033[0m'
else
  C_G=""; C_Y=""; C_R=""; C_B=""; C_W=""; C_0=""
fi

if [ "$(id -u)" -ne 0 ]; then
  printf "%s[FAIL] Installer must be run as root.%s\n" "$C_R" "$C_0"
  printf "Please run: sudo bash install.sh\n"
  exit 1
fi

printf "\n%s=== Installing OMEGA-Tunnel Server Booster ===%s\n\n" "$C_B" "$C_0"

mkdir -p "$SCRIPTS_DIR"
mkdir -p "${INSTALL_DIR}/backup"

SCRIPT_FILES=(
  "omega-menu.sh"
  "omega-boost.sh"
  "omega-operator-fix.sh"
  "omega-sysupdate.sh"
  "omega-preflight.sh"
)

LOCAL_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts"

for file in "${SCRIPT_FILES[@]}"; do
  target="${SCRIPTS_DIR}/${file}"
  if [ -f "${LOCAL_SCRIPTS_DIR}/${file}" ]; then
    cp "${LOCAL_SCRIPTS_DIR}/${file}" "$target"
  else
    printf "  Downloading %s...\n" "$file"
    curl -fsSL "${RAW_BASE}/scripts/${file}" -o "$target" 2>/dev/null || \
      curl -fsSL "http://127.0.0.1:8000/${file}" -o "$target" 2>/dev/null || true
  fi
  chmod +x "$target"
done

# Create global binary wrapper
cat << 'EOF' > "$BIN_LINK"
#!/usr/bin/env bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
if [ ! -t 0 ] && [ -e /dev/tty ]; then
  exec </dev/tty
fi
exec bash /opt/omega-boost/scripts/omega-menu.sh "$@"
EOF
chmod +x "$BIN_LINK"

printf "\n%s[OK] OMEGA-Tunnel installed successfully!%s\n" "$C_G" "$C_0"
printf "  Installation path: %s\n" "$INSTALL_DIR"
printf "  Global command:    %somega%s\n\n" "$C_W" "$C_0"
printf "To launch the menu anytime, simply type: %somega%s\n\n" "$C_G" "$C_0"

# Reconnect to TTY before launching menu
if [ -t 0 ]; then
  exec /usr/local/bin/omega
elif [ -e /dev/tty ]; then
  exec /usr/local/bin/omega </dev/tty
else
  printf "Please type 'omega' to enter the menu.\n"
fi
