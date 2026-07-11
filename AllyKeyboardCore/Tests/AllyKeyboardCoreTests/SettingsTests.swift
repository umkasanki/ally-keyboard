import XCTest
import Foundation
@testable import AllyKeyboardCore

final class SettingsTests: XCTestCase {

    func testDefaults() {
        XCTAssertEqual(Settings().sizePreset, .medium)
    }

    func testPresetScales() {
        XCTAssertEqual(Settings.SizePreset.small.scale, 1.2)
        XCTAssertEqual(Settings.SizePreset.medium.scale, 1.5)
        XCTAssertEqual(Settings.SizePreset.large.scale, 1.9)
    }

    func testStoreDefaultsWhenEmpty() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        XCTAssertEqual(store.load(), Settings())
    }

    func testStoreRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(sizePreset: .large)
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "test.allykeyboard.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }
}
