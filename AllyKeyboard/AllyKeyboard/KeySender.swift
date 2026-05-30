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
    static func send(_ keyID: String, shifted: Bool = false) {
        switch keyID {
        case "Space":     sendKeyCode(49)
        case "Backspace": sendKeyCode(51)
        case "Return":    sendKeyCode(36)
        case "Tab":       sendKeyCode(48)
        case "Escape":    sendKeyCode(53)
        default:
            let char = shifted ? keyID.uppercased() : keyID.lowercased()
            sendUnicode(char)
        }
    }

    /// Shows the system Accessibility permission prompt if not yet granted.
    static func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    // MARK: - Private helpers

    private static let eventSource = CGEventSource(stateID: .hidSystemState)

    private static func sendKeyCode(_ keyCode: CGKeyCode) {
        CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
    }

    private static func sendUnicode(_ string: String) {
        var chars = Array(string.utf16)
        let down = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true)
        down?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        let up = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false)
        up?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
