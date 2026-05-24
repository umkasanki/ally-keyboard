//
//  KeyboardWindowController.swift
//  AllyKeyboard
//

import Cocoa

class KeyboardWindowController: NSWindowController {

    private enum Keys {
        static let windowOrigin = "com.umkasanki.AllyKeyboard.windowOrigin"
    }

    convenience init() {
        // NSPanel with .nonactivatingPanel — proper AppKit way for
        // floating tools that must not steal focus from the active app
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 180),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.title = "AllyKeyboard"
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true

        self.init(window: panel)

        panel.delegate = self

        if let savedOrigin = UserDefaults.standard.string(forKey: Keys.windowOrigin) {
            panel.setFrameOrigin(NSPointFromString(savedOrigin))
        } else {
            panel.center()
        }

        panel.contentViewController = KeyboardViewController()
    }
}

// MARK: - NSWindowDelegate

extension KeyboardWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let origin = window?.frame.origin else { return }
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: Keys.windowOrigin)
    }
}
