import AgentViewKit
import FoundationModelsACPClient
import SwiftUI

/// The rows of a transcript, as ``ConversationView`` shows them, in a stack
/// that keeps each row.
///
/// A lazy stack evaluates only the rows near the view, so a test that counts
/// the rows or their editors uses a `VStack`. Each row gets the environment
/// that ``ConversationView`` gives it: its position, its liveness, the live
/// rows, the session and one text selection. The unit tests and the
/// IntegrationTests package use this one helper, and keep no copy of the
/// environment of the rows.
///
/// The helper has `package` access, because the live rows have `package`
/// access. The IntegrationTests package reaches it with
/// `@testable import AgentViewKitTestSupport`.
package enum TranscriptRowsStack {
  /// The rows of each entry of `session`, with the environment that
  /// ``ConversationView`` gives them.
  ///
  /// - Parameters:
  ///   - session: The session whose transcript the stack shows.
  ///   - rows: The rows that keep their models.
  ///   - width: The width of the rows, in points.
  /// - Returns: The rows in a stack that keeps each row.
  package static func view(of session: SessionModel, rows: LiveRowRange, width: CGFloat) -> some View {
    VStack(spacing: 0) {
      ForEach(Array(session.transcript.enumerated()), id: \.element.id) { position, entry in
        ItemRow(entry: entry)
          .environment(\.transcriptRowPosition, position)
          .modifier(TranscriptRowLiveness(position: position))
      }
    }
    .frame(width: width)
    .environment(\.liveRowRange, rows)
    .environment(\.sessionModel, session)
    .threadTextSelection()
  }
}
