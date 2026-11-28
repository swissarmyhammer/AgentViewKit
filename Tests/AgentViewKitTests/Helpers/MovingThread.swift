import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A ``ConversationView`` in a borderless window that is never ordered in,
/// with the steps of a scroll at rest and of a live scroll (card ^9ync5h3).
///
/// No window shows, and no window takes the focus. The host drives the
/// clip view of the list, and lays the list out synchronously after each
/// step. One pass of the main run loop follows each step at rest
/// (``PendingRunLoopBlocks``), so the list reports its rows in view.
@MainActor final class MovingThread {
  /// The distance of one scroll step at rest, in points: less than the
  /// height of the list, so each row comes into view one time.
  static let settleDistance: CGFloat = 200

  /// The session of the list.
  let session: SessionModel

  /// The manager of the list, which holds the rows in view.
  let anchors = ScrollAnchorManager()

  /// The window of the list. It is never ordered in.
  let window: NSWindow

  /// The host of the list.
  let hosting: NSView

  /// The scroll view of the list.
  let scrollView: NSScrollView

  /// The heights of the static forms of the rows of the list.
  let heights: TranscriptStaticRowHeights

  /// Shows the list of `session` at the bottom.
  ///
  /// - Parameter session: The session of the list.
  convenience init(session: SessionModel) throws {
    try self.init(session: session, frames: TranscriptDisplayLinkFrames())
  }

  /// Shows the list of `session` at the bottom, with the frames that drive
  /// the queue of its rows (``TranscriptRowMountQueue``, card ^7625j1b).
  ///
  /// With no `expandedBlocks`, the list has no height cache: a static row
  /// takes the height of the last layout of its real row.
  ///
  /// - Parameters:
  ///   - session: The session of the list.
  ///   - frames: The frames of the queue, such as ``ManualFrames``.
  ///   - expandedBlocks: The store of the expanded blocks of the rows, or
  ///     `nil`. With a store, the list has the height cache of an
  ///     ``AgentThreadView`` (``TranscriptRowHeights``).
  ///   - messageFooter: The footer of each message row, as the
  ///     `messageFooter` slot gives it, or `nil` (the default) for no
  ///     footer.
  ///   - barHeight: The height of a clear bar over the top and of a clear
  ///     bar over the bottom of the list (`.safeAreaBar`), as the header
  ///     and the composer of an ``AgentThreadView`` are, or zero (the
  ///     default) for no bars. The list goes on under the bars, and its
  ///     scroll view gets the heights of the bars as its content insets.
  ///   - pictureByteLimit: The most bytes of the bitmaps of the pictures of
  ///     the height cache. The default is the default of the cache.
  init(
    session: SessionModel, frames: any TranscriptFrameSource, expandedBlocks: ExpandedBlocksStore? = nil,
    messageFooter: ItemViewRenderer<MessageEntry>? = nil, barHeight: CGFloat = .zero,
    pictureByteLimit: Int = TranscriptRowHeights.defaultPictureByteLimit
  ) throws {
    self.session = session
    let heights = TranscriptStaticRowHeights(pictureByteLimit: pictureByteLimit)
    self.heights = heights
    window = AnswerTextHitTests.mount(
      ConversationView(session: session, anchors: anchors, frames: frames, heights: heights)
        .environment(\.expandedBlocksStore, expandedBlocks)
        .environment(\.messageFooter, messageFooter)
        .safeAreaBar(edge: .top) { Self.bar(height: barHeight) }
        .safeAreaBar(edge: .bottom) { Self.bar(height: barHeight) })
    hosting = try #require(window.contentView)
    scrollView = try #require(
      views(ofType: NSScrollView.self, in: hosting).max { $0.frame.height < $1.frame.height })
  }

  /// A clear bar of a height, or no view for a height of zero, so a list
  /// with no bars has no content insets.
  ///
  /// - Parameter height: The height of the bar.
  /// - Returns: The bar.
  @ViewBuilder private static func bar(height: CGFloat) -> some View {
    if height > .zero {
      Color.clear.frame(height: height)
    }
  }

  /// Shows the list of `session` at the bottom with the height cache of an
  /// ``AgentThreadView``, and waits until the cache knows the exact height
  /// of each row.
  ///
  /// A row that the list makes in a live motion then shows its static form
  /// from its first frame, also when it was never real. The list does not
  /// need to show each row at rest before the motion. The rows that the
  /// list keeps from rest then do not decide which rows are static: SwiftUI
  /// keeps a number of rows out of view that changes with the work on the
  /// main actor, such as the work of other tests.
  ///
  /// The helper waits only for the computation of the cache
  /// (``TranscriptRowHeights/computeHeights(of:)``), not for the main-actor
  /// jobs of other tests. While the call waits for the
  /// worker, the main-actor jobs of the list that are ready run, and they
  /// can ask for a new layout of the list. Thus the host lays the list out
  /// again after the call (``settle()``), so the list is at rest.
  ///
  /// - Parameters:
  ///   - session: The session of the list.
  ///   - frames: The frames of the queue, such as ``ManualFrames``.
  ///   - pictureByteLimit: The most bytes of the bitmaps of the pictures of
  ///     the height cache. The default is the default of the cache.
  /// - Returns: The list, at rest.
  static func makeCached(
    session: SessionModel, frames: any TranscriptFrameSource,
    pictureByteLimit: Int = TranscriptRowHeights.defaultPictureByteLimit
  ) async throws -> MovingThread {
    let thread = try MovingThread(
      session: session, frames: frames, expandedBlocks: ExpandedBlocksStore(), pictureByteLimit: pictureByteLimit)
    thread.settle()
    let cache = try #require(thread.heights.cache, "the list has no height cache")
    await cache.computeHeights(of: session.transcript.map(\.rowKey))
    thread.settle()
    try #require(session.transcript.allSatisfy { cache.knowsHeight(of: $0.id) }, "a row has no exact height")
    return thread
  }

  /// The row keys of the rows in view.
  var rowKeysInView: Set<String> {
    Set(anchors.visibleIDs)
  }

  /// Moves the clip view to `y` at rest, and lays the host out after the
  /// blocks of the main run loop that the layout added.
  ///
  /// - Parameter y: The new offset of the clip view.
  func scrollAtRest(to y: CGFloat) {
    moveClip(to: y)
    settle()
  }

  /// Moves the clip view of the list to the offset `y`, and tells the
  /// scroll view about the move. The host does not lay out.
  ///
  /// - Parameter y: The new offset of the clip view.
  private func moveClip(to y: CGFloat) {
    let clip = scrollView.contentView
    clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
    scrollView.reflectScrolledClipView(clip)
  }

  /// Scrolls the list at rest from the bottom to the top and back, so each
  /// row was real one time and has the height of its layout, and the list
  /// reported its rows in view.
  func showEachRowAtRest() {
    let bottom = scrollView.contentView.bounds.origin.y
    let up = stride(from: bottom, through: .zero, by: -Self.settleDistance).dropFirst()
    let down = stride(from: .zero, through: bottom, by: Self.settleDistance)
    for y in Array(up) + [.zero] + Array(down) + [bottom] {
      scrollAtRest(to: y)
    }
  }

  /// Starts a live scroll of the list, so the rows move, and lays the host
  /// out after the blocks of the main run loop that the layout added.
  func startMoving() {
    postLiveScroll(NSScrollView.willStartLiveScrollNotification)
  }

  /// Ends the live scroll of the list, so the rows are at rest, and lays
  /// the host out after the blocks of the main run loop that the layout
  /// added.
  func stopMoving() {
    postLiveScroll(NSScrollView.didEndLiveScrollNotification)
  }

  /// Moves the offset of the list up by `distance` with no layout, and then
  /// ends the live scroll of the list, so the first layout at rest also
  /// brings the rows at the new offset into the list. Then lays the host
  /// out after the blocks of the main run loop that the layout added.
  ///
  /// - Parameter distance: The distance of the last move, in points.
  func stopMoving(afterMovingBy distance: CGFloat) {
    moveClip(to: scrollView.contentView.bounds.origin.y - distance)
    stopMoving()
  }

  /// Whether the hit test of the window at the center of the first
  /// EditorKit text view in view reaches the view of that text, as a click
  /// or a mouse move there does (``TextHitTest``). With no text view in
  /// view, the value is `false`.
  var hitReachesATextViewInView: Bool {
    guard let text = textViewsInView.first else { return false }
    return TextHitTest.reaches(TextHitTest.hit(in: hosting, atCenterOf: text), text: text, in: hosting)
  }

  /// Posts a live scroll notice of the scroll view of the list, and lays
  /// the host out after the blocks of the main run loop that the layout
  /// added.
  ///
  /// - Parameter name: The name of the live scroll notice.
  private func postLiveScroll(_ name: Notification.Name) {
    NotificationCenter.default.post(name: name, object: scrollView)
    settle()
  }

  /// Moves the offset of the list up by `distance`, and lays the host out
  /// synchronously. In a live scroll, the step also posts the live scroll
  /// notice of the step.
  ///
  /// - Parameters:
  ///   - distance: The distance of the step, in points.
  ///   - isLive: Whether the step is a step of a live scroll.
  func step(by distance: CGFloat, isLive: Bool) {
    moveClip(to: scrollView.contentView.bounds.origin.y - distance)
    if isLive {
      NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: scrollView)
    }
    hosting.layoutSubtreeIfNeeded()
  }

  /// Scrolls the list at rest to the row of `key` on the path of a jump of
  /// the host (``ScrollAnchorManager/noteJump(to:)`` and the scroll of the
  /// manager to the item), lays the host out after the blocks of the main
  /// run loop that the layout added, waits until the manager reports the
  /// row in view, and lays the host out again in the same way. The wait
  /// ends at once when the layout gave the report. No live scroll starts, so the rows do not move in a live
  /// motion.
  ///
  /// - Parameter key: The row key of the entry to scroll to.
  func jumpAtRest(to key: String) async {
    anchors.noteJump(to: key)
    anchors.onScroll(.item(key))
    settle()
    await ObservationWait.until { self.anchors.visibleIDs.contains(key) }
    settle()
  }

  /// The number of EditorKit text views in the list.
  var textViewCount: Int {
    textViews.count
  }

  /// The EditorKit text views in the list.
  var textViews: [NSTextView] {
    views(ofType: NSTextView.self, in: hosting)
  }

  /// The EditorKit text views of the list whose frames are in the visible
  /// area of the scroll view.
  ///
  /// The count does not include the text views of the rows that the lazy
  /// stack keeps out of view. The number of those rows changes with the
  /// work on the main actor, such as the work of other tests, so a test
  /// that counts only the text views in view gets the same count each time.
  var textViewsInView: [NSTextView] {
    let clip = scrollView.contentView
    let visible = clip.convert(clip.bounds, to: nil)
    return textViews.filter { $0.convert($0.bounds, to: nil).intersects(visible) }
  }

  /// Lays the host out, runs the blocks of the main run loop that the
  /// layout added (``PendingRunLoopBlocks``), and lays the host out again,
  /// so the list reports its rows in view.
  func settle() {
    hosting.layoutSubtreeIfNeeded()
    PendingRunLoopBlocks.run()
    hosting.layoutSubtreeIfNeeded()
  }
}

/// The SwiftUI drawing layers of a host that need display: the layers whose
/// content the next frame draws again (card ^9ync5h3).
///
/// SwiftUI draws text, shapes and images that stand among AppKit views into
/// drawing layers (`CGDrawingLayer`, `RBDrawingLayer`). A drawing layer
/// that SwiftUI marks for display draws its content again, such as its
/// text: the main-thread cost of the flick trace. ``drawPending(in:)`` draws
/// each such layer and records it, so the next call reports only the layers
/// that were marked after it. The layers of AppKit views are not counted.
enum PendingLayerDraws {
  /// The end of the class name of each SwiftUI drawing layer.
  static let drawingLayerSuffix = "DrawingLayer"

  /// Tells if a layer is a SwiftUI drawing layer.
  ///
  /// - Parameter layer: The layer.
  /// - Returns: `true` when the class name of the layer ends with
  ///   ``drawingLayerSuffix``.
  static func isSwiftUIDrawing(_ layer: CALayer) -> Bool {
    String(describing: type(of: layer)).hasSuffix(drawingLayerSuffix)
  }

  /// Draws each SwiftUI drawing layer of the tree of `root` that needs
  /// display.
  ///
  /// - Parameter root: The root layer.
  /// - Returns: The identity of each drawing layer of the tree, and whether
  ///   it needed display.
  @MainActor static func drawPending(in root: CALayer) -> [ObjectIdentifier: Bool] {
    var layers: [ObjectIdentifier: Bool] = [:]
    var pending = [root]
    while let layer = pending.popLast() {
      if isSwiftUIDrawing(layer) {
        layers[ObjectIdentifier(layer)] = layer.needsDisplay()
        layer.displayIfNeeded()
      }
      pending.append(contentsOf: layer.sublayers ?? [])
    }
    return layers
  }
}
