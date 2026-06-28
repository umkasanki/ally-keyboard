//
//  KeyInput.swift
//  AllyKeyboardCore
//
//  Platform-independent classification of a virtual-keyboard key press.
//  No AppKit / CoreGraphics dependency — buildable and testable on Linux.
//

/// A keystroke reduced to how it affects the current-word buffer.
///
/// The raw `keyID` vocabulary mirrors `KeySender.send(_:shifted:)` in the app,
/// so the two stay in sync: anything `KeySender` types should classify here.
public enum KeyInput: Equatable {
    /// A printable character that may extend or terminate the current word.
    case character(Character)
    /// Erase one character.
    case backspace
    /// A whitespace word boundary (Space, Return, Tab).
    case wordBoundary
    /// A key with no effect on the word buffer (modifiers, navigation, media…).
    case ignored

    /// Maps an app-level `keyID` (as used by `KeySender`) to a `KeyInput`.
    ///
    /// - Parameters:
    ///   - keyID: the key identifier, e.g. `"a"`, `"Space"`, `"Cmd+C"`.
    ///   - shifted: whether Shift was active for this press.
    public static func from(keyID: String, shifted: Bool = false) -> KeyInput {
        switch keyID {
        case "Space", "Return", "Tab":
            return .wordBoundary
        case "Backspace":
            return .backspace
        case "Escape", "Cmd+C", "Cmd+V", "Cmd+Z", "Cmd+A", "Cmd+X",
             "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight",
             "Home", "End", "PageUp", "PageDown",
             "Mute", "VolumeDown", "VolumeUp",
             "fn", "Ctrl", "Alt", "Cmd", "CapsLock", "Shift",
             "Hi", "LangSwitch":
            return .ignored
        default:
            let text = shifted ? keyID.uppercased() : keyID.lowercased()
            guard let char = text.first else { return .ignored }
            return .character(char)
        }
    }
}
