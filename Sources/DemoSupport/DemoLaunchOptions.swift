import Foundation

/// The launch arguments of the demo app.
///
/// - `--in-memory-agent`: the ACP tab binds ``InMemoryDemoAgent`` and starts
///   no process. The end-to-end test uses this argument.
/// - `--agent-command <path>`: the ACP tab starts this agent program. The
///   default is ``defaultAgentCommand``.
/// - `--cwd <path>`: the working directory of each session. The default is
///   the home directory.
public struct DemoLaunchOptions: Equatable, Sendable {
  /// The argument that names the agent program.
  public static let agentCommandArgument = "--agent-command"

  /// The argument that names the working directory.
  public static let cwdArgument = "--cwd"

  /// The display name of an agent that the demo app starts as a process.
  public static let processAgentName = "ACP Agent"

  /// The path of the `acp-agent` binary below the directory of the sibling
  /// checkouts.
  static let siblingAgentPath = "FoundationModelsACPAgent/.build/release/acp-agent"

  /// The `acp-agent` binary of the sibling FoundationModelsACPAgent checkout.
  ///
  /// The path goes from this source file to the directory that holds the
  /// AgentViewKit checkout, so that a local build of the demo app finds the
  /// sibling build.
  public static var defaultAgentCommand: String {
    URL(filePath: #filePath)
      .deletingLastPathComponent()  // DemoSupport
      .deletingLastPathComponent()  // Sources
      .deletingLastPathComponent()  // AgentViewKit
      .deletingLastPathComponent()  // the directory of the sibling checkouts
      .appending(path: siblingAgentPath)
      .path(percentEncoded: false)
  }

  /// Whether the ACP tab binds the in-memory agent.
  public var usesInMemoryAgent = false

  /// The agent program that the ACP tab starts.
  public var agentCommand = Self.defaultAgentCommand

  /// The working directory of each session.
  public var cwd = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)

  /// Reads the options from the arguments of a process.
  ///
  /// An argument that the demo does not know is ignored, because the system
  /// and the test runner add their own arguments. A value argument with no
  /// value keeps the default.
  ///
  /// - Parameter arguments: The arguments, with the program path first.
  public init(arguments: [String] = ProcessInfo.processInfo.arguments) {
    var remaining = arguments.dropFirst()
    while let argument = remaining.popFirst() {
      switch argument {
      case InMemoryDemoAgent.launchArgument:
        usesInMemoryAgent = true
      case Self.agentCommandArgument:
        if let value = remaining.popFirst() { agentCommand = value }
      case Self.cwdArgument:
        if let value = remaining.popFirst() { cwd = value }
      default:
        continue
      }
    }
  }

  /// The display name of the agent that the options start.
  public var agentName: String {
    usesInMemoryAgent ? InMemoryDemoAgent.name : Self.processAgentName
  }
}
