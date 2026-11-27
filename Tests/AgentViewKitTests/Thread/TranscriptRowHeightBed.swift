import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import Observation
import SwiftUI
import Testing

@testable import AgentViewKit

/// A text measure that gives the heights that the EditorKit text views of a
/// mounted row have.
///
/// The bed pairs each text part of the chrome rule, in the order of the rule,
/// with the EditorKit text view at the same place in the mounted row. Thus a
/// test of a chrome rule checks only the chrome that AgentViewKit adds.
nonisolated struct MountedTextMeasure: TranscriptTextMeasure {
  /// The height of each text part.
  let heights: [TranscriptTextPart: CGFloat]

  func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat {
    heights[part] ?? .zero
  }

  /// Each height is the height of a mounted view, so each part is exact.
  func isExact(_ part: TranscriptTextPart) -> Bool {
    true
  }
}

/// The count of the frame changes of the views under one root view.
///
/// A frame change of a view posts `NSView.frameDidChangeNotification` on
/// the main thread. The count is observable, so a test waits for the next
/// frame change with `ObservationWait`.
@MainActor @Observable final class FrameChangeCount {
  /// The count of the frame changes.
  private(set) var count = 0

  /// The token of the observer of the notification.
  @ObservationIgnored private var token: (any NSObjectProtocol)?

  /// Starts to count the frame changes of the views under `root`.
  ///
  /// - Parameter root: The root view.
  init(under root: NSView) {
    token = NotificationCenter.default.addObserver(
      forName: NSView.frameDidChangeNotification, object: nil, queue: nil
    ) { [weak self, weak root] notification in
      // AppKit posts the notification on the main thread, so the view
      // stays on the main thread.
      nonisolated(unsafe) let object = notification.object
      MainActor.assumeIsolated {
        guard let root, let view = object as? NSView, view.isDescendant(of: root) else { return }
        self?.count += 1
      }
    }
  }

  /// Stops the count.
  func stop() {
    token.map(NotificationCenter.default.removeObserver)
    token = nil
  }
}

/// Mounts transcript rows in a window that is never ordered in, and reads
/// their heights.
@MainActor enum TranscriptRowHeightBed {
  /// The width of a narrow thread, such as a thread in a side panel, in
  /// points.
  nonisolated static let narrowWidth: CGFloat = 320

  /// The width of a thread of regular width, in points.
  nonisolated static let regularWidth: CGFloat = 480

  /// The width of a wide thread, in points.
  nonisolated static let wideWidth: CGFloat = 720

  /// The widths of each row test: the three widths of the acceptance
  /// criteria of card ^9h7bm9j.
  nonisolated static let widths = [narrowWidth, regularWidth, wideWidth]

  /// The largest difference between the cached and the mounted height.
  static let tolerance: CGFloat = 0.5

  /// The difference between the cached and the mounted height of a row
  /// whose text parts are each exact: none.
  static let exactTolerance: CGFloat = .zero

  /// The height of the window before the layout sets the height of the row.
  private static let windowHeight: CGFloat = 2000

  /// The class name ends of the EditorKit views that lay out text.
  private static let textViewClassEnds = ["LaneHostView", "EditorLabelTextView"]

  /// The layout of one mounted row.
  struct MountedRow {
    /// The height of the row.
    let height: CGFloat

    /// The height of each EditorKit text view, from top to bottom.
    let textHeights: [CGFloat]
  }

  /// The first entry of a transcript of preview items.
  ///
  /// - Parameter items: The preview items.
  /// - Returns: The first entry.
  static func entry(_ items: [PreviewTranscriptItem]) throws -> TranscriptEntry {
    try #require(SessionModel.preview(transcript: items).transcript.first)
  }

  /// Mounts the row of `entry` at `width`, and reads its layout.
  ///
  /// An EditorKit view reports its height on the next pass of the main run
  /// loop, so the bed lays out the row, waits for the blocks of the run loop
  /// that the layout added, and lays out the row again.
  ///
  /// - Parameters:
  ///   - entry: The entry of the row.
  ///   - width: The width of the row.
  ///   - store: The store that tells whether a block is expanded.
  /// - Returns: The layout of the row.
  static func mount(_ entry: TranscriptEntry, width: CGFloat, store: ExpandedBlocksStore) async -> MountedRow {
    let (hosting, window) = UnorderedWindow.mount(
      ItemRow(entry: entry)
        .frame(width: width)
        .environment(\.expandedBlocksStore, store),
      size: CGSize(width: width, height: windowHeight))
    defer { UnorderedWindow.close(window) }
    StyleViewHost.layOut(hosting)
    await RunLoopBlockFence.afterPendingBlocks()
    StyleViewHost.layOut(hosting)
    let frames = textViewFrames(in: hosting).sorted { lhs, rhs in
      lhs.minY == rhs.minY ? lhs.minX < rhs.minX : lhs.minY < rhs.minY
    }
    return MountedRow(height: hosting.frame.height, textHeights: frames.map(\.height))
  }

  /// The frames of the outermost EditorKit text views under `root`.
  ///
  /// The walk of the view tree is the one walk of the test support,
  /// `NSView.descendants`. The bed keeps only the views that lay out text
  /// and that no other such view holds.
  ///
  /// - Parameter root: The view to search, and the view of the coordinates.
  /// - Returns: The frames in the coordinates of `root`.
  private static func textViewFrames(in root: NSView) -> [CGRect] {
    let textViews = root.descendants.filter { view in
      textViewClassEnds.contains(where: String(describing: type(of: view)).hasSuffix)
    }
    let outermost = textViews.filter { view in
      !textViews.contains { other in other !== view && view.isDescendant(of: other) }
    }
    return outermost.map { root.convert($0.bounds, from: $0) }
  }

  /// The text parts of the chrome rule of `content`, in the order of the rule.
  ///
  /// - Parameters:
  ///   - content: The content of the row.
  ///   - width: The width of the row.
  ///   - metrics: The theme metrics.
  /// - Returns: The parts.
  static func parts(
    of content: TranscriptRowContent, width: CGFloat, metrics: TranscriptRowMetrics
  ) -> [TranscriptTextPart] {
    var parts: [TranscriptTextPart] = []
    _ = TranscriptRowChrome.height(of: content, width: width, metrics: metrics) { part, _ in
      parts.append(part)
      return .zero
    }
    return parts
  }

  /// Mounts the row of `entry`, computes its height in a cache, and checks
  /// that the two heights are the same.
  ///
  /// - Parameters:
  ///   - entry: The entry of the row.
  ///   - width: The width of the row.
  ///   - expanded: Whether the blocks of the row are expanded.
  ///   - measure: The text measure of the cache, or `nil` for the heights of
  ///     the mounted text views (``MountedTextMeasure``), which check the
  ///     chrome alone.
  ///   - tolerance: The largest difference between the two heights.
  ///   - sourceLocation: The location of the caller.
  static func expectCachedHeightMatchesTheMountedRow(
    _ entry: TranscriptEntry, width: CGFloat, expanded: Bool = false, measure: (any TranscriptTextMeasure)? = nil,
    tolerance: CGFloat = tolerance, sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    let store = ExpandedBlocksStore { _ in expanded }
    let mounted = await mount(entry, width: width, store: store)
    let metrics = TranscriptRowMetrics.probe()
    let content = TranscriptRowContent(entry: entry, isExpanded: expanded)
    let parts = parts(of: content, width: width, metrics: metrics)
    try #require(parts.count == mounted.textHeights.count, sourceLocation: sourceLocation)
    let mountedMeasure = MountedTextMeasure(
      heights: Dictionary(zip(parts, mounted.textHeights)) { first, _ in first })
    let heights = TranscriptRowHeights(measure: measure ?? mountedMeasure, metrics: metrics, expandedBlocks: store)
    let cached = try await cachedHeight(of: entry, in: heights, width: width, sourceLocation: sourceLocation)
    #expect(
      abs(cached - mounted.height) <= tolerance, "cached \(cached), mounted \(mounted.height)",
      sourceLocation: sourceLocation)
  }

  /// Mounts the row of an entry that shows an image, waits until the row
  /// shows the loaded image, and reads the height of the row.
  ///
  /// While the image loads, its view takes one row of text. The load ends
  /// off the main thread, and EditorKit then lays out its text again, so a
  /// view of the row changes its frame. The bed waits for the frame changes
  /// until the row is taller than `loadingHeight`, and lays out the row
  /// again.
  ///
  /// - Parameters:
  ///   - entry: The entry of the row.
  ///   - session: The session of the entry. Its working folder holds the
  ///     image.
  ///   - width: The width of the row.
  ///   - loadingHeight: The height of the row while the image loads.
  /// - Returns: The height of the row with the loaded image.
  static func mountAfterImageLoad(
    _ entry: TranscriptEntry, session: SessionModel, width: CGFloat, loadingHeight: CGFloat
  ) async -> CGFloat {
    let (hosting, window) = UnorderedWindow.mount(
      ItemRow(entry: entry)
        .frame(width: width)
        .environment(\.expandedBlocksStore, ExpandedBlocksStore { _ in false })
        .environment(\.sessionModel, session),
      size: CGSize(width: width, height: windowHeight))
    let frames = FrameChangeCount(under: hosting)
    defer {
      frames.stop()
      UnorderedWindow.close(window)
    }
    StyleViewHost.layOut(hosting)
    await RunLoopBlockFence.afterPendingBlocks()
    await ObservationWait.until {
      _ = frames.count
      return hosting.fittingSize.height > loadingHeight
    }
    StyleViewHost.layOut(hosting)
    await RunLoopBlockFence.afterPendingBlocks()
    StyleViewHost.layOut(hosting)
    return hosting.frame.height
  }

  /// Gives a cache one entry, and waits until the cache publishes its
  /// height.
  ///
  /// - Parameters:
  ///   - entry: The entry of the row.
  ///   - heights: The cache.
  ///   - width: The width of the row.
  ///   - sourceLocation: The location of the caller.
  /// - Returns: The height of the cache.
  static func cachedHeight(
    of entry: TranscriptEntry, in heights: TranscriptRowHeights, width: CGFloat,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws -> CGFloat {
    heights.update(entries: [entry], width: width, rowsInView: 0..<1)
    await ObservationWait.until(sourceLocation: sourceLocation) { heights.height(of: entry.rowKey) != nil }
    return try #require(heights.height(of: entry.rowKey), sourceLocation: sourceLocation)
  }
}
