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

- [x] **1.1** Configure `AppDelegate` — create window on app launch, no Dock icon (`NSApp.setActivationPolicy(.accessory)`)
- [x] **1.2** Create `KeyboardWindowController` — `NSWindow` with:
  - `level = .floating`
  - `collectionBehavior = [.canJoinAllSpaces, .stationary]`
  - `styleMask` without title bar, or minimal
  - Non-activating (focus stays in target app)
- [x] **1.3** Create `KeyboardViewController` — grid of `NSButton` keys
  - QWERTY layout (3 rows: 10 / 9 / 7 keys + Space/Backspace/Enter row)
  - Fixed key size, spacing
- [x] **1.4** Make window draggable by mouse (override `mouseDown` / `mouseDragged`)
- [x] **1.4a** Fix window size: set contentRect 520×180 in storyboard, remove resizable
- [x] **1.5** Persist window position between launches (`setFrameAutosaveName`)
- [x] **1.6** Proportional resize: window is resizable, keys and font scale with window size
  - `viewDidLayout` rebuilds keyboard at current scale; aspect ratio locked via `setContentAspectRatio`
  - Minimum size: 50% of natural (260×90)
- [ ] **1.7** Test: window appears on top of Safari/TextEdit, focus stays in target app; resize works

---

## Phase 2 — Key Press Simulation
> Goal: clicking a key on the keyboard types the character in the active app

- [ ] **2.1** Request Accessibility permission at launch (`AXIsProcessTrusted`)
  - Show alert if not granted, open System Preferences
- [ ] **2.2** Create `KeySender` — wrapper around `CGEvent` for sending keystrokes
  - Map character → `CGKeyCode` (use `CGEventKeyboardSetUnicodeString` for Unicode)
- [ ] **2.3** Handle basic keys: letters a–z, digits 0–9
- [ ] **2.4** Handle Shift key — toggle uppercase mode, visual indicator on button
- [ ] **2.5** Handle special keys: Space, Backspace, Enter, Tab
- [ ] **2.6** Handle modifier combos: Cmd+C, Cmd+V, Cmd+Z (copy/paste/undo row)
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
- [~] **4.2** Keyboard size presets: Small / Medium / Large — replaced by free proportional resize (done in Phase 1.6)
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
- [ ] **6.4** App icon (1024×1024 PNG → xcassets)

---

## Phase 7 — Polish & Testing
> Goal: stable, comfortable daily use

- [ ] **7.1** Handle edge cases: app switches, fullscreen apps, multiple monitors
- [ ] **7.2** Keyboard shortcut to show/hide keyboard (global `NSEvent` monitor)
- [ ] **7.3** Numbers row toggle (show/hide numbers row to save space)
- [ ] **7.4** Punctuation panel (secondary layout with . , ! ? @ etc.)
- [ ] **7.5** Prolonged real-world testing with head tracker

---

## Current state

**Last session:** Phase 1 extended — added proportional resize (keys scale with window, aspect ratio locked).  
**Next step:** Phase 2 — key press simulation (CGEvent, Accessibility permissions).
