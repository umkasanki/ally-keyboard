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
    public static let lettersAndDigits = ActionGroup(title: "Letters & Digits", choices:
        "QWERTYUIOPASDFGHJKLZXCVBNM".map { character(String($0), String($0).lowercased()) }
        + [("1", "!"), ("2", "@"), ("3", "#"), ("4", "$"), ("5", "%"), ("6", "^"), ("7", "&"),
           ("8", "*"), ("9", "("), ("0", ")"), ("-", "_"), ("=", "+"), ("[", "{"), ("]", "}"),
           ("\\", "|"), (";", ":"), ("'", "\""), (",", "<"), (".", ">"), ("/", "?")]
            .map { character($0.0, nil, $0.1) }
        + [character("`", "~", "`")])

    /// Characters typed as they are, whatever the input language.
    public static let text = ActionGroup(title: "Text", choices:
        ["@", "!", "?", ".", ",", "-", "+", "=", ":", ";", "\"", "'", "(", ")", "/", "*", "#", "$", "%", "&", "_"]
            .map { ActionChoice($0, KeySpec(.literal($0), label: $0)) })

    public static let editing = ActionGroup(title: "Editing", choices: [
        ActionChoice("Space", KeySpec(.key(.space), label: "")),
        ActionChoice("Backspace", KeySpec(.key(.backspace), icon: "delete.backward")),
        ActionChoice("Delete", KeySpec(.key(.delete), icon: "delete.forward")),
        ActionChoice("Return", KeySpec(.key(.returnKey), icon: "return")),
        ActionChoice("Tab", KeySpec(.key(.tab), label: "Tab")),
        ActionChoice("Esc", KeySpec(.key(.escape), label: "Esc")),
    ])

    public static let navigation = ActionGroup(title: "Navigation", choices: [
        ActionChoice("Left", KeySpec(.key(.arrowLeft), icon: "arrow.left")),
        ActionChoice("Right", KeySpec(.key(.arrowRight), icon: "arrow.right")),
        ActionChoice("Up", KeySpec(.key(.arrowUp), icon: "arrow.up")),
        ActionChoice("Down", KeySpec(.key(.arrowDown), icon: "arrow.down")),
        ActionChoice("Home", KeySpec(.key(.home), label: "Home")),
        ActionChoice("End", KeySpec(.key(.end), label: "End")),
        ActionChoice("Page Up", KeySpec(.key(.pageUp), label: "PgUp")),
        ActionChoice("Page Down", KeySpec(.key(.pageDown), label: "PgDn")),
    ])

    public static let modifiers = ActionGroup(title: "Modifiers", choices: [
        ActionChoice("Shift", KeySpec(.modifier(.shift), icon: "shift")),
        ActionChoice("Caps Lock", KeySpec(.modifier(.capsLock), label: "Caps")),
        ActionChoice("Control", KeySpec(.modifier(.control), label: "^")),
        ActionChoice("Option", KeySpec(.modifier(.option), label: "\u{2325}")),
        ActionChoice("Command", KeySpec(.modifier(.command), label: "\u{2318}")),
        ActionChoice("fn", KeySpec(.modifier(.fn), label: "fn", fontScale: 0.7)),
    ])

    private static func chord(_ name: String, _ keyCode: Int, _ mods: [Modifier],
                              label: String? = nil, icon: String? = nil) -> ActionChoice {
        ActionChoice(name, KeySpec(.shortcut(Shortcut(keyCode: keyCode, modifiers: mods)),
                                   label: label, icon: icon, colored: icon?.hasSuffix("-icon") ?? false))
    }

    /// Common chords; any other is recorded ("Record Shortcut…" in the window).
    public static let shortcuts = ActionGroup(title: "Shortcuts", choices: [
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
    ] + zip(1...12, [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]).map { n, code in
        ActionChoice("F\(n)", KeySpec(.shortcut(Shortcut(keyCode: code, modifiers: [])), label: "F\(n)", fontScale: 0.7))
    })

    public static let media = ActionGroup(title: "Media", choices: [
        ActionChoice("Mute", KeySpec(.media(.mute), icon: "volume-off-icon", colored: true)),
        ActionChoice("Volume Down", KeySpec(.media(.volumeDown), icon: "volume-down-icon", colored: true)),
        ActionChoice("Volume Up", KeySpec(.media(.volumeUp), icon: "volume-up-icon", colored: true)),
        ActionChoice("Brightness Down", KeySpec(.media(.brightnessDown), icon: "sun.min")),
        ActionChoice("Brightness Up", KeySpec(.media(.brightnessUp), icon: "sun.max")),
        ActionChoice("Previous", KeySpec(.media(.previous), icon: "backward.fill")),
        ActionChoice("Play / Pause", KeySpec(.media(.playPause), icon: "playpause.fill")),
        ActionChoice("Next", KeySpec(.media(.next), icon: "forward.fill")),
        ActionChoice("Eject", KeySpec(.media(.eject), icon: "eject.fill")),
    ])

    public static let keyboard = ActionGroup(title: "Keyboard", choices: [
        ActionChoice("Hide Keyboard", KeySpec(.command(.hideKeyboard), icon: "keyboard-glyph")),
        ActionChoice("Screenshot", KeySpec(.command(.screenshot), icon: "camera")),
        ActionChoice("App Switcher", KeySpec(.command(.appSwitcher), icon: "square.grid.2x2")),
        ActionChoice("Mission Control", KeySpec(.command(.missionControl), icon: "rectangle.3.group")),
        ActionChoice("Spotlight", KeySpec(.command(.spotlight), icon: "magnifyingglass")),
        ActionChoice("Launchpad", KeySpec(.command(.launchpad), icon: "square.grid.3x3")),
        ActionChoice("Translate", KeySpec(.command(.translate), icon: "translate-icon", colored: true)),
        ActionChoice("Show Phrases", KeySpec(.command(.phrases), icon: "list.bullet")),
        ActionChoice("Language", KeySpec(.command(.languageSwitch), label: "\u{1F310}")),
        ActionChoice("Next Layout", KeySpec(.command(.nextLayout), icon: "rectangle.2.swap")),
        ActionChoice("Choose Layout", KeySpec(.command(.chooseLayout), icon: "keyboard.badge.ellipsis")),
        ActionChoice("Settings", KeySpec(.command(.openSettings), icon: "gearshape")),
        ActionChoice("Window Width", KeySpec(.command(.resizeWidth), icon: "resize-width-icon")),
        ActionChoice("Window Height", KeySpec(.command(.resizeHeight), icon: "resize-height-icon")),
    ])

    public static let gaps = ActionGroup(title: "Empty", choices: [
        ActionChoice("Empty Space", KeySpec(.spacer)),
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
        "sun.min", "sun.max", "backward.fill", "playpause.fill", "forward.fill", "rectangle.3.group",
        "eject.fill", "square.grid.3x3", "backward", "playpause", "forward",
        "arrowtriangle.left.fill", "arrowtriangle.right.fill", "arrowtriangle.up.fill", "arrowtriangle.down.fill",
        "mic", "mic.fill", "mic.slash", "record.circle", "stop.fill", "stop.circle", "pause.fill",
        "pause.circle", "play.fill", "video", "video.fill", "waveform",
    ]

    // MARK: - Groups of keys

    /// Several keys put in at once (Add Group…): a row, or a column down the
    /// right end of consecutive rows.
    public struct KeyGroup {
        public enum Shape { case row, column }
        public let name: String
        public let shape: Shape
        public let keys: [KeySpec]
    }

    public static let keyGroups: [KeyGroup] = [numberRow, mediaRow, navigationColumn]

    /// ` 1 2 … 0 - = and Backspace, with the shifted symbols in the corners —
    /// Extended's own number row.
    public static let numberRow: KeyGroup = {
        let row = KeyboardLayout.extended.rows.first { $0.contains { $0.action == .character("1") } } ?? []
        let end = row.firstIndex { $0.action == .key(.backspace) } ?? (row.count - 1)
        return KeyGroup(name: "Number Row", shape: .row, keys: Array(row.prefix(end + 1)))
    }()

    /// A Mac keyboard's top row, as far as it can be sent: brightness, Mission
    /// Control, the music keys and the sound keys.
    public static let mediaRow = KeyGroup(name: "Media Row", shape: .row, keys: [
        KeySpec(.media(.brightnessDown), icon: "sun.min"),
        KeySpec(.media(.brightnessUp), icon: "sun.max"),
        KeySpec(.command(.missionControl), icon: "rectangle.3.group"),
        KeySpec(.media(.previous), icon: "backward.fill"),
        KeySpec(.media(.playPause), icon: "playpause.fill"),
        KeySpec(.media(.next), icon: "forward.fill"),
        KeySpec(.media(.mute), icon: "volume-off-icon", colored: true),
        KeySpec(.media(.volumeDown), icon: "volume-down-icon", colored: true),
        KeySpec(.media(.volumeUp), icon: "volume-up-icon", colored: true),
    ])

    /// Home, Page Up, Page Down, End — Extended's column, top to bottom.
    public static let navigationColumn: KeyGroup = {
        let all = KeyboardLayout.extended.rows.flatMap { $0 }
        let keys = [SpecialKey.home, .pageUp, .pageDown, .end].compactMap { k in all.first { $0.action == .key(k) } }
        return KeyGroup(name: "Navigation Column", shape: .column, keys: keys)
    }()
}
