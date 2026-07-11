//
//  LauncherWindowController.swift
//  AllyKeyboard
//
//  A small floating panel shown when the keyboard is hidden. Clicking it brings
//  the keyboard back; it can be dragged around (clamped to the screen). Size /
//  corner radius / background mirror AllyClicker's panel (70pt, 12pt radius,
//  windowBackgroundColor).
//

import AppKit

final class LauncherWindowController {

    let window: NSPanel
    private let onClick: () -> Void
    private let size: CGFloat = 50
    private static let originKey = "AllyKeyboard.launcherOrigin"

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick

        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered, defer: false)
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true

        let container = LauncherView(frame: NSRect(x: 0, y: 0, width: size, height: size),
                                     onClick: onClick,
                                     onMoved: { [weak self] origin in self?.saveOrigin(origin) })
        window.contentView = container
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        if !window.isVisible { restorePosition() }
        window.orderFront(nil)
    }

    /// Restore the last dragged position (if any and still on a visible screen),
    /// otherwise fall back to the default spot.
    private func restorePosition() {
        if let origin = savedOrigin(), isOnAnyScreen(origin) {
            window.setFrameOrigin(origin)
        } else {
            positionAtDefault()
        }
    }

    private func saveOrigin(_ origin: NSPoint) {
        UserDefaults.standard.set(["x": origin.x, "y": origin.y], forKey: Self.originKey)
    }

    private func savedOrigin() -> NSPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: Self.originKey),
              let x = d["x"] as? CGFloat, let y = d["y"] as? CGFloat else { return nil }
        return NSPoint(x: x, y: y)
    }

    /// Guard against a stored position that's off-screen (monitor unplugged, etc.).
    private func isOnAnyScreen(_ origin: NSPoint) -> Bool {
        let frame = NSRect(x: origin.x, y: origin.y, width: size, height: size)
        return NSScreen.screens.contains { $0.visibleFrame.intersects(frame) }
    }

    func hide() { window.orderOut(nil) }

    private func positionAtDefault() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame

        // Right edge of the screen, just above the Dock.
        let margin: CGFloat = 16
        let x = visible.maxX - size - margin
        let y = visible.minY + margin
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// Rounded panel background (12pt radius, windowBackgroundColor) that also handles
/// dragging the window and click-to-restore. A short press acts as a click; moving
/// beyond a small threshold drags the window, clamped to the screen's visible frame.
private final class LauncherView: NSView {

    private let onClick: () -> Void
    private let onMoved: (NSPoint) -> Void
    private var mouseDownScreen: NSPoint = .zero   // cursor at press (screen coords)
    private var windowOriginAtDown: NSPoint = .zero
    private var didDrag = false
    private let dragThreshold: CGFloat = 4

    init(frame: NSRect, onClick: @escaping () -> Void, onMoved: @escaping (NSPoint) -> Void) {
        self.onClick = onClick
        self.onMoved = onMoved
        super.init(frame: frame)
        let glyph = NSImageView(frame: bounds.insetBy(dx: 10, dy: 10))
        glyph.autoresizingMask = [.width, .height]
        glyph.imageScaling = .scaleProportionallyDown
        if let image = NSImage(named: "keyboard-glyph") {
            image.isTemplate = true
            glyph.image = image
            glyph.contentTintColor = .labelColor
        }
        addSubview(glyph)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        NSColor.windowBackgroundColor.setFill()
        path.fill()
    }

    // Take every mouse event ourselves so the glyph image view can't swallow drags.
    override func hitTest(_ point: NSPoint) -> NSView? { self }

    override func mouseDown(with event: NSEvent) {
        didDrag = false
        mouseDownScreen = NSEvent.mouseLocation
        windowOriginAtDown = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - mouseDownScreen.x
        let dy = now.y - mouseDownScreen.y
        if abs(dx) > dragThreshold || abs(dy) > dragThreshold { didDrag = true }
        let origin = NSPoint(x: windowOriginAtDown.x + dx, y: windowOriginAtDown.y + dy)
        window.setFrameOrigin(clampToScreen(origin, of: window))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            if let window = window { onMoved(window.frame.origin) }
        } else {
            onClick()
        }
    }

    /// Keep the whole window inside the current screen's visible frame.
    private func clampToScreen(_ origin: NSPoint, of window: NSWindow) -> NSPoint {
        let screen = window.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }
        let w = window.frame.width, h = window.frame.height
        let x = min(max(origin.x, visible.minX), visible.maxX - w)
        let y = min(max(origin.y, visible.minY), visible.maxY - h)
        return NSPoint(x: x, y: y)
    }
}
