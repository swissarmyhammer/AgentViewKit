@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the host context menu of the thread header (^2sg9taf).
///
/// The host gives ``AgentThreadView`` the path of one of its own scopes, and
/// a right click on the header shows the EditorKit context menu of that path.
/// The menu leaves out each command that is not available there. With no
/// path, the header has no context menu. Each test registers the commands of
/// a host scope, `session:tab-1`, in the ambient command system of the
/// thread, as TestudoApp registers its `session:<tab id>` commands.
@Suite(.serialized, .hostedSerially) @MainActor struct ThreadHeaderContextMenuHostedTests {
  /// The size of the window.
  static let size = CGSize(width: 480, height: 600)

  /// The path of the host scope whose context menu the header shows.
  static let hostPath = FocusPath.root(FocusSegment(kind: "session", id: "tab-1"))

  /// The available command of the first group.
  static let showInFinder = HostCommand(id: "session.showInFinder", title: "Show in Finder", group: 0)

  /// The available command of the second group.
  static let openTasks = HostCommand(id: "session.openTasks", title: "Open Tasks in New Window", group: 1)

  /// The command of the second group that is not available.
  static let stop = HostCommand(id: "session.stop", title: "Stop", group: 1)

  /// The reason that ``stop`` gives for its unavailability.
  static let stopReason = "Nothing runs"

  /// One host command of the tests, with its place in the context menu.
  struct HostCommand {
    /// The id of the command.
    let id: CommandID
    /// The title of the command.
    let title: String
    /// The group of the command in the context menu.
    let group: Int

    /// The definition of the command.
    ///
    /// - Parameter make: Makes the command that the definition registers.
    /// - Returns: The definition, placed in the context menu by ``group``.
    func definition(make: @escaping @Sendable (CommandPayload?) -> any Command) -> CommandDefinition {
      CommandDefinition(
        id: id, title: .static(title), contextMenu: ContextMenuPlacement(group: group, order: 0), make: make)
    }
  }

  /// A command system with the commands of the host scope at ``hostPath``.
  ///
  /// - Parameter log: The log that gets each run of the available commands.
  /// - Returns: The system.
  static func makeSystem(log: CommandRunLog) -> CommandSystem {
    let system = CommandSystem()
    system.registry.tree = system.registry.tree.merging(nil, by: .host, at: hostPath)
    for command in [showInFinder, openTasks] {
      let id = command.id
      system.registry.register(command.definition { _ in RunRecordingCommand(id: id, log: log) }, at: hostPath)
    }
    let stop = stop
    let reason = stopReason
    system.registry.register(
      stop.definition { _ in UnavailableCommand(id: stop.id, title: stop.title, reason: reason) }, at: hostPath)
    return system
  }

  /// A code-built connection model whose agent gave its info, so that the
  /// thread shows its header.
  static var connection: ConnectionModel {
    .preview(
      initializeResponse: InitializeResponse(
        info: Implementation(name: "tests-agent", version: "1.0.0"),
        protocolVersion: ACPClient.supportedProtocolVersion))
  }

  /// Mounts a thread whose header shows the context menu of `path`, in
  /// `system`.
  ///
  /// - Parameters:
  ///   - path: The path of the host scope, or `nil` for no context menu.
  ///   - system: The ambient command system of the thread.
  /// - Returns: The harness, after one render pass.
  static func mountThread(path: FocusPath?, system: CommandSystem) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      AgentThreadView(
        session: .preview(), connection: connection, sessionTitle: "AgentViewKit", headerContextMenuPath: path
      )
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  @Test func theHeaderShowsTheContextMenuOfTheHostPath() throws {
    let harness = Self.mountThread(path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    let menu = try #require(try harness.contextMenu(identifier: AgentInfoHeader.identifier))

    #expect(menu.items.map(\.title) == [Self.showInFinder.title, "", Self.openTasks.title])
  }

  @Test func theHeaderContextMenuLeavesOutACommandThatIsNotAvailable() throws {
    let harness = Self.mountThread(path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    let menu = try #require(try harness.contextMenu(identifier: AgentInfoHeader.identifier))

    #expect(!menu.items.map(\.title).contains(Self.stop.title))
  }

  @Test func anItemOfTheHeaderContextMenuRunsItsCommandAtTheHostPath() throws {
    let log = CommandRunLog()
    let harness = Self.mountThread(path: Self.hostPath, system: Self.makeSystem(log: log))
    defer { harness.close() }
    let menu = try #require(try harness.contextMenu(identifier: AgentInfoHeader.identifier))
    let index = try #require(menu.items.firstIndex { $0.title == Self.openTasks.title })

    menu.performActionForItem(at: index)

    #expect(log.runs == [CommandRun(id: Self.openTasks.id, path: Self.hostPath)])
  }

  @Test func aHeaderWithNoPathHasNoContextMenu() throws {
    let harness = Self.mountThread(path: nil, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    #expect(try harness.contextMenu(identifier: AgentInfoHeader.identifier) == nil)
  }
}
