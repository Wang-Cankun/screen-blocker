#!/usr/bin/env bun
/**
 * Screen-Sharing Safety Daemon
 * Detects risky Chrome tabs when Zoom/Teams is running
 */

const CHECK_INTERVAL_MS = 10000; // 10 seconds

// === BLOCKLISTS ===
const BLOCKED_DOMAINS = [
  // Common sites
  "pornhub.com",
  "xvideos.com",
  "xnxx.com",
  "xhamster.com",
  "redtube.com",
  "youporn.com",
  "tube8.com",
  "spankbang.com",
  "chaturbate.com",
  "onlyfans.com",
  "fansly.com",
  "eporner.com",
  "xnxx.tv",
  "porn.com",
  "brazzers.com",
  "bangbros.com",
  "realitykings.com",
  "naughtyamerica.com",
  "reddit.com/r/nsfw",
  "reddit.com/r/gonewild",
  "reddit.com/r/porn",
  // From your bookmarks (Profile 2)
  "91porn.com",
  "18comic.vip",
  "hanime1.me",
  "jable.tv",
  "missav.ws",
  "bad.news",
];

const BLOCKED_KEYWORDS = [
  "porn",
  "xxx",
  "nsfw",
  "onlyfans",
  "chaturbate",
  "naked",
  "nude",
  "sex video",
  "adult video",
  "hentai",
  "camgirl",
  "livecam",
];

// === NSFW CHROME PROFILES ===
// Any window from these profiles is considered risky
const NSFW_PROFILES = ["33"];

// === TYPES ===
interface ChromeTab {
  windowId: number;
  tabIndex: number;
  url: string;
  title: string;
  windowName: string; // Contains profile name
}

// === PROCESS DETECTION ===
async function isMeetingAppRunning(): Promise<boolean> {
  const meetingProcesses = ["zoom.us", "Microsoft Teams", "webexmeetings"];

  for (const proc of meetingProcesses) {
    const result = Bun.spawnSync(["pgrep", "-f", proc]);
    if (result.exitCode === 0) {
      return true;
    }
  }

  // Also check for browser-based meetings (Zoom web, Google Meet)
  try {
    const tabs = await getChromeTabs();
    for (const tab of tabs) {
      if (
        tab.url.includes("zoom.us/wc") ||
        tab.url.includes("meet.google.com")
      ) {
        return true;
      }
    }
  } catch {
    // Ignore errors checking tabs
  }

  return false;
}

// === CHROME TAB ACCESS ===
async function getChromeTabs(): Promise<ChromeTab[]> {
  const script = `
    set output to ""
    tell application "Google Chrome"
      if it is running then
        repeat with w in windows
          set wid to id of w
          set wname to name of w
          set idx to 1
          repeat with t in tabs of w
            set output to output & wid & "||" & idx & "||" & (URL of t) & "||" & (title of t) & "||" & wname & "\\n"
            set idx to idx + 1
          end repeat
        end repeat
      end if
    end tell
    return output
  `;

  const result = Bun.spawnSync(["osascript", "-e", script]);
  const output = result.stdout.toString().trim();

  const tabs: ChromeTab[] = [];
  for (const line of output.split("\n")) {
    if (!line.trim()) continue;
    const parts = line.split("||");
    if (parts.length >= 4) {
      tabs.push({
        windowId: parseInt(parts[0]) || 0,
        tabIndex: parseInt(parts[1]) || 0,
        url: parts[2].toLowerCase(),
        title: parts[3].toLowerCase(),
        windowName: parts[4] || "",
      });
    }
  }

  return tabs;
}

// === RISK DETECTION ===
function isRiskyTab(tab: ChromeTab): boolean {
  // Check if tab is from an NSFW profile (e.g., "33")
  // Chrome window names often include "- Profile Name" or just show profile name
  for (const profile of NSFW_PROFILES) {
    if (
      tab.windowName.includes(`- ${profile}`) ||
      tab.windowName.includes(`Profile ${profile}`) ||
      tab.windowName === profile ||
      tab.windowName.endsWith(` ${profile}`)
    ) {
      return true;
    }
  }

  // Check domain blocklist
  for (const domain of BLOCKED_DOMAINS) {
    if (tab.url.includes(domain.toLowerCase())) {
      return true;
    }
  }

  // Check title keywords
  for (const keyword of BLOCKED_KEYWORDS) {
    if (tab.title.includes(keyword.toLowerCase())) {
      return true;
    }
  }

  return false;
}

// === BLOCKING OVERLAY ===
let overlayActive = false;
let overlayProcess: ReturnType<typeof Bun.spawn> | null = null;

async function showBlockingOverlay(riskyTabs: ChromeTab[]) {
  if (overlayActive) return;

  const tabList = riskyTabs
    .map((t) => {
      try {
        return new URL(t.url).hostname;
      } catch {
        return t.url.slice(0, 50);
      }
    })
    .join("\\n  - ");

  // Try Swift overlay first
  const swiftBinary = `${import.meta.dir}/screen-blocker/.build/release/screen-blocker`;
  const swiftExists = await Bun.file(swiftBinary).exists();

  if (swiftExists) {
    log("Showing Swift overlay");
    overlayActive = true;
    try {
      overlayProcess = Bun.spawn([swiftBinary], {
        stdout: "inherit",
        stderr: "inherit",
      });
      await overlayProcess.exited;
    } catch (err) {
      log(`Swift overlay error: ${err}`);
    }
    overlayActive = false;
    overlayProcess = null;
  } else {
    // Fallback to AppleScript alert
    log("Showing AppleScript alert (Swift binary not found)");
    overlayActive = true;

    const alertScript = `
      display alert "Screen Sharing Safety Warning" message "Risky content detected while meeting app is running:\\n\\n  - ${tabList}\\n\\nClose these tabs before sharing your screen!" as critical buttons {"I'll Close Them"} default button 1
    `;

    const result = Bun.spawnSync(["osascript", "-e", alertScript]);
    if (result.exitCode !== 0) {
      log(`Alert error: ${result.stderr.toString()}`);
    }

    overlayActive = false;
  }
}

// === LOGGING ===
function log(msg: string) {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${msg}`);
}

// === MAIN LOOP ===
async function checkLoop() {
  try {
    const meetingActive = await isMeetingAppRunning();

    if (!meetingActive) {
      return; // No meeting, skip checks
    }

    log("Meeting app detected, checking Chrome tabs...");

    const tabs = await getChromeTabs();
    const riskyTabs = tabs.filter(isRiskyTab);

    if (riskyTabs.length > 0 && !overlayActive) {
      log(`WARNING: ${riskyTabs.length} risky tab(s) found!`);
      riskyTabs.forEach((t) => log(`  - ${t.url}`));
      await showBlockingOverlay(riskyTabs);
    } else if (riskyTabs.length === 0) {
      log("All tabs safe");
    }
  } catch (err) {
    log(`Error: ${err}`);
  }
}

// === STARTUP ===
log("Screen safety daemon started");
log(`Check interval: ${CHECK_INTERVAL_MS}ms`);
log(`Blocked domains: ${BLOCKED_DOMAINS.length}`);
log(`Blocked keywords: ${BLOCKED_KEYWORDS.length}`);
log(`NSFW profiles: ${NSFW_PROFILES.join(", ")}`);

// Run immediately then start interval
checkLoop();
setInterval(checkLoop, CHECK_INTERVAL_MS);

// Handle graceful shutdown
process.on("SIGTERM", () => {
  log("Received SIGTERM, shutting down...");
  if (overlayProcess) {
    overlayProcess.kill();
  }
  process.exit(0);
});

process.on("SIGINT", () => {
  log("Received SIGINT, shutting down...");
  if (overlayProcess) {
    overlayProcess.kill();
  }
  process.exit(0);
});
