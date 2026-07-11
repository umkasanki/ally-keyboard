//
//  AppDelegate.swift
//  AllyKeyboard
//
//  Created by user945037 on 5/24/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {


    private var statusBar: StatusBarController!
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Enforce single instance: if another copy is already running, quit this one.
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Request Accessibility permission needed for CGEvent key simulation.
        KeySender.requestAccessibilityIfNeeded()

        // Menu-bar entry: left click toggles the keyboard, right click opens the menu.
        statusBar = StatusBarController(
            onToggleKeyboard: { [weak self] in self?.togglePanel() },
            onOpenSettings: { [weak self] in self?.openSettings() })

        // Launched at login -> start hidden (available via the Dock / menu bar).
        if LoginItem.isEnabled {
            DispatchQueue.main.async {
                NSApp.windows.first(where: { $0 is KeyboardPanel })?.orderOut(nil)
            }
        }
    }

    /// Toggle the keyboard panel's visibility (shared by the Dock icon click/menu).
    @objc private func togglePanel() {
        guard let panel = NSApp.windows.first(where: { $0 is KeyboardPanel }) else { return }
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFront(nil) }
    }

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
            onPercentChange: { [weak vc] percent in vc?.applySizePercent(percent) },
            onShowSuggestionsChange: { [weak vc] on in vc?.applyShowSuggestions(on) },
            onSavedPhrasesChange: { [weak vc] phrases in vc?.applySavedPhrases(phrases) })
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
