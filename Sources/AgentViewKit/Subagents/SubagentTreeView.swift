import SwiftUI

/// The tree of the subagent runs of a thread (plan.md §9 C, §11 decision 15).
///
/// The view shows the runs as an outline by ``SubagentRun/parentID``. Each row
/// has a state symbol, the title, a Stop button, and an Open button. The host
/// gives the closures of the two buttons. A button shows only when the host
/// gives its closure. The Stop button shows only for an active run. The Open
/// button is disabled until the run has a thread id.
///
/// The accessibility value of each row is its nesting level, such as
/// `Level 2`. A root run has level 1.
///
/// Each row reads only its own run. Thus a patch to one run evaluates only the
/// row of that run (plan.md §8). Pass ``AgentThread/subagents`` as `runs`.
public struct SubagentTreeView: View {
  /// The start of the accessibility identifier of each row.
  public static let rowIdentifierPrefix = "subagent-row-"

  /// The start of the accessibility identifier of each Stop button.
  public static let stopIdentifierPrefix = "subagent-stop-"

  /// The start of the accessibility identifier of each Open button.
  public static let openIdentifierPrefix = "subagent-open-"

  /// The accessibility identifier of the empty state.
  public static let emptyIdentifier = "subagents-empty"

  /// The level of a root run.
  public static let rootLevel = 1

  /// The runs to show, in the order that the source sent them.
  let runs: [SubagentRun]

  /// The host closure that stops a run, or `nil` for no Stop button.
  let onStop: ((SubagentRunID) -> Void)?

  /// The host closure that opens the thread of a run, or `nil` for no Open
  /// button.
  let onOpen: ((SubagentRun) -> Void)?

  /// Makes the tree.
  ///
  /// - Parameters:
  ///   - runs: The runs to show, such as ``AgentThread/subagents``.
  ///   - onStop: The host closure that stops a run. It gets the id of the
  ///     run.
  ///   - onOpen: The host closure that opens the child thread of a run. It
  ///     gets the run, which has a ``SubagentRun/threadID``.
  public init(
    runs: [SubagentRun],
    onStop: ((SubagentRunID) -> Void)? = nil,
    onOpen: ((SubagentRun) -> Void)? = nil
  ) {
    self.runs = runs
    self.onStop = onStop
    self.onOpen = onOpen
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the row of `id`.
  ///
  /// - Parameter id: The identifier of the run.
  /// - Returns: `subagent-row-<id>`.
  public static func rowIdentifier(for id: SubagentRunID) -> String {
    AccessibilityIdentifier.make(prefix: rowIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the Stop button of `id`.
  ///
  /// - Parameter id: The identifier of the run.
  /// - Returns: `subagent-stop-<id>`.
  public static func stopIdentifier(for id: SubagentRunID) -> String {
    AccessibilityIdentifier.make(prefix: stopIdentifierPrefix, value: id.rawValue)
  }

  /// The accessibility identifier of the Open button of `id`.
  ///
  /// - Parameter id: The identifier of the run.
  /// - Returns: `subagent-open-<id>`.
  public static func openIdentifier(for id: SubagentRunID) -> String {
    AccessibilityIdentifier.make(prefix: openIdentifierPrefix, value: id.rawValue)
  }

  /// The ``BodyEvaluationCounter`` key of the row of `id`.
  ///
  /// - Parameter id: The identifier of the run, or the start of it.
  /// - Returns: The row identifier, `subagent-row-<id>`.
  public static func counterKey(for id: SubagentRunID) -> String {
    rowIdentifier(for: id)
  }

  /// The accessibility value of a row at `level`.
  ///
  /// - Parameter level: The nesting level. A root run has level 1.
  /// - Returns: `Level <level>`.
  public static func levelValue(_ level: Int) -> String {
    String(localized: "Level \(level)")
  }

  /// The accessibility label of a row.
  ///
  /// - Parameters:
  ///   - title: The title that the row shows.
  ///   - state: The state of the run.
  /// - Returns: The title and the name of the state, such as
  ///   `Find the call sites, Done`.
  public static func rowLabel(title: String, state: SubagentState) -> String {
    "\(title), \(stateLabel(state))"
  }

  /// The name of a state, for the row label and the help tag of the state
  /// symbol.
  ///
  /// - Parameter state: The state of a run.
  /// - Returns: The name of the state. An unknown state gives its wire
  ///   string.
  public static func stateLabel(_ state: SubagentState) -> String {
    switch state {
    case .working: String(localized: "Working")
    case .needsInput: String(localized: "Needs input")
    case .readyForReview: String(localized: "Ready for review")
    case .done: String(localized: "Done")
    case .failed: String(localized: "Failed")
    case .unknown(let wireValue): String(localized: "Unknown state: \(wireValue)")
    }
  }

  // MARK: - Outline

  /// One row of the outline: a run and its nesting level.
  public struct OutlineRow: Identifiable {
    /// The run of the row.
    public let run: SubagentRun

    /// The nesting level. A root run has level 1.
    public let level: Int

    /// The identifier of the run.
    public var id: SubagentRunID { run.id }
  }

  /// The runs in outline order, each with its nesting level.
  ///
  /// A run with no parent, or with a parent that is not in `runs`, is a root.
  /// The roots and the children of each run keep the order of `runs`. A child
  /// comes after its parent and before the next sibling of its parent. When
  /// the parent links make a cycle, the first run of the cycle in `runs`
  /// becomes a root, so that each run shows one time.
  ///
  /// - Parameter runs: The runs, in the order that the source sent them.
  /// - Returns: The rows, in outline order.
  public static func outline(of runs: [SubagentRun]) -> [OutlineRow] {
    let known = Set(runs.map(\.id))
    var children: [SubagentRunID: [SubagentRun]] = [:]
    for run in runs {
      if let parentID = run.parentID, known.contains(parentID) {
        children[parentID, default: []].append(run)
      }
    }
    var rows: [OutlineRow] = []
    var visited: Set<SubagentRunID> = []
    func visit(_ run: SubagentRun, level: Int) {
      guard visited.insert(run.id).inserted else { return }
      rows.append(OutlineRow(run: run, level: level))
      for child in children[run.id, default: []] {
        visit(child, level: level + 1)
      }
    }
    for run in runs where run.parentID.map({ !known.contains($0) }) ?? true {
      visit(run, level: rootLevel)
    }
    for run in runs where !visited.contains(run.id) {
      visit(run, level: rootLevel)
    }
    return rows
  }

  // MARK: - Body

  public var body: some View {
    if runs.isEmpty {
      ContentUnavailableView(
        "No Subagents",
        systemImage: "point.3.filled.connected.trianglepath.dotted",
        description: Text("Runs that the agent starts show here.")
      )
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(Self.emptyIdentifier)
    } else {
      List(Self.outline(of: runs)) { row in
        SubagentRow(run: row.run, level: row.level, onStop: onStop, onOpen: onOpen)
      }
    }
  }
}

/// One run in ``SubagentTreeView``.
///
/// The row reads the fields of its run, so a patch to the run evaluates this
/// body again.
private struct SubagentRow: View {
  /// The run to show.
  let run: SubagentRun

  /// The nesting level of the run.
  let level: Int

  /// The host closure that stops a run, or `nil`.
  let onStop: ((SubagentRunID) -> Void)?

  /// The host closure that opens the thread of a run, or `nil`.
  let onOpen: ((SubagentRun) -> Void)?

  @Environment(\.agentTheme) private var theme

  var body: some View {
    #if DEBUG
      BodyEvaluationCounter.note(SubagentTreeView.counterKey(for: run.id))
    #endif
    let id = run.id
    return HStack(spacing: theme.spacing.s) {
      summary
      Spacer(minLength: theme.spacing.s)
      if let onStop, run.state.isActive {
        Button("Stop") { onStop(id) }
          .buttonStyle(.glass)
          .accessibilityLabel("Stop \(run.title)")
          .accessibilityIdentifier(SubagentTreeView.stopIdentifier(for: id))
      }
      if let onOpen {
        Button("Open") { onOpen(run) }
          .buttonStyle(.glass)
          .disabled(run.threadID == nil)
          .accessibilityLabel("Open \(run.title)")
          .accessibilityIdentifier(SubagentTreeView.openIdentifier(for: id))
      }
    }
    .padding(.leading, theme.spacing.l * CGFloat(level - SubagentTreeView.rootLevel))
  }

  /// The title of the run, or a default name when the title is empty.
  private var displayTitle: String {
    run.title.isEmpty ? String(localized: "Subagent") : run.title
  }

  /// The state symbol and the title, as one accessibility element.
  ///
  /// The element has the row identifier. Its value is the nesting level. A
  /// container element does not give its value, so the value is on this
  /// element and not on the whole row.
  private var summary: some View {
    let stateLabel = SubagentTreeView.stateLabel(run.state)
    return HStack(spacing: theme.spacing.s) {
      Image(systemName: symbolName)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(color)
        .fontWeight(theme.symbolWeight)
        .help(stateLabel)
      Text(displayTitle)
        .lineLimit(1)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(SubagentTreeView.rowLabel(title: displayTitle, state: run.state))
    .accessibilityValue(SubagentTreeView.levelValue(level))
    // An element with no role does not give its value. The trait gives the
    // static text role.
    .accessibilityAddTraits(.isStaticText)
    .accessibilityIdentifier(SubagentTreeView.rowIdentifier(for: run.id))
  }

  /// The SF Symbol name of the state.
  private var symbolName: String {
    switch run.state {
    case .working: "circle.dotted.circle"
    case .needsInput: "questionmark.bubble"
    case .readyForReview: "eye.circle"
    case .done: "checkmark.circle.fill"
    case .failed: "xmark.octagon.fill"
    case .unknown: "questionmark.circle"
    }
  }

  /// The color of the state, from the status colors of the theme.
  private var color: Color {
    let colors = theme.statusColors
    return switch run.state {
    case .working: colors.running
    case .needsInput, .readyForReview: theme.accent
    case .done: colors.completed
    case .failed: colors.failed
    case .unknown: colors.pending
    }
  }
}
