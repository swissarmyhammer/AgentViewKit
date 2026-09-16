/// A change to the fields of one thread record (plan.md §3.2).
///
/// There is one field case for each ``ThreadItem`` case. Each member is a
/// ``PatchField``, so a source sends only the fields that changed. A chunk
/// case adds one part to the end of the content of the record.
///
/// ``AgentThread`` applies a patch to the record with the same id. When no
/// record has the id, the patch makes a new record of its kind.
public nonisolated enum ItemPatch: Sendable, Hashable {
  /// Changes a ``SystemPrompt``.
  ///
  /// - Parameters:
  ///   - text: The text of the instructions.
  ///   - meta: The `_meta` value of the source.
  case system(text: PatchField<String> = .unchanged, meta: PatchField<JSONValue> = .unchanged)

  /// Changes a message from the user.
  ///
  /// - Parameters:
  ///   - content: The blocks of the message.
  ///   - meta: The `_meta` value of the source.
  case userMessage(
    content: PatchField<[ContentBlock]> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )

  /// Adds one block to the end of a message from the user.
  case userMessageChunk(ContentBlock)

  /// Changes a message from the agent.
  ///
  /// - Parameters:
  ///   - content: The blocks of the message.
  ///   - meta: The `_meta` value of the source.
  case assistantMessage(
    content: PatchField<[ContentBlock]> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )

  /// Adds one block to the end of a message from the agent.
  case assistantMessageChunk(ContentBlock)

  /// Changes a ``Reasoning`` record.
  ///
  /// - Parameters:
  ///   - segments: The text segments of the reasoning.
  ///   - signature: The signature that the model gave.
  ///   - meta: The `_meta` value of the source.
  case reasoning(
    segments: PatchField<[String]> = .unchanged,
    signature: PatchField<String> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )

  /// Adds one text segment to the end of a ``Reasoning`` record.
  case reasoningChunk(String)

  /// Changes a ``ToolCallRecord``.
  ///
  /// ``PatchField/cleared`` sets `kind` to ``ToolKind/other`` and `status`
  /// to ``ToolCallStatus/pending``, the values of a new record.
  ///
  /// - Parameters:
  ///   - title: The text that tells what the tool does.
  ///   - kind: The type of the tool.
  ///   - status: The progress of the call.
  ///   - content: The output of the call.
  ///   - locations: The files that the call reads or changes.
  ///   - rawInput: The input that the agent sent to the tool.
  ///   - rawOutput: The output that the tool sent back.
  ///   - meta: The `_meta` value of the source.
  case toolCall(
    title: PatchField<String> = .unchanged,
    kind: PatchField<ToolKind> = .unchanged,
    status: PatchField<ToolCallStatus> = .unchanged,
    content: PatchField<[ToolContent]> = .unchanged,
    locations: PatchField<[ToolCallLocation]> = .unchanged,
    rawInput: PatchField<JSONValue> = .unchanged,
    rawOutput: PatchField<JSONValue> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )

  /// Adds one part to the end of the output of a ``ToolCallRecord``.
  case toolCallChunk(ToolContent)

  /// Changes a ``StructuredRecord``.
  ///
  /// ``PatchField/cleared`` sets `payload` to ``JSONValue/null``.
  ///
  /// - Parameters:
  ///   - schemaName: The schema name of the segment.
  ///   - payload: The content of the segment.
  ///   - meta: The `_meta` value of the source.
  case structured(
    schemaName: PatchField<String> = .unchanged,
    payload: PatchField<JSONValue> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )

  /// Changes a ``CompactionMarker``.
  ///
  /// - Parameters:
  ///   - summary: The summary that replaced the earlier items.
  ///   - meta: The `_meta` value of the source.
  case compaction(
    summary: PatchField<String> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )

  /// Changes a ``ThreadError``.
  ///
  /// ``PatchField/cleared`` sets `kind` to
  /// ``ThreadError/Kind/unknown(message:)`` with an empty message.
  ///
  /// - Parameters:
  ///   - kind: The type of the error and its values.
  ///   - meta: The `_meta` value of the source.
  case error(
    kind: PatchField<ThreadError.Kind> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )

  /// Changes an ``UnknownRecord``.
  ///
  /// ``PatchField/cleared`` sets `raw` to ``JSONValue/null``.
  ///
  /// - Parameters:
  ///   - kind: The name of the item kind that the source gave.
  ///   - raw: The item as the source gave it.
  ///   - meta: The `_meta` value of the source.
  case unknown(
    kind: PatchField<String> = .unchanged,
    raw: PatchField<JSONValue> = .unchanged,
    meta: PatchField<JSONValue> = .unchanged
  )
}

// MARK: - Application

/// The values that ``PatchField/cleared`` sets on fields that are not
/// optional and are not collections.
private nonisolated enum ClearedValue {
  /// The kind of a new tool call record.
  static let toolKind = ToolKind.other

  /// The status of a new tool call record.
  static let toolCallStatus = ToolCallStatus.pending

  /// The JSON value of a payload with no content.
  static let json = JSONValue.null

  /// The kind of an error with no known kind.
  static let errorKind = ThreadError.Kind.unknown(message: "")
}

@MainActor
extension ItemPatch {
  /// Makes a new item with the id, and applies the patch to it.
  ///
  /// The new record has revision zero.
  ///
  /// - Parameter id: The identifier of the new record.
  /// - Returns: An item of the kind of the patch.
  func makeItem(id: String) -> ThreadItem {
    let item = emptyItem(id: id)
    applyFields(to: item)
    return item
  }

  /// Applies the patch to the record of the item. The revision does not
  /// change.
  ///
  /// - Parameter item: The item to change.
  /// - Returns: `false` when the item is of a different kind. Then the
  ///   record does not change.
  @discardableResult
  func applyFields(to item: ThreadItem) -> Bool {
    switch self {
    case .system(let text, let meta):
      update(item.record as? SystemPrompt) { record in
        record.text = text.applied(to: record.text)
        record.meta = meta.applied(to: record.meta)
      }
    case .userMessage(let content, let meta):
      applyMessage(content: content, meta: meta, to: item.userMessage)
    case .userMessageChunk(let block):
      update(item.userMessage) { $0.blocks.append(block) }
    case .assistantMessage(let content, let meta):
      applyMessage(content: content, meta: meta, to: item.assistantMessage)
    case .assistantMessageChunk(let block):
      update(item.assistantMessage) { $0.blocks.append(block) }
    case .reasoning(let segments, let signature, let meta):
      update(item.record as? Reasoning) { record in
        record.segments = segments.applied(to: record.segments)
        record.signature = signature.applied(to: record.signature)
        record.meta = meta.applied(to: record.meta)
      }
    case .reasoningChunk(let segment):
      update(item.record as? Reasoning) { $0.segments.append(segment) }
    case .toolCall(let title, let kind, let status, let content, let locations,
      let rawInput, let rawOutput, let meta):
      update(item.record as? ToolCallRecord) { record in
        record.title = title.applied(to: record.title)
        record.kind = kind.applied(to: record.kind, clearedValue: ClearedValue.toolKind)
        record.status = status.applied(
          to: record.status, clearedValue: ClearedValue.toolCallStatus
        )
        record.content = content.applied(to: record.content)
        record.locations = locations.applied(to: record.locations)
        record.rawInput = rawInput.applied(to: record.rawInput)
        record.rawOutput = rawOutput.applied(to: record.rawOutput)
        record.meta = meta.applied(to: record.meta)
      }
    case .toolCallChunk(let content):
      update(item.record as? ToolCallRecord) { $0.content.append(content) }
    case .structured(let schemaName, let payload, let meta):
      update(item.record as? StructuredRecord) { record in
        record.schemaName = schemaName.applied(to: record.schemaName)
        record.payload = payload.applied(to: record.payload, clearedValue: ClearedValue.json)
        record.meta = meta.applied(to: record.meta)
      }
    case .compaction(let summary, let meta):
      update(item.record as? CompactionMarker) { record in
        record.summary = summary.applied(to: record.summary)
        record.meta = meta.applied(to: record.meta)
      }
    case .error(let kind, let meta):
      update(item.record as? ThreadError) { record in
        record.kind = kind.applied(to: record.kind, clearedValue: ClearedValue.errorKind)
        record.meta = meta.applied(to: record.meta)
      }
    case .unknown(let kind, let raw, let meta):
      update(item.record as? UnknownRecord) { record in
        record.kind = kind.applied(to: record.kind)
        record.raw = raw.applied(to: record.raw, clearedValue: ClearedValue.json)
        record.meta = meta.applied(to: record.meta)
      }
    }
  }

  /// Makes an item of the kind of the patch, with empty fields.
  private func emptyItem(id: String) -> ThreadItem {
    switch self {
    case .system:
      .system(SystemPrompt(id: id, text: ""))
    case .userMessage, .userMessageChunk:
      .userMessage(Message(id: id, blocks: []))
    case .assistantMessage, .assistantMessageChunk:
      .assistantMessage(Message(id: id, blocks: []))
    case .reasoning, .reasoningChunk:
      .reasoning(Reasoning(id: id, segments: []))
    case .toolCall, .toolCallChunk:
      .toolCall(ToolCallRecord(id: id, title: ""))
    case .structured:
      .structured(StructuredRecord(id: id, schemaName: "", payload: ClearedValue.json))
    case .compaction:
      .compaction(CompactionMarker(id: id, summary: nil))
    case .error:
      .error(ThreadError(id: id, kind: ClearedValue.errorKind))
    case .unknown:
      .unknown(UnknownRecord(id: id, kind: "", raw: ClearedValue.json))
    }
  }

  /// Applies the message fields to a message record.
  ///
  /// - Parameters:
  ///   - content: The patch of the blocks.
  ///   - meta: The patch of the `_meta` value.
  ///   - record: The message record of the role of the patch, or `nil`.
  /// - Returns: `false` when `record` is `nil`.
  private func applyMessage(
    content: PatchField<[ContentBlock]>, meta: PatchField<JSONValue>, to record: Message?
  ) -> Bool {
    update(record) { record in
      record.blocks = content.applied(to: record.blocks)
      record.meta = meta.applied(to: record.meta)
    }
  }

  /// Runs `change` on the record when the record exists.
  ///
  /// - Parameters:
  ///   - record: The record of the kind that the patch changes, or `nil`
  ///     when the item is of a different kind.
  ///   - change: The changes to the record.
  /// - Returns: `false` when `record` is `nil`.
  private func update<Record>(_ record: Record?, _ change: (Record) -> Void) -> Bool {
    guard let record else { return false }
    change(record)
    return true
  }
}

@MainActor
extension ThreadItem {
  /// The record of a message from the user, or `nil` for another kind.
  fileprivate var userMessage: Message? {
    guard case .userMessage(let record) = self else { return nil }
    return record
  }

  /// The record of a message from the agent, or `nil` for another kind.
  fileprivate var assistantMessage: Message? {
    guard case .assistantMessage(let record) = self else { return nil }
    return record
  }
}
