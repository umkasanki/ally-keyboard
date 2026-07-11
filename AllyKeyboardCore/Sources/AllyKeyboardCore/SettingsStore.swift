//
//  SettingsStore.swift
//  AllyKeyboardCore
//
//  Persists `Settings` to `UserDefaults` (JSON-encoded). Foundation's
//  UserDefaults is available on Linux too, so this is unit-tested off-Mac.
//

import Foundation

public final class SettingsStore {

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "AllyKeyboard.settings") {
        self.defaults = defaults
        self.key = key
    }

    /// Load persisted settings, or defaults if none/undecodable.
    public func load() -> Settings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(Settings.self, from: data) else {
            return Settings()
        }
        return settings
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
