//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

class ViewController: NSViewController {

    // MARK: - Key definition

    private struct Key {
        let id:    String   // used for key simulation (CGEvent in Phase 2)
        let title: String   // displayed on the button face
        init(_ id: String, title: String? = nil) {
            self.id    = id
            self.title = title ?? id
        }
    }

    // MARK: - Keyboard rows

    private let rows: [[Key]] = [
        [Key("Q"), Key("W"), Key("E"), Key("R"), Key("T"),
         Key("Y"), Key("U"), Key("I"), Key("O"), Key("P")],
        [Key("A"), Key("S"), Key("D"), Key("F"), Key("G"),
         Key("H"), Key("J"), Key("K"), Key("L")],
        [Key("Z"), Key("X"), Key("C"), Key("V"),
         Key("B"), Key("N"), Key("M")],
        [Key("Space", title: ""), Key("Backspace", title: "⌫"), Key("Return", title: "↩")]
    ]

    // MARK: - Base layout constants (natural size at scale 1.0)

    private let baseKeyWidth:   CGFloat = 46
    private let baseKeyHeight:  CGFloat = 36
    private let baseKeySpacing: CGFloat = 4
    private let baseRowSpacing: CGFloat = 4
    private let basePadding:    CGFloat = 12
    private let baseFontSize:   CGFloat = 14

    // MARK: - Natural (unscaled) content size

    private lazy var naturalSize: NSSize = {
        let cols = rows[0].count
        let w = CGFloat(cols) * (baseKeyWidth + baseKeySpacing) - baseKeySpacing + basePadding * 2
        let h = CGFloat(rows.count) * (baseKeyHeight + baseRowSpacing) - baseRowSpacing + basePadding * 2
        return NSSize(width: w, height: h)
    }()

    // MARK: - Scale factor and scaled layout values

    private var scale: CGFloat {
        let w = view.bounds.width
        return w > 0 ? w / naturalSize.width : 1
    }

    private var keyWidth:    CGFloat { baseKeyWidth   * scale }
    private var keyHeight:   CGFloat { baseKeyHeight  * scale }
    private var keySpacing:  CGFloat { baseKeySpacing * scale }
    private var rowSpacing:  CGFloat { baseRowSpacing * scale }
    private var padding:     CGFloat { basePadding    * scale }
    private var keyFontSize: CGFloat { baseFontSize   * scale }
    private var spaceKeyWidth: CGFloat { keyWidth * 3 + keySpacing * 2 }

    // MARK: - Window state

    private let autosaveName   = "AllyKeyboardMain"
    private let hasLaunchedKey = "AllyKeyboard.hasLaunched"
    private var windowConfigured = false
    private var lastBuildSize:   NSSize = .zero

    // MARK: - Lifecycle

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        windowConfigured = true

        window.title = "AllyKeyboard"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        window.setContentAspectRatio(naturalSize)
        window.contentMinSize = NSSize(
            width:  naturalSize.width  * 0.5,
            height: naturalSize.height * 0.5
        )

        window.setFrameAutosaveName(autosaveName)

        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            window.setContentSize(naturalSize)
            window.center()
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard view.bounds.size != lastBuildSize else { return }
        lastBuildSize = view.bounds.size
        buildKeyboard()
    }

    // MARK: - Keyboard layout

    private func buildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let totalWidth = view.bounds.width - padding * 2

        for (rowIndex, row) in rows.enumerated() {
            let flippedRow = rows.count - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = row.reduce(0) { $0 + buttonWidth(for: $1) }
                         + CGFloat(row.count - 1) * keySpacing
            var x = padding + (totalWidth - rowWidth) / 2

            for key in row {
                let w   = buttonWidth(for: key)
                let btn = NSButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.title      = key.title
                btn.bezelStyle = .rounded
                btn.font       = NSFont.systemFont(ofSize: keyFontSize)
                btn.identifier = NSUserInterfaceItemIdentifier(key.id)
                btn.target     = self
                btn.action     = #selector(keyPressed(_:))
                view.addSubview(btn)
                x += w + keySpacing
            }
        }
    }

    private func buttonWidth(for key: Key) -> CGFloat {
        key.id == "Space" ? spaceKeyWidth : keyWidth
    }

    // MARK: - Actions

    @objc private func keyPressed(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else {
            assertionFailure("Key button missing identifier — fix buildKeyboard()")
            return
        }
        print("Key pressed: \(key)")
    }
}
