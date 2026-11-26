import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// A copy of the data of one transcript row that sets its height.
///
/// The copy is a value, so ``TranscriptRowHeights`` sends it to a background
/// task. Its hash is the content digest of the entry version. A row whose
/// look depends on data that the copy does not hold is not covered: its
/// kind is ``Kind/uncovered``, and no chrome rule gives its height. These rows
/// are not covered: a row with a view override, a message with a block that
/// is not text, an expanded thought, a tool call that waits, opens a child
/// session, runs in the background or shows location chips, a diff of more
/// than one file or with no patch text, an output with more rows than the
/// row limit, a terminal that still runs, a plan with unknown content and an
/// unknown entry.
nonisolated public struct TranscriptRowContent: Hashable, Sendable {
  /// The row key of the entry.
  public let rowKey: String

  /// The data of the row kind.
  let kind: Kind

  /// The data of each row kind.
  enum Kind: Hashable, Sendable {
    /// A user or an agent message: its text blocks, and the send state of a
    /// user message.
    case message(blocks: [String], sendState: SendState?)

    /// A collapsed thought.
    case collapsedThought

    /// A tool call card.
    case toolCall(ToolCall)

    /// A terminal that ran a command.
    case terminal(Terminal)

    /// A plan: its rows.
    case plan([PlanRow])

    /// An error notice: the text of its explanation.
    case error(detail: String)

    /// A compaction notice.
    case compaction(Compaction)

    /// A message from another session.
    case sessionMessage(participants: String, blocks: [String])

    /// A row that no chrome rule covers.
    case uncovered
  }

  /// The data of a tool call card.
  struct ToolCall: Hashable, Sendable {
    /// The symbol of the kind of the call.
    let kindSymbol: String

    /// The symbol of the status that the card shows.
    let statusSymbol: String

    /// The parts of the expanded body, or `nil` when the card is collapsed.
    let body: [BodyPart]?
  }

  /// One part of the expanded body of a tool call.
  enum BodyPart: Hashable, Sendable {
    /// A code block of JSON.
    case json(String)

    /// A text block.
    case text(String)

    /// A diff of one file.
    case diff(patch: String)

    /// The output of a command.
    case commandOutput(output: String, exitSymbol: String?)
  }

  /// The data of one row of a plan.
  struct PlanRow: Hashable, Sendable {
    /// The text of the step.
    let text: String

    /// The symbol of the status of the step.
    let statusSymbol: String

    /// The symbol of the priority of the step.
    let prioritySymbol: String
  }

  /// The data of a terminal.
  struct Terminal: Hashable, Sendable {
    /// The command label.
    let command: String

    /// The working folder label, or `nil`.
    let folder: String?

    /// The shown output.
    let output: String

    /// The symbol of the exit label.
    let exitSymbol: String
  }

  /// The data of a compaction notice.
  struct Compaction: Hashable, Sendable {
    /// The status summary.
    let summary: String

    /// The symbol name.
    let symbol: String

    /// The error text, or `nil`.
    let error: String?

    /// The text blocks of the summary.
    let blocks: [String]
  }

  /// Copies the data of `entry` that sets the height of its row.
  ///
  /// - Parameters:
  ///   - entry: The transcript entry.
  ///   - isExpanded: Whether the blocks of the row are expanded.
  @MainActor public init(entry: TranscriptEntry, isExpanded: Bool) {
    rowKey = entry.rowKey
    kind = Self.kind(of: entry, isExpanded: isExpanded)
  }

  /// The data of the row kind of `entry`.
  ///
  /// - Parameters:
  ///   - entry: The transcript entry.
  ///   - isExpanded: Whether the blocks of the row are expanded.
  /// - Returns: The data.
  @MainActor private static func kind(of entry: TranscriptEntry, isExpanded: Bool) -> Kind {
    switch entry {
    case .userMessage(let message):
      textBlocks(of: message.content).map { .message(blocks: $0, sendState: message.sendState) } ?? .uncovered
    case .agentMessage(let message):
      textBlocks(of: message.content).map { .message(blocks: $0, sendState: nil) } ?? .uncovered
    case .thought:
      isExpanded ? .uncovered : .collapsedThought
    case .toolCall(let call):
      toolCall(call, isExpanded: isExpanded).map(Kind.toolCall) ?? .uncovered
    case .terminal(let terminal):
      self.terminal(terminal).map(Kind.terminal) ?? .uncovered
    case .plan(let plan):
      plan.unknownContent == nil ? .plan(plan.entries.map(planRow)) : .uncovered
    case .error(let error):
      error.data == nil
        ? .error(detail: ErrorView.content(code: error.code.wireValue, message: error.message).detail) : .uncovered
    case .compaction(let compaction):
      self.compaction(compaction).map(Kind.compaction) ?? .uncovered
    case .sessionMessage(let message):
      sessionMessage(message)
    case .unknown:
      .uncovered
    }
  }

  /// The texts of the shown blocks of a content list, with adjacent text
  /// joined as `EntryContentView` joins it.
  ///
  /// - Parameter content: The content blocks.
  /// - Returns: The texts, or `nil` when a shown block is not text.
  static func textBlocks(of content: [ContentBlock]) -> [String]? {
    var texts: [String] = []
    for block in EntryContentView.joiningAdjacentText(in: content) where block.isVisibleToUser {
      guard case .text(let text) = block else { return nil }
      texts.append(text.text)
    }
    return texts
  }

  /// The data of a tool call card.
  ///
  /// - Parameters:
  ///   - call: The tool call.
  ///   - isExpanded: Whether the card is expanded.
  /// - Returns: The data, or `nil` when no rule covers the card.
  @MainActor private static func toolCall(_ call: ToolCallEntry, isExpanded: Bool) -> ToolCall? {
    let status = ToolCallBackground.shownStatus(of: call)
    guard call.linkedElicitationIDs.isEmpty, call.childSession == nil,
      !ToolCallBackground.showsBackgroundCaption(call, shownStatus: status)
    else { return nil }
    let kindSymbol = TranscriptRowSymbols.tool(call.shownKind)
    let statusSymbol = TranscriptRowSymbols.status(status)
    guard isExpanded else { return ToolCall(kindSymbol: kindSymbol, statusSymbol: statusSymbol, body: nil) }
    guard let body = toolCallBody(call) else { return nil }
    return ToolCall(kindSymbol: kindSymbol, statusSymbol: statusSymbol, body: body)
  }

  /// The parts of the expanded body of a tool call.
  ///
  /// - Parameter call: The tool call.
  /// - Returns: The parts, or `nil` when no rule covers a part.
  @MainActor private static func toolCallBody(_ call: ToolCallEntry) -> [BodyPart]? {
    let parts = call.parts
    guard ToolCallBody.chipLocations(call.locations, notShownBy: parts, id: call.id.rowKey).isEmpty else {
      return nil
    }
    let showsCommandOutput = call.shownKind == .execute && !parts.contains(where: \.isTerminal)
    let exitCode = ToolCallView.exitCode(from: call.rawOutput)
    var body: [BodyPart] = []
    if let rawInput = call.rawInput {
      body.append(.json(rawInput.prettyPrinted))
    }
    for part in parts {
      guard let shown = bodyPart(part, showsCommandOutput: showsCommandOutput, exitCode: exitCode) else {
        return nil
      }
      body.append(shown)
    }
    if let rawOutput = call.rawOutput {
      body.append(.json(rawOutput.prettyPrinted))
    }
    return body
  }

  /// The data of one part of a tool call body.
  ///
  /// - Parameters:
  ///   - part: The part.
  ///   - showsCommandOutput: Whether a text part shows as command output.
  ///   - exitCode: The exit code of the command, or `nil`.
  /// - Returns: The data, or `nil` when no rule covers the part.
  @MainActor private static func bodyPart(_ part: ToolCallPart, showsCommandOutput: Bool, exitCode: Int?)
    -> BodyPart?
  {
    switch part {
    case .block(let block):
      guard block.isVisibleToUser, case .text(let text) = block else { return nil }
      guard showsCommandOutput else { return .text(text.text) }
      return commandOutput(text.text, exitCode: exitCode)
    case .diff(let diff):
      guard DiffSummary.files(of: diff).count == 1, let patch = DiffSummary.gitPatchText(of: diff) else {
        return nil
      }
      return .diff(patch: patch)
    case .terminal, .unknown:
      return nil
    }
  }

  /// The data of a command output.
  ///
  /// - Parameters:
  ///   - output: The output text.
  ///   - exitCode: The exit code, or `nil`.
  /// - Returns: The data, or `nil` when the output has more rows than the
  ///   row limit.
  @MainActor private static func commandOutput(_ output: String, exitCode: Int?) -> BodyPart? {
    let shown = TerminalOutput(
      output: output, palette: EnvironmentValues().editorTheme.terminalPalette,
      limit: CommandOutputView.defaultRowLimit)
    guard !shown.rows.isCapped else { return nil }
    let symbol = CommandOutputView.ExitOutcome(exitCode: exitCode)?.symbol.systemImage
    return .commandOutput(output: shown.rows.text, exitSymbol: symbol)
  }

  /// The data of a terminal.
  ///
  /// - Parameter terminal: The terminal.
  /// - Returns: The data, or `nil` when the terminal still runs or its
  ///   output has more rows than the row limit.
  @MainActor private static func terminal(_ terminal: TerminalEntry) -> Terminal? {
    guard let status = terminal.exitStatus else { return nil }
    let shown = TerminalOutput(
      output: terminal.text, palette: EnvironmentValues().editorTheme.terminalPalette,
      limit: TerminalView.defaultRowLimit)
    guard !shown.rows.isCapped else { return nil }
    return Terminal(
      command: terminal.command ?? TerminalView.untitledCommand, folder: terminal.cwd?.rawValue,
      output: shown.rows.text,
      exitSymbol: TerminalView.ExitSummary(code: status.exitCode, signal: status.signal).symbolName)
  }

  /// The data of one row of a plan.
  ///
  /// - Parameter entry: The plan entry.
  /// - Returns: The data.
  @MainActor private static func planRow(_ entry: PlanEntry) -> PlanRow {
    PlanRow(
      text: entry.content, statusSymbol: TranscriptRowSymbols.planStatus(entry.status),
      prioritySymbol: TaskListView.prioritySymbol(entry.priority))
  }

  /// The data of a compaction notice.
  ///
  /// - Parameter compaction: The compaction entry.
  /// - Returns: The data, or `nil` when a summary block is not text.
  @MainActor private static func compaction(_ compaction: CompactionEntry) -> Compaction? {
    guard let blocks = textBlocks(of: compaction.summary) else { return nil }
    let status = EditorStatus(compaction.status)
    return Compaction(
      summary: status.summary, symbol: CompactionEntryView.symbolName, error: compaction.error, blocks: blocks)
  }

  /// The data of a message from another session.
  ///
  /// - Parameter message: The session message entry.
  /// - Returns: The data.
  @MainActor private static func sessionMessage(_ message: SessionMessageEntry) -> Kind {
    guard let blocks = textBlocks(of: message.content) else { return .uncovered }
    let participants = SessionMessageView.participantsText(
      sender: message.senderSessionId, recipient: message.recipientSessionId,
      message: SessionMessageView.sender(in: message.meta))
    return .sessionMessage(participants: participants, blocks: blocks)
  }
}
