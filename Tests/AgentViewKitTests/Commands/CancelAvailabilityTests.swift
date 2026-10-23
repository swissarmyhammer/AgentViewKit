@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests for the one cancel rule, ``AgentCommandTarget/canCancel(_:)``.
///
/// The cancel command, the Esc key of the command scope, and the Esc key of
/// the composer read this rule. Most tests make a preview session model with
/// its state and its pending requests directly, in a fixed order, and then
/// assert. The wire tests send `running`, `idle`, and then a request, in this
/// order. Before each next step they wait for the event that the model has
/// the change (``ObservationWait/until(_:)``). No test reads a clock, polls,
/// or has a time limit.
@MainActor struct CancelAvailabilityTests {
  /// The idle state, with no stop reason.
  static let idle = StateUpdate.idle(IdleStateUpdate())

  /// The running state.
  static let running = StateUpdate.running(RunningStateUpdate())

  /// The requires-action state.
  static let requiresAction = StateUpdate.requiresAction(RequiresActionStateUpdate())

  /// A permission request of the preview session, with one allow option and
  /// one reject option.
  static let permissionRequest = RequestPermissionRequest(
    options: [
      PermissionOption(kind: .allowOnce, name: "Allow", optionId: PermissionOptionId(rawValue: "allow")),
      PermissionOption(kind: .rejectOnce, name: "Reject", optionId: PermissionOptionId(rawValue: "reject")),
    ],
    sessionId: SessionModel.previewSessionId,
    title: "Run the tests?")

  /// Makes a preview session model: first the state, then the permission
  /// requests, in this order.
  ///
  /// - Parameters:
  ///   - state: The `agentState` of the model, or `nil` for no state.
  ///   - pendingPermissions: The permission requests that arrive after the
  ///     state.
  /// - Returns: The model.
  static func makeSession(
    state: StateUpdate?, pendingPermissions: [RequestPermissionRequest] = []
  ) -> SessionModel {
    SessionModel.preview(
      transcript: state.map { [.update(.stateUpdate($0))] } ?? [],
      pendingPermissions: pendingPermissions)
  }

  /// Tells if the Esc key of the composer cancels for `session`.
  ///
  /// - Parameter session: The session model of the composer.
  /// - Returns: `true` when the composer gives an Esc action to its editor.
  static func escapeCancels(in session: SessionModel?) -> Bool {
    PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>.cancelsOnEscape(in: session)
  }

  /// Tells if the Esc key of the command scope resolves to the cancel
  /// command.
  ///
  /// - Parameter fixture: The fixture of the scope.
  /// - Returns: `true` when Esc resolves to ``AgentCommandVerb/cancel``.
  static func escapeResolvesToCancel(in fixture: AgentCommandsTests.Fixture) -> Bool {
    fixture.system.registry.resolveKey(KeySequence(.escape), mode: .cua, at: fixture.path)
      == .command(AgentCommandVerb.cancel.id, scope: fixture.path)
  }

  // MARK: - Idle

  @Test func anIdleSessionWithAPendingPermissionCanCancel() throws {
    let model = Self.makeSession(state: Self.idle, pendingPermissions: [Self.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(model.pendingPermissions.count == 1)
    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
  }

  @Test func anIdleSessionWithNoPendingRequestCannotCancel() throws {
    let model = Self.makeSession(state: Self.idle)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(!AgentCommandTarget.canCancel(model))
    #expect(try !AgentCommandsTests.isAvailable(.cancel, in: fixture))
  }

  @Test func aSessionWithNoStateAndAPendingPermissionCannotCancel() throws {
    let model = Self.makeSession(state: nil, pendingPermissions: [Self.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(!AgentCommandTarget.canCancel(model))
    #expect(try !AgentCommandsTests.isAvailable(.cancel, in: fixture))
  }

  // MARK: - Running and requires action

  @Test func aRunningSessionCanCancel() throws {
    let model = Self.makeSession(state: Self.running)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(Self.escapeCancels(in: model))
  }

  @Test func aSessionThatRequiresActionCanCancel() throws {
    let model = Self.makeSession(state: Self.requiresAction)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(Self.escapeCancels(in: model))
  }

  // MARK: - A request that ends

  @Test func theEndOfThePendingRequestsOfAnIdleSessionStopsTheCancel() throws {
    let model = Self.makeSession(state: Self.idle, pendingPermissions: [Self.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)
    let reader = ChangeFlag.observing { _ = AgentCommandTarget.canCancel(model) }

    model.cancelAllPending()

    #expect(reader.value)
    #expect(model.pendingPermissions.isEmpty)
    #expect(!AgentCommandTarget.canCancel(model))
    #expect(try !AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(!Self.escapeCancels(in: model))
  }

  // MARK: - Esc

  @Test func escapeCancelsAnIdleSessionWithAPendingPermission() {
    let model = Self.makeSession(state: Self.idle, pendingPermissions: [Self.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(Self.escapeCancels(in: model))
    #expect(Self.escapeResolvesToCancel(in: fixture))
  }

  @Test func escapeDoesNotCancelAnIdleSessionWithNoPendingRequest() {
    let model = Self.makeSession(state: Self.idle)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(!Self.escapeCancels(in: model))
    #expect(!Self.escapeResolvesToCancel(in: fixture))
  }

  @Test func escapeDoesNotCancelWithNoSessionModel() {
    #expect(!Self.escapeCancels(in: nil))
  }

  // MARK: - A request that arrives over the wire

  /// Tells if `state` is the idle state.
  ///
  /// - Parameter state: The `agentState` of a session model, or `nil`.
  /// - Returns: `true` for `.idle`.
  static func isIdle(_ state: StateUpdate?) -> Bool {
    if case .idle = state { true } else { false }
  }

  /// Sends `running` and then `idle` from the agent, in this order.
  ///
  /// Each send waits for the event that the model has the state, so the next
  /// update goes out after the model folded the last one.
  ///
  /// - Parameter session: The scripted session.
  /// - Throws: The error of the transport.
  static func makeIdleAfterRunning(_ session: ScriptedSession) async throws {
    let model = session.model
    try await session.sendUpdate(ScriptedSession.runningState)
    await ObservationWait.until { AgentCommandTarget.isActive(model.agentState) }
    try await session.sendUpdate(ScriptedSession.idleState)
    await ObservationWait.until { Self.isIdle(model.agentState) }
  }

  @Test func aSessionElicitationThatArrivesWhileIdleEnablesCancelAndEscape() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let fixture = AgentCommandsTests.makeFixture(session: model)
    try await Self.makeIdleAfterRunning(session)
    #expect(!AgentCommandTarget.canCancel(model))

    try await session.sendRequest(
      ScriptedSession.elicitationMethod, id: AgentCommandsTests.agentRequestID,
      params: ScriptedSession.formElicitationParams)
    await ObservationWait.until { !model.pendingElicitations.isEmpty }

    #expect(Self.isIdle(model.agentState))
    #expect(model.pendingPermissions.isEmpty)
    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(Self.escapeCancels(in: model))
    #expect(Self.escapeResolvesToCancel(in: fixture))
  }

  @Test func aPermissionRequestThatArrivesWhileIdleChangesTheCancelRule() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let fixture = AgentCommandsTests.makeFixture(session: model)
    try await Self.makeIdleAfterRunning(session)
    #expect(!AgentCommandTarget.canCancel(model))
    #expect(!Self.escapeCancels(in: model))
    let reader = ChangeFlag.observing { _ = AgentCommandTarget.canCancel(model) }

    try await session.sendRequest(
      ScriptedSession.permissionMethod, id: AgentCommandsTests.agentRequestID,
      params: ScriptedSession.permissionParams)
    await ObservationWait.until { !model.pendingPermissions.isEmpty }

    #expect(reader.value)
    #expect(Self.isIdle(model.agentState))
    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(Self.escapeCancels(in: model))
    #expect(Self.escapeResolvesToCancel(in: fixture))
  }
}
