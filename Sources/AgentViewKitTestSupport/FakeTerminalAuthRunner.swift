import FoundationModelsACPClient
import Synchronization

/// A `TerminalAuthRunner` that records each run and starts no process.
///
/// Each run gives the exit status of the initializer. `nil` acts as a process
/// that ended with no exit status, for example a cancel of the user.
public nonisolated final class FakeTerminalAuthRunner: TerminalAuthRunner {
  /// One recorded run, with its arguments.
  public struct Run: Equatable, Sendable {
    /// The arguments to append to the agent command.
    public let arguments: [String]

    /// The variables to apply over the launch environment, keyed by name.
    public let environment: [String: String]

    /// Makes a run record.
    ///
    /// - Parameters:
    ///   - arguments: The arguments to append to the agent command.
    ///   - environment: The variables to apply over the launch environment.
    public init(arguments: [String], environment: [String: String]) {
      self.arguments = arguments
      self.environment = environment
    }
  }

  /// The exit status that each run gives.
  private let exitStatus: Int32?

  /// Each run, in run order, behind a lock.
  private let storage = Mutex<[Run]>([])

  /// Makes a runner that gives `exitStatus` for each run.
  ///
  /// - Parameter exitStatus: The exit status of each run, or `nil` for a
  ///   process that ended with no exit status.
  public init(exitStatus: Int32?) {
    self.exitStatus = exitStatus
  }

  /// Each run, in run order.
  public var runs: [Run] {
    storage.withLock { $0 }
  }

  public func runTerminalAuth(arguments: [String], environment: [String: String]) async throws -> Int32? {
    storage.withLock { $0.append(Run(arguments: arguments, environment: environment)) }
    return exitStatus
  }
}
