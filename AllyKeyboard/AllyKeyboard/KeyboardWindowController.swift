//
//  KeyboardWindowController.swift
//  AllyKeyboard
//

import Cocoa

class KeyboardWindowController: NSWindowController {

    private enum Keys {
        static let windowOrigin = "windowOrigin"
    }

    convenience init() {
        let window = DraggableWindow(
            contentRect: NSRect(x: 100, y: 100, width: 520, height: 180),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AllyKeyboard"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isReleasedWhenClosed = false

        self.init(window: window)

        // Must set delegate after self.init
        window.delegate = self

        // Restore saved position or center
        if let savedOrigin = UserDefaults.standard.string(forKey: Keys.windowOrigin) {
            window.setFrameOrigin(NSPointFromString(savedOrigin))
        } else {
            window.center()
        }

        window.contentViewController = KeyboardViewController()
    }
}

// MARK: - NSWindowDelegate

extension KeyboardWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let origin = window?.frame.origin else { return }
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: Keys.windowOrigin)
    }
}

// MARK: - DraggableWindow

class DraggableWindow: NSWindow {

    private var dragOffset: NSPoint = .zero

    // Don't steal focus from active app
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragOffset = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let screen = screen else { return }
        let loc = event.locationInWindow
        let newX = frame.origin.x + loc.x - dragOffset.x
        let newY = frame.origin.y + loc.y - dragOffset.y

        let clampedX = max(screen.visibleFrame.minX, min(newX, screen.visibleFrame.maxX - frame.width))
        let clampedY = max(screen.visibleFrame.minY, min(newY, screen.visibleFrame.maxY - frame.height))

        setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
}
