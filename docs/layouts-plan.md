# Editable layouts — implementation plan

Branch: `feature/editable-layouts`. Status: plan, not started.

## Goal

The keyboard is going public. Other people will want other layouts — more
keys, fewer keys, keys in other places — and should not have to ask the author
for each change. So the layout becomes something anyone can edit inside the
app:

- change what a key does, its label or icon, and its width;
- move keys within a row and between rows, add and remove keys and rows;
- keep several layouts, switch between them, create new ones (from scratch or
  as a copy), rename and delete them;
- edit every layout, the default one included;
- export and import a layout as a file, to share it.

The author's own needs are covered by today's keys; the editor is for everyone
else, so it must be able to build any layout from scratch, not only tweak the
default.

The user drives everything with a head mouse, so every edit must be possible
with single clicks: no drag and drop is required anywhere (it may be offered as
an extra later).

## Not in this work

- Automatic layout switching per application (a natural next step, see the end).
- Key repeat on hold, gestures, chords on one key.
- Changing the keyboard's look (themes stay as they are).

## How it works today

- Keys are `ViewController.Key` values: `id`, `title`, `secondary`, `image`,
  width multiplier, font scale, `fixed`, `colored`. Rows are static arrays
  (`functionRow`, `numberRow`, `letterRows`) — 6 rows, about 80 keys.
- The `id` is both the identity and the action. `keyPressed` special-cases ids
  (Shift, CapsLock, Ctrl/Alt/Cmd, LangSwitch, HideKeyboard, Screenshot, Hi,
  AppSwitcher, Translate, ResizeWidth/Height, Blank); `KeySender` maps ids to
  key codes, shortcuts (`Cmd+C`…) and media keys; `fixed` keys type a literal.
- Several features read ids directly and must keep working: Shift and Cmd keys
  sharing an id light up together; character keys are relabelled for the input
  language (`characterButtons`); the smart space, the word tracker and
  `TextTracker.shortcutMayDeleteWord` look at ids; `nonCharacterKeys`;
  `keysKeepingAutoSpace`.
- The window size is computed from the rows (`keyboardSize`).

## Design

### 1. Model (AllyKeyboardCore, Codable, tested)

```swift
struct KeyboardLayout: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var rows: [[KeySpec]]
    var formatVersion: Int          // for future migrations
}

struct KeySpec: Codable, Equatable {
    var action: KeyAction
    var label: String?              // nil = the action's default label
    var secondary: String?
    var icon: String?               // SF Symbol or bundled asset name
    var width: Double               // 1.0 = standard key
    var fontScale: Double
    var colored: Bool
}

enum KeyAction: Codable, Equatable {
    case character(String)          // a layout-aware key: "Q", "1", "[" … relabelled per input language
    case literal(String)            // types this text as is (today's `fixed` keys, and short snippets)
    case key(SpecialKey)            // Space, Backspace, Delete, Return, Tab, Escape, arrows, Home/End, PageUp/Down
    case modifier(Modifier)         // Shift, CapsLock, Ctrl, Alt, Cmd (one-shot, as today)
    case shortcut(keyCode: Int, modifiers: [Modifier], label: String?)   // Cmd+C, Cmd+Z, any recorded chord
    case media(MediaKey)            // Mute, VolumeDown, VolumeUp
    case command(Command)           // HideKeyboard, Screenshot, AppSwitcher, Translate, Phrases (Hi),
                                    // LangSwitch, ResizeWidth/Height, NextLayout, ChooseLayout, OpenSettings
    case spacer                     // empty gap, keeps rows aligned
}
```

- The current hard-coded keyboard becomes the default layout **"Standard"**,
  produced by code from today's arrays. A test pins it: same rows, same actions,
  same widths as today, so the move to data cannot change the keyboard by
  accident.
- **Standard is editable like any other layout.** Its factory definition stays
  in code: the first edit saves the user's version as a file, and
  "Reset to factory" brings the original back. So the default can be changed
  freely and never lost.
- Every action keeps a stable string identity (`KeyAction.legacyID`) equal to
  today's key id, so the code that reads ids (smart space, word tracker,
  shortcut rule, Shift/Cmd highlighting) keeps working unchanged in phase 1.

### 2. Storage

- `~/Library/Application Support/AllyKeyboard/layouts/<uuid>.json`, one file per
  user layout; the active layout's id in `Settings` (`activeLayoutID`, default:
  Standard).
- An unreadable or invalid file is moved aside (as the vocabulary does) and the
  keyboard falls back to Standard.

### 3. Never locked out

The keyboard is this user's only way to type, so a layout must never be able to
take that away:

- switching layouts and opening Settings stay reachable **outside** the
  keyboard: menu bar menu, the launcher's and the keyboard's right-click menu;
- the validator refuses to save a layout with no keys, and warns (does not
  refuse) when a layout lacks Space, Backspace or Return;
- "Switch to Standard" is always one click away in the menu, and
  "Reset Standard to factory" in Settings undoes any edit to it.

### 4. Rendering and dispatch

- `buildKeyboard()` reads the active layout instead of the static arrays;
  `keyboardSize` comes from it; switching rebuilds the window in place, keeping
  its position.
- `keyPressed` dispatches on `KeyAction` instead of id strings. Phase 1 does this
  with **no visible change**: Standard must behave exactly as today.

### 5. Switching layouts

- Menu bar and right-click menus: "Layout ▸" with the list, a checkmark on the
  active one.
- Key actions `NextLayout` (cycles) and `ChooseLayout` (opens a small chooser
  panel of big buttons, head-mouse friendly).
- Standard gets neither by default; the user adds them where they want.

### 6. Editor (its own window, opened from Settings and the menus; AppKit)

A preview of a full keyboard plus an inspector does not fit the Settings window,
so the editor gets a window of its own.


- Left: the list of layouts — New (empty or copy of the current), Duplicate,
  Rename, Delete, Make active, Export…, Import….
- Centre: a live preview of the selected layout, drawn with the keyboard's own
  key views. Clicking a key selects it.
- Right: the selected key's inspector — action (grouped picker: Letters & digits,
  Text, Editing & navigation, Modifiers, Shortcuts, Media, Keyboard commands,
  Gap), label, secondary label, icon, width (stepper, 0.5 steps), colored icon.
  A "Record shortcut" button for custom chords.
- Under the preview, click-only structure editing: ◀ ▶ move key, ▲ ▼ move to the
  row above or below, insert key before/after, delete key, add row above/below,
  delete row.
- Edits apply to the preview at once; "Save" writes the file and, if the layout
  is active, rebuilds the keyboard. "Revert" drops unsaved edits.

### 7. Import and export

Plain JSON (`.allykeyboard-layout`), versioned; import validates and refuses a
file it cannot read rather than half-loading it.

## Phases

Each phase ends with tests green, a build installed, and a check on the device.

1. **Model and Standard as data.** `KeyboardLayout`, `KeySpec`, `KeyAction`,
   `Standard` built in code, Codable round trip, the "same as today" test. No app
   change yet.
2. **Render and dispatch from the model.** The keyboard is built from Standard;
   `keyPressed` dispatches on actions. Nothing visible changes — verified by
   the Core tests and by using the keyboard.
3. **Several layouts.** Storage, `activeLayoutID`, switching from the menus and
   the NextLayout / ChooseLayout actions, fallback and lock-out safeguards.
   Layouts are still created by duplicating Standard and editing JSON by hand —
   enough to prove switching end to end.
4. **The editor.** The Layouts tab: list, preview, inspector, click-only
   structure editing, save/revert.
5. **Import/export and polish.** Files, validator messages, README section.
6. **Review to zero** over the whole branch, then merge and release.

## Risks

- **Ids are read in many places** (smart space, word tracker, shortcut rule,
  relabelling, Shift/Cmd highlighting). Mitigation: `legacyID` keeps the
  existing strings in phase 2; any later change to them goes with tests.
- **Window size changes on switch** could put the keyboard partly off screen:
  clamp to the visible frame, as the launcher does.
- **A bad layout file** must never break startup: fallback to Standard, file
  moved aside, a notice in Settings.
- **Settings window size**: the editor needs room; it may get its own window.

## Decisions (2026-11-10)

- The default layout is editable too, with a factory reset (the user's call).
- No new key actions are needed for the author; the action list above is for
  other people's layouts. Shortcut recording stays in, as the general way to
  add any chord.
- The editor gets its own window (room for a full-size preview).
- Automatic switching per application: not now; the model leaves room for it.
