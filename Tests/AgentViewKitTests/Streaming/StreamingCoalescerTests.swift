import AgentViewKit
import Testing

@Suite @MainActor struct StreamingCoalescerTests {
  /// Records each flush and hands it to a waiting test.
  private final class FlushRecorder {
    private(set) var flushes: [String] = []
    let stream: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init() {
      (stream, continuation) = AsyncStream.makeStream(of: String.self)
    }

    func record(_ text: String) {
      flushes.append(text)
      continuation.yield(text)
    }

    /// Waits for the next flush.
    func nextFlush() async -> String? {
      var iterator = stream.makeAsyncIterator()
      return await iterator.next()
    }
  }

  @Test func theDefaultCadenceIs33Milliseconds() {
    let coalescer = StreamingCoalescer { _ in }

    #expect(coalescer.interval == .milliseconds(33))
    #expect(StreamingCoalescer.defaultInterval == .milliseconds(33))
  }

  @Test func tenChunksInTenMillisecondsFlushAsOne() async {
    let recorder = FlushRecorder()
    let coalescer = StreamingCoalescer { recorder.record($0) }
    let clock = ContinuousClock()
    let start = clock.now

    for index in 0..<10 {
      coalescer.append("c\(index)")
    }
    #expect(clock.now - start < .milliseconds(10))
    #expect(recorder.flushes.isEmpty)

    let flushed = await recorder.nextFlush()

    #expect(flushed == "c0c1c2c3c4c5c6c7c8c9")
    #expect(recorder.flushes == ["c0c1c2c3c4c5c6c7c8c9"])
    #expect(clock.now - start >= .milliseconds(33))
  }

  @Test func flushNowFlushesAtOnce() {
    let recorder = FlushRecorder()
    let coalescer = StreamingCoalescer { recorder.record($0) }

    coalescer.append("a")
    coalescer.append("b")
    coalescer.flushNow()

    #expect(recorder.flushes == ["ab"])
  }

  @Test func flushNowCancelsThePendingFlush() async {
    let recorder = FlushRecorder()
    let coalescer = StreamingCoalescer(interval: .milliseconds(5)) { recorder.record($0) }

    coalescer.append("a")
    coalescer.flushNow()
    #expect(await recorder.nextFlush() == "a")

    coalescer.append("b")
    #expect(await recorder.nextFlush() == "b")

    // The cancelled flush of "a" did not flush an empty buffer.
    #expect(recorder.flushes == ["a", "b"])
  }

  @Test func flushNowWithAnEmptyBufferDoesNotFlush() {
    let recorder = FlushRecorder()
    let coalescer = StreamingCoalescer { recorder.record($0) }

    coalescer.flushNow()
    coalescer.append("")
    coalescer.flushNow()

    #expect(recorder.flushes.isEmpty)
  }

  @Test func chunksAfterAFlushStartANewBatch() async {
    let recorder = FlushRecorder()
    let coalescer = StreamingCoalescer(interval: .milliseconds(5)) { recorder.record($0) }

    coalescer.append("a")
    #expect(await recorder.nextFlush() == "a")
    coalescer.append("b")
    coalescer.append("c")
    #expect(await recorder.nextFlush() == "bc")

    #expect(recorder.flushes == ["a", "bc"])
  }
}
