/// The context window use, the token counts, the cost, and the quota of a
/// thread (plan.md §3.2, research R16).
///
/// This type merges three sources: the FoundationModels
/// `LanguageModelSession.Usage`, the Private Cloud Compute `QuotaUsage`, and
/// the ACP `usage_update`. `Docs/decisions/usage-model.md` maps each source
/// field to a stored property of this type. `ContextUsageTests` makes sure
/// that the table and this type agree. Each source fills only the parts that
/// it has. The other parts stay `nil`.
public nonisolated struct ContextUsage: Sendable, Hashable {
  /// The number of tokens in the context window now.
  public var used: Int

  /// The number of tokens that the context window holds.
  public var size: Int

  /// The cumulative cost of the session, or `nil` when the source gives no
  /// cost.
  public var cost: Cost?

  /// The input token counts, or `nil` when the source gives none.
  public var input: Input?

  /// The output token counts, or `nil` when the source gives none.
  public var output: Output?

  /// The quota state of the model service, or `nil` when the model has no
  /// quota.
  public var quota: Quota?

  /// Makes a usage value.
  ///
  /// - Parameters:
  ///   - used: The number of tokens in the context window now.
  ///   - size: The number of tokens that the context window holds.
  ///   - cost: The cumulative cost of the session, or `nil`.
  ///   - input: The input token counts, or `nil`.
  ///   - output: The output token counts, or `nil`.
  ///   - quota: The quota state of the model service, or `nil`.
  public init(
    used: Int,
    size: Int,
    cost: Cost? = nil,
    input: Input? = nil,
    output: Output? = nil,
    quota: Quota? = nil
  ) {
    self.used = used
    self.size = size
    self.cost = cost
    self.input = input
    self.output = output
    self.quota = quota
  }

  /// The part of the context window that is in use, from `0` to `1`.
  ///
  /// The value is ``used`` divided by ``size``, clamped to `0...1`. When
  /// ``size`` is `0` or less, the value is `0`.
  public var fraction: Double {
    guard size > 0 else { return 0 }
    return min(max(Double(used) / Double(size), 0), 1)
  }

  /// A cumulative cost in one currency.
  public struct Cost: Sendable, Hashable {
    /// The cost.
    public var amount: Double

    /// The ISO 4217 currency code, such as `USD`.
    public var currency: String

    /// Makes a cost.
    ///
    /// - Parameters:
    ///   - amount: The cost.
    ///   - currency: The ISO 4217 currency code.
    public init(amount: Double, currency: String) {
      self.amount = amount
      self.currency = currency
    }
  }

  /// The input token counts.
  public struct Input: Sendable, Hashable {
    /// The number of input tokens.
    public var total: Int

    /// The number of input tokens that came from a cache. This is a part of
    /// ``total``.
    public var cached: Int

    /// Makes input token counts.
    ///
    /// - Parameters:
    ///   - total: The number of input tokens.
    ///   - cached: The number of input tokens that came from a cache.
    public init(total: Int, cached: Int) {
      self.total = total
      self.cached = cached
    }
  }

  /// The output token counts.
  public struct Output: Sendable, Hashable {
    /// The number of output tokens.
    public var total: Int

    /// The number of output tokens that the model used to reason. This is a
    /// part of ``total``.
    public var reasoning: Int

    /// Makes output token counts.
    ///
    /// - Parameters:
    ///   - total: The number of output tokens.
    ///   - reasoning: The number of output tokens that the model used to
    ///     reason.
    public init(total: Int, reasoning: Int) {
      self.total = total
      self.reasoning = reasoning
    }
  }

  /// The quota state of a model service.
  ///
  /// The cases are the cases of the Private Cloud Compute
  /// `QuotaUsage.Status`. The FoundationModels adapter makes this value from
  /// a typed SDK enum, not from a wire string, so it has no `unknown` case.
  public enum Quota: Sendable, Hashable {
    /// The use is below the limit.
    ///
    /// - Parameter approaching: `true` when the use is near the limit.
    case belowLimit(approaching: Bool)

    /// The use is at the limit. The service refuses new requests until the
    /// quota resets.
    case limitReached
  }
}
