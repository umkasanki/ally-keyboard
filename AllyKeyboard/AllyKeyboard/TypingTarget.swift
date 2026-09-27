//
//  TypingTarget.swift
//  AllyKeyboard
//

import Cocoa

/// The application a key press belongs to.
///
/// Normally there is nothing to remember: the keyboard is a non-activating panel,
/// AllyKeyboard is never the active application, and a synthetic event posted to
/// the HID tap lands in whatever *is* active. That stops being true the moment we
/// activate ourselves — which we do while the pointer is over the keyboard,
/// because macOS shows the cursor of the active application and of no other, so
/// that is the only way the pointer can stop being a text caret. With us active,
/// an event posted to the tap would come straight back to us, so it has to be
/// addressed to the application the user was last working in.
enum TypingTarget {

    /// The last application to become active that was not us. `nil` before the
    /// first switch, which is the ordinary case at login and costs nothing —
    /// delivery then falls back to the tap.
    private(set) static var pid: pid_t?

    private static var observer: NSObjectProtocol?

    static func startWatching() {
        guard observer == nil else { return }
        let centre = NSWorkspace.shared.notificationCenter
        // Whatever is frontmost right now counts, in case the keyboard is
        // launched into an existing session rather than at login.
        remember(NSWorkspace.shared.frontmostApplication)
        observer = centre.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                      object: nil, queue: .main) { note in
            remember(note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
    }

    private static func remember(_ app: NSRunningApplication?) {
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        pid = app.processIdentifier
    }

    /// Give the front back to the application being typed into. Called when the
    /// pointer leaves the keyboard, so the document regains its caret and its
    /// selection highlight the moment the user looks away from the keys.
    static func handBack() {
        guard let pid, NSApp.isActive else { return }
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    /// Take the front, so the pointer's shape becomes ours to choose.
    static func takeFront() {
        guard !NSApp.isActive else { return }
        NSApp.activate(ignoringOtherApps: true)
    }
}
