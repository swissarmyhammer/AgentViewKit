import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import SwiftUI

/// A function that gives the connection state of the server that a tool call
/// waits for, or `nil` when the call does not wait for a connection.
public typealias ToolCallConnectionStateProvider = @MainActor (ToolCallRecord) -> ConnectionState?

extension EnvironmentValues {
  /// The function that gives the connection state of a tool call that waits
  /// for authorization (plan.md §12).
  ///
  /// ``ToolCallView`` shows a ``ConnectionStatusChip`` when the function
  /// gives a state. The value is `nil` until a host sets a function with
  /// ``SwiftUI/View/toolCallConnectionState(_:)``.
  @Entry public var toolCallConnectionState: ToolCallConnectionStateProvider? = nil
}

extension View {
  /// Sets the function that gives the connection state of each tool call in
  /// this view.
  ///
  /// Give a state for a call that waits for the authorization of a server.
  /// ``ToolCallView`` then shows a ``ConnectionStatusChip`` in its row. Give
  /// `nil` for each other call.
  ///
  /// - Parameter provider: The function that gives the connection state of a
  ///   tool call, or `nil` for no chip.
  /// - Returns: A view that gives `provider` to its subtree.
  public func toolCallConnectionState(_ provider: ToolCallConnectionStateProvider?) -> some View {
    environment(\.toolCallConnectionState, provider)
  }
}

/// A tool call as a compact row that expands (plan.md §5, §9 C; update.md
/// §4.7 "Tool call view").
///
/// The view shows a ``ToolCallRecord`` of an ``AgentThread``, or a
/// `ToolCallEntry` of a `SessionModel`. It uses the ACP kind and status
/// types for both. See ``ToolKindSymbol`` and ``ToolStatusSymbol``.
///
/// The row shows the symbol of the kind, the `title` as the label, the
/// duration when the record has both times, and a status symbol:
///
/// - A pending or running call shows a `ProgressView` and a status symbol
///   with the variable color effect.
/// - The status symbol changes with the replace transition, and it bounces
///   when the call completes.
/// - A failed, cancelled, lost, or unknown call shows its own symbol and
///   label. See ``ToolStatusSymbol``.
///
/// When the host gives a connection state for a record, the row also shows
/// a ``ConnectionStatusChip``. See
/// ``SwiftUI/View/toolCallConnectionState(_:)``.
///
/// A press on the row expands the call. The expanded body shows the
/// locations as path chips, the raw input and the raw output as JSON in a
/// ``CodeBlockView``, and each part of the content:
///
/// - A block shows through ``ContentBlockView``. The text of an `execute`
///   call that has no terminal shows through ``CommandOutputView``.
/// - A diff shows through ``DiffView``, with the renderer of
///   ``SwiftUI/View/diffRenderer(_:)`` and the actions of
///   ``SwiftUI/View/diffActions(_:)``. A structured ACP diff with no
///   `git_patch` text shows the file of each change.
/// - A terminal shows through ``TerminalView``, with the record from the
///   ``SwiftUI/EnvironmentValues/agentThread``. A terminal that the thread
///   does not have shows a label with its id.
/// - Unknown content shows through ``UnknownItemView``.
///
/// An entry whose `name` has a registration in the
/// ``SwiftUI/EnvironmentValues/toolCallRegistry`` shows the registered view
/// in place of the default body. See ``SwiftUI/View/toolCallView(named:_:)``.
///
/// Under the row of an entry, the view shows a card for each pending
/// elicitation of the ``SwiftUI/EnvironmentValues/sessionModel`` that is
/// linked to the call (`ToolCallEntry.linkedElicitationIDs`). The cards show
/// also while the call is collapsed, because they wait for the user.
///
/// The user decision is in the ``ExpandedBlocksStore`` of the environment,
/// keyed by the record id or the row key of the entry. An entry with no
/// decision uses the ``ExpandedBlocksStore/defaultExpanded`` policy of the
/// store, and a record with no decision is collapsed. The row reads the
/// policy, so a policy that reads the status opens the call when the model
/// sets that status. When the environment has no store, the view uses a
/// store of its own.
///
/// The row reads the status, and the body does not. Thus a status change
/// evaluates the row and not the expanded body.
public struct ToolCallView: View {
  /// The start of the accessibility identifier of each call.
  public static let identifierPrefix = "tool-call-"

  /// The start of the ``BodyEvaluationCounter`` key of each row.
  public static let rowCounterPrefix = "tool-row-"

  /// The start of the ``BodyEvaluationCounter`` key of each expanded body.
  public static let bodyCounterPrefix = "tool-body-"

  /// The end of the accessibility identifier of the row button.
  static let toggleSuffix = "-toggle"

  /// The end of the accessibility identifier of the expanded body.
  static let bodySuffix = "-body"

  /// The end of the accessibility identifier of the location chips.
  static let locationsSuffix = "-locations"

  /// The end of the accessibility identifier of the raw input.
  static let inputSuffix = "-input"

  /// The end of the accessibility identifier of the raw output.
  static let outputSuffix = "-output"

  /// The part of the accessibility identifier of a content part before its
  /// index.
  static let contentInfix = "-content-"

  /// The end of the accessibility identifier of the linked elicitations.
  static let elicitationsSuffix = "-elicitations"

  /// The language of the code blocks that show the raw input and output.
  static let jsonLanguage = "json"

  /// The keys of the command in the raw input of an `execute` call.
  static let commandKeys = ["command", "cmd"]

  /// The keys of the exit code in the raw output of an `execute` call.
  static let exitCodeKeys = ["exitCode", "exit_code"]

  /// The number of seconds below which the duration shows one decimal.
  static let decimalDurationLimit: TimeInterval = 10

  /// The tool call to show.
  let source: ToolCallSource

  /// The store that the view uses when the environment has no store.
  @State private var ownStore = ExpandedBlocksStore()

  @Environment(\.expandedBlocksStore) private var environmentStore
  @Environment(\.toolCallConnectionState) private var connectionState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.agentTheme) private var theme

  /// Makes a tool call view.
  ///
  /// - Parameter record: The tool call to show.
  public init(record: ToolCallRecord) {
    self.source = .record(record)
  }

  /// Makes the tool call view of a tool call entry of a session transcript
  /// (update.md §4.7).
  ///
  /// The view shows the `title` of the entry as its label. The identifiers
  /// and the counter keys of the view use the row key of the entry. See
  /// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey``.
  ///
  /// - Parameter entry: The tool call to show.
  public init(entry: ToolCallEntry) {
    self.source = .entry(entry)
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the call of `id`.
  ///
  /// - Parameter id: The record id, or the row key of the entry.
  /// - Returns: `tool-call-<id>`.
  public static func identifier(for id: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: id)
  }

  /// The accessibility identifier of a part of the call of `id`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - suffix: The end of the identifier, such as ``toggleSuffix``.
  /// - Returns: `tool-call-<id><suffix>`.
  static func suffixedIdentifier(for id: String, suffix: String) -> String {
    identifier(for: id) + suffix
  }

  /// The accessibility identifier of the row button that expands the call.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `tool-call-<id>-toggle`.
  public static func toggleIdentifier(for id: String) -> String {
    suffixedIdentifier(for: id, suffix: toggleSuffix)
  }

  /// The accessibility identifier of the expanded body.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `tool-call-<id>-body`.
  public static func bodyIdentifier(for id: String) -> String {
    suffixedIdentifier(for: id, suffix: bodySuffix)
  }

  /// The accessibility identifier of the location chips.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `tool-call-<id>-locations`.
  public static func locationsIdentifier(for id: String) -> String {
    suffixedIdentifier(for: id, suffix: locationsSuffix)
  }

  /// The accessibility identifier of the raw input.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `tool-call-<id>-input`.
  public static func inputIdentifier(for id: String) -> String {
    suffixedIdentifier(for: id, suffix: inputSuffix)
  }

  /// The accessibility identifier of the raw output.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `tool-call-<id>-output`.
  public static func outputIdentifier(for id: String) -> String {
    suffixedIdentifier(for: id, suffix: outputSuffix)
  }

  /// The accessibility identifier of one part of the content.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - index: The position of the part in ``ToolCallRecord/content``.
  /// - Returns: `tool-call-<id>-content-<index>`.
  public static func contentIdentifier(for id: String, index: Int) -> String {
    suffixedIdentifier(for: id, suffix: contentInfix + String(index))
  }

  /// The ``BodyEvaluationCounter`` key of the row of `id`.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `tool-row-<id>`.
  public static func rowCounterKey(for id: String) -> String {
    rowCounterPrefix + id
  }

  /// The ``BodyEvaluationCounter`` key of the expanded body of `id`.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `tool-body-<id>`.
  public static func bodyCounterKey(for id: String) -> String {
    bodyCounterPrefix + id
  }

  /// The accessibility identifier of the cards of the elicitations that are
  /// linked to the call of `id`.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `tool-call-<id>-elicitations`.
  public static func elicitationsIdentifier(for id: String) -> String {
    suffixedIdentifier(for: id, suffix: elicitationsSuffix)
  }

  // MARK: - Text

  /// The label that VoiceOver reads for a call.
  ///
  /// - Parameters:
  ///   - title: The title of the call.
  ///   - status: The ACP progress of the call.
  /// - Returns: "<title>, <status>", such as "Read README.md, In progress".
  public static func accessibilityLabel(
    title: String, status: FoundationModelsACP.ToolCallStatus
  ) -> String {
    String(localized: "\(displayTitle(title)), \(ToolStatusSymbol.label(for: status))")
  }

  /// The title that the row shows.
  ///
  /// - Parameter title: The title of the call.
  /// - Returns: `title`, or "Tool call" when `title` is empty.
  static func displayTitle(_ title: String) -> String {
    title.isEmpty ? String(localized: "Tool call") : title
  }

  /// The duration that the row shows.
  ///
  /// - Parameters:
  ///   - start: The time when the call started, or `nil`.
  ///   - end: The time when the call ended, or `nil`.
  /// - Returns: `nil` when a time is missing. Otherwise the seconds with one
  ///   decimal below ten seconds, such as "1.5 s", and whole seconds from ten
  ///   seconds, such as "12 s". A negative duration shows as zero.
  public static func durationText(from start: Date?, to end: Date?) -> String? {
    guard let start, let end else { return nil }
    let seconds = max(end.timeIntervalSince(start), 0)
    let decimals = seconds < decimalDurationLimit ? 1 : 0
    let number = seconds.formatted(.number.precision(.fractionLength(decimals)))
    return String(localized: "\(number) s")
  }

  /// The command in the raw input of an `execute` call.
  ///
  /// - Parameter rawInput: The raw input of the call.
  /// - Returns: The string value of the first command key, or the string
  ///   items of an array value joined with spaces. `nil` when there is no
  ///   command.
  static func command(from rawInput: FoundationModelsACP.JSONValue?) -> String? {
    guard case .object(let fields)? = rawInput else { return nil }
    for key in commandKeys {
      switch fields[key] {
      case .string(let command)?:
        return command
      case .array(let parts)?:
        let words = parts.compactMap { part in
          if case .string(let word) = part { word } else { nil }
        }
        if !words.isEmpty {
          return words.joined(separator: " ")
        }
      default:
        continue
      }
    }
    return nil
  }

  /// The exit code in the raw output of an `execute` call.
  ///
  /// - Parameter rawOutput: The raw output of the call.
  /// - Returns: The integer value of the first exit code key, or `nil`.
  static func exitCode(from rawOutput: FoundationModelsACP.JSONValue?) -> Int? {
    guard case .object(let fields)? = rawOutput else { return nil }
    return exitCodeKeys.lazy.compactMap { key in
      if case .number(let code)? = fields[key] { Int(exactly: code) } else { nil }
    }.first
  }

  // MARK: - Body

  public var body: some View {
    let id = source.id
    #if DEBUG
      BodyEvaluationCounter.note(Self.rowCounterKey(for: id))
    #endif
    let store = environmentStore ?? ownStore
    let expanded = source.isExpanded(in: store)
    let label = Self.accessibilityLabel(title: source.title, status: source.status)
    return VStack(alignment: .leading, spacing: theme.spacing.xs) {
      header(id: id, store: store, expanded: expanded, label: label)
      if case .entry(let entry) = source {
        LinkedElicitations(entry: entry)
      }
      if expanded {
        ToolCallBody(source: source)
          .contentContainer(identifier: Self.bodyIdentifier(for: id))
      }
    }
    .contentContainer(identifier: Self.identifier(for: id))
    .accessibilityLabel(label)
    // The row is a container with this call as its one child. The second
    // hidden child keeps SwiftUI from merging the call into the row, so the
    // call keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// The row: the button that expands the call, and the connection chip.
  ///
  /// - Parameters:
  ///   - id: The text identity of the call.
  ///   - store: The store of the user decisions.
  ///   - expanded: `true` while the call is expanded.
  ///   - label: The label that VoiceOver reads for the call.
  /// - Returns: The row view.
  private func header(
    id: String, store: ExpandedBlocksStore, expanded: Bool, label: String
  ) -> some View {
    HStack(spacing: theme.spacing.s) {
      Button {
        source.setExpanded(to: !expanded, in: store)
      } label: {
        rowContent(expanded: expanded)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(label)
      .accessibilityValue(expanded ? Text("Expanded") : Text("Collapsed"))
      .accessibilityIdentifier(Self.toggleIdentifier(for: id))
      if case .record(let record) = source, let state = connectionState?(record) {
        ConnectionStatusChip(state: state)
      }
    }
  }

  /// The symbols and the text inside the row button.
  ///
  /// - Parameter expanded: `true` while the call is expanded.
  /// - Returns: The content of the button.
  private func rowContent(expanded: Bool) -> some View {
    HStack(spacing: theme.spacing.s) {
      Image(systemName: ToolKindSymbol.name(for: source.kind))
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(.secondary)
      Text(Self.displayTitle(source.title))
        .font(theme.proseFont)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: theme.spacing.s)
      if let duration = Self.durationText(from: source.startedAt, to: source.endedAt) {
        Text(duration)
          .font(.caption)
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      statusGlyph
      Image(systemName: "chevron.right")
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(.secondary)
        .rotationEffect(expanded ? ReasoningView.expandedChevronAngle : .zero)
    }
    .contentShape(Rectangle())
  }

  /// The progress indicator and the status symbol.
  private var statusGlyph: some View {
    let status = source.status
    let isLive = ToolStatusSymbol.isLive(status)
    return HStack(spacing: theme.spacing.xs) {
      if isLive {
        ProgressView()
          .controlSize(.mini)
      }
      Image(systemName: ToolStatusSymbol.name(for: status))
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(theme.statusColors.color(for: status))
        .contentTransition(.symbolEffect(.replace))
        .symbolEffect(.variableColor.iterative, isActive: isLive)
        .symbolEffect(.bounce, value: status == .completed)
        .symbolEffectsRemoved(reduceMotion)
    }
  }
}

/// The expanded body of a ``ToolCallView``.
///
/// The body reads the content, the locations, the raw input, the raw
/// output, and the kind of the call. It does not read the status, so a
/// status change does not evaluate it. An entry whose `name` has a
/// registration in the ``SwiftUI/EnvironmentValues/toolCallRegistry`` shows
/// the registered view in place of the default body.
private struct ToolCallBody: View {
  /// The tool call to show.
  let source: ToolCallSource

  @Environment(\.toolCallRegistry) private var registry
  @Environment(\.agentThread) private var thread
  @Environment(\.agentTheme) private var theme

  var body: some View {
    let id = source.id
    #if DEBUG
      BodyEvaluationCounter.note(ToolCallView.bodyCounterKey(for: id))
    #endif
    return Group {
      if case .entry(let entry) = source, let renderer = registry.resolve(name: entry.name) {
        renderer(entry)
      } else {
        defaultBody(id: id)
      }
    }
    .padding(.leading, theme.spacing.l)
  }

  /// The default body: the locations, the raw input, each part of the
  /// content, and the raw output.
  ///
  /// - Parameter id: The text identity of the call.
  /// - Returns: The body view.
  private func defaultBody(id: String) -> some View {
    let parts = source.parts
    let locations = source.locations
    let showsCommandOutput = source.kind == .execute && !parts.contains(where: \.isTerminal)
    return VStack(alignment: .leading, spacing: theme.spacing.s) {
      if !locations.isEmpty {
        LocationChips(locations: locations)
          .contentContainer(identifier: ToolCallView.locationsIdentifier(for: id))
      }
      if let rawInput = source.rawInput {
        jsonBlock(rawInput, title: String(localized: "Input"))
          .contentContainer(identifier: ToolCallView.inputIdentifier(for: id))
      }
      ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
        partView(part, index: index, showsCommandOutput: showsCommandOutput)
          .contentContainer(identifier: ToolCallView.contentIdentifier(for: id, index: index))
      }
      if let rawOutput = source.rawOutput {
        jsonBlock(rawOutput, title: String(localized: "Output"))
          .contentContainer(identifier: ToolCallView.outputIdentifier(for: id))
      }
    }
  }

  /// A JSON value as a code block. The header shows the title.
  ///
  /// - Parameters:
  ///   - value: The value to show.
  ///   - title: The text in the header of the block.
  /// - Returns: The code block.
  private func jsonBlock(_ value: FoundationModelsACP.JSONValue, title: String) -> some View {
    CodeBlockView(code: value.prettyPrinted, language: ToolCallView.jsonLanguage, filename: title)
  }

  /// The view of one part of the content.
  ///
  /// - Parameters:
  ///   - part: The part to show.
  ///   - index: The position of the part in the content.
  ///   - showsCommandOutput: `true` when a text block shows through
  ///     ``CommandOutputView``.
  /// - Returns: The view of the part.
  @ViewBuilder
  private func partView(_ part: ToolCallPart, index: Int, showsCommandOutput: Bool) -> some View {
    let partID = ToolCallView.contentIdentifier(for: source.id, index: index)
    switch part {
    case .block(let block):
      if showsCommandOutput, let text = Self.text(of: block) {
        CommandOutputView(
          command: ToolCallView.command(from: source.rawInput),
          output: text,
          exitCode: ToolCallView.exitCode(from: source.rawOutput))
      } else {
        ContentBlockView(source: block, id: partID)
      }
    case .patch(let patch):
      DiffView(patch: patch)
    case .diff(let diff):
      DiffView(diff: diff)
    case .terminal(let terminalID):
      if let terminal = thread?.terminals[TerminalID(terminalID)] {
        TerminalView(record: terminal)
      } else {
        Label(String(localized: "Terminal \(terminalID)"), systemImage: "terminal")
          .foregroundStyle(.secondary)
      }
    case .unknown(let kind, let raw):
      UnknownItemView(kind: kind, wireValue: raw, id: partID)
    }
  }

  /// The text of a text block of the content.
  ///
  /// - Parameter block: A kit block of a record, or the ACP block of an entry.
  /// - Returns: The text, or `nil` for a block that is not text.
  private static func text(
    of block: BlockSource<ContentBlock, FoundationModelsACP.ContentBlock>
  ) -> String? {
    switch block {
    case .record(let record):
      if case .text(let text) = record.content { text } else { nil }
    case .wire(let wire):
      if case .text(let text) = wire { text.text } else { nil }
    }
  }
}

/// The cards of the pending elicitations that are linked to a tool call entry
/// (update.md §4.2 "Pending requests", §4.7 "Tool call view").
///
/// The view reads `ToolCallEntry.linkedElicitationIDs` and finds each one in
/// the `pendingElicitations` of the ``SwiftUI/EnvironmentValues/sessionModel``.
/// It gives each `PendingElicitation` to an ``ElicitationCard`` with no
/// conversion, in link order, and the card answers to the session model. With
/// no session model in the environment, or with no linked elicitation, it
/// shows nothing.
private struct LinkedElicitations: View {
  /// The log of a link that the session model has no pending request for.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "ToolCallView")

  /// The tool call entry.
  let entry: ToolCallEntry

  @Environment(\.sessionModel) private var session
  @Environment(\.agentTheme) private var theme

  var body: some View {
    if let session {
      let elicitations = Self.elicitations(linkedTo: entry, in: session)
      if !elicitations.isEmpty {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
          ForEach(elicitations) { elicitation in
            ElicitationCard(request: elicitation, owner: session)
          }
        }
        .contentContainer(identifier: ToolCallView.elicitationsIdentifier(for: entry.id.rowKey))
      }
    }
  }

  /// The pending elicitations that are linked to `entry` and have a card.
  ///
  /// The session model keeps each link only while its elicitation is
  /// pending, so each link has a pending request. A link with no pending
  /// request stops a debug build, and the log records it in a release build.
  ///
  /// - Parameters:
  ///   - entry: The tool call entry.
  ///   - session: The session model of the entry.
  /// - Returns: The pending elicitations of the session model, in link order.
  private static func elicitations(
    linkedTo entry: ToolCallEntry, in session: SessionModel
  ) -> [PendingElicitation] {
    let pending = session.pendingElicitations
    return entry.linkedElicitationIDs.compactMap { id in
      guard let elicitation = pending.first(where: { $0.id == id }) else {
        assertionFailure("The tool call links an elicitation that is not pending.")
        logger.error("A tool call links an elicitation that is not pending. The row does not show it.")
        return nil
      }
      return elicitation
    }
    .filter(ElicitationCard.hasCard(for:))
  }
}

/// The locations of a tool call as a row of chips that wraps.
private struct LocationChips: View {
  /// The locations to show.
  let locations: [ToolCallLocation]

  @Environment(\.agentTheme) private var theme

  var body: some View {
    ChipFlowLayout(spacing: theme.spacing.xs) {
      ForEach(Array(locations.enumerated()), id: \.offset) { _, location in
        chip(location)
      }
    }
  }

  /// The text of a location: the path, and the line when there is one.
  ///
  /// - Parameters:
  ///   - location: The location.
  ///   - path: The path text to use.
  /// - Returns: "<path>" or "<path>:<line>".
  private static func text(_ location: ToolCallLocation, path: String) -> String {
    guard let line = location.line else { return path }
    return "\(path):\(line)"
  }

  /// One chip: the file name, with the full path in the help tag.
  ///
  /// - Parameter location: The location to show.
  /// - Returns: The chip view.
  private func chip(_ location: ToolCallLocation) -> some View {
    let fullText = Self.text(location, path: location.path)
    let shortText = Self.text(
      location, path: URL(fileURLWithPath: location.path).lastPathComponent)
    return Label(shortText, systemImage: "doc")
      .font(.caption)
      .lineLimit(1)
      .truncationMode(.middle)
      .padding(.horizontal, theme.spacing.s)
      .padding(.vertical, theme.spacing.xs)
      .background(.quaternary, in: Capsule())
      .help(fullText)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(fullText)
      .accessibilityAddTraits(.isStaticText)
  }
}

/// A layout that puts its views in rows, and starts a new row when a view
/// does not fit.
private struct ChipFlowLayout: Layout {
  /// The space between two views, and between two rows.
  let spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let frames = arrange(subviews, width: proposal.width ?? .infinity)
    let width = frames.map(\.maxX).max() ?? 0
    let height = frames.map(\.maxY).max() ?? 0
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let frames = arrange(subviews, width: bounds.width)
    for (subview, frame) in zip(subviews, frames) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(frame.size))
    }
  }

  /// The frame of each view, from the top left corner of the layout.
  ///
  /// - Parameters:
  ///   - subviews: The views to arrange.
  ///   - width: The width of a row.
  /// - Returns: One frame for each view, in order.
  private func arrange(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
    var frames: [CGRect] = []
    var origin = CGPoint.zero
    var rowHeight: CGFloat = 0
    for subview in subviews {
      var size = subview.sizeThatFits(.unspecified)
      size.width = min(size.width, width)
      if origin.x > 0, origin.x + size.width > width {
        origin.x = 0
        origin.y += rowHeight + spacing
        rowHeight = 0
      }
      frames.append(CGRect(origin: origin, size: size))
      origin.x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return frames
  }
}
