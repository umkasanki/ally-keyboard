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
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            minimizeBtn.widthAnchor.constraint(equalToConstant: 36),
            minimizeBtn.heightAnchor.constraint(equalToConstant: 12),
            minimizeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
            minimizeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
    }

    private func setupTitle() {
        titleLabel.font      = NSFont.systemFont(ofSize: 13, weight: .regular)
        titleLabel.textColor = NSColor(white: 1.0, alpha: 0.85)
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

    /// Secondary symbol drawn in the top-right corner of the key (e.g. shifted character).
    var secondaryText: String? { didSet { needsDisplay = true } }
    var secondaryFontSize: CGFloat = 8
    /// Character to send when Shift is active (overrides uppercased keyID for punctuation)
    var shiftedChar: String?

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

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let text = secondaryText else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: secondaryFontSize, weight: .regular),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.5)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        // Top-right corner: x from right edge, y from top edge (flipped: y=0 is top in draw)
        let margin: CGFloat = 3
        let x = bounds.width  - size.width  - margin
        let y = margin
        str.draw(at: NSPoint(x: x, y: y))
    }
}

// MARK: - ViewController

class ViewController: NSViewController {

    // MARK: - Key definition

    private struct Key {
        let id:             String      // used for key simulation (CGEvent)
        let title:          String      // primary label on the key face
        let secondary:      String?     // secondary label (top-left, small) — e.g. shifted symbol
        let image:          String?     // SF Symbol — overrides title when set
        let widthMultiplier: CGFloat    // 1.0 = standard key width

        init(_ id: String,
             title: String? = nil,
             secondary: String? = nil,
             image: String? = nil,
             w: CGFloat = 1.0) {
            self.id             = id
            self.title          = title ?? id
            self.secondary      = secondary
            self.image          = image
            self.widthMultiplier = w
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
    private func keyW(_ key: Key) -> CGFloat {
        key.widthMultiplier == 1.0
            ? keyWidth
            : keyWidth * key.widthMultiplier + keySpacing * (key.widthMultiplier - 1)
    }

    /// Set from actual window title bar height in viewWillAppear.
    private var dragHandleHeight: CGFloat = 0
    /// Matches dragHandleHeight — all three bars (native, custom, drag) are the same height.
    private var customStatusBarHeight: CGFloat { dragHandleHeight }

    // MARK: - Keyboard rows

    private let numberRow: [Key] = [
        Key("`",   title: "~", secondary: "`"),
        Key("1",   secondary: "!"),
        Key("2",   secondary: "@"),
        Key("3",   secondary: "#"),
        Key("4",   secondary: "$"),
        Key("5",   secondary: "%"),
        Key("6",   secondary: "^"),
        Key("7",   secondary: "&"),
        Key("8",   secondary: "*"),
        Key("9",   secondary: "("),
        Key("0",   secondary: ")"),
        Key("-",   secondary: "_"),
        Key("=",   secondary: "+"),
        Key("Backspace", image: "delete.backward", w: 1.5),
    ]

    private let letterRows: [[Key]] = [
        // QWERTY row
        [Key("Tab",  title: "Tab",  w: 1.5),
         Key("Q"), Key("W"), Key("E"), Key("R"), Key("T"),
         Key("Y"), Key("U"), Key("I"), Key("O"), Key("P"),
         Key("Return", image: "return", w: 1.5)],
        // ASDF row
        [Key("CapsLock", title: "Caps", w: 1.75),
         Key("A"), Key("S"), Key("D"), Key("F"), Key("G"),
         Key("H"), Key("J"), Key("K"), Key("L"),
         Key("Return", image: "return", w: 1.75)],
        // ZXCV row
        [Key("Shift",      image: "shift", w: 1.75),
         Key("Z", title: "z"), Key("X", title: "x"), Key("C", title: "c"),
         Key("V", title: "v"), Key("B", title: "b"), Key("N", title: "n"),
         Key("M", title: "m"),
         Key(",", secondary: "<"),
         Key(".", secondary: ">"),
         Key("/", secondary: "?"),
         Key("Shift",      image: "shift", w: 1.75),
         Key("ArrowUp",    image: "arrow.up"),
         Key("End",        title: "end")],
        // Bottom row
        [Key("Ctrl",       title: "^",  w: 1.5),
         Key("Alt",        title: "⌥", w: 1.5),
         Key("Cmd",        title: "⌘", w: 1.5),
         Key("Space",      title: "",  w: 5.0),
         Key("Cmd",        title: "⌘", w: 1.5),
         Key("Alt",        title: "⌥", w: 1.5),
         Key("ArrowLeft",  image: "arrow.left"),
         Key("ArrowDown",  image: "arrow.down"),
         Key("ArrowRight", image: "arrow.right")],
    ]

    private var allRows: [[Key]] { [numberRow] + letterRows }

    private func rowPixelWidth(_ row: [Key]) -> CGFloat {
        row.reduce(0) { $0 + keyW($1) } + CGFloat(row.count - 1) * keySpacing
    }

    private var keyboardSize: NSSize {
        let contentW = allRows.map { rowPixelWidth($0) }.max() ?? 0
        let w = contentW + padding * 2
        let statusBarH = AppConfig.useCustomTitleBar ? customStatusBarHeight : 0
        let h = CGFloat(allRows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2 + dragHandleHeight + statusBarH
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

        let size       = keyboardSize  // compute once
        let contentW   = size.width - padding * 2
        let symbolSize = keyFontSizePrimary * 0.65

        let handle = DragHandle(frame: NSRect(x: 0, y: 0, width: size.width, height: dragHandleHeight))
        view.addSubview(handle)

        if AppConfig.useCustomTitleBar {
            let statusBar = CustomStatusBar(frame: NSRect(
                x: 0,
                y: size.height - customStatusBarHeight,
                width: size.width,
                height: customStatusBarHeight
            ))
            view.addSubview(statusBar)
        }

        for (rowIndex, row) in allRows.enumerated() {
            let flippedRow = allRows.count - 1 - rowIndex
            let y = dragHandleHeight + padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = rowPixelWidth(row)
            var x = padding + (contentW - rowWidth) / 2

            for key in row {
                let w   = keyW(key)
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

                // Secondary symbol drawn in top-right corner via KeyButton.draw()
                if let secondary = key.secondary {
                    btn.secondaryText     = secondary
                    btn.secondaryFontSize = keyFontSizeSecondary
                    btn.shiftedChar       = secondary
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

        if isShifted, let shiftedChar = (sender as? KeyButton)?.shiftedChar {
            KeySender.send(shiftedChar, shifted: false)
        } else {
            KeySender.send(key, shifted: isShifted)
        }

        // One-shot shift: reset after typing any key
        if isShifted { isShifted = false }

    }
}
