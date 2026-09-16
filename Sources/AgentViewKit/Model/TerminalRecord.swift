import Foundation
import Observation

/// The identifier of a ``TerminalRecord`` in a thread (plan.md §3.2).
///
/// `AgentThread.terminals` is keyed by this type. For ACP, this is the
/// `terminalId`. A ``ToolContent/terminal(id:)`` block holds the same string.
public typealias TerminalID = Identifier<TerminalRecord>

/// A terminal that the agent owns, and its output (plan.md §3.2).
///
/// The fields follow the ACP v2 `TerminalUpdate`. A terminal is not a
/// ``ThreadItem``: a tool call refers to it by its ``TerminalID``. So the
/// record does not conform to ``ThreadRecord``, but it uses the same
/// revision rule. A patch changes the record in place and calls ``bump()``.
@Observable
public final class TerminalRecord: Identifiable {
  /// The identifier of the terminal. For ACP, this is the `terminalId`.
  public nonisolated let id: TerminalID

  /// The number of patches on the record. Call ``bump()`` to change it.
  ///
  /// A new record has revision zero.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The command that the terminal runs, if the source gave it.
  public var command: String?

  /// The absolute working directory of the command, if the source gave it.
  public var cwd: String?

  /// The exit information, or `nil` while the command runs.
  ///
  /// A value marks the terminal as exited, also when the value has no code
  /// and no signal.
  public var exitStatus: ExitStatus?

  /// The output bytes of the terminal, in order.
  public var output: Data

  /// Makes a terminal record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the terminal.
  ///   - command: The command that the terminal runs.
  ///   - cwd: The absolute working directory of the command.
  ///   - exitStatus: The exit information, or `nil` while the command runs.
  ///   - output: The output bytes of the terminal.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: TerminalID,
    command: String? = nil,
    cwd: String? = nil,
    exitStatus: ExitStatus? = nil,
    output: Data = Data(),
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.command = command
    self.cwd = cwd
    self.exitStatus = exitStatus
    self.output = output
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  ///
  /// Call this function after each patch on the record.
  public func bump() {
    revision += 1
  }

  /// Adds a chunk of bytes at the end of ``output`` and calls ``bump()``.
  ///
  /// - Parameter chunk: The bytes to add. An empty chunk also calls
  ///   ``bump()``.
  public func appendOutput(_ chunk: Data) {
    output.append(chunk)
    bump()
  }

  /// The exit information of a terminal.
  ///
  /// The fields follow the ACP v2 `TerminalExitStatus`.
  public nonisolated struct ExitStatus: Sendable, Hashable {
    /// The exit code of the process, if it is known.
    public var code: Int?

    /// The name of the signal that stopped the process, such as `SIGTERM`,
    /// if it is known.
    public var signal: String?

    /// Makes an exit status.
    ///
    /// - Parameters:
    ///   - code: The exit code of the process, if it is known.
    ///   - signal: The name of the signal that stopped the process, if it
    ///     is known.
    public init(code: Int? = nil, signal: String? = nil) {
      self.code = code
      self.signal = signal
    }
  }
}

extension TerminalRecord {
  /// The text before the method id in the id of a terminal auth record.
  public nonisolated static let authIDPrefix = "auth-"

  /// The id of the record that shows the terminal auth process of a method
  /// (plan.md §12).
  ///
  /// A source that runs `AgentThreadActions.runTerminalAuth(_:)` writes the
  /// output of the process to the record with this id. `AgentAuthView` finds
  /// the record with the same id.
  ///
  /// - Parameter methodID: The identifier of the terminal method.
  /// - Returns: `auth-<methodID>`.
  public nonisolated static func authID(for methodID: AuthMethodID) -> TerminalID {
    TerminalID(authIDPrefix + methodID.rawValue)
  }
}
