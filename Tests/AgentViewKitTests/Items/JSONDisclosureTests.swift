import SwiftUI
import Testing

@testable import AgentViewKit

/// The block of an unknown item: EditorKit's `EditorDisclosure`, whose header
/// is an EditorKit plain button (Docs/decisions/focus-audit.md, "Raw
/// controls").
///
/// Each test lays out the block in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility element.
@MainActor @Suite struct JSONDisclosureTests {
  /// The title of the block of each test.
  static let title = "Review summary"

  /// The id and the accessibility identifier of the block of each test.
  static let identifier = "json-disclosure-test"

  /// A production change that fails this test: the block is a system
  /// `DisclosureGroup` in place of the EditorKit `EditorDisclosure`, so its
  /// header does not take the caption style of the button tokens of the
  /// theme.
  @Test func theHeaderTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let block = JSONDisclosure(
      id: Self.identifier, title: Self.title, json: "{}", identifier: Self.identifier, isExpanded: false)

    let frames = try #require(await ControlProbe.framesWithLargeButtonCaptions(of: Self.identifier, in: block))

    #expect(frames.themed.height > frames.plain.height)
  }
}
