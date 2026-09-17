import AgentViewKit
import AgentViewKitFoundationModels
import CoreGraphics
import Foundation
import FoundationModels
import Testing

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

  /// The arguments of the tool call, as JSON.
  static let argumentsJSON = #"{"path":"README.md"}"#

  /// The width and the height of the sample image, in pixels.
  static let imageSide = 2

  /// The number of bits in each color component of the sample image.
  static let bitsPerComponent = 8

  /// The number of bytes in each pixel of the sample image.
  static let bytesPerPixel = 4

  /// The number of items that ``fullTranscript(includesOutput:)`` gives.
  static let fullItemCount = 5

  /// The signature of the PNG file format.
  static let pngSignature = Data([0x89, 0x50, 0x4E, 0x47])

  /// A small opaque image.
  static func image() throws -> CGImage {
    let context = try #require(
      CGContext(
        data: nil, width: imageSide, height: imageSide, bitsPerComponent: bitsPerComponent,
        bytesPerRow: imageSide * bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor.black)
    context.fill(CGRect(x: 0, y: 0, width: imageSide, height: imageSide))
    return try #require(context.makeImage())
  }

  /// A tool call with the sample arguments.
  static func toolCall() throws -> Transcript.ToolCall {
    Transcript.ToolCall(
      id: toolCallID, toolName: toolName, arguments: try GeneratedContent(json: argumentsJSON))
  }

  /// A transcript with instructions, a prompt with an image, a reasoning
  /// entry, a tool call with output, and a response.
  ///
  /// - Parameter includesOutput: Whether the transcript has the output of the
  ///   tool call.
  /// - Returns: The transcript.
  static func fullTranscript(includesOutput: Bool = true) throws -> Transcript {
    var entries: [Transcript.Entry] = [
      .instructions(
        Transcript.Instructions(
          id: instructionsID, segments: [.text(.init(content: instructionsText))], toolDefinitions: [])),
      .prompt(
        Transcript.Prompt(
          id: promptID,
          segments: [
            .text(.init(content: promptText)),
            .attachment(.init(content: .image(.init(try image())), label: "Screenshot")),
          ])),
      .reasoning(
        Transcript.Reasoning(id: reasoningID, segments: [.text(.init(content: reasoningText))])),
      .toolCalls(Transcript.ToolCalls(id: toolCallsID, [try toolCall()])),
    ]
    if includesOutput {
      entries.append(
        .toolOutput(
          Transcript.ToolOutput(
            id: toolCallID, toolName: toolName, segments: [.text(.init(content: outputText))])))
    }
    entries.append(
      .response(
        Transcript.Response(id: responseID, segments: [.text(.init(content: responseText))])))
    return Transcript(entries: entries)
  }

  /// A transcript with one prompt that holds a structured segment.
  ///
  /// - Parameters:
  ///   - schemaName: The schema name of the segment.
  ///   - json: The JSON body of the segment.
  /// - Returns: The transcript.
  static func structuredTranscript(schemaName: String, json: String) throws -> Transcript {
    Transcript(entries: [
      .prompt(
        Transcript.Prompt(
          id: promptID,
          segments: [
            .text(.init(content: promptText)),
            .structure(
              Transcript.StructuredSegment(
                id: structuredID, schemaName: schemaName, content: try GeneratedContent(json: json))),
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

@Suite @MainActor struct TranscriptMappingTests {
  /// The sample approval payload.
  static let approval = ApprovalPayload(
    id: "approval-1", title: "Delete the build folder", description: "The agent wants to delete it.",
    options: ["Allow", "Deny"])

  @Test func aFullTranscriptMapsToFiveItemsInOrder() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript())

    #expect(items.map(kindName) == ["system", "userMessage", "reasoning", "toolCall", "assistantMessage"])
    #expect(
      items.map(\.id) == [
        TranscriptSamples.instructionsID, TranscriptSamples.promptID, TranscriptSamples.reasoningID,
        TranscriptSamples.toolCallID, TranscriptSamples.responseID,
      ])
  }

  @Test func eachRecordHoldsTheContentOfItsEntry() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript())
    try #require(items.count == TranscriptSamples.fullItemCount)

    guard case .system(let system) = items[0] else { throw MappingTestError.wrongKind }
    #expect(system.text == TranscriptSamples.instructionsText)

    guard case .userMessage(let prompt) = items[1] else { throw MappingTestError.wrongKind }
    #expect(prompt.blocks.map(\.kind) == [.text, .image])
    #expect(prompt.blocks.first?.content == .text(TranscriptSamples.promptText))
    guard case .image(let image) = prompt.blocks.last?.content else { throw MappingTestError.wrongKind }
    #expect(image.mimeType == "image/png")
    #expect(image.data.starts(with: TranscriptSamples.pngSignature))

    guard case .reasoning(let reasoning) = items[2] else { throw MappingTestError.wrongKind }
    #expect(reasoning.text == TranscriptSamples.reasoningText)

    guard case .assistantMessage(let response) = items[4] else { throw MappingTestError.wrongKind }
    #expect(response.blocks == [ContentBlock(text: TranscriptSamples.responseText)])
  }

  @Test func aPairedToolCallIsCompletedWithItsOutput() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript())
    guard case .toolCall(let call) = items.first(where: { $0.id == TranscriptSamples.toolCallID }) else {
      throw MappingTestError.wrongKind
    }

    #expect(call.title == TranscriptSamples.toolName)
    #expect(call.status == .completed)
    #expect(call.rawInput == .object(["path": .string("README.md")]))
    #expect(call.content == [.block(ContentBlock(text: TranscriptSamples.outputText))])
  }

  @Test func anUnpairedToolCallIsInProgress() throws {
    let items = TranscriptMapping.items(for: try TranscriptSamples.fullTranscript(includesOutput: false))
    guard case .toolCall(let call) = items.first(where: { $0.id == TranscriptSamples.toolCallID }) else {
      throw MappingTestError.wrongKind
    }

    #expect(call.status == .inProgress)
    #expect(call.content.isEmpty)
  }

  @Test func anOutputWithNoCallIsACompletedToolCall() {
    let transcript = Transcript(entries: [
      .toolOutput(
        Transcript.ToolOutput(
          id: TranscriptSamples.toolCallID, toolName: TranscriptSamples.toolName,
          segments: [.text(.init(content: TranscriptSamples.outputText))]))
    ])
    let items = TranscriptMapping.items(for: transcript)

    guard case .toolCall(let call)? = items.first, items.count == 1 else {
      Issue.record("The output gives \(items.map(kindName)).")
      return
    }
    #expect(call.status == .completed)
    #expect(call.title == TranscriptSamples.toolName)
  }

  @Test func aCatalogSegmentDecodesToTheTypedPayload() throws {
    let segment = Transcript.StructuredSegment(
      id: TranscriptSamples.structuredID, schemaName: ApprovalPayload.schemaName,
      content: try GeneratedContent(json: Self.approval.jsonValue().jsonString))

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
      schemaName: ApprovalPayload.schemaName, json: Self.approval.jsonValue().jsonString)
    let items = TranscriptMapping.items(for: transcript)

    guard case .userMessage(let message)? = items.first, items.count == 1 else {
      Issue.record("The transcript gives \(items.map(kindName)).")
      return
    }
    #expect(message.blocks.map(\.kind) == [.text, .structured])
  }

  @Test func anUnknownSchemaNameBecomesAStructuredRecord() throws {
    let schemaName = "Host.Chart"
    let transcript = try TranscriptSamples.structuredTranscript(schemaName: schemaName, json: #"{"points":[1,2]}"#)
    let items = TranscriptMapping.items(for: transcript)

    #expect(items.map(kindName) == ["userMessage", "structured"])
    guard case .structured(let record) = items.last else { throw MappingTestError.wrongKind }
    #expect(record.id == TranscriptSamples.structuredID)
    #expect(record.schemaName == schemaName)
    #expect(record.payload == .object(["points": .array([.number(1), .number(2)])]))
    guard case .userMessage(let message) = items.first else { throw MappingTestError.wrongKind }
    #expect(message.blocks.map(\.kind) == [.text])
  }

  @Test func aCatalogNameWithABadBodyBecomesAStructuredRecord() throws {
    let transcript = try TranscriptSamples.structuredTranscript(
      schemaName: ApprovalPayload.schemaName, json: #"{"id":true}"#)
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

    guard case .userMessage(let message)? = items.first else { throw MappingTestError.wrongKind }
    #expect(message.meta == .object(["source": .string("voice")]))
  }

  @Test func jsonValuesRoundTripThroughGeneratedContent() throws {
    let value = AgentViewKit.JSONValue.object([
      "name": .string("chart"), "count": .number(2), "flags": .array([.bool(true), .null]),
    ])

    let content = try TranscriptMapping.generatedContent(from: value)
    #expect(TranscriptMapping.json(from: content) == value)
  }
}

/// The error that a mapping test throws when an item has the wrong kind.
enum MappingTestError: Error {
  case wrongKind
}
