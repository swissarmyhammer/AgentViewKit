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
/// the item menu of the message, on the first right click. A right click
/// outside each code block shows no Copy Code Block (D193 (f)).
///
/// The text of an answer is a read-only EditorKit `EditorView`
/// (``RenderedMarkdownView``) with `.editorTextMenu(.ancestor)`, so a right
/// click shows the item menu of the message. Before that menu opens,
/// EditorKit writes the code block under the click into the context of the
/// message scope (`CommandContext.codeBlock`). The SwiftUI menu that the
/// right click builds next must read that value: the unit tests read the
/// registry, and only a hosted test reads the menu that SwiftUI builds.
///
/// Each test shows the answer of ``CodeBlockAnswerFixture`` in a thread, and
/// waits for the parse of the model of the answer, which gives the code
/// blocks. A read hit-tests a point of the text
/// (`HostedViewHarness.contextMenu(at:)`), and makes a right mouse-down that
/// it never posts, so the window stays off the screen and not key. Each suite
/// whose name ends in `PointerHostedTests` holds such a hit test.
@Suite(.serialized, .hostedSerially) @MainActor struct AnswerCodeBlockItemMenuPointerHostedTests {
  /// Mounts a thread with the answer of ``CodeBlockAnswerFixture``, and
  /// waits for the parse of the model of the answer.
  ///
  /// The mount is the thread mount of ``ThreadHeaderContextMenuHostedTests``,
  /// with no context menu on the header and with a cache of the models of
  /// the answers, so the test can wait for the parse.
  ///
  /// - Returns: The harness, after the render of the parse.
  /// - Throws: An error when the transcript has no row, or the cache has no
  ///   model of the answer.
  static func mountAnswer() async throws -> HostedViewHarness<some View> {
    let session = SessionModel.preview(transcript: [.agent(CodeBlockAnswerFixture.markdown)])
    let rowKey = try #require(session.transcript.first?.rowKey)
    let cache = CodeBlockModelCache()
    let harness = ThreadHeaderContextMenuHostedTests.mountThread(
      session, path: nil, system: CommandSystem(), cache: cache)
    let model = try #require(
      ResponseTextChecks.model(of: EntryContentView.blockID(entryID: rowKey, index: 0), in: cache))
    await ResponseTextChecks.renderParsed(model, in: harness)
    return harness
  }

  /// The titles of the menu that a right click at `fraction` of the height
  /// of the text of the answer, from the top, shows.
  ///
  /// - Parameters:
  ///   - fraction: The fraction of the height of the text, from the top.
  ///   - harness: The mount of the answer.
  /// - Returns: The titles of the items, top to bottom.
  /// - Throws: An error when no element has the identifier of the text, or
  ///   when no view under the point gives a menu.
  static func menuTitles(
    atFraction fraction: CGFloat, in harness: HostedViewHarness<some View>
  ) throws -> [String] {
    let frame = try #require(harness.frame(identifier: ResponseView.textIdentifier))
    let point = CodeBlockAnswerFixture.point(atFraction: fraction, of: frame, isFlipped: false)
    let windowPoint = harness.window.convertPoint(fromScreen: point)
    let menu = try #require(try harness.contextMenu(at: windowPoint))
    return menu.items.map(\.title)
  }

  /// A production change that fails this test: the item menu reads the
  /// context of the message scope before the right click writes the code
  /// block, so the first right click in a code block shows no Copy Code
  /// Block.
  @Test func theFirstRightClickInACodeBlockShowsCopyCodeBlockInTheItemMenu() async throws {
    let harness = try await Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(atFraction: CodeBlockAnswerFixture.codeFraction, in: harness)

    #expect(titles.contains(AgentCommandVerb.copyCodeBlock.title))
  }

  /// A production change that fails this test: the item menu of a right
  /// click in a code block is not the item menu of the message, so Copy
  /// Message does not show with Copy Code Block.
  @Test func aRightClickInACodeBlockKeepsTheItemMenuOfTheMessage() async throws {
    let harness = try await Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(atFraction: CodeBlockAnswerFixture.codeFraction, in: harness)

    #expect(titles.contains(AgentCommandVerb.copyMessage.title))
  }

  /// A production change that fails this test: Copy Code Block shows in the
  /// item menu of a right click in a paragraph.
  @Test func aRightClickInAParagraphShowsNoCopyCodeBlock() async throws {
    let harness = try await Self.mountAnswer()
    defer { harness.close() }

    let titles = try Self.menuTitles(
      atFraction: CodeBlockAnswerFixture.paragraphFraction, in: harness)

    #expect(!titles.contains(AgentCommandVerb.copyCodeBlock.title))
  }

  /// A production change that fails this test: the code block of a right
  /// click stays in the message scope, so a later right click in a paragraph
  /// shows Copy Code Block.
  @Test func aRightClickInAParagraphAfterACodeBlockShowsNoCopyCodeBlock() async throws {
    let harness = try await Self.mountAnswer()
    defer { harness.close() }
    let codeTitles = try Self.menuTitles(
      atFraction: CodeBlockAnswerFixture.codeFraction, in: harness)
    try #require(codeTitles.contains(AgentCommandVerb.copyCodeBlock.title))

    let titles = try Self.menuTitles(
      atFraction: CodeBlockAnswerFixture.paragraphFraction, in: harness)

    #expect(!titles.contains(AgentCommandVerb.copyCodeBlock.title))
  }
}
