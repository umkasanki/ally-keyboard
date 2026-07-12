import XCTest
import Foundation
@testable import AllyKeyboardCore

final class SettingsTests: XCTestCase {

    func testDefaults() {
        let s = Settings()
        XCTAssertEqual(s.sizePercent, 100)
        XCTAssertTrue(s.showSuggestions)
        XCTAssertEqual(s.scale, Settings.baseScale, accuracy: 0.0001)   // 100% == base
    }

    func testDefaultSavedPhrases() {
        XCTAssertEqual(Settings().savedPhrases, Settings.defaultGreetings)
        XCTAssertEqual(Settings.defaultGreetings.count, 5)
    }

    func testSavedPhrasesRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(savedPhrases: ["Hi", "Bye"])
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testDecodesLegacyWithoutSavedPhrases() throws {
        let json = Data(#"{"sizePercent":100,"showSuggestions":true}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.savedPhrases, Settings.defaultGreetings)
    }

    func testShowSuggestionsRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(sizePercent: 100, showSuggestions: false)
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testDecodesLegacyWithoutShowSuggestions() throws {
        let json = Data(#"{"sizePercent":120}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.sizePercent, 120)
        XCTAssertTrue(s.showSuggestions)   // defaults to true when the key is absent
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

    func testLauncherDefaults() {
        let s = Settings()
        XCTAssertEqual(s.launcherWidth, 50)
        XCTAssertEqual(s.launcherOpacityPercent, 100)
        XCTAssertEqual(s.launcherAlpha, 1.0, accuracy: 0.0001)
    }

    func testLauncherClampedOnInit() {
        XCTAssertEqual(Settings(launcherWidth: 5).launcherWidth, 30)
        XCTAssertEqual(Settings(launcherWidth: 999).launcherWidth, 200)
        XCTAssertEqual(Settings(launcherOpacityPercent: 0).launcherOpacityPercent, 20)
        XCTAssertEqual(Settings(launcherOpacityPercent: 500).launcherOpacityPercent, 100)
    }

    func testLauncherClampedOnMutation() {
        var s = Settings()
        s.launcherWidth = 9999
        XCTAssertEqual(s.launcherWidth, 200)
        s.launcherOpacityPercent = -1
        XCTAssertEqual(s.launcherOpacityPercent, 20)
    }

    func testLauncherRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(launcherWidth: 80, launcherOpacityPercent: 60)
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testDecodesLegacyWithoutLauncherKeys() throws {
        let json = Data(#"{"sizePercent":100,"showSuggestions":true}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.launcherWidth, 50)
        XCTAssertEqual(s.launcherOpacityPercent, 100)
    }

    func testTopBarDefaultAndClamp() {
        XCTAssertEqual(Settings().topBarHeight, 28)
        XCTAssertEqual(Settings(topBarHeight: 5).topBarHeight, 20)
        XCTAssertEqual(Settings(topBarHeight: 99).topBarHeight, 40)
        var s = Settings()
        s.topBarHeight = 1000
        XCTAssertEqual(s.topBarHeight, 40)
    }

    func testTopBarRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(topBarHeight: 32)
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testDecodesLegacyWithoutTopBar() throws {
        let json = Data(#"{"sizePercent":100}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertEqual(s.topBarHeight, 28)
    }

    func testBottomBarDefaultsAndClamp() {
        XCTAssertEqual(Settings().bottomBarHeight, 28)
        XCTAssertTrue(Settings().bottomBarShow)
        XCTAssertEqual(Settings(bottomBarHeight: 5).bottomBarHeight, 20)
        XCTAssertEqual(Settings(bottomBarHeight: 99).bottomBarHeight, 40)
        var s = Settings()
        s.bottomBarHeight = 1000
        XCTAssertEqual(s.bottomBarHeight, 40)
    }

    func testBottomBarRoundTrip() {
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(bottomBarShow: false, bottomBarHeight: 34)
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testDecodesLegacyWithoutBottomBar() throws {
        let json = Data(#"{"sizePercent":100}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertTrue(s.bottomBarShow)
        XCTAssertEqual(s.bottomBarHeight, 28)
    }

    func testStartCollapsedDefaultAndRoundTrip() {
        XCTAssertFalse(Settings().startCollapsed)
        let store = SettingsStore(defaults: freshDefaults(), key: "s")
        let settings = Settings(startCollapsed: true)
        store.save(settings)
        XCTAssertEqual(store.load(), settings)
    }

    func testDecodesLegacyWithoutStartCollapsed() throws {
        let json = Data(#"{"sizePercent":100}"#.utf8)
        let s = try JSONDecoder().decode(Settings.self, from: json)
        XCTAssertFalse(s.startCollapsed)
    }

    private func freshDefaults() -> UserDefaults {
        let name = "test.allykeyboard.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }
}
