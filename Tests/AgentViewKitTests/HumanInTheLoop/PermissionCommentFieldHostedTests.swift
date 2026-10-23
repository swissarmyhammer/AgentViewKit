@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Hosted tests of the comment field of a ``PermissionView``: a one-line
/// EditorKit field (^8zmkh1a).
///
/// Each test shows the card of a permission request under the root command
/// scope of a window, presses a reject option to show the comment field, and
/// then edits the field with key events.
@Suite(.serialized, .hostedSerially) @MainActor struct PermissionCommentFieldHostedTests {
  /// The prompt of the comment field: its placeholder and its accessibility
  /// label.
  static let prompt = "Tell the agent what to do instead"

  /// Gets a permission request from the agent, shows its card under the root
  /// command scope of a window, and presses the `reject_once` option, so
  /// that the card shows the comment field.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - answerReport: The report that gets each answer of the card, or
  ///     `nil`.
  /// - Returns: The mounted card.
  /// - Throws: The error of the transport, or an issue when the card shows
  ///   no comment field.
  static func mountComment(
    in session: ScriptedSession, answerReport: ObservationReport<PermissionAnswer>? = nil
  ) async throws -> MountedOneLineField<some View> {
    let pending = try await session.receivePermissionRequest(
      id: PermissionViewHostedTests.agentRequestID, params: PermissionViewHostedTests.makeParams())
    let card = try OneLineFieldHarness.mount(size: PermissionViewHostedTests.cardSize) {
      PermissionView(request: pending, session: session.model)
        .environment(\.permissionAnswerReport, answerReport)
    }
    try PermissionViewHostedTests.press(.rejectOnce, in: card.harness)
    return card
  }

  /// The text view of the comment field of `card`.
  ///
  /// - Parameter card: The mounted card.
  /// - Returns: The text view.
  /// - Throws: An issue when the card has no comment text view.
  static func commentTextView(of card: MountedOneLineField<some View>) throws -> NSTextView {
    try OneLineFieldHarness.textView(identifier: PermissionView.commentIdentifier, in: card.harness)
  }

  /// The path of the own command scope of the comment field.
  static var commentPath: FocusPath {
    OneLineFieldHarness.fieldPath(id: PermissionView.commentIdentifier)
  }

  @Test func theCommentFieldIsAnEditorKitTextViewWithTheIdentifierAndThePrompt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let card = try await Self.mountComment(in: session)
    defer { card.harness.close() }

    let textView = try Self.commentTextView(of: card)

    #expect(card.harness.firstEditableTextView(of: NSTextField.self) == nil)
    #expect(card.harness.firstEditableTextView(of: NSTextView.self) === textView)
    #expect(card.harness.element(identifier: PermissionView.commentIdentifier)?.label == Self.prompt)
  }

  @Test func aReturnInTheCommentFieldSendsTheRejectWithTheComment() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let card = try await Self.mountComment(in: session, answerReport: ObservationReport { answers.append($0) })
    defer { card.harness.close() }
    let textView = try Self.commentTextView(of: card)
    try OneLineFieldHarness.type(PermissionViewHostedTests.comment, into: textView, in: card.harness)

    try card.harness.sendKeyDown(.return, to: textView)
    // The card reports its answer in the same step as it starts the answer
    // task, so a Return that the card did not handle stops the test here.
    try #require(
      answers == [
        PermissionAnswer(
          option: PermissionViewHostedTests.optionID(.rejectOnce), comment: PermissionViewHostedTests.comment)
      ])
    let result = await session.result(ofRequest: PermissionViewHostedTests.agentRequestID)
    await ObservationWait.until { !PermissionViewHostedTests.promptTexts(session).isEmpty }

    #expect(result == (try PermissionViewHostedTests.selectedResult(.rejectOnce)))
    #expect(PermissionViewHostedTests.promptTexts(session) == [PermissionViewHostedTests.comment])
  }

  @Test func revertFieldPutsBackTheEmptyCommentAndKeepsTheRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let card = try await Self.mountComment(in: session, answerReport: ObservationReport { answers.append($0) })
    defer { card.harness.close() }
    let textView = try Self.commentTextView(of: card)
    try OneLineFieldHarness.type(PermissionViewHostedTests.comment, into: textView, in: card.harness)

    try OneLineFieldHarness.revertField(at: Self.commentPath, in: card)

    #expect(textView.string.isEmpty)
    #expect(card.harness.window.firstResponder === textView)
    #expect(answers.isEmpty)
    #expect(session.model.pendingPermissions.count == 1)
  }

  /// Esc commits the edit of the field and keeps its text: no key discards
  /// the draft (EditorKit ^a54d840). The request stays pending.
  @Test func anEscapeInTheCommentFieldKeepsTheCommentAndTheRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let card = try await Self.mountComment(in: session, answerReport: ObservationReport { answers.append($0) })
    defer { card.harness.close() }
    let textView = try Self.commentTextView(of: card)
    try OneLineFieldHarness.type(PermissionViewHostedTests.comment, into: textView, in: card.harness)

    try card.harness.sendKeyDown(.escape, to: textView)

    #expect(textView.string == PermissionViewHostedTests.comment)
    #expect(answers.isEmpty)
    #expect(session.model.pendingPermissions.count == 1)
  }

  @Test func typingInTheCommentFieldIsUndoneByTheWindowUndo() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let card = try await Self.mountComment(in: session)
    defer { card.harness.close() }
    let textView = try Self.commentTextView(of: card)
    try OneLineFieldHarness.type(PermissionViewHostedTests.comment, into: textView, in: card.harness)

    try await OneLineFieldHarness.undoAll(PermissionViewHostedTests.comment, in: card)

    #expect(textView.string.isEmpty)
    #expect(!card.stack.canUndo)
    #expect(card.stack.canRedo)
  }
}
