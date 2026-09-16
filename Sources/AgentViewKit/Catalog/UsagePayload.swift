/// The context usage of a thread, as a structured segment (plan.md §3.3,
/// research R16).
///
/// The schema name is `AgentViewKit.UsagePayload`. The payload has the
/// stored properties of ``ContextUsage``. `Docs/decisions/usage-model.md`
/// tells what each property holds.
public nonisolated struct UsagePayload: StructuredPayload, Hashable {
  /// The number of tokens in the context window now.
  public var used: Int

  /// The number of tokens that the context window holds.
  public var size: Int

  /// The cumulative cost of the session, or `nil`.
  public var cost: ContextUsage.Cost?

  /// The input token counts, or `nil`.
  public var input: ContextUsage.Input?

  /// The output token counts, or `nil`.
  public var output: ContextUsage.Output?

  /// The quota state of the model service, or `nil`.
  public var quota: ContextUsage.Quota?

  /// Makes a usage payload from a usage value.
  ///
  /// - Parameter usage: The usage value to copy.
  public init(_ usage: ContextUsage) {
    used = usage.used
    size = usage.size
    cost = usage.cost
    input = usage.input
    output = usage.output
    quota = usage.quota
  }

  /// The usage value that the payload holds.
  public var usage: ContextUsage {
    ContextUsage(used: used, size: size, cost: cost, input: input, output: output, quota: quota)
  }
}
