import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The notice of one request that the agent withdrew, as a ``RequestDeck``
/// shows it (card 39a design section 3).
///
/// The value has the id of the `WithdrawnRequest` record and the text of the
/// notice. The deck makes one value for each record of its model in each
/// body, and keeps no copy.
struct WithdrawnNotice: Identifiable, Equatable {
  /// The id of the record, which is the id that the request had while it was
  /// pending.
  let id: WithdrawnRequest.ID

  /// The text of the notice (``RequestDeck/withdrawnText(title:reason:)``).
  let text: String
}

extension WithdrawnNotice {
  /// Makes the notice of a record.
  ///
  /// - Parameter record: The record of the withdrawn request. Its title is
  ///   the title of the action required announcement: the permission title
  ///   or the elicitation message.
  init(record: WithdrawnRequest) {
    let title = ThreadAccessibility.PendingRequestSummary(request: record.request).title
    self.init(id: record.id, text: RequestDeck.withdrawnText(title: title, reason: record.reason))
  }
}

extension RequestDeck {
  /// The start of the accessibility identifier of the text of each notice of
  /// a withdrawn request.
  public static let withdrawnIdentifierPrefix = "request-deck-withdrawn-"

  /// The start of the accessibility identifier of the Dismiss button of each
  /// notice of a withdrawn request.
  public static let withdrawnDismissIdentifierPrefix = "request-deck-withdrawn-dismiss-"

  /// The accessibility identifier of the text of the notice of a withdrawn
  /// request.
  ///
  /// - Parameter id: The id of the `WithdrawnRequest` record.
  /// - Returns: `request-deck-withdrawn-<id>`.
  public static func identifier(forWithdrawn id: WithdrawnRequest.ID) -> String {
    AccessibilityIdentifier.make(prefix: withdrawnIdentifierPrefix, value: id.uuidString)
  }

  /// The accessibility identifier of the Dismiss button of the notice of a
  /// withdrawn request.
  ///
  /// - Parameter id: The id of the `WithdrawnRequest` record.
  /// - Returns: `request-deck-withdrawn-dismiss-<id>`.
  static func dismissIdentifier(forWithdrawn id: WithdrawnRequest.ID) -> String {
    AccessibilityIdentifier.make(prefix: withdrawnDismissIdentifierPrefix, value: id.uuidString)
  }

  /// The text of the notice of a withdrawn request.
  ///
  /// - Parameters:
  ///   - title: The title of the request.
  ///   - reason: The reason of the agent, or `nil`. An empty reason is no
  ///     reason.
  /// - Returns: "<title> was withdrawn: <reason>", or "<title> was
  ///   withdrawn." with no reason.
  static func withdrawnText(title: String, reason: String?) -> String {
    guard let reason, !reason.isEmpty else {
      return String(localized: "\(title) was withdrawn.", bundle: .module)
    }
    return String(localized: "\(title) was withdrawn: \(reason)", bundle: .module)
  }

  /// The announcements of the notices that are new.
  ///
  /// - Parameters:
  ///   - old: The notices before the change.
  ///   - new: The notices after the change.
  /// - Returns: The text of each new notice, in the order of `new`. A notice
  ///   that went away gives no text.
  static func withdrawnAnnouncements(old: [WithdrawnNotice], new: [WithdrawnNotice]) -> [String] {
    ThreadAccessibility.added(in: new, since: old, id: \.id).map(\.text)
  }
}

/// The glass row of the notice of one withdrawn request in a
/// ``RequestDeck``: the information symbol and tint, the text of the notice,
/// and a Dismiss button.
struct WithdrawnNoticeRow: View {
  /// The severity of each notice of a withdrawn request, which gives the
  /// symbol and the tint.
  static let severity = NoticeSeverity.info

  /// The notice to show.
  let notice: WithdrawnNotice

  /// The closure that the Dismiss button calls.
  let dismiss: () -> Void

  var body: some View {
    NoticeRow(
      severity: Self.severity, title: notice.text, description: nil, label: notice.text,
      identifier: RequestDeck.identifier(forWithdrawn: notice.id),
      dismissIdentifier: RequestDeck.dismissIdentifier(forWithdrawn: notice.id), dismiss: dismiss)
  }
}
