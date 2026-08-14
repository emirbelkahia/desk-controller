# Desk Controller

A Mac menu-bar app for an [IKEA IDÅSEN (Linak)](https://www.ikea.com/au/en/p/idasen-desk-sit-stand-black-beige-s79280979/) sit/stand desk.

Apple Silicon only. Ad-hoc signed (not notarized).

[**Download the latest release**](../../releases/latest)

## Why this repo exists

The original native app is [DWilliames/idasen-desk-controller-mac](https://github.com/DWilliames/idasen-desk-controller-mac) (MIT, 2021). Last binary release: **1.0.2** (June 2022). It still works, but:

- The **Launch at Login helper is Intel-only**, so macOS Tahoe warns that support for Intel-based apps is ending (Rosetta goes away with macOS 28, ~fall 2027).
- After sleep/idle, the desk can **move a couple of centimetres and stall**. That is [issue #3](https://github.com/DWilliames/idasen-desk-controller-mac/issues/3) on the original: CoreBluetooth looks `.connected` while GATT height notifications are dead. The 1.0.1 “reconnect on wake” fix only runs when the peripheral is `.disconnected`, so a zombie link is ignored.

[marcobazzani/idasen-desk-controller-mac](https://github.com/marcobazzani/idasen-desk-controller-mac) rebuilt the app for Apple Silicon (v2.1.5). We used it as a **starting point**, then stopped depending on it:

- Issues are **disabled** on that fork — nowhere to report the stall.
- CoreBluetooth was moved onto the **main queue** (`@MainActor`). A menu-bar app gets App Nap; height notifies die overnight; F17/F18 send **one** Linak pulse (~2 cm) and stop. The next keypress is a no-op (`distSincePrev=0`).
- Arrow buttons already had a 0.4 s hold timer so they do not depend on notifies. **AppleScript / keyboard shortcuts did not.**

This repo keeps the original MIT code + Apple Silicon work, and actually **reconnects a zombie `.connected` link** before a sit/stand move.

## What we changed

- If height notifications are older than 10 s, **force-reconnect** (cancel + connect), then resume the pending move.
- Keep-alive activity so App Nap is less likely to freeze GATT.
- Re-subscribe + read height before a targeted move.
- No Intel login helper. Launch at login uses `SMAppService`.
- Opt-in file debug log.

## Memory (measured)

`phys_footprint` from macOS `footprint` (same number Activity Monitor calls Memory). Mac: Apple Silicon, macOS 26.5.

| Build | Uptime | Footprint | Peak |
|---|---|---|---|
| Original 1.0.2 (universal, Intel helper) | ~24 h | 27 MB | 27 MB |
| Marco 2.1.5 (arm64) | ~19 min | 23 MB | 25 MB |
| This fork 3.0.0 (arm64) | *measured after install* | — | — |

Idle CPU was 0 % in all three cases. RSS is higher than footprint (shared pages); compare **footprint**, not RSS.

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

Needs Xcode (full app, not only Command Line Tools).

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
- Zombie-BLE reconnect + this packaging: Emir Belkahia.

## License

MIT — see [LICENSE.md](LICENSE.md).
