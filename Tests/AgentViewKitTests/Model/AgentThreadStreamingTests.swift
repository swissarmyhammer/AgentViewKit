import AgentViewKit
import Testing

@MainActor
@Suite struct AgentThreadStreamingTests {
  /// Makes a thread that holds the item.
  private func makeThread(_ item: ThreadItem) -> AgentThread {
    let thread = AgentThread()
    thread.apply(.insert(item, after: nil))
    return thread
  }

  /// Streams `chunks` to the record with the id, and closes the stream.
  private func stream(_ chunks: [String], id: String, to thread: AgentThread) {
    for chunk in chunks {
      thread.apply(.appendStreaming(id: id, text: chunk))
    }
    thread.apply(.closeStreaming(id: id))
  }

  /// The message of an assistant message item, or `nil` for any other item.
  private func assistantMessage(_ item: ThreadItem?) -> Message? {
    if case .assistantMessage(let message) = item { message } else { nil }
  }

  @Test func closeWritesTheFinalTextToTheAssistantMessage() {
    let message = Message(id: "m1", blocks: [])
    let thread = makeThread(.assistantMessage(message))

    stream(["Hello", " world.\n\nBye."], id: "m1", to: thread)

    #expect(message.blocks == [ContentBlock(text: "Hello world.\n\nBye.")])
    #expect(message.revision == 1)
    #expect(thread.streaming["m1"] == nil)
  }

  @Test func closeWritesTheFinalTextToTheUserMessage() throws {
    let message = Message(id: "u1", blocks: [])
    let thread = makeThread(.userMessage(message))

    stream(["Fix", " the bug."], id: "u1", to: thread)

    #expect(message.blocks == [ContentBlock(text: "Fix the bug.")])
    let item = try #require(thread.item(id: "u1"))
    #expect(item.record === message)
  }

  @Test func closeWritesTheFinalTextToTheReasoning() {
    let reasoning = Reasoning(id: "r1", segments: [])
    let thread = makeThread(.reasoning(reasoning))

    stream(["Think", "ing."], id: "r1", to: thread)

    #expect(reasoning.segments == ["Thinking."])
  }

  @Test func closeWritesTheFinalTextToTheSystemPrompt() {
    let prompt = SystemPrompt(id: "s1", text: "")
    let thread = makeThread(.system(prompt))

    stream(["Be", " brief."], id: "s1", to: thread)

    #expect(prompt.text == "Be brief.")
  }

  @Test func closeMakesAnAssistantMessageWhenNoRecordHasTheId() throws {
    let thread = AgentThread()

    stream(["New", " text."], id: "m9", to: thread)

    let message = try #require(assistantMessage(thread.item(id: "m9")))
    #expect(message.blocks == [ContentBlock(text: "New text.")])
  }

  @Test func closeDoesNotChangeARecordWithNoTextField() throws {
    let call = ToolCallRecord(id: "t1", title: "Run")
    let thread = makeThread(.toolCall(call))

    stream(["output"], id: "t1", to: thread)

    let item = try #require(thread.item(id: "t1"))
    #expect(item.record === call)
    #expect(call.revision == 0)
    #expect(thread.streaming["t1"] == nil)
  }

  @Test func closeOfAnIdWithNoStreamingMessageDoesNothing() {
    let message = Message(id: "m1", blocks: [ContentBlock(text: "Kept")])
    let thread = makeThread(.assistantMessage(message))

    thread.apply(.closeStreaming(id: "m1"))

    #expect(message.blocks == [ContentBlock(text: "Kept")])
    #expect(message.revision == 0)
  }

  @Test func aChunkDoesNotPatchTheRecord() {
    let message = Message(id: "m1", blocks: [])
    let thread = makeThread(.assistantMessage(message))

    thread.apply(.appendStreaming(id: "m1", text: "Hello"))
    thread.apply(.appendStreaming(id: "m1", text: " again"))

    #expect(message.blocks.isEmpty)
    #expect(message.revision == 0)
  }
}
