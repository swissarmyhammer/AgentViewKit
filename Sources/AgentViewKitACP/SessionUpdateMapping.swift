import AgentViewKit
import Foundation
import FoundationModelsACP
import OSLog

/// Changes ACP v2 `session/update` values into thread changes
/// (plan.md §3.3).
///
/// Each function is pure. It reads the generated ACP types and gives kit
/// values. The kit and the ACP wire package have types with the same name,
/// such as `JSONValue` and `PatchField`, so this file writes the module name
/// on each of them.
///
/// A message chunk gives a chunk patch here. ``ACPThreadSource`` sends text
/// chunks to ``AgentThread/streaming`` instead.
public enum SessionUpdateMapping {
  /// The `sessionUpdate` tag of a thought chunk. The kind of an unknown
  /// record for thought content that is not text.
  static let thoughtChunkKind = "agent_thought_chunk"

  /// The `sessionUpdate` tag of a whole thought. The kind of an unknown
  /// record for thought content that is not text.
  static let thoughtKind = "agent_thought"

  /// The text after the message id in the id of the unknown record that
  /// holds thought content that is not text.
  static let thoughtContentIDSuffix = "#content"

  /// The `sessionUpdate` tag of a state update. The kind of an unknown record
  /// for a state that the kit does not know.
  static let stateUpdateKind = "state_update"

  /// The `sessionUpdate` tag of a plan update. The kind of an unknown record
  /// for a plan content that the kit does not know.
  static let planUpdateKind = "plan_update"

  /// The ACP diff patch format that ``ToolContent/diff(patch:)`` holds.
  static let gitPatchFormat = "git_patch"

  /// The `type` of the tool content that the kit does not show as a diff.
  static let diffContentKind = "diff"

  /// The log of the mapping.
  static let logger = Logger(subsystem: "AgentViewKit", category: "SessionUpdateMapping")

  /// Changes one session update into thread changes.
  ///
  /// - Parameters:
  ///   - update: The session update from the agent.
  ///   - makeUnknownID: Gives the id of a new unknown record. The default
  ///     gives a new UUID string.
  /// - Returns: The changes to apply, in order.
  public static func changes(
    for update: SessionUpdate,
    makeUnknownID: () -> String = { UUID().uuidString }
  ) -> [ThreadChange] {
    switch update {
    case .userMessageChunk(let chunk):
      return messageChunkChanges(chunk, user: true)
    case .agentMessageChunk(let chunk):
      return messageChunkChanges(chunk, user: false)
    case .agentThoughtChunk(let chunk):
      return thoughtChunkChanges(chunk, update: update)
    case .userMessage(let message):
      return [
        .patch(
          id: message.messageId.rawValue,
          .userMessage(content: contentPatch(message.content), meta: jsonPatch(message.meta))
        )
      ]
    case .agentMessage(let message):
      return [
        .patch(
          id: message.messageId.rawValue,
          .assistantMessage(content: contentPatch(message.content), meta: jsonPatch(message.meta))
        )
      ]
    case .agentThought(let thought):
      return thoughtChanges(thought, update: update)
    case .stateUpdate(let state):
      return [stateChange(state, makeUnknownID: makeUnknownID)]
    case .toolCallContentChunk(let chunk):
      return toolCallChunkChanges(chunk)
    case .toolCallUpdate(let toolCall):
      return [toolCallChange(toolCall)]
    case .terminalUpdate(let terminal):
      return [.upsertTerminal(terminalPatch(terminal))]
    case .terminalOutputChunk(let chunk):
      return [.upsertTerminal(terminalChunkPatch(chunk))]
    case .planUpdate(let plan):
      return [planChange(plan, makeUnknownID: makeUnknownID)]
    case .availableCommandsUpdate(let commands):
      return [.setAvailableCommands(commands.availableCommands.map(slashCommand))]
    case .configOptionUpdate(let options):
      return [.setConfigOptions(options.configOptions.map(configOption))]
    case .sessionInfoUpdate(let info):
      return [.patchInfo(infoPatch(info))]
    case .usageUpdate(let usage):
      // An ACP update gives the window size, so the fields go to the
      // `ContextUsage` initializer directly.
      let cost = usage.cost.map { ContextUsage.Cost(amount: $0.amount, currency: $0.currency) }
      return [.setUsage(ContextUsage(used: usage.used, size: usage.size, cost: cost))]
    case .unknown(let kind, let raw):
      return [unknownInsert(id: makeUnknownID(), kind: kind, raw: json(raw))]
    }
  }

  // MARK: - Messages

  /// The changes of a user or agent message chunk.
  private static func messageChunkChanges(
    _ chunk: ContentChunk, user: Bool
  ) -> [ThreadChange] {
    let id = chunk.messageId.rawValue
    let block = contentBlock(chunk.content)
    var changes: [ThreadChange] = [
      .patch(id: id, user ? .userMessageChunk(block) : .assistantMessageChunk(block))
    ]
    if let meta = chunk.meta {
      let metaPatch = AgentViewKit.PatchField.value(json(meta))
      changes.append(
        .patch(
          id: id, user ? .userMessage(meta: metaPatch) : .assistantMessage(meta: metaPatch)))
    }
    return changes
  }

  /// The changes of a thought chunk.
  ///
  /// A text chunk adds one segment. Content that is not text goes to an
  /// unknown record after the reasoning, because a reasoning record holds
  /// only text.
  private static func thoughtChunkChanges(
    _ chunk: ContentChunk, update: SessionUpdate
  ) -> [ThreadChange] {
    let id = chunk.messageId.rawValue
    var changes: [ThreadChange] = []
    if case .text(let text) = chunk.content {
      changes.append(.patch(id: id, .reasoningChunk(text.text)))
    } else {
      changes.append(.patch(id: id, .reasoning()))
      changes.append(thoughtContentInsert(messageID: id, kind: thoughtChunkKind, update: update))
    }
    if let meta = chunk.meta {
      changes.append(.patch(id: id, .reasoning(meta: .value(json(meta)))))
    }
    return changes
  }

  /// The changes of a whole thought.
  ///
  /// The text blocks become the segments. When the content has a block that
  /// is not text, an unknown record after the reasoning holds the update.
  private static func thoughtChanges(
    _ thought: AgentThought, update: SessionUpdate
  ) -> [ThreadChange] {
    let id = thought.messageId.rawValue
    var changes: [ThreadChange] = [
      .patch(
        id: id,
        .reasoning(
          segments: wirePatch(thought.content) { blocks in
            blocks.compactMap { block in
              guard case .text(let text) = block else { return nil }
              return text.text
            }
          },
          meta: jsonPatch(thought.meta)
        )
      )
    ]
    if case .value(let blocks) = thought.content, blocks.contains(where: { !$0.isText }) {
      changes.append(thoughtContentInsert(messageID: id, kind: thoughtKind, update: update))
    }
    return changes
  }

  /// An unknown record after the reasoning that holds thought content that
  /// is not text.
  private static func thoughtContentInsert(
    messageID: String, kind: String, update: SessionUpdate
  ) -> ThreadChange {
    .insert(
      .unknown(
        UnknownRecord(
          id: messageID + thoughtContentIDSuffix,
          kind: kind,
          raw: AgentViewKit.JSONValue.encodedOrNull(update)
        )
      ),
      after: messageID
    )
  }

  // MARK: - Tool calls

  /// The change of a tool call update. An unseen id makes a new record.
  static func toolCallChange(_ update: ToolCallUpdate) -> ThreadChange {
    .patch(
      id: update.toolCallId.rawValue,
      .toolCall(
        title: wirePatch(update.title) { $0 },
        kind: wirePatch(update.kind) { AgentViewKit.ToolKind(wireValue: $0.wireValue) },
        status: wirePatch(update.status) { AgentViewKit.ToolCallStatus(wireValue: $0.wireValue) },
        content: wirePatch(update.content) { $0.map(toolContent) },
        locations: wirePatch(update.locations) { $0.map(toolCallLocation) },
        rawInput: jsonPatch(update.rawInput),
        rawOutput: jsonPatch(update.rawOutput),
        meta: jsonPatch(update.meta)
      )
    )
  }

  /// The changes of a tool call content chunk.
  private static func toolCallChunkChanges(_ chunk: ToolCallContentChunk) -> [ThreadChange] {
    let id = chunk.toolCallId.rawValue
    var changes: [ThreadChange] = [.patch(id: id, .toolCallChunk(toolContent(chunk.content)))]
    if let meta = chunk.meta {
      changes.append(.patch(id: id, .toolCall(meta: .value(json(meta)))))
    }
    return changes
  }

  /// Changes one ACP tool call content into kit tool content.
  ///
  /// A diff shows as ``ToolContent/diff(patch:)`` only when it has a
  /// `git_patch` text. Another diff keeps its JSON in an unknown part.
  static func toolContent(_ content: ToolCallContent) -> ToolContent {
    switch content {
    case .content(let wrapped):
      return .block(contentBlock(wrapped.content))
    case .diff(let diff):
      guard let patch = diff.patch, patch.format.wireValue == gitPatchFormat else {
        return .unknown(kind: diffContentKind, raw: AgentViewKit.JSONValue.encodedOrNull(diff))
      }
      return .diff(patch: patch.text)
    case .terminal(let terminal):
      return .terminal(id: terminal.terminalId.rawValue)
    case .unknown(let kind, let raw):
      return .unknown(kind: kind, raw: json(raw))
    }
  }

  /// Changes one ACP location into a kit location.
  private static func toolCallLocation(
    _ location: FoundationModelsACP.ToolCallLocation
  ) -> AgentViewKit.ToolCallLocation {
    AgentViewKit.ToolCallLocation(path: location.path.rawValue, line: location.line)
  }

  // MARK: - Terminals

  /// The patch of a terminal update.
  ///
  /// Output that is not valid base64 does not change the stored output.
  private static func terminalPatch(_ update: TerminalUpdate) -> TerminalPatch {
    TerminalPatch(
      id: TerminalID(update.terminalId.rawValue),
      command: wirePatch(update.command) { $0 },
      cwd: wirePatch(update.cwd) { $0.rawValue },
      exitStatus: wirePatch(update.exitStatus) {
        TerminalRecord.ExitStatus(code: $0.exitCode, signal: $0.signal)
      },
      output: outputPatch(update.output),
      meta: jsonPatch(update.meta)
    )
  }

  /// The output patch of a terminal update.
  private static func outputPatch(
    _ output: FoundationModelsACP.PatchField<TerminalOutput>
  ) -> AgentViewKit.PatchField<Data> {
    wirePatch(
      output,
      failure: "A terminal output snapshot is not valid base64. The output does not change."
    ) { Data(base64Encoded: $0.data) }
  }

  /// The patch of a terminal output chunk.
  ///
  /// A chunk that is not valid base64 adds no bytes.
  private static func terminalChunkPatch(_ chunk: TerminalOutputChunk) -> TerminalPatch {
    let bytes = Data(base64Encoded: chunk.data)
    if bytes == nil {
      logger.error("A terminal output chunk is not valid base64. The chunk adds no bytes.")
    }
    return TerminalPatch(
      id: TerminalID(chunk.terminalId.rawValue),
      outputChunk: bytes ?? Data(),
      meta: chunk.meta.map { .value(json($0)) } ?? .unchanged
    )
  }

  // MARK: - Session state

  /// The change of a state update. An idle state keeps its stop reason.
  private static func stateChange(
    _ state: StateUpdate, makeUnknownID: () -> String
  ) -> ThreadChange {
    switch state {
    case .running:
      return .setState(.running)
    case .idle(let idle):
      return .setState(
        .idle(idle.stopReason.map { AgentViewKit.StopReason(wireValue: $0.wireValue) }))
    case .requiresAction:
      return .setState(.requiresAction)
    case .unknown(let kind, let raw):
      return unknownInsert(
        id: makeUnknownID(), kind: "\(stateUpdateKind)/\(kind)", raw: json(raw))
    }
  }

  /// The change of a plan update. The plan replaces the plan with its id.
  private static func planChange(
    _ update: PlanUpdate, makeUnknownID: () -> String
  ) -> ThreadChange {
    switch update.plan {
    case .items(let items):
      return .setPlan(
        Plan(
          id: PlanID(items.planId.rawValue),
          entries: items.entries.map { entry in
            AgentViewKit.PlanEntry(
              content: entry.content,
              priority: AgentViewKit.PlanEntry.Priority(wireValue: entry.priority.wireValue),
              status: AgentViewKit.PlanEntry.Status(wireValue: entry.status.wireValue)
            )
          }
        )
      )
    case .unknown(let kind, let raw):
      return unknownInsert(
        id: makeUnknownID(), kind: "\(planUpdateKind)/\(kind)", raw: json(raw))
    }
  }

  /// Changes one ACP command into a kit slash command.
  private static func slashCommand(_ command: AvailableCommand) -> SlashCommand {
    var hint: String?
    if case .text(let input) = command.input {
      hint = input.hint
    }
    return SlashCommand(name: command.name, description: command.description, inputHint: hint)
  }

  /// Changes one ACP config option into a kit config option.
  ///
  /// The option goes through its JSON form, because the ACP select options
  /// are a raw JSON value in the flat or the grouped shape. The kit decoder
  /// reads both shapes. An option that the kit cannot decode keeps its JSON
  /// in an unknown kind.
  static func configOption(_ option: SessionConfigOption) -> ConfigOption {
    do {
      let data = try JSONEncoder().encode(option)
      return try JSONDecoder().decode(ConfigOption.self, from: data)
    } catch {
      logger.error(
        "The config option \(option.configId.rawValue, privacy: .public) does not decode: \(error, privacy: .public)"
      )
      return ConfigOption(
        id: ConfigOptionID(option.configId.rawValue),
        name: option.name,
        description: option.description,
        category: option.category.map { ConfigOption.Category(wireValue: $0.wireValue) },
        kind: .unknown(type: option.type.wireTag, raw: AgentViewKit.JSONValue.encodedOrNull(option))
      )
    }
  }

  /// The patch of a session info update.
  ///
  /// A time that is not ISO 8601 does not change the stored time.
  private static func infoPatch(_ info: SessionInfoUpdate) -> ThreadInfoPatch {
    ThreadInfoPatch(
      title: wirePatch(info.title) { $0 },
      updatedAt: datePatch(info.updatedAt)
    )
  }

  /// The patch of an ISO 8601 time.
  private static func datePatch(
    _ field: FoundationModelsACP.PatchField<String>
  ) -> AgentViewKit.PatchField<Date> {
    wirePatch(field, failure: "A session time is not ISO 8601. The time does not change.") {
      ISO8601Time.date(from: $0)
    }
  }

  // MARK: - Content blocks

  /// Changes one ACP content block into a kit content block.
  ///
  /// Image and audio data that is not valid base64, and a resource with no
  /// `text` or `blob`, give an unknown block that keeps the JSON.
  public static func contentBlock(_ block: FoundationModelsACP.ContentBlock)
    -> AgentViewKit.ContentBlock
  {
    switch block {
    case .text(let text):
      return AgentViewKit.ContentBlock(
        content: .text(text.text), annotations: annotations(text.annotations))
    case .image(let image):
      guard let data = Data(base64Encoded: image.data) else {
        return unknownBlock(block)
      }
      return AgentViewKit.ContentBlock(
        content: .image(
          AgentViewKit.ImageContent(data: data, mimeType: image.mimeType.rawValue, uri: image.uri)),
        annotations: annotations(image.annotations)
      )
    case .audio(let audio):
      guard let data = Data(base64Encoded: audio.data) else {
        return unknownBlock(block)
      }
      return AgentViewKit.ContentBlock(
        content: .audio(AgentViewKit.AudioContent(data: data, mimeType: audio.mimeType.rawValue)),
        annotations: annotations(audio.annotations)
      )
    case .resourceLink(let link):
      return AgentViewKit.ContentBlock(
        content: .resourceLink(
          AgentViewKit.ResourceLink(
            name: link.name,
            uri: link.uri,
            icons: (link.icons ?? []).map { icon in
              ResourceIcon(src: icon.src, mimeType: icon.mimeType?.rawValue, sizes: icon.sizes ?? [])
            },
            mimeType: link.mimeType?.rawValue
          )
        ),
        annotations: annotations(link.annotations)
      )
    case .resource(let resource):
      guard let embedded = embeddedResource(resource.resource) else {
        return unknownBlock(block)
      }
      return AgentViewKit.ContentBlock(
        content: .resource(embedded), annotations: annotations(resource.annotations))
    case .unknown(let kind, let raw):
      return AgentViewKit.ContentBlock(content: .unknown(kind: kind, raw: json(raw)))
    }
  }

  /// The keys of an ACP embedded resource.
  private enum ResourceKey {
    static let uri = "uri"
    static let mimeType = "mimeType"
    static let text = "text"
    static let blob = "blob"
  }

  /// Reads an ACP embedded resource, which is a raw JSON value.
  ///
  /// - Returns: The resource, or `nil` when it has no `uri`, or no `text`
  ///   and no valid base64 `blob`.
  private static func embeddedResource(
    _ resource: EmbeddedResourceResource
  ) -> AgentViewKit.EmbeddedResource? {
    guard case .object(let members) = resource,
      case .string(let uri) = members[ResourceKey.uri]
    else { return nil }
    var mimeType: String?
    if case .string(let value) = members[ResourceKey.mimeType] {
      mimeType = value
    }
    if case .string(let text) = members[ResourceKey.text] {
      return AgentViewKit.EmbeddedResource(uri: uri, mimeType: mimeType, contents: .text(text))
    }
    if case .string(let blob) = members[ResourceKey.blob], let data = Data(base64Encoded: blob) {
      return AgentViewKit.EmbeddedResource(uri: uri, mimeType: mimeType, contents: .blob(data))
    }
    return nil
  }

  /// An unknown block that keeps the JSON of an ACP block.
  private static func unknownBlock(
    _ block: FoundationModelsACP.ContentBlock
  ) -> AgentViewKit.ContentBlock {
    AgentViewKit.ContentBlock(
      content: .unknown(kind: block.wireTag, raw: AgentViewKit.JSONValue.encodedOrNull(block)))
  }

  /// Changes ACP annotations into kit annotations.
  private static func annotations(
    _ annotations: FoundationModelsACP.Annotations?
  ) -> AgentViewKit.Annotations? {
    annotations.map { value in
      AgentViewKit.Annotations(
        audience: value.audience?.map { Audience(wireValue: $0.wireValue) },
        priority: value.priority
      )
    }
  }

  /// The patch of the blocks of a message.
  private static func contentPatch(
    _ field: FoundationModelsACP.PatchField<[FoundationModelsACP.ContentBlock]>
  ) -> AgentViewKit.PatchField<[AgentViewKit.ContentBlock]> {
    wirePatch(field) { $0.map(contentBlock) }
  }

  // MARK: - Requests

  /// Changes a pending ACP permission request into a kit request.
  ///
  /// The kit id is the string of the local id of the request.
  public static func permissionRequest(_ pending: PendingPermissionRequestValue)
    -> PermissionRequest
  {
    let request = pending.request
    return PermissionRequest(
      id: PermissionRequestID(pending.id.uuidString),
      title: request.title,
      description: request.description,
      subject: request.subject.flatMap(permissionSubject),
      options: request.options.map { option in
        AgentViewKit.PermissionOption(
          id: PermissionOptionID(option.optionId.rawValue),
          name: option.name,
          kind: AgentViewKit.PermissionOption.Kind(wireValue: option.kind.wireValue)
        )
      },
      meta: request.meta.map(json)
    )
  }

  /// Changes an ACP permission subject into a kit subject.
  ///
  /// - Returns: The subject, or `nil` for a subject that the kit does not
  ///   know.
  private static func permissionSubject(
    _ subject: RequestPermissionSubject
  ) -> PermissionRequest.Subject? {
    switch subject {
    case .toolCall(let toolCall):
      return .toolCall(id: toolCall.toolCall.toolCallId.rawValue)
    case .command(let command):
      return .command(
        command: command.command,
        cwd: command.cwd.rawValue,
        toolCallId: command.toolCallId?.rawValue,
        terminalId: command.terminalId.map { TerminalID($0.rawValue) }
      )
    case .unknown(let kind, _):
      logger.error("The permission subject \(kind, privacy: .public) is not known.")
      return nil
    }
  }

  /// Changes a pending ACP elicitation into a kit request.
  ///
  /// The kit id is the string of the local id of the elicitation.
  ///
  /// - Parameters:
  ///   - pending: The local id and the request of the elicitation.
  ///   - server: The display name of the agent that asks.
  /// - Returns: The request, or `nil` for a mode that the kit does not know
  ///   or a URL that is not valid.
  public static func elicitationRequest(
    _ pending: PendingElicitationValue, server: String
  ) -> ElicitationRequest? {
    let request = pending.request
    let mode: ElicitationRequest.Mode
    switch request.mode {
    case .form(let form):
      mode = .form(requestedSchema: AgentViewKit.JSONValue.encodedOrNull(form.requestedSchema))
    case .url(let urlMode):
      guard let url = URL(string: urlMode.url) else {
        logger.error("The elicitation URL \(urlMode.url, privacy: .public) is not valid.")
        return nil
      }
      mode = .url(url, elicitationId: urlMode.elicitationId.rawValue)
    case .unknown(let kind, _):
      logger.error("The elicitation mode \(kind, privacy: .public) is not known.")
      return nil
    }
    return ElicitationRequest(
      id: ElicitationRequestID(pending.id.uuidString),
      server: server,
      message: request.message,
      mode: mode,
      meta: request.meta.map(json)
    )
  }

  // MARK: - JSON and patch fields

  /// Changes an ACP JSON value into a kit JSON value.
  public static func json(_ value: FoundationModelsACP.JSONValue) -> AgentViewKit.JSONValue {
    switch value {
    case .null: .null
    case .bool(let bool): .bool(bool)
    case .number(let number): .number(number)
    case .string(let string): .string(string)
    case .array(let elements): .array(elements.map(json))
    case .object(let members): .object(members.mapValues(json))
    }
  }

  /// Changes a kit JSON value into an ACP JSON value.
  public static func wireJSON(_ value: AgentViewKit.JSONValue) -> FoundationModelsACP.JSONValue {
    switch value {
    case .null: .null
    case .bool(let bool): .bool(bool)
    case .number(let number): .number(number)
    case .string(let string): .string(string)
    case .array(let elements): .array(elements.map(wireJSON))
    case .object(let members): .object(members.mapValues(wireJSON))
    }
  }

  /// Changes an ACP patch field into a kit patch field of the same state.
  static func wirePatch<Wire, Kit>(
    _ field: FoundationModelsACP.PatchField<Wire>, _ transform: (Wire) -> Kit
  ) -> AgentViewKit.PatchField<Kit> {
    switch field {
    case .unchanged: .unchanged
    case .cleared: .cleared
    case .value(let value): .value(transform(value))
    }
  }

  /// Changes an ACP patch field into a kit patch field with a transform
  /// that can fail.
  ///
  /// When the transform of a value fails, the mapping logs `failure` and the
  /// patch does not change the stored value.
  ///
  /// - Parameters:
  ///   - field: The ACP patch field.
  ///   - failure: The log message for a value that the transform cannot read.
  ///   - transform: Gives the kit value, or `nil` when it cannot read the
  ///     wire value.
  /// - Returns: The kit patch field.
  private static func wirePatch<Wire, Kit>(
    _ field: FoundationModelsACP.PatchField<Wire>,
    failure: StaticString,
    _ transform: (Wire) -> Kit?
  ) -> AgentViewKit.PatchField<Kit> {
    switch field {
    case .unchanged: return .unchanged
    case .cleared: return .cleared
    case .value(let value):
      guard let converted = transform(value) else {
        logger.error("\(failure.description, privacy: .public)")
        return .unchanged
      }
      return .value(converted)
    }
  }

  /// Changes an ACP JSON patch field into a kit JSON patch field.
  private static func jsonPatch(
    _ field: FoundationModelsACP.PatchField<FoundationModelsACP.JSONValue>
  ) -> AgentViewKit.PatchField<AgentViewKit.JSONValue> {
    wirePatch(field, json)
  }

  /// A change that puts an unknown record at the end of the thread.
  private static func unknownInsert(
    id: String, kind: String, raw: AgentViewKit.JSONValue
  ) -> ThreadChange {
    .insert(.unknown(UnknownRecord(id: id, kind: kind, raw: raw)), after: nil)
  }
}

/// The local id and the request of a pending permission request.
///
/// ``SessionUpdateMapping/permissionRequest(_:)`` reads this value. The ACP
/// client type conforms to it, and a test can give its own value.
public nonisolated protocol PendingPermissionRequestValue {
  /// The local id of the request.
  var id: UUID { get }

  /// The request as the agent sent it.
  var request: RequestPermissionRequest { get }
}

/// The local id and the request of a pending elicitation.
///
/// ``SessionUpdateMapping/elicitationRequest(_:server:)`` reads this value.
/// The ACP client type conforms to it, and a test can give its own value.
public nonisolated protocol PendingElicitationValue {
  /// The local id of the elicitation.
  var id: UUID { get }

  /// The request as the agent sent it.
  var request: CreateElicitationRequest { get }
}

nonisolated extension FoundationModelsACP.ContentBlock {
  /// `true` for a text block.
  fileprivate var isText: Bool {
    if case .text = self { true } else { false }
  }

  /// The wire `type` tag of the block.
  fileprivate var wireTag: String {
    switch self {
    case .text: "text"
    case .image: "image"
    case .audio: "audio"
    case .resourceLink: "resource_link"
    case .resource: "resource"
    case .unknown(let kind, _): kind
    }
  }
}

nonisolated extension SessionConfigOption.Payload {
  /// The wire `type` tag of the payload.
  fileprivate var wireTag: String {
    switch self {
    case .select: "select"
    case .boolean: "boolean"
    case .unknown(let kind, _): kind
    }
  }
}
