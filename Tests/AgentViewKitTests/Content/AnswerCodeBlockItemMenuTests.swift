import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests that a right click in a code block of an agent answer gives Copy
/// Code Block to the item menu of the message (D193 (f)).
///
/// The text of an answer is a read-only EditorKit `EditorView` with
/// `.editorTextMenu(.ancestor)`, so a right click shows the item menu of the
/// message scope `agentMessage:<rowKey>`. Before that menu opens, EditorKit
/// writes the code block under the click into the context of that scope
/// (`CommandContext.codeBlock`), and a right click outside each code block
/// removes it. ``AgentCommandVerb/copyCodeBlock`` reads that value.
///
/// Each test puts the answer of ``CodeBlockAnswerFixture`` in an
/// `NSHostingView` with no window, and waits
/// for the Markdown parse of the model of the answer, which gives the code
/// blocks. Then it calls `menu(for:)` of the text view with a right press that
/// it makes and never posts, and reads the item menu from the registry. No
/// test opens a window or takes the focus.
@Suite @MainActor struct AnswerCodeBlockItemMenuTests {
  /// The width of the host, in points.
  static let width: CGFloat = 400

  /// The objects of one test.
  struct Fixture {
    /// The command system of the answer.
    let system: CommandSystem
    /// The host of the answer, with no window. The fixture keeps it, so the
    /// text view keeps its ancestors.
    let hosting: NSView
    /// The text view of the answer.
    let text: NSTextView
    /// The path of the item scope of the message.
    let itemPath: FocusPath

    /// The ids of the item menu of the message.
    var itemMenuIDs: [CommandID] {
      system.registry.contextMenuMirror(at: itemPath).map(\.id)
    }

    /// Makes a right press at a fraction of the height of the text, and
    /// asks the text view for its menu, as a right click does.
    ///
    /// - Parameter fraction: The fraction of the height, from the top.
    /// - Throws: An error when AppKit makes no event.
    func rightClick(atFraction fraction: CGFloat) throws {
      let point = CodeBlockAnswerFixture.point(
        atFraction: fraction, of: text.bounds, isFlipped: text.isFlipped)
      let press = try RightPress.makeEvent(at: point, in: text)
      _ = text.menu(for: press)
    }
  }

  /// Mounts the answer in an agent command scope, in a host with no window,
  /// and waits for the parse of the model of the answer.
  ///
  /// The model is in a ``CodeBlockModelCache`` of the test, so the test can
  /// wait for its parse. The answer is the first text block of its message.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown of the answer.
  ///   - pasteboard: The pasteboard of the copy commands.
  /// - Returns: The fixture.
  /// - Throws: An error when the transcript has no agent message, the model
  ///   has no grammar, or the view tree has no text view.
  static func mount(
    markdown: String = CodeBlockAnswerFixture.markdown,
    pasteboard: any AgentViewKit.Pasteboard = NSPasteboard.general
  ) async throws -> Fixture {
    let session = SessionModel.preview(transcript: [.agent(markdown)])
    let entry = try #require(PreviewFixtures.firstEntry(in: session, as: AgentMessageEntry.self))
    let rowKey = try #require(session.transcript.first?.rowKey)
    let cache = CodeBlockModelCache()
    let model = ResponseView.model(
      in: cache, id: EntryContentView.blockID(entryID: rowKey, index: 0), markdown: markdown)
    let system = CommandSystem()
    let hosting = NSHostingView(
      rootView: AssistantMessageView(entry: entry)
        .frame(width: width)
        .agentCommandScope(session: session)
        .environment(\.codeBlockModelCache, cache)
        .environment(\.pasteboard, pasteboard)
        .commandSystem(system))
    StyleViewHost.layOut(hosting)
    let syntax = try #require(model.syntax)
    await syntax.ensureParsed(upTo: model.state.version)
    let itemPath = FocusPath.root(AgentCommandTarget.segment(for: session))
      .appending(AgentScopeKind.message(rowKey: rowKey))
    let text = try #require(firstView(ofType: NSTextView.self, in: hosting))
    return Fixture(system: system, hosting: hosting, text: text, itemPath: itemPath)
  }

  /// A production change that fails this test: the answer gives its right
  /// click no ancestor menu, or the item scope is not the command scope of
  /// the text, so the item menu gets no code block.
  @Test func aRightClickInACodeBlockShowsCopyCodeBlockInTheItemMenu() async throws {
    let fixture = try await Self.mount()

    try fixture.rightClick(atFraction: CodeBlockAnswerFixture.codeFraction)

    #expect(fixture.itemMenuIDs.contains(AgentCommandVerb.copyCodeBlock.id))
  }

  /// A production change that fails this test: the code block of a right
  /// click stays in the item scope after a right click in a paragraph, so
  /// Copy Code Block shows outside each code block.
  @Test func aRightClickInAParagraphAfterACodeBlockShowsNoCopyCodeBlock() async throws {
    let fixture = try await Self.mount()
    try fixture.rightClick(atFraction: CodeBlockAnswerFixture.codeFraction)
    try #require(fixture.itemMenuIDs.contains(AgentCommandVerb.copyCodeBlock.id))

    try fixture.rightClick(atFraction: CodeBlockAnswerFixture.paragraphFraction)

    #expect(!fixture.itemMenuIDs.contains(AgentCommandVerb.copyCodeBlock.id))
  }

  /// A production change that fails this test: Copy Code Block of the item
  /// menu does not read the code block of the right click, so it copies
  /// nothing.
  @Test func copyCodeBlockOfTheItemMenuCopiesTheCodeOfTheClickedBlock() async throws {
    try await NSPasteboard.withIsolatedAsync { pasteboard in
      let fixture = try await Self.mount(pasteboard: pasteboard)
      try fixture.rightClick(atFraction: CodeBlockAnswerFixture.codeFraction)

      #expect(
        fixture.system.registry.perform(
          AgentCommandVerb.copyCodeBlock.id, at: fixture.itemPath, clicked: fixture.itemPath))

      #expect(pasteboard.string(forType: .string) == CodeBlockAnswerFixture.code)
    }
  }

  /// A production change that fails this test: the code block of an answer
  /// that ends with its closing fence, with no line break after it, holds
  /// the fence line, so Copy Code Block copies "```" after the code.
  @Test func copyCodeBlockOfAnAnswerThatEndsWithItsFenceCopiesNoFence() async throws {
    try await NSPasteboard.withIsolatedAsync { pasteboard in
      let fixture = try await Self.mount(
        markdown: CodeBlockAnswerFixture.fenceEndingMarkdown, pasteboard: pasteboard)
      try fixture.rightClick(atFraction: CodeBlockAnswerFixture.codeFraction)

      try #require(
        fixture.system.registry.perform(
          AgentCommandVerb.copyCodeBlock.id, at: fixture.itemPath, clicked: fixture.itemPath))

      #expect(pasteboard.string(forType: .string) == CodeBlockAnswerFixture.code)
    }
  }
}
