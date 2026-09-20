//
// ObservationBenchmarks: the observation granularity of a FoundationModels
// stream (plan.md §3.3, §8, research R4).
//
// A fake `LanguageModel` streams 1,000 text chunks into one response entry.
//
//   - SOURCE: `SessionThreadSource.stream(_:)` fills an `AgentThread`. One
//     observer reads `thread.items`, and one observer reads the streaming
//     message `thread.streaming[id]`. The gate: the items observer changes
//     only on entry boundaries, not on chunks.
//   - TAIL SOURCE: the same stream with no source. Each scenario reads the
//     response text from one tail source at each update of that source:
//       - `ResponseStream.Snapshot.transcriptEntries`, one update for each
//         snapshot of the stream.
//       - `session.properties.history` (`SessionPropertyValues`), one update
//         for each observation change.
//       - `session.transcript`, one update for each observation change.
//
// One iteration is one full stream. The measured part is the stream.
//
// `ChangeCounter` counts the observer changes. `ChangeCounter.swift` in this
// directory is a symbolic link to the file in `AgentViewKitTestSupport`.
//

import AgentViewKit
import AgentViewKitFoundationModels
import Benchmark
import FoundationModels
import Observation

/// The shared values of the observation scenarios.
nonisolated enum ObservationCorpus {
  /// The number of text chunks in one stream.
  static let chunkCount = 1_000

  /// The id of the response entry.
  static let responseID = "benchmark-observation-response"

  /// The prompt of the stream.
  static let prompt = "Stream the benchmark response."

  /// The text of one chunk.
  static let chunkText = "word "

  /// The number of observation passes that the counters get after a stream,
  /// so that the last changes reach them.
  static let settlePasses = 16

  /// The measured streams of each scenario.
  static let iterations = 40

  /// The events of the one model call of the stream.
  static var events: [FakeEvent] {
    Array(repeating: FakeEvent.text(entryID: responseID, text: chunkText), count: chunkCount)
  }

  /// Makes a session with a fake model that streams the chunks.
  ///
  /// - Returns: The session.
  static func makeSession() -> LanguageModelSession {
    LanguageModelSession(model: FakeLanguageModel(rounds: [events]))
  }

  /// The response text of a transcript entry.
  ///
  /// - Parameter entry: The entry, or `nil`.
  /// - Returns: The joined text segments of a response entry, or an empty
  ///   string for other entries.
  static func responseText(of entry: Transcript.Entry?) -> String {
    guard case .response(let response) = entry else { return "" }
    return response.segments.map { segment in
      guard case .text(let text) = segment else { return "" }
      return text.content
    }.joined()
  }

  /// Gives the main actor some passes, so that the pending observation
  /// tasks run.
  @MainActor
  static func settle() async {
    for _ in 0..<settlePasses {
      await Task.yield()
    }
  }
}

// MARK: - Source scenario

/// Registers the observation scenarios.
func registerObservationBenchmarks() {
  registerSourceBenchmark()
  for source in TailSource.allCases {
    registerTailSourceBenchmark(source)
  }
}

/// Registers the scenario of `SessionThreadSource`.
private func registerSourceBenchmark() {
  Benchmark(
    "Observation, SessionThreadSource over 1,000 chunks",
    configuration: BenchmarkPolicy.configuration(
      iterations: ObservationCorpus.iterations,
      countMetrics: [BenchmarkPolicy.itemsInvalidations, BenchmarkPolicy.streamingInvalidations])
  ) { benchmark in
    let run = await SourceRun()
    benchmark.startMeasurement()
    await run.stream()
    benchmark.stopMeasurement()
    let counts = try await run.finish()
    benchmark.measurement(BenchmarkPolicy.itemsInvalidations.metric, counts.items)
    benchmark.measurement(BenchmarkPolicy.streamingInvalidations.metric, counts.streaming)
  }
}

/// The observer counts of one source stream.
struct SourceCounts: Sendable {
  /// The changes of `thread.items`.
  let items: Int

  /// The changes of the streaming message.
  let streaming: Int
}

/// One stream through `SessionThreadSource`, with its observers.
@MainActor
final class SourceRun {
  /// The number of item changes that one transcript entry can make at its
  /// boundaries: the insert of its item, and the replace with the final
  /// entry. The limit does not change with the number of chunks.
  static let itemChangesPerEntry = 2

  /// The session.
  private let session = ObservationCorpus.makeSession()

  /// The source.
  private let source: SessionThreadSource

  /// The observer of `thread.items`.
  private let items: ChangeCounter

  /// The observer of the streaming message.
  private let streaming: ChangeCounter

  /// Makes the session, the source, and the observers.
  init() {
    let source = SessionThreadSource(session: session)
    let thread = source.thread
    self.source = source
    items = ChangeCounter { _ = thread.items }
    streaming = ChangeCounter { _ = thread.streaming[ObservationCorpus.responseID]?.text }
    source.start()
  }

  /// Streams the response. This is the measured part.
  func stream() async {
    await source.stream(ObservationCorpus.prompt)
  }

  /// Stops the observers, and checks the gate.
  ///
  /// - Returns: The observer counts.
  /// - Throws: ``BenchmarkGateFailure`` when the items observer changed on
  ///   more than the entry boundaries, or when the stream did not stream.
  func finish() async throws -> SourceCounts {
    await ObservationCorpus.settle()
    source.stop()
    items.stop()
    streaming.stop()
    let counts = SourceCounts(items: items.count, streaming: streaming.count)
    let entryCount = session.transcript.count
    let boundaryLimit = entryCount * Self.itemChangesPerEntry
    let text = ObservationCorpus.responseText(of: session.transcript.last)
    guard text.count == ObservationCorpus.chunkCount * ObservationCorpus.chunkText.count else {
      throw BenchmarkGateFailure(description: "The stream gave \(text.count) characters.")
    }
    guard counts.streaming > 0 else {
      throw BenchmarkGateFailure(description: "The streaming observer did not change.")
    }
    guard counts.items <= boundaryLimit else {
      throw BenchmarkGateFailure(
        description:
          "The items observer changed \(counts.items) times for \(entryCount) entries. The limit is \(boundaryLimit).")
    }
    return counts
  }
}

// MARK: - Tail source scenarios

/// A source of the response text while the response streams.
enum TailSource: CaseIterable, Sendable {
  /// `ResponseStream.Snapshot.transcriptEntries`.
  case snapshotEntries

  /// `SessionPropertyValues.history`.
  case propertyHistory

  /// `LanguageModelSession.transcript`.
  case sessionTranscript

  /// The name of the scenario.
  var scenarioName: String {
    switch self {
    case .snapshotEntries: "Tail source, Snapshot.transcriptEntries"
    case .propertyHistory: "Tail source, SessionPropertyValues.history"
    case .sessionTranscript: "Tail source, session.transcript"
    }
  }

  /// Whether the gate reads the metrics of the source. Only the snapshot
  /// source, the one that the kit uses, does work that does not change with
  /// the machine. The two comparison sources do one unit of work for each
  /// observation tick of the SDK, so their count, their instructions, and
  /// their wall clock all change with the machine (see
  /// ``BenchmarkPolicy/tailUpdates(gated:)``).
  var isGated: Bool {
    self == .snapshotEntries
  }
}

/// Registers the scenario of one tail source.
///
/// - Parameter source: The tail source.
private func registerTailSourceBenchmark(_ source: TailSource) {
  let tailUpdates = BenchmarkPolicy.tailUpdates(gated: source.isGated)
  Benchmark(
    source.scenarioName,
    configuration: BenchmarkPolicy.configuration(
      iterations: ObservationCorpus.iterations, countMetrics: [tailUpdates],
      gated: source.isGated)
  ) { benchmark in
    let run = await TailRun(source: source)
    benchmark.startMeasurement()
    await run.stream()
    benchmark.stopMeasurement()
    let updates = try await run.finish()
    benchmark.measurement(tailUpdates.metric, updates)
  }
}

/// One stream with no source, read through one tail source.
@MainActor
final class TailRun {
  /// The tail source.
  private let source: TailSource

  /// The session.
  private let session = ObservationCorpus.makeSession()

  /// The observer of the tail source, or `nil` for the snapshot source.
  private var observer: ChangeCounter?

  /// The snapshot updates.
  private var snapshotUpdates = 0

  /// The last response text that the tail source gave.
  private var lastText = ""

  /// Makes the session and the observer of the tail source.
  ///
  /// - Parameter source: The tail source.
  init(source: TailSource) {
    self.source = source
    let session = session
    switch source {
    case .snapshotEntries:
      observer = nil
    case .propertyHistory:
      observer = ChangeCounter { [weak self] in
        self?.lastText = ObservationCorpus.responseText(of: session.properties.history.last)
      }
    case .sessionTranscript:
      observer = ChangeCounter { [weak self] in
        self?.lastText = ObservationCorpus.responseText(of: session.transcript.last)
      }
    }
  }

  /// Streams the response, and reads the snapshots for the snapshot source.
  /// This is the measured part.
  func stream() async {
    let stream = session.streamResponse(to: ObservationCorpus.prompt)
    do {
      for try await snapshot in stream where source == .snapshotEntries {
        snapshotUpdates += 1
        lastText = ObservationCorpus.responseText(of: snapshot.transcriptEntries.last)
      }
      _ = try await stream.collect()
    } catch {
      lastText = ""
    }
  }

  /// Stops the observer, and checks that the tail source gave the full text.
  ///
  /// - Returns: The updates of the tail source.
  /// - Throws: ``BenchmarkGateFailure`` when the last text is not the full
  ///   response.
  func finish() async throws -> Int {
    await ObservationCorpus.settle()
    observer?.stop()
    let expected = ObservationCorpus.chunkCount * ObservationCorpus.chunkText.count
    guard lastText.count == expected else {
      throw BenchmarkGateFailure(
        description: "\(source.scenarioName) gave \(lastText.count) characters, not \(expected).")
    }
    return observer?.count ?? snapshotUpdates
  }
}
