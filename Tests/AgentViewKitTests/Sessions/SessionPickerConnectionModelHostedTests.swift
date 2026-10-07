import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import DemoSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Observation
import SwiftUI
import Testing

/// The session picker and the thread close over a `ConnectionModel`
/// (update.md §4.3, §4.7 "Session picker", "Capabilities", §8 item 2).
///
/// Each test opens a ``ScriptedSession``. The view reads the session list,
/// the cursor flag and the capability flags of its connection model. The
/// tests assert on the frames that the scripted agent received.
@Suite(.serialized, .hostedSerially) @MainActor struct SessionPickerConnectionModelHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The size of a list that shows each row.
  static let listSize = CGSize(width: 480, height: 640)

  /// The cursor that the first page gives.
  static let secondPageCursor = "page-2"

  /// The id of the listed session that is not open.
  static let closedSessionID = "s2"

  /// The id of the session of the second page.
  static let secondPageSessionID = "s3"

  /// The working directory of the listed sessions.
  static let listedDirectory = "/work/app"

  /// The working directory of the session with no title.
  static let docsDirectory = "/work/docs"

  /// The title of the open session in the first page.
  static let openSessionTitle = "Fix the build"

  /// The title that a `session_info_update` gives to the open session.
  static let renamedTitle = "Ship the release"

  /// The `session/list` result of the first page: the open session and one
  /// session with no title, with a next cursor.
  static let firstPage = #"""
    {"sessions": [
       {"sessionId": "\#(ScriptedSession.sessionID)", "cwd": "\#(listedDirectory)",
        "title": "\#(openSessionTitle)"},
       {"sessionId": "\#(closedSessionID)", "cwd": "\#(docsDirectory)", "title": "   "}],
     "nextCursor": "\#(secondPageCursor)"}
    """#

  /// The `session/list` result of the second page: one session and no next
  /// cursor.
  static let secondPage = #"""
    {"sessions": [{"sessionId": "\#(secondPageSessionID)", "cwd": "\#(listedDirectory)",
                   "title": "Write the release notes"}]}
    """#

  /// The additional workspace roots of the listed session ``closedSessionID``
  /// in ``directoriesPage``.
  static let listedAdditionalDirectories = ["/work/shared", "/work/vendor"]

  /// A `session/list` result with one session that has additional workspace
  /// roots: ``closedSessionID`` in ``docsDirectory`` with
  /// ``listedAdditionalDirectories``.
  static let directoriesPage = #"""
    {"sessions": [{"sessionId": "\#(closedSessionID)", "cwd": "\#(docsDirectory)",
                   "additionalDirectories": ["\#(listedAdditionalDirectories.joined(separator: #"", ""#))"]}]}
    """#

  /// The `initialize` result of an agent that serves `session/delete`.
  static let deleteCapableInitialize = #"""
    {"info": {"name": "scripted-agent", "version": "1.0.0"}, "protocolVersion": 2,
     "capabilities": {"session": {"delete": {}}}}
    """#

  /// The `initialize` result of an agent with no session capability: it
  /// does not list, resume, close or delete sessions.
  static let sessionlessInitialize = #"""
    {"info": {"name": "scripted-agent", "version": "1.0.0"}, "protocolVersion": 2,
     "capabilities": {}}
    """#

  /// The `session/new` result of the session that ``ScriptedSession`` opens.
  static let scriptedNewSessionResult = #"{"sessionId": "\#(ScriptedSession.sessionID)"}"#

  /// The `session/new` result of a second session. A test sends that
  /// request after a step, and its answer comes after each frame of the
  /// step.
  static let fenceNewSessionResult = #"{"sessionId": "fence-session"}"#

  /// Tells whether the thread view of ``ClosingHost`` shows.
  @Observable final class Visibility {
    /// Whether the thread view shows.
    var showsThread = true
  }

  /// A host that removes its thread view when ``Visibility/showsThread`` is
  /// `false`.
  struct ClosingHost: View {
    /// The scripted session that the thread view shows.
    let session: ScriptedSession

    /// The flag that keeps the thread view.
    let visibility: Visibility

    var body: some View {
      if visibility.showsThread {
        AgentThreadView(session: session.model, connection: session.connection, actions: NoopThreadActions())
      }
    }
  }

  /// Opens a scripted session whose agent answers `session/list` with the
  /// two pages, in order.
  ///
  /// - Parameter initialize: The `initialize` result of the agent, or `nil`
  ///   for the default result of ``ScriptedSession``.
  /// - Returns: The open session.
  static func openSession(initialize: String? = nil) async throws -> ScriptedSession {
    try await ScriptedSession.open { agent in
      agent.resultQueues["session/list"] = [firstPage, secondPage]
      if let initialize {
        agent.results["initialize"] = initialize
      }
    }
  }

  /// Mounts the picker of a session, and waits until the first page shows.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - onOpen: The action for a resumed session.
  /// - Returns: The harness that shows the picker.
  static func mountPicker(
    _ session: ScriptedSession, onOpen: @escaping (SessionModel) -> Void = { _ in }
  ) async -> HostedViewHarness<SessionListView> {
    let harness = HostedViewHarness(
      SessionListView(connection: session.connection, onOpen: onOpen), size: listSize)
    await harness.pump(until: waitTimeout) { !rowIdentifiers(in: harness).isEmpty }
    return harness
  }

  /// The identifiers of the rows that show.
  ///
  /// - Parameter harness: The harness that shows the picker.
  /// - Returns: The row identifiers, in view order.
  static func rowIdentifiers<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
    harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(SessionListView.rowIdentifierPrefix)
    }
  }

  /// The row identifier of a session id.
  ///
  /// - Parameter id: The raw session id.
  /// - Returns: The identifier of the row.
  static func row(_ id: String) -> String {
    SessionListView.rowIdentifier(for: SessionId(rawValue: id))
  }

  // MARK: - Paging

  @Test func theFirstPageShowsFromTheSessionsOfTheModel() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    #expect(Self.rowIdentifiers(in: harness) == [Self.row(ScriptedSession.sessionID), Self.row(Self.closedSessionID)])
    #expect(session.connection.sessions.map(\.sessionId.rawValue) == [ScriptedSession.sessionID, Self.closedSessionID])
    #expect(harness.element(identifier: SessionListView.loadMoreIdentifier) != nil)
    #expect(session.agent.messages(method: "session/list").count == 1)
  }

  @Test func oneLoadMoreShowsTwoPagesAndSendsTheCursor() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    try harness.press(identifier: SessionListView.loadMoreIdentifier)
    await harness.pump(until: Self.waitTimeout) { Self.rowIdentifiers(in: harness).count == 3 }

    #expect(
      Self.rowIdentifiers(in: harness) == [
        Self.row(ScriptedSession.sessionID), Self.row(Self.closedSessionID), Self.row(Self.secondPageSessionID),
      ])
    #expect(harness.element(identifier: SessionListView.loadMoreIdentifier) == nil)
    let lists = session.agent.messages(method: "session/list")
    #expect(lists.count == 2)
    #expect(lists.last?["params"]?["cursor"] == .string(Self.secondPageCursor))
  }

  @Test func aRefreshSendsTheWorkingDirectoryAndReplacesTheList() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = HostedViewHarness(
      SessionListView(
        connection: session.connection, cwd: AbsolutePath(rawValue: Self.listedDirectory), onOpen: { _ in }),
      size: Self.listSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) { !Self.rowIdentifiers(in: harness).isEmpty }

    try harness.press(identifier: SessionListView.refreshIdentifier)
    await harness.pump(until: Self.waitTimeout) { session.agent.messages(method: "session/list").count == 2 }
    await harness.pump(until: Self.waitTimeout) { Self.rowIdentifiers(in: harness).count == 1 }

    let lists = session.agent.messages(method: "session/list")
    #expect(lists.map { $0["params"]?["cwd"] } == [.string(Self.listedDirectory), .string(Self.listedDirectory)])
    #expect(Self.rowIdentifiers(in: harness) == [Self.row(Self.secondPageSessionID)])
  }

  @Test func eachRowShowsTheTitleOrTheUntitledTitle() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains(Self.openSessionTitle) })
    #expect(labels.contains { $0.contains(SessionListView.untitledTitle) })
  }

  // MARK: - Session info

  @Test func aSessionInfoUpdateOfTheOpenSessionChangesItsRowTitle() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    try await session.sendUpdate(#"{"sessionUpdate": "session_info_update", "title": "\#(Self.renamedTitle)"}"#)
    await harness.pump(until: Self.waitTimeout) {
      harness.accessibilityElements().compactMap(\.label).contains { $0.contains(Self.renamedTitle) }
    }

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains { $0.contains(Self.renamedTitle) })
    #expect(!labels.contains { $0.contains(Self.openSessionTitle) })
    #expect(session.agent.messages(method: "session/list").count == 1)
  }

  // MARK: - Search

  @Test func theSearchTextFiltersTheRowsByTitleAndDirectory() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    #expect(harness.focusFirstEditableTextView(of: NSTextField.self))
    harness.type("docs")
    await harness.pump(until: Self.waitTimeout) { Self.rowIdentifiers(in: harness).count == 1 }

    #expect(Self.rowIdentifiers(in: harness) == [Self.row(Self.closedSessionID)])
    #expect(session.connection.sessions.count == 2)
  }

  // MARK: - Resume

  @Test func aRowPressResumesTheSessionFromTheStartAndOpensItsModel() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    var opened: [SessionModel] = []
    let harness = await Self.mountPicker(session) { opened.append($0) }
    defer { harness.close() }

    try harness.press(identifier: Self.row(Self.closedSessionID))
    await harness.pump(until: Self.waitTimeout) { !opened.isEmpty }

    #expect(opened.map(\.sessionId.rawValue) == [Self.closedSessionID])
    let resume = try #require(session.agent.messages(method: "session/resume").first)
    #expect(resume["params"]?["sessionId"] == .string(Self.closedSessionID))
    #expect(resume["params"]?["cwd"] == .string(Self.docsDirectory))
    #expect(resume["params"]?["replayFrom"] == .object(["type": .string("start")]))
    #expect(resume["params"]?["additionalDirectories"] == nil)
  }

  @Test func aRowPressSendsTheWorkingDirectoryAndEachAdditionalDirectoryOfTheRow() async throws {
    let session = try await ScriptedSession.open { agent in
      agent.results["initialize"] = ScriptedSession.additionalDirectoriesInitializeResult
      agent.resultQueues["session/list"] = [Self.directoriesPage]
    }
    defer { session.close() }
    var opened: [SessionModel] = []
    let harness = await Self.mountPicker(session) { opened.append($0) }
    defer { harness.close() }

    try harness.press(identifier: Self.row(Self.closedSessionID))
    await harness.pump(until: Self.waitTimeout) { !opened.isEmpty }

    let resume = try #require(session.agent.messages(method: "session/resume").first)
    #expect(resume["params"]?["cwd"] == .string(Self.docsDirectory))
    #expect(resume["params"]?["additionalDirectories"] == .array(Self.listedAdditionalDirectories.map { .string($0) }))
    #expect(opened.first?.additionalDirectories.map(\.rawValue) == Self.listedAdditionalDirectories)
  }

  // MARK: - Delete

  @Test func aDeleteSendsSessionDeleteAndTheRowGoesAwayWithTheItem() async throws {
    let session = try await Self.openSession(initialize: Self.deleteCapableInitialize)
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    try harness.press(identifier: SessionListView.deleteIdentifier(for: SessionId(rawValue: Self.closedSessionID)))
    await harness.pump(until: Self.waitTimeout) { Self.rowIdentifiers(in: harness).count == 1 }

    let delete = try #require(session.agent.messages(method: "session/delete").first)
    #expect(delete["params"]?["sessionId"] == .string(Self.closedSessionID))
    #expect(session.connection.sessions.map(\.sessionId.rawValue) == [ScriptedSession.sessionID])
    #expect(Self.rowIdentifiers(in: harness) == [Self.row(ScriptedSession.sessionID)])
  }

  @Test func aFailedDeleteShowsTheErrorAndKeepsTheRow() async throws {
    let session = try await ScriptedSession.open { agent in
      agent.resultQueues["session/list"] = [Self.firstPage]
      agent.results["initialize"] = Self.deleteCapableInitialize
      agent.failingMethods = ["session/delete"]
    }
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    try harness.press(identifier: SessionListView.deleteIdentifier(for: SessionId(rawValue: Self.closedSessionID)))
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SessionListView.failureIdentifier) != nil
    }

    #expect(harness.element(identifier: SessionListView.failureIdentifier) != nil)
    #expect(Self.rowIdentifiers(in: harness).count == 2)
  }

  // MARK: - Capability flags

  @Test func withNoDeleteCapabilityNoDeleteControlShows() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = await Self.mountPicker(session)
    defer { harness.close() }

    #expect(!session.connection.canDeleteSessions)
    #expect(Self.rowIdentifiers(in: harness).count == 2)
    let deleteControls = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(SessionListView.deleteIdentifierPrefix)
    }
    #expect(deleteControls.isEmpty)
  }

  @Test func withNoSessionCapabilityTheListAndResumeAreHiddenAndNothingIsListed() async throws {
    let session = try await Self.openSession(initialize: Self.sessionlessInitialize)
    defer { session.close() }
    let harness = HostedViewHarness(
      SessionListView(connection: session.connection, onOpen: { _ in }), size: Self.listSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SessionListView.unavailableIdentifier) != nil
    }

    #expect(!session.connection.canListSessions)
    #expect(!session.connection.canResumeSessions)
    #expect(harness.element(identifier: SessionListView.unavailableIdentifier) != nil)
    #expect(Self.rowIdentifiers(in: harness).isEmpty)
    #expect(harness.element(identifier: SessionListView.refreshIdentifier) == nil)
    #expect(session.agent.messages(method: "session/list").isEmpty)
  }

  @Test func aFailedFirstPageShowsTheError() async throws {
    let session = try await ScriptedSession.open { $0.failingMethods = ["session/list"] }
    defer { session.close() }
    let harness = HostedViewHarness(
      SessionListView(connection: session.connection, onOpen: { _ in }), size: Self.listSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SessionListView.failureIdentifier) != nil
    }

    #expect(harness.element(identifier: SessionListView.failureIdentifier) != nil)
    #expect(Self.rowIdentifiers(in: harness).isEmpty)
  }

  // MARK: - New session

  @Test func theNewSessionButtonCallsTheAction() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    var count = 0
    let harness = HostedViewHarness(
      SessionListView(connection: session.connection, onOpen: { _ in }, onNewSession: { count += 1 }),
      size: Self.listSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) { !Self.rowIdentifiers(in: harness).isEmpty }

    try harness.press(identifier: SessionListView.newSessionIdentifier)

    #expect(count == 1)
  }

  // MARK: - Thread close

  @Test func theCloseOfAThreadViewSendsSessionClose() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let visibility = Visibility()
    let harness = HostedViewHarness(ClosingHost(session: session, visibility: visibility), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    visibility.showsThread = false
    await harness.pump(until: Self.waitTimeout) { session.model.isClosed }

    let close = try #require(session.agent.messages(method: "session/close").first)
    #expect(close["params"]?["sessionId"] == .string(ScriptedSession.sessionID))
    #expect(session.model.isClosed)
    #expect(session.connection.session(for: session.model.sessionId) == nil)
  }

  @Test func withNoCloseCapabilityTheCloseOfAThreadViewSendsNothing() async throws {
    let session = try await ScriptedSession.open { agent in
      agent.results["initialize"] = Self.sessionlessInitialize
      agent.resultQueues["session/new"] = [Self.scriptedNewSessionResult, Self.fenceNewSessionResult]
    }
    defer { session.close() }
    let visibility = Visibility()
    let harness = HostedViewHarness(ClosingHost(session: session, visibility: visibility), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    visibility.showsThread = false
    harness.pump()
    // The frames go over the transport in order, so the answer to this
    // request comes after each frame that the close sent.
    _ = try await session.connection.newSession(NewSessionRequest(cwd: AbsolutePath(rawValue: Self.listedDirectory)))

    #expect(!session.connection.canCloseSessions)
    #expect(session.agent.messages(method: "session/close").isEmpty)
    #expect(!session.model.isClosed)
  }
}
