import Foundation
import FoundationModelsACPAgent

/// The tabs of the demo window. The raw value is the name that the `--tab`
/// launch argument gives.
public enum DemoTab: String, Sendable, Hashable, CaseIterable {
  /// The tab of the ACP agent.
  case acp

  /// The tab that shows the recorded sessions of FoundationModelsACPAgent.
  case gallery
}

/// The agent that the ACP tab of the demo app runs in the app process.
public enum DemoACPAgent: Equatable, Sendable {
  /// ``InMemoryDemoACPAgent`` with the ``InMemoryDemoScript/standard``
  /// script. The UI tests use this agent.
  case inMemory

  /// FoundationModelsACPAgent through the package, with the model of the
  /// model source. The app uses `.live`, the real model. The tests use
  /// `.stub`, so that no model downloads or loads.
  case foundationModels(ComposedAgent.ModelSource)
}

/// The launch arguments of the demo app.
///
/// - `--in-memory-agent`: the ACP tab runs ``InMemoryDemoACPAgent`` in the
///   app process (``DemoAgent``). The UI tests use this argument. Without it,
///   the ACP tab runs FoundationModelsACPAgent with the live model in the app
///   process.
/// - `--cwd <path>`: the working directory of each session of the ACP tab.
///   The default is the home directory.
/// - `--tab <name>`: the tab that the window opens on, by the raw value of
///   ``DemoTab``. The default is the ACP tab. An unknown name keeps the
///   default.
/// - `--primary-screen`: the window opens on the primary screen, the one
///   whose frame origin is (0, 0), in place of the screen that the user is
///   working on (``DemoWindowLayout/primaryScreenFrame(visibleFrame:)``).
///   This is a test-environment switch. XCTest's hit test fails for a window
///   on a screen that lies above or left of the primary screen, where the
///   global coordinates are negative. The UI tests use this argument.
///
/// The demo app starts no agent program. Each tab runs its agent in the app
/// process through ``DemoAgent/makeInProcess(options:environment:)`` or
/// ``DemoAgent/makeInProcess(recordedSessions:)``. The Gallery tab reads no
/// launch argument other than `--tab`.
public struct DemoLaunchOptions: Equatable, Sendable {
  /// The argument that names the working directory.
  public static let cwdArgument = "--cwd"

  /// The argument that names the tab that the window opens on.
  public static let tabArgument = "--tab"

  /// The argument that opens the window on the primary screen.
  public static let primaryScreenArgument = "--primary-screen"

  /// The display name of FoundationModelsACPAgent: the name that the agent
  /// gives in its `initialize` answer.
  public static let foundationModelsAgentName = RoutedACPAgent.implementation.name

  /// The agent that the ACP tab runs.
  public var acpAgent = DemoACPAgent.foundationModels(.live)

  /// The working directory of each session.
  public var cwd = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)

  /// The tab that the window opens on.
  public var initialTab = DemoTab.acp

  /// Whether the window opens on the primary screen, in place of the screen
  /// that the user is working on.
  public var opensOnPrimaryScreen = false

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
        acpAgent = .inMemory
      case Self.primaryScreenArgument:
        opensOnPrimaryScreen = true
      case Self.cwdArgument:
        if let value = remaining.popFirst() { cwd = value }
      case Self.tabArgument:
        if let tab = remaining.popFirst().flatMap(DemoTab.init(rawValue:)) { initialTab = tab }
      default:
        continue
      }
    }
  }

  /// The display name of the agent that the ACP tab runs.
  public var agentName: String {
    switch acpAgent {
    case .inMemory: InMemoryDemoAgent.name
    case .foundationModels: Self.foundationModelsAgentName
    }
  }
}
