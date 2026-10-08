#!/bin/bash
# SF Notification Center — Installer
# Salesforce case status monitor with email alerts & web dashboard
set -e

echo "╔═══════════════════════════════════════════════╗"
echo "║   SF Notification Center — Installer          ║"
echo "╚═══════════════════════════════════════════════╝"

BIN_DIR="$HOME/.local/bin"
LA_DIR="$HOME/Library/LaunchAgents"
STATE_DIR="$HOME/.local/state"
LOG_DIR="$HOME/Library/Logs"

mkdir -p "$BIN_DIR" "$LA_DIR" "$STATE_DIR" "$LOG_DIR"

# Install Python dependency
echo "→ Installing aiosmtpd..."
if command -v pip3 &>/dev/null; then
    pip3 install aiosmtpd --quiet
elif command -v pip &>/dev/null; then
    pip install aiosmtpd --quiet
elif command -v python3 &>/dev/null; then
    python3 -m pip install aiosmtpd --quiet
elif command -v /opt/homebrew/bin/python3 &>/dev/null; then
    /opt/homebrew/bin/python3 -m pip install aiosmtpd --quiet
else
    echo "❌ No pip/python3 found. Install Python 3 first: brew install python3"
    exit 1
fi

# Copy scripts
echo "→ Installing scripts to $BIN_DIR..."
cp sf-case-poller "$BIN_DIR/sf-case-poller"
cp local-mailserver "$BIN_DIR/local-mailserver"
chmod +x "$BIN_DIR/sf-case-poller" "$BIN_DIR/local-mailserver"

# Detect python path
PYTHON=$(which python3 2>/dev/null || echo "/opt/homebrew/bin/python3")
echo "  Using Python: $PYTHON"

# Generate LaunchAgent plists with correct python path
echo "→ Installing LaunchAgents..."

cat > "$LA_DIR/com.mzakria.local-mailserver.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mzakria.local-mailserver</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON</string>
        <string>$BIN_DIR/local-mailserver</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/local-mailserver-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/local-mailserver-stderr.log</string>
</dict>
</plist>
PLIST

cat > "$LA_DIR/com.mzakria.sf-case-poller.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.mzakria.sf-case-poller</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON</string>
        <string>$BIN_DIR/sf-case-poller</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/sf-case-poller-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/sf-case-poller-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SF_POLL_INTERVAL</key>
        <string>300</string>
        <key>SF_NOTIFY_EMAIL</key>
        <string>mzakria@redhat.com</string>
    </dict>
</dict>
</plist>
PLIST

echo ""
echo "╔═══════════════════════════════════════════════╗"
echo "║   Installation complete!                      ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
echo "Before starting, make sure:"
echo "  1. Google Chrome is open & logged into Salesforce"
echo "  2. Chrome → View → Developer → Allow JavaScript from Apple Events ✓"
echo "  3. Mail.app is open & configured"
echo ""
echo "Start commands:"
echo "  ./start.sh          — Start all services"
echo "  ./stop.sh           — Stop all services"
echo ""
echo "Dashboard:  http://localhost:8090"
echo "Logs:       ~/Library/Logs/sf-case-poller.log"
