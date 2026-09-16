import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import Testing

/// Tests for ``ThreadFixtures`` (plan.md §3.4).
@MainActor
struct ThreadFixturesTests {
  @Test func aMessageHasTheTextAsItsOnlyBlock() {
    let message = ThreadFixtures.message(id: "m1", text: "Hello")

    #expect(message.id == "m1")
    #expect(message.blocks == [ContentBlock(text: "Hello")])
  }

  @Test func aToolCallHasTheStatus() {
    for status in ToolCallStatus.knownCases {
      let record = ThreadFixtures.toolCall(id: "t1", status: status)

      #expect(record.id == "t1")
      #expect(record.status == status)
    }
  }

  @Test func theToolCallListHasOneRecordPerKnownStatusWithDistinctIds() {
    let records = ThreadFixtures.toolCallForEachStatus()

    #expect(records.map(\.status) == ToolCallStatus.knownCases)
    #expect(Set(records.map(\.id)).count == records.count)
  }

  @Test func aToolCallThatStartedHasAStartTime() {
    #expect(ThreadFixtures.toolCall(id: "t1", status: .pending).startedAt == nil)
    #expect(ThreadFixtures.toolCall(id: "t2", status: .inProgress).startedAt != nil)
    #expect(ThreadFixtures.toolCall(id: "t3", status: .inProgress).endedAt == nil)
    #expect(ThreadFixtures.toolCall(id: "t4", status: .completed).endedAt != nil)
  }

  @Test func aReasoningHasTheText() {
    let reasoning = ThreadFixtures.reasoning(id: "r1", text: "Think")

    #expect(reasoning.id == "r1")
    #expect(reasoning.segments == ["Think"])
  }

  @Test func aPermissionRequestHasTheFourKnownOptionKinds() {
    let request = ThreadFixtures.permissionRequest(id: "p1")

    #expect(request.id == PermissionRequestID("p1"))
    #expect(request.options.map(\.kind) == PermissionOption.Kind.knownCases)
    #expect(Set(request.options.map(\.id)).count == PermissionOption.Kind.knownCases.count)
  }

  @Test func aFormElicitationRequestHasAnObjectSchema() {
    let request = ThreadFixtures.formElicitationRequest(id: "e1")

    #expect(request.id == ElicitationRequestID("e1"))
    guard case .form(let schema) = request.mode else {
      Issue.record("The mode is not form.")
      return
    }
    #expect(schema["type"]?.stringValue == "object")
    #expect(schema["properties"] != nil)
  }

  @Test func aURLElicitationRequestHasTheURLMode() {
    let request = ThreadFixtures.urlElicitationRequest(id: "e2")

    #expect(request.id == ElicitationRequestID("e2"))
    guard case .url(let url, let elicitationId) = request.mode else {
      Issue.record("The mode is not url.")
      return
    }
    #expect(url.scheme == "https")
    #expect(!elicitationId.isEmpty)
  }

  @Test func theSampleThreadHasTheNumberOfItemsWithDistinctIds() {
    let thread = ThreadFixtures.sampleThread(items: 5)

    #expect(thread.items.count == 5)
    #expect(Set(thread.items.map(\.id)).count == 5)
  }

  @Test func theSampleThreadStartsWithAUserMessageAndUsesEachFixtureKind() {
    let thread = ThreadFixtures.sampleThread(items: 4)

    #expect(thread.items.map(Self.kindName) == ["user", "reasoning", "toolCall", "assistant"])
  }

  @Test func anEmptySampleThreadHasNoItems() {
    #expect(ThreadFixtures.sampleThread(items: 0).items.isEmpty)
  }

  /// A short name for the case of `item`.
  ///
  /// - Parameter item: The item to name.
  /// - Returns: The name.
  private static func kindName(_ item: ThreadItem) -> String {
    switch item {
    case .userMessage: "user"
    case .assistantMessage: "assistant"
    case .reasoning: "reasoning"
    case .toolCall: "toolCall"
    case .system, .structured, .compaction, .error, .unknown: "other"
    }
  }
}
