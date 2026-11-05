import EditorStyle
import EditorSwiftUI
import FoundationModelsACPClient
import SwiftUI

/// The default view of a user message entry (plan.md §9 A2).
///
/// The view shows a ``MessageHeader``, the content blocks of the message, and
/// the ``SwiftUI/EnvironmentValues/messageFooter`` slot with the entry
/// object.
///
/// The view shows a `UserMessageEntry` of a `SessionModel` (plan.md §3.2).
/// The view reads the content of the entry, so a change to the entry
/// evaluates only this view. Its identifier uses the row key of the entry,
/// which does not change when a pending message gets its `messageId`.
///
/// The view is an accessibility container with the identifier
/// `user-message-<id>` and the label "You said".
public struct UserMessageView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each user message.
  public static var identifierPrefix: String { MessageRole.user.messageIdentifierPrefix }

  /// The user message entry to show.
  let entry: UserMessageEntry

  /// Makes the view of a user message entry of a session transcript.
  ///
  /// - Parameter entry: The entry to show.
  public init(entry: UserMessageEntry) {
    self.entry = entry
  }

  /// The end of the accessibility identifier of the send state of an entry.
  private static let sendStateSuffix = "-send-state"

  /// The accessibility identifier of the send state of a user message entry.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `user-message-<id>-send-state`.
  public static func sendStateIdentifier(for id: String) -> String {
    identifier(for: id) + sendStateSuffix
  }

  @Environment(\.editorStyle) private var editorStyle

  public var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
      TranscriptMessageView(entry: .user(entry))
      sendStateLabel
    }
  }

  /// The send state of the entry: pending, sent, or failed (plan.md §3.2
  /// "Prompt helper"), as a ``StatusCaption`` of its status token. The
  /// label is one accessibility element. Its label is the label of the
  /// state.
  private var sendStateLabel: some View {
    StatusCaption(status: EditorStatus(entry.sendState), identifier: Self.sendStateIdentifier(for: entry.id.rowKey))
  }
}

#Preview("User message") {
  if let entry = PreviewFixtures.firstEntry(in: .previewSample, as: UserMessageEntry.self) {
    UserMessageView(entry: entry)
  }
}
