#!/bin/bash
# ╔═══════════════════════════════════════════════════════════════╗
# ║  SF Notification Center — One-command installer              ║
# ║  Installs, configures, and starts everything automatically.  ║
# ╚═══════════════════════════════════════════════════════════════╝
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$HOME"
BIN_DIR="$HOME_DIR/.local/bin"
STATE_DIR="$HOME_DIR/.local/state"
LOG_DIR="$HOME_DIR/Library/Logs"
LAUNCH_DIR="$HOME_DIR/Library/LaunchAgents"
PYTHON="$(command -v python3)"
USER_NAME="${USER:-mzakria}"

POLLER_LABEL="com.mzakria.sf-case-poller"
MAILER_LABEL="com.mzakria.local-mailserver"

G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[1;34m'; N='\033[0m'; BOLD='\033[1m'

ok()   { echo -e "  ${G}✓${N} $1"; }
warn() { echo -e "  ${Y}⚠${N} $1"; }
fail() { echo -e "  ${R}✗${N} $1"; }
step() { echo -e "\n${B}[$1]${N} ${BOLD}$2${N}"; }

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════╗${N}"
echo -e "${BOLD}║   SF Notification Center — Automatic Installer       ║${N}"
echo -e "${BOLD}║   GraphQL-powered • No browser needed                ║${N}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════╝${N}"

# ────────────────────────────────────────────────────────────────
step "1/8" "Checking prerequisites"
# ────────────────────────────────────────────────────────────────

if [ -z "$PYTHON" ]; then
    fail "Python3 not found. Install: brew install python3"
    exit 1
fi
ok "Python3: $PYTHON"

if ! command -v ssh &>/dev/null; then
    fail "SSH not found"
    exit 1
fi
ok "SSH available"

# ────────────────────────────────────────────────────────────────
step "2/8" "Installing scripts to ~/.local/bin/"
# ────────────────────────────────────────────────────────────────

mkdir -p "$BIN_DIR"
cp "$REPO_DIR/sf-case-poller" "$BIN_DIR/sf-case-poller"
chmod +x "$BIN_DIR/sf-case-poller"
ok "sf-case-poller installed"

cp "$REPO_DIR/local-mailserver" "$BIN_DIR/local-mailserver"
chmod +x "$BIN_DIR/local-mailserver"
ok "local-mailserver (dashboard + SMTP) installed"

# ────────────────────────────────────────────────────────────────
step "3/8" "Configuring PATH"
# ────────────────────────────────────────────────────────────────

ZSHRC="$HOME_DIR/.zshrc"
if [ -f "$ZSHRC" ] && grep -q '.local/bin' "$ZSHRC"; then
    ok "PATH already configured in .zshrc"
else
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
    ok "Added ~/.local/bin to PATH in .zshrc"
fi
export PATH="$BIN_DIR:$PATH"

# ────────────────────────────────────────────────────────────────
step "4/8" "Creating config"
# ────────────────────────────────────────────────────────────────

mkdir -p "$STATE_DIR"
CFG="$STATE_DIR/sf-poller-config.json"

if [ -f "$CFG" ]; then
    ok "Config already exists: $CFG"
else
    # Ask for email (with sensible default)
    DEFAULT_EMAIL="${USER_NAME}@redhat.com"
    read -p "  Notification email [$DEFAULT_EMAIL]: " INPUT_EMAIL
    EMAIL="${INPUT_EMAIL:-$DEFAULT_EMAIL}"

    # Ask for supportshell user (with sensible default)
    read -p "  Supportshell username [$USER_NAME]: " INPUT_SSH
    SSH_USER="${INPUT_SSH:-$USER_NAME}"

    cat > "$CFG" <<CFGEOF
{
  "notify_email": "$EMAIL",
  "supportshell_user": "$SSH_USER"
}
CFGEOF
    ok "Config created: $CFG"
fi

# Read SSH user from config for later steps
SSH_USER=$(python3 -c "import json; print(json.load(open('$CFG')).get('supportshell_user','$USER_NAME'))" 2>/dev/null || echo "$USER_NAME")

# ────────────────────────────────────────────────────────────────
step "5/8" "Testing SSH to supportshell"
# ────────────────────────────────────────────────────────────────

SSH_HOST="${SSH_USER}@supportshell-1.sush-001.prod.us-west-2.aws.redhat.com"
SSH_OK=0

if ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_HOST" "echo SSH_OK" 2>/dev/null | grep -q SSH_OK; then
    ok "SSH to supportshell works"
    SSH_OK=1
else
    warn "SSH failed — run: ssh-copy-id $SSH_HOST"
    echo -e "    ${Y}The poller needs SSH to supportshell for GraphQL data.${N}"
    echo -e "    ${Y}Fix it and re-run install.sh, or the poller will retry automatically.${N}"
fi

# ────────────────────────────────────────────────────────────────
step "6/8" "Checking GraphQL token on supportshell"
# ────────────────────────────────────────────────────────────────

if [ "$SSH_OK" -eq 1 ]; then
    TOKEN_OUT=$(ssh -o ConnectTimeout=10 "$SSH_HOST" \
        "test -f ~/.cache/hydra-mcp/tokens/redhat-sso-token.json && echo GQL_OK; \
         test -f ~/.yank/oidc-tokens.json && echo YANK_OK" 2>/dev/null || true)

    if echo "$TOKEN_OUT" | grep -q GQL_OK; then
        ok "GraphQL token found (hydra-mcp)"
    elif echo "$TOKEN_OUT" | grep -q YANK_OK; then
        ok "Yank token found (fallback)"
        warn "For best results, run on supportshell: redhat-hydra-auth --production"
    else
        warn "No GraphQL token found on supportshell"
        echo -e "    ${Y}Run once:  ssh $SSH_HOST${N}"
        echo -e "    ${Y}Then:      redhat-hydra-auth --production${N}"
    fi
else
    warn "Skipped — SSH not working"
fi

# ────────────────────────────────────────────────────────────────
step "7/8" "Starting services"
# ────────────────────────────────────────────────────────────────

mkdir -p "$LAUNCH_DIR" "$LOG_DIR"

# --- Start Mail.app if not running ---
if ! pgrep -x "Mail" > /dev/null 2>&1; then
    open -a Mail
    ok "Started Mail.app"
    sleep 2
else
    ok "Mail.app already running"
fi

# --- Local Mailserver (SMTP + Dashboard on port 8090) ---
launchctl unload "$LAUNCH_DIR/$MAILER_LABEL.plist" 2>/dev/null || true
pkill -f "local-mailserver" 2>/dev/null || true
sleep 1

cat > "$LAUNCH_DIR/$MAILER_LABEL.plist" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$MAILER_LABEL</string>
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
    <string>/tmp/local-mailserver.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/local-mailserver.log</string>
</dict>
</plist>
PLISTEOF
launchctl load "$LAUNCH_DIR/$MAILER_LABEL.plist"
ok "Local mailserver started (SMTP :2525 + Dashboard :8090)"

# --- SF Case Poller ---
launchctl unload "$LAUNCH_DIR/$POLLER_LABEL.plist" 2>/dev/null || true
sleep 1

cat > "$LAUNCH_DIR/$POLLER_LABEL.plist" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$POLLER_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON</string>
        <string>$BIN_DIR/sf-case-poller</string>
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
    <string>$LOG_DIR/sf-case-poller.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/sf-case-poller.log</string>
</dict>
</plist>
PLISTEOF
launchctl load "$LAUNCH_DIR/$POLLER_LABEL.plist"
launchctl start "$POLLER_LABEL"
ok "SF case poller started (every 60s)"

# ────────────────────────────────────────────────────────────────
step "8/8" "Verifying"
# ────────────────────────────────────────────────────────────────

sleep 3

# Check dashboard
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8090 2>/dev/null | grep -q 200; then
    ok "Dashboard responding at http://localhost:8090"
else
    warn "Dashboard not responding yet (may take a few seconds)"
fi

# Check SMTP
if python3 -c "import smtplib; s=smtplib.SMTP('127.0.0.1',2525,timeout=3); s.noop(); s.quit()" 2>/dev/null; then
    ok "Local SMTP relay ready on port 2525"
else
    warn "SMTP not responding yet (may take a few seconds)"
fi

# Wait for first poll
echo ""
echo -e "  ${Y}Waiting for first poll cycle...${N}"
for i in $(seq 1 20); do
    if [ -f "$STATE_DIR/sf-notification-center.db" ]; then
        CASES=$(python3 -c "
import sqlite3
conn = sqlite3.connect('$STATE_DIR/sf-notification-center.db')
try:
    c = conn.execute('SELECT COUNT(*) FROM cases').fetchone()[0]
    print(c)
except:
    print(0)
" 2>/dev/null || echo "0")
        if [ "$CASES" -gt 0 ]; then
            ok "First poll complete — $CASES cases tracked"
            break
        fi
    fi
    sleep 2
done

# Open dashboard
open "http://localhost:8090" 2>/dev/null || true

echo ""
echo -e "${G}╔═══════════════════════════════════════════════════════╗${N}"
echo -e "${G}║  ${BOLD}✅ Installation complete!${N}${G}                              ║${N}"
echo -e "${G}║                                                       ║${N}"
echo -e "${G}║  Dashboard:   ${BOLD}http://localhost:8090${N}${G}                    ║${N}"
echo -e "${G}║  Logs:        ${BOLD}sf-case-poller logs${N}${G}                      ║${N}"
echo -e "${G}║  Health:      ${BOLD}sf-case-poller health${N}${G}                    ║${N}"
echo -e "${G}║  Uninstall:   ${BOLD}sf-case-poller uninstall${N}${G}                 ║${N}"
echo -e "${G}║                                                       ║${N}"
echo -e "${G}║  Data source: Red Hat GraphQL API (no browser needed) ║${N}"
echo -e "${G}║  Polling:     Every 60 seconds                        ║${N}"
echo -e "${G}╚═══════════════════════════════════════════════════════╝${N}"
