import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The count of the open questions of a session: the number of its
/// ``FoundationModelsACPClient/SessionModel/pendingRequests``
/// (elicitation-plan.md §4, task 40).
///
/// The badge shows the count as a number in a capsule. When the session has
/// no pending request, the badge shows nothing. The count changes when the
/// model of the session changes, and the badge makes no announcement.
///
/// ``SessionListView`` shows the badge in the row of each open session that
/// is not its current session:
///
/// ```swift
/// SessionListView(connection: connection, currentSession: shown.sessionId) { opened in
///   shown = opened
/// }
/// ```
///
/// The badge is visual only: it is hidden from accessibility, so VoiceOver
/// does not read the number. The label of the row tells the count with
/// ``openQuestionsLabel(count:)``, so VoiceOver reads the count one time.
/// The view keeps the identifier ``identifier(for:)`` for the code.
public struct PendingRequestCountBadge: View {
  /// The text after the row identifier in the identifier of a badge.
  public static let identifierSuffix = "-pending"

  /// The space between the number and the left and right edges of the
  /// capsule, in points.
  static let horizontalPadding: CGFloat = 6

  /// The space between the number and the top and bottom edges of the
  /// capsule, in points.
  static let verticalPadding: CGFloat = 2

  /// The opacity of the accent color in the capsule.
  static let fillOpacity = 0.18

  /// The accessibility identifier of the badge of a session.
  ///
  /// - Parameter id: The identifier of the session.
  /// - Returns: The row identifier of the session with ``identifierSuffix``,
  ///   such as `session-row-s1-pending`.
  public static func identifier(for id: SessionId) -> String {
    SessionListView.rowIdentifier(for: id) + identifierSuffix
  }

  /// The text that tells the number of open questions.
  ///
  /// - Parameter count: The number of the pending requests.
  /// - Returns: "1 open question" for one request, and "N open questions"
  ///   for each other count.
  public static func openQuestionsLabel(count: Int) -> String {
    count == 1 ? String(localized: "1 open question") : String(localized: "\(count) open questions")
  }

  /// The session model whose pending requests the badge counts.
  let session: SessionModel

  /// The EditorKit theme that gives the accent color of the badge.
  @Environment(\.editorTheme) private var editorTheme

  /// Makes the badge of a session.
  ///
  /// - Parameter session: The session model whose pending requests the badge
  ///   counts.
  public init(session: SessionModel) {
    self.session = session
  }

  public var body: some View {
    let count = session.pendingRequests.count
    if count > 0 {
      Text(count, format: .number)
        .font(.caption.monospacedDigit())
        .foregroundStyle(editorTheme.accent)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .background(Capsule().fill(editorTheme.accent.opacity(Self.fillOpacity)))
        .accessibilityIdentifier(Self.identifier(for: session.sessionId))
        .accessibilityHidden(true)
    }
  }
}
