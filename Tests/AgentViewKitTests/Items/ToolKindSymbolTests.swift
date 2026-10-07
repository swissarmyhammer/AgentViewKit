import AppKit
import Foundation
import FoundationModelsACP
import Testing

@testable import AgentViewKit

@Suite @MainActor struct ToolKindSymbolTests {
  /// The ACP wire value of a call whose result is lost.
  nonisolated static let lostWireValue = "_lost"

  /// Each ACP kind, with one unknown kind.
  nonisolated static let kinds: [FoundationModelsACP.ToolKind] = [
    .read, .edit, .delete, .move, .search, .execute, .think, .fetch, .switchMode, .other,
    .unknown("custom_kind"),
  ]

  /// Each ACP status, with the lost status and one other unknown status.
  nonisolated static let statuses: [FoundationModelsACP.ToolCallStatus] = [
    .pending, .inProgress, .completed, .failed, .cancelled, .unknown(lostWireValue),
    .unknown("custom_status"),
  ]

  // MARK: - Kinds

  @Test func eachKindMapsToADistinctSymbol() {
    let names = Self.kinds.map(ToolKindSymbol.name(for:))
    #expect(Set(names).count == Self.kinds.count)
  }

  @Test(arguments: kinds)
  func eachKindSymbolIsASystemSymbol(kind: FoundationModelsACP.ToolKind) {
    let name = ToolKindSymbol.name(for: kind)
    #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
  }

  @Test func allUnknownKindsShareOneSymbol() {
    #expect(ToolKindSymbol.name(for: .unknown("a")) == ToolKindSymbol.name(for: .unknown("b")))
  }

  // MARK: - Statuses

  @Test func eachStatusMapsToADistinctSymbolAndLabel() {
    let names = Self.statuses.map(ToolStatusSymbol.name(for:))
    let labels = Self.statuses.map(ToolStatusSymbol.label(for:))
    #expect(Set(names).count == Self.statuses.count)
    #expect(Set(labels).count == Self.statuses.count)
  }

  @Test(arguments: statuses)
  func eachStatusSymbolIsASystemSymbol(status: FoundationModelsACP.ToolCallStatus) {
    let name = ToolStatusSymbol.name(for: status)
    #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
  }

  @Test func theStatusLabelsAreTheExpectedText() {
    let expected: [(FoundationModelsACP.ToolCallStatus, String)] = [
      (.pending, "Pending"),
      (.inProgress, "In progress"),
      (.completed, "Completed"),
      (.failed, "Failed"),
      (.cancelled, "Cancelled"),
      (.unknown(Self.lostWireValue), "Result lost"),
      (.unknown("custom_status"), "Unknown status: custom_status"),
    ]
    for (status, label) in expected {
      #expect(ToolStatusSymbol.label(for: status) == label)
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
      #expect(ToolStatusSymbol.label(for: toolStatus) == TaskListView.statusLabel(planStatus))
    }
  }

  @Test func onlyPendingAndRunningCallsAreLive() {
    let live = Self.statuses.filter(ToolStatusSymbol.isLive)
    #expect(live == [.pending, .inProgress])
  }

  // MARK: - Row text

  @Test func theAccessibilityLabelIsTheTitleAndTheStatus() {
    #expect(
      ToolCallView.accessibilityLabel(title: "Read README.md", status: .inProgress)
        == "Read README.md, In progress")
    #expect(
      ToolCallView.accessibilityLabel(title: "", status: .unknown(Self.lostWireValue))
        == "Tool call, Result lost")
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
