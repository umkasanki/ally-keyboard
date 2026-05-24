//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

class ViewController: NSViewController {

    private let keyWidth: CGFloat   = 46
    private let keyHeight: CGFloat  = 36
    private let keySpacing: CGFloat = 4
    private let rowSpacing: CGFloat = 4
    private let padding: CGFloat    = 12

    private let rows: [[(String, String)]] = [
        [("Q","Q"),("W","W"),("E","E"),("R","R"),("T","T"),
         ("Y","Y"),("U","U"),("I","I"),("O","O"),("P","P")],
        [("A","A"),("S","S"),("D","D"),("F","F"),("G","G"),
         ("H","H"),("J","J"),("K","K"),("L","L")],
        [("Z","Z"),("X","X"),("C","C"),("V","V"),
         ("B","B"),("N","N"),("M","M")],
        [("","Space"),("⌫","Backspace"),("↩","Return")]
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Build keyboard here — viewDidLoad doesn't need a window,
        // and buildKeyboard() uses keyboardSize() not view.bounds.
        buildKeyboard()
    }

    private let autosaveName    = "AllyKeyboardMain"
    // Own flag avoids relying on AppKit's internal "NSWindow Frame X" key format.
    private let hasLaunchedKey  = "AllyKeyboard.hasLaunched"
    // Prevents running window setup more than once (viewWillAppear can fire on
    // every Space-switch / hide-show cycle).
    private var windowConfigured = false

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window, !windowConfigured else { return }
        windowConfigured = true

        window.title = "AllyKeyboard"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Register autosave name so AppKit saves/restores position automatically.
        window.setFrameAutosaveName(autosaveName)

        // Fix #2: always enforce the correct content size after frame restoration,
        // so a stale saved size from a previous build doesn't clip keys.
        window.setContentSize(keyboardSize())

        // Fix #3: use our own first-launch flag instead of AppKit's internal key.
        if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: hasLaunchedKey)
            window.center()
        }
    }

    // MARK: - Layout

    /// Returns the window content size that fits the keyboard exactly.
    private func keyboardSize() -> NSSize {
        let maxKeys = rows[0].count
        let w = CGFloat(maxKeys) * (keyWidth + keySpacing) - keySpacing + padding * 2
        let h = CGFloat(rows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2
        return NSSize(width: w, height: h)
    }

    /// Places key buttons using fixed geometry derived from keyboardSize().
    /// Never reads view.bounds — so it works correctly even before the
    /// window has been shown or resized.
    private func buildKeyboard() {
        view.subviews.forEach { $0.removeFromSuperview() }

        let kbSize     = keyboardSize()
        let totalWidth = kbSize.width - padding * 2

        for (rowIndex, row) in rows.enumerated() {
            // AppKit y=0 is at the bottom, so flip the row index.
            let flippedRow = rows.count - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = row.reduce(0) { $0 + keyWidthFor($1.1) }
                         + CGFloat(row.count - 1) * keySpacing
            var x = padding + (totalWidth - rowWidth) / 2

            for (title, key) in row {
                let w   = keyWidthFor(key)
                let btn = NSButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.title      = title
                btn.bezelStyle = .rounded
                btn.font       = NSFont.systemFont(ofSize: 14)
                btn.identifier = NSUserInterfaceItemIdentifier(key)
                btn.target     = self
                btn.action     = #selector(keyPressed(_:))
                view.addSubview(btn)
                x += w + keySpacing
            }
        }
    }

    private func keyWidthFor(_ key: String) -> CGFloat {
        key == "Space" ? keyWidth * 3 + keySpacing * 2 : keyWidth
    }

    // MARK: - Actions

    @objc private func keyPressed(_ sender: NSButton) {
        // identifier is always set in buildKeyboard(); guard here catches
        // any future code path that forgets to set it (Space title is "",
        // so sender.title fallback would silently send an empty key).
        guard let key = sender.identifier?.rawValue else {
            assertionFailure("Key button missing identifier — fix buildKeyboard()")
            return
        }
        print("Key pressed: \(key)")
    }
}

