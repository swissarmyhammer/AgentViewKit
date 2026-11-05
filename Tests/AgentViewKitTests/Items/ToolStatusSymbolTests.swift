import AgentViewKitTestSupport
import EditorSwiftUI
import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

@Suite @MainActor struct ToolStatusSymbolTests {
  /// The ACP wire value of a call whose result is lost.
  nonisolated static let lostWireValue = "_lost"

  /// Each ACP status, with the lost status and one other unknown status.
  nonisolated static let statuses: [FoundationModelsACP.ToolCallStatus] = [
    .pending, .inProgress, .completed, .failed, .cancelled, .unknown(lostWireValue),
    .unknown("custom_status"),
  ]

  // MARK: - Statuses

  @Test func eachStatusHasADistinctText() {
    NameChecks.expectDistinctNames(Self.statuses.map { EditorStatus($0).summary })
  }

  @Test func theStatusTextsAreTheExpectedText() {
    let expected: [(FoundationModelsACP.ToolCallStatus, String)] = [
      (.pending, "Pending"),
      (.inProgress, "In progress"),
      (.completed, "Completed"),
      (.failed, "Failed"),
      (.cancelled, "Cancelled"),
      (.unknown(Self.lostWireValue), "Lost"),
      (.unknown("custom_status"), "Unknown: custom_status"),
    ]
    for (status, text) in expected {
      #expect(EditorStatus(status).summary == text)
    }
  }

  @Test func aToolCallAndAPlanEntryShareTheNameOfEachCommonStatus() {
    let pairs: [(FoundationModelsACP.ToolCallStatus, FoundationModelsACP.PlanEntryStatus)] = [
      (.pending, .pending),
      (.inProgress, .inProgress),
      (.completed, .completed),
      (.cancelled, .cancelled),
      (.unknown("other"), .unknown("other")),
    ]
    for (toolStatus, planStatus) in pairs {
      #expect(EditorStatus(toolStatus).summary == EditorStatus(planStatus).summary)
    }
  }

  @Test func onlyPendingAndRunningCallsAreLive() {
    let live = Self.statuses.filter { EditorStatus($0).isLive }
    #expect(live == [.pending, .inProgress])
  }

  // MARK: - Row text

  @Test func theAccessibilityLabelIsTheTitleAndTheStatus() {
    #expect(
      ToolCallView.accessibilityLabel(title: "Read README.md", status: .inProgress)
        == "Read README.md, In progress")
    #expect(
      ToolCallView.accessibilityLabel(title: "", status: .unknown(Self.lostWireValue))
        == "Tool call, Lost")
  }

  // MARK: - Command output

  @Test func theCommandComesFromAStringOrAnArrayValue() {
    #expect(ToolCallView.command(from: .object(["command": .string("ls -la")])) == "ls -la")
    #expect(
      ToolCallView.command(from: .object(["cmd": .array([.string("git"), .string("status")])]))
        == "git status")
    #expect(ToolCallView.command(from: .object(["path": .string("/tmp")])) == nil)
    #expect(ToolCallView.command(from: .string("ls")) == nil)
    #expect(ToolCallView.command(from: nil) == nil)
  }

  @Test func theExitCodeComesFromEitherKey() {
    #expect(ToolCallView.exitCode(from: .object(["exitCode": .number(2)])) == 2)
    #expect(ToolCallView.exitCode(from: .object(["exit_code": .number(0)])) == 0)
    #expect(ToolCallView.exitCode(from: .object(["stdout": .string("")])) == nil)
    #expect(ToolCallView.exitCode(from: nil) == nil)
  }

  // MARK: - Identifiers

  @Test func theIdentifiersAndCounterKeysUseTheRowKey() {
    #expect(ToolCallView.identifier(for: "call") == "tool-call-call")
    #expect(ToolCallView.toggleIdentifier(for: "call") == "tool-call-call-toggle")
    #expect(ToolCallView.bodyIdentifier(for: "call") == "tool-call-call-body")
    #expect(ToolCallView.contentIdentifier(for: "call", index: 2) == "tool-call-call-content-2")
    #expect(ToolCallView.rowCounterKey(for: "call") == "tool-row-call")
    #expect(ToolCallView.bodyCounterKey(for: "call") == "tool-body-call")
  }
}
