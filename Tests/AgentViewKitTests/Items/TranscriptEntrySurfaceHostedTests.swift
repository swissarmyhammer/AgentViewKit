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

/// Checks that an ``ErrorView`` and a ``CompactionEntryView`` are on the
/// content surface of the kit, and not on glass (D110 (b)). Each view is a
/// row of the transcript, and the transcript is content.
///
/// The tests use the method of ``ContentSurfaceHostedProbe``. Each test shows
/// each entry one time with Reduce Transparency off and one time with it on.
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

  /// The pixels of one entry with the backdrop, in light mode, with only
  /// Reduce Transparency changed.
  ///
  /// - Parameters:
  ///   - kind: The entry to show.
  ///   - placement: Where the backdrop is.
  ///   - reducesTransparency: Whether Reduce Transparency is on.
  /// - Returns: The pixels.
  /// - Throws: An issue when the preview model makes no entry of the kind,
  ///   or an error when AppKit gives no pixels.
  static func pixels(
    of kind: TranscriptEntrySurfaceKind, backdrop placement: BackdropPlacement,
    reducesTransparency: Bool
  ) throws -> RenderedPixels {
    switch kind {
    case .error:
      let entry = try #require(
        PreviewFixtures.entry(.error(code: .internalError, message: errorMessage), as: ErrorEntry.self))
      return try ContentSurfaceHostedProbe.pixels(
        of: ErrorView(entry: entry), backdrop: placement, reducesTransparency: reducesTransparency,
        size: size)
    case .compaction:
      let entry = try #require(PreviewFixtures.entry(compactionItem, as: CompactionEntry.self))
      return try ContentSurfaceHostedProbe.pixels(
        of: CompactionEntryView(entry: entry), backdrop: placement,
        reducesTransparency: reducesTransparency, size: size)
    }
  }

  @Test(arguments: TranscriptEntrySurfaceKind.allCases, ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheEntry(
    kind: TranscriptEntrySurfaceKind, reducesTransparency: Bool
  ) throws {
    let pixels = try Self.pixels(of: kind, backdrop: .inFront, reducesTransparency: reducesTransparency)
    #expect(pixels.contains(GlassRenderProbeTests.backdrop))
  }

  @Test(arguments: TranscriptEntrySurfaceKind.allCases, ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheEntry(
    kind: TranscriptEntrySurfaceKind, reducesTransparency: Bool
  ) throws {
    let pixels = try Self.pixels(of: kind, backdrop: .behind, reducesTransparency: reducesTransparency)
    #expect(!pixels.contains(GlassRenderProbeTests.backdrop))
  }
}
