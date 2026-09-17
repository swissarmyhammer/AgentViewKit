import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``PermissionView`` and ``PendingRequestsHost``.
@Suite(.serialized) @MainActor struct PermissionViewHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 2

  /// The size of a hosted card.
  static let cardSize = CGSize(width: 640, height: 480)

  /// The identifier of the request of the fixtures.
  static let requestID = "permission-1"

  /// The identifier of the terminal of the command request.
  static let terminalID = TerminalID("terminal-1")

  /// The identifier of the mode option.
  static let modeID = ConfigOptionID("mode")

  /// The comment that the reject tests type.
  static let comment = "Use the test file."

  /// The request with one option of each known kind.
  static var request: PermissionRequest {
    ThreadFixtures.permissionRequest(id: requestID)
  }

  /// A request for a command with a related terminal.
  static var commandRequest: PermissionRequest {
    PermissionRequest(
      id: PermissionRequestID(requestID),
      title: "Run the command?",
      subject: .command(
        command: "swift test", cwd: "/project", toolCallId: nil, terminalId: terminalID),
      options: request.options
    )
  }

  /// A mode option with the auto choice.
  ///
  /// - Parameter current: The id of the selected value.
  /// - Returns: The option.
  static func modeOption(current: String) -> ConfigOption {
    ConfigOption(
      id: modeID, name: "Mode", category: .mode,
      kind: .select(
        current: current,
        choices: .flat([
          SelectOption(id: "default", name: "Default"),
          SelectOption(id: PermissionPresentation.autoModeID, name: "Auto"),
        ])))
  }

  /// Mounts a card with a thread in the environment.
  ///
  /// - Parameters:
  ///   - request: The request to show.
  ///   - actions: The actions that record each call.
  ///   - thread: The thread of the environment.
  /// - Returns: The harness.
  static func mount(
    _ request: PermissionRequest,
    actions: NoopThreadActions,
    thread: AgentThread = AgentThread()
  ) -> HostedViewHarness<some View> {
    let harness = threadViewHarness(size: cardSize, actions: actions, thread: thread) {
      PermissionView(request: request)
    }
    harness.pump()
    return harness
  }

  /// The permission decisions that `actions` recorded.
  static func decisions(_ actions: NoopThreadActions) -> [PermissionDecision] {
    actions.calls.compactMap { call in
      guard case .respondToPermission(_, let decision) = call else { return nil }
      return decision
    }
  }

  /// The decision that selects the option with `id`.
  static func selected(_ id: String, comment: String? = nil) -> PermissionDecision {
    PermissionDecision(outcome: .selected(PermissionOptionID(id)), comment: comment)
  }

  /// The wire value of `kind`, which is the option id of the fixtures.
  static func optionID(_ kind: PermissionOption.Kind) -> String {
    kind.wireValue
  }

  /// The identifiers of the option buttons of a harness, in tree order.
  static func optionIdentifiers(_ harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(PermissionView.optionIdentifierPrefix)
    }
  }

  // MARK: - Identifiers

  @Test func theIdentifiersHaveTheDocumentedForm() {
    #expect(
      PermissionView.optionIdentifier(for: PermissionOptionID("allow_once"))
        == "permission-option-allow_once")
    #expect(PermissionView.commentIdentifier == "permission-comment")
    #expect(PermissionView.switchToAutoIdentifier == "permission-switch-auto")
    #expect(PendingRequestsHost.identifier(for: "p-1") == "pending-card-p-1")
  }

  // MARK: - Options

  @Test func fourOptionsMountFourButtonsInOrder() {
    let harness = Self.mount(Self.request, actions: NoopThreadActions())
    defer { harness.close() }

    #expect(
      Self.optionIdentifiers(harness)
        == PermissionOption.Kind.knownCases.map {
          PermissionView.optionIdentifier(for: PermissionOptionID(Self.optionID($0)))
        })
  }

  @Test func theButtonsFollowTheDecisionOrderForAnyRequestOrder() {
    var request = Self.request
    request.options.reverse()
    request.options.insert(
      PermissionOption(
        id: PermissionOptionID("folder"), name: "Always for this folder", kind: .unknown("folder")),
      at: 0)
    let harness = Self.mount(request, actions: NoopThreadActions())
    defer { harness.close() }

    #expect(
      Self.optionIdentifiers(harness)
        == ["allow_once", "allow_always", "reject_once", "reject_always", "folder"].map {
          PermissionView.optionIdentifier(for: PermissionOptionID($0))
        })
  }

  @Test func theCardShowsTheTitleAndTheToolCall() {
    let thread = AgentThread()
    thread.apply(
      .insert(.toolCall(ThreadFixtures.toolCall(id: "tool-call-1", status: .pending)), after: nil))
    let harness = Self.mount(Self.request, actions: NoopThreadActions(), thread: thread)
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.titleIdentifier)?.label == "Run the tool?")
    let subject = harness.element(identifier: PermissionView.subjectIdentifier)
    #expect(subject?.label?.contains("Read README.md") == true)
  }

  @Test func anAllowPressSendsTheOptionWithNoComment() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.request, actions: actions)
    defer { harness.close() }

    try harness.press(
      identifier: PermissionView.optionIdentifier(
        for: PermissionOptionID(Self.optionID(.allowOnce))))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(Self.decisions(actions) == [Self.selected(Self.optionID(.allowOnce))])
    #expect(
      actions.calls.first.map { call in
        guard case .respondToPermission(let request, _) = call else { return false }
        return request == Self.request
      } == true)
  }

  // MARK: - Comment

  @Test func aRejectPressMountsTheCommentAndSubmitSendsIt() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.request, actions: actions)
    defer { harness.close() }
    #expect(harness.element(identifier: PermissionView.commentIdentifier) == nil)

    try harness.press(
      identifier: PermissionView.optionIdentifier(
        for: PermissionOptionID(Self.optionID(.rejectOnce))))
    harness.pump()
    #expect(harness.element(identifier: PermissionView.commentIdentifier) != nil)
    #expect(actions.calls.isEmpty)

    #expect(harness.focusFirstEditableTextView(of: NSTextField.self))
    harness.type(Self.comment)
    try harness.press(identifier: PermissionView.commentSubmitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(
      Self.decisions(actions) == [Self.selected(Self.optionID(.rejectOnce), comment: Self.comment)])
  }

  @Test func anEmptyCommentSendsNoComment() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.request, actions: actions)
    defer { harness.close() }

    try harness.press(
      identifier: PermissionView.optionIdentifier(
        for: PermissionOptionID(Self.optionID(.rejectAlways))))
    harness.pump()
    try harness.press(identifier: PermissionView.commentSubmitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(Self.decisions(actions) == [Self.selected(Self.optionID(.rejectAlways))])
  }

  // MARK: - Escape

  @Test func escapeSendsCancelled() async throws {
    let actions = NoopThreadActions()
    let harness = Self.mount(Self.request, actions: actions)
    defer { harness.close() }

    try harness.sendKey(.escape)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(Self.decisions(actions) == [PermissionDecision(outcome: .cancelled)])
  }

  // MARK: - Switch to auto

  @Test func switchToAutoIsHiddenWithNoModeOption() {
    let harness = Self.mount(Self.request, actions: NoopThreadActions())
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.switchToAutoIdentifier) == nil)
  }

  @Test func switchToAutoIsHiddenWithNoAllowOnceOption() {
    let thread = AgentThread()
    thread.apply(.setConfigOptions([Self.modeOption(current: "default")]))
    var request = Self.request
    request.options.removeAll { $0.kind == .allowOnce }
    let harness = Self.mount(request, actions: NoopThreadActions(), thread: thread)
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.switchToAutoIdentifier) == nil)
  }

  @Test func switchToAutoAllowsThenSetsTheMode() async throws {
    let actions = NoopThreadActions()
    let thread = AgentThread()
    thread.apply(.setConfigOptions([Self.modeOption(current: "default")]))
    let harness = Self.mount(Self.request, actions: actions, thread: thread)
    defer { harness.close() }

    try harness.press(identifier: PermissionView.switchToAutoIdentifier)
    await harness.pump(until: Self.waitTimeout) { actions.calls.count >= 2 }

    #expect(
      actions.calls == [
        .respondToPermission(Self.request, Self.selected(Self.optionID(.allowOnce))),
        .setConfigOption(Self.modeID, PermissionPresentation.autoModeValue),
      ])
  }

  // MARK: - Terminal

  @Test func theTerminalLinkShowsTheTerminal() throws {
    let thread = AgentThread()
    thread.apply(
      .upsertTerminal(
        TerminalPatch(
          id: Self.terminalID, command: .value("swift test"), cwd: .value("/project"),
          output: .value(Data("Building\n".utf8)))))
    let harness = Self.mount(Self.commandRequest, actions: NoopThreadActions(), thread: thread)
    defer { harness.close() }

    let subject = harness.element(identifier: PermissionView.subjectIdentifier)
    #expect(subject?.label?.contains("swift test") == true)
    #expect(subject?.label?.contains("/project") == true)
    #expect(harness.element(identifier: TerminalView.identifier) == nil)

    try harness.press(identifier: PermissionView.terminalLinkIdentifier)
    harness.pump()

    #expect(harness.element(identifier: TerminalView.identifier) != nil)
  }

  @Test func aCommandWithNoTerminalRecordHasNoLink() {
    let harness = Self.mount(Self.commandRequest, actions: NoopThreadActions())
    defer { harness.close() }

    #expect(harness.element(identifier: PermissionView.subjectIdentifier) != nil)
    #expect(harness.element(identifier: PermissionView.terminalLinkIdentifier) == nil)
  }

  // MARK: - Host

  /// Mounts the host of `thread` with `reporter`.
  static func mountHost(
    _ thread: AgentThread, reporter: RecordingFocusReporter
  ) -> HostedViewHarness<some View> {
    let harness = threadViewHarness(size: cardSize, actions: NoopThreadActions()) {
      PendingRequestsHost(thread: thread)
        .environment(\.focusReporter, reporter)
    }
    harness.pump()
    return harness
  }

  @Test func theHostReportsANewCardThenThePromptEditor() async {
    let thread = AgentThread()
    let reporter = RecordingFocusReporter()
    let harness = Self.mountHost(thread, reporter: reporter)
    defer { harness.close() }
    let cardIdentifier = PendingRequestsHost.identifier(for: Self.requestID)
    #expect(reporter.moves.isEmpty)

    thread.apply(.addPermission(Self.request))
    await harness.pump(until: Self.waitTimeout) { !reporter.moves.isEmpty }

    #expect(reporter.moves == [cardIdentifier])
    #expect(harness.element(identifier: cardIdentifier) != nil)
    #expect(harness.element(identifier: PermissionView.identifier) != nil)

    thread.apply(.resolvePermission(PermissionRequestID(Self.requestID)))
    await harness.pump(until: Self.waitTimeout) { reporter.moves.count >= 2 }

    #expect(reporter.moves == [cardIdentifier, StockPromptEditor.identifier])
    #expect(harness.element(identifier: cardIdentifier) == nil)
  }

  @Test func theHostShowsOneCardForEachPendingRequest() {
    let thread = AgentThread()
    let elicitation = ThreadFixtures.formElicitationRequest(id: "elicitation-1")
    let authorization = AuthorizationRequest(
      id: AuthorizationRequestID("authorization-1"),
      serverName: "GitHub",
      scopes: ["repo"],
      authorizationURL: URL(string: "https://github.com/login/oauth/authorize")!
    )
    thread.apply(.addPermission(Self.request))
    thread.apply(.addElicitation(elicitation))
    thread.apply(.addAuthorization(authorization))
    let harness = Self.mountHost(thread, reporter: RecordingFocusReporter())
    defer { harness.close() }

    for id in [Self.requestID, "elicitation-1", "authorization-1"] {
      #expect(harness.element(identifier: PendingRequestsHost.identifier(for: id)) != nil)
    }
    #expect(harness.element(identifier: AuthorizationView.identifier(for: authorization.id)) != nil)
    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
  }

  @Test func theThreadViewShowsThePendingCards() {
    let thread = AgentThread()
    thread.apply(.addPermission(Self.request))
    let harness = HostedViewHarness(AgentThreadView(thread: thread), size: Self.cardSize)
    defer { harness.close() }
    harness.pump()

    #expect(
      harness.element(identifier: PendingRequestsHost.identifier(for: Self.requestID)) != nil)
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
