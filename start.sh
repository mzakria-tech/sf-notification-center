#!/bin/bash
# Start all SF Notification Center services
set -e

echo "Starting SF Notification Center..."

# Start Mail.app if not running
if ! pgrep -x "Mail" > /dev/null; then
    echo "→ Opening Mail.app..."
    open -a Mail
    sleep 2
fi

# Check Chrome
if ! pgrep -x "Google Chrome" > /dev/null; then
    echo "→ Opening Google Chrome..."
    open -a "Google Chrome"
    sleep 3
fi

POLLER_LABEL="com.${USER}.sf-case-poller"
MAILER_LABEL="com.${USER}.local-mailserver"

# Start mail server (dashboard + SMTP)
launchctl unload ~/Library/LaunchAgents/${MAILER_LABEL}.plist 2>/dev/null || true
sleep 1
launchctl load ~/Library/LaunchAgents/${MAILER_LABEL}.plist
echo "→ Mail Server + Dashboard started (port 8090)"

# Start poller
launchctl unload ~/Library/LaunchAgents/${POLLER_LABEL}.plist 2>/dev/null || true
sleep 1
launchctl load ~/Library/LaunchAgents/${POLLER_LABEL}.plist
echo "→ SF Case Poller started (every 1 min)"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  ✅ All services running!                     ║"
echo "║                                               ║"
echo "║  Dashboard:  http://localhost:8090             ║"
echo "║  Poller log: ~/Library/Logs/sf-case-poller.log║"
echo "╚═══════════════════════════════════════════════╝"
