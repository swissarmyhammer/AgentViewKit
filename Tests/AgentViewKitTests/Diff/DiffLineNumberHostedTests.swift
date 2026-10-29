#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import EditorText
  import SwiftUI
  import Testing

  /// Tests that the inline diff of the kit shows its line numbers in one
  /// right-aligned column (card ^7abggb0).
  ///
  /// The EditorKit `DiffView` draws its line numbers as glyph rows in a gutter
  /// lane. The inline layout has one line-number column: an added or a context
  /// row shows its new line number, and a removed row its old line number. So
  /// the number of each row ends at the same x, and the `+` and `-` rows do not
  /// stand apart. The fixture has a hunk deep in the file, so the column is as
  /// wide as a four-digit number, and the one-digit numbers of the first hunk
  /// still end at that x.
  @Suite(.serialized, .hostedSerially) @MainActor struct DiffLineNumberHostedTests {
    /// A size that shows every row of ``patch``.
    static let size = CGSize(width: 720, height: 900)

    /// A patch of one file with two hunks. The first hunk starts at line 8, so
    /// its numbers have one or two digits. The second hunk starts at old line
    /// 1000 and new line 1001, so its numbers have four digits, and the old and
    /// the new number of a row differ.
    static let patch = """
      diff --git a/Sources/Deep.swift b/Sources/Deep.swift
      --- a/Sources/Deep.swift
      +++ b/Sources/Deep.swift
      @@ -8,3 +8,4 @@
       let before = 0
      -let value = 1
      +let value = 2
      +let extra = 3
       let after = 0
      @@ -1000,3 +1001,3 @@
       let deepBefore = 0
      -let deepValue = 1
      +let deepValue = 2
       let deepAfter = 0

      """

    /// The line number of each row of ``patch`` that shows one, in row order.
    /// A context row shows its new number, a removed row its old number, and
    /// an added row its new number.
    static let expectedNumbers = [
      "8", "9", "9", "10", "11",
      "1001", "1001", "1002", "1003",
    ]

    /// The id of the one line-number column of the inline layout.
    static let lineColumnID = EditorDiffIdentifier.inlineLineNumbers

    /// One row of the line-number column: the number it shows, the cell of the
    /// row, and the box the number draws in, in the coordinates of the lane.
    struct NumberedRow {
      /// The line number the row shows.
      let number: String

      /// The cell of the row in the column.
      let cell: CGRect

      /// The box the glyphs of the number draw in.
      let run: CGRect
    }

    /// Makes a harness that shows the inline diff of ``patch``, after one
    /// render pass.
    ///
    /// - Returns: The harness.
    static func mountPatch() -> HostedViewHarness<some View> {
      DiffHarness.mountInline(patch: patch, size: size)
    }

    /// The number of rows of the EditorKit diff: one for each line of its
    /// text view.
    ///
    /// - Parameter root: The root view of the EditorKit diff.
    /// - Returns: The row count.
    static func rowCount(under root: NSView) throws -> Int {
      let text = try #require(root.descendants.lazy.compactMap { $0 as? NSTextView }.first)
      return text.string.components(separatedBy: .newlines).count
    }

    /// The gutter lane under `root` that drew the line-number column.
    ///
    /// - Parameters:
    ///   - root: The root view of the EditorKit diff.
    ///   - rowCount: The number of rows of the diff.
    /// - Returns: The lane.
    static func lineNumberLane(under root: NSView, rowCount: Int) throws -> GutterLaneView {
      let lanes = root.descendants.compactMap { $0 as? GutterLaneView }
      let drawing = lanes.filter { lane in
        (0..<rowCount).contains { lane.preparedGlyphText(columnID: lineColumnID, line: $0) != nil }
      }
      #expect(drawing.count == 1, "lanes that draw \(lineColumnID): \(drawing.count)")
      return try #require(drawing.first)
    }

    /// Each row of `lane` that shows a number in the line-number column, in
    /// row order.
    ///
    /// - Parameters:
    ///   - lane: The lane that drew the line-number column.
    ///   - rowCount: The number of rows of the diff.
    /// - Returns: The numbered rows.
    static func numberedRows(of lane: GutterLaneView, rowCount: Int) throws -> [NumberedRow] {
      let numbered = (0..<rowCount).filter { lane.preparedGlyphText(columnID: lineColumnID, line: $0) != nil }
      return try numbered.map { row in
        let number = try #require(lane.preparedGlyphText(columnID: lineColumnID, line: row))
        let cell = try #require(lane.preparedGlyphRowRect(columnID: lineColumnID, line: row))
        let run = try #require(lane.preparedGlyphRunRect(columnID: lineColumnID, line: row))
        return NumberedRow(number: number, cell: cell, run: run)
      }
    }

    /// The numbered rows of the inline diff of ``patch``, and the lane that
    /// drew them.
    ///
    /// - Parameter harness: The harness that shows the diff.
    /// - Returns: The lane, the row count and the numbered rows.
    static func readNumbers(in harness: HostedViewHarness<some View>) throws -> (
      lane: GutterLaneView, rowCount: Int, rows: [NumberedRow]
    ) {
      let root = try #require(
        views(withAccessibilityIdentifier: EditorDiffIdentifier.root, in: harness.hostingView).first)
      let rowCount = try rowCount(under: root)
      let lane = try lineNumberLane(under: root, rowCount: rowCount)
      return (lane, rowCount, try numberedRows(of: lane, rowCount: rowCount))
    }

    // MARK: - One column

    @Test func eachRowShowsItsNumberInTheOneLineColumn() throws {
      let harness = Self.mountPatch()
      defer { harness.close() }

      let numbers = try Self.readNumbers(in: harness)
      #expect(numbers.rows.map(\.number) == Self.expectedNumbers)
    }

    @Test func theInlineLayoutDrawsNoOldOrNewColumn() throws {
      let harness = Self.mountPatch()
      defer { harness.close() }

      let numbers = try Self.readNumbers(in: harness)
      for columnID in EditorDiffIdentifier.sideBySideLineNumbers {
        let drawn = (0..<numbers.rowCount).filter {
          numbers.lane.preparedGlyphText(columnID: columnID, line: $0) != nil
        }
        #expect(drawn.isEmpty, "\(columnID) draws rows \(drawn)")
      }
    }

    // MARK: - Right edge

    @Test func theNumbersOfAddedRemovedAndContextRowsEndAtOneX() throws {
      let harness = Self.mountPatch()
      defer { harness.close() }

      let rows = try Self.readNumbers(in: harness).rows
      #expect(rows.count == Self.expectedNumbers.count)
      let rightEdges = Set(rows.map(\.run.maxX))
      #expect(rightEdges.count == 1, "right edges \(rightEdges.sorted())")
    }

    @Test func eachNumberDrawsInsideItsColumn() throws {
      let harness = Self.mountPatch()
      defer { harness.close() }

      let rows = try Self.readNumbers(in: harness).rows
      #expect(rows.count == Self.expectedNumbers.count)
      for row in rows {
        #expect(row.run.minX >= row.cell.minX, "\(row.number): run \(row.run) spills left of \(row.cell)")
        #expect(row.run.maxX <= row.cell.maxX, "\(row.number): run \(row.run) spills right of \(row.cell)")
      }
    }
  }
#endif
