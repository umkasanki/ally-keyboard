//
//  ShortcutText.swift
//  AllyKeyboardCore
//
//  Chords written as text, for the key inspector's field: "⌘C", "⇧⌘5",
//  "⌘→", "cmd+shift+5", several in turn split by commas ("⌘H, ⇧⌘5"), and a
//  modifier on its own as a tap of it ("⌘⌘" — Command pressed twice). What
//  the field shows reads back as what it was.
//

import Foundation

extension Shortcut {

    /// The US layout's character keys, by virtual key code (Carbon's kVK_ANSI_*).
    public static let usCharacterCodes: [Character: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "n": 45, "m": 46, ".": 47, "`": 50,
    ]

    private static let modifierSymbols: [Character: Modifier] = [
        "\u{2303}": .control, "\u{2325}": .option, "\u{21E7}": .shift, "\u{2318}": .command,
    ]
    /// A modifier alone, as a tap: its left key's code.
    private static let tapCodes: [Modifier: Int] = [.command: 55, .option: 58, .control: 59, .shift: 56, .fn: 63]

    private static let modifierWords: [String: Modifier] = [
        "cmd": .command, "command": .command, "opt": .option, "option": .option, "alt": .option,
        "ctrl": .control, "control": .control, "shift": .shift, "fn": .fn,
    ]

    /// Key names as words, besides the symbols of `keyNames`.
    private static let keyWords: [String: Int] = [
        "space": 49, "return": 36, "enter": 36, "tab": 48, "esc": 53, "escape": 53,
        "delete": 51, "backspace": 51, "forwarddelete": 117, "left": 123, "right": 124,
        "down": 125, "up": 126, "home": 115, "end": 119, "pageup": 116, "pgup": 116,
        "pagedown": 121, "pgdn": 121, "comma": 43,
    ]

    /// The chord as the field writes it, read back by `parseSequence`: "⇧⌘5",
    /// "⌘→", "⌘Space", "⌘". Character keys by the US layout, so the text
    /// does not depend on the input source; the comma key as "Comma", since
    /// a comma separates chords.
    public var text: String {
        let symbols: [(Modifier, String)] = [(.control, "\u{2303}"), (.option, "\u{2325}"),
                                             (.shift, "\u{21E7}"), (.command, "\u{2318}")]
        let key: String
        if let name = Self.keyNames[keyCode] {
            key = name
        } else if keyCode == 43 {
            key = "Comma"
        } else if let ch = Self.usCharacterCodes.first(where: { $0.value == keyCode })?.key {
            key = String(ch).uppercased()
        } else {
            key = "key \(keyCode)"
        }
        // fn has no symbol: a chord with it is written in words, "fn+cmd+→".
        if modifiers.contains(.fn) {
            let words: [(Modifier, String)] = [(.control, "ctrl"), (.option, "opt"), (.shift, "shift"),
                                               (.command, "cmd"), (.fn, "fn")]
            return (words.filter { modifiers.contains($0.0) }.map(\.1) + [key]).joined(separator: "+")
        }
        return symbols.filter { modifiers.contains($0.0) }.map(\.1).joined() + key
    }

    /// Chords in turn as the field writes them: "⌘H, ⇧⌘5".
    public static func text(of chords: [Shortcut]) -> String {
        chords.map(\.text).joined(separator: ", ")
    }

    /// The written chord's key: a name ("→", "F13", "Space", "right ⌘"), a
    /// word ("return"), a character of the US layout ("C", "5"), or "key 105".
    private static func keyCode(named name: String) -> Int? {
        let lower = name.lowercased()
        if let (code, _) = keyNames.first(where: { $0.value.lowercased() == lower }) { return code }
        if let code = keyWords[lower] { return code }
        if lower.count == 1, let code = usCharacterCodes[lower.first!] { return code }
        if lower.hasPrefix("key "), let n = Int(lower.dropFirst(4)), keyCodeRange.contains(n) { return n }
        return nil
    }

    /// Chords from text, in turn; nil if any part is not understood.
    public static func parseSequence(_ text: String) -> [Shortcut]? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty, !parts.contains(where: \.isEmpty) else {
            return text.trimmingCharacters(in: .whitespaces).isEmpty ? [] : nil
        }
        var chords: [Shortcut] = []
        for part in parts {
            guard let some = parseChord(part) else { return nil }
            chords += some
        }
        return chords
    }

    /// One written chord — or, for modifiers alone, a tap of each.
    private static func parseChord(_ part: String) -> [Shortcut]? {
        // Words joined by "+": "cmd+shift+5", "ctrl", "cmd+cmd".
        if part.contains("+") || modifierWords[part.lowercased()] != nil {
            // "cmd+" and "cmd++c" have an empty word: refused, not read as less.
            let words = part.split(separator: "+", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard !words.isEmpty, !words.contains(where: \.isEmpty) else { return nil }
            var mods: [Modifier] = []
            var key: Int?
            for (i, w) in words.enumerated() {
                if let m = modifierWords[w.lowercased()] ?? modifierSymbols[w.first!].flatMap({ w.count == 1 ? $0 : nil }) {
                    mods.append(m)
                } else if i == words.count - 1, let code = keyCode(named: w) {
                    key = code
                } else {
                    return nil
                }
            }
            if let key {
                guard Set(mods).count == mods.count else { return nil }    // "cmd+cmd+c"
                return [Shortcut(keyCode: key, modifiers: mods)]
            }
            return mods.map { Shortcut(keyCode: tapCodes[$0]!, modifiers: []) }
        }
        // Symbols: "⇧⌘5", "⌘→", "⌘⌘", "right ⌘".
        if let code = keyCode(named: part) { return [Shortcut(keyCode: code, modifiers: [])] }
        var mods: [Modifier] = []
        var rest = Substring(part)
        while let c = rest.first, let m = modifierSymbols[c] {
            mods.append(m)
            rest = rest.dropFirst()
        }
        let name = rest.trimmingCharacters(in: .whitespaces)
        // A modifier twice before a key ("⌘⌘C") says nothing a chord can hold.
        if !name.isEmpty, Set(mods).count != mods.count { return nil }
        if name.isEmpty {
            guard !mods.isEmpty else { return nil }
            return mods.map { Shortcut(keyCode: tapCodes[$0]!, modifiers: []) }
        }
        guard let code = keyCode(named: name) else { return nil }
        return [Shortcut(keyCode: code, modifiers: mods)]
    }
}
