import AgentViewKit
import Testing

@Suite struct PatchFieldTests {
  /// One row of the fold table: the new patch, the earlier patch, and the
  /// result.
  nonisolated struct FoldRow: Sendable, CustomTestStringConvertible {
    let incoming: PatchField<Int>
    let previous: PatchField<Int>
    let expected: PatchField<Int>

    var testDescription: String {
      "\(incoming) onto \(previous)"
    }
  }

  /// The three patch states of a new patch, against the three states of the
  /// earlier patch.
  nonisolated static let foldTable: [FoldRow] = [
    FoldRow(incoming: .unchanged, previous: .unchanged, expected: .unchanged),
    FoldRow(incoming: .unchanged, previous: .cleared, expected: .cleared),
    FoldRow(incoming: .unchanged, previous: .value(1), expected: .value(1)),
    FoldRow(incoming: .cleared, previous: .unchanged, expected: .cleared),
    FoldRow(incoming: .cleared, previous: .cleared, expected: .cleared),
    FoldRow(incoming: .cleared, previous: .value(1), expected: .cleared),
    FoldRow(incoming: .value(2), previous: .unchanged, expected: .value(2)),
    FoldRow(incoming: .value(2), previous: .cleared, expected: .value(2)),
    FoldRow(incoming: .value(2), previous: .value(1), expected: .value(2)),
  ]

  @Test func theFoldTableHasNineRows() {
    #expect(Self.foldTable.count == 9)
  }

  @Test(arguments: foldTable)
  func foldGivesTheExpectedPatch(_ row: FoldRow) {
    #expect(row.incoming.folded(onto: row.previous) == row.expected)
  }

  // MARK: - Optional targets

  @Test func unchangedKeepsAnOptionalTarget() {
    let current: String? = "old"

    #expect(PatchField<String>.unchanged.applied(to: current) == "old")
  }

  @Test func clearedSetsAnOptionalTargetToNil() {
    let current: String? = "old"

    #expect(PatchField<String>.cleared.applied(to: current) == nil)
  }

  @Test func aValueReplacesAnOptionalTarget() {
    let current: String? = nil

    #expect(PatchField.value("new").applied(to: current) == "new")
  }

  // MARK: - Targets that are not optional

  @Test func unchangedKeepsATargetThatIsNotOptional() {
    #expect(PatchField<Int>.unchanged.applied(to: 3, clearedValue: 0) == 3)
  }

  @Test func clearedSetsTheClearedValue() {
    #expect(PatchField<Int>.cleared.applied(to: 3, clearedValue: 0) == 0)
  }

  @Test func aValueReplacesATargetThatIsNotOptional() {
    #expect(PatchField.value(7).applied(to: 3, clearedValue: 0) == 7)
  }

  // MARK: - Collection targets

  @Test func clearedEmptiesACollection() {
    let current = [1, 2]

    #expect(PatchField<[Int]>.cleared.applied(to: current).isEmpty)
    #expect(PatchField<String>.cleared.applied(to: "text").isEmpty)
  }

  @Test func unchangedKeepsACollection() {
    #expect(PatchField<[Int]>.unchanged.applied(to: [1, 2]) == [1, 2])
  }

  @Test func aValueReplacesACollection() {
    #expect(PatchField.value([3]).applied(to: [1, 2]) == [3])
  }
}
