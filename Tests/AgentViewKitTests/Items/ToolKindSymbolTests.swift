import AppKit
import Foundation
import Testing

@testable import AgentViewKit

@Suite @MainActor struct ToolKindSymbolTests {
  /// Each kind, with one unknown kind.
  nonisolated static let kinds = ToolKind.knownCases + [.unknown("custom_kind")]

  /// Each status, with one unknown status.
  nonisolated static let statuses = ToolCallStatus.knownCases + [.unknown("custom_status")]

  /// The start time of the duration tests.
  static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

  // MARK: - Kinds

  @Test func eachKindMapsToADistinctSymbol() {
    let names = Self.kinds.map(ToolKindSymbol.name(for:))
    #expect(Set(names).count == Self.kinds.count)
  }

  @Test(arguments: kinds)
  func eachKindSymbolIsASystemSymbol(kind: ToolKind) {
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
  func eachStatusSymbolIsASystemSymbol(status: ToolCallStatus) {
    let name = ToolStatusSymbol.name(for: status)
    #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
  }

  @Test func theStatusLabelsAreTheExpectedText() {
    let expected: [(ToolCallStatus, String)] = [
      (.pending, "Pending"),
      (.inProgress, "Running"),
      (.completed, "Completed"),
      (.failed, "Failed"),
      (.cancelled, "Cancelled"),
      (.lost, "Result lost"),
      (.unknown("custom_status"), "Unknown status"),
    ]
    for (status, label) in expected {
      #expect(ToolStatusSymbol.label(for: status) == label)
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
        == "Read README.md, Running")
    #expect(ToolCallView.accessibilityLabel(title: "", status: .lost) == "Tool call, Result lost")
  }

  @Test func theDurationNeedsBothTimes() {
    #expect(ToolCallView.durationText(from: nil, to: Self.start) == nil)
    #expect(ToolCallView.durationText(from: Self.start, to: nil) == nil)
  }

  @Test func aShortDurationHasOneDecimalAndALongDurationHasNone() {
    let short = Self.start.addingTimeInterval(1.5)
    let long = Self.start.addingTimeInterval(12.4)
    let negative = Self.start.addingTimeInterval(-3)
    #expect(ToolCallView.durationText(from: Self.start, to: short) == "1.5 s")
    #expect(ToolCallView.durationText(from: Self.start, to: long) == "12 s")
    #expect(ToolCallView.durationText(from: Self.start, to: negative) == "0.0 s")
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

  @Test func theIdentifiersAndCounterKeysUseTheRecordID() {
    #expect(ToolCallView.identifier(for: "call") == "tool-call-call")
    #expect(ToolCallView.toggleIdentifier(for: "call") == "tool-call-call-toggle")
    #expect(ToolCallView.bodyIdentifier(for: "call") == "tool-call-call-body")
    #expect(ToolCallView.contentIdentifier(for: "call", index: 2) == "tool-call-call-content-2")
    #expect(ToolCallView.rowCounterKey(for: "call") == "tool-row-call")
    #expect(ToolCallView.bodyCounterKey(for: "call") == "tool-body-call")
  }
}
