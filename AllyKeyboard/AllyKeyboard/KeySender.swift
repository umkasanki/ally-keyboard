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
            break // greeting suggestions — to be implemented in Phase 3
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

    private static func sendKeyCode(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let down = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        let up = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func sendMediaKey(_ keyCode: Int32) {
        let flags: Int = 0
        let data1down = Int((keyCode << 16) | (0xa << 8))
        let data1up   = Int((keyCode << 16) | (0xb << 8))
        let down = NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1down, data2: flags)
        let up = NSEvent.otherEvent(with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1up, data2: flags)
        down?.cgEvent?.post(tap: .cghidEventTap)
        up?.cgEvent?.post(tap: .cghidEventTap)
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
