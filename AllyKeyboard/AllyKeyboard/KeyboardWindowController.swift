//
//  KeyboardWindowController.swift
//  AllyKeyboard
//

import Cocoa

class KeyboardWindowController: NSWindowController {

    convenience init() {
        // Create window
        let window = DraggableWindow(
            contentRect: NSRect(x: 100, y: 100, width: 520, height: 180),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "AllyKeyboard"

        // Float above all other windows
        window.level = .floating

        // Appear on all Spaces, don't move when switching Spaces
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Don't steal focus from active app
        window.isReleasedWhenClosed = false

        self.init(window: window)

        // Restore saved position or center on screen
        if let savedOrigin = UserDefaults.standard.string(forKey: "windowOrigin") {
            let point = NSPointFromString(savedOrigin)
            window.setFrameOrigin(point)
        } else {
            window.center()
        }

        // Set view controller
        let vc = KeyboardViewController()
        window.contentViewController = vc
    }

    override func windowDidLoad() {
        super.windowDidLoad()
    }
}

// MARK: - Save position on move

extension KeyboardWindowController: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let origin = window?.frame.origin else { return }
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: "windowOrigin")
    }
}

// MARK: - Draggable Window

class DraggableWindow: NSWindow {

    private var dragOffset: NSPoint = .zero

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragOffset = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let screen = screen else { return }
        let current = event.locationInWindow
        let newX = frame.origin.x + current.x - dragOffset.x
        let newY = frame.origin.y + current.y - dragOffset.y

        // Keep window within screen bounds
        let maxX = screen.visibleFrame.maxX - frame.width
        let maxY = screen.visibleFrame.maxY - frame.height
        let clampedX = max(screen.visibleFrame.minX, min(newX, maxX))
        let clampedY = max(screen.visibleFrame.minY, min(newY, maxY))

        setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
}
