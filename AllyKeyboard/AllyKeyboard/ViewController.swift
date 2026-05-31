//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

// MARK: - CustomStatusBar

final class CustomStatusBar: NSView {

    private let titleLabel  = NSTextField(labelWithString: "AllyKeyboard")
    private let minimizeBtn = NSButton()

    override init(frame: NSRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = AppConfig.Colors.statusBarBg.cgColor
        setupTitle()
        setupMinimizeButton()
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            minimizeBtn.widthAnchor.constraint(equalToConstant: 12),
            minimizeBtn.heightAnchor.constraint(equalToConstant: 12),
            minimizeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            minimizeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    private func setupTitle() {
        titleLabel.font      = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = NSColor(white: 1.0, alpha: 0.85)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
    }

    private func setupMinimizeButton() {
        minimizeBtn.isBordered             = false
        minimizeBtn.wantsLayer             = true
        minimizeBtn.layer?.cornerRadius    = 6
        minimizeBtn.layer?.backgroundColor = NSColor.systemYellow.cgColor
        minimizeBtn.layer?.masksToBounds   = true
        minimizeBtn.translatesAutoresizingMaskIntoConstraints = false
        minimizeBtn.target = self
        minimizeBtn.action = #selector(minimizeTapped)
        addSubview(minimizeBtn)
    }

    @objc private func minimizeTapped() { window?.miniaturize(nil) }

    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override var mouseDownCanMoveWindow: Bool { false }
}

// MARK: - DragHandle

private class DragHandle: NSView {

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
        layer?.backgroundColor = AppConfig.Colors.dragBarBg.cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        let dotDiameter: CGFloat = 6
        let dotGap:      CGFloat = 8
        let totalWidth = 3 * dotDiameter + 2 * dotGap
        var x = (bounds.width - totalWidth) / 2
        let y = (bounds.height - dotDiameter) / 2

        NSColor(white: 1.0, alpha: 0.5).setFill()
        for _ in 0..<3 {
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dotDiameter, height: dotDiameter)).fill()
            x += dotDiameter + dotGap
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(DragHandle.appMenu, with: event, for: self)
    }

    override var mouseDownCanMoveWindow: Bool { false }

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
        layer?.cornerRadius = AppConfig.Layout.keyCornerRadius
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
            layer?.backgroundColor = AppConfig.Colors.keyPressed.cgColor
        } else {
            updateBackground()
        }
    }

    private func updateBackground() {
        layer?.backgroundColor = (isActive ? AppConfig.Colors.keyActive : isHovered ? AppConfig.Colors.keyHover : AppConfig.Colors.keyNormal).cgColor
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

    var scale: CGFloat = AppConfig.Layout.keyboardScale {
        didSet {
            guard windowConfigured, let window = view.window else { return }
            let size = keyboardSize
            window.setContentSize(size)
            buildKeyboard()
        }
    }

    // MARK: - Scaled layout values (base constants live in AppConfig.Layout)

    private var keyWidth:         CGFloat { AppConfig.Layout.keyWidth    * scale }
    private var keyHeight:        CGFloat { AppConfig.Layout.keyHeight   * scale }
    private var keySpacing:       CGFloat { AppConfig.Layout.keySpacing  * scale }
    private var rowSpacing:       CGFloat { AppConfig.Layout.rowSpacing  * scale }
    private var padding:          CGFloat { AppConfig.Layout.padding     * scale }
    private var keyFontSizePrimary:   CGFloat { AppConfig.Layout.fontSizePrimary   * scale }
    private var keyFontSizeSecondary: CGFloat { AppConfig.Layout.fontSizeSecondary * scale }
    private var spaceKeyWidth:    CGFloat { keyWidth * 3 + keySpacing * 2 }

    /// Set from actual window title bar height in viewWillAppear.
    private var dragHandleHeight: CGFloat = 0
    /// Matches dragHandleHeight — all three bars (native, custom, drag) are the same height.
    private var customStatusBarHeight: CGFloat { dragHandleHeight }

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
        let h = CGFloat(allRows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2 + dragHandleHeight + customStatusBarHeight
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
        view.layer?.backgroundColor = AppConfig.Colors.keyboardBg.cgColor
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        windowConfigured = true

        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = AppConfig.Colors.statusBarBg
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Compute title bar height BEFORE fullSizeContentView changes the geometry
        dragHandleHeight = window.frame.height - window.contentRect(forFrameRect: window.frame).height

        if AppConfig.useCustomTitleBar {
            // Expand content into title bar zone so CustomStatusBar can sit there
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.title = ""
            [NSWindow.ButtonType.closeButton,
             NSWindow.ButtonType.miniaturizeButton,
             NSWindow.ButtonType.zoomButton].forEach {
                window.standardWindowButton($0)?.isHidden = true
            }
        } else {
            window.titlebarAppearsTransparent = true
            window.title = "AllyKeyboard"
            window.standardWindowButton(.zoomButton)?.isEnabled = false
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
    }

    // MARK: - Keyboard layout

    private func buildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }
        shiftButton = nil

        let size        = keyboardSize  // compute once
        let contentW    = size.width - padding * 2
        let symbolSize  = keyFontSizePrimary * 0.65

        // Number row: auto-size keys to fill content width
        let numKeyW = (contentW - CGFloat(numberRow.count - 1) * keySpacing) / CGFloat(numberRow.count)

        let handle = DragHandle(frame: NSRect(x: 0, y: 0, width: size.width, height: dragHandleHeight))
        view.addSubview(handle)

        // CustomStatusBar sits at the TOP of content area (just below native title bar)
        let statusBar = CustomStatusBar(frame: NSRect(
            x: 0,
            y: size.height - customStatusBarHeight,
            width: size.width,
            height: customStatusBarHeight
        ))
        view.addSubview(statusBar)

        for (rowIndex, row) in allRows.enumerated() {
            let flippedRow = allRows.count - 1 - rowIndex
            let y = dragHandleHeight + padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

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
                    btn.font  = NSFont.systemFont(ofSize: keyFontSizePrimary, weight: .medium)
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
