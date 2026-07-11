import XCTest
import Foundation
@testable import AllyKeyboardCore

final class SettingsTests: XCTestCase {

    func testDefaults() {
        let s = Settings()
        XCTAssertEqual(s.sizePercent, 100)
        XCTAssertEqual(s.scale, Settings.baseScale, accuracy: 0.0001)   // 100% == base
    }

    func testScaleScalesWithPercent() {
        XCTAssertEqual(Settings(sizePercent: 200).scale, Settings.baseScale * 2, accuracy: 0.0001)
        XCTAssertEqual(Settings(sizePercent: 50).scale, Settings.baseScale * 0.5, accuracy: 0.0001)
    }

    func testPercentClampedOnInit() {
        XCTAssertEqual(Settings(sizePercent: 1000).sizePercent, 250)
        XCTAssertEqual(Settings(sizePercent: 10).sizePercent, 50)
    }

    func testPercentClampedOnMutation() {
        var s = Settings()
        s.sizePercent = 9999
        XCTAssertEqual(s.sizePercent, 250)
        s.sizePercent = -5
        XCTAssertEqual(s.sizePercent, 50)
    }

    func testStoreDefaultsWhenEmpty() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        XCTAssertEqual(store.load(), Settings())
    }

    func testStoreRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(sizePercent: 140)
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
