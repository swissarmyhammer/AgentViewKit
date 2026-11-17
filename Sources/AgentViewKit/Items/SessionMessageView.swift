import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The default view of a message between two sessions of the same agent.
///
/// The view shows a line that names the sender, and the content blocks of the
/// message. It reads the entry object each time that it draws, and it keeps
/// no copy.
///
/// The sender comes from `_meta.sah.message` of the entry (D199 (f)). A
/// message that the user wrote in another session shows "From the user, in
/// <title>". A message from another session shows "From <title>". The title
/// of a session is the title in the `_meta`, else the title that the host
/// gives (``SwiftUI/View/sessionTitles(_:)``), else the raw id. An entry with
/// no such `_meta` names both sessions: "From <sender> to <recipient>". A
/// session that the agent did not name shows as "another session".
///
/// The view is an accessibility container with the identifier
/// `session-message-<id>`.
public struct SessionMessageView: View {
  /// The start of the accessibility identifier of each session message.
  public static let identifierPrefix = "session-message-"

  /// The space between the line of the participants and the content.
  private static let spacing: CGFloat = 4

  /// The entry to show.
  let entry: SessionMessageEntry

  /// The titles of the sessions that the host gives.
  @Environment(\.sessionTitles) private var titles

  /// Makes the view of a session message entry.
  ///
  /// - Parameter entry: The entry to show.
  public init(entry: SessionMessageEntry) {
    self.entry = entry
  }

  /// The sender of a message in the `_meta` of its entry.
  ///
  /// - Parameter meta: The `_meta` of the entry, or `nil`.
  /// - Returns: The `_meta.sah.message` object, or `nil`.
  static func sender(in meta: JSONValue?) -> SAH.SessionMessage? {
    SAH.SessionMessage.extract(from: meta)
  }

  /// The line that names the sender of the message.
  ///
  /// - Parameters:
  ///   - sender: The id of the sender session, or `nil`.
  ///   - recipient: The id of the recipient session, or `nil`.
  ///   - message: The `_meta.sah.message` object of the entry, or `nil`.
  ///   - titles: The titles of the sessions that the host gives.
  /// - Returns: Text such as "From the user, in Fix the parser", "From
  ///   planner", or "From s1 to s2".
  static func participantsText(
    sender: SessionId?, recipient: SessionId?, message: SAH.SessionMessage? = nil,
    titles: SessionTitles = SessionTitles()
  ) -> String {
    if let message {
      let session = message.sender.sessionId ?? sender
      let title = name(of: session, metaTitle: message.sender.title, titles: titles)
      switch message.sender.kind {
      case .user:
        return session == nil && message.sender.title == nil
          ? String(localized: "From the user", bundle: .module)
          : String(localized: "From the user, in \(title)", bundle: .module)
      case .session:
        return String(localized: "From \(title)", bundle: .module)
      default:
        break
      }
    }
    let from = name(of: sender, metaTitle: nil, titles: titles)
    let to = name(of: recipient, metaTitle: nil, titles: titles)
    return String(localized: "From \(from) to \(to)", bundle: .module)
  }

  /// The name of a session in the sender line.
  ///
  /// - Parameters:
  ///   - session: The id of the session, or `nil`.
  ///   - metaTitle: The title in the `_meta`, or `nil`.
  ///   - titles: The titles of the sessions that the host gives.
  /// - Returns: The title of the `_meta`, else the title of the host, else
  ///   the raw id, else "another session".
  static func name(of session: SessionId?, metaTitle: String?, titles: SessionTitles) -> String {
    if let metaTitle { return metaTitle }
    guard let session else { return String(localized: "another session", bundle: .module) }
    return titles.title(session) ?? session.rawValue
  }

  /// The line of the participants, and the content of the message.
  public var body: some View {
    let participants = Self.participantsText(
      sender: entry.senderSessionId, recipient: entry.recipientSessionId, message: Self.sender(in: entry.meta),
      titles: titles)
    VStack(alignment: .leading, spacing: Self.spacing) {
      EditorLabel(verbatim: participants).editorTextColor(.secondary)
        .font(.caption)
        .foregroundStyle(.secondary)
      EntryContentView(content: entry.content, id: "\(Self.identifierPrefix)\(entry.messageId.rawValue)")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(participants)
    .accessibilityIdentifier("\(Self.identifierPrefix)\(entry.messageId.rawValue)")
  }
}

/// The titles of sessions that a host gives to the transcript (D199 (f)).
public struct SessionTitles {
  /// Gives the title of a session, or `nil` when the host does not know it.
  let title: @MainActor (SessionId) -> String?

  /// Makes the titles of a host.
  ///
  /// - Parameter title: Gives the title of a session, or `nil`.
  public init(_ title: @escaping @MainActor (SessionId) -> String?) {
    self.title = title
  }

  /// No title: each session shows its title from the `_meta`, or its id.
  init() {
    title = { _ in nil }
  }
}

extension EnvironmentValues {
  /// The titles of sessions that the host gives
  /// (``SwiftUI/View/sessionTitles(_:)``).
  @Entry var sessionTitles = SessionTitles()
}

extension View {
  /// Gives the titles of sessions to the transcript below this view.
  ///
  /// A message from another session (``SessionMessageView``) names its
  /// sender with the title in the `_meta` of the message. When the `_meta`
  /// has no title, the view asks `title`. When `title` gives `nil`, the view
  /// shows the raw id of the session.
  ///
  /// - Parameter title: Gives the title of a session, or `nil`.
  /// - Returns: A view with the titles in its environment.
  public func sessionTitles(_ title: @escaping @MainActor (SessionId) -> String?) -> some View {
    environment(\.sessionTitles, SessionTitles(title))
  }
}
