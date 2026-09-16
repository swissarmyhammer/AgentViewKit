import AgentViewKit
import Foundation
import FoundationModelsACPClient
import OSLog

/// The errors of ``AgentProcessLauncher``.
public enum AgentProcessLauncherError: Error, Equatable, Sendable {
  /// The name of an environment variable is empty or has an equal sign.
  case invalidEnvironmentName(String)

  /// The program path has an equal sign. `env` reads such a path as a
  /// variable, so the launcher cannot give an environment to the program.
  case programPathHasEqualSign(String)
}

/// The default ``ProcessLauncher`` of the ACP adapter (plan.md §12).
///
/// The launcher starts each process with `AgentProcess` from
/// FoundationModelsACPClient. `AgentProcess` puts the process in its own
/// process group, and stops and reaps the process on each teardown path.
///
/// `AgentProcess` gives the environment of the host to the process and has
/// no environment parameter. When the launch has environment variables, the
/// launcher starts ``environmentProgram`` with each `NAME=value` pair and then
/// the program and its arguments.
///
/// Limits of `AgentProcess`:
///
/// - The output of the process is its standard output only. The standard
///   error stream goes to the standard error stream of the host.
/// - `AgentProcess` does not keep the exit status when it reaps the process,
///   so ``LaunchedProcess/exitStatus`` is always `nil`.
public final class AgentProcessLauncher: ProcessLauncher {
  /// The program that sets the environment variables of a launch.
  public static let environmentProgram = "/usr/bin/env"

  /// The character between the name and the value of an `env` argument.
  private static let assignment: Character = "="

  /// Makes a launcher.
  public init() {}

  public func launch(program: String, arguments: [String], environment: [String: String]) throws
    -> any LaunchedProcess
  {
    let command = try Self.command(program: program, arguments: arguments, environment: environment)
    let process = try AgentProcess(command: command.program, arguments: command.arguments)
    return AgentLaunchedProcess(process: process)
  }

  /// The program and the arguments that start `program` with `environment`.
  ///
  /// - Parameters:
  ///   - program: The absolute path of the executable.
  ///   - arguments: The arguments to give to the program.
  ///   - environment: The environment variables to add for the program.
  /// - Returns: `program` and `arguments` when `environment` is empty.
  ///   Otherwise, ``environmentProgram`` with the sorted `NAME=value` pairs,
  ///   then `program`, then `arguments`.
  /// - Throws: ``AgentProcessLauncherError`` when `env` cannot read the
  ///   names or the program path.
  static func command(program: String, arguments: [String], environment: [String: String]) throws
    -> (program: String, arguments: [String])
  {
    guard !environment.isEmpty else { return (program, arguments) }
    guard !program.contains(assignment) else {
      throw AgentProcessLauncherError.programPathHasEqualSign(program)
    }
    let pairs = try environment.sorted { $0.key < $1.key }.map { name, value in
      guard !name.isEmpty, !name.contains(assignment) else {
        throw AgentProcessLauncherError.invalidEnvironmentName(name)
      }
      return "\(name)\(assignment)\(value)"
    }
    return (environmentProgram, pairs + [program] + arguments)
  }
}

/// A process that ``AgentProcessLauncher`` started.
///
/// One task copies the standard output of the agent process to ``output``.
/// One task writes the bytes of each ``write(_:)`` call to the standard input
/// in call order.
final class AgentLaunchedProcess: LaunchedProcess {
  let output: AsyncStream<Data>

  /// Always `nil`: `AgentProcess` does not keep the exit status.
  var exitStatus: Int32? { nil }

  /// The started agent process.
  private let process: AgentProcess

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
