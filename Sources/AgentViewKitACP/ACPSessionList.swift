import AgentViewKit
import Foundation
import FoundationModelsACP

/// The session pages of an ACP agent (plan.md §9 A).
///
/// ``page(after:)`` sends `session/list` with the working directory filter
/// and the cursor of the previous page. ``delete(_:)`` sends
/// `session/delete`. Give ``delete(_:)`` to the `onDelete` closure of
/// ``SessionListView`` when the agent supports `session/delete`.
public final class ACPSessionList: SessionListProvider {
  /// The connection that sends the requests to the agent.
  private let connection: ClientSideConnection

  /// The working directory that filters the sessions, or `nil` for each
  /// session of the agent.
  public let cwd: String?

  /// Makes a session page source.
  ///
  /// - Parameters:
  ///   - connection: The connection that sends the requests to the agent.
  ///   - cwd: The absolute path of the working directory that filters the
  ///     sessions, or `nil` for each session of the agent.
  public init(connection: ClientSideConnection, cwd: String? = nil) {
    self.connection = connection
    self.cwd = cwd
  }

  public func page(after cursor: String?) async throws -> (sessions: [SessionSummary], next: String?) {
    let request = ListSessionsRequest(
      cursor: cursor.map(SessionListCursor.init(rawValue:)),
      cwd: cwd.map(AbsolutePath.init(rawValue:)))
    let response = try await connection.listSessions(request)
    return (response.sessions.map(Self.summary), response.nextCursor?.rawValue)
  }

  /// Sends `session/delete` for one session.
  ///
  /// - Parameter id: The identifier of the session to delete.
  /// - Throws: The error of the connection when the agent refuses the
  ///   request or the connection closes.
  public func delete(_ id: SessionID) async throws {
    _ = try await connection.deleteSession(DeleteSessionRequest(sessionId: SessionId(rawValue: id.rawValue)))
  }

  /// The kit summary of an ACP session.
  ///
  /// - Parameter info: The session from `session/list`.
  /// - Returns: The summary. A title of only white space is `nil`. An
  ///   `updatedAt` that is not an RFC 3339 time is `nil`.
  static func summary(_ info: SessionInfo) -> SessionSummary {
    let title = info.title.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    return SessionSummary(
      id: SessionID(info.sessionId.rawValue),
      title: title,
      cwd: info.cwd.rawValue,
      updatedAt: info.updatedAt.flatMap(ISO8601Time.date(from:)))
  }
}
