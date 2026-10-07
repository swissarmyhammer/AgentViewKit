import FoundationModelsACPClient
import SwiftUI

/// A vertical list of the work of the agent in the transcript of a
/// `SessionModel` (plan.md §9 C).
///
/// The timeline shows one row for each `ThoughtEntry`, `ToolCallEntry`,
/// `TerminalEntry` and `ErrorEntry` of `SessionModel.transcript`, in
/// transcript order. The other entries show no row. The model has no turns
/// and no times, so the timeline shows no turn section, no duration and no
/// time bar. A new entry of the model adds a row with no other step.
///
/// The body reads only the transcript. Each row reads its own entry object,
/// so a status change of a tool call evaluates only the row of that call.
///
/// A click on a row expands the matching view below it: ``ReasoningView``,
/// ``ToolCallView``, ``TerminalView`` or ``ErrorView``. The open state of a
/// row is view state, keyed by the row key of the entry.
///
/// The row button of an entry has the identifier from
/// ``rowIdentifier(for:)``, and its expanded view has the identifier from
/// ``detailIdentifier(for:)``. Both take the
/// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey`` of the entry.
public struct ActivityTimeline: View {
  /// The accessibility identifier of the timeline.
  public static let identifier = "activity-timeline"

  /// The accessibility identifier of the empty state.
  public static let emptyStateIdentifier = "activity-timeline-empty"

  /// The start of the accessibility identifier of each row button.
  public static let rowIdentifierPrefix = "activity-entry-"

  /// The end of the accessibility identifier of an expanded view.
  static let detailSuffix = "-detail"

  /// The SF Symbol name of the empty state.
  static let emptySymbolName = "clock"

  /// The session model whose transcript the timeline shows.
  let session: SessionModel

  /// The row keys of the expanded rows.
  @State private var expandedRows: Set<String> = []

  @Environment(\.agentTheme) private var theme

  /// Makes the timeline of the transcript of a session model.
  ///
  /// - Parameter session: The session model whose transcript the timeline
  ///   shows.
  public init(session: SessionModel) {
    self.session = session
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the row button of an entry.
  ///
  /// - Parameter key: The row key of the entry.
  /// - Returns: `activity-entry-<key>`.
  public static func rowIdentifier(for key: String) -> String {
    AccessibilityIdentifier.make(prefix: rowIdentifierPrefix, value: key)
  }

  /// The accessibility identifier of the expanded view of an entry.
  ///
  /// - Parameter key: The row key of the entry.
  /// - Returns: `activity-entry-<key>-detail`.
  public static func detailIdentifier(for key: String) -> String {
    rowIdentifier(for: key) + detailSuffix
  }

  // MARK: - Body

  public var body: some View {
    let entries = session.transcript.compactMap(TimelineEntry.init(entry:))
    VStack(spacing: 0) {
      if entries.isEmpty {
        ContentUnavailableView(
          "No Activity",
          systemImage: Self.emptySymbolName,
          description: Text("Tool calls and reasoning show here.")
        )
        .accessibilityIdentifier(Self.emptyStateIdentifier)
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: theme.spacing.xs) {
            ForEach(entries) { entry in
              let key = entry.id.rowKey
              ActivityEntryRow(
                entry: entry,
                isExpanded: expandedRows.contains(key),
                onToggle: { toggle(key) }
              )
            }
          }
          .padding(theme.rowPadding)
        }
      }
    }
    .environment(\.sessionModel, session)
    .contentContainer(identifier: Self.identifier)
  }

  /// Expands or collapses the row of `key`.
  ///
  /// - Parameter key: The row key of the entry.
  private func toggle(_ key: String) {
    if expandedRows.contains(key) {
      expandedRows.remove(key)
    } else {
      expandedRows.insert(key)
    }
  }
}

/// A transcript entry that has a row in an ``ActivityTimeline``.
///
/// Each case holds the observable object of the model, and no copy of its
/// data.
private enum TimelineEntry: Identifiable {
  /// A thought of the agent.
  case thought(ThoughtEntry)

  /// A tool call.
  case toolCall(ToolCallEntry)

  /// An agent-owned terminal.
  case terminal(TerminalEntry)

  /// An error that the client shows in the transcript.
  case error(ErrorEntry)

  /// Makes the timeline entry of a transcript entry.
  ///
  /// - Parameter entry: The transcript entry.
  /// - Returns: `nil` for a user message, an agent message, a plan, an
  ///   unknown update and a compaction, which have no row.
  init?(entry: TranscriptEntry) {
    switch entry {
    case .thought(let thought): self = .thought(thought)
    case .toolCall(let toolCall): self = .toolCall(toolCall)
    case .terminal(let terminal): self = .terminal(terminal)
    case .error(let error): self = .error(error)
    case .userMessage, .agentMessage, .plan, .unknown, .compaction: return nil
    }
  }

  /// The stable identity of the transcript entry.
  var id: TranscriptEntry.ID {
    switch self {
    case .thought(let entry): entry.id
    case .toolCall(let entry): entry.id
    case .terminal(let entry): entry.id
    case .error(let entry): entry.id
    }
  }
}

/// One row of an ``ActivityTimeline``, and its expanded view.
private struct ActivityEntryRow: View {
  /// The symbol, the text and the color of a row.
  private struct Appearance {
    /// The text of the row.
    let title: String

    /// The SF Symbol name of the row.
    let symbolName: String

    /// The color of the symbol.
    let tint: Color
  }

  /// The SF Symbol name of a thought row.
  static let thoughtSymbolName = "brain"

  /// The SF Symbol name of a terminal row.
  static let terminalSymbolName = "terminal"

  /// The entry to show.
  let entry: TimelineEntry

  /// `true` while the matching view shows.
  let isExpanded: Bool

  /// The function that expands or collapses the row.
  let onToggle: () -> Void

  @Environment(\.agentTheme) private var theme

  var body: some View {
    let key = entry.id.rowKey
    let appearance = appearance
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Button(action: onToggle) {
        HStack(spacing: theme.spacing.s) {
          Image(systemName: appearance.symbolName)
            .fontWeight(theme.symbolWeight)
            .foregroundStyle(appearance.tint)
          Text(appearance.title)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer(minLength: theme.spacing.s)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(appearance.title)
      .accessibilityHint(isExpanded ? Text("Hides the details") : Text("Shows the details"))
      .accessibilityIdentifier(ActivityTimeline.rowIdentifier(for: key))
      if isExpanded {
        detail
          .contentContainer(identifier: ActivityTimeline.detailIdentifier(for: key))
      }
    }
  }

  // MARK: - Content

  /// The symbol, the text and the color of the row, from the entry object.
  private var appearance: Appearance {
    switch entry {
    case .thought:
      Appearance(
        title: ReasoningView.completedTitle(duration: nil), symbolName: Self.thoughtSymbolName,
        tint: Color.secondary)
    case .toolCall(let toolCall):
      toolCallAppearance(ToolCallSource.entry(toolCall))
    case .terminal(let terminal):
      Appearance(
        title: TerminalSource.entry(terminal).command ?? String(localized: "Terminal"),
        symbolName: Self.terminalSymbolName, tint: Color.secondary)
    case .error(let error):
      errorAppearance(ErrorView.content(for: ErrorView.Source.entry(error).kind))
    }
  }

  /// The appearance of a tool call row.
  ///
  /// - Parameter source: The tool call.
  /// - Returns: The title, the symbol of the kind and the color of the
  ///   status.
  private func toolCallAppearance(_ source: ToolCallSource) -> Appearance {
    Appearance(
      title: ToolCallView.displayTitle(source.title),
      symbolName: ToolKindSymbol.name(for: source.kind),
      tint: theme.statusColors.color(for: source.status))
  }

  /// The appearance of an error row.
  ///
  /// - Parameter content: The content of the error card.
  /// - Returns: The title and the symbol of the card, with the failure color.
  private func errorAppearance(_ content: ErrorView.Content) -> Appearance {
    Appearance(title: content.title, symbolName: content.symbolName, tint: theme.statusColors.failed)
  }

  /// The view that a click on the row shows.
  @ViewBuilder private var detail: some View {
    switch entry {
    case .thought(let thought):
      ReasoningView(entry: thought)
    case .toolCall(let toolCall):
      ToolCallView(entry: toolCall)
    case .terminal(let terminal):
      TerminalView(entry: terminal)
    case .error(let error):
      ErrorView(entry: error)
    }
  }
}
