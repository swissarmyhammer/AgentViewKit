/// The ids of the permission request that the scripted agent sends in the
/// command tests, and of its options.
///
/// The command tests and the hosted tests of the views that answer the
/// request share these ids.
public nonisolated enum AgentCommandFixtures {
  /// The JSON-RPC id of the permission request that the scripted agent sends.
  public static let agentRequestID = 100

  /// The `allow_once` option of ``ScriptedSession/permissionParams``.
  public static let allowOptionID = "yes"

  /// The `reject_once` option of ``ScriptedSession/permissionParams``.
  public static let rejectOptionID = "no"
}
