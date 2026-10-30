#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import SwiftUI
  import Testing

  /// Tests for the top bar of a thread: the header and the banners at the top
  /// are in the bar, and the list scrolls under the bar, and thus under the
  /// toolbar of the window (EditorKit `style.md`, "Scroll under the
  /// bars", D113 answer 7). The list lays its rows out under the bar, but the
  /// system edge effect washes them out there, because AppKit makes the effect
  /// as tall as the whole top inset (^22wbz12, accepted by the user on
  /// 2026-10-23). These tests check the frames, not that a row shows.
  ///
  /// The frame tests use the method of ``ThreadBottomBarHostedTests``: they
  /// read the frame of the `NSScrollView` of the list and the accessibility
  /// frames of the header and the banners after one layout pass of the
  /// window. Each update of the agent is followed by a wait for the model
  /// value that the update is certain to change.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadTopBarHostedTests {
    /// The severity of the notice of the tests.
    static let noticeSeverity = "info"

    /// Opens a scripted session whose agent gives its info, with
    /// ``ConversationViewHostedTests/scrollEntryCount`` agent messages and
    /// one notice.
    ///
    /// The transcript is taller than the window, so that the rows fill the
    /// part of the list in view. The helper waits until the model holds the
    /// notice. When a send fails, the helper closes the session before it
    /// throws.
    ///
    /// - Returns: The scripted session.
    static func openSessionWithNotice() async throws -> ScriptedSession {
      let session = try await ConnectionModelViewsHostedTests.openSession()
      do {
        try await ConversationViewHostedTests.sendMessages(ConversationViewHostedTests.scrollEntryCount, to: session)
        try await session.sendUpdate(CompactionAndNoticeHostedTests.notice(severity: noticeSeverity))
      } catch {
        session.close()
        throw error
      }
      let model = session.model
      await ObservationWait.until { !model.notices.isEmpty }
      return session
    }

    /// The accessibility identifier of the banner of the first notice of
    /// `session`.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The identifier.
    /// - Throws: An issue when the session has no notice.
    static func noticeIdentifier(of session: ScriptedSession) throws -> String {
      SessionNoticeBanner.identifier(for: try #require(session.model.notices.first).id)
    }

    /// Expects that the thread in `harness` holds an element with each of
    /// `identifiers`, in the same order.
    ///
    /// The order is the navigation order, which is the order that VoiceOver
    /// reads (``HostedViewHarness/accessibilityElementsInNavigationOrder()``).
    /// In the plain order of the children, the top bar comes after the list.
    /// Each order ends with the list and then the floating controls of the
    /// bottom bar.
    ///
    /// - Parameters:
    ///   - identifiers: The accessibility identifiers of the top bar, in the
    ///     order of the bar.
    ///   - harness: The harness that shows the thread.
    /// - Throws: An issue when the thread holds no element with one of the
    ///   identifiers.
    static func expectReadingOrder(_ identifiers: [String], in harness: HostedViewHarness<some View>) throws {
      let all = harness.accessibilityElementsInNavigationOrder().compactMap(\.identifier)
      let expected = identifiers + [ConversationLayout.listIdentifier, AgentThreadLayout.floatingControlsIdentifier]

      let positions = try expected.map { try #require(all.firstIndex(of: $0), "\($0) is not in the thread") }

      #expect(positions == positions.sorted(), "\(expected) at \(positions)")
    }

    @Test func theListOfTheThreadReachesTheTopEdgeUnderTheHeaderAndTheNotice() async throws {
      let session = try await Self.openSessionWithNotice()
      defer { session.close() }
      let harness = ConnectionModelViewsHostedTests.mountThread(session)
      defer { harness.close() }
      harness.render()

      let host = harness.screenFrame(of: harness.hostingView)
      let list = try ThreadBottomBarHostedTests.listFrame(in: harness)
      let header = try #require(harness.frame(identifier: AgentInfoHeader.identifier))
      let notice = try #require(harness.frame(identifier: Self.noticeIdentifier(of: session)))

      // The y axis of the screen goes up, so the top edge is `maxY`.
      #expect(abs(list.maxY - host.maxY) <= ThreadBottomBarHostedTests.edgeTolerance, "list \(list), host \(host)")
      #expect(list.contains(header), "list \(list), header \(header)")
      #expect(list.contains(notice), "list \(list), notice \(notice)")
    }

    /// VoiceOver reads the thread in order: the header, the notice, the list,
    /// and then the floating controls of the bottom bar.
    @Test func theThreadReadsTheHeaderThenTheNoticeThenTheListThenTheBottomBar() async throws {
      let session = try await Self.openSessionWithNotice()
      defer { session.close() }
      let harness = ConnectionModelViewsHostedTests.mountThread(session)
      defer { harness.close() }
      harness.render()

      try Self.expectReadingOrder([AgentInfoHeader.identifier, Self.noticeIdentifier(of: session)], in: harness)
    }

    /// VoiceOver reads a closed thread in order: the header, the connection
    /// banner, the stream banner, the list, and then the floating controls
    /// of the bottom bar.
    @Test func aClosedThreadReadsTheHeaderThenTheBannersThenTheListThenTheBottomBar() async throws {
      let session = try await Self.openSessionWithNotice()
      defer { session.close() }
      let harness = ConnectionModelViewsHostedTests.mountThread(session)
      defer { harness.close() }

      // A close of the transport shows the disconnected banner and the closed
      // state of the stream banner.
      session.close()
      let connection = session.connection
      await harness.render { connection.state == .disconnected }

      try Self.expectReadingOrder(
        [
          AgentInfoHeader.identifier, AgentConnectionBanner.disconnectedIdentifier,
          SessionStreamBanner.closedIdentifier,
        ], in: harness)
    }
  }
#endif
