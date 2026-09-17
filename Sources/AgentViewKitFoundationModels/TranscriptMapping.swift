import AgentViewKit
import CoreGraphics
import Foundation
import FoundationModels
import ImageIO
import OSLog
import UniformTypeIdentifiers

/// Changes a FoundationModels transcript into thread items (plan.md §3.3).
///
/// Each function is pure. It reads the SDK values and gives kit values. The
/// id of each record is the id of the transcript entry, so a live source that
/// reads the same session later keeps the same identities.
///
/// The mapping:
///
/// - `.instructions` gives ``ThreadItem/system(_:)``.
/// - `.prompt` gives ``ThreadItem/userMessage(_:)``.
/// - `.response` gives ``ThreadItem/assistantMessage(_:)``.
/// - `.reasoning` gives ``ThreadItem/reasoning(_:)``.
/// - Each call of `.toolCalls` gives one ``ThreadItem/toolCall(_:)``, with the
///   output of the `.toolOutput` entry that has the id of the call. A call
///   with an output is ``ToolCallStatus/completed``. A call with no output is
///   ``ToolCallStatus/inProgress``.
/// - An entry that the SDK adds later gives ``ThreadItem/unknown(_:)``.
///
/// In a message, a `.text` segment gives a text block, and an `.attachment`
/// segment gives an image block. A `.structure` segment with a name of the
/// catalog gives a structured block. A `.structure` segment that the catalog
/// does not claim gives a ``ThreadItem/structured(_:)`` item after the
/// message (plan.md §3.2).
public enum TranscriptMapping {
  /// The kind of an unknown record for a transcript entry that the kit does
  /// not know.
  static let unknownEntryKind = "entry"

  /// The kind of an unknown content block for a segment that the kit does not
  /// know.
  static let unknownSegmentKind = "segment"

  /// The kind of an unknown content block for an attachment that the kit
  /// does not know, or for an image that does not encode.
  static let unknownAttachmentKind = "attachment"

  /// The MIME type of each image block that the mapping makes.
  static let imageMIMEType = "image/png"

  /// The number of images in each encoded image file.
  static let imagesPerFile = 1

  /// The text between two segments in the text of a system prompt.
  static let instructionsSeparator = "\n\n"

  /// The log of the mapping.
  static let logger = Logger(subsystem: "AgentViewKit", category: "TranscriptMapping")

  // MARK: - Items

  /// Changes a transcript into thread items.
  ///
  /// - Parameters:
  ///   - transcript: The transcript to read.
  ///   - catalog: The catalog that decodes the structured segments.
  /// - Returns: The items, in the order of the transcript.
  public static func items(
    for transcript: Transcript,
    catalog: StructuredCatalog = .standard
  ) -> [ThreadItem] {
    let outputList = transcript.compactMap { entry -> Transcript.ToolOutput? in
      guard case .toolOutput(let output) = entry else { return nil }
      return output
    }
    let outputs = Dictionary(outputList.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
    let callIDs = Set(
      transcript.flatMap { entry -> [String] in
        guard case .toolCalls(let calls) = entry else { return [] }
        return calls.map(\.id)
      })
    return transcript.flatMap { entry in
      items(for: entry, outputs: outputs, callIDs: callIDs, catalog: catalog)
    }
  }

  /// Changes one transcript entry into thread items.
  ///
  /// - Parameters:
  ///   - entry: The entry.
  ///   - outputs: The tool outputs of the transcript, keyed by id.
  ///   - callIDs: The ids of the tool calls of the transcript.
  ///   - catalog: The catalog that decodes the structured segments.
  /// - Returns: The items of the entry, in order. A tool output that has a
  ///   call gives no item, because the item of the call shows the output.
  static func items(
    for entry: Transcript.Entry,
    outputs: [String: Transcript.ToolOutput],
    callIDs: Set<String>,
    catalog: StructuredCatalog
  ) -> [ThreadItem] {
    switch entry {
    case .instructions(let instructions):
      return [.system(SystemPrompt(id: instructions.id, text: text(of: instructions.segments)))]
    case .prompt(let prompt):
      return messageItems(
        id: prompt.id, segments: prompt.segments, meta: meta(prompt.metadata), catalog: catalog,
        makeItem: ThreadItem.userMessage)
    case .response(let response):
      return messageItems(
        id: response.id, segments: response.segments, meta: meta(response.metadata), catalog: catalog,
        makeItem: ThreadItem.assistantMessage)
    case .reasoning(let reasoning):
      return [.reasoning(record(for: reasoning))]
    case .toolCalls(let calls):
      return calls.map { call in
        .toolCall(record(for: call, output: outputs[call.id]))
      }
    case .toolOutput(let output):
      guard !callIDs.contains(output.id) else { return [] }
      return [.toolCall(record(for: output))]
    @unknown default:
      logger.debug("The transcript entry \(entry.id, privacy: .public) is not known.")
      return [
        .unknown(
          UnknownRecord(id: entry.id, kind: unknownEntryKind, raw: .string(entry.description)))
      ]
    }
  }

  // MARK: - Messages

  /// The items of a prompt or a response.
  ///
  /// - Parameters:
  ///   - id: The id of the entry.
  ///   - segments: The segments of the entry.
  ///   - meta: The `meta` value of the message.
  ///   - catalog: The catalog that decodes the structured segments.
  ///   - makeItem: Makes the item of the message.
  /// - Returns: The message, then one structured item for each structured
  ///   segment that the catalog does not claim.
  static func messageItems(
    id: String,
    segments: [Transcript.Segment],
    meta: AgentViewKit.JSONValue?,
    catalog: StructuredCatalog,
    makeItem: (Message) -> ThreadItem
  ) -> [ThreadItem] {
    let contents = segments.map { segment in
      guard case .structure(let structured) = segment else {
        return StructuredContent.block(contentBlock(for: segment))
      }
      return structuredContent(for: structured, catalog: catalog)
    }
    let message = makeItem(Message(id: id, blocks: contents.compactMap(\.block), meta: meta))
    return [message] + contents.compactMap(\.record).map(ThreadItem.structured)
  }

  /// The result of the mapping of one segment of a message.
  public enum StructuredContent {
    /// A block that stays in the message.
    case block(ContentBlock)

    /// A record for a structured segment that the catalog does not claim.
    case record(StructuredRecord)

    /// The block of the result, or `nil` for a record.
    var block: ContentBlock? {
      guard case .block(let block) = self else { return nil }
      return block
    }

    /// The record of the result, or `nil` for a block.
    var record: StructuredRecord? {
      guard case .record(let record) = self else { return nil }
      return record
    }
  }

  /// Changes a structured segment into a block or a record.
  ///
  /// - Parameters:
  ///   - segment: The segment.
  ///   - catalog: The catalog that decodes the segment.
  /// - Returns: A structured block when the catalog decodes the segment.
  ///   Otherwise a record with the id of the segment. A segment with a
  ///   catalog name and a body that does not decode gives a record too.
  public static func structuredContent(
    for segment: Transcript.StructuredSegment,
    catalog: StructuredCatalog = .standard
  ) -> StructuredContent {
    let body = json(from: segment.content)
    do {
      if let payload = try catalog.decode(schemaName: segment.schemaName, content: body) {
        return .block(
          ContentBlock(content: .structured(schemaName: segment.schemaName, payload: try payload.jsonValue())))
      }
    } catch {
      logger.debug(
        "The structured segment \(segment.id, privacy: .public) does not decode: \(error, privacy: .public)")
    }
    return .record(StructuredRecord(id: segment.id, schemaName: segment.schemaName, payload: body))
  }

  /// Changes a segment into a content block.
  ///
  /// A structured segment gives a structured block with its JSON body, also
  /// when the catalog does not know its name.
  ///
  /// - Parameter segment: The segment.
  /// - Returns: A text, image, structured, or unknown block.
  static func contentBlock(for segment: Transcript.Segment) -> ContentBlock {
    switch segment {
    case .text(let text):
      return ContentBlock(text: text.content)
    case .structure(let structured):
      return ContentBlock(
        content: .structured(schemaName: structured.schemaName, payload: json(from: structured.content)))
    case .attachment(let attachment):
      return contentBlock(for: attachment)
    @unknown default:
      logger.debug("The transcript segment \(segment.id, privacy: .public) is not known.")
      return ContentBlock(content: .unknown(kind: unknownSegmentKind, raw: .string(segment.description)))
    }
  }

  /// Changes an attachment segment into an image block.
  ///
  /// - Parameter segment: The attachment segment.
  /// - Returns: An image block with PNG data, or an unknown block when the
  ///   attachment is not an image or the image does not encode.
  static func contentBlock(for segment: Transcript.AttachmentSegment) -> ContentBlock {
    switch segment.content {
    case .image(let image):
      guard let data = pngData(image.cgImage) else {
        logger.debug("The image of the segment \(segment.id, privacy: .public) does not encode.")
        return unknownAttachmentBlock(segment)
      }
      return ContentBlock(
        content: .image(ImageContent(data: data, mimeType: imageMIMEType, uri: image.url?.absoluteString)))
    @unknown default:
      logger.debug("The attachment of the segment \(segment.id, privacy: .public) is not known.")
      return unknownAttachmentBlock(segment)
    }
  }

  /// An unknown block for an attachment segment.
  ///
  /// - Parameter segment: The attachment segment.
  /// - Returns: The block, with the description of the segment.
  static func unknownAttachmentBlock(_ segment: Transcript.AttachmentSegment) -> ContentBlock {
    ContentBlock(content: .unknown(kind: unknownAttachmentKind, raw: .string(segment.description)))
  }

  /// Encodes an image as PNG data.
  ///
  /// - Parameter image: The image.
  /// - Returns: The PNG data, or `nil` when the image does not encode.
  static func pngData(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data, UTType.png.identifier as CFString, imagesPerFile, nil)
    else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }

  // MARK: - Other records

  /// The text of a list of segments, for a system prompt.
  ///
  /// - Parameter segments: The segments.
  /// - Returns: The text of each segment, with a blank line between two
  ///   segments. A structured segment gives its JSON text, and an attachment
  ///   gives its label or its description.
  static func text(of segments: [Transcript.Segment]) -> String {
    segments.map(text(of:)).joined(separator: instructionsSeparator)
  }

  /// The text of one segment.
  ///
  /// - Parameter segment: The segment.
  /// - Returns: The text content, the JSON text of a structured segment, or
  ///   the label or the description of an attachment.
  static func text(of segment: Transcript.Segment) -> String {
    switch segment {
    case .text(let text): text.content
    case .structure(let structured): structured.content.jsonString
    case .attachment(let attachment): attachment.label ?? attachment.description
    @unknown default: segment.description
    }
  }

  /// The reasoning record of a reasoning entry.
  ///
  /// - Parameter reasoning: The entry.
  /// - Returns: The record, with the text of each segment. The signature is
  ///   the Base64 text of the signature data.
  static func record(for reasoning: Transcript.Reasoning) -> AgentViewKit.Reasoning {
    AgentViewKit.Reasoning(
      id: reasoning.id,
      segments: reasoning.segments.map(text(of:)),
      signature: reasoning.signature?.base64EncodedString(),
      meta: meta(reasoning.metadata)
    )
  }

  /// The tool call record of one call.
  ///
  /// - Parameters:
  ///   - call: The call.
  ///   - output: The output with the id of the call, or `nil`.
  /// - Returns: A completed record with the output, or an in-progress record
  ///   when `output` is `nil`.
  static func record(for call: Transcript.ToolCall, output: Transcript.ToolOutput?) -> ToolCallRecord {
    ToolCallRecord(
      id: call.id,
      title: call.toolName,
      status: output == nil ? .inProgress : .completed,
      content: output.map(toolContent(for:)) ?? [],
      rawInput: json(from: call.arguments),
      meta: meta(call.metadata)
    )
  }

  /// The tool call record of an output that has no call.
  ///
  /// - Parameter output: The output.
  /// - Returns: A completed record with the id and the tool name of the
  ///   output.
  static func record(for output: Transcript.ToolOutput) -> ToolCallRecord {
    ToolCallRecord(
      id: output.id, title: output.toolName, status: .completed, content: toolContent(for: output))
  }

  /// The tool content of an output.
  ///
  /// - Parameter output: The output.
  /// - Returns: One content block for each segment, in order.
  static func toolContent(for output: Transcript.ToolOutput) -> [ToolContent] {
    output.segments.map { .block(contentBlock(for: $0)) }
  }

  // MARK: - JSON

  /// Changes generated content into a kit JSON value.
  ///
  /// - Parameter content: The generated content.
  /// - Returns: The value, or the JSON text as a string when the text does
  ///   not parse.
  public static func json(from content: GeneratedContent) -> AgentViewKit.JSONValue {
    let text = content.jsonString
    return (try? AgentViewKit.JSONValue(json: text)) ?? .string(text)
  }

  /// Changes a kit JSON value into generated content.
  ///
  /// - Parameter value: The value.
  /// - Returns: The generated content.
  /// - Throws: The error of `GeneratedContent(json:)` when the SDK does not
  ///   parse the JSON text of `value`.
  public static func generatedContent(from value: AgentViewKit.JSONValue) throws -> GeneratedContent {
    try GeneratedContent(json: value.jsonString)
  }

  /// Changes the metadata of an entry into a `meta` value.
  ///
  /// - Parameter metadata: The metadata.
  /// - Returns: An object with one member for each key, or `nil` when the
  ///   metadata is empty.
  static func meta(_ metadata: [String: GeneratedContent]) -> AgentViewKit.JSONValue? {
    guard !metadata.isEmpty else { return nil }
    return .object(metadata.mapValues(json(from:)))
  }
}
