import SwiftUI

/// The task lists of the agent, one checklist for each plan (plan.md §9 C).
///
/// Pass ``AgentThread/plans`` as `plans`. The view shows the plans in the
/// order of their identifiers. Each plan is one section, and the section
/// identity is the plan identifier. When the agent replaces a plan, the
/// section stays and its entries change in place.
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

  /// The accessibility identifier of the empty state.
  public static let emptyIdentifier = "task-list-empty"

  /// The plans to show, keyed by identifier.
  let plans: [PlanID: Plan]

  /// Makes the task list.
  ///
  /// - Parameter plans: The plans to show, such as ``AgentThread/plans``.
  public init(plans: [PlanID: Plan]) {
    self.plans = plans
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the entry at `index` in the plan `id`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the plan.
  ///   - index: The position of the entry in the plan, from `0`.
  /// - Returns: `task-entry-<id>-<index>`.
  public static func entryIdentifier(plan id: PlanID, index: Int) -> String {
    "\(entryIdentifierPrefix)\(id.rawValue)-\(index)"
  }

  /// The accessibility identifier of the header of the plan `id`.
  ///
  /// - Parameter id: The identifier of the plan.
  /// - Returns: `task-plan-<id>`.
  public static func planIdentifier(for id: PlanID) -> String {
    AccessibilityIdentifier.make(prefix: planIdentifierPrefix, value: id.rawValue)
  }

  /// The ``BodyEvaluationCounter`` key that the section of the plan `id`
  /// notes one time for each section identity, when the section first shows.
  ///
  /// A replaced plan keeps its section, so the count stays at one. A new
  /// section identity adds one to the count.
  ///
  /// - Parameter id: The identifier of the plan.
  /// - Returns: `task-plan-<id>-state`.
  public static func sectionStateKey(for id: PlanID) -> String {
    planIdentifier(for: id) + "-state"
  }

  // MARK: - Labels

  /// The name of a status, for the entry label and the help tag of the
  /// status symbol.
  ///
  /// - Parameter status: The status of an entry.
  /// - Returns: The name of the status. An unknown status gives its wire
  ///   string.
  public static func statusLabel(_ status: PlanEntry.Status) -> String {
    switch status {
    case .pending: WorkStatusLabel.pending
    case .inProgress: WorkStatusLabel.inProgress
    case .completed: WorkStatusLabel.completed
    case .cancelled: WorkStatusLabel.cancelled
    case .unknown(let wireValue): WorkStatusLabel.unknown(wireValue)
    }
  }

  /// The name of a priority, for the entry label and the help tag of the
  /// priority tint.
  ///
  /// - Parameter priority: The priority of an entry.
  /// - Returns: The name of the priority. An unknown priority gives its wire
  ///   string.
  public static func priorityLabel(_ priority: PlanEntry.Priority) -> String {
    switch priority {
    case .high: String(localized: "High priority")
    case .medium: String(localized: "Medium priority")
    case .low: String(localized: "Low priority")
    case .unknown(let wireValue): String(localized: "Unknown priority: \(wireValue)")
    }
  }

  /// The accessibility label of an entry.
  ///
  /// - Parameter entry: The entry.
  /// - Returns: The text, the status, and the priority, separated by commas.
  public static func entryLabel(_ entry: PlanEntry) -> String {
    "\(entry.content), \(statusLabel(entry.status)), \(priorityLabel(entry.priority))"
  }

  /// The header text of a plan.
  ///
  /// - Parameter plan: The plan.
  /// - Returns: The number of completed entries of the total, such as
  ///   `2 of 5 done`.
  public static func headerText(for plan: Plan) -> String {
    let done = plan.entries.count { $0.status == .completed }
    return String(localized: "\(done) of \(plan.entries.count) done")
  }

  /// The plans in the order that the view shows them: by identifier.
  ///
  /// - Parameter plans: The plans, keyed by identifier.
  /// - Returns: The plans, sorted by the raw value of the identifier.
  public static func orderedPlans(_ plans: [PlanID: Plan]) -> [Plan] {
    plans.values.sorted { $0.id.rawValue < $1.id.rawValue }
  }

  // MARK: - Body

  public var body: some View {
    if plans.isEmpty {
      ContentUnavailableView(
        "No Tasks",
        systemImage: "checklist",
        description: Text("The task list of the agent shows here.")
      )
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(Self.emptyIdentifier)
    } else {
      List(Self.orderedPlans(plans)) { plan in
        PlanSection(plan: plan)
      }
    }
  }
}

/// One plan in ``TaskListView``.
private struct PlanSection: View {
  /// The plan to show.
  let plan: Plan

  /// A value that SwiftUI makes one time for each section identity.
  ///
  /// The value notes ``TaskListView/sectionStateKey(for:)`` when SwiftUI makes
  /// it, so that a test can prove that a replaced plan keeps its section.
  @State private var identityProbe: SectionIdentityProbe

  /// Makes the section.
  ///
  /// - Parameter plan: The plan to show.
  init(plan: Plan) {
    self.plan = plan
    _identityProbe = State(wrappedValue: SectionIdentityProbe(planID: plan.id))
  }

  var body: some View {
    Section {
      // A `List` needs row identities that are unique over all sections. The
      // accessibility identifier has the plan identifier and the position, so
      // it is the row identity.
      ForEach(entryRows, id: \.identifier) { row in
        PlanEntryRow(entry: row.entry)
          .accessibilityIdentifier(row.identifier)
      }
    } header: {
      Text(TaskListView.headerText(for: plan))
        .accessibilityIdentifier(TaskListView.planIdentifier(for: plan.id))
    }
    .onAppear { identityProbe.noteAppear() }
  }

  /// The entries of the plan, each with its accessibility identifier.
  private var entryRows: [(identifier: String, entry: PlanEntry)] {
    plan.entries.enumerated().map { index, entry in
      (TaskListView.entryIdentifier(plan: plan.id, index: index), entry)
    }
  }
}

/// The identity probe of one ``PlanSection``.
///
/// `@State` keeps the first value for the life of the section identity and
/// drops each later value. So the probe notes the key one time, when the
/// state becomes live, and not in `init`, which SwiftUI calls for each
/// update.
@MainActor
private final class SectionIdentityProbe {
  /// The identifier of the plan of the section.
  let planID: PlanID

  /// Whether the probe noted its key.
  private var didNote = false

  /// Makes a probe.
  ///
  /// - Parameter planID: The identifier of the plan of the section.
  init(planID: PlanID) {
    self.planID = planID
  }

  /// Notes the key the first time that the section shows.
  func noteAppear() {
    guard !didNote else { return }
    didNote = true
    #if DEBUG
      BodyEvaluationCounter.note(TaskListView.sectionStateKey(for: planID))
    #endif
  }
}

/// One entry in ``TaskListView``.
private struct PlanEntryRow: View {
  /// The entry to show.
  let entry: PlanEntry

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
