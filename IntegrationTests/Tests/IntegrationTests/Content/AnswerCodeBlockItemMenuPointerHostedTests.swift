import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A right click in a code block of an agent answer shows Copy Code Block in
/// the item menu, with the verbs of the message, on the first right click. A
/// right click outside each code block shows no Copy Code Block (task
/// ^4g2xbx1, which replaces D193 (f)).
///
/// The answer shows its code block in a ``CodeBlockView``, in the scope of
/// the block (``AgentCodeBlockScope``) inside the scope of the message. The
/// scope of the block gives its code to the context of the commands, and its
/// editor has `.editorTextMenu(.ancestor)`, so a right click on the code
/// shows the item menu of the scope of the block. The unit tests read the
/// registry, and only a hosted test reads the menu that SwiftUI builds.
///
/// Each test shows the answer of ``CodeBlockAnswerFixture`` in a thread. A
/// read hit-tests the center of the code block view or of the paragraph
/// (`HostedViewHarness.contextMenu(at:)`), and makes a right mouse-down that
/// it never posts, so the window stays off the screen and not key. Each suite
/// whose name ends in `PointerHostedTests` holds such a hit test.
@Suite(.serialized, .hostedSerially) @MainActor struct AnswerCodeBlockItemMenuPointerHostedTests {
  /// Mounts a thread with the answer of ``CodeBlockAnswerFixture``.
  ///
  /// The mount is the thread mount of ``ThreadHeaderContextMenuHostedTests``,
  /// with no context menu on the header.
  ///
  /// - Returns: The harness, after one render.
  static func mountAnswer() -> HostedViewHarness<some View> {
    let session = SessionModel.preview(transcript: [.agent(CodeBlockAnswerFixture.markdown)])
    return ThreadHeaderContextMenuHostedTests.mountThread(
      session, path: nil, system: CommandSystem())
  }

  /// The titles of the menu that a right click at the center of the first
  /// element with `identifier` shows.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element: the code
  ///     block view, or the text of the paragraph.
  ///   - harness: The mount of the answer.
  /// - Returns: The titles of the items, top to bottom.
  /// - Throws: An error when no element has the identifier, or when no view
  ///   under the point gives a menu.
  static func menuTitles(
    atCenterOf identifier: String, in harness: HostedViewHarness<some View>
  ) throws -> [String] {
    let frame = try #require(harness.frame(identifier: identifier))
    let windowPoint = harness.window.convertPoint(fromScreen: NSPoint(x: frame.midX, y: frame.midY))
    let menu = try #require(try harness.contextMenu(at: windowPoint))
    return menu.items.map(\.title)
  }

  /// A production change that fails this test: the code block view of the
  /// answer is in no scope that gives its code, so the first right click in
  /// it shows no Copy Code Block.
  @Test func theFirstRightClickInACodeBlockShowsCopyCodeBlockInTheItemMenu() throws {
    let harness = Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(atCenterOf: CodeBlockView.identifier, in: harness)

    #expect(titles.contains(AgentCommandVerb.copyCodeBlock.title))
  }

  /// A production change that fails this test: the item menu of a right
  /// click in a code block is not the item menu of the message, so Copy
  /// Message does not show with Copy Code Block.
  @Test func aRightClickInACodeBlockKeepsTheItemMenuOfTheMessage() throws {
    let harness = Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(atCenterOf: CodeBlockView.identifier, in: harness)

    #expect(titles.contains(AgentCommandVerb.copyMessage.title))
  }

  /// A production change that fails this test: Copy Code Block shows in the
  /// item menu of a right click in a paragraph.
  @Test func aRightClickInAParagraphShowsNoCopyCodeBlock() throws {
    let harness = Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(atCenterOf: ResponseView.textIdentifier, in: harness)

    #expect(!titles.contains(AgentCommandVerb.copyCodeBlock.title))
  }

  /// A production change that fails this test: the code of a right click
  /// goes into the scope of the message, so a later right click in a
  /// paragraph shows Copy Code Block.
  @Test func aRightClickInAParagraphAfterACodeBlockShowsNoCopyCodeBlock() throws {
    let harness = Self.mountAnswer()
    defer { harness.close() }
    let codeTitles = try Self.menuTitles(atCenterOf: CodeBlockView.identifier, in: harness)
    try #require(codeTitles.contains(AgentCommandVerb.copyCodeBlock.title))

    let titles = try Self.menuTitles(atCenterOf: ResponseView.textIdentifier, in: harness)

    #expect(!titles.contains(AgentCommandVerb.copyCodeBlock.title))
  }
}
