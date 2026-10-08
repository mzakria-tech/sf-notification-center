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

# Start mail server (dashboard + SMTP)
launchctl unload ~/Library/LaunchAgents/com.mzakria.local-mailserver.plist 2>/dev/null || true
sleep 1
launchctl load ~/Library/LaunchAgents/com.mzakria.local-mailserver.plist
echo "→ Mail Server + Dashboard started (port 8090)"

# Start poller
launchctl unload ~/Library/LaunchAgents/com.mzakria.sf-case-poller.plist 2>/dev/null || true
sleep 1
launchctl load ~/Library/LaunchAgents/com.mzakria.sf-case-poller.plist
echo "→ SF Case Poller started (every 5 min)"

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║  ✅ All services running!                     ║"
echo "║                                               ║"
echo "║  Dashboard:  http://localhost:8090             ║"
echo "║  Poller log: ~/Library/Logs/sf-case-poller.log║"
echo "╚═══════════════════════════════════════════════╝"
