//
//  AppSwitcherPanel.swift
//  AllyKeyboard
//
//  A row of running applications, drawn as Dock-sized icons.
//
//  Why not the system's ⌘-Tab panel, which is what this imitates: that panel
//  only stays up while Command is physically held, and — measured on this
//  user's Mac on 2026-09-26, where seven of eight applications had every window
//  minimised — it activates an application without restoring them. The menu bar
//  changes and nothing else does. For someone who works with windows minimised
//  that is not a switcher at all.
//
//  This one raises the windows: it unhides, it un-minimises through
//  Accessibility, and only then activates.

import Cocoa
import AllyKeyboardCore

final class AppSwitcherPanel {

    private var panel: NSPanel?
    private var outsideMonitor: Any?

    /// Gaps and padding follow the icon, which is the only size worth a
    /// setting: everything else exists to frame it.
    private var baseGap: CGFloat { settings.appPanelIconSize > 0 ? CGFloat(settings.appPanelIconSize) * 0.22 : 14 }
    /// The margin between the icons and the panel's edge. Deliberately smaller
    /// than the gap between icons: the frame should hold the row, not surround
    /// it with air.
    private var basePadding: CGFloat { baseGap * 0.75 }

    private var settings = Settings()
    private var autoHide: DispatchWorkItem?

    /// The row, in order, with the geometry the wave is computed from.
    private var buttons: [AppIconView] = []
    private var restCentres: [CGFloat] = []
    private var side: CGFloat = 64
    private var gap: CGFloat = 14
    private var rowCentreY: CGFloat = 0

    /// How much the icon under the pointer grows, and how far the swell
    /// reaches. Two icons either side is what the Dock does, and it is what
    /// makes the movement read as one wave rather than each icon twitching.
    private let maxZoom: CGFloat = 1.20
    private var reach: CGFloat { (side + gap) * 2 }

    /// Where each icon is heading, and where it is now. The pointer sets the
    /// target; the size walks towards it on a clock of its own.
    ///
    /// They have to be separate. A head tracker moves the cursor in whole
    /// pixels and, once it is aimed, in rare small jumps — so a size computed
    /// straight from the pointer's position jumps with it. Measured from the
    /// user's screen recording on 2026-09-26: an icon went from 75 to 85 pixels
    /// in a single frame, and back in two. Smooth while the head swept along
    /// the row, a jolt whenever it settled on one icon, which is exactly what
    /// they reported.
    private var targetScales: [CGFloat] = []
    private var currentScales: [CGFloat] = []
    private var ticker: DispatchSourceTimer?

    /// How much of the remaining distance is covered each frame. **1.0 means no
    /// easing at all** — the size takes the pointer's value immediately.
    ///
    /// Eased at 0.25 it was worse, not better, and the user said so at once:
    /// the swell then trails the head by some 60 ms, and while sweeping along
    /// the row the whole wave lags behind the pointer. A jump you can predict
    /// beats a smooth motion that arrives late.
    private let approach: CGFloat = 1.0

    var isVisible: Bool { panel?.isVisible ?? false }

    /// Applications a person would call open — the ones with a Dock icon.
    /// `.accessory` apps are excluded, and this keyboard is one of them, so it
    /// never offers to switch to itself.
    private func runningApps() -> [NSRunningApplication] {
        let hidden = Set(settings.appPanelHiddenApps
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty })
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { !hidden.contains(($0.localizedName ?? "").lowercased()) }
            .sorted {
                ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "")
                    == .orderedAscending
            }
    }

    func toggle(settings: Settings, scale: CGFloat, over keyboard: NSWindow?) {
        if isVisible { hide() } else { show(settings: settings, scale: scale, over: keyboard) }
    }

    func show(settings: Settings, scale: CGFloat, over keyboard: NSWindow?) {
        hide()
        self.settings = settings
        let apps = runningApps()
        guard !apps.isEmpty else { return }

        side = CGFloat(settings.appPanelIconSize) * scale
        gap = baseGap * scale
        let padding = basePadding * scale
        // Room for the swell: at most about two and a half icons' worth of
        // extra width, and the tallest icon has to fit too.
        let slack = settings.appPanelHoverZoom ? (maxZoom - 1) * side * 2.5 : 0
        let width = CGFloat(apps.count) * side + CGFloat(apps.count - 1) * gap + padding * 2 + slack
        let height = (settings.appPanelHoverZoom ? side * maxZoom : side) + padding * 2

        let screen = keyboard?.screen ?? NSScreen.main
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 600)
        let origin = NSPoint(x: frame.midX - width / 2, y: frame.midY - height / 2)

        let p = NSPanel(contentRect: NSRect(origin: origin, size: NSSize(width: width, height: height)),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.level = AppConfig.Levels.keyboard
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.backgroundColor = .clear
        p.isOpaque = false
        // Without this the window is told about the pointer only now and then,
        // and the wave moves in steps rather than with the head.
        p.acceptsMouseMovedEvents = true

        let background = HoverTrackingView(frame: NSRect(origin: .zero, size: p.frame.size))
        background.onMouseMoved = { [weak self] x in self?.updateTargets(pointerX: x) }
        background.onMouseExited = { [weak self] in self?.updateTargets(pointerX: nil) }
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor(
            white: 0.13, alpha: CGFloat(settings.appPanelOpacityPercent) / 100.0).cgColor
        background.layer?.cornerRadius = 18 * scale
        background.layer?.borderWidth = 1
        background.layer?.borderColor = NSColor(white: 1, alpha: 0.12).cgColor

        buttons = []
        restCentres = []
        rowCentreY = height / 2
        let rowWidth = CGFloat(apps.count) * side + CGFloat(apps.count - 1) * gap
        let firstX = (width - rowWidth) / 2

        for (i, app) in apps.enumerated() {
            let centre = firstX + CGFloat(i) * (side + gap) + side / 2
            let icon = AppIconView(frame: NSRect(x: centre - side / 2,
                                                 y: rowCentreY - side / 2,
                                                 width: side, height: side))
            icon.app = app
            icon.toolTip = app.localizedName
            icon.outlineWidth = CGFloat(settings.appPanelOutlineWidth) * scale
            icon.outlineGap = CGFloat(settings.appPanelOutlineGap) * scale
            icon.onPick = { [weak self] picked in
                self?.hide()
                self?.raise(picked)
            }
            background.addSubview(icon)
            buttons.append(icon)
            restCentres.append(centre)
        }
        currentScales = Array(repeating: 1, count: buttons.count)
        targetScales = currentScales

        p.contentView = background
        p.orderFrontRegardless()
        panel = p

        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            self?.hide()
        }

        // Closing on its own is off by default and has to be asked for: a panel
        // that disappears while somebody is still aiming at it with their head
        // is worse than one that waits.
        if settings.appPanelAutoHideSeconds > 0 {
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            autoHide = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(settings.appPanelAutoHideSeconds),
                                          execute: work)
        }
    }

    /// The wave. Every icon is sized from its distance to the pointer, so the
    /// row swells and settles as one shape instead of each icon reacting on its
    /// own — which is what made the previous version feel like a series of
    /// jumps rather than a movement.
    ///
    /// Sizes are set directly, without an animation, while the pointer is
    /// inside: the pointer's own movement is the animation, and animating each
    /// step on top of it only adds lag. Leaving the panel is the one case that
    /// animates, because nothing is driving the change then.
    private func updateTargets(pointerX: CGFloat?) {
        guard !restCentres.isEmpty else { return }
        highlight(pointerX: pointerX)
        targetScales = restCentres.map { centre in
            guard settings.appPanelHoverZoom, let x = pointerX else { return 1 }
            let t = min(abs(x - centre) / reach, 1)
            // A cosine falls off smoothly at both ends: no corner where the
            // growth starts, no step where it stops.
            return 1 + (maxZoom - 1) * cos(t * .pi / 2)
        }
        startTicking()
    }

    /// Outline the icon the pointer is on.
    ///
    /// Unlike the swell, this is a yes-or-no state: it cannot shake with the
    /// pointer and it cannot arrive late. Which is why it is worth having even
    /// when the magnification is turned off — it answers "what am I about to
    /// click" without moving anything.
    ///
    /// Decided from the pointer's distance to each icon's centre rather than
    /// from the frames, because the frames are mid-swell most of the time.
    private func highlight(pointerX: CGFloat?) {
        guard let x = pointerX else {
            buttons.forEach { $0.isHighlighted = false }
            return
        }
        // Against the icon's real rectangle, which is what a click hits. The
        // first version measured distance to the rest centre and lit nothing
        // while the pointer was in a gap — so sweeping along the row made the
        // outline blink out and back, and that reads as the outline lagging
        // behind rather than as a gap doing its job.
        for button in buttons {
            button.isHighlighted = x >= button.frame.minX && x < button.frame.maxX
        }
    }

    private func startTicking() {
        guard ticker == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(16))
        t.setEventHandler { [weak self] in self?.step() }
        t.resume()
        ticker = t
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    private func step() {
        guard currentScales.count == targetScales.count, !currentScales.isEmpty else {
            stopTicking(); return
        }
        var moving = false
        for i in currentScales.indices {
            let remaining = targetScales[i] - currentScales[i]
            if abs(remaining) > 0.002 {
                currentScales[i] += remaining * approach
                moving = true
            } else {
                currentScales[i] = targetScales[i]
            }
        }
        applyLayout()
        if !moving { stopTicking() }     // nothing to draw until the pointer moves again
    }

    /// Lay the row out from the sizes it has right now, spreading the icons so
    /// they push each other apart rather than overlap, and keeping the row
    /// centred in the panel.
    private func applyLayout() {
        guard !buttons.isEmpty else { return }
        let widths = currentScales.map { side * $0 }
        let total = widths.reduce(0, +) + gap * CGFloat(buttons.count - 1)
        let panelWidth = buttons.first?.superview?.bounds.width ?? total
        var x = (panelWidth - total) / 2

        for (i, button) in buttons.enumerated() {
            let w = widths[i]
            button.frame = NSRect(x: x, y: rowCentreY - w / 2, width: w, height: w)
            button.refreshOutline()
            x += w + gap
        }
    }

    func hide() {
        stopTicking()
        autoHide?.cancel()
        autoHide = nil
        if let monitor = outsideMonitor {
            NSEvent.removeMonitor(monitor)
            outsideMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    /// Unhide, un-minimise, then activate — in that order, because activating an
    /// application whose windows are all in the Dock is what the system switcher
    /// already does, and it is exactly what does not help.
    private func raise(_ app: NSRunningApplication) {
        app.unhide()

        let ax = AXUIElementCreateApplication(app.processIdentifier)
        // A frozen application must not freeze the keyboard with it.
        AXUIElementSetMessagingTimeout(ax, 0.25)
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement] {
            for window in windows {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString,
                                             kCFBooleanFalse)
            }
        }

        app.activate(options: [.activateAllWindows])
    }
}

/// One application's icon.
///
/// A layer with the icon as its contents, not an `NSButton` with an image: the
/// wave changes every icon's size on every movement of the pointer, and asking
/// AppKit to redraw a 512-pixel icon eight times per movement is what made the
/// swell stutter. A layer is resized by the graphics card and does not redraw
/// at all.
private final class AppIconView: NSView {
    var app: NSRunningApplication?
    var onPick: ((NSRunningApplication) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // Both, and the first is the one that matters. Since macOS 14 a
        // layer-backed view clips to its bounds by default, and AppKit rewrites
        // the layer's masksToBounds from this property on every layout pass —
        // so setting the layer alone is undone the moment anything moves, and
        // the outline is quietly shaved off at the icon's edge.
        clipsToBounds = false
        layer?.masksToBounds = false
        layer?.contentsGravity = .resizeAspect
        layer?.magnificationFilter = .trilinear
        layer?.minificationFilter = .trilinear
    }

    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? 2
        loadIcon()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        loadIcon()
    }

    private func loadIcon() {
        guard layer?.contents == nil, let image = app?.icon else { return }
        var rect = CGRect(origin: .zero, size: image.size)
        layer?.contents = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    /// White, and the only signal that says which icon a click would reach.
    var isHighlighted = false {
        didSet { if isHighlighted != oldValue { refreshOutline() } }
    }

    /// Both in points, already multiplied by the keyboard's scale. The outline
    /// lives on its own layer rather than on the icon's border, because it has
    /// to be able to stand *off* the icon — a border can only sit on the edge.
    var outlineWidth: CGFloat = 3
    var outlineGap: CGFloat = 4

    private let outline = CALayer()

    /// Appears and fades over 0.3 s, ease-in-out.
    ///
    /// The fade is on the layer's opacity rather than on the border's width: a
    /// border growing from nothing reads as the icon inflating, while a fade
    /// reads as what it is — a mark appearing. Geometry changes are explicitly
    /// *not* animated: this layer moves with the wave on every frame, and a
    /// quarter-second animation on each of those moves is precisely the lag we
    /// spent the afternoon removing.
    /// Short enough to feel immediate while aiming. 0.3 s looked right in the
    /// abstract and felt like waiting in the hand.
    private static let fade: TimeInterval = 0.12

    func refreshOutline() {
        if outline.superlayer == nil {
            outline.borderColor = NSColor.white.cgColor
            outline.masksToBounds = false
            outline.opacity = 0
            // No implicit animation on anything geometric.
            outline.actions = ["position": NSNull(), "bounds": NSNull(),
                               "frame": NSNull(), "cornerRadius": NSNull(),
                               "borderWidth": NSNull()]
            layer?.addSublayer(outline)
        }

        // A macOS application icon does not fill its own image: Apple's grid
        // puts the rounded square in 824 of 1024 points, leaving about 9.8% of
        // transparent margin on each side for shadows and badges. Measuring the
        // outline from the image's edge therefore leaves a visible gap even at
        // a distance of zero — which is exactly what the user saw. The artwork
        // is what the eye calls "the icon", so that is what it is measured from.
        let artInset = bounds.width * 0.098
        let art = bounds.insetBy(dx: artInset, dy: artInset)

        let inset = -(outlineGap + outlineWidth / 2)
        outline.frame = art.insetBy(dx: inset, dy: inset)
        // The squircle's own radius is 22.5% of the artwork, and the outline
        // has to grow its corners by however far it stands off.
        outline.cornerRadius = art.width * 0.225 + outlineGap + outlineWidth / 2
        outline.borderWidth = outlineWidth

        let wanted: Float = (isHighlighted && outlineWidth > 0) ? 1 : 0
        guard outline.opacity != wanted else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = outline.opacity
        fade.toValue = wanted
        fade.duration = Self.fade
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        outline.add(fade, forKey: "fade")
        outline.opacity = wanted
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseUp(with event: NSEvent) {
        guard let app else { return }
        onPick?(app)
    }
}

/// The panel's background, which is where the pointer is followed. One tracking
/// area for the whole row rather than one per icon: the wave needs to know where
/// the pointer is even when it is between two icons.
private final class HoverTrackingView: NSView {
    var onMouseMoved: ((CGFloat) -> Void)?
    var onMouseExited: (() -> Void)?
    private var tracking: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        onMouseMoved?(convert(event.locationInWindow, from: nil).x)
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
