import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACPClient
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
}

/// Mounts transcript rows in a window that is never ordered in, and reads
/// their heights.
@MainActor enum TranscriptRowHeightBed {
  /// The widths of each row test.
  nonisolated static let widths: [CGFloat] = [320, 480, 720]

  /// The largest difference between the cached and the mounted height.
  static let tolerance: CGFloat = 0.5

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
    let hosting = NSHostingView(
      rootView: ItemRow(entry: entry)
        .frame(width: width)
        .environment(\.expandedBlocksStore, store))
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: width, height: windowHeight), styleMask: [.borderless],
      backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    defer {
      window.contentView = nil
      window.close()
    }
    StyleViewHost.layOut(hosting)
    await RunLoopBlockFence.afterPendingBlocks()
    StyleViewHost.layOut(hosting)
    let frames = textViewFrames(under: hosting, in: hosting).sorted { lhs, rhs in
      lhs.minY == rhs.minY ? lhs.minX < rhs.minX : lhs.minY < rhs.minY
    }
    return MountedRow(height: hosting.frame.height, textHeights: frames.map(\.height))
  }

  /// The frames of the outermost EditorKit text views under `view`.
  ///
  /// - Parameters:
  ///   - view: The view to search.
  ///   - root: The view of the coordinates.
  /// - Returns: The frames in the coordinates of `root`.
  private static func textViewFrames(under view: NSView, in root: NSView) -> [CGRect] {
    view.subviews.flatMap { subview -> [CGRect] in
      let name = String(describing: type(of: subview))
      if textViewClassEnds.contains(where: name.hasSuffix) {
        return [root.convert(subview.bounds, from: subview)]
      }
      return textViewFrames(under: subview, in: root)
    }
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
  ///   - measure: The text measure of the cache, or `nil` for a
  ///     ``MountedTextMeasure`` of the mounted row.
  ///   - sourceLocation: The location of the caller.
  static func expectCachedHeightMatchesTheMountedRow(
    _ entry: TranscriptEntry, width: CGFloat, expanded: Bool = false,
    measure: (any TranscriptTextMeasure)? = nil, sourceLocation: SourceLocation = #_sourceLocation
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
    heights.update(entries: [entry], width: width, rowsInView: 0..<1)
    await ObservationWait.until(sourceLocation: sourceLocation) { heights.height(of: entry.rowKey) != nil }
    let cached = try #require(heights.height(of: entry.rowKey), sourceLocation: sourceLocation)
    #expect(
      abs(cached - mounted.height) <= tolerance, "cached \(cached), mounted \(mounted.height)",
      sourceLocation: sourceLocation)
  }
}
