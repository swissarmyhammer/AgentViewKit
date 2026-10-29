import AgentViewKitTestSupport
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The lookup of a transcript entry by its id, the lookup of the position of
/// an entry by its row key, and the objects of the tool call case and the
/// terminal case of an entry.
@Suite @MainActor struct TranscriptEntryLookupTests {
  /// The number of entries of ``openTranscript()``.
  private static let entryCount = 2

  /// The id of the tool call of the transcript.
  private static let toolCallID = TranscriptEntry.ID.wire(.toolCall(ToolCallId(rawValue: "tool-1")))

  /// The id of the terminal of the transcript.
  private static let terminalID = TranscriptEntry.ID.wire(.terminal(TerminalId(rawValue: "terminal-1")))

  /// The id of a tool call that the transcript does not hold.
  private static let missingID = TranscriptEntry.ID.wire(.toolCall(ToolCallId(rawValue: "tool-2")))

  /// A scripted session and its transcript.
  private struct Transcript {
    /// The scripted session that holds the entries.
    let session: ScriptedSession

    /// The entries of the session model: one tool call entry and one terminal
    /// entry.
    let entries: [TranscriptEntry]
  }

  /// Opens a scripted session, and sends a tool call and a terminal from the
  /// agent.
  ///
  /// - Returns: The session and its transcript.
  /// - Throws: The error of the transport.
  private static func openTranscript() async throws -> Transcript {
    let session = try await ScriptedSession.open()
    try await session.sendUpdate(WireBlockJSON.makeToolCallUpdate(id: "tool-1", fields: #""title": "Read file""#))
    try await session.sendUpdate(#"{"sessionUpdate": "terminal_update", "terminalId": "terminal-1", "command": "ls"}"#)
    let model = session.model
    await ObservationWait.until { model.transcript.count == entryCount }
    return Transcript(session: session, entries: model.transcript)
  }

  // MARK: - Entry by id

  @Test func theLookupGivesTheEntryWithTheID() async throws {
    let transcript = try await Self.openTranscript()
    defer { transcript.session.close() }

    #expect(transcript.entries.entry(withID: Self.toolCallID)?.id == Self.toolCallID)
    #expect(transcript.entries.entry(withID: Self.terminalID)?.id == Self.terminalID)
  }

  @Test func theLookupGivesNilWhenNoEntryHasTheID() async throws {
    let transcript = try await Self.openTranscript()
    defer { transcript.session.close() }

    #expect(transcript.entries.entry(withID: Self.missingID) == nil)
  }

  // MARK: - Position by row key

  @Test func theLookupGivesThePositionOfTheEntryWithTheRowKey() async throws {
    let transcript = try await Self.openTranscript()
    defer { transcript.session.close() }

    #expect(transcript.entries.position(ofRowKey: Self.toolCallID.rowKey) == 0)
    #expect(transcript.entries.position(ofRowKey: Self.terminalID.rowKey) == 1)
  }

  @Test func theLookupGivesNilWhenNoEntryHasTheRowKey() async throws {
    let transcript = try await Self.openTranscript()
    defer { transcript.session.close() }

    #expect(transcript.entries.position(ofRowKey: Self.missingID.rowKey) == nil)
  }

  // MARK: - Objects of a case

  @Test func aToolCallEntryGivesItsToolCallObjectAndNoTerminalObject() async throws {
    let transcript = try await Self.openTranscript()
    defer { transcript.session.close() }
    let entry = try #require(transcript.entries.entry(withID: Self.toolCallID))

    #expect(entry.toolCall?.id == Self.toolCallID)
    #expect(entry.terminal == nil)
  }

  @Test func aTerminalEntryGivesItsTerminalObjectAndNoToolCallObject() async throws {
    let transcript = try await Self.openTranscript()
    defer { transcript.session.close() }
    let entry = try #require(transcript.entries.entry(withID: Self.terminalID))

    #expect(entry.terminal?.id == Self.terminalID)
    #expect(entry.toolCall == nil)
  }
}
