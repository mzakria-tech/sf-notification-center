#!/bin/bash
# Uninstall SF Notification Center

echo "Uninstalling SF Notification Center..."

# Stop services
launchctl unload ~/Library/LaunchAgents/com.mzakria.sf-case-poller.plist 2>/dev/null
launchctl unload ~/Library/LaunchAgents/com.mzakria.local-mailserver.plist 2>/dev/null

# Remove LaunchAgents
rm -f ~/Library/LaunchAgents/com.mzakria.sf-case-poller.plist
rm -f ~/Library/LaunchAgents/com.mzakria.local-mailserver.plist

# Remove scripts
rm -f ~/.local/bin/sf-case-poller
rm -f ~/.local/bin/local-mailserver

# Remove state & config
rm -f ~/.local/state/sf-case-status.json
rm -f ~/.local/state/sf-poller-config.json

echo "Uninstalled. Logs left at ~/Library/Logs/ for reference."
