//
//  AppConfig.swift
//  AllyKeyboard
//
//  Global feature flags, colors, and layout defaults.
//  These will be driven by SettingsManager (UserDefaults) in Phase 5.
//

import Cocoa

enum AppConfig {

    // MARK: - Window levels

    /// How high the keyboard floats, kept here so the four windows that make up
    /// this application cannot drift apart from each other.
    ///
    /// **Above everything**, which is what an on-screen keyboard has to be: if a
    /// panel or a dialog can cover it, then whatever that panel asks for cannot
    /// be typed. macOS's own Accessibility Keyboard behaves the same way.
    ///
    /// A menu-bar extra's panel — the BetterDisplay menu, for one — once covered
    /// the keys, and this file used to blame `.statusBar` for it. That was wrong.
    /// The window was measured at **3** on 2026-10-04 and had never been at 25 at
    /// all, because `isFloatingPanel` was resetting it; a menu at 101 covered the
    /// keys for that reason, not because 25 was too low. Whatever stands here only
    /// matters if it is the *last* thing applied to the window — see
    /// `viewWillAppear`.
    ///
    /// The price is real and worth knowing: at this level the keyboard covers
    /// notification banners and system alerts, and, unlike `.screenSaver` (1000),
    /// it also sits above the screen saver itself (the keyboard joins all spaces
    /// and is stationary, so it stays drawn there). For a user whose only way to
    /// answer an alert is this keyboard, that is the right side of the trade.
    enum Levels {
        /// The level macOS reserves for assistive technology, which is exactly
        /// what this keyboard is — Apple's own on-screen keyboard sits here.
        /// `.screenSaver` would also clear every ordinary window, but this one
        /// says what the window is *for*, and the system can tell the difference.
        static let keyboard =
            NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        /// One above the keyboard, so the settings window is reachable while the
        /// keyboard is up. It used to be `.modalPanel` (8), and the note here used
        /// to say that put it below the keyboard's 25. Both numbers were wrong:
        /// the keyboard was really at 3, so `.modalPanel` was already above it.
        /// Measured at 1501 against the keyboard's 1500 on 2026-10-04.
        static let settings =
            NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)) + 1)
    }

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
        /// Font size for primary key label (e.g. letter, symbol).
        ///
        /// **Measured against the Windows keyboard the user came from**, on the
        /// same physical monitor, both screenshots normalised to its pixels:
        /// there a letter stands 28% of the key's height, here it stood 24%.
        /// The keys had grown and the type had not, which reads as a keyboard
        /// with small letters however large the keys are. 13 → 15 closes it.
        static let fontSizePrimary:   CGFloat = 15
        /// Font size for secondary key label (shifted symbol shown top-left)
        static let fontSizeSecondary: CGFloat = 9.6   // was 8; +20% so the shifted symbols can be read
        /// Default keyboard scale factor
        static let keyboardScale:   CGFloat = 1.5
    }
}
