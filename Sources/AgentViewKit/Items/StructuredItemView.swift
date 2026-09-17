import SwiftUI

/// The default view of a structured item or a structured content block
/// (plan.md §3.6, §9 A2).
///
/// The thread shows this view when no registration matches the schema name
/// of the record. The view is a collapsible block. Its title is the schema
/// name, and its body is the payload as pretty-printed JSON.
public struct StructuredItemView: View {
  /// The start of the accessibility identifier of the view.
  public static let identifierPrefix = "structured-item-"

  /// The value that the view shows.
  private enum Source {
    /// A structured thread item. The body reads its current values.
    case record(StructuredRecord)

    /// A structured value, with the id that keys its expanded state.
    case content(StructuredItemContent, id: String)
  }

  /// The value to show.
  private let source: Source

  /// The start state when the environment has no ``ExpandedBlocksStore``.
  let isExpanded: Bool

  /// Makes the view of a structured thread item.
  ///
  /// - Parameters:
  ///   - record: The record to show.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  public init(record: StructuredRecord, isExpanded: Bool = false) {
    self.source = .record(record)
    self.isExpanded = isExpanded
  }

  /// Makes the view of a structured value, such as a structured content
  /// block.
  ///
  /// - Parameters:
  ///   - content: The value to show.
  ///   - id: The id that keys the expanded state in the
  ///     ``ExpandedBlocksStore``.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  public init(content: StructuredItemContent, id: String, isExpanded: Bool = false) {
    self.source = .content(content, id: id)
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
    let (id, content) = resolved
    JSONDisclosure(
      id: id,
      title: content.schemaName,
      json: content.payload.prettyPrinted,
      identifier: Self.identifier(for: content.schemaName),
      isExpanded: isExpanded
    )
  }

  /// The id and the current value of the source.
  private var resolved: (id: String, content: StructuredItemContent) {
    switch source {
    case .record(let record):
      (record.id, StructuredItemContent(record: record))
    case .content(let content, let id):
      (id, content)
    }
  }
}
