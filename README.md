<!--
  Title: CodeQuota - AI Usage Monitor for macOS Menu Bar
  Description: A native macOS menu bar app that monitors Claude Pro/Max and GitHub Copilot premium request usage limits in real-time.
  Keywords: claude usage tracker, copilot usage monitor, macos menu bar app, ai usage limits, claude pro limits, github copilot premium requests, anthropic usage, claude code usage, ai quota tracker
  Author: [your-github-username]
-->

# CodeQuota — AI Usage Monitor for macOS

> **Track your Claude Pro/Max and GitHub Copilot usage limits in real time, right from your macOS menu bar.**

CodeQuota is a native macOS menu bar app that gives you instant visibility into your AI service quotas. It monitors **Anthropic Claude** (5-hour session, weekly all-models, and weekly Sonnet limits) and **GitHub Copilot** premium request usage — so you never get rate-limited mid-workflow.

## Why CodeQuota?

If you use Claude Pro, Claude Max, or GitHub Copilot, you've hit the wall: you're deep in a coding session and suddenly — rate limited. No warning, no countdown, just a dead stop.

CodeQuota solves this by showing a **live usage indicator** in your menu bar with color-coded status (🟢 green / 🟡 yellow / 🔴 red) so you always know where you stand. It's like a fuel gauge for your AI coding tools.

**Who is this for?**

- Developers using **Claude Code**, Claude.ai, or the Claude desktop app with a Pro or Max subscription
- Anyone on a **GitHub Copilot** plan who wants to track premium request consumption per model
- Power users who rely on AI assistants daily and want to avoid surprise rate limits

## Features

- **Menu bar usage indicator** — colored status circle + percentage, visible at a glance
- **Claude usage tracking** — monitors 5-hour rolling session, weekly all-models limit, and weekly Sonnet limit
- **Copilot usage tracking** — tracks monthly premium request usage broken down by model
- **Configurable display** — choose which metric appears in the menu bar via Settings
- **Auto-refresh** — Claude usage polls every 30 seconds; Copilot every 2 minutes
- **Color-coded progress bars** — green (<50%), yellow (50–80%), red (>80%)
- **Transparent popover** — native macOS vibrancy for a clean, system-integrated look
- **Secure authentication** — Anthropic OAuth PKCE + GitHub device flow OAuth

## Screenshots

<!-- Add 1-2 screenshots here showing the menu bar icon and the expanded popover -->

## Installation

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Building from Source

```bash
git clone https://github.com/[your-username]/CodeQuota.git
cd CodeQuota
open CodeQuota.xcodeproj
# Build and run with Cmd+R
```

## Setup

### Connect Anthropic (Claude Pro / Claude Max)

1. Launch CodeQuota — it appears in your menu bar
2. Click the menu bar icon → **Settings**
3. Click **Connect to Anthropic** — opens the Anthropic authorization page in your browser
4. Authorize the app, copy the code shown on the page
5. Paste the code into the app and click **Connect**

CodeQuota uses Anthropic's OAuth PKCE flow (the same one used by Claude Code) to authenticate with your Claude Pro or Max subscription.

### Connect GitHub (Copilot Premium Requests)

1. In **Settings**, click **Connect to GitHub**
2. Copy the displayed device code
3. Open the GitHub device activation page and paste the code
4. Authorize the app — CodeQuota detects authorization automatically

CodeQuota uses GitHub's device flow OAuth and fetches your monthly premium request billing data from the GitHub API.

### Choose Your Menu Bar Metric

In **Settings**, use the **Menu Bar Metric** dropdown to select which usage stat is displayed in the menu bar:

- Claude 5-hour session usage
- Claude weekly all-models usage
- Claude weekly Sonnet usage
- Copilot monthly premium request usage

## How It Works

### Claude (Anthropic)

Once authenticated, CodeQuota polls the Anthropic usage API every 30 seconds and displays:

| Metric | Description |
|---|---|
| **5-Hour Session** | Rolling session utilization with reset countdown |
| **Weekly — All Models** | 7-day usage across all Claude models |
| **Weekly — Sonnet** | 7-day Sonnet-specific usage |

### Copilot (GitHub)

Once authenticated, CodeQuota fetches your monthly premium request billing data, showing usage counts per model against your plan's included allowance.

### Data & Security

- Credentials are stored locally in UserDefaults
- Anthropic tokens are refreshed automatically
- No telemetry, no cloud sync — everything stays on your Mac

## Project Structure

```
CodeQuota/
├── CodeQuotaApp.swift             # App entry point
├── AppDelegate.swift              # Menu bar + popover setup
├── ContentView.swift              # Main popover UI (Claude + Copilot sections)
├── UsageIconView.swift            # Menu bar icon (configurable metric)
├── ClaudeUsageManager.swift       # Claude usage data fetching and parsing
├── AnthropicAuthManager.swift     # Anthropic OAuth PKCE authentication
├── GitHubAuthManager.swift        # GitHub device flow OAuth
├── CopilotUsageManager.swift      # Copilot premium request billing
├── MenuBarMetric.swift            # Menu bar metric selection model
├── SettingsView.swift             # Connection settings UI
├── Info.plist                     # App configuration
└── CodeQuota.entitlements         # Sandbox permissions
```

## FAQ

### Does CodeQuota consume any Claude tokens or Copilot requests?

No. CodeQuota only reads usage/billing data from the respective APIs. It does not make any AI model requests.

### What Claude plans are supported?

CodeQuota works with **Claude Pro** and **Claude Max** subscriptions. It uses the same OAuth flow as Claude Code.

### What Copilot plans are supported?

Any GitHub Copilot plan that includes premium requests (Copilot Pro, Copilot Pro+, Copilot Business, Copilot Enterprise).

### Can I use this with Claude Code?

Yes. CodeQuota monitors the same underlying usage limits that apply to Claude Code, Claude.ai, the Claude desktop app, and the mobile app — they all share the same quota.

### Is my data safe?

Yes. All credentials are stored locally on your Mac. No data is sent to any third-party servers.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

MIT
