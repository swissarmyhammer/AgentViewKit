import CoreGraphics
import FoundationModelsACPClient
import Observation

/// The sources of the height of one row of a thread that the virtual stack
/// reads (``TranscriptElementHeights``, card ^kr7cx7b).
@MainActor protocol TranscriptRowHeightSource {
  /// The exact height of the row from data, or `nil`.
  ///
  /// - Parameters:
  ///   - id: The id of the entry of the row.
  ///   - width: The width of the row.
  /// - Returns: The height in points, or `nil` when no exact height is
  ///   known at that width.
  func exactHeight(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat?

  /// The height of the last layout of the real row, or `nil`.
  ///
  /// - Parameters:
  ///   - id: The id of the entry of the row.
  ///   - width: The width of the row.
  /// - Returns: The height in points, or `nil` when the row had no layout
  ///   at that width.
  func lastRowHeight(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat?

  /// A height of the row from data that is not exact, or `nil`.
  ///
  /// - Parameter id: The id of the entry of the row.
  /// - Returns: The height in points, or `nil` when no estimate is known.
  func estimatedHeight(of id: TranscriptEntry.ID) -> CGFloat?
}

/// The shape of one element of the virtual stack of a thread: the row of an
/// entry and its status lines (``TranscriptRowElement``).
nonisolated struct TranscriptElementShape: Equatable, Sendable {
  /// The id of the entry of the row.
  let id: TranscriptEntry.ID

  /// The number of the status lines after the row.
  let lineCount: Int

  /// Whether the element is the last element: it has the bottom padding of
  /// the list below it.
  let isLast: Bool
}

/// The fixed lengths of the elements of the virtual stack of a thread.
nonisolated struct TranscriptElementMetrics: Equatable, Sendable {
  /// The spacing between two views of an element, and between two
  /// elements.
  let spacing: CGFloat

  /// The padding below the last element.
  let bottomPadding: CGFloat

  /// The padding below an element of a shape.
  ///
  /// - Parameter shape: The shape of the element.
  /// - Returns: ``bottomPadding`` for the last element, else zero.
  func padding(below shape: TranscriptElementShape) -> CGFloat {
    shape.isLast ? bottomPadding : .zero
  }
}

/// The heights of the elements of the virtual stack of a thread (card
/// ^kr7cx7b).
///
/// The stack places each element from its height, and it lays out only the
/// elements near the part in view. The height of an element comes from the
/// first of these sources that knows it:
///
/// 1. The live layout of the element: the element is in the stack, and its
///    last layout is at the width of the stack. A row that streams or that
///    the user expands thus has its real height at once.
/// 2. The exact height of the row in the cache of the rows, for an element
///    with no status line (``TranscriptRowHeights``).
/// 3. The height of the last layout of the element, when it was in the
///    stack before.
/// 4. The height of the row (the last layout of the real row, else a height
///    of the cache that is not exact, else ``estimatedRowHeight``) and an
///    estimate of each status line (``estimatedLineHeight``).
///
/// Each source gives the same value on each read until its row changes, so
/// the estimate of a row is stable. A record of a new height counts as a
/// change (``revision``), and the stack then computes its geometry again.
/// A record keeps the height of the element without the bottom padding of
/// the last element, so the element before a new last element keeps its
/// height.
@MainActor @Observable final class TranscriptElementHeights {
  /// The height of a row that no source knows, in points.
  static let estimatedRowHeight: CGFloat = 60

  /// The height of a status line that no layout measured, in points.
  static let estimatedLineHeight: CGFloat = 20

  /// The count of the records that changed a height.
  private(set) var revision = 0

  /// The last layout of one element.
  private struct Record: Equatable {
    /// The width of the layout.
    var width: CGFloat

    /// The height of the element, without the bottom padding of the last
    /// element.
    var height: CGFloat

    /// Whether the element is in the stack.
    var isLive: Bool
  }

  /// The last layout of each element, by the id of its entry.
  @ObservationIgnored private var records: [TranscriptEntry.ID: Record] = [:]

  /// Makes an empty record.
  init() {}

  /// Records the size of the layout of an element in the stack.
  ///
  /// The record counts as a change (``revision``) only when it changes the
  /// height that the stack gives the element at the width of the layout.
  /// Thus a row that comes into view at the exact height of the cache does
  /// not make the stack compute its geometry again (card ^kr7cx7b).
  ///
  /// - Parameters:
  ///   - height: The height of the element.
  ///   - width: The width of the element.
  ///   - shape: The shape of the element.
  ///   - metrics: The lengths of the stack.
  ///   - source: The sources of the height of the row.
  func record(
    height: CGFloat, width: CGFloat, for shape: TranscriptElementShape, metrics: TranscriptElementMetrics,
    source: some TranscriptRowHeightSource
  ) {
    let old = self.height(of: shape, width: width, source: source, metrics: metrics)
    records[shape.id] = Record(width: width, height: height - metrics.padding(below: shape), isLive: true)
    guard self.height(of: shape, width: width, source: source, metrics: metrics) != old else { return }
    revision += 1
  }

  /// Records that an element left the stack. Its last layout stays as a
  /// height of the element (source 3).
  ///
  /// - Parameter id: The id of the entry of the element.
  func noteGone(_ id: TranscriptEntry.ID) {
    records[id]?.isLive = false
  }

  /// The height of an element in the stack.
  ///
  /// - Parameters:
  ///   - shape: The shape of the element.
  ///   - width: The width of the stack.
  ///   - source: The sources of the height of the row.
  ///   - metrics: The lengths of the stack.
  /// - Returns: The height of the element, with the bottom padding of the
  ///   last element.
  func height(
    of shape: TranscriptElementShape, width: CGFloat, source: some TranscriptRowHeightSource,
    metrics: TranscriptElementMetrics
  ) -> CGFloat {
    let record = records[shape.id].flatMap {
      abs($0.width - width) <= TranscriptMeasuredRowHeights.widthTolerance ? $0 : nil
    }
    return metrics.padding(below: shape)
      + coreHeight(of: shape, width: width, record: record, source: source, metrics: metrics)
  }

  /// The height of an element without its bottom padding.
  ///
  /// - Parameters:
  ///   - shape: The shape of the element.
  ///   - width: The width of the stack.
  ///   - record: The last layout of the element at the width, or `nil`.
  ///   - source: The sources of the height of the row.
  ///   - metrics: The lengths of the stack.
  /// - Returns: The height.
  private func coreHeight(
    of shape: TranscriptElementShape, width: CGFloat, record: Record?, source: some TranscriptRowHeightSource,
    metrics: TranscriptElementMetrics
  ) -> CGFloat {
    if let record, record.isLive {
      return record.height
    }
    let exact = source.exactHeight(of: shape.id, width: width)
    if shape.lineCount == 0, let exact {
      return exact
    }
    if let record {
      return record.height
    }
    let row =
      exact ?? source.lastRowHeight(of: shape.id, width: width) ?? source.estimatedHeight(of: shape.id)
      ?? Self.estimatedRowHeight
    return row + CGFloat(shape.lineCount) * (metrics.spacing + Self.estimatedLineHeight)
  }
}
