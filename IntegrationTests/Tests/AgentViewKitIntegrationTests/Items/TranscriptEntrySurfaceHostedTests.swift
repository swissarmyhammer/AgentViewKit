@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The transcript entries that ``TranscriptEntrySurfaceHostedTests`` shows.
nonisolated enum TranscriptEntrySurfaceKind: CaseIterable, Sendable {
  /// An ``ErrorView`` of an ACP error.
  case error
  /// A ``CompactionEntryView`` of a completed compaction with a summary.
  case compaction
}

/// Checks that an ``ErrorView`` and a ``CompactionEntryView`` have no fill
/// and no glass, and that the separator stroke of the content edge marks
/// their edge (D113). Each view is a row of the transcript, and the
/// transcript is content.
///
/// The tests use the edge check of ``ContentEdgeHostedProbe``, in light mode.
@Suite(.serialized, .hostedSerially) @MainActor struct TranscriptEntrySurfaceHostedTests {
  /// The size of the window. Each entry fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 360, height: 200)

  /// The message of the ACP error of the error entry.
  static let errorMessage = "The agent stopped before it sent an answer."

  /// The text of the summary of the compaction entry.
  static let summaryText = "Kept the plan and the open files."

  /// The transcript item of a completed compaction with a text summary.
  static var compactionItem: PreviewTranscriptItem {
    let update = CompactionUpdate(
      compactionId: CompactionId(rawValue: "tests-compaction"),
      status: .completed,
      summary: .value([.text(TextContent(text: summaryText))]))
    return .update(.compactionUpdate(update))
  }

  /// The view of one entry.
  ///
  /// - Parameter kind: The entry to show.
  /// - Returns: An ``ErrorView`` or a ``CompactionEntryView``.
  /// - Throws: An issue when the preview model makes no entry of the kind.
  @ViewBuilder static func entryView(of kind: TranscriptEntrySurfaceKind) throws -> some View {
    switch kind {
    case .error:
      let entry = try #require(
        PreviewFixtures.entry(.error(code: .internalError, message: errorMessage), as: ErrorEntry.self))
      ErrorView(entry: entry)
    case .compaction:
      let entry = try #require(PreviewFixtures.entry(compactionItem, as: CompactionEntry.self))
      CompactionEntryView(entry: entry)
    }
  }

  @Test(arguments: TranscriptEntrySurfaceKind.allCases)
  func theBackdropShowsInsideTheEdgeOfTheEntry(kind: TranscriptEntrySurfaceKind) async throws {
    try await ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(of: Self.entryView(of: kind), size: Self.size)
  }
}
