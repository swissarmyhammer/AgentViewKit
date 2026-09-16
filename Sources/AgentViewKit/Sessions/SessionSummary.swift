import Foundation

/// The identifier of a session in a session list.
public typealias SessionID = Identifier<SessionSummary>

/// One session in a session list (plan.md §9 A).
///
/// The type does not know the source runtime. An adapter target makes each
/// summary from the session data of its runtime, such as an ACP
/// `SessionInfo` from `session/list`.
public nonisolated struct SessionSummary: Sendable, Hashable, Identifiable {
  /// The identifier of the session.
  public var id: SessionID

  /// The title of the session, or `nil` when the source gives no title.
  public var title: String?

  /// The working directory of the session.
  public var cwd: String

  /// The time of the last activity, or `nil` when the source gives no time.
  public var updatedAt: Date?

  /// Makes a session summary.
  ///
  /// - Parameters:
  ///   - id: The identifier of the session.
  ///   - title: The title of the session.
  ///   - cwd: The working directory of the session.
  ///   - updatedAt: The time of the last activity.
  public init(id: SessionID, title: String? = nil, cwd: String, updatedAt: Date? = nil) {
    self.id = id
    self.title = title
    self.cwd = cwd
    self.updatedAt = updatedAt
  }

  /// Tells whether the title or the working directory contains `query`.
  ///
  /// The comparison ignores case and diacritics. An empty query, or a query
  /// of only white space, matches each session.
  ///
  /// - Parameter query: The text to find.
  /// - Returns: `true` when the session matches `query`.
  public func matches(_ query: String) -> Bool {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return true }
    return [title ?? "", cwd].contains { $0.localizedStandardContains(needle) }
  }
}

/// A source of session pages for ``SessionListView`` (plan.md §9 A).
///
/// A source gives the sessions one page at a time. Each page gives the
/// cursor of the next page, or `nil` when the page is the last page.
public protocol SessionListProvider: AnyObject {
  /// Gets one page of sessions.
  ///
  /// - Parameter cursor: The cursor that the previous page gave, or `nil`
  ///   for the first page.
  /// - Returns: The sessions of the page and the cursor of the next page.
  ///   The cursor is `nil` when there is no next page.
  /// - Throws: The error of the source when it cannot get the page.
  func page(after cursor: String?) async throws -> (sessions: [SessionSummary], next: String?)
}
