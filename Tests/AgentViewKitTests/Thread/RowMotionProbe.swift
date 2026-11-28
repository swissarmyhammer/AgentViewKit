import SwiftUI

@testable import AgentViewKit

/// A view in the footer of each message row of a thread, which records the
/// motion signal that the rows read (card ^9ync5h3).
///
/// Each row of a ``ConversationView`` reads
/// ``SwiftUI/EnvironmentValues/transcriptRowsMove``, and shows its static
/// form while the value is `true`. The footer reads the same value in the
/// same row, so a test reads the form signal of the rows after a layout.
@MainActor final class RowMotionProbe {
  /// The value of ``SwiftUI/EnvironmentValues/transcriptRowsMove`` at the
  /// last evaluation of a footer, or `nil` before the first one.
  private(set) var rowsMove: Bool?

  /// The footer of the message rows, for the `messageFooter` slot.
  var footer: MessageFooter {
    MessageFooter { _ in RowMotionProbeView(probe: self) }
  }

  /// Records the value that a footer read.
  ///
  /// - Parameter rowsMove: Whether the rows of the thread move.
  fileprivate func note(_ rowsMove: Bool) {
    self.rowsMove = rowsMove
  }
}

/// The footer view of a ``RowMotionProbe``: a clear point that records the
/// motion signal of its row at each evaluation.
private struct RowMotionProbeView: View {
  /// The probe that records the signal.
  let probe: RowMotionProbe

  @Environment(\.transcriptRowsMove) private var rowsMove

  var body: some View {
    let _ = probe.note(rowsMove)
    Color.clear.frame(width: 1, height: 1)
  }
}
