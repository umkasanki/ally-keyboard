//
//  KeyboardLayout.swift
//  AllyKeyboardCore
//
//  A keyboard layout as data: rows of keys, each with what it does and how it
//  looks. The built-in default is `KeyboardLayout.standard`; users edit copies
//  of it, or build their own, and share them as files. See
//  docs/layouts-plan.md.
//

import Foundation

/// A whole keyboard: named rows of keys, and their sizes.
public struct KeyboardLayout: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var rows: [[KeySpec]]
    public var geometry: Geometry
    /// Bumped when the file format changes in a way older builds cannot read.
    public var formatVersion: Int

    public static let currentFormatVersion = 1

    public init(id: UUID = UUID(), name: String, rows: [[KeySpec]], geometry: Geometry = Geometry(),
                formatVersion: Int = KeyboardLayout.currentFormatVersion) {
        self.id = id
        self.name = name
        self.rows = rows
        self.geometry = geometry
        self.formatVersion = formatVersion
    }

    private enum CodingKeys: String, CodingKey { case id, name, rows, geometry, formatVersion }

    // Files written before layouts had sizes take today's.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        rows = try c.decode([[KeySpec]].self, forKey: .rows)
        geometry = try c.decodeIfPresent(Geometry.self, forKey: .geometry) ?? Geometry()
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? KeyboardLayout.currentFormatVersion
    }

    /// The sizes a layout is drawn at, in points at 100% keyboard size (the
    /// size setting scales them all). The defaults are what the keyboard has
    /// always used.
    public struct Geometry: Codable, Equatable {
        /// A standard key — a letter. Wider keys are multiples of it.
        public var keyWidth: Double = 36
        public var keyHeight: Double = 32
        /// Between keys in a row.
        public var keySpacing: Double = 3
        /// Between rows.
        public var rowSpacing: Double = 3
        /// Around the keys, inside the keyboard's edge.
        public var padding: Double = 8

        public static let keySizeRange: ClosedRange<Double> = 20...96
        public static let spacingRange: ClosedRange<Double> = 0...24
        public static let paddingRange: ClosedRange<Double> = 0...40

        public init() {}

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Geometry()
            keyWidth = try c.decodeIfPresent(Double.self, forKey: .keyWidth) ?? d.keyWidth
            keyHeight = try c.decodeIfPresent(Double.self, forKey: .keyHeight) ?? d.keyHeight
            keySpacing = try c.decodeIfPresent(Double.self, forKey: .keySpacing) ?? d.keySpacing
            rowSpacing = try c.decodeIfPresent(Double.self, forKey: .rowSpacing) ?? d.rowSpacing
            padding = try c.decodeIfPresent(Double.self, forKey: .padding) ?? d.padding
        }
    }
}

/// One key: what it does, its label or icon, and its size.
public struct KeySpec: Codable, Equatable {
    public var action: KeyAction
    /// The face's text; nil shows the action's own name (`action.legacyID`).
    public var label: String?
    /// The small symbol in the corner — the shifted character, for example.
    public var secondary: String?
    /// An SF Symbol or a bundled image; shown instead of the label.
    public var icon: String?
    /// 1 is a standard key; 1.5 is one and a half keys, gap included.
    public var width: Double
    /// The label's size against the standard one.
    public var fontScale: Double
    /// The icon keeps its own colours instead of taking the text colour.
    public var colored: Bool

    public init(_ action: KeyAction, label: String? = nil, secondary: String? = nil,
                icon: String? = nil, width: Double = 1, fontScale: Double = 1, colored: Bool = false) {
        self.action = action
        self.label = label
        self.secondary = secondary
        self.icon = icon
        self.width = width
        self.fontScale = fontScale
        self.colored = colored
    }

    /// The text on the key when it has no icon.
    public var title: String { label ?? action.legacyID }

    // Readable files: defaults are left out, and missing keys take them.
    private enum CodingKeys: String, CodingKey {
        case action, label, secondary, icon, width, fontScale, colored
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        action = try c.decode(KeyAction.self, forKey: .action)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        secondary = try c.decodeIfPresent(String.self, forKey: .secondary)
        icon = try c.decodeIfPresent(String.self, forKey: .icon)
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 1
        fontScale = try c.decodeIfPresent(Double.self, forKey: .fontScale) ?? 1
        colored = try c.decodeIfPresent(Bool.self, forKey: .colored) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(action, forKey: .action)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(secondary, forKey: .secondary)
        try c.encodeIfPresent(icon, forKey: .icon)
        if width != 1 { try c.encode(width, forKey: .width) }
        if fontScale != 1 { try c.encode(fontScale, forKey: .fontScale) }
        if colored { try c.encode(colored, forKey: .colored) }
    }
}

// MARK: - Actions

/// What a key does.
public enum KeyAction: Hashable {
    /// A key of the active input layout, by its US name ("Q", "1", "["): it
    /// types whatever that layout puts there and is relabelled to match.
    case character(String)
    /// Types this text as it is, whatever the input layout.
    case literal(String)
    /// An editing or navigation key.
    case key(SpecialKey)
    /// A one-shot modifier for the next key, or Caps Lock.
    case modifier(Modifier)
    /// A key chord, such as ⌘C.
    case shortcut(Shortcut)
    /// A media key.
    case media(MediaKey)
    /// Something the keyboard itself does.
    case command(Command)
    /// A key that does nothing — a placeholder.
    case blank
    /// No key at all: an empty gap that keeps rows aligned.
    case spacer

    /// The identifier the app has always used for this key. The app's
    /// behaviour reads it — the smart space, the word tracker, the shortcut
    /// rule, Shift and ⌘ lighting up together — so it must not change for the
    /// keys that already exist.
    public var legacyID: String {
        switch self {
        case .character(let s), .literal(let s): return s
        case .key(let k):        return k.rawValue
        case .modifier(let m):   return m.rawValue
        case .shortcut(let s):   return s.legacyID
        case .media(let m):      return m.rawValue
        case .command(let c):    return c.rawValue
        case .blank:             return "Blank"
        case .spacer:            return "__spacer__"
        }
    }
}

public enum SpecialKey: String, Codable, CaseIterable, Hashable {
    case space = "Space", backspace = "Backspace", delete = "Delete",
         returnKey = "Return", tab = "Tab", escape = "Escape",
         arrowUp = "ArrowUp", arrowDown = "ArrowDown",
         arrowLeft = "ArrowLeft", arrowRight = "ArrowRight",
         home = "Home", end = "End", pageUp = "PageUp", pageDown = "PageDown"
}

public enum Modifier: String, Codable, CaseIterable {
    case shift = "Shift", capsLock = "CapsLock",
         control = "Ctrl", option = "Alt", command = "Cmd"
}

public enum MediaKey: String, Codable, CaseIterable {
    case mute = "Mute", volumeDown = "VolumeDown", volumeUp = "VolumeUp"
}

public enum Command: String, Codable, CaseIterable {
    case phrases = "Hi", appSwitcher = "AppSwitcher", screenshot = "Screenshot",
         translate = "Translate", hideKeyboard = "HideKeyboard",
         languageSwitch = "LangSwitch",
         resizeWidth = "ResizeWidth", resizeHeight = "ResizeHeight",
         nextLayout = "NextLayout", chooseLayout = "ChooseLayout",
         openSettings = "OpenSettings"
}

/// A chord: a virtual key code with modifiers held.
public struct Shortcut: Codable, Hashable {
    public var keyCode: Int
    public var modifiers: [Modifier]

    public init(keyCode: Int, modifiers: [Modifier]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// The chords the keyboard has keys for, by the names the app gives them.
    public static let named: [String: Shortcut] = [
        "Cmd+C": Shortcut(keyCode: 8, modifiers: [.command]),
        "Cmd+V": Shortcut(keyCode: 9, modifiers: [.command]),
        "Cmd+Z": Shortcut(keyCode: 6, modifiers: [.command]),
        "Cmd+A": Shortcut(keyCode: 0, modifiers: [.command]),
        "Cmd+X": Shortcut(keyCode: 7, modifiers: [.command]),
    ]

    public static func named(_ name: String) -> Shortcut? { named[name] }

    /// A named chord's name; any other is spelled out.
    public var legacyID: String {
        if let name = Self.named.first(where: { $0.value == self })?.key { return name }
        return "Shortcut(\(keyCode)," + modifiers.map(\.rawValue).joined(separator: "+") + ")"
    }
}

// Files are written by people as well as by the app, so actions are spelled
// out: {"type": "character", "value": "Q"}, {"type": "shortcut", "keyCode": 8,
// "modifiers": ["Cmd"]}, {"type": "spacer"}.
extension KeyAction: Codable {
    private enum CodingKeys: String, CodingKey { case type, value, keyCode, modifiers }

    private enum Kind: String, Codable {
        case character, literal, key, modifier, shortcut, media, command, blank, spacer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .character: self = .character(try c.decode(String.self, forKey: .value))
        case .literal:   self = .literal(try c.decode(String.self, forKey: .value))
        case .key:       self = .key(try c.decode(SpecialKey.self, forKey: .value))
        case .modifier:  self = .modifier(try c.decode(Modifier.self, forKey: .value))
        case .media:     self = .media(try c.decode(MediaKey.self, forKey: .value))
        case .command:   self = .command(try c.decode(Command.self, forKey: .value))
        case .shortcut:
            self = .shortcut(Shortcut(keyCode: try c.decode(Int.self, forKey: .keyCode),
                                      modifiers: try c.decode([Modifier].self, forKey: .modifiers)))
        case .blank:     self = .blank
        case .spacer:    self = .spacer
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .character(let s): try c.encode(Kind.character, forKey: .type); try c.encode(s, forKey: .value)
        case .literal(let s):   try c.encode(Kind.literal, forKey: .type);   try c.encode(s, forKey: .value)
        case .key(let k):       try c.encode(Kind.key, forKey: .type);       try c.encode(k, forKey: .value)
        case .modifier(let m):  try c.encode(Kind.modifier, forKey: .type);  try c.encode(m, forKey: .value)
        case .media(let m):     try c.encode(Kind.media, forKey: .type);     try c.encode(m, forKey: .value)
        case .command(let x):   try c.encode(Kind.command, forKey: .type);   try c.encode(x, forKey: .value)
        case .shortcut(let s):
            try c.encode(Kind.shortcut, forKey: .type)
            try c.encode(s.keyCode, forKey: .keyCode)
            try c.encode(s.modifiers, forKey: .modifiers)
        case .blank:  try c.encode(Kind.blank, forKey: .type)
        case .spacer: try c.encode(Kind.spacer, forKey: .type)
        }
    }
}
