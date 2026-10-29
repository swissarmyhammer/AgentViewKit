@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import EditorTestSupport
import FoundationModelsACP
import SwiftUI
import Testing

/// Hosted tests of the comment field of a ``PermissionView``: a one-line
/// EditorKit field (`SingleLineField`) in a card of the ``RequestDeck``.
///
/// The field carries ``PermissionView/commentIdentifier`` on its text view.
/// Typing edits the comment, and Return or Command-Return sends the reject
/// option with the comment. Esc and a focus loss end the edit, keep the
/// comment and answer nothing (EditorKit commits the edit with `.leave` or
/// `.focusLoss`). Revert Field (⌃⌘Z) takes back the typing since the field
/// got the focus, and `edit.undo` of the window takes the typing out. The
/// field reads its placeholder as its label and as its hint. The field has
/// its own `editor:` scope inside the scope of the card, so a jump that lands
/// on the card focuses the card and not the field.
@Suite(.serialized, .hostedSerially) @MainActor struct PermissionCommentFieldHostedTests {
  /// The JSON-RPC id of the permission request of the tests.
  static let requestID = 100

  /// The comment that the tests type.
  static let comment = "Use the test file."

  /// The text that the empty comment field shows, the label of the field,
  /// and the hint of the empty field.
  static let placeholder = "Tell the agent what to do instead"

  /// The thread and the deck of a scripted session in a window with an undo
  /// stack, with the comment field of one permission card open.
  struct OpenComment<Content: View> {
    /// The mounted window.
    let window: MountedThread<Content>

    /// The path of the scope of the card.
    let card: FocusPath

    /// The local id of the pending request of the card.
    let request: UUID
  }

  /// Shows the thread and the deck of `session` under a command system,
  /// sends one permission request, and presses its reject option, so that
  /// the card shows its comment field.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - answers: The report that gets each answer of the card.
  /// - Returns: The window and the card.
  /// - Throws: The error of the transport, or an issue when the card shows
  ///   no comment field.
  static func openComment(
    in session: ScriptedSession, answers: ObservationReport<PermissionAnswer>? = nil
  ) async throws -> OpenComment<some View> {
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(
      session: session, system: system, outerScope: true, answerReport: answers)
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    let request = try await session.sendPermissionRequest(id: requestID, rendering: harness)
    try harness.press(
      identifier: PermissionView.optionIdentifier(for: PermissionOptionId(rawValue: AgentCommandFixtures.rejectOptionID)))
    let window = try SingleLineFieldChecks.window(of: harness, system: system, path: thread)
    return OpenComment(window: window, card: thread.appending(AgentScopeKind.request(request)), request: request)
  }

  /// The value of the comment field that the accessibility tree shows.
  ///
  /// - Parameter harness: The harness that shows the card.
  /// - Returns: The value, or `nil` when the card shows no comment field.
  static func commentValue(in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: PermissionView.commentIdentifier)?.value
  }

  @Test func theTextViewOfTheCommentFieldAloneCarriesTheCommentIdentifier() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let open = try await Self.openComment(in: session)
    defer { open.window.harness.close() }

    try SingleLineFieldChecks.expectOneTextViewCarries(PermissionView.commentIdentifier, in: open.window.harness)
    #expect(open.window.harness.element(identifier: PermissionView.commentIdentifier)?.label == Self.placeholder)
  }

  /// EditorKit gives the empty field its placeholder as the accessibility
  /// hint (`.editorPlaceholder(_:)`).
  @Test func theEmptyCommentFieldReadsItsPlaceholderAsItsHint() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let open = try await Self.openComment(in: session)
    defer { open.window.harness.close() }

    let hint = try SingleLineFieldChecks.hint(ofFieldWith: PermissionView.commentIdentifier, in: open.window.harness)

    #expect(hint == Self.placeholder)
  }

  @Test func typingInTheCommentFieldEditsTheComment() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let open = try await Self.openComment(in: session)
    defer { open.window.harness.close() }

    try SingleLineFieldChecks.type(
      Self.comment, intoFieldWith: PermissionView.commentIdentifier, in: open.window.harness)

    #expect(Self.commentValue(in: open.window.harness) == Self.comment)
  }

  @Test(arguments: SingleLineFieldChecks.submitModifiers)
  func returnInTheCommentFieldSendsTheRejectOptionWithTheComment(modifiers: SwiftUI.EventModifiers) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let open = try await Self.openComment(in: session, answers: ObservationReport { answers.append($0) })
    defer { open.window.harness.close() }
    try SingleLineFieldChecks.type(
      Self.comment, intoFieldWith: PermissionView.commentIdentifier, in: open.window.harness)

    try open.window.harness.sendKey(.return, modifiers: modifiers)
    // The card reports its answer in the same step as it starts the answer
    // task, so a Return that the field did not submit stops the test here.
    let reject = PermissionOptionId(rawValue: AgentCommandFixtures.rejectOptionID)
    try #require(answers == [PermissionAnswer(option: reject, comment: Self.comment)])
    let result = await session.result(ofRequest: Self.requestID)
    await ObservationWait.until { !session.promptTexts.isEmpty }

    #expect(result?["outcome"]?["optionId"]?.stringValue == reject.rawValue)
    #expect(session.promptTexts == [Self.comment])
  }

  /// Esc commits the edit with `.leave` and keeps the comment. The field
  /// takes Esc, so it never answers or dismisses the permission request.
  @Test func escapeInTheCommentFieldKeepsTheCommentAndTheRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let open = try await Self.openComment(in: session, answers: ObservationReport { answers.append($0) })
    defer { open.window.harness.close() }

    let textView = try SingleLineFieldChecks.type(
      Self.comment, intoFieldWith: PermissionView.commentIdentifier, in: open.window.harness, thenPress: .escape)

    #expect(textView.string == Self.comment)
    #expect(Self.commentValue(in: open.window.harness) == Self.comment)
    #expect(answers.isEmpty)
    #expect(session.model.pendingPermissions.map(\.id) == [open.request])
  }

  /// A focus loss commits the edit with `.focusLoss`. It answers nothing.
  @Test func aFocusLossOfTheCommentFieldKeepsTheCommentAndTheRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let open = try await Self.openComment(in: session, answers: ObservationReport { answers.append($0) })
    defer { open.window.harness.close() }

    let textView = try SingleLineFieldChecks.typeAndLeaveByFocusLoss(
      Self.comment, intoFieldWith: PermissionView.commentIdentifier, in: open.window.harness)

    #expect(textView.string == Self.comment)
    #expect(answers.isEmpty)
    #expect(session.model.pendingPermissions.map(\.id) == [open.request])
  }

  /// Revert Field (⌃⌘Z) takes back the typing since the field got the
  /// focus, keeps the focus in the field, and answers nothing.
  @Test func revertFieldInTheCommentFieldTakesBackTheTypingAndKeepsTheRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let open = try await Self.openComment(in: session, answers: ObservationReport { answers.append($0) })
    defer { open.window.harness.close() }

    let textView = try SingleLineFieldChecks.typeAndRevertField(
      Self.comment, intoFieldWith: PermissionView.commentIdentifier, in: open.window)

    SingleLineFieldChecks.expectRevertFieldEmptied(textView, harness: open.window.harness)
    #expect((Self.commentValue(in: open.window.harness) ?? "").isEmpty)
    #expect(answers.isEmpty)
    #expect(session.model.pendingPermissions.map(\.id) == [open.request])
  }

  @Test func theWindowUndoTakesTheTypingOutOfTheCommentField() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let open = try await Self.openComment(in: session)
    defer { open.window.harness.close() }

    let textView = try await SingleLineFieldChecks.typeAndUndoAll(
      Self.comment, intoFieldWith: PermissionView.commentIdentifier, in: open.window)

    #expect(textView.string.isEmpty)
    #expect(!open.window.stack.canUndo)
    #expect(open.window.stack.canRedo)
  }

  /// An answered card leaves the window, and the typing of its comment field
  /// leaves the window undo stack with it, so ⌘Z never undoes typing in a
  /// field that is gone.
  ///
  /// Since EditorKit ^1gab15j an editor's entries stay on the window stack
  /// for as long as its `EditorModel` is alive, and leave on the next main
  /// run loop pass after the model is released. The card keeps the model of
  /// its comment field in a kit-owned `@State` slot, so the model goes with
  /// the card. The check applies only to that kit-owned slot: a model that a
  /// host supplies keeps its entries for as long as the host keeps the model.
  @Test func anAnsweredCardTakesTheTypingOfItsCommentFieldOffTheWindowUndoStack() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let open = try await Self.openComment(in: session, answers: ObservationReport { answers.append($0) })
    defer { open.window.harness.close() }
    let model = session.model

    // The card reports its answer in the same step as it starts the answer
    // task, and the model drops the request when that task ends.
    try await SingleLineFieldChecks.expectAnswerTakesTheTypingOffTheUndoStack(
      typing: Self.comment, intoFieldWith: PermissionView.commentIdentifier, in: open.window,
      answered: { answers.count == 1 }, requestIsGone: { model.pendingPermissions.isEmpty })
  }

  /// The nested-scope rule of the user: the comment field has its own
  /// `editor:` scope in the scope of the card, so a jump that lands on the
  /// card focuses the card, and the caret does not go into the field.
  @Test func aJumpOnTheCardFocusesTheCardAndNotItsCommentField() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let open = try await Self.openComment(in: session)
    defer { open.window.harness.close() }

    try AgentItemFocusRingHostedTests.land(
      on: open.card, in: open.window.path, system: open.window.system, by: .jump)
    open.window.harness.render()

    try open.window.harness.requireKeyboardFocusOutsideText()
  }

  /// A focus that lands on the card while the comment field has the focus
  /// moves the focus out of the field and onto the card, by each way that a
  /// focus lands (^cwdb5zg, the nested-scope rule of EditorKit).
  ///
  /// - Parameter landing: The way that the focus lands on the card.
  @Test(arguments: AgentItemFocusRingHostedTests.FocusLanding.allCases)
  func aLandingOnTheCardWhileTheCommentFieldHasTheFocusFocusesTheCard(
    landing: AgentItemFocusRingHostedTests.FocusLanding
  ) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let open = try await Self.openComment(in: session)
    defer { open.window.harness.close() }
    let textView = try SingleLineFieldChecks.textView(
      identifier: PermissionView.commentIdentifier, in: open.window.harness)
    try #require(open.window.harness.window.makeFirstResponder(textView))

    try AgentItemFocusRingHostedTests.land(
      on: open.card, in: open.window.path, system: open.window.system, by: landing)
    open.window.harness.render()

    try open.window.harness.requireKeyboardFocusOutsideText()
    #expect(
      AgentNavigationHostedTests.focusedItem(
        among: [open.card], in: open.window.system, window: open.window.harness.window) == open.card)
  }

  /// A jump that lands on the own scope of the comment field focuses the
  /// text view of the field.
  @Test func aJumpOnTheScopeOfTheCommentFieldFocusesItsTextView() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let open = try await Self.openComment(in: session)
    defer { open.window.harness.close() }
    let field = open.card.appending(.editor(id: PermissionView.commentIdentifier))

    try AgentItemFocusRingHostedTests.land(on: field, in: open.window.path, system: open.window.system, by: .jump)
    open.window.harness.render()

    let textView = try SingleLineFieldChecks.textView(
      identifier: PermissionView.commentIdentifier, in: open.window.harness)
    #expect(open.window.harness.window.firstResponder === textView)
  }
}
