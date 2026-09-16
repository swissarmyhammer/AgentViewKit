/// The run state of a thread (plan.md §3.2).
///
/// The adapter sets the state. ACP `state_update` gives it directly. A
/// FoundationModels session gives it from `isResponding`. The kit makes this
/// state and does not read it from a wire string, so it has no `unknown` case.
/// A stop reason that the kit does not know is ``StopReason/unknown(_:)``.
public nonisolated enum ThreadState: Sendable, Hashable {
  /// The agent does not run a turn.
  ///
  /// The value is the reason that the last turn stopped, or `nil` when no
  /// turn has run or the source gives no reason.
  case idle(StopReason?)

  /// The agent runs a turn.
  case running

  /// The agent waits for the user, for example for a permission answer.
  case requiresAction
}

/// The reason that a turn stopped (plan.md §3.2).
///
/// The wire values are the ACP `StopReason` strings.
public nonisolated enum StopReason: WireValueEnum {
  /// The agent finished the turn.
  case endTurn

  /// The model used its maximum number of output tokens.
  case maxTokens

  /// The turn used its maximum number of model requests.
  case maxTurnRequests

  /// The model refused to continue.
  case refusal

  /// The client cancelled the turn.
  case cancelled

  /// A stop reason that the kit does not know, with its wire string.
  case unknown(String)

  /// Each case of the enum, but not ``unknown(_:)``.
  public static let knownCases: [StopReason] = [
    .endTurn, .maxTokens, .maxTurnRequests, .refusal, .cancelled,
  ]

  /// The ACP wire string of the case.
  public var wireValue: String {
    switch self {
    case .endTurn: "end_turn"
    case .maxTokens: "max_tokens"
    case .maxTurnRequests: "max_turn_requests"
    case .refusal: "refusal"
    case .cancelled: "cancelled"
    case .unknown(let wireValue): wireValue
    }
  }
}
