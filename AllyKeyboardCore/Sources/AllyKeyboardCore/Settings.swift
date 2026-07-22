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
    /// Allowed drag cooldown, in milliseconds.
    public static let dragCooldownRange = 0...1500
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

    /// Move the whole keyboard by pressing-and-dragging a key (a plain click still types).
    public var dragToMove: Bool

    /// After a key-drag moves the window, key presses are ignored for this many ms
    /// (absorbs the synthetic click a head tracker emits at the end of a drag-select).
    public var dragCooldownMs: Int {
        didSet { dragCooldownMs = Settings.clampDragCooldown(dragCooldownMs) }
    }

    /// Launch with the keyboard collapsed (hidden; only the floating launcher shown).
    public var startCollapsed: Bool

    /// Background theme identifier (e.g. "darkCustom" / "darkSystem"); interpreted by the app.
    public var theme: String

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

    /// Whether the top bar (minimize strip) is shown at all.
    public var topBarShow: Bool

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
                topBarShow: Bool = true,
                topBarHeight: Int = 28,
                bottomBarShow: Bool = true,
                bottomBarHeight: Int = 28,
                dragToMove: Bool = true,
                dragCooldownMs: Int = 400,
                startCollapsed: Bool = false,
                theme: String = "darkSystem") {
        self.sizePercent = Settings.clampPercent(sizePercent)   // didSet does not run in init
        self.showSuggestions = showSuggestions
        self.startCollapsed = startCollapsed
        self.theme = theme
        self.savedPhrases = savedPhrases
        self.launcherWidth = Settings.clampLauncherWidth(launcherWidth)
        self.launcherOpacityPercent = Settings.clampLauncherOpacity(launcherOpacityPercent)
        self.topBarShow = topBarShow
        self.topBarHeight = Settings.clampTopBarHeight(topBarHeight)
        self.bottomBarShow = bottomBarShow
        self.bottomBarHeight = Settings.clampBottomBarHeight(bottomBarHeight)
        self.dragToMove = dragToMove
        self.dragCooldownMs = Settings.clampDragCooldown(dragCooldownMs)
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

    public static func clampDragCooldown(_ ms: Int) -> Int {
        min(dragCooldownRange.upperBound, max(dragCooldownRange.lowerBound, ms))
    }

    // Decode leniently so older saved settings (missing new keys) still load.
    private enum CodingKeys: String, CodingKey {
        case sizePercent, showSuggestions, savedPhrases, launcherWidth, launcherOpacityPercent,
             topBarShow, topBarHeight, bottomBarShow, bottomBarHeight,
             dragToMove, dragCooldownMs, startCollapsed, theme
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.sizePercent = Settings.clampPercent(try c.decodeIfPresent(Int.self, forKey: .sizePercent) ?? 100)
        self.showSuggestions = try c.decodeIfPresent(Bool.self, forKey: .showSuggestions) ?? true
        self.savedPhrases = try c.decodeIfPresent([String].self, forKey: .savedPhrases) ?? Settings.defaultGreetings
        self.launcherWidth = Settings.clampLauncherWidth(try c.decodeIfPresent(Int.self, forKey: .launcherWidth) ?? 50)
        self.launcherOpacityPercent = Settings.clampLauncherOpacity(try c.decodeIfPresent(Int.self, forKey: .launcherOpacityPercent) ?? 100)
        self.topBarShow = try c.decodeIfPresent(Bool.self, forKey: .topBarShow) ?? true
        self.topBarHeight = Settings.clampTopBarHeight(try c.decodeIfPresent(Int.self, forKey: .topBarHeight) ?? 28)
        self.bottomBarShow = try c.decodeIfPresent(Bool.self, forKey: .bottomBarShow) ?? true
        self.bottomBarHeight = Settings.clampBottomBarHeight(try c.decodeIfPresent(Int.self, forKey: .bottomBarHeight) ?? 28)
        self.dragToMove = try c.decodeIfPresent(Bool.self, forKey: .dragToMove) ?? true
        self.dragCooldownMs = Settings.clampDragCooldown(try c.decodeIfPresent(Int.self, forKey: .dragCooldownMs) ?? 400)
        self.startCollapsed = try c.decodeIfPresent(Bool.self, forKey: .startCollapsed) ?? false
        self.theme = try c.decodeIfPresent(String.self, forKey: .theme) ?? "darkSystem"
    }
}
