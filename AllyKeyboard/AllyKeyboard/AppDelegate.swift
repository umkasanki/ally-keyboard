//
//  AppDelegate.swift
//  AllyKeyboard
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var keyboardWindowController: KeyboardWindowController?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide from Dock and app switcher (equivalent to LSUIElement = YES)
        NSApp.setActivationPolicy(.accessory)

        // Create and show floating keyboard window
        keyboardWindowController = KeyboardWindowController()
        keyboardWindowController?.showWindow(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
