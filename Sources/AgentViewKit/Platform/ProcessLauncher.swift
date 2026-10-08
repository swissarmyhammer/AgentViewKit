import Foundation
import FoundationModelsACPClient

/// A process that a ``ProcessLauncher`` started.
///
/// Terminal authentication (plan.md §12) runs the agent program with the
/// arguments and the environment of an auth method.
public protocol LaunchedProcess: AnyObject {
  /// The output of the process, one chunk at a time. The stream finishes
  /// when the process closes its output.
  var output: AsyncStream<Data> { get }

  /// How the process ended, or `nil` while the process runs. The value is
  /// the `AgentExitStatus` of FoundationModelsACPClient, with no kit copy.
  var exitStatus: AgentExitStatus? { get }

  /// Writes `data` to the standard input of the process.
  ///
  /// - Parameter data: The bytes to write.
  /// - Throws: An error when the process cannot accept input.
  func write(_ data: Data) throws

  /// Stops the process.
  func terminate()
}

/// The object that starts a process for terminal authentication.
///
/// The protocol has no ACP wire type. The kit supplies the default launcher,
/// ``AgentProcessLauncher``, which wraps `AgentProcess` from
/// FoundationModelsACPClient. A test gives a recording fake.
public protocol ProcessLauncher: AnyObject {
  /// Starts `program` with `arguments` and `environment`.
  ///
  /// - Parameters:
  ///   - program: The absolute path of the executable.
  ///   - arguments: The arguments to give to the program.
  ///   - environment: The environment variables to add for the program.
  /// - Returns: The started process.
  /// - Throws: An error when the process cannot start.
  func launch(program: String, arguments: [String], environment: [String: String]) throws
    -> any LaunchedProcess
}
