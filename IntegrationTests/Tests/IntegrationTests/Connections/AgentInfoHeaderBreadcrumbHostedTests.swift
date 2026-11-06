@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the "Agent › Session" breadcrumb of ``AgentInfoHeader`` (^2sg9taf).
///
/// The layout tests mount the row of the breadcrumb (``AgentBreadcrumb``)
/// alone, because the header is one accessibility element and hides the
/// frames of its segments. The header tests mount the whole header and read
/// that one element.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentInfoHeaderBreadcrumbHostedTests {
  /// The name that the agent of the tests shows: the title of its info.
  static let agentName = "Scripted Agent"

  /// The version of the agent of the tests.
  static let agentVersion = "2.1.0"

  /// The session title that a host gives, such as the name of a folder.
  static let sessionTitle = "AgentViewKit"

  /// A session title that is longer than the narrow row can show.
  static let longSessionTitle =
    "The session that migrates the invoices of each month to the new table, with a long title"

  /// A size wide enough to show each segment whole.
  static let wideSize = CGSize(width: 2_400, height: 120)

  /// A size too narrow to show the long session title whole.
  static let narrowSize = CGSize(width: 420, height: 120)

  /// The size of the small area of a host window, such as the chat pane of
  /// Testudo: too narrow for the root crumb beside a long crumb, and tall
  /// enough for the long crumb to wrap.
  static let paneSize = CGSize(width: 260, height: 320)

  /// The id of the child with the long title in the session tests.
  static let longChild = SessionId(rawValue: "long-child")

  /// The id of the child of the crumb tests.
  static let child = SessionId(rawValue: "reviewer")

  /// The title of the child of the crumb tests.
  static let childTitle = "Reviewer"

  /// The id of the sibling of the child of the crumb tests.
  static let sibling = SessionId(rawValue: "linter")

  /// The title of the sibling of the child of the crumb tests.
  static let siblingTitle = "Linter"

  /// The locale of the views whose labels the tests read.
  static let locale = Locale(identifier: "en_US")

  /// The largest difference between two widths that the tests take as the
  /// same width, in points.
  static let widthTolerance: CGFloat = 0.5

  /// A code-built connection model whose agent gives ``agentName`` and
  /// ``agentVersion``.
  static var connection: ConnectionModel {
    .preview(
      initializeResponse: InitializeResponse(
        info: Implementation(name: "scripted-agent", version: agentVersion, title: agentName),
        protocolVersion: ACPClient.supportedProtocolVersion))
  }

  /// Mounts the row of the breadcrumb.
  ///
  /// - Parameters:
  ///   - sessionTitle: The session title, or `nil` for the agent alone.
  ///   - size: The size of the window.
  /// - Returns: The harness, after one render pass.
  static func mountRow(sessionTitle: String?, size: CGSize) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      AgentBreadcrumb(agent: agentName, version: agentVersion, sessionTitle: sessionTitle)
    }
    harness.render()
    return harness
  }

  /// Mounts the whole header.
  ///
  /// - Parameter sessionTitle: The session title, or `nil` for the agent
  ///   alone.
  /// - Returns: The harness, after one render pass.
  static func mountHeader(sessionTitle: String?) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: wideSize) {
      AgentInfoHeader(connection: connection, sessionTitle: sessionTitle)
    }
    harness.render()
    return harness
  }

  /// The frames of the agent segment and of the session segment of a row.
  ///
  /// - Parameter harness: The harness of the row.
  /// - Returns: The two frames.
  /// - Throws: An issue when the row has no session segment.
  static func segmentFrames(in harness: HostedViewHarness<some View>) throws -> (agent: CGRect, session: CGRect) {
    let agent = try #require(harness.frame(identifier: AgentBreadcrumb.agentIdentifier))
    let session = try #require(harness.frame(identifier: AgentBreadcrumb.sessionIdentifier))
    return (agent, session)
  }

  // MARK: - Layout

  @Test func withNoSessionTitleTheBreadcrumbShowsTheAgentAlone() {
    let harness = Self.mountRow(sessionTitle: nil, size: Self.wideSize)
    defer { harness.close() }

    #expect(harness.element(identifier: AgentBreadcrumb.agentIdentifier)?.label == Self.agentName)
    #expect(harness.element(identifier: AgentBreadcrumb.sessionIdentifier) == nil)
  }

  @Test func theSessionSegmentFollowsTheAgentSegment() throws {
    let harness = Self.mountRow(sessionTitle: Self.sessionTitle, size: Self.wideSize)
    defer { harness.close() }

    let frames = try Self.segmentFrames(in: harness)

    #expect(harness.element(identifier: AgentBreadcrumb.sessionIdentifier)?.label == Self.sessionTitle)
    #expect(frames.agent.maxX < frames.session.minX, "\(frames)")
  }

  @Test func aLongSessionTitleTruncatesBeforeTheAgentSegment() throws {
    let wide = Self.mountRow(sessionTitle: Self.longSessionTitle, size: Self.wideSize)
    let whole = try Self.segmentFrames(in: wide)
    wide.close()
    let narrow = Self.mountRow(sessionTitle: Self.longSessionTitle, size: Self.narrowSize)
    defer { narrow.close() }

    let truncated = try Self.segmentFrames(in: narrow)
    let host = narrow.screenFrame(of: narrow.hostingView)

    #expect(abs(truncated.agent.width - whole.agent.width) <= Self.widthTolerance, "\(truncated), \(whole)")
    #expect(truncated.session.width < whole.session.width, "\(truncated), \(whole)")
    #expect(truncated.session.maxX <= host.maxX, "\(truncated), host \(host)")
  }

  // MARK: - The header element

  @Test func theHeaderIsOneElementThatReadsTheAgentAndTheSession() throws {
    let harness = Self.mountHeader(sessionTitle: Self.sessionTitle)
    defer { harness.close() }

    let header = try #require(harness.element(identifier: AgentInfoHeader.identifier))

    #expect(header.label == AgentInfoHeader.label(agent: Self.agentName, path: [Self.sessionTitle]))
    #expect(header.value == "Version \(Self.agentVersion)")
    #expect(harness.elements(under: AgentInfoHeader.identifier).isEmpty)
  }

  @Test func withNoSessionTitleTheHeaderReadsTheAgentAlone() throws {
    let harness = Self.mountHeader(sessionTitle: nil)
    defer { harness.close() }

    let header = try #require(harness.element(identifier: AgentInfoHeader.identifier))

    #expect(header.label == AgentInfoHeader.label(agent: Self.agentName, path: []))
    #expect(harness.elements(under: AgentInfoHeader.identifier).isEmpty)
  }

  // MARK: - The crumbs of a session

  /// Mounts the header of a session in a window of `size`, in the locale of
  /// the tests.
  ///
  /// - Parameters:
  ///   - session: The session whose path the header shows.
  ///   - connection: The connection of the session.
  ///   - size: The size of the window.
  /// - Returns: The harness, after the render passes that land the shape of
  ///   the bar that fits.
  static func mountCrumbs(
    of session: SessionModel, connection: ConnectionModel, size: CGSize
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      AgentInfoHeader(connection: connection, session: session)
        .environment(\.locale, Self.locale)
    }
    harness.render()
    harness.render()
    return harness
  }

  /// A production change that fails this test: the bar hides the last crumb
  /// when it has no room, cuts it from the accessibility tree, or hides the
  /// root and shows no overflow crumb that holds it.
  @Test func aSqueezedCrumbCollapsesIntoTheOverflowAndThenWraps() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await session.announceChild(Self.longChild, title: Self.longSessionTitle)
    let root = session.model
    let harness = Self.mountCrumbs(of: child, connection: session.connection, size: Self.paneSize)
    defer { harness.close() }

    let overflow = try harness.perform(.showMenu, on: EditorBreadcrumbBar.overflowAccessibilityIdentifier)
    let last = harness.element(identifier: SessionBreadcrumb.crumbIdentifier(for: Self.longChild))

    #expect(harness.element(identifier: SessionBreadcrumb.crumbIdentifier(for: root.sessionId)) == nil)
    #expect(overflow?.items.map(\.title) == [root.displayTitle])
    #expect(last?.label == Self.longSessionTitle)
  }

  /// A production change that fails this test: a crumb splits its title and
  /// its mark into two elements, or the bar publishes a second element for a
  /// crumb.
  @Test func eachCrumbIsOneElement() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await session.announceChild(Self.child, title: Self.childTitle)
    let harness = Self.mountCrumbs(of: child, connection: session.connection, size: Self.wideSize)
    defer { harness.close() }

    let crumbs = harness.accessibilityElements().filter { $0.label == Self.childTitle }

    #expect(crumbs.count == 1, "the elements are \(crumbs)")
  }

  /// A production change that fails this test: the crumb of a session opens
  /// no menu through accessibility, or a menu without its siblings.
  @Test func showingTheMenuOfACrumbListsItsSiblings() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await session.announceChild(Self.child, title: Self.childTitle)
    try await session.announceChild(Self.sibling, title: Self.siblingTitle)
    let harness = Self.mountCrumbs(of: child, connection: session.connection, size: Self.wideSize)
    defer { harness.close() }

    let menu = try harness.perform(.showMenu, on: SessionBreadcrumb.crumbIdentifier(for: Self.child))
    let expected = child.siblingsIncludingSelf.map { SessionStateText.choiceLabel(for: $0, locale: Self.locale) }

    #expect(menu?.items.map(\.title) == expected)
  }

  /// A production change that fails this test: the warning mark of a crumb
  /// whose child waits for the user is drawn and not spoken.
  @Test func aCrumbThatNeedsTheUserSpeaksItAsItsValue() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await session.announceChild(Self.child, title: Self.childTitle)
    try await session.sendInOrder([.permission(id: 1, sessionId: Self.child)], to: child)
    let harness = Self.mountCrumbs(of: child, connection: session.connection, size: Self.wideSize)
    defer { harness.close() }

    let crumb = harness.element(identifier: SessionBreadcrumb.crumbIdentifier(for: Self.child))

    #expect(crumb?.value == SessionStateText.needsAttention)
  }

  @Test func theFirstCrumbShowsTheSessionTitleOfTheHostAndFollowsItsChanges() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let title = HostTitle(Self.sessionTitle)
    let harness = HostedViewHarness(size: Self.wideSize) {
      TitledHeader(connection: session.connection, session: session.model, title: title)
    }
    defer { harness.close() }
    harness.render()

    let info = try #require(session.connection.initializeResponse?.info)
    let agent = info.title ?? info.name

    let header = try #require(harness.element(identifier: AgentInfoHeader.identifier))
    #expect(header.label == AgentInfoHeader.label(agent: agent, path: [Self.sessionTitle]))

    title.value = "Project"
    harness.render()

    let changed = try #require(harness.element(identifier: AgentInfoHeader.identifier))
    #expect(changed.label == AgentInfoHeader.label(agent: agent, path: ["Project"]))
  }
}

/// The title of a tab of a host, which changes while the header shows.
@MainActor @Observable private final class HostTitle {
  var value: String

  init(_ value: String) { self.value = value }
}

/// A host that gives its tab title to the header. The body reads the title,
/// so a change of it renders the header again, as in a host app.
private struct TitledHeader: View {
  let connection: ConnectionModel
  let session: SessionModel
  let title: HostTitle

  var body: some View {
    AgentInfoHeader(connection: connection, session: session, sessionTitle: title.value)
  }
}
