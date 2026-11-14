# Editable layouts — implementation plan

Branch: `feature/editable-layouts`. Status: phases 1–5 done (model, the
keyboard built from it, several layouts with switching, the editor,
import/export); phase 6 under way — the branch reviewed to zero (below), then
merge and release.

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

- The current hard-coded keyboard becomes a built-in layout, produced by code
  from today's arrays. A test pins it: same rows, same actions, same widths as
  today, so the move to data cannot change the keyboard by accident. (Later
  decided: this one is **Extended**; the default **Standard** is a leaner
  version of it — see Decisions.)
- **Standard is editable like any other layout.** Its factory definition stays
  in code: the first edit saves the user's version as a file, and
  "Reset to factory" brings the original back. So the default can be changed
  freely and never lost.
- Every action keeps a stable string identity (`KeyAction.legacyID`) equal to
  today's key id, so the code that reads ids (smart space, word tracker,
  shortcut rule, Shift/Cmd highlighting) keeps working unchanged in phase 1.

### 2. Storage

- `~/Library/Application Support/AllyKeyboard/Layouts/<uuid>.json`, one file per
  user layout (and per edited built-in); the active layout's id in `Settings`
  (`activeLayoutID`, default: Standard). Each file carries the layout's sizes
  (`geometry`: key width and height, gaps, padding); a file without them gets
  the defaults, and values out of range are brought into it.
- An unreadable or invalid file is skipped, and moved aside (as the vocabulary
  does) at launch and on Reload — not by every read, which would rename a file
  someone is editing by hand. A file from a newer version is left alone. The
  keyboard falls back to Standard.

### 3. Never locked out

The keyboard is this user's only way to type, so a layout must never be able to
take that away:

- switching layouts and opening Settings stay reachable **outside** the
  keyboard: the menu-bar menu and the keyboard's right-click menu;
- the validator refuses to save a layout with no keys, and warns (does not
  refuse) when a layout lacks Space, Backspace or Return;
- "Switch to Standard" is always one click away in the menu, and
  "Layout ▸ Reset … to Factory" undoes any edit to a built-in.

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

#### What others do (researched 2026-11-14)

- **VIA / Vial** (configurators for programmable keyboards): the keyboard drawn
  on top; click a key to select it, then click a keycode in a palette below,
  grouped in tabs (Basic, Media, Layers…). An "Any" entry takes a raw code for
  whatever the palette lacks. Two clicks per change, no dragging.
- **Apple's Panel Editor** (for the macOS Accessibility Keyboard): panels of
  buttons, an inspector for the selected button (title, icon, action), panels
  saved as a file that can be shared.
- **Grid 3** (AAC software): an explicit Edit mode with Finish Editing and Undo
  always in the same corner; Copy and Paste of cells.
- **Hot Virtual Keyboard** (the Windows keyboard this one follows): its editor
  gained a "Swap keys" action — exchange two keys by clicking both.
- **OptiKey / EyeMine** (eye-tracking keyboards): layouts are files edited by
  hand, after copying a built-in one to a custom folder. Workable for the
  technical, not for most people — the folder stays as our power-user path.

#### Design

What fits a head-mouse user: everything by single clicks on large targets —
no drag and drop, no double clicks, nothing shown only on hover, no tiny
steppers — and Undo for every change.

- **Top bar:** the layout being edited (a pop-up of all layouts), New,
  Duplicate, Rename, Delete (Reset to Factory for a built-in), Import, Export;
  Undo and Redo, large, always in the same place; Save and Revert.
- **Preview:** the layout drawn as the keyboard draws it, larger. Click a key
  to select it (outlined). Each row shows its width at the right edge and is
  marked when it differs from the others, so rows can be evened up.
- **Action palette** under the preview, VIA-style, in tabs: Letters & Digits,
  Text (type any text), Editing (Space, ⌫, Return, Tab, Esc, Delete),
  Navigation (arrows, Home/End, Page Up/Down), Modifiers, Shortcuts (common
  ones, plus "Record shortcut…" for any chord — our "Any"), Media, Keyboard
  (hide, screenshot, app switcher, translate, phrases, language, next/choose
  layout, settings), Gaps (Gap, Blank). Clicking an action assigns it to the
  selected key at once.
- **Inspector** on the right for the selected key: label, corner label, icon
  (a grid of the bundled icons and common SF Symbols), width and font size with
  big − / + buttons (0.25 steps), colored icon.
- **Structure buttons** (click-only): move ◀ ▶, move to the row above ▲ /
  below ▼, Swap (then click the other key), insert a key left / right (a Blank),
  delete key, add row above / below, delete row.
- **Problems** shown in a strip: no keys (cannot save), no Space / Backspace /
  Return, rows of different widths.
- Edits go to a working copy shown in the preview; Save writes the file and, if
  the layout is active, rebuilds the keyboard; Revert drops the edits. Editing
  a built-in saves the user's version of it (Reset to Factory brings the
  original back).

#### Built in three steps

- **4a — editor model in Core**, no UI: a working copy, the selected key, every
  edit as an operation (assign action, set label/icon/width/font, move,
  swap, insert, delete, add/delete row), Undo/Redo, row widths and problems.
  Fully unit-tested — the window only calls it.
- **4b — the window**: top bar, preview with selection, structure buttons,
  Save/Revert, Undo/Redo, problems strip.
- **4c — palette, inspector and shortcut recording.**
- **4d — the window redesigned** (the user's call, 2026-11-14): the window
  edits the keyboard as a whole — key width and height, gaps, padding, rows,
  each with − / + — and moves, swaps and deletes keys; one key's action and
  look are edited in a dialog of its own (New Key…, prefilled from the
  selection, and Edit Key…). Short rows are drawn centred, as the keyboard
  draws them; a status bar at the bottom shows the hint, errors and warnings.

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
- Two built-in layouts (2026-11-14): **Extended** is the keyboard as built for
  its first user; **Standard**, the default for everyone else, leaves out the
  input-language key and the Windows-style Home / Page Up / Page Down / End
  column (Space one key narrower, Translate in front of the arrows so ↑ stays
  above ↓). Both are editable, with a factory reset each. The author uses
  Extended.
- A third (2026-11-14): **Standard Multilingual** — Standard with the
  input-language key kept and Screenshot left out, for people who type in more
  than one language.
- Sizes belong to the layout (2026-11-14): each layout's file carries its own
  key width and height, gaps and padding; the size setting scales them all.

## Review to zero (2026-11-14)

The whole branch against `main`, in three areas (Core; the keyboard's
integration; the editor's windows), against this plan and main's behaviour.

- **Pass 1** — 32 findings, 3 of them grade 1: a blank key drawn empty in the
  preview but "Blank" on the keyboard; the preview left-aligning rows the
  keyboard centres; Done on an unchanged spacebar relabelling it. Grade 2
  included a Type Text key whose text named a command ("Hi", "Shift") running
  that command, unchecked sizes and key codes in files, the suggestion balloon
  outliving a recorded shortcut, and no migration for existing installs — the
  user's call: settings from before layouts open on **Extended**, the keyboard
  they had; new installs on Standard.
- **Pass 2** (the fixes) — 8, all grade 3; every pinned fix mutation-checked.
- **Pass 3** (the fixes to those, and the migration) — 4, all grade 3. Closed.

Deferred, with reasons: the "same as main" test still pins ids and widths only
(Extended was checked key by key against main by the reviewer); the size
setting does not clamp the keyboard on screen (as on main); quitting is refused
while one of the app's dialogs is up, logout included (AppKit's usual
behaviour). Not testable without an app test target, so checked on the device:
the Type Text dispatch, suggestions after a shortcut, the key dialog's labels,
the quit prompt, typing into the editor's dialogs.

