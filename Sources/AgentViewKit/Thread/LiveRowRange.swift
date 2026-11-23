import Observation
import SwiftUI

/// The rows of a thread that keep their EditorKit models (task ^t9416x5).
///
/// One rendered answer keeps its syntax trees and its TextKit 2 layout in
/// its model and its editor, about 659 KiB in a release build (EditorKit
/// benchmark). A lazy stack can keep the rows that scrolled away, so a long
/// scroll could keep the model of each row. Thus a ``ResponseView`` far from
/// the rows in view drops its model and its editor, and keeps only its text
/// and its height. It makes a new model when its row comes near again.
///
/// The live rows are the rows in view and ``margin`` rows on each side of
/// them. ``ConversationView`` reports the rows in view each time the list
/// reports them. The range moves only when the rows in view come nearer
/// than ``slack`` rows to an end of the range, so a scroll of a few rows
/// does not make each row evaluate its body again. Before the first report,
/// each row is live.
@MainActor @Observable
final class LiveRowRange {
  /// The number of rows before and after the rows in view that keep their
  /// models.
  static let margin = 16

  /// The number of rows that the rows in view can move before the range
  /// moves with them.
  ///
  /// It is half of ``margin``. Thus, after the range moves, the rows in view
  /// can move `slack` rows in each direction before the range moves again,
  /// and each row in view keeps at least `slack` live rows beyond it.
  static let slack = 8

  /// The positions of the live rows, or `nil` before the first report, when
  /// each row is live.
  private var positions: ClosedRange<Int>?

  /// Makes a range in which each row is live.
  init() {}

  /// Records the rows in view, and moves the range when they come near an
  /// end of it.
  ///
  /// A report with no row, such as a layout pass past the end of the
  /// content, keeps the range.
  ///
  /// - Parameter visible: The positions in the transcript of the rows in
  ///   view, in any order.
  func noteVisible(positions visible: [Int]) {
    guard let first = visible.min(), let last = visible.max() else { return }
    guard !covers(first - Self.slack, last + Self.slack) else { return }
    positions = (first - Self.margin)...(last + Self.margin)
  }

  /// Tells if the range holds both positions.
  ///
  /// - Parameters:
  ///   - first: The first position.
  ///   - last: The last position.
  /// - Returns: `true` when the range holds `first` and `last`, and `false`
  ///   before the first report.
  private func covers(_ first: Int, _ last: Int) -> Bool {
    positions.map { $0.contains(first) && $0.contains(last) } ?? false
  }

  /// Tells if the row at `position` keeps its models.
  ///
  /// - Parameter position: The position of the row in the transcript.
  /// - Returns: `true` when the row keeps its models.
  func isLive(_ position: Int) -> Bool {
    positions?.contains(position) ?? true
  }
}

extension EnvironmentValues {
  /// The rows of the thread that keep their EditorKit models, or `nil`
  /// outside a thread, where each view keeps its models.
  /// ``ConversationView`` sets it for its rows.
  @Entry var liveRowRange: LiveRowRange? = nil

  /// Whether the row of the view keeps its EditorKit models.
  ///
  /// ``TranscriptRowLiveness`` sets it for each row of a thread. Outside a
  /// thread row, it is `true`, so each view keeps its models. A view reads
  /// this value, not ``liveRowRange``: a move of the live rows then changes
  /// the value only for the rows that enter or leave the range, and SwiftUI
  /// evaluates only the views of those rows again.
  @Entry var transcriptRowIsLive = true
}

/// Gives a row of a thread its liveness (``LiveRowRange/isLive(_:)``) as the
/// environment value ``SwiftUI/EnvironmentValues/transcriptRowIsLive``.
///
/// The modifier reads the ``LiveRowRange`` of the environment, so each move
/// of the range evaluates the modifier of each row. The modifier sets only a
/// `Bool` for its content. Thus the content of a row whose liveness does not
/// change does not evaluate its body again. With no ``LiveRowRange``, each
/// row is live.
struct TranscriptRowLiveness: ViewModifier {
  /// The position of the row in the transcript.
  let position: Int

  @Environment(\.liveRowRange) private var liveRows

  func body(content: Content) -> some View {
    content.environment(\.transcriptRowIsLive, liveRows?.isLive(position) ?? true)
  }
}
