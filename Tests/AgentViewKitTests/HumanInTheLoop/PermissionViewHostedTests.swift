import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Hosted tests of ``PermissionView`` and ``PendingRequestsHost``.
///
/// Each card test gets a `PendingPermissionRequest` from the session model of
/// a ``ScriptedSession``, shows it in a ``PermissionView``, and reads the
/// frames that the scripted agent receives.
@Suite(.serialized, .hostedSerially) @MainActor struct PermissionViewHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 2

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

  /// The method of a prompt request.
  static let promptMethod = "session/prompt"

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
  /// - Returns: The JSON text of the params.
  static func makeParams(kinds: [PermissionOptionKind] = knownKinds, subject: String? = nil) -> String {
    let options = kinds.map { kind in
      #"{"optionId": "\#(kind.wireValue)", "name": "\#(kind.wireValue)", "kind": "\#(kind.wireValue)"}"#
    }
    let subjectMember = subject.map { #", "subject": \#($0)"# } ?? ""
    return #"""
      {"sessionId": "\#(ScriptedSession.sessionID)", "title": "\#(title)",
       "options": [\#(options.joined(separator: ","))]\#(subjectMember)}
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
  /// - Returns: The harness of the card.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no request.
  static func mountCard(
    in session: ScriptedSession, params: String = makeParams()
  ) async throws -> HostedViewHarness<some View> {
    let pending = try await session.receivePermissionRequest(id: agentRequestID, params: params)
    let harness = HostedViewHarness(size: cardSize) {
      PermissionView(request: pending, session: session.model)
        .transaction { $0.disablesAnimations = true }
    }
    harness.pump()
    return harness
  }

  /// The result that the agent receives for a selected option.
  ///
  /// - Parameter kind: The kind of the selected option.
  /// - Returns: The result.
  /// - Throws: An error when the JSON text does not decode.
  static func selectedResult(_ kind: PermissionOptionKind) throws -> AgentViewKit.JSONValue {
    try AgentViewKit.JSONValue(
      json: #"{"outcome": {"outcome": "selected", "optionId": "\#(kind.wireValue)"}}"#)
  }

  /// The texts of the prompts that the agent received, in arrival order.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The texts.
  static func promptTexts(_ session: ScriptedSession) -> [String] {
    session.agent.messages(method: promptMethod).map(ScriptedWireAgent.promptText(of:))
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
    #expect(PendingRequestsHost.identifier(for: "p-1") == "pending-card-p-1")
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

  @Test func anAllowPressSendsTheOptionWithNoComment() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    try Self.press(.allowOnce, in: harness)
    let result = await session.result(ofRequest: Self.agentRequestID)

    #expect(result == (try Self.selectedResult(.allowOnce)))
    #expect(session.model.pendingPermissions.isEmpty)
    #expect(Self.promptTexts(session).isEmpty)
  }

  // MARK: - Comment

  @Test func aRejectPressMountsTheCommentAndSubmitSendsIt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }
    #expect(harness.element(identifier: PermissionView.commentIdentifier) == nil)

    try Self.press(.rejectOnce, in: harness)
    harness.pump()
    #expect(harness.element(identifier: PermissionView.commentIdentifier) != nil)
    #expect(session.model.pendingPermissions.count == 1)

    #expect(harness.focusFirstEditableTextView(of: NSTextField.self))
    harness.type(Self.comment)
    try harness.press(identifier: PermissionView.commentSubmitIdentifier)
    let result = await session.result(ofRequest: Self.agentRequestID)
    #expect(await waitUntil { !Self.promptTexts(session).isEmpty })

    #expect(result == (try Self.selectedResult(.rejectOnce)))
    #expect(Self.promptTexts(session) == [Self.comment])
  }

  @Test func anEmptyCommentSendsNoPrompt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    try Self.press(.rejectAlways, in: harness)
    harness.pump()
    try harness.press(identifier: PermissionView.commentSubmitIdentifier)
    let result = await session.result(ofRequest: Self.agentRequestID)
    harness.pump()

    #expect(result == (try Self.selectedResult(.rejectAlways)))
    #expect(Self.promptTexts(session).isEmpty)
  }

  // MARK: - Escape

  @Test func escapeSendsCancelled() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }

    try harness.sendKey(.escape)
    let result = await session.result(ofRequest: Self.agentRequestID)

    #expect(result == (try AgentViewKit.JSONValue(json: #"{"outcome": {"outcome": "cancelled"}}"#)))
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

  @Test func switchToAutoAllowsThenSetsTheMode() async throws {
    let session = try await Self.openSessionInAskMode()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session)
    defer { harness.close() }
    let agent = session.agent
    let allowedBeforeModeSet = ChangeFlag.observing {
      _ = session.model.pendingPermissions
    } when: {
      MainActor.assumeIsolated { agent.messages(method: Self.setConfigOptionMethod).isEmpty }
    }

    try harness.press(identifier: PermissionView.switchToAutoIdentifier)
    let result = await session.result(ofRequest: Self.agentRequestID)
    #expect(await waitUntil { !agent.messages(method: Self.setConfigOptionMethod).isEmpty })

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

    try harness.press(identifier: PermissionView.terminalLinkIdentifier)
    harness.pump()

    #expect(harness.element(identifier: TerminalView.identifier) != nil)
  }

  @Test func aCommandWithNoTerminalEntryHasNoLink() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = try await Self.mountCard(in: session, params: Self.makeParams(subject: Self.commandSubject))
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.subjectIdentifier) != nil)
    #expect(harness.element(identifier: PermissionView.terminalLinkIdentifier) == nil)
  }

  // MARK: - Host

  /// Mounts the host of the session model of `session` with `reporter`.
  static func mountHost(
    _ session: ScriptedSession, reporter: RecordingFocusReporter
  ) -> HostedViewHarness<some View> {
    let harness = threadViewHarness(size: cardSize, actions: NoopThreadActions()) {
      PendingRequestsHost(session: session.model)
        .environment(\.focusReporter, reporter)
    }
    harness.pump()
    return harness
  }

  /// Sends a permission request of the session from the agent, and waits
  /// until the session model holds it.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness to pump while the test waits.
  /// - Returns: The local id of the pending request.
  static func sendPermissionRequest(
    _ session: ScriptedSession, harness: HostedViewHarness<some View>
  ) async throws -> UUID {
    try #require(
      try await session.sendPermissionRequest(id: agentRequestID, pumping: harness, timeout: waitTimeout))
  }

  @Test func theHostReportsANewCardThenThePromptEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let reporter = RecordingFocusReporter()
    let harness = Self.mountHost(session, reporter: reporter)
    defer { harness.close() }
    #expect(reporter.moves.isEmpty)

    let id = try await Self.sendPermissionRequest(session, harness: harness)
    let cardIdentifier = PendingRequestsHost.identifier(for: id.uuidString)
    await harness.pump(until: Self.waitTimeout) { reporter.moves.count >= 2 }

    // The host reports the card container, and the card reports itself.
    #expect(Set(reporter.moves) == [cardIdentifier, PermissionView.identifier])
    #expect(harness.element(identifier: cardIdentifier) != nil)
    #expect(harness.element(identifier: PermissionView.identifier) != nil)

    let movesBeforeAnswer = reporter.moves.count
    session.model.cancelPermission(id)
    await harness.pump(until: Self.waitTimeout) { reporter.moves.count > movesBeforeAnswer }

    #expect(reporter.moves.dropFirst(movesBeforeAnswer) == [StockPromptEditor.identifier])
    #expect(harness.element(identifier: cardIdentifier) == nil)
  }

  @Test func theHostShowsOneCardForEachPendingRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mountHost(session, reporter: RecordingFocusReporter())
    defer { harness.close() }

    let permissionID = try await Self.sendPermissionRequest(session, harness: harness)
    try await session.sendRequest(
      "elicitation/create", id: Self.agentRequestID + 1, params: ScriptedSession.formElicitationParams)
    await harness.pump(until: Self.waitTimeout) { !session.model.pendingElicitations.isEmpty }
    let elicitationID = try #require(session.model.pendingElicitations.first).id
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: ElicitationView.formIdentifier) != nil
    }

    for id in [permissionID, elicitationID] {
      #expect(harness.element(identifier: PendingRequestsHost.identifier(for: id.uuidString)) != nil)
    }
    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
  }

  @Test func theThreadViewShowsThePendingCards() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.cardSize)
    defer { harness.close() }
    harness.pump()

    let id = try await Self.sendPermissionRequest(session, harness: harness)
    let cardIdentifier = PendingRequestsHost.identifier(for: id.uuidString)
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: cardIdentifier) != nil }

    #expect(harness.element(identifier: cardIdentifier) != nil)
  }

  // MARK: - Focus target

  @Test func theFocusTargetFollowsTheChange() {
    let card = PendingRequestsHost.identifier(for:)
    #expect(PendingRequestsHost.focusTarget(old: [], new: ["a"]) == card("a"))
    #expect(PendingRequestsHost.focusTarget(old: ["a"], new: ["a", "b", "c"]) == card("c"))
    #expect(PendingRequestsHost.focusTarget(old: ["a"], new: []) == StockPromptEditor.identifier)
    #expect(PendingRequestsHost.focusTarget(old: ["a", "b"], new: ["a"]) == card("a"))
    #expect(PendingRequestsHost.focusTarget(old: ["a"], new: ["a"]) == nil)
    #expect(PendingRequestsHost.focusTarget(old: ["a", "b"], new: ["b", "a"]) == nil)
  }
}
