# Screen Blocker

A macOS daemon that protects you from embarrassing moments during screen sharing. Detects when Zoom, Teams, or Google Meet is running and alerts you if sensitive content is open in Chrome.

## Features

- Detects Zoom, Microsoft Teams, WebEx, and Google Meet
- Scans Chrome tabs for adult content (URL domains + tab title keywords)
- Shows fullscreen blocking overlay requiring explicit dismissal
- Runs automatically on login via LaunchAgent
- Low resource usage (~0.1% CPU)

## Requirements

- macOS 13+ (Ventura or later)
- [Bun](https://bun.sh) runtime
- Google Chrome
- Xcode Command Line Tools (for Swift compilation)

## Installation

### Quick Install

```bash
./install.sh
```

### Manual Install

1. **Build the Swift overlay:**
   ```bash
   cd screen-blocker
   swift build -c release
   ```

2. **Copy files:**
   ```bash
   mkdir -p ~/.claude/scripts/screen-blocker
   cp screen-safety.ts ~/.claude/scripts/
   cp -r screen-blocker/.build ~/.claude/scripts/screen-blocker/
   ```

3. **Install LaunchAgent:**
   ```bash
   # Edit paths in plist if needed
   cp com.user.screen-safety.plist ~/Library/LaunchAgents/
   ```

4. **Load the daemon:**
   ```bash
   launchctl load ~/Library/LaunchAgents/com.user.screen-safety.plist
   ```

5. **Grant permissions** when prompted:
   - System Preferences > Privacy & Security > Automation > Google Chrome

## Configuration

Edit `screen-safety.ts` to customize:

### Blocked Domains

```typescript
const BLOCKED_DOMAINS = [
  "pornhub.com",
  "xvideos.com",
  // Add your own...
];
```

### Blocked Keywords

```typescript
const BLOCKED_KEYWORDS = [
  "porn",
  "xxx",
  "nsfw",
  // Add your own...
];
```

### Check Interval

```typescript
const CHECK_INTERVAL_MS = 10000; // 10 seconds
```

## Usage

The daemon runs automatically in the background. When a meeting app is detected:

1. Chrome tabs are scanned every 10 seconds
2. If sensitive content is found, a fullscreen overlay appears
3. Click "I Have Closed Sensitive Tabs" or press ESC to dismiss

### View Logs

```bash
tail -f ~/.claude/logs/screen-safety.log
```

### Manual Control

```bash
# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.user.screen-safety.plist

# Start daemon
launchctl load ~/Library/LaunchAgents/com.user.screen-safety.plist

# Check status
launchctl list | grep screen-safety
```

## Uninstall

```bash
launchctl unload ~/Library/LaunchAgents/com.user.screen-safety.plist
rm ~/Library/LaunchAgents/com.user.screen-safety.plist
rm -rf ~/.claude/scripts/screen-safety.ts
rm -rf ~/.claude/scripts/screen-blocker
rm -rf ~/.claude/logs/screen-safety.log
```

## How It Works

```
┌─────────────────────────────────────────────────────┐
│              LaunchAgent (auto-start)               │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│             screen-safety.ts (Bun)                  │
│  ┌───────────────────────────────────────────────┐  │
│  │  Every 10 seconds:                            │  │
│  │  1. pgrep zoom.us / Microsoft Teams           │  │
│  │  2. If meeting: AppleScript get Chrome tabs   │  │
│  │  3. Match against blocklist                   │  │
│  │  4. If risky → show blocking overlay          │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│       Swift Overlay (fullscreen, modal)             │
│  - Covers all screens                               │
│  - Above fullscreen apps                            │
│  - Requires explicit dismissal                      │
└─────────────────────────────────────────────────────┘
```

## License

MIT
