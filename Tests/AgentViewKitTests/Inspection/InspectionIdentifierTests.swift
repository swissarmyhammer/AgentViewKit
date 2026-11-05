import EditorInspector
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks that each inspection of the kit has an explicit id, which is the
/// view part of the scheme id of each of its rows, with no view.
///
/// An inspection with no id of its own takes the key of the name of its
/// type from EditorKit, such as `toolcallentry`, which a rename of the type
/// changes.
@Suite @MainActor struct InspectionIdentifierTests {
  @Test func eachClientModelInspectionHasAnExplicitID() {
    let ids = [
      ToolCallEntry.inspection.id, TerminalEntry.inspection.id, UserMessageEntry.inspection.id,
      AgentMessageEntry.inspection.id, ThoughtEntry.inspection.id, SessionMessageEntry.inspection.id,
      PlanTranscriptEntry.inspection.id, CompactionEntry.inspection.id, ErrorEntry.inspection.id,
      UnknownEntry.inspection.id, SessionModel.inspection.id, ConnectionModel.inspection.id,
      MCPServerItem.inspection.id,
    ]

    #expect(
      ids == [
        "tool-call", "terminal", "user-message", "agent-message", "thought", "session-message", "plan",
        "compaction", "error", "unknown-update", "session", "connection", "mcp-server",
      ])
  }

  @Test func theConfigOptionsInspectionHasTheIDOfItsView() {
    let inspection = ConfigOptionFields.inspection(title: "Options", sections: [], reporting: nil)

    #expect(inspection.id == ConfigOptionsView.viewIdentifier)
  }
}
