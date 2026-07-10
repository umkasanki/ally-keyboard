//
//  SuggestionBarView.swift
//  AllyKeyboard
//
//  A vertical column of clickable word suggestions, drawn as a speech-balloon
//  with a triangular tail pointing at the keyboard. Rows reuse KeyButton and
//  blend into the keyboard background (flat list, highlight on hover).
//

import AppKit

final class SuggestionBarView: NSView {

    /// Called with the chosen suggestion when a button is clicked.
    var onSelect: ((String) -> Void)?

    private let maxSlots: Int
    private let spacing: CGFloat
    private let fontSize: CGFloat
    private var buttons: [KeyButton] = []

    init(frame: NSRect, maxSlots: Int, spacing: CGFloat, fontSize: CGFloat) {
        self.maxSlots = maxSlots
        self.spacing = spacing
        self.fontSize = fontSize
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// - Parameters:
    ///   - tailOnTop: tail points up (panel docked below the keyboard) vs down.
    ///   - tailHeight: height of the triangular tail strip.
    func setSuggestions(_ words: [String], prefixLength: Int, tailOnTop: Bool, tailHeight: CGFloat, cornerRadius: CGFloat) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = []

        let bodyRect = applyBalloonMask(tailOnTop: tailOnTop, tailHeight: tailHeight, cornerRadius: cornerRadius)

        let items = Array(words.prefix(maxSlots))
        guard !items.isEmpty else { return }

        let n = items.count
        let leftPadding = fontSize * 0.6
        let rowH = (bodyRect.height - spacing * CGFloat(n - 1)) / CGFloat(n)

        let para = NSMutableParagraphStyle()
        para.alignment = .left
        para.firstLineHeadIndent = leftPadding
        para.headIndent = leftPadding
        para.lineBreakMode = .byTruncatingTail

        for (i, word) in items.enumerated() {
            let y = bodyRect.maxY - rowH * CGFloat(i + 1) - spacing * CGFloat(i)
            let btn = KeyButton(frame: NSRect(x: bodyRect.minX, y: y, width: bodyRect.width, height: rowH))
            btn.identifier = NSUserInterfaceItemIdentifier(word)
            let attr = NSMutableAttributedString(string: word, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor(white: 1, alpha: 0.45),   // completion is dimmed
                .paragraphStyle: para,
            ])
            let ns = word as NSString
            let bright = max(0, min(prefixLength, ns.length))        // already-typed prefix stays bright
            if bright > 0 {
                attr.addAttribute(.foregroundColor, value: NSColor.white,
                                  range: NSRange(location: 0, length: bright))
            }
            btn.attributedTitle = attr
            btn.normalColorOverride = AppConfig.Colors.keyboardBg
            btn.layer?.cornerRadius = 0
            btn.target = self
            btn.action = #selector(tapped(_:))
            addSubview(btn)
            buttons.append(btn)
        }
    }

    /// Masks the layer to a rounded-rect body plus a triangular tail, filled with
    /// the keyboard background. Returns the body rect (where rows are laid out).
    private func applyBalloonMask(tailOnTop: Bool, tailHeight: CGFloat, cornerRadius: CGFloat) -> NSRect {
        let w = bounds.width, h = bounds.height
        let midX = w * 0.5
        let halfBase = tailHeight * 1.5   // wider than tall reads better as a pointer

        let bodyRect: NSRect
        let tail = NSBezierPath()
        if tailOnTop {
            bodyRect = NSRect(x: 0, y: 0, width: w, height: h - tailHeight)
            let baseY = h - tailHeight
            tail.move(to: NSPoint(x: midX - halfBase, y: baseY))
            tail.line(to: NSPoint(x: midX, y: h))
            tail.line(to: NSPoint(x: midX + halfBase, y: baseY))
        } else {
            bodyRect = NSRect(x: 0, y: tailHeight, width: w, height: h - tailHeight)
            let baseY = tailHeight
            tail.move(to: NSPoint(x: midX - halfBase, y: baseY))
            tail.line(to: NSPoint(x: midX, y: 0))
            tail.line(to: NSPoint(x: midX + halfBase, y: baseY))
        }
        tail.close()

        let path = NSBezierPath(roundedRect: bodyRect, xRadius: cornerRadius, yRadius: cornerRadius)
        path.append(tail)

        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer?.mask = mask
        layer?.backgroundColor = AppConfig.Colors.keyboardBg.cgColor
        return bodyRect
    }

    @objc private func tapped(_ sender: NSButton) {
        guard let word = sender.identifier?.rawValue else { return }
        onSelect?(word)
    }
}
