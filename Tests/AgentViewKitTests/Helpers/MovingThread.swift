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
/// step. A wait for the blocks of the main run loop follows each step at
/// rest, so the list reports its rows in view.
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

  /// Shows the list of `session` at the bottom.
  ///
  /// - Parameter session: The session of the list.
  convenience init(session: SessionModel) throws {
    try self.init(session: session, frames: TranscriptDisplayLinkFrames())
  }

  /// Shows the list of `session` at the bottom, with the frames that drive
  /// the queue of its rows (``TranscriptRowMountQueue``, card ^7625j1b).
  ///
  /// - Parameters:
  ///   - session: The session of the list.
  ///   - frames: The frames of the queue, such as ``ManualFrames``.
  init(session: SessionModel, frames: any TranscriptFrameSource) throws {
    self.session = session
    window = AnswerTextHitTests.mount(ConversationView(session: session, anchors: anchors, frames: frames))
    hosting = try #require(window.contentView)
    scrollView = try #require(
      views(ofType: NSScrollView.self, in: hosting).max { $0.frame.height < $1.frame.height })
  }

  /// The row keys of the rows in view.
  var rowKeysInView: Set<String> {
    Set(anchors.visibleIDs)
  }

  /// Moves the clip view to `y` at rest, and lays the host out after the
  /// blocks of the main run loop that the layout added.
  ///
  /// - Parameter y: The new offset of the clip view.
  func scrollAtRest(to y: CGFloat) async {
    let clip = scrollView.contentView
    clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
    scrollView.reflectScrolledClipView(clip)
    await settle()
  }

  /// Scrolls the list at rest from the bottom to the top and back, so each
  /// row was real one time and has the height of its layout, and the list
  /// reported its rows in view.
  func showEachRowAtRest() async {
    let bottom = scrollView.contentView.bounds.origin.y
    let up = stride(from: bottom, through: .zero, by: -Self.settleDistance).dropFirst()
    let down = stride(from: .zero, through: bottom, by: Self.settleDistance)
    for y in Array(up) + [.zero] + Array(down) + [bottom] {
      await scrollAtRest(to: y)
    }
  }

  /// Starts a live scroll of the list, so the rows move, and lays the host
  /// out after the blocks of the main run loop that the layout added.
  func startMoving() async {
    NotificationCenter.default.post(name: NSScrollView.willStartLiveScrollNotification, object: scrollView)
    await settle()
  }

  /// Ends the live scroll of the list, so the rows are at rest, and lays
  /// the host out after the blocks of the main run loop that the layout
  /// added.
  func stopMoving() async {
    NotificationCenter.default.post(name: NSScrollView.didEndLiveScrollNotification, object: scrollView)
    await settle()
  }

  /// Moves the offset of the list up by `distance`, and lays the host out
  /// synchronously. In a live scroll, the step also posts the live scroll
  /// notice of the step.
  ///
  /// - Parameters:
  ///   - distance: The distance of the step, in points.
  ///   - isLive: Whether the step is a step of a live scroll.
  func step(by distance: CGFloat, isLive: Bool) {
    let clip = scrollView.contentView
    let origin = clip.bounds.origin
    clip.scroll(to: NSPoint(x: origin.x, y: origin.y - distance))
    scrollView.reflectScrolledClipView(clip)
    if isLive {
      NotificationCenter.default.post(name: NSScrollView.didLiveScrollNotification, object: scrollView)
    }
    hosting.layoutSubtreeIfNeeded()
  }

  /// Scrolls the list at rest to the row of `key` on the path of a jump of
  /// the host (``ScrollAnchorManager/noteJump(to:)`` and the scroll of the
  /// manager to the item), waits until the manager reports the row in view,
  /// and lays the host out after the blocks of the main run loop that the
  /// layout added. No live scroll starts, so the rows do not move in a live
  /// motion.
  ///
  /// - Parameter key: The row key of the entry to scroll to.
  func jumpAtRest(to key: String) async {
    anchors.noteJump(to: key)
    anchors.onScroll(.item(key))
    hosting.layoutSubtreeIfNeeded()
    await ObservationWait.until { self.anchors.visibleIDs.contains(key) }
    await settle()
  }

  /// The number of EditorKit text views in the list.
  var textViewCount: Int {
    views(ofType: NSTextView.self, in: hosting).count
  }

  /// The EditorKit text views in the list.
  var textViews: [NSTextView] {
    views(ofType: NSTextView.self, in: hosting)
  }

  /// Lays the host out, waits for the blocks of the main run loop that the
  /// layout added, and lays the host out again, so the list reports its
  /// rows in view.
  func settle() async {
    hosting.layoutSubtreeIfNeeded()
    await RunLoopBlockFence.afterPendingBlocks()
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
