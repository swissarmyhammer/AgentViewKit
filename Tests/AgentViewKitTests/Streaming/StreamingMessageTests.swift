import AgentViewKit
import Observation
import Testing

@Suite @MainActor struct StreamingMessageTests {
  /// A flush interval that no test reaches, so that only `flush()` flushes.
  private static let manualInterval: Duration = .seconds(3600)

  /// A flush interval that the timer test waits for.
  private static let shortInterval: Duration = .milliseconds(5)

  /// The longest time that the timer test waits for the flush.
  private static let flushTimeout: Duration = .seconds(5)

  /// The number of chunks that the three-paragraph test sends.
  private static let chunkCount = 12

  /// A message with three paragraphs and no blank line at the end.
  private static let threeParagraphs =
    "First paragraph.\n\nSecond paragraph.\n\nThird paragraph."

  /// Makes a message that flushes only when the test calls `flush()`.
  private func makeMessage(_ text: String = "") -> StreamingMessage {
    StreamingMessage(id: "m1", text: text, interval: Self.manualInterval)
  }

  /// Splits `text` into `count` chunks of about the same length.
  private func chunks(of text: String, count: Int) -> [String] {
    let characters = Array(text)
    return (0..<count).map { part in
      let start = part * characters.count / count
      let end = (part + 1) * characters.count / count
      return String(characters[start..<end])
    }
  }

  /// The texts of the settled paragraphs of `message`.
  private func settledTexts(_ message: StreamingMessage) -> [String] {
    message.settledParagraphs.map(\.text)
  }

  // MARK: - append

  @Test func threeParagraphsInTwelveChunksGiveTwoSettledParagraphsAndATail() {
    let message = makeMessage()
    let parts = chunks(of: Self.threeParagraphs, count: Self.chunkCount)
    #expect(parts.count == Self.chunkCount)

    for part in parts {
      message.append(part)
    }
    message.flush()

    #expect(settledTexts(message) == ["First paragraph.", "Second paragraph."])
    #expect(message.tail == .markdown("Third paragraph."))
    #expect(message.isOpen)
  }

  @Test func closeSettlesTheTailAsTheLastParagraph() {
    let message = makeMessage()
    for part in chunks(of: Self.threeParagraphs, count: Self.chunkCount) {
      message.append(part)
    }

    message.close()

    #expect(
      settledTexts(message) == ["First paragraph.", "Second paragraph.", "Third paragraph."])
    #expect(message.tail == .markdown(""))
    #expect(!message.isOpen)
    #expect(message.text == Self.threeParagraphs)
  }

  @Test func appendDoesNotChangeTheMessageBeforeTheFlush() {
    let message = makeMessage("Hello")

    message.append(" world")

    #expect(message.text == "Hello")
    #expect(message.tail == .markdown("Hello"))
  }

  @Test func theCoalescerFlushesTheChunksWhenTheIntervalEnds() async throws {
    let message = StreamingMessage(id: "m1", interval: Self.shortInterval)

    message.append("Hello")
    let clock = ContinuousClock()
    let deadline = clock.now + Self.flushTimeout
    while message.text.isEmpty, clock.now < deadline {
      try await Task.sleep(for: Self.shortInterval)
    }

    #expect(message.text == "Hello")
    #expect(message.tail == .markdown("Hello"))
  }

  @Test func theInitialTextIsRenderedAtOnce() {
    let message = makeMessage("Done.\n\nsome **bold")

    #expect(settledTexts(message) == ["Done."])
    #expect(message.tail == .markdown("some **bold**"))
  }

  @Test func appendAfterCloseDoesNothing() {
    let message = makeMessage("Final.")
    message.close()

    message.append(" More.")
    message.flush()

    #expect(message.text == "Final.")
    #expect(settledTexts(message) == ["Final."])
  }

  @Test func closeFlushesThePendingChunks() {
    let message = makeMessage("Hello")
    message.append(" world")

    message.close()

    #expect(settledTexts(message) == ["Hello world"])
  }

  @Test func aTailWithABlankLineAtTheEndIsNotAParagraphOnClose() {
    let message = makeMessage("One.\n\n")

    message.close()

    #expect(settledTexts(message) == ["One."])
  }

  @Test func closeRemovesTheLineBreakAtTheEndOfTheTail() {
    let message = makeMessage("One.\nTwo.\n")

    message.close()

    #expect(settledTexts(message) == ["One.\nTwo."])
  }

  // MARK: - Observation

  @Test func aChunkThatChangesOnlyTheTailDoesNotNotifyAnObserverOfTheSettledParagraphs() {
    let message = makeMessage("Settled.\n\nTail")
    let changed = ChangeFlag.observing { _ = message.settledParagraphs }

    message.append(" grows")
    message.flush()

    #expect(message.tail == .markdown("Tail grows"))
    #expect(!changed.value)
  }

  @Test func aChunkThatChangesOnlyTheTailNotifiesAnObserverOfTheTail() {
    let message = makeMessage("Settled.\n\nTail")
    let changed = ChangeFlag.observing { _ = message.tail }

    message.append(" grows")
    message.flush()

    #expect(changed.value)
  }

  @Test func aChunkThatSettlesAParagraphNotifiesAnObserverOfTheSettledParagraphs() {
    let message = makeMessage("Settled.\n\nTail")
    let changed = ChangeFlag.observing { _ = message.settledParagraphs }

    message.append("\n\nNext")
    message.flush()

    #expect(changed.value)
    #expect(settledTexts(message) == ["Settled.", "Tail"])
  }

  // MARK: - replace

  @Test func replaceWithShorterTextShrinksTheSettledParagraphs() {
    let message = makeMessage("One.\n\nTwo.\n\nThree.\n\nFour")

    message.replace("One.\n\nTail")

    #expect(settledTexts(message) == ["One."])
    #expect(message.tail == .markdown("Tail"))
    #expect(message.text == "One.\n\nTail")
  }

  @Test func replaceOverwritesThePendingChunks() {
    let message = makeMessage("Old")
    message.append(" pending")

    message.replace("New")

    #expect(message.text == "New")
    #expect(message.tail == .markdown("New"))
  }

  @Test func replaceAfterCloseKeepsTheMessageClosed() {
    let message = makeMessage("Old.")
    message.close()

    message.replace("New one.\n\nNew two.")

    #expect(!message.isOpen)
    #expect(settledTexts(message) == ["New one.", "New two."])
    #expect(message.tail == .markdown(""))
  }

  // MARK: - Fences

  @Test func aFenceThatOpensInOneChunkAndClosesInALaterChunkSettles() {
    let message = makeMessage()

    message.append("Intro.\n\n```swift\nlet x")
    message.flush()

    #expect(settledTexts(message) == ["Intro."])
    #expect(message.tail == .openFence(language: "swift", body: "let x"))

    message.append(" = 1\n")
    message.flush()

    #expect(message.tail == .openFence(language: "swift", body: "let x = 1\n"))

    message.append("```\n")
    message.flush()

    #expect(settledTexts(message) == ["Intro.", "```swift\nlet x = 1\n```"])
    #expect(message.tail == .markdown(""))
  }

  @Test func closeSettlesAnOpenFence() {
    let message = makeMessage("```swift\nlet x = 1")

    message.close()

    #expect(settledTexts(message) == ["```swift\nlet x = 1"])
    #expect(message.tail == .markdown(""))
  }
}
