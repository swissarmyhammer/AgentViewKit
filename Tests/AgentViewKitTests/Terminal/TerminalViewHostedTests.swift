#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import EditorSwiftUI
  import Foundation
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Hosted tests of one ``TerminalView`` over a `TerminalEntry` of a scripted
  /// session. `SessionEntryRowsHostedTests` tests the terminal rows of the
  /// thread.
  @Suite(.serialized, .hostedSerially) @MainActor struct TerminalViewHostedTests {
    /// The command in the header.
    static let command = "npm test"
    /// The working directory in the header.
    static let cwd = "/Users/dev/project"
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
    /// The `command` and `cwd` members of a `terminal_update`.
    static let headerFields = #""command": "\#(command)", "cwd": "\#(cwd)""#

    /// The `output` member of a `terminal_update`.
    ///
    /// - Parameter data: The bytes of the output.
    /// - Returns: The JSON member.
    static func outputField(_ data: Data) -> String {
      #""output": {"data": "\#(data.base64EncodedString())"}"#
    }

    /// The `output` member of a `terminal_update` with UTF-8 text.
    ///
    /// - Parameter text: The output text.
    /// - Returns: The JSON member.
    static func outputField(_ text: String) -> String {
      outputField(Data(text.utf8))
    }

    /// The first terminal entry of a session model.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The entry, or `nil` while the model has no terminal entry.
    static func firstTerminal(in model: SessionModel) -> TerminalEntry? {
      model.transcript.lazy.compactMap { entry -> TerminalEntry? in
        if case .terminal(let terminal) = entry { terminal } else { nil }
      }.first
    }

    /// Opens a scripted session and sends one `terminal_update`.
    ///
    /// - Parameter fields: The other members of the update, as JSON members.
    /// - Returns: The session and the terminal entry.
    /// - Throws: The error of the transport, or an issue when the model holds
    ///   no terminal entry at the time limit.
    static func openTerminal(_ fields: String) async throws -> (ScriptedSession, TerminalEntry) {
      try await ScriptedSession.openWithEntry(
        update: SessionEntryRowsHostedTests.terminalUpdate(fields), lookingUp: firstTerminal(in:))
    }

    // MARK: - Header

    @Test func theHeaderShowsTheCommandAndTheWorkingDirectory() async throws {
      let (session, terminal) = try await Self.openTerminal(Self.headerFields)
      defer { session.close() }
      let harness = HostedViewHarness(TerminalView(entry: terminal))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: TerminalView.identifier)?.label == "Terminal, \(Self.command)")
      #expect(harness.element(identifier: TerminalView.commandIdentifier)?.label == Self.command)
      #expect(
        harness.element(identifier: TerminalView.cwdIdentifier)?.label
          == "Working directory \(Self.cwd)")
    }

    @Test func aTerminalWithNoCommandShowsAPlaceholderAndNoWorkingDirectory() async throws {
      let (session, terminal) = try await Self.openTerminal(Self.outputField("ok"))
      defer { session.close() }
      let harness = HostedViewHarness(TerminalView(entry: terminal))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: TerminalView.identifier)?.label == "Terminal")
      #expect(harness.element(identifier: TerminalView.commandIdentifier)?.label == "Terminal")
      #expect(harness.element(identifier: TerminalView.cwdIdentifier) == nil)
    }

    // MARK: - Output

    @Test func theEditorShowsTheOutputWithNoEscapeSequences() async throws {
      let (session, terminal) = try await Self.openTerminal(
        Self.outputField("\u{1B}[31mred\u{1B}[0m\n\u{1B}[2Kdone"))
      defer { session.close() }
      let model = EditorModel("")
      let harness = HostedViewHarness(TerminalView(entry: terminal, model: model))
      defer { harness.close() }
      harness.pump()

      #expect(model.text == "red\ndone")
      #expect(model.isReadOnly)
    }

    @Test func invalidUTF8OutputShowsReplacementCharacters() async throws {
      let (session, terminal) = try await Self.openTerminal(Self.outputField(Data([0x61, 0xC3, 0x28])))
      defer { session.close() }
      let model = EditorModel("")
      let harness = HostedViewHarness(TerminalView(entry: terminal, model: model))
      defer { harness.close() }
      harness.pump()

      #expect(model.text == "a\u{FFFD}(")
    }

    @Test func longOutputShowsTheCapAndShowAllExpandsIt() async throws {
      let lines = (1...Self.longLineCount).map { "line \($0)" }
      let (session, terminal) = try await Self.openTerminal(Self.outputField(lines.joined(separator: "\n")))
      defer { session.close() }
      let model = EditorModel("")
      let harness = HostedViewHarness(TerminalView(entry: terminal, rowLimit: Self.rowLimit, model: model))
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

    @Test func anExitReplacesTheProgressWithTheExitCode() async throws {
      let (session, terminal) = try await Self.openTerminal(Self.headerFields)
      defer { session.close() }
      let harness = HostedViewHarness(TerminalView(entry: terminal))
      defer { harness.close() }
      harness.pump()
      #expect(harness.element(identifier: TerminalView.progressIdentifier) != nil)
      #expect(harness.element(identifier: TerminalView.footerIdentifier) == nil)

      try await session.sendUpdate(
        SessionEntryRowsHostedTests.terminalUpdate(#""exitStatus": {"exitCode": \#(Self.failureExitCode)}"#))
      await harness.pump(until: Self.timeout) {
        harness.element(identifier: TerminalView.footerIdentifier) != nil
      }

      let footer = harness.element(identifier: TerminalView.footerIdentifier)
      #expect(footer?.label == "Exit code \(Self.failureExitCode)")
      #expect(footer?.value == CommandOutputView.ExitOutcome.failure.label)
      #expect(harness.element(identifier: TerminalView.progressIdentifier) == nil)
    }

    @Test func theFooterShowsTheSignal() async throws {
      let (session, terminal) = try await Self.openTerminal(#""exitStatus": {"signal": "\#(Self.signal)"}"#)
      defer { session.close() }
      let harness = HostedViewHarness(TerminalView(entry: terminal))
      defer { harness.close() }
      harness.pump()

      let footer = harness.element(identifier: TerminalView.footerIdentifier)
      #expect(footer?.label == "Stopped by \(Self.signal)")
      #expect(footer?.value == CommandOutputView.ExitOutcome.failure.label)
    }

    @Test func anExitWithNoCodeAndNoSignalShowsExited() async throws {
      let (session, terminal) = try await Self.openTerminal(#""exitStatus": {}"#)
      defer { session.close() }
      let harness = HostedViewHarness(TerminalView(entry: terminal))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: TerminalView.footerIdentifier)?.label == "Exited")
      #expect(harness.element(identifier: TerminalView.progressIdentifier) == nil)
    }

    @Test(arguments: [
      (successExitCode as Int?, nil as String?, TerminalView.ExitSummary.code(successExitCode)),
      (failureExitCode, nil, .code(failureExitCode)),
      (failureExitCode, signal, .signal(signal)),
      (nil, nil, .unknown),
    ])
    func eachExitStatusHasItsSummary(code: Int?, signal: String?, expected: TerminalView.ExitSummary) {
      #expect(TerminalView.ExitSummary(code: code, signal: signal) == expected)
    }

    @Test func theSummariesHaveTheirOutcomesAndLabels() {
      #expect(TerminalView.ExitSummary.code(Self.successExitCode).outcome == .success)
      #expect(TerminalView.ExitSummary.code(Self.failureExitCode).outcome == .failure)
      #expect(TerminalView.ExitSummary.signal(Self.signal).outcome == .failure)
      #expect(TerminalView.ExitSummary.unknown.outcome == nil)
      #expect(TerminalView.ExitSummary.unknown.label == "Exited")
    }
  }
#endif
