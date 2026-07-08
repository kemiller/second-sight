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
