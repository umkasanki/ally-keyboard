//
//  AppDelegate.swift
//  AllyKeyboard
//
//  Created by user945037 on 5/24/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set .accessory policy HERE, before any window is shown,
        // so the Dock icon never flashes on launch.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Enforce single instance: if another copy is already running, quit this one.
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Request Accessibility permission needed for CGEvent key simulation.
        KeySender.requestAccessibilityIfNeeded()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
