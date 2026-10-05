/// The context window use and the cost of a thread (plan.md §3.2, research
/// R16).
///
/// The source is the ACP `usage_update`. `Docs/decisions/usage-model.md` maps
/// each `usage_update` field to a stored property of this type.
/// `ContextUsageTests` makes sure that the table and this type agree.
public nonisolated struct ContextUsage: Sendable, Hashable {
  /// The number of tokens in the context window now.
  public var used: Int

  /// The number of tokens that the context window holds.
  public var size: Int

  /// The cumulative cost of the session, or `nil` when the source gives no
  /// cost.
  public var cost: Cost?

  /// Makes a usage value.
  ///
  /// - Parameters:
  ///   - used: The number of tokens in the context window now.
  ///   - size: The number of tokens that the context window holds.
  ///   - cost: The cumulative cost of the session, or `nil`.
  public init(used: Int, size: Int, cost: Cost? = nil) {
    self.used = used
    self.size = size
    self.cost = cost
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
  public struct Cost: Sendable, Hashable, Codable {
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
}
