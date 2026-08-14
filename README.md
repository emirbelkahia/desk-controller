# Desk Controller

A Mac menu-bar app for an [IKEA IDÅSEN (Linak)](https://www.ikea.com/au/en/p/idasen-desk-sit-stand-black-beige-s79280979/) sit/stand desk.

Apple Silicon only. Ad-hoc signed (not notarized).

This is a small personal fork so the desk can be driven **from the Mac**, especially via **dedicated keyboard shortcuts / AppleScript**. It is not a product. Issues and pull requests are welcome; maintenance is **best effort** and the app is not expected to move much.

[**Download the latest release**](../../releases/latest)

## Why this repo exists

The original native app is [DWilliames/idasen-desk-controller-mac](https://github.com/DWilliames/idasen-desk-controller-mac) (MIT, 2021). Last binary release: **1.0.2** (June 2022). On this machine it **just worked** — including after sleep and idle. No stall, no 2 cm pulse. The only reason to leave it was macOS: the nested **Launch at Login helper is Intel-only**, so Tahoe warns that support for Intel-based apps is ending (Rosetta goes away with macOS 28, ~fall 2027). That helper is what made 1.0.2 feel like a dead end.

[marcobazzani/idasen-desk-controller-mac](https://github.com/marcobazzani/idasen-desk-controller-mac) is a native Apple Silicon rebuild (v2.1.5). It was the obvious next step. After about a day and a half:

- Right after launch, sit/stand shortcuts worked as before.
- After the app had been sitting in the menu bar for a while, the shortcut moved the desk **about 2 cm and stopped**.
- Pressing it again did **nothing**.

That is a zombie BLE link: CoreBluetooth still says `.connected`, but height notifications are dead. Linak only moves for about a second per GATT write; the app needs those notifies to keep pulsing. Arrow buttons already had a 0.4 s hold timer, so they hide the bug. **AppleScript / keyboard shortcuts do not.** Marco’s repo has **issues disabled**, so there was nowhere to report it.

In 2026, with [Cursor](https://cursor.com), there is not much reason to live with a menu-bar app that almost works. The original was frictionless here until the Intel warning; Marco broke the shortcuts after idle; turning that into a working, scriptable build is an afternoon, not a product roadmap. That is also why this fork exists.

This repo starts from that Apple Silicon code, keeps the original MIT app name (so existing shortcuts keep working), and **force-reconnects** a zombie `.connected` link before a targeted sit/stand move. Published for anyone who hit the same shortcut stall and wants a native, scriptable controller without an Intel helper.

## What we changed

- If height notifications are older than 10 s, **force-reconnect** (cancel, wait for disconnect, then connect) and resume the pending move. A same-turn `connect()` is ignored by CoreBluetooth.
- Keep-alive activity so App Nap is less likely to freeze GATT.
- Re-subscribe + read height before a targeted move.
- No Intel login helper. Launch at login uses `SMAppService`.
- Menu-bar icon actually draws when auto-stand is off.
- Preferences **Current height** / sit–stand gauge follow the desk live.
- Opt-in file debug log.

## Memory (measured)

`phys_footprint` from macOS `footprint` (same number Activity Monitor calls Memory). Mac: Apple Silicon, macOS 26.5.

| Build | Uptime | Footprint | Peak |
|---|---|---|---|
| Original 1.0.2 (universal, Intel helper) | ~24 h | 27 MB | 27 MB |
| Marco 2.1.5 (arm64) | ~19 min | 23 MB | 25 MB |
| This fork 3.0.0 (arm64), idle | ~56 min | 17 MB | 17 MB |
| This fork 3.0.0 (arm64), prefs + moves | ~5 min | 31 MB | 147 MB |

Idle CPU was 0 % in all cases. RSS is higher than footprint (shared pages); compare **footprint**, not RSS. The 147 MB peak is a spike while Preferences is open and the desk is moving; it is not the idle resident size.

It stays small because there is almost nothing running: a menu-bar accessory (no window, no web view), **arm64 only** (no Intel slice), and **no nested login helper process**. Launch at login uses `SMAppService` inside the same app. The original’s extra Intel helper is both the Tahoe warning and a second resident binary.

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
- Zombie-BLE reconnect + this packaging: Emir Belkahia.

## License

MIT — see [LICENSE.md](LICENSE.md).
