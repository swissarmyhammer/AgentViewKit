import Foundation

/// The tabs of the demo window.
public enum DemoTab: Sendable, Hashable, CaseIterable {
  /// The tab of the ACP agent.
  case acp

  /// The tab of the FoundationModels session.
  case foundationModels
}

/// The launch arguments of the demo app.
///
/// - `--in-memory-agent`: the ACP tab binds ``InMemoryDemoAgent`` and starts
///   no process. The end-to-end test uses this argument.
/// - `--agent-command <path>`: the ACP tab starts this agent program. The
///   default is ``defaultAgentCommand``.
/// - `--cwd <path>`: the working directory of each session. The default is
///   the home directory.
/// - `--fake-language-model`: the FoundationModels tab binds
///   ``FakeLanguageModel``, and the app opens on that tab. The end-to-end
///   test uses this argument, so that it runs on a machine without the
///   system model.
/// - `--force-model-unavailable`: the FoundationModels tab shows the model
///   as not available, and the app opens on that tab. The end-to-end test
///   uses this argument.
public struct DemoLaunchOptions: Equatable, Sendable {
  /// The language model of the FoundationModels tab.
  public enum LanguageModelChoice: Sendable, Hashable {
    /// `SystemLanguageModel.default`, when it is available.
    case system

    /// ``FakeLanguageModel`` with the scripted reply of
    /// ``FoundationModelsDemoSession``.
    case fake

    /// No model. The tab shows the model as not available.
    case forcedUnavailable
  }

  /// The argument that names the agent program.
  public static let agentCommandArgument = "--agent-command"

  /// The argument that names the working directory.
  public static let cwdArgument = "--cwd"

  /// The argument that binds the fake language model.
  public static let fakeLanguageModelArgument = "--fake-language-model"

  /// The argument that makes the language model unavailable.
  public static let forceModelUnavailableArgument = "--force-model-unavailable"

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

  /// The language model of the FoundationModels tab.
  public var languageModel = LanguageModelChoice.system

  /// Reads the options from the arguments of a process.
  ///
  /// An argument that the demo does not know is ignored, because the system
  /// and the test runner add their own arguments. A value argument with no
  /// value keeps the default. Of the two language model arguments, the last
  /// one wins.
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
      case Self.fakeLanguageModelArgument:
        languageModel = .fake
      case Self.forceModelUnavailableArgument:
        languageModel = .forcedUnavailable
      default:
        continue
      }
    }
  }

  /// The display name of the agent that the options start.
  public var agentName: String {
    usesInMemoryAgent ? InMemoryDemoAgent.name : Self.processAgentName
  }

  /// The tab that the app opens on: the FoundationModels tab when an
  /// argument of that tab is present, or the ACP tab.
  public var initialTab: DemoTab {
    languageModel == .system ? .acp : .foundationModels
  }
}
