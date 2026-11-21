# Layouts and the layout editor

The keys on the keyboard come from a **layout**. Four are built in —
**Standard**, **Standard Multilingual**, **Extended** and **Accessibility
Keyboard** — and you can make your own. Switch layouts from the menu-bar icon
or the right-click menu (**Layout ▸**); **Layout ▸ Edit Layouts…** opens the
editor.

## The editor

One window. The keyboard is drawn large on the left; on the right is a column
for the keyboard as a whole, which becomes the **key inspector** while a key
is edited. Everything is a single click on a large button: no drag and drop,
no double clicks, nothing that appears only on hover. Undo and Redo take back
any change; nothing is written to disk until **Save** (**Revert** drops the
edits).

- **Top bar** — the layout being edited, **New ▸** (an almost empty layout, or
  a copy of a built-in one to start from),
  Duplicate, Rename, Delete (**Reset to Factory** for a built-in), Import,
  Export; Undo, Redo, Revert, Save.
- **The keyboard as a whole** — key width and height, the gaps between keys
  and rows, the padding and the number of rows, each with − / +; **Align
  rows** Left, Centre or Stretch (stretched keys grow, the gaps stay). Each
  row's width is written at its right edge, so uneven rows show; a row
  shorter than the longest has its empty places drawn dashed. Centre turns
  into Left by itself once rows are of different widths.
- **Keys** — click a key to select it, then ◀ ▶ ▲ ▼ (a key moves through
  empty room as well as past other keys), **Swap** (then click the other key),
  **Delete Key**; **Add Group…** puts in a number row, a media row
  (brightness, Mission Control, music, sound) or a Home / Page Up / Page Down
  / End column at once.
- **Add Key…** and **Edit Key…** open the inspector in the right-hand column.
  Every change shows on the key at once and is one Undo step; clicking
  another key moves the inspector to it; **Done** goes back to the keyboard
  column.
- **Status bar** at the bottom — the hint for what is on screen, warnings
  (no Space key, uneven rows) and errors (nothing to save).

## The key inspector

**Action** — what the key does:

| Action | |
|---|---|
| None | does nothing |
| Character | a letter, digit or symbol; follows the input source |
| Type Text | types the text as it is, whatever the input source |
| Key | Space, Return, Tab, Delete, Esc, the arrows, Home / End, Page Up / Down |
| Modifier | ⇧ ⌃ ⌥ ⌘ fn, held for the next key; with fn the top row is F1–F12 and the arrows Home, End, Page Up and Down, as on Apple's Accessibility Keyboard |
| Press Keyboard Shortcut | one or more shortcuts, pressed in turn |
| System Event | sound, brightness, music, Mission Control, Spotlight, Launchpad, the input source |
| Keyboard | one of AllyKeyboard's own commands — hide, screenshot, the app switcher, translate, **Show Phrases**, next or chosen layout, settings |
| Open App | an app chosen with **Choose…** |
| Run Command from Shortcuts App | one of your Shortcuts, picked from a list |
| AppleScript | a script, run in the background |
| Empty Space | a gap that keeps the rows lined up |

A **Show Phrases** key has its own list of phrases, one a line, so several
keys can offer different ones.

**Shortcuts** for *Press Keyboard Shortcut* are recorded with **Record…**,
picked from **Common**, or written in the field:

- `⌘C`, `⇧⌘5`, `⌘→`, `⌘Space`, `F13` — modifiers as symbols, then the key
  (F-keys are pressed this way);
- `cmd+shift+5`, `ctrl+alt+delete` — or as words joined by `+`;
- `⌘H, ⇧⌘5` — several shortcuts, pressed one after another, separated by
  commas (spaces optional);
- `⌘⌘` or `⌘, ⌘` — a modifier on its own is pressed and let go by itself:
  this is Command pressed twice, macOS's shortcut for Dictation. **Add Tap**
  adds one without typing (the on-screen ⌘ only arms the next key, so a tap
  cannot be recorded from it);
- the comma key is written `Comma`; letters always by the US layout, whatever
  the input source.

Text the field cannot read turns red and changes nothing.

**Look** — the label, the corner label, the font size, the width, the
**height** (the whole row, or its top or bottom half: a top half followed by
a bottom half share one place, ↑ over ↓, as a Mac's arrows do) and the
**icon**: bundled images and SF Symbols, listed A to Z, with a search field
above the list. **Second icon, every other press** (folded away until
opened) gives a key a second icon it switches to on each press and back on
the next — for a shortcut that starts and stops something, such as a
microphone key for Dictation (`mic`, then `mic.slash`). The keyboard counts
presses: it cannot tell whether the thing was stopped in another way.

## Files and sharing

Built-in layouts can be edited too; **Reset to Factory** brings the original
back. Each layout is one JSON file in
`~/Library/Application Support/AllyKeyboard/Layouts`.

**Export…** writes the layout on screen to an `.allykeyboard-layout` file (the
same JSON); **Import…** reads one. An import is added beside the layouts
already there — never in place of one — and a file that cannot be read, comes
from a newer version of the app, or has no keys is refused with a message
saying why. A file whose keys run AppleScript asks before it is imported.
