//
//  KeySender.swift
//  AllyKeyboard
//

import Cocoa

/// Sends synthetic keyboard events to the frontmost application.
/// Requires Accessibility permission — call `requestAccessibilityIfNeeded()` at launch.
enum KeySender {

    // MARK: - Public API

    /// Send a key event. `keyID` matches `Key.id` defined in ViewController.
    static func send(_ keyID: String, shifted: Bool = false, modifiers: CGEventFlags = []) {
        // Chord (Ctrl/Alt/Cmd held): send via virtual keycode + flags so the target
        // app recognises the shortcut — unicode injection ignores modifier flags.
        if !modifiers.isEmpty {
            // Some of the top row's characters have no key of their own. `+` is
            // Shift and `=`, and a lookup by the character alone finds nothing,
            // so Command-plus used to fall through to unicode injection, which
            // carries no modifiers at all: the shortcut simply never arrived.
            if let s = shiftedKeyCodes[keyID] {
                sendKeyCode(s, flags: modifiers.union(.maskShift))
                return
            }
            if let code = keyCode(for: keyID) {
                var flags = modifiers
                if shifted { flags.insert(.maskShift) }
                sendKeyCode(code, flags: flags)
                return
            }
        }
        switch keyID {
        case "Space":     sendKeyCode(49)
        case "Backspace": sendKeyCode(51)
        case "Delete":    sendKeyCode(117)
        case "Return":    sendKeyCode(36)
        case "Tab":       sendKeyCode(48)
        case "Escape":    sendKeyCode(53)
        // The system's capture panel — Shift-Cmd-5. Not Shift-Cmd-3, which fires
        // immediately and gives no choice, and not Shift-Cmd-4, which asks for
        // a rectangle to be dragged. The panel's options are all clicks.
        case "Screenshot": sendKeyCode(23,  flags: [.maskCommand, .maskShift])
        case "Cmd+C":      sendKeyCode(8,   flags: .maskCommand)
        case "Cmd+V":      sendKeyCode(9,   flags: .maskCommand)
        case "Cmd+Z":      sendKeyCode(6,   flags: .maskCommand)
        case "Cmd+A":      sendKeyCode(0,   flags: .maskCommand)
        case "Cmd+X":      sendKeyCode(7,   flags: .maskCommand)
        case "ArrowUp":    sendKeyCode(126)
        case "ArrowDown":  sendKeyCode(125)
        case "ArrowLeft":  sendKeyCode(123)
        case "ArrowRight": sendKeyCode(124)
        case "Home":       sendKeyCode(115)
        case "End":        sendKeyCode(119)
        case "PageUp":     sendKeyCode(116)
        case "PageDown":   sendKeyCode(121)
        case "Mute":       sendMediaKey(7)
        case "VolumeDown": sendMediaKey(1)
        case "VolumeUp":   sendMediaKey(0)
        case "fn", "Ctrl", "Alt", "Cmd", "CapsLock":
            break // modifier-only keys — no action yet
        case "Hi":
            break // greetings placeholder — not wired yet
        case "LangSwitch", "HideKeyboard":
            break // handled in ViewController before reaching KeySender
        default:
            // Prefer virtual keycode so the active system layout (language) applies;
            // fall back to unicode for anything without a known keycode.
            if let code = keyCode(for: keyID) {
                var flags: CGEventFlags = []
                if shifted { flags.insert(.maskShift) }
                sendKeyCode(code, flags: flags)
            } else {
                let char = shifted ? keyID.uppercased() : keyID.lowercased()
                sendUnicode(char)
            }
        }
    }

    /// Shows the system Accessibility permission prompt if not yet granted.
    static func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    // MARK: - Private helpers

    /// US-ANSI virtual keycodes for keys that can take part in a chord.
    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8,
        "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
        "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42, ";": 41, "'": 39,
        ",": 43, ".": 47, "/": 44, "`": 50,
        "Space": 49, "Return": 36, "Tab": 48, "Escape": 53,
        "ArrowUp": 126, "ArrowDown": 125, "ArrowLeft": 123, "ArrowRight": 124,
        "Home": 115, "End": 119, "PageUp": 116, "PageDown": 121,
    ]

    /// Characters that are a key *plus Shift*, not a key. Without these a chord
    /// built on one of them is lost: the top row types `+`, `!`, `?` and `@` as
    /// literals, which is right on its own and useless the moment Command is
    /// held. US-ANSI positions, which is what the virtual keycodes above are.
    private static let shiftedKeyCodes: [String: CGKeyCode] = [
        "+": 24,   // Shift-=
        "_": 27,   // Shift--
        "!": 18, "@": 19, "#": 20, "$": 21, "%": 23, "^": 22, "&": 26, "*": 28,
        "(": 25, ")": 29,
        "?": 44,   // Shift-/
        ":": 41, "\"": 39, "<": 43, ">": 47, "{": 33, "}": 30, "|": 42, "~": 50,
    ]

    static func keyCode(for keyID: String) -> CGKeyCode? {
        keyCodes[keyID] ?? keyCodes[keyID.lowercased()]
    }

    private static let eventSource = CGEventSource(stateID: .hidSystemState)

    /// Where a finished event goes: to whatever application is active, which is
    /// right because this one never is — the keyboard is a non-activating panel
    /// on purpose, so that a key press does not take focus from the document
    /// being typed into.
    private static func deliver(_ event: CGEvent?) {
        event?.post(tap: .cghidEventTap)
    }

    private static func sendKeyCode(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        deliver(down)
        deliver(up)
    }

    private static func sendMediaKey(_ keyCode: Int32) {
        let data1down = Int((keyCode << 16) | (0xa << 8))
        let data1up   = Int((keyCode << 16) | (0xb << 8))
        let down = NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1down, data2: -1)
        let up = NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1up, data2: -1)
        deliver(down?.cgEvent)
        deliver(up?.cgEvent)
    }

    /// Type a literal string (used to insert a chosen suggestion).
    static func sendText(_ string: String) {
        sendUnicode(string)
    }

    private static func sendUnicode(_ string: String) {
        var chars = Array(string.utf16)
        let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true)
        down?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false)
        up?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        deliver(down)
        deliver(up)
    }
}
