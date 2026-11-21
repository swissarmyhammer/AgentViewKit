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
/// Code Block to the item menu of the message, with the Copy button of the
/// block (task ^4g2xbx1, which replaces D193 (f)).
///
/// The answer shows each fenced code block in a ``CodeBlockView``, in the
/// scope of the block (``AgentCodeBlockScope``) inside the scope of the
/// message `agentMessage:<rowKey>`. The scope of the block gives its code to
/// the context of the commands, and its EditorKit editor has
/// `.editorTextMenu(.ancestor)`, so a right click on the code shows the item
/// menu of the scope of the block. That menu holds the commands of the
/// message and ``AgentCommandVerb/copyCodeBlock``.
///
/// Each test puts the answer of ``CodeBlockAnswerFixture`` in an
/// `NSHostingView` with no window. Then it calls `menu(for:)` of a text view
/// with a right press that it makes and never posts, and reads the item menu
/// from the registry. No test opens a window or takes the focus.
@Suite @MainActor struct AnswerCodeBlockItemMenuTests {
  /// The width of the host, in points.
  static let width: CGFloat = 400

  /// The index of the code segment of the answer: the segment after the
  /// paragraph.
  static let codeSegmentIndex = 1

  /// The objects of one test.
  struct Fixture {
    /// The command system of the answer.
    let system: CommandSystem
    /// The host of the answer, with no window. The fixture keeps it, so the
    /// text views keep their ancestors.
    let hosting: NSView
    /// The text view of the paragraph of the answer.
    let paragraph: NSTextView
    /// The text view of the code block view of the answer.
    let code: NSTextView
    /// The path of the item scope of the message.
    let itemPath: FocusPath
    /// The path of the scope of the code block view.
    let codePath: FocusPath

    /// The ids of the item menu at `path`.
    ///
    /// - Parameter path: The path of the menu.
    /// - Returns: The ids, top to bottom.
    func menuIDs(at path: FocusPath) -> [CommandID] {
      system.registry.contextMenuMirror(at: path).map(\.id)
    }

    /// Makes a right press at the center of `text`, and asks the text view
    /// for its menu, as a right click does.
    ///
    /// - Parameter text: The text view.
    /// - Throws: An error when AppKit makes no event.
    func rightClick(on text: NSTextView) throws {
      let press = try RightPress.makeEvent(atCenterOf: text)
      _ = text.menu(for: press)
    }
  }

  /// Mounts the answer in an agent command scope, in a host with no window.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown of the answer.
  ///   - pasteboard: The pasteboard of the copy commands.
  /// - Returns: The fixture.
  /// - Throws: An error when the transcript has no agent message, or the
  ///   view tree has no text view of the paragraph or of the code.
  static func mount(
    markdown: String = CodeBlockAnswerFixture.markdown,
    pasteboard: any AgentViewKit.Pasteboard = NSPasteboard.general
  ) throws -> Fixture {
    let session = SessionModel.preview(transcript: [.agent(markdown)])
    let entry = try #require(PreviewFixtures.firstEntry(in: session, as: AgentMessageEntry.self))
    let rowKey = try #require(session.transcript.first?.rowKey)
    let system = CommandSystem()
    let hosting = NSHostingView(
      rootView: AssistantMessageView(entry: entry)
        .frame(width: width)
        .agentCommandScope(session: session)
        .environment(\.pasteboard, pasteboard)
        .commandSystem(system))
    StyleViewHost.layOut(hosting)
    let itemPath = FocusPath.root(AgentCommandTarget.segment(for: session))
      .appending(AgentScopeKind.message(rowKey: rowKey))
    let codeSegment = AgentScopeKind.codeBlock(
      responseID: EntryContentView.blockID(entryID: rowKey, index: 0), index: codeSegmentIndex)
    let texts = allViews(ofType: NSTextView.self, in: hosting)
    return Fixture(
      system: system, hosting: hosting,
      paragraph: try #require(texts.first { $0.string != CodeBlockAnswerFixture.code }),
      code: try #require(texts.first { $0.string == CodeBlockAnswerFixture.code }),
      itemPath: itemPath, codePath: itemPath.appending(codeSegment))
  }

  /// Each view of `type` under `root`, depth first.
  ///
  /// - Parameters:
  ///   - type: The class of the views.
  ///   - root: The root view.
  /// - Returns: The views, in tree order.
  static func allViews<V: NSView>(ofType type: V.Type, in root: NSView) -> [V] {
    ((root as? V).map { [$0] } ?? []) + root.subviews.flatMap { allViews(ofType: type, in: $0) }
  }

  /// A production change that fails this test: the code block view of the
  /// answer gives its right click no ancestor menu, or its scope does not
  /// give its code, so the item menu gets no Copy Code Block.
  @Test func aRightClickInACodeBlockShowsCopyCodeBlockInTheItemMenu() throws {
    let fixture = try Self.mount()

    try fixture.rightClick(on: fixture.code)

    #expect(fixture.menuIDs(at: fixture.codePath).contains(AgentCommandVerb.copyCodeBlock.id))
  }

  /// A production change that fails this test: the code of the block goes
  /// into the scope of the message, so Copy Code Block shows outside each
  /// code block.
  @Test func aRightClickInAParagraphAfterACodeBlockShowsNoCopyCodeBlock() throws {
    let fixture = try Self.mount()
    try fixture.rightClick(on: fixture.code)
    try #require(fixture.menuIDs(at: fixture.codePath).contains(AgentCommandVerb.copyCodeBlock.id))

    try fixture.rightClick(on: fixture.paragraph)

    #expect(!fixture.menuIDs(at: fixture.itemPath).contains(AgentCommandVerb.copyCodeBlock.id))
  }

  /// A production change that fails this test: Copy Code Block of the item
  /// menu does not read the code of the clicked block, so it copies nothing.
  @Test func copyCodeBlockOfTheItemMenuCopiesTheCodeOfTheClickedBlock() throws {
    try NSPasteboard.withIsolated { pasteboard in
      let fixture = try Self.mount(pasteboard: pasteboard)
      try fixture.rightClick(on: fixture.code)

      #expect(
        fixture.system.registry.perform(
          AgentCommandVerb.copyCodeBlock.id, at: fixture.codePath, clicked: fixture.codePath))

      #expect(pasteboard.string(forType: .string) == CodeBlockAnswerFixture.code)
    }
  }

  /// A production change that fails this test: the code block of an answer
  /// that ends with its closing fence, with no line break after it, holds
  /// the fence line, so Copy Code Block copies "```" after the code.
  @Test func copyCodeBlockOfAnAnswerThatEndsWithItsFenceCopiesNoFence() throws {
    try NSPasteboard.withIsolated { pasteboard in
      let fixture = try Self.mount(
        markdown: CodeBlockAnswerFixture.fenceEndingMarkdown, pasteboard: pasteboard)
      try fixture.rightClick(on: fixture.code)

      try #require(
        fixture.system.registry.perform(
          AgentCommandVerb.copyCodeBlock.id, at: fixture.codePath, clicked: fixture.codePath))

      #expect(pasteboard.string(forType: .string) == CodeBlockAnswerFixture.code)
    }
  }
}
