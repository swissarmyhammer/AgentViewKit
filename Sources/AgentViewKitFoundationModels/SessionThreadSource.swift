import AgentViewKit
import Foundation
import FoundationModels
import OSLog
import Observation

/// Fills an ``AgentViewKit/AgentThread`` from a live FoundationModels
/// `LanguageModelSession` (plan.md §3.3).
///
/// ``start()`` copies the items of `session.transcript` into the thread with
/// ``TranscriptMapping``. Then the source observes `session.transcript`,
/// `session.isResponding`, and `session.usage` with
/// `withObservationTracking`, again after each change. At each change, the
/// source compares the entries with the entries that it applied before, by
/// id. A new entry gives an insert, a changed entry gives a replace, and an
/// entry that is gone gives a remove. The id of each item is the id of its
/// transcript entry, or the id of its tool call.
///
/// ``stream(_:)`` runs `session.streamResponse(to:)`. Each text delta of the
/// response goes to ``AgentViewKit/AgentThread/streaming``. The source does
/// not replace the item of the response while it streams, so a chunk does not
/// change ``AgentViewKit/AgentThread/items``. At the end, the source closes
/// the stream and applies the final entries of the response.
///
/// The SDK gives no times. The source stamps the start time of a tool call
/// when it first sees the call, and the end time when it first sees the
/// output of the call.
///
/// Known limit: `ThreadChange` cannot put an item before the first item. A
/// new entry at the start of a transcript that already has items goes after
/// the last item.
public final class SessionThreadSource {
  /// The prefix of the id of each error that the source adds.
  public static let errorIDPrefix = "error-"

  /// The thread that the source fills.
  public let thread: AgentThread

  /// The session that the source reads.
  public let session: LanguageModelSession

  /// The catalog that decodes the structured segments.
  let catalog: StructuredCatalog

  /// The measure of the context window, or `nil` when the host gives none.
  let contextWindow: ContextWindow?

  /// The host clock. It gives the start and the end times of the tool calls.
  private let clock: () -> Date

  /// Whether the source observes the session.
  private var isObserving = false

  /// The state of each entry that the source applied, keyed by entry id.
  private var appliedEntries: [String: AppliedEntry] = [:]

  /// The host times of each tool call, keyed by call id.
  private var callTimes: [String: CallTimes] = [:]

  /// The ids of the tool calls whose tool threw an error.
  private var failedCallIDs: Set<String> = []

  /// The open stream, or `nil` when no response streams.
  private var openStream: OpenStream?

  /// The number of errors that the source added.
  private var errorCount = 0

  /// The last measured fill of the context window, or `nil` before the first
  /// measure.
  private var contextFill: ContextFill?

  /// The task that measures the context window now.
  private var measureTask: Task<Void, Never>?

  /// The log of the source.
  private let logger = Logger(subsystem: "AgentViewKit", category: "SessionThreadSource")

  /// Makes a source for a session.
  ///
  /// - Parameters:
  ///   - session: The session to read.
  ///   - thread: The thread to fill.
  ///   - catalog: The catalog that decodes the structured segments.
  ///   - contextWindow: The measure of the context window of the model of
  ///     the session. Without a measure, the usage has `used` and `size`
  ///     equal to zero.
  ///   - clock: The host clock for the times of the tool calls.
  public init(
    session: LanguageModelSession,
    thread: AgentThread = AgentThread(),
    catalog: StructuredCatalog = .standard,
    contextWindow: ContextWindow? = nil,
    clock: @escaping () -> Date = Date.init
  ) {
    self.session = session
    self.thread = thread
    self.catalog = catalog
    self.contextWindow = contextWindow
    self.clock = clock
  }

  // MARK: - Observation

  /// Copies the transcript of the session into the thread, and starts to
  /// observe the session.
  ///
  /// A second call does nothing until ``stop()``.
  public func start() {
    guard !isObserving else { return }
    isObserving = true
    observe()
  }

  /// Stops the observation of the session. The thread keeps its items.
  public func stop() {
    isObserving = false
    measureTask?.cancel()
    measureTask = nil
  }

  /// Reads the observed values of the session, applies them, and observes
  /// them again after the next change.
  private func observe() {
    guard isObserving else { return }
    let values = withObservationTracking {
      ObservedValues(
        transcript: session.transcript, isResponding: session.isResponding, usage: session.usage)
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.observe()
      }
    }
    apply(values)
  }

  /// Applies the observed values of the session to the thread.
  ///
  /// - Parameter values: The values that the source read.
  private func apply(_ values: ObservedValues) {
    let changed = update(from: values.transcript)
    setState(values.isResponding ? .running : .idle(nil))
    if openStream == nil {
      publishUsage(tokens: TokenCounts(values.usage))
    }
    if changed {
      measureContext(of: values.transcript)
    }
  }

  // MARK: - Streaming

  /// Sends a prompt to the session and streams the response into the thread.
  ///
  /// Each text delta of the response goes to the streaming message of the
  /// response entry. When the stream ends, the source closes the streaming
  /// message and applies the final entries of the response. When the session
  /// throws, the source adds an error item.
  ///
  /// - Parameter prompt: The text of the prompt.
  public func stream(_ prompt: String) async {
    let baseline = TokenCounts(session.usage)
    let responseStream = session.streamResponse(to: prompt)
    setState(.running)
    defer { setState(.idle(nil)) }
    do {
      for try await snapshot in responseStream {
        applySnapshot(
          rawContent: snapshot.rawContent, entries: snapshot.transcriptEntries,
          tokens: baseline + TokenCounts(snapshot.usage))
      }
      let response = try await responseStream.collect()
      closeStream()
      update(from: session.transcript, replacing: response.transcriptEntries)
      publishUsage(tokens: TokenCounts(session.usage))
      measureContext(of: session.transcript)
    } catch {
      closeStream()
      report(error)
    }
  }

  /// Applies one snapshot of a stream.
  ///
  /// - Parameters:
  ///   - rawContent: The content of the response so far.
  ///   - entries: The transcript entries of the response so far.
  ///   - tokens: The token counts of the session with the response so far.
  private func applySnapshot(
    rawContent: GeneratedContent,
    entries: ArraySlice<Transcript.Entry>,
    tokens: TokenCounts
  ) {
    publishUsage(tokens: tokens)
    let responseID = entries.last { entry in
      if case .response = entry { return true }
      return false
    }?.id
    guard let responseID else { return }
    let text = Self.text(of: rawContent)
    if openStream?.id != responseID {
      closeStream()
      update(from: session.transcript)
      openStream = OpenStream(id: responseID, text: "")
    }
    guard var stream = openStream else { return }
    let delta = text.hasPrefix(stream.text) ? String(text.dropFirst(stream.text.count)) : text
    stream.text = text
    openStream = stream
    guard !delta.isEmpty else { return }
    thread.apply(.appendStreaming(id: responseID, text: delta))
  }

  /// Closes the open stream, if any.
  ///
  /// The final text goes to the record of the response. When the transcript
  /// of the session has no entry for the stream, the source removes the
  /// record, because the session reverted the response.
  private func closeStream() {
    guard let stream = openStream else { return }
    openStream = nil
    thread.apply(.closeStreaming(id: stream.id))
    let isInTranscript = session.transcript.contains { $0.id == stream.id }
    if !isInTranscript {
      appliedEntries[stream.id] = nil
      thread.apply(.remove(id: stream.id))
    }
  }

  /// The text of the content of a response.
  ///
  /// - Parameter content: The content.
  /// - Returns: The string value, or the JSON text when the content is not a
  ///   string.
  static func text(of content: GeneratedContent) -> String {
    (try? content.value(String.self)) ?? content.jsonString
  }

  // MARK: - Errors

  /// Adds an error item at the end of the thread, and applies the transcript
  /// that the session has after the error.
  ///
  /// A host that calls `session.respond(to:)` itself calls this function
  /// with the error that the call threw. A `ToolCallError` also marks the
  /// last running call of its tool as ``AgentViewKit/ToolCallStatus/failed``.
  ///
  /// - Parameter error: The error that the session threw.
  public func report(_ error: any Error) {
    logger.error("A FoundationModels turn failed: \(String(describing: error), privacy: .public)")
    if let toolError = error as? LanguageModelSession.ToolCallError {
      markFailed(toolName: toolError.tool.name)
    }
    update(from: session.transcript)
    errorCount += 1
    thread.apply(
      .insert(
        .error(ThreadError(id: Self.errorIDPrefix + String(errorCount), kind: SessionErrorMapping.kind(for: error))),
        after: nil))
    setState(.idle(nil))
  }

  /// Sets the state of the thread when it is different.
  ///
  /// - Parameter state: The new state.
  private func setState(_ state: ThreadState) {
    guard thread.state != state else { return }
    thread.apply(.setState(state))
  }

  /// Marks the last running call of a tool as failed.
  ///
  /// - Parameter toolName: The name of the tool that threw.
  private func markFailed(toolName: String) {
    let call = thread.items.reversed().lazy.compactMap { item -> ToolCallRecord? in
      guard case .toolCall(let record) = item, record.title == toolName, record.status == .inProgress
      else { return nil }
      return record
    }.first
    guard let call else { return }
    failedCallIDs.insert(call.id)
    call.endedAt = stamp(callID: call.id, isComplete: true).endedAt
    thread.apply(.patch(id: call.id, .toolCall(status: .value(.failed))))
  }

  // MARK: - Transcript

  /// Applies the entries of a transcript to the thread.
  ///
  /// - Parameters:
  ///   - transcript: The transcript of the session.
  ///   - finalEntries: The final entries of a response. Each one replaces
  ///     the entry of the transcript with the same id.
  /// - Returns: `true` when the thread changed.
  @discardableResult
  private func update(
    from transcript: Transcript,
    replacing finalEntries: ArraySlice<Transcript.Entry> = []
  ) -> Bool {
    let overrides = Dictionary(finalEntries.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    let entries = transcript.map { overrides[$0.id] ?? $0 }
    let context = MappingContext(entries)
    let lastKnown = entries.lastIndex { appliedEntries[$0.id] != nil }
    let removed = removeMissingEntries(keeping: Set(entries.map(\.id)))
    var anchor: String?
    var changed = removed
    for (position, entry) in entries.enumerated() {
      let applied = appliedEntries[entry.id]
      let state = AppliedEntry(entry: entry, context: context, itemIDs: applied?.itemIDs ?? [])
      let isStreaming = openStream?.id == entry.id
      guard applied?.matches(state) != true, !(isStreaming && applied != nil) else {
        anchor = applied?.itemIDs.last ?? anchor
        continue
      }
      let placement = lastKnown.map { position > $0 } ?? true ? Placement.end : .after(anchor)
      anchor = apply(entry, context: context, replacing: applied, placement: placement) ?? anchor
      changed = true
    }
    return changed
  }

  /// Removes the items of each applied entry that the transcript no longer
  /// has.
  ///
  /// - Parameter ids: The ids of the entries of the transcript.
  /// - Returns: `true` when the source removed an entry.
  private func removeMissingEntries(keeping ids: Set<String>) -> Bool {
    let missing = appliedEntries.keys.filter { !ids.contains($0) }
    for id in missing {
      for itemID in appliedEntries.removeValue(forKey: id)?.itemIDs ?? [] {
        thread.apply(.remove(id: itemID))
      }
    }
    return !missing.isEmpty
  }

  /// Maps one entry and puts its items in the thread.
  ///
  /// - Parameters:
  ///   - entry: The entry.
  ///   - context: The tool outputs and the call ids of the transcript.
  ///   - previous: The state of the entry that the source applied before.
  ///   - placement: Where the new items of the entry go. An item that the
  ///     thread has keeps its position.
  /// - Returns: The id of the last item of the entry, or `nil` when the entry
  ///   has no items.
  private func apply(
    _ entry: Transcript.Entry,
    context: MappingContext,
    replacing previous: AppliedEntry?,
    placement: Placement
  ) -> String? {
    let items = TranscriptMapping.items(
      for: entry, outputs: context.outputs, callIDs: context.callIDs, catalog: catalog)
    items.forEach(stampToolCall)
    let itemIDs = items.map(\.id)
    for staleID in previous?.itemIDs ?? [] where !itemIDs.contains(staleID) {
      thread.apply(.remove(id: staleID))
    }
    var last: String?
    if case .after(let anchor) = placement {
      last = anchor
    }
    for item in items {
      let isNew = thread.item(id: item.id) == nil
      thread.apply(.insert(item, after: isNew && placement == .end ? nil : last))
      last = item.id
    }
    appliedEntries[entry.id] = AppliedEntry(entry: entry, context: context, itemIDs: itemIDs)
    return itemIDs.last
  }

  /// Writes the host times and the failed status to a tool call item.
  ///
  /// - Parameter item: A mapped item. Other kinds do not change.
  private func stampToolCall(_ item: ThreadItem) {
    guard case .toolCall(let record) = item else { return }
    let times = stamp(callID: record.id, isComplete: record.status == .completed)
    record.startedAt = times.startedAt
    record.endedAt = times.endedAt
    if failedCallIDs.contains(record.id) {
      record.status = .failed
    }
  }

  /// Records the host times of a tool call.
  ///
  /// - Parameters:
  ///   - callID: The id of the call.
  ///   - isComplete: Whether the call has ended.
  /// - Returns: The start time, which is the time of the first record, and
  ///   the end time, which is the time of the first record with
  ///   `isComplete`.
  private func stamp(callID: String, isComplete: Bool) -> CallTimes {
    let now = clock()
    var times = callTimes[callID] ?? CallTimes(startedAt: now)
    if isComplete, times.endedAt == nil {
      times.endedAt = now
    }
    callTimes[callID] = times
    return times
  }

  // MARK: - Usage

  /// Measures the fill of the context window, and then writes the usage.
  ///
  /// A new measure cancels the measure that runs.
  ///
  /// - Parameter transcript: The transcript to count.
  private func measureContext(of transcript: Transcript) {
    guard let contextWindow else { return }
    measureTask?.cancel()
    measureTask = Task { [weak self] in
      do {
        let size = try await contextWindow.size()
        let used = try await contextWindow.tokenCount(transcript)
        guard !Task.isCancelled, let self else { return }
        contextFill = ContextFill(used: used, size: size)
        publishUsage(tokens: nil)
      } catch {
        self?.logger.error("The context window measure failed: \(String(describing: error), privacy: .public)")
      }
    }
  }

  /// Writes the usage of the thread when it changed
  /// (`Docs/decisions/usage-model.md`).
  ///
  /// The source fills `used`, `size`, `input`, and `output`, and keeps the
  /// other parts of the usage of the thread.
  ///
  /// - Parameter tokens: The new token counts, or `nil` to keep the counts
  ///   of the thread.
  private func publishUsage(tokens: TokenCounts?) {
    var usage = thread.usage ?? ContextUsage(used: 0, size: 0)
    if let contextFill {
      usage.used = contextFill.used
      usage.size = contextFill.size
    }
    if let tokens {
      usage.input = tokens.input
      usage.output = tokens.output
    }
    guard usage != thread.usage else { return }
    thread.apply(.setUsage(usage))
  }
}

// MARK: - Supporting types

/// The values of a session that the source observes.
private struct ObservedValues {
  /// The transcript of the session.
  let transcript: Transcript

  /// Whether the session runs a turn.
  let isResponding: Bool

  /// The cumulative token counts of the session.
  let usage: LanguageModelSession.Usage
}

/// The tool outputs and the tool call ids of a transcript.
private struct MappingContext {
  /// The tool outputs, keyed by id.
  let outputs: [String: Transcript.ToolOutput]

  /// The ids of the tool calls.
  let callIDs: Set<String>

  /// Reads the context of the entries of a transcript.
  ///
  /// - Parameter entries: The entries, in order.
  init(_ entries: [Transcript.Entry]) {
    let outputList = entries.compactMap { entry -> Transcript.ToolOutput? in
      guard case .toolOutput(let output) = entry else { return nil }
      return output
    }
    outputs = Dictionary(outputList.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    callIDs = Set(
      entries.flatMap { entry -> [String] in
        guard case .toolCalls(let calls) = entry else { return [] }
        return calls.map(\.id)
      })
  }
}

/// The state of an entry that the source applied.
private struct AppliedEntry {
  /// The entry.
  let entry: Transcript.Entry

  /// The outputs of the calls of a tool calls entry, in call order.
  let outputs: [Transcript.ToolOutput?]

  /// Whether a tool output entry has a call in the transcript.
  let hasCall: Bool

  /// The ids of the items of the entry, in order.
  let itemIDs: [String]

  /// Reads the state of an entry.
  ///
  /// - Parameters:
  ///   - entry: The entry.
  ///   - context: The tool outputs and the call ids of the transcript.
  ///   - itemIDs: The ids of the items of the entry.
  init(entry: Transcript.Entry, context: MappingContext, itemIDs: [String]) {
    self.entry = entry
    self.itemIDs = itemIDs
    switch entry {
    case .toolCalls(let calls):
      outputs = calls.map { context.outputs[$0.id] }
      hasCall = false
    case .toolOutput(let output):
      outputs = []
      hasCall = context.callIDs.contains(output.id)
    default:
      outputs = []
      hasCall = false
    }
  }

  /// Whether the other state maps to the same items.
  ///
  /// - Parameter other: The state to compare.
  /// - Returns: `true` when the entries, the outputs, and the call flags are
  ///   equal.
  func matches(_ other: AppliedEntry) -> Bool {
    entry == other.entry && outputs == other.outputs && hasCall == other.hasCall
  }
}

/// Where the new items of an entry go.
private enum Placement: Equatable {
  /// At the end of the thread. The entry comes after each applied entry.
  case end

  /// After the item with the id, or at the end when the id is `nil`. The
  /// entry comes before an applied entry.
  case after(String?)
}

/// The host times of a tool call.
private struct CallTimes {
  /// The time when the source first saw the call.
  var startedAt: Date

  /// The time when the source first saw the output of the call.
  var endedAt: Date?
}

/// A response that streams.
private struct OpenStream {
  /// The id of the response entry.
  let id: String

  /// The text that the source sent to the streaming message.
  var text: String
}

/// A measured fill of the context window.
private struct ContextFill {
  /// The number of tokens that the transcript uses.
  let used: Int

  /// The number of tokens that the window holds.
  let size: Int
}

/// The input and output token counts of a session.
private struct TokenCounts {
  /// The input token counts.
  let input: ContextUsage.Input

  /// The output token counts.
  let output: ContextUsage.Output

  /// Reads the token counts of a session usage value.
  ///
  /// - Parameter usage: The usage value.
  init(_ usage: LanguageModelSession.Usage) {
    input = ContextUsage.Input(total: usage.input.totalTokenCount, cached: usage.input.cachedTokenCount)
    output = ContextUsage.Output(
      total: usage.output.totalTokenCount, reasoning: usage.output.reasoningTokenCount)
  }

  /// Makes token counts.
  ///
  /// - Parameters:
  ///   - input: The input token counts.
  ///   - output: The output token counts.
  init(input: ContextUsage.Input, output: ContextUsage.Output) {
    self.input = input
    self.output = output
  }

  /// The sum of two token counts.
  ///
  /// A stream gives the counts of its response. The session gives the
  /// cumulative counts before the stream. The sum is the cumulative count
  /// with the response.
  static func + (lhs: TokenCounts, rhs: TokenCounts) -> TokenCounts {
    TokenCounts(
      input: ContextUsage.Input(
        total: lhs.input.total + rhs.input.total, cached: lhs.input.cached + rhs.input.cached),
      output: ContextUsage.Output(
        total: lhs.output.total + rhs.output.total, reasoning: lhs.output.reasoning + rhs.output.reasoning))
  }
}
