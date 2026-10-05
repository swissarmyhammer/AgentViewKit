import Foundation
import FoundationModelsACPClient

/// The terminal that a ``TerminalView`` shows: a record of the kit model, or a
/// `TerminalEntry` of a `SessionModel` (update.md §4.4, §4.7 "Terminal
/// view").
///
/// Each property reads only its own fields of the observable object, so the
/// view observes the fields that it shows.
enum TerminalSource {
  /// A terminal record of an ``AgentThread``.
  case record(TerminalRecord)

  /// A terminal entry of the transcript of a `SessionModel`.
  case entry(TerminalEntry)

  /// The command that the terminal runs, or `nil` when it is not known.
  var command: String? {
    switch self {
    case .record(let record): record.command
    case .entry(let entry): entry.command
    }
  }

  /// The working directory of the command, or `nil` when it is not known.
  var cwd: String? {
    switch self {
    case .record(let record): record.cwd
    case .entry(let entry): entry.cwd?.rawValue
    }
  }

  /// The exit status of the command, or `nil` while it runs.
  var exitSummary: TerminalView.ExitSummary? {
    switch self {
    case .record(let record):
      record.exitStatus.map(TerminalView.ExitSummary.init)
    case .entry(let entry):
      entry.exitStatus.map { TerminalView.ExitSummary(code: $0.exitCode, signal: $0.signal) }
    }
  }

  /// The output with no escape sequences.
  ///
  /// A record gives bytes, which ``ANSIText`` reads as UTF-8. An entry gives
  /// its computed `text`, which the client model decoded, so the kit does not
  /// decode it.
  var output: String {
    let attributed =
      switch self {
      case .record(let record): ANSIText.attributed(from: record.output)
      case .entry(let entry): ANSIText.attributed(from: entry.text)
      }
    return String(attributed.characters)
  }
}
