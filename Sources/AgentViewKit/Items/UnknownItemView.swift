import SwiftUI

/// The default view of an item that the adapter did not know (plan.md §9 A2).
///
/// The view is a collapsible block. Its title holds the raw kind, and its
/// body is the raw item as pretty-printed JSON. The kit shows the item and
/// does not drop it.
public struct UnknownItemView: View {
  /// The accessibility identifier of the view.
  public static let identifier = "unknown-item"

  /// The record to show.
  let record: UnknownRecord

  /// The start state when the environment has no ``ExpandedBlocksStore``.
  let isExpanded: Bool

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - record: The record to show.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  public init(record: UnknownRecord, isExpanded: Bool = false) {
    self.record = record
    self.isExpanded = isExpanded
  }

  public var body: some View {
    JSONDisclosure(
      id: record.id,
      title: String(localized: "Unknown item: \(record.kind)"),
      json: record.raw.prettyPrinted,
      identifier: Self.identifier,
      isExpanded: isExpanded
    )
  }
}
