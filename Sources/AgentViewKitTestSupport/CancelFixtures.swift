import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient

/// The session fixtures of the cancel rule: the idle state, a permission
/// request, a preview session model, and the `running` then `idle` order of a
/// scripted agent.
///
/// The cancel tests and the hosted tests of the views that read the rule
/// share these fixtures.
public enum CancelFixtures {
  /// The idle state, with no stop reason.
  public static let idle = StateUpdate.idle(IdleStateUpdate())

  /// A permission request of the preview session, with one allow option and
  /// one reject option.
  public static let permissionRequest = RequestPermissionRequest(
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
  public static func makeSession(
    state: StateUpdate?, pendingPermissions: [RequestPermissionRequest] = []
  ) -> SessionModel {
    SessionModel.preview(
      transcript: state.map { [.update(.stateUpdate($0))] } ?? [],
      pendingPermissions: pendingPermissions)
  }

  /// Tells if `state` is the idle state.
  ///
  /// - Parameter state: The `agentState` of a session model, or `nil`.
  /// - Returns: `true` for `.idle`.
  public static func isIdle(_ state: StateUpdate?) -> Bool {
    if case .idle = state { true } else { false }
  }

  /// Tells if `state` is foreground work of the agent, as the cancel rule of
  /// the kit reads it.
  ///
  /// - Parameter state: The `agentState` of a session model, or `nil`.
  /// - Returns: `true` for `.running` and `.requiresAction`.
  private static func isActive(_ state: StateUpdate?) -> Bool {
    switch state {
    case .running, .requiresAction: true
    case .idle, .unknown, nil: false
    }
  }

  /// Sends `running` and then `idle` from the agent, in this order.
  ///
  /// Each send waits for the event that the model has the state, so the next
  /// update goes out after the model folded the last one.
  ///
  /// - Parameter session: The scripted session.
  /// - Throws: The error of the transport.
  public static func makeIdleAfterRunning(_ session: ScriptedSession) async throws {
    let model = session.model
    try await session.sendUpdate(ScriptedSession.runningState)
    await ObservationWait.until { isActive(model.agentState) }
    try await session.sendUpdate(ScriptedSession.idleState)
    await ObservationWait.until { isIdle(model.agentState) }
  }
}
