import Foundation
import FoundationModelsACPClient
import OSLog

/// The errors of ``AgentProcessLauncher``.
public enum AgentProcessLauncherError: Error, Equatable, Sendable {
  /// The name of an environment variable is empty or has an equal sign. The
  /// environment block of the process would read such a name wrongly.
  case invalidEnvironmentName(String)
}

/// The default ``ProcessLauncher`` of the kit (plan.md §12).
///
/// The launcher starts each process with `AgentProcess` from
/// FoundationModelsACPClient. `AgentProcess` puts the process in its own
/// process group, and stops and reaps the process on each teardown path.
///
/// The launcher starts the program itself. It gives the environment and the
/// working directory to the `environment` and `currentDirectory` parameters
/// of `AgentProcess`:
///
/// - With no launch variables, the process gets the environment of the host.
/// - With launch variables, the process gets the environment of the host
///   with the launch variables added. A launch variable replaces a host
///   variable that has the same name.
/// - The process starts in ``currentDirectory``, or in the working directory
///   of the host when it is `nil`.
///
/// ``LaunchedProcess/exitStatus`` is the `exitStatus` of `AgentProcess`. The
/// output of the process is its standard output only. The standard error
/// stream goes to the standard error stream of the host.
public final class AgentProcessLauncher: ProcessLauncher {
  /// The character between the name and the value of an environment entry.
  private static let assignment: Character = "="

  /// The working directory of each process, or `nil` for the working
  /// directory of the host.
  public let currentDirectory: String?

  /// Makes a launcher.
  ///
  /// - Parameter currentDirectory: The working directory of each process, or
  ///   `nil` for the working directory of the host. A relative path is
  ///   relative to the working directory of the host.
  public init(currentDirectory: String? = nil) {
    self.currentDirectory = currentDirectory
  }

  public func launch(program: String, arguments: [String], environment: [String: String]) throws
    -> any LaunchedProcess
  {
    let process = try AgentProcess(
      command: program,
      arguments: arguments,
      environment: try Self.processEnvironment(adding: environment),
      currentDirectory: currentDirectory
    )
    return AgentLaunchedProcess(process: process)
  }

  /// The whole environment of a process that gets the launch variables
  /// `additions`.
  ///
  /// - Parameter additions: The environment variables to add for the program.
  /// - Returns: `nil` when `additions` is empty, so that `AgentProcess` gives
  ///   the environment of the host. Otherwise, the environment of the host
  ///   with `additions` added.
  /// - Throws: ``AgentProcessLauncherError/invalidEnvironmentName(_:)`` for a
  ///   name that is empty or has an equal sign.
  private static func processEnvironment(adding additions: [String: String]) throws -> [String: String]? {
    guard !additions.isEmpty else { return nil }
    for name in additions.keys where name.isEmpty || name.contains(assignment) {
      throw AgentProcessLauncherError.invalidEnvironmentName(name)
    }
    return ProcessInfo.processInfo.environment.merging(additions) { _, addition in addition }
  }
}

/// A process that ``AgentProcessLauncher`` started.
///
/// One task copies the standard output of the agent process to ``output``.
/// One task writes the bytes of each ``write(_:)`` call to the standard input
/// in call order.
final class AgentLaunchedProcess: LaunchedProcess {
  let output: AsyncStream<Data>

  /// The `exitStatus` of the agent process. The teardown of `AgentProcess`
  /// records it before ``output`` finishes.
  var exitStatus: AgentExitStatus? { process.exitStatus }

  /// The started agent process.
  let process: AgentProcess

  /// The continuation of the queue of bytes to write.
  private let writes: AsyncStream<Data>.Continuation

  /// The task that copies the output.
  private let reader: Task<Void, Never>

  /// The task that writes the queued bytes.
  private let writer: Task<Void, Never>

  /// Whether ``terminate()`` was called.
  private var isTerminated = false

  /// The log of the process.
  nonisolated private static let logger = Logger(subsystem: "AgentViewKit", category: "AgentProcessLauncher")

  /// Starts the output and input tasks of `process`.
  ///
  /// - Parameter process: The started agent process.
  init(process: AgentProcess) {
    self.process = process
    let (output, outputContinuation) = AsyncStream.makeStream(of: Data.self)
    self.output = output
    let bytes = process.transport.bytes
    reader = Task.detached {
      do {
        for try await chunk in bytes {
          outputContinuation.yield(chunk)
        }
      } catch {
        Self.logger.error("The output of the process failed: \(String(describing: error), privacy: .public)")
      }
      outputContinuation.finish()
    }
    let (queue, writes) = AsyncStream.makeStream(of: Data.self)
    self.writes = writes
    let transport = process.transport
    writer = Task.detached {
      for await data in queue {
        do {
          try await transport.write(data)
        } catch {
          Self.logger.error("A write to the process failed: \(String(describing: error), privacy: .public)")
          return
        }
      }
    }
  }

  /// Puts `data` in the queue of bytes to write.
  ///
  /// - Parameter data: The bytes to write.
  /// - Throws: `AgentProcessError.agentUnavailable` after ``terminate()``.
  func write(_ data: Data) throws {
    guard !isTerminated else { throw AgentProcessError.agentUnavailable }
    writes.yield(data)
  }

  /// Stops and reaps the process, and ends both tasks.
  func terminate() {
    isTerminated = true
    writes.finish()
    writer.cancel()
    process.shutdown()
    reader.cancel()
  }
}
