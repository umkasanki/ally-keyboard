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


    // MARK: Row alignment

    private func shortOverLong(_ alignment: KeyboardLayout.RowAlignment) -> KeyboardLayout {
        let keys = (0..<10).map { KeySpec(.character(String(UnicodeScalar(UInt8(97 + $0))))) }
        var l = KeyboardLayout(name: "T", rows: [Array(keys.prefix(4)), keys])
        l.geometry.rowAlignment = alignment
        return l
    }

    func testRowsAreCentredUnlessToldOtherwise() throws {
        XCTAssertEqual(KeyboardLayout.Geometry().rowAlignment, .center)
        let none = try JSONDecoder().decode(KeyboardLayout.Geometry.self, from: Data("{}".utf8))
        XCTAssertEqual(none.rowAlignment, .center)
        let unknown = try JSONDecoder().decode(KeyboardLayout.Geometry.self, from: Data(#"{"rowAlignment":"diagonal"}"#.utf8))
        XCTAssertEqual(unknown.rowAlignment, .center)
        var g = KeyboardLayout.Geometry()
        g.rowAlignment = .stretch
        XCTAssertEqual(try JSONDecoder().decode(KeyboardLayout.Geometry.self, from: JSONEncoder().encode(g)), g)
    }

    func testCentreAndLeftPlaceTheShortRow() {
        // 36 + 3 a unit: the long row spans 10 * 39 - 3 = 387, the short 4 * 39 - 3 = 153.
        let centre = shortOverLong(.center).placements(inRow: 0)
        XCTAssertEqual(centre[0].x, (387 - 153) / 2, accuracy: 1e-9)
        XCTAssertEqual(centre[0].width, 36, accuracy: 1e-9)
        XCTAssertEqual(shortOverLong(.left).placements(inRow: 0)[0].x, 0, accuracy: 1e-9)
        // The widest row is the same whatever the alignment.
        XCTAssertEqual(shortOverLong(.left).placements(inRow: 1)[9].x, 9 * 39, accuracy: 1e-9)
    }

    func testStretchWidensKeysAndKeepsTheGap() {
        var l = shortOverLong(.stretch)
        l.rows[0][1].width = 2                                  // keys 1, 2, 1, 1
        let row = l.placements(inRow: 0)
        XCTAssertEqual(row[0].x, 0, accuracy: 1e-9)
        for i in 1..<row.count {
            XCTAssertEqual(row[i].x - (row[i - 1].x + row[i - 1].width), 3, accuracy: 1e-9)   // the key gap
        }
        XCTAssertEqual(row.last!.x + row.last!.width, 387, accuracy: 1e-9)                    // the full width
        XCTAssertEqual(row[1].width / row[0].width, 75.0 / 36, accuracy: 1e-9)                // in proportion
    }

    func testMovingToARowFollowsTheAlignment() {
        let e = LayoutEditor(layout: shortOverLong(.left))
        e.select(KeyPosition(row: 0, index: 0))
        e.moveToRow(by: 1)
        XCTAssertEqual(e.selection, KeyPosition(row: 1, index: 0))
    }

    func testRowAlignmentIsOneStepToUndo() {
        let e = LayoutEditor(layout: shortOverLong(.center))
        e.setRowAlignment(.stretch)
        XCTAssertEqual(e.layout.geometry.rowAlignment, .stretch)
        e.setRowAlignment(.stretch)                             // no change, no step
        e.undo()
        XCTAssertEqual(e.layout.geometry.rowAlignment, .center)
        XCTAssertFalse(e.canUndo)
    }

    func testStretchedRowsAreNotCalledUneven() {
        let e = LayoutEditor(layout: shortOverLong(.center))
        XCTAssertTrue(e.problems.contains { if case .unevenRows = $0 { return true }; return false })
        e.setRowAlignment(.stretch)
        XCTAssertFalse(e.problems.contains { if case .unevenRows = $0 { return true }; return false })
        e.setRowAlignment(.left)
        XCTAssertTrue(e.problems.contains { if case .unevenRows = $0 { return true }; return false })
    }

    func testAKeyNeverComesOutNegative() {
        var l = KeyboardLayout(name: "T", rows: [[KeySpec(.character("a"), width: 0.5), KeySpec(.character("b"))],
                                                 [KeySpec(.character("c"), width: 6)]])
        l.geometry.keyWidth = 20
        l.geometry.keySpacing = 24                              // a half key spans 0.5 * 44 - 24 < 0
        for alignment in KeyboardLayout.RowAlignment.allCases {
            l.geometry.rowAlignment = alignment
            XCTAssertTrue(l.placements(inRow: 0).allSatisfy { $0.width >= 0 }, "\(alignment)")
        }
    }

    func testATieIsATieDespiteRoundingError() {
        // [6] over [3.3, 6]: the key's left edge meets the middle of 3.3's cell
        // only up to rounding error; on a tie it goes to the left key.
        let e = LayoutEditor(layout: KeyboardLayout(name: "T", rows: [
            [KeySpec(.character("a"), width: 6)],
            [KeySpec(.character("b"), width: 3.3), KeySpec(.character("c"), width: 6)],
        ]))
        e.select(KeyPosition(row: 0, index: 0))
        e.moveToRow(by: 1)
        XCTAssertEqual(e.selection, KeyPosition(row: 0, index: 0))
        XCTAssertEqual(e.layout.rows[0].map(\.title), ["a", "b", "c"])
    }

    func testNoRowRunsPastTheWidestEvenWithHalfKeysWiderGaps() {
        // Key 20, gap 24: a half key clamps to nothing. Neither centring nor
        // stretching may push a row past the widest, or make a key negative.
        let half = KeySpec(.character("h"), width: 0.5)
        for rows in [[[KeySpec(.character("w"), width: 10)], Array(repeating: half, count: 18)],
                     [[KeySpec(.character("w"))] + Array(repeating: half, count: 20), [KeySpec(.character("x"), width: 2)]]] {
            var l = KeyboardLayout(name: "T", rows: rows)
            l.geometry.keyWidth = 20
            l.geometry.keySpacing = 24
            for alignment in KeyboardLayout.RowAlignment.allCases {
                l.geometry.rowAlignment = alignment
                // The widest row, worked out here: each key max(0, w * 44 - 24),
                // and a 24 gap between neighbours.
                let widest = l.rows.map { row in
                    row.reduce(0) { $0 + max(0, $1.width * 44 - 24) } + Double(row.count - 1) * 24
                }.max()!
                for r in l.rows.indices {
                    let places = l.placements(inRow: r)
                    XCTAssertGreaterThanOrEqual(places.first!.x, -1e-9, "\(alignment)")
                    XCTAssertLessThanOrEqual(places.last!.x + places.last!.width, widest + 1e-9, "\(alignment) row \(r)")
                    XCTAssertTrue(places.allSatisfy { $0.width >= 0 }, "\(alignment)")
                }
            }
        }
    }
}
