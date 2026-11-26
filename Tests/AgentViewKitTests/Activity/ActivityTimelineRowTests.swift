import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The header of a row of an ``ActivityTimeline``: EditorKit's
/// `EditorPlainButton`, with the row identifier and the hint of the row
/// (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the timeline in a window that is never ordered in
/// (``ControlProbe``), and reads the element of the row.
@MainActor @Suite struct ActivityTimelineRowTests {
  /// The title of the tool call of the row.
  static let title = "Read the parser"

  /// The session of each test: one tool call.
  static var session: SessionModel {
    .preview(transcript: [PreviewTranscriptItem.toolCall(title: title, kind: .read, status: .completed)])
  }

  /// The identifier of the row of the tool call of `session`.
  ///
  /// - Parameter session: The session of the timeline.
  /// - Returns: The identifier, or `nil` when the session has no entry.
  static func rowIdentifier(in session: SessionModel) -> String? {
    session.transcript.first.map { ActivityTimeline.rowIdentifier(for: $0.id.rowKey) }
  }

  /// A production change that fails this test: the header of a row is a
  /// plain system `Button` in place of the EditorKit `EditorPlainButton`, so
  /// its title does not take the caption style of the button tokens of the
  /// theme.
  @Test func theHeaderTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let session = Self.session
    let identifier = try #require(Self.rowIdentifier(in: session))

    let frames = try #require(
      await ControlProbe.framesWithLargeButtonCaptions(of: identifier, in: ActivityTimeline(session: session)))

    #expect(frames.themed.height > frames.plain.height)
  }

  /// A production change that fails this test: the header of a closed row
  /// loses the hint that tells what a press does.
  @Test func theHeaderOfAClosedRowSaysThatAPressShowsTheDetails() async throws {
    let session = Self.session
    let identifier = try #require(Self.rowIdentifier(in: session))

    let hint = await ControlProbe.read(identifier, in: ActivityTimeline(session: session)) {
      accessibilityString("accessibilityHelp", of: $0)
    }

    #expect(hint == ActivityTimeline.showsDetailsHint)
  }
}
