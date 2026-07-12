//
//  AppConfig.swift
//  AllyKeyboard
//
//  Global feature flags, colors, and layout defaults.
//  These will be driven by SettingsManager (UserDefaults) in Phase 5.
//

import Cocoa

enum AppConfig {

    // MARK: - Feature flags

    /// Hide the native macOS title bar and use CustomStatusBar instead.
    static let useCustomTitleBar = true

    // MARK: - Colors

    /// Selectable background palette (persisted in Settings, applied at launch / on change).
    enum Theme: String, CaseIterable {
        case darkCustom   // original hand-picked flat grays
        case darkSystem   // macOS dark semantic colors

        /// Overall keyboard window background.
        var bodyBg: NSColor {
            switch self {
            case .darkCustom: return NSColor(white: 0.13, alpha: 1)
            case .darkSystem: return .windowBackgroundColor            // ~0.118
            }
        }
        /// Top / bottom panel background.
        var panelBg: NSColor {
            switch self {
            case .darkCustom: return NSColor(white: 0.22, alpha: 1)
            case .darkSystem: return .underPageBackgroundColor         // ~0.157
            }
        }
        /// Key face (default state).
        var keyBg: NSColor {
            switch self {
            case .darkCustom: return NSColor(white: 0.22, alpha: 1)
            case .darkSystem: return NSColor(white: 0.20, alpha: 1)
            }
        }

        var displayName: String {
            switch self {
            case .darkCustom: return "Dark (custom)"
            case .darkSystem: return "Dark (system)"
            }
        }
    }

    enum Colors {

        /// Active theme — set from Settings before the keyboard is built.
        static var theme: Theme = .darkSystem

        // MARK: Theme-driven backgrounds
        static var statusBarBg: NSColor { theme.panelBg }
        static var dragBarBg:   NSColor { theme.panelBg }
        static var keyboardBg:  NSColor { theme.bodyBg }
        static var keyNormal:   NSColor { theme.keyBg }

        // MARK: Shared across themes
        /// Key — mouse hover
        static let keyHover    = NSColor(white: 0.36, alpha: 1)
        /// Key — pressed flash
        static let keyPressed  = NSColor(red: 0.72, green: 0.13, blue: 0.13, alpha: 1)
        /// Key — active/toggled (e.g. Shift on) — systemRed, matching ally-clicker's active panel
        static let keyActive   = NSColor.systemRed
    }

    // MARK: - Layout (base values at scale = 1.0)

    enum Layout {
        static let keyWidth:        CGFloat = 36
        static let keyHeight:       CGFloat = 32
        static let keySpacing:      CGFloat = 3
        static let rowSpacing:      CGFloat = 3
        static let padding:         CGFloat = 8
        /// Corner radius of key buttons
        static let keyCornerRadius: CGFloat = 5
        /// Font size for primary key label (e.g. letter, symbol)
        static let fontSizePrimary:   CGFloat = 13
        /// Font size for secondary key label (shifted symbol shown top-left)
        static let fontSizeSecondary: CGFloat = 8
        /// Default keyboard scale factor
        static let keyboardScale:   CGFloat = 1.5
    }
}
