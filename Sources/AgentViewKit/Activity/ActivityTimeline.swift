import SwiftUI

/// One row of an ``ActivityTimeline``: a reasoning span, a tool call, a
/// terminal of a tool call, or an error (plan.md §9 C).
///
/// The row button of an entry has the identifier from
/// ``PrefixedAccessibilityIdentifier/identifier(for:)``, with the entry id:
/// `activity-entry-<id>`.
public nonisolated struct ActivityEntry: Identifiable, Sendable, Hashable,
  PrefixedAccessibilityIdentifier
{
  /// The type of an entry.
  public enum Kind: Sendable, Hashable {
    /// A ``Reasoning`` item.
    case reasoning

    /// A ``ToolCallRecord`` item.
    case toolCall

    /// A terminal that a tool call refers to.
    ///
    /// - Parameter id: The identifier of the terminal.
    case terminal(id: String)

    /// A ``ThreadError`` item.
    case error
  }

  /// The part of a terminal entry id between the call id and the terminal
  /// id.
  public static let terminalInfix = "-terminal-"

  /// The start of the accessibility identifier of each row button.
  public static let identifierPrefix = "activity-entry-"

  /// The end of the accessibility identifier of an expanded view.
  static let detailSuffix = "-detail"

  /// The identifier of the entry. For an item, this is the item id.
  public let id: String

  /// The type of the entry.
  public let kind: Kind

  /// The identifier of the item of the entry. For a terminal, this is the id
  /// of the tool call that refers to it.
  public let itemID: String

  /// The time when the host saw the work start, or `nil`.
  public let startedAt: Date?

  /// The time when the host saw the work end, or `nil`.
  public let endedAt: Date?

  /// Makes an entry.
  ///
  /// - Parameters:
  ///   - id: The identifier of the entry.
  ///   - kind: The type of the entry.
  ///   - itemID: The identifier of the item of the entry.
  ///   - startedAt: The time when the host saw the work start.
  ///   - endedAt: The time when the host saw the work end.
  public init(id: String, kind: Kind, itemID: String, startedAt: Date? = nil, endedAt: Date? = nil) {
    self.id = id
    self.kind = kind
    self.itemID = itemID
    self.startedAt = startedAt
    self.endedAt = endedAt
  }

  /// The identifier of the entry of a terminal that a tool call refers to.
  ///
  /// - Parameters:
  ///   - callID: The identifier of the tool call.
  ///   - terminalID: The identifier of the terminal.
  /// - Returns: `<callID>-terminal-<terminalID>`.
  public static func terminalEntryID(callID: String, terminalID: String) -> String {
    callID + terminalInfix + terminalID
  }

  /// The accessibility identifier of the expanded view of an entry.
  ///
  /// - Parameter id: The identifier of the entry.
  /// - Returns: `activity-entry-<id>-detail`.
  public static func detailIdentifier(for id: String) -> String {
    identifier(for: id) + detailSuffix
  }

  /// The entries of `items`.
  ///
  /// Each reasoning item, tool call, and error gives one entry. Each terminal
  /// of a tool call gives one entry after the entry of the call, with the
  /// times of the call. When each entry has a start time, the entries are in
  /// start time order. Otherwise they are in thread order.
  ///
  /// - Parameter items: The items of one turn, in thread order.
  /// - Returns: The entries.
  @MainActor
  public static func entries(in items: some Sequence<ThreadItem>) -> [ActivityEntry] {
    var entries: [ActivityEntry] = []
    for item in items {
      switch item {
      case .reasoning(let record):
        entries.append(
          ActivityEntry(
            id: record.id, kind: .reasoning, itemID: record.id,
            startedAt: record.startedAt, endedAt: record.endedAt))
      case .toolCall(let record):
        entries.append(
          ActivityEntry(
            id: record.id, kind: .toolCall, itemID: record.id,
            startedAt: record.startedAt, endedAt: record.endedAt))
        entries.append(contentsOf: terminalEntries(of: record))
      case .error(let record):
        entries.append(ActivityEntry(id: record.id, kind: .error, itemID: record.id))
      default:
        continue
      }
    }
    guard entries.allSatisfy({ $0.startedAt != nil }) else { return entries }
    // A stable sort, so that a terminal stays after its call.
    return entries.enumerated()
      .sorted { lhs, rhs in
        let left = lhs.element.startedAt ?? .distantPast
        let right = rhs.element.startedAt ?? .distantPast
        return left == right ? lhs.offset < rhs.offset : left < right
      }
      .map(\.element)
  }

  /// The terminal entries of a tool call, one for each terminal id.
  ///
  /// - Parameter record: The tool call.
  /// - Returns: The entries, in content order.
  @MainActor
  private static func terminalEntries(of record: ToolCallRecord) -> [ActivityEntry] {
    var seen: Set<String> = []
    return record.content.compactMap { part in
      guard case .terminal(let terminalID) = part, seen.insert(terminalID).inserted else {
        return nil
      }
      return ActivityEntry(
        id: terminalEntryID(callID: record.id, terminalID: terminalID),
        kind: .terminal(id: terminalID), itemID: record.id,
        startedAt: record.startedAt, endedAt: record.endedAt)
    }
  }

  /// The part of a time span that a bar fills.
  ///
  /// - Parameters:
  ///   - start: The start of the work, or `nil`.
  ///   - end: The end of the work, or `nil`.
  ///   - span: The time span of the turn.
  /// - Returns: The start and the end of the bar as parts of the span, in
  ///   `0...1`, or `nil` when a time is missing. A span with no length gives
  ///   `0...0`.
  public static func barRange(start: Date?, end: Date?, span: ClosedRange<Date>) -> ClosedRange<Double>? {
    guard let start, let end else { return nil }
    let length = span.upperBound.timeIntervalSince(span.lowerBound)
    guard length > 0 else { return 0...0 }
    let lower = min(max(start.timeIntervalSince(span.lowerBound) / length, 0), 1)
    let upper = min(max(end.timeIntervalSince(span.lowerBound) / length, lower), 1)
    return lower...upper
  }
}

/// A vertical timeline of the work of the agent, one section for each turn
/// (plan.md §9 C).
///
/// Each section has a ``TurnSummaryRow`` header and one row for each
/// reasoning span, tool call, terminal, and error of the turn, in time order.
/// See ``ActivityEntry/entries(in:)``. A row with both times shows its
/// duration and a bar in the time span of the turn. A row with a missing time
/// shows no bar and no duration.
///
/// A click on a row expands the matching view below it: ``ToolCallView``,
/// ``ReasoningView``, ``TerminalView``, or ``ErrorView``. A click on a turn
/// header opens or closes the turn. Only the last turn is open at first.
///
/// The host measures the times. See ``ToolCallRecord/startedAt`` and
/// ``Reasoning/startedAt``.
public struct ActivityTimeline: View {
  /// The accessibility identifier of the timeline.
  public static let identifier = "activity-timeline"

  /// The accessibility identifier of the empty state.
  public static let emptyStateIdentifier = "activity-timeline-empty"

  /// The end of the accessibility identifier of a turn section, after the
  /// identifier of its summary row.
  static let sectionSuffix = "-section"

  /// The end of the accessibility identifier of a turn toggle, after the
  /// identifier of its summary row.
  static let toggleSuffix = "-toggle"

  /// The SF Symbol name of the empty state.
  static let emptySymbolName = "clock"

  /// The thread to show.
  let thread: AgentThread

  /// The open state of each turn that the user changed, keyed by turn id.
  @State private var turnDecisions: [String: Bool] = [:]

  @Environment(\.agentTheme) private var theme

  /// Makes the timeline of a thread.
  ///
  /// - Parameter thread: The thread to show.
  public init(thread: AgentThread) {
    self.thread = thread
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the section of the turn with `id`.
  ///
  /// - Parameter id: The identifier of the turn.
  /// - Returns: `turn-summary-<id>-section`.
  public static func turnIdentifier(for id: String) -> String {
    TurnSummaryRow.identifier(for: id) + sectionSuffix
  }

  /// The accessibility identifier of the button that opens or closes a turn.
  ///
  /// - Parameter id: The identifier of the turn.
  /// - Returns: `turn-summary-<id>-toggle`.
  public static func turnToggleIdentifier(for id: String) -> String {
    TurnSummaryRow.identifier(for: id) + toggleSuffix
  }

  // MARK: - Body

  public var body: some View {
    let items = thread.items
    let turnIDs = TurnSummary.turnRanges(in: items).map { items[$0.lowerBound].id }
    VStack(spacing: 0) {
      if turnIDs.isEmpty {
        ContentUnavailableView(
          "No Activity",
          systemImage: Self.emptySymbolName,
          description: Text("Tool calls and reasoning show here.")
        )
        .accessibilityIdentifier(Self.emptyStateIdentifier)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: theme.spacing.m) {
            ForEach(turnIDs, id: \.self) { turnID in
              ActivityTurnSection(
                thread: thread,
                turnID: turnID,
                isExpanded: turnDecisions[turnID] ?? (turnID == turnIDs.last),
                onToggle: { isExpanded in turnDecisions[turnID] = !isExpanded }
              )
            }
          }
          .padding(theme.rowPadding)
        }
      }
    }
    .environment(\.agentThread, thread)
    .contentContainer(identifier: Self.identifier)
  }
}

/// One turn of an ``ActivityTimeline``: the summary header and the rows.
///
/// This view, and not the timeline, reads the records of the turn. A turn
/// with no entry shows nothing. The view keeps the expanded rows of the turn,
/// also while the turn is closed.
private struct ActivityTurnSection: View {
  /// The thread.
  let thread: AgentThread

  /// The identifier of the first item of the turn.
  let turnID: String

  /// `true` while the turn is open.
  let isExpanded: Bool

  /// The function that gets the open state before a press on the header.
  let onToggle: (Bool) -> Void

  /// The ids of the expanded rows of the turn.
  @State private var expandedEntries: Set<String> = []

  @Environment(\.agentTheme) private var theme

  var body: some View {
    let items = thread.items
    if let position = thread.position(of: turnID),
      let turn = TurnSummary.turn(startingAt: position, in: items)
    {
      let slice = items[position..<(position + turn.itemIDs.count)]
      let entries = ActivityEntry.entries(in: slice)
      if !entries.isEmpty {
        section(turn: turn, items: slice, entries: entries)
      }
    }
  }

  /// The header and, while the turn is open, the rows.
  ///
  /// - Parameters:
  ///   - turn: The summary of the turn.
  ///   - items: The items of the turn.
  ///   - entries: The entries of the turn, not empty.
  /// - Returns: The section view.
  private func section(
    turn: TurnSummary, items: ArraySlice<ThreadItem>, entries: [ActivityEntry]
  ) -> some View {
    let records = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let span = Self.span(of: turn, entries: entries)
    return VStack(alignment: .leading, spacing: theme.spacing.xs) {
      header(turn: turn)
      if isExpanded {
        ForEach(entries) { entry in
          if let item = records[entry.itemID] {
            ActivityEntryRow(
              entry: entry,
              item: item,
              span: span,
              isExpanded: expandedEntries.contains(entry.id),
              onToggle: { toggle(entry.id) }
            )
          }
        }
        .padding(.leading, theme.spacing.l)
      }
    }
    .contentContainer(identifier: ActivityTimeline.turnIdentifier(for: turnID))
  }

  /// The summary row and the button that opens or closes the turn.
  ///
  /// - Parameter turn: The summary of the turn.
  /// - Returns: The header view.
  private func header(turn: TurnSummary) -> some View {
    let isExpanded = isExpanded
    let toggle = { onToggle(isExpanded) }
    return HStack(spacing: theme.spacing.s) {
      TurnSummaryRow(turn: turn)
      Spacer(minLength: theme.spacing.s)
      Button(action: toggle) {
        Image(systemName: "chevron.right")
          .fontWeight(theme.symbolWeight)
          .rotationEffect(isExpanded ? ReasoningView.expandedChevronAngle : .zero)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(isExpanded ? Text("Hide turn activity") : Text("Show turn activity"))
      .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
      .accessibilityIdentifier(ActivityTimeline.turnToggleIdentifier(for: turnID))
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: toggle)
  }

  /// Expands or collapses the row of `id`.
  ///
  /// - Parameter id: The identifier of the entry.
  private func toggle(_ id: String) {
    if expandedEntries.contains(id) {
      expandedEntries.remove(id)
    } else {
      expandedEntries.insert(id)
    }
  }

  /// The time span that the bars of a turn fill.
  ///
  /// - Parameters:
  ///   - turn: The summary of the turn.
  ///   - entries: The entries of the turn.
  /// - Returns: The span from the first start to the last start or end, or
  ///   `nil` when the turn has no start time.
  private static func span(of turn: TurnSummary, entries: [ActivityEntry]) -> ClosedRange<Date>? {
    guard let start = turn.startedAt else { return nil }
    let lastStart = entries.compactMap(\.startedAt).max() ?? start
    let end = max(turn.endedAt ?? start, lastStart, start)
    return start...end
  }
}

/// One row of an ``ActivityTimeline``, and its expanded view.
private struct ActivityEntryRow: View {
  /// The height of a bar, in points.
  static let barHeight: CGFloat = 6

  /// The width of the bar track, in points.
  static let trackWidth: CGFloat = 160

  /// The smallest width of a bar, in points.
  static let minimumBarWidth: CGFloat = 2

  /// The width of the duration text, in points.
  static let durationWidth: CGFloat = 48

  /// The opacity of the bar track.
  static let trackOpacity: CGFloat = 0.15

  /// The SF Symbol name of a reasoning row.
  static let reasoningSymbolName = "brain"

  /// The SF Symbol name of a terminal row.
  static let terminalSymbolName = "terminal"

  /// The entry to show.
  let entry: ActivityEntry

  /// The item of the entry.
  let item: ThreadItem

  /// The time span of the turn, or `nil`.
  let span: ClosedRange<Date>?

  /// `true` while the matching view shows.
  let isExpanded: Bool

  /// The function that expands or collapses the row.
  let onToggle: () -> Void

  @Environment(\.agentThread) private var thread
  @Environment(\.agentTheme) private var theme

  var body: some View {
    let title = self.title
    let duration = ToolCallView.durationText(from: entry.startedAt, to: entry.endedAt)
    let bar = span.flatMap {
      ActivityEntry.barRange(start: entry.startedAt, end: entry.endedAt, span: $0)
    }
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Button(action: onToggle) {
        HStack(spacing: theme.spacing.s) {
          Image(systemName: symbolName)
            .fontWeight(theme.symbolWeight)
            .foregroundStyle(tint)
          Text(title)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: theme.spacing.s)
          barView(bar)
          Text(duration ?? "")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: Self.durationWidth, alignment: .trailing)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(title)
      .accessibilityValue(Text(duration ?? ""))
      .accessibilityHint(isExpanded ? Text("Hides the details") : Text("Shows the details"))
      .accessibilityIdentifier(ActivityEntry.identifier(for: entry.id))
      if isExpanded {
        detail
          .contentContainer(identifier: ActivityEntry.detailIdentifier(for: entry.id))
      }
    }
  }

  /// The bar of the row in its track, or an empty track with no bar.
  ///
  /// The track and the bar are capsules.
  ///
  /// - Parameter range: The part of the span that the bar fills, or `nil`.
  /// - Returns: The bar view.
  private func barView(_ range: ClosedRange<Double>?) -> some View {
    let tint = tint
    return Canvas { context, size in
      let track = CGRect(origin: .zero, size: size)
      context.fill(
        Capsule().path(in: track),
        with: .color(Color.secondary.opacity(Self.trackOpacity)))
      guard let range else { return }
      let x = size.width * range.lowerBound
      let width = max(size.width * (range.upperBound - range.lowerBound), Self.minimumBarWidth)
      let rect = CGRect(
        x: min(x, size.width - width), y: track.minY, width: width, height: size.height)
      context.fill(Capsule().path(in: rect), with: .color(tint))
    }
    .frame(width: Self.trackWidth, height: Self.barHeight)
    .accessibilityHidden(true)
  }

  // MARK: - Content

  /// The text of the row.
  private var title: String {
    switch entry.kind {
    case .terminal(let id):
      return terminal(id: id)?.command ?? String(localized: "Terminal \(id)")
    case .reasoning, .toolCall, .error:
      break
    }
    switch item {
    case .toolCall(let record):
      return ToolCallView.displayTitle(record.title)
    case .reasoning(let record):
      return isInProgress(record.id)
        ? ActivityIndicator.thinkingText
        : ReasoningView.completedTitle(duration: record.duration)
    case .error(let record):
      return ErrorView.content(for: record.kind).title
    default:
      return item.id
    }
  }

  /// The SF Symbol name of the row.
  private var symbolName: String {
    if case .terminal = entry.kind {
      return Self.terminalSymbolName
    }
    switch item {
    case .toolCall(let record): return ToolKindSymbol.name(for: record.kind)
    case .error(let record): return ErrorView.content(for: record.kind).symbolName
    default: return Self.reasoningSymbolName
    }
  }

  /// The color of the symbol and the bar.
  private var tint: Color {
    switch item {
    case .toolCall(let record): theme.statusColors.color(for: record.status)
    case .error: theme.statusColors.failed
    default: Color.secondary
    }
  }

  /// The view that a click on the row shows.
  @ViewBuilder private var detail: some View {
    switch (entry.kind, item) {
    case (.terminal(let id), _):
      if let record = terminal(id: id) {
        TerminalView(record: record)
      } else {
        Label(String(localized: "Terminal \(id)"), systemImage: Self.terminalSymbolName)
          .foregroundStyle(.secondary)
      }
    case (_, .toolCall(let record)):
      ToolCallView(record: record)
    case (_, .reasoning(let record)):
      ReasoningView(
        record: record,
        isInProgress: isInProgress(record.id),
        streaming: thread?.streaming[record.id])
    case (_, .error(let record)):
      ErrorView(error: record)
    default:
      EmptyView()
    }
  }

  /// The terminal of the thread with `id`, or `nil`.
  ///
  /// - Parameter id: The identifier of the terminal.
  /// - Returns: The record.
  private func terminal(id: String) -> TerminalRecord? {
    thread?.terminals[TerminalID(id)]
  }

  /// Tells whether the reasoning of `id` is still in progress.
  ///
  /// - Parameter id: The identifier of the reasoning.
  /// - Returns: `true` when it is the last item while the thread runs.
  private func isInProgress(_ id: String) -> Bool {
    thread?.isLastWhileRunning(id) ?? false
  }
}
