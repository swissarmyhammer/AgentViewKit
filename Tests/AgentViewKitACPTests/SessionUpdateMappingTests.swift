import AgentViewKit
import AgentViewKitACP
import Foundation
import FoundationModelsACP
import Testing

/// The id that the tests give to each new unknown record.
private let unknownID = "unknown-1"

/// The time `2026-09-16T10:00:00Z` of the session info fixture.
private let sessionTime = Date(timeIntervalSince1970: 1_789_552_800)

/// The fractional seconds of the second session info fixture.
private let halfSecond: TimeInterval = 0.5

/// Maps each fixture, applies the changes to a new thread, and gives the
/// thread.
@MainActor
private func thread(applying fixtures: String...) throws -> AgentThread {
  let thread = AgentThread()
  for fixture in fixtures {
    let update = try SessionUpdateFixtures.decode(fixture)
    for change in SessionUpdateMapping.changes(for: update, makeUnknownID: { unknownID }) {
      thread.apply(change)
    }
  }
  return thread
}

/// Decodes one ACP content block and maps it.
@MainActor
private func mappedBlock(_ json: String) throws -> AgentViewKit.ContentBlock {
  SessionUpdateMapping.contentBlock(
    try SessionUpdateFixtures.decode(FoundationModelsACP.ContentBlock.self, json))
}

/// A pending permission request that a test makes.
private struct TestPermission: PendingPermissionRequestValue {
  var id: UUID
  var request: RequestPermissionRequest
}

/// A pending elicitation that a test makes.
private struct TestElicitation: PendingElicitationValue {
  var id: UUID
  var request: CreateElicitationRequest
}

@MainActor
@Suite struct SessionUpdateMappingTests {
  // MARK: - Coverage

  @Test func eachSessionUpdateCaseHasAFixture() throws {
    #expect(SessionUpdateFixtures.byTag.count == 17)
    for (tag, fixture) in SessionUpdateFixtures.byTag {
      let update = try SessionUpdateFixtures.decode(fixture)
      #expect(SessionUpdateFixtures.tag(of: update) == tag)
      #expect(!SessionUpdateMapping.changes(for: update).isEmpty, "\(tag) gives no change")
    }
  }

  // MARK: - Messages

  @Test func userMessageChunkAddsABlockAndKeepsTheMeta() throws {
    let thread = try thread(applying: SessionUpdateFixtures.userMessageChunk)

    guard case .userMessage(let message)? = thread.item(id: "u1") else {
      Issue.record("The thread has no user message u1.")
      return
    }
    #expect(message.blocks == [AgentViewKit.ContentBlock(text: "Fix the bug.")])
    #expect(message.meta == .object(["source": .string("replay")]))
  }

  @Test func userMessageReplacesTheContent() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.userMessageChunk, SessionUpdateFixtures.userMessage)

    guard case .userMessage(let message)? = thread.item(id: "u1") else {
      Issue.record("The thread has no user message u1.")
      return
    }
    #expect(message.blocks == [AgentViewKit.ContentBlock(text: "Fix it.")])
    #expect(message.meta == .object(["edited": .bool(true)]))
    #expect(thread.items.count == 1)
  }

  @Test func agentMessageChunkAddsABlockToTheAssistantMessage() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.agentMessageChunk, SessionUpdateFixtures.agentMessageChunk)

    guard case .assistantMessage(let message)? = thread.item(id: "m1") else {
      Issue.record("The thread has no assistant message m1.")
      return
    }
    #expect(message.blocks == [AgentViewKit.ContentBlock(text: "Hello"), AgentViewKit.ContentBlock(text: "Hello")])
  }

  @Test func agentMessageReplacesTheContentAndANullClearsIt() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.agentMessageChunk, SessionUpdateFixtures.agentMessage)
    guard case .assistantMessage(let message)? = thread.item(id: "m1") else {
      Issue.record("The thread has no assistant message m1.")
      return
    }
    #expect(message.blocks == [AgentViewKit.ContentBlock(text: "Done.")])
    #expect(message.meta == .object(["model": .string("a")]))

    let clear = try SessionUpdateFixtures.decode(
      #"{"sessionUpdate": "agent_message", "messageId": "m1", "content": null}"#)
    for change in SessionUpdateMapping.changes(for: clear) {
      thread.apply(change)
    }

    #expect(message.blocks.isEmpty)
    #expect(message.meta == .object(["model": .string("a")]))
  }

  @Test func agentThoughtChunkAddsASegment() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.agentThoughtChunk, SessionUpdateFixtures.agentThoughtChunk)

    guard case .reasoning(let reasoning)? = thread.item(id: "t1") else {
      Issue.record("The thread has no reasoning t1.")
      return
    }
    #expect(reasoning.segments == ["Think", "Think"])
  }

  @Test func agentThoughtChunkWithAnImageAddsAnUnknownRecordAfterTheReasoning() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.agentThoughtChunk,
      #"""
      {"sessionUpdate": "agent_thought_chunk", "messageId": "t1",
       "content": {"type": "image", "data": "AAE=", "mimeType": "image/png"}}
      """#
    )

    #expect(thread.items.map(\.id) == ["t1", "t1#content"])
    guard case .unknown(let record)? = thread.item(id: "t1#content") else {
      Issue.record("The thread has no unknown record for the thought image.")
      return
    }
    #expect(record.kind == "agent_thought_chunk")
    #expect(record.raw["content"]?["mimeType"] == .string("image/png"))
  }

  @Test func agentThoughtSetsTheSegmentsFromTheTextBlocks() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.agentThoughtChunk, SessionUpdateFixtures.agentThought)

    guard case .reasoning(let reasoning)? = thread.item(id: "t1") else {
      Issue.record("The thread has no reasoning t1.")
      return
    }
    #expect(reasoning.segments == ["Plan", "Act"])
    #expect(thread.items.count == 1)
  }

  // MARK: - State

  @Test func stateUpdateIdleKeepsTheStopReason() throws {
    let thread = try thread(applying: SessionUpdateFixtures.stateIdle)

    #expect(thread.state == .idle(.maxTokens))
  }

  @Test func stateUpdateRunningAndRequiresActionSetTheState() throws {
    let running = try thread(applying: #"{"sessionUpdate": "state_update", "state": "running"}"#)
    let waiting = try thread(
      applying: #"{"sessionUpdate": "state_update", "state": "requires_action"}"#)
    let idle = try thread(applying: #"{"sessionUpdate": "state_update", "state": "idle"}"#)

    #expect(running.state == .running)
    #expect(waiting.state == .requiresAction)
    #expect(idle.state == .idle(nil))
  }

  @Test func stateUpdateWithAnUnknownStateAddsAnUnknownRecord() throws {
    let thread = try thread(
      applying: #"{"sessionUpdate": "state_update", "state": "paused", "reason": "user"}"#)

    guard case .unknown(let record)? = thread.item(id: unknownID) else {
      Issue.record("The thread has no unknown record.")
      return
    }
    #expect(record.kind == "state_update/paused")
    #expect(record.raw["reason"] == .string("user"))
    #expect(thread.state == .idle(nil))
  }

  // MARK: - Tool calls

  @Test func toolCallUpdateForAnUnseenIdMakesANewRecord() throws {
    let thread = try thread(applying: SessionUpdateFixtures.toolCallUpdate)

    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("The thread has no tool call c1.")
      return
    }
    #expect(call.title == "Read file")
    #expect(call.kind == .read)
    #expect(call.status == .lost)
    #expect(call.content == [.block(AgentViewKit.ContentBlock(text: "body")), .terminal(id: "term1")])
    #expect(call.locations == [AgentViewKit.ToolCallLocation(path: "/tmp/a.swift", line: 3)])
    #expect(call.rawInput == .object(["path": .string("/tmp/a.swift")]))
    #expect(call.rawOutput == nil)
    #expect(call.meta == .object(["x": .number(1)]))
  }

  @Test func toolCallUpdatePatchesOnlyTheGivenFields() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.toolCallUpdate,
      #"{"sessionUpdate": "tool_call_update", "toolCallId": "c1", "status": "completed", "title": null}"#
    )

    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("The thread has no tool call c1.")
      return
    }
    #expect(call.status == .completed)
    #expect(call.title.isEmpty)
    #expect(call.kind == .read)
    #expect(call.revision == 1)
  }

  @Test func toolCallStatusThatIsNotKnownGivesUnknown() throws {
    let thread = try thread(
      applying: #"{"sessionUpdate": "tool_call_update", "toolCallId": "c2", "status": "_paused"}"#)

    guard case .toolCall(let call)? = thread.item(id: "c2") else {
      Issue.record("The thread has no tool call c2.")
      return
    }
    #expect(call.status == .unknown("_paused"))
  }

  @Test func toolCallContentChunkAddsADiffAndKeepsTheMeta() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.toolCallUpdate, SessionUpdateFixtures.toolCallDiffChunk)

    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("The thread has no tool call c1.")
      return
    }
    #expect(call.content.last == .diff(patch: "--- a\n+++ b\n"))
    #expect(call.meta == .object(["chunk": .number(1)]))
  }

  @Test func toolCallContentChunkWithADiffWithNoPatchKeepsTheJSON() throws {
    let thread = try thread(
      applying: #"""
        {"sessionUpdate": "tool_call_content_chunk", "toolCallId": "c3",
         "content": {"type": "diff", "changes": []}}
        """#)

    guard case .toolCall(let call)? = thread.item(id: "c3"),
      case .unknown(let kind, let raw)? = call.content.first
    else {
      Issue.record("The tool call c3 has no unknown content.")
      return
    }
    #expect(kind == "diff")
    #expect(raw["changes"] == .array([]))
  }

  @Test func toolCallContentChunkWithAnUnknownTypeKeepsTheJSON() throws {
    let thread = try thread(
      applying: #"""
        {"sessionUpdate": "tool_call_content_chunk", "toolCallId": "c4",
         "content": {"type": "chart", "points": [1]}}
        """#)

    guard case .toolCall(let call)? = thread.item(id: "c4") else {
      Issue.record("The thread has no tool call c4.")
      return
    }
    #expect(call.content == [.unknown(kind: "chart", raw: .object(["points": .array([.number(1)])]))])
  }

  // MARK: - Terminals

  @Test func terminalUpdateMakesATerminal() throws {
    let thread = try thread(applying: SessionUpdateFixtures.terminalUpdate)

    let terminal = try #require(thread.terminals[TerminalID("term1")])
    #expect(terminal.command == "ls")
    #expect(terminal.cwd == "/tmp")
    #expect(terminal.exitStatus == TerminalRecord.ExitStatus(code: 0, signal: nil))
    #expect(terminal.output == Data("hi".utf8))
    #expect(terminal.meta == .object(["tty": .bool(true)]))
  }

  @Test func terminalOutputChunkAddsBytes() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.terminalUpdate, SessionUpdateFixtures.terminalOutputChunk)

    let terminal = try #require(thread.terminals[TerminalID("term1")])
    #expect(terminal.output == Data("hi!".utf8))
    #expect(terminal.command == "ls")
  }

  @Test func terminalOutputThatIsNotBase64ChangesNothing() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.terminalUpdate,
      #"{"sessionUpdate": "terminal_output_chunk", "terminalId": "term1", "data": "%%%"}"#,
      #"{"sessionUpdate": "terminal_update", "terminalId": "term1", "output": {"data": "%%%"}}"#
    )

    let terminal = try #require(thread.terminals[TerminalID("term1")])
    #expect(terminal.output == Data("hi".utf8))
  }

  // MARK: - Session state

  @Test func planUpdateReplacesThePlan() throws {
    let thread = try thread(applying: SessionUpdateFixtures.planUpdate)

    let plan = try #require(thread.plans[PlanID("p1")])
    #expect(
      plan.entries == [
        AgentViewKit.PlanEntry(content: "Read", priority: .high, status: .inProgress),
        AgentViewKit.PlanEntry(content: "Ship", priority: .unknown("urgent"), status: .pending),
      ])
  }

  @Test func planUpdateWithAnUnknownTypeAddsAnUnknownRecord() throws {
    let thread = try thread(
      applying: ##"{"sessionUpdate": "plan_update", "plan": {"type": "markdown", "text": "# Plan"}}"##)

    guard case .unknown(let record)? = thread.item(id: unknownID) else {
      Issue.record("The thread has no unknown record.")
      return
    }
    #expect(record.kind == "plan_update/markdown")
    #expect(record.raw["text"] == .string("# Plan"))
    #expect(thread.plans.isEmpty)
  }

  @Test func availableCommandsUpdateReplacesTheCommands() throws {
    let thread = try thread(applying: SessionUpdateFixtures.availableCommands)

    #expect(
      thread.availableCommands == [
        SlashCommand(name: "review", description: "Review the code", inputHint: "path"),
        SlashCommand(name: "clear", description: "Clear the thread"),
      ])
  }

  @Test func configOptionUpdateReadsFlatSelectAndBooleanOptions() throws {
    let thread = try thread(applying: SessionUpdateFixtures.flatConfigOptions)

    #expect(
      thread.configOptions == [
        ConfigOption(
          id: ConfigOptionID("mode"), name: "Mode", category: .mode,
          kind: .select(
            current: "ask",
            choices: .flat([
              SelectOption(id: "ask", name: "Ask"), SelectOption(id: "code", name: "Code"),
            ]))),
        ConfigOption(id: ConfigOptionID("web"), name: "Web", kind: .boolean(current: true)),
      ])
  }

  @Test func configOptionUpdateReadsGroupedSelectOptions() throws {
    let thread = try thread(applying: SessionUpdateFixtures.groupedConfigOptions)

    let option = try #require(thread.configOptions.first)
    #expect(
      option.kind
        == .select(
          current: "fast",
          choices: .grouped([
            SelectGroup(id: "local", name: "Local", options: [SelectOption(id: "fast", name: "Fast")]),
            SelectGroup(id: "cloud", name: "Cloud", options: [SelectOption(id: "big", name: "Big")]),
          ])))
    #expect(option.category == .model)
  }

  @Test func configOptionUpdateKeepsAnUnknownTypeAsJSON() throws {
    let thread = try thread(applying: SessionUpdateFixtures.unknownConfigOption)

    let option = try #require(thread.configOptions.first)
    #expect(option.id == ConfigOptionID("level"))
    guard case .unknown(let type, let raw) = option.kind else {
      Issue.record("The option kind is not unknown.")
      return
    }
    #expect(type == "slider")
    #expect(raw["min"] == .number(0))
  }

  @Test func configOptionUpdateKeepsASelectThatTheKitCannotReadAsJSON() throws {
    let thread = try thread(
      applying: #"""
        {"sessionUpdate": "config_option_update",
         "configOptions": [{"configId": "mode", "name": "Mode", "type": "select",
                            "currentValue": "ask", "options": "not a list"}]}
        """#)

    let option = try #require(thread.configOptions.first)
    guard case .unknown(let type, let raw) = option.kind else {
      Issue.record("The option kind is not unknown.")
      return
    }
    #expect(type == "select")
    #expect(raw["options"] == .string("not a list"))
    #expect(option.name == "Mode")
  }

  @Test func sessionInfoUpdatePatchesTheInfo() throws {
    let thread = try thread(applying: SessionUpdateFixtures.sessionInfo)

    #expect(thread.info.title == "Bug hunt")
    #expect(thread.info.updatedAt == sessionTime)
  }

  @Test func sessionInfoUpdateReadsFractionalSecondsAndClearsTheTitle() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.sessionInfo,
      #"{"sessionUpdate": "session_info_update", "title": null, "updatedAt": "2026-09-16T10:00:00.500Z"}"#
    )

    #expect(thread.info.title == nil)
    #expect(thread.info.updatedAt == sessionTime.addingTimeInterval(halfSecond))
  }

  @Test func sessionInfoUpdateWithATimeThatIsNotISO8601KeepsTheTime() throws {
    let thread = try thread(
      applying: SessionUpdateFixtures.sessionInfo,
      #"{"sessionUpdate": "session_info_update", "updatedAt": "yesterday"}"#
    )

    #expect(thread.info.updatedAt == sessionTime)
  }

  @Test func usageUpdateSetsTheUsageWithTheCost() throws {
    let thread = try thread(applying: SessionUpdateFixtures.usage)

    #expect(
      thread.usage
        == ContextUsage(
          used: 1200, size: 200_000, cost: ContextUsage.Cost(amount: 0.25, currency: "USD")))
  }

  @Test func unknownUpdateAddsAnUnknownRecord() throws {
    let thread = try thread(applying: SessionUpdateFixtures.unknownUpdate)

    guard case .unknown(let record)? = thread.item(id: unknownID) else {
      Issue.record("The thread has no unknown record.")
      return
    }
    #expect(record.kind == "mood_update")
    #expect(record.raw == .object(["mood": .string("happy")]))
  }

  // MARK: - Content blocks

  @Test func textBlockKeepsTheAnnotations() throws {
    let block = try mappedBlock(
      #"{"type": "text", "text": "Hi", "annotations": {"audience": ["user", "robot"], "priority": 0.5}}"#
    )

    #expect(block.content == .text("Hi"))
    #expect(block.annotations == AgentViewKit.Annotations(audience: [.user, .unknown("robot")], priority: 0.5))
  }

  @Test func imageBlockDecodesTheData() throws {
    let block = try mappedBlock(
      #"{"type": "image", "data": "AAE=", "mimeType": "image/png", "uri": "file:///a.png"}"#)

    #expect(
      block.content
        == .image(
          AgentViewKit.ImageContent(data: Data([0, 1]), mimeType: "image/png", uri: "file:///a.png")))
  }

  @Test func imageBlockWithDataThatIsNotBase64KeepsTheJSON() throws {
    let block = try mappedBlock(#"{"type": "image", "data": "%%%", "mimeType": "image/png"}"#)

    guard case .unknown(let kind, let raw) = block.content else {
      Issue.record("The block is not unknown.")
      return
    }
    #expect(kind == "image")
    #expect(raw["data"] == .string("%%%"))
  }

  @Test func audioBlockDecodesTheData() throws {
    let block = try mappedBlock(#"{"type": "audio", "data": "AAE=", "mimeType": "audio/wav"}"#)

    #expect(block.content == .audio(AgentViewKit.AudioContent(data: Data([0, 1]), mimeType: "audio/wav")))
  }

  @Test func resourceLinkBlockKeepsTheIcons() throws {
    let block = try mappedBlock(
      #"""
      {"type": "resource_link", "name": "a.swift", "uri": "file:///a.swift",
       "mimeType": "text/x-swift",
       "icons": [{"src": "https://x/icon.png", "mimeType": "image/png", "sizes": ["48x48"]},
                 {"src": "https://x/icon.svg"}]}
      """#)

    #expect(
      block.content
        == .resourceLink(
          AgentViewKit.ResourceLink(
            name: "a.swift", uri: "file:///a.swift",
            icons: [
              ResourceIcon(src: "https://x/icon.png", mimeType: "image/png", sizes: ["48x48"]),
              ResourceIcon(src: "https://x/icon.svg"),
            ],
            mimeType: "text/x-swift")))
  }

  @Test func resourceBlockReadsTextAndBlobContents() throws {
    let text = try mappedBlock(
      #"{"type": "resource", "resource": {"uri": "file:///a.txt", "mimeType": "text/plain", "text": "hi"}}"#
    )
    let blob = try mappedBlock(
      #"{"type": "resource", "resource": {"uri": "file:///a.bin", "blob": "AAE="}}"#)

    #expect(
      text.content
        == .resource(
          AgentViewKit.EmbeddedResource(uri: "file:///a.txt", mimeType: "text/plain", contents: .text("hi"))))
    #expect(
      blob.content
        == .resource(AgentViewKit.EmbeddedResource(uri: "file:///a.bin", contents: .blob(Data([0, 1])))))
  }

  @Test func resourceBlockWithNoContentsKeepsTheJSON() throws {
    let block = try mappedBlock(#"{"type": "resource", "resource": {"uri": "file:///a"}}"#)

    guard case .unknown(let kind, let raw) = block.content else {
      Issue.record("The block is not unknown.")
      return
    }
    #expect(kind == "resource")
    #expect(raw["resource"]?["uri"] == .string("file:///a"))
  }

  @Test func unknownBlockKeepsItsTypeAndJSON() throws {
    let block = try mappedBlock(#"{"type": "video", "src": "v.mp4"}"#)

    #expect(block.content == .unknown(kind: "video", raw: .object(["src": .string("v.mp4")])))
  }

  // MARK: - Requests

  @Test func permissionRequestMapsTheOptionsAndTheCommandSubject() throws {
    let id = UUID()
    let request = try SessionUpdateFixtures.decode(
      RequestPermissionRequest.self,
      #"""
      {"sessionId": "s1", "title": "Run ls", "description": "List files",
       "options": [{"optionId": "yes", "name": "Allow", "kind": "allow_once"},
                   {"optionId": "no", "name": "Deny", "kind": "reject_forever"}],
       "subject": {"type": "command", "command": "ls", "cwd": "/tmp",
                   "terminalId": "term1", "toolCallId": "c1"},
       "_meta": {"k": "v"}}
      """#)

    let mapped = SessionUpdateMapping.permissionRequest(TestPermission(id: id, request: request))

    #expect(mapped.id == PermissionRequestID(id.uuidString))
    #expect(mapped.title == "Run ls")
    #expect(mapped.description == "List files")
    #expect(
      mapped.subject
        == .command(command: "ls", cwd: "/tmp", toolCallId: "c1", terminalId: TerminalID("term1")))
    #expect(
      mapped.options == [
        AgentViewKit.PermissionOption(id: PermissionOptionID("yes"), name: "Allow", kind: .allowOnce),
        AgentViewKit.PermissionOption(
          id: PermissionOptionID("no"), name: "Deny", kind: .unknown("reject_forever")),
      ])
    #expect(mapped.meta == .object(["k": .string("v")]))
  }

  @Test func permissionRequestMapsTheToolCallSubjectAndDropsAnUnknownSubject() throws {
    let toolCall = try SessionUpdateFixtures.decode(
      RequestPermissionRequest.self,
      #"""
      {"sessionId": "s1", "title": "Edit", "options": [],
       "subject": {"type": "tool_call", "toolCall": {"toolCallId": "c9", "title": "Edit"}}}
      """#)
    let unknown = try SessionUpdateFixtures.decode(
      RequestPermissionRequest.self,
      #"{"sessionId": "s1", "title": "Other", "options": [], "subject": {"type": "network", "host": "x"}}"#
    )

    let mappedToolCall = SessionUpdateMapping.permissionRequest(
      TestPermission(id: UUID(), request: toolCall))
    let mappedUnknown = SessionUpdateMapping.permissionRequest(
      TestPermission(id: UUID(), request: unknown))

    #expect(mappedToolCall.subject == .toolCall(id: "c9"))
    #expect(mappedUnknown.subject == nil)
  }

  @Test func elicitationRequestMapsTheFormAndTheURLModes() throws {
    let formID = UUID()
    let form = try SessionUpdateFixtures.decode(
      CreateElicitationRequest.self,
      #"""
      {"sessionId": "s1", "message": "Your name?", "mode": "form",
       "requestedSchema": {"type": "object", "properties": {"name": {"type": "string"}}}}
      """#)
    let url = try SessionUpdateFixtures.decode(
      CreateElicitationRequest.self,
      #"""
      {"sessionId": "s1", "message": "Sign in", "mode": "url",
       "url": "https://example.com/auth", "elicitationId": "e1", "_meta": {"k": 1}}
      """#)

    let mappedForm = try #require(
      SessionUpdateMapping.elicitationRequest(
        TestElicitation(id: formID, request: form), server: "Agent"))
    let mappedURL = try #require(
      SessionUpdateMapping.elicitationRequest(
        TestElicitation(id: UUID(), request: url), server: "Agent"))

    #expect(mappedForm.id == ElicitationRequestID(formID.uuidString))
    #expect(mappedForm.server == "Agent")
    #expect(mappedForm.message == "Your name?")
    guard case .form(let schema) = mappedForm.mode else {
      Issue.record("The form request is not in form mode.")
      return
    }
    #expect(schema["properties"]?["name"]?["type"] == .string("string"))
    #expect(mappedURL.mode == .url(try #require(URL(string: "https://example.com/auth")), elicitationId: "e1"))
    #expect(mappedURL.meta == .object(["k": .number(1)]))
  }

  @Test func elicitationRequestWithAnUnknownModeGivesNil() throws {
    let request = try SessionUpdateFixtures.decode(
      CreateElicitationRequest.self,
      #"{"sessionId": "s1", "message": "Pick", "mode": "picker"}"#)

    #expect(
      SessionUpdateMapping.elicitationRequest(
        TestElicitation(id: UUID(), request: request), server: "Agent") == nil)
  }
}
