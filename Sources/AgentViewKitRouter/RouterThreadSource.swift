import AgentViewKit
import Foundation
import FoundationModelsRouter
import OSLog

/// Fills an ``AgentThread`` from a FoundationModelsRouter session
/// (plan.md §3.3).
///
/// ``run()`` first copies the rows of `SessionProjection.transcript` into the
/// thread. Each row keeps its id. Then the source reads
/// `RoutedSession.streamSessionEvents()` until the stream ends, and changes
/// each event with ``SessionEventMapping``.
///
/// The session stream has no text fragments. ``RouterThreadActions`` reads
/// the text fragments of each turn that it starts, and gives them to
/// ``apply(_:)``. A text or reasoning fragment goes to
/// ``AgentThread/streaming``. The first fragment makes a row with a
/// provisional id, `provisional-<n>`. When `entryRecorded` names the durable
/// entry id, the oldest row of that kind that has no durable id gets it, as
/// `SessionProjection` does.
///
/// The source handles `elicitationRequested` itself, because
/// `SessionProjection` does not keep that event.
///
/// Known limit: `SessionProjection` does not keep the prompts, so a seeded
/// thread has no messages from the user. A message that the user sends
/// through ``RouterThreadActions`` shows in the thread.
public final class RouterThreadSource {
  /// The prefix of each provisional row id.
  public static let provisionalIDPrefix = "provisional-"

  /// The prefix of the id of each message from the user.
  public static let userMessageIDPrefix = "user-"

  /// The prefix of the id of each error that the source adds.
  public static let errorIDPrefix = "error-"

  /// The thread that the source fills.
  public let thread: AgentThread

  /// The session that the source reads.
  let session: any RouterSessionPort

  /// Whether ``run()`` started.
  private var hasStarted = false

  /// The number of provisional ids that the source made.
  private var provisionalCount = 0

  /// The number of messages from the user that the source added.
  private var userMessageCount = 0

  /// The number of errors that the source added.
  private var errorCount = 0

  /// The open stream of each row kind.
  private var openStreams: [StreamKind: String] = [:]

  /// The provisional row ids of each kind that have no durable id, oldest
  /// first.
  private var provisionalRows: [StreamKind: [String]] = [:]

  /// The host clock. It gives the start and the end times of the subagent
  /// runs.
  private let clock: () -> Date

  /// The host clock value when each tool call started, keyed by tool call
  /// id. A spawned run reads its start time from this table.
  private var toolCallStarts: [String: Date] = [:]

  /// The log of the source.
  private let logger = Logger(subsystem: "AgentViewKit", category: "RouterThreadSource")

  /// Makes a source for a Router session.
  ///
  /// - Parameters:
  ///   - thread: The thread to fill.
  ///   - session: The Router session to read.
  ///   - clock: The host clock for the times of the subagent runs.
  public convenience init(
    thread: AgentThread = AgentThread(),
    session: any RoutedSession,
    clock: @escaping () -> Date = Date.init
  ) {
    self.init(thread: thread, port: RoutedSessionPort(session: session), clock: clock)
  }

  /// Makes a source for a session port.
  ///
  /// - Parameters:
  ///   - thread: The thread to fill.
  ///   - port: The calls to the session.
  ///   - clock: The host clock for the times of the subagent runs.
  public init(
    thread: AgentThread = AgentThread(),
    port: any RouterSessionPort,
    clock: @escaping () -> Date = Date.init
  ) {
    self.thread = thread
    self.session = port
    self.clock = clock
  }

  /// Copies the transcript of the session into the thread, then applies each
  /// session event until the stream ends. Then closes each open stream.
  ///
  /// The source runs one time. A second call does nothing.
  public func run() async {
    guard !hasStarted else { return }
    hasStarted = true
    let events = await session.sessionEvents()
    seed(await session.transcriptRows())
    for await event in events {
      apply(event)
    }
    closeAllStreams()
  }

  /// Copies the rows of a projection into the thread.
  ///
  /// - Parameter projection: The projection to copy.
  public func seed(from projection: SessionProjection) {
    seed(projection.transcript)
  }

  /// Applies one session event to the thread.
  ///
  /// - Parameter event: The session event from the Router.
  public func apply(_ event: SessionEvent) {
    switch event {
    case .textDelta:
      applyFragment(event, kind: .text)
    case .reasoningDelta:
      applyFragment(event, kind: .reasoning)
    case .textReset:
      closeStream(kind: .text)
    case .entryRecorded(let id, let kind):
      adoptEntry(id: id, kind: kind)
    case .turnEnded:
      closeAllStreams()
      applyChanges(of: event)
    case .turnStarted, .toolCall, .toolStatus, .toolInvocation, .toolCallReport, .compaction,
      .discoveryPrimingFailed, .generationStalled, .runSettled, .elicitationRequested:
      applyChanges(of: event)
    }
    applySubagentPatch(of: event)
  }

  /// Applies one Router transcript event to the subagent runs of the thread.
  ///
  /// The `session` event of a spawned session adds its run
  /// (`Docs/decisions/subagent-source.md`). The parent of the run is the run
  /// whose thread is the parent session. A new run takes its title, its
  /// state, and its start time from the parent tool call, when the source
  /// saw that call. Other events change nothing.
  ///
  /// - Parameter event: A transcript event from a Router recorder sink.
  public func apply(_ event: TranscriptEvent) {
    let parentSession = SubagentMapping.parentSessionID(of: event)
    let parentRunID = thread.subagents.first { $0.threadID != nil && $0.threadID == parentSession }?.id
    guard case .upsertSubagent(var patch) = SubagentMapping.spawnChange(for: event, parentRunID: parentRunID)
    else { return }
    if thread.subagent(id: patch.id) == nil {
      let callID = patch.id.rawValue
      if case .toolCall(let call) = thread.item(id: callID) {
        patch.title = .value(call.title)
        patch.state = .value(SubagentMapping.state(for: call.status))
      }
      if let start = toolCallStarts[callID] {
        patch.startedAt = .value(start)
      }
    }
    thread.apply(.upsertSubagent(patch))
  }

  // MARK: - Actions support

  /// Adds a message from the user at the end of the thread.
  ///
  /// - Parameter input: The input of the user.
  func addUserMessage(_ input: UserInput) {
    userMessageCount += 1
    var blocks = [ContentBlock(text: input.text)]
    blocks += input.attachments.map { ContentBlock(content: .attachment($0)) }
    thread.apply(
      .patch(id: Self.userMessageIDPrefix + String(userMessageCount), .userMessage(content: .value(blocks))))
  }

  /// Adds an error at the end of the thread, closes each open stream, and
  /// sets the state to idle.
  ///
  /// - Parameter error: The error of the turn.
  func report(_ error: any Error) {
    closeAllStreams()
    errorCount += 1
    let message = String(describing: error)
    logger.error("A Router turn failed: \(message, privacy: .public)")
    thread.apply(
      .patch(id: Self.errorIDPrefix + String(errorCount), .error(kind: .value(.unknown(message: message)))))
    thread.apply(.setState(.idle(nil)))
  }

  // MARK: - Seed

  /// Applies the changes of each row.
  ///
  /// - Parameter rows: The rows of a projection, oldest first.
  private func seed(_ rows: [SessionProjection.TranscriptEntry]) {
    for row in rows {
      for change in SessionEventMapping.changes(for: row) {
        thread.apply(change)
      }
    }
  }

  // MARK: - Streams

  /// Sends a fragment to the stream of its kind. The first fragment opens the
  /// stream and closes the stream of the other kind.
  ///
  /// - Parameters:
  ///   - event: A text or reasoning fragment.
  ///   - kind: The kind of the row that the fragment goes to.
  private func applyFragment(_ event: SessionEvent, kind: StreamKind) {
    let id = openStreams[kind] ?? openStream(kind: kind)
    let changes = SessionEventMapping.changes(for: event, textID: id, reasoningID: id)
    for change in changes {
      thread.apply(change)
    }
  }

  /// Makes a row with a provisional id and opens its stream.
  ///
  /// - Parameter kind: The kind of the row.
  /// - Returns: The provisional id.
  private func openStream(kind: StreamKind) -> String {
    for other in openStreams.keys where other != kind {
      closeStream(kind: other)
    }
    provisionalCount += 1
    let id = Self.provisionalIDPrefix + String(provisionalCount)
    thread.apply(.patch(id: id, kind.emptyPatch))
    openStreams[kind] = id
    provisionalRows[kind, default: []].append(id)
    return id
  }

  /// Closes the stream of a kind. The row keeps its provisional id until
  /// `entryRecorded` arrives.
  ///
  /// - Parameter kind: The kind of the stream.
  private func closeStream(kind: StreamKind) {
    guard let id = openStreams.removeValue(forKey: kind) else { return }
    thread.apply(.closeStreaming(id: id))
  }

  /// Closes each open stream.
  private func closeAllStreams() {
    for kind in StreamKind.allCases {
      closeStream(kind: kind)
    }
  }

  /// Gives the durable entry id to the oldest provisional row of the kind.
  ///
  /// The row keeps its position and its content. A `.toolCalls` entry
  /// changes nothing, because each tool call row has the id of its call.
  ///
  /// - Parameters:
  ///   - id: The durable entry id.
  ///   - kind: The kind of the recorded entry.
  private func adoptEntry(id: String, kind: RecordedEntryKind) {
    let streamKind: StreamKind
    switch kind {
    case .response: streamKind = .text
    case .reasoning: streamKind = .reasoning
    case .toolCalls: return
    }
    guard var rows = provisionalRows[streamKind], !rows.isEmpty else {
      logger.debug("The recorded entry \(id, privacy: .public) has no provisional row.")
      return
    }
    let provisional = rows.removeFirst()
    provisionalRows[streamKind] = rows
    if openStreams[streamKind] == provisional {
      closeStream(kind: streamKind)
    }
    rename(provisional, to: id)
  }

  /// Replaces the item with the id `old` by a copy with the id `new`, in the
  /// same position.
  ///
  /// The copy goes in after the old item, and then the old item goes out.
  ///
  /// - Parameters:
  ///   - old: The id of the item now.
  ///   - new: The new id.
  private func rename(_ old: String, to new: String) {
    guard let copy = thread.item(id: old)?.copy(id: new) else { return }
    thread.apply(.insert(copy, after: old))
    thread.apply(.remove(id: old))
  }

  /// Keeps the start time of a tool call, and changes the subagent run of
  /// the event when the thread has that run.
  ///
  /// - Parameter event: The session event.
  private func applySubagentPatch(of event: SessionEvent) {
    guard let patch = SubagentMapping.patch(for: event, now: clock()) else { return }
    if case .toolCall(let id, _, _) = event, case .value(let start) = patch.startedAt {
      toolCallStarts[id] = start
    }
    guard thread.subagent(id: patch.id) != nil else { return }
    thread.apply(.upsertSubagent(patch))
  }

  /// Applies the mapped changes of an event.
  ///
  /// - Parameter event: The session event.
  private func applyChanges(of event: SessionEvent) {
    for change in SessionEventMapping.changes(for: event) {
      thread.apply(change)
    }
  }
}

// MARK: - Supporting types

/// The kind of row that a stream fills.
private enum StreamKind: CaseIterable {
  /// A message from the agent.
  case text

  /// A reasoning record.
  case reasoning

  /// The patch that makes an empty record of the kind.
  var emptyPatch: ItemPatch {
    switch self {
    case .text: .assistantMessage()
    case .reasoning: .reasoning()
    }
  }
}

extension ThreadItem {
  /// A copy of a message or reasoning item with another id.
  ///
  /// - Parameter id: The id of the copy.
  /// - Returns: The copy, or `nil` for another kind.
  fileprivate func copy(id: String) -> ThreadItem? {
    switch self {
    case .assistantMessage(let message):
      .assistantMessage(Message(id: id, blocks: message.blocks, meta: message.meta))
    case .reasoning(let reasoning):
      .reasoning(
        Reasoning(id: id, segments: reasoning.segments, signature: reasoning.signature, meta: reasoning.meta))
    case .system, .userMessage, .toolCall, .structured, .compaction, .error, .unknown:
      nil
    }
  }
}
