#!/bin/bash
set -e

echo "=== Screen Blocker Installation ==="

# Check for bun
if ! command -v bun &> /dev/null; then
    echo "Error: Bun is required. Install from https://bun.sh"
    exit 1
fi

# Check for swift
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is required. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.claude/scripts"
LOG_DIR="$HOME/.claude/logs"

echo "Installing to: $INSTALL_DIR"

# Create directories
mkdir -p "$INSTALL_DIR/screen-blocker"
mkdir -p "$LOG_DIR"

# Build Swift overlay
echo "Building Swift overlay..."
cd "$SCRIPT_DIR/screen-blocker"
swift build -c release

# Copy files
echo "Copying files..."
cp "$SCRIPT_DIR/screen-safety.ts" "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/screen-blocker/.build" "$INSTALL_DIR/screen-blocker/"
cp "$SCRIPT_DIR/screen-blocker/Package.swift" "$INSTALL_DIR/screen-blocker/"
mkdir -p "$INSTALL_DIR/screen-blocker/Sources"
cp "$SCRIPT_DIR/screen-blocker/Sources/main.swift" "$INSTALL_DIR/screen-blocker/Sources/"

# Install LaunchAgent
echo "Installing LaunchAgent..."
PLIST_FILE="$HOME/Library/LaunchAgents/com.user.screen-safety.plist"

# Update paths in plist
BUN_PATH=$(which bun)
cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.screen-safety</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BUN_PATH</string>
        <string>run</string>
        <string>$INSTALL_DIR/screen-safety.ts</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/screen-safety.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/screen-safety.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$(dirname "$BUN_PATH"):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
EOF

# Load LaunchAgent
echo "Loading daemon..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true
launchctl load "$PLIST_FILE"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "The daemon is now running. When you first open Chrome,"
echo "macOS will ask for Automation permission."
echo ""
echo "Grant permission in:"
echo "  System Preferences > Privacy & Security > Automation > Google Chrome"
echo ""
echo "View logs: tail -f $LOG_DIR/screen-safety.log"
echo ""
