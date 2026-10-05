import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The row of a context compaction of a `SessionModel` (update.md §4.2; the
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
/// Below the status, the row shows the summary that the compaction keeps,
/// one ``ContentBlockView`` for each block.
///
/// The view reads the entry object, so each later `compaction_update` and
/// each `compaction_summary_chunk` changes this row in place. Compaction is
/// unstable ACP.
public struct CompactionEntryView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of the title and the status of
  /// each row. The rest is the row key of the entry.
  public static let identifierPrefix = "compaction-"

  /// The accessibility identifier of the reason of a failed compaction.
  public static let errorIdentifier = "compaction-error"

  /// The SF Symbol name of the row.
  private static let symbolName = "arrow.down.right.and.arrow.up.left"

  /// The compaction entry to show.
  let entry: CompactionEntry

  @Environment(\.agentTheme) private var theme

  /// Makes the row of a compaction entry of a `SessionModel`.
  ///
  /// - Parameter entry: The compaction entry to show.
  public init(entry: CompactionEntry) {
    self.entry = entry
  }

  /// The title of each row.
  private static var title: String {
    String(localized: "Context compaction")
  }

  /// The name of a compaction status.
  ///
  /// - Parameter status: The status of the compaction.
  /// - Returns: The name of the status. The status of an entry with no
  ///   `compaction_update` gives "No status yet", and a status that the kit
  ///   does not know gives its wire value.
  private static func statusLabel(for status: Unstable.CompactionStatus) -> String {
    switch status {
    case .inProgress: WorkStatusLabel.inProgress
    case .completed: WorkStatusLabel.completed
    case .failed: WorkStatusLabel.failed
    case .cancelled: WorkStatusLabel.cancelled
    case SessionEntry.Compaction.unreportedStatus: String(localized: "No status yet")
    case .unknown(let wireValue): WorkStatusLabel.unknown(for: wireValue)
    }
  }

  public var body: some View {
    let key = entry.id.rowKey
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      header(key: key)
      if let error = entry.error {
        Text(error)
          .font(.callout)
          .foregroundStyle(theme.statusColors.failed)
          .textSelection(.enabled)
          .accessibilityIdentifier(Self.errorIdentifier)
      }
      summary(key: key)
    }
    .padding(theme.spacing.m)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
  }

  /// The symbol, the title and the status of the row.
  ///
  /// - Parameter key: The row key of the entry.
  /// - Returns: The header.
  private func header(key: String) -> some View {
    let status = entry.status
    let statusText = Self.statusLabel(for: status)
    return HStack(spacing: theme.spacing.m) {
      Image(systemName: Self.symbolName)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(theme.statusColors.color(for: status))
        .fontWeight(theme.symbolWeight)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Text(Self.title)
          .font(.headline)
        Text(statusText)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      // The text is the element of the header. A container element here
      // merges into the element of an `ItemRow` and loses its identifier.
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(Self.title), \(statusText)")
      .accessibilityIdentifier(Self.identifier(for: key))
    }
  }

  /// The blocks of the summary that the compaction keeps.
  ///
  /// - Parameter key: The row key of the entry. The id of each block view is
  ///   `<key>-summary-<index>`.
  /// - Returns: One ``ContentBlockView`` for each block.
  private func summary(key: String) -> some View {
    let blocks = TranscriptMessageView.messageBlocks(of: entry.summary)
    return ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
      ContentBlockView(block: block, id: "\(key)-summary-\(index)")
    }
  }
}
