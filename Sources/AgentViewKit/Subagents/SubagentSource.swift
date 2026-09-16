/// The data sources that can supply the subagent tree (plan.md §14, R14).
///
/// `Docs/decisions/subagent-source.md` compares the candidates and records the
/// v1 decision. `SubagentSourceTests` makes sure that ``v1`` and the
/// `decision:` line of that file agree. The raw value of each case is the
/// name that the file uses.
///
/// This enum records a design decision. No adapter decodes it from a wire
/// payload, so it has no `unknown` case.
public enum SubagentSource: String, Sendable, CaseIterable {
  /// The FoundationModelsRouter recording. The `session` `TranscriptEvent`
  /// of a spawned session carries `agentSpawn`, with the parent session id and
  /// the parent tool call id.
  case router

  /// The ACP `_meta` object on a `tool_call_update` that starts a subagent.
  case acpMeta

  /// The AG-UI `SUBAGENT_STARTED`, `SUBAGENT_FINISHED`, and `SUBAGENT_ERROR`
  /// events. The kit uses them only as a reference shape.
  case agUI

  /// The source that the v1 subagent tree reads.
  public static let v1: SubagentSource = .router
}
