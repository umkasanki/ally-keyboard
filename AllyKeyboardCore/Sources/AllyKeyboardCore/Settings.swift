//
//  Settings.swift
//  AllyKeyboardCore
//
//  User-configurable settings — platform-independent (no AppKit), so it builds
//  and is unit-tested on Linux. The macOS app applies these to the window.
//

public struct Settings: Codable, Equatable {

    public enum SizePreset: String, Codable, CaseIterable {
        case small, medium, large

        /// Keyboard scale factor applied to the base layout metrics.
        public var scale: Double {
            switch self {
            case .small:  return 1.2
            case .medium: return 1.5
            case .large:  return 1.9
            }
        }
    }

    public var sizePreset: SizePreset

    public init(sizePreset: SizePreset = .medium) {
        self.sizePreset = sizePreset
    }
}
