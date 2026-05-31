//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

// MARK: - Theme

enum Theme {
    static let panelBg     = NSColor(white: 0.22, alpha: 1)  // title bar, drag handle
    static let keyboardBg  = NSColor(white: 0.13, alpha: 1)  // keyboard area background
    static let keyNormal   = NSColor(white: 0.22, alpha: 1)  // key default state
    static let keyHover    = NSColor(white: 0.36, alpha: 1)  // key hover state
    static let keyPressed  = NSColor(red: 0.72, green: 0.13, blue: 0.13, alpha: 1) // key press
    static let keyActive   = NSColor(red: 0.20, green: 0.45, blue: 0.80, alpha: 1) // shift on
}

// MARK: - DragHandle

private class DragHandle: NSView {

    // MARK: - Subviews

    private let titleLabel   = NSTextField(labelWithString: "AllyKeyboard")
    private let minimizeBtn  = NSButton()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = Theme.panelBg.cgColor

        // Title label
        titleLabel.font      = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = NSColor(white: 1.0, alpha: 0.7)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // Minimize button — yellow circle
        minimizeBtn.bezelStyle              = .circular
        minimizeBtn.isBordered              = false
        minimizeBtn.wantsLayer              = true
        minimizeBtn.layer?.cornerRadius     = 6
        minimizeBtn.layer?.backgroundColor  = NSColor.systemYellow.cgColor
        minimizeBtn.layer?.masksToBounds    = true
        minimizeBtn.translatesAutoresizingMaskIntoConstraints = false
        minimizeBtn.target = self
        minimizeBtn.action = #selector(minimizeWindow)
        addSubview(minimizeBtn)

        NSLayoutConstraint.activate([
            // Title: vertically centered, left-aligned with padding
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),

            // Minimize button: 12×12, vertically centered, right-aligned
            minimizeBtn.widthAnchor.constraint(equalToConstant: 12),
            minimizeBtn.heightAnchor.constraint(equalToConstant: 12),
            minimizeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            minimizeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    @objc private func minimizeWindow() {
        window?.miniaturize(nil)
    }

    // MARK: - Drag

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(DragHandle.appMenu, with: event, for: self)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    // MARK: - Context menu

    static let appMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit AllyKeyboard",
                                action: #selector(NSApp.terminate(_:)),
                                keyEquivalent: ""))
        return menu
    }()
}

// MARK: - KeyButton

/// Custom keyboard key with dark styling, hover highlight, and red press feedback.
final class KeyButton: NSButton {


    private var isHovered = false

    var isActive = false { didSet { updateBackground() } }

    override init(frame: NSRect) { super.init(frame: frame); configure() }
    required init?(coder: NSCoder) { super.init(coder: coder); configure() }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true
        isBordered = false
        contentTintColor = .white
        updateBackground()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas
            .filter { $0.owner === self }
            .forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true;  updateBackground() }
    override func mouseExited (with event: NSEvent) { isHovered = false; updateBackground() }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        if flag {
            layer?.backgroundColor = Theme.keyPressed.cgColor
        } else {
            updateBackground()
        }
    }

    private func updateBackground() {
        layer?.backgroundColor = (isActive ? Theme.keyActive : isHovered ? Theme.keyHover : Theme.keyNormal).cgColor
    }
}

// MARK: - ViewController

class ViewController: NSViewController {

    // MARK: - Key definition

    private struct Key {
        let id:    String       // used for key simulation (CGEvent)
        let title: String       // displayed on the button face
        let image: String?      // SF Symbol name — overrides title when set
        init(_ id: String, title: String? = nil, image: String? = nil) {
            self.id    = id
            self.title = title ?? id
            self.image = image
        }
    }


    // MARK: - Scale

    var scale: CGFloat = AppConfig.defaultScale {
        didSet {
            guard windowConfigured, let window = view.window else { return }
            let size = keyboardSize
            window.setContentSize(size)
            buildKeyboard()
        }
    }

    // MARK: - Base layout constants (at scale = 1.0)

    private let baseKeyWidth:         CGFloat = 46
    private let baseKeyHeight:        CGFloat = 36
    private let baseKeySpacing:       CGFloat = 4
    private let baseRowSpacing:       CGFloat = 4
    private let basePadding:          CGFloat = 12
    private let baseKeyFontSize:      CGFloat = 14
    // MARK: - Scaled layout values

    private var keyWidth:         CGFloat { baseKeyWidth    * scale }
    private var keyHeight:        CGFloat { baseKeyHeight   * scale }
    private var keySpacing:       CGFloat { baseKeySpacing  * scale }
    private var rowSpacing:       CGFloat { baseRowSpacing  * scale }
    private var padding:          CGFloat { basePadding     * scale }
    private var keyFontSize:      CGFloat { baseKeyFontSize * scale }
    private var spaceKeyWidth:    CGFloat { keyWidth * 3 + keySpacing * 2 }

    /// Set from actual window title bar height in viewWillAppear.
    private var dragHandleHeight: CGFloat = 0

    // Number row fits the keyboard content width (14 keys auto-sized)
    private let numberRow: [Key] = [
        Key("`"),
        Key("1"), Key("2"), Key("3"), Key("4"), Key("5"),
        Key("6"), Key("7"), Key("8"), Key("9"), Key("0"),
        Key("-"), Key("="),
        Key("Backspace", image: "delete.backward")
    ]

    // Letter/special rows — define keyboard width
    private let letterRows: [[Key]] = [
        [Key("Q"), Key("W"), Key("E"), Key("R"), Key("T"),
         Key("Y"), Key("U"), Key("I"), Key("O"), Key("P")],
        [Key("A"), Key("S"), Key("D"), Key("F"), Key("G"),
         Key("H"), Key("J"), Key("K"), Key("L")],
        [Key("Shift", image: "shift"), Key("Z"), Key("X"), Key("C"), Key("V"),
         Key("B"), Key("N"), Key("M")],
        [Key("Cmd+A", title: "All"), Key("Cmd+X", title: "Cut"),
         Key("Cmd+C", title: "Copy"), Key("Cmd+V", title: "Paste"),
         Key("Cmd+Z", title: "Undo"),
         Key("Space", title: ""), Key("Backspace", image: "delete.backward"),
         Key("Return", image: "return")]
    ]

    private var allRows: [[Key]] { [numberRow] + letterRows }

    private var keyboardSize: NSSize {
        // Width from letter rows only — number row auto-fits this width
        let maxKeys = letterRows.map { $0.count }.max() ?? 0
        let w = CGFloat(maxKeys) * (keyWidth + keySpacing) - keySpacing + padding * 2
        let h = CGFloat(allRows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2 + dragHandleHeight
        return NSSize(width: w, height: h)
    }

    // MARK: - Shift state

    private var isShifted = false {
        didSet {
            shiftButton?.isActive = isShifted
            if !isShifted { shiftButton?.state = .off }
        }
    }
    private weak var shiftButton: KeyButton?

    // MARK: - Window state

    private let autosaveName   = "AllyKeyboardMain"
    private let hasLaunchedKey = "AllyKeyboard.hasLaunched"
    private var windowConfigured = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.keyboardBg.cgColor
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        windowConfigured = true

        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.panelBg
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        if AppConfig.useCustomTitleBar {
            // Custom title bar: hide all native traffic-light buttons,
            // make the native titlebar transparent so our DragHandle shows through.
            window.titlebarAppearsTransparent = true
            window.title = ""
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = false
            [NSWindow.ButtonType.closeButton,
             NSWindow.ButtonType.miniaturizeButton,
             NSWindow.ButtonType.zoomButton].forEach {
                window.standardWindowButton($0)?.isHidden = true
            }
            dragHandleHeight = window.frame.height - window.contentRect(forFrameRect: window.frame).height
        } else {
            // Native title bar: transparent, close active, zoom disabled
            window.title = "AllyKeyboard"
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            dragHandleHeight = window.frame.height - window.contentRect(forFrameRect: window.frame).height
        }

        window.setFrameAutosaveName(autosaveName)
        // setContentSize enforces the scale-based size on every launch.
        // Autosave persists position only (size is always derived from scale).
        let size = keyboardSize
        window.setContentSize(size)
        buildKeyboard()

        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            window.center()
        }

        // With .accessory policy and borderless styleMask the window must be
        // brought to front explicitly — makeKeyAndOrderFront is not enough.
        window.orderFrontRegardless()
    }

    // MARK: - Keyboard layout

    private func buildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }
        shiftButton = nil

        let size        = keyboardSize  // compute once
        let contentW    = size.width - padding * 2
        let symbolSize  = keyFontSize * 0.65

        // Number row: auto-size keys to fill content width
        let numKeyW = (contentW - CGFloat(numberRow.count - 1) * keySpacing) / CGFloat(numberRow.count)

        // DragHandle sits at the TOP of the window (high y in AppKit coords)
        let handle = DragHandle(frame: NSRect(x: 0, y: size.height - dragHandleHeight, width: size.width, height: dragHandleHeight))
        view.addSubview(handle)

        for (rowIndex, row) in allRows.enumerated() {
            let flippedRow = allRows.count - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let isNumRow = rowIndex == 0
            let rowWidth = isNumRow
                ? contentW
                : row.reduce(0) { $0 + letterKeyWidth(for: $1) } + CGFloat(row.count - 1) * keySpacing
            var x = padding + (contentW - rowWidth) / 2

            for key in row {
                let w   = isNumRow ? numKeyW : letterKeyWidth(for: key)
                let btn = KeyButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.identifier = NSUserInterfaceItemIdentifier(key.id)
                btn.target     = self
                btn.action     = #selector(keyPressed(_:))

                if let symbolName = key.image,
                   let img = NSImage(systemSymbolName: symbolName,
                                     accessibilityDescription: nil) {
                    let cfg = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
                    btn.image         = img.withSymbolConfiguration(cfg)
                    btn.imagePosition = .imageOnly
                } else {
                    btn.title = key.title
                    btn.font  = NSFont.systemFont(ofSize: keyFontSize, weight: .medium)
                }

                if key.id == "Shift" {
                    btn.setButtonType(.toggle)
                    if let altImg = NSImage(systemSymbolName: "shift.fill",
                                           accessibilityDescription: nil) {
                        let cfg = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .bold)
                        btn.alternateImage = altImg.withSymbolConfiguration(cfg)
                    }
                    shiftButton = btn
                }

                view.addSubview(btn)
                x += w + keySpacing
            }
        }
    }

    private func letterKeyWidth(for key: Key) -> CGFloat {
        key.id == "Space" ? spaceKeyWidth : keyWidth
    }

    // MARK: - Context menu

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(DragHandle.appMenu, with: event, for: view)
    }

    // MARK: - Actions

    @objc private func keyPressed(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else {
            assertionFailure("Key button missing identifier — fix buildKeyboard()")
            return
        }

        if key == "Shift" {
            isShifted = sender.state == .on
            return
        }

        KeySender.send(key, shifted: isShifted)

        // One-shot shift: reset after typing any key
        if isShifted { isShifted = false }

    }
}
