import CoreGraphics
import FoundationModelsACP
import FoundationModelsACPClient

/// The layout of one row as the chrome rules give it: the text parts and the
/// chrome views of the row, and how the views of the row stack them (card
/// ^9ync5h3).
///
/// ``TranscriptRowChrome`` gives the tree of a row kind. The height of the
/// row is the height of the tree (``height(width:measure:)``), so the height
/// cache and the flat form of a static row (``TranscriptFlatRowPlan``) read
/// the same rule: the flat form places each part at the place of the tree,
/// and its height is the height of the cache.
nonisolated indirect enum TranscriptRowNode: Hashable, Sendable {
  /// A text part in the whole width of its place.
  case text(TranscriptTextPart)

  /// A chrome view of a fixed height, such as a header line. `line` names
  /// the chrome line that the flat form draws in its place, or is `nil` for
  /// a view that the flat form does not draw.
  case chrome(height: CGFloat, line: TranscriptChromeLine?)

  /// Views one below the other, with a spacing between them.
  case stack([TranscriptRowNode], spacing: CGFloat)

  /// Views side by side in one line: the height of the tallest view.
  case line([TranscriptRowNode])

  /// A view with a padding on each edge.
  case inset(TranscriptRowNode, padding: CGFloat)

  /// A view with less width than its place, such as a label after a
  /// symbol column.
  case narrowed(TranscriptRowNode, by: CGFloat)

  /// The frame of a code block around a view (`editorBlockFrame()`).
  case band(TranscriptRowNode)

  /// The number of edges that a padding pads on one axis: SwiftUI
  /// `padding(_:)` pads the leading and the trailing edge, or the top and the
  /// bottom edge.
  static let paddedEdgesPerAxis: CGFloat = 2

  /// The height of the tree at a width.
  ///
  /// The tree calls `measure` for each text part in the order of the parts
  /// from top to bottom.
  ///
  /// - Parameters:
  ///   - width: The width of the place of the tree.
  ///   - measure: The height of a text part at a width.
  /// - Returns: The height.
  func height(width: CGFloat, measure: TranscriptRowChrome.Measure) -> CGFloat {
    switch self {
    case .text(let part): measure(part, width)
    case .chrome(let height, _): height
    case .stack(let nodes, let spacing):
      nodes.map { $0.height(width: width, measure: measure) }.reduce(.zero, +)
        + spacing * CGFloat(max(nodes.count - 1, .zero))
    case .line(let nodes): nodes.map { $0.height(width: width, measure: measure) }.max() ?? .zero
    case .inset(let node, let padding):
      node.height(width: width - padding * Self.paddedEdgesPerAxis, measure: measure)
        + padding * Self.paddedEdgesPerAxis
    case .narrowed(let node, let amount): node.height(width: width - amount, measure: measure)
    case .band(let node): node.height(width: width, measure: measure)
    }
  }
}

/// One chrome line of a row that the flat form of a static row draws: a
/// picture of the real view of the line (``TranscriptChromeLineView``, card
/// ^9ync5h3).
///
/// Each case holds the data that the view of the line reads, so two lines
/// with the same value look the same.
nonisolated enum TranscriptChromeLine: Hashable, Sendable {
  /// The role header of a message (`MessageHeader`).
  case messageHeader(MessageRole)

  /// The send state caption of a user message.
  case sendState(SendState)

  /// The row of the message actions in the footer of a message
  /// (``MessageActions``, card ^grwk69d), with its look. The chrome rule
  /// does not know the look: the buttons and their states come from the
  /// environment of the row, so the tree holds `nil`, and the flat row
  /// draws the line with the look of its row
  /// (``TranscriptMessageActionsLine``).
  case messageActions(MessageActionsLook?)

  /// The header of a code block: its symbol, its title and its copy button
  /// (`CodeBlockHeader`).
  case codeBlockHeader(title: String)

  /// The header of a closed thought: its title and its disclosure button
  /// (`ReasoningHeader`).
  case thoughtHeader(title: String)

  /// The header of a tool call card (`ToolCallHeaderLabel`).
  case toolCallHeader(TranscriptToolCallHeader)
}

/// The data of the header of a tool call card that the flat form of its row
/// draws (card ^9ync5h3).
nonisolated struct TranscriptToolCallHeader: Hashable, Sendable {
  /// The shown title of the call.
  let title: String

  /// The shown kind of the call.
  let kind: ToolKind

  /// The shown status of the call.
  let status: ToolCallStatus

  /// Whether the card is expanded.
  let isExpanded: Bool
}
