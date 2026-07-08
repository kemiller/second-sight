# Second Sight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS menu-bar app showing a transparent, click-through clock that glides to a new screen position at intervals — an anti-time-blindness aid — with a settings window and snooze mode.

**Architecture:** SwiftPM executable (no Xcode — Command Line Tools only). AppKit owns the app lifecycle, menu bar item, and the floating `NSPanel`; SwiftUI renders the clock face (hosted in the panel) and the settings form. Pure-logic components (`PositionSampler`, `RGBAColor`, `ClockPalette`, `SnoozeController`, `SettingsStore`, coordinate conversion) are unit-tested; thin AppKit glue is verified by a manual smoke checklist at the end.

**Tech Stack:** Swift 6.3 (Command Line Tools at `/Library/Developer/CommandLineTools`), SwiftPM, AppKit, SwiftUI, Combine, ServiceManagement, Swift Testing (`import Testing` — NOT XCTest; XCTest is not shipped with Command Line Tools).

**Spec:** `docs/superpowers/specs/2026-07-08-second-sight-design.md`

## Global Constraints

- Minimum macOS: **14.0** (`platforms: [.macOS(.v14)]`).
- Build with `swift build` / test with `Scripts/test.sh` only — **never `xcodebuild`** (not installed) and never bare `swift test` (it silently runs zero tests on this machine; see Task 1).
- **Zero third-party dependencies.** Apple frameworks only.
- **Zero TCC permissions** — no Accessibility, no Screen Recording. Focused-screen detection uses only `CGWindowListCopyWindowInfo` bounds (public, unprompted) with a mouse-position fallback.
- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — XCTest is unavailable on this machine.
- Swift language mode **v5** per target (`.swiftLanguageMode(.v5)`) to avoid strict-concurrency friction; tools version 6.0.
- Names: package/executable/bundle name `SecondSight`, display name `Second Sight`, bundle id `com.kenmiller.secondsight`.
- Defaults (verbatim from spec): move interval **300 s**, presets `[30, 60, 120, 300, 600, 900, 1800, 3600]` s; font **nil = system** (SF rounded semibold); size **64 pt** (range 24–160); opacity **0.35** (range 0.10–1.00); color **soft white `#F2F2EDFF`**; rotate colors **off**; glide **1.2 s ease-in-out**; screen inset **24 px**; min hop **20 % of screen width**; snooze presets **15 m / 30 m / 1 h / 2 h / indefinite**; fade out **0.4 s**, fade in **0.5 s**.
- All settings persist in `UserDefaults.standard` (tests use throwaway suites).
- Every value read from `UserDefaults` is validated; invalid/missing → hard-coded default.
- Commits: small, one per task, message style `feat:`/`test:`/`chore:`.
- This repo is brand new with a single spec commit on `main`; execute directly on `main` (no worktree needed).

---

## File Structure

```
Package.swift
.gitignore
README.md
Resources/Info.plist                                — bundle metadata (LSUIElement)
Scripts/build-app.sh                                — assemble + ad-hoc sign dist/SecondSight.app
Sources/SecondSight/
  main.swift                                        — NSApplication bootstrap
  AppDelegate.swift                                 — wiring only
  Clock/
    ClockView.swift                                 — SwiftUI time text (TimelineView .everyMinute)
    ClockState.swift                                — palette-rotation state (ObservableObject)
    ColorBridges.swift                              — RGBAColor ⇄ SwiftUI Color / NSColor
    ClockPanelController.swift                      — floating NSPanel, glide/fade animations
  Movement/
    PositionSampler.swift                           — pure position sampling (tested)
    FocusedScreenLocator.swift                      — CGWindowList + mouse fallback; pure converter (tested)
    MovementEngine.swift                            — interval timer + relocation triggers
  Settings/
    RGBAColor.swift                                 — pure color value type + hex codec (tested)
    SettingsStore.swift                             — UserDefaults-backed ObservableObject (tested)
    SettingsView.swift                              — SwiftUI form incl. launch-at-login
    SettingsWindowController.swift                  — hosts SettingsView in an NSWindow
  Snooze/
    SnoozeController.swift                          — state machine + persistence (tested)
  StatusItem/
    StatusItemController.swift                      — NSStatusItem + dynamic menu
Tests/SecondSightTests/
  SmokeTests.swift
  SeededRNG.swift                                   — deterministic RNG test helper
  PositionSamplerTests.swift
  RGBAColorTests.swift
  ClockPaletteTests.swift
  SettingsStoreTests.swift
  SnoozeControllerTests.swift
  ScreenCoordinateConverterTests.swift
```

---

### Task 1: Package scaffold + toolchain verification

Verifies the critical assumption that Swift Testing works with Command Line Tools alone. **Finding from execution:** bare `swift test` FAILS (`no such module 'Testing'`) — CLT ships `Testing.framework` at `/Library/Developer/CommandLineTools/Library/Developer/Frameworks`, outside the default search paths. The flags must be passed on the command line (not in `Package.swift`) because SwiftPM's synthesized test runner is compiled with `#if canImport(Testing)` and manifest settings don't reach that synthesized module — manifest-only flags produce a build that silently runs zero tests. `Scripts/test.sh` encapsulates the working invocation (verified on this machine). **If Step 3 fails anyway, STOP and report.**

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Scripts/test.sh` (executable)
- Create: `Sources/SecondSight/main.swift` (stub)
- Test: `Tests/SecondSightTests/SmokeTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: buildable/testable package `SecondSight`; later tasks add files under `Sources/SecondSight/` and `Tests/SecondSightTests/` without touching `Package.swift`.

- [ ] **Step 1: Write the package manifest, gitignore, stub entry point, and smoke test**

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SecondSight",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SecondSight",
            path: "Sources/SecondSight",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "SecondSightTests",
            dependencies: ["SecondSight"],
            path: "Tests/SecondSightTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

`.gitignore`:

```
.build/
dist/
.DS_Store
*.xcodeproj
```

`Sources/SecondSight/main.swift`:

```swift
// Entry point — replaced with the NSApplication bootstrap in the wiring task.
```

`Tests/SecondSightTests/SmokeTests.swift`:

```swift
import Testing
@testable import SecondSight

@Test func toolchainRunsSwiftTesting() {
    #expect(1 + 1 == 2)
}
```

`Scripts/test.sh` (then `chmod +x Scripts/test.sh`):

```bash
#!/bin/bash
# swift test wrapper for machines with Command Line Tools only (no Xcode).
#
# CLT ships Testing.framework outside the compiler's default search paths,
# and SwiftPM's synthesized test runner is compiled with
# `#if canImport(Testing)` — so the search paths must be injected from the
# command line, where they reach every compiled module. Package.swift
# settings cannot do this (they don't apply to the synthesized runner,
# which then silently runs zero tests).
set -euo pipefail
cd "$(dirname "$0")/.."

CLT_FRAMEWORKS=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
CLT_TESTING_LIBS=/Library/Developer/CommandLineTools/Library/Developer/usr/lib

if [[ -d "$CLT_FRAMEWORKS/Testing.framework" ]]; then
    exec swift test \
        -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
        -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$CLT_TESTING_LIBS" \
        "$@"
fi
# Full Xcode installed: no extra flags needed.
exec swift test "$@"
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Run tests**

Run: `Scripts/test.sh`
Expected: `✔ Test toolchainRunsSwiftTesting() passed` and `Test run with 1 test in 0 suites passed`. **If this fails, STOP the plan and report to the user** (user decides whether to install Xcode).

- [ ] **Step 4: Commit**

```bash
git add Package.swift .gitignore Scripts/test.sh Sources Tests
git commit -m "chore: scaffold SwiftPM package with CLT-compatible test wrapper"
```

---

### Task 2: PositionSampler (pure logic, TDD)

**Files:**
- Create: `Sources/SecondSight/Movement/PositionSampler.swift`
- Test: `Tests/SecondSightTests/SeededRNG.swift`, `Tests/SecondSightTests/PositionSamplerTests.swift`

**Interfaces:**
- Consumes: nothing (CoreGraphics types only).
- Produces: `PositionSampler.samplePosition(in:clockSize:previous:inset:minDistanceFraction:using:) -> CGPoint` — returns the **origin** (bottom-left, AppKit coords) for the clock panel. Defaults: `inset: CGFloat = 24`, `minDistanceFraction: CGFloat = 0.2`. `MovementEngine` (Task 9) calls it with a live `SystemRandomNumberGenerator`.

- [ ] **Step 1: Write the failing tests**

`Tests/SecondSightTests/SeededRNG.swift`:

```swift
// Deterministic RNG (splitmix64) so sampling tests are reproducible.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
```

`Tests/SecondSightTests/PositionSamplerTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import SecondSight

private let screen = CGRect(x: 0, y: 0, width: 1512, height: 944)
private let clock = CGSize(width: 220, height: 90)

@Test func staysWithinInsetBounds() {
    var rng = SeededRNG(seed: 42)
    for _ in 0..<200 {
        let p = PositionSampler.samplePosition(in: screen, clockSize: clock, previous: nil, using: &rng)
        #expect(p.x >= screen.minX + 24)
        #expect(p.y >= screen.minY + 24)
        #expect(p.x + clock.width <= screen.maxX - 24)
        #expect(p.y + clock.height <= screen.maxY - 24)
    }
}

@Test func worksOnSecondaryScreenWithNonZeroOrigin() {
    var rng = SeededRNG(seed: 11)
    let external = CGRect(x: 1512, y: -200, width: 2560, height: 1415)
    for _ in 0..<200 {
        let p = PositionSampler.samplePosition(in: external, clockSize: clock, previous: nil, using: &rng)
        #expect(p.x >= external.minX + 24)
        #expect(p.y >= external.minY + 24)
        #expect(p.x + clock.width <= external.maxX - 24)
        #expect(p.y + clock.height <= external.maxY - 24)
    }
}

@Test func hopsAtLeastMinDistanceFromPrevious() {
    var rng = SeededRNG(seed: 7)
    var previous = CGPoint(x: 100, y: 100)
    for _ in 0..<200 {
        let p = PositionSampler.samplePosition(in: screen, clockSize: clock, previous: previous, using: &rng)
        #expect(hypot(p.x - previous.x, p.y - previous.y) >= screen.width * 0.2)
        previous = p
    }
}

@Test func degenerateTinyScreenPinsToInsetOriginWithoutCrashing() {
    var rng = SeededRNG(seed: 3)
    let tiny = CGRect(x: 0, y: 0, width: 200, height: 100) // usable area smaller than the clock
    let p = PositionSampler.samplePosition(in: tiny, clockSize: clock, previous: .zero, using: &rng)
    #expect(p == CGPoint(x: tiny.minX + 24, y: tiny.minY + 24))
}

@Test func relaxesMinDistanceWhenUnsatisfiableButStaysInBounds() {
    var rng = SeededRNG(seed: 9)
    // Usable area barely fits the clock, so many candidates are near the previous point.
    let small = CGRect(x: 0, y: 0, width: 300, height: 160)
    let size = CGSize(width: 200, height: 80)
    for _ in 0..<100 {
        let p = PositionSampler.samplePosition(in: small, clockSize: size, previous: CGPoint(x: 24, y: 24), using: &rng)
        #expect(p.x >= small.minX + 24 && p.x + size.width <= small.maxX - 24)
        #expect(p.y >= small.minY + 24 && p.y + size.height <= small.maxY - 24)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Scripts/test.sh`
Expected: FAIL — compile error, `cannot find 'PositionSampler' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/SecondSight/Movement/PositionSampler.swift`:

```swift
import CoreGraphics

/// Picks where the clock goes next. Pure — screen rect in, origin out.
enum PositionSampler {
    /// Returns a bottom-left origin for a `clockSize` panel placed randomly inside
    /// `visibleFrame`, inset on all sides, and (when possible) at least
    /// `minDistanceFraction` of the screen width away from `previous`.
    /// Falls back to the farthest candidate found when the distance constraint
    /// is unsatisfiable (small screens), and to the inset origin when the clock
    /// doesn't fit at all.
    static func samplePosition(
        in visibleFrame: CGRect,
        clockSize: CGSize,
        previous: CGPoint?,
        inset: CGFloat = 24,
        minDistanceFraction: CGFloat = 0.2,
        using rng: inout some RandomNumberGenerator
    ) -> CGPoint {
        let usable = visibleFrame.insetBy(dx: inset, dy: inset)
        let maxX = usable.maxX - clockSize.width
        let maxY = usable.maxY - clockSize.height
        guard maxX >= usable.minX, maxY >= usable.minY else {
            return CGPoint(x: usable.minX, y: usable.minY)
        }

        let minDistance = visibleFrame.width * minDistanceFraction
        var farthest = CGPoint(x: usable.minX, y: usable.minY)
        var farthestDistance: CGFloat = -1

        for _ in 0..<64 {
            let candidate = CGPoint(
                x: CGFloat.random(in: usable.minX...maxX, using: &rng),
                y: CGFloat.random(in: usable.minY...maxY, using: &rng)
            )
            guard let previous else { return candidate }
            let distance = hypot(candidate.x - previous.x, candidate.y - previous.y)
            if distance >= minDistance { return candidate }
            if distance > farthestDistance {
                farthest = candidate
                farthestDistance = distance
            }
        }
        return farthest
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Scripts/test.sh`
Expected: PASS — all `PositionSampler` tests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/SecondSight/Movement/PositionSampler.swift Tests/SecondSightTests/SeededRNG.swift Tests/SecondSightTests/PositionSamplerTests.swift
git commit -m "feat: position sampler with inset, min-hop, and degenerate-screen handling"
```

---

### Task 3: RGBAColor + ClockPalette (pure color logic, TDD)

**Files:**
- Create: `Sources/SecondSight/Settings/RGBAColor.swift`
- Test: `Tests/SecondSightTests/RGBAColorTests.swift`, `Tests/SecondSightTests/ClockPaletteTests.swift`

**Interfaces:**
- Consumes: nothing (Foundation only).
- Produces:
  - `struct RGBAColor: Equatable` with `red/green/blue/alpha: Double` (0…1), `init(red:green:blue:alpha:)` (clamping), `init?(hex: String)` (accepts `#RRGGBB` / `#RRGGBBAA`, `#` optional), `var hexString: String` (always `#RRGGBBAA`), `static let softWhite` (`#F2F2ED`, alpha 1).
  - `enum ClockPalette` with `static let colors: [RGBAColor]` (8 curated colors, `colors[0]` is soft white) and `static func randomColor(differingFrom:using:) -> RGBAColor`.
  - Used by `SettingsStore` (Task 4), `ClockState`/`ClockView` (Task 7), `SettingsView` (Task 11).

- [ ] **Step 1: Write the failing tests**

`Tests/SecondSightTests/RGBAColorTests.swift`:

```swift
import Testing
@testable import SecondSight

@Test func parsesSixDigitHex() {
    let c = RGBAColor(hex: "#FF8800")
    #expect(c == RGBAColor(red: 1.0, green: 136.0 / 255.0, blue: 0.0, alpha: 1.0))
}

@Test func parsesEightDigitHexWithAlpha() {
    let c = RGBAColor(hex: "#FF880080")
    #expect(c?.alpha != nil)
    #expect(abs((c?.alpha ?? 0) - 128.0 / 255.0) < 0.001)
}

@Test func parsesWithoutHashPrefix() {
    #expect(RGBAColor(hex: "FF8800") != nil)
}

@Test func rejectsInvalidHex() {
    #expect(RGBAColor(hex: "") == nil)
    #expect(RGBAColor(hex: "#FFF") == nil)
    #expect(RGBAColor(hex: "#GGGGGG") == nil)
    #expect(RGBAColor(hex: "not a color") == nil)
}

@Test func hexStringRoundTrips() {
    let original = RGBAColor(hex: "#F2C464")!
    let reparsed = RGBAColor(hex: original.hexString)
    #expect(reparsed == original)
    #expect(original.hexString == "#F2C464FF")
}

@Test func initClampsComponents() {
    let c = RGBAColor(red: 2.0, green: -1.0, blue: 0.5, alpha: 9.0)
    #expect(c == RGBAColor(red: 1.0, green: 0.0, blue: 0.5, alpha: 1.0))
}
```

`Tests/SecondSightTests/ClockPaletteTests.swift`:

```swift
import Testing
@testable import SecondSight

@Test func paletteHasEightColorsStartingWithSoftWhite() {
    #expect(ClockPalette.colors.count == 8)
    #expect(ClockPalette.colors[0] == .softWhite)
}

@Test func randomColorAlwaysComesFromPalette() {
    var rng = SeededRNG(seed: 1)
    for _ in 0..<100 {
        let c = ClockPalette.randomColor(differingFrom: nil, using: &rng)
        #expect(ClockPalette.colors.contains(c))
    }
}

@Test func randomColorNeverRepeatsCurrent() {
    var rng = SeededRNG(seed: 2)
    var current: RGBAColor? = nil
    for _ in 0..<100 {
        let next = ClockPalette.randomColor(differingFrom: current, using: &rng)
        #expect(next != current)
        current = next
    }
}

@Test func randomColorHandlesNonPaletteCurrent() {
    var rng = SeededRNG(seed: 3)
    let custom = RGBAColor(hex: "#123456")!
    let next = ClockPalette.randomColor(differingFrom: custom, using: &rng)
    #expect(ClockPalette.colors.contains(next))
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Scripts/test.sh`
Expected: FAIL — compile error, `cannot find 'RGBAColor' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/SecondSight/Settings/RGBAColor.swift`:

```swift
import Foundation

/// Framework-agnostic sRGB color. Bridged to SwiftUI/AppKit in ColorBridges.swift.
struct RGBAColor: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }

    /// Accepts "#RRGGBB", "#RRGGBBAA", with or without "#".
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              s.allSatisfy({ $0.isHexDigit }),
              let value = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        } else {
            self.init(
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                alpha: Double(value & 0xFF) / 255
            )
        }
    }

    var hexString: String {
        String(
            format: "#%02X%02X%02X%02X",
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded()),
            Int((alpha * 255).rounded())
        )
    }

    static let softWhite = RGBAColor(hex: "#F2F2ED")!
}

/// Curated colors for the rotate-colors mode — muted enough to stay subtle.
enum ClockPalette {
    static let colors: [RGBAColor] = [
        .softWhite,                    // soft white
        RGBAColor(hex: "#7FB8E8")!,    // sky
        RGBAColor(hex: "#7FD8A8")!,    // mint
        RGBAColor(hex: "#F2C464")!,    // amber
        RGBAColor(hex: "#B49FE8")!,    // lavender
        RGBAColor(hex: "#F2937F")!,    // coral
        RGBAColor(hex: "#6FC4C4")!,    // teal
        RGBAColor(hex: "#E88FB0")!,    // rose
    ]

    static func randomColor(
        differingFrom current: RGBAColor?,
        using rng: inout some RandomNumberGenerator
    ) -> RGBAColor {
        let candidates = colors.filter { $0 != current }
        return candidates.randomElement(using: &rng) ?? colors[0]
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Scripts/test.sh`
Expected: PASS — all color tests green.

- [ ] **Step 5: Commit**

```bash
git add Sources/SecondSight/Settings/RGBAColor.swift Tests/SecondSightTests/RGBAColorTests.swift Tests/SecondSightTests/ClockPaletteTests.swift
git commit -m "feat: RGBA color value type with hex codec and rotation palette"
```

---

### Task 4: SettingsStore (TDD)

**Files:**
- Create: `Sources/SecondSight/Settings/SettingsStore.swift`
- Test: `Tests/SecondSightTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: `RGBAColor` (Task 3).
- Produces: `final class SettingsStore: ObservableObject` with
  - `@Published var moveInterval: TimeInterval` (seconds), `@Published var fontName: String?` (nil = system), `@Published var fontSize: Double`, `@Published var opacity: Double`, `@Published var colorHex: String`, `@Published var rotateColors: Bool`
  - `static let intervalPresets: [TimeInterval] = [30, 60, 120, 300, 600, 900, 1800, 3600]`
  - `init(defaults: UserDefaults = .standard)`
  - Every mutation persists immediately (didSet). Consumers subscribe via `$property` Combine publishers.

- [ ] **Step 1: Write the failing tests**

`Tests/SecondSightTests/SettingsStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import SecondSight

private func makeDefaults() -> UserDefaults {
    let name = "SettingsStoreTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

@Test func freshStoreUsesSpecDefaults() {
    let store = SettingsStore(defaults: makeDefaults())
    #expect(store.moveInterval == 300)
    #expect(store.fontName == nil)
    #expect(store.fontSize == 64)
    #expect(store.opacity == 0.35)
    #expect(store.colorHex == RGBAColor.softWhite.hexString)
    #expect(store.rotateColors == false)
}

@Test func mutationsPersistAcrossInstances() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    store.moveInterval = 60
    store.fontName = "Avenir"
    store.fontSize = 96
    store.opacity = 0.5
    store.colorHex = "#7FB8E8FF"
    store.rotateColors = true

    let reloaded = SettingsStore(defaults: defaults)
    #expect(reloaded.moveInterval == 60)
    #expect(reloaded.fontName == "Avenir")
    #expect(reloaded.fontSize == 96)
    #expect(reloaded.opacity == 0.5)
    #expect(reloaded.colorHex == "#7FB8E8FF")
    #expect(reloaded.rotateColors == true)
}

@Test func settingFontNameNilPersistsAsSystem() {
    let defaults = makeDefaults()
    let store = SettingsStore(defaults: defaults)
    store.fontName = "Avenir"
    store.fontName = nil
    #expect(SettingsStore(defaults: defaults).fontName == nil)
}

@Test func invalidStoredValuesFallBackToDefaults() {
    let defaults = makeDefaults()
    defaults.set(-3.0, forKey: "moveInterval")       // not a preset
    defaults.set(9999.0, forKey: "fontSize")         // out of range
    defaults.set(5.0, forKey: "opacity")             // out of range
    defaults.set("garbage", forKey: "colorHex")      // unparseable

    let store = SettingsStore(defaults: defaults)
    #expect(store.moveInterval == 300)
    #expect(store.fontSize == 64)
    #expect(store.opacity == 0.35)
    #expect(store.colorHex == RGBAColor.softWhite.hexString)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Scripts/test.sh`
Expected: FAIL — compile error, `cannot find 'SettingsStore' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/SecondSight/Settings/SettingsStore.swift`:

```swift
import Combine
import Foundation

/// Single source of truth for user preferences. Every mutation persists
/// immediately; consumers react via the @Published Combine publishers.
final class SettingsStore: ObservableObject {
    static let intervalPresets: [TimeInterval] = [30, 60, 120, 300, 600, 900, 1800, 3600]

    private enum Keys {
        static let moveInterval = "moveInterval"
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let opacity = "opacity"
        static let colorHex = "colorHex"
        static let rotateColors = "rotateColors"
    }

    private enum Defaults {
        static let moveInterval: TimeInterval = 300
        static let fontSize: Double = 64
        static let fontSizeRange: ClosedRange<Double> = 24...160
        static let opacity: Double = 0.35
        static let opacityRange: ClosedRange<Double> = 0.10...1.0
    }

    @Published var moveInterval: TimeInterval {
        didSet { defaults.set(moveInterval, forKey: Keys.moveInterval) }
    }

    @Published var fontName: String? {
        didSet {
            if let fontName {
                defaults.set(fontName, forKey: Keys.fontName)
            } else {
                defaults.removeObject(forKey: Keys.fontName)
            }
        }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    @Published var opacity: Double {
        didSet { defaults.set(opacity, forKey: Keys.opacity) }
    }

    @Published var colorHex: String {
        didSet { defaults.set(colorHex, forKey: Keys.colorHex) }
    }

    @Published var rotateColors: Bool {
        didSet { defaults.set(rotateColors, forKey: Keys.rotateColors) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedInterval = defaults.double(forKey: Keys.moveInterval)
        moveInterval = Self.intervalPresets.contains(storedInterval)
            ? storedInterval : Defaults.moveInterval

        fontName = defaults.string(forKey: Keys.fontName)

        let storedSize = defaults.double(forKey: Keys.fontSize)
        fontSize = Defaults.fontSizeRange.contains(storedSize)
            ? storedSize : Defaults.fontSize

        let storedOpacity = defaults.double(forKey: Keys.opacity)
        opacity = Defaults.opacityRange.contains(storedOpacity)
            ? storedOpacity : Defaults.opacity

        let storedHex = defaults.string(forKey: Keys.colorHex)
        colorHex = storedHex.flatMap { RGBAColor(hex: $0) != nil ? $0 : nil }
            ?? RGBAColor.softWhite.hexString

        rotateColors = defaults.bool(forKey: Keys.rotateColors)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Scripts/test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SecondSight/Settings/SettingsStore.swift Tests/SecondSightTests/SettingsStoreTests.swift
git commit -m "feat: UserDefaults-backed settings store with validation"
```

---

### Task 5: SnoozeController (TDD)

**Files:**
- Create: `Sources/SecondSight/Snooze/SnoozeController.swift`
- Test: `Tests/SecondSightTests/SnoozeControllerTests.swift`

**Interfaces:**
- Consumes: Foundation only.
- Produces: `final class SnoozeController` with
  - `enum State: Equatable { case active; case snoozed(until: Date); case snoozedIndefinitely }`
  - `private(set) var state: State`, `var onChange: ((State) -> Void)?`
  - `init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init)` — restores persisted snooze; an expired persisted snooze restores as `.active`.
  - `func snooze(for duration: TimeInterval)`, `func snoozeIndefinitely()`, `func resume()`
  - Timed auto-resume via a `Timer` on the main run loop (fires in the real app; unit tests cover state + persistence, timer firing is covered by the manual smoke checklist in Task 13).
  - `AppDelegate` (Task 12) sets `onChange`; `StatusItemController` (Task 10) reads `state` and calls the mutators.

- [ ] **Step 1: Write the failing tests**

`Tests/SecondSightTests/SnoozeControllerTests.swift`:

```swift
import Foundation
import Testing
@testable import SecondSight

private func makeDefaults() -> UserDefaults {
    let name = "SnoozeTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}

private let epoch = Date(timeIntervalSince1970: 1_000_000)

@Test func startsActive() {
    let c = SnoozeController(defaults: makeDefaults())
    #expect(c.state == .active)
}

@Test func snoozeForDurationSetsUntilDate() {
    let c = SnoozeController(defaults: makeDefaults(), now: { epoch })
    c.snooze(for: 900)
    #expect(c.state == .snoozed(until: epoch.addingTimeInterval(900)))
}

@Test func resumeReturnsToActive() {
    let c = SnoozeController(defaults: makeDefaults(), now: { epoch })
    c.snooze(for: 900)
    c.resume()
    #expect(c.state == .active)
}

@Test func snoozeIndefinitelyHoldsUntilResume() {
    let c = SnoozeController(defaults: makeDefaults())
    c.snoozeIndefinitely()
    #expect(c.state == .snoozedIndefinitely)
    c.resume()
    #expect(c.state == .active)
}

@Test func timedSnoozeSurvivesRestart() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 3600)

    let restarted = SnoozeController(defaults: defaults, now: { epoch.addingTimeInterval(60) })
    #expect(restarted.state == .snoozed(until: epoch.addingTimeInterval(3600)))
}

@Test func expiredSnoozeRestoresAsActive() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 900)

    let restarted = SnoozeController(defaults: defaults, now: { epoch.addingTimeInterval(901) })
    #expect(restarted.state == .active)
}

@Test func indefiniteSnoozeSurvivesRestart() {
    let defaults = makeDefaults()
    SnoozeController(defaults: defaults).snoozeIndefinitely()
    #expect(SnoozeController(defaults: defaults).state == .snoozedIndefinitely)
}

@Test func resumeIsPersisted() {
    let defaults = makeDefaults()
    let c = SnoozeController(defaults: defaults, now: { epoch })
    c.snooze(for: 3600)
    c.resume()
    #expect(SnoozeController(defaults: defaults, now: { epoch }).state == .active)
}

@Test func onChangeFiresForEachTransition() {
    let c = SnoozeController(defaults: makeDefaults(), now: { epoch })
    var seen: [SnoozeController.State] = []
    c.onChange = { seen.append($0) }
    c.snooze(for: 900)
    c.resume()
    #expect(seen == [.snoozed(until: epoch.addingTimeInterval(900)), .active])
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Scripts/test.sh`
Expected: FAIL — compile error, `cannot find 'SnoozeController' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/SecondSight/Snooze/SnoozeController.swift`:

```swift
import Foundation

/// Snooze state machine. Persists across relaunches so an accidental restart
/// mid-presentation doesn't unsnooze the clock.
final class SnoozeController {
    enum State: Equatable {
        case active
        case snoozed(until: Date)
        case snoozedIndefinitely
    }

    private(set) var state: State = .active {
        didSet {
            guard state != oldValue else { return }
            persist()
            onChange?(state)
        }
    }

    var onChange: ((State) -> Void)?

    private enum Keys {
        static let snoozeUntil = "snoozeUntil"
        static let snoozeIndefinite = "snoozeIndefinite"
    }

    private let defaults: UserDefaults
    private let now: () -> Date
    private var resumeTimer: Timer?

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        restore()
    }

    func snooze(for duration: TimeInterval) {
        let until = now().addingTimeInterval(duration)
        state = .snoozed(until: until)
        scheduleResume(at: until)
    }

    func snoozeIndefinitely() {
        resumeTimer?.invalidate()
        state = .snoozedIndefinitely
    }

    func resume() {
        resumeTimer?.invalidate()
        state = .active
    }

    private func scheduleResume(at date: Date) {
        resumeTimer?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.resume()
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        resumeTimer = timer
    }

    private func restore() {
        if defaults.bool(forKey: Keys.snoozeIndefinite) {
            state = .snoozedIndefinitely
        } else if let until = defaults.object(forKey: Keys.snoozeUntil) as? Date, until > now() {
            state = .snoozed(until: until)
            scheduleResume(at: until)
        }
    }

    private func persist() {
        switch state {
        case .active:
            defaults.removeObject(forKey: Keys.snoozeUntil)
            defaults.set(false, forKey: Keys.snoozeIndefinite)
        case .snoozed(let until):
            defaults.set(until, forKey: Keys.snoozeUntil)
            defaults.set(false, forKey: Keys.snoozeIndefinite)
        case .snoozedIndefinitely:
            defaults.removeObject(forKey: Keys.snoozeUntil)
            defaults.set(true, forKey: Keys.snoozeIndefinite)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Scripts/test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SecondSight/Snooze/SnoozeController.swift Tests/SecondSightTests/SnoozeControllerTests.swift
git commit -m "feat: snooze state machine with persistence and timed auto-resume"
```

---

### Task 6: Focused-screen detection (converter TDD + AppKit locator)

**Files:**
- Create: `Sources/SecondSight/Movement/FocusedScreenLocator.swift`
- Test: `Tests/SecondSightTests/ScreenCoordinateConverterTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum ScreenCoordinateConverter` with `static func appKitRect(fromCGBounds:primaryScreenHeight:) -> CGRect` (pure, tested).
  - `final class FocusedScreenLocator` with `func focusedScreen() -> NSScreen?` — frontmost app's window screen via `CGWindowList`, else mouse screen, else `NSScreen.main`. Used by `MovementEngine` (Task 9).

- [ ] **Step 1: Write the failing test**

`Tests/SecondSightTests/ScreenCoordinateConverterTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import SecondSight

@Test func convertsTopLeftCGToBottomLeftAppKit() {
    // Primary screen 1000 pt tall. A CG rect at y=100 with height 200 occupies
    // rows 100–300 from the top, i.e. AppKit origin.y = 1000 - 300 = 700.
    let cg = CGRect(x: 50, y: 100, width: 400, height: 200)
    let appKit = ScreenCoordinateConverter.appKitRect(fromCGBounds: cg, primaryScreenHeight: 1000)
    #expect(appKit == CGRect(x: 50, y: 700, width: 400, height: 200))
}

@Test func roundTripsAtScreenTop() {
    let cg = CGRect(x: 0, y: 0, width: 100, height: 50) // menu-bar-adjacent window
    let appKit = ScreenCoordinateConverter.appKitRect(fromCGBounds: cg, primaryScreenHeight: 900)
    #expect(appKit.origin.y == 850)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `Scripts/test.sh`
Expected: FAIL — compile error, `cannot find 'ScreenCoordinateConverter' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/SecondSight/Movement/FocusedScreenLocator.swift`:

```swift
import AppKit

/// CGWindowList reports window bounds in a top-left-origin global space;
/// AppKit uses bottom-left origin of the primary screen.
enum ScreenCoordinateConverter {
    static func appKitRect(fromCGBounds bounds: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: bounds.origin.x,
            y: primaryScreenHeight - bounds.origin.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
    }
}

/// Finds the screen the user is working on — where the frontmost app's
/// top window lives — without any TCC permission (window *bounds* are public;
/// only names/contents are gated). Falls back to the mouse screen.
final class FocusedScreenLocator {
    func focusedScreen() -> NSScreen? {
        frontmostWindowScreen() ?? mouseScreen() ?? NSScreen.main
    }

    private func frontmostWindowScreen() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let primaryHeight = NSScreen.screens.first?.frame.height else { return nil }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // List is front-to-back; the first layer-0 window owned by the
        // frontmost app is its foreground window.
        for info in infoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pid == app.processIdentifier,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Double] else { continue }

            let cgRect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            let rect = ScreenCoordinateConverter.appKitRect(fromCGBounds: cgRect, primaryScreenHeight: primaryHeight)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
                return screen
            }
        }
        return nil
    }

    private func mouseScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `Scripts/test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/SecondSight/Movement/FocusedScreenLocator.swift Tests/SecondSightTests/ScreenCoordinateConverterTests.swift
git commit -m "feat: focused-screen locator via CGWindowList with mouse fallback"
```

---

### Task 7: ClockState, color bridges, ClockView

SwiftUI view code — verified by compilation here, visually in Task 12/13. The palette logic it leans on was tested in Task 3.

**Files:**
- Create: `Sources/SecondSight/Clock/ClockState.swift`
- Create: `Sources/SecondSight/Clock/ColorBridges.swift`
- Create: `Sources/SecondSight/Clock/ClockView.swift`

**Interfaces:**
- Consumes: `SettingsStore` (Task 4), `RGBAColor`/`ClockPalette` (Task 3).
- Produces:
  - `final class ClockState: ObservableObject` with `@Published private(set) var paletteColor: RGBAColor?`, `func advancePalette()`, `func clearPalette()`.
  - `struct ClockView: View` with `init(settings: SettingsStore, clockState: ClockState)`.
  - `extension RGBAColor`: `var swiftUIColor: Color`, `var nsColor: NSColor`, `init?(color: Color)`.
  - `ClockPanelController` (Task 8) hosts `ClockView` and owns a `ClockState`; `AppDelegate` (Task 12) calls `advancePalette`/`clearPalette` on each move.

- [ ] **Step 1: Write the three files**

`Sources/SecondSight/Clock/ClockState.swift`:

```swift
import Combine
import Foundation

/// Holds the transient rotate-colors override. When nil, the clock uses the
/// user's fixed color from SettingsStore.
final class ClockState: ObservableObject {
    @Published private(set) var paletteColor: RGBAColor?

    private var rng = SystemRandomNumberGenerator()

    func advancePalette() {
        paletteColor = ClockPalette.randomColor(differingFrom: paletteColor, using: &rng)
    }

    func clearPalette() {
        paletteColor = nil
    }
}
```

`Sources/SecondSight/Clock/ColorBridges.swift`:

```swift
import AppKit
import SwiftUI

extension RGBAColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    init?(color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(
            red: srgb.redComponent,
            green: srgb.greenComponent,
            blue: srgb.blueComponent,
            alpha: srgb.alphaComponent
        )
    }
}
```

`Sources/SecondSight/Clock/ClockView.swift`:

```swift
import AppKit
import SwiftUI

struct ClockView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var clockState: ClockState

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(ClockView.timeString(for: context.date))
                .font(ClockView.font(name: settings.fontName, size: settings.fontSize))
                .foregroundStyle(displayColor)
                .shadow(color: .black.opacity(0.55), radius: max(2, settings.fontSize / 16), y: 1)
                .padding(settings.fontSize / 8)
        }
        .opacity(settings.opacity)
        .fixedSize()
    }

    private var displayColor: Color {
        let rgba = clockState.paletteColor
            ?? RGBAColor(hex: settings.colorHex)
            ?? .softWhite
        return rgba.swiftUIColor
    }

    /// HH:MM or h:mm AM/PM — follows the system 12/24-hour setting.
    static func timeString(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func font(name: String?, size: Double) -> Font {
        if let name, NSFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: .semibold, design: .rounded)
    }
}
```

- [ ] **Step 2: Build and run existing tests**

Run: `swift build && Scripts/test.sh`
Expected: build succeeds, all prior tests still PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/SecondSight/Clock/ClockState.swift Sources/SecondSight/Clock/ColorBridges.swift Sources/SecondSight/Clock/ClockView.swift
git commit -m "feat: SwiftUI clock face with palette rotation state and color bridges"
```

---

### Task 8: ClockPanelController (floating panel)

AppKit window glue — compile-verified now, behavior-verified in the smoke checklist (Task 13).

**Files:**
- Create: `Sources/SecondSight/Clock/ClockPanelController.swift`

**Interfaces:**
- Consumes: `SettingsStore` (Task 4), `ClockView`/`ClockState` (Task 7).
- Produces: `final class ClockPanelController` with
  - `init(settings: SettingsStore)`
  - `let clockState: ClockState`
  - `var clockSize: CGSize { get }` — current panel size
  - `var currentOrigin: CGPoint? { get }` — origin when visible, nil when hidden
  - `func moveOrShow(at origin: CGPoint)` — glides if visible (1.2 s ease-in-out), fades in (0.5 s) if hidden
  - `func hide()` — fades out (0.4 s) then orders out
  - Used by `MovementEngine` callbacks and `AppDelegate` (Tasks 9, 12).

- [ ] **Step 1: Write the implementation**

`Sources/SecondSight/Clock/ClockPanelController.swift`:

```swift
import AppKit
import Combine
import QuartzCore
import SwiftUI

/// Owns the floating clock window. The panel is borderless, transparent,
/// click-through, joins every Space, and floats above full-screen apps.
final class ClockPanelController {
    let clockState = ClockState()

    private let panel: NSPanel
    private let hostingView: NSHostingView<ClockView>
    private let settings: SettingsStore
    private var cancellables: Set<AnyCancellable> = []

    init(settings: SettingsStore) {
        self.settings = settings
        hostingView = NSHostingView(rootView: ClockView(settings: settings, clockState: clockState))

        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView

        // Text metrics change with font settings; keep the panel snug.
        settings.$fontSize.map { _ in () }
            .merge(with: settings.$fontName.map { _ in () })
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.resizeToFit() }
            .store(in: &cancellables)
    }

    var clockSize: CGSize { panel.frame.size }

    var currentOrigin: CGPoint? { panel.isVisible ? panel.frame.origin : nil }

    func moveOrShow(at origin: CGPoint) {
        if panel.isVisible {
            glide(to: origin)
        } else {
            fadeIn(at: origin)
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }

    private func fadeIn(at origin: CGPoint) {
        panel.setFrameOrigin(origin)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.5
            panel.animator().alphaValue = 1
        }
    }

    private func glide(to origin: CGPoint) {
        var frame = panel.frame
        frame.origin = origin
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func resizeToFit() {
        var frame = panel.frame
        frame.size = hostingView.fittingSize
        panel.setFrame(frame, display: true)
    }
}
```

- [ ] **Step 2: Build and run existing tests**

Run: `swift build && Scripts/test.sh`
Expected: build succeeds, all prior tests still PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/SecondSight/Clock/ClockPanelController.swift
git commit -m "feat: click-through floating clock panel with glide and fade animations"
```

---

### Task 9: MovementEngine

**Files:**
- Create: `Sources/SecondSight/Movement/MovementEngine.swift`

**Interfaces:**
- Consumes: `SettingsStore` (Task 4), `FocusedScreenLocator` (Task 6), `PositionSampler` (Task 2).
- Produces: `final class MovementEngine` with
  - `init(settings: SettingsStore, screenLocator: FocusedScreenLocator = FocusedScreenLocator())`
  - `var onMove: ((CGPoint, NSScreen) -> Void)?` — fired with each new origin
  - `var clockSize: () -> CGSize` and `var currentOrigin: () -> CGPoint?` — injected by `AppDelegate` (Task 12) to read panel geometry
  - `private(set) var isRunning: Bool`, `func start()`, `func stop()`, `func relocateNow()`
  - Automatically relocates on: interval tick, `moveInterval` change (timer restart), screen-parameter changes, and frontmost-app changes that move focus to a different screen.

- [ ] **Step 1: Write the implementation**

`Sources/SecondSight/Movement/MovementEngine.swift`:

```swift
import AppKit
import Combine

/// Decides *when* the clock moves and *where* to. Owns the interval timer and
/// listens for display/focus changes that warrant an immediate hop.
final class MovementEngine {
    var onMove: ((CGPoint, NSScreen) -> Void)?
    var clockSize: () -> CGSize = { .zero }
    var currentOrigin: () -> CGPoint? = { nil }

    private(set) var isRunning = false

    private let settings: SettingsStore
    private let screenLocator: FocusedScreenLocator
    private var timer: Timer?
    private var rng = SystemRandomNumberGenerator()
    private var cancellables: Set<AnyCancellable> = []

    init(settings: SettingsStore, screenLocator: FocusedScreenLocator = FocusedScreenLocator()) {
        self.settings = settings
        self.screenLocator = screenLocator

        settings.$moveInterval
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.scheduleTimer()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.relocateNow()
            }
            .store(in: &cancellables)

        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in self?.relocateIfFocusMovedScreens() }
            .store(in: &cancellables)
    }

    func start() {
        isRunning = true
        relocateNow()
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func relocateNow() {
        guard let screen = screenLocator.focusedScreen() else { return }
        let origin = PositionSampler.samplePosition(
            in: screen.visibleFrame,
            clockSize: clockSize(),
            previous: currentOrigin(),
            using: &rng
        )
        onMove?(origin, screen)
    }

    private func relocateIfFocusMovedScreens() {
        guard isRunning,
              let origin = currentOrigin(),
              let focused = screenLocator.focusedScreen() else { return }
        let clockScreen = NSScreen.screens.first { $0.frame.contains(origin) }
        if clockScreen != focused {
            relocateNow()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer.scheduledTimer(withTimeInterval: settings.moveInterval, repeats: true) { [weak self] _ in
            self?.relocateNow()
        }
        newTimer.tolerance = settings.moveInterval * 0.1
        timer = newTimer
    }
}
```

- [ ] **Step 2: Build and run existing tests**

Run: `swift build && Scripts/test.sh`
Expected: build succeeds, all prior tests still PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/SecondSight/Movement/MovementEngine.swift
git commit -m "feat: movement engine with interval timer and focus/display triggers"
```

---

### Task 10: StatusItemController (menu bar)

**Files:**
- Create: `Sources/SecondSight/StatusItem/StatusItemController.swift`

**Interfaces:**
- Consumes: `SnoozeController` (Task 5).
- Produces: `final class StatusItemController: NSObject, NSMenuDelegate` with
  - `init(snooze: SnoozeController, openSettings: @escaping () -> Void)`
  - `func refresh()` — updates the icon (`clock` vs `clock.badge.xmark`); `AppDelegate` calls it on snooze-state changes.
  - Menu (rebuilt on open via `menuNeedsUpdate`): when active — `Snooze ▸ (For 15 Minutes / For 30 Minutes / For 1 Hour / For 2 Hours / Until I Resume)`; when snoozed — disabled status line (`Snoozed until 3:45 PM` / `Snoozed`) + `Resume Now`. Always: `Settings… (⌘,)`, `Quit Second Sight (⌘Q)`.

- [ ] **Step 1: Write the implementation**

`Sources/SecondSight/StatusItem/StatusItemController.swift`:

```swift
import AppKit

/// The app's only always-visible UI: a menu bar clock icon whose menu adapts
/// to the current snooze state.
final class StatusItemController: NSObject, NSMenuDelegate {
    private static let snoozeOptions: [(title: String, duration: TimeInterval)] = [
        ("For 15 Minutes", 15 * 60),
        ("For 30 Minutes", 30 * 60),
        ("For 1 Hour", 60 * 60),
        ("For 2 Hours", 2 * 60 * 60),
    ]

    private let statusItem: NSStatusItem
    private let snooze: SnoozeController
    private let openSettings: () -> Void

    init(snooze: SnoozeController, openSettings: @escaping () -> Void) {
        self.snooze = snooze
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refresh()
    }

    func refresh() {
        let snoozed = snooze.state != .active
        let symbol = snoozed ? "clock.badge.xmark" : "clock"
        statusItem.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: snoozed ? "Second Sight (snoozed)" : "Second Sight"
        )
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        switch snooze.state {
        case .snoozed(let until):
            let label = "Snoozed until \(until.formatted(date: .omitted, time: .shortened))"
            menu.addItem(disabledItem(label))
            menu.addItem(actionItem("Resume Now", action: #selector(resumeNow)))
            menu.addItem(.separator())
        case .snoozedIndefinitely:
            menu.addItem(disabledItem("Snoozed"))
            menu.addItem(actionItem("Resume Now", action: #selector(resumeNow)))
            menu.addItem(.separator())
        case .active:
            let snoozeMenu = NSMenu()
            snoozeMenu.autoenablesItems = false
            for option in Self.snoozeOptions {
                let item = actionItem(option.title, action: #selector(snoozeFor(_:)))
                item.representedObject = option.duration
                snoozeMenu.addItem(item)
            }
            snoozeMenu.addItem(actionItem("Until I Resume", action: #selector(snoozeUntilResumed)))

            let snoozeRoot = NSMenuItem(title: "Snooze", action: nil, keyEquivalent: "")
            menu.addItem(snoozeRoot)
            menu.setSubmenu(snoozeMenu, for: snoozeRoot)
            menu.addItem(.separator())
        }

        menu.addItem(actionItem("Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Second Sight", action: #selector(quit), keyEquivalent: "q"))
    }

    // MARK: - Actions

    @objc private func snoozeFor(_ sender: NSMenuItem) {
        guard let duration = sender.representedObject as? TimeInterval else { return }
        snooze.snooze(for: duration)
    }

    @objc private func snoozeUntilResumed() {
        snooze.snoozeIndefinitely()
    }

    @objc private func resumeNow() {
        snooze.resume()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Item helpers

    private func actionItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
```

- [ ] **Step 2: Build and run existing tests**

Run: `swift build && Scripts/test.sh`
Expected: build succeeds, all prior tests still PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/SecondSight/StatusItem/StatusItemController.swift
git commit -m "feat: menu bar status item with snooze-aware menu"
```

---

### Task 11: Settings window (SwiftUI form + launch at login)

**Files:**
- Create: `Sources/SecondSight/Settings/SettingsView.swift`
- Create: `Sources/SecondSight/Settings/SettingsWindowController.swift`

**Interfaces:**
- Consumes: `SettingsStore` (Task 4), `RGBAColor`/`ClockPalette` (Task 3), bridges (Task 7).
- Produces:
  - `struct SettingsView: View` — `init(settings: SettingsStore)`.
  - `final class SettingsWindowController` — `init(settings: SettingsStore)`, `func show()` (creates window lazily, centers, activates app, brings to front). Used by `AppDelegate`/`StatusItemController` (Task 12/10).

- [ ] **Step 1: Write the implementation**

`Sources/SecondSight/Settings/SettingsView.swift`:

```swift
import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var launchAtLogin = false
    @State private var loginItemError: String?

    // SMAppService needs a real .app bundle; `swift run` executes a bare binary.
    private var isBundledApp: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    var body: some View {
        Form {
            Section("Movement") {
                Picker("Move every", selection: $settings.moveInterval) {
                    ForEach(SettingsStore.intervalPresets, id: \.self) { interval in
                        Text(Self.intervalLabel(interval)).tag(interval)
                    }
                }
            }

            Section("Appearance") {
                Picker("Font", selection: $settings.fontName) {
                    Text("System").tag(String?.none)
                    ForEach(NSFontManager.shared.availableFontFamilies, id: \.self) { family in
                        Text(family).tag(String?.some(family))
                    }
                }

                LabeledContent("Size") {
                    Slider(value: $settings.fontSize, in: 24...160)
                    Text("\(Int(settings.fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }

                LabeledContent("Opacity") {
                    Slider(value: $settings.opacity, in: 0.1...1.0)
                    Text("\(Int(settings.opacity * 100)) %")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }

                LabeledContent("Color") {
                    HStack(spacing: 6) {
                        ForEach(Array(ClockPalette.colors.enumerated()), id: \.offset) { _, swatch in
                            Button {
                                settings.colorHex = swatch.hexString
                            } label: {
                                Circle()
                                    .fill(swatch.swiftUIColor)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                            }
                            .buttonStyle(.plain)
                        }
                        ColorPicker("", selection: colorBinding)
                            .labelsHidden()
                    }
                }

                Toggle("Rotate colors on each move", isOn: $settings.rotateColors)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .disabled(!isBundledApp)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if !isBundledApp {
                    Text("Available when running the installed app (Scripts/build-app.sh --install).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if isBundledApp {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { (RGBAColor(hex: settings.colorHex) ?? .softWhite).swiftUIColor },
            set: { newValue in
                if let rgba = RGBAColor(color: newValue) {
                    settings.colorHex = rgba.hexString
                }
            }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        guard (service.status == .enabled) != enabled else { return }
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = service.status == .enabled
        }
    }

    static func intervalLabel(_ interval: TimeInterval) -> String {
        if interval < 60 { return "\(Int(interval)) seconds" }
        if interval == 60 { return "1 minute" }
        return "\(Int(interval / 60)) minutes"
    }
}
```

`Sources/SecondSight/Settings/SettingsWindowController.swift`:

```swift
import AppKit
import SwiftUI

final class SettingsWindowController {
    private let settings: SettingsStore
    private var window: NSWindow?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(settings: settings))
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "Second Sight Settings"
            newWindow.styleMask = [.titled, .closable]
            newWindow.isReleasedWhenClosed = false
            window = newWindow
        }
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 2: Build and run existing tests**

Run: `swift build && Scripts/test.sh`
Expected: build succeeds, all prior tests still PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/SecondSight/Settings/SettingsView.swift Sources/SecondSight/Settings/SettingsWindowController.swift
git commit -m "feat: settings window with live-applying preferences and launch-at-login"
```

---

### Task 12: AppDelegate wiring + entry point + first live run

**Files:**
- Create: `Sources/SecondSight/AppDelegate.swift`
- Modify: `Sources/SecondSight/main.swift` (replace stub)

**Interfaces:**
- Consumes: everything from Tasks 4–11.
- Produces: a runnable app. `AppDelegate: NSObject, NSApplicationDelegate` builds and connects: `SettingsStore` → `SnoozeController` → `ClockPanelController` → `MovementEngine` → `StatusItemController` → `SettingsWindowController`.

- [ ] **Step 1: Write the implementation**

`Sources/SecondSight/AppDelegate.swift`:

```swift
import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: SettingsStore!
    private var snooze: SnoozeController!
    private var panelController: ClockPanelController!
    private var movementEngine: MovementEngine!
    private var statusItemController: StatusItemController!
    private var settingsWindowController: SettingsWindowController!
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = SettingsStore()
        snooze = SnoozeController()
        panelController = ClockPanelController(settings: settings)
        movementEngine = MovementEngine(settings: settings)
        settingsWindowController = SettingsWindowController(settings: settings)

        movementEngine.clockSize = { [weak self] in self?.panelController.clockSize ?? .zero }
        movementEngine.currentOrigin = { [weak self] in self?.panelController.currentOrigin }
        movementEngine.onMove = { [weak self] origin, _ in
            guard let self else { return }
            if self.settings.rotateColors {
                self.panelController.clockState.advancePalette()
            } else {
                self.panelController.clockState.clearPalette()
            }
            self.panelController.moveOrShow(at: origin)
        }

        statusItemController = StatusItemController(
            snooze: snooze,
            openSettings: { [weak self] in self?.settingsWindowController.show() }
        )

        snooze.onChange = { [weak self] state in self?.apply(snoozeState: state) }
        apply(snoozeState: snooze.state)

        // After font metrics change, hop once so the resized clock can't hang
        // off-screen. dropFirst(2) skips the two initial @Published emissions.
        settings.$fontSize.map { _ in () }
            .merge(with: settings.$fontName.map { _ in () })
            .dropFirst(2)
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self, self.movementEngine.isRunning else { return }
                self.movementEngine.relocateNow()
            }
            .store(in: &cancellables)
    }

    private func apply(snoozeState: SnoozeController.State) {
        switch snoozeState {
        case .active:
            movementEngine.start()
        case .snoozed, .snoozedIndefinitely:
            movementEngine.stop()
            panelController.hide()
        }
        statusItemController.refresh()
    }
}
```

`Sources/SecondSight/main.swift` (replace entire file):

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 2: Build and run all tests**

Run: `swift build && Scripts/test.sh`
Expected: build succeeds, all tests PASS.

- [ ] **Step 3: Launch the app live**

Run: `swift run` (leave it running; it's a UI app — stop it with Ctrl-C or via its Quit menu item)
Expected: a clock icon appears in the menu bar; a translucent `HH:MM` clock appears on screen; no Dock icon. If the sandbox blocks UI, run it in the background and confirm no crash within ~10 s of launch.

- [ ] **Step 4: Commit**

```bash
git add Sources/SecondSight/AppDelegate.swift Sources/SecondSight/main.swift
git commit -m "feat: wire components in AppDelegate and boot as accessory app"
```

---

### Task 13: App bundle, build script, README, smoke checklist

**Files:**
- Create: `Resources/Info.plist`
- Create: `Scripts/build-app.sh`
- Create: `README.md`

**Interfaces:**
- Consumes: the release binary from `swift build -c release`.
- Produces: `dist/SecondSight.app` (ad-hoc signed); `--install` copies it to `/Applications`.

- [ ] **Step 1: Write the bundle metadata and build script**

`Resources/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Second Sight</string>
    <key>CFBundleExecutable</key>
    <string>SecondSight</string>
    <key>CFBundleIdentifier</key>
    <string>com.kenmiller.secondsight</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>SecondSight</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

Note: no custom `.icns` — the app never appears in the Dock (`LSUIElement`), so Finder's generic icon is acceptable for personal use. This is a deliberate, documented deviation from the spec's parenthetical "+ icon".

`Scripts/build-app.sh`:

```bash
#!/bin/bash
# Builds dist/SecondSight.app from the SwiftPM release binary.
# Usage: Scripts/build-app.sh [--install]
#   --install  also copy the app to /Applications (enables Launch at Login)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/SecondSight.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/SecondSight "$APP/Contents/MacOS/SecondSight"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/SecondSight.app
    cp -R "$APP" /Applications/
    echo "Installed /Applications/SecondSight.app"
fi
```

Run: `chmod +x Scripts/build-app.sh`

- [ ] **Step 2: Build the bundle**

Run: `Scripts/build-app.sh`
Expected: `Built dist/SecondSight.app`; `codesign -dv dist/SecondSight.app` reports `Signature=adhoc`.

- [ ] **Step 3: Write the README**

`README.md`:

```markdown
# Second Sight

A tiny native macOS menu-bar app that fights time blindness: a subtle,
transparent clock floats above every window — including full-screen apps —
and glides to a new spot on your focused screen at an interval you choose.
The motion is the point: it catches your eye just enough to keep you
anchored in time.

A "second" is a unit of time; "second sight" is the power to perceive what
others can't.

## Build & install

Requires macOS 14+ and the Swift toolchain from Xcode Command Line Tools
(no full Xcode needed).

    Scripts/build-app.sh --install
    open /Applications/SecondSight.app

For development: `swift run` · tests: `Scripts/test.sh`

## Use

Everything lives behind the menu bar clock icon:

- **Snooze** — hide the clock for 15 m / 30 m / 1 h / 2 h or until you
  resume (e.g., while presenting). Snooze survives relaunches.
- **Settings…** — move interval, font, size, opacity, color (with an
  optional rotate-colors-on-each-move mode), launch at login. Everything
  applies live.

The clock is fully click-through — it can never steal a click — and the app
requests zero macOS permissions.

## Design docs

- Spec: `docs/superpowers/specs/2026-07-08-second-sight-design.md`
- Plan: `docs/superpowers/plans/2026-07-08-second-sight.md`
```

- [ ] **Step 4: Run the manual smoke checklist**

Launch: `open dist/SecondSight.app`, then verify with the user (items needing human eyes):

1. Menu bar shows a clock icon; **no Dock icon**.
2. Translucent `HH:MM` clock is visible on screen.
3. Clicking directly on the clock hits the window **beneath** it (click-through).
4. Settings → Move every **30 seconds** → clock glides to a new spot within 30 s; movement is smooth (~1.2 s).
5. Full-screen an app (e.g., YouTube video) → clock still appears above it.
6. Snooze → For 15 Minutes → clock fades out; icon becomes slashed clock; menu shows "Snoozed until …" + Resume Now. Resume Now → clock fades back in at a new spot.
7. While snoozed, Quit and relaunch → still snoozed.
8. Settings: size/opacity/color/font changes apply live; Rotate colors → color changes on each move.
9. (After `--install`) Launch at login toggle works; app appears in System Settings → General → Login Items.

Record any failures; fix before final commit.

- [ ] **Step 5: Commit**

```bash
git add Resources/Info.plist Scripts/build-app.sh README.md
git commit -m "chore: app bundle assembly, ad-hoc signing, README"
```

---

## Plan Self-Review (completed)

- **Spec coverage:** glide movement (T2/T8/T9), click-through + all-Spaces + full-screen panel (T8), minute-aligned HH:MM (T7), focused-screen with zero permissions (T6/T9), settings incl. rotate colors + launch at login (T4/T11), snooze with persistence (T5/T10), display-change + font-change immediate relocation (T9/T12), error handling (font fallback T7, defaults validation T4, screen disconnect T9, SMAppService failure T11), unit tests for the spec's three named suites plus color logic (T2–T6), manual smoke checklist (T13), build script + ad-hoc signing (T13). One documented deviation: no custom app icon (T13 note).
- **Placeholder scan:** none — every code step contains complete code.
- **Type consistency:** verified — `SnoozeController.State` cases, `SettingsStore` property names/types, `ClockPanelController.clockSize/currentOrigin/moveOrShow/hide`, `MovementEngine` closures, `RGBAColor` API all match across tasks.
