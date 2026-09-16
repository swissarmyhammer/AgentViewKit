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

  /// Makes a usage value from the tokens in use and the part of the window
  /// that they fill.
  ///
  /// A source that gives the fill but not the window size uses this
  /// initializer. The size is `used` divided by `fill`, rounded. When `fill`
  /// is not a positive finite number, the size is `0`, so ``fraction`` is `0`.
  ///
  /// - Parameters:
  ///   - used: The number of tokens in the context window now.
  ///   - fill: The part of the context window that `used` fills, from `0` to
  ///     `1`.
  public init(used: Int, fill: Double) {
    guard fill.isFinite, fill > 0 else {
      self.init(used: used, size: 0)
      return
    }
    self.init(used: used, size: Int((Double(used) / fill).rounded()))
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

  /// The input token counts.
  public struct Input: Sendable, Hashable, Codable {
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
  public struct Output: Sendable, Hashable, Codable {
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
  ///
  /// The JSON form is an object with a `status` key, `belowLimit` or
  /// `limitReached`. The `belowLimit` form also has an `approaching` key.
  public enum Quota: Sendable, Hashable, Codable {
    /// The use is below the limit.
    ///
    /// - Parameter approaching: `true` when the use is near the limit.
    case belowLimit(approaching: Bool)

    /// The use is at the limit. The service refuses new requests until the
    /// quota resets.
    case limitReached

    /// The keys of the JSON form.
    private enum CodingKeys: String, CodingKey {
      case status
      case approaching
    }

    /// The values of the `status` key.
    private enum Status: String, Codable {
      case belowLimit
      case limitReached
    }

    /// Decodes a quota state from its JSON form.
    ///
    /// - Parameter decoder: The decoder to read from.
    /// - Throws: `DecodingError` when the `status` value is not known, or
    ///   when a `belowLimit` form has no `approaching` value.
    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      switch try container.decode(Status.self, forKey: .status) {
      case .belowLimit:
        self = .belowLimit(approaching: try container.decode(Bool.self, forKey: .approaching))
      case .limitReached:
        self = .limitReached
      }
    }

    /// Encodes the quota state in its JSON form.
    ///
    /// - Parameter encoder: The encoder to write to.
    /// - Throws: The error of the encoder.
    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .belowLimit(let approaching):
        try container.encode(Status.belowLimit, forKey: .status)
        try container.encode(approaching, forKey: .approaching)
      case .limitReached:
        try container.encode(Status.limitReached, forKey: .status)
      }
    }
  }
}
