//
//  AppDelegate.swift
//  AllyKeyboard
//
//  Created by user945037 on 5/24/26.
//

import Cocoa
import AllyKeyboardCore

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    /// Held for the life of the process: the system may not throttle us (see below).
    private var activity: NSObjectProtocol?

    private var statusBar: StatusBarController!
    private var settingsWindow: SettingsWindowController?
    private var launcher: LauncherWindowController?

    // App Nap off, as AllyClicker and SmartNav Lite do. The keyboard has no Dock
    // icon and is never the active application — exactly what App Nap looks for —
    // and a napping app's events and timers are slowed and coalesced: a key that
    // lands late. The defaults key is the measured mechanism, read at launch, so it
    // is written as early as AppKit lets us; the activity is the documented one and
    // covers this launch too. Latency-critical keeps timers from being coalesced;
    // idle system sleep stays allowed, so the Mac still sleeps.
    func applicationWillFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(true, forKey: "NSAppSleepDisabled")
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "The on-screen keyboard is this user's only way to type and must not be throttled")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Enforce single instance: if another copy is already running, quit this one.
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Run as a menu-bar accessory: no Dock icon (controls live in the menu bar / launcher).
        NSApp.setActivationPolicy(.accessory)

        // Always dark, so the semantic system colors resolve to their dark variants.
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Request Accessibility permission needed for CGEvent key simulation.
        KeySender.requestAccessibilityIfNeeded()
        // Let go of a modifier left held down by anyone — see the guard itself.
        KeySender.startStuckModifierGuard()

        // Menu-bar entry: left click toggles the keyboard, right click opens the menu.
        statusBar = StatusBarController(
            onToggleKeyboard: { [weak self] in self?.togglePanel() },
            onOpenSettings: { [weak self] in self?.openSettings() })

        // Floating launcher shown while the keyboard is hidden; click brings it back.
        let s = SettingsStore().load()
        launcher = LauncherWindowController(width: CGFloat(s.launcherWidth),
                                            alpha: CGFloat(s.launcherAlpha)) { [weak self] in
            self?.showKeyboard()
        }

        // Start hidden when launched at login, or when "start collapsed" is enabled.
        if LoginItem.isEnabled || s.startCollapsed {
            DispatchQueue.main.async { [weak self] in self?.hideKeyboard(animated: false) }
        }
    }

    private func keyboardPanel() -> NSWindow? {
        NSApp.windows.first(where: { $0 is KeyboardPanel })
    }

    // MARK: - Show / hide animation

    /// How far below its place the keyboard starts (and ends) its slide: the
    /// display's height less the keyboard's, at the user's request 2026-11-01,
    /// after 36, 60, 120, 240 and 480 pt each read as too short.
    ///
    /// The slide goes through `setFrame(_:display:)`: an animator's
    /// `setFrameOrigin` does nothing at all — measured — so the keyboard was
    /// placed low for the slide and left there, a step lower on every show.
    private static let slideDuration: TimeInterval = 0.15
    /// Not linear: arriving, it starts fast and settles softly (ease-out quint);
    /// leaving, it gathers speed as it goes (ease-in), the way CSS slide-ins read.
    private static let showCurve = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
    private static let hideCurve = CAMediaTimingFunction(controlPoints: 0.55, 0, 1, 0.45)

    /// Where the keyboard rests while a show or hide is in flight, so that a
    /// toggle mid-way returns it to its real place, not to a point on the slide.
    private var restingOrigin: NSPoint?
    /// Bumped on every show/hide, so a hide that was overtaken by a show does
    /// not order the window out when its animation finishes.
    private var showHideGeneration = 0
    /// What the last show/hide asked for — the window's own state lags behind
    /// it while an animation runs: a keyboard fading out is still "visible".
    private var keyboardWanted: Bool?

    /// The effects are chosen in Settings → Animation; with neither, no animation.
    private var slides: Bool { keyboardViewController()?.currentShowHideSlide ?? true }
    private var fades: Bool { keyboardViewController()?.currentShowHideFade ?? true }
    private var animatesShowHide: Bool { slides || fades }

    /// The slide is motion, so Reduce Motion keeps only the fade.
    private func slideDistance(for panel: NSWindow) -> CGFloat {
        guard slides, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let screen = panel.screen ?? NSScreen.main else { return 0 }
        return max(0, screen.frame.height - panel.frame.height)
    }

    /// Show the keyboard and hide the floating launcher.
    func showKeyboard() {
        launcher?.hide()
        guard let panel = keyboardPanel() else { return }
        panel.animationBehavior = .none   // ours only; the system's own nudges the frame
        showHideGeneration += 1
        keyboardWanted = true
        let origin = restingOrigin ?? panel.frame.origin
        guard animatesShowHide else {
            restingOrigin = nil
            panel.setFrameOrigin(origin)
            panel.alphaValue = 1
            panel.orderFront(nil)
            return
        }
        restingOrigin = origin
        if !panel.isVisible {
            panel.alphaValue = fades ? 0 : 1
            panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y - slideDistance(for: panel)))
        }
        panel.orderFront(nil)
        let generation = showHideGeneration
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.slideDuration
            ctx.timingFunction = Self.showCurve
            if fades { panel.animator().alphaValue = 1 }
            panel.animator().setFrame(NSRect(origin: origin, size: panel.frame.size), display: true)
        }, completionHandler: { [weak self] in
            guard let self, self.showHideGeneration == generation else { return }
            self.restingOrigin = nil
        })
    }

    /// Hide the keyboard and show the floating launcher in its place.
    func hideKeyboard(animated: Bool = true) {
        launcher?.show()
        guard let panel = keyboardPanel() else { return }
        panel.animationBehavior = .none
        showHideGeneration += 1
        keyboardWanted = false
        let origin = restingOrigin ?? panel.frame.origin
        guard animated, animatesShowHide, panel.isVisible else {
            panel.orderOut(nil)
            panel.setFrameOrigin(origin)
            panel.alphaValue = 1
            restingOrigin = nil
            return
        }
        restingOrigin = origin
        let generation = showHideGeneration
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.slideDuration
            ctx.timingFunction = Self.hideCurve
            if fades { panel.animator().alphaValue = 0 }
            panel.animator().setFrame(NSRect(origin: NSPoint(x: origin.x, y: origin.y - slideDistance(for: panel)),
                                             size: panel.frame.size), display: true)
        }, completionHandler: { [weak self] in
            guard let self, self.showHideGeneration == generation else { return }
            // Out of sight, back to its place at full opacity, so the saved
            // frame and the next show both start from where the user left it.
            panel.orderOut(nil)
            panel.setFrameOrigin(origin)
            panel.alphaValue = 1
            self.restingOrigin = nil
        })
    }

    @objc private func togglePanel() {
        if keyboardWanted ?? (keyboardPanel()?.isVisible == true) { hideKeyboard() } else { showKeyboard() }
    }

    /// Apply a new launcher width live (called from Settings).
    func updateLauncherWidth(_ width: Int) { launcher?.setWidth(CGFloat(width)) }

    /// Apply a new launcher opacity live (called from Settings).
    func updateLauncherOpacity(_ percent: Int) { launcher?.setOpacity(CGFloat(percent) / 100.0) }

    /// The context menu shown on right-click (keyboard body / drag bar), matching the menu bar.
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Keyboard", action: #selector(togglePanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AllyKeyboard", action: #selector(quitApp), keyEquivalent: "").target = self
        return menu
    }

    @objc private func quitApp() { NSApp.terminate(nil) }

    // Never leave ⇧ held in the system behind us.
    func applicationWillTerminate(_ notification: Notification) {
        KeySender.holdShift(false)
    }

    // Left click on the Dock icon toggles the keyboard (show if hidden, hide if shown).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePanel()
        return true
    }

    // Right click (or click-hold) on the Dock icon shows this menu.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Keyboard", action: #selector(togglePanel), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: "").target = self
        return menu
    }

    private func keyboardViewController() -> ViewController? {
        NSApp.windows.first(where: { $0 is KeyboardPanel })?.contentViewController as? ViewController
    }

    @objc func openSettings() {
        guard let vc = keyboardViewController() else { return }
        let win = SettingsWindowController(
            currentPercent: vc.currentSizePercent,
            currentShowSuggestions: vc.currentShowSuggestions,
            currentSavedPhrases: vc.currentSavedPhrases,
            currentLearnWords: vc.currentLearnWords,
            currentLearnedWords: vc.currentLearnedWords,
            currentLauncherWidth: vc.currentLauncherWidth,
            currentLauncherOpacity: vc.currentLauncherOpacity,
            currentTopBarShow: vc.currentTopBarShow,
            currentTopBarHeight: vc.currentTopBarHeight,
            currentBottomBarShow: vc.currentBottomBarShow,
            currentBottomBarHeight: vc.currentBottomBarHeight,
            currentDragToMove: vc.currentDragToMove,
            currentDragCooldownMs: vc.currentDragCooldownMs,
            currentStartCollapsed: vc.currentStartCollapsed,
            currentShowHideSlide: vc.currentShowHideSlide,
            currentShowHideFade: vc.currentShowHideFade,
            currentTheme: vc.currentTheme,
            currentAppPanelIcon: vc.currentAppPanelIconSize,
            currentAppPanelOpacity: vc.currentAppPanelOpacity,
            currentAppPanelHidden: vc.currentAppPanelHiddenApps,
            currentAppPanelAutoHide: vc.currentAppPanelAutoHide,
            currentAppPanelHoverZoom: vc.currentAppPanelHoverZoom,
            currentAppPanelOutlineWidth: vc.currentAppPanelOutlineWidth,
            currentAppPanelOutlineGap: vc.currentAppPanelOutlineGap,
            currentAppPanelIconSpacing: vc.currentAppPanelIconSpacing,
            currentAppPanelEdgeSpacing: vc.currentAppPanelEdgeSpacing,
            onPercentChange: { [weak vc] percent in vc?.applySizePercent(percent) },
            onShowSuggestionsChange: { [weak vc] on in vc?.applyShowSuggestions(on) },
            onSavedPhrasesChange: { [weak vc] phrases in vc?.applySavedPhrases(phrases) },
            onLearnWordsChange: { [weak vc] on in vc?.applyLearnWords(on) },
            onLearnedWordsChange: { [weak vc] words in vc?.applyLearnedWords(words) },
            onLauncherWidthChange: { [weak vc] width in vc?.applyLauncherWidth(width) },
            onLauncherOpacityChange: { [weak vc] percent in vc?.applyLauncherOpacity(percent) },
            onTopBarHeightChange: { [weak vc] pt in vc?.applyTopBarHeight(pt) },
            onTopBarShowChange: { [weak vc] on in vc?.applyTopBarShow(on) },
            onBottomBarShowChange: { [weak vc] on in vc?.applyBottomBarShow(on) },
            onDragToMoveChange: { [weak vc] on in vc?.applyDragToMove(on) },
            onDragCooldownChange: { [weak vc] ms in vc?.applyDragCooldownMs(ms) },
            onBottomBarHeightChange: { [weak vc] pt in vc?.applyBottomBarHeight(pt) },
            onStartCollapsedChange: { [weak vc] on in vc?.applyStartCollapsed(on) },
            onShowHideSlideChange: { [weak vc] on in vc?.applyShowHideSlide(on) },
            onShowHideFadeChange: { [weak vc] on in vc?.applyShowHideFade(on) },
            onThemeChange: { [weak vc] raw in vc?.applyTheme(raw) },
            onAppPanelIconChange: { [weak vc] pt in vc?.applyAppPanelIconSize(pt) },
            onAppPanelOpacityChange: { [weak vc] percent in vc?.applyAppPanelOpacity(percent) },
            onAppPanelHiddenChange: { [weak vc] names in vc?.applyAppPanelHiddenApps(names) },
            onAppPanelAutoHideChange: { [weak vc] seconds in vc?.applyAppPanelAutoHide(seconds) },
            onAppPanelHoverZoomChange: { [weak vc] on in vc?.applyAppPanelHoverZoom(on) },
            onAppPanelOutlineWidthChange: { [weak vc] pt in vc?.applyAppPanelOutlineWidth(pt) },
            onAppPanelOutlineGapChange: { [weak vc] pt in vc?.applyAppPanelOutlineGap(pt) },
            onAppPanelIconSpacingChange: { [weak vc] pt in vc?.applyAppPanelIconSpacing(pt) },
            onAppPanelEdgeSpacingChange: { [weak vc] pt in vc?.applyAppPanelEdgeSpacing(pt) })
        settingsWindow = win
        win.present()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}


/// Menu-bar icon: left click toggles the keyboard, right/ctrl click opens the menu.
final class StatusBarController {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private let onToggleKeyboard: () -> Void
    private let onOpenSettings: () -> Void

    init(onToggleKeyboard: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onToggleKeyboard = onToggleKeyboard
        self.onOpenSettings = onOpenSettings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        menu.addItem(withTitle: "Show / Hide Keyboard", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettingsItem), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit AllyKeyboard", action: #selector(quit), keyEquivalent: "q").target = self

        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let img = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AllyKeyboard")?
                .withSymbolConfiguration(config)
            img?.isTemplate = true
            button.image = img
            // Left click toggles the keyboard; right/ctrl click opens the menu.
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let rightClick = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if rightClick {
            item.menu = menu
            item.button?.performClick(nil)   // pops the menu at the item
            item.menu = nil                  // keep left click as an action, not a menu
        } else {
            onToggleKeyboard()
        }
    }

    @objc private func toggle() { onToggleKeyboard() }
    @objc private func openSettingsItem() { onOpenSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
