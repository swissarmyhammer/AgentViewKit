import AgentViewKit
import AgentViewKitRouter
import Foundation
import FoundationModelsExtras

@testable import FoundationModelsRouter

/// A ``RouterSessionPort`` that records each call and gives scripted events.
final class FakeRouterSession: RouterSessionPort {
  /// One recorded call.
  enum Call: Equatable {
    /// `transcriptRows()`.
    case transcriptRows
    /// `sessionEvents()`.
    case sessionEvents
    /// `promptEvents(for:)` with the prompt.
    case promptEvents(String)
    /// `cancelCurrentTurn()`.
    case cancelCurrentTurn
    /// `respond(elicitationId:response:)` with its values.
    case respond(elicitationId: String, response: ElicitationResponse)
    /// `complete(elicitationId:)` with its value.
    case complete(elicitationId: String)
  }

  /// Each call, in call order.
  private(set) var calls: [Call] = []

  /// The rows that `transcriptRows()` gives.
  var rows: [SessionProjection.TranscriptEntry] = []

  /// The events that each prompt stream gives, before it ends.
  var promptScript: [SessionEvent] = []

  /// The error that each prompt stream throws after its events, or `nil`.
  var promptError: (any Error)?

  /// The session stream that `sessionEvents()` gives.
  private let stream: AsyncStream<SessionEvent>

  /// The continuation of the session stream.
  private let continuation: AsyncStream<SessionEvent>.Continuation

  /// Makes a fake session with an open session stream.
  init() {
    (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
  }

  /// Sends events on the session stream.
  ///
  /// - Parameter events: The events to send, in order.
  func emit(_ events: SessionEvent...) {
    for event in events {
      continuation.yield(event)
    }
  }

  /// Ends the session stream.
  func finish() {
    continuation.finish()
  }

  func transcriptRows() async -> [SessionProjection.TranscriptEntry] {
    calls.append(.transcriptRows)
    return rows
  }

  func sessionEvents() async -> AsyncStream<SessionEvent> {
    calls.append(.sessionEvents)
    return stream
  }

  func promptEvents(for prompt: String) async -> AsyncThrowingStream<SessionEvent, any Error> {
    calls.append(.promptEvents(prompt))
    let (events, eventsContinuation) = AsyncThrowingStream.makeStream(of: SessionEvent.self)
    for event in promptScript {
      eventsContinuation.yield(event)
    }
    eventsContinuation.finish(throwing: promptError)
    return events
  }

  func cancelCurrentTurn() async {
    calls.append(.cancelCurrentTurn)
  }

  func respond(elicitationId: String, response: ElicitationResponse) async {
    calls.append(.respond(elicitationId: elicitationId, response: response))
  }

  func complete(elicitationId: String) async {
    calls.append(.complete(elicitationId: elicitationId))
  }
}

/// Values that the Router tests share.
enum RouterFixtures {
  /// The elicitation id of the fixtures.
  static let elicitationId = ULID(ulidString: "01M21AEADJ22WP5CSF1P752EXA")!

  /// The session id of the fixtures.
  static let sessionID = ULID(ulidString: "01M21ABCXCQMMYMRK3QBM7CCJV")!

  /// The URL of the URL-mode fixtures.
  static let url = URL(string: "https://example.com/authorize")!

  /// The start time of the tool invocation fixture, in seconds after 1970.
  static let openedAtSeconds: TimeInterval = 1_000

  /// The start time of the tool invocation fixture.
  static let openedAt = Date(timeIntervalSince1970: openedAtSeconds)

  /// The input token count of the usage fixture.
  static let tokensIn = 300

  /// The output token count of the usage fixture.
  static let tokensOut = 100

  /// The tokens in use that the usage fixture gives.
  static let usedTokens = tokensIn + tokensOut

  /// The context fill of the usage fixture: 400 of 1,600 tokens.
  static let contextFill = 0.25

  /// The context size that the usage fixture gives.
  static let contextSize = 1_600

  /// The token usage of one attempt.
  static let usage = TokenUsage(tokensIn: tokensIn, tokensOut: tokensOut, contextFill: contextFill)

  /// The context usage that ``usage`` gives.
  static let contextUsage = ContextUsage(used: usedTokens, size: contextSize)

  /// The token count before the compaction fixture.
  static let tokensBeforeCompaction = 900

  /// The token count after the compaction fixture.
  static let tokensAfterCompaction = 300

  /// The seconds without progress of the stall fixture.
  static let stallSeconds = 30

  /// The seconds in flight of the stall fixture.
  static let flightSeconds = 60

  /// The time without progress of the stall fixture.
  static let stallTime = Duration.seconds(stallSeconds)

  /// The time in flight of the stall fixture.
  static let flightTime = Duration.seconds(flightSeconds)

  /// The number of the first turn of a session.
  static let firstTurnNumber: UInt64 = 1

  /// A turn start.
  static let turnStart = TurnStart(turnId: TurnID(firstTurnNumber), promptId: nil)

  /// The requested schema of the form fixture.
  static func requestedSchema() throws -> ElicitationRequestedSchema {
    let json = #"{"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}"#
    return try JSONDecoder().decode(ElicitationRequestedSchema.self, from: Data(json.utf8))
  }

  /// An elicitation operation event with a form request.
  static func formElicitation() throws -> OperationEvent {
    OperationEvent(
      tool: "files",
      op: "write",
      correlationID: "run-1",
      kind: .elicitation,
      detail: "Name the file",
      elicitation: FoundationModelsExtras.ElicitationRequest(
        message: "Name the file",
        elicitationId: elicitationId,
        requestedSchema: try requestedSchema()
      )
    )
  }

  /// An elicitation operation event with a URL request.
  static func urlElicitation() -> OperationEvent {
    OperationEvent(
      tool: "github",
      op: "connect",
      correlationID: "run-2",
      kind: .elicitation,
      detail: "Sign in",
      elicitation: FoundationModelsExtras.ElicitationRequest(
        message: "Sign in",
        elicitationId: elicitationId,
        url: url
      )
    )
  }

  /// A tool invocation record.
  static let invocation = ToolInvocationRecord(
    tool: "files", op: "read", correlationID: "run-3", sessionID: sessionID, openedAt: openedAt)

  /// A settled run.
  static let settled = OperationEvent(
    tool: "files", op: "read", correlationID: "run-4", kind: .completed, detail: "Done")
}
