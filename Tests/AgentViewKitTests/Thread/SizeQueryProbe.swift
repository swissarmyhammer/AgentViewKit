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

  /// Records one size query.
  ///
  /// - Parameter symbols: The call stack of the query.
  func noteQuery(symbols: [String]) {
    queryCount += 1
    if symbols.contains(where: { $0.contains(Self.barMeasureSymbol) }) {
      barQueryCount += 1
    }
  }

  /// Removes the queries of the record.
  func reset() {
    queryCount = 0
    barQueryCount = 0
  }
}

/// A `Layout` that a test puts in a view, and that records each size query
/// that it gets.
///
/// The probe has no subview. Its size is the proposed width (zero for an
/// unspecified width) and its ``height``.
struct SizeQueryProbe: Layout {
  /// The record that gets the queries.
  let record: SizeQueryRecord

  /// The height of the probe, in points.
  let height: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let symbols = Thread.callStackSymbols
    MainActor.assumeIsolated { record.noteQuery(symbols: symbols) }
    return CGSize(width: proposal.width ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
}
