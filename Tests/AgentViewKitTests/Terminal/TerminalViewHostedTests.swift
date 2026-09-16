import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorSwiftUI
import Foundation
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct TerminalViewHostedTests {
  /// The command in the header.
  static let command = "npm test"
  /// The working directory in the header.
  static let cwd = "/Users/dev/project"
  /// The identifier of the terminal record.
  static let terminalID = TerminalID("t1")
  /// The exit code of a command that failed.
  nonisolated static let failureExitCode = 2
  /// The exit code of a command that completed.
  nonisolated static let successExitCode = 0
  /// The signal that stopped a command.
  nonisolated static let signal = "SIGTERM"
  /// The row limit of the capped view in the tests.
  static let rowLimit = 3
  /// The number of lines in the long output.
  static let longLineCount = 10
  /// The longest time that a test waits for a view update, in seconds.
  static let timeout: TimeInterval = 5
  /// The line that the stdin test types.
  static let inputLine = "yes"

  /// Makes a terminal record.
  ///
  /// - Parameters:
  ///   - output: The output text.
  ///   - exitStatus: The exit status, or `nil` while the command runs.
  ///   - command: The command.
  ///   - cwd: The working directory.
  /// - Returns: The record.
  static func record(
    output: String = "",
    exitStatus: TerminalRecord.ExitStatus? = nil,
    command: String? = command,
    cwd: String? = cwd
  ) -> TerminalRecord {
    TerminalRecord(
      id: terminalID, command: command, cwd: cwd, exitStatus: exitStatus,
      output: Data(output.utf8))
  }

  // MARK: - Header

  @Test func theHeaderShowsTheCommandAndTheWorkingDirectory() {
    let harness = HostedViewHarness(TerminalView(record: Self.record(output: "ok")))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.identifier)?.label == "Terminal, \(Self.command)")
    #expect(harness.element(identifier: TerminalView.commandIdentifier)?.label == Self.command)
    #expect(
      harness.element(identifier: TerminalView.cwdIdentifier)?.label
        == "Working directory \(Self.cwd)")
  }

  @Test func aRecordWithNoCommandShowsAPlaceholderAndNoWorkingDirectory() {
    let harness = HostedViewHarness(
      TerminalView(record: Self.record(output: "ok", command: nil, cwd: nil)))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.identifier)?.label == "Terminal")
    #expect(harness.element(identifier: TerminalView.commandIdentifier)?.label == "Terminal")
    #expect(harness.element(identifier: TerminalView.cwdIdentifier) == nil)
  }

  // MARK: - Output

  @Test func theEditorShowsTheOutputWithNoEscapeSequences() {
    let model = EditorModel("")
    let record = Self.record(output: "\u{1B}[31mred\u{1B}[0m\n\u{1B}[2Kdone")
    let harness = HostedViewHarness(TerminalView(record: record, model: model))
    defer { harness.close() }
    harness.pump()

    #expect(model.text == "red\ndone")
    #expect(model.isReadOnly)
  }

  @Test func aNewChunkUpdatesTheEditor() async {
    let model = EditorModel("")
    let record = Self.record(output: "one\n")
    let harness = HostedViewHarness(TerminalView(record: record, model: model))
    defer { harness.close() }
    harness.pump()

    record.appendOutput(Data("two\n".utf8))
    await harness.pump(until: Self.timeout) { model.text == "one\ntwo\n" }

    #expect(model.text == "one\ntwo\n")
  }

  @Test func invalidUTF8OutputShowsReplacementCharacters() {
    let model = EditorModel("")
    var output = Data("a".utf8)
    output.append(contentsOf: [0xC3, 0x28])
    let record = TerminalRecord(id: Self.terminalID, output: output)
    let harness = HostedViewHarness(TerminalView(record: record, model: model))
    defer { harness.close() }
    harness.pump()

    #expect(model.text == "a\u{FFFD}(")
  }

  @Test func longOutputShowsTheCapAndShowAllExpandsIt() throws {
    let model = EditorModel("")
    let lines = (1...Self.longLineCount).map { "line \($0)" }
    let record = Self.record(output: lines.joined(separator: "\n"))
    let harness = HostedViewHarness(
      TerminalView(record: record, rowLimit: Self.rowLimit, model: model))
    defer { harness.close() }
    harness.pump()

    #expect(
      harness.element(identifier: TerminalView.capIdentifier)?.label
        == "Showing the last \(Self.rowLimit) of \(Self.longLineCount) lines")
    #expect(model.text == lines.suffix(Self.rowLimit).joined(separator: "\n"))

    try harness.press(identifier: TerminalView.showAllIdentifier)
    harness.pump()

    #expect(model.text == lines.joined(separator: "\n"))
    #expect(harness.element(identifier: TerminalView.capIdentifier) == nil)
  }

  // MARK: - Footer

  @Test func aRunningTerminalShowsProgressAndNoExitStatus() {
    let harness = HostedViewHarness(TerminalView(record: Self.record()))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.progressIdentifier) != nil)
    #expect(harness.element(identifier: TerminalView.footerIdentifier) == nil)
  }

  @Test func anExitReplacesTheProgressWithTheExitCode() async {
    let record = Self.record()
    let harness = HostedViewHarness(TerminalView(record: record))
    defer { harness.close() }
    harness.pump()

    record.exitStatus = TerminalRecord.ExitStatus(code: Self.failureExitCode)
    record.bump()
    await harness.pump(until: Self.timeout) {
      harness.element(identifier: TerminalView.footerIdentifier) != nil
    }

    let footer = harness.element(identifier: TerminalView.footerIdentifier)
    #expect(footer?.label == "Exit code \(Self.failureExitCode)")
    #expect(footer?.value == CommandOutputView.ExitOutcome.failure.label)
    #expect(harness.element(identifier: TerminalView.progressIdentifier) == nil)
  }

  @Test func theFooterShowsASuccessCode() {
    let record = Self.record(exitStatus: TerminalRecord.ExitStatus(code: Self.successExitCode))
    let harness = HostedViewHarness(TerminalView(record: record))
    defer { harness.close() }
    harness.pump()

    let footer = harness.element(identifier: TerminalView.footerIdentifier)
    #expect(footer?.label == "Exit code \(Self.successExitCode)")
    #expect(footer?.value == CommandOutputView.ExitOutcome.success.label)
  }

  @Test func theFooterShowsTheSignal() {
    let record = Self.record(exitStatus: TerminalRecord.ExitStatus(signal: Self.signal))
    let harness = HostedViewHarness(TerminalView(record: record))
    defer { harness.close() }
    harness.pump()

    let footer = harness.element(identifier: TerminalView.footerIdentifier)
    #expect(footer?.label == "Stopped by \(Self.signal)")
    #expect(footer?.value == CommandOutputView.ExitOutcome.failure.label)
  }

  @Test(arguments: [
    (
      TerminalRecord.ExitStatus(code: successExitCode),
      TerminalView.ExitSummary.code(successExitCode)
    ),
    (TerminalRecord.ExitStatus(code: failureExitCode), .code(failureExitCode)),
    (TerminalRecord.ExitStatus(code: failureExitCode, signal: signal), .signal(signal)),
    (TerminalRecord.ExitStatus(), .unknown),
  ])
  func eachExitStatusHasItsSummary(
    status: TerminalRecord.ExitStatus, expected: TerminalView.ExitSummary
  ) {
    #expect(TerminalView.ExitSummary(status) == expected)
  }

  @Test func theSummariesHaveTheirOutcomesAndLabels() {
    #expect(TerminalView.ExitSummary.code(Self.successExitCode).outcome == .success)
    #expect(TerminalView.ExitSummary.code(Self.failureExitCode).outcome == .failure)
    #expect(TerminalView.ExitSummary.signal(Self.signal).outcome == .failure)
    #expect(TerminalView.ExitSummary.unknown.outcome == nil)
    #expect(TerminalView.ExitSummary.unknown.label == "Exited")
  }

  @Test func anExitWithNoCodeAndNoSignalShowsExited() {
    let record = Self.record(exitStatus: TerminalRecord.ExitStatus())
    let harness = HostedViewHarness(TerminalView(record: record))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.footerIdentifier)?.label == "Exited")
    #expect(harness.element(identifier: TerminalView.progressIdentifier) == nil)
  }

  // MARK: - Input

  @Test func noStdinShowsNoInputField() {
    let harness = HostedViewHarness(TerminalView(record: Self.record()))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.inputIdentifier) == nil)
  }

  @Test func typingAndReturnSendTheLineToStdin() async throws {
    var lines: [String] = []
    let harness = HostedViewHarness(
      TerminalView(record: Self.record(), stdin: { lines.append($0) }))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.inputIdentifier) != nil)
    try #require(harness.focusFirstEditableTextView(of: NSTextField.self))

    harness.type(Self.inputLine)
    try harness.sendKey(.return)
    await harness.pump(until: Self.timeout) { !lines.isEmpty }

    #expect(lines == [Self.inputLine])
    // An empty field can have no accessibility value.
    let input = try #require(harness.element(identifier: TerminalView.inputIdentifier))
    #expect((input.value ?? "").isEmpty)
  }

  @Test func theInputFieldIsDisabledAfterTheExit() {
    let record = Self.record(exitStatus: TerminalRecord.ExitStatus(code: Self.successExitCode))
    let harness = HostedViewHarness(TerminalView(record: record, stdin: { _ in }))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.inputIdentifier)?.isEnabled == false)
  }
}
