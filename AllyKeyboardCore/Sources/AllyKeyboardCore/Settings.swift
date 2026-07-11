//
//  Settings.swift
//  AllyKeyboardCore
//
//  User-configurable settings — platform-independent (no AppKit), so it builds
//  and is unit-tested on Linux. The macOS app applies these to the window.
//

public struct Settings: Codable, Equatable {

    /// Base keyboard scale that corresponds to 100% ("small").
    public static let baseScale = 1.2
    /// Allowed size range, in percent.
    public static let percentRange = 50...250
    /// Default saved phrases shown by the list ("Hi") key.
    public static let defaultGreetings = [
        "Hello!",
        "Hi there!",
        "Good morning!",
        "Good afternoon!",
        "How are you?",
    ]

    /// Keyboard size as a percentage; 100% == `baseScale`.
    public var sizePercent: Int {
        didSet { sizePercent = Settings.clampPercent(sizePercent) }
    }

    /// Whether the word-prediction panel appears while typing.
    public var showSuggestions: Bool

    /// User-defined phrases opened by the list key, inserted on tap.
    public var savedPhrases: [String]

    /// Concrete scale factor applied to the base layout metrics.
    public var scale: Double { Settings.baseScale * Double(sizePercent) / 100.0 }

    public init(sizePercent: Int = 100,
                showSuggestions: Bool = true,
                savedPhrases: [String] = Settings.defaultGreetings) {
        self.sizePercent = Settings.clampPercent(sizePercent)   // didSet does not run in init
        self.showSuggestions = showSuggestions
        self.savedPhrases = savedPhrases
    }

    public static func clampPercent(_ percent: Int) -> Int {
        min(percentRange.upperBound, max(percentRange.lowerBound, percent))
    }

    // Decode leniently so older saved settings (missing new keys) still load.
    private enum CodingKeys: String, CodingKey { case sizePercent, showSuggestions, savedPhrases }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sizePercent = Settings.clampPercent(try c.decodeIfPresent(Int.self, forKey: .sizePercent) ?? 100)
        self.showSuggestions = try c.decodeIfPresent(Bool.self, forKey: .showSuggestions) ?? true
        self.savedPhrases = try c.decodeIfPresent([String].self, forKey: .savedPhrases) ?? Settings.defaultGreetings
    }
}
