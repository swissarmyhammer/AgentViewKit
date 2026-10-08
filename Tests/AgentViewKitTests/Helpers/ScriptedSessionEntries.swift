import AgentViewKitTestSupport
import FoundationModelsACPClient
import Testing

/// The shared send-and-wait helpers of the hosted test suites.
///
/// A suite that tests one view over one transcript entry calls
/// ``openWithEntry(update:lookingUp:)``, and keeps no copy of the open,
/// send, wait and look-up steps of its own.
extension ScriptedSession {
  /// Opens a scripted session, sends one `session/update` from the agent,
  /// and waits until the session model holds the entry that `lookup` finds.
  ///
  /// When a step fails, the helper closes the session before it throws.
  ///
  /// - Parameters:
  ///   - update: The JSON text of the update.
  ///   - lookup: Finds the entry in the session model, or gives `nil` while
  ///     the model has no such entry.
  /// - Returns: The open session and the entry.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no entry at the time limit.
  static func openWithEntry<Entry>(
    update: String,
    lookingUp lookup: (SessionModel) -> Entry?
  ) async throws -> (ScriptedSession, Entry) {
    let session = try await open()
    do {
      return (session, try await session.receiveEntry(update: update, lookingUp: lookup))
    } catch {
      session.close()
      throw error
    }
  }

  /// Sends one `session/update` from the agent, and waits until the session
  /// model holds the entry that `lookup` finds.
  ///
  /// - Parameters:
  ///   - update: The JSON text of the update.
  ///   - lookup: Finds the entry in the session model, or gives `nil` while
  ///     the model has no such entry.
  /// - Returns: The entry.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no entry at the time limit.
  func receiveEntry<Entry>(
    update: String,
    lookingUp lookup: (SessionModel) -> Entry?
  ) async throws -> Entry {
    try await sendUpdate(update)
    let model = model
    try #require(await waitUntil { lookup(model) != nil })
    return try #require(lookup(model))
  }
}
