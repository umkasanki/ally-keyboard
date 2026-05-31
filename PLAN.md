# Ally Keyboard — Plan

macOS virtual keyboard for head tracker / headmouse users.
Floating window + clickable word suggestions, inspired by Hot Virtual Keyboard (Windows).

**Stack:** Swift + AppKit, CGEvent, AXUIElement  
**Dev workflow:** Edit in WSL (PhpStorm + Claude Code) → git push → MacInCloud (Xcode, weekends)

---

## Status legend
- `[ ]` — not started
- `[~]` — in progress
- `[x]` — done

---

## Phase 0 — Environment & Repository Setup
> Goal: working git pipeline WSL ↔ GitHub ↔ MacInCloud, empty Xcode project compiles and runs

- [x] **0.1** Create Xcode project on MacInCloud
  - App type: macOS App, AppKit (not SwiftUI), Swift
  - Bundle ID: `com.umkasanki.AllyKeyboard`
  - Product name: `AllyKeyboard`
- [x] **0.2** Add `.gitignore` for Xcode (xcuserdata, DerivedData, .DS_Store)
- [x] **0.3** First commit and push from MacInCloud to GitHub
- [x] **0.4** `git pull` in WSL — verify files appear correctly
- [ ] **0.5** Open project in PhpStorm on WSL — verify Swift files are readable

---

## Phase 1 — Floating Keyboard Window
> Goal: window with QWERTY buttons stays on top of all apps, can be dragged

- [x] **1.1** Configure `AppDelegate` — create window on app launch, icon in Dock (`.regular` policy)
- [x] **1.2** Create `KeyboardWindowController` — `NSWindow` with:
  - `level = .floating`
  - `collectionBehavior = [.canJoinAllSpaces, .stationary]`
  - Non-activating (focus stays in target app)
- [x] **1.3** Create `KeyboardViewController` — grid of `NSButton` keys
- [x] **1.4** Make window draggable via `DragHandle` (three dots, bottom strip)
- [x] **1.4a** Fix window size — auto-sized from key layout
- [x] **1.5** Persist window position between launches (`setFrameAutosaveName`)
- [ ] **1.6** Test: window appears on top of Safari/TextEdit, focus stays in target app
- [x] **1.7** Custom status bar:
  - `AppConfig.swift` — global settings (colors, layout, feature flags)
  - `useCustomTitleBar` flag — switches between native and custom title bar
  - `CustomStatusBar` view — app name left, yellow rounded-rect minimize button right
  - Native title bar hidden via `fullSizeContentView` + transparent titlebar
- [x] **1.8** App icon — keyboard SF Symbol on dark rounded background → xcassets
- [x] **1.9** Full keyboard layout redesign:
  - 6 rows: function bar, number row, QWERTY, ASDF, ZXCV, bottom
  - Variable key widths (`widthMultiplier`), secondary labels (top-right corner), `fontScale` per key
  - Function row: esc, hi (greetings placeholder), @!?,., mute/vol, copy/paste/cut/undo, 🇺🇸 (lang switch)
  - Nav keys: Home, End, PageUp ("up"), PageDown ("down"), arrows
  - Both Shift buttons via `shiftButtons` array; shifted punctuation via `shiftedChar`
  - Media keys via `sendMediaKey` (NSEvent systemDefined)

---

## Phase 2 — Key Press Simulation
> Goal: clicking a key on the keyboard types the character in the active app

- [x] **2.1** Request Accessibility permission at launch (`AXIsProcessTrusted`)
  - `KeySender.requestAccessibilityIfNeeded()` called from `applicationDidFinishLaunching`
- [x] **2.2** Create `KeySender.swift` — wrapper around `CGEvent`
  - Letters/symbols via `CGEventKeyboardSetUnicodeString` (no keycode table needed)
  - Special keys via `CGKeyCode`: Space=49, Backspace=51, Return=36
- [x] **2.3** Handle basic keys: letters a–z
- [x] **2.4** Handle Shift key — one-shot toggle (⇧/⇪), resets after first keystroke
- [x] **2.5** Handle special keys: Space, Backspace, Return
- [x] **2.6** Handle modifier combos: Cmd+C, Cmd+V, Cmd+Z, Cmd+A, Cmd+X (bottom row on keyboard)
- [ ] **2.7** Test: type into TextEdit, Safari URL bar, Terminal

---

## Phase 3 — Word Prediction Bar
> Goal: row of clickable word suggestions appears above keyboard while typing, click inserts word

- [ ] **3.1** Create `TextTracker` — tracks characters sent via `KeySender`, maintains current word buffer
  - Reset buffer on Space / Enter / Punctuation
  - Update on Backspace
- [ ] **3.2** Create `PredictionEngine` — wraps `NSSpellChecker.completions(forPartialWordRange:)`
  - Returns up to 5 suggestions for current buffer
- [ ] **3.3** Create `SuggestionBarView` — horizontal row of `NSButton` above keyboard
  - Each button shows one suggestion
  - Horizontally scrollable if suggestions overflow
- [ ] **3.4** Connect: `TextTracker` → `PredictionEngine` → `SuggestionBarView`
- [ ] **3.5** Clicking a suggestion: delete current partial word (send N Backspaces), send suggestion + Space
- [ ] **3.6** Support Russian language suggestions (NSSpellChecker locale: `ru_RU`)
- [ ] **3.7** Language toggle button (EN / RU) on keyboard, switches layout + spell checker locale
- [ ] **3.8** Test: type "hel" → suggestion "hello" appears → click → "hello " inserted

---

## Phase 4 — Head Tracker UX
> Goal: keyboard is comfortable to use with head tracker, correct key sizes and visual feedback

- [ ] **4.1** Visual hover highlight — key changes color on mouseEnter
- [ ] **4.2** Keyboard size presets: Small / Medium / Large (affects key size + font)
- [ ] **4.3** Keyboard opacity setting (0.7–1.0, for seeing content behind)
- [ ] **4.4** Test with actual head tracker device

---

## Phase 5 — Settings & Persistence
> Goal: user can configure keyboard without editing files

- [ ] **5.1** `SettingsManager` — `UserDefaults` wrapper for all settings:
  - Window position, size preset, opacity, language
- [ ] **5.2** Settings panel (simple `NSWindow` or popover):
  - Size preset picker
  - Opacity slider
  - Language toggle
- [ ] **5.3** Settings accessible via menu bar icon right-click

---

## Phase 6 — Menu Bar & Launch
> Goal: keyboard can be shown/hidden from menu bar, optionally launches at login

- [ ] **6.1** `NSStatusItem` in menu bar — icon, click toggles keyboard visibility
- [ ] **6.2** Right-click menu: Show/Hide Keyboard, Settings, Quit
- [ ] **6.3** Launch at Login toggle in Settings (using `SMAppService` on macOS 13+ or `LaunchAgent` plist)
- [x] **6.4** App icon (1024×1024 PNG → xcassets) — done in 1.8

---

## Phase 7 — Polish & Testing
> Goal: stable, comfortable daily use

- [ ] **7.1** Handle edge cases: app switches, fullscreen apps, multiple monitors
- [ ] **7.2** Keyboard shortcut to show/hide keyboard (global `NSEvent` monitor)
- [ ] **7.3** Numbers row toggle (show/hide numbers row to save space)
- [ ] **7.4** Punctuation panel (secondary layout with . , ! ? @ etc.)
- [ ] **7.5** Prolonged real-world testing with head tracker

---

## Backlog

- [ ] Доработать иконку приложения (Dock / Launchpad) — нужен нормальный дизайн

---

## Current state

**Last session:** Phase 1.9 complete — new 6-row layout, variable key widths, secondary labels, nav/media keys.  
**Next step:** Test on MacInCloud (1.6, 2.7). Then Phase 3 — Word Prediction Bar.
