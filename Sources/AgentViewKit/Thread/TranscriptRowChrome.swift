import CoreGraphics
import FoundationModelsACPClient

/// The chrome rule of each row kind: the padding, the header heights and the
/// block frames that AgentViewKit adds around the text parts of a row.
///
/// Each rule is a pure function of the row content and the theme metrics.
/// A rule gives the layout tree of its row (``TranscriptRowNode``), and the
/// height of the row is the height of that tree with the text measure. A
/// rule follows the layout of the views of its row kind, so a change to that
/// layout changes the rule too. The tests of the rules mount each row kind
/// and compare its height with the rule.
nonisolated public enum TranscriptRowChrome {
  /// The height of a text part at a width.
  public typealias Measure = (TranscriptTextPart, CGFloat) -> CGFloat

  /// The language of the code blocks of the raw input and output of a call.
  static let jsonLanguage = "json"

  /// The height of a row.
  ///
  /// - Parameters:
  ///   - content: The content of the row.
  ///   - width: The width of the row.
  ///   - metrics: The theme metrics.
  ///   - measure: The height of a text part at a width. A rule calls it for
  ///     each text part in the order of the parts from top to bottom.
  /// - Returns: The height, or `nil` when no rule covers the content.
  public static func height(
    of content: TranscriptRowContent, width: CGFloat, metrics: TranscriptRowMetrics, measure: Measure
  ) -> CGFloat? {
    withoutActuallyEscaping(measure) { measure in
      layout(of: content, metrics: metrics)?.height(width: width, measure: measure)
    }
  }

  /// The layout tree of a row.
  ///
  /// - Parameters:
  ///   - content: The content of the row.
  ///   - metrics: The theme metrics.
  /// - Returns: The tree, or `nil` when no rule covers the content.
  static func layout(of content: TranscriptRowContent, metrics: TranscriptRowMetrics) -> TranscriptRowNode? {
    TranscriptRowRule(metrics: metrics).layout(of: content.kind)
  }
}

/// The chrome rules with their metrics.
nonisolated private struct TranscriptRowRule {
  /// The theme metrics.
  let metrics: TranscriptRowMetrics

  /// The layout tree of a row of one kind.
  ///
  /// - Parameter kind: The data of the row kind.
  /// - Returns: The tree, or `nil` when no rule covers the row.
  func layout(of kind: TranscriptRowContent.Kind) -> TranscriptRowNode? {
    switch kind {
    case .message(let role, let blocks, let sendState): message(role: role, blocks: blocks, sendState: sendState)
    case .collapsedThought(let title): collapsedThought(title: title)
    case .toolCall(let call): toolCall(call)
    case .terminal(let terminal): self.terminal(terminal)
    case .plan(let rows): plan(rows)
    case .error(let detail): error(detail: detail)
    case .compaction(let compaction): self.compaction(compaction)
    case .sessionMessage(let participants, let blocks): sessionMessage(participants: participants, blocks: blocks)
    case .uncovered: nil
    }
  }

  // MARK: - Shared chrome

  /// A content tile around a list of parts.
  ///
  /// `ContentTileStack` puts the tile gap between the parts, and
  /// `contentTile()` pads the stack on each side.
  ///
  /// - Parameter parts: The parts, or `nil` for a part that no rule covers.
  /// - Returns: The tile, or `nil` when a part has no rule.
  func tile(_ parts: [TranscriptRowNode?]) -> TranscriptRowNode? {
    stack(parts, spacing: metrics.tileGap).map { .inset($0, padding: metrics.tilePadding) }
  }

  /// A content tile around a stack of parts (``tile(_:)``).
  ///
  /// - Parameter parts: The parts, or `nil` for a part that no rule covers.
  /// - Returns: The tile, or `nil` when a part has no rule.
  func tile(_ parts: TranscriptRowNode?...) -> TranscriptRowNode? {
    tile(parts)
  }

  /// All parts.
  ///
  /// - Parameter parts: The parts, or `nil` for a part that no rule covers.
  /// - Returns: The parts, or `nil` when a part has no rule.
  func all(_ parts: [TranscriptRowNode?]) -> [TranscriptRowNode]? {
    let nodes = parts.compactMap(\.self)
    return nodes.count == parts.count ? nodes : nil
  }

  /// A stack of parts with a spacing between them.
  ///
  /// - Parameters:
  ///   - parts: The parts, or `nil` for a part that no rule covers.
  ///   - spacing: The spacing.
  /// - Returns: The stack, or `nil` when a part has no rule.
  func stack(_ parts: [TranscriptRowNode?], spacing: CGFloat) -> TranscriptRowNode? {
    all(parts).map { .stack($0, spacing: spacing) }
  }

  /// A line of views that a horizontal stack centers.
  ///
  /// - Parameter parts: The views.
  /// - Returns: The line, or `nil` when a view has no rule.
  func line(_ parts: TranscriptRowNode?...) -> TranscriptRowNode? {
    all(parts).map(TranscriptRowNode.line)
  }

  /// A line of chrome views of fixed heights, which the flat form draws as
  /// one chrome line.
  ///
  /// - Parameters:
  ///   - heights: The heights of the views, or `nil` for a view that the
  ///     probe did not lay out.
  ///   - line: The chrome line of the views, or `nil` for a line that the
  ///     flat form does not draw.
  /// - Returns: The chrome view of the height of the tallest view, or `nil`
  ///   when a view has no height.
  func chrome(_ heights: CGFloat?..., line: TranscriptChromeLine?) -> TranscriptRowNode? {
    let known = heights.compactMap(\.self)
    guard known.count == heights.count else { return nil }
    return .chrome(height: known.max() ?? .zero, line: line)
  }

  /// A text part.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - style: The kind of view that shows the text.
  /// - Returns: The text part.
  func text(_ text: String, _ style: TranscriptTextPart.Style) -> TranscriptRowNode {
    .text(TranscriptTextPart(text: text, style: style))
  }

  /// A `ResponseView`: one rendered Markdown view, or a stack of prose and
  /// code blocks when the text has a code fence.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The response.
  func response(_ markdown: String) -> TranscriptRowNode? {
    let pieces = MarkdownCodeFences.segments(in: markdown)
    guard pieces.contains(where: \.isCode) else { return text(markdown, .markdown) }
    let nodes = pieces.map { segment -> TranscriptRowNode? in
      switch segment {
      case .prose(let prose): text(prose, .markdown)
      case .code(let code, let language, let filename):
        codeBlock(code, language: language, title: CodeBlockView.title(language: language, filename: filename))
      }
    }
    return stack(nodes, spacing: metrics.stackSpacing)
  }

  /// A `CodeBlockView`: a tile with a block header and the code, in the
  /// frame of a code block.
  ///
  /// - Parameters:
  ///   - code: The code.
  ///   - language: The language of the code, or `nil`.
  ///   - title: The title of the header, or `nil` for a header that the
  ///     flat form does not draw.
  /// - Returns: The code block.
  func codeBlock(_ code: String, language: String?, title: String?) -> TranscriptRowNode? {
    let header = chrome(
      metrics.height(.blockHeaderTitle), metrics.height(.copyButton), line: title.map(TranscriptChromeLine.codeBlockHeader))
    // The part names the language as the view of the block keeps it, so
    // the slot of the view finds the picture of the part.
    let style = TranscriptTextPart.Style.code(language: CodeBlockView.normalized(language))
    return tile(header, text(code, style)).map(TranscriptRowNode.band)
  }

  /// A `StatusTitleLayout`: the symbol and the headline title on one line,
  /// and the explanation label below the title.
  ///
  /// - Parameters:
  ///   - symbol: The name of the symbol.
  ///   - explanation: The explanation text.
  /// - Returns: The status title.
  func statusTitle(symbol: String, explanation: String) -> TranscriptRowNode? {
    guard let row = chrome(metrics.height(.symbol(symbol)), metrics.height(.headline), line: nil) else { return nil }
    guard !explanation.isEmpty else { return row }
    let label = TranscriptRowNode.narrowed(
      text(explanation, .label(.ui(.callout))), by: metrics.symbolColumnWidth + metrics.spacingM)
    return .stack([row, label], spacing: metrics.spacingXS)
  }

  // MARK: - Row kinds

  /// The rule of a user or an agent message (`TranscriptMessageView`).
  ///
  /// The role header and the blocks stand in a stack with the small
  /// spacing. The send state caption of a user message stands below with the
  /// extra-small spacing, and the extra-small inset pads the whole message.
  ///
  /// - Parameters:
  ///   - role: The sender of the message.
  ///   - blocks: The text blocks.
  ///   - sendState: The send state of a user message, or `nil`.
  /// - Returns: The message.
  func message(role: MessageRole, blocks: [String], sendState: SendState?) -> TranscriptRowNode? {
    let header = chrome(metrics.height(.messageHeader), line: .messageHeader(role))
    guard let layout = stack([header] + blocks.map(response), spacing: metrics.spacingS) else { return nil }
    guard let sendState else { return .inset(layout, padding: metrics.spacingXS) }
    let caption = chrome(metrics.height(.sendState(sendState)), line: .sendState(sendState))
    return stack([layout, caption], spacing: metrics.spacingXS).map { .inset($0, padding: metrics.spacingXS) }
  }

  /// The rule of a collapsed thought (`ReasoningBlock`): a tile with the
  /// title and the disclosure toggle on one line.
  ///
  /// - Parameter title: The title of the header.
  /// - Returns: The thought.
  func collapsedThought(title: String) -> TranscriptRowNode? {
    tile(chrome(metrics.height(.rowText), metrics.height(.disclosureButton), line: .thoughtHeader(title: title)))
  }

  /// The rule of a tool call card (`ToolCallView`): a tile with the header
  /// line, and the body parts when the card is expanded.
  ///
  /// - Parameter call: The data of the card.
  /// - Returns: The card.
  func toolCall(_ call: TranscriptRowContent.ToolCall) -> TranscriptRowNode? {
    let header = chrome(
      metrics.height(.buttonText), metrics.height(.buttonSymbol(call.kindSymbol)),
      metrics.height(.buttonSymbol(call.statusSymbol)), metrics.height(.buttonSymbol(metrics.disclosureSymbol)),
      line: .toolCallHeader(call.header))
    guard let body = call.body else { return tile(header) }
    return tile(header, stack(body.map(bodyPart), spacing: metrics.tileGap))
  }

  /// One part of the body of a tool call (`ToolCallBody`).
  ///
  /// - Parameter part: The part.
  /// - Returns: The part.
  func bodyPart(_ part: TranscriptRowContent.BodyPart) -> TranscriptRowNode? {
    switch part {
    case .json(let json): codeBlock(json, language: TranscriptRowChrome.jsonLanguage, title: nil)
    case .text(let markdown): response(markdown)
    case .diff(let patch): diff(patch)
    case .commandOutput(let output, let exitSymbol): commandOutput(output, exitSymbol: exitSymbol)
    }
  }

  /// The rule of a diff in a tool call (`DiffView`): the file chip, then the
  /// diff, with the tile gap and no padding.
  ///
  /// - Parameter patch: The git patch text.
  /// - Returns: The diff.
  func diff(_ patch: String) -> TranscriptRowNode? {
    stack([chrome(metrics.height(.pathChip), line: nil), text(patch, .diff)], spacing: metrics.tileGap)
  }

  /// The rule of a command output (`CommandOutputView`): a tile with the
  /// command line, the output and the exit label.
  ///
  /// - Parameters:
  ///   - output: The shown output.
  ///   - exitSymbol: The symbol of the exit label, or `nil` with no exit code.
  /// - Returns: The output.
  func commandOutput(_ output: String, exitSymbol: String?) -> TranscriptRowNode? {
    let header = chrome(metrics.height(.codeText), metrics.height(.copyButton), line: nil)
    let body = text(output, .output)
    guard let exitSymbol else { return tile(header, body) }
    return tile(header, body, chrome(metrics.height(.exitLabel(exitSymbol)), line: nil))
  }

  /// The rule of a terminal (`TerminalView`): a tile with the command line,
  /// the output and the exit label.
  ///
  /// - Parameter terminal: The data of the terminal.
  /// - Returns: The terminal.
  func terminal(_ terminal: TranscriptRowContent.Terminal) -> TranscriptRowNode? {
    let gaps = metrics.spacingS * CGFloat(TranscriptRowRule.terminalHeaderGapCount)
    let labelInset = metrics.symbolColumnWidth + gaps
    let command = TranscriptRowNode.narrowed(text(terminal.command, .label(.code)), by: labelInset)
    let folder = terminal.folder.map { TranscriptRowNode.narrowed(text($0, .label(.ui(.caption))), by: labelInset) }
    let header = line(
      chrome(metrics.height(.symbol(metrics.terminalSymbol)), line: nil), command,
      folder ?? .chrome(height: .zero, line: nil))
    return tile(
      header, text(terminal.output, .output), chrome(metrics.height(.exitLabel(terminal.exitSymbol)), line: nil))
  }

  /// The number of small gaps that the rule takes from the width of the
  /// labels of a terminal header: the stack space after the symbol column,
  /// and the least width of the spacer after the command.
  static let terminalHeaderGapCount = 2

  /// The rule of a plan (`TaskListView`): the headline, then the rows with
  /// the large spacing, with the medium spacing between the two.
  ///
  /// - Parameter rows: The rows of the plan.
  /// - Returns: The plan.
  func plan(_ rows: [TranscriptRowContent.PlanRow]) -> TranscriptRowNode? {
    let steps = stack(rows.map(planRow), spacing: metrics.spacingL)
    return stack([chrome(metrics.height(.headline), line: nil), steps], spacing: metrics.spacingM)
  }

  /// The rule of one row of a plan (`PlanEntryRow`): the status symbol, the
  /// label and the priority symbol on one line.
  ///
  /// - Parameter row: The data of the row.
  /// - Returns: The row.
  func planRow(_ row: TranscriptRowContent.PlanRow) -> TranscriptRowNode? {
    guard let priorityWidth = metrics.width(.symbol(row.prioritySymbol)) else { return nil }
    let gaps = metrics.spacingS * CGFloat(TranscriptRowRule.planRowGapCount)
    let label = TranscriptRowNode.narrowed(
      text(row.text, .label(.inherited)), by: metrics.symbolColumnWidth + priorityWidth + gaps)
    return line(
      chrome(metrics.height(.symbol(row.statusSymbol)), line: nil), label,
      chrome(metrics.height(.symbol(row.prioritySymbol)), line: nil))
  }

  /// The number of small gaps of a plan row: the three stack spaces and the
  /// least width of its spacer.
  static let planRowGapCount = 4

  /// The rule of a compaction notice (`CompactionEntryView`): a tile with the
  /// status title, the error label and the summary blocks.
  ///
  /// - Parameter compaction: The data of the notice.
  /// - Returns: The notice.
  func compaction(_ compaction: TranscriptRowContent.Compaction) -> TranscriptRowNode? {
    let title = statusTitle(symbol: compaction.symbol, explanation: compaction.summary)
    let error = compaction.error.map { text($0, .label(.ui(.callout))) }
    return tile([title] + [error].compactMap(\.self) + compaction.blocks.map(response))
  }

  /// The rule of an error notice (`ErrorView`): a tile with the status
  /// title.
  ///
  /// - Parameter detail: The explanation text.
  /// - Returns: The notice.
  func error(detail: String) -> TranscriptRowNode? {
    tile(statusTitle(symbol: metrics.errorSymbol, explanation: detail))
  }

  /// The rule of a message from another session (`SessionMessageView`): the
  /// participants label, then the blocks.
  ///
  /// - Parameters:
  ///   - participants: The participants text.
  ///   - blocks: The text blocks.
  /// - Returns: The message.
  func sessionMessage(participants: String, blocks: [String]) -> TranscriptRowNode? {
    stack([text(participants, .label(.systemCaption))] + blocks.map(response), spacing: SessionMessageView.spacing)
  }
}
