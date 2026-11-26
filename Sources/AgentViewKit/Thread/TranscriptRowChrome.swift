import CoreGraphics
import FoundationModelsACPClient

/// The chrome rule of each row kind: the padding, the header heights and the
/// block frames that AgentViewKit adds around the text parts of a row.
///
/// Each rule is a pure function of the row content, the theme metrics and
/// the text measure. A rule follows the layout of the views of its row kind,
/// so a change to that layout changes the rule too. The tests of the rules
/// mount each row kind and compare its height with the rule.
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
      TranscriptRowRule(metrics: metrics, measure: measure).height(of: content.kind, width: width)
    }
  }
}

/// The chrome rules with their metrics and their measure.
nonisolated private struct TranscriptRowRule {
  /// The theme metrics.
  let metrics: TranscriptRowMetrics

  /// The text measure.
  let measure: TranscriptRowChrome.Measure

  /// The height of a row of one kind.
  ///
  /// - Parameters:
  ///   - kind: The data of the row kind.
  ///   - width: The width of the row.
  /// - Returns: The height, or `nil` when no rule covers the row.
  func height(of kind: TranscriptRowContent.Kind, width: CGFloat) -> CGFloat? {
    switch kind {
    case .message(let blocks, let sendState): message(blocks: blocks, sendState: sendState, width: width)
    case .collapsedThought: collapsedThought()
    case .toolCall(let call): toolCall(call, width: width)
    case .terminal(let terminal): self.terminal(terminal, width: width)
    case .plan(let rows): plan(rows, width: width)
    case .error(let detail): error(detail: detail, width: width)
    case .compaction(let compaction): self.compaction(compaction, width: width)
    case .sessionMessage(let participants, let blocks):
      sessionMessage(participants: participants, blocks: blocks, width: width)
    case .uncovered: nil
    }
  }

  // MARK: - Shared chrome

  /// The height of a content tile around a stack of parts.
  ///
  /// `ContentTileStack` puts the tile gap between the parts, and
  /// `contentTile()` pads the stack on each side.
  ///
  /// - Parameter parts: The heights of the parts, or `nil` for a part that no
  ///   rule covers.
  /// - Returns: The height.
  func tile(_ parts: CGFloat?...) -> CGFloat? {
    tile(parts)
  }

  /// The height of a content tile around a list of parts.
  ///
  /// - Parameter parts: The heights of the parts, or `nil` for a part that no
  ///   rule covers.
  /// - Returns: The height.
  func tile(_ parts: [CGFloat?]) -> CGFloat? {
    stack(parts, spacing: metrics.tileGap).map { $0 + 2 * metrics.tilePadding }
  }

  /// The height of a stack of parts with a spacing between them.
  ///
  /// - Parameters:
  ///   - parts: The heights of the parts.
  ///   - spacing: The spacing.
  /// - Returns: The height, or `nil` when a part has no height.
  func stack(_ parts: [CGFloat?], spacing: CGFloat) -> CGFloat? {
    var total: CGFloat = .zero
    for part in parts {
      guard let part else { return nil }
      total += part
    }
    return total + spacing * CGFloat(max(parts.count - 1, .zero))
  }

  /// The height of a row of views that a horizontal stack centers.
  ///
  /// - Parameter parts: The heights of the views.
  /// - Returns: The largest height, or `nil` when a view has no height.
  func line(_ parts: CGFloat?...) -> CGFloat? {
    var tallest: CGFloat = .zero
    for part in parts {
      guard let part else { return nil }
      tallest = max(tallest, part)
    }
    return tallest
  }

  /// The height of a text part.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - style: The kind of view that shows the text.
  ///   - width: The width of the view.
  /// - Returns: The height.
  func text(_ text: String, _ style: TranscriptTextPart.Style, width: CGFloat) -> CGFloat {
    measure(TranscriptTextPart(text: text, style: style), width)
  }

  /// The height of a `ResponseView`: one rendered Markdown view, or a
  /// stack of prose and code blocks when the text has a code fence.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text.
  ///   - width: The width of the view.
  /// - Returns: The height.
  func response(_ markdown: String, width: CGFloat) -> CGFloat? {
    let pieces = MarkdownCodeFences.segments(in: markdown)
    guard pieces.contains(where: \.isCode) else { return text(markdown, .markdown, width: width) }
    let heights = pieces.map { segment -> CGFloat? in
      switch segment {
      case .prose(let prose): text(prose, .markdown, width: width)
      case .code(let code, let language, _): codeBlock(code, language: language, width: width)
      }
    }
    return stack(heights, spacing: metrics.stackSpacing)
  }

  /// The height of a `CodeBlockView`: a tile with a block header and the
  /// code.
  ///
  /// - Parameters:
  ///   - code: The code.
  ///   - language: The language of the code, or `nil`.
  ///   - width: The width of the view.
  /// - Returns: The height.
  func codeBlock(_ code: String, language: String?, width: CGFloat) -> CGFloat? {
    let header = line(metrics.height(.blockHeaderTitle), metrics.height(.copyButton))
    return tile(header, text(code, .code(language: language), width: width - 2 * metrics.tilePadding))
  }

  /// The height of a `StatusTitleLayout`: the symbol and the headline title
  /// on one line, and the explanation label below the title.
  ///
  /// - Parameters:
  ///   - symbol: The name of the symbol.
  ///   - explanation: The explanation text.
  ///   - width: The width of the layout.
  /// - Returns: The height.
  func statusTitle(symbol: String, explanation: String, width: CGFloat) -> CGFloat? {
    guard let row = line(metrics.height(.symbol(symbol)), metrics.height(.headline)) else { return nil }
    guard !explanation.isEmpty else { return row }
    let textWidth = width - metrics.symbolColumnWidth - metrics.spacingM
    return row + metrics.spacingXS + text(explanation, .label(.ui(.callout)), width: textWidth)
  }

  // MARK: - Row kinds

  /// The rule of a user or an agent message (`TranscriptMessageView`).
  ///
  /// The role header and the blocks stand in a stack with the small
  /// spacing. The send state caption of a user message stands below with the
  /// extra-small spacing, and the extra-small inset pads the whole message.
  ///
  /// - Parameters:
  ///   - blocks: The text blocks.
  ///   - sendState: The send state of a user message, or `nil`.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func message(blocks: [String], sendState: SendState?, width: CGFloat) -> CGFloat? {
    let inner = width - 2 * metrics.spacingXS
    let parts = [metrics.height(.messageHeader)] + blocks.map { response($0, width: inner) }
    guard var height = stack(parts, spacing: metrics.spacingS) else { return nil }
    if let sendState {
      guard let caption = metrics.height(.sendState(sendState)) else { return nil }
      height += metrics.spacingXS + caption
    }
    return height + 2 * metrics.spacingXS
  }

  /// The rule of a collapsed thought (`ReasoningBlock`): a tile with the
  /// title and the disclosure toggle on one line.
  ///
  /// - Returns: The height.
  func collapsedThought() -> CGFloat? {
    tile(line(metrics.height(.rowText), metrics.height(.disclosureButton)))
  }

  /// The rule of a tool call card (`ToolCallView`): a tile with the header
  /// line, and the body parts when the card is expanded.
  ///
  /// - Parameters:
  ///   - call: The data of the card.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func toolCall(_ call: TranscriptRowContent.ToolCall, width: CGFloat) -> CGFloat? {
    let header = line(
      metrics.height(.buttonText), metrics.height(.buttonSymbol(call.kindSymbol)),
      metrics.height(.buttonSymbol(call.statusSymbol)),
      metrics.height(.buttonSymbol(metrics.disclosureSymbol)))
    guard let body = call.body else { return tile(header) }
    let inner = width - 2 * metrics.tilePadding
    return tile(header, stack(body.map { bodyPart($0, width: inner) }, spacing: metrics.tileGap))
  }

  /// The height of one part of the body of a tool call (`ToolCallBody`).
  ///
  /// - Parameters:
  ///   - part: The part.
  ///   - width: The width of the body.
  /// - Returns: The height.
  func bodyPart(_ part: TranscriptRowContent.BodyPart, width: CGFloat) -> CGFloat? {
    switch part {
    case .json(let json): codeBlock(json, language: TranscriptRowChrome.jsonLanguage, width: width)
    case .text(let markdown): response(markdown, width: width)
    case .diff(let patch): diff(patch, width: width)
    case .commandOutput(let output, let exitSymbol): commandOutput(output, exitSymbol: exitSymbol, width: width)
    }
  }

  /// The rule of a diff in a tool call (`DiffView`): the file chip, then the
  /// diff, with the tile gap and no padding.
  ///
  /// - Parameters:
  ///   - patch: The git patch text.
  ///   - width: The width of the view.
  /// - Returns: The height.
  func diff(_ patch: String, width: CGFloat) -> CGFloat? {
    stack([metrics.height(.pathChip), text(patch, .diff, width: width)], spacing: metrics.tileGap)
  }

  /// The rule of a command output (`CommandOutputView`): a tile with the
  /// command line, the output and the exit label.
  ///
  /// - Parameters:
  ///   - output: The shown output.
  ///   - exitSymbol: The symbol of the exit label, or `nil` with no exit code.
  ///   - width: The width of the view.
  /// - Returns: The height.
  func commandOutput(_ output: String, exitSymbol: String?, width: CGFloat) -> CGFloat? {
    let header = line(metrics.height(.codeText), metrics.height(.copyButton))
    let body = text(output, .output, width: width - 2 * metrics.tilePadding)
    guard let exitSymbol else { return tile(header, body) }
    return tile(header, body, metrics.height(.exitLabel(exitSymbol)))
  }

  /// The rule of a terminal (`TerminalView`): a tile with the command line,
  /// the output and the exit label.
  ///
  /// - Parameters:
  ///   - terminal: The data of the terminal.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func terminal(_ terminal: TranscriptRowContent.Terminal, width: CGFloat) -> CGFloat? {
    let inner = width - 2 * metrics.tilePadding
    let labelWidth = inner - metrics.symbolColumnWidth - 2 * metrics.spacingS
    let command = text(terminal.command, .label(.code), width: labelWidth)
    let folder = terminal.folder.map { text($0, .label(.ui(.caption)), width: labelWidth) } ?? .zero
    let header = line(metrics.height(.symbol(metrics.terminalSymbol)), command, folder)
    return tile(header, text(terminal.output, .output, width: inner), metrics.height(.exitLabel(terminal.exitSymbol)))
  }

  /// The rule of a plan (`TaskListView`): the headline, then the rows with
  /// the large spacing, with the medium spacing between the two.
  ///
  /// - Parameters:
  ///   - rows: The rows of the plan.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func plan(_ rows: [TranscriptRowContent.PlanRow], width: CGFloat) -> CGFloat? {
    let steps = stack(rows.map { planRow($0, width: width) }, spacing: metrics.spacingL)
    return stack([metrics.height(.headline), steps], spacing: metrics.spacingM)
  }

  /// The rule of one row of a plan (`PlanEntryRow`): the status symbol, the
  /// label and the priority symbol on one line.
  ///
  /// - Parameters:
  ///   - row: The data of the row.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func planRow(_ row: TranscriptRowContent.PlanRow, width: CGFloat) -> CGFloat? {
    guard let priorityWidth = metrics.width(.symbol(row.prioritySymbol)) else { return nil }
    let gaps = metrics.spacingS * CGFloat(TranscriptRowRule.planRowGapCount)
    let labelWidth = width - metrics.symbolColumnWidth - priorityWidth - gaps
    return line(
      metrics.height(.symbol(row.statusSymbol)), text(row.text, .label(.inherited), width: labelWidth),
      metrics.height(.symbol(row.prioritySymbol)))
  }

  /// The number of small gaps of a plan row: the three stack spaces and the
  /// least width of its spacer.
  static let planRowGapCount = 4

  /// The rule of a compaction notice (`CompactionEntryView`): a tile with the
  /// status title, the error label and the summary blocks.
  ///
  /// - Parameters:
  ///   - compaction: The data of the notice.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func compaction(_ compaction: TranscriptRowContent.Compaction, width: CGFloat) -> CGFloat? {
    let inner = width - 2 * metrics.tilePadding
    var parts = [statusTitle(symbol: compaction.symbol, explanation: compaction.summary, width: inner)]
    if let error = compaction.error {
      parts.append(text(error, .label(.ui(.callout)), width: inner))
    }
    parts += compaction.blocks.map { response($0, width: inner) }
    return tile(parts)
  }

  /// The rule of an error notice (`ErrorView`): a tile with the status
  /// title.
  ///
  /// - Parameters:
  ///   - detail: The explanation text.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func error(detail: String, width: CGFloat) -> CGFloat? {
    tile(statusTitle(symbol: metrics.errorSymbol, explanation: detail, width: width - 2 * metrics.tilePadding))
  }

  /// The rule of a message from another session (`SessionMessageView`): the
  /// participants label, then the blocks.
  ///
  /// - Parameters:
  ///   - participants: The participants text.
  ///   - blocks: The text blocks.
  ///   - width: The width of the row.
  /// - Returns: The height.
  func sessionMessage(participants: String, blocks: [String], width: CGFloat) -> CGFloat? {
    let label = text(participants, .label(.systemCaption), width: width)
    return stack([label] + blocks.map { response($0, width: width) }, spacing: SessionMessageView.spacing)
  }
}
