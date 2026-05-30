//
//  KeyButton.swift
//  AllyKeyboard
//

import Cocoa

/// Custom keyboard key with dark styling, hover highlight, and red press feedback.
final class KeyButton: NSButton {

    // MARK: - Colors

    private static let normalBg  = NSColor(white: 0.22, alpha: 1)   // #383838
    private static let hoverBg   = NSColor(white: 0.36, alpha: 1)   // #5C5C5C
    private static let pressedBg = NSColor(red: 0.72, green: 0.13, blue: 0.13, alpha: 1) // red
    private static let activeBg  = NSColor(red: 0.20, green: 0.45, blue: 0.80, alpha: 1) // blue (Shift on)

    // MARK: - State

    private var isHovered = false

    /// Set to true to show the key as "latched" (e.g. Shift active).
    var isActive = false {
        didSet { updateBackground() }
    }

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true

        isBordered = false
        font = NSFont.systemFont(ofSize: 14, weight: .medium)
        contentTintColor = .white

        updateBackground()
    }

    // MARK: - Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateBackground()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateBackground()
    }

    // MARK: - Press feedback

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        layer?.backgroundColor = flag ? Self.pressedBg.cgColor : nil
        if !flag { updateBackground() }
    }

    // MARK: - Background helper

    private func updateBackground() {
        if isActive {
            layer?.backgroundColor = Self.activeBg.cgColor
        } else if isHovered {
            layer?.backgroundColor = Self.hoverBg.cgColor
        } else {
            layer?.backgroundColor = Self.normalBg.cgColor
        }
    }
}
