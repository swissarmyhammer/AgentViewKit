@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import EditorSwiftUI
import EditorTestSupport
import EditorText
import FoundationModelsACPClient
import Testing

/// A pasteboard that keeps the last copied text.
private final class RecordingPasteboard: AgentViewKit.Pasteboard {
  /// The last copied text, or `nil`.
  private(set) var text: String?

  func copyText(_ text: String) {
    self.text = text
  }
}

/// Tests for Copy Code Block, the command of the code block scope of
/// EditorKit (AVK-9.2, D185, D193 (f)).
///
/// The palette and the context menu show the command only in a fenced code
/// block. The command copies the code of the block with no fence lines. The
/// tests write the code block value of EditorKit (`CommandContext.codeBlock`)
/// from a scope below the scope of the session, as the editor scope does.
@MainActor struct CopyCodeBlockCommandTests {
  /// The code of the block of the tests.
  nonisolated static let code = "let a = 1\nprint(a)"

  /// The segment of the scope that gives the code block.
  static let blockSegment = FocusSegment(kind: "testCodeBlock", id: "0")

  /// The code block value of the tests.
  nonisolated static let value = EditorCodeBlockContextValue(
    block: FencedCodeBlock(
      index: 0, range: 0..<40, content: 9..<36, infoString: "swift App.swift", language: "swift",
      fileName: "App.swift"),
    text: code)

  /// The objects of one test.
  struct Fixture {
    /// The target of the commands. The commands hold it weakly, so the
    /// fixture keeps it.
    let target: AgentCommandTarget
    /// The system of the scopes.
    let system: CommandSystemHarness
    /// The path of the session scope, with no code block.
    let sessionPath: FocusPath
    /// The path of the scope that gives the code block.
    let blockPath: FocusPath
  }

  /// Registers the agent commands at a session scope, with a child scope
  /// that gives ``value``.
  ///
  /// - Parameters:
  ///   - session: The session model.
  ///   - pasteboard: The pasteboard of the target.
  /// - Returns: The fixture.
  static func makeFixture(session: SessionModel, pasteboard: any AgentViewKit.Pasteboard) -> Fixture {
    let target = AgentCommandTarget()
    target.session = session
    target.pasteboard = pasteboard
    let segment = AgentCommandTarget.segment(for: session)
    let bindings: [ScopeBinding] = AgentCommand.definitions(for: target).map { .command($0) }
    let system = CommandSystemHarness {
      Scope(segment, bindings: bindings) {
        Scope(blockSegment, contributes: { $0.codeBlock = value })
      }
    }
    let sessionPath = FocusPath.root(segment)
    system.focus(sessionPath)
    return Fixture(target: target, system: system, sessionPath: sessionPath, blockPath: sessionPath.appending(blockSegment))
  }

  // MARK: - Place

  @Test func copyCodeBlockIsAClipboardCommandInTheEditMenuAndTheContextMenu() {
    let verb = AgentCommandVerb.copyCodeBlock

    #expect(verb.group == .clipboard)
    #expect(verb.menu?.path == .edit)
    #expect(verb.contextMenu != nil)
    #expect(verb.title == "Copy Code Block")
    #expect(AgentKeymap.defaultChords[verb] == nil)
  }

  // MARK: - Visibility

  @Test func thePaletteShowsCopyCodeBlockOnlyInACodeBlock() {
    let fixture = Self.makeFixture(session: .preview(), pasteboard: RecordingPasteboard())

    let sessionRows = fixture.system.registry.eligible(path: fixture.sessionPath).filter(\.isVisible)
    let blockRows = fixture.system.registry.eligible(path: fixture.blockPath).filter(\.isVisible)

    #expect(!sessionRows.contains { $0.id == AgentCommandVerb.copyCodeBlock.id })
    #expect(blockRows.first { $0.id == AgentCommandVerb.copyCodeBlock.id }?.isEnabled == true)
  }

  @Test func theContextMenuOfACodeBlockShowsCopyCodeBlock() {
    let fixture = Self.makeFixture(session: .preview(), pasteboard: RecordingPasteboard())

    let blockIDs = fixture.system.registry.contextMenuMirror(at: fixture.blockPath).map(\.id)
    let sessionIDs = fixture.system.registry.contextMenuMirror(at: fixture.sessionPath).map(\.id)

    #expect(blockIDs.contains(AgentCommandVerb.copyCodeBlock.id))
    #expect(!sessionIDs.contains(AgentCommandVerb.copyCodeBlock.id))
  }

  // MARK: - Run

  @Test func copyCodeBlockCopiesTheCodeOfTheBlock() {
    NSPasteboard.withIsolated { pasteboard in
      let fixture = Self.makeFixture(session: .preview(), pasteboard: pasteboard)

      #expect(
        fixture.system.registry.perform(
          AgentCommandVerb.copyCodeBlock.id, at: fixture.blockPath, clicked: fixture.blockPath))

      #expect(pasteboard.string(forType: .string) == Self.code)
    }
  }

  @Test func copyCodeBlockOutsideACodeBlockDoesNotRun() {
    NSPasteboard.withIsolated { pasteboard in
      pasteboard.copyText("before")
      let fixture = Self.makeFixture(session: .preview(), pasteboard: pasteboard)

      #expect(!fixture.system.perform(AgentCommandVerb.copyCodeBlock.id))

      #expect(pasteboard.string(forType: .string) == "before")
    }
  }

  @Test func aHostCanCopyCodeWithThePayload() {
    NSPasteboard.withIsolated { pasteboard in
      let fixture = Self.makeFixture(session: .preview(), pasteboard: pasteboard)

      #expect(
        fixture.system.registry.perform(
          AgentCommandVerb.copyCodeBlock.id, at: fixture.sessionPath,
          payload: AgentCommandPayload.code("echo hi")))

      #expect(pasteboard.string(forType: .string) == "echo hi")
    }
  }

  // MARK: - Header label

  @Test func theHeaderOfABlockShowsItsFileName() {
    #expect(RenderedMarkdownView.headerTitle(of: Self.value.block) == "App.swift")
  }

  @Test func theHeaderOfABlockWithNoFileNameShowsItsLanguage() {
    let block = FencedCodeBlock(
      index: 0, range: 0..<20, content: 8..<16, infoString: "json", language: "json", fileName: nil)

    #expect(RenderedMarkdownView.headerTitle(of: block) == "json")
  }

  @Test func theHeaderOfABlockWithNoInfoShowsNoTitle() {
    let block = FencedCodeBlock(
      index: 0, range: 0..<12, content: 4..<8, infoString: nil, language: nil, fileName: nil)

    #expect(RenderedMarkdownView.headerTitle(of: block) == nil)
  }
}
