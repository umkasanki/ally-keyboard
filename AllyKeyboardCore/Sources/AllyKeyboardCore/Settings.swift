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
    /// Allowed icon side for the running-applications panel, in points.
    /// It is aimed at with a head tracker, so the range starts where the Dock
    /// ends rather than where it begins.
    public static let appPanelIconRange = 40...140
    /// Allowed background opacity of that panel, in percent.
    public static let appPanelOpacityRange = 20...100
    /// Allowed auto-hide delay, in seconds. Zero means it stays until dismissed.
    public static let appPanelAutoHideRange = 0...60
    /// Allowed outline thickness, in points. Zero draws no outline at all.
    public static let appPanelOutlineWidthRange = 0...12
    /// Allowed distance between the icon and its outline, in points.
    public static let appPanelOutlineGapRange = 0...24
    /// Allowed space between two icons, in points.
    public static let appPanelIconSpacingRange = 0...60
    /// Allowed space between the icons and the panel's edge, in points.
    public static let appPanelEdgeSpacingRange = 0...60
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

    /// Icon side for the running-applications panel, in points.
    public var appPanelIconSize: Int {
        didSet { appPanelIconSize = Settings.clampAppPanelIcon(appPanelIconSize) }
    }

    /// Background opacity of that panel, in percent.
    public var appPanelOpacityPercent: Int {
        didSet { appPanelOpacityPercent = Settings.clampAppPanelOpacity(appPanelOpacityPercent) }
    }

    /// Applications to leave out of that panel, by name, one per line in the
    /// settings window. Matched case-insensitively against the name macOS shows.
    public var appPanelHiddenApps: [String]

    /// Seconds before the panel closes on its own. Zero keeps it until it is
    /// dismissed — which is the honest default, because a panel that vanishes
    /// while somebody is still aiming at it is worse than one that lingers.
    public var appPanelAutoHideSeconds: Int {
        didSet { appPanelAutoHideSeconds = Settings.clampAppPanelAutoHide(appPanelAutoHideSeconds) }
    }

    /// Space between two icons.
    public var appPanelIconSpacing: Int {
        didSet { appPanelIconSpacing = Settings.clampAppPanelIconSpacing(appPanelIconSpacing) }
    }

    /// Space between the icons and the panel's edge.
    public var appPanelEdgeSpacing: Int {
        didSet { appPanelEdgeSpacing = Settings.clampAppPanelEdgeSpacing(appPanelEdgeSpacing) }
    }

    /// Whether an icon grows a little while the pointer is on it. Not
    /// decoration: with a head tracker it confirms which icon is under the
    /// cursor before the click, which is the moment a mistake still costs
    /// nothing.
    public var appPanelHoverZoom: Bool

    /// Thickness of the outline drawn around the icon under the pointer.
    public var appPanelOutlineWidth: Int {
        didSet { appPanelOutlineWidth = Settings.clampAppPanelOutlineWidth(appPanelOutlineWidth) }
    }

    /// How far that outline stands off the icon.
    public var appPanelOutlineGap: Int {
        didSet { appPanelOutlineGap = Settings.clampAppPanelOutlineGap(appPanelOutlineGap) }
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
                theme: String = "darkSystem",
                appPanelIconSize: Int = 64,
                appPanelOpacityPercent: Int = 92,
                appPanelHiddenApps: [String] = [],
                appPanelAutoHideSeconds: Int = 0,
                appPanelHoverZoom: Bool = true,
                appPanelOutlineWidth: Int = 3,
                appPanelOutlineGap: Int = 4,
                appPanelIconSpacing: Int = 14,
                appPanelEdgeSpacing: Int = 10) {
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
        self.appPanelIconSize = Settings.clampAppPanelIcon(appPanelIconSize)
        self.appPanelOpacityPercent = Settings.clampAppPanelOpacity(appPanelOpacityPercent)
        self.appPanelHiddenApps = appPanelHiddenApps
        self.appPanelAutoHideSeconds = Settings.clampAppPanelAutoHide(appPanelAutoHideSeconds)
        self.appPanelHoverZoom = appPanelHoverZoom
        self.appPanelOutlineWidth = Settings.clampAppPanelOutlineWidth(appPanelOutlineWidth)
        self.appPanelOutlineGap = Settings.clampAppPanelOutlineGap(appPanelOutlineGap)
        self.appPanelIconSpacing = Settings.clampAppPanelIconSpacing(appPanelIconSpacing)
        self.appPanelEdgeSpacing = Settings.clampAppPanelEdgeSpacing(appPanelEdgeSpacing)
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

    public static func clampAppPanelIcon(_ pt: Int) -> Int {
        min(max(pt, appPanelIconRange.lowerBound), appPanelIconRange.upperBound)
    }

    public static func clampAppPanelOpacity(_ percent: Int) -> Int {
        min(max(percent, appPanelOpacityRange.lowerBound), appPanelOpacityRange.upperBound)
    }

    public static func clampAppPanelOutlineWidth(_ pt: Int) -> Int {
        min(max(pt, appPanelOutlineWidthRange.lowerBound), appPanelOutlineWidthRange.upperBound)
    }

    public static func clampAppPanelOutlineGap(_ pt: Int) -> Int {
        min(max(pt, appPanelOutlineGapRange.lowerBound), appPanelOutlineGapRange.upperBound)
    }

    public static func clampAppPanelIconSpacing(_ pt: Int) -> Int {
        min(max(pt, appPanelIconSpacingRange.lowerBound), appPanelIconSpacingRange.upperBound)
    }

    public static func clampAppPanelEdgeSpacing(_ pt: Int) -> Int {
        min(max(pt, appPanelEdgeSpacingRange.lowerBound), appPanelEdgeSpacingRange.upperBound)
    }

    public static func clampAppPanelAutoHide(_ seconds: Int) -> Int {
        min(max(seconds, appPanelAutoHideRange.lowerBound), appPanelAutoHideRange.upperBound)
    }

    public static func clampDragCooldown(_ ms: Int) -> Int {
        min(dragCooldownRange.upperBound, max(dragCooldownRange.lowerBound, ms))
    }

    // Decode leniently so older saved settings (missing new keys) still load.
    private enum CodingKeys: String, CodingKey {
        case sizePercent, showSuggestions, savedPhrases, launcherWidth, launcherOpacityPercent,
             topBarShow, topBarHeight, bottomBarShow, bottomBarHeight,
             dragToMove, dragCooldownMs, startCollapsed, theme,
             appPanelIconSize, appPanelOpacityPercent, appPanelHiddenApps, appPanelAutoHideSeconds,
             appPanelHoverZoom, appPanelOutlineWidth, appPanelOutlineGap,
             appPanelIconSpacing, appPanelEdgeSpacing
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
        self.appPanelIconSize = Settings.clampAppPanelIcon(
            try c.decodeIfPresent(Int.self, forKey: .appPanelIconSize) ?? 64)
        self.appPanelOpacityPercent = Settings.clampAppPanelOpacity(
            try c.decodeIfPresent(Int.self, forKey: .appPanelOpacityPercent) ?? 92)
        self.appPanelHiddenApps = try c.decodeIfPresent([String].self, forKey: .appPanelHiddenApps) ?? []
        self.appPanelAutoHideSeconds = Settings.clampAppPanelAutoHide(
            try c.decodeIfPresent(Int.self, forKey: .appPanelAutoHideSeconds) ?? 0)
        self.appPanelHoverZoom = try c.decodeIfPresent(Bool.self, forKey: .appPanelHoverZoom) ?? true
        self.appPanelOutlineWidth = Settings.clampAppPanelOutlineWidth(
            try c.decodeIfPresent(Int.self, forKey: .appPanelOutlineWidth) ?? 3)
        self.appPanelOutlineGap = Settings.clampAppPanelOutlineGap(
            try c.decodeIfPresent(Int.self, forKey: .appPanelOutlineGap) ?? 4)
        self.appPanelIconSpacing = Settings.clampAppPanelIconSpacing(
            try c.decodeIfPresent(Int.self, forKey: .appPanelIconSpacing) ?? 14)
        self.appPanelEdgeSpacing = Settings.clampAppPanelEdgeSpacing(
            try c.decodeIfPresent(Int.self, forKey: .appPanelEdgeSpacing) ?? 10)
    }
}
