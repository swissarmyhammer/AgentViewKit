import Foundation

/// One change to an ``AgentThread`` (plan.md §3.2).
///
/// A source makes these changes and calls ``AgentThread/apply(_:)``. The
/// cases follow the ACP v2 update stream, because that stream is the
/// superset of what each source sends.
public enum ThreadChange {
  /// Puts an item in the thread after the item with the id `after`.
  ///
  /// When `after` is `nil`, or no item has that id, the item goes at the end.
  /// When an item with the same id is in the thread, this change replaces
  /// that item in its position, as ``replace(_:)`` does.
  case insert(ThreadItem, after: String?)

  /// Changes the fields of the record with the id.
  ///
  /// The record changes in place, and its revision increments by one. When
  /// no record has the id, the patch makes a new record at the end. When
  /// the record is of a different kind, a new record of the patch kind
  /// replaces it in its position.
  case patch(id: String, ItemPatch)

  /// Replaces the item with the same id, in its position.
  ///
  /// The new record gets the revision of the old record plus one. When no
  /// item has the id, the item goes at the end.
  case replace(ThreadItem)

  /// Removes the item with the id. An unknown id changes nothing.
  case remove(id: String)

  /// Removes all items, plans, terminals, pending requests, and streaming
  /// messages.
  ///
  /// The state, the config options, the commands, the usage, and the info
  /// do not change, because they belong to the session.
  case clear

  /// Sets the state of the thread.
  case setState(ThreadState)

  /// Puts the plan in ``AgentThread/plans``, keyed by its id.
  case setPlan(Plan)

  /// Removes the plan with the id.
  case removePlan(PlanID)

  /// Changes the terminal with the id of the patch, or makes it.
  case upsertTerminal(TerminalPatch)

  /// Replaces the config options.
  case setConfigOptions([ConfigOption])

  /// Replaces the slash commands that the agent accepts.
  case setAvailableCommands([SlashCommand])

  /// Sets the context usage. `nil` removes it.
  case setUsage(ContextUsage?)

  /// Changes the fields of ``AgentThread/info``.
  case patchInfo(ThreadInfoPatch)

  /// Adds a permission request. A request with the same id is replaced.
  case addPermission(PermissionRequest)

  /// Removes the permission request with the id.
  case resolvePermission(PermissionRequestID)

  /// Adds an elicitation request. A request with the same id is replaced.
  case addElicitation(ElicitationRequest)

  /// Removes the elicitation request with the id.
  case resolveElicitation(ElicitationRequestID)

  /// Adds an authorization request. A request with the same id is replaced.
  case addAuthorization(AuthorizationRequest)

  /// Removes the authorization request with the id.
  case resolveAuthorization(AuthorizationRequestID)

  /// Adds text to the streaming message of the record with the id.
  ///
  /// When no streaming message has the id, this change makes one.
  case appendStreaming(id: String, text: String)

  /// Closes and removes the streaming message of the record with the id.
  ///
  /// The final text goes to the text field of the record in one patch: the
  /// content of a message, the segments of a reasoning record, or the text
  /// of a system prompt. When the thread has no record with the id, the
  /// patch makes an assistant message. A record of another kind does not
  /// change. When no streaming message has the id, this change does nothing.
  case closeStreaming(id: String)
}

/// A change to the fields of a ``TerminalRecord`` (plan.md §3.2).
///
/// The fields follow the ACP v2 `terminal_update` and
/// `terminal_output_chunk` messages.
public nonisolated struct TerminalPatch: Sendable, Hashable {
  /// The identifier of the terminal to change.
  public var id: TerminalID

  /// The command that the terminal runs.
  public var command: PatchField<String>

  /// The absolute working directory of the command.
  public var cwd: PatchField<String>

  /// The exit information of the command.
  public var exitStatus: PatchField<TerminalRecord.ExitStatus>

  /// All of the output bytes. ``PatchField/cleared`` empties the output.
  public var output: PatchField<Data>

  /// The bytes to add to the end of the output, after ``output`` applies.
  public var outputChunk: Data

  /// The `_meta` value of the source.
  public var meta: PatchField<JSONValue>

  /// Makes a terminal patch.
  ///
  /// - Parameters:
  ///   - id: The identifier of the terminal to change.
  ///   - command: The command that the terminal runs.
  ///   - cwd: The absolute working directory of the command.
  ///   - exitStatus: The exit information of the command.
  ///   - output: All of the output bytes.
  ///   - outputChunk: The bytes to add to the end of the output.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: TerminalID,
    command: PatchField<String> = .unchanged,
    cwd: PatchField<String> = .unchanged,
    exitStatus: PatchField<TerminalRecord.ExitStatus> = .unchanged,
    output: PatchField<Data> = .unchanged,
    outputChunk: Data = Data(),
    meta: PatchField<JSONValue> = .unchanged
  ) {
    self.id = id
    self.command = command
    self.cwd = cwd
    self.exitStatus = exitStatus
    self.output = output
    self.outputChunk = outputChunk
    self.meta = meta
  }
}

@MainActor
extension TerminalPatch {
  /// Makes a new terminal record with the id, and applies the patch to it.
  ///
  /// The new record has revision zero.
  ///
  /// - Returns: The new terminal record.
  func makeRecord() -> TerminalRecord {
    let record = TerminalRecord(id: id)
    applyFields(to: record)
    return record
  }

  /// Applies the patch to the record. The revision does not change.
  ///
  /// - Parameter record: The terminal record to change.
  func applyFields(to record: TerminalRecord) {
    record.command = command.applied(to: record.command)
    record.cwd = cwd.applied(to: record.cwd)
    record.exitStatus = exitStatus.applied(to: record.exitStatus)
    record.output = output.applied(to: record.output)
    record.output.append(outputChunk)
    record.meta = meta.applied(to: record.meta)
  }
}

/// A change to the fields of a ``ThreadInfo`` (plan.md §3.2).
///
/// The fields follow the ACP v2 `session_info_update` message.
public nonisolated struct ThreadInfoPatch: Sendable, Hashable {
  /// The title of the thread.
  public var title: PatchField<String>

  /// The time of the last change to the thread.
  public var updatedAt: PatchField<Date>

  /// Makes a thread info patch.
  ///
  /// - Parameters:
  ///   - title: The title of the thread.
  ///   - updatedAt: The time of the last change to the thread.
  public init(title: PatchField<String> = .unchanged, updatedAt: PatchField<Date> = .unchanged) {
    self.title = title
    self.updatedAt = updatedAt
  }

  /// Applies the patch to thread info.
  ///
  /// - Parameter info: The thread info before the patch.
  /// - Returns: The thread info after the patch.
  public func applied(to info: ThreadInfo) -> ThreadInfo {
    ThreadInfo(
      title: title.applied(to: info.title),
      updatedAt: updatedAt.applied(to: info.updatedAt)
    )
  }
}
