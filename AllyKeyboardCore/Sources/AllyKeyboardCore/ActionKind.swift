//
//  ActionKind.swift
//  AllyKeyboardCore
//
//  The key inspector's Action list: what kind of thing a key does, as Apple's
//  Panel Editor lists them, and under each kind the choices that say exactly
//  what. Every action falls into one kind, so the list always opens on the
//  key's own.
//

import Foundation

public enum ActionKind: String, CaseIterable {
    case none, character, text, key, modifier, keys, system, keyboard, openApp, runShortcut, appleScript, gap

    /// The name in the Action list.
    public var title: String {
        switch self {
        case .none: return "None"
        case .character: return "Character"
        case .text: return "Type Text"
        case .key: return "Key"
        case .modifier: return "Modifier"
        case .keys: return "Press Keyboard Shortcut"
        case .system: return "System Event"
        case .keyboard: return "Keyboard"
        case .openApp: return "Open App"
        case .runShortcut: return "Run Command from Shortcuts App"
        case .appleScript: return "AppleScript"
        case .gap: return "Empty Space"
        }
    }

    /// What a key with this action does, as a kind.
    public static func of(_ action: KeyAction) -> ActionKind {
        switch action {
        case .blank: return .none
        case .character: return .character
        case .literal: return .text
        case .key: return .key
        case .modifier: return .modifier
        case .shortcut, .keySequence: return .keys
        case .media, .command(.missionControl), .command(.spotlight), .command(.launchpad),
             .command(.languageSwitch):
            return .system
        case .command: return .keyboard
        case .openApp: return .openApp
        case .appleScript: return .appleScript
        case .runShortcut: return .runShortcut
        case .spacer: return .gap
        }
    }

    /// The exact actions a kind offers in a second list, each with the look a
    /// key gets when it is chosen; empty for the kinds set by a field (text,
    /// a recorded chord, an app, a script) or by nothing at all.
    public var choices: [ActionChoice] {
        switch self {
        case .character: return ActionCatalog.lettersAndDigits.choices
        case .key: return ActionCatalog.editing.choices + ActionCatalog.navigation.choices
        case .modifier: return ActionCatalog.modifiers.choices
        case .keys: return ActionCatalog.shortcuts.choices
        case .system:
            return ActionCatalog.media.choices
                + ActionCatalog.keyboard.choices.filter { Self.systemCommands.contains($0.key.action) }
        case .keyboard:
            return ActionCatalog.keyboard.choices.filter { !Self.systemCommands.contains($0.key.action) }
        case .none, .text, .openApp, .runShortcut, .appleScript, .gap: return []
        }
    }

    /// The keyboard's own commands that are, to the user, system events —
    /// listed with them, as Apple's Panel Editor lists them.
    private static let systemCommands: Set<KeyAction> = [
        .command(.missionControl), .command(.spotlight), .command(.launchpad), .command(.languageSwitch),
    ]

    /// The key a kind starts from when it is picked in the Action list.
    public var start: KeySpec {
        if let first = choices.first { return first.key }
        switch self {
        case .none: return KeySpec(.blank)
        case .text: return KeySpec(.literal(""), label: "")
        case .openApp: return KeySpec(.openApp(""))
        case .runShortcut: return KeySpec(.runShortcut(""))
        case .appleScript: return KeySpec(.appleScript(""), label: "Script")
        case .gap: return KeySpec(.spacer)
        default: return KeySpec(.blank)
        }
    }
}
