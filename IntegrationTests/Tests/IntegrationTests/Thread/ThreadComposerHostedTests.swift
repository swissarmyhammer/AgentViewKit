import ACPMarkdown
import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The closure of the host for the composer of a read-only thread: it keeps
/// each text, and it can hold the submit open until the test opens its gate.
@Observable final class ThreadComposerHostRecord {
  /// Each text that the closure got, in order.
  private(set) var texts: [String] = []

  /// Whether the closure waits for the gate before it returns.
  let holdsSubmit: Bool

  /// The gate of the closure that waits, or `nil` while no closure waits.
  private(set) var gate: CheckedContinuation<Void, Never>?

  /// Makes the record of the closure of the host.
  ///
  /// - Parameter holdsSubmit: Whether the closure waits for ``openGate()``
  ///   before it returns.
  init(holdsSubmit: Bool = false) {
    self.holdsSubmit = holdsSubmit
  }

  /// The closure of the host: keeps the text, then waits for the gate when
  /// ``holdsSubmit`` is `true`.
  ///
  /// - Parameter text: The text of the prompt.
  func take(_ text: String) async {
    texts.append(text)
    guard holdsSubmit else { return }
    await withCheckedContinuation { gate = $0 }
  }

  /// Lets the closure that waits return.
  func openGate() {
    gate?.resume()
    gate = nil
  }
}

/// Tests for the composer of the host in a read-only thread (TestudoApp
/// D212, design sections 5.3 and 5.4): the thread of a read-only session
/// with ``SwiftUI/View/threadComposer(placeholder:onSubmit:)`` shows the
/// ``DefaultThreadComposer`` with the placeholder of the host, and Return
/// gives the typed text to the closure of the host.
///
/// The tests type with key events that the harness sends to its off-screen
/// window, and wait for observable values: the draft of the session and the
/// record of the host closure.
@Suite(.serialized, .hostedSerially) @MainActor struct ThreadComposerHostedTests {
  /// The placeholder of the host.
  static let placeholder = "Message to continue in Testudo"

  /// The prompt that the tests type.
  static let message = "Go on"

  /// The id of the read-only session.
  static let sessionID = SessionId(rawValue: "external-session")

  /// A read-only model of a share snapshot of one user message.
  ///
  /// - Returns: The model.
  static func readOnlyModel() -> SessionModel {
    let chunk = ContentChunk(
      content: .text(TextContent(text: "Hi.")), messageId: MessageId(rawValue: "user-1"))
    return SessionModel(
      snapshot: SessionSnapshot.build(updates: [.userMessageChunk(chunk)]), sessionId: sessionID)
  }

  /// Shows the read-only thread of `session` with the default composer and
  /// the composer of the host, under a command system.
  ///
  /// - Parameters:
  ///   - session: The read-only session model.
  ///   - host: The record of the closure of the host.
  /// - Returns: The mounted thread.
  /// - Throws: An error when the window has no undo stack.
  static func mount(_ session: SessionModel, host: ThreadComposerHostRecord) throws
    -> MountedThread<some View>
  {
    try ComposerHarness.mountThread(of: session) {
      AgentThreadView(session: session)
        .threadComposer(placeholder: placeholder, onSubmit: host.take)
    }
  }

  /// The plain text of the draft of the default composer for `session`.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The text.
  static func draftText(of session: SessionModel) -> String {
    String(PromptDraftStore.shared.draft(for: session).text.characters)
  }

  /// The text view of the editor carries the placeholder of the host as its
  /// label.
  @Test func theEditorOfAReadOnlyThreadShowsThePlaceholderOfTheHost() throws {
    let session = Self.readOnlyModel()
    let thread = try Self.mount(session, host: ThreadComposerHostRecord())
    defer { thread.harness.close() }

    #expect(thread.harness.element(identifier: EditorKitPromptEditor.identifier)?.label == Self.placeholder)
  }

  /// Return gives the typed text to the closure of the host one time, and
  /// then the composer and the draft are empty.
  @Test func returnGivesTheTextToTheHostAndClearsTheComposer() async throws {
    let session = Self.readOnlyModel()
    let host = ThreadComposerHostRecord()
    let thread = try Self.mount(session, host: host)
    defer { thread.harness.close() }
    try await ComposerHarness.typePrompt(Self.message, in: thread.harness) { Self.draftText(of: session) }

    try EditorKitPromptEditorHostedTests.pressReturn(in: thread.harness)
    await ObservationWait.until { Self.draftText(of: session).isEmpty }

    #expect(host.texts == [Self.message])
    try thread.harness.requireTextViewShows("")
  }

  /// A second Return while the closure of the host runs does not call the
  /// host again: the composer waits for the closure, as the host turns the
  /// tab into a live session.
  @Test func aSecondReturnWhileTheHostRunsDoesNotSubmitAgain() async throws {
    let session = Self.readOnlyModel()
    let host = ThreadComposerHostRecord(holdsSubmit: true)
    let thread = try Self.mount(session, host: host)
    defer { thread.harness.close() }
    try await ComposerHarness.typePrompt(Self.message, in: thread.harness) { Self.draftText(of: session) }
    // The field is disabled while the host runs, so the test keeps the text
    // view and sends the second Return straight to it.
    let editor = try #require(thread.harness.firstEditableTextView(of: NSTextView.self))
    try thread.harness.sendKeyDown(.return, to: editor)
    await ObservationWait.until { host.gate != nil }
    thread.harness.render()
    try #require(thread.harness.element(identifier: DefaultPromptAccessory.submitProgressIdentifier) != nil)

    try thread.harness.sendKeyDown(.return, to: editor)
    host.openGate()
    await ObservationWait.until { Self.draftText(of: session).isEmpty }

    #expect(host.texts == [Self.message])
  }
}
