# Desk Controller

A Mac menu-bar app for an [IKEA IDÅSEN (Linak)](https://www.ikea.com/au/en/p/idasen-desk-sit-stand-black-beige-s79280979/) sit/stand desk.

Apple Silicon only. Ad-hoc signed (not notarized).

This is a small personal fork so the desk can be driven **from the Mac**, especially via **dedicated keyboard shortcuts / AppleScript**. It is not a product. Issues and pull requests are welcome; maintenance is **best effort** and the app is not expected to move much.

[**Download the latest release**](../../releases/latest)

## Why this repo exists

The original native app is [DWilliames/idasen-desk-controller-mac](https://github.com/DWilliames/idasen-desk-controller-mac) (MIT, 2021). Last binary release: **1.0.2** (June 2022). On this machine it **just worked** — including after sleep and idle. The only reason to leave it was macOS: the nested **Launch at Login helper is Intel-only**, so Tahoe warns that support for Intel-based apps is ending (Rosetta goes away with macOS 28, ~fall 2027). That helper is what made 1.0.2 feel like a dead end.

[marcobazzani/idasen-desk-controller-mac](https://github.com/marcobazzani/idasen-desk-controller-mac) is a native Apple Silicon rebuild (v2.1.5) — credit to Marco for doing that port. On this machine, one thing didn't hold up: after the app had been sitting in the menu bar for a few hours, the sit/stand keyboard shortcuts stopped working until the app was restarted. The cause turned out to be a Bluetooth connection that still looks connected but has silently gone stale after a long idle. The on-screen arrow buttons masked the problem; keyboard shortcuts did not. With issues not enabled on that repo, a fork was the practical way to fix it for my own setup.

In 2026, with [Cursor](https://cursor.com), there is not much reason to live with a menu-bar app that almost works: turning it into a build that fits my daily use was an afternoon, not a product roadmap. That is also why this fork exists.

This repo starts from that Apple Silicon code, keeps the original MIT app name (so existing shortcuts keep working), and reconnects automatically when the Bluetooth link has gone stale before a sit/stand move. Published for anyone who hit the same shortcut stall and wants a native, scriptable controller without an Intel helper.

## What changed in this fork

The investigation and the fixes below were done with [Cursor](https://cursor.com) agents; I mostly described the symptoms and tested the results.

- The app now notices when the Bluetooth link has gone stale after a long idle and reconnects on its own before moving the desk — so keyboard shortcuts keep working after hours in the menu bar.
- macOS is told not to put the app to sleep in the background, which was part of what killed the connection overnight.
- Launch at login no longer needs the Intel-only helper (the reason to leave the original app in the first place).
- The menu-bar icon shows up reliably, and Preferences shows the desk height live.
- Opt-in debug log for troubleshooting.

## Memory

The goal is for this to stay an extremely light tool. Expect roughly **15–20 MB** in Activity Monitor when idle, with brief spikes while Preferences is open or the desk is moving; it settles back down afterwards. Idle CPU is 0 %.

No memory growth has been observed so far across multi-hour sessions, but there has been no formal leak audit. If you see it creeping up over days, please open an issue.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 13 Ventura or newer

## Install

1. Download `Desk-Controller-v*.zip` from [Releases](../../releases/latest).
2. Unzip and drag `Desk Controller.app` into `/Applications`.
3. The build is **ad-hoc signed**, not notarized. Remove quarantine once:

```sh
xattr -dr com.apple.quarantine "/Applications/Desk Controller.app"
```

4. Launch from `/Applications`. Grant Bluetooth when asked.

The app name stays **Desk Controller** so existing AppleScript / Automator shortcuts keep working (`tell application "Desk Controller"`).

## How I use it

Apple **Magic Keyboard**, macOS **Automator** Quick Actions bound to **F17** and **F18**:

| Key | Service | AppleScript |
|---|---|---|
| F17 | `sit position` | `tell application "Desk Controller" to move to "68cm"` |
| F18 | `stand position` | `tell application "Desk Controller" to move to "105cm"` |

The services live in `~/Library/Services/`. The app stays in the menu bar; the keys are the UI. Heights are whatever you set in Preferences (here: sit 68 cm, stand 105 cm).

## AppleScript

```applescript
tell application "Desk Controller"
    move to "68cm"   -- sit
    move to "105cm"  -- stand
    move "to-sit"
    move "to-stand"
    move "up"
    move "down"
end tell
```

## Debug log

Off by default.

```sh
defaults write com.emirbelkahia.DeskController debugLoggingEnabled -bool true
defaults write com.emirbelkahia.DeskController debugLoggingEnabled -bool false
```

Log file:

```
~/Library/Containers/com.emirbelkahia.DeskController/Data/Library/Application Support/DeskControllerDebug/debug.log
```

The toggle applies immediately (no restart). The file grows without rotation — turn it off when you are done.

## Build from source

Needs the full **Xcode** app (not only Command Line Tools). Releases are built on GitHub Actions, so you do not need Xcode installed to *use* the app.

```sh
xcodebuild -project "Desk Controller.xcodeproj" -scheme "Desk Controller" \
  -configuration Release -derivedDataPath build \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" build
```

Pushing a `v*` tag runs GitHub Actions: ad-hoc `.app`, zip, GitHub Release.

## Credits

- Original app: [David Williames](https://github.com/DWilliames).
- Auto-stand scheduling: Johan Eklund ([@meck](https://github.com/meck)).
- Apple Silicon / Swift concurrency work we started from: [marcobazzani/idasen-desk-controller-mac](https://github.com/marcobazzani/idasen-desk-controller-mac) and its contributors (Martin Ryberg Laude, akucharczyk, and others).
- Stale-connection fix + this packaging: Emir Belkahia.

## License

MIT — see [LICENSE.md](LICENSE.md).
