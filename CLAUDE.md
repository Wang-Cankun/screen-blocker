# Claude Code Instructions

## Project Overview

Screen sharing safety daemon for macOS. Detects meeting apps + scans Chrome for adult content.

## File Structure

```
screen-blocker/
├── screen-safety.ts          # Main Bun daemon
├── screen-blocker/           # Swift overlay app
│   ├── Package.swift
│   └── Sources/main.swift
├── com.user.screen-safety.plist  # LaunchAgent config
├── install.sh                # Installation script
└── README.md
```

## Build Commands

```bash
# Build Swift overlay
cd screen-blocker && swift build -c release

# Run daemon manually (for testing)
bun run screen-safety.ts

# Test overlay
./screen-blocker/.build/release/screen-blocker
```

## Adding Blocked Domains

Edit `screen-safety.ts`:

```typescript
const BLOCKED_DOMAINS = [
  // Add new domain here
  "example.com",
];
```

## Adding Blocked Keywords

Edit `screen-safety.ts`:

```typescript
const BLOCKED_KEYWORDS = [
  // Add new keyword here
  "keyword",
];
```

## Testing

1. Start a meeting app (Zoom/Teams) or open `meet.google.com`
2. Open a blocked domain in Chrome
3. Overlay should appear within 4 seconds
4. Check logs: `tail -f ~/.claude/logs/screen-safety.log`

## LaunchAgent Management

```bash
# Reload after changes
launchctl unload ~/Library/LaunchAgents/com.user.screen-safety.plist
launchctl load ~/Library/LaunchAgents/com.user.screen-safety.plist

# View logs
tail -f ~/.claude/logs/screen-safety.log
tail -f ~/.claude/logs/screen-safety.error.log
```

## Key Components

### screen-safety.ts
- `isMeetingAppRunning()`: Checks for Zoom/Teams/Meet via pgrep
- `getChromeTabs()`: AppleScript to get all Chrome tab URLs/titles
- `isRiskyTab()`: Matches against blocklists
- `showBlockingOverlay()`: Spawns Swift binary or falls back to AppleScript

### screen-blocker (Swift)
- `NSWindow` at `maximumWindow` level
- Covers all screens
- ESC key handler for dismiss
- No dock icon (accessory activation policy)
