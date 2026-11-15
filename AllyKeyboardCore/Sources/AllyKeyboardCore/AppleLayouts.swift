//
//  AppleLayouts.swift
//  AllyKeyboardCore
//
//  Starting points for a new layout: Apple's own keyboards, as near as an
//  on-screen keyboard can come. The Magic Keyboard (compact) and the Magic
//  Keyboard with Numeric Keypad. The top-row keys that cannot be pressed for
//  the user — Dictation, Do Not Disturb, Touch ID — are given this keyboard's
//  own: Screenshot, the app switcher, Hide Keyboard (the user's call,
//  2026-11-15); fn / Globe switches the input source, its main job on a Mac; the half-height arrows become whole keys,
//  ↑ over ↓. Every row is as wide as the others.
//

import Foundation

extension KeyboardLayout {

    /// Apple's Magic Keyboard — or, with `numericKeypad`, the Magic Keyboard
    /// with Numeric Keypad — under a new id.
    public static func magicKeyboard(numericKeypad: Bool) -> KeyboardLayout {
        let name = numericKeypad ? "Magic Keyboard with Numeric Keypad" : "Magic Keyboard"
        var rows = [topRow, numberRow, tabRow, capsRow,
                    numericKeypad ? shiftRowFull : shiftRowCompact,
                    numericKeypad ? bottomRowFull : bottomRowCompact]
        if numericKeypad {
            let gap = { (w: Double) in KeySpec(.spacer, width: w) }
            let fKeys = [(105, 13), (107, 14), (113, 15), (106, 16), (64, 17), (79, 18), (80, 19)].map { code, n in
                KeySpec(.shortcut(Shortcut(keyCode: code, modifiers: [])), label: "F\(n)", fontScale: 0.7)
            }
            let nav: [[KeySpec]] = [
                Array(fKeys.prefix(3)),
                [KeySpec(.command(.languageSwitch), label: "fn", fontScale: 0.7), word(.home, "Home"), word(.pageUp, "PgUp")],
                [KeySpec(.key(.delete), icon: "delete.forward"), word(.end, "End"), word(.pageDown, "PgDn")],
            ]
            let pad: [[KeySpec]] = [
                Array(fKeys.suffix(4)),
                [KeySpec(.shortcut(Shortcut(keyCode: 71, modifiers: [])), label: "clear", fontScale: 0.7),
                 text("="), text("/"), text("*")],
                [digit("7"), digit("8"), digit("9"), text("-")],
                [digit("4"), digit("5"), digit("6"), text("+")],
                [digit("1"), digit("2"), digit("3"), enter],
                [KeySpec(.character("0"), width: 2), text("."), enter],
            ]
            rows[0] += [gap(0.5)] + nav[0] + [gap(0.5)] + pad[0]
            rows[1] += [gap(0.5)] + nav[1] + [gap(0.5)] + pad[1]
            rows[2] += [gap(0.5)] + nav[2] + [gap(0.5)] + pad[2]
            rows[3] += [gap(4)] + pad[3]
            rows[4] += [gap(1.5), KeySpec(.key(.arrowUp), icon: "arrow.up"), gap(1.5)] + pad[4]
            rows[5] += [gap(0.5), KeySpec(.key(.arrowLeft), icon: "arrow.left"),
                        KeySpec(.key(.arrowDown), icon: "arrow.down"),
                        KeySpec(.key(.arrowRight), icon: "arrow.right"), gap(0.5)] + pad[5]
        }
        return KeyboardLayout(name: name, rows: rows)
    }

    // MARK: - Keys

    private static func ch(_ id: String, _ label: String? = nil, secondary: String? = nil) -> KeySpec {
        KeySpec(.character(id), label: label, secondary: secondary)
    }
    private static func digit(_ d: String) -> KeySpec { KeySpec(.character(d)) }
    private static func text(_ t: String) -> KeySpec { KeySpec(.literal(t), label: t) }
    private static func word(_ key: SpecialKey, _ label: String) -> KeySpec { KeySpec(.key(key), label: label, fontScale: 0.7) }
    private static let enter = KeySpec(.key(.returnKey), label: "enter", fontScale: 0.7)

    /// Esc, then the top row's keys as a Mac sends them by default.
    private static let topRow: [KeySpec] = [
        KeySpec(.key(.escape), label: "esc", width: 1.5, fontScale: 0.7),
        KeySpec(.media(.brightnessDown), icon: "sun.min"),
        KeySpec(.media(.brightnessUp), icon: "sun.max"),
        KeySpec(.command(.missionControl), icon: "rectangle.3.group"),
        KeySpec(.shortcut(Shortcut(keyCode: 49, modifiers: [.command])), icon: "magnifyingglass"),   // Spotlight
        KeySpec(.command(.screenshot), icon: "camera"),             // in place of Dictation
        KeySpec(.command(.appSwitcher), icon: "square.grid.2x2"),   // in place of Do Not Disturb
        KeySpec(.media(.previous), icon: "backward.fill"),
        KeySpec(.media(.playPause), icon: "playpause.fill"),
        KeySpec(.media(.next), icon: "forward.fill"),
        KeySpec(.media(.mute), icon: "volume-off-icon", colored: true),
        KeySpec(.media(.volumeDown), icon: "volume-down-icon", colored: true),
        KeySpec(.media(.volumeUp), icon: "volume-up-icon", colored: true),
        KeySpec(.command(.hideKeyboard), icon: "keyboard-glyph", width: 1.5),   // in place of Touch ID
    ]

    private static let numberRow: [KeySpec] = [
        ch("`", "~", secondary: "`"),
        ch("1", secondary: "!"), ch("2", secondary: "@"), ch("3", secondary: "#"),
        ch("4", secondary: "$"), ch("5", secondary: "%"), ch("6", secondary: "^"),
        ch("7", secondary: "&"), ch("8", secondary: "*"), ch("9", secondary: "("),
        ch("0", secondary: ")"), ch("-", secondary: "_"), ch("=", secondary: "+"),
        KeySpec(.key(.backspace), icon: "delete.backward", width: 2),
    ]

    private static let tabRow: [KeySpec] = [
        KeySpec(.key(.tab), label: "tab", width: 1.5, fontScale: 0.7),
        ch("Q", "q"), ch("W", "w"), ch("E", "e"), ch("R", "r"), ch("T", "t"),
        ch("Y", "y"), ch("U", "u"), ch("I", "i"), ch("O", "o"), ch("P", "p"),
        ch("[", secondary: "{"), ch("]", secondary: "}"),
        KeySpec(.character("\\"), secondary: "|", width: 1.5),
    ]

    private static let capsRow: [KeySpec] = [
        KeySpec(.modifier(.capsLock), label: "caps lock", width: 1.75, fontScale: 0.7),
        ch("A", "a"), ch("S", "s"), ch("D", "d"), ch("F", "f"), ch("G", "g"),
        ch("H", "h"), ch("J", "j"), ch("K", "k"), ch("L", "l"),
        ch(";", secondary: ":"), ch("'", secondary: "\""),
        KeySpec(.key(.returnKey), icon: "return", width: 2.25),
    ]

    private static let letters: [KeySpec] = [
        ch("Z", "z"), ch("X", "x"), ch("C", "c"), ch("V", "v"), ch("B", "b"),
        ch("N", "n"), ch("M", "m"), ch(",", secondary: "<"), ch(".", secondary: ">"), ch("/", secondary: "?"),
    ]

    /// ↑ stands over ↓: a gap after it, over →.
    private static let shiftRowCompact: [KeySpec] =
        [KeySpec(.modifier(.shift), icon: "shift", width: 1.75)] + letters +
        [KeySpec(.modifier(.shift), icon: "shift", width: 1.25),
         KeySpec(.key(.arrowUp), icon: "arrow.up"), KeySpec(.spacer)]

    private static let shiftRowFull: [KeySpec] =
        [KeySpec(.modifier(.shift), icon: "shift", width: 2.25)] + letters +
        [KeySpec(.modifier(.shift), icon: "shift", width: 2.75)]

    private static let bottomRowCompact: [KeySpec] = [
        KeySpec(.command(.languageSwitch), label: "fn", fontScale: 0.7),
        KeySpec(.modifier(.control), label: "\u{2303}"),
        KeySpec(.modifier(.option), label: "\u{2325}"),
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.25),
        KeySpec(.key(.space), label: "", width: 5.5),
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.25),
        KeySpec(.modifier(.option), label: "\u{2325}"),
        KeySpec(.key(.arrowLeft), icon: "arrow.left"),
        KeySpec(.key(.arrowDown), icon: "arrow.down"),
        KeySpec(.key(.arrowRight), icon: "arrow.right"),
    ]

    private static let bottomRowFull: [KeySpec] = [
        KeySpec(.modifier(.control), label: "\u{2303}", width: 1.25),
        KeySpec(.modifier(.option), label: "\u{2325}", width: 1.25),
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.5),
        KeySpec(.key(.space), label: "", width: 7),
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.5),
        KeySpec(.modifier(.option), label: "\u{2325}", width: 1.25),
        KeySpec(.modifier(.control), label: "\u{2303}", width: 1.25),
    ]
}
