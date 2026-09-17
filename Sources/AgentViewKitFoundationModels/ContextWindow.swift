import FoundationModels

/// Measures the context window of a model (`Docs/decisions/usage-model.md`).
///
/// ``SessionThreadSource`` uses these two closures to fill
/// ``AgentViewKit/ContextUsage/used`` and ``AgentViewKit/ContextUsage/size``.
/// `LanguageModelSession.Usage` holds cumulative token counts and not the
/// fill of the window, so the source counts the transcript entries.
public nonisolated struct ContextWindow: Sendable {
  /// Gives the number of tokens that the context window of the model holds.
  public var size: @Sendable () async throws -> Int

  /// Gives the number of tokens that the entries of a transcript use.
  public var tokenCount: @Sendable (Transcript) async throws -> Int

  /// Makes a context window measure.
  ///
  /// - Parameters:
  ///   - size: Gives the number of tokens that the window holds.
  ///   - tokenCount: Gives the number of tokens that a transcript uses.
  public init(
    size: @escaping @Sendable () async throws -> Int,
    tokenCount: @escaping @Sendable (Transcript) async throws -> Int
  ) {
    self.size = size
    self.tokenCount = tokenCount
  }

  /// The context window of an on-device model.
  ///
  /// - Parameter model: The on-device model.
  /// - Returns: A measure that reads `SystemLanguageModel.contextSize` and
  ///   calls `SystemLanguageModel.tokenCount(for:)`.
  public static func system(_ model: SystemLanguageModel = .default) -> ContextWindow {
    ContextWindow(
      size: { model.contextSize },
      tokenCount: { transcript in try await model.tokenCount(for: transcript) }
    )
  }
}
