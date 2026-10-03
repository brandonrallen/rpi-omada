#!/usr/bin/env bash

set -euo pipefail

###############################################################################
# Raspberry Pi Omada Controller Bootstrap
#
# Target:
#   Raspberry Pi 4B
#   Raspberry Pi OS Lite 64-bit
#
# Installs:
#   - Git
#   - Docker
#   - Docker Compose
#   - Omada Controller 5.15
#
# The Pi initially uses DHCP.
# Configure a DHCP reservation in your router after installation.
###############################################################################

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

REPO_URL="https://github.com/brandonrallen/rpi-omada.git"
REPO_BRANCH="main"

INSTALL_DIR="/opt/rpi-omada"

OMADA_VERSION="5.15"

TIMEZONE="America/Chicago"

OMADA_COMPOSE="${INSTALL_DIR}/compose.yml"


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

log() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo
}

error() {
    echo
    echo "ERROR: $1"
    echo
    exit 1
}


# -----------------------------------------------------------------------------
# Root check
# -----------------------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    error "Run this script with sudo."
fi


# -----------------------------------------------------------------------------
# Detect OS
# -----------------------------------------------------------------------------

log "Checking operating system"

if [[ ! -f /etc/os-release ]]; then
    error "Unable to determine operating system."
fi

source /etc/os-release

echo "OS: ${PRETTY_NAME:-unknown}"


# -----------------------------------------------------------------------------
# Architecture check
# -----------------------------------------------------------------------------

log "Checking CPU architecture"

ARCH="$(uname -m)"

echo "Architecture: ${ARCH}"

if [[ "${ARCH}" != "aarch64" ]]; then
    error "This installation requires a 64-bit OS (aarch64)."
fi


# -----------------------------------------------------------------------------
# Raspberry Pi check
# -----------------------------------------------------------------------------

log "Checking Raspberry Pi"

if [[ -f /proc/device-tree/model ]]; then

    MODEL="$(tr -d '\0' < /proc/device-tree/model)"

    echo "Model: ${MODEL}"

else

    echo "WARNING: Unable to determine Raspberry Pi model."

fi


# -----------------------------------------------------------------------------
# Update operating system
# -----------------------------------------------------------------------------

log "Updating operating system"

apt-get update
apt-get upgrade -y


# -----------------------------------------------------------------------------
# Install prerequisites
# -----------------------------------------------------------------------------

log "Installing prerequisites"

apt-get install -y \
    git \
    curl \
    ca-certificates \
    gnupg \
    lsb-release


# -----------------------------------------------------------------------------
# Configure timezone
# -----------------------------------------------------------------------------

log "Configuring timezone"

timedatectl set-timezone "${TIMEZONE}"

echo "Timezone: ${TIMEZONE}"


# -----------------------------------------------------------------------------
# Configure hostname
# -----------------------------------------------------------------------------

log "Configuring hostname"

read -r -p "Enter hostname [omada-pi]: " HOSTNAME_INPUT

HOSTNAME_INPUT="${HOSTNAME_INPUT:-omada-pi}"

hostnamectl set-hostname "${HOSTNAME_INPUT}"

echo "Hostname: ${HOSTNAME_INPUT}"


# -----------------------------------------------------------------------------
# Install Docker
# -----------------------------------------------------------------------------

log "Installing Docker"

if command -v docker >/dev/null 2>&1; then

    echo "Docker is already installed."

else

    curl -fsSL https://get.docker.com | sh

fi


# -----------------------------------------------------------------------------
# Enable Docker
# -----------------------------------------------------------------------------

log "Enabling Docker"

systemctl enable docker
systemctl start docker


# -----------------------------------------------------------------------------
# Verify Docker
# -----------------------------------------------------------------------------

log "Verifying Docker installation"

docker --version
docker compose version


# -----------------------------------------------------------------------------
# Determine original user
# -----------------------------------------------------------------------------

REAL_USER="${SUDO_USER:-}"

if [[ -n "${REAL_USER}" && "${REAL_USER}" != "root" ]]; then

    log "Configuring Docker permissions"

    usermod -aG docker "${REAL_USER}"

    echo "Added ${REAL_USER} to the docker group."

fi


# -----------------------------------------------------------------------------
# Clone repository
# -----------------------------------------------------------------------------

log "Cloning Omada repository"

if [[ -d "${INSTALL_DIR}/.git" ]]; then

    echo "Repository already exists."

    cd "${INSTALL_DIR}"

    git fetch origin

    git checkout "${REPO_BRANCH}"

    git pull origin "${REPO_BRANCH}"

else

    mkdir -p "$(dirname "${INSTALL_DIR}")"

    git clone \
        --branch "${REPO_BRANCH}" \
        "${REPO_URL}" \
        "${INSTALL_DIR}"

fi


# -----------------------------------------------------------------------------
# Verify Compose file
# -----------------------------------------------------------------------------

log "Checking Docker Compose configuration"

if [[ ! -f "${OMADA_COMPOSE}" ]]; then

    error "Could not find ${OMADA_COMPOSE}"

fi

cd "${INSTALL_DIR}"

docker compose config >/dev/null

echo "Compose configuration is valid."


# -----------------------------------------------------------------------------
# Pull Omada image
# -----------------------------------------------------------------------------

log "Pulling Omada Controller ${OMADA_VERSION}"

docker compose pull


# -----------------------------------------------------------------------------
# Start Omada
# -----------------------------------------------------------------------------

log "Starting Omada Controller"

docker compose up -d


# -----------------------------------------------------------------------------
# Wait for container
# -----------------------------------------------------------------------------

log "Waiting for Omada Controller"

for i in {1..30}; do

    if docker ps \
        --filter "name=omada-controller" \
        --filter "status=running" \
        --format "{{.Names}}" | grep -q "^omada-controller$"; then

        echo "Omada container is running."

        break

    fi

    echo "Waiting for Omada..."

    sleep 2

done


# -----------------------------------------------------------------------------
# Verify container
# -----------------------------------------------------------------------------

if ! docker ps \
    --filter "name=omada-controller" \
    --filter "status=running" \
    --format "{{.Names}}" | grep -q "^omada-controller$"; then

    echo
    echo "Omada failed to start."
    echo
    echo "Container status:"
    docker compose ps
    echo
    echo "Recent logs:"
    docker compose logs --tail=100

    exit 1

fi


# -----------------------------------------------------------------------------
# Detect IP
# -----------------------------------------------------------------------------

IP_ADDRESS="$(
    hostname -I |
    awk '{print $1}'
)"


# -----------------------------------------------------------------------------
# Installation complete
# -----------------------------------------------------------------------------

log "OMADA INSTALLATION COMPLETE"

echo "Hostname:"
echo "  ${HOSTNAME_INPUT}"

echo

echo "IP address:"
echo "  ${IP_ADDRESS}"

echo

echo "Omada Controller:"
echo
echo "  https://${IP_ADDRESS}:8043"

echo

echo "Docker container:"
echo "  omada-controller"

echo

echo "Useful commands:"
echo
echo "  cd ${INSTALL_DIR}"
echo "  docker compose ps"
echo "  docker compose logs -f"
echo "  docker compose restart"
echo "  docker compose pull"
echo "  docker compose up -d"

echo

echo "IMPORTANT:"
echo
echo "Create a DHCP reservation for this Pi in your router."
echo
echo "MAC addresses:"
ip link show | awk '/^[0-9]+: (eth|en)/ {iface=$2; gsub(":", "", iface); print iface}' >/dev/null 2>&1 || true

echo
ip -br link

echo

echo "The Pi is using DHCP. The router should reserve its"
echo "current IP address so the Omada Controller always has"
echo "the same address."

echo
echo "Installation complete."