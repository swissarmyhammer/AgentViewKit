import SwiftUI

/// The default view of a structured item (plan.md §3.6, §9 A2).
///
/// The thread shows this view when no registration matches the schema name
/// of the record. The view is a collapsible block. Its title is the schema
/// name, and its body is the payload as pretty-printed JSON.
public struct StructuredItemView: View {
  /// The start of the accessibility identifier of the view.
  public static let identifierPrefix = "structured-item-"

  /// The record to show.
  let record: StructuredRecord

  /// The start state when the environment has no ``ExpandedBlocksStore``.
  let isExpanded: Bool

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - record: The record to show.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  public init(record: StructuredRecord, isExpanded: Bool = false) {
    self.record = record
    self.isExpanded = isExpanded
  }

  /// The accessibility identifier of the view of `schemaName`.
  ///
  /// - Parameter schemaName: The schema name of the record.
  /// - Returns: `structured-item-<schemaName>`.
  public static func identifier(for schemaName: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: schemaName)
  }

  public var body: some View {
    JSONDisclosure(
      id: record.id,
      title: record.schemaName,
      json: record.payload.prettyPrinted,
      identifier: Self.identifier(for: record.schemaName),
      isExpanded: isExpanded
    )
  }
}
