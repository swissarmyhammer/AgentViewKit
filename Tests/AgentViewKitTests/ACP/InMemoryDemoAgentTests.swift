import AgentViewKit
import FoundationModelsACP
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
    let request = JSONValue.object([
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

  @Test func aSessionUpdateFrameHoldsTheParamsInAJSONRPCNotification() throws {
    let params = JSONValue.object([
      "sessionId": .string(InMemoryDemoAgent.sessionID),
      "update": .object(["sessionUpdate": .string("state_update"), "state": .string("idle")]),
    ])

    let frame = try JSONValue(json: ScriptedWireAgent.makeSessionUpdateFrame(params: params))

    #expect(
      frame
        == .object([
          "jsonrpc": .string("2.0"),
          "method": .string("session/update"),
          "params": params,
        ]))
  }

  @Test func eachTurnFrameIsTheSessionUpdateFrameOfItsNotification() {
    let request = JSONValue.object([
      "params": .object([
        "sessionId": .string(InMemoryDemoAgent.sessionID),
        "prompt": .array([ScriptedWireAgent.textBlock(text: "hello")]),
      ])
    ])

    let frames = InMemoryDemoAgent.turnFrames(for: request, turn: 1)

    let expected = InMemoryDemoAgent.turnNotifications(for: request, turn: 1)
      .map(ScriptedWireAgent.makeSessionUpdateFrame(params:))
    #expect(!frames.isEmpty)
    #expect(frames == expected)
  }
}
