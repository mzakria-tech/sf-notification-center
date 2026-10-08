#!/bin/bash
# Stop all SF Notification Center services

echo "Stopping SF Notification Center..."

POLLER_LABEL="com.${USER}.sf-case-poller"
MAILER_LABEL="com.${USER}.local-mailserver"

launchctl unload ~/Library/LaunchAgents/${POLLER_LABEL}.plist 2>/dev/null && echo "→ SF Case Poller stopped" || echo "→ SF Case Poller was not running"
launchctl unload ~/Library/LaunchAgents/${MAILER_LABEL}.plist 2>/dev/null && echo "→ Mail Server + Dashboard stopped" || echo "→ Mail Server was not running"

echo ""
echo "All services stopped."
