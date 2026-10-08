import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The task list of the agent: the checklist of one plan (plan.md §3.8
/// "Plan view", §9 C).
///
/// The view shows one `PlanTranscriptEntry` of a `SessionModel` at its
/// position in the transcript: the header and the entries of the plan, with
/// no list. The client model keeps a plan with a `planId` at
/// the position where it first appeared, and a plan with no `planId` is a new
/// entry (plan.md §3.7 "Plans"). Content that the kit does not know shows
/// with its type, and its JSON shows when the user expands it.
///
/// Each entry shows a status symbol, the text of the task, and a priority
/// tint. An entry in progress shows a `ProgressView`. A cancelled entry shows
/// its text with a strikethrough.
///
/// The accessibility label of each entry is the text, the status, and the
/// priority, such as `Read the file, In progress, High priority`.
public struct TaskListView: View {
  /// The start of the accessibility identifier of each entry.
  public static let entryIdentifierPrefix = "task-entry-"

  /// The start of the accessibility identifier of each plan header.
  public static let planIdentifierPrefix = "task-plan-"

  /// The start of the accessibility identifier of the unknown content of a
  /// plan entry of a `SessionModel`.
  public static let unknownContentIdentifierPrefix = "task-plan-unknown-"

  /// The plan entry to show.
  let entry: PlanTranscriptEntry

  @Environment(\.agentTheme) private var theme

  /// Makes the task list of one plan entry of a `SessionModel`, for the row
  /// of the entry in the transcript.
  ///
  /// - Parameter entry: The plan entry to show.
  public init(entry: PlanTranscriptEntry) {
    self.entry = entry
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the entry at `index` in the plan of the
  /// row `key`.
  ///
  /// - Parameters:
  ///   - key: The row key of a plan entry of a `SessionModel`.
  ///   - index: The position of the entry in the plan, from `0`.
  /// - Returns: `task-entry-<key>-<index>`.
  public static func entryIdentifier(row key: String, index: Int) -> String {
    "\(entryIdentifierPrefix)\(key)-\(index)"
  }

  /// The accessibility identifier of the header of the plan of the row `key`.
  ///
  /// - Parameter key: The row key of a plan entry of a `SessionModel`.
  /// - Returns: `task-plan-<key>`.
  public static func planIdentifier(row key: String) -> String {
    AccessibilityIdentifier.make(prefix: planIdentifierPrefix, value: key)
  }

  /// The accessibility identifier of the unknown content of the plan entry of
  /// the row `key`.
  ///
  /// - Parameter key: The row key of a plan entry of a `SessionModel`.
  /// - Returns: `task-plan-unknown-<key>`.
  public static func unknownContentIdentifier(row key: String) -> String {
    AccessibilityIdentifier.make(prefix: unknownContentIdentifierPrefix, value: key)
  }

  // MARK: - Labels

  /// The name of a status, for the entry label and the help tag of the
  /// status symbol.
  ///
  /// - Parameter status: The ACP status of an entry.
  /// - Returns: The name of the status. An unknown status gives its wire
  ///   string.
  public static func statusLabel(_ status: FoundationModelsACP.PlanEntryStatus) -> String {
    switch status {
    case .pending: WorkStatusLabel.pending
    case .inProgress: WorkStatusLabel.inProgress
    case .completed: WorkStatusLabel.completed
    case .cancelled: WorkStatusLabel.cancelled
    case .unknown(let wireValue): WorkStatusLabel.unknown(for: wireValue)
    }
  }

  /// The name of a priority, for the entry label and the help tag of the
  /// priority tint.
  ///
  /// - Parameter priority: The ACP priority of an entry.
  /// - Returns: The name of the priority. An unknown priority gives its wire
  ///   string.
  public static func priorityLabel(_ priority: FoundationModelsACP.PlanEntryPriority) -> String {
    switch priority {
    case .high: String(localized: "High priority")
    case .medium: String(localized: "Medium priority")
    case .low: String(localized: "Low priority")
    case .unknown(let wireValue): String(localized: "Unknown priority: \(wireValue)")
    }
  }

  /// The accessibility label of an ACP plan entry.
  ///
  /// - Parameter entry: The entry, as the plan entry of a `SessionModel`
  ///   holds it.
  /// - Returns: The text, the status, and the priority, separated by commas.
  public static func entryLabel(_ entry: FoundationModelsACP.PlanEntry) -> String {
    "\(entry.content), \(statusLabel(entry.status)), \(priorityLabel(entry.priority))"
  }

  /// The header text of the ACP entries of a plan.
  ///
  /// - Parameter entries: The entries of the plan, as the plan entry of a
  ///   `SessionModel` holds them.
  /// - Returns: The number of completed entries of the total, such as
  ///   `2 of 5 done`.
  public static func headerText(for entries: [FoundationModelsACP.PlanEntry]) -> String {
    let done = entries.count { $0.status == .completed }
    return String(localized: "\(done) of \(entries.count) done")
  }

  // MARK: - Body

  /// The view reads the entry object, so a new plan update for the same
  /// `planId` changes this view in place.
  public var body: some View {
    let key = entry.id.rowKey
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      if let unknown = entry.unknownContent {
        JSONDisclosure(
          id: key,
          title: String(localized: "Unknown plan content: \(unknown.type)"),
          json: unknown.payload.prettyPrinted,
          identifier: TaskListView.unknownContentIdentifier(row: key),
          isExpanded: false)
      } else {
        Text(TaskListView.headerText(for: entry.entries))
          .font(.headline)
          .accessibilityIdentifier(TaskListView.planIdentifier(row: key))
        ForEach(Array(entry.entries.enumerated()), id: \.offset) { index, item in
          PlanEntryRow(entry: item)
            .accessibilityIdentifier(TaskListView.entryIdentifier(row: key, index: index))
        }
      }
    }
  }
}

/// One entry in ``TaskListView``.
private struct PlanEntryRow: View {
  /// The ACP entry to show.
  let entry: FoundationModelsACP.PlanEntry

  @Environment(\.agentTheme) private var theme

  var body: some View {
    HStack(spacing: theme.spacing.s) {
      statusSymbol
        .frame(width: theme.spacing.l)
        .help(TaskListView.statusLabel(entry.status))
      Text(entry.content)
        .strikethrough(entry.status == .cancelled)
        .foregroundStyle(entry.status == .cancelled ? .secondary : .primary)
      Spacer(minLength: theme.spacing.s)
      Image(systemName: "flag.fill")
        .foregroundStyle(theme.statusColors.color(for: entry.priority))
        .fontWeight(theme.symbolWeight)
        .help(TaskListView.priorityLabel(entry.priority))
    }
    .padding(.vertical, theme.rowPadding)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(TaskListView.entryLabel(entry))
    .accessibilityAddTraits(.isStaticText)
  }

  /// The symbol of the status. An entry in progress shows a spinner.
  @ViewBuilder private var statusSymbol: some View {
    if entry.status == .inProgress {
      ProgressView()
        .controlSize(.mini)
    } else {
      Image(systemName: symbolName)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(theme.statusColors.color(for: entry.status))
        .fontWeight(theme.symbolWeight)
    }
  }

  /// The SF Symbol name of a status that is not in progress.
  private var symbolName: String {
    switch entry.status {
    case .pending: "circle"
    case .inProgress: "circle.dotted"
    case .completed: "checkmark.circle.fill"
    case .cancelled: "xmark.circle"
    case .unknown: "questionmark.circle"
    }
  }
}
