import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct CommandOutputViewHostedTests {
  /// The number of lines in the long output.
  static let longLineCount = 500
  /// The row limit of the capped view in the tests.
  static let rowLimit = 20
  /// The exit code of a command that failed.
  nonisolated static let failureExitCode = 1
  /// The exit code of a command that completed.
  nonisolated static let successExitCode = 0
  /// The command in the header.
  static let command = "swift build"

  /// An exit code below zero, which a command that a signal stopped can have.
  nonisolated static let negativeExitCode = -1
  /// The row limit of the tests of ``CommandOutputView/VisibleRows``.
  static let smallRowLimit = 2
  /// A row limit below one.
  static let zeroRowLimit = 0

  /// The output with ``longLineCount`` numbered lines.
  static let longOutput = (1...longLineCount).map(line).joined(separator: "\n")

  /// The text of the line with `number` in the long output.
  ///
  /// - Parameter number: The line number, from one.
  /// - Returns: The text of the line.
  nonisolated static func line(_ number: Int) -> String {
    "line \(number)"
  }

  /// A set of status colors with a different color for each status.
  static let colors = AgentTheme.StatusColors(
    running: .blue, completed: .green, failed: .red, cancelled: .gray, pending: .yellow)

  // MARK: - Mount

  @Test func mountsAnElementWithTheExitCodeInTheLabel() {
    let harness = HostedViewHarness(
      CommandOutputView(command: Self.command, output: "ok", exitCode: Self.successExitCode))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: CommandOutputView.identifier)
    #expect(element?.label == "Command output, exit \(Self.successExitCode)")
    let titles = harness.accessibilityElements().filter { $0.label == Self.command }
    #expect(!titles.isEmpty)
  }

  @Test func aNilExitCodeMountsNoFooterAndALabelWithNoCode() {
    let harness = HostedViewHarness(
      CommandOutputView(command: nil, output: "ok", exitCode: nil))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: CommandOutputView.identifier)?.label == "Command output")
    #expect(harness.element(identifier: CommandOutputView.footerIdentifier) == nil)
  }

  // MARK: - Footer

  @Test func exitCodeZeroTintsSuccess() {
    let harness = HostedViewHarness(
      CommandOutputView(command: Self.command, output: "ok", exitCode: Self.successExitCode))
    defer { harness.close() }
    harness.pump()

    let footer = harness.element(identifier: CommandOutputView.footerIdentifier)
    #expect(footer?.label == "Exit code \(Self.successExitCode)")
    #expect(footer?.value == CommandOutputView.ExitOutcome.success.label)
    #expect(Self.colors.color(for: CommandOutputView.ExitOutcome.success) == .green)
  }

  @Test func exitCodeOneTintsFailure() {
    let harness = HostedViewHarness(
      CommandOutputView(command: Self.command, output: "error", exitCode: Self.failureExitCode))
    defer { harness.close() }
    harness.pump()

    let footer = harness.element(identifier: CommandOutputView.footerIdentifier)
    #expect(footer?.label == "Exit code \(Self.failureExitCode)")
    #expect(footer?.value == CommandOutputView.ExitOutcome.failure.label)
    #expect(Self.colors.color(for: CommandOutputView.ExitOutcome.failure) == .red)
  }

  @Test(arguments: [
    (Int?.some(successExitCode), CommandOutputView.ExitOutcome?.some(.success)),
    (failureExitCode, .failure),
    (negativeExitCode, .failure),
    (nil, nil),
  ])
  func eachExitCodeHasItsOutcome(exitCode: Int?, expected: CommandOutputView.ExitOutcome?) {
    #expect(CommandOutputView.ExitOutcome(exitCode: exitCode) == expected)
  }

  @Test func theOutcomesHaveDistinctLabels() {
    #expect(CommandOutputView.ExitOutcome.success.label != CommandOutputView.ExitOutcome.failure.label)
  }

  // MARK: - Cap

  @Test func longOutputShowsTheCapAndTheLastRows() {
    let model = EditorModel("")
    let harness = HostedViewHarness(
      CommandOutputView(
        command: Self.command, output: Self.longOutput, exitCode: nil,
        rowLimit: Self.rowLimit, model: model))
    defer { harness.close() }
    harness.pump()

    let cap = harness.element(identifier: CommandOutputView.capIdentifier)
    #expect(cap?.label == "Showing the last \(Self.rowLimit) of \(Self.longLineCount) lines")
    #expect(
      harness.element(identifier: CommandOutputView.showAllIdentifier)?.label
        == "Show all \(Self.longLineCount) lines")
    let lines = model.text.split(separator: "\n", omittingEmptySubsequences: false)
    #expect(lines.count == Self.rowLimit)
    #expect(lines.first.map(String.init) == Self.line(Self.longLineCount - Self.rowLimit + 1))
    #expect(lines.last.map(String.init) == Self.line(Self.longLineCount))
    #expect(model.isReadOnly)
  }

  @Test func showAllExpandsTheOutput() throws {
    let model = EditorModel("")
    let harness = HostedViewHarness(
      CommandOutputView(
        command: Self.command, output: Self.longOutput, exitCode: nil,
        rowLimit: Self.rowLimit, model: model))
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: CommandOutputView.showAllIdentifier)
    harness.pump()

    #expect(model.text == Self.longOutput)
    #expect(harness.element(identifier: CommandOutputView.capIdentifier) == nil)
    #expect(harness.element(identifier: CommandOutputView.showAllIdentifier) == nil)
  }

  @Test func shortOutputShowsNoCap() {
    let model = EditorModel("")
    let output = "one\ntwo\n"
    let harness = HostedViewHarness(
      CommandOutputView(
        command: Self.command, output: output, exitCode: nil, rowLimit: Self.rowLimit, model: model))
    defer { harness.close() }
    harness.pump()

    #expect(model.text == output)
    #expect(harness.element(identifier: CommandOutputView.capIdentifier) == nil)
    #expect(harness.element(identifier: CommandOutputView.showAllIdentifier) == nil)
  }

  @Test func theDefaultRowLimitCapsTheLongOutput() {
    let harness = HostedViewHarness(
      CommandOutputView(command: Self.command, output: Self.longOutput, exitCode: nil))
    defer { harness.close() }
    harness.pump()

    let cap = harness.element(identifier: CommandOutputView.capIdentifier)
    #expect(
      cap?.label
        == "Showing the last \(CommandOutputView.defaultRowLimit) of \(Self.longLineCount) lines")
  }

  @Test func aTrailingNewlineIsNotARow() {
    let rows = CommandOutputView.VisibleRows(output: "a\nb\nc\n", limit: Self.smallRowLimit)
    #expect(rows.totalCount == ["a", "b", "c"].count)
    #expect(rows.hiddenCount == ["a"].count)
    #expect(rows.text == "b\nc")
  }

  @Test func aLimitBelowOneShowsOneRow() {
    let rows = CommandOutputView.VisibleRows(output: "a\nb", limit: Self.zeroRowLimit)
    #expect(rows.text == "b")
    #expect(rows.hiddenCount == ["a"].count)
  }

  @Test func emptyOutputHasNoHiddenRows() {
    let rows = CommandOutputView.VisibleRows(output: "", limit: Self.smallRowLimit)
    #expect(rows.text == "")
    #expect(rows.hiddenCount == 0)
    #expect(rows.isCapped == false)
  }

  // MARK: - Copy

  @Test func copyPutsTheFullOutputOnThePasteboard() throws {
    let pasteboard = FakePasteboard()
    let harness = HostedViewHarness(
      CommandOutputView(
        command: Self.command, output: Self.longOutput, exitCode: nil, rowLimit: Self.rowLimit)
        .environment(\.pasteboard, pasteboard))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: CommandOutputView.copyIdentifier)?.label == "Copy output")
    try harness.press(identifier: CommandOutputView.copyIdentifier)

    #expect(pasteboard.copies == [Self.longOutput])
  }
}
