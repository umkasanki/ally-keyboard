import XCTest
@testable import AllyKeyboardCore

final class ActionKindTests: XCTestCase {

    /// Every palette entry lands in a kind whose list offers it, so the
    /// inspector opens on the key's own action.
    func testEveryPaletteActionIsOfferedByItsKind() {
        for group in ActionCatalog.groups {
            for choice in group.choices {
                let kind = ActionKind.of(choice.key.action)
                if !kind.choices.isEmpty {
                    XCTAssertTrue(kind.choices.contains { $0.key.action == choice.key.action }, "\(choice.name) in \(kind)")
                }
            }
        }
    }

    func testEveryBuiltInKeyHasAKind() {
        for layout in KeyboardLayout.builtIns + [.magicKeyboard(numericKeypad: true)] {
            for key in layout.rows.flatMap({ $0 }) {
                // Recorded chords are not on any list; every other listed kind is.
                let kind = ActionKind.of(key.action)
                if case .shortcut = key.action { continue }
                if !kind.choices.isEmpty {
                    XCTAssertTrue(kind.choices.contains { $0.key.action == key.action }, "\(key.action.legacyID)")
                }
            }
        }
    }

    func testEachKindStartsAsItself() {
        for kind in ActionKind.allCases {
            XCTAssertEqual(ActionKind.of(kind.start.action), kind, "\(kind)")
        }
    }

    func testMissionControlIsASystemEvent() {
        XCTAssertEqual(ActionKind.of(.command(.missionControl)), .system)
        XCTAssertEqual(ActionKind.of(.command(.screenshot)), .keyboard)
        XCTAssertEqual(ActionKind.of(.command(.languageSwitch)), .system)
        XCTAssertEqual(ActionKind.of(.media(.eject)), .system)
    }

    func testTheNewActionsSurviveAFile() throws {
        let actions: [KeyAction] = [
            .openApp("/System/Applications/Calculator.app"),
            .appleScript(#"display dialog "Hi""#),
            .runShortcut("Do Not Disturb"),
            .keySequence([Shortcut(keyCode: 4, modifiers: [.command]), Shortcut(keyCode: 23, modifiers: [.command, .shift])]),
        ]
        for a in actions {
            XCTAssertEqual(try JSONDecoder().decode(KeyAction.self, from: JSONEncoder().encode(a)), a)
        }
        let bad = Data(#"{"type":"keySequence","value":[{"keyCode":999,"modifiers":[]}]}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(KeyAction.self, from: bad))
    }

    func testTheNewActionsShowANameNotAnID() {
        XCTAssertEqual(KeySpec(.openApp("/System/Applications/Calculator.app")).title, "Calculator")
        XCTAssertEqual(KeySpec(.appleScript("beep")).title, "Script")
        XCTAssertEqual(KeySpec(.runShortcut("Do Not Disturb")).title, "Do Not Disturb")
        XCTAssertEqual(ActionKind.of(.runShortcut("x")), .runShortcut)
        XCTAssertEqual(KeySpec(.keySequence([Shortcut(keyCode: 4, modifiers: [.command])])).title, "Keys")
    }

    func testScriptKeysAreCounted() {
        let l = KeyboardLayout(name: "T", rows: [[KeySpec(.appleScript("beep")), KeySpec(.character("A"))],
                                                 [KeySpec(.appleScript("beep 2"))]])
        XCTAssertEqual(l.scriptKeyCount, 2)
        XCTAssertEqual(KeyboardLayout.extended.scriptKeyCount, 0)
    }
}
