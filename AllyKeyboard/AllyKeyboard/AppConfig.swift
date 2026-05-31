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
    static let useCustomTitleBar = false

    // MARK: - Colors

    enum Colors {

        // MARK: Panels

        /// Custom status bar background (top panel with title/buttons)
        static let statusBarBg = NSColor(white: 0.22, alpha: 1)
        /// Drag handle background (bottom grip strip)
        static let dragBarBg   = NSColor(white: 0.22, alpha: 1)
        /// Overall keyboard window background
        static let keyboardBg  = NSColor(white: 0.13, alpha: 1)

        // MARK: Keys

        /// Key — default state
        static let keyNormal   = NSColor(white: 0.22, alpha: 1)
        /// Key — mouse hover
        static let keyHover    = NSColor(white: 0.36, alpha: 1)
        /// Key — pressed flash
        static let keyPressed  = NSColor(red: 0.72, green: 0.13, blue: 0.13, alpha: 1)
        /// Key — active/toggled (e.g. Shift on)
        static let keyActive   = NSColor(red: 0.20, green: 0.45, blue: 0.80, alpha: 1)
    }

    // MARK: - Layout (base values at scale = 1.0)

    enum Layout {
        static let keyWidth:        CGFloat = 46
        static let keyHeight:       CGFloat = 36
        static let keySpacing:      CGFloat = 4
        static let rowSpacing:      CGFloat = 4
        static let padding:         CGFloat = 12
        /// Corner radius of key buttons
        static let keyCornerRadius: CGFloat = 5
        /// Font size for primary key label (e.g. letter, symbol)
        static let fontSizePrimary:   CGFloat = 14
        /// Font size for secondary key label (e.g. shifted symbol, hint) — not yet used
        static let fontSizeSecondary: CGFloat = 9
        /// Default keyboard scale factor
        static let keyboardScale:   CGFloat = 2.0
    }
}
