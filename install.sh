#!/bin/bash
# SF Notification Center — Installer
# Salesforce case status monitor with email alerts & web dashboard
set -e

echo "╔═══════════════════════════════════════════════╗"
echo "║   SF Notification Center — Installer          ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

BIN_DIR="$HOME/.local/bin"
LA_DIR="$HOME/Library/LaunchAgents"
STATE_DIR="$HOME/.local/state"
LOG_DIR="$HOME/Library/Logs"

mkdir -p "$BIN_DIR" "$LA_DIR" "$STATE_DIR" "$LOG_DIR"

# ── 1. Homebrew ──────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo "→ Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
else
    echo "✓ Homebrew found"
fi

# ── 2. Python 3 ─────────────────────────────────────
if ! command -v python3 &>/dev/null && ! command -v /opt/homebrew/bin/python3 &>/dev/null; then
    echo "→ Python 3 not found. Installing..."
    brew install python3
else
    echo "✓ Python 3 found ($(python3 --version 2>/dev/null || /opt/homebrew/bin/python3 --version))"
fi

PYTHON=$(command -v python3 2>/dev/null || echo "/opt/homebrew/bin/python3")

# ── 3. pip (ensure available) ────────────────────────
if ! "$PYTHON" -m pip --version &>/dev/null; then
    echo "→ pip not found. Installing..."
    "$PYTHON" -m ensurepip --upgrade 2>/dev/null || brew install python3
else
    echo "✓ pip found"
fi

# ── 4. Python dependencies ───────────────────────────
echo "→ Installing Python packages..."
"$PYTHON" -m pip install aiosmtpd --quiet --break-system-packages 2>/dev/null \
    || "$PYTHON" -m pip install aiosmtpd --quiet 2>/dev/null \
    || pip3 install aiosmtpd --quiet
echo "✓ aiosmtpd installed"

# ── 5. Google Chrome ─────────────────────────────────
if [ -d "/Applications/Google Chrome.app" ]; then
    echo "✓ Google Chrome found"
else
    echo "→ Google Chrome not found. Installing via Homebrew..."
    brew install --cask google-chrome
fi

# ── 6. macOS Mail.app ────────────────────────────────
if [ -d "/System/Applications/Mail.app" ] || [ -d "/Applications/Mail.app" ]; then
    echo "✓ Mail.app found"
else
    echo "⚠ Mail.app not found (comes built-in with macOS)"
fi

# ── 7. Copy scripts ─────────────────────────────────
echo "→ Installing scripts to $BIN_DIR..."
cp sf-case-poller "$BIN_DIR/sf-case-poller"
cp local-mailserver "$BIN_DIR/local-mailserver"
chmod +x "$BIN_DIR/sf-case-poller" "$BIN_DIR/local-mailserver"
echo "  Using Python: $PYTHON"

# ── 8. LaunchAgent plists ────────────────────────────
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
echo "║   ✅ Installation complete!                   ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""
echo "  Dependencies installed:"
echo "    ✓ Homebrew"
echo "    ✓ Python 3 + pip"
echo "    ✓ aiosmtpd (Python SMTP library)"
echo "    ✓ Google Chrome"
echo "    ✓ Mail.app"
echo ""
echo "  Before starting, make sure:"
echo "    1. Google Chrome is open & logged into Salesforce"
echo "    2. Chrome → View → Developer → Allow JavaScript from Apple Events ✓"
echo "    3. Mail.app is open & configured with your email"
echo ""
echo "  Commands:"
echo "    ./start.sh          — Start all services"
echo "    ./stop.sh           — Stop all services"
echo "    ./uninstall.sh      — Remove everything"
echo ""
echo "  Dashboard:  http://localhost:8090"
echo "  Logs:       ~/Library/Logs/sf-case-poller.log"
