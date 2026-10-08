#!/bin/bash
# SF Case Notification Center - One-click installer
# Run: curl -sL <repo>/install.sh | bash
# Or:  ./install.sh

set -e
echo "=== SF Case Notification Center - Installer ==="

# Detect username
USER_NAME=$(whoami)
USER_HOME=$(eval echo ~$USER_NAME)
SUPPORTSHELL_USER="${SUPPORTSHELL_USER:-$USER_NAME}"

# 1. Install poller script
echo "[1/4] Installing poller..."
mkdir -p "$USER_HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/sf-case-poller" "$USER_HOME/.local/bin/sf-case-poller"
chmod +x "$USER_HOME/.local/bin/sf-case-poller"

# Add to PATH if needed
if ! echo "$PATH" | grep -q "$USER_HOME/.local/bin"; then
    for rc in "$USER_HOME/.zshrc" "$USER_HOME/.bashrc"; do
        if [ -f "$rc" ]; then
            grep -q '.local/bin' "$rc" 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$rc"
        fi
    done
    export PATH="$USER_HOME/.local/bin:$PATH"
fi

# 2. Create config
echo "[2/4] Creating config..."
mkdir -p "$USER_HOME/.local/state"
if [ ! -f "$USER_HOME/.local/state/sf-poller-config.json" ]; then
    cat > "$USER_HOME/.local/state/sf-poller-config.json" << EOF
{
  "case_list_url": "https://redhatsupport.lightning.force.com/lightning/o/Case/list?filterName=My_ca",
  "notify_email": "${SUPPORTSHELL_USER}@redhat.com",
  "supportshell_user": "${SUPPORTSHELL_USER}"
}
EOF
    echo "  Config: $USER_HOME/.local/state/sf-poller-config.json"
else
    echo "  Config already exists, skipping"
fi

# 3. Install LaunchAgent
echo "[3/4] Installing LaunchAgent (auto-start on login)..."
mkdir -p "$USER_HOME/Library/LaunchAgents"
cat > "$USER_HOME/Library/LaunchAgents/com.${SUPPORTSHELL_USER}.sf-case-poller.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.${SUPPORTSHELL_USER}.sf-case-poller</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>${USER_HOME}/.local/bin/sf-case-poller</string>
        <string>poll</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SF_POLL_INTERVAL</key>
        <string>60</string>
    </dict>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
    <key>StandardOutPath</key>
    <string>${USER_HOME}/Library/Logs/sf-case-poller.log</string>
    <key>StandardErrorPath</key>
    <string>${USER_HOME}/Library/Logs/sf-case-poller.log</string>
</dict>
</plist>
EOF

# Load the agent
launchctl unload "$USER_HOME/Library/LaunchAgents/com.${SUPPORTSHELL_USER}.sf-case-poller.plist" 2>/dev/null || true
launchctl load "$USER_HOME/Library/LaunchAgents/com.${SUPPORTSHELL_USER}.sf-case-poller.plist"

# 4. Start
echo "[4/4] Starting poller..."
launchctl start "com.${SUPPORTSHELL_USER}.sf-case-poller"
sleep 3

echo ""
echo "=== INSTALLED SUCCESSFULLY ==="
echo ""
echo "Prerequisites (do these once):"
echo "  1. Open Chrome with your Salesforce case list view"
echo "  2. SSH must work: ssh ${SUPPORTSHELL_USER}@supportshell-1.sush-001.prod.us-west-2.aws.redhat.com"
echo "  3. Run on supportshell: redhat-hydra-auth --production"
echo ""
echo "Commands:"
echo "  sf-case-poller --status    # Check status"
echo "  sf-case-poller --health    # Health check"
echo "  sf-case-poller --history   # Notification history"
echo "  sf-case-poller --test-email # Test email"
echo ""
echo "  launchctl stop com.${SUPPORTSHELL_USER}.sf-case-poller   # Stop"
echo "  launchctl start com.${SUPPORTSHELL_USER}.sf-case-poller  # Start"
echo ""
echo "Logs: tail -f ~/Library/Logs/sf-case-poller.log"
echo ""
