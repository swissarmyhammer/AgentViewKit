import DemoSupport
import FoundationModelsACPClient

/// The launch options of the in-memory demo agent, and the box of the
/// sessions that an operation opens.
///
/// The tests of ``DemoAgent`` and the hosted tests of the ACP window share
/// these fixtures.
public enum DemoAgentFixtures {
  /// The working directory of each test session.
  public static let workingDirectory = "/tmp/demo-agent"

  /// The launch options that start the in-memory agent in
  /// ``workingDirectory``.
  public static let inMemoryOptions = DemoLaunchOptions(arguments: [
    "app", InMemoryDemoAgent.launchArgument, DemoLaunchOptions.cwdArgument, workingDirectory,
  ])

  /// The sessions that the operation of a test opened, in open order.
  public final class OpenedSessions {
    /// The sessions, in open order.
    public var sessions: [SessionModel] = []

    /// Makes an empty box.
    public init() {}
  }
}
