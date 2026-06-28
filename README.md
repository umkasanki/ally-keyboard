# AllyKeyboard

[![Core tests](https://github.com/umkasanki/ally-keyboard/actions/workflows/core-tests.yml/badge.svg)](https://github.com/umkasanki/ally-keyboard/actions/workflows/core-tests.yml)

A floating virtual keyboard for macOS with improved usability, designed for head tracker users.

![AllyKeyboard prototype](docs/preview.jpg)

## What it is

AllyKeyboard is a clickable on-screen keyboard that stays on top of all windows. It lets users who rely on a headmouse or similar pointing device type without a physical keyboard. Inspired by Hot Virtual Keyboard on Windows, built natively for macOS.

## Features

- Floating window that stays above all other apps
- Full QWERTY layout with modifier keys (Shift, Ctrl, Alt, Cmd)
- Number row with symbol variants
- Media and function keys (mute, volume, cut, copy, paste, undo)
- Navigation keys (Home, End, Up, Down, Left, Right)
- Caps Lock, Tab, Escape
- Language switcher
- Dark appearance

## Tech stack

- Swift / AppKit (no SwiftUI)
- CGEvent for cross-process key simulation
- Accessibility API (AXUIElement)
- `NSWindow.level = .floating` for always-on-top behaviour

## AllyKeyboardCore

Platform-independent domain logic lives in the [`AllyKeyboardCore`](AllyKeyboardCore) Swift
package — no AppKit dependency, so it builds and is unit-tested on Linux (CI) as well as macOS:

- `TextTracker` — tracks the word currently being typed
- `PredictionEngine` — protocol for word completion; `DictionaryPredictionEngine` is the
  portable implementation (a `NSSpellChecker` adapter plugs in on macOS)
- `SuggestionApplier` — computes the minimal keystrokes to replace a partial word with a suggestion

```bash
cd AllyKeyboardCore && swift test
```

The macOS app links this package locally and supplies the AppKit UI and key simulation.

## Status

Work in progress — personal use project, not distributed via the App Store.