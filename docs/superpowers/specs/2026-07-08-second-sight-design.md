# Second Sight — Design

**Date:** 2026-07-08
**Status:** Approved 2026-07-08
**Name:** *Second Sight* — a "second" is a unit of time; "second sight" is the power to perceive what others can't. The cure for time blindness. (Bundle/executable name: `SecondSight`.)
**Goal:** A native macOS menu-bar app that shows a subtle, transparent clock floating above all windows. The clock relocates around the screen at intervals so it keeps catching your eye — an anti-time-blindness aid — without ever blocking your work.

## Decisions already made (from Q&A)

- **Movement style:** smooth glide (~1.2 s ease-in-out) to a new random position at each interval. The motion is the attention cue.
- **Mouse:** fully click-through. The clock never intercepts clicks; all control is via the menu bar.
- **Displays:** one clock, shown on the screen where your focus is (details below).
- **Full-screen apps:** yes — the clock appears over full-screen apps and all Spaces. Snooze covers presentations.
- **Clock face:** time only, `HH:MM`, following the system 12/24-hour setting. No seconds, no date.
- **Distribution:** personal use only (ad-hoc signed, no notarization), with a Launch-at-login toggle.
- **Stack:** Approach A — SwiftPM executable, AppKit shell + SwiftUI settings UI. No Xcode required (built with the Swift 6.3 Command Line Tools already installed).

## 1. Architecture

A single SwiftPM executable target, minimum macOS 14, assembled into `SecondSight.app` by a small build script. Runs as an accessory app (`LSUIElement` — menu bar icon only, no Dock icon).

Components, each with one job:

| Component | Responsibility |
|---|---|
| `AppDelegate` | Wires everything at launch; owns lifecycle. |
| `StatusItemController` | Menu bar icon + menu (Snooze submenu, Settings…, Quit). Icon reflects normal vs. snoozed state. |
| `ClockPanelController` | Owns the floating `NSPanel`: borderless, transparent, click-through, joins all Spaces, floats above full-screen apps. Hosts the clock face. |
| `ClockView` (SwiftUI) | Renders the time text; updates aligned to the minute boundary. |
| `MovementEngine` | Interval timer; picks the next position on the focused screen; triggers the glide animation. |
| `PositionSampler` | Pure logic: given a screen rect, clock size, and previous position, returns a valid random position (fully on-screen with margin, minimum distance from the previous spot). Unit-testable. |
| `SnoozeController` | State machine: `active` / `snoozed(until: Date)` / `snoozedIndefinitely`. |
| `SettingsStore` | Observable settings backed by `UserDefaults`. Changes apply live — no Save button. |
| `SettingsWindow` (SwiftUI form) | The config panel. |

**"Screen with focus":** macOS doesn't tell accessory apps which screen has the focused window directly. We read the frontmost app's window bounds via the public `CGWindowList` API (bounds are available without any permission prompt) and map them to a screen; if that fails, fall back to the screen containing the mouse pointer. The app therefore requests **zero permissions**.

## 2. Clock panel behavior

**Window setup:** `NSPanel` with `.borderless` + `.nonactivatingPanel` style, `ignoresMouseEvents = true`, `isOpaque = false`, clear background, no *window* shadow (`hasShadow = false`; the time text itself does get a soft text shadow — see Rendering), `level = .screenSaver` (above full-screen apps), `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`. It never becomes key or main, so it can't steal focus.

**Rendering:** `HH:MM` (or `h:mm AM/PM` per system setting), re-rendered on each minute boundary via a timer aligned to the next minute. Text gets a subtle soft shadow so it stays legible over both light and dark content even at low opacity.

**Movement:**
- Every *interval* (configurable), `MovementEngine` asks `PositionSampler` for a new position on the focused screen and glides the panel there over ~1.2 s with ease-in-out timing (`NSAnimationContext` frame animation).
- Position constraints: fully on-screen with a 24 px inset; at least 20 % of the screen's width away from the previous position (so it never "moves" imperceptibly); avoids the menu bar strip.
- Immediate relocation (no wait for next tick) when: display configuration changes, the focused screen changes since the last tick, font/size settings change, or snooze ends.

## 3. Customization (Settings window)

All settings live in `UserDefaults` and apply instantly:

| Setting | Control | Range / options | Default |
|---|---|---|---|
| Move interval | Preset picker | 30 s, 1, 2, 5, 10, 15, 30, 60 min | 5 min |
| Font | System font-family picker | Any installed family | System (SF Pro Rounded), semibold |
| Size | Slider | 24–160 pt | 64 pt |
| Opacity | Slider | 10–100 % | 35 % |
| Color | Preset swatches + custom color well | Any color | Soft white |
| Rotate colors | Toggle | Picks a new color from a curated palette on each move | Off |
| Launch at login | Toggle | `SMAppService.mainApp` | Off |

Time format deliberately follows the system setting — no override (YAGNI).

## 4. Snooze

Menu bar → **Snooze** submenu: 15 min, 30 min, 1 h, 2 h, and "Until I resume".

- While snoozed: the panel is hidden (ordered out), the menu bar icon switches to a slashed-clock glyph, and the menu shows the remaining time plus **Resume now**.
- When the snooze timer fires (or Resume is clicked): the clock fades back in at a freshly sampled position.
- Snooze state survives app restarts (the `until` date is persisted), so an accidental relaunch mid-presentation doesn't unsnooze you.

## 5. Error handling

Small failure surface, handled simply:

- **Display disconnect / reconnect:** listen for screen-parameter-change notifications; if the clock's screen disappears, immediately resample on a remaining screen.
- **Selected font missing** (e.g., font uninstalled): fall back to the system font; settings UI shows the actual font in use.
- **Corrupt/missing defaults:** every setting has a hard-coded default; unreadable values are ignored.
- **Launch-at-login registration fails:** show the error inline in the settings window; the toggle reverts.

## 6. Testing

- **Unit tests (XCTest, `swift test`):** `PositionSampler` (bounds, inset, min-distance, degenerate small screens), `SnoozeController` state machine (timer expiry, indefinite, persistence round-trip), `SettingsStore` defaults/decode fallbacks.
- **Manual smoke test** (scripted checklist): clock visible and click-through, glides on interval, appears over a full-screen app, snooze hides/restores, settings apply live.
- UI/visual behavior is deliberately verified manually — automating `NSPanel` visuals isn't worth the harness for an app this size.

## 7. Build & distribution

- `swift build -c release` produces the binary; `Scripts/build-app.sh` assembles `dist/SecondSight.app` (binary + `Info.plist` with `LSUIElement=true` + icon), ad-hoc codesigns it, and can copy it to `/Applications`.
- Personal use only: no Developer ID, no notarization.
- Repo gets a git history from the start; this design doc is the first commit.

## Out of scope (YAGNI)

- Seconds / date display, multiple simultaneous clocks, hover-dodge behavior, pomodoro/timer features, App Store or notarized distribution, preferences sync.
