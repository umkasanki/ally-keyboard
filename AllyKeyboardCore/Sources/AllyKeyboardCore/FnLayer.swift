//
//  FnLayer.swift
//  AllyKeyboardCore
//
//  What a key does with fn held, where that differs from what it does alone —
//  as on Apple's Accessibility Keyboard and a Mac keyboard: the top row's
//  brightness, Mission Control, Launchpad, music and sound keys are F1–F12,
//  the arrows Home, End, Page Up and Page Down, and Delete deletes forward.
//  Home and End are this keyboard's own (the start and end of the line).
//

import Foundation

public enum FnLayer {

    /// The F-keys' virtual key codes, F1 to F12.
    static let fKeyCodes = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    /// Which F-key a top-row key is, 1 to 12; F5 and F6 are themselves.
    public static func fKeyNumber(of action: KeyAction) -> Int? {
        switch action {
        case .media(.brightnessDown): return 1
        case .media(.brightnessUp): return 2
        case .command(.missionControl): return 3
        case .command(.launchpad): return 4
        case .media(.previous): return 7
        case .media(.playPause): return 8
        case .media(.next): return 9
        case .media(.mute): return 10
        case .media(.volumeDown): return 11
        case .media(.volumeUp): return 12
        default: return nil
        }
    }

    /// The key's action with fn held, or nil where fn changes nothing about
    /// it (the key is then pressed with fn added).
    public static func variant(of action: KeyAction) -> KeyAction? {
        if let n = fKeyNumber(of: action) {
            return .shortcut(Shortcut(keyCode: fKeyCodes[n - 1], modifiers: []))
        }
        switch action {
        case .key(.arrowLeft): return .key(.home)
        case .key(.arrowRight): return .key(.end)
        case .key(.arrowUp): return .key(.pageUp)
        case .key(.arrowDown): return .key(.pageDown)
        case .key(.backspace): return .key(.delete)
        default: return nil
        }
    }

    /// The label a key shows while fn is held: "F1" and so on, for the keys
    /// that become F-keys. The arrows and Delete keep theirs, as on a Mac.
    public static func label(for action: KeyAction) -> String? {
        fKeyNumber(of: action).map { "F\($0)" }
    }
}
