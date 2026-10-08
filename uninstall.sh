#!/bin/bash
# SF Case Notification Center - Uninstaller
set -e
USER_NAME=$(whoami)
USER_HOME=$(eval echo ~$USER_NAME)

echo "=== Uninstalling SF Case Notification Center ==="
launchctl stop "com.${USER_NAME}.sf-case-poller" 2>/dev/null || true
launchctl unload "$USER_HOME/Library/LaunchAgents/com.${USER_NAME}.sf-case-poller.plist" 2>/dev/null || true
rm -f "$USER_HOME/Library/LaunchAgents/com.${USER_NAME}.sf-case-poller.plist"
rm -f "$USER_HOME/.local/bin/sf-case-poller"
echo "Done. Config and DB preserved in ~/.local/state/"
