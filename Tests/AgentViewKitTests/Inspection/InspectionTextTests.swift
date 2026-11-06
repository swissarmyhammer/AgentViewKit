import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks the text that the inspector rows of the client models show, with
/// no view.
@Suite @MainActor struct InspectionTextTests {
  @Test func theTextOfAMessageJoinsItsTextBlocksWithABlankLine() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: "First")), .image(ImageContent(data: "", mimeType: MediaType(rawValue: "image/png"))),
      .text(TextContent(text: "Second")),
    ]

    #expect(InspectionText.text(of: content) == "First\n\nSecond")
  }

  @Test func aPlanStepStartsWithItsStatus() {
    let entry = PlanEntry(content: "Write the tests", priority: .high, status: .inProgress)

    #expect(InspectionText.step(entry) == "\(EditorStatus(EditorSymbol.Status.inProgress).label): Write the tests")
  }
}
