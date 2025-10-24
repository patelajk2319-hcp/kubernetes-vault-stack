#!/usr/bin/env bash
set -euo pipefail

# Set up minikube mount for vault-audit-logs directory
# This allows the CronJob in minikube to write directly to the host filesystem

# Colour codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

HOST_DIR="$(pwd)/vault-audit-logs"
MINIKUBE_MOUNT_PATH="/hosthome/vault-audit-logs"
PID_FILE="./vault-audit-logs/.minikube-mount.pid"

# Create host directory if it doesn't exist
mkdir -p "$HOST_DIR"

# Check if mount is already running
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if ps -p "$OLD_PID" > /dev/null 2>&1; then
    echo -e "${YELLOW}Minikube mount already running (PID: $OLD_PID)${NC}"
    echo -e "${YELLOW}To stop it: kill $OLD_PID${NC}"
    exit 0
  else
    # Stale PID file
    rm -f "$PID_FILE"
  fi
fi

echo -e "${BLUE}Setting up minikube mount...${NC}"
echo -e "${BLUE}Host directory: ${HOST_DIR}${NC}"
echo -e "${BLUE}Minikube path: ${MINIKUBE_MOUNT_PATH}${NC}"
echo ""

# Start minikube mount in background
nohup minikube mount "${HOST_DIR}:${MINIKUBE_MOUNT_PATH}" > ./vault-audit-logs/.minikube-mount.log 2>&1 &
MOUNT_PID=$!
echo "$MOUNT_PID" > "$PID_FILE"

# Wait a bit for mount to be established
echo -e "${YELLOW}Waiting for mount to be established...${NC}"
sleep 3

# Verify mount is working
if ps -p "$MOUNT_PID" > /dev/null 2>&1; then
  echo -e "${GREEN}✓ Minikube mount started (PID: $MOUNT_PID)${NC}"
  echo -e "${BLUE}Log file: ./vault-audit-logs/.minikube-mount.log${NC}"
  echo -e "${YELLOW}Note: This mount will stay active until you stop it or restart minikube${NC}"
  echo ""
  echo -e "${BLUE}To stop the mount: kill $MOUNT_PID${NC}"
  echo -e "${BLUE}Or run: pkill -f 'minikube mount'${NC}"
else
  echo -e "${RED}Failed to start mount${NC}"
  rm -f "$PID_FILE"
  exit 1
fi

# Verify mount is accessible in minikube
echo -e "${BLUE}Verifying mount in minikube...${NC}"
if minikube ssh "test -d ${MINIKUBE_MOUNT_PATH}" 2>/dev/null; then
  echo -e "${GREEN}✓ Mount verified - directory accessible in minikube${NC}"
else
  echo -e "${RED}Mount directory not accessible in minikube yet${NC}"
  echo -e "${YELLOW}It may take a moment to sync. Check the log file for details.${NC}"
fi
