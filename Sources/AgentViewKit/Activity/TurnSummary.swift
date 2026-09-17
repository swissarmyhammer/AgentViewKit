import Foundation
import SwiftUI

/// The number of added and removed lines in one or more unified diffs.
public nonisolated struct DiffStat: Sendable, Hashable {
  /// The number of added lines.
  public var added: Int

  /// The number of removed lines.
  public var removed: Int

  /// Makes a diff stat.
  ///
  /// - Parameters:
  ///   - added: The number of added lines.
  ///   - removed: The number of removed lines.
  public init(added: Int = 0, removed: Int = 0) {
    self.added = added
    self.removed = removed
  }

  /// `true` when the stat has no added line and no removed line.
  public var isEmpty: Bool {
    added == 0 && removed == 0
  }

  /// The sum of two stats.
  ///
  /// - Parameters:
  ///   - lhs: A stat.
  ///   - rhs: A stat.
  /// - Returns: The stat with the sum of the added lines and the sum of the
  ///   removed lines.
  public static func + (lhs: DiffStat, rhs: DiffStat) -> DiffStat {
    DiffStat(added: lhs.added + rhs.added, removed: lhs.removed + rhs.removed)
  }

  /// The start of a hunk header line.
  static let hunkPrefix = "@@"

  /// The start of a line that starts the diff of a new file.
  static let fileHeaderPrefix = "diff "

  /// The start of the header line of the new file.
  static let newFilePrefix = "+++ "

  /// The start of the header line of the old file.
  static let oldFilePrefix = "--- "

  /// Counts the added and removed lines of a unified diff.
  ///
  /// Inside a hunk, each line that starts with `+` is added and each line that
  /// starts with `-` is removed. The `---` and `+++` file headers before a
  /// hunk do not count. A patch with no hunk header counts each `+` and `-`
  /// line that is not a file header.
  ///
  /// - Parameter patch: The unified diff text.
  /// - Returns: The stat of the patch.
  public static func count(patch: String) -> DiffStat {
    let lines = patch.split(separator: "\n", omittingEmptySubsequences: false)
    let hasHunks = lines.contains { $0.hasPrefix(hunkPrefix) }
    var stat = DiffStat()
    var inHunk = !hasHunks
    for line in lines {
      if line.hasPrefix(hunkPrefix) {
        inHunk = true
      } else if line.hasPrefix(fileHeaderPrefix) {
        inHunk = !hasHunks
      } else if !hasHunks, line.hasPrefix(newFilePrefix) || line.hasPrefix(oldFilePrefix) {
        continue
      } else if inHunk, line.hasPrefix("+") {
        stat.added += 1
      } else if inHunk, line.hasPrefix("-") {
        stat.removed += 1
      }
    }
    return stat
  }
}

/// The summary of one turn of a thread (plan.md §9 C).
///
/// A user message starts a turn. The items before the first user message are
/// a turn too. The summary gives the time from the first `startedAt` to the
/// last `endedAt` of the reasoning and tool call records of the turn, the
/// number of tool calls for each status, and the sum of the diffs in the tool
/// call content.
///
/// ``TurnSummaryRow`` shows the summary as one line. ``AgentThreadView`` shows
/// the line above the first agent item of each turn that has work, and
/// ``ActivityTimeline`` shows it as the header of each turn.
public nonisolated struct TurnSummary: Identifiable, Sendable, Hashable {
  /// The identifier of the first item of the turn.
  public let id: String

  /// The identifiers of the items of the turn, in thread order.
  public let itemIDs: [String]

  /// The first start time of a record in the turn, or `nil` when no record
  /// has one.
  public let startedAt: Date?

  /// The last end time of a record in the turn, or `nil` when no record has
  /// one.
  public let endedAt: Date?

  /// The number of tool calls in the turn, keyed by status.
  public let toolCounts: [ToolCallStatus: Int]

  /// The sum of the diffs in the content of the tool calls.
  public let diffStat: DiffStat

  /// Makes a summary.
  ///
  /// - Parameters:
  ///   - id: The identifier of the first item of the turn.
  ///   - itemIDs: The identifiers of the items of the turn, in thread order.
  ///   - startedAt: The first start time of a record in the turn.
  ///   - endedAt: The last end time of a record in the turn.
  ///   - toolCounts: The number of tool calls, keyed by status.
  ///   - diffStat: The sum of the diffs in the content of the tool calls.
  public init(
    id: String,
    itemIDs: [String],
    startedAt: Date? = nil,
    endedAt: Date? = nil,
    toolCounts: [ToolCallStatus: Int] = [:],
    diffStat: DiffStat = DiffStat()
  ) {
    self.id = id
    self.itemIDs = itemIDs
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.toolCounts = toolCounts
    self.diffStat = diffStat
  }

  /// The time from ``startedAt`` to ``endedAt``, or `nil` when a time is
  /// missing or the end is before the start.
  public var duration: TimeInterval? {
    guard let startedAt, let endedAt, endedAt >= startedAt else { return nil }
    return endedAt.timeIntervalSince(startedAt)
  }

  /// The number of tool calls in the turn.
  public var toolCount: Int {
    toolCounts.values.reduce(0, +)
  }

  /// The number of tool calls in the turn with `status`.
  ///
  /// - Parameter status: The progress of the calls to count.
  /// - Returns: The number of calls.
  public func count(of status: ToolCallStatus) -> Int {
    toolCounts[status] ?? 0
  }

  /// `true` when the turn has a tool call or a duration.
  ///
  /// The thread shows a summary line only for a turn with work.
  public var hasWork: Bool {
    toolCount > 0 || duration != nil
  }

  /// The one-line text of the summary, such as "Worked 3 s, 2 tools, +4 −1".
  public var text: String {
    Self.text(duration: duration, toolCount: toolCount, diffStat: diffStat)
  }

  /// The one-line text of a summary.
  ///
  /// - Parameters:
  ///   - duration: The time of the turn, or `nil` when it is not known.
  ///   - toolCount: The number of tool calls.
  ///   - diffStat: The sum of the diffs.
  /// - Returns: "Worked N s" with N rounded to whole seconds, or "Worked"
  ///   with no duration. Then ", K tools" when `toolCount` is more than zero,
  ///   and ", +A −R" when `diffStat` is not empty.
  public static func text(duration: TimeInterval?, toolCount: Int, diffStat: DiffStat) -> String {
    var parts: [String] = []
    if let duration {
      let seconds = Int(duration.rounded())
      parts.append(String(localized: "Worked \(seconds) s"))
    } else {
      parts.append(String(localized: "Worked"))
    }
    if toolCount == 1 {
      parts.append(String(localized: "1 tool"))
    } else if toolCount > 1 {
      parts.append(String(localized: "\(toolCount) tools"))
    }
    if !diffStat.isEmpty {
      parts.append(String(localized: "+\(diffStat.added) \u{2212}\(diffStat.removed)"))
    }
    return parts.joined(separator: ", ")
  }

  // MARK: - Grouping

  /// The position ranges of the turns of `items`.
  ///
  /// The function reads only the cases of the items, and not the records.
  ///
  /// - Parameter items: The items of a thread, in order.
  /// - Returns: One range for each turn, in order. A user message starts a
  ///   new range.
  static func turnRanges(in items: [ThreadItem]) -> [Range<Int>] {
    var ranges: [Range<Int>] = []
    var start = items.startIndex
    for position in items.indices where position > start && isTurnStart(items[position]) {
      ranges.append(start..<position)
      start = position
    }
    if start < items.endIndex {
      ranges.append(start..<items.endIndex)
    }
    return ranges
  }

  /// Tells whether `item` starts a turn.
  ///
  /// - Parameter item: The item.
  /// - Returns: `true` for a user message.
  static func isTurnStart(_ item: ThreadItem) -> Bool {
    if case .userMessage = item {
      return true
    }
    return false
  }

  /// Tells whether `item` is an item of the agent.
  ///
  /// - Parameter item: The item.
  /// - Returns: `false` for a user message and for the system prompt.
  static func isAgentItem(_ item: ThreadItem) -> Bool {
    switch item {
    case .userMessage, .system: false
    default: true
    }
  }

  /// The summaries of the turns of `items`.
  ///
  /// - Parameter items: The items of a thread, in order.
  /// - Returns: One summary for each turn, in order.
  @MainActor
  public static func compute(items: [ThreadItem]) -> [TurnSummary] {
    turnRanges(in: items).map { summarize(items[$0]) }
  }

  /// The first agent item of each turn, keyed by item id.
  ///
  /// The thread shows the summary line of a turn above this item. The
  /// function reads only the cases of the items, and not the records. Thus a
  /// view that calls it does not become invalid when a record changes.
  ///
  /// - Parameter items: The items of a thread, in order.
  /// - Returns: The identifier of the turn, keyed by the identifier of its
  ///   first agent item. A turn with no agent item has no entry.
  @MainActor
  public static func anchors(in items: [ThreadItem]) -> [String: String] {
    var anchors: [String: String] = [:]
    for range in turnRanges(in: items) {
      let turn = items[range]
      if let anchor = turn.first(where: isAgentItem) {
        anchors[anchor.id] = items[range.lowerBound].id
      }
    }
    return anchors
  }

  /// The summary of the turn that starts at `position`.
  ///
  /// - Parameters:
  ///   - position: The position of the first item of the turn.
  ///   - items: The items of a thread, in order.
  /// - Returns: The summary of the items from `position` to the next user
  ///   message, or `nil` when `position` is not in `items`.
  @MainActor
  public static func turn(startingAt position: Int, in items: [ThreadItem]) -> TurnSummary? {
    guard items.indices.contains(position) else { return nil }
    let next = items[(position + 1)...].firstIndex(where: isTurnStart) ?? items.endIndex
    return summarize(items[position..<next])
  }

  /// The summary of the items of one turn.
  ///
  /// - Parameter turn: The items of the turn, not empty.
  /// - Returns: The summary.
  @MainActor
  static func summarize(_ turn: ArraySlice<ThreadItem>) -> TurnSummary {
    var starts: [Date] = []
    var ends: [Date] = []
    var counts: [ToolCallStatus: Int] = [:]
    var diffStat = DiffStat()
    for item in turn {
      let times: (start: Date?, end: Date?)
      switch item {
      case .reasoning(let record):
        times = (record.startedAt, record.endedAt)
      case .toolCall(let record):
        times = (record.startedAt, record.endedAt)
        counts[record.status, default: 0] += 1
        diffStat = diffStat + diffStatOfContent(record.content)
      default:
        continue
      }
      if let start = times.start {
        starts.append(start)
      }
      if let end = times.end {
        ends.append(end)
      }
    }
    return TurnSummary(
      id: turn.first?.id ?? "",
      itemIDs: turn.map(\.id),
      startedAt: starts.min(),
      endedAt: ends.max(),
      toolCounts: counts,
      diffStat: diffStat)
  }

  /// The sum of the diffs in the content of a tool call.
  ///
  /// - Parameter content: The content of the call.
  /// - Returns: The sum of the stats of each ``ToolContent/diff(patch:)``.
  static func diffStatOfContent(_ content: [ToolContent]) -> DiffStat {
    content.reduce(DiffStat()) { sum, part in
      guard case .diff(let patch) = part else { return sum }
      return sum + DiffStat.count(patch: patch)
    }
  }
}

/// The one-line summary of a turn: "Worked N s, K tools, +A −R"
/// (plan.md §9 C).
///
/// The row is one static text element with the identifier from
/// ``identifier(for:)``.
public struct TurnSummaryRow: View {
  /// The start of the accessibility identifier of each row.
  public static let identifierPrefix = "turn-summary-"

  /// The SF Symbol name of the row.
  static let symbolName = "clock"

  /// The summary to show.
  let turn: TurnSummary

  @Environment(\.agentTheme) private var theme

  /// Makes the row of a turn.
  ///
  /// - Parameter turn: The summary to show.
  public init(turn: TurnSummary) {
    self.turn = turn
  }

  /// The accessibility identifier of the row of the turn with `id`.
  ///
  /// - Parameter id: The identifier of the turn.
  /// - Returns: `turn-summary-<id>`.
  public static func identifier(for id: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: id)
  }

  public var body: some View {
    let text = turn.text
    Label {
      Text(text)
        .monospacedDigit()
        .lineLimit(1)
    } icon: {
      Image(systemName: Self.symbolName)
        .fontWeight(theme.symbolWeight)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(text)
    .accessibilityAddTraits(.isStaticText)
    .accessibilityIdentifier(Self.identifier(for: turn.id))
  }
}

/// Shows the ``TurnSummaryRow`` of one turn of the thread, when the turn has
/// work.
///
/// This view, and not the row of the item, reads the records of the turn.
/// Thus a patch to a record of the turn evaluates this view and not the item
/// rows.
struct ThreadTurnSummary: View {
  /// The thread.
  let thread: AgentThread

  /// The identifier of the first item of the turn.
  let turnID: String

  var body: some View {
    if let position = thread.position(of: turnID),
      let turn = TurnSummary.turn(startingAt: position, in: thread.items),
      turn.hasWork
    {
      TurnSummaryRow(turn: turn)
    }
  }
}
