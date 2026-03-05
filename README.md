# Tendies App

macOS menu bar app that shows your realized day-trading P&L at a glance — like battery percentage, but for your gains. Companion to the [`tendies`](https://github.com/batjaa/tendies) CLI.

## Install

```bash
brew install --cask batjaa/tools/tendies-app
```

Requires the `tendies` CLI:

```bash
brew install batjaa/tap/tendies
```

## How It Works

The app sits in your macOS menu bar showing net P&L:

```
▲ +$1,234     positive day
▼ -$567       negative day
● $0          flat / no trades
▲ +$3,456 (w) weekend fallback to week
```

Click to open a popover with per-timeframe breakdown (Day / Week / Month), drill into per-ticker P&L, and see individual executions with FIFO-matched opening legs.

Under the hood, the app runs `tendies --json` on a timer and parses the structured output. No direct Schwab API calls from the app — the CLI handles all data fetching.

## Authentication

The app handles OAuth login natively — click "Login with Schwab" in the popover, authenticate in the browser, and the app receives the token automatically.

- Uses `ASWebAuthenticationSession` with a `tendies://` custom URL scheme
- PKCE flow against the Tendies broker backend (Laravel Passport)
- Tokens stored in macOS Keychain, shared with the CLI (same `go-keyring` format)
- After logging in via the app, `tendies --day` in Terminal works without separate auth

### Config

The app reads `~/.tendies/config.json` (same config the CLI uses):

- `broker_client_id` — required for login
- `broker_url` — defaults to `https://tendies.batjaa.site`

### Backend Setup

The Passport PKCE client must include `tendies://callback` in its redirect URIs:

```bash
php artisan tinker
$client = \App\Models\PassportClient::first();
$uris = $client->redirect_uris;
$uris[] = 'tendies://callback';
$client->redirect_uris = $uris;
$client->save();
```

## Development

Requires macOS 14+ and Swift 5.9+ (Xcode 15+).

```bash
make dev      # debug build + update .app bundle
make watch    # auto-rebuild on file changes (requires fswatch)
make build    # release build
make bundle   # release build + create .app bundle
make install  # bundle + copy to /Applications
make clean    # remove build artifacts
```

## Architecture

```
Sources/TendiesApp/
├── TendiesApp.swift          # @main entry, MenuBarExtra
├── AppState.swift            # Observable state: auth, refresh, settings
├── CLIRunner.swift           # Runs `tendies --json`, parses output
├── AuthService.swift         # OAuth PKCE flow (ASWebAuthenticationSession)
├── KeychainService.swift     # Keychain read/write (go-keyring compatible)
├── TendiesConfig.swift       # Reads ~/.tendies/config.json
├── Models.swift              # Codable types for CLI JSON output
├── SubscriptionService.swift # Trial/subscription status, checkout URLs
├── Helpers/Formatting.swift  # P&L and number formatting
└── Views/
    ├── PopoverView.swift     # Main popover layout (routes to login/data/error)
    ├── LoginView.swift       # "Login with Schwab" screen
    ├── HeaderView.swift      # Title bar with refresh/settings
    ├── FooterView.swift      # Last updated, trial badge, logout, quit
    ├── TimeframeRowView.swift
    ├── TickerListView.swift
    ├── ExecutionListView.swift
    ├── SubscriptionView.swift
    ├── ErrorView.swift
    └── LoadingView.swift
```

### Data Flow

1. Timer fires (default 1 min) or user clicks refresh
2. `AppState.refresh()` ensures valid auth → checks subscription → runs `tendies --json`
3. CLI subprocess returns structured JSON (timeframes, tickers, executions)
4. UI updates reactively via SwiftUI `@Observable`

### Subscription

The app enforces a subscription paywall after a 7-day free trial:

- **Free trial**: 7 days, full access
- **Pro**: $5/mo or $40/yr
- Status checked via `GET /api/v1/subscription` on the broker backend
- Checkout and billing portal via Stripe

## Stack

- **Swift / SwiftUI** — `MenuBarExtra(.window)` for menu bar widget
- **ASWebAuthenticationSession** — native OAuth with `tendies://` URL scheme
- **Security.framework** — Keychain for token storage
- **CryptoKit** — PKCE code challenge (SHA256)
- **SPM** — Swift Package Manager (no external dependencies)
- **GitHub Actions** — universal binary (arm64 + x86_64), GitHub Release, Homebrew cask update

## Release

```bash
git tag v0.1.0
git push origin main v0.1.0
```

CI builds the universal `.app`, creates a GitHub Release, and updates the Homebrew cask in [`batjaa/homebrew-tools`](https://github.com/batjaa/homebrew-tools).
