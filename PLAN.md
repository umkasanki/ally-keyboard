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

- [x] **1.1** Configure `AppDelegate` — create window on app launch
  - Runs as `.regular` with a Dock icon (pink keyboard). Focus is preserved by the non-activating `NSPanel` (1.2), not by hiding from the Dock — verified `.regular` no longer steals focus once the panel is created non-activating.
- [x] **1.2** Keyboard window is a **non-activating `NSPanel`** (`KeyboardPanel: NSPanel`):
  - Storyboard window given `customClass=KeyboardPanel` + `nonactivatingPanel` styleMask (set at creation)
  - `canBecomeKey/Main = false`; combined with the non-activating panel → clicking keys never moves focus (holds even under `.regular`)
  - `level = .statusBar`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`
- [x] **1.3** Create `KeyboardViewController` — grid of `NSButton` keys
- [x] **1.4** Make window draggable via `DragHandle` (three dots, bottom strip)
- [x] **1.4a** Fix window size — auto-sized from key layout
- [x] **1.5** Persist window position between launches (`setFrameAutosaveName`)
- [x] **1.6** Test: window floats on top; focus stays in target app (verified on macOS 26.3, typing into TextEdit)
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
- [x] **2.6** Modifier keys & combos:
  - Dedicated Cmd+C/V/Z/A/X keys (bottom row)
  - **Sticky modifiers** Ctrl/Alt/Cmd (one-shot, like Shift): click to arm (highlights), next key sent with accumulated `CGEventFlags` via virtual keycode, then reset. Chords with Shift work (e.g. Cmd+Shift+←). Verified on macOS 26.3.
- [x] **2.7** Test: typing verified into TextEdit on macOS 26.3 (Accessibility granted, non-activating panel)

---

## Phase 3 — Word Prediction Bar
> Goal: row of clickable word suggestions appears above keyboard while typing, click inserts word

- [x] **3.1** Create `TextTracker` — tracks characters sent via `KeySender`, maintains current word buffer
  - Reset buffer on Space / Enter / Punctuation
  - Update on Backspace
  - Lives in `AllyKeyboardCore` SPM package (platform-independent, no AppKit) — built & tested on Linux (WSL)
  - `KeyInput` enum + `KeyInput.from(keyID:shifted:)` mirrors `KeySender` vocabulary
- [x] **3.2** Create `PredictionEngine` — wraps `NSSpellChecker.completions(forPartialWordRange:)`
  - Returns up to 5 suggestions for current buffer
  - Protocol `PredictionEngine` + portable `DictionaryPredictionEngine` done in `AllyKeyboardCore` (tested on Linux)
  - Done on Mac: `SpellCheckerPredictionEngine` adapter over `NSSpellChecker` (locale from the active input source)
- [x] **3.3** `SuggestionBarView` — vertical list in a separate **docked balloon panel** (non-activating `NSPanel`, triangular tail pointing at the keyboard); docks above/below by available screen space, follows the keyboard on move. Flat rows on the keyboard background, hover highlight, typed prefix bright / completion dimmed.
- [x] **3.4** Connected: keystrokes feed `TextTracker` (actual layout character), `SpellCheckerPredictionEngine` → docked panel. `AllyKeyboardCore` linked as a local Swift Package.
- [x] **3.5** Clicking a suggestion: delete current partial word (send N Backspaces), send suggestion + Space
  - Logic done in `AllyKeyboardCore`: `SuggestionApplier.plan(...)` → `ReplacementPlan` (backspaces + text), keeps common prefix to minimise keystrokes. Tested on Linux.
  - Done on Mac: plan applied via `KeySender` on click (Backspaces + `sendText`), `TextTracker` reset after.
- [x] **3.6** Russian (and any enabled language) suggestions — NSSpellChecker locale follows the active input source.
- [x] **3.7** Language switch button (`InputSourceSwitcher`): cycles the system input source (any enabled language), relabels keys to the active layout via `UCKeyTranslate`, types layout-correct characters (keycode-based, not unicode), shows a rounded flag card of the current language (flagpack SVG assets). Spell-checker locale to follow in prediction work.
- [x] **3.8** Verified on macOS 26.3: typing EN/RU shows suggestions; click inserts word + space.

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

- [x] **5.1** `Settings` + `SettingsStore` in `AllyKeyboardCore` (UserDefaults / JSON, lenient decode of old data): keyboard size (percent, 100% = base scale), show-suggestions flag, saved phrases. Tested on Linux/CI (40 tests).
- [x] **5.2** `SettingsWindowController` — tabbed window (`.modalPanel`, above the keyboard):
  - General: launch-at-login + keyboard size (editable percent field, −/+ 5% steps, manual entry)
  - Suggestions: toggle word predictions + saved-phrases editor (one per line)
- [x] **5.3** Settings opened from the menu-bar and Dock menus (Settings…).

---

## Phase 6 — Menu Bar & Launch
> Goal: keyboard can be shown/hidden from menu bar, optionally launches at login

- [x] **6.1** `NSStatusItem` in menu bar — `StatusBarController` with Show/Hide Keyboard + Quit.
- [x] **6.2** Menu: Show/Hide Keyboard, Quit (Settings later).
- [x] **6.3** Launch at login via `SMAppService` (`LoginItem`); auto-launched → keyboard starts hidden.
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

## Code signing & Accessibility (dev setup)
> Ad-hoc signing changes the code hash every build, so the Accessibility grant
> was resetting on each rebuild. Fixed with a stable self-signed identity.

- `AllyKeyboard/setup-signing.sh` — one-time: creates a self-signed "AllyKeyboard Local"
  identity in a dedicated keychain (`allykeyboard.keychain-db`), codesign-accessible over SSH.
- `AllyKeyboard/build-signed.sh` — `xcodebuild` + re-sign the `.app` with that identity.
  Stable designated requirement → TCC keeps the Accessibility grant across rebuilds.

---

## Improvements from ally-clicker (sibling project)
> Patterns to adopt from the more mature ally-clicker codebase.

- [x] **A** Menu-bar `StatusBarController` — Show/Hide + Quit; left click toggles, right/ctrl click opens the menu.
- [x] **B** (revisited) Kept `.regular` with a Dock icon instead of hiding the app — the non-activating panel already preserves focus, so `LSUIElement` isn't needed.
- [x] **C** Window: `.fullScreenAuxiliary` added + `level = .statusBar`.
- [x] **D** Settings model in `AllyKeyboardCore` + `SettingsStore` (UserDefaults) — done in Phase 5.
- [x] **E** Launch-at-login via `SMAppService` (`LoginItem`) — done in 6.3.
- [ ] **F** `KeyEventSink` port in Core so `TextTracker → SuggestionApplier → sink` is testable end-to-end without AppKit

---

## Polish — done

- [x] Delete key: right Cmd → forward delete (keycode 117, labelled "del")
- [x] Hide-keyboard button: right Alt → 3-row keyboard glyph; hides the panel (`orderOut`)
- [x] Minimize button hides the keyboard (no Dock window thumbnail); Dock-icon click / menu-bar re-show it
- [x] Menu-bar icon: left click toggles the keyboard, right/ctrl click opens the menu
- [x] Keys can render custom template image assets, not only SF Symbols
- [x] Flag card on the language key (flagpack SVG, per active input source)
- [x] Saved phrases: the list key ("Hi") pops a menu of user phrases (5 English greetings by default), inserts on tap

---

## Backlog

- [x] Иконка приложения — новый дизайн (розовый градиент + 3-рядный глиф клавиатуры; генератор `tools/make-icon.swift`).

---

## Current state

**Done:** Phases 0–3 and 5 complete. Floating non-activating keyboard, key/chord
simulation, multilingual layout switching, docked word-prediction balloon, saved-phrase
list key, tabbed Settings (size %, launch-at-login, suggestions toggle, phrases), menu bar
+ Dock control, stable code signing, redesigned app/Dock icon. `AllyKeyboardCore` is a local
Swift Package with 40 tests green on Linux CI.

**Next up:** Phase 4 (real head-tracker testing; size presets already covered by the % setting)
and Phase 7 polish (fullscreen/multi-monitor edge cases, global show/hide hotkey, punctuation panel).
