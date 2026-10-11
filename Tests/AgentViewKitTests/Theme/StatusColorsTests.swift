import AgentViewKit
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that each status, priority and severity gets its color role from
/// the EditorKit theme.
@Suite struct StatusColorsTests {
  /// A theme with a different color for each role.
  static let theme = DistinctRolesTheme()

  /// The role colors of ``theme``.
  typealias Role = DistinctRolesTheme.Role

  @Test(arguments: [
    (FoundationModelsACP.ToolCallStatus.pending, Role.pending),
    (.inProgress, Role.running),
    (.completed, Role.succeeded),
    (.failed, Role.failed),
    (.cancelled, Role.cancelled),
    (.unknown("_lost"), Role.failed),
    (.unknown("paused"), Role.pending),
  ])
  func eachToolCallStatusHasItsColor(status: FoundationModelsACP.ToolCallStatus, expected: Color) {
    #expect(Self.theme.statusColor(for: status) == expected)
  }

  @Test(arguments: [
    (FoundationModelsACP.PlanEntryStatus.pending, Role.pending),
    (.inProgress, Role.running),
    (.completed, Role.succeeded),
    (.cancelled, Role.cancelled),
    (.unknown("paused"), Role.pending),
  ])
  func eachPlanEntryStatusHasItsColor(status: FoundationModelsACP.PlanEntryStatus, expected: Color) {
    #expect(Self.theme.statusColor(for: status) == expected)
  }

  @Test(arguments: [
    (CompactionStatus.inProgress, Role.running),
    (.completed, Role.succeeded),
    (.failed, Role.failed),
    (.cancelled, Role.cancelled),
    (SessionEntry.Compaction.unreportedStatus, Role.pending),
    (.unknown("paused"), Role.pending),
  ])
  func eachCompactionStatusHasItsColor(status: CompactionStatus, expected: Color) {
    #expect(Self.theme.statusColor(for: status) == expected)
  }

  @Test(arguments: [
    (SendState.pending, Role.pending),
    (.sent, Role.succeeded),
    (.failed, Role.failed),
  ])
  func eachSendStateHasItsColor(state: SendState, expected: Color) {
    #expect(Self.theme.statusColor(for: state) == expected)
  }

  @Test(arguments: [
    (NoticeSeverity.error, Role.error),
    (.warning, Role.warning),
    (.info, Role.info),
    (.unknown("critical"), Role.info),
  ])
  func eachNoticeSeverityHasItsTint(severity: NoticeSeverity, expected: Color) {
    #expect(Self.theme.tint(for: severity) == expected)
  }

  @Test(arguments: [
    (FoundationModelsACP.PlanEntryPriority.high, Role.error),
    (.medium, Role.warning),
    (.low, Role.pending),
    (.unknown("urgent"), Role.pending),
  ])
  func eachPlanEntryPriorityHasItsTint(priority: FoundationModelsACP.PlanEntryPriority, expected: Color) {
    #expect(Self.theme.tint(for: priority) == expected)
  }

  @Test func theSystemThemeGivesTheEditorKitRoleDefaults() {
    let theme = SystemTheme.system
    #expect(theme.statusColor(for: FoundationModelsACP.ToolCallStatus.completed) == ThemeRoleDefaults.succeeded)
    #expect(theme.statusColor(for: FoundationModelsACP.ToolCallStatus.cancelled) == ThemeRoleDefaults.cancelled)
    #expect(theme.tint(for: NoticeSeverity.warning) == ThemeRoleDefaults.warning)
  }
}
