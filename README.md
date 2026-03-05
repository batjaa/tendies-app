# Tendies App

macOS menu bar app for tracking day trading P&L. Calls the `tendies` CLI for data and displays results in a popover.

## Install

```bash
brew install --cask batjaa/tools/tendies-app
```

## Authentication

The app handles OAuth login natively — click "Login with Schwab" in the popover, authenticate in the browser, and the app receives the token automatically.

- Uses `ASWebAuthenticationSession` with a `tendies://` custom URL scheme
- PKCE flow against the Tendies broker backend (Laravel Passport)
- Tokens are stored in the macOS Keychain, shared with the `tendies` CLI (same `go-keyring` format)
- After logging in via the app, `tendies --day` in Terminal works without a separate `tendies auth login`

### Config

The app reads `~/.tendies/config.json` (same config the CLI uses):

- `broker_client_id` — **required** for login
- `broker_url` — defaults to `https://tendies.batjaa.site`

### Backend setup

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

Requires macOS 14+ and Swift 5.9+.

```bash
make build    # compile
make bundle   # build + create .app bundle
make install  # bundle + copy to /Applications
make clean    # remove build artifacts
```

## Architecture

```
Sources/TendiesApp/
├── TendiesApp.swift          # @main entry, MenuBarExtra
├── AppState.swift            # Observable state: auth, refresh, settings
├── CLIRunner.swift           # Runs `tendies --json` and parses output
├── AuthService.swift         # OAuth PKCE flow (ASWebAuthenticationSession)
├── KeychainService.swift     # Keychain read/write (go-keyring compatible)
├── TendiesConfig.swift       # Reads ~/.tendies/config.json
├── Models.swift              # Codable types for CLI JSON output
├── Helpers/Formatting.swift  # Number formatting
└── Views/
    ├── PopoverView.swift     # Main popover (login or P&L)
    ├── LoginView.swift       # "Login with Schwab" screen
    ├── HeaderView.swift      # Title bar with refresh/settings
    ├── FooterView.swift      # Last updated + log out + quit
    ├── TimeframeRowView.swift
    ├── TickerListView.swift
    ├── ExecutionListView.swift
    ├── ErrorView.swift
    └── LoadingView.swift
```

## Stack

- **Swift / SwiftUI** — `MenuBarExtra` for the menu bar widget
- **ASWebAuthenticationSession** — Native OAuth with `tendies://` URL scheme
- **Security.framework** — Keychain access for token storage
- **CryptoKit** — PKCE code challenge (SHA256)
- **SPM** — Swift Package Manager for building
- **GitHub Actions** — CI/CD: builds universal binary (arm64 + x86_64), creates GitHub Release, updates Homebrew cask

## Release

```bash
git tag v0.1.0
git push origin main v0.1.0
```

CI builds the universal `.app`, creates a GitHub Release, and updates the Homebrew cask in [`batjaa/homebrew-tools`](https://github.com/batjaa/homebrew-tools).
