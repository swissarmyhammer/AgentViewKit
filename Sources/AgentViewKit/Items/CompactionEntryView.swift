import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The row of a context compaction of a `SessionModel` (plan.md §3.2; the
/// owner decision of 2026-10-04 in `Docs/decisions/acp-client-kit.md`).
///
/// A compaction changes only the model context of the agent. The transcript
/// keeps the full history, so the row is a mark at the position where the
/// compaction first appeared. The row shows that the agent compacted the
/// context, and the status from the last `compaction_update`:
///
/// | Status | Text |
/// |--------|------|
/// | `in_progress` | In progress |
/// | `completed` | Completed |
/// | `failed` | Failed, with the reason when the agent gave one |
/// | `cancelled` | Cancelled |
/// | no update yet | No status yet |
/// | other | Unknown status, with the wire value |
///
/// Below the status, the row shows the ACP content blocks of the summary that
/// the compaction keeps, as the entry holds them, through an
/// ``EntryContentView``.
///
/// The view reads the entry object, so each later `compaction_update` and
/// each `compaction_summary_chunk` changes this row in place. Compaction is
/// stable ACP since schema alpha.8.
///
/// The row is content of the transcript, so it has no fill and no glass. A
/// separator stroke marks its edge
/// (`.inlineEdge(radius:)`, D113).
public struct CompactionEntryView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of the title and the status of
  /// each row. The rest is the row key of the entry.
  public static let identifierPrefix = "compaction-"

  /// The accessibility identifier of the reason of a failed compaction.
  public static let errorIdentifier = "compaction-error"

  /// The SF Symbol name of the row.
  private static let symbolName = SharedSymbol.compaction

  /// The text after the row key in the start of the id of each summary
  /// block view.
  private static let summaryIDSuffix = "-summary"

  /// The compaction entry to show.
  let entry: CompactionEntry

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// Makes the row of a compaction entry of a `SessionModel`.
  ///
  /// - Parameter entry: The compaction entry to show.
  public init(entry: CompactionEntry) {
    self.entry = entry
  }

  /// The title of each row.
  private static var title: String {
    String(localized: "Context compaction", bundle: .module)
  }

  /// The name of a compaction status.
  ///
  /// - Parameter status: The status of the compaction.
  /// - Returns: The name of the status. The status of an entry with no
  ///   `compaction_update` gives "No status yet", and a status that the kit
  ///   does not know gives its wire value.
  private static func statusLabel(for status: CompactionStatus) -> String {
    switch status {
    case .inProgress: WorkStatusLabel.inProgress
    case .completed: WorkStatusLabel.completed
    case .failed: WorkStatusLabel.failed
    case .cancelled: WorkStatusLabel.cancelled
    case SessionEntry.Compaction.unreportedStatus:
      String(localized: "No status yet", bundle: .module)
    case .unknown(let wireValue): WorkStatusLabel.unknown(for: wireValue)
    }
  }

  public var body: some View {
    let key = entry.id.rowKey
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      header(key: key)
      if let error = entry.error {
        Text(error)
          .font(editorTheme.font(for: .ui, style: .callout))
          .foregroundStyle(editorTheme.severityError)
          .textSelection(.enabled)
          .accessibilityIdentifier(Self.errorIdentifier)
      }
      summary(key: key)
    }
    .padding(editorStyle.spacing.m)
    .inlineEdge(radius: editorStyle.radii.l)
  }

  /// The symbol, the title and the status of the row.
  ///
  /// - Parameter key: The row key of the entry.
  /// - Returns: The header.
  private func header(key: String) -> some View {
    let status = entry.status
    let statusText = Self.statusLabel(for: status)
    return HStack(spacing: editorStyle.spacing.m) {
      StatusSymbolImage(name: Self.symbolName, color: editorTheme.statusColor(for: status))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
        Text(Self.title)
          .font(editorTheme.font(for: .ui, style: .headline))
        Text(statusText)
          .font(editorTheme.font(for: .ui, style: .callout))
          .foregroundStyle(.secondary)
      }
      // The text is the element of the header. A container element here
      // merges into the element of an `ItemRow` and loses its identifier.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(String(localized: "\(Self.title), \(statusText)", bundle: .module))
      .accessibilityIdentifier(Self.identifier(for: key))
    }
  }

  /// The ACP blocks of the summary that the compaction keeps, as the entry
  /// holds them.
  ///
  /// - Parameter key: The row key of the entry. The id of each block view is
  ///   `<key>-summary-<index>`.
  /// - Returns: An ``EntryContentView`` of the summary.
  private func summary(key: String) -> some View {
    EntryContentView(content: entry.summary, id: key + Self.summaryIDSuffix)
  }
}

#Preview("Compaction") {
  let update = CompactionUpdate(
    compactionId: CompactionId(rawValue: "preview-compaction"),
    status: .completed,
    summary: .value([.text(TextContent(text: "The user asked why the build fails. The agent added an import."))]))
  if let entry = PreviewFixtures.entry(.update(.compactionUpdate(update)), as: CompactionEntry.self) {
    CompactionEntryView(entry: entry)
  }
}
