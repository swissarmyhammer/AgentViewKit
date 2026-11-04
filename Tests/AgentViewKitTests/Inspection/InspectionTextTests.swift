import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks the text that the inspector rows of the client models show, with
/// no view.
@Suite @MainActor struct InspectionTextTests {
  /// The path of the location of the tests.
  private static let path = "/tmp/Package.swift"

  @Test func theTextOfAMessageJoinsItsTextBlocksWithABlankLine() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: "First")), .image(ImageContent(data: "", mimeType: MediaType(rawValue: "image/png"))),
      .text(TextContent(text: "Second")),
    ]

    #expect(InspectionText.text(of: content) == "First\n\nSecond")
  }

  @Test func aLocationWithALineEndsWithTheLine() {
    let location = ToolCallLocation(path: AbsolutePath(rawValue: Self.path), line: LineNumber(12))

    #expect(InspectionText.location(location) == "\(Self.path):12")
  }

  @Test func aLocationWithNoLineIsItsPath() {
    let location = ToolCallLocation(path: AbsolutePath(rawValue: Self.path))

    #expect(InspectionText.location(location) == Self.path)
  }

  @Test func aPlanStepStartsWithItsStatus() {
    let entry = PlanEntry(content: "Write the tests", priority: .high, status: .inProgress)

    #expect(InspectionText.step(entry) == "\(WorkStatusLabel.inProgress): Write the tests")
  }

  @Test func aFailedConnectionTellsItsError() {
    let text = InspectionText.connectionState(.failed(ConnectionError.closed))

    #expect(text.hasSuffix(ConnectionError.closed.localizedDescription))
  }

  @Test func aMessageThatDidNotSendSaysSo() {
    #expect(InspectionText.sendState(.failed) == "Not sent")
  }
}
