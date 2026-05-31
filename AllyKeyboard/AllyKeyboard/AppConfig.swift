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
        static let keyboardScale:   CGFloat = 2.0
    }
}
