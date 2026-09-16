/// A string identifier that is typed by the thing that it identifies
/// (plan.md §3.2).
///
/// The `Tag` type is not stored. It makes two identifier types different,
/// so that the compiler stops a ``TerminalID`` where a ``ConfigOptionID`` is
/// necessary. ``PlanID`` is also this type. The ``description`` shows the
/// name of `Tag`. The JSON form is the identifier string.
public nonisolated struct Identifier<Tag>: Sendable, Hashable, RawRepresentable, Codable,
  CustomStringConvertible
{
  /// The identifier string.
  public let rawValue: String

  /// Makes an identifier from its string.
  ///
  /// - Parameter rawValue: The identifier string.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }

  /// Makes an identifier from its string.
  ///
  /// - Parameter rawValue: The identifier string.
  public init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }

  /// The name of the identified type and the identifier string, such as
  /// `TerminalRecord(t1)`.
  public var description: String {
    "\(Tag.self)(\(rawValue))"
  }
}
