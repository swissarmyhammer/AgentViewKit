import AgentViewKit
import Foundation
import FoundationModelsExtras
import FoundationModelsRouter
import OSLog

/// Changes FoundationModelsRouter session events into thread changes
/// (plan.md §3.3).
///
/// Each function is pure. It reads the Router types and gives kit values. The
/// kit and the Router have types with the same name, such as `JSONValue`,
/// `ElicitationRequest`, and `ToolCallStatus`, so this file writes the module
/// name on each of them.
///
/// A text or reasoning fragment gives a change to ``AgentThread/streaming``.
/// ``RouterThreadSource`` selects the id of the row that each fragment goes
/// to, opens and closes the streams, and gives the durable id to a row when
/// `entryRecorded` arrives. So `entryRecorded` gives no change here.
public enum SessionEventMapping {
  /// The id of the open text row when the caller gives no id.
  public static let defaultTextID = "provisional-text"

  /// The id of the open reasoning row when the caller gives no id.
  public static let defaultReasoningID = "provisional-reasoning"

  /// The kind of the unknown record for a tool invocation record.
  static let toolInvocationKind = "toolInvocation"

  /// The kind of the unknown record for a settled background run.
  static let runSettledKind = "runSettled"

  /// The kind of the unknown record for a discovery priming failure.
  static let discoveryPrimingFailedKind = "discoveryPrimingFailed"

  /// The kind of the unknown record for a generation stall.
  static let generationStalledKind = "generationStalled"

  /// The kind of the unknown record for an elicitation event that has no
  /// request.
  static let elicitationRequestedKind = "elicitationRequested"

  /// The kind of an unknown content block for a Router segment that the kit
  /// does not know.
  static let unknownSegmentKind = "segment"

  /// The kind of an unknown content block for a legacy Router custom segment.
  static let customSegmentKind = "custom"

  /// The kind of an unknown content block for an attachment with no valid URL.
  static let attachmentSegmentKind = "attachment"

  /// The prefix of the id of the unknown record for a tool invocation.
  static let toolInvocationIDPrefix = "tool-invocation-"

  /// The prefix of the id of the unknown record for a settled run.
  static let runSettledIDPrefix = "run-settled-"

  /// The prefix of the id of the unknown record for an elicitation event that
  /// has no request.
  static let elicitationIDPrefix = "elicitation-"

  /// The text between the correlation id and the index in the id of a
  /// structured record from a tool call report.
  static let attachmentIDInfix = "#attachment-"

  /// The log of the mapping.
  static let logger = Logger(subsystem: "AgentViewKit", category: "SessionEventMapping")

  // MARK: - Events

  /// Changes one session event into thread changes.
  ///
  /// - Parameters:
  ///   - event: The session event from the Router.
  ///   - textID: The id of the row that a text fragment goes to.
  ///   - reasoningID: The id of the row that a reasoning fragment goes to.
  ///   - makeUnknownID: Gives the id of a new unknown record. The default
  ///     gives a new UUID string.
  /// - Returns: The changes to apply, in order.
  public static func changes(
    for event: SessionEvent,
    textID: String = defaultTextID,
    reasoningID: String = defaultReasoningID,
    makeUnknownID: () -> String = { UUID().uuidString }
  ) -> [ThreadChange] {
    switch event {
    case .turnStarted:
      return [.setState(.running)]
    case .textDelta(let fragment):
      return [.appendStreaming(id: textID, text: fragment)]
    case .textReset:
      return [.closeStreaming(id: textID)]
    case .reasoningDelta(let fragment):
      return [.appendStreaming(id: reasoningID, text: fragment)]
    case .toolCall(let id, let name, let argumentsJSON):
      return [
        .patch(
          id: id,
          .toolCall(
            title: .value(name),
            status: .value(.inProgress),
            rawInput: .value(json(parsing: argumentsJSON))
          )
        )
      ]
    case .toolStatus(let id, let status, let summary, let output):
      return [toolStatusChange(id: id, status: status, summary: summary, output: output)]
    case .toolCallReport(let report):
      return reportChanges(report)
    case .entryRecorded:
      return []
    case .compaction(let result):
      return [compactionChange(result)]
    case .elicitationRequested(let operation):
      return [elicitationChange(operation)]
    case .turnEnded(let usage):
      // The Router gives the fill of the working context, not its size.
      return [
        .setUsage(ContextUsage(used: usage.tokensIn + usage.tokensOut, fill: usage.contextFill)),
        .setState(.idle(stopReason(usage.finishReason))),
      ]
    case .toolInvocation(let record):
      return [
        unknownChange(
          id: toolInvocationIDPrefix + record.correlationID,
          kind: toolInvocationKind,
          raw: AgentViewKit.JSONValue.encodedOrNull(record)
        )
      ]
    case .runSettled(let operation):
      return [
        unknownChange(
          id: runSettledIDPrefix + operation.correlationID,
          kind: runSettledKind,
          raw: AgentViewKit.JSONValue.encodedOrNull(operation)
        )
      ]
    case .discoveryPrimingFailed(let failure):
      return [
        unknownChange(
          id: makeUnknownID(),
          kind: discoveryPrimingFailedKind,
          raw: .string(String(describing: failure))
        )
      ]
    case .generationStalled(let stall):
      return [
        unknownChange(id: makeUnknownID(), kind: generationStalledKind, raw: .string(stall.description))
      ]
    }
  }

  // MARK: - Seed rows

  /// Changes one row of `SessionProjection.transcript` into thread changes.
  ///
  /// The row keeps its id. A text row becomes an assistant message, a
  /// reasoning row becomes a reasoning record, a tool call row becomes a tool
  /// call record, and a compaction row becomes a compaction marker.
  ///
  /// - Parameter row: The row of the projection.
  /// - Returns: The changes to apply, in order.
  public static func changes(for row: SessionProjection.TranscriptEntry) -> [ThreadChange] {
    switch row.kind {
    case .text(let text):
      return [.patch(id: row.id, .assistantMessage(content: .value([ContentBlock(text: text)])))]
    case .reasoning(let text):
      return [.patch(id: row.id, .reasoning(segments: .value([text])))]
    case .toolCall(let call):
      return [
        .patch(
          id: row.id,
          .toolCall(
            title: .value(call.name),
            status: .value(toolCallStatus(call.status)),
            content: call.output.map { .value(toolContent($0)) } ?? .unchanged,
            rawInput: .value(json(parsing: call.argumentsJSON)),
            rawOutput: call.summary.map { .value(.string($0)) } ?? .unchanged
          )
        )
      ]
    case .compaction(let result):
      return [compactionChange(result)]
    }
  }

  // MARK: - Tool calls

  /// The patch of a tool call for a status event.
  ///
  /// - Parameters:
  ///   - id: The id of the tool call.
  ///   - status: The Router status.
  ///   - summary: The flat output text, or `nil`.
  ///   - output: The output segments, or `nil`.
  /// - Returns: The patch change.
  static func toolStatusChange(
    id: String,
    status: FoundationModelsRouter.ToolCallStatus,
    summary: String?,
    output: [SegmentPayload]?
  ) -> ThreadChange {
    .patch(
      id: id,
      .toolCall(
        status: .value(toolCallStatus(status)),
        content: output.map { .value(toolContent($0)) } ?? .unchanged,
        rawOutput: summary.map { .value(.string($0)) } ?? .unchanged
      )
    )
  }

  /// Changes a Router tool call status into the kit status.
  ///
  /// - Parameter status: The Router status.
  /// - Returns: `inProgress` for `running`, and the same name for the others.
  static func toolCallStatus(_ status: FoundationModelsRouter.ToolCallStatus) -> AgentViewKit.ToolCallStatus {
    switch status {
    case .running: .inProgress
    case .completed: .completed
    case .failed: .failed
    }
  }

  /// Changes the output segments of a tool call into tool content.
  ///
  /// - Parameter segments: The output segments.
  /// - Returns: One content block for each segment, in order.
  static func toolContent(_ segments: [SegmentPayload]) -> [ToolContent] {
    segments.map { .block(contentBlock($0)) }
  }

  /// Changes a Router segment into a content block.
  ///
  /// - Parameter segment: The segment.
  /// - Returns: A text, structured, or attachment block. A segment that the
  ///   kit does not know gives an unknown block.
  static func contentBlock(_ segment: SegmentPayload) -> ContentBlock {
    switch segment {
    case .text(_, let content):
      return ContentBlock(text: content)
    case .structure(_, let schemaName, let contentJSON):
      return ContentBlock(content: .structured(schemaName: schemaName, payload: json(parsing: contentJSON)))
    case .attachment(let id, let label, let url):
      if let url, let location = URL(string: url) {
        return ContentBlock(content: .attachment(location))
      }
      return unknownBlock(kind: attachmentSegmentKind, segment: segment, id: id, label: label)
    case .custom(_, let typeDiscriminator, let contentJSON, _):
      return ContentBlock(
        content: .unknown(
          kind: customSegmentKind,
          raw: .object([
            "typeDiscriminator": .string(typeDiscriminator), "content": json(parsing: contentJSON),
          ])
        )
      )
    case .unknown(let id, let description):
      return unknownBlock(kind: unknownSegmentKind, segment: segment, id: id, label: description)
    }
  }

  /// An unknown content block that holds the segment as JSON.
  ///
  /// - Parameters:
  ///   - kind: The kind of the block.
  ///   - segment: The segment.
  ///   - id: The id of the segment.
  ///   - label: The label or the description of the segment, or `nil`.
  /// - Returns: The unknown block.
  private static func unknownBlock(kind: String, segment: SegmentPayload, id: String, label: String?)
    -> ContentBlock
  {
    let raw = AgentViewKit.JSONValue.encodedOrNull(segment)
    logger.debug("The Router segment \(id, privacy: .public) of kind \(kind, privacy: .public) is not known.")
    return ContentBlock(content: .unknown(kind: kind, raw: raw == .null ? .string(label ?? id) : raw))
  }

  /// The structured records of the attachments of a tool call report.
  ///
  /// - Parameter report: The report.
  /// - Returns: One patch for each attachment, in order.
  static func reportChanges(_ report: ToolCallReport) -> [ThreadChange] {
    let meta = AgentViewKit.JSONValue.object([
      "tool": .string(report.tool),
      "op": .string(report.op),
      "correlationID": .string(report.correlationID),
    ])
    return report.attachments.enumerated().map { index, attachment in
      .patch(
        id: report.correlationID + attachmentIDInfix + String(index),
        .structured(
          schemaName: .value(attachment.schemaName),
          payload: .value(json(parsing: attachment.contentJSON)),
          meta: .value(meta)
        )
      )
    }
  }

  // MARK: - Compaction

  /// The patch of a compaction marker.
  ///
  /// The token counts and the stages go to the `meta` value of the marker.
  ///
  /// - Parameter result: The result of the compaction.
  /// - Returns: The patch change, with the id of the result.
  static func compactionChange(_ result: CompactionResult) -> ThreadChange {
    let meta = AgentViewKit.JSONValue.object([
      "tokensBefore": .number(Double(result.tokensBefore)),
      "tokensAfter": .number(Double(result.tokensAfter)),
      "stagesApplied": .array(result.stagesApplied.map { .string($0) }),
      "summaryCut": .bool(result.summaryCut),
    ])
    return .patch(
      id: result.id,
      .compaction(summary: result.summary.map { .value($0) } ?? .unchanged, meta: .value(meta))
    )
  }

  // MARK: - Elicitation

  /// The change for an elicitation event.
  ///
  /// - Parameter operation: The `.elicitation` operation event.
  /// - Returns: An added elicitation, or an unknown record when the event has
  ///   no request.
  static func elicitationChange(_ operation: OperationEvent) -> ThreadChange {
    guard let request = elicitationRequest(operation) else {
      return unknownChange(
        id: elicitationIDPrefix + operation.correlationID,
        kind: elicitationRequestedKind,
        raw: AgentViewKit.JSONValue.encodedOrNull(operation)
      )
    }
    return .addElicitation(request)
  }

  /// Changes the request of an operation event into a kit request.
  ///
  /// The id of the kit request is the string form of the Router
  /// `elicitationId`. The server is the tool of the event. The `meta` value
  /// holds the tool, the operation, and the correlation id.
  ///
  /// - Parameter operation: The operation event.
  /// - Returns: The kit request, or `nil` when the event has no request, or a
  ///   URL request has no URL.
  static func elicitationRequest(_ operation: OperationEvent) -> AgentViewKit.ElicitationRequest? {
    guard let request = operation.elicitation else { return nil }
    let elicitationId = request.elicitationId.ulidString
    let mode: AgentViewKit.ElicitationRequest.Mode
    switch request.mode {
    case .form:
      mode = .form(
        requestedSchema: request.requestedSchema.map { AgentViewKit.JSONValue.encodedOrNull($0) }
          ?? .object([:]))
    case .url:
      guard let url = request.url else { return nil }
      mode = .url(url, elicitationId: elicitationId)
    }
    return AgentViewKit.ElicitationRequest(
      id: ElicitationRequestID(elicitationId),
      server: operation.tool,
      message: request.message,
      mode: mode,
      meta: .object([
        "tool": .string(operation.tool),
        "op": .string(operation.op),
        "correlationID": .string(operation.correlationID),
      ])
    )
  }

  /// Changes the answer of the user into a Router response.
  ///
  /// An accept with an object gives the members that are a string, a
  /// number, a Boolean, or an array of strings. The other members are not
  /// sent, and the log records each one.
  ///
  /// - Parameter result: The answer of the user.
  /// - Returns: The Router response.
  public static func response(for result: ElicitationResult) -> ElicitationResponse {
    switch result {
    case .accept(let content):
      guard case .object(let members)? = content else { return .accept(content: nil) }
      var values: [String: ElicitationValue] = [:]
      for (name, value) in members {
        guard let converted = elicitationValue(value) else {
          logger.debug("The elicitation value \(name, privacy: .public) has no Router form. It is not sent.")
          continue
        }
        values[name] = converted
      }
      return .accept(content: values)
    case .decline:
      return .decline
    case .cancel:
      return .cancel
    }
  }

  /// Changes one kit value into a Router elicitation value.
  ///
  /// - Parameter value: The kit value.
  /// - Returns: The Router value, or `nil` for null, an object, or an array
  ///   that holds a value that is not a string.
  static func elicitationValue(_ value: AgentViewKit.JSONValue) -> ElicitationValue? {
    switch value {
    case .string(let text): return .string(text)
    case .number(let number): return .number(number)
    case .bool(let flag): return .boolean(flag)
    case .array(let elements):
      let strings = elements.compactMap { element -> String? in
        guard case .string(let text) = element else { return nil }
        return text
      }
      return strings.count == elements.count ? .stringArray(strings) : nil
    case .null, .object: return nil
    }
  }

  // MARK: - Stop reason

  /// Changes a Router finish reason into a stop reason.
  ///
  /// - Parameter reason: The finish reason.
  /// - Returns: `endTurn` for `completed`, and `maxTokens` for `maxTokens`.
  static func stopReason(_ reason: FinishReason) -> StopReason {
    switch reason {
    case .completed: .endTurn
    case .maxTokens: .maxTokens
    }
  }

  // MARK: - JSON

  /// The patch that makes or changes an unknown record.
  ///
  /// - Parameters:
  ///   - id: The id of the record.
  ///   - kind: The kind of the event.
  ///   - raw: The event as JSON.
  /// - Returns: The patch change.
  static func unknownChange(id: String, kind: String, raw: AgentViewKit.JSONValue) -> ThreadChange {
    .patch(id: id, .unknown(kind: .value(kind), raw: .value(raw)))
  }

  /// Parses JSON text into a kit value.
  ///
  /// - Parameter text: The JSON text.
  /// - Returns: The value, or the text as a string when it is not valid JSON.
  static func json(parsing text: String) -> AgentViewKit.JSONValue {
    (try? AgentViewKit.JSONValue(json: text)) ?? .string(text)
  }
}
