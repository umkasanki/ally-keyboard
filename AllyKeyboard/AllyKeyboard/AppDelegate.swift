//
//  AppDelegate.swift
//  AllyKeyboard
//
//  Created by user945037 on 5/24/26.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Enforce single instance: if another copy is already running, quit this one.
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
            NSApp.terminate(nil)
            return
        }

        // Hide from Dock — this is an accessory (floating keyboard) app.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
