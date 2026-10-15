import FoundationModelsACP
import FoundationModelsACPClient

extension ConnectionModel {
  /// The number of the agent requests that wait for the user on the open
  /// session model of a session: the pending elicitations and the pending
  /// permission requests.
  ///
  /// The function reads the session model through `session(for:)`, which
  /// reads the observable `openSessions`. Thus `ObservationWait` wakes when
  /// the session opens, and when a request becomes pending.
  ///
  /// - Parameter sessionId: The id of the session.
  /// - Returns: The number of the pending requests, or 0 when no session
  ///   model of the session is open.
  func pendingRequestCount(of sessionId: SessionId) -> Int {
    session(for: sessionId).map { $0.pendingElicitations.count + $0.pendingPermissions.count } ?? 0
  }
}
