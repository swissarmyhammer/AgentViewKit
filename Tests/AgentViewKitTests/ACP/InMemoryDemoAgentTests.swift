import AgentViewKit
import Testing

@testable import DemoSupport

/// The tests of the script of the in-memory demo agent.
struct InMemoryDemoAgentTests {
  @Test func theChunksOfAReplyJoinToTheReply() {
    let reply = InMemoryDemoAgent.replyText(to: "hello")

    let chunks = InMemoryDemoAgent.chunks(of: reply)

    #expect(chunks.count == InMemoryDemoAgent.replyChunkCount)
    #expect(chunks.joined() == reply)
    #expect(InMemoryDemoAgent.chunks(of: "a") == ["a"])
  }

  @Test func thePromptTextJoinsTheTextBlocks() {
    let request = AgentViewKit.JSONValue.object([
      "params": .object([
        "prompt": .array([
          .object(["type": .string("text"), "text": .string("he")]),
          .object(["type": .string("resource_link"), "uri": .string("file:///a")]),
          .object(["type": .string("text"), "text": .string("llo")]),
        ])
      ])
    ])

    #expect(ScriptedWireAgent.promptText(of: request) == "hello")
    #expect(ScriptedWireAgent.promptText(of: .object([:])).isEmpty)
  }
}
