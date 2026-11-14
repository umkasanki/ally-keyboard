import XCTest
@testable import AllyKeyboardCore

final class KeyboardLayoutTests: XCTestCase {

    // MARK: The built-ins

    /// Every key's id (the one the app's behaviour reads) and width, row by row.
    /// Extended is the keyboard as it was built for its first user — checked
    /// key for key against ViewController's row arrays (2026-11-10). Change it
    /// only together with a deliberate change to the layout.
    private let expectedExtended: [[String]] = [
        ["Escape@1.5", "Hi", "AppSwitcher", "Screenshot", "@", "!", "?", ".", ",", "-", "+", "=", "Mute", "VolumeDown", "VolumeUp", "LangSwitch"],
        ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace@1.5", "Home", "Cmd+C"],
        ["Tab@1.5", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\", "PageUp", "Cmd+X"],
        ["CapsLock@1.75", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Return@1.75", "PageDown", "Cmd+V"],
        ["Shift@2.25", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "Shift@1.25", "ArrowUp", "End", "Cmd+Z"],
        ["Ctrl@1.5", "Alt@1.5", "Cmd@1.5", "Space@5.0", "Cmd@1.5", "HideKeyboard@1.5", "ArrowLeft", "ArrowDown", "ArrowRight", "Translate"],
    ]

    /// Standard, the default: Extended without the language key and the
    /// Home / Page Up / Page Down / End column (2026-11-14), Space one key
    /// narrower, Translate in front of the arrows.
    private let expectedStandard: [[String]] = [
        ["Escape@1.5", "Hi", "AppSwitcher", "Screenshot", "@", "!", "?", ".", ",", "-", "+", "=", "Mute", "VolumeDown", "VolumeUp"],
        ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace@1.5", "Cmd+C"],
        ["Tab@1.5", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\", "Cmd+X"],
        ["CapsLock@1.75", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Return@1.75", "Cmd+V"],
        ["Shift@2.25", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "Shift@1.25", "ArrowUp", "Cmd+Z"],
        ["Ctrl@1.5", "Alt@1.5", "Cmd@1.5", "Space@4.0", "Cmd@1.5", "HideKeyboard@1.5", "Translate", "ArrowLeft", "ArrowDown", "ArrowRight"],
    ]

    /// Standard Multilingual: the language key back, the screenshot key out.
    private let expectedStandardMultilingual: [[String]] = [
        ["Escape@1.5", "Hi", "AppSwitcher", "@", "!", "?", ".", ",", "-", "+", "=", "Mute", "VolumeDown", "VolumeUp", "LangSwitch"],
        ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=", "Backspace@1.5", "Cmd+C"],
        ["Tab@1.5", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]", "\\", "Cmd+X"],
        ["CapsLock@1.75", "A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'", "Return@1.75", "Cmd+V"],
        ["Shift@2.25", "Z", "X", "C", "V", "B", "N", "M", ",", ".", "/", "Shift@1.25", "ArrowUp", "Cmd+Z"],
        ["Ctrl@1.5", "Alt@1.5", "Cmd@1.5", "Space@4.0", "Cmd@1.5", "HideKeyboard@1.5", "Translate", "ArrowLeft", "ArrowDown", "ArrowRight"],
    ]

    private func ids(_ layout: KeyboardLayout) -> [[String]] {
        layout.rows.map { row in
            row.map { $0.width == 1 ? $0.action.legacyID : "\($0.action.legacyID)@\($0.width)" }
        }
    }

    func testExtendedIsTheKeyboardAsItHasBeen() {
        XCTAssertEqual(ids(.extended), expectedExtended)
    }

    func testStandardIsTheLeanDefault() {
        XCTAssertEqual(ids(.standard), expectedStandard)
    }

    func testStandardMultilingualKeepsTheLanguageKey() {
        XCTAssertEqual(ids(.standardMultilingual), expectedStandardMultilingual)
    }

    /// Where a key starts, in key widths from the left edge.
    private func start(of action: KeyAction, in row: [KeySpec]) -> Double {
        row.prefix { $0.action != action }.reduce(0) { $0 + $1.width }
    }

    func testEveryBuiltInHasEvenRowsAndUpAboveDown() {
        for layout in KeyboardLayout.builtIns {
            let widths = Set(layout.rows.map { $0.reduce(0) { $0 + $1.width } })
            XCTAssertEqual(widths.count, 1, "\(layout.name): rows of different widths \(widths)")
            let zxcv = layout.rows[4], bottom = layout.rows[5]
            XCTAssertEqual(start(of: .key(.arrowUp), in: zxcv), start(of: .key(.arrowDown), in: bottom),
                           "\(layout.name): ↑ is not above ↓")
        }
    }

    func testBuiltInsHaveFixedIDsAndNoProblems() {
        XCTAssertEqual(KeyboardLayout.builtIns.map(\.id),
                       [KeyboardLayout.standardID, KeyboardLayout.standardMultilingualID, KeyboardLayout.extendedID])
        XCTAssertEqual(KeyboardLayout.builtIns.map(\.name), ["Standard", "Standard Multilingual", "Extended"])
        XCTAssertEqual(Set(KeyboardLayout.builtIns.map(\.id)).count, 3)
        for layout in KeyboardLayout.builtIns { XCTAssertEqual(layout.problems, [], layout.name) }
    }

    func testKindsOfKey() {
        let rows = KeyboardLayout.extended.rows
        XCTAssertEqual(rows[0][4].action, .literal("@"))           // top-row punctuation types as is
        XCTAssertEqual(rows[1][1].action, .character("1"))         // follows the input layout
        XCTAssertEqual(rows[2][1].title, "q")
        XCTAssertEqual(rows[1][0].title, "~")
        XCTAssertEqual(rows[1][0].secondary, "`")
        XCTAssertEqual(rows[4][0].action, .modifier(.shift))
        XCTAssertEqual(rows[1][15].action, .shortcut(Shortcut(keyCode: 8, modifiers: [.command])))
        XCTAssertEqual(rows[1][15].icon, "copy-icon")
        XCTAssertTrue(rows[1][15].colored)
    }

    // MARK: Files

    func testALayoutSurvivesAFileRoundTrip() throws {
        let data = try JSONEncoder().encode(KeyboardLayout.standard)
        XCTAssertEqual(try JSONDecoder().decode(KeyboardLayout.self, from: data), KeyboardLayout.standard)
    }

    func testActionsAreWrittenReadably() throws {
        // Compared as text, not through JSONSerialization: the same on macOS
        // and on Linux, where the core tests also run.
        func json(_ a: KeyAction) throws -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return String(data: try encoder.encode(a), encoding: .utf8)!
        }
        XCTAssertEqual(try json(.character("Q")), #"{"type":"character","value":"Q"}"#)
        XCTAssertEqual(try json(.key(.returnKey)), #"{"type":"key","value":"Return"}"#)
        XCTAssertEqual(try json(.shortcut(Shortcut(keyCode: 8, modifiers: [.command]))),
                       #"{"keyCode":8,"modifiers":["Cmd"],"type":"shortcut"}"#)
        XCTAssertEqual(try json(.spacer), #"{"type":"spacer"}"#)
    }

    func testEveryKindOfActionRoundTrips() throws {
        let all: [KeyAction] = [.character("Q"), .literal("hi there"), .key(.tab), .modifier(.option),
                                .shortcut(Shortcut(keyCode: 1, modifiers: [.command, .shift])),
                                .media(.mute), .command(.nextLayout), .blank, .spacer]
        for a in all {
            XCTAssertEqual(try JSONDecoder().decode(KeyAction.self, from: JSONEncoder().encode(a)), a)
        }
    }

    func testAKeyWrittenByHandNeedsOnlyItsAction() throws {
        let key = try JSONDecoder().decode(KeySpec.self, from: Data(#"{"action":{"type":"key","value":"Space"}}"#.utf8))
        XCTAssertEqual(key, KeySpec(.key(.space)))
        XCTAssertEqual(key.width, 1)
        XCTAssertEqual(key.title, "Space")
        // And defaults are left out when written.
        let written = String(data: try JSONEncoder().encode(KeySpec(.key(.space))), encoding: .utf8)!
        XCTAssertFalse(written.contains("width"))
        XCTAssertFalse(written.contains("colored"))
    }

    func testAnUnknownActionIsRefusedNotGuessed() {
        let data = Data(#"{"type":"teleport"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(KeyAction.self, from: data))
    }

    // MARK: Ids the app reads

    func testLegacyIDsMatchTheAppsKeyIDs() {
        XCTAssertEqual(KeyAction.shortcut(Shortcut.named("Cmd+Z")!).legacyID, "Cmd+Z")
        XCTAssertEqual(KeyAction.modifier(.option).legacyID, "Alt")
        XCTAssertEqual(KeyAction.command(.phrases).legacyID, "Hi")
        XCTAssertEqual(KeyAction.spacer.legacyID, "__spacer__")
        // Spelled in macOS's own order, ⌃⌥⇧⌘, whatever order they came in.
        XCTAssertEqual(KeyAction.shortcut(Shortcut(keyCode: 1, modifiers: [.command, .shift])).legacyID,
                       "Shortcut(1,Shift+Cmd)")
    }

    func testKeysThatTypeNothingHaveNames() {
        // Apple's virtual key codes (Events.h): kVK_RightArrow 0x7C, kVK_Return
        // 0x24, kVK_F1 0x7A, kVK_Escape 0x35, kVK_Home 0x73.
        XCTAssertEqual(Shortcut.keyNames[0x7C], "\u{2192}")
        XCTAssertEqual(Shortcut.keyNames[0x24], "\u{21A9}")
        XCTAssertEqual(Shortcut.keyNames[0x7A], "F1")
        XCTAssertEqual(Shortcut.keyNames[0x35], "\u{238B}")
        XCTAssertEqual(Shortcut.keyNames[0x73], "\u{2196}")
        XCTAssertNil(Shortcut.keyNames[1])                     // S types a character
    }
}
