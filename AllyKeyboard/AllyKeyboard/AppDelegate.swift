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
        statusBar = StatusBarController(onToggleKeyboard: {
            guard let panel = NSApp.windows.first(where: { $0 is KeyboardPanel }) else { return }
            if panel.isVisible { panel.orderOut(nil) } else { panel.orderFront(nil) }
        })
    }

    // Clicking the Dock icon re-shows the keyboard after it was hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let panel = NSApp.windows.first(where: { $0 is KeyboardPanel }) {
            panel.orderFront(nil)
        }
        return true
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

    init(onToggleKeyboard: @escaping () -> Void) {
        self.onToggleKeyboard = onToggleKeyboard
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menu.addItem(withTitle: "Show / Hide Keyboard", action: #selector(toggle), keyEquivalent: "").target = self
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
    @objc private func quit() { NSApp.terminate(nil) }
}
