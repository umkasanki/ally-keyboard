import XCTest
@testable import AllyKeyboardCore

final class ActionCatalogTests: XCTestCase {

    private var all: [ActionChoice] { ActionCatalog.groups.flatMap(\.choices) }

    func testEveryActionTheBuiltInsUseIsOnThePalette() {
        // Whatever a built-in key does, a user can give it to a key of their own.
        let offered = Set(all.map(\.key.action))
        for layout in KeyboardLayout.builtIns {
            for key in layout.rows.joined() {
                XCTAssertTrue(offered.contains(key.action), "\(layout.name): \(key.action) is not on the palette")
            }
        }
    }

    func testNoEntryAppearsTwiceInATab() {
        for group in ActionCatalog.groups {
            XCTAssertEqual(Set(group.choices.map(\.key.action)).count, group.choices.count, group.title)
        }
    }

    func testEveryKeyboardCommandIsOffered() {
        let offered = Set(all.map(\.key.action))
        for command in Command.allCases { XCTAssertTrue(offered.contains(.command(command)), "\(command)") }
        for key in SpecialKey.allCases { XCTAssertTrue(offered.contains(.key(key)), "\(key)") }
        for m in Modifier.allCases { XCTAssertTrue(offered.contains(.modifier(m)), "\(m)") }
        for m in MediaKey.allCases { XCTAssertTrue(offered.contains(.media(m)), "\(m)") }
    }

    func testThePaletteShortcutsTheKeyboardNamesKeepTheirNames() {
        // Copy, Paste, Cut, Undo, Select All go out as the keyboard's named
        // chords, so the smart space and the word tracker know them.
        let names = Set(all.compactMap { choice -> String? in
            if case .shortcut(let s) = choice.key.action, Shortcut.named(s.legacyID) != nil { return s.legacyID }
            return nil
        })
        XCTAssertEqual(names, Set(Shortcut.named.keys))
    }

    func testAssigningKeepsWidthAndFontButTakesTheLook() {
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [[KeySpec(.character("Q"), label: "q",
                                                                               width: 2, fontScale: 1.25)]]))
        e.select(KeyPosition(row: 0, index: 0))
        let copy = ActionCatalog.groups.first { $0.title == "Shortcuts" }!.choices.first { $0.name == "Copy" }!
        e.assign(copy)
        XCTAssertEqual(e.selectedKey?.action, .shortcut(Shortcut.named("Cmd+C")!))
        XCTAssertEqual(e.selectedKey?.icon, "copy-icon")
        XCTAssertTrue(e.selectedKey?.colored ?? false)
        XCTAssertNil(e.selectedKey?.label)                  // the old "q" goes with the old action
        XCTAssertEqual(e.selectedKey?.width, 2)
        XCTAssertEqual(e.selectedKey?.fontScale, 1.25)
        e.undo()
        XCTAssertEqual(e.selectedKey?.label, "q")
    }
}
