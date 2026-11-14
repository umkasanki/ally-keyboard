import XCTest
@testable import AllyKeyboardCore

final class LayoutEditorTests: XCTestCase {

    private let a = KeySpec(.character("A")), b = KeySpec(.character("B")), c = KeySpec(.character("C"))
    private let space = KeySpec(.key(.space), width: 3)

    /// Two rows: A B C / Space(3).
    private func editor() -> LayoutEditor {
        LayoutEditor(layout: KeyboardLayout(name: "Test", rows: [[a, b, c], [space]]))
    }

    private func names(_ e: LayoutEditor) -> [[String]] {
        e.layout.rows.map { $0.map(\.action.legacyID) }
    }

    private func p(_ row: Int, _ index: Int) -> KeyPosition { KeyPosition(row: row, index: index) }

    // MARK: Selection

    func testSelectingAKeyAndNothing() {
        let e = editor()
        e.select(p(0, 1))
        XCTAssertEqual(e.selectedKey, b)
        e.select(p(5, 0))                                   // no such key
        XCTAssertNil(e.selection)
        e.select(nil)
        XCTAssertNil(e.selectedKey)
    }

    func testEditsWithNothingSelectedDoNothing() {
        let e = editor()
        e.setAction(.key(.tab)); e.moveAlongRow(by: 1); e.deleteKey(); e.insertKey(after: true)
        XCTAssertFalse(e.hasUnsavedChanges)
        XCTAssertFalse(e.canUndo)
    }

    // MARK: The selected key

    func testAssigningAnActionAndLabels() {
        let e = editor(); e.select(p(0, 0))
        e.setAction(.shortcut(Shortcut.named("Cmd+C")!))
        e.setLabel("Copy"); e.setSecondary("⌘C"); e.setIcon("copy-icon"); e.setColored(true)
        XCTAssertEqual(e.selectedKey, KeySpec(.shortcut(Shortcut.named("Cmd+C")!), label: "Copy",
                                              secondary: "⌘C", icon: "copy-icon", colored: true))
        e.setLabel(""); e.setIcon("")                       // empty clears
        XCTAssertNil(e.selectedKey?.label)
        XCTAssertNil(e.selectedKey?.icon)
    }

    func testWidthAndFontMoveInQuarterStepsWithinLimits() {
        let e = editor(); e.select(p(0, 0))
        e.adjustWidth(by: 2)
        XCTAssertEqual(e.selectedKey?.width, 1.5)
        e.setWidth(1.33)
        XCTAssertEqual(e.selectedKey?.width, 1.25)          // snapped to a quarter
        e.adjustWidth(by: -10)
        XCTAssertEqual(e.selectedKey?.width, 0.5)           // the narrowest
        e.setWidth(50)
        XCTAssertEqual(e.selectedKey?.width, 10)            // the widest
        e.adjustFontScale(by: 1)
        XCTAssertEqual(e.selectedKey?.fontScale, 1.25)
        e.setFontScale(0.1)
        XCTAssertEqual(e.selectedKey?.fontScale, 0.5)
    }

    func testRenamingIgnoresAnEmptyName() {
        let e = editor()
        e.rename("  Mine  ")
        XCTAssertEqual(e.layout.name, "Mine")
        e.rename("   ")
        XCTAssertEqual(e.layout.name, "Mine")
    }

    // MARK: Structure

    func testMovingAlongARowCarriesTheSelection() {
        let e = editor(); e.select(p(0, 0))
        e.moveAlongRow(by: 1)
        XCTAssertEqual(names(e)[0], ["B", "A", "C"])
        XCTAssertEqual(e.selection, p(0, 1))
        e.moveAlongRow(by: 1); e.moveAlongRow(by: 1)        // the second goes nowhere: end of row
        XCTAssertEqual(names(e)[0], ["B", "C", "A"])
        XCTAssertEqual(e.selection, p(0, 2))
    }

    func testMovingToAnotherRowLandsUnderItsOwnPlace() {
        // Row 0: A B C (starts 0, 1, 2); row 1: X(1) Y(1) Z(1).
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [
            [a, b, c], [KeySpec(.character("X")), KeySpec(.character("Y")), KeySpec(.character("Z"))],
        ]))
        e.select(p(0, 2))                                   // C, starting at 2
        e.moveToRow(by: 1)
        XCTAssertEqual(names(e), [["A", "B"], ["X", "Y", "C", "Z"]])
        XCTAssertEqual(e.selection, p(1, 2))
        e.moveToRow(by: 1)                                  // no row below: nothing
        XCTAssertEqual(e.selection, p(1, 2))
    }

    func testMovingTheLastKeyOutOfARowRemovesTheRow() {
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [[a], [b, c], [space]]))
        e.select(p(0, 0))
        e.moveToRow(by: 1)
        XCTAssertEqual(names(e), [["A", "B", "C"], ["Space"]])
        XCTAssertEqual(e.selection, p(0, 0))
        XCTAssertEqual(e.selectedKey, a)
    }

    func testSwapExchangesTwoKeysAnywhere() {
        let e = editor(); e.select(p(0, 0))
        e.swapSelected(with: p(1, 0))
        XCTAssertEqual(names(e), [["Space", "B", "C"], ["A"]])
        XCTAssertEqual(e.selection, p(1, 0))                // the selection follows A
        XCTAssertEqual(e.selectedKey, a)
    }

    func testInsertAddsABlankKeyAndSelectsIt() {
        let e = editor(); e.select(p(0, 1))
        e.insertKey(after: true)
        XCTAssertEqual(names(e)[0], ["A", "B", "Blank", "C"])
        XCTAssertEqual(e.selection, p(0, 2))
        e.insertKey(after: false)
        XCTAssertEqual(names(e)[0], ["A", "B", "Blank", "Blank", "C"])
        XCTAssertEqual(e.selection, p(0, 2))
    }

    func testDeleteSelectsTheNextKeyAndDropsAnEmptyRow() {
        let e = editor(); e.select(p(0, 2))
        e.deleteKey()
        XCTAssertEqual(names(e)[0], ["A", "B"])
        XCTAssertEqual(e.selection, p(0, 1))                // the one before, at the end
        e.select(p(1, 0))
        e.deleteKey()                                       // Space was alone in its row
        XCTAssertEqual(names(e), [["A", "B"]])
        XCTAssertNil(e.selection)
    }

    func testAddingAndDeletingRows() {
        let e = editor(); e.select(p(0, 0))
        e.addRow(below: true)
        XCTAssertEqual(names(e), [["A", "B", "C"], ["Blank"], ["Space"]])
        XCTAssertEqual(e.selection, p(1, 0))
        e.deleteRow()
        XCTAssertEqual(names(e), [["A", "B", "C"], ["Space"]])
        XCTAssertNil(e.selection)
        e.addRow(below: false)                              // nothing selected: at the bottom
        XCTAssertEqual(names(e).last, ["Blank"])
    }

    // MARK: Undo, saving

    func testUndoAndRedoRestoreTheSelectionToo() {
        let e = editor(); e.select(p(0, 0))
        e.moveAlongRow(by: 1)
        e.setLabel("first")
        e.undo()
        XCTAssertNil(e.selectedKey?.label)
        e.undo()
        XCTAssertEqual(names(e)[0], ["A", "B", "C"])
        XCTAssertEqual(e.selection, p(0, 0))
        XCTAssertFalse(e.canUndo)
        e.redo(); e.redo()
        XCTAssertEqual(e.selectedKey?.label, "first")
        XCTAssertEqual(e.selection, p(0, 1))
    }

    func testANewEditClearsRedoAndANoOpIsNotRecorded() {
        let e = editor(); e.select(p(0, 0))
        e.setLabel("x"); e.undo()
        XCTAssertTrue(e.canRedo)
        e.setLabel("y")
        XCTAssertFalse(e.canRedo)
        e.setLabel("y")                                     // the same again: not a step
        e.undo()
        XCTAssertNil(e.selectedKey?.label)
    }

    func testSavingAndReverting() {
        let e = editor(); e.select(p(0, 0))
        e.setLabel("x")
        XCTAssertTrue(e.hasUnsavedChanges)
        e.markSaved()
        XCTAssertFalse(e.hasUnsavedChanges)
        e.setLabel("y"); e.deleteKey()
        e.revert()
        XCTAssertEqual(e.layout.rows[0][0].label, "x")      // back to what was saved
        XCTAssertFalse(e.hasUnsavedChanges)
        e.undo()                                            // and the revert itself can be undone
        XCTAssertEqual(names(e)[0], ["B", "C"])
    }

    // MARK: Problems

    func testProblemsIncludeUnevenRows() {
        let e = editor()
        XCTAssertEqual(e.rowWidths, [3, 3])
        XCTAssertFalse(e.problems.contains { if case .unevenRows = $0 { return true }; return false })
        e.select(p(1, 0)); e.adjustWidth(by: 2)
        XCTAssertTrue(e.problems.contains(.unevenRows([3, 3.5])))
        XCTAssertTrue(e.problems.contains(.layout(.missing(.backspace))))
    }

    func testALayoutWithNoKeysCannotBeSaved() {
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [[a]]))
        e.select(p(0, 0)); e.deleteKey()
        XCTAssertFalse(e.canSave)
        XCTAssertTrue(e.problems.contains(.layout(.noKeys)))
        // The one problem that stops a save is the one called an error.
        XCTAssertEqual(e.problems.filter(\.isError), [.layout(.noKeys)])
        XCTAssertFalse(LayoutEditor.Problem.layout(.missing(.space)).isError)
        XCTAssertFalse(LayoutEditor.Problem.unevenRows([3, 3.5]).isError)
    }

    func testTheBuiltInsCanBeEditedWithoutProblems() {
        for layout in KeyboardLayout.builtIns {
            XCTAssertEqual(LayoutEditor(layout: layout).problems, [], layout.name)
        }
    }

    func testANewKeyFillsTheFirstRowWithRoomForIt() {
        // Widths 1.5, 1, 2: row 0 is half a key short — too little for a
        // key of width 1 — row 1 a whole key short, so the key goes there.
        let half = KeySpec(.character("H"), width: 0.5)
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [[b, half], [a], [b, c]]))
        e.addKey(KeySpec(.character("N")))
        XCTAssertEqual(names(e), [["B", "H"], ["A", "N"], ["B", "C"]])
        XCTAssertEqual(e.selection, p(1, 1))
    }

    func testANewKeyTooWideForAnyGapGoesToTheLastRow() {
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [[a], [b, c]]))
        e.addKey(KeySpec(.character("N"), width: 2))
        XCTAssertEqual(names(e), [["A"], ["B", "C", "N"]])
        XCTAssertEqual(e.selection, p(1, 2))
    }
}

final class LayoutGeometryTests: XCTestCase {

    func testTheDefaultsAreTheKeyboardsSizes() {
        let g = KeyboardLayout.Geometry()
        XCTAssertEqual([g.keyWidth, g.keyHeight, g.keySpacing, g.rowSpacing, g.padding], [36, 32, 3, 3, 8])
        for layout in KeyboardLayout.builtIns { XCTAssertEqual(layout.geometry, g, layout.name) }
    }

    func testAFileWithoutSizesTakesTheDefaults() throws {
        let json = #"{"id":"\#(UUID().uuidString)","name":"Old","rows":[[{"action":{"type":"key","value":"Space"}}]]}"#
        let layout = try JSONDecoder().decode(KeyboardLayout.self, from: Data(json.utf8))
        XCTAssertEqual(layout.geometry, KeyboardLayout.Geometry())
        XCTAssertEqual(layout.formatVersion, KeyboardLayout.currentFormatVersion)
    }

    func testSizesSurviveAFile() throws {
        var layout = KeyboardLayout.standard
        layout.geometry.keyHeight = 48
        layout.geometry.padding = 12
        XCTAssertEqual(try JSONDecoder().decode(KeyboardLayout.self, from: JSONEncoder().encode(layout)), layout)
    }

    func testEditingSizesInWholePointsWithinRangeAndUndoable() {
        let e = LayoutEditor(layout: .standard)
        e.adjustGeometry(.keyHeight, by: 4)
        XCTAssertEqual(e.layout.geometry.keyHeight, 36)
        e.setGeometry(.keySpacing, to: 2.6)
        XCTAssertEqual(e.layout.geometry.keySpacing, 3)       // whole points
        e.setGeometry(.padding, to: -5)
        XCTAssertEqual(e.layout.geometry.padding, 0)          // within range
        e.setGeometry(.keyWidth, to: 500)
        XCTAssertEqual(e.layout.geometry.keyWidth, 96)
        e.undo()
        XCTAssertEqual(e.layout.geometry.keyWidth, 36)
        XCTAssertEqual(e.value(of: .keyHeight), 36)
    }

    func testAddingAKeyRightOfTheSelectedOneOrAtTheEnd() {
        let a = KeySpec(.character("A")), b = KeySpec(.character("B"))
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [[a, b], [a]]))
        e.addKey(KeySpec(.character("X")))                   // nothing selected: end of the last row
        XCTAssertEqual(e.layout.rows[1].map(\.action.legacyID), ["A", "X"])
        XCTAssertEqual(e.selection, KeyPosition(row: 1, index: 1))
        e.select(KeyPosition(row: 0, index: 0))
        e.addKey(KeySpec(.character("Y"), width: 40))        // width kept in range
        XCTAssertEqual(e.layout.rows[0].map(\.action.legacyID), ["A", "Y", "B"])
        XCTAssertEqual(e.selectedKey?.width, 10)
        let empty = LayoutEditor(layout: KeyboardLayout(name: "E", rows: []))
        empty.addKey(KeySpec(.key(.space)))
        XCTAssertEqual(empty.layout.rows.count, 1)
    }

    func testDoneOnAnUntouchedBuiltInKeyChangesNothing() {
        let e = LayoutEditor(layout: .extended)
        for (r, row) in KeyboardLayout.extended.rows.enumerated() {
            for i in row.indices {
                e.select(KeyPosition(row: r, index: i))
                e.replaceSelectedKey(with: e.selectedKey!)
            }
        }
        XCTAssertEqual(e.layout, .extended)
        XCTAssertFalse(e.hasUnsavedChanges)
    }

    func testReplacingTheSelectedKeyIsOneStep() {
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [[KeySpec(.character("A"), label: "a")]]))
        e.select(KeyPosition(row: 0, index: 0))
        e.replaceSelectedKey(with: KeySpec(.key(.tab), label: "Tab", width: 1.5, fontScale: 0.7))
        XCTAssertEqual(e.selectedKey, KeySpec(.key(.tab), label: "Tab", width: 1.5, fontScale: 0.7))    // not rounded
        e.undo()
        XCTAssertEqual(e.selectedKey, KeySpec(.character("A"), label: "a"))
    }

    // MARK: Review 2026-11-14

    func testMovingToARowGoesWhereTheKeyStandsOnTheKeyboard() {
        // A 4-key row over a 10-key row: the keyboard centres it, so its first
        // key stands above the fourth key below (index 3), not the first.
        let keys = (0..<10).map { KeySpec(.character(String(UnicodeScalar(UInt8(97 + $0))))) }
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [Array(keys.prefix(4)), keys]))
        e.select(KeyPosition(row: 0, index: 0))
        e.moveToRow(by: 1)
        XCTAssertEqual(e.selection, KeyPosition(row: 1, index: 3))
    }

}
