@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI
import Testing

/// A thread view of a scripted session with a composer in its composer slot.
///
/// The thread view applies the agent command scope of the session at the root
/// of the window, so EditorKit gives the window its undo stack there.
struct ComposerUndoThreadHost: View {
  /// The scripted session of the thread.
  let session: ScriptedSession

  /// The text of the composer.
  let composer: PromptInputHostedTestModel

  var body: some View {
    AgentThreadView(session: session.model, connection: session.connection) {
      PromptInputHost(model: composer)
    }
  }
}

/// Tests for the undo and the redo of the composer, an
/// ``EditorKitPromptEditor``, on the window undo stack of EditorKit (EK-6)
/// (^m1wgq3k, from TestudoApp ^yahkhjn).
///
/// The window has one undo stack. A mount or a re-render of the composer is
/// not something the person did, so it leaves no entry. The clear of the
/// composer after Send is one entry, and `edit.undo` gives the sent prompt
/// back (the decision of the user, 2026-10-22).
///
/// The tests type with key events that the harness sends to its off-screen
/// window. The harness cannot send a ⌘Z or a ⇧⌘Z through `NSApplication`, so
/// the tests run `edit.undo` and `edit.redo` through the command registry of
/// the window: the commands that ⌘Z and ⇧⌘Z resolve to.
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

  /// Shows the thread of `session` with its composer, under a command
  /// system, and renders it.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - composer: The text of the composer.
  /// - Returns: The mounted thread.
  /// - Throws: An error when the window has no undo stack.
  static func mount(
    _ session: ScriptedSession, composer: PromptInputHostedTestModel
  ) throws -> MountedThread<some View> {
    let system = CommandSystem()
    let harness = HostedViewHarness(size: windowSize) {
      ComposerUndoThreadHost(session: session, composer: composer)
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
  /// goes straight to it.
  ///
  /// - Parameters:
  ///   - thread: The mounted thread.
  ///   - composer: The text of the composer.
  /// - Throws: An error when the press sends nothing.
  static func send(in thread: MountedThread<some View>, composer: PromptInputHostedTestModel) throws {
    try EditorKitPromptEditorHostedTests.pressReturn(in: thread.harness)
    // The composer clears its text in the same step as the press, so a press
    // that sent nothing stops the test here.
    try #require(composer.submitCount == 1)
    try #require(composer.plainText.isEmpty)
    thread.harness.render()
  }

  /// Runs `command` of the window and waits until the stack ran its work.
  ///
  /// - Parameters:
  ///   - command: `edit.undo` or `edit.redo`.
  ///   - thread: The mounted thread.
  /// - Throws: An error when `command` is not available.
  static func perform(_ command: CommandID, in thread: MountedThread<some View>) async throws {
    try #require(thread.system.registry.perform(command, at: thread.path))
    await thread.stack.waitUntilIdle()
    thread.harness.render()
  }

  /// Runs `command` of the window while the stack holds an entry for it,
  /// one time for each character of ``message`` at most.
  ///
  /// - Parameters:
  ///   - command: `edit.undo` or `edit.redo`.
  ///   - thread: The mounted thread.
  ///   - canPerform: Whether the stack holds an entry for `command`.
  /// - Throws: An error when `command` is not available.
  static func performWhileAvailable(
    _ command: CommandID, in thread: MountedThread<some View>, canPerform: () -> Bool
  ) async throws {
    for _ in message where canPerform() {
      try await perform(command, in: thread)
    }
  }

  /// Types ``message``, and then runs `edit.undo` until the stack has nothing
  /// left to undo.
  ///
  /// - Parameters:
  ///   - thread: The mounted thread.
  ///   - composer: The text of the composer.
  /// - Throws: An error when the editor cannot get the focus or the typing
  ///   leaves nothing to undo.
  static func typeAndUndoAll(in thread: MountedThread<some View>, composer: PromptInputHostedTestModel) async throws {
    try await typeMessage(in: thread, composer: composer)
    try #require(thread.stack.canUndo)
    try await performWhileAvailable(.undo, in: thread) { thread.stack.canUndo }
  }

  // MARK: - Mount and re-render

  /// The ^yahkhjn regression: a composer that mounts with an empty text or
  /// with a draft, and then re-renders with no edit, leaves the window stack
  /// with nothing to undo, so `edit.undo` and `edit.redo` stay unavailable.
  @Test(arguments: ["", message])
  func aMountedAndReRenderedComposerLeavesNothingToUndo(draft: String) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let composer = PromptInputHostedTestModel(text: draft)
    let thread = try Self.mount(session, composer: composer)
    defer { thread.harness.close() }
    try thread.harness.requireTextViewShows(draft)

    try await Self.reRender(thread, session: session, composer: composer)

    try WindowUndoChecks.expectUnavailableOnAnEmptyStack(at: thread.path, in: thread.system)
    #expect(composer.plainText == draft)
  }

  // MARK: - Typing

  /// Typing in the composer is undoable on the window stack, and `edit.undo`
  /// takes the typing back out until the stack has nothing left to undo. The
  /// stack then can redo the typing.
  @Test func typingIsUndoneByTheWindowUndo() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let composer = PromptInputHostedTestModel()
    let thread = try Self.mount(session, composer: composer)
    defer { thread.harness.close() }

    try await Self.typeAndUndoAll(in: thread, composer: composer)

    try thread.harness.requireTextViewShows("")
    #expect(composer.plainText.isEmpty)
    #expect(!thread.stack.canUndo)
    #expect(thread.stack.canRedo)
  }

  /// `edit.redo` of the window, the command that ⇧⌘Z resolves to, puts the
  /// typing that `edit.undo` took out back into the composer, until the stack
  /// has nothing left to redo.
  @Test func theWindowRedoGivesTheUndoneTypingBack() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let composer = PromptInputHostedTestModel()
    let thread = try Self.mount(session, composer: composer)
    defer { thread.harness.close() }
    try await Self.typeAndUndoAll(in: thread, composer: composer)
    try thread.harness.requireTextViewShows("")
    try #require(composer.plainText.isEmpty)

    try await Self.performWhileAvailable(.redo, in: thread) { thread.stack.canRedo }

    try thread.harness.requireTextViewShows(Self.message)
    #expect(composer.plainText == Self.message)
    #expect(!thread.stack.canRedo)
    #expect(thread.stack.canUndo)
  }

  // MARK: - Send

  /// The clear after Send is ONE entry on top of the typing: one `edit.undo`
  /// gives the whole sent prompt back to the composer, and the typing entry
  /// is the top of the stack again.
  @Test func theClearAfterSendIsOneEntryThatGivesThePromptBack() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let composer = PromptInputHostedTestModel()
    let thread = try Self.mount(session, composer: composer)
    defer { thread.harness.close() }
    try await Self.typeMessage(in: thread, composer: composer)
    let typing = try #require(thread.stack.undoTop)
    try Self.send(in: thread, composer: composer)
    await ObservationWait.until { !session.promptTexts.isEmpty }
    try thread.harness.requireTextViewShows("")
    let clear = try #require(thread.stack.undoTop)
    try #require(clear.id != typing.id)

    try await Self.perform(.undo, in: thread)

    try thread.harness.requireTextViewShows(Self.message)
    #expect(composer.plainText == Self.message)
    #expect(thread.stack.undoTop?.id == typing.id)
    #expect(thread.stack.redoTitle == clear.title)
    #expect(session.promptTexts == [Self.message])
  }
}
