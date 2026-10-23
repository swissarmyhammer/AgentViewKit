@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI
import Testing

/// The editor that a hosted thread puts in its composer slot. It is not
/// isolated to the main actor, because `@Test(arguments:)` lists read it.
nonisolated enum ComposerUndoEditor: CaseIterable, CustomTestStringConvertible {
  /// ``EditorKitPromptEditor``: an EditorKit `EditorView`, which joins the
  /// window undo stack through the editor source of EditorKit.
  case editorKit

  /// ``StockPromptEditor``: a SwiftUI `TextEditor`, which joins the window
  /// undo stack through the window `NSUndoManager`.
  case stock

  var testDescription: String {
    switch self {
    case .editorKit: "EditorKitPromptEditor"
    case .stock: "StockPromptEditor"
    }
  }
}

/// A thread view of a scripted session with a composer of one editor in its
/// composer slot.
///
/// The thread view applies the agent command scope of the session at the root
/// of the window, so EditorKit gives the window its undo stack there.
struct ComposerUndoThreadHost: View {
  /// The scripted session of the thread.
  let session: ScriptedSession

  /// The text of the composer.
  let composer: PromptInputHostedTestModel

  /// The editor of the composer.
  let editor: ComposerUndoEditor

  var body: some View {
    AgentThreadView(session: session.model, connection: session.connection) {
      switch editor {
      case .editorKit:
        EditorKitPromptInputHost(model: composer, fileRoot: nil)
      case .stock:
        PromptInputHost(model: composer)
      }
    }
  }
}

/// Tests for the undo of the composer on the window undo stack of EditorKit
/// (EK-6), for both editors (^m1wgq3k, from TestudoApp ^yahkhjn).
///
/// The window has one undo stack. A mount or a re-render of the composer is
/// not something the person did, so it leaves no entry. The clear of the
/// composer after Send is one entry, and `edit.undo` gives the sent prompt
/// back (the decision of the user, 2026-10-22).
///
/// The tests type with key events that the harness sends to its off-screen
/// window. The harness cannot send a ⌘Z through `NSApplication`, so the
/// tests run `edit.undo` through the command registry of the window: the
/// command that ⌘Z resolves to.
///
/// AppKit limit of ``StockPromptEditor``: ⇧⌘Z cannot redo undone
/// `TextEditor` typing. After an undo, the `TextEditor` writes its binding
/// back into its text view; that opens a new undo group, which clears the
/// redo list of the window undo manager. AppKit's own Edit menu loses the
/// redo the same way. ``expectRedo(in:editor:)`` records the limit as a known
/// issue, and fakes no redo.
@Suite(.serialized, .hostedSerially) @MainActor struct ComposerWindowUndoHostedTests {
  /// The prompt that the tests type and send. It is not isolated to the main
  /// actor, because a `@Test(arguments:)` list reads it.
  nonisolated static let message = "Hello"

  /// The size of a window that shows a thread and its composer.
  static let windowSize = CGSize(width: 480, height: 480)

  /// The thread of a scripted session, its composer, and the window undo
  /// stack.
  struct MountedThread<Content: View> {
    /// The harness that shows the thread.
    let harness: HostedViewHarness<Content>

    /// The command system of the window.
    let system: CommandSystem

    /// The root path of the window.
    let path: FocusPath

    /// The undo stack of the window.
    let stack: WindowUndoStack
  }

  /// Shows the thread of `session` with a composer of `editor`, under a
  /// command system, and renders it.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - composer: The text of the composer.
  ///   - editor: The editor of the composer.
  /// - Returns: The mounted thread.
  /// - Throws: An error when the window has no undo stack.
  static func mount(
    _ session: ScriptedSession, composer: PromptInputHostedTestModel, editor: ComposerUndoEditor
  ) throws -> MountedThread<some View> {
    let system = CommandSystem()
    let harness = HostedViewHarness(size: windowSize) {
      ComposerUndoThreadHost(session: session, composer: composer, editor: editor)
        .environment(\.sessionModel, session.model)
        .commandSystem(system)
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    let path = AgentCommandScopeHostedTests.path(of: session.model)
    let stack = try #require(system.undo.stack(for: path))
    return MountedThread(harness: harness, system: system, path: path, stack: stack)
  }

  /// Re-renders the composer with no edit: the agent starts to run, which
  /// redraws the composer with a cancel action, and the host gives the
  /// composer the text that it already holds.
  ///
  /// - Parameters:
  ///   - thread: The mounted thread.
  ///   - session: The scripted session.
  ///   - composer: The text of the composer.
  /// - Throws: The error of the transport.
  static func reRender(
    _ thread: MountedThread<some View>, session: ScriptedSession, composer: PromptInputHostedTestModel
  ) async throws {
    try await AgentCommandScopeHostedTests.sendState(
      ScriptedSession.runningState, to: session, rendering: thread.harness)
    composer.text = composer.text
    thread.harness.render()
  }

  /// Focuses the editor and types ``message`` into it.
  ///
  /// - Parameters:
  ///   - thread: The mounted thread.
  ///   - composer: The text of the composer.
  /// - Throws: An error when the editor cannot get the focus.
  static func typeMessage(in thread: MountedThread<some View>, composer: PromptInputHostedTestModel) async throws {
    try #require(thread.harness.focusFirstEditableTextView(of: NSTextView.self))
    thread.harness.type(message)
    try thread.harness.requireTextViewShows(message)
    await ObservationWait.until { composer.plainText == message }
  }

  /// Sends the prompt with a Return press, as the person does.
  ///
  /// ``EditorKitPromptEditor`` takes Return in its text view, so the press
  /// goes straight to it. ``StockPromptEditor`` takes Return in a SwiftUI key
  /// press handler, so the press goes through the window.
  ///
  /// - Parameters:
  ///   - thread: The mounted thread.
  ///   - editor: The editor of the composer.
  ///   - composer: The text of the composer.
  /// - Throws: An error when the press sends nothing.
  static func send(
    in thread: MountedThread<some View>, editor: ComposerUndoEditor, composer: PromptInputHostedTestModel
  ) throws {
    switch editor {
    case .editorKit: try EditorKitPromptEditorHostedTests.pressReturn(in: thread.harness)
    case .stock: try thread.harness.sendKey(.return)
    }
    // The composer clears its text in the same step as the press, so a press
    // that sent nothing stops the test here.
    try #require(composer.submitCount == 1)
    try #require(composer.plainText.isEmpty)
    thread.harness.render()
  }

  /// Runs `edit.undo` of the window and waits until the stack ran its work.
  ///
  /// - Parameter thread: The mounted thread.
  /// - Throws: An error when `edit.undo` is not available.
  static func undo(in thread: MountedThread<some View>) async throws {
    try #require(thread.system.registry.perform(.undo, at: thread.path))
    await thread.stack.waitUntilIdle()
    thread.harness.render()
  }

  /// Expects that the stack can redo the typing that `edit.undo` took out.
  ///
  /// ``EditorKitPromptEditor`` keeps its redo. ``StockPromptEditor`` loses
  /// it to an AppKit limit: after an undo the `TextEditor` writes its binding
  /// back into its text view, which opens a new undo group and clears the
  /// redo list of the window undo manager, so ⇧⌘Z has nothing to redo. The
  /// known issue records that limit. It does not fake a redo, and it reports
  /// when AppKit starts to keep the redo.
  ///
  /// - Parameters:
  ///   - thread: The mounted thread.
  ///   - editor: The editor of the composer.
  static func expectRedo(in thread: MountedThread<some View>, editor: ComposerUndoEditor) {
    switch editor {
    case .editorKit:
      #expect(thread.stack.canRedo)
    case .stock:
      withKnownIssue("A TextEditor writes its binding back after an undo, which clears the AppKit redo list") {
        #expect(thread.stack.canRedo)
      }
    }
  }

  // MARK: - Mount and re-render

  /// The ^yahkhjn regression: a composer that mounts with an empty text or
  /// with a draft, and then re-renders with no edit, leaves the window stack
  /// with nothing to undo, so `edit.undo` and `edit.redo` stay unavailable.
  @Test(arguments: ComposerUndoEditor.allCases, ["", message])
  func aMountedAndReRenderedComposerLeavesNothingToUndo(editor: ComposerUndoEditor, draft: String) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let composer = PromptInputHostedTestModel(text: draft)
    let thread = try Self.mount(session, composer: composer, editor: editor)
    defer { thread.harness.close() }
    try thread.harness.requireTextViewShows(draft)

    try await Self.reRender(thread, session: session, composer: composer)

    try WindowUndoChecks.expectUnavailableOnAnEmptyStack(at: thread.path, in: thread.system)
    #expect(composer.plainText == draft)
  }

  // MARK: - Typing

  /// Typing in the composer is undoable on the window stack, and `edit.undo`
  /// takes the typing back out until the stack has nothing left to undo.
  @Test(arguments: ComposerUndoEditor.allCases)
  func typingIsUndoneByTheWindowUndo(editor: ComposerUndoEditor) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let composer = PromptInputHostedTestModel()
    let thread = try Self.mount(session, composer: composer, editor: editor)
    defer { thread.harness.close() }
    try await Self.typeMessage(in: thread, composer: composer)
    try #require(thread.stack.canUndo)

    for _ in Self.message where thread.stack.canUndo {
      try await Self.undo(in: thread)
    }

    try thread.harness.requireTextViewShows("")
    #expect(composer.plainText.isEmpty)
    #expect(!thread.stack.canUndo)
    Self.expectRedo(in: thread, editor: editor)
  }

  // MARK: - Send

  /// The clear after Send is ONE entry on top of the typing: one `edit.undo`
  /// gives the whole sent prompt back to the composer, and the typing entry
  /// is the top of the stack again.
  @Test(arguments: ComposerUndoEditor.allCases)
  func theClearAfterSendIsOneEntryThatGivesThePromptBack(editor: ComposerUndoEditor) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let composer = PromptInputHostedTestModel()
    let thread = try Self.mount(session, composer: composer, editor: editor)
    defer { thread.harness.close() }
    try await Self.typeMessage(in: thread, composer: composer)
    let typing = try #require(thread.stack.undoTop)
    try Self.send(in: thread, editor: editor, composer: composer)
    await ObservationWait.until { !session.promptTexts.isEmpty }
    try thread.harness.requireTextViewShows("")
    let clear = try #require(thread.stack.undoTop)
    try #require(clear.id != typing.id)

    try await Self.undo(in: thread)

    try thread.harness.requireTextViewShows(Self.message)
    #expect(composer.plainText == Self.message)
    #expect(thread.stack.undoTop?.id == typing.id)
    #expect(thread.stack.redoTitle == clear.title)
    #expect(session.promptTexts == [Self.message])
  }
}
