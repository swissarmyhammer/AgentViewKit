import FoundationModelsACPClient

/// The model whose rows a ``ConversationView`` shows.
///
/// The list, the pages and the scroll anchors read the rows through the text
/// key of each row: the item id of a thread item, or the
/// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey`` of a transcript
/// entry.
enum ConversationSource {
  /// The items of an ``AgentThread``.
  case thread(AgentThread)

  /// The transcript of a `SessionModel` (update.md §4.2).
  case session(SessionModel)

  /// The thread, or `nil` for a session.
  var thread: AgentThread? {
    if case .thread(let thread) = self { thread } else { nil }
  }

  /// The session model, or `nil` for a thread.
  var session: SessionModel? {
    if case .session(let session) = self { session } else { nil }
  }

  /// The number of rows.
  var rowCount: Int {
    switch self {
    case .thread(let thread): thread.items.count
    case .session(let session): session.transcript.count
    }
  }

  /// The key of each row, in order.
  var rowKeys: [String] {
    switch self {
    case .thread(let thread): thread.items.map(\.id)
    case .session(let session): session.transcript.map(\.rowKey)
    }
  }

  /// The key of the last row, or `nil` when there is no row.
  var lastRowKey: String? {
    switch self {
    case .thread(let thread): thread.lastItemID
    case .session(let session): session.transcript.last?.rowKey
    }
  }

  /// The position of the row with `key`.
  ///
  /// - Parameter key: The key of a row.
  /// - Returns: The position, or `nil` when no row has the key.
  func position(of key: String) -> Int? {
    switch self {
    case .thread(let thread): thread.position(of: key)
    case .session(let session): session.transcript.firstIndex { $0.rowKey == key }
    }
  }
}
