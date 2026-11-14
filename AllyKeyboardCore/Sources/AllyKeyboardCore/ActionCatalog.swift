//
//  ActionCatalog.swift
//  AllyKeyboardCore
//
//  What the layout editor's palette offers, in tabs, each entry with the
//  look a key gets when it is given that action. See docs/layouts-plan.md,
//  "Editor".
//

import Foundation

/// One entry of the palette: an action, and how a key doing it looks.
public struct ActionChoice: Equatable {
    /// The name on the palette button.
    public var name: String
    /// The key a click gives the selected one; its width and font size are
    /// kept from the key it lands on.
    public var key: KeySpec

    public init(_ name: String, _ key: KeySpec) {
        self.name = name
        self.key = key
    }
}

public struct ActionGroup: Equatable {
    public var title: String
    public var choices: [ActionChoice]
}

public enum ActionCatalog {

    /// The palette's tabs, in order.
    public static let groups: [ActionGroup] = [
        lettersAndDigits, text, editing, navigation, modifiers, shortcuts, media, keyboard, gaps,
    ]

    private static func character(_ id: String, _ label: String? = nil, _ secondary: String? = nil) -> ActionChoice {
        ActionChoice(label ?? id, KeySpec(.character(id), label: label, secondary: secondary))
    }

    /// Keys of the input layout, by their US names; they show what the
    /// active language puts there, as on the keyboard.
    static let lettersAndDigits = ActionGroup(title: "Letters & Digits", choices:
        "QWERTYUIOPASDFGHJKLZXCVBNM".map { character(String($0), String($0).lowercased()) }
        + [("1", "!"), ("2", "@"), ("3", "#"), ("4", "$"), ("5", "%"), ("6", "^"), ("7", "&"),
           ("8", "*"), ("9", "("), ("0", ")"), ("-", "_"), ("=", "+"), ("[", "{"), ("]", "}"),
           ("\\", "|"), (";", ":"), ("'", "\""), (",", "<"), (".", ">"), ("/", "?")]
            .map { character($0.0, nil, $0.1) }
        + [character("`", "~", "`")])

    /// Characters typed as they are, whatever the input language.
    static let text = ActionGroup(title: "Text", choices:
        ["@", "!", "?", ".", ",", "-", "+", "=", ":", ";", "\"", "'", "(", ")", "/", "*", "#", "$", "%", "&", "_"]
            .map { ActionChoice($0, KeySpec(.literal($0), label: $0)) })

    static let editing = ActionGroup(title: "Editing", choices: [
        ActionChoice("Space", KeySpec(.key(.space), label: "")),
        ActionChoice("Backspace", KeySpec(.key(.backspace), icon: "delete.backward")),
        ActionChoice("Delete", KeySpec(.key(.delete), icon: "delete.forward")),
        ActionChoice("Return", KeySpec(.key(.returnKey), icon: "return")),
        ActionChoice("Tab", KeySpec(.key(.tab), label: "Tab")),
        ActionChoice("Esc", KeySpec(.key(.escape), label: "Esc")),
    ])

    static let navigation = ActionGroup(title: "Navigation", choices: [
        ActionChoice("Left", KeySpec(.key(.arrowLeft), icon: "arrow.left")),
        ActionChoice("Right", KeySpec(.key(.arrowRight), icon: "arrow.right")),
        ActionChoice("Up", KeySpec(.key(.arrowUp), icon: "arrow.up")),
        ActionChoice("Down", KeySpec(.key(.arrowDown), icon: "arrow.down")),
        ActionChoice("Home", KeySpec(.key(.home), label: "Home")),
        ActionChoice("End", KeySpec(.key(.end), label: "End")),
        ActionChoice("Page Up", KeySpec(.key(.pageUp), label: "PgUp")),
        ActionChoice("Page Down", KeySpec(.key(.pageDown), label: "PgDn")),
    ])

    static let modifiers = ActionGroup(title: "Modifiers", choices: [
        ActionChoice("Shift", KeySpec(.modifier(.shift), icon: "shift")),
        ActionChoice("Caps Lock", KeySpec(.modifier(.capsLock), label: "Caps")),
        ActionChoice("Control", KeySpec(.modifier(.control), label: "^")),
        ActionChoice("Option", KeySpec(.modifier(.option), label: "\u{2325}")),
        ActionChoice("Command", KeySpec(.modifier(.command), label: "\u{2318}")),
    ])

    private static func chord(_ name: String, _ keyCode: Int, _ mods: [Modifier],
                              label: String? = nil, icon: String? = nil) -> ActionChoice {
        ActionChoice(name, KeySpec(.shortcut(Shortcut(keyCode: keyCode, modifiers: mods)),
                                   label: label, icon: icon, colored: icon?.hasSuffix("-icon") ?? false))
    }

    /// Common chords; any other is recorded ("Record Shortcut…" in the window).
    static let shortcuts = ActionGroup(title: "Shortcuts", choices: [
        chord("Copy", 8, [.command], icon: "copy-icon"),
        chord("Paste", 9, [.command], icon: "paste-icon"),
        chord("Cut", 7, [.command], icon: "cut-icon"),
        chord("Undo", 6, [.command], icon: "undo-icon"),
        chord("Redo", 6, [.command, .shift], label: "Redo"),
        chord("Select All", 0, [.command], label: "\u{2318}A"),
        chord("Save", 1, [.command], label: "Save"),
        chord("Find", 3, [.command], label: "Find"),
        chord("New Tab", 17, [.command], label: "\u{2318}T"),
        chord("Close", 13, [.command], label: "\u{2318}W"),
    ])

    static let media = ActionGroup(title: "Media", choices: [
        ActionChoice("Mute", KeySpec(.media(.mute), icon: "volume-off-icon", colored: true)),
        ActionChoice("Volume Down", KeySpec(.media(.volumeDown), icon: "volume-down-icon", colored: true)),
        ActionChoice("Volume Up", KeySpec(.media(.volumeUp), icon: "volume-up-icon", colored: true)),
    ])

    static let keyboard = ActionGroup(title: "Keyboard", choices: [
        ActionChoice("Hide Keyboard", KeySpec(.command(.hideKeyboard), icon: "keyboard-glyph")),
        ActionChoice("Screenshot", KeySpec(.command(.screenshot), icon: "camera")),
        ActionChoice("App Switcher", KeySpec(.command(.appSwitcher), icon: "square.grid.2x2")),
        ActionChoice("Translate", KeySpec(.command(.translate), icon: "translate-icon", colored: true)),
        ActionChoice("Phrases", KeySpec(.command(.phrases), icon: "list.bullet")),
        ActionChoice("Language", KeySpec(.command(.languageSwitch), label: "\u{1F310}")),
        ActionChoice("Next Layout", KeySpec(.command(.nextLayout), icon: "rectangle.2.swap")),
        ActionChoice("Choose Layout", KeySpec(.command(.chooseLayout), icon: "keyboard.badge.ellipsis")),
        ActionChoice("Settings", KeySpec(.command(.openSettings), icon: "gearshape")),
        ActionChoice("Window Width", KeySpec(.command(.resizeWidth), icon: "resize-width-icon")),
        ActionChoice("Window Height", KeySpec(.command(.resizeHeight), icon: "resize-height-icon")),
    ])

    static let gaps = ActionGroup(title: "Gaps", choices: [
        ActionChoice("Gap", KeySpec(.spacer)),
        ActionChoice("Blank Key", KeySpec(.blank)),
    ])

    /// Images bundled with the app that a key may show.
    public static let bundledIcons = [
        "copy-icon", "cut-icon", "paste-icon", "undo-icon", "translate-icon",
        "volume-off-icon", "volume-down-icon", "volume-up-icon", "keyboard-glyph",
        "resize-width-icon", "resize-height-icon",
    ]

    /// System symbols offered in the icon picker; any other SF Symbol name can
    /// be written into a layout file.
    public static let symbolIcons = [
        "delete.backward", "delete.forward", "return", "shift", "capslock", "arrow.left", "arrow.right",
        "arrow.up", "arrow.down", "space", "escape", "command", "option", "control", "camera",
        "list.bullet", "square.grid.2x2", "globe", "gearshape", "magnifyingglass", "doc.on.doc",
        "scissors", "arrow.uturn.backward", "arrow.uturn.forward", "speaker.slash", "speaker.wave.1",
        "speaker.wave.3", "keyboard", "rectangle.2.swap", "star", "heart",
    ]
}
