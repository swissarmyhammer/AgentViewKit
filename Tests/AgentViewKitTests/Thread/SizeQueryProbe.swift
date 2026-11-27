import Foundation
import SwiftUI

/// The record of a ``SizeQueryProbe``: the size queries that the probe got.
@MainActor final class SizeQueryRecord {
  /// The mangled name of the size function of `InsetViewLayout`, the
  /// SwiftUI layout of `.safeAreaBar` and `.safeAreaInset`, as the call
  /// stack of a size query shows it.
  ///
  /// The bar layout asks its content for a size in this function. The bar
  /// layout also places its content, and a placement of the lazy stack asks
  /// the rows for their sizes. The call stack of such a query has the place
  /// functions of the bar layout, and not this function.
  static let barMeasureSymbol = "15InsetViewLayoutV12sizeThatFits"

  /// The number of the size queries.
  private(set) var queryCount = 0

  /// The number of the size queries that a safe-area bar made to measure
  /// its content: the call stack of each of them has ``barMeasureSymbol``.
  private(set) var barQueryCount = 0

  /// The proposal of each size query, in the order of the queries.
  private(set) var proposals: [ProposedViewSize] = []

  /// Records one size query.
  ///
  /// - Parameters:
  ///   - proposal: The proposal of the query.
  ///   - symbols: The call stack of the query.
  func noteQuery(_ proposal: ProposedViewSize, symbols: [String]) {
    queryCount += 1
    proposals.append(proposal)
    if symbols.contains(where: { $0.contains(Self.barMeasureSymbol) }) {
      barQueryCount += 1
    }
  }

  /// The number of the alignment guide queries.
  private(set) var alignmentQueryCount = 0

  /// The proposal of each placement of the probe, in the order of the
  /// placements.
  private(set) var placements: [ProposedViewSize] = []

  /// Records one placement.
  ///
  /// - Parameter proposal: The proposal of the placement.
  func notePlacement(_ proposal: ProposedViewSize) {
    placements.append(proposal)
  }

  /// Records one alignment guide query.
  func noteAlignmentQuery() {
    alignmentQueryCount += 1
  }

  /// Removes the queries of the record.
  func reset() {
    queryCount = 0
    proposals = []
    placements = []
    barQueryCount = 0
    alignmentQueryCount = 0
  }
}

/// A `Layout` that a test puts in a view, and that records each size query
/// and each alignment guide query that it gets.
///
/// The probe has no subview, so it gives no guide of its own: each
/// alignment guide query returns `nil`. Its size is the proposed width (zero for an
/// unspecified width) and its ``height``.
struct SizeQueryProbe: Layout {
  /// The record that gets the queries.
  let record: SizeQueryRecord

  /// The height of the probe, in points.
  let height: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let symbols = Thread.callStackSymbols
    MainActor.assumeIsolated { record.noteQuery(proposal, symbols: symbols) }
    return CGSize(width: proposal.width ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
    MainActor.assumeIsolated { record.notePlacement(proposal) }
  }

  func explicitAlignment(
    of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout Void
  ) -> CGFloat? {
    MainActor.assumeIsolated { record.noteAlignmentQuery() }
    return nil
  }

  func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout Void
  ) -> CGFloat? {
    MainActor.assumeIsolated { record.noteAlignmentQuery() }
    return nil
  }
}

/// A stack that asks its content for a horizontal guide and for a vertical
/// guide: the leading edge and the first text baseline, as a `ZStack` with
/// that alignment asks each of its children.
///
/// A text beside the content gives the stack a baseline of its own.
struct AlignmentQueryStack<Content: View>: View {
  /// The content that the stack aligns.
  @ViewBuilder let content: Content

  var body: some View {
    ZStack(alignment: .leadingFirstTextBaseline) {
      Text(verbatim: "A")
      content
    }
  }
}
