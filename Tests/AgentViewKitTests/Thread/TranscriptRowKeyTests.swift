import AgentViewKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// The text key of the row of a transcript entry (plan.md §3.2 "Row
/// identity").
@Suite struct TranscriptRowKeyTests {
  @Test func aThoughtAndAnAgentMessageWithOneMessageIDHaveTwoKeys() {
    let messageID = MessageId(rawValue: "m1")
    let thought = TranscriptEntry.ID.wire(.agentThought(messageID)).rowKey
    let message = TranscriptEntry.ID.wire(.agentMessage(messageID)).rowKey

    #expect(thought != message)
  }

  @Test func aLocalEntryKeepsTheKeyOfItsUUID() {
    let uuid = UUID()

    #expect(TranscriptEntry.ID.local(uuid).rowKey == TranscriptEntry.ID.local(uuid).rowKey)
    #expect(TranscriptEntry.ID.local(uuid).rowKey != TranscriptEntry.ID.local(UUID()).rowKey)
  }

  @Test func eachWireKindGivesADifferentKeyForOneRawValue() {
    let raw = "same"
    let ids: [SessionEntry.ID] = [
      .userMessage(MessageId(rawValue: raw)),
      .agentMessage(MessageId(rawValue: raw)),
      .agentThought(MessageId(rawValue: raw)),
      .toolCall(ToolCallId(rawValue: raw)),
      .terminal(TerminalId(rawValue: raw)),
      .plan(PlanId(rawValue: raw)),
      .compaction(Unstable.CompactionId(rawValue: raw)),
      .unidentified(position: 0),
    ]

    let keys = ids.map { TranscriptEntry.ID.wire($0).rowKey }

    #expect(Set(keys).count == ids.count, "\(keys)")
  }
}
