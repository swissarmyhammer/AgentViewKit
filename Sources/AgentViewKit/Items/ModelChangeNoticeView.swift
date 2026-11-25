import AgentViewKitStyle
import EditorStyle
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// A notice of the agent that tells that a resume moved a session to a
/// different model (TestudoApp request, 2026-11-24).
///
/// The agent sends the notice as `session/update` `notice` with `_meta`
/// `kind` `modelChanged`. Its `_meta` `afterMessageId` is the `messageId` of
/// the last user message, agent message or thought of the history. The field
/// is absent when the history has no message. The `SessionModel` puts the
/// notice in `notices`, and not in the transcript. The agent keeps the notice
/// in the history, so each resume gives it again.
struct ModelChangeNotice: Equatable, Sendable {
  /// The `_meta` key of the kind of a notice.
  static let kindKey = "kind"

  /// The `_meta` kind of a modelChanged notice.
  static let kind = "modelChanged"

  /// The `_meta` key of the message after which the notice stands.
  static let afterMessageIdKey = "afterMessageId"

  /// The title of the notice.
  let title: String

  /// The message after which the notice stands, or `nil` when the history
  /// has no message.
  let afterMessageId: MessageId?

  /// Reads a modelChanged notice.
  ///
  /// - Parameter notice: A notice of the session.
  /// - Returns: The notice, or `nil` when its `_meta` `kind` is not
  ///   `modelChanged`.
  init?(_ notice: SessionNotice) {
    guard case .object(let meta)? = notice.meta, meta[Self.kindKey] == .string(Self.kind) else { return nil }
    title = notice.title
    afterMessageId = Self.messageId(in: meta)
  }

  /// The `afterMessageId` of the `_meta` of a notice.
  ///
  /// - Parameter meta: The members of the `_meta` object.
  /// - Returns: The message id, or `nil` when the member is absent or is not
  ///   a string.
  private static func messageId(in meta: [String: JSONValue]) -> MessageId? {
    guard case .string(let rawValue)? = meta[afterMessageIdKey] else { return nil }
    return MessageId(rawValue: rawValue)
  }

  /// Whether a notice is a modelChanged notice.
  ///
  /// - Parameter notice: A notice of the session.
  /// - Returns: `true` when the `_meta` `kind` of the notice is
  ///   `modelChanged`.
  static func isModelChange(_ notice: SessionNotice) -> Bool {
    Self(notice) != nil
  }

  /// The modelChanged notices of a session, in arrival order.
  ///
  /// - Parameter notices: The notices of a session, such as
  ///   `SessionModel.notices`.
  /// - Returns: The modelChanged notices. A notice of another kind gives
  ///   nothing.
  static func notices(in notices: [SessionNotice]) -> [ModelChangeNotice] {
    notices.compactMap(Self.init)
  }

  /// The place of the notice in a transcript.
  ///
  /// The notice stands after the entry whose wire identity is the user
  /// message, the agent message or the thought of ``afterMessageId``. Each
  /// kind of message has its own id space, so two entries can have the id.
  /// The notice then stands after the later entry, because the id is that of
  /// the last message of the history. With no ``afterMessageId``, or with an
  /// id that no entry has, the notice stands before the first entry.
  ///
  /// - Parameter transcript: The entries of the transcript.
  /// - Returns: The place.
  func place(in transcript: [TranscriptEntry]) -> ModelChangePlace {
    guard let afterMessageId else { return .start }
    let ids: Set<TranscriptEntry.ID> = [
      .wire(.userMessage(afterMessageId)), .wire(.agentMessage(afterMessageId)),
      .wire(.agentThought(afterMessageId)),
    ]
    guard let entry = transcript.last(where: { ids.contains($0.id) }) else { return .start }
    return .after(entry.id)
  }
}

/// The place of the status line of a ``ModelChangeNotice`` in a transcript.
enum ModelChangePlace: Hashable, Sendable {
  /// Before the first entry.
  case start

  /// After the entry with this identity.
  case after(TranscriptEntry.ID)

  /// The text form of the place: `start`, or the row key of the entry.
  ///
  /// The row key holds the `afterMessageId` of the notice and the kind of
  /// its entry. A replay gives the same key, and no row key is `start`.
  var key: String {
    switch self {
    case .start: "start"
    case .after(let id): id.rowKey
    }
  }
}

/// The status line of one ``ModelChangeNotice`` at its place.
struct ModelChangeLine: Equatable, Identifiable, Sendable {
  /// The identity of a status line: its place, and its index at that place.
  struct ID: Hashable, Sendable {
    /// The place of the line.
    let place: ModelChangePlace

    /// The index of the line among the lines at its place, in arrival order.
    let index: Int
  }

  /// The identity of the line.
  let id: ID

  /// The title of the notice.
  let title: String

  /// The accessibility identifier of the text of the line:
  /// `model-change-<place key>-<index>`.
  ///
  /// The identifier comes from the place and the index, and not from the
  /// `UUID` of the `SessionNotice`. Thus a replay of the same history gives
  /// the same identifier.
  var identifier: String {
    AccessibilityIdentifier.make(
      prefix: ModelChangeNoticeView.identifierPrefix, value: "\(id.place.key)-\(id.index)")
  }
}

/// The status lines of the modelChanged notices of a transcript, at their
/// places.
struct ModelChangePlacements: Equatable, Sendable {
  /// The lines at each place, in arrival order.
  private let linesByPlace: [ModelChangePlace: [ModelChangeLine]]

  /// Places the modelChanged notices of a session in its transcript.
  ///
  /// With no modelChanged notice, the placements read no entry of the
  /// transcript. Two notices at one place keep their arrival order.
  ///
  /// - Parameters:
  ///   - notices: The notices of the session, in arrival order. A notice of
  ///     another kind gets no line.
  ///   - transcript: The entries of the transcript.
  init(notices: [SessionNotice], transcript: [TranscriptEntry]) {
    let placed = ModelChangeNotice.notices(in: notices).map { notice in
      (place: notice.place(in: transcript), title: notice.title)
    }
    linesByPlace = Dictionary(grouping: placed, by: \.place).mapValues { group in
      group.enumerated().map { index, notice in
        ModelChangeLine(id: ModelChangeLine.ID(place: notice.place, index: index), title: notice.title)
      }
    }
  }

  /// Whether no status line has a place.
  var isEmpty: Bool {
    linesByPlace.isEmpty
  }

  /// The status lines at a place.
  ///
  /// - Parameter place: The place.
  /// - Returns: The lines, in arrival order. A place with no line gives an
  ///   empty array.
  func lines(at place: ModelChangePlace) -> [ModelChangeLine] {
    linesByPlace[place] ?? []
  }
}

/// The status line of a modelChanged notice in the transcript.
///
/// The line is a ``StatusBar`` with the information symbol and the title of
/// the notice, and no button: the notice tells of the history, so it is not
/// dismissible. The line is content, so it has the
/// ``StatusBarPlacement/content`` surface: a separator stroke, no fill and no
/// glass (TestudoApp D213). ``ConversationView`` shows the line after the row
/// of its entry, and ``SessionNoticeBanner`` shows no banner for the notice.
struct ModelChangeNoticeView: View {
  /// The start of the accessibility identifier of the text of each line.
  static let identifierPrefix = "model-change-"

  /// The severity of each line.
  private static let severity = NoticeSeverity.info

  /// The status line to show.
  let line: ModelChangeLine

  var body: some View {
    StatusBar(
      message: StatusBar.Message(
        title: line.title, explanation: "", symbolName: NoticeBanner.symbolName(for: Self.severity),
        identifier: line.identifier, severity: StatusBar.Message.Severity(notice: Self.severity),
        symbolHelp: NoticeBanner.severityLabel(Self.severity)),
      action: nil
    )
    .statusBarPlacement(.content)
  }
}

#Preview("A modelChanged notice") {
  let notice = Notice(
    severity: .info, title: "This session was recorded with model-a. It continues with model-b.",
    meta: .object([ModelChangeNotice.kindKey: .string(ModelChangeNotice.kind)]))
  let session = SessionModel.preview(transcript: [.update(.notice(notice))])
  let placements = ModelChangePlacements(notices: session.notices, transcript: session.transcript)
  ForEach(placements.lines(at: .start)) { line in
    ModelChangeNoticeView(line: line)
  }
}
