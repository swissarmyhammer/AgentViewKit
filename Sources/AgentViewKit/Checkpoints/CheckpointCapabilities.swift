/// What one data source can restore from a checkpoint (plan.md §14, R13).
///
/// `Docs/decisions/checkpoints.md` records the survey and the v1 decision.
/// `CheckpointCapabilitiesTests` parses the table of that file and compares
/// each row with the value of the same source. The raw values of ``Source``
/// and ``Granularity`` are the names that the table uses.
///
/// This type records a design decision. No adapter decodes it from a wire
/// payload, so its enums have no `unknown` case.
public nonisolated struct CheckpointCapabilities: Sendable, Hashable {
  /// The data sources that the checkpoint survey compares.
  public enum Source: String, Sendable, Hashable, CaseIterable {
    /// The FoundationModelsRouter session. `RoutedSession.fork(workingDirectory:)`
    /// copies the conversation into a new child session.
    case router

    /// An ACP agent. The unstable `session/fork` method copies the
    /// conversation into a new ACP session.
    case acp
  }

  /// The smallest step at which a source can go back.
  ///
  /// No v1 source gives a restore point inside a turn, so there is no
  /// entry case. A new decision adds it when a source gives one.
  public enum Granularity: String, Sendable, Hashable, CaseIterable {
    /// The kit cannot use the source to restore anything in v1.
    case unavailable

    /// One restore point for each completed turn. The source copies the
    /// conversation only between turns.
    case turn
  }

  /// The source that these capabilities apply to.
  public let source: Source

  /// `true` when the source can put the files of the working directory back.
  public let restoresCode: Bool

  /// `true` when the source can put the conversation back.
  public let restoresConversation: Bool

  /// The smallest step at which the source can go back.
  public let granularity: Granularity

  /// The API call or the wire method that makes the restore point.
  public let wireCall: String

  /// The FoundationModelsRouter capabilities.
  ///
  /// A fork between turns copies the conversation. The fork does not copy
  /// files, so the Router cannot restore code.
  public static let router = CheckpointCapabilities(
    source: .router,
    restoresCode: false,
    restoresConversation: true,
    granularity: .turn,
    wireCall: "RoutedSession.fork(workingDirectory:)"
  )

  /// The ACP capabilities.
  ///
  /// `session/fork` is in the unstable schema only, and the kit must not
  /// build on it. Thus v1 cannot restore anything from an ACP agent.
  public static let acp = CheckpointCapabilities(
    source: .acp,
    restoresCode: false,
    restoresConversation: false,
    granularity: .unavailable,
    wireCall: "session/fork"
  )

  /// The capabilities of each source, in the order of ``Source/allCases``.
  public static let all: [CheckpointCapabilities] = Source.allCases.map(capabilities(for:))

  /// Gives the capabilities of one source.
  ///
  /// - Parameter source: The data source.
  /// - Returns: The static value for that source.
  public static func capabilities(for source: Source) -> CheckpointCapabilities {
    switch source {
    case .router: router
    case .acp: acp
    }
  }
}
