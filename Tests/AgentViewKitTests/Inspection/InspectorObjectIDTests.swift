import EditorInspector
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks the object part of the scheme id of each inspected client model,
/// with no view: the readable text that ``InspectedClientModel`` gives
/// EditorKit's `InspectorScheme` in place of the debug description of an id
/// of FoundationModelsACP.
@Suite @MainActor struct InspectorObjectIDTests {
  /// The UUID of the local entry of the tests.
  nonisolated static let localUUID = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!

  /// The position of the unidentified entry of the tests.
  nonisolated static let position = 3

  /// Each id of a transcript entry, with the object id that it gives.
  nonisolated static let entryIDs: [(TranscriptEntry.ID, String)] = [
    (.wire(.userMessage(MessageId(rawValue: "msg_1"))), "user-message-msg_1"),
    (.wire(.agentMessage(MessageId(rawValue: "msg_1"))), "agent-message-msg_1"),
    (.wire(.agentThought(MessageId(rawValue: "msg_1"))), "thought-msg_1"),
    (.wire(.toolCall(ToolCallId(rawValue: "call_1"))), "tool-call-call_1"),
    (.wire(.terminal(TerminalId(rawValue: "term_1"))), "terminal-term_1"),
    (.wire(.plan(PlanId(rawValue: "plan_1"))), "plan-plan_1"),
    (.wire(.compaction(CompactionId(rawValue: "compact_1"))), "compaction-compact_1"),
    (.wire(.sessionMessage(MessageId(rawValue: "msg_1"))), "session-message-msg_1"),
    (.wire(.unidentified(position: position)), "position-3"),
    (.local(localUUID), "local-6F9619FF-8B86-D011-B42D-00C04FC964FF"),
  ]

  @Test(arguments: entryIDs)
  func theObjectIDOfAnEntryIsItsKindAndItsRawID(id: TranscriptEntry.ID, objectID: String) {
    #expect(id.inspectorObjectID == objectID)
  }

  @Test func theObjectIDOfAToolCallEntryIsItsKindAndItsToolCallID() throws {
    let item = PreviewTranscriptItem.toolCall(title: "Read", kind: .read, status: .completed)
    let entry = try #require(PreviewFixtures.entry(item, as: ToolCallEntry.self))
    let toolCallID = entry.toolCallId.rawValue

    #expect(InspectedClientModel(entry).id == "tool-call-\(toolCallID)")
  }

  @Test func theObjectIDOfASessionIsItsRawSessionID() {
    let session = SessionModel.preview(sessionId: SessionId(rawValue: "sess_1"))

    #expect(InspectedClientModel(session).id == "sess_1")
  }

  @Test func theSchemeEscapesTheObjectIDOfASession() {
    let session = SessionModel.preview(sessionId: SessionId(rawValue: "sess.1/a"))

    #expect(InspectorScheme.objectID(of: InspectedClientModel(session), key: "session") == "sess%2E1%2Fa")
  }
}
