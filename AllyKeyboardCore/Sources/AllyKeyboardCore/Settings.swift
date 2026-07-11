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

    /// Keyboard size as a percentage; 100% == `baseScale`.
    public var sizePercent: Int {
        didSet { sizePercent = Settings.clampPercent(sizePercent) }
    }

    /// Concrete scale factor applied to the base layout metrics.
    public var scale: Double { Settings.baseScale * Double(sizePercent) / 100.0 }

    public init(sizePercent: Int = 100) {
        self.sizePercent = Settings.clampPercent(sizePercent)   // didSet does not run in init
    }

    public static func clampPercent(_ percent: Int) -> Int {
        min(percentRange.upperBound, max(percentRange.lowerBound, percent))
    }
}
