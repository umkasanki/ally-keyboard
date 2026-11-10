//
//  StandardLayout.swift
//  AllyKeyboardCore
//
//  The keyboard as it has been, as data: the factory definition of the
//  default layout. The user may edit their copy of it; this stays the
//  original that "Reset to factory" brings back. Pinned key for key by
//  StandardLayoutTests — change it only on purpose.
//

import Foundation

extension KeyboardLayout {

    /// Fixed, so the default layout is recognised across launches and files.
    public static let standardID = UUID(uuidString: "00000000-0000-0000-0000-00000000A11E")!

    public static let standard = KeyboardLayout(id: standardID, name: "Standard", rows: [
        functionRow, numberRow, qwertyRow, asdfRow, zxcvRow, bottomRow,
    ])

    // Shorthands for the rows below.
    private static func ch(_ id: String, _ label: String? = nil, secondary: String? = nil) -> KeySpec {
        KeySpec(.character(id), label: label, secondary: secondary)
    }
    private static func lit(_ text: String) -> KeySpec { KeySpec(.literal(text), label: text) }
    private static func shortcut(_ name: String, icon: String) -> KeySpec {
        KeySpec(.shortcut(Shortcut.named(name)!), icon: icon, fontScale: 0.85, colored: true)
    }

    private static let functionRow: [KeySpec] = [
        KeySpec(.key(.escape), label: "Esc", width: 1.5, fontScale: 0.7),
        KeySpec(.command(.phrases), icon: "list.bullet"),
        KeySpec(.command(.appSwitcher), icon: "square.grid.2x2"),
        KeySpec(.command(.screenshot), icon: "camera"),
        lit("@"), lit("!"), lit("?"), lit("."), lit(","), lit("-"), lit("+"), lit("="),
        KeySpec(.media(.mute), icon: "volume-off-icon", fontScale: 0.95, colored: true),
        KeySpec(.media(.volumeDown), icon: "volume-down-icon", fontScale: 1.08, colored: true),
        KeySpec(.media(.volumeUp), icon: "volume-up-icon", fontScale: 0.95, colored: true),
        KeySpec(.command(.languageSwitch), label: "\u{1F1FA}\u{1F1F8}", fontScale: 1.5),   // the flag, replaced at run time
    ]

    private static let numberRow: [KeySpec] = [
        ch("`", "~", secondary: "`"),
        ch("1", secondary: "!"), ch("2", secondary: "@"), ch("3", secondary: "#"),
        ch("4", secondary: "$"), ch("5", secondary: "%"), ch("6", secondary: "^"),
        ch("7", secondary: "&"), ch("8", secondary: "*"), ch("9", secondary: "("),
        ch("0", secondary: ")"), ch("-", secondary: "_"), ch("=", secondary: "+"),
        KeySpec(.key(.backspace), icon: "delete.backward", width: 1.5, fontScale: 1.25),
        KeySpec(.key(.home), label: "Home", fontScale: 0.7),
        shortcut("Cmd+C", icon: "copy-icon"),
    ]

    private static let qwertyRow: [KeySpec] = [
        KeySpec(.key(.tab), label: "Tab", width: 1.5, fontScale: 0.7),
        ch("Q", "q"), ch("W", "w"), ch("E", "e"), ch("R", "r"), ch("T", "t"),
        ch("Y", "y"), ch("U", "u"), ch("I", "i"), ch("O", "o"), ch("P", "p"),
        ch("[", secondary: "{"), ch("]", secondary: "}"), ch("\\", secondary: "|"),
        KeySpec(.key(.pageUp), label: "Up", fontScale: 0.7),
        shortcut("Cmd+X", icon: "cut-icon"),
    ]

    private static let asdfRow: [KeySpec] = [
        KeySpec(.modifier(.capsLock), label: "Caps", width: 1.75, fontScale: 0.7),
        ch("A", "a"), ch("S", "s"), ch("D", "d"), ch("F", "f"), ch("G", "g"),
        ch("H", "h"), ch("J", "j"), ch("K", "k"), ch("L", "l"),
        ch(";", secondary: ":"), ch("'", secondary: "\""),
        KeySpec(.key(.returnKey), icon: "return", width: 1.75),
        KeySpec(.key(.pageDown), label: "Down", fontScale: 0.7),
        shortcut("Cmd+V", icon: "paste-icon"),
    ]

    private static let zxcvRow: [KeySpec] = [
        KeySpec(.modifier(.shift), icon: "shift", width: 2.25),
        ch("Z", "z"), ch("X", "x"), ch("C", "c"), ch("V", "v"),
        ch("B", "b"), ch("N", "n"), ch("M", "m"),
        ch(",", secondary: "<"), ch(".", secondary: ">"), ch("/", secondary: "?"),
        KeySpec(.modifier(.shift), icon: "shift", width: 1.25),
        KeySpec(.key(.arrowUp), icon: "arrow.up"),
        KeySpec(.key(.end), label: "End", fontScale: 0.7),
        shortcut("Cmd+Z", icon: "undo-icon"),
    ]

    private static let bottomRow: [KeySpec] = [
        KeySpec(.modifier(.control), label: "^", width: 1.5),
        KeySpec(.modifier(.option), label: "\u{2325}", width: 1.5),
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.5),
        KeySpec(.key(.space), label: "", width: 5),
        // A second ⌘ in place of Del (see ViewController's history).
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.5),
        KeySpec(.command(.hideKeyboard), icon: "keyboard-glyph", width: 1.5),
        KeySpec(.key(.arrowLeft), icon: "arrow.left"),
        KeySpec(.key(.arrowDown), icon: "arrow.down"),
        KeySpec(.key(.arrowRight), icon: "arrow.right"),
        KeySpec(.command(.translate), icon: "translate-icon", fontScale: 0.85, colored: true),
    ]
}
