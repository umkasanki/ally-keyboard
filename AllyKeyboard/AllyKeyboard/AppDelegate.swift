//
//  AppDelegate.swift
//  AllyKeyboard
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var keyboardWindowController: KeyboardWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide from Dock and app switcher
        NSApp.setActivationPolicy(.accessory)

        // Create floating keyboard window
        keyboardWindowController = KeyboardWindowController()

        // NSPanel with .nonactivatingPanel requires orderFrontRegardless
        // to appear without the app becoming active
        keyboardWindowController?.window?.orderFrontRegardless()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
