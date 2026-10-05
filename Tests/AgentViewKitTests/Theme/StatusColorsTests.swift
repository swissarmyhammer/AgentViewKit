import AgentViewKit
import FoundationModelsACP
import SwiftUI
import Testing

@Suite struct StatusColorsTests {
  /// A set of status colors with a different color for each status.
  static let colors = AgentTheme.StatusColors(
    running: .blue, completed: .green, failed: .red, cancelled: .gray, pending: .yellow)

  @Test(arguments: [
    (FoundationModelsACP.ToolCallStatus.pending, Color.yellow),
    (.inProgress, .blue),
    (.completed, .green),
    (.failed, .red),
    (.cancelled, .gray),
    (.unknown("_lost"), .red),
    (.unknown("paused"), .yellow),
  ])
  func eachToolCallStatusHasItsColor(status: FoundationModelsACP.ToolCallStatus, expected: Color) {
    #expect(Self.colors.color(for: status) == expected)
  }

  @Test(arguments: [
    (AgentViewKit.PlanEntry.Status.pending, Color.yellow),
    (.inProgress, .blue),
    (.completed, .green),
    (.cancelled, .gray),
    (.unknown("paused"), .yellow),
  ])
  func eachPlanEntryStatusHasItsColor(status: AgentViewKit.PlanEntry.Status, expected: Color) {
    #expect(Self.colors.color(for: status) == expected)
  }

  @Test(arguments: [
    (AgentViewKit.PlanEntry.Priority.high, Color.red),
    (.medium, .blue),
    (.low, .yellow),
    (.unknown("urgent"), .yellow),
  ])
  func eachPlanEntryPriorityHasItsTint(priority: AgentViewKit.PlanEntry.Priority, expected: Color) {
    #expect(Self.colors.color(for: priority) == expected)
  }
}
