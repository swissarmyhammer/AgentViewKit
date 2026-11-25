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

@testable import AgentViewKit

/// Tests for the host context menu of the thread header (^2sg9taf), of
/// each part of the top bar (^tsr28g) and of the gaps between the parts
/// (^z7r9tk).
///
/// The host gives ``AgentThreadView`` the path of one of its own scopes, and
/// a right click on the status line, on the header of the host, on a banner
/// or in the gap between two parts shows the EditorKit context menu of that
/// path. The menu leaves out each command that is not available there. With
/// no path, the top bar has no context menu, and a gap between two parts
/// takes no click. Each test registers the commands of
/// a host scope, `session:tab-1`, in the ambient command system of the
/// thread, as TestudoApp registers its `session:<tab id>` commands.
@Suite(.serialized, .hostedSerially) @MainActor struct ThreadHeaderContextMenuHostedTests {
  /// The size of the window.
  static let size = CGSize(width: 480, height: 600)

  /// The path of the host scope whose context menu the header shows.
  static let hostPath = FocusPath.root(FocusSegment(kind: "session", id: "tab-1"))

  /// The available command of the first group.
  static let showInFinder = HostCommand(
    id: "session.showInFinder", title: "Show in Finder", group: 0)

  /// The available command of the second group.
  static let openTasks = HostCommand(
    id: "session.openTasks", title: "Open Tasks in New Window", group: 1)

  /// The command of the second group that is not available.
  static let stop = HostCommand(id: "session.stop", title: "Stop", group: 1)

  /// The reason that ``stop`` gives for its unavailability.
  static let stopReason = "Nothing runs"

  /// The titles of the context menu of ``hostPath``: the available command
  /// of the first group, a separator, and the available command of the
  /// second group.
  static let menuTitles = [showInFinder.title, "", openTasks.title]

  /// The titles of each command of the host scope, available or not.
  static let hostCommandTitles: Set = [showInFinder.title, openTasks.title, stop.title]

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
    func definition(make: @escaping @Sendable (CommandPayload?) -> any EditorCommands.Command)
      -> CommandDefinition
    {
      CommandDefinition(
        id: id, title: .static(title), contextMenu: ContextMenuPlacement(group: group, order: 0),
        make: make)
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
      stop.definition { _ in UnavailableCommand(id: stop.id, title: stop.title, reason: reason) },
      at: hostPath)
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
        session: session, connection: connection, sessionTitle: "AgentViewKit",
        headerContextMenuPath: path
      )
      .environment(\.codeBlockModelCache, cache)
      .environment(\.threadHeader, header)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  /// The point of a right click on a part of the top bar.
  enum ClickSpot {
    /// The view that has the accessibility identifier.
    case identifier(String)
    /// A point near the trailing edge of the frame of the view that has the
    /// accessibility identifier, after the end of its text.
    case trailingEdge(ofFrame: String)
    /// The midpoint of the gap between the bottom of the frame of the status
    /// line and the top of the frame of the header of the host.
    case gapBetweenStatusLineAndHostHeader
  }

  /// Gives the midpoint of the gap between the bottom of the frame of the
  /// status line and the top of the frame of the header of the host, in
  /// window coordinates.
  ///
  /// - Parameter harness: The harness of a mounted thread that shows the
  ///   status line and the header of the host.
  /// - Returns: The point.
  static func gapBetweenStatusLineAndHostHeader(in harness: HostedViewHarness<some View>) throws
    -> NSPoint
  {
    let line = try #require(harness.frame(identifier: StatusLineView.identifier))
    let header = try #require(harness.frame(identifier: AgentThreadLayout.headerIdentifier))
    try #require(line.minY > header.maxY)
    let gap = CGRect(
      x: line.minX, y: header.maxY, width: line.width, height: line.minY - header.maxY)
    return harness.window.convertPoint(fromScreen: NSPoint(x: gap.midX, y: gap.midY))
  }

  /// Gives the accessibility identifier of the banner of the first notice of
  /// `session`.
  ///
  /// - Parameter session: A session model with one notice or more.
  /// - Returns: The identifier of the ``SessionNoticeBanner`` of the first
  ///   notice.
  static func noticeBannerIdentifier(of session: SessionModel) throws -> String {
    let notice = try #require(session.notices.first)
    return SessionNoticeBanner.identifier(for: notice.id)
  }

  /// Gives the context menu at `spot` in `harness`.
  ///
  /// - Parameters:
  ///   - spot: The point of the right click.
  ///   - harness: The harness of the mounted thread.
  /// - Returns: The context menu, or `nil` when the spot has no context menu.
  static func contextMenu(at spot: ClickSpot, in harness: HostedViewHarness<some View>) throws
    -> NSMenu?
  {
    switch spot {
    case .identifier(let identifier):
      return try harness.contextMenu(identifier: identifier)
    case .trailingEdge(let identifier):
      let frame = try #require(harness.frame(identifier: identifier))
      let point = harness.window.convertPoint(
        fromScreen: NSPoint(x: frame.maxX - trailingClickInset, y: frame.midY))
      return try harness.contextMenu(at: point)
    case .gapBetweenStatusLineAndHostHeader:
      return try harness.contextMenu(at: gapBetweenStatusLineAndHostHeader(in: harness))
    }
  }

  /// Mounts a thread, reads the context menu at `spot`, and gives the menu to
  /// `body` while the thread is in its window.
  ///
  /// - Parameters:
  ///   - spot: The point of the right click.
  ///   - session: The session model of the thread.
  ///   - path: The path of the host scope, or `nil` for no context menu.
  ///   - header: The header of the host, or `nil` for no header.
  ///   - log: The log that gets each run of the host commands.
  ///   - body: Examines the context menu, or `nil` when the spot has none.
  /// - Returns: The value that `body` gives.
  static func withContextMenu<Result>(
    at spot: ClickSpot, of session: SessionModel = .preview(), path: FocusPath?,
    header: AnyView? = nil,
    log: CommandRunLog = CommandRunLog(), _ body: (NSMenu?) throws -> Result
  ) throws -> Result {
    let harness = mountThread(session, path: path, system: makeSystem(log: log), header: header)
    defer { harness.close() }
    return try body(try contextMenu(at: spot, in: harness))
  }

  /// Expects that a right click at `spot` shows the context menu of
  /// ``hostPath``.
  ///
  /// - Parameters:
  ///   - spot: The point of the right click.
  ///   - session: The session model of the thread.
  ///   - header: The header of the host, or `nil` for no header.
  ///   - sourceLocation: The location of the call, for each failure.
  static func expectMenuOfHostPath(
    at spot: ClickSpot, of session: SessionModel = .preview(), header: AnyView? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let titles = try withContextMenu(at: spot, of: session, path: hostPath, header: header) {
      $0?.items.map(\.title)
    }

    #expect(titles == menuTitles, sourceLocation: sourceLocation)
  }

  /// Expects that a right click at `spot` shows no context menu when the
  /// thread has no host path.
  ///
  /// - Parameters:
  ///   - spot: The point of the right click.
  ///   - session: The session model of the thread.
  ///   - header: The header of the host, or `nil` for no header.
  ///   - sourceLocation: The location of the call, for each failure.
  static func expectNoContextMenu(
    at spot: ClickSpot, of session: SessionModel = .preview(), header: AnyView? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let menu = try withContextMenu(at: spot, of: session, path: nil, header: header) { $0 }

    #expect(menu == nil, sourceLocation: sourceLocation)
  }

  /// Expects that a right click at `spot` shows no item of the host scope
  /// when the thread has no host path. The click can go to the list below the
  /// top bar, so the spot can show a menu of the list.
  ///
  /// - Parameters:
  ///   - spot: The point of the right click.
  ///   - header: The header of the host, or `nil` for no header.
  ///   - sourceLocation: The location of the call, for each failure.
  static func expectNoHostItem(
    at spot: ClickSpot, header: AnyView? = nil, sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let titles = try withContextMenu(at: spot, path: nil, header: header) {
      $0?.items.map(\.title) ?? []
    }

    #expect(hostCommandTitles.isDisjoint(with: titles), sourceLocation: sourceLocation)
  }

  @Test func theHeaderShowsTheContextMenuOfTheHostPath() throws {
    try Self.expectMenuOfHostPath(at: .identifier(StatusLineView.identifier))
  }

  @Test func theEmptyPartOfTheHeaderShowsTheContextMenuOfTheHostPath() throws {
    try Self.expectMenuOfHostPath(at: .trailingEdge(ofFrame: StatusLineView.identifier))
  }

  @Test func theHeaderContextMenuLeavesOutACommandThatIsNotAvailable() throws {
    let titles = try Self.withContextMenu(
      at: .identifier(StatusLineView.identifier), path: Self.hostPath
    ) { menu in
      try #require(menu).items.map(\.title)
    }

    #expect(!titles.contains(Self.stop.title))
  }

  @Test func anItemOfTheHeaderContextMenuRunsItsCommandAtTheHostPath() throws {
    let log = CommandRunLog()

    try Self.withContextMenu(
      at: .identifier(StatusLineView.identifier), path: Self.hostPath, log: log
    ) { menu in
      let menu = try #require(menu)
      let index = try #require(menu.items.firstIndex { $0.title == Self.openTasks.title })
      menu.performActionForItem(at: index)
    }

    #expect(log.runs == [CommandRun(id: Self.openTasks.id, path: Self.hostPath)])
  }

  @Test func aHeaderWithNoPathHasNoContextMenu() throws {
    try Self.expectNoContextMenu(at: .identifier(StatusLineView.identifier))
  }

  @Test func theHostHeaderShowsTheContextMenuOfTheHostPath() throws {
    try Self.expectMenuOfHostPath(
      at: .identifier(Self.hostHeaderTextIdentifier), header: Self.hostHeader)
  }

  @Test func theEmptyPartOfTheHostHeaderShowsTheContextMenuOfTheHostPath() throws {
    try Self.expectMenuOfHostPath(
      at: .trailingEdge(ofFrame: AgentThreadLayout.headerIdentifier), header: Self.hostHeader)
  }

  @Test func aNoticeBannerShowsTheContextMenuOfTheHostPath() throws {
    let session = Self.sessionWithNotice

    try Self.expectMenuOfHostPath(
      at: .identifier(try Self.noticeBannerIdentifier(of: session)), of: session)
  }

  @Test func aHostHeaderWithNoPathHasNoContextMenu() throws {
    try Self.expectNoContextMenu(
      at: .identifier(Self.hostHeaderTextIdentifier), header: Self.hostHeader)
  }

  @Test func aNoticeBannerWithNoPathHasNoContextMenu() throws {
    let session = Self.sessionWithNotice

    try Self.expectNoContextMenu(
      at: .identifier(try Self.noticeBannerIdentifier(of: session)), of: session)
  }

  @Test func theGapBetweenTheStatusLineAndTheHostHeaderShowsTheContextMenuOfTheHostPath() throws {
    try Self.expectMenuOfHostPath(
      at: .gapBetweenStatusLineAndHostHeader, header: Self.hostHeader)
  }

  @Test func theGapBetweenTheStatusLineAndTheHostHeaderWithNoPathShowsNoHostItem() throws {
    try Self.expectNoHostItem(at: .gapBetweenStatusLineAndHostHeader, header: Self.hostHeader)
  }
}
