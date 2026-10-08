#!/bin/bash
# Stop all SF Notification Center services

echo "Stopping SF Notification Center..."

launchctl unload ~/Library/LaunchAgents/com.sf-notify.case-poller.plist 2>/dev/null && echo "→ SF Case Poller stopped" || echo "→ SF Case Poller was not running"
launchctl unload ~/Library/LaunchAgents/com.sf-notify.mailserver.plist 2>/dev/null && echo "→ Mail Server + Dashboard stopped" || echo "→ Mail Server was not running"

echo ""
echo "All services stopped."
