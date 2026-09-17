import AgentViewKit
import AgentViewKitFoundationModels
import CoreGraphics
import Foundation
import FoundationModels
import ImageIO
import Testing
import UniformTypeIdentifiers

/// The transcripts that the mapping tests read.
enum TranscriptSamples {
  /// The id of the instructions entry.
  static let instructionsID = "instructions-1"

  /// The id of the prompt entry.
  static let promptID = "prompt-1"

  /// The id of the reasoning entry.
  static let reasoningID = "reasoning-1"

  /// The id of the tool calls entry.
  static let toolCallsID = "tool-calls-1"

  /// The id of the tool call and of its output.
  static let toolCallID = "call-1"

  /// The id of the response entry.
  static let responseID = "response-1"

  /// The id of the structured segment.
  static let structuredID = "structured-1"

  /// The name of the tool.
  static let toolName = "readFile"

  /// The label of the image attachment.
  static let imageLabel = "Screenshot"

  /// The text of the instructions.
  static let instructionsText = "You are a helpful agent."

  /// The text of the prompt.
  static let promptText = "Read the file."

  /// The text of the reasoning.
  static let reasoningText = "The user wants the file."

  /// The text of the tool output.
  static let outputText = "The file text."

  /// The text of the response.
  static let responseText = "The file says hello."

  /// The path argument of the tool call.
  static let pathArgument = "README.md"

  /// The arguments of the tool call, as a kit value.
  static let arguments = AgentViewKit.JSONValue.object(["path": .string(pathArgument)])

  /// The width and the height of the sample image, in pixels.
  static let imageSide = 2

  /// The number of bits in each color component of the sample image.
  static let bitsPerComponent = 8

  /// The number of bytes in each pixel of the sample image.
  static let bytesPerPixel = 4

  /// The kinds of the items of ``fullTranscript(includesOutput:)``, in order.
  static let fullItemKinds = ["system", "userMessage", "reasoning", "toolCall", "assistantMessage"]

  /// The ids of the items of ``fullTranscript(includesOutput:)``, in order.
  static let fullItemIDs = [instructionsID, promptID, reasoningID, toolCallID, responseID]

  /// A small opaque image.
  static func image() throws -> CGImage {
    let context = try #require(
      CGContext(
        data: nil, width: imageSide, height: imageSide, bitsPerComponent: bitsPerComponent,
        bytesPerRow: imageSide * bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor.black)
    context.fill(CGRect(origin: .zero, size: CGSize(width: imageSide, height: imageSide)))
    return try #require(context.makeImage())
  }

  /// A tool call with the sample arguments.
  static func toolCall() throws -> Transcript.ToolCall {
    Transcript.ToolCall(
      id: toolCallID, toolName: toolName, arguments: try TranscriptMapping.generatedContent(from: arguments))
  }

  /// A transcript with instructions, a prompt with an image, a reasoning
  /// entry, a tool call with output, and a response.
  ///
  /// - Parameter includesOutput: Whether the transcript has the output of the
  ///   tool call.
  /// - Returns: The transcript.
  static func fullTranscript(includesOutput: Bool = true) throws -> Transcript {
    let before: [Transcript.Entry] = [
      .instructions(
        Transcript.Instructions(
          id: instructionsID, segments: [.text(.init(content: instructionsText))], toolDefinitions: [])),
      .prompt(
        Transcript.Prompt(
          id: promptID,
          segments: [
            .text(.init(content: promptText)),
            .attachment(.init(content: .image(.init(try image())), label: imageLabel)),
          ])),
      .reasoning(
        Transcript.Reasoning(id: reasoningID, segments: [.text(.init(content: reasoningText))])),
      .toolCalls(Transcript.ToolCalls(id: toolCallsID, [try toolCall()])),
    ]
    let output: [Transcript.Entry] = [
      .toolOutput(
        Transcript.ToolOutput(id: toolCallID, toolName: toolName, segments: [.text(.init(content: outputText))]))
    ]
    let response: Transcript.Entry = .response(
      Transcript.Response(id: responseID, segments: [.text(.init(content: responseText))]))
    return Transcript(entries: before + (includesOutput ? output : []) + [response])
  }

  /// A transcript with one prompt that holds a structured segment.
  ///
  /// - Parameters:
  ///   - schemaName: The schema name of the segment.
  ///   - body: The JSON body of the segment.
  /// - Returns: The transcript.
  static func structuredTranscript(schemaName: String, body: AgentViewKit.JSONValue) throws -> Transcript {
    Transcript(entries: [
      .prompt(
        Transcript.Prompt(
          id: promptID,
          segments: [
            .text(.init(content: promptText)),
            .structure(
              Transcript.StructuredSegment(
                id: structuredID, schemaName: schemaName,
                content: try TranscriptMapping.generatedContent(from: body))),
          ]))
    ])
  }
}

/// The name of the kind of an item, for the comparison of item lists.
private func kindName(_ item: ThreadItem) -> String {
  switch item {
  case .system: "system"
  case .userMessage: "userMessage"
  case .assistantMessage: "assistantMessage"
  case .reasoning: "reasoning"
  case .toolCall: "toolCall"
  case .structured: "structured"
  case .compaction: "compaction"
  case .error: "error"
  case .unknown: "unknown"
  }
}

/// The item with an id.
///
/// - Parameters:
///   - id: The id of the item.
///   - items: The items to search.
/// - Returns: The item.
/// - Throws: ``MappingTestError/noItem`` when no item has `id`.
private func item(_ id: String, in items: [ThreadItem]) throws -> ThreadItem {
  guard let item = items.first(where: { $0.id == id }) else { throw MappingTestError.noItem }
  return item
}

@Suite @MainActor struct TranscriptMappingTests {
  /// The sample approval payload.
  static let approval = ApprovalPayload(
    id: "approval-1", title: "Delete the build folder", description: "The agent wants to delete it.",
    options: ["Allow", "Deny"])

  /// The schema name that the catalog does not know.
  static let unknownSchemaName = "Host.Chart"

  /// The points of the unknown chart body.
  static let chartPoints: [Double] = [1, 2]

  /// The body of the unknown chart segment.
  static let chartBody = AgentViewKit.JSONValue.object(["points": .array(chartPoints.map { .number($0) })])

  /// An approval body in which the id has the wrong type.
  static let badApprovalBody = AgentViewKit.JSONValue.object(["id": .bool(true)])

  @Test func aFullTranscriptMapsToFiveItemsInOrder() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript())

    #expect(items.map(kindName) == TranscriptSamples.fullItemKinds)
    #expect(items.map(\.id) == TranscriptSamples.fullItemIDs)
  }

  @Test func eachRecordHoldsTheContentOfItsEntry() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript())

    guard case .system(let system) = try item(TranscriptSamples.instructionsID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(system.text == TranscriptSamples.instructionsText)

    guard case .reasoning(let reasoning) = try item(TranscriptSamples.reasoningID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(reasoning.text == TranscriptSamples.reasoningText)

    guard case .assistantMessage(let response) = try item(TranscriptSamples.responseID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(response.blocks == [ContentBlock(text: TranscriptSamples.responseText)])
  }

  @Test func aPromptImageBecomesAPNGImageBlock() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript())
    guard case .userMessage(let prompt) = try item(TranscriptSamples.promptID, in: items) else {
      throw MappingTestError.wrongKind
    }

    #expect(prompt.blocks.map(\.kind) == [.text, .image])
    #expect(prompt.blocks.first?.content == .text(TranscriptSamples.promptText))
    guard case .image(let image) = prompt.blocks.last?.content else { throw MappingTestError.wrongKind }
    #expect(image.mimeType == UTType.png.preferredMIMEType)
    let source = try #require(CGImageSourceCreateWithData(image.data as CFData, nil))
    #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
    let decoded = try #require(CGImageSourceCreateImageAtIndex(source, .zero, nil))
    #expect(decoded.width == TranscriptSamples.imageSide)
  }

  @Test func aPairedToolCallIsCompletedWithItsOutput() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript())
    guard case .toolCall(let call) = try item(TranscriptSamples.toolCallID, in: items) else {
      throw MappingTestError.wrongKind
    }

    #expect(call.title == TranscriptSamples.toolName)
    #expect(call.status == .completed)
    #expect(call.rawInput == TranscriptSamples.arguments)
    #expect(call.content == [.block(ContentBlock(text: TranscriptSamples.outputText))])
  }

  @Test func anUnpairedToolCallIsInProgress() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript(includesOutput: false))
    guard case .toolCall(let call) = try item(TranscriptSamples.toolCallID, in: items) else {
      throw MappingTestError.wrongKind
    }

    #expect(call.status == .inProgress)
    #expect(call.content.isEmpty)
  }

  @Test func anOutputWithNoCallIsACompletedToolCall() throws {
    let transcript = Transcript(entries: [
      .toolOutput(
        Transcript.ToolOutput(
          id: TranscriptSamples.toolCallID, toolName: TranscriptSamples.toolName,
          segments: [.text(.init(content: TranscriptSamples.outputText))]))
    ])
    let items = TranscriptMapping.items(for: transcript)

    #expect(items.map(kindName) == ["toolCall"])
    guard case .toolCall(let call) = try item(TranscriptSamples.toolCallID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(call.status == .completed)
    #expect(call.title == TranscriptSamples.toolName)
  }

  @Test func aCatalogSegmentDecodesToTheTypedPayload() throws {
    let segment = Transcript.StructuredSegment(
      id: TranscriptSamples.structuredID, schemaName: ApprovalPayload.schemaName,
      content: try TranscriptMapping.generatedContent(from: Self.approval.jsonValue()))

    guard case .block(let block) = TranscriptMapping.structuredContent(for: segment) else {
      throw MappingTestError.wrongKind
    }
    guard case .structured(let schemaName, let payload) = block.content else {
      throw MappingTestError.wrongKind
    }
    #expect(schemaName == ApprovalPayload.schemaName)
    #expect(try ApprovalPayload(content: payload) == Self.approval)
  }

  @Test func aCatalogSegmentStaysInItsMessage() throws {
    let transcript = try TranscriptSamples.structuredTranscript(
      schemaName: ApprovalPayload.schemaName, body: Self.approval.jsonValue())
    let items = TranscriptMapping.items(for: transcript)

    #expect(items.map(kindName) == ["userMessage"])
    guard case .userMessage(let message) = try item(TranscriptSamples.promptID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(message.blocks.map(\.kind) == [.text, .structured])
  }

  @Test func anUnknownSchemaNameBecomesAStructuredRecord() throws {
    let transcript = try TranscriptSamples.structuredTranscript(
      schemaName: Self.unknownSchemaName, body: Self.chartBody)
    let items = TranscriptMapping.items(for: transcript)

    #expect(items.map(kindName) == ["userMessage", "structured"])
    guard case .structured(let record) = try item(TranscriptSamples.structuredID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(record.schemaName == Self.unknownSchemaName)
    #expect(record.payload == Self.chartBody)
    guard case .userMessage(let message) = try item(TranscriptSamples.promptID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(message.blocks.map(\.kind) == [.text])
  }

  @Test func aCatalogNameWithABadBodyBecomesAStructuredRecord() throws {
    let transcript = try TranscriptSamples.structuredTranscript(
      schemaName: ApprovalPayload.schemaName, body: Self.badApprovalBody)
    let items = TranscriptMapping.items(for: transcript)

    #expect(items.map(kindName) == ["userMessage", "structured"])
  }

  @Test func metadataGoesToTheMetaValue() throws {
    let transcript = Transcript(entries: [
      .prompt(
        Transcript.Prompt(
          id: TranscriptSamples.promptID, metadata: ["source": "voice"],
          segments: [.text(.init(content: TranscriptSamples.promptText))]))
    ])
    let items = TranscriptMapping.items(for: transcript)

    guard case .userMessage(let message) = try item(TranscriptSamples.promptID, in: items) else {
      throw MappingTestError.wrongKind
    }
    #expect(message.meta == .object(["source": .string("voice")]))
  }

  @Test func jsonValuesRoundTripThroughGeneratedContent() throws {
    let value = AgentViewKit.JSONValue.object([
      "name": .string("chart"), "points": Self.chartBody, "flags": .array([.bool(true), .null]),
    ])

    let content = try TranscriptMapping.generatedContent(from: value)
    #expect(TranscriptMapping.json(from: content) == value)
  }
}

/// The error that a mapping test throws when the items are not as expected.
enum MappingTestError: Error {
  /// An item has the wrong kind.
  case wrongKind

  /// No item has the expected id.
  case noItem
}
