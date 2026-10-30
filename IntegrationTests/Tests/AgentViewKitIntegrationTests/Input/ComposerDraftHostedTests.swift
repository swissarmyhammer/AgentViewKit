@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tells ``ComposerDraftHost`` which session its thread view shows, and when
/// to rebuild the thread view.
@Observable final class ComposerDraftHostModel {
  /// The session model of the thread view.
  var session: SessionModel

  /// The identity of the thread view. A new value rebuilds the view.
  var generation = 0

  /// Makes the model of a host that shows `session`.
  ///
  /// - Parameter session: The session model of the thread view.
  init(session: SessionModel) {
    self.session = session
  }
}

/// A host that shows the thread view of a session with the default composer
/// (``DefaultThreadComposer``), as Testudo does.
///
/// A new generation rebuilds the thread view under a new identity for the
/// same session, as Swap Chat and View rebuilds a chat. A new session shows
/// the other session in the same thread view, as a detail column that shows
/// the selected session does.
struct ComposerDraftHost: View {
  /// The model that gives the session and the identity of the thread view.
  let model: ComposerDraftHostModel

  var body: some View {
    AgentThreadView(session: model.session)
      .id(model.generation)
  }
}

/// Tests for the draft of the default composer, which outlives a rebuild of
/// the thread view for the same session (^f41brfh, from Testudo ^ad0cgnc).
///
/// The draft of a session lives in the ``PromptDraftStore`` of the kit, not in
/// the state of the composer view. The tests type with key events that the
/// harness sends to its off-screen window, and wait for the draft of the
/// store, because the editor gives its text to the draft after the key event.
@Suite(.serialized, .hostedSerially) @MainActor struct ComposerDraftHostedTests {
  /// The prompt that the tests type.
  static let message = "Hello"

  /// Shows the thread of `session` in a ``ComposerDraftHost`` under a command
  /// system, and renders it.
  ///
  /// - Parameters:
  ///   - host: The model of the host.
  ///   - session: The scripted session that the host shows first.
  /// - Returns: The mounted thread.
  /// - Throws: An error when the window has no undo stack.
  static func mount(
    _ host: ComposerDraftHostModel, session: ScriptedSession
  ) throws -> MountedThread<some View> {
    try ComposerHarness.mountThread(of: session.model) {
      ComposerDraftHost(model: host)
    }
  }

  /// The draft that the default composer keeps for `session`.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The plain text of the draft.
  static func draftText(of session: ScriptedSession) -> String {
    String(PromptDraftStore.shared.draft(for: session.model).text.characters)
  }

  /// Focuses the editor, types ``message`` into it, and waits until the draft
  /// of `session` holds it.
  ///
  /// - Parameters:
  ///   - harness: The harness that shows the thread.
  ///   - session: The scripted session of the thread.
  /// - Throws: An error when the editor cannot get the focus.
  static func typeMessage(in harness: HostedViewHarness<some View>, session: ScriptedSession) async throws {
    try await ComposerHarness.typePrompt(message, in: harness) { draftText(of: session) }
  }

  /// Rebuilds the thread view under a new identity for the same session.
  ///
  /// - Parameters:
  ///   - host: The model of the host.
  ///   - harness: The harness that shows the thread.
  static func rebuild(_ host: ComposerDraftHostModel, in harness: HostedViewHarness<some View>) {
    host.generation += 1
    harness.render()
  }

  // MARK: - Rebuild

  /// The Testudo repro: a rebuild of the thread view for the same session
  /// shows the whole typed prompt, with the caret at its end, so that the
  /// person types on where they stopped.
  @Test func aRebuiltThreadViewShowsTheTypedDraftWithTheCaretAtItsEnd() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let host = ComposerDraftHostModel(session: session.model)
    let thread = try Self.mount(host, session: session)
    defer { thread.harness.close() }
    try await Self.typeMessage(in: thread.harness, session: session)

    Self.rebuild(host, in: thread.harness)

    try thread.harness.requireTextViewShows(Self.message)
    let textView = try #require(thread.harness.firstEditableTextView(of: NSTextView.self))
    #expect(textView.selectedRange() == NSRange(location: Self.message.utf16.count, length: 0))
  }

  /// The draft belongs to its session: a thread view that shows another
  /// session shows the empty draft of that session, and shows the typed
  /// draft again when it comes back to the first session.
  @Test func eachSessionShowsItsOwnDraft() async throws {
    let first = try await ScriptedSession.open()
    defer { first.close() }
    let second = try await ScriptedSession.open()
    defer { second.close() }
    let host = ComposerDraftHostModel(session: first.model)
    let thread = try Self.mount(host, session: first)
    defer { thread.harness.close() }
    try await Self.typeMessage(in: thread.harness, session: first)

    host.session = second.model
    thread.harness.render()
    try thread.harness.requireTextViewShows("")
    #expect(Self.draftText(of: second).isEmpty)

    host.session = first.model
    thread.harness.render()
    try thread.harness.requireTextViewShows(Self.message)
  }

  // MARK: - Send

  /// Send clears the draft of the session as well as the composer, so a
  /// rebuild after Send shows an empty composer.
  @Test func aRebuildAfterSendShowsAnEmptyComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let host = ComposerDraftHostModel(session: session.model)
    let thread = try Self.mount(host, session: session)
    defer { thread.harness.close() }
    try await Self.typeMessage(in: thread.harness, session: session)
    try EditorKitPromptEditorHostedTests.pressReturn(in: thread.harness)
    await ObservationWait.until { session.promptTexts == [Self.message] }
    #expect(Self.draftText(of: session).isEmpty)

    Self.rebuild(host, in: thread.harness)

    try thread.harness.requireTextViewShows("")
    #expect(Self.draftText(of: session).isEmpty)
  }

  /// `edit.undo` after Send gives the prompt back to the composer AND to the
  /// draft of the session: the draft is the text that the composer shows, so
  /// a rebuild after the undo shows the prompt that the undo gave back.
  @Test func theUndoAfterSendGivesThePromptBackToTheDraft() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let host = ComposerDraftHostModel(session: session.model)
    let thread = try Self.mount(host, session: session)
    defer { thread.harness.close() }
    try await Self.typeMessage(in: thread.harness, session: session)
    try EditorKitPromptEditorHostedTests.pressReturn(in: thread.harness)
    await ObservationWait.until { session.promptTexts == [Self.message] }
    thread.harness.render()

    try await ComposerWindowUndoHostedTests.perform(.undo, in: thread)
    await ObservationWait.until { Self.draftText(of: session) == Self.message }
    Self.rebuild(host, in: thread.harness)

    try thread.harness.requireTextViewShows(Self.message)
    #expect(session.promptTexts == [Self.message])
  }
}
