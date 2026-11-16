import XCTest
@testable import AllyKeyboardCore

final class HalfKeyTests: XCTestCase {

    private func k(_ c: String, _ half: KeyHalf? = nil, width: Double = 1) -> KeySpec {
        KeySpec(.character(c), width: width, half: half)
    }

    /// ↑ over ↓ share one place; ← and →, halves alone, take one each.
    func testTheArrowTTakesThreePlaces() {
        var l = KeyboardLayout(name: "T", rows: [[k("A"), k("L", .bottom), k("U", .top), k("D", .bottom), k("R", .bottom)]])
        l.geometry.rowAlignment = .left
        XCTAssertEqual(l.rowWidths, [4])
        let p = l.placements(inRow: 0)
        XCTAssertEqual(p[2].x, p[3].x, accuracy: 1e-9)                // up over down
        XCTAssertEqual(p[2].width, p[3].width, accuracy: 1e-9)
        XCTAssertGreaterThan(p[4].x, p[3].x)
        XCTAssertGreaterThan(p[2].x, p[1].x)
    }

    func testHalvesNotPairedTakeTheirOwnPlace() {
        let l = KeyboardLayout(name: "T", rows: [[k("D", .bottom), k("U", .top)]])
        XCTAssertEqual(l.rowWidths, [2])
    }

    func testTheSpanOfEachHalf() {
        let top = KeyHalf.top.span(rowHeight: 40, gap: 4), bottom = KeyHalf.bottom.span(rowHeight: 40, gap: 4)
        XCTAssertEqual(top.fromTop, 0); XCTAssertEqual(top.height, 18)
        XCTAssertEqual(bottom.fromTop, 22); XCTAssertEqual(bottom.height, 18)
    }

    func testAHalfSurvivesAFileAndAWholeKeyWritesNone() throws {
        let key = k("U", .top)
        let data = try JSONEncoder().encode(key)
        XCTAssertEqual(try JSONDecoder().decode(KeySpec.self, from: data), key)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(k("A")), as: UTF8.self).contains("half"))
    }

    func testStretchCountsPlacesNotKeys() {
        var l = KeyboardLayout(name: "T", rows: [[k("A"), k("B"), k("C"), k("E")],
                                                 [k("U", .top), k("D", .bottom), k("X")]])
        l.geometry.rowAlignment = .stretch
        let p = l.placements(inRow: 1), full = l.placements(inRow: 0)
        XCTAssertEqual(p[2].x + p[2].width, full[3].x + full[3].width, accuracy: 1e-6)
    }
}
