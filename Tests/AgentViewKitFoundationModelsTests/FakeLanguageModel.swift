import Foundation
import FoundationModels
import Synchronization

/// One event that the fake model sends in one model call.
nonisolated enum FakeEvent: Sendable, Hashable {
  /// Reasoning text, in the reasoning entry with the id.
  case reasoning(entryID: String, text: String)

  /// Response text, in the response entry with the id.
  ///
  /// With a `nil` id, the SDK gives the entry a new id.
  case text(entryID: String?, text: String)

  /// A tool call, in the tool calls entry with the id.
  case toolCall(entryID: String, callID: String, toolName: String, arguments: String)

  /// The fake waits until the test opens the gate one time.
  case waitForGate

  /// The fake throws `LanguageModelError.contextSizeExceeded`.
  case contextSizeExceeded(contextSize: Int, tokenCount: Int)
}

/// A gate that the fake model waits at until the test opens it.
///
/// Each ``open()`` lets one wait continue. An open before the wait is kept,
/// so the order of the two calls is not important.
nonisolated final class FakeGate: Sendable, Hashable {
  /// The state of the gate.
  private struct State {
    /// The opens that no wait used.
    var openCount = 0

    /// The waits that no open continued, in order.
    var waiters: [CheckedContinuation<Void, Never>] = []
  }

  /// The state, behind a lock.
  private let state = Mutex(State())

  /// Makes a closed gate.
  init() {}

  /// Waits until the test opens the gate.
  func wait() async {
    await withCheckedContinuation { continuation in
      let resumeNow = state.withLock { state in
        guard state.openCount > 0 else {
          state.waiters.append(continuation)
          return false
        }
        state.openCount -= 1
        return true
      }
      if resumeNow { continuation.resume() }
    }
  }

  /// Lets one wait continue.
  func open() {
    let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
      guard !state.waiters.isEmpty else {
        state.openCount += 1
        return nil
      }
      return state.waiters.removeFirst()
    }
    waiter?.resume()
  }

  static func == (lhs: FakeGate, rhs: FakeGate) -> Bool {
    lhs === rhs
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}

/// A `LanguageModel` that sends scripted events through the macOS 27
/// `LanguageModelExecutor` protocol.
///
/// Each item of ``rounds`` is the events of one model call. The executor
/// counts the tool calls entries after the last prompt of the transcript, and
/// sends the round with that position. So a script with a tool call in round
/// zero and text in round one gives one full turn with a tool.
nonisolated struct FakeLanguageModel: LanguageModel {
  /// The events of each model call of a turn, in order.
  let rounds: [[FakeEvent]]

  /// The gate that ``FakeEvent/waitForGate`` waits at.
  let gate: FakeGate

  /// The token count of each fragment that the fake sends.
  static let fragmentTokenCount = 1

  /// Makes a fake model.
  ///
  /// - Parameters:
  ///   - rounds: The events of each model call of a turn.
  ///   - gate: The gate that ``FakeEvent/waitForGate`` waits at.
  init(rounds: [[FakeEvent]], gate: FakeGate = FakeGate()) {
    self.rounds = rounds
    self.gate = gate
  }

  var capabilities: LanguageModelCapabilities {
    LanguageModelCapabilities([.toolCalling, .reasoning])
  }

  var executorConfiguration: Executor.Configuration {
    Executor.Configuration(rounds: rounds, gate: gate)
  }

  /// The executor that sends the scripted events.
  struct Executor: LanguageModelExecutor {
    /// The key that the SDK makes and keeps the executor with.
    struct Configuration: Sendable, Hashable {
      /// The events of each model call of a turn.
      let rounds: [[FakeEvent]]

      /// The gate that ``FakeEvent/waitForGate`` waits at.
      let gate: FakeGate
    }

    typealias Model = FakeLanguageModel

    /// The configuration that the SDK gave.
    private let configuration: Configuration

    /// Keeps the configuration.
    ///
    /// - Parameter configuration: The script and the gate.
    init(configuration: Configuration) throws {
      self.configuration = configuration
    }

    func respond(
      to request: LanguageModelExecutorGenerationRequest,
      model: FakeLanguageModel,
      streamingInto channel: LanguageModelExecutorGenerationChannel
    ) async throws {
      let round = Self.roundCount(in: request.transcript)
      guard round < configuration.rounds.count else { return }
      for event in configuration.rounds[round] {
        try await send(event, into: channel)
      }
    }

    /// Sends one event, waits at the gate, or throws.
    ///
    /// - Parameters:
    ///   - event: The event.
    ///   - channel: The channel of the model call.
    /// - Throws: `LanguageModelError` for an error event.
    private func send(_ event: FakeEvent, into channel: LanguageModelExecutorGenerationChannel) async throws {
      let tokens = FakeLanguageModel.fragmentTokenCount
      switch event {
      case .reasoning(let entryID, let text):
        await channel.send(.reasoning(entryID: entryID, action: .appendText(text, tokenCount: tokens)))
      case .text(let entryID, let text):
        await channel.send(.response(entryID: entryID, action: .appendText(text, tokenCount: tokens)))
      case .toolCall(let entryID, let callID, let toolName, let arguments):
        await channel.send(
          .toolCalls(
            entryID: entryID,
            action: .toolCall(
              id: callID, name: toolName, action: .appendArguments(arguments, tokenCount: tokens))))
      case .waitForGate:
        await configuration.gate.wait()
      case .contextSizeExceeded(let contextSize, let tokenCount):
        throw LanguageModelError.contextSizeExceeded(
          .init(contextSize: contextSize, tokenCount: tokenCount, debugDescription: "The context is full."))
      }
    }

    /// The number of tool calls entries after the last prompt.
    ///
    /// - Parameter transcript: The transcript of the request.
    /// - Returns: The position of the round to send.
    private static func roundCount(in transcript: Transcript) -> Int {
      let lastPrompt = transcript.lastIndex { entry in
        if case .prompt = entry { return true }
        return false
      }
      let turn = transcript[(lastPrompt ?? transcript.startIndex)...]
      return turn.filter { entry in
        if case .toolCalls = entry { return true }
        return false
      }.count
    }
  }
}
