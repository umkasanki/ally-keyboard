//
//  AppConfig.swift
//  AllyKeyboard
//
//  Global feature flags and defaults.
//  These will be driven by SettingsManager (UserDefaults) in Phase 5.
//

import CoreGraphics

enum AppConfig {

    // MARK: - Title bar

    /// Use a custom DragHandle instead of the native macOS title bar.
    /// When true: borderless window, no traffic-light buttons, DragHandle provides drag.
    /// When false: native title bar with close button, zoom button disabled.
    static let useCustomTitleBar = true

    // MARK: - Layout

    /// Global keyboard scale factor (1.0 = base size).
    static let defaultScale: CGFloat = 2.0
}
