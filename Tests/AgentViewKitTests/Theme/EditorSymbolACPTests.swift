import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Checks that each ACP kind, status and priority that the kit shows as a
/// symbol gives its EditorKit symbol, so it draws in the tone of the theme
/// that EditorKit gives it.
///
/// EditorKit's own tests check that each symbol is an SF Symbol, that two
/// cases of one kind show two symbols, and that each tone reads its token of
/// the theme. These tests check only the map from ACP to EditorKit.
@Suite struct EditorSymbolACPTests {
  /// The ACP wire value of a call whose result is lost.
  nonisolated static let lostWireValue = "_lost"

  @Test(arguments: [
    (FoundationModelsACP.ToolKind.read, EditorSymbol.ToolKind.read),
    (.edit, .edit),
    (.delete, .delete),
    (.move, .move),
    (.search, .search),
    (.execute, .execute),
    (.think, .think),
    (.fetch, .fetch),
    (.switchMode, .switchMode),
    (.other, .other),
    (.unknown("custom_kind"), .unknown),
  ])
  func eachToolKindGivesItsEditorKitKind(kind: FoundationModelsACP.ToolKind, expected: EditorSymbol.ToolKind) {
    #expect(EditorSymbol.ToolKind(kind) == expected)
  }

  @Test(arguments: [
    (FoundationModelsACP.ToolCallStatus.pending, EditorSymbol.Status.pending),
    (.inProgress, .inProgress),
    (.paused, .paused),
    (.completed, .completed),
    (.failed, .failed),
    (.cancelled, .cancelled),
    (.unknown(lostWireValue), .lost),
    (.unknown("custom_status"), .unknown),
  ])
  func eachToolCallStatusGivesItsEditorKitStatus(
    status: FoundationModelsACP.ToolCallStatus, expected: EditorSymbol.Status
  ) {
    #expect(EditorSymbol.Status(status) == expected)
  }

  @Test(arguments: [
    (FoundationModelsACP.PlanEntryStatus.pending, EditorSymbol.Status.pending),
    (.inProgress, .inProgress),
    (.completed, .completed),
    (.cancelled, .cancelled),
    (.unknown("paused"), .unknown),
  ])
  func eachPlanEntryStatusGivesItsEditorKitStatus(
    status: FoundationModelsACP.PlanEntryStatus, expected: EditorSymbol.Status
  ) {
    #expect(EditorSymbol.Status(status) == expected)
  }

  @Test(arguments: [
    (CompactionStatus.inProgress, EditorSymbol.Status.inProgress),
    (.completed, .completed),
    (.failed, .failed),
    (.cancelled, .cancelled),
    (SessionEntry.Compaction.unreportedStatus, .unknown),
    (.unknown("paused"), .unknown),
  ])
  func eachCompactionStatusGivesItsEditorKitStatus(status: CompactionStatus, expected: EditorSymbol.Status) {
    #expect(EditorSymbol.Status(status) == expected)
  }

  @Test(arguments: [
    (SendState.pending, EditorSymbol.Status.pending),
    (.sent, .completed),
    (.failed, .failed),
  ])
  func eachSendStateGivesItsEditorKitStatus(state: SendState, expected: EditorSymbol.Status) {
    #expect(EditorSymbol.Status(state) == expected)
  }

  @Test(arguments: [
    (CommandOutputView.ExitOutcome.success, EditorSymbol.Status.completed),
    (.failure, .failed),
  ])
  func eachExitOutcomeGivesItsEditorKitStatus(outcome: CommandOutputView.ExitOutcome, expected: EditorSymbol.Status) {
    #expect(EditorSymbol.Status(outcome) == expected)
  }

  @Test(arguments: [
    (FoundationModelsACP.PlanEntryPriority.high, EditorSymbol.Tone.error),
    (.medium, .warning),
    (.low, .pending),
    (.unknown("urgent"), .pending),
  ])
  func eachPlanEntryPriorityGivesItsTone(priority: FoundationModelsACP.PlanEntryPriority, expected: EditorSymbol.Tone) {
    #expect(EditorSymbol.Tone(priority) == expected)
  }

  @Test func aLostResultDrawsInTheFailedColorOfTheTheme() {
    let status = FoundationModelsACP.ToolCallStatus.unknown(Self.lostWireValue)
    let tone = EditorSymbol.status(EditorSymbol.Status(status)).tone

    #expect(tone.color(in: DistinctRolesTheme()) == DistinctRolesTheme.Role.failed)
  }
}
