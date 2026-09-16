import AgentViewKit
import Foundation

/// A ``ProcessLauncher`` that starts no process.
///
/// Each launch gives a ``ScriptedProcess`` that sends the scripted output
/// chunks. The process then finishes its output, unless
/// ``keepsOutputOpen`` is `true`. The launcher and each process write to one call
/// list, so a test can read the full order of calls.
public final class FakeProcessLauncher: ProcessLauncher {
  /// The error that ``launch(program:arguments:environment:)`` throws when
  /// ``launchError`` is set.
  public struct LaunchError: Error, Equatable, Sendable {
    /// A description of the failure.
    public let message: String

    /// Makes a launch error.
    ///
    /// - Parameter message: A description of the failure.
    public init(message: String) {
      self.message = message
    }
  }

  /// The error that ``ScriptedProcess/write(_:)`` throws after the process
  /// stopped.
  public struct ProcessStoppedError: Error, Equatable, Sendable {
    /// Makes the error.
    public init() {}
  }

  /// One recorded call.
  public enum Call: Equatable, Sendable {
    /// A launch, with its program, arguments, and environment.
    case launch(program: String, arguments: [String], environment: [String: String])
    /// A write to a process.
    case write(Data)
    /// A stop of a process.
    case terminate
  }

  /// The output chunks that each later launch sends.
  public var scriptedOutput: [Data]

  /// The exit status of each later process.
  public var scriptedExitStatus: Int32

  /// The error that each later launch throws, or `nil` to launch.
  public var launchError: LaunchError?

  /// Whether the output of each later process stays open after the scripted
  /// chunks. When it is `true`, the output finishes only at
  /// ``ScriptedProcess/finishOutput()`` or ``ScriptedProcess/terminate()``.
  /// A test uses it to write to a process that runs.
  public var keepsOutputOpen: Bool

  /// Each call, in call order.
  public private(set) var calls: [Call] = []

  /// Each process that the launcher gave, in launch order.
  public private(set) var processes: [ScriptedProcess] = []

  /// Makes a launcher.
  ///
  /// - Parameters:
  ///   - scriptedOutput: The output chunks of each process.
  ///   - scriptedExitStatus: The exit status of each process.
  ///   - keepsOutputOpen: Whether the output of each process stays open
  ///     after the scripted chunks.
  public init(scriptedOutput: [Data] = [], scriptedExitStatus: Int32 = 0, keepsOutputOpen: Bool = false) {
    self.scriptedOutput = scriptedOutput
    self.scriptedExitStatus = scriptedExitStatus
    self.keepsOutputOpen = keepsOutputOpen
  }

  /// Records the launch, then gives a process with the scripted output.
  ///
  /// - Parameters:
  ///   - program: The path of the executable.
  ///   - arguments: The arguments.
  ///   - environment: The environment variables.
  /// - Returns: A ``ScriptedProcess``.
  /// - Throws: ``launchError`` when it is set.
  public func launch(program: String, arguments: [String], environment: [String: String]) throws
    -> any LaunchedProcess
  {
    calls.append(.launch(program: program, arguments: arguments, environment: environment))
    if let launchError { throw launchError }
    let process = ScriptedProcess(
      launcher: self, output: scriptedOutput, exitStatus: scriptedExitStatus,
      keepsOutputOpen: keepsOutputOpen)
    processes.append(process)
    return process
  }

  /// Removes each recorded call and process.
  public func reset() {
    calls.removeAll()
    processes.removeAll()
  }

  /// Adds `call` to the call list.
  ///
  /// - Parameter call: The call to record.
  fileprivate func record(_ call: Call) {
    calls.append(call)
  }

  /// A process that ``FakeProcessLauncher`` gave.
  public final class ScriptedProcess: LaunchedProcess {
    /// The launcher that records the calls of the process.
    private weak var launcher: FakeProcessLauncher?

    /// The continuation of ``output``.
    private let continuation: AsyncStream<Data>.Continuation

    public let output: AsyncStream<Data>

    /// The scripted exit status. The status is set from the start, also
    /// while the output stays open.
    public let exitStatus: Int32?

    /// The bytes of each write, in call order.
    public private(set) var writes: [Data] = []

    /// Whether ``terminate()`` was called.
    public private(set) var isTerminated = false

    /// Makes a process that already buffered all of its scripted output.
    ///
    /// - Parameters:
    ///   - launcher: The launcher that records the calls.
    ///   - output: The output chunks.
    ///   - exitStatus: The exit status.
    ///   - keepsOutputOpen: Whether the output stays open after the chunks.
    fileprivate init(
      launcher: FakeProcessLauncher, output chunks: [Data], exitStatus: Int32, keepsOutputOpen: Bool
    ) {
      self.launcher = launcher
      (output, continuation) = AsyncStream.makeStream(of: Data.self)
      for chunk in chunks {
        continuation.yield(chunk)
      }
      if !keepsOutputOpen {
        continuation.finish()
      }
      self.exitStatus = exitStatus
    }

    /// Finishes the output, as a process does when it closes its output.
    /// This call records no call on the launcher.
    public func finishOutput() {
      continuation.finish()
    }

    /// Records `data`.
    ///
    /// - Parameter data: The bytes to write.
    /// - Throws: ``ProcessStoppedError`` after ``terminate()``.
    public func write(_ data: Data) throws {
      launcher?.record(.write(data))
      guard !isTerminated else { throw ProcessStoppedError() }
      writes.append(data)
    }

    /// Records the stop and finishes the output.
    public func terminate() {
      launcher?.record(.terminate)
      isTerminated = true
      continuation.finish()
    }
  }
}
