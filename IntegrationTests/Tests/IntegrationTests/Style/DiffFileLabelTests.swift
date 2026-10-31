import AgentViewKitStyle
import SwiftUI
import Testing

/// Checks the label of a changed file through its public API.
@Suite @MainActor struct DiffFileLabelTests {
  /// The path of the file of the tests.
  static let path = "Sources/Board/BoardColumn.swift"

  /// The counts of the file of the tests.
  static let counts = DiffFileLabel.Counts(added: 12, removed: 3)

  @Test func theCountsWidenTheLabel() {
    let with = StyleViewHost.fittingSize(of: DiffFileLabel(operation: .modified, path: Self.path, counts: Self.counts))
    let without = StyleViewHost.fittingSize(of: DiffFileLabel(operation: .modified, path: Self.path, counts: nil))

    #expect(with.width > without.width)
  }

  @Test func aBinaryFileDrawsNoCounts() {
    let binary = StyleViewHost.fittingSize(of: DiffFileLabel(operation: .binary, path: Self.path, counts: Self.counts))
    let modified = StyleViewHost.fittingSize(
      of: DiffFileLabel(operation: .modified, path: Self.path, counts: Self.counts))

    #expect(binary.width < modified.width)
  }
}
