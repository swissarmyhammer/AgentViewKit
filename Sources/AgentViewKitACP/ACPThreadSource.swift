import AgentViewKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Observation

/// Fills an ``AgentThread`` from an ACP v2 session (plan.md §3.3).
///
/// The source reads the `session/update` stream of one session, changes each
/// update with ``SessionUpdateMapping``, and applies the changes to the
/// thread. A text chunk of a message or a thought goes to
/// ``AgentThread/streaming``, so that only the tail row renders again for
/// each chunk. The source closes a stream when a whole-message update for
/// the same id arrives, when a stream for another id starts, when the state
/// changes, and when the update stream ends.
///
/// The source also copies the pending permission requests of the session
/// and the pending elicitations of the client into the pending lists of the
/// thread.
@MainActor
public final class ACPThreadSource {
  /// The thread that the source fills.
  public let thread: AgentThread

  /// The display name of the agent. Each elicitation shows this name as its
  /// server.
  public let agentName: String

  /// The updates that ``run()`` reads, or `nil` after ``run()`` starts.
  private var updates: AsyncStream<SessionUpdate>?

  /// The streams that are open, keyed by record id, with the content that
  /// the record had when its stream opened.
  private var openStreams: [String: StreamPrefix] = [:]

  /// Makes a source.
  ///
  /// - Parameters:
  ///   - thread: The thread to fill.
  ///   - updates: The update stream of the session, from
  ///     `ClientSideConnection.updates(for:)`.
  ///   - agentName: The display name of the agent.
  public init(thread: AgentThread, updates: AsyncStream<SessionUpdate>, agentName: String) {
    self.thread = thread
    self.updates = updates
    self.agentName = agentName
  }

  /// Applies each update of the stream until the stream ends, then closes
  /// each open stream.
  ///
  /// The source reads the stream one time. A second call does nothing.
  public func run() async {
    guard let updates else { return }
    self.updates = nil
    for await update in updates {
      apply(update)
    }
    closeAllStreams()
  }

  /// Applies one session update to the thread.
  ///
  /// - Parameter update: The session update from the agent.
  public func apply(_ update: SessionUpdate) {
    switch update {
    case .userMessageChunk(let chunk):
      route(chunk, as: .userMessage, update: update)
    case .agentMessageChunk(let chunk):
      route(chunk, as: .assistantMessage, update: update)
    case .agentThoughtChunk(let chunk):
      route(chunk, as: .reasoning, update: update)
    case .userMessage(let message):
      closeStream(id: message.messageId.rawValue)
      applyChanges(of: update)
    case .agentMessage(let message):
      closeStream(id: message.messageId.rawValue)
      applyChanges(of: update)
    case .agentThought(let thought):
      closeStream(id: thought.messageId.rawValue)
      applyChanges(of: update)
    case .stateUpdate:
      closeAllStreams()
      applyChanges(of: update)
    case .toolCallContentChunk, .toolCallUpdate, .terminalUpdate, .terminalOutputChunk,
      .planUpdate, .availableCommandsUpdate, .configOptionUpdate, .sessionInfoUpdate,
      .usageUpdate, .unknown:
      applyChanges(of: update)
    }
  }

  // MARK: - Pending requests

  /// Copies the pending permission requests into the thread.
  ///
  /// A request that is not in the list any more is resolved. A new request
  /// is added. When a new request names a tool call, the tool call update of
  /// the request is applied first, so that the thread shows the call.
  ///
  /// - Parameter pending: The pending requests of the session, in order.
  public func mirrorPermissions<Pending: PendingPermissionRequestValue>(_ pending: [Pending]) {
    let requests = pending.map(SessionUpdateMapping.permissionRequest)
    let current = Set(requests.map(\.id))
    for stale in thread.pendingPermissions where !current.contains(stale.id) {
      thread.apply(.resolvePermission(stale.id))
    }
    let known = Set(thread.pendingPermissions.map(\.id))
    for (request, source) in zip(requests, pending) where !known.contains(request.id) {
      if case .toolCall(let subject)? = source.request.subject {
        thread.apply(SessionUpdateMapping.toolCallChange(subject.toolCall))
      }
      thread.apply(.addPermission(request))
    }
  }

  /// Copies the pending elicitations into the thread.
  ///
  /// An elicitation that is not in the list any more is resolved. A new
  /// elicitation is added. An elicitation with a mode that the kit does not
  /// know is not added.
  ///
  /// - Parameter pending: The pending elicitations of the session, in order.
  public func mirrorElicitations<Pending: PendingElicitationValue>(_ pending: [Pending]) {
    let requests = pending.compactMap { SessionUpdateMapping.elicitationRequest($0, server: agentName) }
    let current = Set(requests.map(\.id))
    for stale in thread.pendingElicitations where !current.contains(stale.id) {
      thread.apply(.resolveElicitation(stale.id))
    }
    let known = Set(thread.pendingElicitations.map(\.id))
    for request in requests where !known.contains(request.id) {
      thread.apply(.addElicitation(request))
    }
  }

  /// Copies the pending requests of a session into the thread each time
  /// that they change, until the task is cancelled.
  ///
  /// The source copies the permission requests of `session` and the
  /// elicitations that `client` holds for `sessionId`. An elicitation with
  /// no session is not for this thread.
  ///
  /// - Parameters:
  ///   - session: The observable state of the session.
  ///   - client: The client that holds the pending elicitations.
  ///   - sessionId: The id of the session.
  public func mirrorPendingRequests(
    of session: ACPSessionState, client: SwiftUIACPClient, sessionId: SessionId
  ) async {
    let changes = Observations { @MainActor in
      PendingRequests(
        permissions: session.pendingPermissionRequests,
        elicitations: client.pendingElicitations(for: sessionId)
      )
    }
    for await requests in changes {
      mirrorPermissions(requests.permissions)
      mirrorElicitations(requests.elicitations)
    }
  }

  // MARK: - Streams

  /// Sends a text chunk to the stream of its record. Another chunk closes
  /// the stream and applies its changes to the record.
  private func route(_ chunk: ContentChunk, as kind: StreamKind, update: SessionUpdate) {
    let id = chunk.messageId.rawValue
    guard case .text(let text) = chunk.content, text.annotations == nil else {
      closeStream(id: id)
      applyChanges(of: update)
      return
    }
    if openStreams[id] == nil {
      openStream(id: id, kind: kind)
    }
    thread.apply(.appendStreaming(id: id, text: text.text))
    if let meta = chunk.meta {
      thread.apply(.patch(id: id, kind.metaPatch(SessionUpdateMapping.json(meta))))
    }
  }

  /// Opens the stream of a record. The record is made when the thread has
  /// no record of the kind with the id. Each other open stream closes.
  private func openStream(id: String, kind: StreamKind) {
    for other in openStreams.keys where other != id {
      closeStream(id: other)
    }
    let item = thread.item(id: id)
    if let prefix = StreamPrefix(kind: kind, item: item) {
      openStreams[id] = prefix
    } else {
      thread.apply(.patch(id: id, kind.emptyPatch))
      openStreams[id] = StreamPrefix(kind: kind)
    }
  }

  /// Closes the stream of a record. The content that the record had before
  /// the stream goes before the streamed text.
  private func closeStream(id: String) {
    guard let prefix = openStreams.removeValue(forKey: id) else { return }
    thread.apply(.closeStreaming(id: id))
    if let patch = prefix.patch(before: thread.item(id: id)) {
      thread.apply(.patch(id: id, patch))
    }
  }

  /// Closes each open stream.
  private func closeAllStreams() {
    for id in openStreams.keys {
      closeStream(id: id)
    }
  }

  /// Applies the mapped changes of an update.
  private func applyChanges(of update: SessionUpdate) {
    for change in SessionUpdateMapping.changes(for: update) {
      thread.apply(change)
    }
  }
}

// MARK: - Supporting types

/// The pending requests of one session at one time.
private struct PendingRequests: Sendable {
  /// The permission requests of the session.
  var permissions: [PendingPermissionRequest]

  /// The elicitations of the session.
  var elicitations: [PendingElicitation]
}

/// The kind of record that a stream fills.
private enum StreamKind {
  /// A message from the user.
  case userMessage

  /// A message from the agent.
  case assistantMessage

  /// A reasoning record.
  case reasoning

  /// The patch that makes an empty record of the kind.
  var emptyPatch: ItemPatch {
    switch self {
    case .userMessage: .userMessage()
    case .assistantMessage: .assistantMessage()
    case .reasoning: .reasoning()
    }
  }

  /// The patch that sets the `_meta` value of a record of the kind.
  func metaPatch(_ meta: AgentViewKit.JSONValue) -> ItemPatch {
    switch self {
    case .userMessage: .userMessage(meta: .value(meta))
    case .assistantMessage: .assistantMessage(meta: .value(meta))
    case .reasoning: .reasoning(meta: .value(meta))
    }
  }
}

/// The content that a record had when its stream opened.
///
/// Closing a stream replaces the text field of the record with the streamed
/// text. The prefix puts the earlier content back before that text.
private enum StreamPrefix {
  /// The blocks of a message from the user.
  case userMessage([AgentViewKit.ContentBlock])

  /// The blocks of a message from the agent.
  case assistantMessage([AgentViewKit.ContentBlock])

  /// The segments of a reasoning record.
  case reasoning([String])

  /// An empty prefix of the kind.
  init(kind: StreamKind) {
    switch kind {
    case .userMessage: self = .userMessage([])
    case .assistantMessage: self = .assistantMessage([])
    case .reasoning: self = .reasoning([])
    }
  }

  /// The content of the item, or `nil` when the item is not of the kind.
  init?(kind: StreamKind, item: ThreadItem?) {
    switch (kind, item) {
    case (.userMessage, .userMessage(let message)?): self = .userMessage(message.blocks)
    case (.assistantMessage, .assistantMessage(let message)?):
      self = .assistantMessage(message.blocks)
    case (.reasoning, .reasoning(let reasoning)?): self = .reasoning(reasoning.segments)
    default: return nil
    }
  }

  /// The patch that puts the prefix before the content of the closed
  /// record.
  ///
  /// - Parameter item: The item after the stream closed.
  /// - Returns: The patch, or `nil` when the prefix is empty or the item is
  ///   of another kind.
  func patch(before item: ThreadItem?) -> ItemPatch? {
    switch (self, item) {
    case (.userMessage(let blocks), .userMessage(let message)?) where !blocks.isEmpty:
      .userMessage(content: .value(blocks + message.blocks))
    case (.assistantMessage(let blocks), .assistantMessage(let message)?) where !blocks.isEmpty:
      .assistantMessage(content: .value(blocks + message.blocks))
    case (.reasoning(let segments), .reasoning(let reasoning)?) where !segments.isEmpty:
      .reasoning(segments: .value(segments + reasoning.segments))
    default:
      nil
    }
  }
}

nonisolated extension PendingPermissionRequest: PendingPermissionRequestValue {}

nonisolated extension PendingElicitation: PendingElicitationValue {}
