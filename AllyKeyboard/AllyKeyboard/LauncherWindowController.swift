//
//  LauncherWindowController.swift
//  AllyKeyboard
//
//  A small floating panel shown when the keyboard is hidden. Clicking it brings
//  the keyboard back; it can be dragged around (clamped to the screen). Width and
//  opacity are configurable in Settings; the corner radius is 10% of the width and
//  the glyph is 60% of the width.
//

import AppKit

final class LauncherWindowController {

    let window: NSPanel
    private let onClick: () -> Void
    private var size: CGFloat
    private static let originKey = "AllyKeyboard.launcherOrigin"

    init(width: CGFloat = 50, alpha: CGFloat = 1.0, onClick: @escaping () -> Void) {
        self.onClick = onClick
        self.size = width

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
        window.alphaValue = alpha

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

    func hide() { window.orderOut(nil) }

    /// Resize the panel (keeping it clamped on screen), radius/glyph follow the width.
    func setWidth(_ width: CGFloat) {
        size = width
        var frame = window.frame
        frame.size = NSSize(width: width, height: width)
        window.setFrame(frame, display: true)
        window.setFrameOrigin(clampToScreen(frame.origin))
        window.contentView?.needsLayout = true
        window.contentView?.needsDisplay = true
    }

    func setOpacity(_ alpha: CGFloat) {
        window.alphaValue = alpha
    }

    // MARK: - Position persistence

    /// Restore the last dragged position (if any and still on a visible screen),
    /// otherwise fall back to the default spot.
    private func restorePosition() {
        if let origin = savedOrigin(), isOnAnyScreen(origin) {
            window.setFrameOrigin(clampToScreen(origin))
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

    private func positionAtDefault() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame

        // Right edge of the screen, just above the Dock.
        let margin: CGFloat = 16
        let x = visible.maxX - size - margin
        let y = visible.minY + margin
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func clampToScreen(_ origin: NSPoint) -> NSPoint {
        let screen = window.screen ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return origin }
        let x = min(max(origin.x, visible.minX), visible.maxX - size)
        let y = min(max(origin.y, visible.minY), visible.maxY - size)
        return NSPoint(x: x, y: y)
    }
}

/// Rounded panel background (radius = 10% of width, windowBackgroundColor) that also
/// handles dragging and click-to-restore. A short press acts as a click; moving beyond
/// a small threshold drags the window, clamped to the screen's visible frame.
private final class LauncherView: NSView {

    private let onClick: () -> Void
    private let onMoved: (NSPoint) -> Void
    private let glyph = NSImageView()
    private var mouseDownScreen: NSPoint = .zero   // cursor at press (screen coords)
    private var windowOriginAtDown: NSPoint = .zero
    private var didDrag = false
    private let dragThreshold: CGFloat = 4

    init(frame: NSRect, onClick: @escaping () -> Void, onMoved: @escaping (NSPoint) -> Void) {
        self.onClick = onClick
        self.onMoved = onMoved
        super.init(frame: frame)
        glyph.imageScaling = .scaleProportionallyDown
        if let image = NSImage(named: "keyboard-glyph") {
            image.isTemplate = true
            glyph.image = image
            glyph.contentTintColor = .labelColor
        }
        addSubview(glyph)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        // Glyph is 60% of the width, centered.
        let inset = bounds.width * 0.20
        glyph.frame = bounds.insetBy(dx: inset, dy: inset)
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.width * 0.10
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
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
