//
// StreamingBenchmarks: the cost of one streamed chunk through Textual, with
// the paragraph split on and off (plan.md §8, research R1).
//
// Each scenario streams the 2,000-line message of `StreamingCorpus` into a
// `StreamingMessage` that a hosted view shows:
//
//   - SPLIT ON: `ResponseView`. Settled paragraphs render one time, and only
//     the tail parses again.
//   - SPLIT OFF: one Textual `StructuredText` of the full text. Each chunk
//     parses the full message again.
//
// One iteration is one chunk. The iterations are spread over the full
// message: before each measured chunk, the workbench streams the chunks
// between two samples and renders them, outside the measurement. Thus the
// percentiles hold chunks from the start, the middle, and the end of the
// message.
//
// The measured part is: give the chunk to the message, flush the coalescer,
// and render the hosted view.
//
// Gates (a failed gate stops the run with an error):
//
//   - SPLIT ON: the p90 cost of one chunk is less than 4 ms.
//   - SPLIT ON: a chunk that settles no paragraph does not evaluate the
//     settled paragraph list. `Tests/AgentViewKitTests/Streaming/
//     ParagraphReuseTests.swift` proves the same property for each
//     `ParagraphView` in a debug build.
//   - BOTH: each chunk evaluates the view of the text that changed. This
//     proves that the render did the update.
//

import AgentViewKit
import Benchmark
import SwiftUI
import Textual

/// The two ways to render a streamed message.
enum StreamingMode: CaseIterable, Sendable {
  /// ``AgentViewKit/ResponseView``, with the paragraph split.
  case splitOn

  /// One Textual view of the full text, with no paragraph split.
  case splitOff

  /// The name of the scenario.
  var scenarioName: String {
    switch self {
    case .splitOn: "Streaming chunk, paragraph split on"
    case .splitOff: "Streaming chunk, paragraph split off"
    }
  }

  /// The measured chunks of the scenario. A chunk with no split costs much
  /// more, so that scenario measures fewer chunks.
  var iterations: Int {
    switch self {
    case .splitOn: 400
    case .splitOff: 60
    }
  }
}

/// The error of a failed benchmark gate.
struct BenchmarkGateFailure: Error, CustomStringConvertible {
  /// What the gate found.
  let description: String
}

/// Registers the streaming scenarios.
func registerStreamingBenchmarks() {
  for mode in StreamingMode.allCases {
    registerStreamingBenchmark(mode)
  }
}

/// Registers the scenario of one mode.
///
/// - Parameter mode: The render mode.
private func registerStreamingBenchmark(_ mode: StreamingMode) {
  Benchmark(
    mode.scenarioName,
    configuration: BenchmarkPolicy.configuration(
      iterations: mode.iterations,
      countMetrics: [BenchmarkPolicy.bodyEvaluations, BenchmarkPolicy.paragraphsParsed])
  ) { benchmark in
    await StreamingWorkbench.shared.streamToNextSample()
    benchmark.startMeasurement()
    await StreamingWorkbench.shared.streamSampledChunk()
    benchmark.stopMeasurement()
    let sample = try await StreamingWorkbench.shared.checkSample()
    benchmark.measurement(BenchmarkPolicy.bodyEvaluations.metric, sample.bodyEvaluations)
    benchmark.measurement(BenchmarkPolicy.paragraphsParsed.metric, sample.paragraphsParsed)
  } setup: {
    await StreamingWorkbench.shared.open(
      mode: mode, samples: mode.iterations + BenchmarkPolicy.warmupIterations)
  } teardown: {
    try await StreamingWorkbench.shared.close()
  }
}

/// The counts of one measured chunk.
struct StreamingSample: Sendable {
  /// The body evaluations of the probes.
  let bodyEvaluations: Int

  /// The paragraphs that Textual parsed.
  let paragraphsParsed: Int
}

/// The hosted view, the message, and the counts of one streaming scenario.
@MainActor
final class StreamingWorkbench {
  /// The workbench of the scenario that runs.
  static let shared = StreamingWorkbench()

  /// The id of the streamed message.
  static let messageID = "benchmark-response"

  /// The size of the host window.
  static let hostSize = CGSize(width: 640, height: 800)

  /// The gate: the p90 cost of one chunk with the split on, in milliseconds.
  static let splitOnP90LimitMilliseconds = 4.0

  /// The percentile that the cost gate reads.
  static let gatedPercentile = 0.9

  /// The number of microseconds in one millisecond.
  static let microsecondsPerMillisecond = 1_000.0

  /// The number of the tail paragraph: the tail is one paragraph.
  static let tailParagraphCount = 1

  /// The render mode of the scenario.
  private var mode = StreamingMode.splitOn

  /// The chunks between two measured chunks.
  private var strideLength = 1

  /// The position of the next chunk.
  private var cursor = 0

  /// The streamed message.
  private var message = StreamingMessage(id: messageID)

  /// The host of the view of the message.
  private var host: BenchmarkHost<StreamingRoot>?

  /// The evaluations of the view of the settled paragraphs.
  private let settledCount = EvaluationCount()

  /// The evaluations of the view of the changing text.
  private let changingCount = EvaluationCount()

  /// The settled paragraph count before the measured chunk.
  private var settledBefore = 0

  /// The tail before the measured chunk.
  private var tailBefore = StreamingMarkdownBalancer.BalancedTail.markdown("")

  /// The cost of each measured chunk, in milliseconds.
  private var costs: [Double] = []

  /// The clock of the cost gate.
  private let clock = ContinuousClock()

  /// Mounts the view of a new message.
  ///
  /// - Parameters:
  ///   - mode: The render mode.
  ///   - samples: The number of chunks that the scenario measures, with
  ///     the warm-up chunks.
  func open(mode: StreamingMode, samples: Int) {
    self.mode = mode
    strideLength = max(1, StreamingCorpus.chunks.count / samples)
    cursor = 0
    costs = []
    message = StreamingMessage(id: Self.messageID)
    host = BenchmarkHost(
      StreamingRoot(mode: mode, message: message, settledCount: settledCount, changingCount: changingCount),
      size: Self.hostSize)
    _ = settledCount.take()
    _ = changingCount.take()
  }

  /// Checks the cost gate and closes the host.
  ///
  /// - Throws: ``BenchmarkGateFailure`` when the p90 cost with the split on
  ///   is not less than the limit.
  func close() throws {
    host?.close()
    host = nil
    guard mode == .splitOn, !costs.isEmpty else { return }
    let sorted = costs.sorted()
    let index = min(sorted.count - 1, Int(Double(sorted.count) * Self.gatedPercentile))
    let p90 = sorted[index]
    print("\(mode.scenarioName): p90 chunk cost \(p90) ms over \(sorted.count) chunks.")
    guard p90 < Self.splitOnP90LimitMilliseconds else {
      throw BenchmarkGateFailure(
        description: "The p90 chunk cost is \(p90) ms. The limit is \(Self.splitOnP90LimitMilliseconds) ms.")
    }
  }

  /// Streams the chunks before the next measured chunk, and renders them.
  ///
  /// At the end of the message, the message starts again from no text.
  func streamToNextSample() {
    if cursor + strideLength > StreamingCorpus.chunks.count {
      message.replace("")
      cursor = 0
    }
    let skipped = StreamingCorpus.chunks[cursor..<(cursor + strideLength - 1)]
    cursor += skipped.count
    message.append(skipped.joined())
    message.flush()
    host?.render()
    settledBefore = message.settledParagraphs.count
    tailBefore = message.tail
    _ = settledCount.take()
    _ = changingCount.take()
  }

  /// Streams one chunk and renders it. This is the measured part.
  func streamSampledChunk() {
    let start = clock.now
    message.append(StreamingCorpus.chunks[cursor])
    message.flush()
    host?.render()
    costs.append(Self.milliseconds(clock.now - start))
    cursor += 1
  }

  /// Reads the counts of the measured chunk, and checks the count gates.
  ///
  /// - Returns: The counts of the chunk.
  /// - Throws: ``BenchmarkGateFailure`` when a gate fails.
  func checkSample() throws -> StreamingSample {
    let settledEvaluations = settledCount.take()
    let changingEvaluations = changingCount.take()
    let settledAfter = message.settledParagraphs.count
    let changed = message.tail != tailBefore || settledAfter != settledBefore
    if changed, changingEvaluations == 0 {
      throw BenchmarkGateFailure(description: "\(mode.scenarioName): the chunk did not render.")
    }
    switch mode {
    case .splitOn:
      if settledAfter == settledBefore, settledEvaluations > 0 {
        throw BenchmarkGateFailure(
          description: "A chunk that settled no paragraph evaluated the settled paragraphs.")
      }
      return StreamingSample(
        bodyEvaluations: settledEvaluations + changingEvaluations,
        paragraphsParsed: settledAfter - settledBefore + Self.tailParagraphCount)
    case .splitOff:
      return StreamingSample(
        bodyEvaluations: changingEvaluations,
        paragraphsParsed: settledAfter + Self.tailParagraphCount)
    }
  }

  /// A duration in milliseconds.
  ///
  /// - Parameter duration: The duration.
  /// - Returns: The duration, in milliseconds.
  private static func milliseconds(_ duration: Duration) -> Double {
    Double(duration / .microseconds(1)) / microsecondsPerMillisecond
  }
}

/// The hosted view of a streaming scenario, with its probes.
struct StreamingRoot: View {
  /// The render mode.
  let mode: StreamingMode

  /// The streamed message.
  let message: StreamingMessage

  /// The evaluations of the view of the settled paragraphs.
  let settledCount: EvaluationCount

  /// The evaluations of the view of the changing text.
  let changingCount: EvaluationCount

  var body: some View {
    ScrollView {
      switch mode {
      case .splitOn:
        ResponseView(message: Message(id: message.id, blocks: []), streaming: message)
          .background {
            EvaluationProbe(model: message, property: \.settledParagraphs, count: settledCount)
            EvaluationProbe(model: message, property: \.tail, count: changingCount)
          }
          .lazyResponseParagraphs()
      case .splitOff:
        WholeMessageView(message: message)
          .background {
            EvaluationProbe(model: message, property: \.text, count: changingCount)
          }
      }
    }
  }
}

/// The full text of a message in one Textual view, with no paragraph split.
struct WholeMessageView: View {
  /// The streamed message.
  let message: StreamingMessage

  var body: some View {
    StructuredText(markdown: message.text)
      .textual.codeBlockStyle(EditorKitCodeBlockStyle())
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}
