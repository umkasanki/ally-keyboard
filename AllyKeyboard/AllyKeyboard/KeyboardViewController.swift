//
//  KeyboardViewController.swift
//  AllyKeyboard
//

import Cocoa

class KeyboardViewController: NSViewController {

    // QWERTY rows
    private let rows: [[String]] = [
        ["Q","W","E","R","T","Y","U","I","O","P"],
        ["A","S","D","F","G","H","J","K","L"],
        ["Z","X","C","V","B","N","M"],
        ["Space", "⌫", "↩"]
    ]

    private let keyWidth: CGFloat  = 46
    private let keyHeight: CGFloat = 36
    private let keySpacing: CGFloat = 4
    private let rowSpacing: CGFloat = 4
    private let padding: CGFloat = 10

    override func loadView() {
        let totalRows = rows.count
        let maxKeys = rows[0].count
        let width = CGFloat(maxKeys) * (keyWidth + keySpacing) - keySpacing + padding * 2
        let height = CGFloat(totalRows) * (keyHeight + rowSpacing) - rowSpacing + padding * 2

        view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildKeyboard()
    }

    private func buildKeyboard() {
        let totalRows = rows.count

        for (rowIndex, row) in rows.enumerated() {
            // Flip row index so row 0 is at bottom in macOS coordinate system
            let flippedRow = totalRows - 1 - rowIndex
            let y = padding + CGFloat(flippedRow) * (keyHeight + rowSpacing)

            // Center each row horizontally
            let rowWidth = CGFloat(row.count) * (keyWidth + keySpacing) - keySpacing
            let totalWidth = CGFloat(rows[0].count) * (keyWidth + keySpacing) - keySpacing
            let offsetX = padding + (totalWidth - rowWidth) / 2

            for (keyIndex, key) in row.enumerated() {
                let x = offsetX + CGFloat(keyIndex) * (keyWidth + keySpacing)

                // Special keys get wider
                var width = keyWidth
                if key == "Space" { width = keyWidth * 3 + keySpacing * 2 }

                let button = makeKeyButton(title: key, frame: NSRect(x: x, y: y, width: width, height: keyHeight))
                view.addSubview(button)
            }
        }
    }

    private func makeKeyButton(title: String, frame: NSRect) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = title == "Space" ? "" : title
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        button.target = self
        button.action = #selector(keyPressed(_:))
        return button
    }

    @objc private func keyPressed(_ sender: NSButton) {
        // Phase 2 will implement actual key sending
        print("Key pressed: \(sender.title)")
    }
}
