import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The default view of a transcript entry or a content block that the kit
/// does not know (plan.md §9 A2; update.md §4.4 "Unknown updates stay visible").
///
/// The view is a collapsible block. Its title holds the raw kind, and its
/// body is the raw value as pretty-printed JSON. The kit shows the value and
/// does not drop it. For an `UnknownEntry` of a `SessionModel`, the kind is
/// the type string of the session update, and the body is its raw JSON.
public struct UnknownItemView: View {
  /// The accessibility identifier of the view.
  public static let identifier = "unknown-item"

  /// The value that the view shows.
  private enum Source {
    /// An unknown entry of the transcript of a `SessionModel`. The body
    /// reads its current values.
    case entry(UnknownEntry)

    /// An unknown value, with the id that keys its expanded state.
    case value(kind: String, raw: JSONValue, id: String)

    /// An ACP value that the kit does not know, such as an unknown content
    /// block of a transcript entry, with the id that keys its expanded state.
    case wireValue(kind: String, raw: FoundationModelsACP.JSONValue, id: String)
  }

  /// The value to show.
  private let source: Source

  /// The start state when the environment has no ``ExpandedBlocksStore``.
  let isExpanded: Bool

  /// Makes the view of an unknown entry of a `SessionModel`.
  ///
  /// The title shows the type string of the update, and the body shows its
  /// raw JSON. The row key of the entry keys the expanded state.
  ///
  /// - Parameters:
  ///   - entry: The entry to show.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  public init(entry: UnknownEntry, isExpanded: Bool = false) {
    self.source = .entry(entry)
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

  /// Makes the view of an ACP value that the kit does not know, such as an
  /// unknown content block of a transcript entry.
  ///
  /// The view reads the ACP value directly.
  ///
  /// - Parameters:
  ///   - kind: The type name that the agent gave.
  ///   - raw: The value as the entry holds it.
  ///   - id: The id that keys the expanded state in the
  ///     ``ExpandedBlocksStore``.
  ///   - isExpanded: The start state when the environment has no
  ///     ``ExpandedBlocksStore``. The default is collapsed.
  init(kind: String, wireValue raw: FoundationModelsACP.JSONValue, id: String, isExpanded: Bool = false) {
    self.source = .wireValue(kind: kind, raw: raw, id: id)
    self.isExpanded = isExpanded
  }

  public var body: some View {
    let (id, kind, json) = resolved
    JSONDisclosure(
      id: id,
      title: String(localized: "Unknown item: \(kind)"),
      json: json,
      identifier: Self.identifier,
      isExpanded: isExpanded
    )
  }

  /// The id, the kind, and the pretty-printed JSON of the current raw value
  /// of the source.
  private var resolved: (id: String, kind: String, json: String) {
    switch source {
    case .entry(let entry):
      (entry.id.rowKey, entry.type, entry.raw.prettyPrinted)
    case .value(let kind, let raw, let id):
      (id, kind, raw.prettyPrinted)
    case .wireValue(let kind, let raw, let id):
      (id, kind, raw.prettyPrinted)
    }
  }
}
