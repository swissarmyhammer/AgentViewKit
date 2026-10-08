//
// SessionModelObservationBenchmarks: the cost of the transcript view when
// 1,000 chunks stream into one agent message of a `SessionModel` (plan.md
// §8, §14 R4).
//
// Each iteration opens a `SessionModel` over the scripted agent of the root
// package (`ScriptedSession`), and hosts `AgentThreadView` over the model in
// an off-screen window. Outside the measurement, the agent sends the first
// chunk of one agent message, and the window shows its row. The measured
// part is: the agent sends 1,000 `agent_message_chunk` updates to that
// message, the model applies them, and the window renders until the entry
// holds each chunk.
//
// The view binds directly to the `TranscriptEntry` objects of the model. The
// chunks go through the coalescing of the model, and through no coalescer
// and no text copy of the kit. The two scenarios differ only in the cadence
// of the model:
//
//   - CADENCE ZERO: the model applies each chunk at once.
//   - DEFAULT CADENCE: the model flushes the chunks at
//     `SessionModel.defaultCoalescingCadence`, as in an app.
//
// Gates (a failed gate stops the run with an error):
//
//   - The entry holds each chunk before the time limit.
//   - The render evaluated the view that reads the content of the entry.
//
// `Tests/AgentViewKitTests/Thread/SessionModelRedrawScopeTests.swift` proves
// in a debug build that the chunks evaluate the row of the streamed entry
// only.
//

import AgentViewKit
import Benchmark
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The registration of the observation scenarios.
enum SessionModelObservationBenchmarks {
  /// The measured iterations of each scenario. Each iteration streams the
  /// whole message.
  static let iterations = 20

  /// Registers one scenario for each cadence.
  static func register() {
    for cadence in ObservationCadence.allCases {
      register(cadence: cadence)
    }
  }

  /// Registers the scenario of one cadence.
  ///
  /// - Parameter cadence: The coalescing cadence of the session model.
  private static func register(cadence: ObservationCadence) {
    Benchmark(
      cadence.scenarioName,
      configuration: BenchmarkPolicy.configuration(iterations: iterations)
    ) { benchmark in
      let iteration = try await ObservationIteration.open(cadence: cadence)
      do {
        benchmark.startMeasurement()
        try await iteration.streamChunks()
        benchmark.stopMeasurement()
      } catch {
        // `defer` cannot await, so the error path closes the iteration here.
        await iteration.close()
        throw error
      }
      try await iteration.checkAndClose()
    }
  }
}

/// The coalescing cadence of the session model of one scenario.
enum ObservationCadence: CaseIterable, Sendable {
  /// The model applies each chunk at once.
  case zero

  /// The model flushes the chunks at `SessionModel.defaultCoalescingCadence`.
  case modelDefault

  /// The name of the scenario.
  var scenarioName: String {
    switch self {
    case .zero: "Transcript stream, cadence zero"
    case .modelDefault: "Transcript stream, default cadence"
    }
  }

  /// The cadence that the session model gets.
  @MainActor var coalescingCadence: Duration {
    switch self {
    case .zero: .zero
    case .modelDefault: SessionModel.defaultCoalescingCadence
    }
  }
}

/// The error of a failed benchmark gate.
struct BenchmarkGateFailure: Error, CustomStringConvertible {
  /// What the gate found.
  let description: String
}

/// The session, the streamed entry, and the hosted view of one iteration.
@MainActor
final class ObservationIteration {
  /// The `messageId` of the streamed agent message.
  static let messageID = "benchmark-response"

  /// The text of the chunk that opens the agent message, outside the
  /// measurement.
  static let firstChunk = "Benchmark response."

  /// The number of chunks that one iteration streams.
  static let streamedChunkCount = 1_000

  /// The number of chunks in one paragraph of the message. The last chunk
  /// of each paragraph ends with a blank line, as a model response does.
  static let chunksPerParagraph = 20

  /// The end of each paragraph.
  static let paragraphBreak = "\n\n"

  /// The chunks that one iteration streams, in order.
  static let streamedChunks = (0..<streamedChunkCount).map { makeChunk(index: $0) }

  /// The number of content blocks of the entry after the stream: one block
  /// for the first chunk, and one block for each streamed chunk.
  static let streamedBlockCount = 1 + streamedChunkCount

  /// The width of the host window, in points.
  static let hostWidth: CGFloat = 640

  /// The height of the host window, in points.
  static let hostHeight: CGFloat = 800

  /// The size of the host window.
  static let hostSize = CGSize(width: hostWidth, height: hostHeight)

  /// The longest time that one wait can take before the gate fails, in
  /// seconds.
  static let waitTimeLimitSeconds = 10

  /// The longest time that one wait can take before the gate fails.
  static let waitTimeLimit = Duration.seconds(waitTimeLimitSeconds)

  /// The time between two renders while the model applies the chunks.
  static let renderInterval = Duration.milliseconds(1)

  /// The gate failure when the model shows no agent message.
  static let noEntryFailure = "The model shows no agent message."

  /// The session of the iteration.
  private let session: ScriptedSession

  /// The streamed agent message entry.
  private let entry: AgentMessageEntry

  /// The host of the thread view.
  private let host: BenchmarkHost<ObservationRoot>

  /// The evaluations of the view that reads the content of the entry.
  private let contentCount: EvaluationCount

  /// Makes the iteration from its open parts.
  ///
  /// - Parameters:
  ///   - session: The open session.
  ///   - entry: The streamed agent message entry.
  ///   - host: The host of the thread view.
  ///   - contentCount: The evaluations of the view that reads the content of
  ///     the entry.
  private init(
    session: ScriptedSession, entry: AgentMessageEntry, host: BenchmarkHost<ObservationRoot>,
    contentCount: EvaluationCount
  ) {
    self.session = session
    self.entry = entry
    self.host = host
    self.contentCount = contentCount
  }

  /// Opens a session, sends the first chunk of the agent message, and hosts
  /// the thread view.
  ///
  /// - Parameter cadence: The coalescing cadence of the session model.
  /// - Returns: The iteration, with no counted evaluation.
  /// - Throws: The error of the session, or ``BenchmarkGateFailure`` when the
  ///   model shows no agent message before the time limit. On an error after
  ///   the session opens, this function closes the session before it throws
  ///   the error again.
  static func open(cadence: ObservationCadence) async throws -> ObservationIteration {
    let session = try await ScriptedSession.open(coalescingCadence: cadence.coalescingCadence)
    let entry: AgentMessageEntry
    do {
      entry = try await openMessage(in: session)
    } catch {
      // `defer` cannot await, so the error path closes the session here.
      session.close()
      throw error
    }
    let contentCount = EvaluationCount()
    let host = BenchmarkHost(
      ObservationRoot(model: session.model, entry: entry, contentCount: contentCount), size: hostSize)
    _ = contentCount.take()
    return ObservationIteration(session: session, entry: entry, host: host, contentCount: contentCount)
  }

  /// Streams the chunks, and renders until the entry holds each chunk. This
  /// is the measured part.
  ///
  /// - Throws: The error of the transport, or ``BenchmarkGateFailure`` when
  ///   the entry does not hold each chunk before the time limit.
  func streamChunks() async throws {
    for chunk in Self.streamedChunks {
      try await session.send(update: Self.makeUpdate(text: chunk))
    }
    let entry = entry
    try await Self.wait(
      failure: "The entry holds \(entry.content.count) blocks. The stream gives \(Self.streamedBlockCount).",
      render: host.render
    ) { entry.content.count == Self.streamedBlockCount }
    host.render()
  }

  /// Closes the host and the session, and checks that the render evaluated
  /// the content of the entry. This is the check of the success path.
  ///
  /// - Throws: ``BenchmarkGateFailure`` when no render read the content.
  func checkAndClose() throws {
    let evaluations = contentCount.take()
    close()
    guard evaluations > 0 else {
      throw BenchmarkGateFailure(description: "The stream did not render the content of the entry.")
    }
  }

  /// Closes the host and the session. The success path and the error path
  /// of an iteration both call this.
  func close() {
    host.close()
    session.close()
  }

  /// Sends the first chunk of the agent message, and waits until the model
  /// shows the message.
  ///
  /// - Parameter session: The open session.
  /// - Returns: The agent message entry.
  /// - Throws: The error of the transport, or ``BenchmarkGateFailure`` when
  ///   the model shows no agent message before the time limit.
  private static func openMessage(in session: ScriptedSession) async throws -> AgentMessageEntry {
    try await session.send(update: makeUpdate(text: firstChunk))
    try await wait(failure: noEntryFailure, render: {}) { agentMessage(in: session.model) != nil }
    guard let entry = agentMessage(in: session.model) else {
      throw BenchmarkGateFailure(description: noEntryFailure)
    }
    return entry
  }

  /// Makes the text of the chunk at `index` of the stream.
  ///
  /// - Parameter index: The position of the chunk in the stream.
  /// - Returns: The text of the chunk.
  private static func makeChunk(index: Int) -> String {
    let endsParagraph = (index + 1).isMultiple(of: chunksPerParagraph)
    return " Word \(index)." + (endsParagraph ? paragraphBreak : "")
  }

  /// Makes one `agent_message_chunk` update of the streamed message.
  ///
  /// - Parameter text: The text of the chunk.
  /// - Returns: The update.
  private static func makeUpdate(text: String) -> SessionUpdate {
    .agentMessageChunk(
      ContentChunk(content: .text(TextContent(text: text)), messageId: MessageId(rawValue: messageID)))
  }

  /// The first agent message entry of `model`.
  ///
  /// - Parameter model: The session model.
  /// - Returns: The entry, or `nil` when the transcript has no agent message.
  private static func agentMessage(in model: SessionModel) -> AgentMessageEntry? {
    model.transcript.lazy.compactMap { entry -> AgentMessageEntry? in
      if case .agentMessage(let message) = entry { message } else { nil }
    }.first
  }

  /// Renders, and waits one ``renderInterval``, until `condition` is true.
  ///
  /// The wait gives the main actor to the transport and to the coalescing
  /// of the model.
  ///
  /// - Parameters:
  ///   - failure: The text of the gate failure at the time limit.
  ///   - render: Renders the hosted view.
  ///   - condition: The condition to wait for.
  /// - Throws: ``BenchmarkGateFailure`` when the condition is false at the
  ///   time limit.
  private static func wait(
    failure: @autoclosure () -> String, render: () -> Void, until condition: () -> Bool
  ) async throws {
    let deadline = ContinuousClock.now.advanced(by: waitTimeLimit)
    while !condition() {
      guard ContinuousClock.now < deadline else {
        throw BenchmarkGateFailure(description: failure())
      }
      render()
      try await Task.sleep(for: renderInterval)
    }
  }
}

/// The hosted view of an observation scenario: the thread view over the
/// session model, with a probe that reads the content of the streamed entry.
struct ObservationRoot: View {
  /// The session model.
  let model: SessionModel

  /// The streamed agent message entry.
  let entry: AgentMessageEntry

  /// The evaluations of the view that reads the content of the entry.
  let contentCount: EvaluationCount

  var body: some View {
    AgentThreadView(session: model)
      .background {
        EvaluationProbe(model: entry, property: \.content, count: contentCount)
      }
  }
}
