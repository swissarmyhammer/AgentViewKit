import SwiftUI

/// The default view of an item or a content block that the adapter did not
/// know (plan.md §9 A2).
///
/// The view is a collapsible block. Its title holds the raw kind, and its
/// body is the raw value as pretty-printed JSON. The kit shows the value and
/// does not drop it.
public struct UnknownItemView: View {
  /// The accessibility identifier of the view.
  public static let identifier = "unknown-item"

  /// The value that the view shows.
  private enum Source {
    /// An unknown thread item. The body reads its current values.
    case record(UnknownRecord)

    /// An unknown value, with the id that keys its expanded state.
    case value(kind: String, raw: JSONValue, id: String)
  }

  /// The value to show.
  private let source: Source

  /// The start state when the environment has no ``ExpandedBlocksStore``.
  let isExpanded: Bool

  /// Makes the view of an unknown thread item.
  ///
  /// - Parameters:
  ///   - record: The record to show.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  public init(record: UnknownRecord, isExpanded: Bool = false) {
    self.source = .record(record)
    self.isExpanded = isExpanded
  }

  /// Makes the view of an unknown value, such as an unknown content block.
  ///
  /// - Parameters:
  ///   - kind: The type name that the source gave.
  ///   - raw: The value as the source gave it.
  ///   - id: The id that keys the expanded state in the
  ///     ``ExpandedBlocksStore``.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  public init(kind: String, raw: JSONValue, id: String, isExpanded: Bool = false) {
    self.source = .value(kind: kind, raw: raw, id: id)
    self.isExpanded = isExpanded
  }

  public var body: some View {
    let (id, kind, raw) = resolved
    JSONDisclosure(
      id: id,
      title: String(localized: "Unknown item: \(kind)"),
      json: raw.prettyPrinted,
      identifier: Self.identifier,
      isExpanded: isExpanded
    )
  }

  /// The id, the kind, and the current raw value of the source.
  private var resolved: (id: String, kind: String, raw: JSONValue) {
    switch source {
    case .record(let record):
      (record.id, record.kind, record.raw)
    case .value(let kind, let raw, let id):
      (id, kind, raw)
    }
  }
}
