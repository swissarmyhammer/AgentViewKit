import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient
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
    (FoundationModelsACP.PlanEntryStatus.pending, Color.yellow),
    (.inProgress, .blue),
    (.completed, .green),
    (.cancelled, .gray),
    (.unknown("paused"), .yellow),
  ])
  func eachPlanEntryStatusHasItsColor(status: FoundationModelsACP.PlanEntryStatus, expected: Color) {
    #expect(Self.colors.color(for: status) == expected)
  }

  @Test(arguments: [
    (Unstable.CompactionStatus.inProgress, Color.blue),
    (.completed, .green),
    (.failed, .red),
    (.cancelled, .gray),
    (SessionEntry.Compaction.unreportedStatus, .yellow),
    (.unknown("paused"), .yellow),
  ])
  func eachCompactionStatusHasItsColor(status: Unstable.CompactionStatus, expected: Color) {
    #expect(Self.colors.color(for: status) == expected)
  }

  @Test(arguments: [
    (SendState.pending, Color.yellow),
    (.sent, .green),
    (.failed, .red),
  ])
  func eachSendStateHasItsColor(state: SendState, expected: Color) {
    #expect(Self.colors.color(for: state) == expected)
  }

  @Test(arguments: [
    (Unstable.NoticeSeverity.error, Color.red),
    (.warning, .blue),
    (.info, .yellow),
    (.unknown("critical"), .yellow),
  ])
  func eachNoticeSeverityHasItsTint(severity: Unstable.NoticeSeverity, expected: Color) {
    #expect(Self.colors.color(for: severity) == expected)
  }

  @Test(arguments: [
    (FoundationModelsACP.PlanEntryPriority.high, Color.red),
    (.medium, .blue),
    (.low, .yellow),
    (.unknown("urgent"), .yellow),
  ])
  func eachPlanEntryPriorityHasItsTint(priority: FoundationModelsACP.PlanEntryPriority, expected: Color) {
    #expect(Self.colors.color(for: priority) == expected)
  }
}
