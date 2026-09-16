import AgentViewKit
import Foundation
import Testing

@MainActor
@Suite struct TerminalRecordTests {
  @Test func aNewRecordHasNoOutputAndRevisionZero() {
    let record = TerminalRecord(id: TerminalID("t1"), command: "ls", cwd: "/tmp")

    #expect(record.id == TerminalID("t1"))
    #expect(record.command == "ls")
    #expect(record.cwd == "/tmp")
    #expect(record.output.isEmpty)
    #expect(record.exitStatus == nil)
    #expect(record.revision == 0)
  }

  @Test func appendOutputAddsTheChunkAtTheEnd() {
    let record = TerminalRecord(id: TerminalID("t1"))

    record.appendOutput(Data("ab".utf8))
    record.appendOutput(Data("cd".utf8))

    #expect(record.output == Data("abcd".utf8))
  }

  @Test func appendOutputIncrementsRevisionByOnePerCall() {
    let record = TerminalRecord(id: TerminalID("t1"))

    record.appendOutput(Data("a".utf8))
    #expect(record.revision == 1)

    record.appendOutput(Data("b".utf8))
    #expect(record.revision == 2)

    record.appendOutput(Data())
    #expect(record.revision == 3)
  }

  @Test func bumpIncrementsRevision() {
    let record = TerminalRecord(id: TerminalID("t1"))

    record.exitStatus = TerminalRecord.ExitStatus(code: 0)
    record.bump()

    #expect(record.revision == 1)
    #expect(record.exitStatus == TerminalRecord.ExitStatus(code: 0, signal: nil))
  }

  @Test func anExitStatusCanHoldASignalWithNoCode() {
    let status = TerminalRecord.ExitStatus(signal: "SIGKILL")

    #expect(status.code == nil)
    #expect(status.signal == "SIGKILL")
  }
}
