//
//  LoginItem.swift
//  AllyKeyboard
//
//  Launch-at-login via SMAppService (macOS 13+). The system persists the state,
//  so we read/write it directly rather than storing it in our own settings.
//

import Foundation
import ServiceManagement

enum LoginItem {

    static var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    /// Enable/disable launch at login. Returns false if the system rejected it.
    @discardableResult
    static func setEnabled(_ on: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if on {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else {
                if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            }
            return true
        } catch {
            NSLog("AllyKeyboard: login-item toggle failed: \(error)")
            return false
        }
    }
}
