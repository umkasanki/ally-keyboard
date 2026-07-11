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
    /// Allowed floating-launcher width, in points.
    public static let launcherWidthRange = 30...200
    /// Allowed floating-launcher opacity, in percent.
    public static let launcherOpacityRange = 20...100
    /// Allowed top-bar height, in points.
    public static let topBarHeightRange = 20...40
    /// Allowed bottom-bar (drag handle) height, in points.
    public static let bottomBarHeightRange = 20...40
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

    /// Floating-launcher width (and height — it's square), in points.
    public var launcherWidth: Int {
        didSet { launcherWidth = Settings.clampLauncherWidth(launcherWidth) }
    }

    /// Floating-launcher opacity, in percent.
    public var launcherOpacityPercent: Int {
        didSet { launcherOpacityPercent = Settings.clampLauncherOpacity(launcherOpacityPercent) }
    }

    /// Top-bar (minimize strip) height, in points.
    public var topBarHeight: Int {
        didSet { topBarHeight = Settings.clampTopBarHeight(topBarHeight) }
    }

    /// Whether the bottom drag bar is shown at all.
    public var bottomBarShow: Bool

    /// Bottom-bar (drag handle) height, in points.
    public var bottomBarHeight: Int {
        didSet { bottomBarHeight = Settings.clampBottomBarHeight(bottomBarHeight) }
    }

    /// Concrete scale factor applied to the base layout metrics.
    public var scale: Double { Settings.baseScale * Double(sizePercent) / 100.0 }

    /// Launcher opacity as a 0...1 alpha value.
    public var launcherAlpha: Double { Double(launcherOpacityPercent) / 100.0 }

    public init(sizePercent: Int = 100,
                showSuggestions: Bool = true,
                savedPhrases: [String] = Settings.defaultGreetings,
                launcherWidth: Int = 50,
                launcherOpacityPercent: Int = 100,
                topBarHeight: Int = 28,
                bottomBarShow: Bool = true,
                bottomBarHeight: Int = 28) {
        self.sizePercent = Settings.clampPercent(sizePercent)   // didSet does not run in init
        self.showSuggestions = showSuggestions
        self.savedPhrases = savedPhrases
        self.launcherWidth = Settings.clampLauncherWidth(launcherWidth)
        self.launcherOpacityPercent = Settings.clampLauncherOpacity(launcherOpacityPercent)
        self.topBarHeight = Settings.clampTopBarHeight(topBarHeight)
        self.bottomBarShow = bottomBarShow
        self.bottomBarHeight = Settings.clampBottomBarHeight(bottomBarHeight)
    }

    public static func clampPercent(_ percent: Int) -> Int {
        min(percentRange.upperBound, max(percentRange.lowerBound, percent))
    }

    public static func clampLauncherWidth(_ width: Int) -> Int {
        min(launcherWidthRange.upperBound, max(launcherWidthRange.lowerBound, width))
    }

    public static func clampLauncherOpacity(_ percent: Int) -> Int {
        min(launcherOpacityRange.upperBound, max(launcherOpacityRange.lowerBound, percent))
    }

    public static func clampTopBarHeight(_ pt: Int) -> Int {
        min(topBarHeightRange.upperBound, max(topBarHeightRange.lowerBound, pt))
    }

    public static func clampBottomBarHeight(_ pt: Int) -> Int {
        min(bottomBarHeightRange.upperBound, max(bottomBarHeightRange.lowerBound, pt))
    }

    // Decode leniently so older saved settings (missing new keys) still load.
    private enum CodingKeys: String, CodingKey {
        case sizePercent, showSuggestions, savedPhrases, launcherWidth, launcherOpacityPercent,
             topBarHeight, bottomBarShow, bottomBarHeight
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sizePercent = Settings.clampPercent(try c.decodeIfPresent(Int.self, forKey: .sizePercent) ?? 100)
        self.showSuggestions = try c.decodeIfPresent(Bool.self, forKey: .showSuggestions) ?? true
        self.savedPhrases = try c.decodeIfPresent([String].self, forKey: .savedPhrases) ?? Settings.defaultGreetings
        self.launcherWidth = Settings.clampLauncherWidth(try c.decodeIfPresent(Int.self, forKey: .launcherWidth) ?? 50)
        self.launcherOpacityPercent = Settings.clampLauncherOpacity(try c.decodeIfPresent(Int.self, forKey: .launcherOpacityPercent) ?? 100)
        self.topBarHeight = Settings.clampTopBarHeight(try c.decodeIfPresent(Int.self, forKey: .topBarHeight) ?? 28)
        self.bottomBarShow = try c.decodeIfPresent(Bool.self, forKey: .bottomBarShow) ?? true
        self.bottomBarHeight = Settings.clampBottomBarHeight(try c.decodeIfPresent(Int.self, forKey: .bottomBarHeight) ?? 28)
    }
}
