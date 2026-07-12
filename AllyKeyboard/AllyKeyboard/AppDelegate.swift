//
//  AppDelegate.swift
//  AllyKeyboard
//
//  Created by user945037 on 5/24/26.
//

import Cocoa
import AllyKeyboardCore

@main
class AppDelegate: NSObject, NSApplicationDelegate {


    private var statusBar: StatusBarController!
    private var settingsWindow: SettingsWindowController?
    private var launcher: LauncherWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Enforce single instance: if another copy is already running, quit this one.
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Run as a menu-bar accessory: no Dock icon (controls live in the menu bar / launcher).
        NSApp.setActivationPolicy(.accessory)

        // Always dark, so the semantic system colors resolve to their dark variants.
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Request Accessibility permission needed for CGEvent key simulation.
        KeySender.requestAccessibilityIfNeeded()

        // Menu-bar entry: left click toggles the keyboard, right click opens the menu.
        statusBar = StatusBarController(
            onToggleKeyboard: { [weak self] in self?.togglePanel() },
            onOpenSettings: { [weak self] in self?.openSettings() })

        // Floating launcher shown while the keyboard is hidden; click brings it back.
        let s = SettingsStore().load()
        launcher = LauncherWindowController(width: CGFloat(s.launcherWidth),
                                            alpha: CGFloat(s.launcherAlpha)) { [weak self] in
            self?.showKeyboard()
        }

        // Start hidden when launched at login, or when "start collapsed" is enabled.
        if LoginItem.isEnabled || s.startCollapsed {
            DispatchQueue.main.async { [weak self] in self?.hideKeyboard() }
        }
    }

    private func keyboardPanel() -> NSWindow? {
        NSApp.windows.first(where: { $0 is KeyboardPanel })
    }

    /// Show the keyboard and hide the floating launcher.
    func showKeyboard() {
        keyboardPanel()?.orderFront(nil)
        launcher?.hide()
    }

    /// Hide the keyboard and show the floating launcher in its place.
    func hideKeyboard() {
        keyboardPanel()?.orderOut(nil)
        launcher?.show()
    }

    @objc private func togglePanel() {
        if keyboardPanel()?.isVisible == true { hideKeyboard() } else { showKeyboard() }
    }

    /// Apply a new launcher width live (called from Settings).
    func updateLauncherWidth(_ width: Int) { launcher?.setWidth(CGFloat(width)) }

    /// Apply a new launcher opacity live (called from Settings).
    func updateLauncherOpacity(_ percent: Int) { launcher?.setOpacity(CGFloat(percent) / 100.0) }

    /// The context menu shown on right-click (keyboard body / drag bar), matching the menu bar.
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Keyboard", action: #selector(togglePanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AllyKeyboard", action: #selector(quitApp), keyEquivalent: "").target = self
        return menu
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    // Left click on the Dock icon toggles the keyboard (show if hidden, hide if shown).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePanel()
        return true
    }

    // Right click (or click-hold) on the Dock icon shows this menu.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Keyboard", action: #selector(togglePanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: "").target = self
        return menu
    }

    private func keyboardViewController() -> ViewController? {
        NSApp.windows.first(where: { $0 is KeyboardPanel })?.contentViewController as? ViewController
    }

    @objc func openSettings() {
        guard let vc = keyboardViewController() else { return }
        let win = SettingsWindowController(
            currentPercent: vc.currentSizePercent,
            currentShowSuggestions: vc.currentShowSuggestions,
            currentSavedPhrases: vc.currentSavedPhrases,
            currentLauncherWidth: vc.currentLauncherWidth,
            currentLauncherOpacity: vc.currentLauncherOpacity,
            currentTopBarHeight: vc.currentTopBarHeight,
            currentBottomBarShow: vc.currentBottomBarShow,
            currentBottomBarHeight: vc.currentBottomBarHeight,
            currentStartCollapsed: vc.currentStartCollapsed,
            currentTheme: vc.currentTheme,
            onPercentChange: { [weak vc] percent in vc?.applySizePercent(percent) },
            onShowSuggestionsChange: { [weak vc] on in vc?.applyShowSuggestions(on) },
            onSavedPhrasesChange: { [weak vc] phrases in vc?.applySavedPhrases(phrases) },
            onLauncherWidthChange: { [weak vc] width in vc?.applyLauncherWidth(width) },
            onLauncherOpacityChange: { [weak vc] percent in vc?.applyLauncherOpacity(percent) },
            onTopBarHeightChange: { [weak vc] pt in vc?.applyTopBarHeight(pt) },
            onBottomBarShowChange: { [weak vc] on in vc?.applyBottomBarShow(on) },
            onBottomBarHeightChange: { [weak vc] pt in vc?.applyBottomBarHeight(pt) },
            onStartCollapsedChange: { [weak vc] on in vc?.applyStartCollapsed(on) },
            onThemeChange: { [weak vc] raw in vc?.applyTheme(raw) })
        settingsWindow = win
        win.present()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}


/// Menu-bar icon: left click toggles the keyboard, right/ctrl click opens the menu.
final class StatusBarController {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let onToggleKeyboard: () -> Void
    private let onOpenSettings: () -> Void

    init(onToggleKeyboard: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onToggleKeyboard = onToggleKeyboard
        self.onOpenSettings = onOpenSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menu.addItem(withTitle: "Show / Hide Keyboard", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettingsItem), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AllyKeyboard", action: #selector(quit), keyEquivalent: "q").target = self

        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AllyKeyboard")?
                .withSymbolConfiguration(config)
            img?.isTemplate = true
            button.image = img
            // Left click toggles the keyboard; right/ctrl click opens the menu.
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let rightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if rightClick {
            item.menu = menu
            item.button?.performClick(nil)   // pops the menu at the item
            item.menu = nil                  // keep left click as an action, not a menu
        } else {
            onToggleKeyboard()
        }
    }

    @objc private func toggle() { onToggleKeyboard() }
    @objc private func openSettingsItem() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
