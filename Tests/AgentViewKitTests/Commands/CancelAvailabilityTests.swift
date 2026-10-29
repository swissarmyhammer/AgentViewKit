@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorTestSupport
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
  /// The running state.
  static let running = StateUpdate.running(RunningStateUpdate())

  /// The requires-action state.
  static let requiresAction = StateUpdate.requiresAction(RequiresActionStateUpdate())

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
    let model = CancelFixtures.makeSession(
      state: CancelFixtures.idle, pendingPermissions: [CancelFixtures.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(model.pendingPermissions.count == 1)
    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
  }

  @Test func anIdleSessionWithNoPendingRequestCannotCancel() throws {
    let model = CancelFixtures.makeSession(state: CancelFixtures.idle)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(!AgentCommandTarget.canCancel(model))
    #expect(try !AgentCommandsTests.isAvailable(.cancel, in: fixture))
  }

  @Test func aSessionWithNoStateAndAPendingPermissionCannotCancel() throws {
    let model = CancelFixtures.makeSession(
      state: nil, pendingPermissions: [CancelFixtures.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(!AgentCommandTarget.canCancel(model))
    #expect(try !AgentCommandsTests.isAvailable(.cancel, in: fixture))
  }

  // MARK: - Running and requires action

  @Test func aRunningSessionCanCancel() throws {
    let model = CancelFixtures.makeSession(state: Self.running)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(Self.escapeCancels(in: model))
  }

  @Test func aSessionThatRequiresActionCanCancel() throws {
    let model = CancelFixtures.makeSession(state: Self.requiresAction)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(Self.escapeCancels(in: model))
  }

  // MARK: - A request that ends

  @Test func theEndOfThePendingRequestsOfAnIdleSessionStopsTheCancel() throws {
    let model = CancelFixtures.makeSession(
      state: CancelFixtures.idle, pendingPermissions: [CancelFixtures.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)
    let reader = ObservationFlag.observing { _ = AgentCommandTarget.canCancel(model) }

    model.cancelAllPending()

    #expect(reader.isRaised)
    #expect(model.pendingPermissions.isEmpty)
    #expect(!AgentCommandTarget.canCancel(model))
    #expect(try !AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(!Self.escapeCancels(in: model))
  }

  // MARK: - Esc

  @Test func escapeCancelsAnIdleSessionWithAPendingPermission() {
    let model = CancelFixtures.makeSession(
      state: CancelFixtures.idle, pendingPermissions: [CancelFixtures.permissionRequest])
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(Self.escapeCancels(in: model))
    #expect(Self.escapeResolvesToCancel(in: fixture))
  }

  @Test func escapeDoesNotCancelAnIdleSessionWithNoPendingRequest() {
    let model = CancelFixtures.makeSession(state: CancelFixtures.idle)
    let fixture = AgentCommandsTests.makeFixture(session: model)

    #expect(!Self.escapeCancels(in: model))
    #expect(!Self.escapeResolvesToCancel(in: fixture))
  }

  @Test func escapeDoesNotCancelWithNoSessionModel() {
    #expect(!Self.escapeCancels(in: nil))
  }

  // MARK: - A request that arrives over the wire

  @Test func aSessionElicitationThatArrivesWhileIdleEnablesCancelAndEscape() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let fixture = AgentCommandsTests.makeFixture(session: model)
    try await CancelFixtures.makeIdleAfterRunning(session)
    #expect(!AgentCommandTarget.canCancel(model))

    try await session.sendRequest(
      ScriptedSession.elicitationMethod, id: AgentCommandFixtures.agentRequestID,
      params: ScriptedSession.formElicitationParams)
    await ObservationWait.until { !model.pendingElicitations.isEmpty }

    #expect(CancelFixtures.isIdle(model.agentState))
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
    try await CancelFixtures.makeIdleAfterRunning(session)
    #expect(!AgentCommandTarget.canCancel(model))
    #expect(!Self.escapeCancels(in: model))
    let reader = ObservationFlag.observing { _ = AgentCommandTarget.canCancel(model) }

    try await session.sendRequest(
      ScriptedSession.permissionMethod, id: AgentCommandFixtures.agentRequestID,
      params: ScriptedSession.permissionParams)
    await ObservationWait.until { !model.pendingPermissions.isEmpty }

    #expect(reader.isRaised)
    #expect(CancelFixtures.isIdle(model.agentState))
    #expect(AgentCommandTarget.canCancel(model))
    #expect(try AgentCommandsTests.isAvailable(.cancel, in: fixture))
    #expect(Self.escapeCancels(in: model))
    #expect(Self.escapeResolvesToCancel(in: fixture))
  }
}
