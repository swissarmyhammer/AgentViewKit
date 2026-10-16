@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Hosted tests of ``PermissionView`` and ``RequestDeck``.
///
/// Each card test gets a `PendingPermissionRequest` from the session model of
/// a ``ScriptedSession``, shows it in a ``PermissionView``, and reads the
/// frames that the scripted agent receives.
@Suite(.serialized, .hostedSerially) @MainActor struct PermissionViewHostedTests {
  /// The size of a hosted card.
  static let cardSize = CGSize(width: 640, height: 480)

  /// The JSON-RPC id of the permission request of the agent.
  static let agentRequestID = 100

  /// The title of each permission request of the tests.
  static let title = "Run the tool?"

  /// The id of the tool call of the tool call subject.
  static let toolCallID = "tool-call-1"

  /// The title of the tool call of the tool call subject.
  static let toolCallTitle = "Read README.md"

  /// The id of the terminal of the command subject.
  static let terminalID = "terminal-1"

  /// The command of the command subject.
  static let command = "swift test"

  /// The working directory of the command subject.
  static let workingDirectory = "/project"

  /// The comment that the reject tests type.
  static let comment = "Use the test file."

  /// The description of the request of the minimum height test. The text
  /// wraps at a narrow width.
  static let description = "The agent wants to read the files of the project and run the tests."

  /// The method of a set-config-option request.
  static let setConfigOptionMethod = "session/set_config_option"

  /// The id of the mode config option.
  static let modeID = "mode"

  /// The four known option kinds, in the order of the card.
  static let knownKinds: [PermissionOptionKind] = [.allowOnce, .allowAlways, .rejectOnce, .rejectAlways]

  /// A kind that no ACP option has, as a source-defined fifth option sends.
  static let folderKind = PermissionOptionKind.unknown("folder")

  /// The `mode` config option of a session in the `ask` mode, with an `auto`
  /// choice.
  static let askModeOption = #"""
    {"configId": "mode", "name": "Mode", "category": "mode", "type": "select",
     "currentValue": "ask",
     "options": [{"value": "ask", "name": "Ask"}, {"value": "auto", "name": "Auto"}]}
    """#

  /// The tool call subject of the tool call of the tests.
  static var toolCallSubject: String {
    #"{"type": "tool_call", "toolCall": {"toolCallId": "\#(toolCallID)"}}"#
  }

  /// The command subject with the terminal of the tests.
  static var commandSubject: String {
    #"""
    {"type": "command", "command": "\#(command)", "cwd": "\#(workingDirectory)",
     "terminalId": "\#(terminalID)"}
    """#
  }

  // MARK: - Fixtures

  /// The option id of a kind. The options of the tests use the wire value of
  /// the kind as the id.
  ///
  /// - Parameter kind: The kind of the option.
  /// - Returns: The option id.
  static func optionID(_ kind: PermissionOptionKind) -> PermissionOptionId {
    PermissionOptionId(rawValue: kind.wireValue)
  }

  /// The params of a permission request of the scripted session.
  ///
  /// - Parameters:
  ///   - kinds: The kinds of the options, in request order. Each option has
  ///     the wire value of its kind as its id and its name.
  ///   - subject: The JSON text of the subject, or `nil` for no subject.
  ///   - description: The description of the request, or `nil` for no
  ///     description.
  /// - Returns: The JSON text of the params.
  static func makeParams(
    kinds: [PermissionOptionKind] = knownKinds, subject: String? = nil, description: String? = nil
  ) -> String {
    let options = kinds.map { kind in
      #"{"optionId": "\#(kind.wireValue)", "name": "\#(kind.wireValue)", "kind": "\#(kind.wireValue)"}"#
    }
    let subjectMember = subject.map { #", "subject": \#($0)"# } ?? ""
    let descriptionMember = description.map { #", "description": "\#($0)""# } ?? ""
    return #"""
      {"sessionId": "\#(ScriptedSession.sessionID)", "title": "\#(title)",
       "options": [\#(options.joined(separator: ","))]\#(subjectMember)\#(descriptionMember)}
      """#
  }

  /// Opens a scripted session whose `session/new` result has the `mode`
  /// option ``askModeOption``.
  ///
  /// - Returns: The session.
  /// - Throws: The error of `initialize` or of `session/new`.
  static func openSessionInAskMode() async throws -> ScriptedSession {
    try await ScriptedSession.open { agent in
      agent.results["session/new"] =
        #"{"sessionId": "\#(ScriptedSession.sessionID)", "configOptions": [\#(askModeOption)]}"#
    }
  }

  /// Gets a permission request from the agent and shows it in a card.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - params: The JSON text of the params of the request.
  ///   - answerReport: The report that gets each answer of the card, or
  ///     `nil`.
  ///   - requestStartReport: The report that gets the method of each request
  ///     that the card starts, or `nil`.
  /// - Returns: The harness of the card.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no request.
  static func mountCard(
    in session: ScriptedSession, params: String = makeParams(),
    answerReport: ObservationReport<PermissionAnswer>? = nil,
    requestStartReport: ObservationReport<String>? = nil
  ) async throws -> HostedViewHarness<some View> {
    let pending = try await session.receivePermissionRequest(id: agentRequestID, params: params)
    let harness = HostedViewHarness(size: cardSize) {
      PermissionView(request: pending, session: session.model)
        .environment(\.permissionAnswerReport, answerReport)
        .environment(\.requestStartReport, requestStartReport)
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  /// The result that the agent receives for a selected option.
  ///
  /// - Parameter kind: The kind of the selected option.
  /// - Returns: The result.
  /// - Throws: An error when the JSON text does not decode.
  static func selectedResult(_ kind: PermissionOptionKind) throws -> JSONValue {
    try JSONValue(
      json: #"{"outcome": {"outcome": "selected", "optionId": "\#(kind.wireValue)"}}"#)
  }

  /// The texts of the prompts that the agent received, in arrival order.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The texts.
  static func promptTexts(_ session: ScriptedSession) -> [String] {
    session.agent.messages(method: ScriptedSession.promptMethod).map(ScriptedWireAgent.promptText(of:))
  }

  /// The identifiers of the option buttons of a harness, in tree order.
  static func optionIdentifiers(_ harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(PermissionView.optionIdentifierPrefix)
    }
  }

  /// Presses the button of the option of `kind`.
  ///
  /// - Parameters:
  ///   - kind: The kind of the option.
  ///   - harness: The harness of the card.
  /// - Throws: An error when the card has no such button.
  static func press(_ kind: PermissionOptionKind, in harness: HostedViewHarness<some View>) throws {
    try harness.press(identifier: PermissionView.optionIdentifier(for: optionID(kind)))
  }

  // MARK: - Identifiers

  @Test func theIdentifiersHaveTheDocumentedForm() {
    #expect(
      PermissionView.optionIdentifier(for: PermissionOptionId(rawValue: "allow_once"))
        == "permission-option-allow_once")
    #expect(PermissionView.commentIdentifier == "permission-comment")
    #expect(PermissionView.switchToAutoIdentifier == "permission-switch-auto")
    #expect(RequestDeck.identifier == "request-deck")
    #expect(RequestDeck.identifier(for: "p-1") == "pending-card-p-1")
  }

  // MARK: - Options

  @Test func fourOptionsMountFourButtonsInOrder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    #expect(
      Self.optionIdentifiers(harness)
        == Self.knownKinds.map { PermissionView.optionIdentifier(for: Self.optionID($0)) })
  }

  @Test func eachOptionButtonKeepsTheNameOfItsOptionAsItsLabel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let kinds = Self.knownKinds + [Self.folderKind]
    let harness = try await Self.mountCard(in: session, params: Self.makeParams(kinds: kinds))
    defer { harness.close() }

    for kind in kinds {
      let button = harness.element(identifier: PermissionView.optionIdentifier(for: Self.optionID(kind)))
      #expect(button?.role == NSAccessibility.Role.button.rawValue, "\(kind)")
      #expect(button?.label == kind.wireValue, "\(kind)")
    }
  }

  @Test func theButtonsFollowTheDecisionOrderForAnyRequestOrder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(
      in: session, params: Self.makeParams(kinds: [Self.folderKind] + Self.knownKinds.reversed()))
    defer { harness.close() }

    #expect(
      Self.optionIdentifiers(harness)
        == (Self.knownKinds + [Self.folderKind]).map { PermissionView.optionIdentifier(for: Self.optionID($0)) })
  }

  @Test func theCardShowsTheTitleAndTheToolCallOfTheSessionModel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      #"""
      {"sessionUpdate": "tool_call_update", "toolCallId": "\#(Self.toolCallID)",
       "title": "\#(Self.toolCallTitle)", "kind": "read", "status": "pending"}
      """#)
    let harness = try await Self.mountCard(in: session, params: Self.makeParams(subject: Self.toolCallSubject))
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.titleIdentifier)?.label == Self.title)
    let subject = harness.element(identifier: PermissionView.subjectIdentifier)
    #expect(subject?.label?.contains(Self.toolCallTitle) == true)
  }

  @Test func theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let pending = try await session.receivePermissionRequest(
      id: Self.agentRequestID, params: Self.makeParams(description: Self.description))

    HostedLayoutExpectations.expectMinimumHeightFitsWidth(
      of: PermissionView(request: pending, session: session.model), width: Self.cardSize.width)
  }

  @Test func anAllowPressSendsTheOptionWithNoComment() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let harness = try await Self.mountCard(in: session, answerReport: ObservationReport { answers.append($0) })
    defer { harness.close() }

    try Self.press(.allowOnce, in: harness)
    // The card reports its answer in the same step as it starts the answer
    // task, so a press that the card did not handle stops the test here.
    try #require(answers == [PermissionAnswer(option: Self.optionID(.allowOnce), comment: nil)])
    let result = await session.result(ofRequest: Self.agentRequestID)

    #expect(result == (try Self.selectedResult(.allowOnce)))
    #expect(session.model.pendingPermissions.isEmpty)
    #expect(Self.promptTexts(session).isEmpty)
  }

  // MARK: - Comment

  @Test func aRejectPressMountsTheCommentAndSubmitSendsIt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let harness = try await Self.mountCard(in: session, answerReport: ObservationReport { answers.append($0) })
    defer { harness.close() }
    #expect(harness.element(identifier: PermissionView.commentIdentifier) == nil)

    try Self.press(.rejectOnce, in: harness)
    #expect(harness.element(identifier: PermissionView.commentIdentifier) != nil)
    #expect(session.model.pendingPermissions.count == 1)

    try #require(harness.focusFirstEditableTextView(of: NSTextField.self))
    harness.type(Self.comment)
    try harness.press(identifier: PermissionView.commentSubmitIdentifier)
    // The card reports its answer in the same step as it starts the answer
    // task, so a Send press that the card did not handle stops the test here.
    try #require(answers == [PermissionAnswer(option: Self.optionID(.rejectOnce), comment: Self.comment)])
    let result = await session.result(ofRequest: Self.agentRequestID)
    await ObservationWait.until { !Self.promptTexts(session).isEmpty }

    #expect(result == (try Self.selectedResult(.rejectOnce)))
    #expect(Self.promptTexts(session) == [Self.comment])
  }

  @Test func theSendButtonOfTheCommentKeepsItsTextAsItsLabel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    try Self.press(.rejectOnce, in: harness)

    harness.expectButton(identifier: PermissionView.commentSubmitIdentifier, label: "Send")
  }

  /// An empty comment selects the reject option and sends no prompt.
  ///
  /// The card reports its answer in the same step as it gives the answer to
  /// the session model, so the test knows that the card handled the Send
  /// press and gave no comment. With no comment, the session model sends no
  /// prompt, so no prompt frame can come after the check.
  @Test func anEmptyCommentSendsNoPrompt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    var answers: [PermissionAnswer] = []
    let harness = try await Self.mountCard(in: session, answerReport: ObservationReport { answers.append($0) })
    defer { harness.close() }

    try Self.press(.rejectAlways, in: harness)
    try harness.press(identifier: PermissionView.commentSubmitIdentifier)
    try #require(answers == [PermissionAnswer(option: Self.optionID(.rejectAlways), comment: nil)])
    let result = await session.result(ofRequest: Self.agentRequestID)

    #expect(result == (try Self.selectedResult(.rejectAlways)))
    #expect(Self.promptTexts(session).isEmpty)
  }

  // MARK: - Escape

  @Test func escapeSendsCancelled() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    // The card cancels in a task, so no model state changes in the same step
    // as Esc. The keyboard focus is the proof that Esc can get to the card.
    try harness.requireKeyboardFocusOutsideText()
    try harness.sendKey(.escape)
    let result = await session.result(ofRequest: Self.agentRequestID)

    #expect(result == (try JSONValue(json: #"{"outcome": {"outcome": "cancelled"}}"#)))
    #expect(session.model.pendingPermissions.isEmpty)
  }

  // MARK: - Switch to auto

  @Test func switchToAutoIsHiddenWithNoModeOption() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.switchToAutoIdentifier) == nil)
  }

  @Test func switchToAutoIsHiddenWithNoAllowOnceOption() async throws {
    let session = try await Self.openSessionInAskMode()
    defer { session.close() }
    let harness = try await Self.mountCard(
      in: session, params: Self.makeParams(kinds: Self.knownKinds.filter { $0 != .allowOnce }))
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.switchToAutoIdentifier) == nil)
  }

  @Test func switchToAutoKeepsItsTextAsItsLabel() async throws {
    let session = try await Self.openSessionInAskMode()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    harness.expectButton(identifier: PermissionView.switchToAutoIdentifier, label: "Allow and Switch to Auto Mode")
  }

  @Test func switchToAutoAllowsThenSetsTheMode() async throws {
    let session = try await Self.openSessionInAskMode()
    defer { session.close() }
    let starts = ReportRecorder<String>()
    let harness = try await Self.mountCard(in: session, requestStartReport: starts.report)
    defer { harness.close() }
    let agent = session.agent
    let allowedBeforeModeSet = ChangeFlag.observing {
      _ = session.model.pendingPermissions
    } when: {
      MainActor.assumeIsolated { agent.messages(method: Self.setConfigOptionMethod).isEmpty }
    }

    try harness.press(identifier: PermissionView.switchToAutoIdentifier)
    // The card starts both requests in the same step as the press, so a
    // press that started nothing stops the test here.
    try #require(starts.values == [ScriptedSession.permissionMethod, Self.setConfigOptionMethod])
    let result = await session.result(ofRequest: Self.agentRequestID)
    await ObservationWait.until { !agent.messages(method: Self.setConfigOptionMethod).isEmpty }

    #expect(result == (try Self.selectedResult(.allowOnce)))
    #expect(allowedBeforeModeSet.value)
    let params = agent.messages(method: Self.setConfigOptionMethod).first?["params"]
    #expect(params?["configId"] == .string(Self.modeID))
    #expect(params?["value"] == .string(PermissionPresentation.autoModeID))
  }

  // MARK: - Terminal

  @Test func theTerminalLinkShowsTheTerminalEntryOfTheSessionModel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendUpdate(
      #"{"sessionUpdate": "terminal_update", "terminalId": "\#(Self.terminalID)", "command": "\#(Self.command)"}"#)
    let harness = try await Self.mountCard(in: session, params: Self.makeParams(subject: Self.commandSubject))
    defer { harness.close() }

    let subject = harness.element(identifier: PermissionView.subjectIdentifier)
    #expect(subject?.label?.contains(Self.command) == true)
    #expect(subject?.label?.contains(Self.workingDirectory) == true)
    #expect(harness.element(identifier: TerminalView.identifier) == nil)
    #expect(harness.element(identifier: PermissionView.terminalLinkIdentifier)?.label == "Show Terminal")

    try harness.press(identifier: PermissionView.terminalLinkIdentifier)

    #expect(harness.element(identifier: TerminalView.identifier) != nil)
    #expect(harness.element(identifier: PermissionView.terminalLinkIdentifier)?.label == "Hide Terminal")
  }

  @Test func theCommandUsesTheEditorFontOfTheEditorTheme() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let pending = try await session.receivePermissionRequest(
      id: Self.agentRequestID, params: Self.makeParams(subject: Self.commandSubject))

    try ThemeHeightExpectations.expectThemeIncreasesHeight(
      of: PermissionView(request: pending, session: session.model), identifier: PermissionView.subjectIdentifier,
      size: Self.cardSize)
  }

  @Test func aCommandWithNoTerminalEntryHasNoLink() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session, params: Self.makeParams(subject: Self.commandSubject))
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.subjectIdentifier) != nil)
    #expect(harness.element(identifier: PermissionView.terminalLinkIdentifier) == nil)
  }

  // MARK: - Deck

  /// Mounts the deck of the session model of `session` with `reporter`.
  static func mountDeck(
    _ session: ScriptedSession, reporter: RecordingFocusReporter
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: cardSize) {
      RequestDeck(session: session.model)
        .environment(\.focusReporter, reporter)
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  /// Sends a permission request of the session from the agent, waits until
  /// the session model holds it, and then renders `harness`.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view after the wait.
  /// - Returns: The local id of the pending request.
  static func sendPermissionRequest(
    _ session: ScriptedSession, harness: HostedViewHarness<some View>
  ) async throws -> UUID {
    try await session.sendPermissionRequest(id: agentRequestID, rendering: harness)
  }

  @Test func theDeckReportsNoMoveForANewCardThenThePromptEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let reporter = RecordingFocusReporter()
    let harness = Self.mountDeck(session, reporter: reporter)
    defer { harness.close() }

    let id = try await Self.sendPermissionRequest(session, harness: harness)
    let cardIdentifier = RequestDeck.identifier(for: id.uuidString)

    // A new card does not take the focus, and the card does not report
    // itself when it appears.
    #expect(reporter.moves.isEmpty)
    #expect(harness.element(identifier: cardIdentifier) != nil)
    #expect(harness.element(identifier: PermissionView.identifier) != nil)

    await session.model.cancelPermission(id)
    harness.render()

    #expect(reporter.moves == [StockPromptEditor.identifier])
    #expect(harness.element(identifier: cardIdentifier) == nil)
  }

  @Test func theDeckShowsOneCardForEachPendingRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mountDeck(session, reporter: RecordingFocusReporter())
    defer { harness.close() }

    let permissionID = try await Self.sendPermissionRequest(session, harness: harness)
    try await session.sendRequest(
      "elicitation/create", id: Self.agentRequestID + 1, params: ScriptedSession.formElicitationParams)
    let model = session.model
    await harness.render { !model.pendingElicitations.isEmpty }
    let elicitationID = try #require(session.model.pendingElicitations.first).id
    #expect(harness.element(identifier: RequestDeck.identifier(for: permissionID.uuidString)) != nil)

    // Only the front card is in the accessibility tree. Next brings the card
    // behind it to the front.
    try harness.press(identifier: RequestDeck.nextIdentifier)

    #expect(harness.element(identifier: RequestDeck.identifier(for: elicitationID.uuidString)) != nil)
    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
  }

  /// The thread view shows no card. The app mounts a ``RequestDeck`` next to
  /// the thread view.
  @Test func theThreadViewWithAPendingPermissionShowsNoPendingCard() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model), size: Self.cardSize)
    defer { harness.close() }
    harness.render()

    _ = try await Self.sendPermissionRequest(session, harness: harness)
    harness.render()

    let cards = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(RequestDeck.identifierPrefix)
    }
    #expect(!session.model.pendingPermissions.isEmpty)
    #expect(cards.isEmpty)
    #expect(harness.element(identifier: PermissionView.identifier) == nil)
  }
}
