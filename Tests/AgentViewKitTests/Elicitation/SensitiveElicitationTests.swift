@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import Testing

/// A sensitive elicitation: the agent asks for a secret with
/// `"sensitive": true` in the `_meta` of `elicitation/create`. The answer
/// stays in no undo history, no model and no log after the send.
@Suite(.serialized) @MainActor struct SensitiveElicitationTests {
  /// The secret answer of the tests.
  static let secret = "sk-test-\(UUID().uuidString)"

  /// The params of a sensitive form request with one text field.
  static let sensitiveParams = #"""
    {"sessionId": "\#(ScriptedSession.sessionID)", "message": "The API key of the server?", "mode": "form",
     "_meta": {"sensitive": true},
     "requestedSchema": {"type": "object", "properties": {"apiKey": {"type": "string"}}, "required": ["apiKey"]}}
    """#

  /// The JSON-RPC id of the request of the agent.
  static let requestID = 7_001

  @Test func sensitiveMetaMarksTheRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model

    try await session.sendRequest(ScriptedSession.elicitationMethod, id: Self.requestID, params: Self.sensitiveParams)
    await ObservationWait.until { !model.pendingElicitations.isEmpty }

    #expect(try #require(model.pendingElicitations.first).isSensitive)
  }

  @Test func requestWithNoSensitiveMetaIsNotSensitive() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model

    try await session.sendRequest(
      ScriptedSession.elicitationMethod, id: Self.requestID, params: ScriptedSession.formElicitationParams)
    await ObservationWait.until { !model.pendingElicitations.isEmpty }

    #expect(try #require(model.pendingElicitations.first).isSensitive == false)
  }

  @Test func sensitiveFieldModelKeepsNoUndoHistory() {
    let sensitive = OwnModelSlot(editable: true).model(text: "", recordsUndo: false)
    sensitive.replaceAll(Self.secret)
    sensitive.finalizeUndoGroup()
    #expect(sensitive.text == Self.secret)
    #expect(!sensitive.canUndo)
    #expect(sensitive.undoTop == nil)

    // A field that is not sensitive keeps its undo history.
    let plain = OwnModelSlot(editable: true).model(text: "")
    plain.replaceAll("text")
    plain.finalizeUndoGroup()
    #expect(plain.canUndo)
  }

  @Test func acceptedSensitiveAnswerIsNotInTheModelOrTheLog() async throws {
    let start = Date()
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    try await session.sendRequest(ScriptedSession.elicitationMethod, id: Self.requestID, params: Self.sensitiveParams)
    await ObservationWait.until { !model.pendingElicitations.isEmpty }
    let request = try #require(model.pendingElicitations.first)

    model.acceptElicitation(request.id, content: .object(["apiKey": .string(Self.secret)]))
    await ObservationWait.until { model.pendingElicitations.isEmpty }

    var dumped = ""
    dump(model, to: &dumped)
    #expect(!dumped.contains(Self.secret))
    // The marker shows that the read of the log works, so that the check of
    // the secret is not a check of an empty list.
    let marker = "sensitive-elicitation-marker-\(UUID().uuidString)"
    Logger(subsystem: "AgentViewKitTests", category: "SensitiveElicitation").error("\(marker, privacy: .public)")
    let messages = try Self.logMessages(since: start)
    #expect(messages.contains { $0.contains(marker) })
    #expect(messages.allSatisfy { !$0.contains(Self.secret) })
  }

  /// The log messages of this process since a time.
  static func logMessages(since date: Date) throws -> [String] {
    let store = try OSLogStore(scope: .currentProcessIdentifier)
    return try store.getEntries(at: store.position(date: date)).compactMap { ($0 as? OSLogEntryLog)?.composedMessage }
  }
}
