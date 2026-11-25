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

/// Tests for the host context menu of the thread header (^2sg9taf) and of
/// each part of the top bar (^tsr28g).
///
/// The host gives ``AgentThreadView`` the path of one of its own scopes, and
/// a right click on the status line, on the header of the host or on a
/// banner shows the EditorKit context menu of that path. The menu leaves out
/// each command that is not available there. With no path, no part of the
/// top bar has a context menu. Each test registers the commands of
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

  /// The titles of the context menu of ``hostPath``: the available command
  /// of the first group, a separator, and the available command of the
  /// second group.
  static let menuTitles = [showInFinder.title, "", openTasks.title]

  /// The distance, in points, from the trailing edge of a part of the top
  /// bar to the point of a right click on the empty part of it.
  static let trailingClickInset: CGFloat = 4

  /// The accessibility identifier of the text of the header of the host.
  static let hostHeaderTextIdentifier = "tests.host-header-text"

  /// The header of the host, as TestudoApp shows it on a shared session.
  static var hostHeader: AnyView {
    AnyView(Text(verbatim: "Shared · Ann").accessibilityIdentifier(hostHeaderTextIdentifier))
  }

  /// A session model whose one notice shows a ``SessionNoticeBanner``.
  static var sessionWithNotice: SessionModel {
    .preview(transcript: [.update(.notice(Notice(severity: .warning, title: "Quota low")))])
  }

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
    func definition(make: @escaping @Sendable (CommandPayload?) -> any EditorCommands.Command) -> CommandDefinition {
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
    register([showInFinder, openTasks], at: hostPath, in: system, log: log)
    let stop = stop
    let reason = stopReason
    system.registry.register(
      stop.definition { _ in UnavailableCommand(id: stop.id, title: stop.title, reason: reason) }, at: hostPath)
    return system
  }

  /// Registers `commands` at `path` in `system`. Each command records its
  /// runs in `log`.
  ///
  /// - Parameters:
  ///   - commands: The host commands to register.
  ///   - path: The path of the scope that gets the commands.
  ///   - system: The command system that gets the commands.
  ///   - log: The log that gets each run of the commands.
  static func register(
    _ commands: [HostCommand], at path: FocusPath, in system: CommandSystem, log: CommandRunLog
  ) {
    for command in commands {
      let id = command.id
      let definition = command.definition { _ in RunRecordingCommand(id: id, log: log) }
      system.registry.register(definition, at: path)
    }
  }

  /// A code-built connection model whose agent gave its info, so that the
  /// thread shows its header.
  static var connection: ConnectionModel {
    .preview(
      initializeResponse: InitializeResponse(
        info: Implementation(name: "tests-agent", version: "1.0.0"),
        protocolVersion: ACPClient.supportedProtocolVersion))
  }

  /// Mounts a thread of `session` whose header shows the context menu of
  /// `path`, in `system`.
  ///
  /// - Parameters:
  ///   - session: The session model of the thread. The default has an empty
  ///     transcript.
  ///   - path: The path of the host scope, or `nil` for no context menu.
  ///   - system: The ambient command system of the thread.
  ///   - header: The header of the host (``SwiftUI/View/threadHeader(_:)``),
  ///     or `nil` for no header.
  ///   - cache: The cache of the models of the answers, or `nil` for a
  ///     model in the state of each answer. A test that waits for the parse
  ///     of the model of an answer gives a cache.
  /// - Returns: The harness, after one render pass.
  static func mountThread(
    _ session: SessionModel = .preview(), path: FocusPath?, system: CommandSystem,
    header: AnyView? = nil, cache: CodeBlockModelCache? = nil
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      AgentThreadView(
        session: session, connection: connection, sessionTitle: "AgentViewKit", headerContextMenuPath: path
      )
      .environment(\.codeBlockModelCache, cache)
      .environment(\.threadHeader, header)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  @Test func theHeaderShowsTheContextMenuOfTheHostPath() throws {
    let harness = Self.mountThread(path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    let menu = try #require(try harness.contextMenu(identifier: StatusLineView.identifier))

    #expect(menu.items.map(\.title) == Self.menuTitles)
  }

  @Test func theEmptyPartOfTheHeaderShowsTheContextMenuOfTheHostPath() throws {
    let harness = Self.mountThread(path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }
    let line = try #require(harness.frame(identifier: StatusLineView.identifier))
    // A point near the trailing edge of the line, after the end of its text.
    let point = harness.window.convertPoint(fromScreen: NSPoint(x: line.maxX - Self.trailingClickInset, y: line.midY))

    let menu = try #require(try harness.contextMenu(at: point))

    #expect(menu.items.map(\.title) == Self.menuTitles)
  }

  @Test func theHeaderContextMenuLeavesOutACommandThatIsNotAvailable() throws {
    let harness = Self.mountThread(path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    let menu = try #require(try harness.contextMenu(identifier: StatusLineView.identifier))

    #expect(!menu.items.map(\.title).contains(Self.stop.title))
  }

  @Test func anItemOfTheHeaderContextMenuRunsItsCommandAtTheHostPath() throws {
    let log = CommandRunLog()
    let harness = Self.mountThread(path: Self.hostPath, system: Self.makeSystem(log: log))
    defer { harness.close() }
    let menu = try #require(try harness.contextMenu(identifier: StatusLineView.identifier))
    let index = try #require(menu.items.firstIndex { $0.title == Self.openTasks.title })

    menu.performActionForItem(at: index)

    #expect(log.runs == [CommandRun(id: Self.openTasks.id, path: Self.hostPath)])
  }

  @Test func aHeaderWithNoPathHasNoContextMenu() throws {
    let harness = Self.mountThread(path: nil, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    #expect(try harness.contextMenu(identifier: StatusLineView.identifier) == nil)
  }

  @Test func theHostHeaderShowsTheContextMenuOfTheHostPath() throws {
    let harness = Self.mountThread(
      path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()), header: Self.hostHeader)
    defer { harness.close() }

    let menu = try #require(try harness.contextMenu(identifier: Self.hostHeaderTextIdentifier))

    #expect(menu.items.map(\.title) == Self.menuTitles)
  }

  @Test func theEmptyPartOfTheHostHeaderShowsTheContextMenuOfTheHostPath() throws {
    let harness = Self.mountThread(
      path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()), header: Self.hostHeader)
    defer { harness.close() }
    let slot = try #require(harness.frame(identifier: AgentThreadLayout.headerIdentifier))
    // A point near the trailing edge of the header, after the end of its text.
    let point = harness.window.convertPoint(fromScreen: NSPoint(x: slot.maxX - Self.trailingClickInset, y: slot.midY))

    let menu = try #require(try harness.contextMenu(at: point))

    #expect(menu.items.map(\.title) == Self.menuTitles)
  }

  @Test func aNoticeBannerShowsTheContextMenuOfTheHostPath() throws {
    let session = Self.sessionWithNotice
    let notice = try #require(session.notices.first)
    let harness = Self.mountThread(session, path: Self.hostPath, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    let menu = try #require(try harness.contextMenu(identifier: SessionNoticeBanner.identifier(for: notice.id)))

    #expect(menu.items.map(\.title) == Self.menuTitles)
  }

  @Test func aHostHeaderWithNoPathHasNoContextMenu() throws {
    let harness = Self.mountThread(
      path: nil, system: Self.makeSystem(log: CommandRunLog()), header: Self.hostHeader)
    defer { harness.close() }

    #expect(try harness.contextMenu(identifier: Self.hostHeaderTextIdentifier) == nil)
  }

  @Test func aNoticeBannerWithNoPathHasNoContextMenu() throws {
    let session = Self.sessionWithNotice
    let notice = try #require(session.notices.first)
    let harness = Self.mountThread(session, path: nil, system: Self.makeSystem(log: CommandRunLog()))
    defer { harness.close() }

    #expect(try harness.contextMenu(identifier: SessionNoticeBanner.identifier(for: notice.id)) == nil)
  }
}
