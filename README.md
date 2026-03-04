# Tendies App

macOS menu bar app for tracking day trading P&L.

## Install

```bash
brew install --cask batjaa/tools/tendies-app
```

## Development

Requires macOS 13+ and Swift 5.9+.

```bash
make build    # compile
make bundle   # build + create .app bundle
make install  # bundle + copy to /Applications
make clean    # remove build artifacts
```

## Stack

- **Swift / SwiftUI** — `MenuBarExtra` for the menu bar widget
- **SPM** — Swift Package Manager for building
- **GitHub Actions** — CI/CD: builds universal binary (arm64 + x86_64), creates GitHub Release, updates Homebrew cask

## Release

```bash
git tag v0.1.0
git push origin main v0.1.0
```

CI builds the universal `.app`, creates a GitHub Release, and updates the Homebrew cask in [`batjaa/homebrew-tools`](https://github.com/batjaa/homebrew-tools).
