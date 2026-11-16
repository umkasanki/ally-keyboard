//
//  AppleLayouts.swift
//  AllyKeyboardCore
//
//  A starting point for a new layout: macOS's own Accessibility Keyboard, as
//  it first appears — the top row of a Mac keyboard (brightness, Mission
//  Control, Launchpad, F5, F6, music, sound) ending in its Panels button, here
//  this keyboard's Choose Layout, layouts being what its panels are; then a
//  Mac's keys, fn among them, working as Apple's does (`FnLayer`), and its
//  half-height arrows (`KeySpec.half`). Every row is as wide as the others. It took the place of the two Magic Keyboard templates (the user's
//  call, 2026-11-16).
//

import Foundation

extension KeyboardLayout {

    /// The Accessibility Keyboard — under a new id for New ▸, under its own
    /// for the built-in one (`accessibilityKeyboardID`).
    public static func accessibilityKeyboard(id: UUID = UUID()) -> KeyboardLayout {
        KeyboardLayout(id: id, name: "Accessibility Keyboard",
                       rows: [topRow, numberRow, tabRow, capsRow, shiftRow, bottomRow])
    }

    // MARK: - Keys

    private static func ch(_ id: String, _ label: String? = nil, secondary: String? = nil) -> KeySpec {
        KeySpec(.character(id), label: label, secondary: secondary)
    }
    /// Every row is fourteen and a half keys wide, as on Apple's (measured
    /// from its screenshot, 2026-11-16): the top row's fourteen keys share
    /// that width equally.
    private static let topKey = 14.5 / 14

    /// Esc, the keys a Mac sends from its top row by default, and the
    /// Panels button — Choose Layout.
    private static let topRow: [KeySpec] = [
        KeySpec(.key(.escape), label: "esc", width: topKey, fontScale: 0.7),
        KeySpec(.media(.brightnessDown), icon: "sun.min", width: topKey),
        KeySpec(.media(.brightnessUp), icon: "sun.max", width: topKey),
        KeySpec(.command(.missionControl), icon: "rectangle.3.group", width: topKey),
        KeySpec(.command(.launchpad), icon: "square.grid.3x3", width: topKey),
        fKey(96, 5), fKey(97, 6),
        KeySpec(.media(.previous), icon: "backward", width: topKey),
        KeySpec(.media(.playPause), icon: "playpause", width: topKey),
        KeySpec(.media(.next), icon: "forward", width: topKey),
        KeySpec(.media(.mute), icon: "speaker.slash", width: topKey, fontScale: 0.9),
        KeySpec(.media(.volumeDown), icon: "speaker.wave.1", width: topKey, fontScale: 0.9),
        KeySpec(.media(.volumeUp), icon: "speaker.wave.3", width: topKey, fontScale: 0.9),
        KeySpec(.command(.chooseLayout), icon: "list.bullet", width: topKey),
    ]

    private static func fKey(_ code: Int, _ n: Int) -> KeySpec {
        KeySpec(.shortcut(Shortcut(keyCode: code, modifiers: [])), label: "F\(n)", width: topKey, fontScale: 0.7)
    }

    private static let numberRow: [KeySpec] = [
        ch("`", "~", secondary: "`"),
        ch("1", secondary: "!"), ch("2", secondary: "@"), ch("3", secondary: "#"),
        ch("4", secondary: "$"), ch("5", secondary: "%"), ch("6", secondary: "^"),
        ch("7", secondary: "&"), ch("8", secondary: "*"), ch("9", secondary: "("),
        ch("0", secondary: ")"), ch("-", secondary: "_"), ch("=", secondary: "+"),
        KeySpec(.key(.backspace), icon: "delete.backward", width: 1.5),
    ]

    private static let tabRow: [KeySpec] = [
        KeySpec(.key(.tab), icon: "arrow.right.to.line", width: 1.5),
        ch("Q", "q"), ch("W", "w"), ch("E", "e"), ch("R", "r"), ch("T", "t"),
        ch("Y", "y"), ch("U", "u"), ch("I", "i"), ch("O", "o"), ch("P", "p"),
        ch("[", secondary: "{"), ch("]", secondary: "}"), ch("\\", secondary: "|"),
    ]

    private static let capsRow: [KeySpec] = [
        KeySpec(.modifier(.capsLock), icon: "capslock", width: 1.75),
        ch("A", "a"), ch("S", "s"), ch("D", "d"), ch("F", "f"), ch("G", "g"),
        ch("H", "h"), ch("J", "j"), ch("K", "k"), ch("L", "l"),
        ch(";", secondary: ":"), ch("'", secondary: "\""),
        KeySpec(.key(.returnKey), icon: "return", width: 1.75),
    ]

    private static let shiftRow: [KeySpec] =
        [KeySpec(.modifier(.shift), icon: "shift", width: 2.25)] + [
            ch("Z", "z"), ch("X", "x"), ch("C", "c"), ch("V", "v"), ch("B", "b"),
            ch("N", "n"), ch("M", "m"), ch(",", secondary: "<"), ch(".", secondary: ">"), ch("/", secondary: "?"),
        ] + [KeySpec(.modifier(.shift), icon: "shift", width: 2.25)]

    /// The arrows as on a Mac: half-height ← and →, ↑ over ↓ between them.
    private static let bottomRow: [KeySpec] = [
        KeySpec(.modifier(.fn), label: "fn", fontScale: 0.7),
        KeySpec(.modifier(.control), label: "\u{2303}"),
        KeySpec(.modifier(.option), label: "\u{2325}"),
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.25),
        KeySpec(.key(.space), label: "", width: 5),
        KeySpec(.modifier(.command), label: "\u{2318}", width: 1.25),
        KeySpec(.command(.hideKeyboard), icon: "keyboard-glyph"),        // in place of the right ⌥ (the user's call)
        arrow(.arrowLeft, "arrowtriangle.left.fill", .bottom),
        arrow(.arrowUp, "arrowtriangle.up.fill", .top),
        arrow(.arrowDown, "arrowtriangle.down.fill", .bottom),
        arrow(.arrowRight, "arrowtriangle.right.fill", .bottom),
    ]

    private static func arrow(_ key: SpecialKey, _ icon: String, _ half: KeyHalf) -> KeySpec {
        KeySpec(.key(key), icon: icon, fontScale: 0.5, half: half)
    }
}
