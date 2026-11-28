import EditorStyle
import EditorSwiftUI
import FoundationModelsACPClient
import SwiftUI
import os

/// The flat form of a static row of a thread: the pictures of the row in one
/// layout, in a frame of the exact height of the row (card ^9ync5h3).
///
/// While the rows move, or while a row waits in the
/// ``TranscriptRowMountQueue``, a row with an exact height, a picture of each
/// text part and a picture of each chrome line shows this one view in place
/// of the views of its real row. The view holds no button, no label, no
/// command scope and no accessibility view of the row: each part is an
/// image at the place that the chrome rule of the row gives it
/// (``TranscriptFlatRowPlan``). The text parts are the pictures that
/// EditorKit drew off the main thread, and the chrome lines are pictures of
/// the real views of the lines (``TranscriptChromePictures``).
///
/// The view is one accessibility element, with the text of each part of the
/// row as its label. A press of the mouse on a row that waits at rest, and
/// a press or the focus of an assistive app, make the row real at once
/// (``TranscriptStillInteraction``), as on the still view of a text slot.
struct TranscriptFlatRow: View {
  /// The start of the ``BodyEvaluationCounter`` key of each flat row.
  static let counterKeyPrefix = "flat-row-"

  /// The row key of the entry of the row.
  let rowKey: String

  /// The parts of the row and their places.
  let plan: TranscriptFlatRowPlan

  /// The pictures of the chrome lines of the thread.
  let chrome: TranscriptChromePictures

  /// The message entry of a message row, whose look the line of its
  /// message actions draws, or `nil` for another row.
  let message: MessageEntry?

  /// The ``BodyEvaluationCounter`` key of the flat row of a row key.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: `flat-row-<rowKey>`.
  static func counterKey(for rowKey: String) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, id: rowKey)
  }

  var body: some View {
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(for: rowKey))
    #endif
    let leaves = plan.leaves
    return TranscriptFlatRowLayout(rowKey: rowKey, frames: leaves.map(\.frame), size: plan.size) {
      ForEach(leaves.indices, id: \.self) { index in
        TranscriptFlatLeafView(leaf: leaves[index], chrome: chrome, message: message)
      }
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: plan.spokenText))
    .modifier(TranscriptStillInteraction())
  }
}

/// One part of a flat row at its place: a picture of a text part, a picture
/// of a chrome line, or the frame of a code block (card ^9ync5h3).
struct TranscriptFlatLeaf {
  /// What a part of a flat row draws.
  enum Kind {
    /// The picture of a text part, and the text of the part.
    case picture(EditorStaticRendering, text: String)

    /// The picture of a chrome line.
    case chrome(TranscriptChromeLine)

    /// The frame of a code block (`editorBlockFrame()`).
    case band
  }

  /// What the part draws.
  let kind: Kind

  /// The place of the part in the row.
  let frame: CGRect
}

/// The parts of a flat row and their places, from the layout tree of the
/// chrome rule of the row (``TranscriptRowNode``, card ^9ync5h3).
///
/// The plan places each node where the views of the real row place it: a
/// stack puts its spacing between its views, an inset pads its view on each
/// edge, and the frame of a code block takes the size of its view. A text
/// part takes the size of its picture, which has the measured height of the
/// part, and a chrome line takes the whole width of its place and the
/// height of the rule. The frame of a code block comes after its views, as
/// the edge of the real block lies over the block.
struct TranscriptFlatRowPlan {
  /// The parts, in the order that the row draws them.
  let leaves: [TranscriptFlatLeaf]

  /// The size of the row: the width of the row and its exact height.
  let size: CGSize

  /// The largest difference between the height of the plan and the exact
  /// height of the row, in points.
  static let heightTolerance: CGFloat = 0.5

  /// The plan of a row, or `nil` when the flat form cannot draw the row.
  ///
  /// The flat form draws a row only when each text part of the tree has a
  /// picture, each chrome view of the tree is a chrome line that the form
  /// draws (``TranscriptChromeLine/isStill``), and the tree has no line of
  /// views side by side and no narrowed view. The height of the plan must
  /// be the exact height of the row, so the row does not move when it
  /// becomes real.
  ///
  /// - Parameters:
  ///   - node: The layout tree of the row.
  ///   - width: The width of the row.
  ///   - height: The exact height of the row.
  ///   - picture: The picture of a text part of the row, or `nil` when the
  ///     cache has none.
  /// - Returns: The plan.
  static func make(
    node: TranscriptRowNode, width: CGFloat, height: CGFloat,
    picture: (TranscriptTextPart) -> EditorStaticRendering?
  ) -> TranscriptFlatRowPlan? {
    withoutActuallyEscaping(picture) { picture in
      var placer = TranscriptFlatPlacer(picture: picture)
      guard let placed = placer.place(node, at: .zero, width: width),
        abs(placed - height) <= heightTolerance
      else { return nil }
      return TranscriptFlatRowPlan(leaves: placer.leaves, size: CGSize(width: width, height: height))
    }
  }
}

/// Places the nodes of a layout tree for a ``TranscriptFlatRowPlan``.
private struct TranscriptFlatPlacer {
  /// The picture of a text part, or `nil` when the cache has none.
  let picture: (TranscriptTextPart) -> EditorStaticRendering?

  /// The parts that the placer placed, in draw order.
  private(set) var leaves: [TranscriptFlatLeaf] = []

  /// Makes a placer.
  ///
  /// - Parameter picture: The picture of a text part.
  init(picture: @escaping (TranscriptTextPart) -> EditorStaticRendering?) {
    self.picture = picture
  }

  /// Places a node and the nodes in it.
  ///
  /// - Parameters:
  ///   - node: The node.
  ///   - origin: The top leading corner of the place of the node.
  ///   - width: The width of the place of the node.
  /// - Returns: The height of the node, or `nil` when the flat form cannot
  ///   draw it.
  mutating func place(_ node: TranscriptRowNode, at origin: CGPoint, width: CGFloat) -> CGFloat? {
    switch node {
    case .text(let part): placeText(part, at: origin)
    case .chrome(let height, let line): placeChrome(line, at: origin, size: CGSize(width: width, height: height))
    case .stack(let nodes, let spacing): placeStack(nodes, spacing: spacing, at: origin, width: width)
    case .inset(let node, let padding): placeInset(node, padding: padding, at: origin, width: width)
    case .band(let node): placeBand(node, at: origin, width: width)
    case .line, .narrowed: nil
    }
  }

  /// Places the picture of a text part.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - origin: The top leading corner of its place.
  /// - Returns: The height of the picture, or `nil` with no picture.
  private mutating func placeText(_ part: TranscriptTextPart, at origin: CGPoint) -> CGFloat? {
    guard let rendering = picture(part), rendering.image != nil else { return nil }
    leaves.append(
      TranscriptFlatLeaf(kind: .picture(rendering, text: part.text), frame: CGRect(origin: origin, size: rendering.size)))
    return rendering.size.height
  }

  /// Places a chrome line.
  ///
  /// - Parameters:
  ///   - line: The chrome line, or `nil` for a view that the flat form does
  ///     not draw.
  ///   - origin: The top leading corner of its place.
  ///   - size: The size of its place.
  /// - Returns: The height of the line, or `nil` when the flat form does
  ///   not draw it.
  private mutating func placeChrome(_ line: TranscriptChromeLine?, at origin: CGPoint, size: CGSize) -> CGFloat? {
    guard let line, line.isStill else { return nil }
    leaves.append(TranscriptFlatLeaf(kind: .chrome(line), frame: CGRect(origin: origin, size: size)))
    return size.height
  }

  /// Places the views of a stack, one below the other.
  ///
  /// - Parameters:
  ///   - nodes: The views.
  ///   - spacing: The spacing between two views.
  ///   - origin: The top leading corner of the stack.
  ///   - width: The width of the stack.
  /// - Returns: The height of the stack.
  private mutating func placeStack(
    _ nodes: [TranscriptRowNode], spacing: CGFloat, at origin: CGPoint, width: CGFloat
  ) -> CGFloat? {
    var y = origin.y
    for (index, node) in nodes.enumerated() {
      y += index == .zero ? .zero : spacing
      guard let height = place(node, at: CGPoint(x: origin.x, y: y), width: width) else { return nil }
      y += height
    }
    return y - origin.y
  }

  /// Places a view with a padding on each edge.
  ///
  /// - Parameters:
  ///   - node: The view.
  ///   - padding: The padding of one edge.
  ///   - origin: The top leading corner of the padded view.
  ///   - width: The width of the padded view.
  /// - Returns: The height of the padded view.
  private mutating func placeInset(
    _ node: TranscriptRowNode, padding: CGFloat, at origin: CGPoint, width: CGFloat
  ) -> CGFloat? {
    let both = padding * TranscriptRowNode.paddedEdgesPerAxis
    let inner = CGPoint(x: origin.x + padding, y: origin.y + padding)
    return place(node, at: inner, width: width - both).map { $0 + both }
  }

  /// Places a view, and the frame of a code block over it.
  ///
  /// - Parameters:
  ///   - node: The view.
  ///   - origin: The top leading corner of the block.
  ///   - width: The width of the block.
  /// - Returns: The height of the block.
  private mutating func placeBand(_ node: TranscriptRowNode, at origin: CGPoint, width: CGFloat) -> CGFloat? {
    guard let height = place(node, at: origin, width: width) else { return nil }
    leaves.append(TranscriptFlatLeaf(kind: .band, frame: CGRect(x: origin.x, y: origin.y, width: width, height: height)))
    return height
  }
}

extension TranscriptFlatRowPlan {
  /// The text of the row for an assistive app: the text of each part, in
  /// order, one part on each line.
  var spokenText: String {
    leaves.compactMap { leaf -> String? in
      switch leaf.kind {
      case .picture(_, let text): text
      case .chrome(let line): line.spokenText
      case .band: nil
      }
    }.filter { !$0.isEmpty }.joined(separator: "\n")
  }
}

/// The layout of a flat row: each part at its place, in a frame of the size
/// of the row (card ^9ync5h3).
///
/// The layout asks no part for its size: it gives the row its size, and it
/// places each part with the size of its place.
struct TranscriptFlatRowLayout: Layout {
  /// The start of the ``BodyEvaluationCounter`` key of the layouts of each
  /// flat row.
  static let counterKeyPrefix = "flat-row-layout-"

  /// The row key of the entry of the row.
  let rowKey: String

  /// The place of each part, in the order of the parts.
  let frames: [CGRect]

  /// The size of the row.
  let size: CGSize

  /// The ``BodyEvaluationCounter`` key of the size computations and the
  /// placements of the flat row of a row key.
  ///
  /// - Parameter rowKey: The row key of the entry.
  /// - Returns: `flat-row-layout-<rowKey>`.
  @MainActor static func counterKey(for rowKey: String) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, id: rowKey)
  }

  /// The size of the row, at the proposed width.
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    noteLayout()
    return CGSize(width: proposal.width ?? size.width, height: size.height)
  }

  /// Places each part at its place, with the size of its place.
  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    noteLayout()
    for (subview, frame) in zip(subviews, frames) {
      let origin = CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY)
      subview.place(at: origin, anchor: .topLeading, proposal: ProposedViewSize(frame.size))
    }
  }

  /// No horizontal guide of its own: the guides of a part would ask the
  /// part for its size.
  func explicitAlignment(
    of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }

  /// No vertical guide of its own, for the reason of the horizontal guide.
  func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }

  /// Notes one size computation or placement of the row.
  private func noteLayout() {
    #if DEBUG
      MainActor.assumeIsolated { BodyEvaluationCounter.note(Self.counterKey(for: rowKey)) }
    #endif
  }
}

/// The view of one part of a flat row (card ^9ync5h3).
struct TranscriptFlatLeafView: View {
  /// The part.
  let leaf: TranscriptFlatLeaf

  /// The pictures of the chrome lines of the thread.
  let chrome: TranscriptChromePictures

  /// The message entry of a message row, or `nil` for another row.
  let message: MessageEntry?

  var body: some View {
    switch leaf.kind {
    case .picture(let rendering, let text): StaticPictureView(rendering, text: text)
    case .chrome(.messageActions(nil)):
      TranscriptMessageActionsLine(entry: message, size: leaf.frame.size, chrome: chrome)
    case .chrome(let line): TranscriptChromeLineView(line: line, size: leaf.frame.size, chrome: chrome)
    case .band: Color.clear.editorBlockFrame()
    }
  }
}

/// The picture of the row of the message actions of a flat message row,
/// with the look of the row (card ^grwk69d).
///
/// The chrome rule of a message does not know the buttons of the row and
/// their states: they come from the environment of the row, as the real
/// ``MessageActions`` row reads them (``MessageActions/Context``). This
/// view reads them, so only this view of the flat row observes the session
/// and the command scope, and it draws the line with that look
/// (``TranscriptChromeLine/messageActions(_:)``). Each later row with the
/// same look shows the kept picture.
struct TranscriptMessageActionsLine: View {
  /// The message entry of the row, or `nil` when the row is not a message.
  let entry: MessageEntry?

  /// The size of the place of the line.
  let size: CGSize

  /// The pictures of the chrome lines of the thread.
  let chrome: TranscriptChromePictures

  /// The log of a line of a row that is not a message.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "TranscriptMessageActionsLine")

  @Environment(\.sessionModel) private var session
  @Environment(\.agentCommandTarget) private var commandTarget
  @Environment(\.forkFromHere) private var forkFromHere
  @Environment(\.agentCommandGroupsOff) private var groupsOff

  var body: some View {
    if let entry {
      let context = MessageActions.Context(
        session: session, commandTarget: commandTarget, forkFromHere: forkFromHere, groupsOff: groupsOff)
      TranscriptChromeLineView(line: .messageActions(context.look(for: entry)), size: size, chrome: chrome)
    } else {
      Color.clear.frame(width: size.width, height: size.height).onAppear(perform: Self.noteNoMessage)
    }
  }

  /// Records a line of the message actions in a row that is not a message:
  /// the line stays clear.
  private static func noteNoMessage() {
    assertionFailure("a flat row that is not a message has a line of message actions")
    logger.error("a flat row that is not a message has a line of message actions; the line stays clear")
  }
}

/// The picture of one chrome line of a flat row, at the size of its place
/// (card ^9ync5h3).
///
/// The view reads the whole environment of the row, so the picture of the
/// real view of the line has the theme, the fonts and the colors of the
/// row. The picture is larger than the place by ``TranscriptChromePictures/bleed``
/// on each edge, so a part of the line that the real view draws past its
/// frame, such as the separator of a block header, is in the picture too.
struct TranscriptChromeLineView: View {
  /// The chrome line.
  let line: TranscriptChromeLine

  /// The size of the place of the line.
  let size: CGSize

  /// The pictures of the chrome lines of the thread.
  let chrome: TranscriptChromePictures

  @Environment(\.self) private var environment

  var body: some View {
    let image = chrome.image(of: line, size: size, environment: environment)
    Color.clear
      .frame(width: size.width, height: size.height)
      .overlay(alignment: .topLeading) {
        if let image {
          Image(image, scale: environment.displayScale, label: Text(verbatim: line.spokenText))
            .offset(x: -TranscriptChromePictures.bleed, y: -TranscriptChromePictures.bleed)
        }
      }
  }
}

/// The pictures of the chrome lines of the flat rows of a thread, by line,
/// size and appearance, with a bound on the bytes of their bitmaps (card
/// ^9ync5h3).
///
/// The first flat row that shows a line draws the real view of the line
/// (``TranscriptChromeLine/view``) with SwiftUI's `ImageRenderer`, in the
/// environment of the row. Each later row with the same line, size and
/// appearance shows the kept picture, so the lines that each row of a
/// kind has, such as the role header of a message, the header of a code
/// block of one language or the header of a closed thought, draw one time.
@MainActor final class TranscriptChromePictures {
  /// The key of a picture: the line, the size of its place and the
  /// appearance of the row.
  private struct Key: Hashable {
    /// The line.
    let line: TranscriptChromeLine

    /// The width of the place of the line.
    let width: CGFloat

    /// The height of the place of the line.
    let height: CGFloat

    /// The color scheme and the scale of the row.
    let appearance: TranscriptTextAppearance
  }

  /// The margin of a picture past each edge of the place of its line, in
  /// points.
  static let bleed: CGFloat = 8

  /// The default of the most mebibytes of the bitmaps of the pictures. A
  /// header line of 700 × 30 points at a scale of 2 takes about 0.4 MiB.
  static let defaultMebibytes = 16

  /// The start of the ``BodyEvaluationCounter`` key of each drawn picture.
  static let counterKeyPrefix = "chrome-picture-"

  /// The log of a line that the renderer did not draw.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "TranscriptChromePictures")

  /// The kept pictures, the newest last.
  private var pictures = TranscriptPictureCache<Key, CGImage>(
    byteLimit: defaultMebibytes * TranscriptRowHeightWorker.bytesPerMebibyte)

  /// Makes the pictures with no picture.
  init() {}

  /// The ``BodyEvaluationCounter`` key of each picture that the renderer
  /// draws of a line.
  ///
  /// - Parameter line: The line.
  /// - Returns: `chrome-picture-<line>`.
  static func counterKey(for line: TranscriptChromeLine) -> String {
    BodyEvaluationKey.make(prefix: counterKeyPrefix, id: String(describing: line))
  }

  /// The picture of a line at a size in an environment: the kept picture,
  /// or a new picture of the real view of the line.
  ///
  /// - Parameters:
  ///   - line: The line.
  ///   - size: The size of the place of the line.
  ///   - environment: The environment of the row.
  /// - Returns: The picture, or `nil` when the renderer draws nothing.
  func image(of line: TranscriptChromeLine, size: CGSize, environment: EnvironmentValues) -> CGImage? {
    let appearance = TranscriptTextAppearance(colorScheme: environment.colorScheme, scale: environment.displayScale)
    let key = Key(line: line, width: size.width, height: size.height, appearance: appearance)
    if let kept = pictures[key] {
      return kept
    }
    guard let image = render(line, size: size, environment: environment) else {
      assertionFailure("the renderer drew no picture of \(line)")
      Self.logger.error("the renderer drew no picture of a chrome line; the line stays clear")
      return nil
    }
    pictures.insert(image, forKey: key)
    return image
  }

  /// Drops each picture, such as for a new theme.
  func removeAll() {
    pictures.removeAll()
  }

  /// Draws the real view of a line at a size, with the bleed on each edge.
  ///
  /// - Parameters:
  ///   - line: The line.
  ///   - size: The size of the place of the line.
  ///   - environment: The environment of the row.
  /// - Returns: The picture, or `nil` when the renderer draws nothing.
  private func render(_ line: TranscriptChromeLine, size: CGSize, environment: EnvironmentValues) -> CGImage? {
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(for: line))
    #endif
    let renderer = ImageRenderer(
      content: line.view
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .padding(Self.bleed)
        .environment(\.self, environment))
    renderer.scale = environment.displayScale
    return renderer.cgImage
  }
}

extension TranscriptChromeLine {
  /// The real view of the line, with no action: the view that the real row
  /// shows in the place of the line.
  @MainActor @ViewBuilder var view: some View {
    switch self {
    case .messageHeader(let role): MessageHeader(role: role)
    case .sendState(let state): StatusCaption(status: EditorStatus(state), identifier: "")
    case .messageActions(let look): look.map(MessageActionsLookView.init(look:))
    case .codeBlockHeader(let title): CodeBlockHeader(title: title) {}
    case .thoughtHeader(let title):
      ReasoningHeader(id: "", title: title, isOn: .constant(false), isExpanded: false) {}
    case .toolCallHeader(let header): ToolCallToggle(header: header, title: Text(header.title)) {}
    }
  }

  /// Whether the real view of the line holds still, so a picture of it
  /// shows what the real view shows: each line but the header of a live
  /// tool call, whose status symbol moves.
  @MainActor var isStill: Bool {
    guard case .toolCallHeader(let header) = self else { return true }
    return !EditorStatus(header.status).isLive
  }

  /// The text of the line for an assistive app.
  @MainActor var spokenText: String {
    switch self {
    case .messageHeader(let role): role.title
    case .sendState(let state): EditorStatus(state).summary
    case .messageActions: ""
    case .codeBlockHeader(let title), .thoughtHeader(let title): title
    case .toolCallHeader(let header): ToolCallView.accessibilityLabel(title: header.title, status: header.status)
    }
  }
}
