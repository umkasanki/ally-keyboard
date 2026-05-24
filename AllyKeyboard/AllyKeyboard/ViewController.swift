//
//  ViewController.swift
//  AllyKeyboard
//

import Cocoa

class ViewController: NSViewController {

    // MARK: - Layout constants
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

    private var keyboardBuilt = false

    // MARK: - View lifecycle

    override func viewWillAppear() {
        super.viewWillAppear()
        guard let window = view.window else { return }

        // 1. Resize window first
        let size = keyboardSize()
        window.setContentSize(size)
        window.title = "AllyKeyboard"
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.center()

        // 2. Build keyboard using actual view bounds after window resize
        if !keyboardBuilt {
            keyboardBuilt = true
            buildKeyboard(in: size)
        }
    }

    // MARK: - Keyboard layout

    private func keyboardSize() -> NSSize {
        let maxKeys = rows[0].count
        let w = CGFloat(maxKeys) * (keyWidth + keySpacing) - keySpacing + padding * 2
        let h = CGFloat(rows.count) * (keyHeight + rowSpacing) - rowSpacing + padding * 2
        return NSSize(width: w, height: h)
    }

    private func buildKeyboard(in size: NSSize) {
        // Remove any existing buttons
        view.subviews.forEach { $0.removeFromSuperview() }

        let totalWidth = size.width - padding * 2

        for (rowIndex, row) in rows.enumerated() {
            let flippedRow = rows.count - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            let rowWidth = row.reduce(0) { $0 + keyWidthFor($1.1) } + CGFloat(row.count - 1) * keySpacing
            var x = padding + (totalWidth - rowWidth) / 2

            for (title, key) in row {
                let w = keyWidthFor(key)
                let btn = NSButton(frame: NSRect(x: x, y: y, width: w, height: keyHeight))
                btn.title = title
                btn.bezelStyle = .rounded
                btn.font = NSFont.systemFont(ofSize: 14)
                btn.identifier = NSUserInterfaceItemIdentifier(key)
                btn.target = self
                btn.action = #selector(keyPressed(_:))
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
        let key = sender.identifier?.rawValue ?? sender.title
        print("Key pressed: \(key)")
    }
}
