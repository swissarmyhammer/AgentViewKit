import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog

/// Gives the state of a `SessionModel` as the session updates that make the
/// same thread (update.md §4.2).
///
/// ``ACPThreadSource`` reads `SessionModel.updateTap()`. The tap gives only
/// the updates that arrive after the call. The updates that came before, for
/// example the replay of a resume, are already in the model. The seed gives
/// one whole-entry update for each transcript entry and one update for each
/// last-value state, so that ``SessionUpdateMapping`` stays the one mapping of
/// the kit.
enum TranscriptSeed {
  /// One step of a seed.
  enum Step {
    /// A session update that the source applies.
    case update(SessionUpdate)

    /// An error record that the model made itself, for example for a
    /// failed prompt. No session update gives an error.
    ///
    /// - Parameters:
    ///   - id: The id of the error record.
    ///   - kind: The kind of the error.
    case error(id: String, kind: ThreadError.Kind)
  }

  /// The log of the seed.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "TranscriptSeed")

  /// The steps that make the thread of a session model.
  ///
  /// - Parameter session: The session model. Flush its chunk buffer first,
  ///   so that the transcript holds each chunk that arrived.
  /// - Returns: One step for each transcript entry, in transcript order, then
  ///   one update for each last-value state that the model holds.
  static func steps(for session: SessionModel) -> [Step] {
    session.transcript.compactMap(step) + lastValueUpdates(of: session).map(Step.update)
  }

  // MARK: - Transcript

  /// The step of one transcript entry.
  ///
  /// - Parameter entry: The transcript entry.
  /// - Returns: The step, or `nil` when the entry cannot be given as an
  ///   update. The seed writes a log record for such an entry.
  private static func step(_ entry: TranscriptEntry) -> Step? {
    switch entry {
    case .userMessage(let message):
      .update(.userMessage(UserMessage(fields(of: message))))
    case .agentMessage(let message):
      .update(.agentMessage(AgentMessage(fields(of: message))))
    case .thought(let thought):
      .update(.agentThought(AgentThought(fields(of: thought))))
    case .toolCall(let call):
      toolCallUpdate(call).map(Step.update)
    case .terminal(let terminal):
      terminalUpdate(terminal).map(Step.update)
    case .plan(let plan):
      planUpdate(plan).map(Step.update)
    case .unknown(let unknown):
      .update(.unknown(unknown.type, unknown.raw))
    case .compaction(let compaction):
      compactionUpdate(compaction).map(Step.update)
    case .error(let error):
      .error(id: recordID(of: error.id), kind: .acp(code: error.code.wireValue, message: error.message))
    }
  }

  /// The fields of a whole-message update for one message entry.
  ///
  /// A local user message that has no `messageId` yet takes its local id.
  ///
  /// - Parameters:
  ///   - id: The transcript id of the entry.
  ///   - messageId: The message id of the entry, or `nil`.
  ///   - content: The content blocks of the entry.
  ///   - meta: The `_meta` value of the entry, or `nil`.
  /// - Returns: The message id, the content and the `_meta` patch.
  private static func fields(
    id: TranscriptEntry.ID,
    messageId: MessageId?,
    content: [FoundationModelsACP.ContentBlock],
    meta: FoundationModelsACP.JSONValue?
  ) -> MessageFields {
    MessageFields(
      messageId: messageId ?? MessageId(rawValue: recordID(of: id)),
      content: .value(content),
      meta: patch(meta)
    )
  }

  /// The fields of a whole-message update for a user message entry.
  private static func fields(of message: UserMessageEntry) -> MessageFields {
    fields(id: message.id, messageId: message.messageId, content: message.content, meta: message.meta)
  }

  /// The fields of a whole-message update for an agent message entry.
  private static func fields(of message: AgentMessageEntry) -> MessageFields {
    fields(id: message.id, messageId: message.messageId, content: message.content, meta: message.meta)
  }

  /// The fields of a whole-message update for a thought entry.
  private static func fields(of thought: ThoughtEntry) -> MessageFields {
    fields(id: thought.id, messageId: thought.messageId, content: thought.content, meta: thought.meta)
  }

  /// The whole tool call update of a tool call entry.
  ///
  /// - Parameter call: The tool call entry.
  /// - Returns: The update, or `nil` when the entry has no tool call id.
  private static func toolCallUpdate(_ call: ToolCallEntry) -> SessionUpdate? {
    guard case .wire(.toolCall(let toolCallId)) = call.id else {
      return unexpected(call.id)
    }
    return .toolCallUpdate(
      ToolCallUpdate(
        toolCallId: toolCallId,
        content: .value(call.content),
        kind: patch(call.kind),
        locations: .value(call.locations),
        name: patch(call.name),
        rawInput: patch(call.rawInput),
        rawOutput: patch(call.rawOutput),
        status: patch(call.status),
        title: patch(call.title),
        meta: patch(call.meta)
      ))
  }

  /// The whole terminal update of a terminal entry, with no output.
  ///
  /// The kit does not decode terminal output (update.md §4.4, §4.5), so the
  /// seed does not encode the bytes of the entry again.
  ///
  /// - Parameter terminal: The terminal entry.
  /// - Returns: The update, or `nil` when the entry has no terminal id.
  private static func terminalUpdate(_ terminal: TerminalEntry) -> SessionUpdate? {
    guard case .wire(.terminal(let terminalId)) = terminal.id else {
      return unexpected(terminal.id)
    }
    return .terminalUpdate(
      TerminalUpdate(
        terminalId: terminalId,
        command: patch(terminal.command),
        cwd: patch(terminal.cwd),
        exitStatus: patch(terminal.exitStatus),
        meta: patch(terminal.meta)
      ))
  }

  /// The plan update of a plan entry.
  ///
  /// - Parameter plan: The plan entry.
  /// - Returns: The update with the unknown content of the entry, or with its
  ///   items and plan id. `nil` when the entry has neither.
  private static func planUpdate(_ plan: PlanTranscriptEntry) -> SessionUpdate? {
    if let unknown = plan.unknownContent {
      return .planUpdate(PlanUpdate(plan: .unknown(unknown.type, unknown.payload), meta: plan.meta))
    }
    guard let planId = plan.planId else {
      return unexpected(plan.id)
    }
    return .planUpdate(PlanUpdate(plan: .items(PlanItems(entries: plan.entries, planId: planId)), meta: plan.meta))
  }

  /// The compaction update of a compaction entry, as the stable update that
  /// carries it.
  ///
  /// - Parameter compaction: The compaction entry.
  /// - Returns: The update, or `nil` when the update cannot be encoded. The
  ///   seed then writes a log record.
  private static func compactionUpdate(_ compaction: CompactionEntry) -> SessionUpdate? {
    let update = Unstable.CompactionUpdate(
      compactionId: compaction.compactionId,
      status: compaction.status,
      error: patch(compaction.error),
      summary: compaction.summary.isEmpty ? .unchanged : .value(compaction.summary),
      meta: patch(compaction.meta)
    )
    do {
      return try SessionUpdate(Unstable.SessionUpdate.compactionUpdate(update))
    } catch {
      logger.error("A compaction entry did not encode: \(String(describing: error), privacy: .public)")
      return nil
    }
  }

  // MARK: - Last-value state

  /// The updates of the last-value state of a session model: the commands,
  /// the config options, the usage, the session info and the agent state.
  ///
  /// - Parameter session: The session model.
  /// - Returns: One update for each state that the model holds.
  private static func lastValueUpdates(of session: SessionModel) -> [SessionUpdate] {
    let commands = session.availableCommands.map {
      SessionUpdate.availableCommandsUpdate(AvailableCommandsUpdate(availableCommands: $0))
    }
    let options = session.configOptions.map {
      SessionUpdate.configOptionUpdate(ConfigOptionUpdate(configOptions: $0))
    }
    let info = session.sessionInfo == SessionInfoUpdate() ? nil : SessionUpdate.sessionInfoUpdate(session.sessionInfo)
    return [
      commands, options, session.usage.map(SessionUpdate.usageUpdate), info,
      session.agentState.map(SessionUpdate.stateUpdate),
    ].compactMap(\.self)
  }

  // MARK: - Helpers

  /// The record id of a transcript entry: the wire id of a message, or the
  /// local id of an entry that the client made.
  ///
  /// - Parameter id: The transcript id.
  /// - Returns: The record id.
  private static func recordID(of id: TranscriptEntry.ID) -> String {
    switch id {
    case .local(let uuid): uuid.uuidString
    case .wire(let wire): String(describing: wire)
    }
  }

  /// The patch that sets a value, or leaves the field unchanged for `nil`.
  ///
  /// - Parameter value: The value of the entry.
  /// - Returns: The patch.
  private static func patch<Value>(_ value: Value?) -> FoundationModelsACP.PatchField<Value> {
    value.map(FoundationModelsACP.PatchField.value) ?? .unchanged
  }

  /// Records an entry whose id does not fit its kind. The model makes no such
  /// entry, so the seed stops in a debug build and skips it in a release
  /// build.
  ///
  /// - Parameter id: The id of the entry.
  /// - Returns: `nil`.
  private static func unexpected(_ id: TranscriptEntry.ID) -> SessionUpdate? {
    assertionFailure("The transcript entry \(id) has no wire id of its kind.")
    logger.error("A transcript entry has no wire id of its kind; the seed skips it.")
    return nil
  }
}

/// The fields of a whole-message update: the message id, the content and the
/// `_meta` patch.
struct MessageFields {
  /// The message id of the update.
  let messageId: MessageId

  /// The content patch of the update.
  let content: FoundationModelsACP.PatchField<[FoundationModelsACP.ContentBlock]>

  /// The `_meta` patch of the update.
  let meta: FoundationModelsACP.PatchField<FoundationModelsACP.JSONValue>
}

extension UserMessage {
  /// Makes a whole user message update from its fields.
  ///
  /// - Parameter fields: The message id, the content and the `_meta` patch.
  init(_ fields: MessageFields) {
    self.init(messageId: fields.messageId, content: fields.content, meta: fields.meta)
  }
}

extension AgentMessage {
  /// Makes a whole agent message update from its fields.
  ///
  /// - Parameter fields: The message id, the content and the `_meta` patch.
  init(_ fields: MessageFields) {
    self.init(messageId: fields.messageId, content: fields.content, meta: fields.meta)
  }
}

extension AgentThought {
  /// Makes a whole thought update from its fields.
  ///
  /// - Parameter fields: The message id, the content and the `_meta` patch.
  init(_ fields: MessageFields) {
    self.init(messageId: fields.messageId, content: fields.content, meta: fields.meta)
  }
}
