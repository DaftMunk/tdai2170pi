#!/bin/bash
# TDAI-2170 RPI Ser2net Installation and Configuration Script
# Installs ser2net and creates initial configuration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SER2NET_CONFIG="/etc/ser2net.yaml"
TCP_PORT=4001
SERIAL_DEVICE="/dev/ttyUSB0"
BAUD_RATE="115200N81"

echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  TDAI-2170 Ser2net Installation and Configuration Script${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error:${NC} This script must be run as root"
    echo "Usage: sudo $0"
    exit 1
fi

# Check if ser2net is already installed
if command -v ser2net &> /dev/null; then
    SER2NET_VERSION=$(ser2net -v 2>&1 | head -1)
    echo -e "${YELLOW}Note:${NC} ser2net is already installed: ${SER2NET_VERSION}"
    read -p "Do you want to continue and overwrite configuration? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Step 1: Update package list
echo -e "${BLUE}[1/5]${NC} Updating package list..."
apt update -qq
if [ $? -eq 0 ]; then
    echo -e "      ${GREEN}✓${NC} Package list updated"
else
    echo -e "${RED}Error:${NC} Failed to update package list"
    exit 1
fi

# Step 2: Install ser2net
echo -e "${BLUE}[2/5]${NC} Installing ser2net..."
if command -v ser2net &> /dev/null; then
    echo -e "      ${GREEN}✓${NC} ser2net already installed"
else
    apt install -y ser2net > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "      ${GREEN}✓${NC} ser2net installed successfully"
    else
        echo -e "${RED}Error:${NC} Failed to install ser2net"
        exit 1
    fi
fi

# Show installed version
SER2NET_VERSION=$(ser2net -v 2>&1 | head -1)
echo -e "      ${BLUE}Version:${NC} ${SER2NET_VERSION}"

# Step 3: Backup existing configuration if it exists
echo -e "${BLUE}[3/5]${NC} Checking for existing configuration..."
if [ -f "${SER2NET_CONFIG}" ]; then
    BACKUP_FILE="${SER2NET_CONFIG}.backup-$(date +%Y%m%d-%H%M%S)"
    cp "${SER2NET_CONFIG}" "${BACKUP_FILE}"
    echo -e "      ${YELLOW}!${NC} Existing config backed up to:"
    echo -e "        ${BACKUP_FILE}"
else
    echo -e "      ${GREEN}✓${NC} No existing configuration found"
fi

# Step 4: Create new configuration
echo -e "${BLUE}[4/5]${NC} Creating ser2net configuration..."

# Detect available serial devices
echo -e "      ${BLUE}Detecting serial devices...${NC}"
AVAILABLE_DEVICES=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -1)
if [ -z "$AVAILABLE_DEVICES" ]; then
    echo -e "      ${YELLOW}!${NC} No serial devices found (using ${SERIAL_DEVICE} as default)"
    echo -e "        Connect your USB serial device and restart ser2net later"
else
    SERIAL_DEVICE="$AVAILABLE_DEVICES"
    echo -e "      ${GREEN}✓${NC} Found serial device: ${SERIAL_DEVICE}"
fi

# Create the configuration file
cat > "${SER2NET_CONFIG}" << EOF
# ser2net configuration to emulate Moxa NPort 5150A via FTDI USB cable
# Device: ${SERIAL_DEVICE} (FTDI FT232R or similar)
# TCP port ${TCP_PORT} + RFC2217 (exact Moxa behavior)
#
# This configuration provides network access to the serial device
# Clients can connect via: telnet <ip-address> ${TCP_PORT}
#
# Created by install-ser2net.sh on $(date)

connection: &moxa_ftdi
  accepter: telnet(rfc2217),tcp,${TCP_PORT}
  enable: on
  timeout: 0
  connector: serialdev,${SERIAL_DEVICE},${BAUD_RATE},local
  options:
    kickolduser: true
    max-connections: 10
    telnet-brk-on-sync: true
EOF

if [ $? -eq 0 ]; then
    echo -e "      ${GREEN}✓${NC} Configuration created: ${SER2NET_CONFIG}"
else
    echo -e "${RED}Error:${NC} Failed to create configuration"
    exit 1
fi

# Step 5: Enable and start ser2net service
echo -e "${BLUE}[5/5]${NC} Configuring ser2net service..."

# Enable service to start on boot
systemctl enable ser2net > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "      ${GREEN}✓${NC} Service enabled (will start on boot)"
else
    echo -e "${YELLOW}!${NC} Could not enable service"
fi

# Start the service
systemctl restart ser2net
sleep 2

if systemctl is-active --quiet ser2net; then
    echo -e "      ${GREEN}✓${NC} Service started successfully"
else
    echo -e "${RED}Error:${NC} Service failed to start"
    echo ""
    echo -e "${YELLOW}Checking logs:${NC}"
    journalctl -u ser2net -n 10 --no-pager
    exit 1
fi

# Verify it's listening
if ss -tln | grep -q ":${TCP_PORT}"; then
    echo -e "      ${GREEN}✓${NC} Listening on port ${TCP_PORT}"
else
    echo -e "${YELLOW}!${NC} Not listening on expected port ${TCP_PORT}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Config file:     ${GREEN}${SER2NET_CONFIG}${NC}"
echo -e "TCP Port:        ${GREEN}${TCP_PORT}${NC}"
echo -e "Serial Device:   ${GREEN}${SERIAL_DEVICE}${NC}"
echo -e "Baud Rate:       ${GREEN}${BAUD_RATE}${NC}"
echo -e "Protocol:        ${GREEN}telnet + RFC2217${NC}"
echo -e "Max Connections: ${GREEN}10${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get IP address
IP_ADDR=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)
if [ -n "$IP_ADDR" ]; then
    echo -e "${BLUE}Network Access:${NC}"
    echo -e "  Local:   ${GREEN}telnet localhost ${TCP_PORT}${NC}"
    echo -e "  Network: ${GREEN}telnet ${IP_ADDR} ${TCP_PORT}${NC}"
    echo ""
fi

echo -e "${BLUE}Service Management:${NC}"
echo -e "  Status:  ${GREEN}sudo systemctl status ser2net${NC}"
echo -e "  Stop:    ${GREEN}sudo systemctl stop ser2net${NC}"
echo -e "  Start:   ${GREEN}sudo systemctl start ser2net${NC}"
echo -e "  Restart: ${GREEN}sudo systemctl restart ser2net${NC}"
echo -e "  Logs:    ${GREEN}sudo journalctl -u ser2net -f${NC}"
echo ""

echo -e "${BLUE}Configuration:${NC}"
echo -e "  Edit:    ${GREEN}sudo nano ${SER2NET_CONFIG}${NC}"
echo -e "  Test:    ${GREEN}sudo ser2net -n -c ${SER2NET_CONFIG} -d${NC}"
echo ""

echo -e "${YELLOW}Quick Test:${NC}"
echo -e "  ${GREEN}telnet localhost ${TCP_PORT}${NC}"
echo ""

# Check if serial device is accessible
if [ -e "${SERIAL_DEVICE}" ]; then
    echo -e "${GREEN}✓${NC} Serial device ${SERIAL_DEVICE} is accessible"
    ls -l ${SERIAL_DEVICE}
else
    echo -e "${YELLOW}!${NC} Serial device ${SERIAL_DEVICE} not found"
    echo -e "  Connect your USB serial adapter and restart ser2net:"
    echo -e "  ${GREEN}sudo systemctl restart ser2net${NC}"
fi
echo ""

# Check user permissions for serial access
CURRENT_USER="${SUDO_USER:-$USER}"
if id -nG "${CURRENT_USER}" | grep -qw "dialout"; then
    echo -e "${GREEN}✓${NC} User ${CURRENT_USER} is in 'dialout' group (can access serial ports)"
else
    echo -e "${YELLOW}Note:${NC} User ${CURRENT_USER} is NOT in 'dialout' group"
    echo -e "      Add user to group for direct serial access:"
    echo -e "      ${GREEN}sudo usermod -a -G dialout ${CURRENT_USER}${NC}"
    echo -e "      (Then log out and back in)"
fi
echo ""

echo -e "${GREEN}Installation successful!${NC}"
echo ""

echo -e "${BLUE}You can now do manual add of TDAI-2170 unit from Lyngdorf App using following parameters:${NC}"
echo -e "  IP-address: ${GREEN}${IP_ADDR}${NC}"
echo -e "  Portnumber: ${GREEN}${TCP_PORT}${NC}"
